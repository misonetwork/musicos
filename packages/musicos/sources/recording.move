// Copyright (c) Sona Labs, Pte Ltd.
// SPDX-License-Identifier: Apache-2.0

module musicos::recording;

use interest_bps::bps::BPS;
use musicos::artifact::Artifact;
use musicos::composition::Composition;
use musicos::contributor::{Contributor, ContributorID};
use musicos::genre::Genre;
use musicos::mix::Mix;
use musicos::music::MUSIC;
use musicos::recording_artifact_variant::RecordingArtifactVariant;
use musicos::recording_contributor_role::RecordingContributorRole;
use musicos::share::{Self, share_icon_url};
use musicos::snapshot::Snapshot;
use std::string::String;
use sui::balance::Balance;
use sui::clock::Clock;
use sui::coin::TreasuryCap;
use sui::coin_registry::{Currency, MetadataCap};
use sui::derived_object::{claim, exists};
use sui::event::emit;
use sui::vec_map::{Self, VecMap};
use sui::vec_set::{Self, VecSet};

//=== Structs ===

public struct Recording<phantom RecordingShare> has key, store {
    id: UID,
    state: RecordingState,
    composition_id: ID,
    composition_commission_rate: BPS,
    genre_id: ID,
    secondary_genres: VecSet<String>,
    artists: VecMap<ContributorID, RecordingArtistRole>,
    contributors: VecMap<ContributorID, VecSet<RecordingContributorRole>>,
    mixes: vector<Mix>,
    artifacts: vector<Artifact<RecordingArtifactVariant>>,
    snapshots: vector<Snapshot>,
    metadata_cap: MetadataCap<RecordingShare>,
}

// (derivation_idx)
public struct RecordingKey(u32) has copy, drop, store;

public struct RecordingAdminCap has key, store {
    id: UID,
    recording_id: ID,
}

public struct RecordingVerificationCap has key, store {
    id: UID,
}

public struct RecordingAdminCapKey() has copy, drop, store;

//=== Events ===

public struct RecordingCreatedEvent has copy, drop {
    composition_id: ID,
    recording_id: ID,
    timestamp: u64,
}

public struct RecordingDestroyedEvent has copy, drop {
    composition_id: ID,
    recording_id: ID,
}

public struct RecordingContributorAddedEvent has copy, drop {
    recording_id: ID,
    contributor_id: ContributorID,
}

public struct RecordingContributorRemovedEvent has copy, drop {
    recording_id: ID,
    contributor_id: ContributorID,
}

public struct RecordingMixAddedEvent has copy, drop {
    recording_id: ID,
}

public struct RecordingMixRemovedEvent has copy, drop {
    recording_id: ID,
    mix_idx: u64,
}

public struct RecordingMixSwappedEvent has copy, drop {
    recording_id: ID,
    mix_a_idx: u64,
    mix_b_idx: u64,
}

public struct RecordingVerificationRequestedEvent has copy, drop {
    recording_id: ID,
    timestamp: u64,
}

public struct RecordingPublishedEvent has copy, drop {
    recording_id: ID,
    timestamp: u64,
}

public struct RecordingVerifiedEvent has copy, drop {
    recording_id: ID,
    timestamp: u64,
}

//=== Enums ===

public enum RecordingArtistRole has copy, drop, store {
    Primary,
    Featured,
}

public enum RecordingState has copy, drop, store {
    Created,
    Verifying(u64),
    Verified(u64),
    Published(u64),
}

//=== Constants ===

const MAX_MIXES: u64 = 5;
const MAX_ARTIFACTS: u64 = 30;
const MAX_CONTRIBUTORS: u64 = 200;
const MAX_ROLES_PER_CONTRIBUTOR: u64 = 10;
const MAX_SNAPSHOTS: u64 = 50;
const MAX_SECONDARY_GENRES: u64 = 5;

//=== Errors ===

const EInvalidRecordingAdminCap: u64 = 0;
const ENotSequentialDerivationIndex: u64 = 1;
const EMaxMixesExceeded: u64 = 2;
const EMaxArtifactsExceeded: u64 = 3;
const EMaxSnapshotsExceeded: u64 = 4;
const EInvalidDecimals: u64 = 5;
const EInvalidSymbol: u64 = 6;
const EExceedsMaxSupply: u64 = 7;
const EAlreadyPublished: u64 = 8;
const ENotVerifiedState: u64 = 9;
const ENotCreatedState: u64 = 10;
const ENotVerifyingState: u64 = 11;

//=== Public Functions ===

public fun new<RecordingShare, CompositionShare>(
    composition: &mut Composition<CompositionShare>,
    mix: Mix,
    derivation_idx: u32,
    genre: &Genre,
    currency: &mut Currency<RecordingShare>,
    metadata_cap: MetadataCap<RecordingShare>,
    treasury_cap: TreasuryCap<RecordingShare>,
    clock: &Clock,
): (Recording<RecordingShare>, RecordingAdminCap, Balance<RecordingShare>) {
    // If the derivation index is not 0, assert the UID associated with the previous
    // derivation index has been claimed and exists. This ensures UIDs generated for
    // Recordings are sequential in nature.
    if (derivation_idx > 0) {
        assert!(
            exists(composition.uid(), RecordingKey(derivation_idx - 1)),
            ENotSequentialDerivationIndex,
        );
    };

    let composition_id = composition.id();

    let mut recording = Recording<RecordingShare> {
        id: claim(composition.uid_mut(), RecordingKey(derivation_idx)),
        state: RecordingState::Created,
        composition_id,
        composition_commission_rate: composition.commission_rate(),
        genre_id: genre.id(),
        secondary_genres: vec_set::empty(),
        artists: vec_map::empty(),
        contributors: vec_map::empty(),
        mixes: vector::singleton(mix),
        artifacts: vector[],
        snapshots: vector[],
        metadata_cap,
    };

    let recording_id = recording.id.to_inner();

    let recording_admin_cap = RecordingAdminCap {
        id: claim(&mut recording.id, RecordingAdminCapKey()),
        recording_id,
    };

    let mut description = b"MusicOS Recording Shares for ".to_string();
    description.append(recording_id.to_address().to_string());
    description.append(b".".to_string());

    let balance = share::new<RecordingShare>(
        b"MusicOS Recording Share".to_string(),
        description,
        share_icon_url!(),
        currency,
        &recording.metadata_cap,
        treasury_cap,
    );

    emit(RecordingCreatedEvent {
        composition_id,
        recording_id,
        timestamp: clock.timestamp_ms(),
    });

    (recording, recording_admin_cap, balance)
}

public fun request_verification<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap,
    clock: &Clock,
) {
    self.authorize(cap);

    match (self.state) {
        RecordingState::Created => {
            let timestamp = clock.timestamp_ms();
            self.state = RecordingState::Verifying(timestamp);

            emit(RecordingVerificationRequestedEvent {
                recording_id: self.id(),
                timestamp,
            });
        },
        _ => abort ENotCreatedState,
    }
}

public fun verify<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    _: &RecordingVerificationCap,
    clock: &Clock,
) {
    match (self.state) {
        RecordingState::Verifying(..) => {
            self.state = RecordingState::Verified(clock.timestamp_ms());

            emit(RecordingVerifiedEvent {
                recording_id: self.id(),
                timestamp: clock.timestamp_ms(),
            });
        },
        _ => abort ENotVerifyingState,
    }
}

public fun publish<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap,
    clock: &Clock,
) {
    self.authorize(cap);

    match (self.state) {
        RecordingState::Verified(..) => {
            self.state = RecordingState::Published(clock.timestamp_ms());

            emit(RecordingPublishedEvent {
                recording_id: self.id(),
                timestamp: clock.timestamp_ms(),
            });
        },
        _ => abort ENotVerifiedState,
    }
}

// TODO: Think about what states to allow destruction.
public fun destroy<RecordingShare>(
    self: Recording<RecordingShare>,
    cap: RecordingAdminCap,
): MetadataCap<RecordingShare> {
    let Recording { id, metadata_cap, .. } = self;
    id.delete();
    let RecordingAdminCap { id, .. } = cap;
    id.delete();
    metadata_cap
}

// Add a `Mix` to a `Recording`.
// Requires the `Recording` to be in the `Created` state.
public fun add_mix<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap,
    mix: Mix,
) {
    self.authorize(cap);

    match (self.state) {
        RecordingState::Created => {
            assert!(self.mixes.length() < MAX_MIXES, EMaxMixesExceeded);
            self.mixes.push_back(mix);

            emit(RecordingMixAddedEvent {
                recording_id: self.id(),
            });
        },
        _ => abort ENotCreatedState,
    }
}

public fun remove_mix<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap,
    mix_idx: u64,
): Mix {
    match (self.state) {
        RecordingState::Created => {
            self.authorize(cap);

            emit(RecordingMixRemovedEvent {
                recording_id: self.id(),
                mix_idx,
            });

            self.mixes.remove(mix_idx)
        },
        _ => abort ENotCreatedState,
    }
}

public fun swap_mix<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap,
    mix_a_idx: u64,
    mix_b_idx: u64,
) {
    match (self.state) {
        RecordingState::Created => {
            self.authorize(cap);
            self.mixes.swap(mix_a_idx, mix_b_idx);

            emit(RecordingMixSwappedEvent {
                recording_id: self.id(),
                mix_a_idx,
                mix_b_idx,
            });
        },
        _ => abort ENotCreatedState,
    }
}

public fun add_contributor<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap,
    contributor_id: ContributorID,
) {
    match (self.state) {
        RecordingState::Created => {
            self.authorize(cap);
            self.contributors.insert(contributor_id, vec_set::empty());

            emit(RecordingContributorAddedEvent {
                recording_id: self.id(),
                contributor_id,
            });
        },
        _ => abort ENotCreatedState,
    }
}

public fun remove_contributor<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap,
    contributor_id: ContributorID,
): (ContributorID, VecSet<RecordingContributorRole>) {
    match (self.state) {
        RecordingState::Created => {
            self.authorize(cap);

            emit(RecordingContributorRemovedEvent {
                recording_id: self.id(),
                contributor_id,
            });

            self.contributors.remove(&contributor_id)
        },
        _ => abort ENotCreatedState,
    }
}

public fun add_contributor_role<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap,
    contributor_id: ContributorID,
    role: RecordingContributorRole,
) {
    self.authorize(cap);
    self.contributors.get_mut(&contributor_id).insert(role);
}

public fun remove_contributor_role<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap,
    contributor_id: ContributorID,
    role: RecordingContributorRole,
) {
    self.authorize(cap);
    self.contributors.get_mut(&contributor_id).remove(&role);
}

public fun add_artifact<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap,
    artifact: Artifact<RecordingArtifactVariant>,
) {
    self.authorize(cap);
    assert!(self.artifacts.length() < MAX_ARTIFACTS, EMaxArtifactsExceeded);
    self.artifacts.push_back(artifact);
}

public fun remove_artifact<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap,
    artifact_idx: u64,
): Artifact<RecordingArtifactVariant> {
    self.authorize(cap);
    self.artifacts.remove(artifact_idx)
}

public fun add_snapshot<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap,
    snapshot: Snapshot,
) {
    self.authorize(cap);
    assert!(self.snapshots.length() < MAX_SNAPSHOTS, EMaxSnapshotsExceeded);
    self.snapshots.push_back(snapshot);
}

public fun remove_snapshot<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap,
    snapshot_idx: u64,
): Snapshot {
    self.authorize(cap);
    self.snapshots.remove(snapshot_idx)
}

//=== Public View Functions ===

public fun id<RecordingShare>(self: &Recording<RecordingShare>): ID {
    self.id.to_inner()
}

public fun composition_id<RecordingShare>(self: &Recording<RecordingShare>): ID {
    self.composition_id
}

public fun composition_commission_rate<RecordingShare>(self: &Recording<RecordingShare>): BPS {
    self.composition_commission_rate
}

public fun genre_id<RecordingShare>(self: &Recording<RecordingShare>): ID {
    self.genre_id
}

public fun mixes<RecordingShare>(self: &Recording<RecordingShare>): &vector<Mix> {
    &self.mixes
}

public fun is_created_state<RecordingShare>(self: &Recording<RecordingShare>): bool {
    match (self.state) {
        RecordingState::Created => true,
        _ => false,
    }
}

public fun is_published_state<RecordingShare>(self: &Recording<RecordingShare>): bool {
    match (self.state) {
        RecordingState::Published(_) => true,
        _ => false,
    }
}

public fun authorize<RecordingShare>(self: &Recording<RecordingShare>, cap: &RecordingAdminCap) {
    assert!(self.id() == cap.recording_id, EInvalidRecordingAdminCap);
}

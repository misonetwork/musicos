// Copyright (c) Sona Labs, Pte Ltd.
// SPDX-License-Identifier: Apache-2.0

module musicos::recording;

use interest_bps::bps::BPS;
use musicos::audio::Audio;
use musicos::composition::Composition;
use musicos::contributor::Contributor;
use musicos::genre::Genre;
use musicos::recording_contributor_role::RecordingContributorRole;
use musicos::share::{Self, share_icon_url};
use musicos::stem::Stem;
use sui::balance::Balance;
use sui::clock::Clock;
use sui::coin::TreasuryCap;
use sui::coin_registry::{Currency, MetadataCap};
use sui::derived_object::claim;
use sui::event::emit;
use sui::vec_map::{Self, VecMap};
use sui::vec_set::{Self, VecSet};

//=== Structs ===

public struct Recording<phantom RecordingShare> has key {
    id: UID,
    state: RecordingState,
    composition_id: ID,
    composition_commission_rate: BPS,
    genre_id: ID,
    secondary_genre_ids: VecSet<ID>,
    contributors: VecMap<ID, vector<RecordingContributorRole>>,
    master: Audio,
    stems: vector<Stem>,
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
    contributor_id: ID,
}

public struct RecordingContributorRemovedEvent has copy, drop {
    recording_id: ID,
    contributor_id: ID,
}

public struct RecordingPrimaryGenreSetEvent has copy, drop {
    recording_id: ID,
    genre_id: ID,
}

public struct RecordingSecondaryGenreAddedEvent has copy, drop {
    recording_id: ID,
    genre_id: ID,
}

public struct RecordingSecondaryGenreRemovedEvent has copy, drop {
    recording_id: ID,
    genre_id: ID,
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

public struct RecordingContributorRoleAddedEvent has copy, drop {
    recording_id: ID,
    contributor_id: ID,
    contributor_role: RecordingContributorRole,
}

public struct RecordingContributorRoleRemovedEvent has copy, drop {
    recording_id: ID,
    contributor_id: ID,
    contributor_role: RecordingContributorRole,
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
const ENotOriginalMixVariant: u64 = 12;
const EInvalidMixVariant: u64 = 13;
const EInvalidStemDuration: u64 = 14;
const EAlreadySecondaryGenre: u64 = 15;
const EAlreadyPrimaryGenre: u64 = 16;
const EDuplicateContributorRole: u64 = 17;

//=== Public Functions ===

public fun new<RecordingShare, CompositionShare>(
    composition: &mut Composition<CompositionShare>,
    master: Audio,
    genre: &Genre, // Primary genre.
    currency: &mut Currency<RecordingShare>,
    metadata_cap: MetadataCap<RecordingShare>,
    treasury_cap: TreasuryCap<RecordingShare>,
    clock: &Clock,
): (Recording<RecordingShare>, RecordingAdminCap, Balance<RecordingShare>) {
    let composition_id = composition.id();

    let mut recording = Recording<RecordingShare> {
        // Derive a Recording ID from the Composition ID and the master's digest.
        id: claim(composition.uid_mut(), master.stream().digest()),
        state: RecordingState::Created,
        composition_id,
        composition_commission_rate: composition.commission_rate(),
        genre_id: genre.id(),
        secondary_genre_ids: vec_set::empty(),
        contributors: vec_map::empty(),
        master,
        stems: vector[],
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

    let balance = share::intialize<RecordingShare>(
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

public fun add_stem<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap,
    stem: Stem,
) {
    self.authorize(cap);

    match (self.state) {
        RecordingState::Created => {
            assert!(
                stem.audio().stream().duration() == self.master.stream().duration(),
                EInvalidStemDuration,
            );
            self.stems.push_back(stem);
        },
        _ => abort ENotCreatedState,
    }
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

public fun set_genre<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap,
    genre: &Genre,
) {
    self.authorize(cap);

    match (self.state) {
        RecordingState::Created => {
            let genre_id = genre.id();
            assert!(!self.secondary_genre_ids.contains(&genre_id), EAlreadySecondaryGenre);

            self.genre_id = genre_id;

            emit(RecordingPrimaryGenreSetEvent {
                recording_id: self.id(),
                genre_id,
            });
        },
        _ => abort ENotCreatedState,
    }
}

public fun add_secondary_genre<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap,
    genre: &Genre,
) {
    self.authorize(cap);

    match (self.state) {
        RecordingState::Created => {
            let genre_id = genre.id();
            // Assert the provided Genre is not the primary Genre.
            assert!(genre_id != self.genre_id, EAlreadyPrimaryGenre);
            // Assert the provided Genre is not already a secondary Genre.
            assert!(!self.secondary_genre_ids.contains(&genre_id), EAlreadySecondaryGenre);

            self.genre_id = genre_id;

            emit(RecordingSecondaryGenreAddedEvent {
                recording_id: self.id(),
                genre_id,
            })
        },
        _ => abort ENotCreatedState,
    }
}

public fun remove_secondary_genre<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap,
    genre_id: ID,
) {
    self.authorize(cap);

    match (self.state) {
        RecordingState::Created => {
            self.secondary_genre_ids.remove(&genre_id);

            emit(RecordingSecondaryGenreRemovedEvent {
                recording_id: self.id(),
                genre_id,
            });
        },
        _ => abort ENotCreatedState,
    }
}

// TODO: FIX!
public fun add_contributor<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap,
    contributor: &Contributor,
) {
    match (self.state) {
        RecordingState::Created => {
            self.authorize(cap);
            //self.contributors.insert(contributor_id, vector[]);

            emit(RecordingContributorAddedEvent {
                recording_id: self.id(),
                contributor_id: contributor.id(),
            });
        },
        _ => abort ENotCreatedState,
    }
}

public fun remove_contributor<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap,
    contributor_id: ID,
) {
    match (self.state) {
        RecordingState::Created => {
            self.authorize(cap);

            emit(RecordingContributorRemovedEvent {
                recording_id: self.id(),
                contributor_id,
            });

            self.contributors.remove(&contributor_id);
        },
        _ => abort ENotCreatedState,
    }
}

public fun add_contributor_role<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap,
    contributor_id: ID,
    role: RecordingContributorRole,
) {
    self.authorize(cap);

    match (self.state) {
        RecordingState::Created => {
            let roles = self.contributors.get_mut(&contributor_id);
            assert!(!roles.contains(&role), EDuplicateContributorRole);

            roles.push_back(role);

            emit(RecordingContributorRoleAddedEvent {
                recording_id: self.id(),
                contributor_id,
                contributor_role: role,
            });
        },
        _ => abort ENotCreatedState,
    }
}

public fun remove_contributor_role<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap,
    contributor_id: ID,
    role_idx: u64,
) {
    self.authorize(cap);

    match (self.state) {
        RecordingState::Created => {
            let role = self.contributors.get_mut(&contributor_id).remove(role_idx);

            emit(RecordingContributorRoleRemovedEvent {
                recording_id: self.id(),
                contributor_id,
                contributor_role: role,
            });
        },
        _ => abort ENotCreatedState,
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

public fun master<RecordingShare>(self: &Recording<RecordingShare>): &Audio {
    &self.master
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

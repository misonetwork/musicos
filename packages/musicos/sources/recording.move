// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module musicos::recording;

use currency_treasury::burn_facility::BurnFacility;
use music::music::MUSIC;
use musicos::audio::Audio;
use musicos::bps::BPS;
use musicos::composition::Composition;
use musicos::contributor::Contributor;
use musicos::genre::Genre;
use musicos::key::{Self, RevenuePoolKey, RewardPoolKey};
use musicos::protocol::Protocol;
use musicos::recording_contributor_role::RecordingContributorRole;
use musicos::share;
use musicos::stem::Stem;
use revenue_pool::revenue_pool;
use reward_pool::reward_pool;
use std::string::String;
use std::type_name::{Self, TypeName};
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
    // System
    id: UID,
    state: RecordingState,
    title: String,
    title_version: Option<String>,
    composition_id: ID,
    composition_split: BPS,
    genre_id: ID,
    secondary_genre_ids: VecSet<ID>,
    language: Option<String>,
    is_explicit: bool,
    is_instrumental: bool,
    tempo_bpm: u16,
    share_metadata_cap: MetadataCap<RecordingShare>,
    artists: VecSet<ID>,
    featured_artists: VecSet<ID>,
    contributors: VecMap<ID, vector<RecordingContributorRole>>,
    master: Audio,
    stems: vector<Stem>,
}

public struct RecordingAdminCap has key, store {
    id: UID,
    recording_id: ID,
}

public struct ShareRecordingPromise(ID)

//=== Derivation Keys ===

public struct RecordingAdminCapKey() has copy, drop, store;
public struct RecordingKey(vector<u8>) has copy, drop, store;

//=== Events ===

public struct RecordingCreatedEvent has copy, drop {
    recording_id: ID,
    share_type: TypeName,
    composition_id: ID,
    genre_id: ID,
}

public struct RecordingPublishedEvent has copy, drop {
    recording_id: ID,
}

public struct RecordingStemAddedEvent has copy, drop {
    recording_id: ID,
    audio_digest: vector<u8>,
}

public struct RecordingContributorAddedEvent has copy, drop {
    recording_id: ID,
    contributor_id: ID,
}

public struct RecordingContributorRemovedEvent has copy, drop {
    recording_id: ID,
    contributor_id: ID,
}

public struct RecordingStemRemovedEvent has copy, drop {
    recording_id: ID,
    audio_digest: vector<u8>,
}

//=== Enums ===

public enum RecordingState has copy, drop, store {
    Created,
    // Timestamp of publication.
    Published(u64),
}

//=== Constants ===

const MIN_ROLES_PER_CONTRIBUTOR: u64 = 1;
const MAX_ROLES_PER_CONTRIBUTOR: u64 = 20;
const MAX_STEMS_PER_RECORDING: u8 = 10;

//=== Errors ===

const EUnauthorized: u64 = 0;
const ENotCreatedState: u64 = 1;
const EMaxStemsExceeded: u64 = 2;
const EInvalidRecordingForPromise: u64 = 3;
const ENoContributors: u64 = 4;
const EInvalidRecordingFee: u64 = 5;
const EMinRolesNotMet: u64 = 6;
const EExceedsMaxRoles: u64 = 7;

//=== Public Functions ===

public fun new<RecordingShare, CompositionShare>(
    composition: &mut Composition<CompositionShare>,
    genre: &Genre,
    master: Audio,
    tempo_bpm: u16,
    share_currency: &mut Currency<RecordingShare>,
    share_metadata_cap: MetadataCap<RecordingShare>,
    share_treasury_cap: TreasuryCap<RecordingShare>,
): (Recording<RecordingShare>, RecordingAdminCap, Balance<RecordingShare>, ShareRecordingPromise) {
    let composition_id = composition.id();
    let genre_id = genre.id();

    let mut recording = Recording<RecordingShare> {
        id: claim(composition.uid_mut(), RecordingKey(*master.digest())),
        state: RecordingState::Created,
        composition_id,
        composition_split: composition.split(),
        title: *composition.title(),
        title_version: option::none(),
        genre_id,
        secondary_genre_ids: vec_set::empty(),
        language: option::none(),
        is_explicit: false,
        is_instrumental: false,
        tempo_bpm,
        contributors: vec_map::empty(),
        artists: vec_set::empty(),
        featured_artists: vec_set::empty(),
        master,
        stems: vector[],
        share_metadata_cap,
    };

    let recording_admin_cap = RecordingAdminCap {
        id: claim(&mut recording.id, RecordingAdminCapKey()),
        recording_id: recording.id(),
    };

    let mut description = b"MusicOS Recording Shares for 0x".to_string();
    description.append(recording.id().to_address().to_string());
    description.append(b".".to_string());

    let recording_shares = share::intialize<RecordingShare>(
        b"MusicOS Recording Share".to_string(),
        description,
        share_currency,
        &recording.share_metadata_cap,
        share_treasury_cap,
    );

    let share_recording_promise = ShareRecordingPromise(recording.id());

    emit(RecordingCreatedEvent {
        recording_id: recording.id(),
        share_type: type_name::with_defining_ids<RecordingShare>(),
        composition_id,
        genre_id,
    });

    (recording, recording_admin_cap, recording_shares, share_recording_promise)
}

// Share a recording.
// Required State: Initialized
public fun share<RecordingShare>(
    self: Recording<RecordingShare>,
    share_recording_promise: ShareRecordingPromise,
) {
    match (self.state) {
        RecordingState::Created => {
            let ShareRecordingPromise(recording_id) = share_recording_promise;
            assert!(self.id() == recording_id, EInvalidRecordingForPromise);
            transfer::share_object(self);
        },
        _ => abort ENotCreatedState,
    }
}

// Publish a recording.
// Required State: Created
public fun publish<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap,
    clock: &Clock,
) {
    self.authorize(cap);

    match (self.state) {
        RecordingState::Created => {
            // Assert the recording has at least one contributor.
            assert!(!self.contributors.is_empty(), ENoContributors);

            self.state = RecordingState::Published(clock.timestamp_ms());

            emit(RecordingPublishedEvent {
                recording_id: self.id(),
            });
        },
        _ => abort ENotCreatedState,
    };
}

// Add a contributor to a recording.
public fun add_contributor<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap,
    contributor: &Contributor,
    roles: vector<RecordingContributorRole>,
) {
    self.authorize(cap);

    match (self.state) {
        RecordingState::Created => {
            assert!(roles.length() >= MIN_ROLES_PER_CONTRIBUTOR, EMinRolesNotMet);
            assert!(roles.length() <= MAX_ROLES_PER_CONTRIBUTOR, EExceedsMaxRoles);

            self.contributors.insert(contributor.id(), roles);

            emit(RecordingContributorAddedEvent {
                recording_id: self.id(),
                contributor_id: contributor.id(),
            });
        },
        _ => abort ENotCreatedState,
    }
}

// Remove a contributor from a recording.
public fun remove_contributor<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap,
    contributor_id: ID,
) {
    self.authorize(cap);

    match (self.state) {
        RecordingState::Created => {
            self.contributors.remove(&contributor_id);

            emit(RecordingContributorRemovedEvent {
                recording_id: self.id(),
                contributor_id: contributor_id,
            });
        },
        _ => abort ENotCreatedState,
    }
}

// Adds a stem to a recording.
// Required State: Created
public fun add_stem<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap,
    stem: Stem,
) {
    self.authorize(cap);

    match (self.state) {
        RecordingState::Created => {
            assert!(self.stems.length() < MAX_STEMS_PER_RECORDING as u64, EMaxStemsExceeded);

            emit(RecordingStemAddedEvent {
                recording_id: self.id(),
                audio_digest: *stem.audio().digest(),
            });

            self.stems.push_back(stem);
        },
        _ => abort ENotCreatedState,
    }
}

// Removes a stem from a recording.
// Required State: Created
public fun remove_stem<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap,
    stem_idx: u64,
): Stem {
    self.authorize(cap);

    match (self.state) {
        RecordingState::Created => {
            let stem = self.stems.swap_remove(stem_idx);

            emit(RecordingStemRemovedEvent {
                recording_id: self.id(),
                audio_digest: *stem.audio().digest(),
            });

            stem
        },
        _ => abort ENotCreatedState,
    }
}

public fun new_revenue_pool<RecordingShare, Currency>(self: &mut Recording<RecordingShare>) {
    let revenue_pool = revenue_pool::new<Currency, RevenuePoolKey<Currency>>(
        &mut self.id,
        key::new_revenue_pool_key<Currency>(),
    );
    transfer::public_share_object(revenue_pool);
}

public fun new_reward_pool<RecordingShare, Currency>(self: &mut Recording<RecordingShare>) {
    let reward_pool = reward_pool::new<RecordingShare, Currency, RewardPoolKey<Currency>>(
        &mut self.id,
        key::new_reward_pool_key<Currency>(),
    );
    transfer::public_share_object(reward_pool);
}

//=== Public View Functions ===

public fun id<RecordingShare>(recording: &Recording<RecordingShare>): ID {
    recording.id.to_inner()
}

public fun composition_id<RecordingShare>(recording: &Recording<RecordingShare>): ID {
    recording.composition_id
}

public fun composition_split<RecordingShare>(recording: &Recording<RecordingShare>): BPS {
    recording.composition_split
}

public fun genre_id<RecordingShare>(recording: &Recording<RecordingShare>): ID {
    recording.genre_id
}

public fun master<RecordingShare>(recording: &Recording<RecordingShare>): &Audio {
    &recording.master
}

public fun stems<RecordingShare>(recording: &Recording<RecordingShare>): &vector<Stem> {
    &recording.stems
}

//=== Private Functions ===

public(package) fun authorize<RecordingShare>(
    self: &Recording<RecordingShare>,
    cap: &RecordingAdminCap,
) {
    assert!(self.id() == cap.recording_id, EUnauthorized);
}

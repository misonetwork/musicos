// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module musicos::recording;

use iso639_1::language_code::LanguageCode;
use musicos::artifact::Artifact;
use musicos::audio::Audio;
use musicos::bps::BPS;
use musicos::composition::Composition;
use musicos::contributor::Contributor;
use musicos::genre::Genre;
use musicos::musical_key::MusicalKey;
use musicos::recording_artifact_kind::RecordingArtifactKind;
use musicos::recording_contributor_role::RecordingContributorRole;
use musicos::share;
use musicos::snapshot::Snapshot;
use musicos::stem::Stem;
use musicos::time_signature::TimeSignature;
use revenue_pool::revenue_pool;
use reward_pool::reward_pool;
use std::string::String;
use std::type_name::{Self, TypeName, with_defining_ids};
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
    share_metadata_cap: MetadataCap<RecordingShare>,
    // Title
    title: String,
    title_version: Option<String>,
    // Composition
    composition_id: ID,
    composition_share_type: TypeName,
    composition_split: BPS,
    // People
    artists: VecSet<ID>,
    featured_artists: VecSet<ID>,
    contributors: VecMap<ID, vector<RecordingContributorRole>>,
    // Classification
    genre_id: ID,
    secondary_genre_ids: VecSet<ID>,
    language: Option<LanguageCode>,
    is_explicit: bool,
    is_instrumental: bool,
    // Musical Properties
    musical_key: Option<MusicalKey>,
    time_signature: Option<TimeSignature>,
    tempo_bpm: Option<u16>,
    // Audio
    master: Audio,
    stems: vector<Stem>,
    // Attachments
    artifacts: vector<Artifact<RecordingArtifactKind>>,
    snapshots: vector<Snapshot>,
}

public struct RecordingAdminCap has key, store {
    id: UID,
    recording_id: ID,
}

public struct ShareRecordingPromise(ID)

//=== Derivation Keys ===

public struct RecordingAdminCapKey() has copy, drop, store;
public struct RecordingKey(vector<u8>) has copy, drop, store;

//=== Fees ===

public struct PublishRecordingFee() has drop;

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

public struct RecordingContributorAddedEvent has copy, drop {
    recording_id: ID,
    contributor_id: ID,
}

public struct RecordingContributorRemovedEvent has copy, drop {
    recording_id: ID,
    contributor_id: ID,
}

public struct RecordingStemAddedEvent has copy, drop {
    recording_id: ID,
    audio_digest: vector<u8>,
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
const EMinRolesNotMet: u64 = 5;
const EExceedsMaxRoles: u64 = 6;

//=== Public Functions ===

// --- Lifecycle ---

public fun new<RecordingShare, CompositionShare>(
    composition: &mut Composition<CompositionShare>,
    genre: &Genre,
    master: Audio,
    is_explicit: bool,
    is_instrumental: bool,
    share_currency: &mut Currency<RecordingShare>,
    share_metadata_cap: MetadataCap<RecordingShare>,
    share_treasury_cap: TreasuryCap<RecordingShare>,
): (Recording<RecordingShare>, RecordingAdminCap, Balance<RecordingShare>, ShareRecordingPromise) {
    let composition_id = composition.id();
    let genre_id = genre.id();

    let mut recording = Recording<RecordingShare> {
        id: claim(composition.uid_mut(), RecordingKey(*master.digest())),
        state: RecordingState::Created,
        share_metadata_cap,
        title: *composition.title(),
        title_version: option::none(),
        composition_id,
        composition_share_type: with_defining_ids<CompositionShare>(),
        composition_split: composition.split(),
        artists: vec_set::empty(),
        featured_artists: vec_set::empty(),
        contributors: vec_map::empty(),
        genre_id,
        secondary_genre_ids: vec_set::empty(),
        language: option::none(),
        is_explicit,
        is_instrumental,
        musical_key: option::none(),
        time_signature: option::none(),
        tempo_bpm: option::none(),
        master,
        stems: vector[],
        artifacts: vector[],
        snapshots: vector[],
    };

    let recording_admin_cap = RecordingAdminCap {
        id: claim(&mut recording.id, RecordingAdminCapKey()),
        recording_id: recording.id(),
    };

    let mut description: String = "MusicOS Recording Shares for 0x";
    description.append(recording.id().to_address().to_string());
    description.append(".");

    let recording_shares = share::intialize<RecordingShare>(
        "MusicOS Recording Share",
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
// Required State: Created
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

// --- Title ---

// Set the title of a recording.
// Required State: Created
public fun set_title<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap,
    title: String,
) {
    self.authorize(cap);

    match (self.state) {
        RecordingState::Created => {
            self.title = title;
        },
        _ => abort ENotCreatedState,
    }
}

// Set the title version of a recording.
// Required State: Created
public fun set_title_version<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap,
    title_version: String,
) {
    self.authorize(cap);

    match (self.state) {
        RecordingState::Created => {
            self.title_version.swap_or_fill(title_version);
        },
        _ => abort ENotCreatedState,
    }
}

// --- People ---

// Add an artist to a recording.
// Required State: Created
public fun add_artist<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap,
    contributor: &Contributor,
) {
    self.authorize(cap);

    match (self.state) {
        RecordingState::Created => {
            self.artists.insert(contributor.id());
        },
        _ => abort ENotCreatedState,
    }
}

// Remove an artist from a recording.
// Required State: Created
public fun remove_artist<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap,
    contributor_id: ID,
) {
    self.authorize(cap);

    match (self.state) {
        RecordingState::Created => {
            self.artists.remove(&contributor_id);
        },
        _ => abort ENotCreatedState,
    }
}

// Add a featured artist to a recording.
// Required State: Created
public fun add_featured_artist<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap,
    contributor: &Contributor,
) {
    self.authorize(cap);

    match (self.state) {
        RecordingState::Created => {
            self.featured_artists.insert(contributor.id());
        },
        _ => abort ENotCreatedState,
    }
}

// Remove a featured artist from a recording.
// Required State: Created
public fun remove_featured_artist<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap,
    contributor_id: ID,
) {
    self.authorize(cap);

    match (self.state) {
        RecordingState::Created => {
            self.featured_artists.remove(&contributor_id);
        },
        _ => abort ENotCreatedState,
    }
}

// Add a contributor to a recording.
// Required State: Created
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
// Required State: Created
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

// --- Classification ---

// Set the genre of a recording.
// Required State: Created
public fun set_genre<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap,
    genre: &Genre,
) {
    self.authorize(cap);

    match (self.state) {
        RecordingState::Created => {
            self.genre_id = genre.id();
        },
        _ => abort ENotCreatedState,
    }
}

// Add a secondary genre to a recording.
// Required State: Created
public fun add_secondary_genre<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap,
    genre: &Genre,
) {
    self.authorize(cap);

    match (self.state) {
        RecordingState::Created => {
            self.secondary_genre_ids.insert(genre.id());
        },
        _ => abort ENotCreatedState,
    }
}

// Remove a secondary genre from a recording.
// Required State: Created
public fun remove_secondary_genre<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap,
    genre_id: ID,
) {
    self.authorize(cap);

    match (self.state) {
        RecordingState::Created => {
            self.secondary_genre_ids.remove(&genre_id);
        },
        _ => abort ENotCreatedState,
    }
}

// Set the language of a recording.
// Required State: Created
public fun set_language<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap,
    language: LanguageCode,
) {
    self.authorize(cap);

    match (self.state) {
        RecordingState::Created => {
            self.language.swap_or_fill(language);
        },
        _ => abort ENotCreatedState,
    }
}

// Set the explicit flag of a recording.
// Required State: Created
public fun set_is_explicit<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap,
    is_explicit: bool,
) {
    self.authorize(cap);

    match (self.state) {
        RecordingState::Created => {
            self.is_explicit = is_explicit;
        },
        _ => abort ENotCreatedState,
    }
}

// Set the instrumental flag of a recording.
// Required State: Created
public fun set_is_instrumental<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap,
    is_instrumental: bool,
) {
    self.authorize(cap);

    match (self.state) {
        RecordingState::Created => {
            self.is_instrumental = is_instrumental;
        },
        _ => abort ENotCreatedState,
    }
}

// --- Musical Properties ---

// Set the musical key of a recording.
// Required State: Created
public fun set_musical_key<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap,
    musical_key: MusicalKey,
) {
    self.authorize(cap);

    match (self.state) {
        RecordingState::Created => {
            self.musical_key.swap_or_fill(musical_key);
        },
        _ => abort ENotCreatedState,
    }
}

// Set the time signature of a recording.
// Required State: Created
public fun set_time_signature<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap,
    time_signature: TimeSignature,
) {
    self.authorize(cap);

    match (self.state) {
        RecordingState::Created => {
            self.time_signature.swap_or_fill(time_signature);
        },
        _ => abort ENotCreatedState,
    }
}

// Set the tempo BPM of a recording.
// Required State: Created
public fun set_tempo_bpm<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap,
    tempo_bpm: u16,
) {
    self.authorize(cap);

    match (self.state) {
        RecordingState::Created => {
            self.tempo_bpm.swap_or_fill(tempo_bpm);
        },
        _ => abort ENotCreatedState,
    }
}

// --- Audio ---

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

// --- Attachments ---

// Add an artifact to a recording.
// Required State: Created
public fun add_artifact<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap,
    artifact: Artifact<RecordingArtifactKind>,
) {
    self.authorize(cap);

    match (self.state) {
        RecordingState::Created => {
            self.artifacts.push_back(artifact);
        },
        _ => abort ENotCreatedState,
    }
}

// Remove an artifact from a recording.
// Required State: Created
public fun remove_artifact<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap,
    artifact_idx: u64,
): Artifact<RecordingArtifactKind> {
    self.authorize(cap);

    match (self.state) {
        RecordingState::Created => {
            self.artifacts.swap_remove(artifact_idx)
        },
        _ => abort ENotCreatedState,
    }
}

// Add a snapshot to a recording.
// Required State: Created
public fun add_snapshot<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap,
    snapshot: Snapshot,
) {
    self.authorize(cap);

    match (self.state) {
        RecordingState::Created => {
            self.snapshots.push_back(snapshot);
        },
        _ => abort ENotCreatedState,
    }
}

// Remove a snapshot from a recording.
// Required State: Created
public fun remove_snapshot<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap,
    snapshot_idx: u64,
): Snapshot {
    self.authorize(cap);

    match (self.state) {
        RecordingState::Created => {
            self.snapshots.swap_remove(snapshot_idx)
        },
        _ => abort ENotCreatedState,
    }
}

// --- Pools ---

public fun new_revenue_pool<RecordingShare, Currency>(self: &mut Recording<RecordingShare>) {
    let revenue_pool = revenue_pool::new<Currency>(&mut self.id);
    transfer::public_share_object(revenue_pool);
}

public fun new_reward_pool<RecordingShare, Currency>(self: &mut Recording<RecordingShare>) {
    let reward_pool = reward_pool::new<RecordingShare, Currency>(&mut self.id);
    transfer::public_share_object(reward_pool);
}

//=== Public View Functions ===

public fun id<RecordingShare>(self: &Recording<RecordingShare>): ID {
    self.id.to_inner()
}

public fun state<RecordingShare>(self: &Recording<RecordingShare>): RecordingState {
    self.state
}

public fun title<RecordingShare>(self: &Recording<RecordingShare>): &String {
    &self.title
}

public fun title_version<RecordingShare>(self: &Recording<RecordingShare>): &Option<String> {
    &self.title_version
}

public fun composition_id<RecordingShare>(self: &Recording<RecordingShare>): ID {
    self.composition_id
}

public fun composition_share_type<RecordingShare>(self: &Recording<RecordingShare>): &TypeName {
    &self.composition_share_type
}

public fun composition_split<RecordingShare>(self: &Recording<RecordingShare>): &BPS {
    &self.composition_split
}

public fun artists<RecordingShare>(self: &Recording<RecordingShare>): &VecSet<ID> {
    &self.artists
}

public fun featured_artists<RecordingShare>(self: &Recording<RecordingShare>): &VecSet<ID> {
    &self.featured_artists
}

public fun contributors<RecordingShare>(self: &Recording<RecordingShare>): &VecMap<ID, vector<RecordingContributorRole>> {
    &self.contributors
}

public fun genre_id<RecordingShare>(self: &Recording<RecordingShare>): ID {
    self.genre_id
}

public fun secondary_genre_ids<RecordingShare>(self: &Recording<RecordingShare>): &VecSet<ID> {
    &self.secondary_genre_ids
}

public fun language<RecordingShare>(self: &Recording<RecordingShare>): &Option<LanguageCode> {
    &self.language
}

public fun is_explicit<RecordingShare>(self: &Recording<RecordingShare>): bool {
    self.is_explicit
}

public fun is_instrumental<RecordingShare>(self: &Recording<RecordingShare>): bool {
    self.is_instrumental
}

public fun musical_key<RecordingShare>(self: &Recording<RecordingShare>): &Option<MusicalKey> {
    &self.musical_key
}

public fun time_signature<RecordingShare>(self: &Recording<RecordingShare>): &Option<TimeSignature> {
    &self.time_signature
}

public fun tempo_bpm<RecordingShare>(self: &Recording<RecordingShare>): &Option<u16> {
    &self.tempo_bpm
}

public fun master<RecordingShare>(self: &Recording<RecordingShare>): &Audio {
    &self.master
}

public fun stems<RecordingShare>(self: &Recording<RecordingShare>): &vector<Stem> {
    &self.stems
}

public fun artifacts<RecordingShare>(self: &Recording<RecordingShare>): &vector<Artifact<RecordingArtifactKind>> {
    &self.artifacts
}

public fun snapshots<RecordingShare>(self: &Recording<RecordingShare>): &vector<Snapshot> {
    &self.snapshots
}

//=== Package Functions ===

public(package) fun authorize<RecordingShare>(
    self: &Recording<RecordingShare>,
    cap: &RecordingAdminCap,
) {
    assert!(self.id() == cap.recording_id, EUnauthorized);
}

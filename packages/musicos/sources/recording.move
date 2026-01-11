// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Represents an audio recording of a composition in the MusicOS protocol.
/// Recordings are the audio performances that are distributed and played.
/// Each recording has its own share token for ownership distribution.
///
/// Key features:
/// - Share token initialization with fixed supply (100M tokens, 6 decimals)
/// - Contributor management with role assignments (Producer, Vocalist, etc.)
/// - State machine: Created -> Published (immutable after publish)
/// - Audio management (master track and optional stems)
/// - Musical metadata (key, tempo, time signature)
/// - Deterministic addresses via derived object pattern
module musicos::recording;

use iso639_1::language_code::LanguageCode;
use musicos::artifact::Artifact;
use musicos::audio::Audio;
use musicos::bps::BPS;
use musicos::composition::Composition;
use musicos::contributor::Contributor;
use musicos::cover_art::CoverArt;
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

/// An audio recording of a composition.
/// The phantom RecordingShare type parameter links to the share token.
public struct Recording<phantom RecordingShare> has key {
    /// Unique identifier for this recording.
    id: UID,
    /// Current lifecycle state.
    state: RecordingState,
    /// Capability for updating share token metadata.
    share_metadata_cap: MetadataCap<RecordingShare>,
    /// Primary title of the recording.
    title: String,
    /// Version suffix (e.g., "Radio Edit", "Extended Mix").
    title_version: Option<String>,
    /// Subtitle of the recording.
    subtitle: Option<String>,
    /// ID of the underlying composition.
    composition_id: ID,
    /// Type of the composition's share token.
    composition_share_type: TypeName,
    /// Revenue split for the composition (captured at creation time).
    composition_split: BPS,
    /// Primary artists credited on the recording.
    artists: VecSet<ID>,
    /// Featured artists credited on the recording.
    featured_artists: VecSet<ID>,
    /// Map of contributor IDs to their roles on this recording.
    contributors: VecMap<ID, vector<RecordingContributorRole>>,
    /// Primary genre of the recording.
    genre_id: ID,
    /// Additional genres for the recording.
    secondary_genre_ids: VecSet<ID>,
    /// Language of the vocals (if any).
    language: Option<LanguageCode>,
    /// Whether the recording contains explicit content.
    is_explicit: bool,
    /// Whether the recording is instrumental (no vocals).
    is_instrumental: bool,
    /// Musical key of the recording.
    musical_key: Option<MusicalKey>,
    /// Time signature of the recording.
    time_signature: Option<TimeSignature>,
    /// Tempo in beats per minute.
    tempo_bpm: Option<u16>,
    /// The final mixed/mastered audio file.
    master: Audio,
    /// Cover art for the recording.
    cover_art: CoverArt,
    /// Individual audio stems (vocals, drums, etc.).
    stems: vector<Stem>,
    /// Attached artifacts (lyrics, liner notes, etc.).
    artifacts: vector<Artifact<RecordingArtifactKind>>,
    /// Point-in-time content snapshots.
    snapshots: vector<Snapshot>,
}

/// Capability that authorizes modifications to a specific recording.
/// Created when a recording is registered and transferred to the owner.
public struct RecordingAdminCap has key, store {
    /// Unique identifier for this capability.
    id: UID,
    /// ID of the recording this capability controls.
    recording_id: ID,
}

/// Promise that ensures a recording is shared after creation.
/// Must be consumed by calling `share()`.
public struct ShareRecordingPromise(
    /// ID of the recording to be shared.
    ID,
)

//=== Derivation Keys ===

/// Key for deriving the admin capability's deterministic address.
public struct RecordingAdminCapKey() has copy, drop, store;

/// Key for deriving the recording's address from the composition.
public struct RecordingKey(
    /// Digest of the master audio file.
    vector<u8>,
) has copy, drop, store;

//=== Fees ===

/// Marker type for publish recording fee payments.
public struct PublishRecordingFee() has drop;

//=== Events ===

/// Emitted when a new recording is created.
public struct RecordingCreatedEvent has copy, drop {
    /// ID of the created recording.
    recording_id: ID,
    /// Type of the recording's share token.
    share_type: TypeName,
    /// ID of the underlying composition.
    composition_id: ID,
    /// ID of the recording's genre.
    genre_id: ID,
}

/// Emitted when a recording is published.
public struct RecordingPublishedEvent has copy, drop {
    /// ID of the published recording.
    recording_id: ID,
}

/// Emitted when a contributor is added to a recording.
public struct RecordingContributorAddedEvent has copy, drop {
    /// ID of the recording.
    recording_id: ID,
    /// ID of the added contributor.
    contributor_id: ID,
}

/// Emitted when a contributor is removed from a recording.
public struct RecordingContributorRemovedEvent has copy, drop {
    /// ID of the recording.
    recording_id: ID,
    /// ID of the removed contributor.
    contributor_id: ID,
}

/// Emitted when a stem is added to a recording.
public struct RecordingStemAddedEvent has copy, drop {
    /// ID of the recording.
    recording_id: ID,
    /// Digest of the added audio file.
    audio_digest: vector<u8>,
}

/// Emitted when a stem is removed from a recording.
public struct RecordingStemRemovedEvent has copy, drop {
    /// ID of the recording.
    recording_id: ID,
    /// Digest of the removed audio file.
    audio_digest: vector<u8>,
}

//=== Enums ===

/// Lifecycle state of a recording.
public enum RecordingState has copy, drop, store {
    /// Recording is being set up and can be modified.
    Created,
    /// Recording is published and immutable. Includes publication timestamp.
    Published(
        /// Timestamp (ms) when published.
        u64,
    ),
}

//=== Constants ===

/// Minimum number of roles a contributor must have.
const MIN_ROLES_PER_CONTRIBUTOR: u64 = 1;
/// Maximum number of roles a contributor can have.
const MAX_ROLES_PER_CONTRIBUTOR: u64 = 20;
/// Maximum number of stems allowed per recording.
const MAX_STEMS_PER_RECORDING: u8 = 10;

//=== Errors ===

/// The provided admin capability does not match this recording.
const EUnauthorized: u64 = 0;
/// Operation requires Created state but recording is published.
const ENotCreatedState: u64 = 1;
/// Recording has reached the maximum number of stems (10).
const EMaxStemsExceeded: u64 = 2;
/// Promise does not match this recording's ID.
const EInvalidRecordingForPromise: u64 = 3;
/// Recording must have at least one contributor to publish.
const ENoContributors: u64 = 4;
/// Contributor must have at least one role.
const EMinRolesNotMet: u64 = 5;
/// Contributor has too many roles.
const EExceedsMaxRoles: u64 = 6;

//=== Public Functions ===

// --- Lifecycle ---

/// Creates a new recording for a composition.
/// Initializes share tokens (100M supply, 6 decimals) and returns:
/// - The recording object
/// - Admin capability for the owner
/// - Initial share token balance
/// - Promise that must be consumed by calling `share()`
public fun new<RecordingShare, CompositionShare>(
    composition: &mut Composition<CompositionShare>,
    genre: &Genre,
    is_explicit: bool,
    is_instrumental: bool,
    master: Audio,
    cover_art: CoverArt,
    share_currency: &mut Currency<RecordingShare>,
    share_metadata_cap: MetadataCap<RecordingShare>,
    share_treasury_cap: TreasuryCap<RecordingShare>,
): (Recording<RecordingShare>, RecordingAdminCap, Balance<RecordingShare>, ShareRecordingPromise) {
    let composition_id = composition.id();
    let genre_id = genre.id();

    let mut recording = Recording<RecordingShare> {
        id: claim(composition.uid_mut(), RecordingKey(*master.pcm_digest())),
        state: RecordingState::Created,
        share_metadata_cap,
        title: *composition.title(),
        title_version: option::none(),
        subtitle: option::none(),
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
        cover_art,
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

/// Converts the recording into a shared object.
/// Consumes the promise returned by `new()`.
/// Required State: Created
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

/// Publishes the recording, making it immutable.
/// Requires at least one contributor to be assigned.
/// Required State: Created
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

/// Sets the primary title of the recording.
/// Required State: Created
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

/// Sets the title version (e.g., "Radio Edit", "Extended Mix").
/// Required State: Created
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

/// Sets the subtitle of the recording.
/// Required State: Created
public fun set_subtitle<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap,
    subtitle: String,
) {
    self.authorize(cap);

    match (self.state) {
        RecordingState::Created => {
            self.subtitle.swap_or_fill(subtitle);
        },
        _ => abort ENotCreatedState,
    }
}

// --- People ---

/// Adds a primary artist to the recording.
/// Required State: Created
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

/// Removes a primary artist from the recording.
/// Required State: Created
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

/// Adds a featured artist to the recording.
/// Required State: Created
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

/// Removes a featured artist from the recording.
/// Required State: Created
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

/// Adds a contributor to the recording with specified roles.
/// Each contributor must have 1-20 roles.
/// Required State: Created
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

/// Removes a contributor from the recording.
/// Required State: Created
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

/// Sets the primary genre of the recording.
/// Required State: Created
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

/// Adds a secondary genre to the recording.
/// Required State: Created
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

/// Removes a secondary genre from the recording.
/// Required State: Created
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

/// Sets the language of the recording's vocals.
/// Required State: Created
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

/// Sets whether the recording contains explicit content.
/// Required State: Created
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

/// Sets whether the recording is instrumental (no vocals).
/// Required State: Created
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

/// Sets the musical key of the recording.
/// Required State: Created
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

/// Sets the time signature of the recording.
/// Required State: Created
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

/// Sets the tempo in beats per minute.
/// Required State: Created
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

/// Adds a stem (isolated audio track) to the recording.
/// Maximum of 10 stems per recording.
/// Required State: Created
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
                audio_digest: *stem.audio().pcm_digest(),
            });

            self.stems.push_back(stem);
        },
        _ => abort ENotCreatedState,
    }
}

/// Removes a stem by index and returns it.
/// Required State: Created
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
                audio_digest: *stem.audio().pcm_digest(),
            });

            stem
        },
        _ => abort ENotCreatedState,
    }
}

// --- Attachments ---

/// Adds an artifact to the recording.
/// Required State: Created
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

/// Removes an artifact by index and returns it.
/// Required State: Created
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

/// Adds a snapshot to the recording.
/// Required State: Created
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

/// Removes a snapshot by index and returns it.
/// Required State: Created
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

/// Creates a new revenue pool for this recording.
/// Revenue pools receive incoming payments before distribution.
public fun new_revenue_pool<RecordingShare, Currency>(self: &mut Recording<RecordingShare>) {
    let revenue_pool = revenue_pool::new<Currency>(&mut self.id);
    transfer::public_share_object(revenue_pool);
}

/// Creates a new reward pool for this recording.
/// Reward pools distribute revenue to share token holders.
public fun new_reward_pool<RecordingShare, Currency>(self: &mut Recording<RecordingShare>) {
    let reward_pool = reward_pool::new<RecordingShare, Currency>(&mut self.id);
    transfer::public_share_object(reward_pool);
}

//=== Public View Functions ===

/// Returns the recording's object ID.
public fun id<RecordingShare>(self: &Recording<RecordingShare>): ID {
    self.id.to_inner()
}

/// Returns the current lifecycle state.
public fun state<RecordingShare>(self: &Recording<RecordingShare>): RecordingState {
    self.state
}

/// Returns the primary title.
public fun title<RecordingShare>(self: &Recording<RecordingShare>): &String {
    &self.title
}

/// Returns the optional title version.
public fun title_version<RecordingShare>(self: &Recording<RecordingShare>): &Option<String> {
    &self.title_version
}

/// Returns the optional subtitle.
public fun subtitle<RecordingShare>(self: &Recording<RecordingShare>): &Option<String> {
    &self.subtitle
}

/// Returns the ID of the underlying composition.
public fun composition_id<RecordingShare>(self: &Recording<RecordingShare>): ID {
    self.composition_id
}

/// Returns the type of the composition's share token.
public fun composition_share_type<RecordingShare>(self: &Recording<RecordingShare>): &TypeName {
    &self.composition_share_type
}

/// Returns the composition's revenue split in basis points.
public fun composition_split<RecordingShare>(self: &Recording<RecordingShare>): &BPS {
    &self.composition_split
}

/// Returns the set of primary artist IDs.
public fun artists<RecordingShare>(self: &Recording<RecordingShare>): &VecSet<ID> {
    &self.artists
}

/// Returns the set of featured artist IDs.
public fun featured_artists<RecordingShare>(self: &Recording<RecordingShare>): &VecSet<ID> {
    &self.featured_artists
}

/// Returns the contributor-to-roles mapping.
public fun contributors<RecordingShare>(self: &Recording<RecordingShare>): &VecMap<ID, vector<RecordingContributorRole>> {
    &self.contributors
}

/// Returns the primary genre ID.
public fun genre_id<RecordingShare>(self: &Recording<RecordingShare>): ID {
    self.genre_id
}

/// Returns the set of secondary genre IDs.
public fun secondary_genre_ids<RecordingShare>(self: &Recording<RecordingShare>): &VecSet<ID> {
    &self.secondary_genre_ids
}

/// Returns the optional language code.
public fun language<RecordingShare>(self: &Recording<RecordingShare>): &Option<LanguageCode> {
    &self.language
}

/// Returns whether the recording contains explicit content.
public fun is_explicit<RecordingShare>(self: &Recording<RecordingShare>): bool {
    self.is_explicit
}

/// Returns whether the recording is instrumental.
public fun is_instrumental<RecordingShare>(self: &Recording<RecordingShare>): bool {
    self.is_instrumental
}

/// Returns the optional musical key.
public fun musical_key<RecordingShare>(self: &Recording<RecordingShare>): &Option<MusicalKey> {
    &self.musical_key
}

/// Returns the optional time signature.
public fun time_signature<RecordingShare>(self: &Recording<RecordingShare>): &Option<TimeSignature> {
    &self.time_signature
}

/// Returns the optional tempo in BPM.
public fun tempo_bpm<RecordingShare>(self: &Recording<RecordingShare>): &Option<u16> {
    &self.tempo_bpm
}

/// Returns a reference to the master audio file.
public fun master<RecordingShare>(self: &Recording<RecordingShare>): &Audio {
    &self.master
}

/// Returns a reference to the cover art.
public fun cover_art<RecordingShare>(self: &Recording<RecordingShare>): &CoverArt {
    &self.cover_art
}

/// Returns a reference to the list of stems.
public fun stems<RecordingShare>(self: &Recording<RecordingShare>): &vector<Stem> {
    &self.stems
}

/// Returns the list of attached artifacts.
public fun artifacts<RecordingShare>(self: &Recording<RecordingShare>): &vector<Artifact<RecordingArtifactKind>> {
    &self.artifacts
}

/// Returns the list of snapshots.
public fun snapshots<RecordingShare>(self: &Recording<RecordingShare>): &vector<Snapshot> {
    &self.snapshots
}

//=== Package Functions ===

/// Verifies that the admin capability matches this recording.
/// Aborts with EUnauthorized if the capability doesn't match.
public(package) fun authorize<RecordingShare>(
    self: &Recording<RecordingShare>,
    cap: &RecordingAdminCap,
) {
    assert!(self.id() == cap.recording_id, EUnauthorized);
}

// Copyright (c) Studio Mirai, LLC
// SPDX-License-Identifier: Apache-2.0

/// Represents an audio recording of a composition in MusicOS.
/// Recordings are the audio performances that are distributed and played.
/// Each recording has its own share token for ownership distribution.
///
/// Key features:
/// - Share token initialization with fixed supply (100M tokens, 6 decimals)
/// - Contributor management with role assignments (Producer, Vocalist, etc.)
/// - State machine: Initialized -> Published (immutable after publish)
/// - Musical metadata (key, tempo, time signature)
/// - Deterministic addresses via derived object pattern
module musicos::recording;

use interest_bps::bps::BPS;
use language_code::language_code::LanguageCode;
use musicos::audio::Audio;
use musicos::composition::Composition;
use musicos::contributor::Contributor;
use musicos::cover_art::CoverArt;
use musicos::credit::Credit;
use musicos::genre::Genre;
use musicos::musical_key::MusicalKey;
use musicos::plugin;
use musicos::recording_contributor_role::RecordingContributorRole;
use musicos::share;
use musicos::time_signature::TimeSignature;
use std::string::String;
use std::type_name::{TypeName, with_defining_ids};
use sui::balance::Balance;
use sui::clock::Clock;
use sui::coin::TreasuryCap;
use sui::coin_registry::Currency;
use sui::derived_object::claim;
use sui::event::emit;
use sui::vec_map::{Self, VecMap};
use sui::vec_set::{Self, VecSet};

//=== Structs ===

/// An audio recording of a composition.
/// The phantom RS type parameter links to the share token.
public struct Recording<phantom RS> has key {
    /// Unique identifier for this recording.
    id: UID,
    /// Current lifecycle state.
    state: RecordingState,
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
    /// Revenue split for the composition in basis points (captured at creation time).
    composition_split_bps: BPS,
    /// Primary genre of the recording.
    primary_genre_id: ID,
    /// Additional genres for the recording.
    secondary_genre_ids: VecSet<ID>,
    // IDs of the primary artists on the recording.
    primary_artist_ids: VecSet<ID>,
    // IDs of the featured artists on the recording.
    featured_artist_ids: VecSet<ID>,
    /// Map of contributor IDs to their roles on this recording.
    credits: VecMap<ID, Credit<RecordingContributorRole>>,
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
}

/// Capability that authorizes modifications to a specific recording.
/// Initialized when a recording is registered and transferred to the owner.
/// Address is derived from the recording for client-side discoverability.
public struct RecordingAdminCap<phantom RS> has key, store {
    /// Unique identifier for this capability.
    id: UID,
}

//=== Derivation Keys ===

/// Key for deriving the admin capability's deterministic address from the recording.
public struct RecordingAdminCapKey() has copy, drop, store;

/// Key for deriving the recording's address from the composition.
public struct RecordingKey(
    /// Digest of the master audio file.
    vector<u8>,
) has copy, drop, store;

//=== Events ===

/// Emitted when a new recording is created.
public struct RecordingInitializedEvent has copy, drop {
    /// ID of the created recording.
    recording_id: ID,
    /// Type of the recording's share token.
    recording_share_type: TypeName,
    /// ID of the underlying composition.
    composition_id: ID,
    /// ID of the recording's genre.
    primary_genre_id: ID,
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

//=== Enums ===

/// Lifecycle state of a recording.
public enum RecordingState has copy, drop, store {
    /// Recording is being set up and can be modified.
    Initialized,
    /// Recording is published and immutable. Includes publication timestamp.
    Published(
        /// Timestamp (ms) when published.
        u64,
    ),
}

//=== Constants ===

/// Minimum number of roles a contributor must have.
const MIN_ROLES_PER_CREDIT: u64 = 1;
/// Maximum number of roles a contributor can have.
const MAX_ROLES_PER_CREDIT: u64 = 10;

//=== Errors ===

/// Operation requires Initialized state but recording is created.
const ENotInitializedState: u64 = 1;
/// Contributor has too many roles.
const EExceedsMaxRoles: u64 = 11;
/// Contributor must have at least one role.
const EMinRolesNotMet: u64 = 12;
/// Recording must have at least one contributor to publish.
const ENoContributors: u64 = 20;
/// Recording must have at least one primary artist to publish.
const ENoPrimaryArtistAssigned: u64 = 21;
/// Contributor is not credited on the recording.
const EContributorNotCredited: u64 = 22;
/// Contributor is already a featured artist.
const EAlreadyFeaturedArtist: u64 = 23;
/// Contributor is already a primary artist.
const EAlreadyPrimaryArtist: u64 = 24;
/// Genre is already assigned as a secondary genre.
const EAlreadyAssignedAsSecondaryGenre: u64 = 25;
/// Genre is already assigned as a primary genre.
const EAlreadyAssignedAsPrimaryGenre: u64 = 26;

//=== Public Functions ===

// --- Lifecycle ---

/// Creates a new recording for a composition.
/// Initializes share tokens (100M supply, 6 decimals) and returns:
/// - The recording object
/// - Admin capability for the owner
/// - Initial share token balance
/// - Promise that must be consumed by calling `share()`
public fun new<RS, CS>(
    composition: &mut Composition<CS>,
    genre: &Genre,
    is_explicit: bool,
    is_instrumental: bool,
    master: Audio,
    cover_art: CoverArt,
    share_currency: &mut Currency<RS>,
    share_treasury_cap: TreasuryCap<RS>,
): (Recording<RS>, RecordingAdminCap<RS>, Balance<RS>) {
    let composition_id = composition.id();
    let primary_genre_id = genre.id();

    let mut recording = Recording<RS> {
        id: claim(composition.uid_mut_internal(), RecordingKey(*master.pcm_digest())),
        state: RecordingState::Initialized,
        title: *composition.title(),
        title_version: option::none(),
        subtitle: option::none(),
        composition_id,
        composition_share_type: with_defining_ids<CS>(),
        composition_split_bps: composition.split_bps(),
        primary_genre_id,
        secondary_genre_ids: vec_set::empty(),
        primary_artist_ids: vec_set::empty(),
        featured_artist_ids: vec_set::empty(),
        credits: vec_map::empty(),
        language: option::none(),
        is_explicit,
        is_instrumental,
        musical_key: option::none(),
        time_signature: option::none(),
        tempo_bpm: option::none(),
        master,
        cover_art,
    };

    let recording_admin_cap = RecordingAdminCap<RS> {
        id: claim(&mut recording.id, RecordingAdminCapKey()),
    };

    let mut description: String = "MusicOS Recording Shares for 0x";
    description.append(recording.id().to_address().to_string());
    description.append(".");

    let recording_shares = share::intialize<RS>(
        share_currency,
        share_treasury_cap,
    );

    emit(RecordingInitializedEvent {
        recording_id: recording.id(),
        recording_share_type: with_defining_ids<RS>(),
        composition_id,
        primary_genre_id,
    });

    (recording, recording_admin_cap, recording_shares)
}

/// Publishes the recording, making it immutable.
/// Requires at least one contributor to be assigned.
/// Required State: Initialized
public fun publish<RS>(mut self: Recording<RS>, clock: &Clock) {
    match (self.state) {
        RecordingState::Initialized => {
            // Assert the recording has at least one contributor.
            assert!(!self.credits.is_empty(), ENoContributors);
            // Assert the recording has at least one primary artist.
            assert!(!self.primary_artist_ids.is_empty(), ENoPrimaryArtistAssigned);

            // Set the recording's publish timestamp.
            self.state = RecordingState::Published(clock.timestamp_ms());

            emit(RecordingPublishedEvent {
                recording_id: self.id(),
            });

            transfer::share_object(self);
        },
        _ => abort ENotInitializedState,
    };
}

// --- Title ---

/// Sets the primary title of the recording.
/// Required State: Initialized
public fun set_title<RS>(self: &mut Recording<RS>, title: String) {
    match (self.state) {
        RecordingState::Initialized => {
            self.title = title;
        },
        _ => abort ENotInitializedState,
    }
}

/// Sets the title version (e.g., "Radio Edit", "Extended Mix").
/// Required State: Initialized
public fun set_title_version<RS>(self: &mut Recording<RS>, title_version: String) {
    match (self.state) {
        RecordingState::Initialized => {
            self.title_version.swap_or_fill(title_version);
        },
        _ => abort ENotInitializedState,
    }
}

/// Sets the subtitle of the recording.
/// Required State: Initialized
public fun set_subtitle<RS>(self: &mut Recording<RS>, subtitle: String) {
    match (self.state) {
        RecordingState::Initialized => {
            self.subtitle.swap_or_fill(subtitle);
        },
        _ => abort ENotInitializedState,
    }
}

/// Sets the language of the recording.
/// Required State: Initialized
public fun set_language<RS>(self: &mut Recording<RS>, language: LanguageCode) {
    match (self.state) {
        RecordingState::Initialized => {
            self.language.swap_or_fill(language);
        },
        _ => abort ENotInitializedState,
    }
}

// --- People ---

/// Adds a contributor to the recording with specified roles.
/// Each contributor must have 1-20 roles.
/// Required State: Initialized
public fun add_credit<RS>(
    self: &mut Recording<RS>,
    contributor: &Contributor,
    credit: Credit<RecordingContributorRole>,
) {
    match (self.state) {
        RecordingState::Initialized => {
            assert!(credit.roles().length() >= MIN_ROLES_PER_CREDIT, EMinRolesNotMet);
            assert!(credit.roles().length() <= MAX_ROLES_PER_CREDIT, EExceedsMaxRoles);

            let contributor_id = contributor.id();
            self.credits.insert(contributor_id, credit);

            emit(RecordingContributorAddedEvent {
                recording_id: self.id(),
                contributor_id,
            });
        },
        _ => abort ENotInitializedState,
    }
}

public fun add_primary_artist<RS>(self: &mut Recording<RS>, contributor: &Contributor) {
    match (self.state) {
        RecordingState::Initialized => {
            let contributor_id = contributor.id();
            // Assert the contributor is credited on the recording.
            assert!(self.credits.contains(&contributor_id), EContributorNotCredited);
            // Assert the contributor is not already a featured artist.
            assert!(!self.featured_artist_ids.contains(&contributor_id), EAlreadyFeaturedArtist);

            self.primary_artist_ids.insert(contributor_id);
        },
        _ => abort ENotInitializedState,
    }
}

public fun add_featured_artist<RS>(self: &mut Recording<RS>, contributor: &Contributor) {
    match (self.state) {
        RecordingState::Initialized => {
            let contributor_id = contributor.id();
            // Assert the contributor is credited on the recording.
            assert!(self.credits.contains(&contributor_id), EContributorNotCredited);
            // Assert the contributor is not already a primary artist.
            assert!(!self.primary_artist_ids.contains(&contributor_id), EAlreadyPrimaryArtist);

            self.featured_artist_ids.insert(contributor_id);
        },
        _ => abort ENotInitializedState,
    }
}

/// Removes a primary artist from the recording.
/// Required State: Initialized
public fun remove_primary_artist<RS>(self: &mut Recording<RS>, contributor_id: ID) {
    match (self.state) {
        RecordingState::Initialized => {
            self.primary_artist_ids.remove(&contributor_id);
        },
        _ => abort ENotInitializedState,
    }
}

/// Removes a featured artist from the recording.
/// Required State: Initialized
public fun remove_featured_artist<RS>(self: &mut Recording<RS>, contributor_id: ID) {
    match (self.state) {
        RecordingState::Initialized => {
            self.featured_artist_ids.remove(&contributor_id);
        },
        _ => abort ENotInitializedState,
    }
}

// --- Classification ---

/// Sets the primary genre of the recording.
/// Required State: Initialized
public fun set_primary_genre<RS>(self: &mut Recording<RS>, genre: &Genre) {
    match (self.state) {
        RecordingState::Initialized => {
            assert!(
                !self.secondary_genre_ids.contains(&genre.id()),
                EAlreadyAssignedAsSecondaryGenre,
            );
            self.primary_genre_id = genre.id();
        },
        _ => abort ENotInitializedState,
    }
}

/// Adds a secondary genre to the recording.
/// Required State: Initialized
public fun add_secondary_genre<RS>(self: &mut Recording<RS>, genre: &Genre) {
    match (self.state) {
        RecordingState::Initialized => {
            assert!(self.primary_genre_id != genre.id(), EAlreadyAssignedAsPrimaryGenre);
            self.secondary_genre_ids.insert(genre.id());
        },
        _ => abort ENotInitializedState,
    }
}

/// Removes a secondary genre from the recording.
/// Required State: Initialized
public fun remove_secondary_genre<RS>(self: &mut Recording<RS>, genre_id: ID) {
    match (self.state) {
        RecordingState::Initialized => {
            self.secondary_genre_ids.remove(&genre_id);
        },
        _ => abort ENotInitializedState,
    }
}

// --- Musical Properties ---

/// Sets the musical key of the recording.
/// Required State: Initialized
public fun set_musical_key<RS>(self: &mut Recording<RS>, musical_key: MusicalKey) {
    match (self.state) {
        RecordingState::Initialized => {
            self.musical_key.swap_or_fill(musical_key);
        },
        _ => abort ENotInitializedState,
    }
}

/// Sets the time signature of the recording.
/// Required State: Initialized
public fun set_time_signature<RS>(self: &mut Recording<RS>, time_signature: TimeSignature) {
    match (self.state) {
        RecordingState::Initialized => {
            self.time_signature.swap_or_fill(time_signature);
        },
        _ => abort ENotInitializedState,
    }
}

/// Sets the tempo in beats per minute.
/// Required State: Initialized
public fun set_tempo_bpm<RS>(self: &mut Recording<RS>, tempo_bpm: u16) {
    match (self.state) {
        RecordingState::Initialized => {
            self.tempo_bpm.swap_or_fill(tempo_bpm);
        },
        _ => abort ENotInitializedState,
    }
}

//=== Public View Functions ===

/// Returns the recording's object ID.
public fun id<RS>(self: &Recording<RS>): ID {
    self.id.to_inner()
}

/// Returns the current lifecycle state.
public fun state<RS>(self: &Recording<RS>): RecordingState {
    self.state
}

/// Returns the primary title.
public fun title<RS>(self: &Recording<RS>): &String {
    &self.title
}

/// Returns the optional title version.
public fun title_version<RS>(self: &Recording<RS>): &Option<String> {
    &self.title_version
}

/// Returns the optional subtitle.
public fun subtitle<RS>(self: &Recording<RS>): &Option<String> {
    &self.subtitle
}

/// Returns the ID of the underlying composition.
public fun composition_id<RS>(self: &Recording<RS>): ID {
    self.composition_id
}

/// Returns the type of the composition's share token.
public fun composition_share_type<RS>(self: &Recording<RS>): &TypeName {
    &self.composition_share_type
}

/// Returns the composition's revenue split in basis points.
public fun composition_split_bps<RS>(self: &Recording<RS>): BPS {
    self.composition_split_bps
}

/// Returns the contributor-to-roles mapping.
public fun credits<RS>(self: &Recording<RS>): &VecMap<ID, Credit<RecordingContributorRole>> {
    &self.credits
}

/// Returns the primary genre ID.
public fun primary_genre_id<RS>(self: &Recording<RS>): ID {
    self.primary_genre_id
}

/// Returns the set of secondary genre IDs.
public fun secondary_genre_ids<RS>(self: &Recording<RS>): &VecSet<ID> {
    &self.secondary_genre_ids
}

/// Returns the optional language code.
public fun language<RS>(self: &Recording<RS>): &Option<LanguageCode> {
    &self.language
}

/// Returns whether the recording contains explicit content.
public fun is_explicit<RS>(self: &Recording<RS>): bool {
    self.is_explicit
}

/// Returns whether the recording is instrumental.
public fun is_instrumental<RS>(self: &Recording<RS>): bool {
    self.is_instrumental
}

/// Returns the optional musical key.
public fun musical_key<RS>(self: &Recording<RS>): &Option<MusicalKey> {
    &self.musical_key
}

/// Returns the optional time signature.
public fun time_signature<RS>(self: &Recording<RS>): &Option<TimeSignature> {
    &self.time_signature
}

/// Returns the optional tempo in BPM.
public fun tempo_bpm<RS>(self: &Recording<RS>): &Option<u16> {
    &self.tempo_bpm
}

/// Returns a reference to the master audio file.
public fun master<RS>(self: &Recording<RS>): &Audio {
    &self.master
}

/// Returns a reference to the cover art.
public fun cover_art<RS>(self: &Recording<RS>): &CoverArt {
    &self.cover_art
}

/// Returns whether the provided ID is a primary artist on the recording.
public fun is_primary_artist<RS>(self: &Recording<RS>, contributor_id: ID): bool {
    self.primary_artist_ids.contains(&contributor_id)
}

/// Returns whether the s is a featured artist on the recording.
public fun is_featured_artist<RS>(self: &Recording<RS>, contributor_id: ID): bool {
    self.featured_artist_ids.contains(&contributor_id)
}

/// Returns a reference to the primary artist IDs.
public fun primary_artist_ids<RS>(self: &Recording<RS>): &VecSet<ID> {
    &self.primary_artist_ids
}

/// Returns a reference to the featured artist IDs.
public fun featured_artist_ids<RS>(self: &Recording<RS>): &VecSet<ID> {
    &self.featured_artist_ids
}

//=== UID Functions ===

/// Returns a reference to the recording's UID for reading dynamic fields.
public fun uid<RS>(self: &Recording<RS>): &UID {
    &self.id
}

/// Returns a mutable reference to the recording's UID for dynamic field operations.
/// Requires the admin capability.
public fun uid_mut<RS>(self: &mut Recording<RS>, _cap: &RecordingAdminCap<RS>): &mut UID {
    &mut self.id
}

/// Returns a mutable reference to the recording's UID for authorized plugins.
/// Requires a witness from the plugin module.
public fun uid_mut_authorized<RS, P: drop>(self: &mut Recording<RS>, _: P): &mut UID {
    plugin::assert_authorized<P>(&self.id);
    &mut self.id
}

public(package) fun uid_mut_internal<RS>(self: &mut Recording<RS>): &mut UID {
    &mut self.id
}

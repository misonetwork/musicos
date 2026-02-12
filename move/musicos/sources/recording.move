// Copyright (c) Studio Mirai, LLC
// SPDX-License-Identifier: Apache-2.0

/// Represents an audio recording of a composition in MusicOS.
/// Recordings are the audio performances that are distributed and played.
/// Each recording has its own share token for ownership distribution.
///
/// Key features:
/// - Share token initialization with fixed supply (100M tokens, 6 decimals)
/// - Party management with role assignments (Producer, Vocalist, etc.)
/// - State machine: Initialized -> Published (immutable after publish)
/// - Musical metadata (key, tempo, time signature)
/// - Deterministic addresses via derived object pattern
module musicos::recording;

use interest_bps::bps::BPS;
use language_code::language_code::{Self, LanguageCode};
use musicos::audio::Audio;
use musicos::composition::Composition;
use musicos::cover_art::CoverArt;
use musicos::credit::Credit;
use musicos::extension;
use musicos::genre::Genre;
use musicos::musical_key::MusicalKey;
use musicos::party::Party;
use musicos::recording_party_role::RecordingPartyRole;
use musicos::share;
use musicos::stem::Stem;
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
use walrus_data::walrus_data::WalrusData;

//=== Structs ===

/// An audio recording of a composition.
/// The phantom RecordingShare type parameter links to the share token.
public struct Recording<phantom RecordingShare> has key {
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
    /// Map of party IDs to their roles on this recording.
    credits: VecMap<ID, Credit<RecordingPartyRole>>,
    /// Language of the vocals (if any).
    language: Option<LanguageCode>,
    /// Whether the recording contains explicit content.
    is_explicit: bool,
    /// Whether the recording is instrumental (no vocals).
    is_instrumental: bool,
    /// Optional timed lyrics file (WebVTT format on Walrus).
    lyrics: Option<WalrusData>,
    /// Musical key of the recording.
    musical_key: Option<MusicalKey>,
    /// Time signature of the recording.
    time_signature: Option<TimeSignature>,
    /// Tempo in beats per minute.
    tempo_bpm: Option<u16>,
    /// The final mixed/mastered audio file.
    master: Audio,
    /// The stems of the recording.
    stems: vector<Stem>,
    /// Cover art for the recording.
    cover_art: CoverArt,
}

/// Capability that authorizes modifications to a specific recording.
/// Initialized when a recording is registered and transferred to the owner.
/// Address is derived from the recording for client-side discoverability.
public struct RecordingAdminCap<phantom RecordingShare> has key, store {
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

//=== Events ===

/// Emitted when a recording is published.
public struct RecordingPublishedEvent has copy, drop {
    /// ID of the published recording.
    recording_id: ID,
}

/// Emitted when a party is added to a recording.
public struct RecordingPartyAddedEvent has copy, drop {
    /// ID of the recording.
    recording_id: ID,
    /// ID of the added party.
    party_id: ID,
}

/// Emitted when an extension is registered for a recording.
public struct RecordingExtensionRegisteredEvent<phantom Extension: drop> has copy, drop {
    /// ID of the recording.
    recording_id: ID,
}

/// Emitted when an extension is unregistered from a recording.
public struct RecordingExtensionUnregisteredEvent<phantom Extension: drop> has copy, drop {
    /// ID of the recording.
    recording_id: ID,
}

//=== Constants ===

/// Minimum number of roles a party must have.
const MIN_ROLES_PER_CREDIT: u64 = 1;
/// Maximum number of roles a party can have.
const MAX_ROLES_PER_CREDIT: u64 = 20;
/// Minimum number of contributors a stem must have.
const MIN_CONTRIBUTORS_PER_STEM: u64 = 1;

//=== Errors ===

// State errors (10-19)
/// Operation requires Initialized state but recording is in a different state.
const ENotInitializedState: u64 = 10;

// Validation errors (20-29)
/// Party must have at least one role.
const EMinRolesNotMet: u64 = 20;
/// Tempo BPM must be at least 1.
const EInvalidTempoBpm: u64 = 21;

// Constraint errors (30-39)
/// Party has too many roles.
const EExceedsMaxRoles: u64 = 30;

// Conflict errors (40-49)
/// Party already has a credit on this recording.
const EPartyAlreadyCredited: u64 = 40;
/// Party is already a primary artist.
const EAlreadyPrimaryArtist: u64 = 41;
/// Party is already a featured artist.
const EAlreadyFeaturedArtist: u64 = 42;
/// Genre is already assigned as the primary genre.
const EAlreadyAssignedAsPrimaryGenre: u64 = 43;
/// Genre is already assigned as a secondary genre.
const EAlreadyAssignedAsSecondaryGenre: u64 = 44;
/// Lyrics/instrumental state conflict.
const ELyricsInstrumentalConflict: u64 = 45;

// Reference errors (50-59)
/// Recording must have at least one party to publish.
const ENoParties: u64 = 50;
/// Recording must have at least one primary artist to publish.
const ENoPrimaryArtistAssigned: u64 = 51;
/// Party is not credited on the recording.
const EPartyNotCredited: u64 = 52;
/// Stem must have at least one contributor.
const EMinStemContributorsNotMet: u64 = 53;

//=== Public Functions ===

// --- Lifecycle ---

/// Creates a new recording for a composition.
/// Initializes share tokens (100M supply, 6 decimals) and returns:
/// - The recording object
/// - Admin capability for the owner
/// - Initial share token balance
/// - Promise that must be consumed by calling `share()`
public fun new<RecordingShare, CS>(
    composition: &mut Composition<CS>,
    genre: &Genre,
    is_explicit: bool,
    is_instrumental: bool,
    master: Audio,
    cover_art: CoverArt,
    share_currency: &mut Currency<RecordingShare>,
    share_treasury_cap: TreasuryCap<RecordingShare>,
): (Recording<RecordingShare>, RecordingAdminCap<RecordingShare>, Balance<RecordingShare>) {
    let composition_id = composition.id();
    let primary_genre_id = genre.id();

    let mut recording = Recording<RecordingShare> {
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
        lyrics: option::none(),
        musical_key: option::none(),
        time_signature: option::none(),
        tempo_bpm: option::none(),
        master,
        stems: vector[],
        cover_art,
    };

    let recording_admin_cap = RecordingAdminCap<RecordingShare> {
        id: claim(&mut recording.id, RecordingAdminCapKey()),
    };

    let mut description: String = "MusicOS Recording Shares for 0x";
    description.append(recording.id().to_address().to_string());
    description.append(".");

    let recording_shares = share::initialize<RecordingShare>(
        share_currency,
        share_treasury_cap,
    );

    (recording, recording_admin_cap, recording_shares)
}

/// Publishes the recording, making it immutable.
/// Requires at least one party to be assigned.
/// Required State: Initialized
public fun publish<RecordingShare>(
    mut self: Recording<RecordingShare>,
    _: &RecordingAdminCap<RecordingShare>,
    clock: &Clock,
) {
    match (self.state) {
        RecordingState::Initialized => {
            // Assert the recording has at least one party.
            assert!(!self.credits.is_empty(), ENoParties);
            // Assert the recording has at least one primary artist.
            assert!(!self.primary_artist_ids.is_empty(), ENoPrimaryArtistAssigned);
            // Assert instrumental => no lyrics
            assert!(!self.is_instrumental || self.lyrics.is_none(), ELyricsInstrumentalConflict);

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

/// Sets the title version (e.g., "Radio Edit", "Extended Mix").
/// Required State: Initialized
public fun set_title_version<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    _: &RecordingAdminCap<RecordingShare>,
    title_version: String,
) {
    match (self.state) {
        RecordingState::Initialized => {
            self.title_version.swap_or_fill(title_version);
        },
        _ => abort ENotInitializedState,
    }
}

/// Sets the subtitle of the recording.
/// Required State: Initialized
public fun set_subtitle<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    _: &RecordingAdminCap<RecordingShare>,
    subtitle: String,
) {
    match (self.state) {
        RecordingState::Initialized => {
            self.subtitle.swap_or_fill(subtitle);
        },
        _ => abort ENotInitializedState,
    }
}

/// Sets the language of the recording.
/// Required State: Initialized
public fun set_language<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    _: &RecordingAdminCap<RecordingShare>,
    language_code: String,
) {
    match (self.state) {
        RecordingState::Initialized => {
            self.language.swap_or_fill(language_code::new(language_code));
        },
        _ => abort ENotInitializedState,
    }
}

/// Sets the lyrics file (WebVTT format on Walrus) for the recording.
/// Required State: Initialized
public fun set_lyrics<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    _: &RecordingAdminCap<RecordingShare>,
    lyrics: WalrusData,
) {
    match (self.state) {
        RecordingState::Initialized => {
            // Abort early if recording is instrumental - lyrics not allowed.
            assert!(!self.is_instrumental, ELyricsInstrumentalConflict);
            self.lyrics.swap_or_fill(lyrics);
        },
        _ => abort ENotInitializedState,
    }
}

// --- People ---

/// Adds a party to the recording with specified roles.
/// Each party must have 1-20 roles.
/// Required State: Initialized
public fun add_credit<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    _: &RecordingAdminCap<RecordingShare>,
    party: &Party,
    credit: Credit<RecordingPartyRole>,
) {
    match (self.state) {
        RecordingState::Initialized => {
            assert!(credit.roles().length() >= MIN_ROLES_PER_CREDIT, EMinRolesNotMet);
            assert!(credit.roles().length() <= MAX_ROLES_PER_CREDIT, EExceedsMaxRoles);

            let party_id = party.id();
            // Abort early if party already has a credit on this recording.
            assert!(!self.credits.contains(&party_id), EPartyAlreadyCredited);
            self.credits.insert(party_id, credit);

            emit(RecordingPartyAddedEvent {
                recording_id: self.id(),
                party_id,
            });
        },
        _ => abort ENotInitializedState,
    }
}

public fun add_primary_artist<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    _: &RecordingAdminCap<RecordingShare>,
    party: &Party,
) {
    match (self.state) {
        RecordingState::Initialized => {
            let party_id = party.id();
            // Assert the party is credited on the recording.
            assert!(self.credits.contains(&party_id), EPartyNotCredited);
            // Assert the party is not already a featured artist.
            assert!(!self.featured_artist_ids.contains(&party_id), EAlreadyFeaturedArtist);
            // Assert the party is not already a primary artist.
            assert!(!self.primary_artist_ids.contains(&party_id), EAlreadyPrimaryArtist);

            self.primary_artist_ids.insert(party_id);
        },
        _ => abort ENotInitializedState,
    }
}

public fun add_featured_artist<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    _: &RecordingAdminCap<RecordingShare>,
    party: &Party,
) {
    match (self.state) {
        RecordingState::Initialized => {
            let party_id = party.id();
            // Assert the party is credited on the recording.
            assert!(self.credits.contains(&party_id), EPartyNotCredited);
            // Assert the party is not already a primary artist.
            assert!(!self.primary_artist_ids.contains(&party_id), EAlreadyPrimaryArtist);
            // Assert the party is not already a featured artist.
            assert!(!self.featured_artist_ids.contains(&party_id), EAlreadyFeaturedArtist);

            self.featured_artist_ids.insert(party_id);
        },
        _ => abort ENotInitializedState,
    }
}

// --- Classification ---

/// Sets the primary genre of the recording.
/// Required State: Initialized
public fun set_primary_genre<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    _: &RecordingAdminCap<RecordingShare>,
    genre: &Genre,
) {
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
public fun add_secondary_genre<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    _: &RecordingAdminCap<RecordingShare>,
    genre: &Genre,
) {
    match (self.state) {
        RecordingState::Initialized => {
            let genre_id = genre.id();
            assert!(self.primary_genre_id != genre_id, EAlreadyAssignedAsPrimaryGenre);
            // Assert the genre is not already a secondary genre.
            assert!(
                !self.secondary_genre_ids.contains(&genre_id),
                EAlreadyAssignedAsSecondaryGenre,
            );
            self.secondary_genre_ids.insert(genre_id);
        },
        _ => abort ENotInitializedState,
    }
}

/// Removes a secondary genre from the recording.
/// Required State: Initialized
public fun remove_secondary_genre<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    _: &RecordingAdminCap<RecordingShare>,
    genre_id: ID,
) {
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
public fun set_musical_key<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    _: &RecordingAdminCap<RecordingShare>,
    musical_key: MusicalKey,
) {
    match (self.state) {
        RecordingState::Initialized => {
            self.musical_key.swap_or_fill(musical_key);
        },
        _ => abort ENotInitializedState,
    }
}

/// Sets the time signature of the recording.
/// Required State: Initialized
public fun set_time_signature<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    _: &RecordingAdminCap<RecordingShare>,
    time_signature: TimeSignature,
) {
    match (self.state) {
        RecordingState::Initialized => {
            self.time_signature.swap_or_fill(time_signature);
        },
        _ => abort ENotInitializedState,
    }
}

/// Sets the tempo in beats per minute.
/// Required State: Initialized
public fun set_tempo_bpm<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    _: &RecordingAdminCap<RecordingShare>,
    tempo_bpm: u16,
) {
    match (self.state) {
        RecordingState::Initialized => {
            assert!(tempo_bpm >= 1, EInvalidTempoBpm);
            self.tempo_bpm.swap_or_fill(tempo_bpm);
        },
        _ => abort ENotInitializedState,
    }
}

public fun add_stem<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    _: &RecordingAdminCap<RecordingShare>,
    stem: Stem,
) {
    match (self.state) {
        RecordingState::Initialized => {
            // Assert the stem has at least one contributor.
            assert!(
                stem.contributors().length() >= MIN_CONTRIBUTORS_PER_STEM,
                EMinStemContributorsNotMet,
            );
            // If the stem has assigned contributors, assert that each contributor
            // is credited in the recording's credits.
            stem.contributors().do_ref!(|contributor_id| {
                assert!(self.credits.contains(contributor_id), EPartyNotCredited);
            });
            // Add the stem to the recording.
            self.stems.push_back(stem);
        },
        _ => abort ENotInitializedState,
    }
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
public fun composition_split_bps<RecordingShare>(self: &Recording<RecordingShare>): BPS {
    self.composition_split_bps
}

/// Returns the primary genre ID.
public fun primary_genre_id<RecordingShare>(self: &Recording<RecordingShare>): ID {
    self.primary_genre_id
}

/// Returns the set of secondary genre IDs.
public fun secondary_genre_ids<RecordingShare>(self: &Recording<RecordingShare>): &VecSet<ID> {
    &self.secondary_genre_ids
}

/// Returns a reference to the primary artist IDs.
public fun primary_artist_ids<RecordingShare>(self: &Recording<RecordingShare>): &VecSet<ID> {
    &self.primary_artist_ids
}

/// Returns a reference to the featured artist IDs.
public fun featured_artist_ids<RecordingShare>(self: &Recording<RecordingShare>): &VecSet<ID> {
    &self.featured_artist_ids
}

/// Returns the party-to-roles mapping.
public fun credits<RecordingShare>(
    self: &Recording<RecordingShare>,
): &VecMap<ID, Credit<RecordingPartyRole>> {
    &self.credits
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

/// Returns the optional lyrics file reference.
public fun lyrics<RecordingShare>(self: &Recording<RecordingShare>): &Option<WalrusData> {
    &self.lyrics
}

/// Returns the optional musical key.
public fun musical_key<RecordingShare>(self: &Recording<RecordingShare>): &Option<MusicalKey> {
    &self.musical_key
}

/// Returns the optional time signature.
public fun time_signature<RecordingShare>(
    self: &Recording<RecordingShare>,
): &Option<TimeSignature> {
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

/// Returns a reference to the stems.
public fun stems<RecordingShare>(self: &Recording<RecordingShare>): &vector<Stem> {
    &self.stems
}

/// Returns whether the provided ID is a primary artist on the recording.
public fun is_primary_artist<RecordingShare>(self: &Recording<RecordingShare>, party_id: ID): bool {
    self.primary_artist_ids.contains(&party_id)
}

/// Returns whether the party is a featured artist on the recording.
public fun is_featured_artist<RecordingShare>(
    self: &Recording<RecordingShare>,
    party_id: ID,
): bool {
    self.featured_artist_ids.contains(&party_id)
}

//=== Extension Functions ===

/// Registers an extension for the recording with associated config.
public fun register_extension<RecordingShare, Extension: drop, Config: store>(
    self: &mut Recording<RecordingShare>,
    _: &RecordingAdminCap<RecordingShare>,
    _extension: Extension,
    config: Config,
) {
    extension::register<Extension, Config>(&mut self.id, config);

    emit(RecordingExtensionRegisteredEvent<Extension> {
        recording_id: self.id(),
    });
}

/// Unregisters an extension from the recording and returns its config.
public fun unregister_extension<RecordingShare, Extension: drop, Config: store>(
    self: &mut Recording<RecordingShare>,
    _: &RecordingAdminCap<RecordingShare>,
    _extension: Extension,
): Config {
    let config = extension::unregister<Extension, Config>(&mut self.id);

    emit(RecordingExtensionUnregisteredEvent<Extension> {
        recording_id: self.id(),
    });

    config
}

//=== UID Functions ===

/// Returns a reference to the recording's UID for reading dynamic fields.
public fun uid<RecordingShare>(self: &Recording<RecordingShare>): &UID {
    &self.id
}

/// Returns a mutable reference to the recording's UID.
/// Requires the admin capability.
public fun uid_mut<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    _: &RecordingAdminCap<RecordingShare>,
): &mut UID {
    &mut self.id
}

/// Returns a mutable reference to the recording's UID with an extension.
public fun uid_mut_with_extension<RecordingShare, Extension: drop>(
    self: &mut Recording<RecordingShare>,
    _extension: Extension,
): &mut UID {
    extension::assert_registered<Extension>(&self.id);
    &mut self.id
}

public(package) fun uid_mut_internal<RecordingShare>(
    self: &mut Recording<RecordingShare>,
): &mut UID {
    &mut self.id
}

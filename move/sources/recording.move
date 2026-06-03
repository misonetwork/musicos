// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Represents an audio recording of a composition in MusicOS.
/// Recordings are the audio performances that are distributed and played.
/// Each recording has its own share token for ownership distribution.
///
/// ### Key Features:
///
/// - Share token initialization with fixed supply (100M tokens, 6 decimals)
/// - Party management with role assignments (Producer, Vocalist, etc.)
/// - State machine: Initialized -> Published (immutable after publish)
/// - Deterministic addresses via derived object pattern
module musicos::recording;

use gengo::language_code::{Self, LanguageCode};
use bps::bps::BPS;
#[test_only]
use bps::bps;
use audio::audio::Audio;
use musicos::composition::Composition;
use musicos::cover_art::CoverArt;
use musicos::recording_party_role::RecordingPartyRole;
use partyos::credit::Credit;
use partyos::party::Party;
use share::share;
use std::string::String;
use std::type_name::TypeName;
use sui::balance::Balance;
use sui::clock::Clock;
use sui::coin::TreasuryCap;
use sui::coin_registry::Currency;
use sui::derived_object::claim;
use sui::event::emit;
use sui::vec_map::{Self, VecMap};
use sui::vec_set::{Self, VecSet};

// === Structs ===

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
    /// Royalty rate owed to the composition (captured from the composition at creation time).
    composition_royalty_rate: BPS,
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
    /// The final mixed/mastered audio file.
    master: Audio,
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

// === Derivation Keys ===

/// Key for deriving the admin capability's deterministic address from the recording.
public struct RecordingAdminCapKey() has copy, drop, store;

/// Key for deriving the recording's address from the composition.
/// Derived from the master audio's plaintext content (PCM digest) and its
/// verifier (ingester type). The PCM digest — not the Walrus blob id — keys the
/// recording so the address is stable even when the master is encrypted (the
/// blob id is the ciphertext hash, randomized by the AES key). Content gives
/// one recording per distinct master; the verifier namespaces it so an
/// untrusted ingester cannot squat the address a trusted ingester would derive
/// for the same bytes.
public struct RecordingKey(vector<u8>, TypeName) has copy, drop, store;

// === Enums ===

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

// === Events ===

/// Emitted once when a recording is published. A pure pointer: it carries the
/// recording's identity and its parent composition (for routing). A recording is
/// immutable after publishing, so an indexer treats this as a signal to fetch
/// the full, final object by `recording_id`; all indexed data — including the
/// publish timestamp — lives in the object itself.
public struct RecordingPublishedEvent<phantom RecordingShare> has copy, drop {
    recording_id: ID,
    composition_id: ID,
}

// === Constants ===

/// Minimum number of roles a party must have.
const MIN_ROLES_PER_CREDIT: u64 = 1;
/// Maximum number of roles a party can have.
const MAX_ROLES_PER_CREDIT: u64 = 10;
/// Maximum number of credits allowed on a recording.
const MAX_CREDITS: u64 = 150;
/// Maximum number of primary artists allowed on a recording.
const MAX_PRIMARY_ARTISTS: u64 = 20;
/// Maximum number of featured artists allowed on a recording.
const MAX_FEATURED_ARTISTS: u64 = 50;
/// Maximum length of a title version in bytes.
const MAX_TITLE_VERSION_LENGTH: u64 = 100;
/// Maximum length of a subtitle in bytes.
const MAX_SUBTITLE_LENGTH: u64 = 300;

// === Errors ===

// State errors (10-19)
/// Operation requires Initialized state but recording is in a different state.
const ENotInitializedState: u64 = 10;

// Validation errors (20-29)
/// Party must have at least one role.
const EMinRolesNotMet: u64 = 20;

// Constraint errors (30-39)
/// Party has too many roles.
const EExceedsMaxRoles: u64 = 30;
/// Recording has too many credits.
const EMaxCreditsExceeded: u64 = 32;
/// Recording has too many primary artists.
const EMaxPrimaryArtistsExceeded: u64 = 34;
/// Recording has too many featured artists.
const EMaxFeaturedArtistsExceeded: u64 = 35;
/// Title version exceeds maximum length.
const EMaxTitleVersionLengthExceeded: u64 = 36;
/// Subtitle exceeds maximum length.
const EMaxSubtitleLengthExceeded: u64 = 37;
/// String must not be empty.
const EEmptyString: u64 = 38;

// Conflict errors (40-49)
/// Party already has a credit on this recording.
const EPartyAlreadyCredited: u64 = 40;
/// Party is already a primary artist.
const EAlreadyPrimaryArtist: u64 = 41;
/// Party is already a featured artist.
const EAlreadyFeaturedArtist: u64 = 42;

// Reference errors (50-59)
/// Recording must have at least one party to publish.
const ENoParties: u64 = 50;
/// Recording must have at least one primary artist to publish.
const ENoPrimaryArtistAssigned: u64 = 51;
/// Party is not credited on the recording.
const EPartyNotCredited: u64 = 52;

// === Public Functions ===

// === Lifecycle ===

/// Creates a new recording for a composition.
/// Initializes share tokens (100M supply, 6 decimals) and returns:
/// - The recording object
/// - Admin capability for the owner
/// - Initial share token balance
/// - Promise that must be consumed by calling `share()`
public fun new<RecordingShare, CompositionShare>(
    composition: &mut Composition<CompositionShare>,
    is_explicit: bool,
    is_instrumental: bool,
    master: Audio,
    cover_art: CoverArt,
    share_currency: &mut Currency<RecordingShare>,
    share_treasury_cap: TreasuryCap<RecordingShare>,
): (Recording<RecordingShare>, RecordingAdminCap<RecordingShare>, Balance<RecordingShare>) {
    let composition_id = composition.id();

    let mut recording = Recording<RecordingShare> {
        id: claim(
            composition.uid_mut_internal(),
            RecordingKey(*master.pcm_digest(), *master.ingester_type()),
        ),
        state: RecordingState::Initialized,
        title: *composition.title(),
        title_version: option::none(),
        subtitle: option::none(),
        composition_id,
        composition_royalty_rate: composition.royalty_rate(),
        primary_artist_ids: vec_set::empty(),
        featured_artist_ids: vec_set::empty(),
        credits: vec_map::empty(),
        language: option::none(),
        is_explicit,
        is_instrumental,
        master,
        cover_art,
    };

    let recording_admin_cap = RecordingAdminCap<RecordingShare> {
        id: claim(&mut recording.id, RecordingAdminCapKey()),
    };

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

            // Set the recording's publish timestamp.
            let published_at_ms = clock.timestamp_ms();
            self.state = RecordingState::Published(published_at_ms);

            emit(RecordingPublishedEvent<RecordingShare> {
                recording_id: self.id(),
                composition_id: self.composition_id,
            });

            transfer::share_object(self);
        },
        _ => abort ENotInitializedState,
    };
}

// === Title ===

/// Sets the title version (e.g., "Radio Edit", "Extended Mix").
/// Required State: Initialized
public fun set_title_version<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    _: &RecordingAdminCap<RecordingShare>,
    title_version: String,
) {
    match (self.state) {
        RecordingState::Initialized => {
            assert!(!title_version.is_empty(), EEmptyString);
            assert!(
                title_version.length() <= MAX_TITLE_VERSION_LENGTH,
                EMaxTitleVersionLengthExceeded,
            );
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
            assert!(!subtitle.is_empty(), EEmptyString);
            assert!(subtitle.length() <= MAX_SUBTITLE_LENGTH, EMaxSubtitleLengthExceeded);
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

// === People ===

/// Adds a party to the recording with specified roles.
/// Each party must have 1-10 roles.
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
            assert!(self.credits.length() < MAX_CREDITS, EMaxCreditsExceeded);

            let party_id = party.id();
            // Abort early if party already has a credit on this recording.
            assert!(!self.credits.contains(&party_id), EPartyAlreadyCredited);
            self.credits.insert(party_id, credit);
        },
        _ => abort ENotInitializedState,
    }
}

/// Adds a party as a primary artist on the recording.
/// The party must already be credited and not already assigned as primary or featured.
/// Required State: Initialized
public fun add_primary_artist<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    _: &RecordingAdminCap<RecordingShare>,
    party: &Party,
) {
    match (self.state) {
        RecordingState::Initialized => {
            assert!(
                self.primary_artist_ids.length() < MAX_PRIMARY_ARTISTS,
                EMaxPrimaryArtistsExceeded,
            );

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

/// Adds a party as a featured artist on the recording.
/// The party must already be credited and not already assigned as primary or featured.
/// Required State: Initialized
public fun add_featured_artist<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    _: &RecordingAdminCap<RecordingShare>,
    party: &Party,
) {
    match (self.state) {
        RecordingState::Initialized => {
            assert!(
                self.featured_artist_ids.length() < MAX_FEATURED_ARTISTS,
                EMaxFeaturedArtistsExceeded,
            );

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

// === Public View Functions ===

/// Returns the recording's object ID.
public fun id<RecordingShare>(self: &Recording<RecordingShare>): ID {
    self.id.to_inner()
}

/// Returns the current lifecycle state.
public fun state<RecordingShare>(self: &Recording<RecordingShare>): RecordingState {
    self.state
}

/// Returns true if the recording is in the Initialized state.
public fun is_initialized_state<RecordingShare>(self: &Recording<RecordingShare>): bool {
    match (self.state) { RecordingState::Initialized => true, _ => false }
}

/// Returns true if the recording is in the Published state.
public fun is_published_state<RecordingShare>(self: &Recording<RecordingShare>): bool {
    match (self.state) { RecordingState::Published(_) => true, _ => false }
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

/// Returns the royalty rate owed to the composition.
public fun composition_royalty_rate<RecordingShare>(self: &Recording<RecordingShare>): BPS {
    self.composition_royalty_rate
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

/// Returns a reference to the master audio file.
public fun master<RecordingShare>(self: &Recording<RecordingShare>): &Audio {
    &self.master
}

/// Returns the ingester type of the recording's master audio file.
public fun master_ingester_type<RecordingShare>(self: &Recording<RecordingShare>): &TypeName {
    self.master.ingester_type()
}

/// Returns a reference to the cover art.
public fun cover_art<RecordingShare>(self: &Recording<RecordingShare>): &CoverArt {
    &self.cover_art
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

// === UID Functions ===

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

public(package) fun uid_mut_internal<RecordingShare>(
    self: &mut Recording<RecordingShare>,
): &mut UID {
    &mut self.id
}

// === Test Only ===

#[test_only]
public fun new_for_testing<RecordingShare>(
    title: String,
    composition_id: ID,
    composition_royalty_rate_bps: u16,
    is_explicit: bool,
    is_instrumental: bool,
    master: Audio,
    cover_art: CoverArt,
    ctx: &mut TxContext,
): (Recording<RecordingShare>, RecordingAdminCap<RecordingShare>) {
    let mut recording = Recording<RecordingShare> {
        id: object::new(ctx),
        state: RecordingState::Initialized,
        title,
        title_version: option::none(),
        subtitle: option::none(),
        composition_id,
        composition_royalty_rate: bps::new(composition_royalty_rate_bps),
        primary_artist_ids: vec_set::empty(),
        featured_artist_ids: vec_set::empty(),
        credits: vec_map::empty(),
        language: option::none(),
        is_explicit,
        is_instrumental,
        master,
        cover_art,
    };

    let recording_admin_cap = RecordingAdminCap<RecordingShare> {
        id: claim(&mut recording.id, RecordingAdminCapKey()),
    };

    (recording, recording_admin_cap)
}

/// Pre-fills a recording with `n` fake credits (bypasses public API validation).
/// Each credit gets a unique fake party ID and a single vocalist role.
#[test_only]
public fun prefill_credits_for_testing<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    n: u64,
    ctx: &mut TxContext,
) {
    use partyos::credit;
    use musicos::recording_party_role;

    n.do!(|_| {
        let uid = object::new(ctx);
        let id = uid.to_inner();
        uid.delete();
        let credit = credit::new(
            b"Test".to_string(),
            vector[recording_party_role::new_vocalist_role(option::none())],
        );
        self.credits.insert(id, credit);
    });
}

/// Pre-fills a recording with `n` fake credits and designates them as primary artists.
#[test_only]
public fun prefill_primary_artists_for_testing<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    n: u64,
    ctx: &mut TxContext,
) {
    use partyos::credit;
    use musicos::recording_party_role;

    n.do!(|_| {
        let uid = object::new(ctx);
        let id = uid.to_inner();
        uid.delete();
        let credit = credit::new(
            b"Test".to_string(),
            vector[recording_party_role::new_vocalist_role(option::none())],
        );
        self.credits.insert(id, credit);
        self.primary_artist_ids.insert(id);
    });
}

/// Pre-fills a recording with `n` fake credits and designates them as featured artists.
#[test_only]
public fun prefill_featured_artists_for_testing<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    n: u64,
    ctx: &mut TxContext,
) {
    use partyos::credit;
    use musicos::recording_party_role;

    n.do!(|_| {
        let uid = object::new(ctx);
        let id = uid.to_inner();
        uid.delete();
        let credit = credit::new(
            b"Test".to_string(),
            vector[recording_party_role::new_vocalist_role(option::none())],
        );
        self.credits.insert(id, credit);
        self.featured_artist_ids.insert(id);
    });
}

/// Creates a test Audio object.
#[test_only]
public fun new_test_audio(): Audio {
    use audio::audio;
    use ori::walrus_data;
    audio::new(b"flac".to_string(), 2, 16, 44100, 441000, x"0000000000000000000000000000000000000000000000000000000000000000", walrus_data::new_blob(1), TestWitness())
}

/// Witness for creating test Audio objects.
#[test_only]
public struct TestWitness() has drop;

/// A second test ingester witness, for exercising verifier namespacing in the
/// recording address derivation.
#[test_only]
public struct TestWitnessB() has drop;

/// Creates a test Audio with the given blob id, ingested by `TestWitness`.
/// The PCM digest is derived from `blob` so distinct `blob` values model
/// distinct master *content* (recording id now keys on the digest).
#[test_only]
public fun test_audio_with_blob(blob: u256): Audio {
    use audio::audio;
    use ori::walrus_data;
    audio::new(b"flac".to_string(), 2, 16, 44100, 441000, std::bcs::to_bytes(&blob), walrus_data::new_blob(blob), TestWitness())
}

/// Creates a test Audio with the given blob id, ingested by `TestWitnessB`.
/// Same digest-from-`blob` convention as `test_audio_with_blob`.
#[test_only]
public fun test_audio_with_blob_b(blob: u256): Audio {
    use audio::audio;
    use ori::walrus_data;
    audio::new(b"flac".to_string(), 2, 16, 44100, 441000, std::bcs::to_bytes(&blob), walrus_data::new_blob(blob), TestWitnessB())
}

/// Claims a recording id off a composition via the real RecordingKey derivation.
/// (The production path; `new_for_testing` bypasses it with `object::new`.)
#[test_only]
public fun derive_recording_id_for_testing<CompositionShare>(
    composition: &mut Composition<CompositionShare>,
    master: &Audio,
): UID {
    claim(
        composition.uid_mut_internal(),
        RecordingKey(*master.pcm_digest(), *master.ingester_type()),
    )
}

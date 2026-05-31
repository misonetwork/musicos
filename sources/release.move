// Copyright (c) Unconfirmed Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Represents a music release in MusicOS.
/// A release is a collection of tracks organized into discs, with cover art
/// and revenue distribution configuration.
///
/// ### Key Features:
///
/// - Multi-disc releases with track sequencing
/// - Configurable per-track revenue splits
/// - Revenue distribution to composition and recording royalty pools
/// - State machine: Initialized -> Published
module musicos::release;

use bps::bps;
use musicos::cover_art::CoverArt;
use musicos::disc::Disc;
use musicos::release_kind::ReleaseKind;
use musicos::release_party_role::ReleasePartyRole;
use partyos::credit::Credit;
use partyos::party::Party;
use std::string::String;
use std::type_name::TypeName;
use sui::bcs::to_bytes;
use sui::clock::Clock;
use sui::derived_object::{Self, claim};
use sui::event::emit;
use sui::hash::blake2b256;
use sui::vec_map::{Self, VecMap};

public use fun release_admin_cap_release_id as ReleaseAdminCap.release_id;

// === Structs ===

public struct RELEASE() has drop;

/// A music release containing one or more discs of tracks.
public struct Release has key {
    /// Unique identifier for this release.
    id: UID,
    /// The type of release.
    kind: ReleaseKind,
    /// Current lifecycle state.
    state: ReleaseState,
    /// Title of the release.
    title: String,
    /// Optional subtitle (e.g., "Deluxe Edition").
    subtitle: Option<String>,
    /// Description of the release.
    description: String,
    /// Attribution information for the release.
    credits: VecMap<ID, Credit<ReleasePartyRole>>,
    /// Collection of discs containing tracks.
    discs: vector<Disc>,
    /// Cover artwork for the release.
    cover_art: CoverArt,
}

/// Key for release UID derivation.
public struct ReleaseKey(vector<u8>) has copy, drop, store;

/// A registry that acts as a parent object for release UID derivation.
public struct ReleaseRegistry has key {
    id: UID,
}

/// Capability that authorizes modifications to a specific release.
/// Initialized when a release is registered and transferred to the owner.
public struct ReleaseAdminCap has key, store {
    /// Unique identifier for this capability.
    id: UID,
    /// ID of the release this capability controls.
    release_id: ID,
}

// Derivation key for ReleaseAdminCap.
public struct ReleaseAdminCapKey() has copy, drop, store;

// === Enums ===

/// Lifecycle state of a release.
public enum ReleaseState has copy, drop, store {
    /// Release is initialized but not yet created.
    Initialized(
        /// Indicates if the release has a primary credit.
        bool,
    ),
    /// Release is published and immutable. Includes publication timestamp.
    Published(
        /// Timestamp (ms) when published.
        u64,
    ),
}

// === Events ===

/// Emitted when a party is added to a release.
public struct ReleasePartyAddedEvent has copy, drop {
    release_id: ID,
    party_id: ID,
    credit_display_name: String,
}

/// Emitted for each role assigned to a credited party on a release.
public struct ReleaseCreditRoleAssignedEvent has copy, drop {
    release_id: ID,
    party_id: ID,
    role_name: String,
}

/// Emitted when a release is created.
public struct ReleaseCreatedEvent has copy, drop {
    release_id: ID,
    kind: String,
    title: String,
    subtitle: Option<String>,
    description: String,
    total_discs: u64,
    total_tracks: u64,
    duration_ms: u64,
    cover_art_static_blob_id: u256,
    cover_art_animated_blob_id: Option<u256>,
    created_by: address,
}

/// Emitted for each track when a release is created or published.
public struct ReleaseTrackAddedEvent has copy, drop {
    release_id: ID,
    disc_idx: u64,
    disc_title: Option<String>,
    disc_artwork_static_blob_id: Option<u256>,
    disc_artwork_animated_blob_id: Option<u256>,
    track_idx: u64,
    recording_id: ID,
    composition_id: ID,
    track_title: String,
    track_duration_ms: u64,
    track_cover_art_static_blob_id: u256,
    track_cover_art_animated_blob_id: Option<u256>,
    split_bps_value: u64,
    composition_split_bps_value: u16,
}

/// Emitted when a release is published.
public struct ReleasePublishedEvent has copy, drop {
    release_id: ID,
    kind: String,
    title: String,
    subtitle: Option<String>,
    description: String,
    total_discs: u64,
    total_tracks: u64,
    duration_ms: u64,
    cover_art_static_blob_id: u256,
    cover_art_animated_blob_id: Option<u256>,
    published_at_ms: u64,
    published_by: address,
}

// === Constants ===

/// Number of roles allowed per credit on a release.
const CREDIT_ROLE_COUNT: u64 = 1;
/// Maximum length of a release description in bytes.
const MAX_DESCRIPTION_LENGTH: u64 = 500;
/// Maximum number of discs allowed in a release.
const MAX_DISCS: u64 = 20;
/// Maximum total number of tracks allowed across all discs.
const MAX_TRACKS: u64 = 255;
/// Maximum number of credits allowed on a release.
const MAX_CREDITS: u64 = 50;
/// Maximum length of a release title in bytes.
const MAX_TITLE_LENGTH: u64 = 300;

// === Errors ===

// Authorization errors (0-9)
/// The provided admin capability does not match this release.
const EUnauthorized: u64 = 0;

// State errors (10-19)
/// Operation requires Initialized state.
const ENotInitializedState: u64 = 10;

// Validation errors (20-29)
/// Track splits don't sum to 100% (10,000 BPS).
const EInvalidTrackSplitsSum: u64 = 20;

// Constraint errors (30-39)
/// Too many discs in release.
const EMaxDiscsExceeded: u64 = 30;
/// Too many tracks in release.
const EMaxTracksExceeded: u64 = 31;
/// Too long description in release.
const EMaxDescriptionLengthExceeded: u64 = 32;
/// Release has too many credits.
const EMaxCreditsExceeded: u64 = 33;
/// Title exceeds maximum length.
const EMaxTitleLengthExceeded: u64 = 34;
/// String must not be empty.
const EEmptyString: u64 = 35;

// Reference errors (50-59)
/// Release must contain at least one disc.
const ENoDiscs: u64 = 51;
/// Release must contain at least one credit.
const ENoPrimaryCredit: u64 = 52;
/// Invalid number of roles in credit.
const EInvalidCreditRoleCount: u64 = 53;
const EPartyAlreadyCredited: u64 = 54;

// === Init Function ===

/// Module initializer. Creates and shares the `ReleaseRegistry`.
fun init(_otw: RELEASE, ctx: &mut TxContext) {
    let registry = ReleaseRegistry {
        id: object::new(ctx),
    };

    transfer::share_object(registry);
}

// === Public Functions ===

/// Creates a new release with the given configuration.
/// Returns the release and admin capability.
public fun new(
    kind: ReleaseKind,
    title: String,
    description: String,
    cover_art: CoverArt,
    discs: vector<Disc>,
    nonce: u256,
    registry: &mut ReleaseRegistry,
    ctx: &TxContext,
): (Release, ReleaseAdminCap) {
    assert!(!title.is_empty(), EEmptyString);
    assert!(title.length() <= MAX_TITLE_LENGTH, EMaxTitleLengthExceeded);
    assert!(description.length() <= MAX_DESCRIPTION_LENGTH, EMaxDescriptionLengthExceeded);
    // Assert that the release has at least one disc.
    assert!(!discs.is_empty(), ENoDiscs);
    // Assert that the release doesn't have too many discs.
    assert!(discs.length() <= MAX_DISCS, EMaxDiscsExceeded);

    // Extract digest inputs and validate splits
    let (recording_ids, track_split_values, split_sum) = extract_digest_inputs(&discs);

    // Assert total tracks don't exceed maximum
    assert!(recording_ids.length() <= MAX_TRACKS, EMaxTracksExceeded);

    // Assert that the track splits sum to 100% (10,000 BPS).
    assert!(split_sum == (bps::denominator!() as u64), EInvalidTrackSplitsSum);

    // Calculate the release digest and claim the release UID.
    let release_digest = calculate_release_digest(recording_ids, track_split_values, nonce);
    let release_uid = claim(&mut registry.id, ReleaseKey(release_digest));

    let mut release = Release {
        id: release_uid,
        kind,
        state: ReleaseState::Initialized(false),
        title,
        subtitle: option::none(),
        description,
        credits: vec_map::empty(),
        discs,
        cover_art,
    };

    let release_admin_cap = ReleaseAdminCap {
        id: claim(&mut release.id, ReleaseAdminCapKey()),
        release_id: release.id(),
    };

    let animated_blob_id = if (release.cover_art.animated().is_some()) {
        option::some(release.cover_art.animated().borrow().blob_id())
    } else {
        option::none()
    };

    emit(ReleaseCreatedEvent {
        release_id: release.id(),
        kind: release.kind().name(),
        title: *release.title(),
        subtitle: release.subtitle,
        description: *release.description(),
        total_discs: release.discs.length(),
        total_tracks: release.total_tracks(),
        duration_ms: release.duration_ms(),
        cover_art_static_blob_id: release.cover_art.static().blob_id(),
        cover_art_animated_blob_id: animated_blob_id,
        created_by: ctx.sender(),
    });

    emit_track_events(&release);

    (release, release_admin_cap)
}

/// Adds a credit to the release for a party.
/// Each credit must have exactly one role (Primary or Featured).
/// Required State: Initialized
public fun add_credit(
    self: &mut Release,
    cap: &ReleaseAdminCap,
    party: &Party,
    credit: Credit<ReleasePartyRole>,
) {
    self.authorize(cap);

    match (&mut self.state) {
        ReleaseState::Initialized(has_primary_credit) => {
            assert!(self.credits.length() < MAX_CREDITS, EMaxCreditsExceeded);
            // Assert the credit has a single role (releases only support "Primary" or "Featured").
            assert!(credit.roles().length() == CREDIT_ROLE_COUNT, EInvalidCreditRoleCount);

            // Loop through the credit roles and check if the credit has a primary role.
            // If yes, set the has_primary_credit flag to true.
            credit.roles().do_ref!(|role| {
                if (role.is_primary_role()) {
                    *has_primary_credit = true;
                }
            });

            // Insert the credit into the release credits map.
            let party_id = party.id();
            assert!(!self.credits.contains(&party_id), EPartyAlreadyCredited);
            self.credits.insert(party_id, credit);

            let release_id = self.id();
            emit(ReleasePartyAddedEvent {
                release_id,
                party_id,
                credit_display_name: *credit.display_name(),
            });

            let roles = credit.roles();
            let mut i = 0;
            while (i < roles.length()) {
                emit(ReleaseCreditRoleAssignedEvent {
                    release_id,
                    party_id,
                    role_name: roles[i].name(),
                });
                i = i + 1;
            };
        },
        _ => abort ENotInitializedState,
    }
}

/// Publishes the release, making it immutable.
/// Track splits must be set and sum to 100% before publishing.
/// Required State: Initialized
public fun publish(mut self: Release, cap: &ReleaseAdminCap, clock: &Clock, ctx: &TxContext) {
    self.authorize(cap);

    match (self.state) {
        ReleaseState::Initialized(has_primary_credit) => {
            // Assert that the release has a primary credit.
            assert!(has_primary_credit, ENoPrimaryCredit);
            // Assert that the tracks are assigned to the release.
            self.assert_track_assignments();

            let timestamp_ms = clock.timestamp_ms();

            // Update the release state to published.
            self.state = ReleaseState::Published(timestamp_ms);

            let animated_blob_id = if (self.cover_art.animated().is_some()) {
                option::some(self.cover_art.animated().borrow().blob_id())
            } else {
                option::none()
            };

            emit(ReleasePublishedEvent {
                release_id: self.id(),
                kind: self.kind().name(),
                title: *self.title(),
                subtitle: self.subtitle,
                description: *self.description(),
                total_discs: self.discs.length(),
                total_tracks: self.total_tracks(),
                duration_ms: self.duration_ms(),
                cover_art_static_blob_id: self.cover_art.static().blob_id(),
                cover_art_animated_blob_id: animated_blob_id,
                published_at_ms: timestamp_ms,
                published_by: ctx.sender(),
            });

            transfer::share_object(self);
        },
        _ => abort ENotInitializedState,
    }
}

/// Verifies that the admin capability matches this release.
public fun authorize(self: &Release, cap: &ReleaseAdminCap) {
    assert!(self.id() == cap.release_id, EUnauthorized);
}

// === Public View Functions ===

/// Derives the release ID that `new()` would produce for the given inputs,
/// without creating the object. This is the on-chain equivalent of the
/// client-side `deriveReleaseId()` function.
public fun derive_release_id(
    recording_ids: vector<ID>,
    track_split_values: vector<u64>,
    nonce: u256,
    registry: &ReleaseRegistry,
): ID {
    let release_digest = calculate_release_digest(recording_ids, track_split_values, nonce);
    derived_object::derive_address(registry.id.to_inner(), ReleaseKey(release_digest)).to_id()
}

/// Returns the release's object ID.
public fun id(self: &Release): ID {
    self.id.to_inner()
}

/// Returns the release kind.
public fun kind(self: &Release): &ReleaseKind {
    &self.kind
}

/// Returns the release state.
public fun state(self: &Release): ReleaseState {
    self.state
}

/// Returns true if the release is in the Initialized state.
public fun is_initialized_state(self: &Release): bool {
    match (self.state) {
        ReleaseState::Initialized(_) => true,
        _ => false,
    }
}

/// Returns true if the release is in the Published state.
public fun is_published_state(self: &Release): bool {
    match (self.state) {
        ReleaseState::Published(_) => true,
        _ => false,
    }
}

/// Returns the release title.
public fun title(self: &Release): &String {
    &self.title
}

/// Returns the optional subtitle.
public fun subtitle(self: &Release): &Option<String> {
    &self.subtitle
}

/// Returns the release description.
public fun description(self: &Release): &String {
    &self.description
}

/// Returns a reference to the release credits.
public fun credits(self: &Release): &VecMap<ID, Credit<ReleasePartyRole>> {
    &self.credits
}

/// Returns a reference to all discs.
public fun discs(self: &Release): &vector<Disc> {
    &self.discs
}

/// Returns a reference to the cover art.
public fun cover_art(self: &Release): &CoverArt {
    &self.cover_art
}

/// Returns the total number of tracks across all discs.
public fun total_tracks(self: &Release): u64 {
    let mut count = 0;
    self.discs.do_ref!(|disc| {
        count = count + disc.tracks().length();
    });
    count
}

/// Returns the total duration of all tracks in milliseconds.
public fun duration_ms(self: &Release): u64 {
    let mut duration = 0;
    self.discs.do_ref!(|disc| {
        duration = duration + disc.duration_ms();
    });
    duration
}

public fun audio_ingester_types(self: &Release): vector<TypeName> {
    let mut unique = vector<TypeName>[];

    self.discs.do_ref!(|disc| {
        disc.tracks().do_ref!(|track| {
            // Add the composition's demo audio ingester type.
            track.composition_demo_ingester_type().do_ref!(|t| {
                if (!unique.contains(t)) unique.push_back(*t);
            });
            // Add the recording's master audio ingester type.
            let master = track.recording_master_ingester_type();
            if (!unique.contains(master)) unique.push_back(*master);
            // Add the recording's stem audio ingester types.
            track.recording_stem_ingester_types().do_ref!(|t| {
                if (!unique.contains(t)) unique.push_back(*t);
            });
        });
    });

    unique
}

/// Returns the release ID associated with the admin capability.
public fun release_admin_cap_release_id(cap: &ReleaseAdminCap): ID {
    cap.release_id
}

// === UID Functions ===

/// Returns a reference to the release's UID for reading dynamic fields.
public fun uid(self: &Release): &UID {
    &self.id
}

/// Returns a mutable reference to the release's UID.
/// Requires the admin capability.
public fun uid_mut(self: &mut Release, cap: &ReleaseAdminCap): &mut UID {
    self.authorize(cap);
    &mut self.id
}

public(package) fun uid_mut_internal(self: &mut Release): &mut UID {
    &mut self.id
}

// === Private Functions ===

/// Extracts the recording IDs, split values, and split sum from discs.
/// Used for release digest calculation and split validation.
fun extract_digest_inputs(discs: &vector<Disc>): (vector<ID>, vector<u64>, u64) {
    let mut recording_ids: vector<ID> = vector[];
    let mut track_split_values: vector<u64> = vector[];
    let mut split_sum: u64 = 0;

    discs.do_ref!(|disc| {
        disc.tracks().do_ref!(|track| {
            recording_ids.push_back(track.recording_id());
            // bps::value() returns u16; widen to u64 to preserve digest format.
            let split_value = track.split_bps().value() as u64;
            track_split_values.push_back(split_value);
            split_sum = split_sum + split_value;
        });
    });

    (recording_ids, track_split_values, split_sum)
}

/// Calculates the deterministic release digest from recording IDs, split values, and nonce.
fun calculate_release_digest(
    recording_ids: vector<ID>,
    track_split_values: vector<u64>,
    nonce: u256,
): vector<u8> {
    let mut hash_input = vector<u8>[];
    hash_input.append(to_bytes(&recording_ids));
    hash_input.append(to_bytes(&track_split_values));
    hash_input.append(to_bytes(&nonce));

    blake2b256(&hash_input)
}

/// Emits a `ReleaseTrackAddedEvent` for each track across all discs.
fun emit_track_events(release: &Release) {
    let release_id = release.id();
    release.discs.length().do!(|disc_idx| {
        let disc = &release.discs[disc_idx];
        let disc_title = *disc.title();
        let (disc_artwork_static_blob_id, disc_artwork_animated_blob_id) = if (
            disc.artwork().is_some()
        ) {
            let art = disc.artwork().borrow();
            let animated = if (art.animated().is_some()) {
                option::some(art.animated().borrow().blob_id())
            } else {
                option::none()
            };
            (option::some(art.static().blob_id()), animated)
        } else {
            (option::none(), option::none())
        };
        disc.tracks().length().do!(|track_idx| {
            let track = &disc.tracks()[track_idx];
            let track_cover_art = track.cover_art();
            let track_cover_art_animated_blob_id = if (track_cover_art.animated().is_some()) {
                option::some(track_cover_art.animated().borrow().blob_id())
            } else {
                option::none()
            };
            emit(ReleaseTrackAddedEvent {
                release_id,
                disc_idx,
                disc_title,
                disc_artwork_static_blob_id,
                disc_artwork_animated_blob_id,
                track_idx,
                recording_id: track.recording_id(),
                composition_id: track.composition_id(),
                track_title: *track.title(),
                track_duration_ms: track.duration_ms(),
                track_cover_art_static_blob_id: track_cover_art.static().blob_id(),
                track_cover_art_animated_blob_id,
                split_bps_value: track.split_bps().value() as u64,
                composition_split_bps_value: track.composition_split_bps().value(),
            });
        });
    });
}

/// Assigns all tracks to this release, verifying each track's target release ID matches.
fun assert_track_assignments(self: &mut Release) {
    self.discs.do_mut!(|disc| {
        disc.tracks_mut().do_mut!(|track| { track.assign(&self.id); });
    });
}

// === Test Only ===

#[test_only]
public fun new_release_registry_for_testing(ctx: &mut TxContext): ReleaseRegistry {
    ReleaseRegistry {
        id: object::new(ctx),
    }
}

/// Pre-fills a release with `n` fake credits (bypasses public API validation).
/// The first credit is designated as a primary role.
#[test_only]
public fun prefill_credits_for_testing(self: &mut Release, n: u64, ctx: &mut TxContext) {
    use partyos::credit;
    use musicos::release_party_role;

    n.do!(|i| {
        let uid = object::new(ctx);
        let id = uid.to_inner();
        uid.delete();
        let role = if (i == 0) {
            release_party_role::new_primary_role()
        } else {
            release_party_role::new_featured_role()
        };
        let credit = credit::new(
            b"Test".to_string(),
            vector[role],
        );
        self.credits.insert(id, credit);
        // Set has_primary_credit flag for the first credit
        if (i == 0) {
            self.state = ReleaseState::Initialized(true);
        };
    });
}

#[test_only]
public fun new_for_testing(
    kind: ReleaseKind,
    title: String,
    description: String,
    cover_art: CoverArt,
    discs: vector<Disc>,
    ctx: &mut TxContext,
): (Release, ReleaseAdminCap) {
    use musicos::track;

    let mut release = Release {
        id: object::new(ctx),
        kind,
        state: ReleaseState::Initialized(false),
        title,
        subtitle: option::none(),
        description,
        credits: vec_map::empty(),
        discs,
        cover_art,
    };

    // Patch all tracks to point to this release's ID so publish() can assign them.
    let release_id = release.id();
    release.discs.do_mut!(|disc| {
        disc.tracks_mut().do_mut!(|t| {
            track::set_release_id_for_testing(t, release_id);
        });
    });

    let release_admin_cap = ReleaseAdminCap {
        id: claim(&mut release.id, ReleaseAdminCapKey()),
        release_id: release.id(),
    };

    (release, release_admin_cap)
}

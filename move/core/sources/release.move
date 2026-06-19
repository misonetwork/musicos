// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Represents a music release in Miso.
/// A release is a collection of tracks organized into discs, with cover art
/// and revenue distribution configuration.
///
/// ### Key Features:
///
/// - Multi-disc releases with track sequencing
/// - Configurable per-track revenue splits
/// - State machine: Initialized -> Published
///
/// Attribution (credits, primary/featured artists) is intentionally NOT part of
/// core: it is display-oriented, varies across platforms, and is never read by
/// the economics. It lives in a first-party credits extension attached via
/// `uid_mut`, so core takes no dependency on an identity package and core
/// publish enforces no attribution.
module miso::release;

use bps::bps;
use miso::disc::Disc;
use std::string::String;
use sui::bcs::to_bytes;
use sui::clock::Clock;
use sui::derived_object::{Self, claim};
use sui::event::emit;
use sui::hash::blake2b256;

public use fun release_admin_cap_release_id as ReleaseAdminCap.release_id;

// === Structs ===

public struct RELEASE() has drop;

/// A music release containing one or more discs of tracks.
public struct Release has key {
    /// Unique identifier for this release.
    id: UID,
    /// Current lifecycle state.
    state: ReleaseState,
    /// Title of the release.
    title: String,
    /// Optional subtitle (e.g., "Deluxe Edition").
    subtitle: Option<String>,
    /// Collection of discs containing tracks.
    discs: vector<Disc>,
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
    /// Release is initialized but not yet published.
    Initialized,
    /// Release is published and immutable. Includes publication timestamp.
    Published(
        /// Timestamp (ms) when published.
        u64,
    ),
}

// === Events ===

/// Emitted once when a release is published. A pure pointer: it carries the
/// release's identity. A release's embedded fields (discs, tracks) are
/// immutable after publishing, so an indexer treats this as a signal to
/// fetch the full object by `release_id`; all indexed data — including the
/// publish timestamp — lives in the object itself. Dynamic fields (e.g.
/// credits attached by the credits extension) may still be attached afterward.
public struct ReleasePublishedEvent has copy, drop {
    release_id: ID,
}

// === Constants ===

/// Maximum number of discs allowed in a release.
const MAX_DISCS: u64 = 20;
/// Maximum total number of tracks allowed across all discs.
const MAX_TRACKS: u64 = 255;
/// Maximum length of a release title in bytes.
const MAX_TITLE_LENGTH: u64 = 300;
/// Maximum length of a release subtitle in bytes.
const MAX_SUBTITLE_LENGTH: u64 = 300;

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
/// Title exceeds maximum length.
const EMaxTitleLengthExceeded: u64 = 34;
/// String must not be empty.
const EEmptyString: u64 = 35;
/// Subtitle exceeds maximum length.
const EMaxSubtitleLengthExceeded: u64 = 36;

// Reference errors (50-59)
/// Release must contain at least one disc.
const ENoDiscs: u64 = 51;

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
    title: String,
    discs: vector<Disc>,
    nonce: u256,
    registry: &mut ReleaseRegistry,
): (Release, ReleaseAdminCap) {
    assert!(!title.is_empty(), EEmptyString);
    assert!(title.length() <= MAX_TITLE_LENGTH, EMaxTitleLengthExceeded);
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
        state: ReleaseState::Initialized,
        title,
        subtitle: option::none(),
        discs,
    };

    let release_admin_cap = ReleaseAdminCap {
        id: claim(&mut release.id, ReleaseAdminCapKey()),
        release_id: release.id(),
    };

    (release, release_admin_cap)
}

/// Sets the subtitle of the release (e.g., "Deluxe Edition").
/// A subtitle is part of the release's identity — it distinguishes which
/// edition this release is — so it lives in the frozen embedded fields.
/// Required State: Initialized
public fun set_subtitle(self: &mut Release, cap: &ReleaseAdminCap, subtitle: String) {
    self.authorize(cap);

    match (self.state) {
        ReleaseState::Initialized => {
            assert!(!subtitle.is_empty(), EEmptyString);
            assert!(subtitle.length() <= MAX_SUBTITLE_LENGTH, EMaxSubtitleLengthExceeded);
            self.subtitle.swap_or_fill(subtitle);
        },
        _ => abort ENotInitializedState,
    }
}

/// Publishes the release, making it immutable.
/// Track splits must be set and sum to 100% before publishing.
/// Required State: Initialized
///
/// Note: core enforces no attribution requirement — credits live in the credits
/// extension and may be attached before or after publish via `uid_mut`.
public fun publish(mut self: Release, cap: &ReleaseAdminCap, clock: &Clock) {
    self.authorize(cap);

    match (self.state) {
        ReleaseState::Initialized => {
            // Assert that the tracks are assigned to the release.
            self.assert_track_assignments();

            let timestamp_ms = clock.timestamp_ms();

            // Update the release state to published.
            self.state = ReleaseState::Published(timestamp_ms);

            emit(ReleasePublishedEvent {
                release_id: self.id(),
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

/// Returns the release state.
public fun state(self: &Release): ReleaseState {
    self.state
}

/// Returns true if the release is in the Initialized state.
public fun is_initialized_state(self: &Release): bool {
    match (self.state) {
        ReleaseState::Initialized => true,
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

/// Returns a reference to all discs.
public fun discs(self: &Release): &vector<Disc> {
    &self.discs
}

/// Returns the total number of tracks across all discs.
public fun total_tracks(self: &Release): u64 {
    let mut count = 0;
    self.discs.do_ref!(|disc| {
        count = count + disc.tracks().length();
    });
    count
}

/// Returns whether the release contains a track for the given recording.
public fun contains_recording(self: &Release, recording_id: ID): bool {
    self.discs.any!(|disc| disc.tracks().any!(|track| track.recording_id() == recording_id))
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
/// Requires the admin capability. Works in any lifecycle state — dynamic
/// fields are the extension surface (e.g. credits) and stay admin-mutable
/// after publish; only the embedded fields are frozen.
public fun uid_mut(self: &mut Release, cap: &ReleaseAdminCap): &mut UID {
    self.authorize(cap);
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

/// Assigns all tracks to this release, verifying each track's target release ID matches.
fun assert_track_assignments(self: &mut Release) {
    self.discs.do_mut!(|disc| {
        disc.tracks_mut().do_mut!(|track| { track.assign(&self.id); });
    });
}

// === Test Only ===

/// Runs the real module initializer (creates and shares the `ReleaseRegistry`).
#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(RELEASE(), ctx);
}

#[test_only]
public fun new_release_registry_for_testing(ctx: &mut TxContext): ReleaseRegistry {
    ReleaseRegistry {
        id: object::new(ctx),
    }
}

#[test_only]
public fun new_for_testing(
    title: String,
    discs: vector<Disc>,
    ctx: &mut TxContext,
): (Release, ReleaseAdminCap) {
    use miso::track;

    let mut release = Release {
        id: object::new(ctx),
        state: ReleaseState::Initialized,
        title,
        subtitle: option::none(),
        discs,
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

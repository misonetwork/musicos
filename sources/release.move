// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Represents a music release in Miso.
/// A release is an ordered tracklist with per-track revenue distribution
/// configuration. Cover art lives in the `cover_art` extension, not in core.
///
/// The tracklist is deliberately FLAT — a `vector<Track>` with no disc
/// structure. Grouping a sequence into discs, vinyl sides, acts, or movements
/// is a property of a distribution medium, not of the release: it has more
/// than one correct rendering, which makes it presentation, and presentation
/// lives in the metadata extension. A consequence worth stating: the stored
/// tracklist and the digest pre-image have the same shape, so what signers
/// consented to is exactly what is stored — nothing structural is chosen
/// after consent except the title.
///
/// ### Key Features:
///
/// - Ordered flat tracklist (grouping is presentation, in the metadata extension)
/// - Configurable per-track revenue splits
/// - State machine: Initialized -> Published
///
/// Attribution (credits, primary/featured artists) is intentionally NOT part of
/// core: it is display-oriented, varies across platforms, and is never read by
/// the economics. It lives in a first-party credits extension attached via
/// `uid_mut`, so core takes no dependency on an identity package and core
/// publish enforces no attribution.
///
/// The same rule governs naming. Core stores what a thing *is* — identity and
/// everything the economics read; extensions describe it. The release's `title`
/// is the one embedded name: it is constitutive (naming the package is part of
/// creating it) and freezing it at publish is a buyer-facing guarantee. Edition
/// naming ("Deluxe Edition"), disc titles, localized titles, and DSP-shaped
/// slots all have more than one correct rendering — presentation — and live in
/// the metadata extension.
///
/// ### Consent scope
///
/// The release digest — and therefore the derived release id every `Track`
/// commits to at creation — binds the economics and membership of the
/// release: the ordered list of `(recording, split)` pairs and the creator's
/// nonce. It deliberately binds nothing else. The title — the one embedded
/// field outside the digest — and everything in the extension layer (artwork,
/// credits, display grouping) are chosen by the release creator, before or
/// after tracks are created, and are trusted and publicly attributable rather
/// than cryptographically committed. See `track::new` for the signer-side
/// statement of this boundary.
///
/// The derived id commits to a `(parent, digest)` pair, not the digest alone
/// — so targeting an id also consents to that namespace's liveness. If the
/// parent object is deleted, or its `&mut UID` becomes permanently
/// unreachable, the release can never exist and every track or offer
/// targeting it is stranded — the same blast-radius class as a release that
/// simply never publishes. A coordinator meant to serve as the default
/// parent namespace should therefore be shared and undeletable.
///
/// ### Lifecycle and trust model
///
/// A release is `key`-only with no `drop`: a fresh `Initialized` object
/// cannot be transferred, wrapped, publicly shared, or discarded, and its only
/// by-value consumer is `publish`. Create-and-publish is therefore atomic by
/// construction — an `Initialized` release cannot outlive its creating
/// transaction, and every release that exists on-chain is `Published` and
/// shared. There is deliberately no keep function; assembling tracks, discs,
/// and the release must fit one transaction.
///
/// `uid_mut` works in any lifecycle state and is permanent root over ALL
/// dynamic fields on the object — including fields attached by other
/// extensions. "Immutable after publish" covers the embedded fields only;
/// extension-layer data stays admin-mutable in perpetuity. This is the
/// designed extension surface, and it is the one trust assumption that never
/// expires: integrators should model the cap holder as able to mutate or
/// delete any extension data, forever.
module miso::release;

use bps::bps;
use miso::track::Track;
use std::string::String;
use sui::bcs::to_bytes;
use sui::clock::Clock;
use sui::derived_object::{Self, claim};
use sui::event::emit;
use sui::hash::blake2b256;

public use fun release_admin_cap_release_id as ReleaseAdminCap.release_id;

// === Structs ===

/// A music release containing one or more discs of tracks.
public struct Release has key {
    /// Unique identifier for this release.
    id: UID,
    /// Current lifecycle state.
    state: ReleaseState,
    /// Title of the release.
    title: String,
    /// The ordered tracklist. Same shape as the digest pre-image every track's
    /// creator consented to; display grouping lives in the metadata extension.
    tracks: vector<Track>,
}

/// Key for release UID derivation.
public struct ReleaseKey(vector<u8>) has copy, drop, store;

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
///
/// There is deliberately no `ReleaseCreatedEvent`: an `Initialized` release
/// exists only inside its creating transaction (create-and-publish is atomic),
/// so publish is the one lifecycle moment an observer can ever see. Pre-publish
/// correlation, where an integrator needs it, is an offer extension's
/// responsibility — core's one observable lifecycle moment remains publish.
public struct ReleasePublishedEvent has copy, drop {
    release_id: ID,
}

// === Constants ===

/// Maximum number of tracks allowed in a release.
const MAX_TRACKS: u64 = 255;
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
/// Too many tracks in release.
const EMaxTracksExceeded: u64 = 31;
/// Title exceeds maximum length.
const EMaxTitleLengthExceeded: u64 = 34;
/// String must not be empty.
const EEmptyString: u64 = 35;

// Reference errors (50-59)
/// Release must contain at least one track.
const ENoTracks: u64 = 51;

// === Public Functions ===

/// Creates a new release with the given configuration.
/// Claims the release's UID as a derived child of `parent`, keyed by the
/// release digest (see the module doc's "Consent scope" section) — so
/// contention is per-parent, and which object serves as parent is entirely
/// the caller's choice.
/// Returns the release and admin capability.
public fun new(
    title: String,
    tracks: vector<Track>,
    nonce: u256,
    parent: &mut UID,
): (Release, ReleaseAdminCap) {
    assert!(!title.is_empty(), EEmptyString);
    assert!(title.length() <= MAX_TITLE_LENGTH, EMaxTitleLengthExceeded);
    // Assert that the release has at least one track and not too many.
    assert!(!tracks.is_empty(), ENoTracks);
    assert!(tracks.length() <= MAX_TRACKS, EMaxTracksExceeded);

    // Extract digest inputs and validate splits
    let (recording_ids, track_split_values, split_sum) = extract_digest_inputs(&tracks);

    // Assert that the track splits sum to 100% (10,000 BPS).
    assert!(split_sum == (bps::denominator!() as u64), EInvalidTrackSplitsSum);

    // Calculate the release digest and claim the release UID.
    let release_digest = calculate_release_digest(recording_ids, track_split_values, nonce);
    let release_uid = claim(parent, ReleaseKey(release_digest));

    let mut release = Release {
        id: release_uid,
        state: ReleaseState::Initialized,
        title,
        tracks,
    };

    let release_admin_cap = ReleaseAdminCap {
        id: claim(&mut release.id, ReleaseAdminCapKey()),
        release_id: release.id(),
    };

    (release, release_admin_cap)
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

/// Derives the target release ID that `new()` would produce for the given
/// inputs and parent, without creating the object. This is the on-chain
/// equivalent of the client-side `deriveReleaseId()` function.
public fun derive_target_release_id(
    recording_ids: vector<ID>,
    track_split_values: vector<u64>,
    nonce: u256,
    parent: ID,
): ID {
    let release_digest = calculate_release_digest(recording_ids, track_split_values, nonce);
    derived_object::derive_address(parent, ReleaseKey(release_digest)).to_id()
}

/// Returns the release's object ID.
public fun id(self: &Release): ID {
    self.id.to_inner()
}

/// Returns the release title.
public fun title(self: &Release): &String {
    &self.title
}

/// Returns a reference to the ordered tracklist. The single tracklist
/// accessor — consumers derive length, membership, and per-track data from it
/// (`tracks().length()`, `tracks().any!(..)`, indexing).
public fun tracks(self: &Release): &vector<Track> {
    &self.tracks
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
/// after publish; only the embedded fields are frozen. The reference is root
/// over every dynamic field on the object, including fields attached by
/// other extensions.
public fun uid_mut(self: &mut Release, cap: &ReleaseAdminCap): &mut UID {
    self.authorize(cap);
    &mut self.id
}

// === Private Functions ===

/// Extracts the recording IDs, split values, and split sum from the tracklist.
/// Used for release digest calculation and split validation. The vectors mirror
/// the tracklist ordering exactly — the digest pre-image IS the stored shape.
fun extract_digest_inputs(tracks: &vector<Track>): (vector<ID>, vector<u64>, u64) {
    let recording_ids = tracks.map_ref!(|track| track.recording_id());
    // bps::value() returns u16; widen to u64 to preserve digest format.
    let track_split_values = tracks.map_ref!(|track| track.split_bps().value() as u64);
    let split_sum = track_split_values.fold!(0u64, |accumulator, value| accumulator + value);

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
    self.tracks.do_mut!(|track| track.assign(&self.id));
}

// === Test Only ===

// The state predicates are test-only: create-and-publish is atomic (see the
// module doc), so every release any runtime caller can hold is `Published` —
// the answer is known a priori and a public accessor would carry no
// information. Tests still need them to verify the transition itself.

#[test_only]
public fun is_initialized_state(self: &Release): bool {
    match (self.state) {
        ReleaseState::Initialized => true,
        _ => false,
    }
}

#[test_only]
public fun is_published_state(self: &Release): bool {
    match (self.state) {
        ReleaseState::Published(_) => true,
        _ => false,
    }
}

#[test_only]
public fun new_for_testing(
    title: String,
    tracks: vector<Track>,
    ctx: &mut TxContext,
): (Release, ReleaseAdminCap) {
    use miso::track;

    let mut release = Release {
        id: object::new(ctx),
        state: ReleaseState::Initialized,
        title,
        tracks,
    };

    // Patch all tracks to point to this release's ID so publish() can assign them.
    let release_id = release.id();
    release.tracks.do_mut!(|t| track::set_target_release_id_for_testing(t, release_id));

    let release_admin_cap = ReleaseAdminCap {
        id: claim(&mut release.id, ReleaseAdminCapKey()),
        release_id: release.id(),
    };

    (release, release_admin_cap)
}

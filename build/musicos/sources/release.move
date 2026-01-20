// Copyright (c) Studio Mirai, LLC
// SPDX-License-Identifier: Apache-2.0

/// Represents a music release (album, EP, or single) in MusicOS.
/// A release is a collection of tracks organized into discs, with cover art
/// and revenue distribution configuration.
///
/// Key features:
/// - Support for albums, EPs, and singles
/// - Multi-disc releases with track sequencing
/// - Configurable per-track revenue splits
/// - Revenue distribution to composition and recording royalty pools
/// - State machine: Initialized -> Published
module musicos::release;

use interest_bps::bps::{Self, BPS};
use musicos::cover_art::CoverArt;
use musicos::disc::Disc;
use musicos::plugin;
use musicos::track_position::TrackPosition;
use musicos::track_sequence::{Self, TrackSequence};
use std::string::String;
use std::type_name::TypeName;
use sui::balance::{withdraw_funds_from_object, redeem_funds};
use sui::clock::Clock;
use sui::derived_object::claim;
use sui::event::emit;

//=== Structs ===

/// A music release containing one or more discs of tracks.
public struct Release has key {
    /// Unique identifier for this release.
    id: UID,
    /// Type of release (Album, EP, or Single).
    kind: ReleaseKind,
    /// Current lifecycle state.
    state: ReleaseState,
    /// Title of the release.
    title: String,
    /// Optional subtitle (e.g., "Deluxe Edition").
    subtitle: Option<String>,
    /// Collection of discs containing tracks.
    discs: vector<Disc>,
    /// Navigation structure for track ordering.
    track_sequence: TrackSequence,
    /// Revenue split for each track in basis points (must sum to 100%).
    track_splits_bps: vector<BPS>,
    /// Cover artwork for the release.
    cover_art: CoverArt,
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
public struct RelaseAdminCapKey() has copy, drop, store;

/// Revenue split information for a single track.
#[allow(unused_field)]
public struct TrackSplit has copy, drop, store {
    /// Position of the track in the release.
    track_position: TrackPosition,
    /// ID of the track's composition.
    composition_id: ID,
    /// Share token type for the composition.
    composition_share_type: TypeName,
    /// Revenue amount for the composition.
    composition_split_value: u64,
    /// ID of the track's recording.
    recording_id: ID,
    /// Share token type for the recording.
    recording_share_type: TypeName,
    /// Revenue amount for the recording.
    recording_split_value: u64,
}

//=== Events ===

/// Emitted when a release is published.
public struct ReleasePublishedEvent has copy, drop {
    /// ID of the published release.
    release_id: ID,
    /// Timestamp (ms) when published.
    timestamp_ms: u64,
    /// Address of the sender.
    sender: address,
}

/// Emitted when revenue is distributed for a track.
public struct ReleaseRevenueDistributedEvent<phantom C> has copy, drop {
    /// ID of the release.
    release_id: ID,
    /// ID of the composition receiving revenue.
    composition_id: ID,
    /// Amount distributed to the composition.
    composition_split_value: u64,
    /// ID of the recording receiving revenue.
    recording_id: ID,
    /// Amount distributed to the recording.
    recording_split_value: u64,
}

/// Emitted when a track payment is completed.
#[allow(unused_field)]
public struct ReleaseTrackPaidEvent<phantom C, phantom CS, phantom RS> has copy, drop {
    /// ID of the release.
    release_id: ID,
    /// Total value distributed.
    distribution_value: u64,
}

//=== Enums ===

/// The type of music release.
public enum ReleaseKind has copy, drop, store {
    /// Full-length album (typically 7+ tracks).
    Album,
    /// Extended play (typically 3-6 tracks).
    EP,
    /// Single release (typically 1-2 tracks).
    Single,
}

/// Lifecycle state of a release.
public enum ReleaseState has copy, drop, store {
    /// Release is initialized but not yet created.
    Initialized,
    /// Release is published and immutable. Includes publication timestamp.
    Published(
        /// Timestamp (ms) when published.
        u64,
    ),
}

//=== Constants ===

const MAX_DISCS: u8 = 20;

//=== Errors ===

/// The provided admin capability does not match this release.
const EUnauthorized: u64 = 0;
/// Operation requires Initialized state.
const ENotInitializedState: u64 = 1;
/// Operation requires Published state.
const ENotPublishedState: u64 = 2;
/// Too many discs in release.
const EMaxDiscsReached: u64 = 10;
/// Track splits count doesn't match track count.
const EInvalidTrackSplitsLength: u64 = 20;
/// Track splits don't sum to 100% (10,000 BPS).
const EInvalidTrackSplitsSum: u64 = 21;
/// Revenue pool has no funds to distribute.
const ENoRevenueToDistribute: u64 = 22;

//=== Public Functions ===

/// Creates a new release with the given configuration.
/// Returns the release, admin capability, and a promise that must be consumed.
public fun new(
    kind: ReleaseKind,
    title: String,
    cover_art: CoverArt,
    discs: vector<Disc>,
    ctx: &mut TxContext,
): (Release, ReleaseAdminCap) {
    assert!(discs.length() <= MAX_DISCS as u64, EMaxDiscsReached);

    // Build a track sequence for the release based on the number of discs.
    let track_sequence = track_sequence::new(&discs);

    let mut release = Release {
        id: object::new(ctx),
        kind,
        state: ReleaseState::Initialized,
        title,
        subtitle: option::none(),
        discs,
        track_sequence,
        track_splits_bps: vector[],
        cover_art,
    };

    let release_admin_cap = ReleaseAdminCap {
        id: claim(&mut release.id, RelaseAdminCapKey()),
        release_id: release.id(),
    };

    (release, release_admin_cap)
}

/// Publishes the release, making it immutable.
/// Track splits must be set and sum to 100% before publishing.
/// Required State: Initialized
public fun publish(mut self: Release, cap: &ReleaseAdminCap, clock: &Clock, ctx: &TxContext) {
    self.authorize(cap);

    match (self.state) {
        ReleaseState::Initialized => {
            // Assert that the number of track splits matches the number of tracks.
            assert_track_splits_bps_length(self.track_splits_bps, &self.track_sequence);
            // Assert that the track splits sum to 100% (10,000 BPS).
            assert_track_splits_bps_sum(self.track_splits_bps);

            let timestamp_ms = clock.timestamp_ms();

            // Update the release state to published.
            self.state = ReleaseState::Published(timestamp_ms);

            emit(ReleasePublishedEvent {
                release_id: self.id(),
                timestamp_ms,
                sender: ctx.sender(),
            });

            transfer::share_object(self);
        },
        _ => abort ENotInitializedState,
    }
}

/// Sets the revenue splits for each track.
/// The number of splits must match the track count, and they must sum to 100%.
/// Required State: Initialized
public fun set_track_splits_bps(
    self: &mut Release,
    cap: &ReleaseAdminCap,
    track_splits_bps_values: vector<u64>,
) {
    self.authorize(cap);

    match (self.state) {
        ReleaseState::Initialized => {
            let track_splits_bps = track_splits_bps_values.map!(|value| bps::new(value));

            assert_track_splits_bps_length(track_splits_bps, &self.track_sequence);
            assert_track_splits_bps_sum(track_splits_bps);

            self.track_splits_bps = track_splits_bps;
        },
        _ => abort ENotInitializedState,
    }
}

/// Distributes revenue from the release's revenue pool to composition and recording royalty pools.
/// Splits revenue according to track splits.
/// Each track's revenue is further split between its composition and recording based on their split ratio.
/// Required State: Published
public fun distribute_revenue<C>(self: &mut Release, value: u64) {
    match (self.state) {
        ReleaseState::Published(_) => {
            // Acquire a mutable reference to the revenue pool's balance.
            // This will abort if the provided revenue pool is not the correct one for the release
            // because revenue_pool.balance_mut() performs an authorization check internally.
            let release_id = self.id();

            let withdrawal = withdraw_funds_from_object<C>(&mut self.id, value);
            let mut revenue = redeem_funds(withdrawal);

            assert!(revenue.value() > 0, ENoRevenueToDistribute);

            // Store the distribution's principal value.
            let distribution_value = revenue.value();

            self.track_sequence.length().do!(|i| {
                // Derive the track identifier for the given track sequence index.
                let track_position = self.track_sequence.track_positions()[i as u64];

                // Fetch the disc and track with the track identifier.
                let disc = &self.discs[track_position.disc_idx() as u64];
                let track = &disc.tracks()[track_position.track_idx() as u64];

                // Fetch the track split rate for the given track sequence index.
                let track_split_bps = self.track_splits_bps[i as u64];

                if (track_split_bps.value() > 0) {
                    let rec_split_value = track_split_bps.calc(distribution_value);
                    let mut rec_split_balance = revenue.split(rec_split_value);

                    // Calculate the composition's revenue share, and split the value from the recording's revenue.
                    // Use rec_split_value directly since split() guarantees the exact amount requested.
                    let comp_split_value = track.composition_split_bps().calc(rec_split_value);
                    let comp_split_balance = rec_split_balance.split(comp_split_value);

                    let composition_id = track.composition_id();
                    let recording_id = track.recording_id();

                    emit(ReleaseRevenueDistributedEvent<C> {
                        release_id,
                        composition_id,
                        composition_split_value: comp_split_balance.value(),
                        recording_id,
                        recording_split_value: rec_split_balance.value(),
                    });

                    rec_split_balance.send_funds(recording_id.to_address());
                    comp_split_balance.send_funds(composition_id.to_address());
                };
            });

            // Transfer dust back to the release.
            revenue.send_funds(release_id.to_address());
        },
        _ => abort ENotPublishedState,
    }
}

//=== Public View Functions ===

/// Returns the release's object ID.
public fun id(self: &Release): ID {
    self.id.to_inner()
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

/// Returns a reference to the track sequence.
public fun track_sequence(self: &Release): &TrackSequence {
    &self.track_sequence
}

/// Returns a reference to the track splits in basis points.
public fun track_splits_bps(self: &Release): &vector<BPS> {
    &self.track_splits_bps
}

/// Returns the release kind (Album, EP, or Single).
public fun kind(self: &Release): ReleaseKind {
    self.kind
}

/// Returns the release state.
public fun state(self: &Release): ReleaseState {
    self.state
}

/// Returns a reference to the cover art.
public fun cover_art(self: &Release): &CoverArt {
    &self.cover_art
}

//=== UID Functions ===

/// Returns a reference to the release's UID for reading dynamic fields.
public fun uid(self: &Release): &UID {
    &self.id
}

/// Returns a mutable reference to the release's UID for dynamic field operations.
/// Requires the admin capability.
public fun uid_mut(self: &mut Release, cap: &ReleaseAdminCap): &mut UID {
    self.authorize(cap);
    &mut self.id
}

/// Returns a mutable reference to the release's UID for authorized plugins.
/// Requires a witness from the plugin module.
public fun uid_mut_authorized<P: drop>(self: &mut Release, _: P): &mut UID {
    plugin::assert_authorized<P>(&self.id);
    &mut self.id
}

//=== Private Functions ===

/// Verifies that the admin capability matches this release.
fun authorize(self: &Release, cap: &ReleaseAdminCap) {
    assert!(self.id() == cap.release_id, EUnauthorized);
}

/// Asserts that the number of track splits matches the number of tracks.
fun assert_track_splits_bps_length(track_splits_bps: vector<BPS>, track_sequence: &TrackSequence) {
    assert!(track_splits_bps.length() == track_sequence.length() as u64, EInvalidTrackSplitsLength);
}

/// Asserts that the track splits sum to 100% (10,000 BPS).
fun assert_track_splits_bps_sum(track_splits_bps: vector<BPS>) {
    assert!(
        track_splits_bps.fold!(0, |acc, split_bps| acc + split_bps.value()) == bps::max_value!(),
        EInvalidTrackSplitsSum,
    );
}

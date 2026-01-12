// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Represents a music release (album, EP, or single) in the MusicOS protocol.
/// A release is a collection of tracks organized into discs, with cover art
/// and revenue distribution configuration.
///
/// Key features:
/// - Support for albums, EPs, and singles
/// - Multi-disc releases with track sequencing
/// - Configurable per-track revenue splits
/// - Revenue distribution to composition and recording reward pools
/// - State machine: Created -> Created -> Published
module musicos::release;

use musicos::bps::{Self, BPS};
use musicos::cover_art::CoverArt;
use musicos::disc::Disc;
use musicos::protocol::Protocol;
use musicos::track_identifier::TrackIdentifier;
use musicos::track_sequence::{Self, TrackSequence};
use revenue_pool::revenue_pool::{Self, RevenuePool};
use reward_pool::reward_pool;
use std::string::String;
use std::type_name::{TypeName, with_defining_ids};
use sui::balance::Balance;
use sui::clock::Clock;
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
    /// Duration of the release in milliseconds.
    duration: u64,
    /// Collection of discs containing tracks.
    discs: vector<Disc>,
    /// Navigation structure for track ordering.
    track_sequence: TrackSequence,
    /// Revenue split for each track (must sum to 100%).
    track_splits: vector<BPS>,
    /// Cover artwork for the release.
    cover_art: CoverArt,
}

/// Capability that authorizes modifications to a specific release.
/// Created when a release is registered and transferred to the owner.
public struct ReleaseAdminCap has key, store {
    /// Unique identifier for this capability.
    id: UID,
    /// ID of the release this capability controls.
    release_id: ID,
}

/// Promise that ensures a release is shared after creation.
/// Must be consumed by calling `share()`.
public struct ShareReleasePromise(
    /// ID of the release to be shared.
    ID,
)

/// Manifest for distributing revenue from a release.
/// Used internally during the distribution process.
#[allow(unused_field)]
public struct ReleaseRevenueDistributionManifest<phantom Currency> {
    /// ID of the release being distributed.
    release_id: ID,
    /// Balance being distributed.
    distribution_balance: Balance<Currency>,
    /// Total value being distributed.
    distribution_value: u64,
    /// Per-track split information.
    track_splits: vector<TrackSplit>,
}

/// Revenue split information for a single track.
#[allow(unused_field)]
public struct TrackSplit has copy, drop, store {
    /// Position of the track in the release.
    track_identifier: TrackIdentifier,
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

/// Emitted when a new release is created.
public struct ReleaseCreatedEvent has copy, drop {
    /// ID of the created release.
    release_id: ID,
}

/// Emitted when revenue is distributed for a track.
public struct ReleaseRevenueDistributedEvent<phantom Currency> has copy, drop {
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
public struct ReleaseTrackPaidEvent<
    phantom Currency,
    phantom CompShare,
    phantom RecShare,
> has copy, drop {
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
    /// Release has been created but not yet published.
    Created,
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
/// Operation requires Created state.
const ENotCreatedState: u64 = 1;
/// Operation requires Published state.
const ENotPublishedState: u64 = 2;
/// Promise does not match this release's ID.
const EInvalidReleaseForPromise: u64 = 3;
/// Track splits count doesn't match track count.
const EInvalidTrackSplitsLength: u64 = 4;
/// Track splits don't sum to 100% (10,000 BPS).
const EInvalidTrackSplitsSum: u64 = 5;
/// Revenue pool has no funds to distribute.
const ENoRevenueToDistribute: u64 = 6;
/// Too many discs in release.
const EMaxDiscsReached: u64 = 7;

//=== Public Functions ===

/// Creates a new release with the given configuration.
/// Returns the release, admin capability, and a promise that must be consumed.
public fun new(
    kind: ReleaseKind,
    title: String,
    cover_art: CoverArt,
    discs: vector<Disc>,
    ctx: &mut TxContext,
): (Release, ReleaseAdminCap, ShareReleasePromise) {
    assert!(discs.length() <= MAX_DISCS as u64, EMaxDiscsReached);

    // Build a track sequence for the release based on the number of discs.
    let (track_sequence, duration) = track_sequence::new(&discs);

    let release = Release {
        id: object::new(ctx),
        kind,
        state: ReleaseState::Created,
        title,
        subtitle: option::none(),
        duration,
        discs,
        track_sequence,
        track_splits: vector[],
        cover_art,
    };

    let release_admin_cap = ReleaseAdminCap {
        id: object::new(ctx),
        release_id: release.id(),
    };

    let share_release_promise = ShareReleasePromise(release.id());

    (release, release_admin_cap, share_release_promise)
}

/// Converts the release into a shared object.
/// Consumes the promise returned by `new()`.
/// Required State: Created
public fun share(mut self: Release, share_release_promise: ShareReleasePromise) {
    match (self.state) {
        ReleaseState::Created => {
            let ShareReleasePromise(release_id) = share_release_promise;
            assert!(self.id() == release_id, EInvalidReleaseForPromise);

            self.state = ReleaseState::Created;

            emit(ReleaseCreatedEvent {
                release_id: self.id(),
            });

            transfer::share_object(self);
        },
        _ => abort ENotCreatedState,
    }
}

/// Publishes the release, making it immutable.
/// Track splits must be set and sum to 100% before publishing.
/// Required State: Created
public fun publish(self: &mut Release, cap: &ReleaseAdminCap, clock: &Clock) {
    self.authorize(cap);

    match (self.state) {
        ReleaseState::Created => {
            self.assert_track_splits_length();
            self.assert_track_splits_sum();

            self.state = ReleaseState::Published(clock.timestamp_ms());
        },
        _ => abort ENotCreatedState,
    }
}

/// Sets the revenue splits for each track.
/// The number of splits must match the track count, and they must sum to 100%.
/// Required State: Created
public fun set_track_splits(self: &mut Release, cap: &ReleaseAdminCap, track_splits: vector<BPS>) {
    self.authorize(cap);

    match (self.state) {
        ReleaseState::Created => {
            self.track_splits = track_splits;

            self.assert_track_splits_length();
            self.assert_track_splits_sum();
        },
        _ => abort ENotCreatedState,
    }
}

/// Distributes revenue from the release's revenue pool to composition and recording reward pools.
/// Takes a protocol commission and splits the remainder according to track splits.
/// Each track's revenue is further split between its composition and recording based on their split ratio.
/// Required State: Published
public fun distribute_revenue<Currency>(
    self: &Release,
    revenue_pool: &mut RevenuePool<Currency>,
    protocol: &Protocol,
) {
    match (self.state) {
        ReleaseState::Published(_) => {
            // Acquire a mutable reference to the revenue pool's balance.
            // This will abort if the provided revenue pool is not the correct one for the release
            // because revenue_pool.balance_mut() performs an authorization check internally.
            let revenue = revenue_pool.balance_mut<Currency>(&self.id);

            assert!(revenue.value() > 0, ENoRevenueToDistribute);

            // Calculate the protocol commission and transfer it to the protocol's revenue pool.
            let protocol_commission_value = protocol.commission_rate().calc(revenue.value());
            let protocol_commission = revenue.split(protocol_commission_value);
            protocol_commission.send_funds(revenue_pool::derived_address<Currency>(protocol.id()));

            // Store the distribution's principal value.
            let distribution_value = revenue.value();

            let release_id = self.id();
            let currency_type = with_defining_ids<Currency>();

            self.track_sequence.length().do!(|i| {
                // Derive the track identifier for the given track sequence index.
                let track_identifier = self.track_sequence.track_identifier(i);

                // Fetch the disc and track with the track identifier.
                let disc = &self.discs[track_identifier.disc_idx() as u64];
                let track = &disc.tracks()[track_identifier.track_idx() as u64];

                // Fetch the track split rate for the given track sequence index.
                let track_split = &self.track_splits[i as u64];

                if (track_split.value() > 0) {
                    let rec_split_value = track_split.calc(distribution_value);
                    let mut rec_split_balance = revenue.split(rec_split_value);

                    // Calculate the composition's revenue share, and split the value from the recording's revenue.
                    // Use rec_split_value directly since split() guarantees the exact amount requested.
                    let comp_split_value = track.composition_split().calc(rec_split_value);
                    let comp_split_balance = rec_split_balance.split(comp_split_value);

                    let composition_id = track.composition_id();
                    let recording_id = track.recording_id();

                    // Transfer funds to the reward pools for the composition and recording.
                    let composition_reward_pool_address = reward_pool::derived_address(
                        composition_id,
                        *track.composition_share_type(),
                        currency_type,
                    );

                    let recording_reward_pool_address = reward_pool::derived_address(
                        recording_id,
                        *track.recording_share_type(),
                        currency_type,
                    );

                    emit(ReleaseRevenueDistributedEvent<Currency> {
                        release_id,
                        composition_id,
                        composition_split_value: comp_split_balance.value(),
                        recording_id,
                        recording_split_value: rec_split_balance.value(),
                    });

                    comp_split_balance.send_funds(composition_reward_pool_address);
                    rec_split_balance.send_funds(recording_reward_pool_address);
                };
            });
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
public fun title(self: &Release): String {
    self.title
}

/// Returns the optional subtitle.
public fun subtitle(self: &Release): Option<String> {
    self.subtitle
}

/// Returns a reference to a disc by index.
public fun disc(self: &Release, disc_idx: u8): &Disc {
    &self.discs[disc_idx as u64]
}

/// Returns a reference to all discs.
public fun discs(self: &Release): &vector<Disc> {
    &self.discs
}

/// Returns a reference to the track sequence.
public fun track_sequence(self: &Release): &TrackSequence {
    &self.track_sequence
}

/// Returns a reference to the track splits.
public fun track_splits(self: &Release): &vector<BPS> {
    &self.track_splits
}

//=== Private Functions ===

/// Verifies that the admin capability matches this release.
fun authorize(self: &Release, cap: &ReleaseAdminCap) {
    assert!(self.id() == cap.release_id, EUnauthorized);
}

/// Asserts that the number of track splits matches the number of tracks.
fun assert_track_splits_length(self: &Release) {
    assert!(
        self.track_splits.length() == self.track_sequence.length() as u64,
        EInvalidTrackSplitsLength,
    );
}

/// Asserts that the track splits sum to 100% (10,000 BPS).
fun assert_track_splits_sum(self: &Release) {
    assert!(
        self.track_splits.fold!(0, |acc, split| acc + split.value()) == bps::max_value!(),
        EInvalidTrackSplitsSum,
    );
}

// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module musicos::release;

use interest_bps::bps::{Self, BPS};
use interest_math::u64::sum;
use musicos::disc::Disc;
use musicos::protocol::Protocol;
use musicos::revenue_pool::{Self, RevenuePool};
use musicos::royalty_pool;
use musicos::track_sequence::{Self, TrackSequence};
use std::string::String;
use sui::clock::Clock;
use sui::event::emit;

//=== Structs ===

public struct Release has key {
    id: UID,
    kind: ReleaseKind,
    state: ReleaseState,
    title: String,
    subtitle: Option<String>,
    discs: vector<Disc>,
    track_sequence: TrackSequence,
    track_splits: vector<BPS>,
}

public struct ReleaseAdminCap has key, store {
    id: UID,
    release_id: ID,
}

public struct ShareReleasePromise(ID)

//=== Events ===

public struct ReleaseCreatedEvent has copy, drop {
    release_id: ID,
}

public struct ReleaseRevenueForwardedEvent<phantom Currency> has copy, drop {
    release_id: ID,
    composition_id: ID,
    composition_split_value: u64,
    recording_id: ID,
    recording_split_value: u64,
}

//=== Enums ===

public enum ReleaseKind has copy, drop, store {
    Album,
    EP,
    Single,
}

public enum ReleaseState has copy, drop, store {
    Initialized,
    Created,
    Published(u64),
}

//=== Errors ===

const EUnauthorized: u64 = 0;
const ENotInitializedState: u64 = 1;
const ENotCreatedState: u64 = 2;
const ENotPublishedState: u64 = 3;
const EInvalidReleaseForPromise: u64 = 4;
const EInvalidTrackSplitsLength: u64 = 5;
const EInvalidTrackSplitsSum: u64 = 6;
const EMaxDiscsExceeded: u64 = 7;
const EIncorrectRevenuePool: u64 = 8;

//=== Public Functions ===

// Create a new release.
public fun new(
    kind: ReleaseKind,
    title: String,
    subtitle: Option<String>,
    discs: vector<Disc>,
    protocol: &Protocol,
    ctx: &mut TxContext,
): (Release, ReleaseAdminCap, ShareReleasePromise) {
    // Assert the number of discs doesn't exceed the protocol's allowed maximum.
    assert!(discs.length() <= protocol.max_discs_per_release() as u64, EMaxDiscsExceeded);

    // Build a track sequence for the release based on the number of discs.
    let track_sequence = track_sequence::new(&discs, protocol);

    let release = Release {
        id: object::new(ctx),
        kind,
        state: ReleaseState::Initialized,
        title,
        subtitle,
        discs,
        track_sequence,
        track_splits: vector[],
    };

    let release_admin_cap = ReleaseAdminCap {
        id: object::new(ctx),
        release_id: release.id(),
    };

    let share_release_promise = ShareReleasePromise(release.id());

    (release, release_admin_cap, share_release_promise)
}

// Turn the release into a shared object.
// Required State: Initialized
public fun share(mut self: Release, share_release_promise: ShareReleasePromise) {
    match (self.state) {
        ReleaseState::Initialized => {
            let ShareReleasePromise(release_id) = share_release_promise;
            assert!(self.id() == release_id, EInvalidReleaseForPromise);

            self.state = ReleaseState::Created;

            emit(ReleaseCreatedEvent {
                release_id: self.id(),
            });

            transfer::share_object(self);
        },
        _ => abort ENotInitializedState,
    }
}

// Transition the release from `Created` state to `Published` state.
// To successfully publish, the track splits must be set and the sum of the track splits must be 10_000 (100%).
// Required State: Created
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

// Set the track splits for the release.
// Required State: Created
public fun set_track_splits(self: &mut Release, track_splits: vector<BPS>) {
    match (self.state) {
        ReleaseState::Created => {
            self.track_splits = track_splits;

            self.assert_track_splits_length();
            self.assert_track_splits_sum();
        },
        _ => abort ENotCreatedState,
    }
}

// Forward funds from a release's revenue pool to the royalty pools of the release's compositions and recordings.
public fun forward_revenue<Currency>(self: &Release, revenue_pool: &mut RevenuePool<Currency>) {
    match (self.state) {
        ReleaseState::Published(_) => {
            // Assert the provided revenue pool is the correct one for the release.
            self.assert_revenue_pool_for_release(revenue_pool);

            // Acquire a mutable reference to the revenue pool's balance.
            let revenue = revenue_pool.balance_mut();

            // Store the value to distribute to the compositions and recordings.
            let distribution_value = revenue.value();

            let release_id = self.id();

            self.track_sequence.length().do!(|i| {
                // Derive the track identifier for the given track sequence index.
                let track_identifier = self.track_sequence.track_identifier(i);

                // Fetch the disc and track with the track identifier.
                let disc = &self.discs[track_identifier.disc_idx() as u64];
                let track = &disc.tracks()[track_identifier.track_idx() as u64];

                // Fetch the track split rate for the given track sequence index.
                let track_split_rate = self.track_splits[i as u64];

                // Split the track's revenue from the principal.
                let rec_split_value = track_split_rate.calc(distribution_value);
                let mut rec_split = revenue.split(rec_split_value);

                // Calculate the composition's revenue share, and split the value from the recording's revenue.
                // Use rec_split_value directly since split() guarantees the exact amount requested.
                let comp_split_value = track.composition_commission_rate().calc(rec_split_value);
                let comp_split = rec_split.split(comp_split_value);

                let comp_id = track.composition_id();
                let rec_id = track.recording_id();

                // Transfer funds to the royalty pools for the composition and recording.
                rec_split.send_funds(royalty_pool::derived_address<Currency>(rec_id));
                comp_split.send_funds(royalty_pool::derived_address<Currency>(comp_id));

                emit(ReleaseRevenueForwardedEvent<Currency> {
                    release_id,
                    composition_id: comp_id,
                    composition_split_value: comp_split_value,
                    recording_id: rec_id,
                    recording_split_value: rec_split_value,
                });
            });
        },
        _ => abort ENotPublishedState,
    }
}

//=== Public View Functions ===

public fun id(self: &Release): ID {
    self.id.to_inner()
}

//=== Private Functions ===

fun authorize(self: &Release, cap: &ReleaseAdminCap) {
    assert!(self.id() == cap.release_id, EUnauthorized);
}

// Assert the number of track splits is equal to the length of the track sequence.
fun assert_track_splits_length(self: &Release) {
    assert!(
        self.track_splits.length() == self.track_sequence.length() as u64,
        EInvalidTrackSplitsLength,
    );
}

// Assert the sum of the track splits is equal to 10_000 (100%).
fun assert_track_splits_sum(self: &Release) {
    assert!(
        sum(self.track_splits.map!(|split| split.value())) == bps::max_value!(),
        EInvalidTrackSplitsSum,
    );
}

fun assert_revenue_pool_for_release<Currency>(
    self: &Release,
    revenue_pool: &RevenuePool<Currency>,
) {
    assert!(
        revenue_pool.id().to_address() == revenue_pool::derived_address<Currency>(self.id()),
        EIncorrectRevenuePool,
    );
}

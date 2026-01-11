// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module musicos::release;

use musicos::bps::{Self, BPS};
use musicos::cover_art::CoverArt;
use musicos::disc::Disc;
use musicos::protocol::Protocol;
use musicos::track_identifier::TrackIdentifier;
use musicos::track_sequence::{Self, TrackSequence};
use revenue_pool::revenue_pool::{Self, RevenuePool};
use reward_pool::reward_pool::{Self, RewardPool};
use std::string::String;
use std::type_name::{TypeName, with_defining_ids};
use sui::balance::Balance;
use sui::clock::Clock;
use sui::event::emit;
use sui::vec_map::{Self, VecMap};

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
    cover_art: CoverArt,
}

public struct ReleaseAdminCap has key, store {
    id: UID,
    release_id: ID,
}

public struct ShareReleasePromise(ID)

public struct ReleaseRevenueDistributionManifest<phantom Currency> {
    release_id: ID,
    distribution_balance: Balance<Currency>,
    distribution_value: u64,
    track_splits: vector<TrackSplit>,
}

public struct TrackSplit has copy, drop, store {
    track_identifier: TrackIdentifier,
    composition_id: ID,
    composition_share_type: TypeName,
    composition_split_value: u64,
    recording_id: ID,
    recording_share_type: TypeName,
    recording_split_value: u64,
}

//=== Events ===

public struct ReleaseCreatedEvent has copy, drop {
    release_id: ID,
}

public struct ReleaseRevenueDistributedEvent<phantom Currency> has copy, drop {
    release_id: ID,
    composition_id: ID,
    composition_split_value: u64,
    recording_id: ID,
    recording_split_value: u64,
}

public struct ReleaseTrackPaidEvent<
    phantom Currency,
    phantom CompShare,
    phantom RecShare,
> has copy, drop {
    release_id: ID,
    distribution_value: u64,
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
const ENoRevenueToDistribute: u64 = 8;
const EInvalidReleaseForManifest: u64 = 9;
const EIncompleteDistribution: u64 = 10;
const EInvalidCompositionShareType: u64 = 11;
const EInvalidRecordingShareType: u64 = 12;

//=== Public Functions ===

// Create a new release.
public fun new(
    kind: ReleaseKind,
    title: String,
    cover_art: CoverArt,
    discs: vector<Disc>,
    ctx: &mut TxContext,
): (Release, ReleaseAdminCap, ShareReleasePromise) {
    // Build a track sequence for the release based on the number of discs.
    let track_sequence = track_sequence::new(&discs);

    let release = Release {
        id: object::new(ctx),
        kind,
        state: ReleaseState::Initialized,
        title,
        subtitle: option::none(),
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

// Distribute funds from a release's revenue pool to the royalty pools of the release's compositions and recordings.
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

public fun id(self: &Release): ID {
    self.id.to_inner()
}

public fun title(self: &Release): String {
    self.title
}

public fun subtitle(self: &Release): Option<String> {
    self.subtitle
}

public fun disc(self: &Release, disc_idx: u8): &Disc {
    &self.discs[disc_idx as u64]
}

public fun discs(self: &Release): &vector<Disc> {
    &self.discs
}

public fun track_sequence(self: &Release): &TrackSequence {
    &self.track_sequence
}

public fun track_splits(self: &Release): &vector<BPS> {
    &self.track_splits
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
        self.track_splits.fold!(0, |acc, split| acc + split.value()) == bps::max_value!(),
        EInvalidTrackSplitsSum,
    );
}

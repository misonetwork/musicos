// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module musicos::release;

use interest_bps::bps::{Self, BPS};
use interest_math::u64::sum;
use musicos::disc::Disc;
use musicos::track_identifier::TrackIdentifier;
use musicos::track_info;
use musicos::track_sequence::{Self, TrackSequence};
use std::string::String;
use std::type_name::{TypeName, with_defining_ids};
use sui::balance::Balance;
use sui::clock::Clock;
use sui::derived_object::claim;
use sui::dynamic_field as df;
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
const EInvalidReleaseForPromise: u64 = 3;
const EInvalidTrackSplitsLength: u64 = 4;
const EInvalidTrackSplitsSum: u64 = 5;

//=== Public Functions ===

public fun new(
    kind: ReleaseKind,
    title: String,
    subtitle: Option<String>,
    discs: vector<Disc>,
    ctx: &mut TxContext,
): (Release, ReleaseAdminCap, ShareReleasePromise) {
    // Build a track sequence for the release.
    let track_sequence = track_sequence::new(&discs);

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

public fun publish(self: &mut Release, cap: &ReleaseAdminCap, clock: &Clock) {
    self.authorize(cap);

    match (self.state) {
        ReleaseState::Created => {
            // Assert the number of track splits is equal to the length of the track sequence.
            assert!(
                self.track_splits.length() == self.track_sequence.length() as u64,
                EInvalidTrackSplitsLength,
            );
            // Assert the sum of the track splits is equal to 10_000 (100%).
            assert!(
                sum(self.track_splits.map!(|split| split.value())) == bps::max_value!(),
                EInvalidTrackSplitsSum,
            );

            self.state = ReleaseState::Published(clock.timestamp_ms());
        },
        _ => abort ENotCreatedState,
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

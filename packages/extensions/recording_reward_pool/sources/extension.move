// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// A MusicOS extension that enables revenue distribution for recordings.
///
/// When authorized, this extension allows permissionless creation of reward pools that
/// distribute accumulated revenue to recording share holders. Revenue flows from the
/// recording's funds accumulator into the reward pool, where it can be claimed
/// proportionally by staked recording shares.

module recording_reward_pool::extension;

use musicos::extension;
use musicos::recording::{Recording, RecordingAdminCap};
use reward_pool::reward_pool::{Self, RewardPool};
use sui::balance::{redeem_funds, withdraw_funds_from_object};
use sui::event::emit;

//=== Structs ===

public struct Extension() has drop;

//=== Events ===

public struct RecordingRevenuePoolCreatedEvent<phantom Currency> has copy, drop {
    recording_id: ID,
    reward_pool_id: ID,
}

//=== Public Functions ===

public fun authorize<RecordingShare>(
    recording: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap<RecordingShare>,
) {
    let uid_mut = recording.uid_mut(cap);
    extension::authorize(uid_mut, Extension());
}

public fun new_revenue_pool<RecordingShare, Currency>(
    recording: &mut Recording<RecordingShare>,
): RewardPool<RecordingShare, Currency> {
    let uid_mut = recording.uid_mut_authorized(Extension());
    let reward_pool = reward_pool::new<RecordingShare, Currency>(uid_mut);

    emit(RecordingRevenuePoolCreatedEvent<Currency> {
        recording_id: recording.id(),
        reward_pool_id: reward_pool.id(),
    });

    reward_pool
}

// Redeem revenue from a recording's funds accumulator and forward it to the recording's reward pool.
public fun redeem_and_forward_revenue<RecordingShare, Currency>(
    recording: &mut Recording<RecordingShare>,
    value: u64,
    reward_pool: &mut RewardPool<RecordingShare, Currency>,
) {
    let uid_mut = recording.uid_mut_authorized(Extension());
    let withdrawal = withdraw_funds_from_object<Currency>(uid_mut, value);
    let balance = redeem_funds<Currency>(withdrawal);
    reward_pool.deposit(balance);
}

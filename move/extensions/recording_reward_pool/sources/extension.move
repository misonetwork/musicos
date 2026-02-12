// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// A MusicOS extension that enables revenue distribution for recordings.
///
/// When authorized, this extension allows permissionless creation of reward pools that
/// distribute accumulated revenue to recording share holders. Revenue flows from the
/// recording's funds accumulator into the reward pool, where it can be claimed
/// proportionally by staked recording shares.

module recording_reward_pool::extension;

use hikida::hikida;
use musicos::recording::{Recording, RecordingAdminCap};
use reward_pool::reward_pool::{Self, RewardPool};
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
    recording.register_extension(cap, Extension(), true);
}

public fun new_reward_pool<RecordingShare, Currency>(
    recording: &mut Recording<RecordingShare>,
): RewardPool<RecordingShare, Currency> {
    let uid_mut = recording.uid_mut_with_extension(Extension());
    let reward_pool = reward_pool::new<RecordingShare, Currency>(
        uid_mut,
        reward_pool::new_open_kind(),
    );

    emit(RecordingRevenuePoolCreatedEvent<Currency> {
        recording_id: recording.id(),
        reward_pool_id: reward_pool.id(),
    });

    reward_pool
}

// Redeem revenue from a recording's funds accumulator and forward it to the recording's reward pool.
public fun redeem_and_deposit_revenue<RecordingShare, Currency>(
    recording: &mut Recording<RecordingShare>,
    value: u64,
    reward_pool: &mut RewardPool<RecordingShare, Currency>,
) {
    let uid_mut = recording.uid_mut_with_extension(Extension());
    let revenue = hikida::redeem_balance<Currency>(uid_mut, value);
    reward_pool.deposit(revenue);
}

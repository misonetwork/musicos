// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// A MusicOS extension that enables revenue distribution for recordings.
///
/// When authorized by the recording owner, this extension allows
/// permissionless creation of reward pools that distribute accumulated
/// revenue to recording share holders. Revenue flows from the recording's
/// funds accumulator into the reward pool, where it can be claimed
/// proportionally by staked recording shares.
///
/// ### Flow:
///
/// - The recording owner calls `authorize` with their `RecordingAdminCap`
/// to register this extension on a recording.
/// - Once authorized, anyone can call `new_reward_pool` to create a
/// currency-specific reward pool attached to the recording.
/// - Revenue is moved from the recording's funds accumulator into the
/// reward pool via `redeem_and_deposit_revenue`, making it claimable by
/// staked share holders.
///
/// ### Notes:
///
/// - Each currency type gets its own reward pool. Multiple currencies can
/// be supported simultaneously on the same recording.
/// - The reward pool uses an open distribution kind, meaning any share
/// holder can stake and claim without additional authorization.
module recording_reward_pool::extension;

use hikida::hikida;
use musicos::recording::{Recording, RecordingAdminCap};
use reward_pool::reward_pool::{Self, RewardPool};
use sui::event::emit;

// === Structs ===

/// Witness type identifying this extension. Used as the phantom type
/// parameter when registering with the MusicOS extension system.
public struct Extension() has drop;

// === Events ===

/// Emitted when a new reward pool is created for a recording.
public struct RecordingRevenuePoolCreatedEvent<phantom Currency> has copy, drop {
    /// ID of the recording the reward pool is attached to.
    recording_id: ID,
    /// ID of the newly created reward pool.
    reward_pool_id: ID,
}

// === Public Functions ===

/// Register this extension on a recording. Can only be called by the
/// recording owner with the matching `RecordingAdminCap`.
///
/// Must be called before `new_reward_pool` or
/// `redeem_and_deposit_revenue` can be used on this recording.
public fun authorize<RecordingShare>(
    recording: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap<RecordingShare>,
) {
    recording.register_extension(cap, Extension(), true);
}

/// Create a new reward pool for the given currency type on the
/// recording. The reward pool is attached to the recording's UID as
/// a dynamic field.
///
/// Requires the extension to be authorized via `authorize` first.
/// Emits a `RecordingRevenuePoolCreatedEvent` on success.
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

/// Redeem revenue from the recording's funds accumulator and deposit it
/// into the reward pool, making it available for share holders to claim.
///
/// Requires the extension to be authorized via `authorize` first.
public fun redeem_and_deposit_revenue<RecordingShare, Currency>(
    recording: &mut Recording<RecordingShare>,
    value: u64,
    reward_pool: &mut RewardPool<RecordingShare, Currency>,
) {
    let uid_mut = recording.uid_mut_with_extension(Extension());
    let revenue = hikida::redeem_balance<Currency>(uid_mut, value);
    reward_pool.deposit(revenue);
}

// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// A MusicOS extension that enables revenue distribution for compositions.
///
/// When authorized by the composition owner, this extension allows
/// permissionless creation of reward pools that distribute accumulated
/// revenue to composition share holders. Revenue flows from the
/// composition's funds accumulator into the reward pool, where it can be
/// claimed proportionally by staked composition shares.
///
/// ### Flow:
///
/// - The composition owner calls `authorize` with their `CompositionAdminCap`
/// to register this extension on a composition.
/// - Once authorized, anyone can call `new_reward_pool` to create a
/// currency-specific reward pool attached to the composition.
/// - Revenue is moved from the composition's funds accumulator into the
/// reward pool via `redeem_and_deposit_revenue`, making it claimable by
/// staked share holders.
///
/// ### Notes:
///
/// - Each currency type gets its own reward pool. Multiple currencies can
/// be supported simultaneously on the same composition.
/// - The reward pool uses an open distribution kind, meaning any share
/// holder can stake and claim without additional authorization.
module composition_reward_pool::extension;

use hikida::hikida;
use musicos::composition::{Composition, CompositionAdminCap};
use reward_pool::reward_pool::{Self, RewardPool};
use sui::event::emit;

// === Structs ===

/// Witness type identifying this extension. Used as the phantom type
/// parameter when registering with the MusicOS extension system.
public struct Extension() has drop;

// === Events ===

/// Emitted when a new reward pool is created for a composition.
public struct CompositionRevenuePoolCreatedEvent<phantom Currency> has copy, drop {
    /// ID of the composition the reward pool is attached to.
    composition_id: ID,
    /// ID of the newly created reward pool.
    reward_pool_id: ID,
}

// === Public Functions ===

/// Register this extension on a composition. Can only be called by the
/// composition owner with the matching `CompositionAdminCap`.
///
/// Must be called before `new_reward_pool` or
/// `redeem_and_deposit_revenue` can be used on this composition.
public fun authorize<CompositionShare>(
    composition: &mut Composition<CompositionShare>,
    cap: &CompositionAdminCap<CompositionShare>,
) {
    composition.register_extension(cap, Extension(), true);
}

/// Create a new reward pool for the given currency type on the
/// composition. The reward pool is attached to the composition's UID as
/// a dynamic field.
///
/// Requires the extension to be authorized via `authorize` first.
/// Emits a `CompositionRevenuePoolCreatedEvent` on success.
public fun new_reward_pool<CompositionShare, Currency>(
    composition: &mut Composition<CompositionShare>,
): RewardPool<CompositionShare, Currency> {
    let uid_mut = composition.uid_mut_with_extension(Extension());
    let reward_pool = reward_pool::new<CompositionShare, Currency>(
        uid_mut,
        reward_pool::new_open_kind(),
    );

    emit(CompositionRevenuePoolCreatedEvent<Currency> {
        composition_id: composition.id(),
        reward_pool_id: reward_pool.id(),
    });

    reward_pool
}

/// Redeem revenue from the composition's funds accumulator and deposit it
/// into the reward pool, making it available for share holders to claim.
///
/// Requires the extension to be authorized via `authorize` first.
public fun redeem_and_deposit_revenue<CompositionShare, Currency>(
    composition: &mut Composition<CompositionShare>,
    value: u64,
    reward_pool: &mut RewardPool<CompositionShare, Currency>,
) {
    let uid_mut = composition.uid_mut_with_extension(Extension());
    let revenue = hikida::redeem_balance<Currency>(uid_mut, value);
    reward_pool.deposit(revenue);
}

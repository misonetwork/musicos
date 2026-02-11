// Copyright (c) Studio Mirai, LLC
// SPDX-License-Identifier: Apache-2.0

/// A MusicOS extension that enables revenue distribution for compositions.
///
/// When authorized, this extension allows permissionless creation reward pools that
/// distribute accumulated revenue to composition share holders. Revenue flows from the
/// composition's funds accumulator into the reward pool, where it can be claimed
/// proportionally by staked composition shares.

module composition_reward_pool::extension;

use musicos::composition::{Composition, CompositionAdminCap};
use musicos::extension;
use reward_pool::reward_pool::{Self, RewardPool};
use sui::balance::{redeem_funds, withdraw_funds_from_object};
use sui::event::emit;

//=== Structs ===

public struct Extension() has drop;

//=== Events ===

public struct CompositionRevenuePoolCreatedEvent<phantom Currency> has copy, drop {
    composition_id: ID,
    reward_pool_id: ID,
}

//=== Public Functions ===

public fun register<CompositionShare>(
    composition: &mut Composition<CompositionShare>,
    cap: &CompositionAdminCap<CompositionShare>,
) {
    composition.register_extension(cap, Extension());
}

public fun new_revenue_pool<CompositionShare, Currency>(
    composition: &mut Composition<CompositionShare>,
): RewardPool<CompositionShare, Currency> {
    let uid_mut = composition.uid_mut_with_extension(Extension());
    let reward_pool = reward_pool::new<CompositionShare, Currency>(uid_mut);

    emit(CompositionRevenuePoolCreatedEvent<Currency> {
        composition_id: composition.id(),
        reward_pool_id: reward_pool.id(),
    });

    reward_pool
}

// Redeem revenue from a composition's funds accumulator and forward it to the composition's reward pool.
public fun redeem_and_forward_revenue<CompositionShare, Currency>(
    composition: &mut Composition<CompositionShare>,
    value: u64,
    reward_pool: &mut RewardPool<CompositionShare, Currency>,
) {
    let uid_mut = composition.uid_mut_authorized(Extension());
    let withdrawal = withdraw_funds_from_object<Currency>(uid_mut, value);
    let balance = redeem_funds<Currency>(withdrawal);
    reward_pool.deposit(balance);
}

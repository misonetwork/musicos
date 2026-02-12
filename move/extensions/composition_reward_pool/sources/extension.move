// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// A MusicOS extension that enables revenue distribution for compositions.
///
/// When authorized, this extension allows permissionless creation of reward pools that
/// distribute accumulated revenue to composition share holders. Revenue flows from the
/// composition's funds accumulator into the reward pool, where it can be claimed
/// proportionally by staked composition shares.

module composition_reward_pool::extension;

use hikida::hikida;
use musicos::composition::{Composition, CompositionAdminCap};
use reward_pool::reward_pool::{Self, RewardPool};
use sui::event::emit;

//=== Structs ===

public struct Extension() has drop;

//=== Events ===

public struct CompositionRevenuePoolCreatedEvent<phantom Currency> has copy, drop {
    composition_id: ID,
    reward_pool_id: ID,
}

//=== Public Functions ===

public fun authorize<CompositionShare>(
    composition: &mut Composition<CompositionShare>,
    cap: &CompositionAdminCap<CompositionShare>,
) {
    composition.register_extension(cap, Extension(), true);
}

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

// Redeem revenue from a composition's funds accumulator and forward it to the composition's reward pool.
public fun redeem_and_deposit_revenue<CompositionShare, Currency>(
    composition: &mut Composition<CompositionShare>,
    value: u64,
    reward_pool: &mut RewardPool<CompositionShare, Currency>,
) {
    let uid_mut = composition.uid_mut_with_extension(Extension());
    let revenue = hikida::redeem_balance<Currency>(uid_mut, value);
    reward_pool.deposit(revenue);
}

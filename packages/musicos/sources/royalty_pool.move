// Copyright (c) Sona Labs, Pte Ltd.
// SPDX-License-Identifier: Apache-2.0

module musicos::royalty_pool;

use musicos::royalty_distribution::{Self, RoyaltyDistribution};
use sui::balance::{Self, Balance};
use sui::derived_object::{claim, derive_address as derive_address_impl, exists as exists_impl};

public struct RoyaltyPool<phantom RevenueCurrency, phantom RoyaltyShare> has key, store {
    id: UID,
    balance: Balance<RevenueCurrency>,
}

public struct RoyaltyPoolRegistry has key {
    id: UID,
}

public struct RoyaltyPoolKey<phantom RevenueCurrency>() has copy, drop, store;

public(package) fun new<RevenueCurrency, RoyaltyShare>(
    parent: &mut UID,
): RoyaltyPool<RevenueCurrency, RoyaltyShare> {
    RoyaltyPool {
        id: claim(parent, RoyaltyPoolKey<RevenueCurrency>()),
        balance: balance::zero(),
    }
}

// TODO: Add minimum distribution amount enforcement?
public fun distribute<RoyaltyShare, RevenueCurrency>(
    self: &mut RoyaltyPool<RevenueCurrency, RoyaltyShare>,
    ctx: &TxContext,
) {
    royalty_distribution::new<RoyaltyShare, RevenueCurrency>(
        &mut self.id,
        self.balance.withdraw_all(),
        ctx,
    );
}

//=== Public Functions ===

public fun derive_address<RevenueCurrency>(parent_id: ID): address {
    derive_address_impl(parent_id, RoyaltyPoolKey<RevenueCurrency>())
}

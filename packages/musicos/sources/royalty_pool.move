// Copyright (c) Sona Labs, Pte Ltd.
// SPDX-License-Identifier: Apache-2.0

module musicos::royalty_pool;

use musicos::protocol::Protocol;
use musicos::royalty_distribution::{Self, RoyaltyDistribution};
use sui::balance::{Self, Balance};
use sui::derived_object::{claim, derive_address as derive_address_impl, exists as exists_impl};

public struct RoyaltyPool<phantom Currency, phantom Share> has key, store {
    id: UID,
    balance: Balance<Currency>,
}

public struct RoyaltyPoolRegistry has key {
    id: UID,
}

const ENoFundsToReclaim: u64 = 0;
const ENotEnoughFunds: u64 = 1;

public struct RoyaltyPoolKey<phantom Currency>() has copy, drop, store;

public(package) fun new<Currency, Share>(parent: &mut UID): RoyaltyPool<Currency, Share> {
    RoyaltyPool {
        id: claim(parent, RoyaltyPoolKey<Currency>()),
        balance: balance::zero(),
    }
}

// TODO: Derive minimum distribution amount for share currency supply and revenue currency decimals?
public fun new_distribution<Share, Currency>(
    self: &mut RoyaltyPool<Currency, Share>,
    protocol: &Protocol,
    ctx: &TxContext,
) {
    assert!(self.balance.value() >= protocol.min_royalty_distribution_threshold(), ENotEnoughFunds);

    royalty_distribution::new<Share, Currency>(
        &mut self.id,
        self.balance.withdraw_all(),
        ctx,
    );
}

// Reclaim funds from a RoyaltyDistribution that has expired.
public fun destroy_distribution<Currency, Share>(
    self: &mut RoyaltyPool<Currency, Share>,
    distribution: RoyaltyDistribution<Share, Currency>,
    ctx: &TxContext,
) {
    distribution.assert_expired(ctx);
    self.balance.join(distribution.destroy());
}

//=== Public Functions ===

public fun derive_address<Currency>(parent_id: ID): address {
    derive_address_impl(parent_id, RoyaltyPoolKey<Currency>())
}

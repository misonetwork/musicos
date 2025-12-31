// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module musicos::royalty_pool;

use sui::balance::{Self, Balance};
use sui::coin::Coin;
use sui::derived_object;
use sui::event::emit;
use sui::transfer::Receiving;

//=== Structs ===

public struct ROYALTY_POOL() has drop;

public struct RoyaltyPool<phantom Currency> has key, store {
    id: UID,
    balance: Balance<Currency>,
}

// Registry object for tracking derived addresses for RoyaltyPools.
public struct RoyaltyPoolRegistry has key {
    id: UID,
}

/// Key used to deterministically derive the RoyaltyPool object ID.
public struct RoyaltyPoolKey<phantom Currency>() has copy, drop, store;

//=== Events ===

public struct RoyaltyDepositedEvent<phantom Currency> has copy, drop {
    royalty_pool_id: ID,
    value: u64,
}

//=== Errors ===

const EDoesNotExist: u64 = 0;

//=== Init Function ===

fun init(_otw: ROYALTY_POOL, ctx: &mut TxContext) {
    let royalty_pool_registry = RoyaltyPoolRegistry {
        id: object::new(ctx),
    };

    transfer::share_object(royalty_pool_registry);
}

//=== Public Functions ===

// Receive a coin and deposit it into the revenue pool.
public fun receive_and_deposit<Currency>(
    self: &mut RoyaltyPool<Currency>,
    coin_to_receive: Receiving<Coin<Currency>>,
) {
    let coin = transfer::public_receive(&mut self.id, coin_to_receive);
    self.deposit_impl(coin.into_balance());
}

//=== Package Functions ===

public(package) fun new<Currency>(parent: &mut UID): RoyaltyPool<Currency> {
    RoyaltyPool {
        id: derived_object::claim(parent, RoyaltyPoolKey<Currency>()),
        balance: balance::zero(),
    }
}

//=== Public View Functions ===

public fun id<Currency>(self: &RoyaltyPool<Currency>): ID {
    self.id.to_inner()
}

public fun balance<Currency>(self: &RoyaltyPool<Currency>): &Balance<Currency> {
    &self.balance
}

public fun derived_address<Currency>(parent_id: ID): address {
    derived_object::derive_address(parent_id, RoyaltyPoolKey<Currency>())
}

//=== Assert Functions ===

public fun assert_exists<Currency>(parent: &UID) {
    assert!(derived_object::exists(parent, RoyaltyPoolKey<Currency>()), EDoesNotExist);
}

//=== Private Functions ===

fun deposit_impl<Currency>(self: &mut RoyaltyPool<Currency>, balance: Balance<Currency>) {
    emit(RoyaltyDepositedEvent<Currency> {
        royalty_pool_id: self.id(),
        value: balance.value(),
    });

    self.balance.join(balance);
}

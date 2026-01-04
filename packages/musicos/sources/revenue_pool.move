// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module musicos::revenue_pool;

use musicos::protocol::Protocol;
use sui::balance::{Self, Balance};
use sui::coin::Coin;
use sui::derived_object;
use sui::event::emit;
use sui::transfer::Receiving;

//=== Structs ===

public struct REVENUE_POOL() has drop;

public struct RevenuePool<phantom Currency> has key, store {
    id: UID,
    balance: Balance<Currency>,
    cumulative_earnings: u128,
}

// Registry object for tracking derived addresses for RevenuePools.
public struct RevenuePoolRegistry has key {
    id: UID,
}

/// Key used to deterministically derive the RevenuePool object ID.
public struct RevenuePoolKey<phantom Currency>() has copy, drop, store;

//=== Events ===

public struct RevenueDepositedEvent<phantom Currency> has copy, drop {
    revenue_pool_id: ID,
    value: u64,
}

//=== Errors ===

const EDoesNotExist: u64 = 0;
const ENoCoinsToReceive: u64 = 1;

//=== Init Function ===

fun init(_otw: REVENUE_POOL, ctx: &mut TxContext) {
    let revenue_pool_registry = RevenuePoolRegistry {
        id: object::new(ctx),
    };

    transfer::share_object(revenue_pool_registry);
}

//=== Public Functions ===

// Deposit funds into the revenue pool.
public fun deposit<Currency>(
    self: &mut RevenuePool<Currency>,
    balance: Balance<Currency>,
    protocol: &Protocol,
) {
    protocol.assert_is_active_state();

    self.deposit_impl(balance);
}

// Receive a coin and deposit it into the revenue pool.
public fun receive_and_deposit<Currency>(
    self: &mut RevenuePool<Currency>,
    coin_to_receive: Receiving<Coin<Currency>>,
    protocol: &Protocol,
) {
    protocol.assert_is_active_state();

    let coin = transfer::public_receive(&mut self.id, coin_to_receive);

    self.deposit_impl(coin.into_balance());
}

// Batch receive coins and deposit the combined balance into the royalty pool.
public fun batch_receive_and_deposit<Currency>(
    self: &mut RevenuePool<Currency>,
    coins_to_receive: vector<Receiving<Coin<Currency>>>,
    protocol: &Protocol,
) {
    protocol.assert_is_active_state();

    assert!(!coins_to_receive.is_empty(), ENoCoinsToReceive);

    let parent = &mut self.id;
    let mut balance = balance::zero<Currency>();

    coins_to_receive.destroy!(|coin_to_receive| {
        let coin = transfer::public_receive(parent, coin_to_receive);
        balance.join(coin.into_balance());
    });

    if (balance.value() > 0) {
        self.deposit_impl(balance);
    } else {
        balance.destroy_zero();
    }
}

//=== Package Functions ===

public(package) fun new<Currency>(parent: &mut UID): RevenuePool<Currency> {
    RevenuePool {
        id: derived_object::claim(parent, RevenuePoolKey<Currency>()),
        balance: balance::zero(),
        cumulative_earnings: 0,
    }
}

public(package) fun balance_mut<Currency>(
    self: &mut RevenuePool<Currency>,
): &mut Balance<Currency> {
    &mut self.balance
}

//=== Public View Functions ===

public fun id<Currency>(self: &RevenuePool<Currency>): ID {
    self.id.to_inner()
}

public fun balance<Currency>(self: &RevenuePool<Currency>): &Balance<Currency> {
    &self.balance
}

public fun cumulative_earnings<Currency>(self: &RevenuePool<Currency>): u128 {
    self.cumulative_earnings
}

public fun derived_address<Currency>(parent_id: ID): address {
    derived_object::derive_address(parent_id, RevenuePoolKey<Currency>())
}

//=== Assert Functions ===

public fun assert_exists<Currency>(parent: &UID) {
    assert!(derived_object::exists(parent, RevenuePoolKey<Currency>()), EDoesNotExist);
}

//=== Private Functions ===

fun deposit_impl<Currency>(self: &mut RevenuePool<Currency>, balance: Balance<Currency>) {
    let deposit_value = balance.value();

    self.cumulative_earnings = self.cumulative_earnings + (deposit_value as u128);
    self.balance.join(balance);

    emit(RevenueDepositedEvent<Currency> {
        revenue_pool_id: self.id(),
        value: deposit_value,
    });
}

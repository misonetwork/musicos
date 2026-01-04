// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module musicos::royalty_pool;

use musicos::protocol::Protocol;
use musicos::share::share_currency_supply;
use sui::balance::{Self, Balance};
use sui::coin::Coin;
use sui::derived_object;
use sui::event::emit;
use sui::transfer::Receiving;

//=== Structs ===

public struct ROYALTY_POOL() has drop;

public struct RoyaltyPool<phantom Share, phantom Currency> has key, store {
    id: UID,
    balance: Balance<Currency>,
    staked_shares: u64,
    cumulative_reward_per_share: u256,
    cumulative_deposits: u128,
}

// Registry object for tracking derived addresses for RoyaltyPools.
public struct RoyaltyPoolRegistry has key {
    id: UID,
}

/// Key used to deterministically derive the RoyaltyPool object ID.
public struct RoyaltyPoolKey<phantom Currency>() has copy, drop, store;

//=== Events ===

public struct RoyaltyPoolCreatedEvent<phantom Share, phantom Currency> has copy, drop {
    royalty_pool_id: ID,
}

public struct RoyaltyDepositedEvent<phantom Currency> has copy, drop {
    royalty_pool_id: ID,
    value: u64,
}

public struct RoyaltyPoolStakedSharesIncreasedEvent<
    phantom Share,
    phantom Currency,
> has copy, drop {
    royalty_pool_id: ID,
    previous_staked_shares: u64,
    new_staked_shares: u64,
}

public struct RoyaltyPoolStakedSharesDecreasedEvent<
    phantom Share,
    phantom Currency,
> has copy, drop {
    royalty_pool_id: ID,
    previous_staked_shares: u64,
    new_staked_shares: u64,
}

//=== Constants ===

const PRECISION: u256 = 1_000_000_000_000_000_000;

//=== Errors ===

const EDoesNotExist: u64 = 0;
const EStakedSharesOverflow: u64 = 1;
const ENoStakedShares: u64 = 2;
const ENoCoinsToReceive: u64 = 3;
const ECoinValueIsZero: u64 = 4;

//=== Init Function ===

fun init(_otw: ROYALTY_POOL, ctx: &mut TxContext) {
    let royalty_pool_registry = RoyaltyPoolRegistry {
        id: object::new(ctx),
    };

    transfer::share_object(royalty_pool_registry);
}

//=== Public Functions ===

// Receive a coin and deposit it into the revenue pool.
public fun receive_and_deposit<Share, Currency>(
    self: &mut RoyaltyPool<Share, Currency>,
    coin_to_receive: Receiving<Coin<Currency>>,
    protocol: &Protocol,
) {
    protocol.assert_is_active_state();

    let coin = transfer::public_receive(&mut self.id, coin_to_receive);
    assert!(coin.value() > 0, ECoinValueIsZero);

    self.deposit_impl(coin.into_balance());
}

// Batch receive coins and deposit the combined balance into the royalty pool.
public fun batch_receive_and_deposit<Share, Currency>(
    self: &mut RoyaltyPool<Share, Currency>,
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

public(package) fun new<Share, Currency>(parent: &mut UID): RoyaltyPool<Share, Currency> {
    let royalty_pool = RoyaltyPool {
        id: derived_object::claim(parent, RoyaltyPoolKey<Currency>()),
        balance: balance::zero(),
        staked_shares: 0,
        cumulative_reward_per_share: 0,
        cumulative_deposits: 0,
    };

    emit(RoyaltyPoolCreatedEvent<Share, Currency> {
        royalty_pool_id: royalty_pool.id(),
    });

    royalty_pool
}

public(package) fun increase_staked_shares<Share, Currency>(
    self: &mut RoyaltyPool<Share, Currency>,
    value: u64,
) {
    let previous_staked_shares = self.staked_shares;
    let new_staked_shares = previous_staked_shares + value;

    assert!(new_staked_shares <= share_currency_supply!(), EStakedSharesOverflow);

    self.staked_shares = new_staked_shares;

    emit(RoyaltyPoolStakedSharesIncreasedEvent<Share, Currency> {
        royalty_pool_id: self.id(),
        previous_staked_shares,
        new_staked_shares,
    });
}

public(package) fun decrease_staked_shares<Share, Currency>(
    self: &mut RoyaltyPool<Share, Currency>,
    value: u64,
) {
    let previous_staked_shares = self.staked_shares;
    let new_staked_shares = previous_staked_shares - value;

    self.staked_shares = self.staked_shares - value;

    emit(RoyaltyPoolStakedSharesDecreasedEvent<Share, Currency> {
        royalty_pool_id: self.id(),
        previous_staked_shares,
        new_staked_shares,
    });
}

public(package) fun uid_mut<Share, Currency>(self: &mut RoyaltyPool<Share, Currency>): &mut UID {
    &mut self.id
}

//=== Public View Functions ===

public fun id<Share, Currency>(self: &RoyaltyPool<Share, Currency>): ID {
    self.id.to_inner()
}

public fun balance<Share, Currency>(self: &RoyaltyPool<Share, Currency>): &Balance<Currency> {
    &self.balance
}

public fun staked_shares<Share, Currency>(self: &RoyaltyPool<Share, Currency>): u64 {
    self.staked_shares
}

public fun cumulative_reward_per_share<Share, Currency>(self: &RoyaltyPool<Share, Currency>): u256 {
    self.cumulative_reward_per_share
}

public fun cumulative_deposits<Share, Currency>(self: &RoyaltyPool<Share, Currency>): u128 {
    self.cumulative_deposits
}

public fun derived_address<Currency>(parent_id: ID): address {
    derived_object::derive_address(parent_id, RoyaltyPoolKey<Currency>())
}

//=== Assert Functions ===

public fun assert_exists<Currency>(parent: &UID) {
    assert!(derived_object::exists(parent, RoyaltyPoolKey<Currency>()), EDoesNotExist);
}

//=== Private Functions ===

fun deposit_impl<Share, Currency>(
    self: &mut RoyaltyPool<Share, Currency>,
    balance: Balance<Currency>,
) {
    // Require a non-zero number of staked shares before processing deposits.
    //
    // This check serves two purposes:
    //
    // 1. Mathematical: The reward accumulator formula divides the deposit value by
    //    staked_shares. If staked_shares is zero, this would either cause a division
    //    by zero error or, if guarded, the deposit would be added to the balance
    //    without updating cumulative_reward_per_share — making those funds permanently
    //    unclaimable ("orphaned").
    //
    // 2. Economic: Royalty payments sent to the pool before any shareholders have
    //    staked will remain as pending Coin objects at the pool's address OR a balance
    //    in the royalty pool's balance accumulator. Once shareholders stake and call
    //    receive_and_deposit() those queued payments are processed and distributed proportionally.
    //    This ensures no royalties are lost due to timing mismatches between when payments
    //    arrive and when shareholders register their entitlements.
    //
    // Callers should check staked_shares > 0 before sending transactions, or expect
    // this to revert if no shareholders have staked yet.
    assert!(self.staked_shares > 0, ENoStakedShares);

    let deposit_value = balance.value();

    let reward_per_share = (deposit_value as u256) * PRECISION / (self.staked_shares as u256);
    self.cumulative_reward_per_share = self.cumulative_reward_per_share + reward_per_share;
    self.cumulative_deposits = self.cumulative_deposits + (deposit_value as u128);

    self.balance.join(balance);

    emit(RoyaltyDepositedEvent<Currency> {
        royalty_pool_id: self.id(),
        value: deposit_value,
    });
}

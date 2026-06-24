// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module revenue_ops::revenue_ops_tests;

use miso_vault::vault::{Self, Vault, VaultAdminCap, OperatorCap};
use revenue_ops::revenue_ops;
use royalty_pool::pool::{Self, RoyaltyPool};
use royalty_pool::stake::{Self, Stake};
use std::unit_test::destroy;
use sui::balance;
use sui::clock;
use sui::coin::Coin;
use sui::test_scenario as ts;

// === Test types ===

/// The share token type the stake holds (phantom on `Stake` / `RoyaltyPool`).
public struct TEST_SHARE() has drop;
/// The royalty currency paid out by the pool.
public struct TEST_CURRENCY() has drop;

const OWNER: address = @0xA1;
const AGENT: address = @0xB2;
const PAYOUT: address = @0xCAFE;

const PUBKEY: vector<u8> = x"0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20";

// === Helpers ===

/// Mint a `Stake<TEST_SHARE>` with `amount` base units.
fun new_stake(scenario: &mut ts::Scenario, amount: u64): Stake<TEST_SHARE> {
    stake::new(balance::create_for_testing<TEST_SHARE>(amount), scenario.ctx())
}

/// Create + share a `RoyaltyPool<TEST_SHARE, TEST_CURRENCY>` derived from a
/// fresh parent UID. Returns the pool id.
fun create_pool(scenario: &mut ts::Scenario): ID {
    scenario.next_tx(OWNER);
    let mut parent = object::new(scenario.ctx());
    let pool = pool::new<TEST_SHARE, TEST_CURRENCY>(&mut parent);
    let pool_id = pool.id();
    pool.share();
    destroy(parent);
    pool_id
}

// === Happy path: wrap stake -> install(payout) -> register -> claim ===

#[test]
fun test_claim_sends_to_payout() {
    let mut scenario = ts::begin(OWNER);
    let s = &mut scenario;

    // Owner mints a 1000-share stake and wraps it in a vault.
    let stake = new_stake(s, 1000);
    let admin_cap = vault::wrap(stake, PUBKEY, s.ctx());
    transfer::public_transfer(admin_cap, OWNER);

    let pool_id = create_pool(s);

    // Owner installs the plugin (payout -> PAYOUT) and authorizes the operator.
    s.next_tx(OWNER);
    {
        let mut v = ts::take_shared<Vault<Stake<TEST_SHARE>>>(s);
        let admin = ts::take_from_sender<VaultAdminCap>(s);

        revenue_ops::install(&mut v, &admin, PAYOUT);
        assert!(revenue_ops::payout(&v) == PAYOUT);

        vault::authorize_operator(&mut v, &admin, AGENT, 1_000, s.ctx());

        ts::return_to_sender(s, admin);
        ts::return_shared(v);
    };

    // Operator registers the vaulted stake against the pool.
    s.next_tx(AGENT);
    {
        let mut v = ts::take_shared<Vault<Stake<TEST_SHARE>>>(s);
        let mut pool = ts::take_shared_by_id<RoyaltyPool<TEST_SHARE, TEST_CURRENCY>>(s, pool_id);
        let op = ts::take_from_sender<OperatorCap>(s);
        let clk = clock::create_for_testing(s.ctx());

        revenue_ops::register(&mut v, &mut pool, &op, &clk);
        assert!(pool.staked_shares() == 1000);

        clock::destroy_for_testing(clk);
        ts::return_to_sender(s, op);
        ts::return_shared(pool);
        ts::return_shared(v);
    };

    // Anyone funds the pool: deposit 500 currency units. With the sole stake of
    // 1000 shares registered, all of it accrues to that stake.
    s.next_tx(OWNER);
    {
        let mut pool = ts::take_shared_by_id<RoyaltyPool<TEST_SHARE, TEST_CURRENCY>>(s, pool_id);
        pool.deposit(balance::create_for_testing<TEST_CURRENCY>(500));
        ts::return_shared(pool);
    };

    // Operator claims; funds must land at PAYOUT, not at the operator.
    s.next_tx(AGENT);
    {
        let mut v = ts::take_shared<Vault<Stake<TEST_SHARE>>>(s);
        let mut pool = ts::take_shared_by_id<RoyaltyPool<TEST_SHARE, TEST_CURRENCY>>(s, pool_id);
        let op = ts::take_from_sender<OperatorCap>(s);
        let clk = clock::create_for_testing(s.ctx());

        revenue_ops::claim(&mut v, &mut pool, &op, &clk, s.ctx());

        clock::destroy_for_testing(clk);
        ts::return_to_sender(s, op);
        ts::return_shared(pool);
        ts::return_shared(v);
    };

    // PAYOUT received a Coin<TEST_CURRENCY> of 500. The operator (AGENT) did not.
    s.next_tx(PAYOUT);
    {
        let coin = ts::take_from_sender<Coin<TEST_CURRENCY>>(s);
        assert!(coin.value() == 500);
        ts::return_to_sender(s, coin);
    };
    s.next_tx(AGENT);
    {
        assert!(!ts::has_most_recent_for_sender<Coin<TEST_CURRENCY>>(s));
    };

    scenario.end();
}

// === Negative: an unauthorized (revoked) operator cannot claim ===

#[test]
#[expected_failure(abort_code = miso_vault::vault::ERevoked)]
fun test_claim_revoked_operator_fails() {
    let mut scenario = ts::begin(OWNER);
    let s = &mut scenario;

    let stake = new_stake(s, 1000);
    let admin_cap = vault::wrap(stake, PUBKEY, s.ctx());
    transfer::public_transfer(admin_cap, OWNER);

    let pool_id = create_pool(s);

    // Install plugin, authorize the operator, then immediately revoke it.
    s.next_tx(OWNER);
    {
        let mut v = ts::take_shared<Vault<Stake<TEST_SHARE>>>(s);
        let admin = ts::take_from_sender<VaultAdminCap>(s);

        revenue_ops::install(&mut v, &admin, PAYOUT);
        vault::authorize_operator(&mut v, &admin, AGENT, 1_000, s.ctx());

        ts::return_to_sender(s, admin);
        ts::return_shared(v);
    };

    // Operator registers while still authorized.
    s.next_tx(AGENT);
    {
        let mut v = ts::take_shared<Vault<Stake<TEST_SHARE>>>(s);
        let mut pool = ts::take_shared_by_id<RoyaltyPool<TEST_SHARE, TEST_CURRENCY>>(s, pool_id);
        let op = ts::take_from_sender<OperatorCap>(s);
        let clk = clock::create_for_testing(s.ctx());

        revenue_ops::register(&mut v, &mut pool, &op, &clk);

        clock::destroy_for_testing(clk);
        ts::return_to_sender(s, op);
        ts::return_shared(pool);
        ts::return_shared(v);
    };

    // Owner revokes the operator.
    s.next_tx(OWNER);
    {
        let mut v = ts::take_shared<Vault<Stake<TEST_SHARE>>>(s);
        let admin = ts::take_from_sender<VaultAdminCap>(s);
        let op_id = ts::most_recent_id_for_address<OperatorCap>(AGENT).extract();
        vault::revoke_operator(&mut v, &admin, op_id);
        ts::return_to_sender(s, admin);
        ts::return_shared(v);
    };

    // Fund the pool so there is something to claim.
    s.next_tx(OWNER);
    {
        let mut pool = ts::take_shared_by_id<RoyaltyPool<TEST_SHARE, TEST_CURRENCY>>(s, pool_id);
        pool.deposit(balance::create_for_testing<TEST_CURRENCY>(500));
        ts::return_shared(pool);
    };

    // Revoked operator attempts to claim => ERevoked.
    s.next_tx(AGENT);
    {
        let mut v = ts::take_shared<Vault<Stake<TEST_SHARE>>>(s);
        let mut pool = ts::take_shared_by_id<RoyaltyPool<TEST_SHARE, TEST_CURRENCY>>(s, pool_id);
        let op = ts::take_from_sender<OperatorCap>(s);
        let clk = clock::create_for_testing(s.ctx());

        revenue_ops::claim(&mut v, &mut pool, &op, &clk, s.ctx()); // aborts

        clock::destroy_for_testing(clk);
        ts::return_to_sender(s, op);
        ts::return_shared(pool);
        ts::return_shared(v);
    };

    scenario.end();
}

// === unregister: claim drains, then unregister succeeds ===

#[test]
fun test_unregister_after_claim() {
    let mut scenario = ts::begin(OWNER);
    let s = &mut scenario;

    let stake = new_stake(s, 1000);
    let admin_cap = vault::wrap(stake, PUBKEY, s.ctx());
    transfer::public_transfer(admin_cap, OWNER);

    let pool_id = create_pool(s);

    s.next_tx(OWNER);
    {
        let mut v = ts::take_shared<Vault<Stake<TEST_SHARE>>>(s);
        let admin = ts::take_from_sender<VaultAdminCap>(s);
        revenue_ops::install(&mut v, &admin, PAYOUT);
        vault::authorize_operator(&mut v, &admin, AGENT, 1_000, s.ctx());
        ts::return_to_sender(s, admin);
        ts::return_shared(v);
    };

    // register, fund, claim, then unregister — all by the operator.
    s.next_tx(AGENT);
    {
        let mut v = ts::take_shared<Vault<Stake<TEST_SHARE>>>(s);
        let mut pool = ts::take_shared_by_id<RoyaltyPool<TEST_SHARE, TEST_CURRENCY>>(s, pool_id);
        let op = ts::take_from_sender<OperatorCap>(s);
        let clk = clock::create_for_testing(s.ctx());

        revenue_ops::register(&mut v, &mut pool, &op, &clk);
        pool.deposit(balance::create_for_testing<TEST_CURRENCY>(500));
        revenue_ops::claim(&mut v, &mut pool, &op, &clk, s.ctx());
        // pending is now 0, so unregister is allowed.
        revenue_ops::unregister(&mut v, &mut pool, &op, &clk);
        assert!(pool.staked_shares() == 0);

        clock::destroy_for_testing(clk);
        ts::return_to_sender(s, op);
        ts::return_shared(pool);
        ts::return_shared(v);
    };

    scenario.end();
}

// === Owner can update payout; operator cannot ===

#[test]
fun test_set_payout_updates_destination() {
    let mut scenario = ts::begin(OWNER);
    let s = &mut scenario;

    let stake = new_stake(s, 1000);
    let admin_cap = vault::wrap(stake, PUBKEY, s.ctx());
    transfer::public_transfer(admin_cap, OWNER);

    s.next_tx(OWNER);
    {
        let mut v = ts::take_shared<Vault<Stake<TEST_SHARE>>>(s);
        let admin = ts::take_from_sender<VaultAdminCap>(s);

        revenue_ops::install(&mut v, &admin, PAYOUT);
        assert!(revenue_ops::payout(&v) == PAYOUT);

        revenue_ops::set_payout(&mut v, &admin, @0xBEEF);
        assert!(revenue_ops::payout(&v) == @0xBEEF);

        ts::return_to_sender(s, admin);
        ts::return_shared(v);
    };

    scenario.end();
}

// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module miso_vault::vault_tests;

use miso_vault::vault::{Self, Vault, OwnerCap, AgentAuth};
use sui::clock;
use sui::test_scenario as ts;

// === Test fixtures ===

/// A dummy capability to wrap. `key + store` as required by the vault.
public struct TestCap has key, store {
    id: UID,
    secret: u64,
}

/// A dynamic-field key type for a plugin.
public struct TestKey has copy, drop, store {}

/// A plugin config value.
public struct TestConfig has store {
    limit: u64,
}

const OWNER: address = @0xA1;
const AGENT: address = @0xB2;
// Second owner, used to keep two vaults under distinct senders so that
// `take_from_sender` is unambiguous in the cross-cap negative tests.
const OWNER2: address = @0xC3;

fun new_cap(ctx: &mut TxContext): TestCap {
    TestCap { id: object::new(ctx), secret: 42 }
}

// === Happy path ===

#[test]
fun test_full_lifecycle() {
    let mut scenario = ts::begin(OWNER);
    let s = &mut scenario;

    // wrap -> shares Vault, returns OwnerCap to owner.
    let cap = new_cap(s.ctx());
    let owner_cap = vault::wrap(cap, s.ctx());
    transfer::public_transfer(owner_cap, OWNER);

    // authorize_agent + add_plugin (owner).
    ts::next_tx(s, OWNER);
    {
        let mut v = ts::take_shared<Vault<TestCap>>(s);
        let o = ts::take_from_sender<OwnerCap>(s);

        let exp = 1_000;
        vault::authorize_agent(&mut v, &o, AGENT, exp, s.ctx());
        vault::add_plugin(&mut v, &o, TestKey {}, TestConfig { limit: 7 });

        assert!(vault::has_plugin<TestCap, TestKey>(&v), 0);
        // permissionless read of plugin config
        let cfg = vault::config<TestCap, TestKey, TestConfig>(&v, TestKey {});
        assert!(cfg.limit == 7, 1);
        // owner-gated mutable read
        let cfg_mut = vault::config_mut<TestCap, TestKey, TestConfig>(&mut v, &o, TestKey {});
        cfg_mut.limit = 9;

        ts::return_to_sender(s, o);
        ts::return_shared(v);
    };

    // agent borrows -> uses -> put_back (same tx).
    ts::next_tx(s, AGENT);
    {
        let mut v = ts::take_shared<Vault<TestCap>>(s);
        let auth = ts::take_from_sender<AgentAuth>(s);
        assert!(vault::is_agent(&v, object::id(&auth)), 2);
        assert!(vault::auth_vault_id(&auth) == vault::vault_id(&v), 3);

        let clk = clock::create_for_testing(s.ctx());
        // clock at 0 < expires_ms 1000 => OK.
        let (cap, b) = vault::borrow(&mut v, &auth, &clk);
        assert!(cap.secret == 42, 4);
        vault::put_back(&mut v, cap, b);

        clock::destroy_for_testing(clk);
        ts::return_to_sender(s, auth);
        ts::return_shared(v);
    };

    // owner removes plugin then withdraws the cap.
    ts::next_tx(s, OWNER);
    {
        let mut v = ts::take_shared<Vault<TestCap>>(s);
        let o = ts::take_from_sender<OwnerCap>(s);

        let cfg: TestConfig =
            vault::remove_plugin<TestCap, TestKey, TestConfig>(&mut v, &o, TestKey {});
        assert!(cfg.limit == 9, 5);
        let TestConfig { limit: _ } = cfg;
        assert!(!vault::has_plugin<TestCap, TestKey>(&v), 6);

        let recovered = vault::withdraw(v, &o);
        assert!(recovered.secret == 42, 7);
        let TestCap { id, secret: _ } = recovered;
        object::delete(id);

        ts::return_to_sender(s, o);
    };

    scenario.end();
}

// === Negative: revoked auth ===

#[test]
#[expected_failure(abort_code = miso_vault::vault::ERevoked)]
fun test_borrow_revoked_fails() {
    let mut scenario = ts::begin(OWNER);
    let s = &mut scenario;

    let cap = new_cap(s.ctx());
    let owner_cap = vault::wrap(cap, s.ctx());
    transfer::public_transfer(owner_cap, OWNER);

    // authorize.
    ts::next_tx(s, OWNER);
    {
        let mut v = ts::take_shared<Vault<TestCap>>(s);
        let o = ts::take_from_sender<OwnerCap>(s);
        vault::authorize_agent(&mut v, &o, AGENT, 1_000, s.ctx());
        ts::return_to_sender(s, o);
        ts::return_shared(v);
    };

    // grab the auth id.
    ts::next_tx(s, AGENT);
    let auth_id;
    {
        let auth = ts::take_from_sender<AgentAuth>(s);
        auth_id = object::id(&auth);
        ts::return_to_sender(s, auth);
    };

    // revoke.
    ts::next_tx(s, OWNER);
    {
        let mut v = ts::take_shared<Vault<TestCap>>(s);
        let o = ts::take_from_sender<OwnerCap>(s);
        vault::revoke_agent(&mut v, &o, auth_id);
        assert!(!vault::is_agent(&v, auth_id), 0);
        ts::return_to_sender(s, o);
        ts::return_shared(v);
    };

    // agent attempts to borrow with a revoked auth => ERevoked.
    ts::next_tx(s, AGENT);
    {
        let mut v = ts::take_shared<Vault<TestCap>>(s);
        let auth = ts::take_from_sender<AgentAuth>(s);
        let clk = clock::create_for_testing(s.ctx());
        let (cap, b) = vault::borrow(&mut v, &auth, &clk);
        vault::put_back(&mut v, cap, b); // unreachable
        clock::destroy_for_testing(clk);
        ts::return_to_sender(s, auth);
        ts::return_shared(v);
    };

    scenario.end();
}

// === Negative: expired auth ===

#[test]
#[expected_failure(abort_code = miso_vault::vault::EExpired)]
fun test_borrow_expired_fails() {
    let mut scenario = ts::begin(OWNER);
    let s = &mut scenario;

    let cap = new_cap(s.ctx());
    let owner_cap = vault::wrap(cap, s.ctx());
    transfer::public_transfer(owner_cap, OWNER);

    ts::next_tx(s, OWNER);
    {
        let mut v = ts::take_shared<Vault<TestCap>>(s);
        let o = ts::take_from_sender<OwnerCap>(s);
        // expires at 500ms.
        vault::authorize_agent(&mut v, &o, AGENT, 500, s.ctx());
        ts::return_to_sender(s, o);
        ts::return_shared(v);
    };

    ts::next_tx(s, AGENT);
    {
        let mut v = ts::take_shared<Vault<TestCap>>(s);
        let auth = ts::take_from_sender<AgentAuth>(s);
        let mut clk = clock::create_for_testing(s.ctx());
        // advance clock to exactly expiry: 500 is not > 500 => EExpired.
        clock::set_for_testing(&mut clk, 500);
        let (cap, b) = vault::borrow(&mut v, &auth, &clk);
        vault::put_back(&mut v, cap, b); // unreachable
        clock::destroy_for_testing(clk);
        ts::return_to_sender(s, auth);
        ts::return_shared(v);
    };

    scenario.end();
}

// === Negative: auth for a different vault ===

#[test]
#[expected_failure(abort_code = miso_vault::vault::EWrongVault)]
fun test_borrow_wrong_vault_fails() {
    let mut scenario = ts::begin(OWNER);
    let s = &mut scenario;

    // Vault A; its agent auth goes to AGENT.
    let cap_a = new_cap(s.ctx());
    let owner_a = vault::wrap(cap_a, s.ctx());
    transfer::public_transfer(owner_a, OWNER);

    let vault_a_id;
    ts::next_tx(s, OWNER);
    {
        let o_a = ts::take_from_sender<OwnerCap>(s);
        vault_a_id = vault::owner_vault_id(&o_a);
        let mut v_a = ts::take_shared_by_id<Vault<TestCap>>(s, vault_a_id);
        vault::authorize_agent(&mut v_a, &o_a, AGENT, 1_000, s.ctx());
        ts::return_to_sender(s, o_a);
        ts::return_shared(v_a);
    };

    // Vault B (the wrong target).
    ts::next_tx(s, OWNER);
    let cap_b = new_cap(s.ctx());
    let owner_b = vault::wrap(cap_b, s.ctx());
    let vault_b_id = vault::owner_vault_id(&owner_b);
    transfer::public_transfer(owner_b, OWNER);

    // AGENT tries to borrow from vault B using vault A's auth => EWrongVault.
    ts::next_tx(s, AGENT);
    {
        let auth = ts::take_from_sender<AgentAuth>(s);
        let mut v_b = ts::take_shared_by_id<Vault<TestCap>>(s, vault_b_id);
        let clk = clock::create_for_testing(s.ctx());
        let (cap, b) = vault::borrow(&mut v_b, &auth, &clk); // auth is for vault A
        vault::put_back(&mut v_b, cap, b); // unreachable
        clock::destroy_for_testing(clk);
        ts::return_to_sender(s, auth);
        ts::return_shared(v_b);
    };

    let _ = vault_a_id;
    scenario.end();
}

// === Negative: withdraw while a plugin is installed ===

#[test]
#[expected_failure(abort_code = miso_vault::vault::EPluginsInstalled)]
fun test_withdraw_with_plugin_fails() {
    let mut scenario = ts::begin(OWNER);
    let s = &mut scenario;

    let cap = new_cap(s.ctx());
    let owner_cap = vault::wrap(cap, s.ctx());
    transfer::public_transfer(owner_cap, OWNER);

    ts::next_tx(s, OWNER);
    {
        let mut v = ts::take_shared<Vault<TestCap>>(s);
        let o = ts::take_from_sender<OwnerCap>(s);
        vault::add_plugin(&mut v, &o, TestKey {}, TestConfig { limit: 1 });
        // withdraw with a plugin still installed => EPluginsInstalled.
        let recovered = vault::withdraw(v, &o);
        let TestCap { id, secret: _ } = recovered; // unreachable
        object::delete(id);
        ts::return_to_sender(s, o);
    };

    scenario.end();
}

// === Negative: owner-gated fn with the wrong OwnerCap ===

#[test]
#[expected_failure(abort_code = miso_vault::vault::ENotOwner)]
fun test_wrong_owner_cap_fails() {
    let mut scenario = ts::begin(OWNER);
    let s = &mut scenario;

    // Vault A.
    let cap_a = new_cap(s.ctx());
    let owner_a = vault::wrap(cap_a, s.ctx());
    let vault_a_id = vault::owner_vault_id(&owner_a);
    transfer::public_transfer(owner_a, OWNER);

    // Vault B owned by OWNER2 (its OwnerCap is the "wrong" cap for vault A).
    ts::next_tx(s, OWNER2);
    let cap_b = new_cap(s.ctx());
    let owner_b = vault::wrap(cap_b, s.ctx());
    transfer::public_transfer(owner_b, OWNER2);

    // Use vault B's OwnerCap against vault A => ENotOwner.
    ts::next_tx(s, OWNER2);
    let wrong_owner = ts::take_from_sender<OwnerCap>(s);
    ts::next_tx(s, OWNER);
    {
        let mut v_a = ts::take_shared_by_id<Vault<TestCap>>(s, vault_a_id);
        // owner-gated call with the wrong cap.
        vault::authorize_agent(&mut v_a, &wrong_owner, AGENT, 1_000, s.ctx());
        ts::return_shared(v_a);
    };
    ts::return_to_address(OWNER2, wrong_owner);

    scenario.end();
}

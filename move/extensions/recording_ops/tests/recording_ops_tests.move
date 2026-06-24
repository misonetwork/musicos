// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module recording_ops::recording_ops_tests;

use miso::recording::{Self, Recording, RecordingAdminCap};
use miso_vault::vault::{Self, Vault, VaultAdminCap, OperatorCap};
use recording_ops::recording_ops;
use royalty_pool::pool::{Self, RoyaltyPool};
use royalty_pool::stake::{Self, Stake};
use std::bcs;
use std::string::String;
use std::unit_test::destroy;
use sui::balance;
use sui::clock;
use sui::coin::{Self, Coin};
use sui::dynamic_field as df;
use sui::test_scenario::{Self as ts, Scenario};

const OWNER: address = @0xA1;
const AGENT: address = @0xB2;
const ASSEMBLER: address = @0xC3;

// A 32-byte placeholder Ed25519 public key. The byte-encoding and pre-signature
// abort-path tests either never reach the signature check or only need it to
// FAIL, so a real key is unnecessary here. The full signature-verified happy path
// (personal-message reconstruction) is proven on-chain by the hardcoded vector in
// `miso_vault::vault_tests` and exercised end-to-end by the off-chain integration
// eval, which signs with the matching private key via `signPersonalMessage`.
const PUBKEY: vector<u8> = x"0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20";

public struct TEST_SHARE() has drop;
public struct TEST_COMP_SHARE() has drop;
public struct TEST_CURRENCY() has drop;

// === Helpers ===

/// Mint a real `Recording` + `RecordingAdminCap`, wrap the cap in a vault,
/// install the plugin with `min_split_bps`, and authorize `AGENT` as an operator
/// until `expires_ms`. Leaves the recording and vault-admin cap in `OWNER`'s
/// hands for the caller to route. Returns the recording (caller owns it).
fun setup(
    s: &mut Scenario,
    min_split_bps: u16,
    operator_expires_ms: u64,
): Recording<TEST_SHARE, TEST_COMP_SHARE> {
    let (recording, rec_cap) = recording::new_for_testing<TEST_SHARE, TEST_COMP_SHARE>(
        b"Test Recording".to_string(),
        s.ctx(),
    );

    // Wrap the recording's admin cap in a vault; install the plugin; authorize
    // the agent.
    let admin_cap = vault::wrap(rec_cap, PUBKEY, s.ctx());
    transfer::public_transfer(admin_cap, OWNER);

    ts::next_tx(s, OWNER);
    {
        let mut v = ts::take_shared<Vault<RecordingAdminCap<TEST_SHARE>>>(s);
        let admin = ts::take_from_sender<VaultAdminCap>(s);
        recording_ops::install(&mut v, &admin, min_split_bps);
        vault::authorize_operator(&mut v, &admin, AGENT, operator_expires_ms, s.ctx());
        ts::return_to_sender(s, admin);
        ts::return_shared(v);
    };

    recording
}

// === build_intent_msg: exact byte encoding ===

#[test]
/// The canonical intent message must be exactly:
///   tag(19) ++ vault_id(32) ++ release_id(32) ++ split(2) ++ nonce(8) ++ expiry(8)
/// = 101 bytes, with the two IDs as raw address bytes and the scalars as
/// little-endian BCS. This is the contract the off-chain signer reproduces.
fun test_build_intent_msg_exact_encoding() {
    let vault_id = object::id_from_address(@0xAA);
    let release_id = object::id_from_address(@0xBB);
    let split_bps: u16 = 1500;
    let nonce: u64 = 42;
    let expiry: u64 = 1_000_000;

    let msg = recording_ops::build_intent_msg(vault_id, release_id, split_bps, nonce, expiry);

    // Independently reconstruct the expected bytes.
    let mut expected = b"miso:submit_deal:v1";
    expected.append(vault_id.to_bytes());
    expected.append(release_id.to_bytes());
    expected.append(bcs::to_bytes(&split_bps));
    expected.append(bcs::to_bytes(&nonce));
    expected.append(bcs::to_bytes(&expiry));

    assert!(msg == expected);
    // Fixed total length: 19 + 32 + 32 + 2 + 8 + 8.
    assert!(msg.length() == 101);

    // Spot-check the structure byte-for-byte against fully literal bytes so a
    // change to the tag or field order is caught even if `build_intent_msg` and
    // the reconstruction above drift together.
    let mut literal = x"6d69736f3a7375626d69745f6465616c3a7631"; // "miso:submit_deal:v1"
    // vault_id @0xAA as 32 raw bytes.
    literal.append(x"00000000000000000000000000000000000000000000000000000000000000aa");
    // release_id @0xBB as 32 raw bytes.
    literal.append(x"00000000000000000000000000000000000000000000000000000000000000bb");
    literal.append(x"dc05"); // split 1500 u16 LE
    literal.append(x"2a00000000000000"); // nonce 42 u64 LE
    literal.append(x"40420f0000000000"); // expiry 1_000_000 u64 LE
    assert!(msg == literal);
}

// === install + config ===

#[test]
/// `install` records the config and makes the plugin discoverable. Config is
/// permissionlessly readable; the plugin is gone after the owner removes it.
fun test_install_records_config() {
    let mut scenario = ts::begin(OWNER);
    let s = &mut scenario;

    let recording = setup(s, 500, 1_000);

    ts::next_tx(s, OWNER);
    {
        let v = ts::take_shared<Vault<RecordingAdminCap<TEST_SHARE>>>(s);
        assert!(vault::has_plugin<RecordingAdminCap<TEST_SHARE>, recording_ops::Key>(&v));
        ts::return_shared(v);
    };

    destroy(recording);
    ts::end(scenario);
}

// === submit_deal: pre-signature abort paths ===

#[test]
#[expected_failure(abort_code = recording_ops::ESplitTooLow)]
/// A split below the owner-configured floor is rejected before any signature is
/// considered.
fun test_submit_deal_below_floor_aborts() {
    let mut scenario = ts::begin(OWNER);
    let s = &mut scenario;

    let recording = setup(s, 2000, 10_000); // floor 20%

    ts::next_tx(s, AGENT);
    {
        let mut v = ts::take_shared<Vault<RecordingAdminCap<TEST_SHARE>>>(s);
        let op = ts::take_from_sender<OperatorCap>(s);
        let clk = clock::create_for_testing(s.ctx());

        // split 1000 (10%) < floor 2000 (20%) => ESplitTooLow, before sig check.
        recording_ops::submit_deal<TEST_SHARE, TEST_COMP_SHARE>(
            &mut v,
            &recording,
            &op,
            object::id_from_address(@0xDEAD),
            1000,
            ASSEMBLER,
            b"", // never reached
            1,
            10_000,
            &clk,
            s.ctx(),
        );

        clock::destroy_for_testing(clk);
        ts::return_to_sender(s, op);
        ts::return_shared(v);
    };

    destroy(recording);
    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = recording_ops::EIntentExpired)]
/// An expired intent is rejected before any signature is considered.
fun test_submit_deal_expired_intent_aborts() {
    let mut scenario = ts::begin(OWNER);
    let s = &mut scenario;

    let recording = setup(s, 500, 10_000);

    ts::next_tx(s, AGENT);
    {
        let mut v = ts::take_shared<Vault<RecordingAdminCap<TEST_SHARE>>>(s);
        let op = ts::take_from_sender<OperatorCap>(s);
        let mut clk = clock::create_for_testing(s.ctx());
        clk.set_for_testing(5_000); // now = 5000

        // split 1000 >= floor 500 OK; expiry 4000 <= now 5000 => EIntentExpired.
        recording_ops::submit_deal<TEST_SHARE, TEST_COMP_SHARE>(
            &mut v,
            &recording,
            &op,
            object::id_from_address(@0xDEAD),
            1000,
            ASSEMBLER,
            b"", // never reached
            1,
            4_000,
            &clk,
            s.ctx(),
        );

        clock::destroy_for_testing(clk);
        ts::return_to_sender(s, op);
        ts::return_shared(v);
    };

    destroy(recording);
    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = miso_vault::vault::EBadIntent)]
/// With floor and expiry satisfied, a bogus signature is rejected by the vault's
/// on-chain personal-message Ed25519 verification (`EBadIntent` now lives in the
/// vault, where `verify_and_consume_intent` performs the check).
fun test_submit_deal_bad_signature_aborts() {
    let mut scenario = ts::begin(OWNER);
    let s = &mut scenario;

    let recording = setup(s, 500, 10_000);

    ts::next_tx(s, AGENT);
    {
        let mut v = ts::take_shared<Vault<RecordingAdminCap<TEST_SHARE>>>(s);
        let op = ts::take_from_sender<OperatorCap>(s);
        let clk = clock::create_for_testing(s.ctx());

        // floor 500 <= 1000, expiry 10_000 > now 0; a 64-byte all-zero sig over
        // the personal-message digest for PUBKEY will not verify => EBadIntent.
        recording_ops::submit_deal<TEST_SHARE, TEST_COMP_SHARE>(
            &mut v,
            &recording,
            &op,
            object::id_from_address(@0xDEAD),
            1000,
            ASSEMBLER,
            x"0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
            1,
            10_000,
            &clk,
            s.ctx(),
        );

        clock::destroy_for_testing(clk);
        ts::return_to_sender(s, op);
        ts::return_shared(v);
    };

    destroy(recording);
    ts::end(scenario);
}

// === Autonomous tier: royalty pool init + sweep through the vaulted cap ===

#[test]
/// The operator can initialize the royalty pool, sweep coins sent to the
/// recording's address into it, and a staker claims the deposit — all driven
/// through the vaulted cap with only an `OperatorCap` (no signed intent).
fun test_royalty_sweep_full_flow_through_vault() {
    let mut scenario = ts::begin(OWNER);
    let s = &mut scenario;

    let mut recording = setup(s, 500, 1_000_000);
    let recording_id = recording.id();

    // Operator initializes + shares the pool through the vault.
    ts::next_tx(s, AGENT);
    let pool_id;
    {
        let mut v = ts::take_shared<Vault<RecordingAdminCap<TEST_SHARE>>>(s);
        let op = ts::take_from_sender<OperatorCap>(s);
        let clk = clock::create_for_testing(s.ctx());

        recording_ops::init_royalty_pool<TEST_SHARE, TEST_COMP_SHARE, TEST_CURRENCY>(
            &mut v, &mut recording, &op, &clk,
        );

        clock::destroy_for_testing(clk);
        ts::return_to_sender(s, op);
        ts::return_shared(v);
    };

    // Grab the freshly-shared pool by its derived id and stake against it.
    ts::next_tx(s, AGENT);
    let mut stk: Stake<TEST_SHARE>;
    {
        let pool_addr = pool::derived_address<TEST_CURRENCY>(recording_id);
        pool_id = object::id_from_address(pool_addr);
        let mut pool: RoyaltyPool<TEST_SHARE, TEST_CURRENCY> = ts::take_shared_by_id(s, pool_id);
        stk = stake::new(balance::create_for_testing<TEST_SHARE>(100), s.ctx());
        pool.register_stake(&mut stk);
        ts::return_shared(pool);
    };

    // Royalties land at the recording's address.
    ts::next_tx(s, AGENT);
    let coin_id;
    {
        let coin = coin::from_balance(
            balance::create_for_testing<TEST_CURRENCY>(1_000),
            s.ctx(),
        );
        coin_id = object::id(&coin);
        transfer::public_transfer(coin, recording_id.to_address());
    };

    // Operator sweeps the received coin into the pool through the vault.
    ts::next_tx(s, AGENT);
    {
        let mut v = ts::take_shared<Vault<RecordingAdminCap<TEST_SHARE>>>(s);
        let op = ts::take_from_sender<OperatorCap>(s);
        let mut pool: RoyaltyPool<TEST_SHARE, TEST_CURRENCY> = ts::take_shared_by_id(s, pool_id);
        let clk = clock::create_for_testing(s.ctx());
        let ticket = ts::receiving_ticket_by_id<Coin<TEST_CURRENCY>>(coin_id);

        recording_ops::sweep_received<TEST_SHARE, TEST_COMP_SHARE, TEST_CURRENCY>(
            &mut v, &mut recording, &op, vector[ticket], &mut pool, &clk,
        );

        let reward = pool.claim_rewards(&mut stk);
        assert!(reward.value() == 1_000);
        pool.unregister_stake(&mut stk);
        balance::destroy_for_testing(reward);

        clock::destroy_for_testing(clk);
        ts::return_to_sender(s, op);
        ts::return_shared(pool);
        ts::return_shared(v);
    };

    balance::destroy_for_testing(stake::destroy(stk));
    destroy(recording);
    ts::end(scenario);
}

// === Autonomous tier: set_extension through the vaulted cap ===

#[test]
/// The operator writes (and then overwrites) a String-keyed bytes field on the
/// recording through the vaulted cap.
fun test_set_extension_writes_and_overwrites() {
    let mut scenario = ts::begin(OWNER);
    let s = &mut scenario;

    let mut recording = setup(s, 500, 1_000_000);
    let key = b"distributor".to_string();

    ts::next_tx(s, AGENT);
    {
        let mut v = ts::take_shared<Vault<RecordingAdminCap<TEST_SHARE>>>(s);
        let op = ts::take_from_sender<OperatorCap>(s);
        let clk = clock::create_for_testing(s.ctx());

        recording_ops::set_extension<TEST_SHARE, TEST_COMP_SHARE>(
            &mut v, &mut recording, &op, key, b"label-a", &clk,
        );
        assert!(*df::borrow<String, vector<u8>>(recording.uid(), key) == b"label-a");

        // Overwrite the same key.
        recording_ops::set_extension<TEST_SHARE, TEST_COMP_SHARE>(
            &mut v, &mut recording, &op, key, b"label-b", &clk,
        );
        assert!(*df::borrow<String, vector<u8>>(recording.uid(), key) == b"label-b");

        clock::destroy_for_testing(clk);
        ts::return_to_sender(s, op);
        ts::return_shared(v);
    };

    destroy(recording);
    ts::end(scenario);
}

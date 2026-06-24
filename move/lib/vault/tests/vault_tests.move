// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module miso_vault::vault_tests;

use miso_vault::vault::{Self, Vault, VaultAdminCap, OperatorCap};
use sui::clock;
use sui::test_scenario as ts;

// === Test fixtures ===

/// A dummy capability to wrap. `key + store` as required by the vault.
public struct TestCap has key, store {
    id: UID,
    secret: u64,
}

/// The installed plugin's witness type `K`: supplied (by value) at install to fix
/// the type parameter, and used as the witness `W` for the witness-gated cap
/// borrow / nonce consumption. The vault keys the config df by its own
/// `PluginKey<K>` wrapper and records `with_defining_ids<K>()` in `plugins`. A
/// real plugin uses one `drop`-only witness type for these roles.
public struct TestPlugin has drop {}

/// A second, *uninstalled* plugin witness type — used to prove witness gating.
public struct OtherPlugin has drop {}

/// A plugin config value.
public struct TestConfig has store {
    limit: u64,
}

const OWNER: address = @0xA1;
const AGENT: address = @0xB2;
// Second owner, used to keep two vaults under distinct senders so that
// `take_from_sender` is unambiguous in the cross-cap negative tests.
const OWNER2: address = @0xC3;

const PUBKEY: vector<u8> = x"0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20";

fun new_cap(ctx: &mut TxContext): TestCap {
    TestCap { id: object::new(ctx), secret: 42 }
}

// === Happy path ===

#[test]
fun test_full_lifecycle() {
    let mut scenario = ts::begin(OWNER);
    let s = &mut scenario;

    // wrap -> shares Vault, returns VaultAdminCap to owner.
    let cap = new_cap(s.ctx());
    let admin_cap = vault::wrap(cap, PUBKEY, s.ctx());
    transfer::public_transfer(admin_cap, OWNER);

    // authorize_operator + add_plugin (admin).
    ts::next_tx(s, OWNER);
    {
        let mut v = ts::take_shared<Vault<TestCap>>(s);
        let admin = ts::take_from_sender<VaultAdminCap>(s);

        // admin_pubkey reader.
        assert!(*vault::admin_pubkey(&v) == PUBKEY, 0);

        let exp = 1_000;
        vault::authorize_operator(&mut v, &admin, AGENT, exp, s.ctx());
        vault::add_plugin(&mut v, &admin, TestPlugin {}, TestConfig { limit: 7 });

        assert!(vault::has_plugin<TestCap, TestPlugin>(&v), 1);
        // permissionless read of plugin config (by type param, no witness value)
        let cfg = vault::config<TestCap, TestPlugin, TestConfig>(&v);
        assert!(cfg.limit == 7, 2);
        // admin-gated mutable read (by type param, no witness value)
        let cfg_mut = vault::config_mut<TestCap, TestPlugin, TestConfig>(&mut v, &admin);
        cfg_mut.limit = 9;

        ts::return_to_sender(s, admin);
        ts::return_shared(v);
    };

    // operator borrows (plugin path) -> uses -> return_cap (same tx).
    ts::next_tx(s, AGENT);
    {
        let mut v = ts::take_shared<Vault<TestCap>>(s);
        let op = ts::take_from_sender<OperatorCap>(s);
        assert!(vault::is_operator(&v, object::id(&op)), 3);
        assert!(vault::operator_vault_id(&op) == vault::vault_id(&v), 4);

        let clk = clock::create_for_testing(s.ctx());
        // clock at 0 < expires_ms 1000, plugin installed => OK.
        let (cap, b) = vault::borrow_cap_plugin(&mut v, &op, TestPlugin {}, &clk);
        assert!(cap.secret == 42, 5);
        vault::return_cap(&mut v, cap, b);

        clock::destroy_for_testing(clk);
        ts::return_to_sender(s, op);
        ts::return_shared(v);
    };

    // admin removes plugin then withdraws the cap.
    ts::next_tx(s, OWNER);
    {
        let mut v = ts::take_shared<Vault<TestCap>>(s);
        let admin = ts::take_from_sender<VaultAdminCap>(s);

        let cfg: TestConfig =
            vault::remove_plugin<TestCap, TestPlugin, TestConfig>(&mut v, &admin);
        assert!(cfg.limit == 9, 6);
        let TestConfig { limit: _ } = cfg;
        assert!(!vault::has_plugin<TestCap, TestPlugin>(&v), 7);

        let recovered = vault::withdraw(v, &admin);
        assert!(recovered.secret == 42, 8);
        let TestCap { id, secret: _ } = recovered;
        object::delete(id);

        ts::return_to_sender(s, admin);
    };

    scenario.end();
}

// === Admin borrow path ===

#[test]
fun test_borrow_cap_admin() {
    let mut scenario = ts::begin(OWNER);
    let s = &mut scenario;

    let cap = new_cap(s.ctx());
    let admin_cap = vault::wrap(cap, PUBKEY, s.ctx());
    transfer::public_transfer(admin_cap, OWNER);

    ts::next_tx(s, OWNER);
    {
        let mut v = ts::take_shared<Vault<TestCap>>(s);
        let admin = ts::take_from_sender<VaultAdminCap>(s);

        // admin can borrow unconditionally (no operator, no plugin, no clock).
        let (cap, b) = vault::borrow_cap_admin(&mut v, &admin);
        assert!(cap.secret == 42, 0);
        vault::return_cap(&mut v, cap, b);

        ts::return_to_sender(s, admin);
        ts::return_shared(v);
    };

    scenario.end();
}

// === Negative: plugin borrow with an uninstalled plugin witness ===

#[test]
#[expected_failure(abort_code = miso_vault::vault::EPluginNotInstalled)]
fun test_borrow_cap_plugin_not_installed_fails() {
    let mut scenario = ts::begin(OWNER);
    let s = &mut scenario;

    let cap = new_cap(s.ctx());
    let admin_cap = vault::wrap(cap, PUBKEY, s.ctx());
    transfer::public_transfer(admin_cap, OWNER);

    // authorize an operator but install a plugin keyed by TestPlugin only; the
    // borrow below uses OtherPlugin as the witness, which is NOT installed.
    ts::next_tx(s, OWNER);
    {
        let mut v = ts::take_shared<Vault<TestCap>>(s);
        let admin = ts::take_from_sender<VaultAdminCap>(s);
        vault::authorize_operator(&mut v, &admin, AGENT, 1_000, s.ctx());
        vault::add_plugin(&mut v, &admin, TestPlugin {}, TestConfig { limit: 1 });
        ts::return_to_sender(s, admin);
        ts::return_shared(v);
    };

    ts::next_tx(s, AGENT);
    {
        let mut v = ts::take_shared<Vault<TestCap>>(s);
        let op = ts::take_from_sender<OperatorCap>(s);
        let clk = clock::create_for_testing(s.ctx());
        // OtherPlugin witness is not in `plugins` => EPluginNotInstalled.
        let (cap, b) = vault::borrow_cap_plugin(&mut v, &op, OtherPlugin {}, &clk);
        vault::return_cap(&mut v, cap, b); // unreachable
        clock::destroy_for_testing(clk);
        ts::return_to_sender(s, op);
        ts::return_shared(v);
    };

    scenario.end();
}

// === Signed personal-message intent: hardcoded on-chain vector ===
//
// The following three tests use a REAL (pubkey, msg, sig) triple produced
// off-chain by `@mysten/sui`: an `Ed25519Keypair` (from the fixed 32-byte secret
// 0x0102..1f20) signed `INTENT_MSG` with `signPersonalMessage`, and the resulting
// serialized wallet signature was split via `parseSerializedSignature` into the
// raw 64-byte Ed25519 signature (`INTENT_SIG`) and 32-byte public key
// (`INTENT_PUBKEY`). `INTENT_MSG` is exactly `recording_ops::build_intent_msg`
// for vault @0xAA, release @0xBB, split 1500, nonce 42, expiry 1_000_000 — the
// 101-byte canonical encoding. These vectors prove, independent of any off-chain
// eval, that `verify_and_consume_intent` reconstructs the Sui personal-message
// digest `blake2b256([3,0,0] ++ bcs(PersonalMessage{ message: msg }))` correctly
// and verifies a wallet's `signPersonalMessage` output on-chain.

/// The personal-message public key matching `INTENT_SIG` (raw 32-byte Ed25519).
const INTENT_PUBKEY: vector<u8> =
    x"79b5562e8fe654f94078b112e8a98ba7901f853ae695bed7e0e3910bad049664";
/// The 101-byte canonical intent message that was signed.
const INTENT_MSG: vector<u8> =
    x"6d69736f3a7375626d69745f6465616c3a763100000000000000000000000000000000000000000000000000000000000000aa00000000000000000000000000000000000000000000000000000000000000bbdc052a0000000000000040420f0000000000";
/// The raw 64-byte Ed25519 signature `signPersonalMessage(INTENT_MSG)` produced.
const INTENT_SIG: vector<u8> =
    x"a1c3078e07c04f90b6450ca1ace68610ba4b4c80f21bb863b75e08780aeff30e8a5350bc5ffd0ac48637d50e1986a0ce059626efc7338f87d5ffaca4e1fa0d0d";

#[test]
/// The valid (pubkey, msg, sig) triple PASSES: the vault reconstructs the
/// personal-message digest and Ed25519-verifies it against `admin_pubkey`, then
/// records the nonce. This is the key on-chain proof of the personal-message
/// reconstruction.
fun test_verify_and_consume_intent_valid_vector() {
    let mut scenario = ts::begin(OWNER);
    let s = &mut scenario;

    // Wrap a vault whose admin_pubkey IS the personal-message signer's pubkey.
    let cap = new_cap(s.ctx());
    let admin_cap = vault::wrap(cap, INTENT_PUBKEY, s.ctx());
    transfer::public_transfer(admin_cap, OWNER);

    ts::next_tx(s, OWNER);
    {
        let mut v = ts::take_shared<Vault<TestCap>>(s);
        let admin = ts::take_from_sender<VaultAdminCap>(s);

        // Valid signature over the canonical message => passes, nonce 42 consumed.
        vault::verify_and_consume_intent(&mut v, INTENT_MSG, INTENT_SIG, 42u64);

        ts::return_to_sender(s, admin);
        ts::return_shared(v);
    };

    scenario.end();
}

#[test]
#[expected_failure(abort_code = miso_vault::vault::EBadIntent)]
/// Flipping a single byte of the signed message breaks the personal-message
/// digest, so Ed25519 verification fails => EBadIntent.
fun test_verify_and_consume_intent_flipped_byte_fails() {
    let mut scenario = ts::begin(OWNER);
    let s = &mut scenario;

    let cap = new_cap(s.ctx());
    let admin_cap = vault::wrap(cap, INTENT_PUBKEY, s.ctx());
    transfer::public_transfer(admin_cap, OWNER);

    ts::next_tx(s, OWNER);
    {
        let mut v = ts::take_shared<Vault<TestCap>>(s);
        let admin = ts::take_from_sender<VaultAdminCap>(s);

        // Flip the first byte of the message: 'm' (0x6d) -> 0x6e. The signature no
        // longer matches the digest of the tampered message => EBadIntent.
        let mut tampered = INTENT_MSG;
        *tampered.borrow_mut(0) = 0x6e;
        vault::verify_and_consume_intent(&mut v, tampered, INTENT_SIG, 42u64);

        ts::return_to_sender(s, admin);
        ts::return_shared(v);
    };

    scenario.end();
}

#[test]
#[expected_failure(abort_code = miso_vault::vault::ENonceUsed)]
/// Replaying the same valid intent (same nonce) a second time aborts ENonceUsed:
/// the first call recorded nonce 42, so the second is rejected as a replay.
fun test_verify_and_consume_intent_replay_fails() {
    let mut scenario = ts::begin(OWNER);
    let s = &mut scenario;

    let cap = new_cap(s.ctx());
    let admin_cap = vault::wrap(cap, INTENT_PUBKEY, s.ctx());
    transfer::public_transfer(admin_cap, OWNER);

    ts::next_tx(s, OWNER);
    {
        let mut v = ts::take_shared<Vault<TestCap>>(s);
        let admin = ts::take_from_sender<VaultAdminCap>(s);

        // First call succeeds and burns nonce 42; the replay with the same nonce
        // aborts ENonceUsed (the signature is still valid, but the nonce is spent).
        vault::verify_and_consume_intent(&mut v, INTENT_MSG, INTENT_SIG, 42u64);
        vault::verify_and_consume_intent(&mut v, INTENT_MSG, INTENT_SIG, 42u64); // unreachable

        ts::return_to_sender(s, admin);
        ts::return_shared(v);
    };

    scenario.end();
}

// === secp256r1 (P-256) personal-message intent: hardcoded on-chain vector ===
//
// The same proof shape as the Ed25519 vector above, but for the secp256r1 /
// WebCrypto-P-256 path. The triple was produced off-chain by `@mysten/sui`: a
// `Secp256r1Keypair` (from the fixed 32-byte secret 0x0102..1f20) signed the
// SAME 101-byte `INTENT_MSG` with `signPersonalMessage`, and the resulting
// serialized wallet signature was split via `parseSerializedSignature` into the
// raw 64-byte secp256r1 `(r, s)` signature (`R1_SIG`) and the compressed 33-byte
// SEC1 public key (`R1_PUBKEY`).
//
// This proves the secp256r1 reconstruction end to end: the vault rebuilds the
// personal-message digest `blake2b256([3,0,0] ++ bcs(PersonalMessage{ message:
// INTENT_MSG }))` (identical to the Ed25519 path) and verifies it via
// `secp256r1_verify(sig, pubkey, digest, /*hash=*/ SHA256)`. The SHA256 flag is
// load-bearing: the native re-hashes the digest with sha256 internally, matching
// `Secp256r1Keypair.sign`, which signs `sha256(digest)`. Reproduce the vector
// off-chain with:
//
//   import { Secp256r1Keypair } from '@mysten/sui/keypairs/secp256r1';
//   import { parseSerializedSignature } from '@mysten/sui/cryptography';
//   const secret = Uint8Array.from('0102...1f20'.match(/../g).map(h=>parseInt(h,16)));
//   const kp = Secp256r1Keypair.fromSecretKey(secret);
//   const { signature } = await kp.signPersonalMessage(INTENT_MSG_BYTES);
//   const { publicKey, signature: raw } = parseSerializedSignature(signature);
//
// secp256r1 ECDSA signatures are NOT deterministic across the spec (RFC6979 with
// lowS makes @noble's output deterministic for a fixed key+msg, so this exact
// vector is reproducible), but verification is what matters: any valid `(r, s)`
// for this (pubkey, digest) passes.

/// The compressed 33-byte SEC1 secp256r1 public key matching `R1_SIG`.
const R1_PUBKEY: vector<u8> =
    x"02515c3d6eb9e396b904d3feca7f54fdcd0cc1e997bf375dca515ad0a6c3b4035f";
/// The raw 64-byte secp256r1 `(r, s)` signature of
/// `Secp256r1Keypair.signPersonalMessage(INTENT_MSG)`.
const R1_SIG: vector<u8> =
    x"8058393a585b536f9cd09115d9f0f0787c2e07c4ee64fffabbf08679f12804a558cabcfaf38bfd896cac45cb82aa4d6c5f41aa0b41b653cad4dd39c33733dd90";

#[test]
/// The valid secp256r1 (pubkey, msg, sig) triple PASSES: a vault wrapped with
/// `SCHEME_SECP256R1` reconstructs the personal-message digest and verifies it
/// with `secp256r1_verify(.., SHA256)` against `admin_pubkey`, then records the
/// nonce. This is the key on-chain proof of the secp256r1 personal-message
/// reconstruction (digest bytes + SHA256 hash flag + compressed-pubkey format).
fun test_verify_and_consume_intent_secp256r1_valid_vector() {
    let mut scenario = ts::begin(OWNER);
    let s = &mut scenario;

    // Wrap a vault under the secp256r1 scheme whose admin_pubkey IS the P-256
    // personal-message signer's compressed public key.
    let cap = new_cap(s.ctx());
    let admin_cap =
        vault::wrap_with_scheme(cap, R1_PUBKEY, vault::scheme_secp256r1(), s.ctx());
    transfer::public_transfer(admin_cap, OWNER);

    ts::next_tx(s, OWNER);
    {
        let mut v = ts::take_shared<Vault<TestCap>>(s);
        let admin = ts::take_from_sender<VaultAdminCap>(s);

        assert!(vault::scheme(&v) == vault::scheme_secp256r1(), 0);
        assert!(*vault::admin_pubkey(&v) == R1_PUBKEY, 1);

        // Valid secp256r1 signature over the canonical message => passes, nonce 7
        // consumed.
        vault::verify_and_consume_intent(&mut v, INTENT_MSG, R1_SIG, 7u64);

        ts::return_to_sender(s, admin);
        ts::return_shared(v);
    };

    scenario.end();
}

#[test]
#[expected_failure(abort_code = miso_vault::vault::EBadIntent)]
/// Flipping a single byte of the signed message breaks the personal-message
/// digest, so secp256r1 verification fails => EBadIntent. Mirrors the Ed25519
/// negative, proving the digest binds the message under secp256r1 too.
fun test_verify_and_consume_intent_secp256r1_flipped_byte_fails() {
    let mut scenario = ts::begin(OWNER);
    let s = &mut scenario;

    let cap = new_cap(s.ctx());
    let admin_cap =
        vault::wrap_with_scheme(cap, R1_PUBKEY, vault::scheme_secp256r1(), s.ctx());
    transfer::public_transfer(admin_cap, OWNER);

    ts::next_tx(s, OWNER);
    {
        let mut v = ts::take_shared<Vault<TestCap>>(s);
        let admin = ts::take_from_sender<VaultAdminCap>(s);

        // Flip the first byte of the message: 'm' (0x6d) -> 0x6e. The secp256r1
        // signature no longer matches the digest of the tampered message =>
        // EBadIntent.
        let mut tampered = INTENT_MSG;
        *tampered.borrow_mut(0) = 0x6e;
        vault::verify_and_consume_intent(&mut v, tampered, R1_SIG, 7u64);

        ts::return_to_sender(s, admin);
        ts::return_shared(v);
    };

    scenario.end();
}

#[test]
#[expected_failure(abort_code = miso_vault::vault::EBadIntent)]
/// Cross-scheme guard: the valid secp256r1 signature must NOT verify when the
/// vault is (mis)configured as Ed25519. Verification dispatches on the stored
/// scheme, so an Ed25519 vault runs `ed25519_verify` over the secp256r1 sig and
/// rejects it => EBadIntent. (Here the 33-byte key is wrapped via the low-level
/// scheme entrypoint with the Ed25519 tag; in practice `wrap_with_scheme` would
/// reject a 33-byte Ed25519 key, so this isolates the verify dispatch using a
/// 32-byte truncation of the key purely to reach the verify call.)
fun test_secp256r1_sig_rejected_under_ed25519_scheme() {
    let mut scenario = ts::begin(OWNER);
    let s = &mut scenario;

    // A syntactically valid 32-byte Ed25519 key (so wrap passes the length gate),
    // but it is NOT the signer of R1_SIG, and the scheme is Ed25519. Either way
    // the secp256r1 signature cannot verify => EBadIntent.
    let cap = new_cap(s.ctx());
    let admin_cap = vault::wrap(cap, PUBKEY, s.ctx()); // SCHEME_ED25519
    transfer::public_transfer(admin_cap, OWNER);

    ts::next_tx(s, OWNER);
    {
        let mut v = ts::take_shared<Vault<TestCap>>(s);
        let admin = ts::take_from_sender<VaultAdminCap>(s);

        // secp256r1 sig under an Ed25519-scheme vault => routed to ed25519_verify
        // => fails => EBadIntent.
        vault::verify_and_consume_intent(&mut v, INTENT_MSG, R1_SIG, 7u64);

        ts::return_to_sender(s, admin);
        ts::return_shared(v);
    };

    scenario.end();
}

#[test]
#[expected_failure(abort_code = miso_vault::vault::EBadScheme)]
/// `wrap_with_scheme` rejects a pubkey whose length is wrong for the scheme: a
/// 32-byte key under the secp256r1 scheme (which expects a compressed 33-byte
/// point) aborts EBadScheme at creation rather than failing silently later.
fun test_wrap_with_scheme_bad_pubkey_len_fails() {
    let mut scenario = ts::begin(OWNER);
    let s = &mut scenario;

    let cap = new_cap(s.ctx());
    // PUBKEY is 32 bytes; secp256r1 wants 33 => EBadScheme.
    let admin_cap =
        vault::wrap_with_scheme(cap, PUBKEY, vault::scheme_secp256r1(), s.ctx());
    transfer::public_transfer(admin_cap, OWNER); // unreachable

    scenario.end();
}

#[test]
#[expected_failure(abort_code = miso_vault::vault::EBadScheme)]
/// `wrap_with_scheme` rejects an unknown scheme tag outright.
fun test_wrap_with_unknown_scheme_fails() {
    let mut scenario = ts::begin(OWNER);
    let s = &mut scenario;

    let cap = new_cap(s.ctx());
    let admin_cap = vault::wrap_with_scheme(cap, R1_PUBKEY, 99u8, s.ctx());
    transfer::public_transfer(admin_cap, OWNER); // unreachable

    scenario.end();
}

// === Negative: revoked operator ===

#[test]
#[expected_failure(abort_code = miso_vault::vault::ERevoked)]
fun test_borrow_revoked_fails() {
    let mut scenario = ts::begin(OWNER);
    let s = &mut scenario;

    let cap = new_cap(s.ctx());
    let admin_cap = vault::wrap(cap, PUBKEY, s.ctx());
    transfer::public_transfer(admin_cap, OWNER);

    // authorize + install plugin (so the borrow reaches the revocation check).
    ts::next_tx(s, OWNER);
    {
        let mut v = ts::take_shared<Vault<TestCap>>(s);
        let admin = ts::take_from_sender<VaultAdminCap>(s);
        vault::authorize_operator(&mut v, &admin, AGENT, 1_000, s.ctx());
        vault::add_plugin(&mut v, &admin, TestPlugin {}, TestConfig { limit: 1 });
        ts::return_to_sender(s, admin);
        ts::return_shared(v);
    };

    // grab the operator id.
    ts::next_tx(s, AGENT);
    let operator_id;
    {
        let op = ts::take_from_sender<OperatorCap>(s);
        operator_id = object::id(&op);
        ts::return_to_sender(s, op);
    };

    // revoke.
    ts::next_tx(s, OWNER);
    {
        let mut v = ts::take_shared<Vault<TestCap>>(s);
        let admin = ts::take_from_sender<VaultAdminCap>(s);
        vault::revoke_operator(&mut v, &admin, operator_id);
        assert!(!vault::is_operator(&v, operator_id), 0);
        ts::return_to_sender(s, admin);
        ts::return_shared(v);
    };

    // operator attempts to borrow with a revoked cap => ERevoked.
    ts::next_tx(s, AGENT);
    {
        let mut v = ts::take_shared<Vault<TestCap>>(s);
        let op = ts::take_from_sender<OperatorCap>(s);
        let clk = clock::create_for_testing(s.ctx());
        let (cap, b) = vault::borrow_cap_plugin(&mut v, &op, TestPlugin {}, &clk);
        vault::return_cap(&mut v, cap, b); // unreachable
        clock::destroy_for_testing(clk);
        ts::return_to_sender(s, op);
        ts::return_shared(v);
    };

    scenario.end();
}

// === Negative: expired operator ===

#[test]
#[expected_failure(abort_code = miso_vault::vault::EExpired)]
fun test_borrow_expired_fails() {
    let mut scenario = ts::begin(OWNER);
    let s = &mut scenario;

    let cap = new_cap(s.ctx());
    let admin_cap = vault::wrap(cap, PUBKEY, s.ctx());
    transfer::public_transfer(admin_cap, OWNER);

    ts::next_tx(s, OWNER);
    {
        let mut v = ts::take_shared<Vault<TestCap>>(s);
        let admin = ts::take_from_sender<VaultAdminCap>(s);
        // expires at 500ms.
        vault::authorize_operator(&mut v, &admin, AGENT, 500, s.ctx());
        vault::add_plugin(&mut v, &admin, TestPlugin {}, TestConfig { limit: 1 });
        ts::return_to_sender(s, admin);
        ts::return_shared(v);
    };

    ts::next_tx(s, AGENT);
    {
        let mut v = ts::take_shared<Vault<TestCap>>(s);
        let op = ts::take_from_sender<OperatorCap>(s);
        let mut clk = clock::create_for_testing(s.ctx());
        // advance clock to exactly expiry: 500 is not > 500 => EExpired.
        clock::set_for_testing(&mut clk, 500);
        let (cap, b) = vault::borrow_cap_plugin(&mut v, &op, TestPlugin {}, &clk);
        vault::return_cap(&mut v, cap, b); // unreachable
        clock::destroy_for_testing(clk);
        ts::return_to_sender(s, op);
        ts::return_shared(v);
    };

    scenario.end();
}

// === Negative: operator for a different vault ===

#[test]
#[expected_failure(abort_code = miso_vault::vault::EWrongVault)]
fun test_borrow_wrong_vault_fails() {
    let mut scenario = ts::begin(OWNER);
    let s = &mut scenario;

    // Vault A; its operator cap goes to AGENT.
    let cap_a = new_cap(s.ctx());
    let admin_a = vault::wrap(cap_a, PUBKEY, s.ctx());
    transfer::public_transfer(admin_a, OWNER);

    let vault_a_id;
    ts::next_tx(s, OWNER);
    {
        let admin_a = ts::take_from_sender<VaultAdminCap>(s);
        vault_a_id = vault::admin_vault_id(&admin_a);
        let mut v_a = ts::take_shared_by_id<Vault<TestCap>>(s, vault_a_id);
        vault::authorize_operator(&mut v_a, &admin_a, AGENT, 1_000, s.ctx());
        ts::return_to_sender(s, admin_a);
        ts::return_shared(v_a);
    };

    // Vault B (the wrong target) — install the plugin so the borrow reaches the
    // wrong-vault check rather than aborting on EPluginNotInstalled.
    ts::next_tx(s, OWNER);
    let cap_b = new_cap(s.ctx());
    let admin_b = vault::wrap(cap_b, PUBKEY, s.ctx());
    let vault_b_id = vault::admin_vault_id(&admin_b);
    transfer::public_transfer(admin_b, OWNER);

    ts::next_tx(s, OWNER);
    {
        let admin_b = ts::take_from_sender<VaultAdminCap>(s);
        let mut v_b = ts::take_shared_by_id<Vault<TestCap>>(s, vault_b_id);
        vault::add_plugin(&mut v_b, &admin_b, TestPlugin {}, TestConfig { limit: 1 });
        ts::return_to_sender(s, admin_b);
        ts::return_shared(v_b);
    };

    // AGENT tries to borrow from vault B using vault A's operator => EWrongVault.
    ts::next_tx(s, AGENT);
    {
        let op = ts::take_from_sender<OperatorCap>(s);
        let mut v_b = ts::take_shared_by_id<Vault<TestCap>>(s, vault_b_id);
        let clk = clock::create_for_testing(s.ctx());
        let (cap, b) = vault::borrow_cap_plugin(&mut v_b, &op, TestPlugin {}, &clk);
        vault::return_cap(&mut v_b, cap, b); // unreachable
        clock::destroy_for_testing(clk);
        ts::return_to_sender(s, op);
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
    let admin_cap = vault::wrap(cap, PUBKEY, s.ctx());
    transfer::public_transfer(admin_cap, OWNER);

    ts::next_tx(s, OWNER);
    {
        let mut v = ts::take_shared<Vault<TestCap>>(s);
        let admin = ts::take_from_sender<VaultAdminCap>(s);
        vault::add_plugin(&mut v, &admin, TestPlugin {}, TestConfig { limit: 1 });
        // withdraw with a plugin still installed => EPluginsInstalled.
        let recovered = vault::withdraw(v, &admin);
        let TestCap { id, secret: _ } = recovered; // unreachable
        object::delete(id);
        ts::return_to_sender(s, admin);
    };

    scenario.end();
}

// === Owner-direct uninstall: no plugin cooperation needed ===

/// The whole point of the vault-owned `PluginKey<K>` keying: the OWNER can
/// uninstall ANY installed plugin purely by type parameter — `remove_plugin<Cap,
/// K, Config>` takes no witness value and calls into no plugin module — and then
/// withdraw the wrapped cap. This proves the `withdraw` escape hatch is
/// structurally un-loseable: a plugin that ships no `uninstall` (or whose package
/// is gone) can still be torn down by the owner directly through the vault.
#[test]
fun test_owner_can_remove_any_plugin_directly() {
    let mut scenario = ts::begin(OWNER);
    let s = &mut scenario;

    let cap = new_cap(s.ctx());
    let admin_cap = vault::wrap(cap, PUBKEY, s.ctx());
    transfer::public_transfer(admin_cap, OWNER);

    // Install a plugin keyed by the `TestPlugin` witness type.
    ts::next_tx(s, OWNER);
    {
        let mut v = ts::take_shared<Vault<TestCap>>(s);
        let admin = ts::take_from_sender<VaultAdminCap>(s);
        vault::add_plugin(&mut v, &admin, TestPlugin {}, TestConfig { limit: 5 });
        assert!(vault::has_plugin<TestCap, TestPlugin>(&v), 0);
        ts::return_to_sender(s, admin);
        ts::return_shared(v);
    };

    // The owner removes it WITHOUT the plugin module's help: `remove_plugin` is
    // keyed purely by the `TestPlugin` type parameter, takes no witness value,
    // and is callable with just the `VaultAdminCap`. Then the now-plugin-free
    // cap is withdrawn.
    ts::next_tx(s, OWNER);
    {
        let mut v = ts::take_shared<Vault<TestCap>>(s);
        let admin = ts::take_from_sender<VaultAdminCap>(s);

        let cfg: TestConfig =
            vault::remove_plugin<TestCap, TestPlugin, TestConfig>(&mut v, &admin);
        assert!(cfg.limit == 5, 1);
        let TestConfig { limit: _ } = cfg;
        assert!(!vault::has_plugin<TestCap, TestPlugin>(&v), 2);

        // With no plugins left, the escape hatch is available.
        let recovered = vault::withdraw(v, &admin);
        assert!(recovered.secret == 42, 3);
        let TestCap { id, secret: _ } = recovered;
        object::delete(id);

        ts::return_to_sender(s, admin);
    };

    scenario.end();
}

// === Negative: admin-gated fn with the wrong VaultAdminCap ===

#[test]
#[expected_failure(abort_code = miso_vault::vault::ENotAdmin)]
fun test_wrong_admin_cap_fails() {
    let mut scenario = ts::begin(OWNER);
    let s = &mut scenario;

    // Vault A.
    let cap_a = new_cap(s.ctx());
    let admin_a = vault::wrap(cap_a, PUBKEY, s.ctx());
    let vault_a_id = vault::admin_vault_id(&admin_a);
    transfer::public_transfer(admin_a, OWNER);

    // Vault B owned by OWNER2 (its VaultAdminCap is the "wrong" cap for vault A).
    ts::next_tx(s, OWNER2);
    let cap_b = new_cap(s.ctx());
    let admin_b = vault::wrap(cap_b, PUBKEY, s.ctx());
    transfer::public_transfer(admin_b, OWNER2);

    // Use vault B's VaultAdminCap against vault A => ENotAdmin.
    ts::next_tx(s, OWNER2);
    let wrong_admin = ts::take_from_sender<VaultAdminCap>(s);
    ts::next_tx(s, OWNER);
    {
        let mut v_a = ts::take_shared_by_id<Vault<TestCap>>(s, vault_a_id);
        // admin-gated call with the wrong cap.
        vault::authorize_operator(&mut v_a, &wrong_admin, AGENT, 1_000, s.ctx());
        ts::return_shared(v_a);
    };
    ts::return_to_address(OWNER2, wrong_admin);

    scenario.end();
}

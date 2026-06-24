// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache 2.0

#[test_only]
module release_ops::release_ops_tests;

use miso::disc;
use miso::release::{Self, Release, ReleaseAdminCap};
use miso::track;
use miso_vault::vault::{Self, Vault, VaultAdminCap};
use release_ops::release_ops::{Self, Config};
use std::string;
use std::unit_test::destroy;
use sui::test_scenario as ts;

const OWNER: address = @0xA1;
const PUBKEY: vector<u8> = x"0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20";

/// Build a minimal real `Release` + its `ReleaseAdminCap` for testing. One disc,
/// one track at 100% (10_000 bps) so split validation is irrelevant to the
/// `new_for_testing` path (which skips split-sum checks).
fun new_release(ctx: &mut TxContext): (Release, ReleaseAdminCap) {
    let recording_id = object::id_from_address(@0xBEEF);
    let release_placeholder = object::id_from_address(@0x0);
    let track = track::new_for_testing(recording_id, release_placeholder, 10_000);
    let disc = disc::new(vector[track], option::none());
    release::new_for_testing(string::utf8(b"Test Release"), vector[disc], ctx)
}

// === install / config ===

#[test]
fun test_install_and_config() {
    let mut scenario = ts::begin(OWNER);
    let s = &mut scenario;

    // Mint a real ReleaseAdminCap and wrap it in a vault.
    let (release, cap) = new_release(s.ctx());
    let admin_cap = vault::wrap(cap, PUBKEY, s.ctx());
    transfer::public_transfer(admin_cap, OWNER);
    // Release isn't needed for install; `Release` is `key`-only so dispose via destroy.
    destroy(release);

    ts::next_tx(s, OWNER);
    {
        let mut v = ts::take_shared<Vault<ReleaseAdminCap>>(s);
        let admin = ts::take_from_sender<VaultAdminCap>(s);

        // Not installed yet.
        assert!(!vault::has_plugin<ReleaseAdminCap, release_ops::Key>(&v), 0);

        release_ops::install(&mut v, &admin);

        // Installed: plugin tag recorded + config readable (by type param).
        assert!(vault::has_plugin<ReleaseAdminCap, release_ops::Key>(&v), 1);
        let _cfg: &Config = vault::config<ReleaseAdminCap, release_ops::Key, Config>(&v);

        ts::return_to_sender(s, admin);
        ts::return_shared(v);
    };

    scenario.end();
}

// === metadata helper ===

#[test]
fun test_write_metadata_init_and_overwrite() {
    let mut scenario = ts::begin(OWNER);
    let s = &mut scenario;

    // The helper operates on a bare UID — exercise init then overwrite.
    let mut uid = object::new(s.ctx());

    release_ops::write_metadata_for_testing(&mut uid, string::utf8(b"first"));
    release_ops::write_metadata_for_testing(&mut uid, string::utf8(b"second"));

    object::delete(uid);
    scenario.end();
}

// === metadata views on a real release ===

#[test]
fun test_metadata_views() {
    let mut scenario = ts::begin(OWNER);
    let s = &mut scenario;

    let (mut release, cap) = new_release(s.ctx());

    // No metadata yet.
    assert!(!release_ops::has_metadata(&release), 0);

    // Write directly through the cap-gated uid_mut (mirrors set_extension's body).
    release_ops::write_metadata_for_testing(
        release::uid_mut(&mut release, &cap),
        string::utf8(b"hello"),
    );

    assert!(release_ops::has_metadata(&release), 1);
    assert!(*release_ops::metadata(&release) == string::utf8(b"hello"), 2);

    destroy(release);
    destroy(cap);
    scenario.end();
}

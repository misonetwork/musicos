// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache 2.0

/// Vaulted operations plugin for releases.
///
/// `release_ops` is a `miso_vault` plugin that operates a vaulted, non-generic
/// `ReleaseAdminCap` on behalf of an operator. The vault holds the cap; this
/// plugin installs a `Config` (keyed by the vault under `vault::PluginKey<Key>`)
/// and exposes autonomous, operator-only entry points that hot-potato-borrow the
/// cap for the duration of a single transaction, perform a release op, and
/// return it.
///
/// The key post-publish release op is revenue distribution: routing funds that
/// have landed on the release's address out to each track's recording, by the
/// track `split_bps` fixed in core at release creation. Two sources mirror the
/// `release_revenue_distributor` primitives:
///
/// - `distribute_received`: receive coin objects sent to the release's address.
/// - `distribute_accrued`: redeem from the release's balance accumulator.
///
/// Because release distribution is driven entirely by on-chain track splits, the
/// plugin carries no economic configuration — `Config` is an empty marker whose
/// only job is to register `Key` in the vault's `plugins` set (the witness gate
/// for `borrow_cap_plugin`).
///
/// `set_extension` is the metadata op: it borrows the cap and writes this
/// plugin's own extension record onto the release's UID via the cap-gated
/// `release::uid_mut`, so every write is authorized by the vaulted admin cap.
module release_ops::release_ops;

use miso::release::{Self, Release, ReleaseAdminCap};
use miso_vault::vault::{Self, Vault, VaultAdminCap, OperatorCap};
use release_revenue_distributor::release_revenue_distributor;
use std::string::String;
use sui::clock::Clock;
use sui::coin::Coin;
use sui::dynamic_field as df;
use sui::transfer::Receiving;

// === Plugin identity ===

/// The plugin's witness type. It fixes the type parameter `K` at install (the
/// vault keys the `Config` df by its own `vault::PluginKey<Key>` wrapper) and is
/// the witness `W` passed to `vault::borrow_cap_plugin`, so the installed plugin
/// tag matches the witness gate. A `drop`-only witness: the vault — not this
/// module — owns the config df key. A client resolves this vault's config under
/// `release_ops::release_ops::Key` / `::Config`.
public struct Key() has drop;

/// The plugin's per-vault config. Release distribution is by fixed on-chain track
/// splits, so there is no economic knob to store — this is a pure installation
/// marker that lands `Key` in the vault's `plugins` set.
public struct Config has store, drop {}

// === Extension metadata ===

/// Dynamic-field key for this plugin's extension record on a `Release`'s UID.
public struct ReleaseOpsMetadataKey() has copy, drop, store;

/// The per-release extension record written by `set_extension`. A single opaque
/// metadata string owned by this plugin's namespace.
public struct ReleaseOpsMetadata has store, drop {
    metadata: String,
}

// === Install ===

/// Install the plugin on a vault wrapping a `ReleaseAdminCap`. Admin-gated:
/// records `Key` in the vault's `plugins` set so the operator borrow path is
/// unlocked.
public fun install(v: &mut Vault<ReleaseAdminCap>, admin: &VaultAdminCap) {
    vault::add_plugin(v, admin, Key(), Config {});
}

/// Uninstall the plugin, returning the stored `Config`. Owner-only (requires the
/// `VaultAdminCap`). A convenience wrapper: because the vault owns the config df
/// key (`vault::PluginKey<Key>`), the owner can equivalently uninstall directly
/// via `vault::remove_plugin<_, Key, Config>` without this module's help, so the
/// wrapped `ReleaseAdminCap` can never be permanently trapped.
public fun uninstall(v: &mut Vault<ReleaseAdminCap>, admin: &VaultAdminCap): Config {
    vault::remove_plugin<_, Key, Config>(v, admin)
}

// === Autonomous operator ops ===

/// Receive coins sent to the release's address and distribute them to tracks.
/// Operator-only: borrows the vaulted `ReleaseAdminCap` (witness + live-operator
/// gated), distributes, and returns the cap in the same tx.
public entry fun distribute_received<Cur>(
    v: &mut Vault<ReleaseAdminCap>,
    rel: &mut Release,
    op: &OperatorCap,
    coins: vector<Receiving<Coin<Cur>>>,
    clk: &Clock,
    ctx: &mut TxContext,
) {
    // Installed check (aborts if the plugin is not installed on this vault).
    let _ = vault::config<_, Key, Config>(v);

    let (cap, b) = vault::borrow_cap_plugin(v, op, Key(), clk);
    release_revenue_distributor::receive_and_distribute_revenue<Cur>(rel, &cap, coins, ctx);
    vault::return_cap(v, cap, b);
}

/// Redeem `value` from the release's balance accumulator and distribute it to
/// tracks. Operator-only: same borrow/return shape as `distribute_received`.
public entry fun distribute_accrued<Cur>(
    v: &mut Vault<ReleaseAdminCap>,
    rel: &mut Release,
    op: &OperatorCap,
    value: u64,
    clk: &Clock,
    _ctx: &mut TxContext,
) {
    // Installed check.
    let _ = vault::config<_, Key, Config>(v);

    let (cap, b) = vault::borrow_cap_plugin(v, op, Key(), clk);
    release_revenue_distributor::redeem_and_distribute_revenue<Cur>(rel, &cap, value);
    vault::return_cap(v, cap, b);
}

/// Write this plugin's extension metadata onto the release's UID. Operator-only:
/// borrows the vaulted cap, writes (or overwrites) the record via the cap-gated
/// `release::uid_mut`, and returns the cap in the same tx.
public entry fun set_extension(
    v: &mut Vault<ReleaseAdminCap>,
    rel: &mut Release,
    op: &OperatorCap,
    metadata: String,
    clk: &Clock,
    _ctx: &mut TxContext,
) {
    // Installed check.
    let _ = vault::config<_, Key, Config>(v);

    let (cap, b) = vault::borrow_cap_plugin(v, op, Key(), clk);
    write_metadata(release::uid_mut(rel, &cap), metadata);
    vault::return_cap(v, cap, b);
}

// === Views ===

/// Whether this plugin has written an extension record onto the release.
public fun has_metadata(rel: &Release): bool {
    df::exists(release::uid(rel), ReleaseOpsMetadataKey())
}

/// The extension metadata string. Aborts if none has been written.
public fun metadata(rel: &Release): &String {
    &df::borrow<ReleaseOpsMetadataKey, ReleaseOpsMetadata>(
        release::uid(rel),
        ReleaseOpsMetadataKey(),
    ).metadata
}

// === Private helpers ===

/// Overwrite-or-init the plugin's extension record on a release UID.
fun write_metadata(uid: &mut UID, metadata: String) {
    if (df::exists(uid, ReleaseOpsMetadataKey())) {
        let record: &mut ReleaseOpsMetadata = df::borrow_mut(uid, ReleaseOpsMetadataKey());
        record.metadata = metadata;
    } else {
        df::add(uid, ReleaseOpsMetadataKey(), ReleaseOpsMetadata { metadata });
    }
}

// === Test only ===

#[test_only]
public fun key_for_testing(): Key { Key() }

#[test_only]
public fun write_metadata_for_testing(uid: &mut UID, metadata: String) {
    write_metadata(uid, metadata)
}

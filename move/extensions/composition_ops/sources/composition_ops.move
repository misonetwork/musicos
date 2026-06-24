// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Vault-operated composition operations.
///
/// A composition owner who has wrapped their `CompositionAdminCap` in a
/// `miso_vault::vault::Vault` can install this plugin to delegate *bounded* admin
/// operations to operator addresses. The owner installs the plugin with a royalty
/// ceiling (`max_royalty_bps`); thereafter any live, unexpired operator may drive
/// the wrapped cap to:
///
/// - `set_royalty_rate` — the key post-publish composition op. Borrows the cap
///   and calls `composition::set_royalty_rate`, but only up to the owner-set
///   ceiling, which itself may never exceed the protocol cap (20%).
/// - `set_extension` — write a simple `String => vector<u8>` metadata entry onto
///   the composition's UID via the cap-gated `uid_mut`.
///
/// The plugin's `Key` type is a `drop`-only witness: install and borrow pass
/// `Key()` by value to fix the type parameter, while config reads and uninstall
/// key purely off the type parameter `Key` (the vault owns the config df key,
/// `vault::PluginKey<Key>`). The owner retains the `VaultAdminCap` escape hatch
/// and can revoke operators or uninstall the plugin — via this module or directly
/// through the vault — at any time.
///
/// Note: composition royalty-pool sweep ops are intentionally NOT included here.
/// They would require a dependency on `composition_royalty_pool`, which is not yet
/// published on testnet; a follow-up can add them once that package is published.
module composition_ops::composition_ops;

use miso::composition::{Self, Composition, CompositionAdminCap};
use miso_vault::vault::{Self, Vault, VaultAdminCap, OperatorCap};
use std::string::String;
use sui::clock::Clock;
use sui::dynamic_field as df;

// === Constants ===

/// Protocol-immutable ceiling for a composition's royalty rate (20%), mirrored
/// from `miso::composition`. The owner-set `max_royalty_bps` may never exceed it.
const PROTOCOL_MAX_ROYALTY_BPS: u16 = 2000;

// === Errors ===

// Validation errors (20-29)
/// The requested royalty rate exceeds the owner-set ceiling for this vault.
const ERoyaltyTooHigh: u64 = 20;
/// The owner-set ceiling exceeds the protocol maximum royalty rate.
const ECeilingAboveProtocolMax: u64 = 21;

// === Plugin key + config ===

/// The plugin's witness type. It fixes the type parameter `K` at install, gates
/// the witness-checked cap borrow (`borrow_cap_plugin`), and tags this plugin in
/// the vault's `plugins` set. It is a `drop`-only witness: the vault owns the
/// config dynamic-field key (`vault::PluginKey<Key>`), so this type never needs
/// to be the df key itself. A client resolves this vault's config under
/// `composition_ops::composition_ops::Key` / `::Config`.
public struct Key() has drop;

/// Per-vault plugin configuration: the owner-set royalty ceiling operators are
/// bounded by. Always `<= PROTOCOL_MAX_ROYALTY_BPS`.
public struct Config has store, drop {
    /// Maximum royalty rate (bps) an operator may set via this plugin.
    max_royalty_bps: u16,
}

/// Dynamic-field key wrapping an extension metadata `String`. Keying the
/// composition's UID with this wrapper (rather than a bare `String`) namespaces
/// this plugin's metadata so it cannot collide with other extensions' fields.
public struct ExtensionKey(String) has copy, drop, store;

// === Install ===

/// Install the plugin on a vault wrapping a `CompositionAdminCap`, setting the
/// royalty ceiling operators are bounded by. Owner-only (requires the
/// `VaultAdminCap`). Aborts if the ceiling exceeds the protocol maximum.
public fun install<CompositionShare>(
    v: &mut Vault<CompositionAdminCap<CompositionShare>>,
    admin: &VaultAdminCap,
    max_royalty_bps: u16,
) {
    vault::add_plugin(v, admin, Key(), new_config(max_royalty_bps));
}

/// Uninstall the plugin, returning the stored `Config`. Owner-only (requires the
/// `VaultAdminCap`). A convenience wrapper: because the vault owns the config df
/// key (`vault::PluginKey<Key>`), the owner can equivalently uninstall this
/// plugin directly via `vault::remove_plugin<_, Key, Config>` without this
/// module's help, so the cap can never be permanently trapped.
public fun uninstall<CompositionShare>(
    v: &mut Vault<CompositionAdminCap<CompositionShare>>,
    admin: &VaultAdminCap,
): Config {
    vault::remove_plugin<_, Key, Config>(v, admin)
}

/// Builds a validated `Config`. Aborts if the ceiling exceeds the protocol
/// maximum. Exposed as a pure helper so the install bound is unit-testable
/// without a vault.
public fun new_config(max_royalty_bps: u16): Config {
    assert!(max_royalty_bps <= PROTOCOL_MAX_ROYALTY_BPS, ECeilingAboveProtocolMax);
    Config { max_royalty_bps }
}

// === Operator ops ===

/// Autonomous op: set the composition's royalty rate, bounded by the owner-set
/// ceiling. Operator-only — borrows the wrapped cap through a live `OperatorCap`.
/// Aborts if `royalty_rate_bps` exceeds the ceiling, or (in core) if the rate
/// cooldown has not elapsed.
public entry fun set_royalty_rate<CompositionShare>(
    v: &mut Vault<CompositionAdminCap<CompositionShare>>,
    comp: &mut Composition<CompositionShare>,
    op: &OperatorCap,
    royalty_rate_bps: u16,
    clk: &Clock,
    ctx: &mut TxContext,
) {
    let max = vault::config<_, Key, Config>(v).max_royalty_bps;
    assert!(royalty_rate_bps <= max, ERoyaltyTooHigh);

    let (cap, b) = vault::borrow_cap_plugin(v, op, Key(), clk);
    composition::set_royalty_rate(comp, &cap, royalty_rate_bps, ctx);
    vault::return_cap(v, cap, b);
}

/// Autonomous op: write (or overwrite) a `String => vector<u8>` metadata entry on
/// the composition's UID. Operator-only — borrows the wrapped cap through a live
/// `OperatorCap` to obtain the cap-gated `uid_mut`.
public entry fun set_extension<CompositionShare>(
    v: &mut Vault<CompositionAdminCap<CompositionShare>>,
    comp: &mut Composition<CompositionShare>,
    op: &OperatorCap,
    key: String,
    value: vector<u8>,
    clk: &Clock,
    _ctx: &mut TxContext,
) {
    let (cap, b) = vault::borrow_cap_plugin(v, op, Key(), clk);
    let uid = composition::uid_mut(comp, &cap);
    let dfk = ExtensionKey(key);
    if (df::exists_with_type<ExtensionKey, vector<u8>>(uid, dfk)) {
        *df::borrow_mut<ExtensionKey, vector<u8>>(uid, dfk) = value;
    } else {
        df::add(uid, dfk, value);
    };
    vault::return_cap(v, cap, b);
}

// === Views ===

/// The owner-set royalty ceiling (bps) configured for this vault's plugin.
public fun max_royalty_bps(cfg: &Config): u16 {
    cfg.max_royalty_bps
}

/// Read an extension metadata value previously written via `set_extension`.
/// Permissionless; aborts if no entry exists for `key`.
public fun extension<CompositionShare>(
    comp: &Composition<CompositionShare>,
    key: String,
): &vector<u8> {
    df::borrow(composition::uid(comp), ExtensionKey(key))
}

/// Whether an extension metadata entry exists for `key`.
public fun has_extension<CompositionShare>(
    comp: &Composition<CompositionShare>,
    key: String,
): bool {
    df::exists_with_type<ExtensionKey, vector<u8>>(composition::uid(comp), ExtensionKey(key))
}

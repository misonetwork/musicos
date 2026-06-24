// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

// =============================================================================
// REFERENCE SKELETON — NOT A BUILDABLE PACKAGE.
//
// This file is the canonical shape of a `miso_vault` plugin. Copy it into a new
// `move/extensions/<name>_ops/` package, rename the module and types, and fill in
// the real operate functions. It is intentionally NOT wired into a Move.toml (no
// `miso_vault` dep is resolved here), so it does not build on its own — it is a
// commented reference, mirrored against the four shipped plugins. See the sibling
// README.md and `docs/PLUGIN_STANDARD.md` for the full convention, and
// `scripts/lint-plugins.sh` for the conformance checks every plugin must pass.
//
// THE CONVENTION IN ONE BREATH: one plugin == one module. It declares exactly one
// `Key` (a `drop`-only witness) and one `Config` (`store + drop`), and exposes
// `install` / `uninstall` plus one or more operate functions. The VAULT owns the
// dynamic-field key (`vault::PluginKey<Key>`) — the plugin only ever supplies its
// `Key` *witness* type. That single fact is what lets a vault owner uninstall ANY
// plugin (`vault::remove_plugin<Cap, Key, Config>`) with no cooperation from the
// plugin module, keeping the vault's `withdraw` escape hatch un-loseable.
// =============================================================================

module plugin_template::plugin_template;

use miso_vault::vault::{Self, Vault, VaultAdminCap, OperatorCap};
use sui::clock::Clock;

// === Plugin identity ===

/// The plugin's witness type. Canonical name: `Key`. It is a `drop`-only witness
/// with TWO roles:
///   1. fix the type parameter `K` at `install` (the vault keys the `Config`
///      dynamic field by its own `vault::PluginKey<Key>` wrapper, and records
///      `with_defining_ids<Key>()` in the vault's `plugins` set);
///   2. the witness `W` for `vault::borrow_cap_plugin` (the real auth proof —
///      only this package can construct `Key`, so only it can borrow the cap).
///
/// Signed-intent ops do NOT use the witness: `vault::verify_and_consume_intent`
/// is authorized purely by the principal's personal-message signature over the
/// canonical intent bytes (and replay-protected by the vault's nonce set), so it
/// takes no `Key`.
///
/// It must NOT have `store` — the vault, not the plugin, owns the df key now, so
/// `Key` is never itself a dynamic-field key. `drop` is the only required ability.
public struct Key() has drop;

/// The plugin's per-vault configuration. Canonical name: `Config`. Must have
/// `store` (it lives in a dynamic field) and `drop` (so `uninstall` can return it
/// and callers can discard it). Hold the owner-set policy knobs the operator is
/// bounded by here — e.g. a ceiling, a floor, a payout address. An empty `Config`
/// is fine for plugins whose policy is entirely on-chain elsewhere.
public struct Config has store, drop {
    /// Example owner-set bound. Replace with the real policy for your plugin.
    example_max: u64,
}

// === Install / uninstall ===

/// Install the plugin on a vault wrapping `Cap`. Owner-only — `vault::add_plugin`
/// asserts the `VaultAdminCap` controls `v`. Pass `Key()` by value to fix the
/// type parameter; the vault keys the `Config` under `vault::PluginKey<Key>`.
public fun install<Cap: key + store>(
    v: &mut Vault<Cap>,
    admin: &VaultAdminCap,
    example_max: u64,
) {
    vault::add_plugin(v, admin, Key(), Config { example_max });
}

/// Uninstall the plugin, returning the stored `Config`. Owner-only. This is a
/// CONVENIENCE wrapper only: because the vault owns the df key, the owner can
/// equivalently call `vault::remove_plugin<Cap, Key, Config>(v, admin)` directly
/// — no witness value, no call into this module — which is the structural
/// guarantee the cap can never be trapped. Always provide this anyway for a clean
/// PTB call site.
public fun uninstall<Cap: key + store>(v: &mut Vault<Cap>, admin: &VaultAdminCap): Config {
    vault::remove_plugin<_, Key, Config>(v, admin)
}

// === Operate ===

/// One canonical operate function. The shape every operate fn follows:
///   1. (optional) read the installed `Config` BY TYPE PARAM — no witness value —
///      to enforce the owner's policy: `vault::config<_, Key, Config>(v)`;
///   2. borrow the wrapped cap through a live `OperatorCap`, passing the `Key()`
///      witness VALUE: `vault::borrow_cap_plugin(v, op, Key(), clk)`;
///   3. drive the cap (do the real work) while holding the `Borrow` hot potato;
///   4. return the cap in the SAME function via `vault::return_cap(v, cap, b)` —
///      the lint enforces that every `borrow_cap_plugin` is paired with a
///      `return_cap` in the same function body.
public fun operate<Cap: key + store>(
    v: &mut Vault<Cap>,
    op: &OperatorCap,
    clk: &Clock,
) {
    // 1. Read policy (permissionless, by type param).
    let _bound = vault::config<_, Key, Config>(v).example_max;

    // 2. Borrow the cap under operator authority (witness value gates this).
    let (cap, b) = vault::borrow_cap_plugin(v, op, Key(), clk);

    // 3. ...drive `cap` here: call the wrapped capability's authorized entrypoints.

    // 4. Return the cap before the function ends (paired with the borrow above).
    vault::return_cap(v, cap, b);
}

// === Views ===

/// Example permissionless config reader. Reads BY TYPE PARAM — no witness value.
public fun example_max<Cap: key + store>(v: &Vault<Cap>): u64 {
    vault::config<_, Key, Config>(v).example_max
}

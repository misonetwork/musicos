// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// A vault plugin that operates a vaulted `Stake<Share>` — the royalty-bearing
/// position — to claim royalties and manage its pool registration.
///
/// The vault (`miso_vault::vault`) wraps the `Stake<Share>` as its capability.
/// This plugin installs a per-vault `Config` holding a single owner-set `payout`
/// address. An authorized vault operator may then:
///
///   - `claim`      — drain accrued royalties from a `RoyaltyPool` and send the
///                    resulting coin to the configured `payout` address.
///   - `register`   — register the vaulted stake against a pool.
///   - `unregister` — remove the stake's registration (the pool asserts the
///                    stake has no claimable rewards pending).
///
/// The trust split is deliberate: the operator can *trigger* a claim but cannot
/// *redirect* the funds. The payout destination lives in the plugin `Config`,
/// which only the vault admin (owner) can mutate via `vault::config_mut`. The
/// operator-facing path reads the payout read-only and is structurally unable to
/// route funds anywhere else.
module revenue_ops::revenue_ops;

use miso_vault::vault::{Self, Vault, VaultAdminCap, OperatorCap};
use royalty_pool::pool::{Self, RoyaltyPool};
use royalty_pool::stake::Stake;
use sui::clock::Clock;
use sui::coin;

// === Structs ===

/// The plugin's witness type. It fixes the type parameter `K` at install, gates
/// the witness-checked operator cap borrow (`borrow_cap_plugin`), and tags this
/// plugin in the vault's `plugins` set. A `drop`-only witness: the vault owns the
/// config dynamic-field key (`vault::PluginKey<Key>`), so this type is never the
/// df key itself. A client resolves this vault's config under
/// `revenue_ops::revenue_ops::Key` / `::Config`.
public struct Key() has drop;

/// Per-vault plugin config. `payout` is the address every claim is sent to.
/// Owner-controlled (mutable only through `vault::config_mut`, which is admin
/// gated); the operator cannot change it.
public struct Config has store, drop {
    payout: address,
}

// === Install / config ===

/// Install the plugin on `v`, recording the owner-set `payout` address. Admin
/// gated by `vault::add_plugin`.
public fun install<Share>(
    v: &mut Vault<Stake<Share>>,
    admin: &VaultAdminCap,
    payout: address,
) {
    vault::add_plugin(v, admin, Key(), Config { payout });
}

/// Owner-only update of the payout address. Admin gated by `vault::config_mut`.
public fun set_payout<Share>(
    v: &mut Vault<Stake<Share>>,
    admin: &VaultAdminCap,
    payout: address,
) {
    let cfg = vault::config_mut<_, Key, Config>(v, admin);
    cfg.payout = payout;
}

/// Uninstall the plugin, returning the stored `Config`. Admin gated. A
/// convenience wrapper: because the vault owns the config df key
/// (`vault::PluginKey<Key>`), the owner can equivalently uninstall directly via
/// `vault::remove_plugin<_, Key, Config>` without this module's help.
public fun uninstall<Share>(
    v: &mut Vault<Stake<Share>>,
    admin: &VaultAdminCap,
): Config {
    vault::remove_plugin<_, Key, Config>(v, admin)
}

// === Operator actions ===

/// Claim accrued royalties for the vaulted stake from `pool` and transfer the
/// resulting coin to the owner-set payout address.
///
/// The operator triggers the claim but cannot redirect the funds: the payout
/// is read from the admin-controlled `Config`.
public fun claim<Share, Cur>(
    v: &mut Vault<Stake<Share>>,
    pool: &mut RoyaltyPool<Share, Cur>,
    op: &OperatorCap,
    clk: &Clock,
    ctx: &mut TxContext,
) {
    // Copy the payout out before the `&mut` borrow of the vault (address is copy).
    let payout = vault::config<_, Key, Config>(v).payout;

    let (mut stake, b) = vault::borrow_cap_plugin(v, op, Key(), clk);
    let bal = pool::claim_rewards(pool, &mut stake);
    vault::return_cap(v, stake, b);

    transfer::public_transfer(coin::from_balance(bal, ctx), payout);
}

/// Register the vaulted stake against `pool` so future deposits accrue to it.
public fun register<Share, Cur>(
    v: &mut Vault<Stake<Share>>,
    pool: &mut RoyaltyPool<Share, Cur>,
    op: &OperatorCap,
    clk: &Clock,
) {
    let (mut stake, b) = vault::borrow_cap_plugin(v, op, Key(), clk);
    pool::register_stake(pool, &mut stake);
    vault::return_cap(v, stake, b);
}

/// Unregister the vaulted stake from `pool`. The pool asserts the stake has no
/// claimable rewards pending, so callers should `claim` first.
public fun unregister<Share, Cur>(
    v: &mut Vault<Stake<Share>>,
    pool: &mut RoyaltyPool<Share, Cur>,
    op: &OperatorCap,
    clk: &Clock,
) {
    let (mut stake, b) = vault::borrow_cap_plugin(v, op, Key(), clk);
    pool::unregister_stake(pool, &mut stake);
    vault::return_cap(v, stake, b);
}

// === Views ===

/// The payout address every claim is sent to.
public fun payout<Share>(v: &Vault<Stake<Share>>): address {
    vault::config<_, Key, Config>(v).payout
}

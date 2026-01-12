// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// MusicOS plugin for receiving coins sent to protocol objects.
///
/// When coins are sent to a Composition, Contributor, Recording, or Release,
/// they cannot be accessed directly because these are shared objects. This plugin
/// provides authorized access to receive those coins using Sui's `Receiving` pattern.
///
/// ## Setup
///
/// The protocol admin must register this plugin for each target type:
/// ```
/// plugin::new<CompositionWitness, PluginWitness>(&admin_cap, &mut protocol);
/// plugin::new<ContributorWitness, PluginWitness>(&admin_cap, &mut protocol);
/// plugin::new<RecordingWitness, PluginWitness>(&admin_cap, &mut protocol);
/// plugin::new<ReleaseWitness, PluginWitness>(&admin_cap, &mut protocol);
/// ```
///
/// ## Usage
///
/// To receive coins sent to an object:
/// ```
/// let coin = coin_receive::receive_coins_from_composition(
///     &mut composition,
///     &composition_cap,
///     coins_to_receive,  // vector<Receiving<Coin<Currency>>>
///     &plugin,
/// );
/// ```
///
/// Multiple coins of the same currency are automatically merged into a single coin.
module coin_receive::coin_receive;

use musicos::composition::{Composition, CompositionAdminCap, CompositionWitness};
use musicos::contributor::{Contributor, ContributorAdminCap, ContributorWitness};
use musicos::plugin::Plugin;
use musicos::recording::{Recording, RecordingAdminCap, RecordingWitness};
use musicos::release::{Release, ReleaseAdminCap, ReleaseWitness};
use revenue_pool::revenue_pool::RevenuePool;
use royalty_pool::royalty_pool::RoyaltyPool;
use sui::balance::{Self, Balance};
use sui::coin::Coin;
use sui::transfer::Receiving;

//=== Structs ===

/// Witness type for this plugin. Used to authenticate plugin capability requests.
public struct PluginWitness() has drop;

//=== Errors ===

/// No coins were provided to receive.
const ENoCoinsToReceive: u64 = 0;

//=== Public Functions ===

/// Receives coins sent to a Composition.
/// Requires the composition admin capability and an enabled plugin.
/// Returns all received coins merged into a single coin.
public fun composition_receive_coins_and_deposit<Currency, CompositionShare>(
    composition: &mut Composition<CompositionShare>,
    cap: &CompositionAdminCap,
    coins_to_receive: vector<Receiving<Coin<Currency>>>,
    royalty_pool: &mut RoyaltyPool<CompositionShare, Currency>,
    plugin: &Plugin<CompositionWitness, PluginWitness>,
) {
    let uid_mut = composition.uid_mut_with_plugin(cap, plugin.request_cap(PluginWitness()));
    let balance = receive_coins_impl(uid_mut, coins_to_receive);
    royalty_pool.deposit(balance);
}

/// Receives coins sent to a Contributor.
/// Requires the contributor admin capability and an enabled plugin.
/// Returns all received coins merged into a single coin.
public fun receive_coins_from_contributor<Currency>(
    contributor: &mut Contributor,
    cap: &ContributorAdminCap,
    coins_to_receive: vector<Receiving<Coin<Currency>>>,
    plugin: &Plugin<ContributorWitness, PluginWitness>,
    ctx: &mut TxContext,
): Coin<Currency> {
    let uid_mut = contributor.uid_mut_with_plugin(cap, plugin.request_cap(PluginWitness()));
    let balance = receive_coins_impl(uid_mut, coins_to_receive);
    balance.into_coin(ctx)
}

/// Receives coins sent to a Recording.
/// Requires the recording admin capability and an enabled plugin.
/// Returns all received coins merged into a single coin.
public fun receive_coins_from_recording<Currency, RecordingShare>(
    recording: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap,
    coins_to_receive: vector<Receiving<Coin<Currency>>>,
    royalty_pool: &mut RoyaltyPool<RecordingShare, Currency>,
    plugin: &Plugin<RecordingWitness, PluginWitness>,
) {
    let uid_mut = recording.uid_mut_with_plugin(cap, plugin.request_cap(PluginWitness()));
    let balance = receive_coins_impl(uid_mut, coins_to_receive);
    royalty_pool.deposit(balance);
}

/// Receives coins sent to a Release.
/// Requires the release admin capability and an enabled plugin.
/// Returns all received coins merged into a single coin.
public fun receive_coins_from_release<Currency>(
    release: &mut Release,
    cap: &ReleaseAdminCap,
    coins_to_receive: vector<Receiving<Coin<Currency>>>,
    revenue_pool: &mut RevenuePool<Currency>,
    plugin: &Plugin<ReleaseWitness, PluginWitness>,
) {
    let uid_mut = release.uid_mut_with_plugin(cap, plugin.request_cap(PluginWitness()));
    let balance = receive_coins_impl(uid_mut, coins_to_receive);
    revenue_pool.deposit(balance);
}

//=== Private Functions ===

/// Internal implementation for receiving and merging coins.
/// Receives each coin from the parent UID and merges them into a single coin.
/// Aborts if no coins are provided.
fun receive_coins_impl<Currency>(
    parent: &mut UID,
    coins_to_receive: vector<Receiving<Coin<Currency>>>,
): Balance<Currency> {
    assert!(!coins_to_receive.is_empty(), ENoCoinsToReceive);

    let mut balance = balance::zero<Currency>();

    coins_to_receive.destroy!(|c| {
        balance.join(transfer::public_receive(parent, c).into_balance());
    });

    balance
}

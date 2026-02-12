// Copyright (c) Studio Mirai, LLC
// SPDX-License-Identifier: Apache-2.0

/// A MusicOS extension that enables revenue distribution for releases.
///
/// When authorized by the release owner, this extension allows
/// permissionless distribution of accumulated revenue across the release's
/// tracks. Revenue is split according to each track's configured BPS
/// (basis points) and forwarded to the corresponding composition and
/// recording funds accumulators.
///
/// ### Flow:
///
/// - The release owner calls `register` with their `ReleaseAdminCap` to
/// register this extension on a release.
/// - Once registered, anyone can distribute revenue via two entry points:
///   - `redeem_and_distribute_revenue`: redeems a specified amount from
///     the release's funds accumulator and distributes it.
///   - `receive_and_distribute_revenue`: receives coins sent to the
///     release object and distributes the total value.
///
/// ### Notes:
///
/// - Revenue distribution is split per-track according to the BPS values
/// configured during release creation.
/// - Each track's share is further split between its composition and
/// recording based on the track's commission rate.
module release_revenue_distributor::extension;

use hikida::hikida;
use musicos::release::{Release, ReleaseAdminCap};
use sui::coin::Coin;
use sui::transfer::Receiving;

// === Structs ===

/// Witness type identifying this extension. Used as the phantom type
/// parameter when registering with the MusicOS extension system.
public struct Extension() has drop;

// === Public Functions ===

/// Register this extension on a release. Can only be called by the
/// release owner with the matching `ReleaseAdminCap`.
///
/// Must be called before `redeem_and_distribute_revenue` or
/// `receive_and_distribute_revenue` can be used on this release.
public fun register(release: &mut Release, cap: &ReleaseAdminCap) {
    release.register_extension(cap, Extension(), true);
}

/// Redeem revenue from the release's funds accumulator and distribute it
/// across the release's tracks according to their configured BPS splits.
///
/// Requires the extension to be registered via `register` first.
public fun redeem_and_distribute_revenue<Currency>(release: &mut Release, value: u64) {
    let uid_mut = release.uid_mut_with_extension(Extension());
    let revenue = hikida::redeem_balance(uid_mut, value);
    release.distribute_revenue<Currency>(revenue);
}

/// Receive coins sent to the release object and distribute the total
/// value across the release's tracks according to their configured BPS
/// splits.
///
/// Requires the extension to be registered via `register` first.
public fun receive_and_distribute_revenue<Currency>(
    release: &mut Release,
    coins: vector<Receiving<Coin<Currency>>>,
) {
    let uid_mut = release.uid_mut_with_extension(Extension());
    let revenue = hikida::receive_balance(uid_mut, coins);
    release.distribute_revenue<Currency>(revenue);
}

module release_revenue_distributor::extension;

use hikida::hikida;
use musicos::release::{Release, ReleaseAdminCap};
use sui::coin::Coin;
use sui::transfer::Receiving;

//=== Structs ===

public struct Extension() has drop;

//=== Public Functions ===

// Register the extension for the release.
public fun register(release: &mut Release, cap: &ReleaseAdminCap) {
    release.register_extension(cap, Extension());
}

// Redeem revenue from the release's funds accumulator and distribute it to the release's tracks.
public fun redeem_and_distribute_revenue<Currency>(release: &mut Release, value: u64) {
    let uid_mut = release.uid_mut_with_extension(Extension());
    let revenue = hikida::redeem_balance(uid_mut, value);
    release.distribute_revenue<Currency>(revenue);
}

// Receive revenue from the release and distribute it to the release's tracks.
public fun receive_and_distribute_revenue<Currency>(
    release: &mut Release,
    coins: vector<Receiving<Coin<Currency>>>,
) {
    let uid_mut = release.uid_mut_with_extension(Extension());
    let revenue = hikida::receive_balance(uid_mut, coins);
    release.distribute_revenue<Currency>(revenue);
}

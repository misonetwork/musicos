module release_revenue_distributor::extension;

use musicos::extension;
use musicos::release::{Release, ReleaseAdminCap};
use sui::balance::{redeem_funds, withdraw_funds_from_object};
use sui::coin::Coin;
use sui::transfer::{Receiving, public_receive};

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
    let withdrawal = withdraw_funds_from_object<Currency>(uid_mut, value);
    let revenue = redeem_funds<Currency>(withdrawal);
    release.distribute_revenue(revenue);
}

// Receive revenue from the release and distribute it to the release's tracks.
public fun receive_and_distribute_revenue<Currency>(
    release: &mut Release,
    mut coins_to_receive: vector<Receiving<Coin<Currency>>>,
) {
    let uid_mut = release.uid_mut_with_extension(Extension());

    // Receive the first coin and convert it to a balance.
    let mut revenue_balance = public_receive(
        uid_mut,
        coins_to_receive.pop_back(),
    ).into_balance();

    // Receive the remaining coins and join them to the balance.
    coins_to_receive.destroy!(|c| {
        revenue_balance.join(public_receive(uid_mut, c).into_balance());
    });

    release.distribute_revenue(revenue_balance);
}

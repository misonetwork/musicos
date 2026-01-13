module share::share;

use sui::coin::TreasuryCap;
use sui::coin_registry::{CoinRegistry, CurrencyInitializer, new_currency};

//=== Structs ===

public struct Share has key {
    id: UID,
}

const SYMBOL: vector<u8> = b"";

public fun initialize(
    coin_registry: &mut CoinRegistry,
    ctx: &mut TxContext,
): (CurrencyInitializer<Share>, TreasuryCap<Share>) {
    let (currency_initializer, treasury_cap) = new_currency<Share>(
        coin_registry,
        6,
        SYMBOL.to_string(),
        SYMBOL.to_string(),
        SYMBOL.to_string(),
        b"https://sonamusic.com/share.webp".to_string(),
        ctx,
    );

    (currency_initializer, treasury_cap)

    //    let metadata_cap = currency_initializer.finalize(ctx);
    //
    //    transfer::public_transfer(metadata_cap, ctx.sender());
    //    transfer::public_transfer(treasury_cap, ctx.sender());
}

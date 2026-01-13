module share::share;

use sui::coin::TreasuryCap;
use sui::coin_registry::{CoinRegistry, new_currency};

//=== Structs ===

public struct Share has key {
    id: UID,
}

//=== Constants ===

const SYMBOL: vector<u8> = b"SHARE";

//=== Init Function ===

public fun initialize(coin_registry: &mut CoinRegistry, ctx: &mut TxContext): TreasuryCap<Share> {
    let (currency_initializer, treasury_cap) = new_currency<Share>(
        coin_registry,
        6,
        SYMBOL.to_string(),
        SYMBOL.to_string(),
        SYMBOL.to_string(),
        b"https://sonamusic.com/share.webp".to_string(),
        ctx,
    );

    currency_initializer.finalize_and_delete_metadata_cap(ctx);

    treasury_cap
}

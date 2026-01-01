module share::share;

use sui::coin::TreasuryCap;
use sui::coin_registry::{CoinRegistry, MetadataCap};

//=== Structs ===

public struct Share has key {
    id: UID,
}

//=== Constants ===

const SYMBOL: vector<u8> = b"SHARE";

//=== Errors ===

const EUnauthorized: u64 = 0;

//=== Public Functions ===

public fun initialize_currency(
    coin_registry: &mut CoinRegistry,
    ctx: &mut TxContext,
): (MetadataCap<Share>, TreasuryCap<Share>) {
    assert!(ctx.sender() == @initializer, EUnauthorized);

    let (currency_initializer, treasury_cap) = coin_registry.new_currency<Share>(
        6,
        SYMBOL.to_string(),
        b"".to_string(),
        b"".to_string(),
        b"".to_string(),
        ctx,
    );

    let metadata_cap = currency_initializer.finalize(ctx);

    (metadata_cap, treasury_cap)
}

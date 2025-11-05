module share::share;

use sui::coin::TreasuryCap;
use sui::coin_registry::{CoinRegistry, MetadataCap, new_currency};

public struct Share has key { id: UID }

const EUnauthorized: u64 = 0;

public fun initialize_currency(
    registry: &mut CoinRegistry,
    ctx: &mut TxContext,
): (MetadataCap<Share>, TreasuryCap<Share>) {
    assert!(ctx.sender() == @initializer, EUnauthorized);

    let (currency_initializer, treasury_cap) = new_currency<Share>(
        registry,
        6,
        b"".to_string(),
        b"".to_string(),
        b"".to_string(),
        b"".to_string(),
        ctx,
    );

    (currency_initializer.finalize(ctx), treasury_cap)
}

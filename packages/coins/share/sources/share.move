module share::share;

use sui::coin_registry::new_currency_with_otw;

//=== Structs ===

public struct SHARE() has drop;

const SYMBOL: vector<u8> = b"";

fun init(otw: SHARE, ctx: &mut TxContext) {
    let (currency_initializer, treasury_cap) = new_currency_with_otw(
        otw,
        6,
        SYMBOL.to_string(),
        SYMBOL.to_string(),
        SYMBOL.to_string(),
        b"https://sonamusic.com/share.webp".to_string(),
        ctx,
    );

    let metadata_cap = currency_initializer.finalize(ctx);

    transfer::public_transfer(metadata_cap, ctx.sender());
    transfer::public_transfer(treasury_cap, ctx.sender());
}

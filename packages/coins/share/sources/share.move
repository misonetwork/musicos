module share::share;

use sui::coin_registry::new_currency_with_otw;

//=== Structs ===

public struct SHARE() has drop;

//=== Constants ===

const SYMBOL: vector<u8> = b"SHARE";

//=== Init Function ===

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

    currency_initializer.finalize_and_delete_metadata_cap(ctx);

    transfer::public_transfer(treasury_cap, ctx.sender());
}

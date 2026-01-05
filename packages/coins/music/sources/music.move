module music::music;

use currency_treasury::currency_treasury;
use sui::coin_registry::new_currency_with_otw;

public struct MUSIC() has drop;

#[allow(lint(share_owned))]
fun init(otw: MUSIC, ctx: &mut TxContext) {
    let (currency_initializer, treasury_cap) = new_currency_with_otw(
        otw,
        3,
        b"MUSIC".to_string(),
        b"MUSIC".to_string(),
        b"MUSIC".to_string(),
        b"MUSIC".to_string(),
        ctx,
    );

    let metadata_cap = currency_initializer.finalize(ctx);

    transfer::public_transfer(metadata_cap, ctx.sender());

    let (currency_treasury, currency_treasury_admin_cap, burn_facility) = currency_treasury::new(
        treasury_cap,
        ctx,
    );

    transfer::public_transfer(currency_treasury_admin_cap, ctx.sender());

    transfer::public_share_object(currency_treasury);
    transfer::public_share_object(burn_facility)
}

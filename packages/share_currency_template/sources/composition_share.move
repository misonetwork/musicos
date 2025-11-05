module share_currency_template::composition_share;

use std::type_name::TypeName;
use sui::coin::TreasuryCap;
use sui::coin_registry::{CoinRegistry, MetadataCap, new_currency};
use sui::event::emit;

public struct CompositionShare has key { id: UID }

public fun initialize_currency(
    registry: &mut CoinRegistry,
    ctx: &mut TxContext,
): (MetadataCap<CompositionShare>, TreasuryCap<CompositionShare>) {
    let (currency_initializer, treasury_cap) = new_currency<CompositionShare>(
        registry,
        6,
        b"COMPOSITION_SHARE".to_string(),
        b"Composition Share".to_string(),
        b"MusicOS Composition Share".to_string(),
        b"https://sonamusic.com/images/composition-share.webp".to_string(),
        ctx,
    );

    (currency_initializer.finalize(ctx), treasury_cap)
}

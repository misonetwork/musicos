module musicos::protocol;

use std::type_name::{TypeName, with_defining_ids};
use sui::vec_set::VecSet;

//=== Structs ===

public struct Protocol has key {
    id: UID,
    state: ProtocolState,
    play_authorities: VecSet<TypeName>,
    settlement_currencies: VecSet<TypeName>,
}

//=== Enums ===

public enum ProtocolState has copy, drop, store {
    Genesis,
    Active,
    Paused,
    Stopped,
    Deprecated,
}

//=== Errors ===

const EInvalidSettlementCurrency: u64 = 0;
const EInvalidPlayAuthority: u64 = 1;

public(package) fun assert_is_settlement_currency<Currency>(self: &Protocol) {
    assert!(
        self.settlement_currencies.contains(&with_defining_ids<Currency>()),
        EInvalidSettlementCurrency,
    )
}

public(package) fun assert_is_play_authority<Authority>(self: &Protocol) {
    assert!(self.play_authorities.contains(&with_defining_ids<Authority>()), EInvalidPlayAuthority)
}

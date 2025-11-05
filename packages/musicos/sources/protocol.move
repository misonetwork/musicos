module musicos::protocol;

use std::type_name::{TypeName, with_defining_ids};
use sui::vec_set::VecSet;

public struct Protocol has key {
    id: UID,
    settlement_currencies: VecSet<TypeName>,
}

const EInvalidSettlementCurrencyType: u64 = 0;

public(package) fun assert_is_settlement_currency<Currency>(self: &Protocol) {
    assert!(
        self.settlement_currencies.contains(&with_defining_ids<Currency>()),
        EInvalidSettlementCurrencyType,
    )
}

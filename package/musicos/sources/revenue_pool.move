module musicos::revenue_pool;

use sui::balance::{Self, Balance};
use sui::derived_object::{claim, derive_address as derive_address_impl, exists as exists_impl};

//=== Structs ===

public struct RevenuePool<phantom Currency> has key, store {
    id: UID,
    balance: Balance<Currency>,
}

// Registry object for tracking derived addresses for RevenuePools.
public struct RevenuePoolRegistry has key {
    id: UID,
}

/// Key used to deterministically derive the RevenuePool object ID.
public struct RevenuePoolKey<phantom Currency>() has copy, drop, store;

//=== Errors ===

const EDoesNotExist: u64 = 0;

//=== Public Functions ===

public fun derive_address<Currency>(parent_id: ID): address {
    derive_address_impl(parent_id, RevenuePoolKey<Currency>())
}

//=== Package Functions ===

public(package) fun new<Currency>(parent: &mut UID): RevenuePool<Currency> {
    RevenuePool {
        id: claim(parent, RevenuePoolKey<Currency>()),
        balance: balance::zero(),
    }
}

//=== Assert Functions ===

public fun assert_exists<Currency>(parent: &UID) {
    assert!(exists_impl(parent, RevenuePoolKey<Currency>()), EDoesNotExist);
}

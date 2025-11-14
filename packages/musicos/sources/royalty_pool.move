module musicos::royalty_pool;

use sui::balance::{Self, Balance};
use sui::derived_object::{claim, derive_address as derive_address_impl, exists as exists_impl};

public struct RoyaltyPool<phantom RevenueCurrency, phantom ShareCurrency> has key, store {
    id: UID,
    balance: Balance<RevenueCurrency>,
}

public struct RoyaltyPoolRegistry has key {
    id: UID,
}

public struct RoyaltyPoolKey<phantom RevenueCurrency>() has copy, drop, store;

public(package) fun new<RevenueCurrency, ShareCurrency>(
    parent: &mut UID,
): RoyaltyPool<RevenueCurrency, ShareCurrency> {
    RoyaltyPool {
        id: claim(parent, RoyaltyPoolKey<RevenueCurrency>()),
        balance: balance::zero(),
    }
}

//=== Public Functions ===

public fun derive_address<RevenueCurrency>(parent_id: ID): address {
    derive_address_impl(parent_id, RoyaltyPoolKey<RevenueCurrency>())
}

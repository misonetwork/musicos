module musicos::key;

use sui::derived_object::derive_address;

public struct RewardPoolKey<phantom Currency>() has copy, drop, store;
public struct RevenuePoolKey<phantom Currency>() has copy, drop, store;

public fun reward_pool_address<Currency>(parent_id: ID): address {
    derive_address(parent_id, RewardPoolKey<Currency>())
}

public fun revenue_pool_address<Currency>(parent_id: ID): address {
    derive_address(parent_id, RevenuePoolKey<Currency>())
}

public(package) fun new_reward_pool_key<Currency>(): RewardPoolKey<Currency> {
    RewardPoolKey()
}

public(package) fun new_revenue_pool_key<Currency>(): RevenuePoolKey<Currency> {
    RevenuePoolKey()
}

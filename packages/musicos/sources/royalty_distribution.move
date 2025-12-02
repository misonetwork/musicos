module musicos::royalty_distribution;

use interest_bps::bps::{Self, BPS};
use musicos::royalty_entitlement::RoyaltyEntitlement;
use musicos::share::share_currency_supply;
use sui::balance::Balance;
use sui::derived_object::claim;

public struct RoyaltyDistribution<phantom Share, phantom Currency> has key {
    id: UID,
    share_value: u64,
    balance: Balance<Currency>,
}

// Key used to deterministically derive the RoyaltyDistribution's object ID.
// We use a combination of Share type, Currency type, and epoch to ensure that
// there is only a single RoyaltyDistribution per epoch. This implies that royalties
// can only be claimed once per day (at most), which is beyond reasonable and a huge improvement
// over royalty payment timelines in the traditional music industry.
public struct RoyaltyDistributionKey<phantom Share, phantom Currency>(u64) has copy, drop, store;

public(package) fun new<Share, Currency>(
    parent: &mut UID,
    balance: Balance<Currency>,
    ctx: &TxContext,
) {
    let distribution = RoyaltyDistribution<Share, Currency> {
        id: claim(parent, RoyaltyDistributionKey<Share, Currency>(ctx.epoch())),
        share_value: ((balance.value() as u128) / (share_currency_supply!() as u128)) as u64,
        balance,
    };

    transfer::share_object(distribution);
}

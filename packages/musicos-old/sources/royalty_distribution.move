module musicos::royalty_distribution;

use interest_bps::bps::{Self, BPS};
use musicos::royalty_entitlement::RoyaltyEntitlement;
use musicos::share::share_currency_supply;
use sui::balance::Balance;
use sui::derived_object::claim;

//=== Structs ===

public struct RoyaltyDistribution<phantom Share, phantom Currency> has key {
    id: UID,
    epoch: u64,
    share_value: u64,
    balance: Balance<Currency>,
}

// Key used to deterministically derive the RoyaltyDistribution's object ID.
// We use a combination of Share type, Currency type, and epoch to ensure that
// there is only a single RoyaltyDistribution per epoch. This implies that royalties
// can only be claimed once per day (at most), which is beyond reasonable and a huge improvement
// over royalty payment timelines in the traditional music industry.
public struct RoyaltyDistributionKey<phantom Share, phantom Currency>(u64) has copy, drop, store;

//=== Errors ===

const ENotExpired: u64 = 0;
const EHasZeroBalance: u64 = 1;
const EHasNonzeroBalance: u64 = 2;

//=== Public Functions ===

public fun claim_with_entitlement<Share, Currency>(
    self: &mut RoyaltyDistribution<Share, Currency>,
    entitlement: &mut RoyaltyEntitlement<Share>,
) {}

//=== Package Functions ===

public(package) fun new<Share, Currency>(
    parent: &mut UID,
    balance: Balance<Currency>,
    ctx: &TxContext,
) {
    let epoch = ctx.epoch();
    let distribution = RoyaltyDistribution<Share, Currency> {
        id: claim(parent, RoyaltyDistributionKey<Share, Currency>(epoch)),
        epoch,
        share_value: ((balance.value() as u128) / (share_currency_supply!() as u128)) as u64,
        balance,
    };

    transfer::share_object(distribution);
}

public(package) fun destroy<Share, Currency>(
    self: RoyaltyDistribution<Share, Currency>,
): Balance<Currency> {
    self.destroy_impl()
}

//=== Public View Functions ===

public fun balance<Share, Currency>(
    self: &RoyaltyDistribution<Share, Currency>,
): &Balance<Currency> {
    &self.balance
}

//=== Assert Functions ===

public fun assert_expired<Share, Currency>(
    self: &RoyaltyDistribution<Share, Currency>,
    ctx: &TxContext,
) {
    assert!(self.epoch <= ctx.epoch(), ENotExpired);
}

public fun assert_has_nonzero_balance<Share, Currency>(
    self: &RoyaltyDistribution<Share, Currency>,
) {
    assert!(self.balance.value() > 0, EHasZeroBalance);
}

public fun assert_has_zero_balance<Share, Currency>(self: &RoyaltyDistribution<Share, Currency>) {
    assert!(self.balance.value() == 0, EHasNonzeroBalance);
}

//=== Private Functions ===

fun destroy_impl<Share, Currency>(self: RoyaltyDistribution<Share, Currency>): Balance<Currency> {
    let RoyaltyDistribution { id, balance, .. } = self;
    id.delete();
    balance
}

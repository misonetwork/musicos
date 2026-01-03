module musicos::royalty_distribution;

use musicos::protocol::Protocol;
use musicos::royalty_entitlement::RoyaltyEntitlement;
use musicos::royalty_pool::RoyaltyPool;
use musicos::share::share_currency_supply;
use sui::balance::Balance;
use sui::derived_object;
use sui::event::emit;

public struct RoyaltyDistribution<phantom Share, phantom Currency> has key {
    id: UID,
    epoch: u64,
    balance: Balance<Currency>,
    distribution_value_per_share: u64,
}

// (epoch)
public struct RoyaltyDistributionKey<phantom Share, phantom Currency>(u64) has copy, drop, store;

public struct RoyaltyDistributionRegistry has key {
    id: UID,
}

//=== Events ===

public struct RoyaltyDistributionDestroyedEvent has copy, drop {
    royalty_distribution_id: ID,
    unclaimed_balance: u64,
}

const ENotActiveState: u64 = 0;
const EAlreadyClaimed: u64 = 1;
const EDistributionNotExpired: u64 = 2;

public fun new<Share, Currency>(
    royalty_pool: &mut RoyaltyPool<Share, Currency>,
    protocol: &Protocol,
    ctx: &TxContext,
) {
    protocol.assert_is_active_state();

    let balance = royalty_pool.balance_mut().withdraw_all();

    let distribution_value_per_share = balance.value() / share_currency_supply!();

    let epoch = ctx.epoch();

    let royalty_distribution = RoyaltyDistribution<Share, Currency> {
        id: derived_object::claim(
            royalty_pool.uid_mut(),
            RoyaltyDistributionKey<Share, Currency>(epoch),
        ),
        epoch,
        balance,
        distribution_value_per_share,
    };

    transfer::share_object(royalty_distribution);
}

// Destroy a royalty distribution and deposit the unclaimed balance back into the royalty pool.
public fun destroy<Share, Currency>(
    self: RoyaltyDistribution<Share, Currency>,
    royalty_pool: &mut RoyaltyPool<Share, Currency>,
    ctx: &TxContext,
) {
    // Assert the distribution has expired by ensuring the current epoch is greater than the distribution epoch.
    assert!(ctx.epoch() > self.epoch, EDistributionNotExpired);

    let RoyaltyDistribution { id, balance, .. } = self;

    emit(RoyaltyDistributionDestroyedEvent {
        royalty_distribution_id: id.to_inner(),
        unclaimed_balance: balance.value(),
    });

    id.delete();

    // If there's an unclaimed balance, deposit it back into the royalty pool.
    // Otherwise, destroy the zero balance.
    if (balance.value() > 0) {
        royalty_pool.balance_mut().join(balance);
    } else {
        balance.destroy_zero();
    }
}

public fun claim<Share, Currency>(
    self: &mut RoyaltyDistribution<Share, Currency>,
    entitlement: &mut RoyaltyEntitlement<Share>,
    ctx: &TxContext,
): Balance<Currency> {
    assert!(entitlement.claimed_distribution_ids().contains(&self.id()), EAlreadyClaimed);

    let claim_value = self.distribution_value_per_share * entitlement.balance().value();
    let claim_balance = self.balance.split(claim_value);

    entitlement.add_claimed_distribution_id(self.id());

    claim_balance
}

public fun id<Share, Currency>(self: &RoyaltyDistribution<Share, Currency>): ID {
    self.id.to_inner()
}

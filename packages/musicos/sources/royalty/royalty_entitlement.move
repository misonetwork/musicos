module musicos::royalty_entitlement;

use sui::balance::Balance;

public struct RoyaltyEntitlement<phantom ShareCurrency> has key, store {
    id: UID,
    balance: Balance<ShareCurrency>,
}

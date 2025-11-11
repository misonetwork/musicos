module musicos::treasury;

use music::music::MUSIC;
use musicos::admin::AdminCap;
use musicos::protocol::Protocol;
use std::type_name::{TypeName, with_defining_ids};
use sui::balance::Balance;
use sui::coin::TreasuryCap;
use sui::vec_set::{Self, VecSet};

public struct TREASURY() has drop;

public struct Treasury has key {
    id: UID,
    treasury_cap: TreasuryCap<MUSIC>,
    authorities: VecSet<TypeName>,
}

const EUnauthorized: u64 = 0;

public fun new(cap: TreasuryCap<MUSIC>, ctx: &mut TxContext) {
    let treasury = Treasury {
        id: object::new(ctx),
        treasury_cap: cap,
        authorities: vec_set::empty(),
    };

    transfer::share_object(treasury);
}

// TODO: Add protocol state verification.
public fun destroy(self: Treasury, _: &AdminCap): TreasuryCap<MUSIC> {
    let Treasury { id, treasury_cap, .. } = self;
    id.delete();
    treasury_cap
}

public fun mint<Authority: drop>(self: &mut Treasury, _: Authority, value: u64): Balance<MUSIC> {
    assert!(self.authorities.contains(&with_defining_ids<Authority>()), EUnauthorized);
    self.treasury_cap.mint_balance(value)
}

public fun burn(self: &mut Treasury, balance: Balance<MUSIC>) {
    self.treasury_cap.supply_mut().decrease_supply(balance);
}

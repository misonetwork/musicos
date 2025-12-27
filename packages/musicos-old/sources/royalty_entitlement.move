// Copyright (c) Sona Labs, Pte Ltd.
// SPDX-License-Identifier: Apache-2.0
// A `RoyaltyEntitlement` is a container that holds a balance of composition
// or recording shares. It's used to "stake" shares, which can then be used
// to claim royalties from a `RoyaltyPool`.
module musicos::royalty_entitlement;

use sui::balance::{Self, Balance};

public struct RoyaltyEntitlement<phantom Share> has key, store {
    id: UID,
    shares: Balance<Share>,
    unlock_epoch: u64,
    claimed_distribution_ids: vector<ID>,
}

const ENotUnlocked: u64 = 0;

public fun new<Share>(ctx: &mut TxContext): RoyaltyEntitlement<Share> {
    RoyaltyEntitlement {
        id: object::new(ctx),
        shares: balance::zero(),
        unlock_epoch: ctx.epoch(),
        claimed_distribution_ids: vector::empty(),
    }
}

// Think more about share unlock.
public fun deposit_shares<Share>(
    self: &mut RoyaltyEntitlement<Share>,
    shares: Balance<Share>,
    ctx: &TxContext,
) {
    self.shares.join(shares);
    self.unlock_epoch = ctx.epoch() + 1;
}

// Withdraw shares.
public fun withdraw_shares<Share>(
    self: &mut RoyaltyEntitlement<Share>,
    value: Option<u64>,
    ctx: &TxContext,
): Balance<Share> {
    assert!(self.unlock_epoch <= ctx.epoch(), ENotUnlocked);
    let value = value.destroy_or!(self.shares.value());
    self.shares.split(value)
}

public fun shares<Share>(self: &RoyaltyEntitlement<Share>): &Balance<Share> {
    &self.shares
}

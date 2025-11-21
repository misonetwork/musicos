// Copyright (c) Sona Labs, Pte Ltd.
// SPDX-License-Identifier: Apache-2.0

module musicos::royalty_entitlement;

use sui::balance::{Self, Balance};

public struct RoyaltyEntitlement<phantom RoyaltyShare> has key, store {
    id: UID,
    balance: Balance<RoyaltyShare>,
}

public fun new<RoyaltyShare>(ctx: &mut TxContext): RoyaltyEntitlement<RoyaltyShare> {
    RoyaltyEntitlement {
        id: object::new(ctx),
        balance: balance::zero(),
    }
}

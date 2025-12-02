// Copyright (c) Sona Labs, Pte Ltd.
// SPDX-License-Identifier: Apache-2.0
// A `RoyaltyEntitlement` is a container that holds a balance of composition
// or recording shares. It's used to "stake" shares, which can then be used
// to claim royalties from a `RoyaltyPool`.
module musicos::royalty_entitlement;

use sui::balance::{Self, Balance};

public struct RoyaltyEntitlement<phantom Share> has key, store {
    id: UID,
    balance: Balance<Share>,
}

public fun new<Share>(ctx: &mut TxContext): RoyaltyEntitlement<Share> {
    RoyaltyEntitlement {
        id: object::new(ctx),
        balance: balance::zero(),
    }
}

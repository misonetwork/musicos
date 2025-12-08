// Copyright (c) Sona Labs, Pte Ltd.
// SPDX-License-Identifier: Apache-2.0

module musicos::governance;

use sui::party::single_owner;

public struct GOVERNANCE() has drop;

public struct AdminCap has key {
    id: UID,
}

fun init(_otw: GOVERNANCE, ctx: &mut TxContext) {
    let admin_cap = AdminCap {
        id: object::new(ctx),
    };

    single_owner(@admin).transfer!(admin_cap);
}

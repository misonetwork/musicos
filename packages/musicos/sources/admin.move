// Copyright (c) Sona Labs, Pte Ltd.
// SPDX-License-Identifier: Apache-2.0

module musicos::admin;

use sui::party::single_owner;

public struct ADMIN() has drop;

public struct AdminCap has key {
    id: UID,
}

fun init(_otw: ADMIN, ctx: &mut TxContext) {
    let admin_cap = AdminCap {
        id: object::new(ctx),
    };

    single_owner(@admin).transfer!(admin_cap);
}

// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Provides administrative capabilities for the MusicOS protocol.
/// The AdminCap is a transferable capability object that grants administrative
/// privileges to its holder, enabling protocol-level operations such as
/// state management and configuration changes.
///
/// Key features:
/// - One-time witness pattern for secure initialization
/// - Transferable admin capability for flexible governance
/// - Created on module publish and sent to deployer
module musicos::admin;

/// One-time witness for module initialization.
public struct ADMIN() has drop;

/// Administrative capability that grants protocol-level permissions.
/// Holder of this capability can perform privileged operations on the protocol.
public struct AdminCap has key, store {
    id: UID,
}

/// Initializes the admin module by creating an AdminCap and transferring it to the deployer.
fun init(_otw: ADMIN, ctx: &mut TxContext) {
    let admin_cap = AdminCap {
        id: object::new(ctx),
    };

    transfer::public_transfer(admin_cap, ctx.sender());
}

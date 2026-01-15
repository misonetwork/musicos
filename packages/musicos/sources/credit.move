// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module musicos::credit;

use std::string::String;
use sui::vec_set;

//=== Structs ===

public struct Credit<Role: copy + drop + store> has copy, drop, store {
    display_name: String,
    roles: vector<Role>,
}

const EDuplicateRoles: u64 = 0;

//=== Public Functions ===

public fun new<Role: copy + drop + store>(display_name: String, roles: vector<Role>): Credit<Role> {
    assert!(vec_set::from_keys(roles).length() == roles.length(), EDuplicateRoles);
    Credit { display_name, roles }
}

//=== Public View Functions ===

public fun display_name<Role: copy + drop + store>(self: &Credit<Role>): &String {
    &self.display_name
}

public fun roles<Role: copy + drop + store>(self: &Credit<Role>): &vector<Role> {
    &self.roles
}

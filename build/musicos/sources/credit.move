// Copyright (c) Studio Mirai, LLC
// SPDX-License-Identifier: Apache-2.0

module musicos::credit;

use std::string::String;
use sui::vec_set;

//=== Structs ===

public struct Credit<R: copy + drop + store> has copy, drop, store {
    display_name: String,
    roles: vector<R>,
}

const EDuplicateRoles: u64 = 0;

//=== Public Functions ===

public fun new<R: copy + drop + store>(display_name: String, roles: vector<R>): Credit<R> {
    assert!(vec_set::from_keys(roles).length() == roles.length(), EDuplicateRoles);
    Credit { display_name, roles }
}

//=== Public View Functions ===

public fun display_name<R: copy + drop + store>(self: &Credit<R>): &String {
    &self.display_name
}

public fun roles<R: copy + drop + store>(self: &Credit<R>): &vector<R> {
    &self.roles
}

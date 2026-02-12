// Copyright (c) Studio Mirai, LLC
// SPDX-License-Identifier: Apache-2.0

/// Represents a party's credit on a composition, recording, or release.
/// A credit pairs a display name with one or more roles, identifying how
/// a party contributed to the work.
module musicos::credit;

use std::string::String;
use sui::vec_set;

// === Structs ===

/// A credit attributing roles to a party on a musical work.
/// Generic over the role type to support composition, recording, and
/// release-specific roles.
public struct Credit<Role: copy + drop + store> has copy, drop, store {
    /// Human-readable name to display for this credit.
    display_name: String,
    /// Roles assigned to the credited party.
    roles: vector<Role>,
}

// === Errors ===

// Conflict errors (40-49)
/// Credit contains duplicate roles.
const EDuplicateRoles: u64 = 40;

// === Public Functions ===

/// Creates a new credit with the given display name and roles.
/// Aborts if the roles vector contains duplicates.
public fun new<Role: copy + drop + store>(display_name: String, roles: vector<Role>): Credit<Role> {
    assert!(vec_set::from_keys(roles).length() == roles.length(), EDuplicateRoles);
    Credit { display_name, roles }
}

// === Public View Functions ===

/// Returns the display name for this credit.
public fun display_name<Role: copy + drop + store>(self: &Credit<Role>): &String {
    &self.display_name
}

/// Returns a reference to the roles assigned in this credit.
public fun roles<Role: copy + drop + store>(self: &Credit<Role>): &vector<Role> {
    &self.roles
}

// Copyright (c) Unconfirmed Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Defines the roles that parties can hold on a release.
/// Releases support two roles: Primary (the main artist) and Featured
/// (a guest or collaborating artist).
module musicos::release_party_role;

use std::string::String;

//=== Enums ===

/// Represents a party's role on a release.
public enum ReleasePartyRole has copy, drop, store {
    Primary,
    Featured,
}

//=== Public Functions ===

/// Creates a new primary role.
public fun new_primary_role(): ReleasePartyRole {
    ReleasePartyRole::Primary
}

/// Creates a new featured role.
public fun new_featured_role(): ReleasePartyRole {
    ReleasePartyRole::Featured
}

//=== Public View Functions ===

/// Returns the human-readable name of the role.
public fun name(self: &ReleasePartyRole): String {
    match (self) {
        ReleasePartyRole::Primary => "Primary",
        ReleasePartyRole::Featured => "Featured",
    }
}

/// Checks if the role is a primary role.
public fun is_primary_role(self: &ReleasePartyRole): bool {
    match (self) {
        ReleasePartyRole::Primary => true,
        _ => false,
    }
}

/// Checks if the role is a featured role.
public fun is_featured_role(self: &ReleasePartyRole): bool {
    match (self) {
        ReleasePartyRole::Featured => true,
        _ => false,
    }
}

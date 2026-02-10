module musicos::release_party_role;

use std::string::String;

/// Represents a party's role on a release.
public enum ReleasePartyRole has copy, drop, store {
    Primary,
    Featured,
}

/// Creates a new primary role.
public fun new_primary_role(): ReleasePartyRole {
    ReleasePartyRole::Primary
}

/// Creates a new featured role.
public fun new_featured_role(): ReleasePartyRole {
    ReleasePartyRole::Featured
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

public fun name(self: &ReleasePartyRole): String {
    match (self) {
        ReleasePartyRole::Primary => "Primary",
        ReleasePartyRole::Featured => "Featured",
    }
}

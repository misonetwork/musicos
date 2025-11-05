module musicos::contributor_identifier;

use std::string::String;

//=== Structs ===

public enum ContributorIdentifier has copy, drop, store {
    Address(address),
    /// String representation of a SuiNS name (e.g., "bl.sui" or "bl@artist.sui").
    /// Note: MusicOS does not validate or resolve SuiNS names. Higher-level application
    /// layers are responsible for resolution and validation.
    SuiNs(String),
}

const ENotAddressVariant: u64 = 0;
const ENotSuinsVariant: u64 = 1;

//=== Public Functions ===

public fun new_address(address: address): ContributorIdentifier {
    ContributorIdentifier::Address(address)
}

public fun new_suins(name: String): ContributorIdentifier {
    ContributorIdentifier::SuiNs(name)
}

//=== Public View Functions ===

public fun addr(self: &ContributorIdentifier): &address {
    match (self) {
        ContributorIdentifier::Address(address) => address,
        _ => abort 0,
    }
}

public fun name(self: &ContributorIdentifier): &String {
    match (self) {
        ContributorIdentifier::SuiNs(name) => name,
        _ => abort 0,
    }
}

public fun is_address(self: &ContributorIdentifier): bool {
    match (self) {
        ContributorIdentifier::Address(_) => true,
        _ => false,
    }
}

public fun is_suins(self: &ContributorIdentifier): bool {
    match (self) {
        ContributorIdentifier::SuiNs(_) => true,
        _ => false,
    }
}

//=== Assert Functions ===

public fun assert_is_address(self: &ContributorIdentifier) {
    assert!(self.is_address(), ENotAddressVariant);
}

public fun assert_is_suins(self: &ContributorIdentifier) {
    assert!(self.is_suins(), ENotSuinsVariant);
}

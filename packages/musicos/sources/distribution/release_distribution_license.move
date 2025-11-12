module musicos::release_distribution_license;

use sui::bcs::{Self, to_bytes};

// A license that defines the distribution terms for a Release.
//
// Requires four types: Distributor and Format.
//    - Distributor: OTW type that identifies the distributor (e.g. sonaos::witness::Witness).
//    - Format: The type of the release format (e.g. sonaos::record::Record).
//    - Packager: The type of the release format packager (e.g. sonaos::pressing::Pressing).
//    - Currency: The currency type for settlement (e.g. sonaos::currency::Currency).
public struct ReleaseDistributionLicense<
    phantom Distributor: drop,
    phantom Format: key,
    phantom Packager: key,
    phantom Currency,
> has store {
    release_id: ID,
    kind: ReleaseDistributionKind,
    state: ReleaseDistributionLicenseState,
    unit_price: u64,
}

public struct ReleaseDistributionLicenseGrant(ID) has drop, store;

//=== Enums ===

public enum ReleaseDistributionLicenseState has copy, drop, store {
    Issued,
    Activated,
}

public fun activate<Distributor: drop, Format: key, Packager: key, Currency>(
    self: &mut ReleaseDistributionLicense<Distributor, Format, Packager, Currency>,
) {
    match (self.state) {
        ReleaseDistributionLicenseState::Issued => {},
        _ => abort 0,
    }
}

public struct ReleaseDistributionLicenseKey() has copy, drop, store;

public enum ReleaseDistributionKind has copy, drop, store {
    Digital(u64), // (quantity)
    Physical(u64), // (quantity)
    Streaming,
}

//=== Public Functions ===

public fun new_digital_kind(quantity: u64): ReleaseDistributionKind {
    ReleaseDistributionKind::Digital(quantity)
}

public fun new_physical_kind(quantity: u64): ReleaseDistributionKind {
    ReleaseDistributionKind::Physical(quantity)
}

public fun new_streaming_kind(): ReleaseDistributionKind {
    ReleaseDistributionKind::Streaming
}

//=== Package Functions ===

public(package) fun new<Distributor: drop, Format: key, Packager: key, Currency>(
    release_id: ID,
    kind: ReleaseDistributionKind,
    unit_price: u64,
): ReleaseDistributionLicense<Distributor, Packager, Format, Currency> {
    ReleaseDistributionLicense {
        release_id: release_id,
        kind: kind,
        state: ReleaseDistributionLicenseState::Issued,
        unit_price,
    }
}

//=== Public View Functions ===

public fun release_id<Distributor: drop, Format: key, Packager: key, Currency>(
    self: &ReleaseDistributionLicense<Distributor, Packager, Format, Currency>,
): ID {
    self.release_id
}

public fun quantity<Distributor: drop, Format: key, Packager: key, Currency>(
    self: &ReleaseDistributionLicense<Distributor, Packager, Format, Currency>,
): u64 {
    match (self.kind) {
        ReleaseDistributionKind::Digital(quantity) => quantity,
        ReleaseDistributionKind::Physical(quantity) => quantity,
        _ => abort 0,
    }
}

public fun unit_price<Distributor: drop, Format: key, Packager: key, Currency>(
    self: &ReleaseDistributionLicense<Distributor, Packager, Format, Currency>,
): u64 {
    self.unit_price
}

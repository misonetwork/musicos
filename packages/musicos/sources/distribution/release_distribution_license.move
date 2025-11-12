module musicos::release_distribution_license;

use std::type_name::{TypeName, with_defining_ids};
use sui::dynamic_field as df;

// A license that defines the distribution terms for a Release.
//
// Requires four types: Distributor and Format.
//    - Distributor: OTW type that identifies the distributor (e.g. sonaos::witness::Witness).
//    - Format: The type of the release format (e.g. sonaos::record::Record).
//    - Packager: The type of the release format packager (e.g. sonaos::pressing::Pressing).
//    - Currency: The currency type for settlement (e.g. sonaos::currency::Currency).
public struct ReleaseDistributionLicense<
    phantom Distributor,
    phantom Format,
    phantom Packager,
    phantom Currency,
> has store {
    release_id: ID,
    kind: ReleaseDistributionKind,
    unit_price: u64,
}

// (release_id)
public struct ReleaseUidClaim<phantom Distributor>(ID)

public struct ReleaseDistributionLicenseKey() has copy, drop, store;
// (release_id, number)
public struct ReleaseDistributionLicenseGrant(ID) has drop, store;

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

public(package) fun new<Distributor, Packager, Format, Currency>(
    release_id: ID,
    kind: ReleaseDistributionKind,
    unit_price: u64,
): ReleaseDistributionLicense<Distributor, Packager, Format, Currency> {
    ReleaseDistributionLicense {
        release_id: release_id,
        kind: kind,
        unit_price,
    }
}

public(package) fun attach_license<Distributor, Packager, Format, Currency>(
    parent: &mut UID,
    release_id: ID,
) {
    df::add(parent, ReleaseDistributionLicenseKey(), ReleaseDistributionLicenseGrant(release_id))
}

//=== Public View Functions ===

public fun release_id<Distributor, Packager, Format, Currency>(
    self: &ReleaseDistributionLicense<Distributor, Packager, Format, Currency>,
): ID {
    self.release_id
}

public fun quantity<Distributor, Packager, Format, Currency>(
    self: &ReleaseDistributionLicense<Distributor, Packager, Format, Currency>,
): u64 {
    match (self.kind) {
        ReleaseDistributionKind::Digital(quantity) => quantity,
        ReleaseDistributionKind::Physical(quantity) => quantity,
        _ => abort 0,
    }
}

public fun unit_price<Distributor, Packager, Format, Currency>(
    self: &ReleaseDistributionLicense<Distributor, Packager, Format, Currency>,
): u64 {
    self.unit_price
}

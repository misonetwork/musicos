module musicos::release_distribution_license;

use std::type_name::{TypeName, with_defining_ids};
use sui::clock::Clock;
use sui::dynamic_field as df;
use sui::vec_map::{Self, VecMap};

// A license that defines the distribution terms for a Release.
// Requires two types: Distributor and Format.
//    - Distributor: OTW object that identifies the distributoe (e.g. sonaos::distribution::Distributor).
//    - Format: The format of the Release (e.g. sonaos::record::Record).
public struct ReleaseDistributionLicense<phantom Distributor, phantom Format> has store {
    release_id: ID,
    kind: ReleaseDistributionKind,
    unit_prices_by_currency: VecMap<TypeName, u64>,
}

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

public(package) fun new<Distributor, Format>(
    release_id: ID,
    kind: ReleaseDistributionKind,
): ReleaseDistributionLicense<Distributor, Format> {
    ReleaseDistributionLicense {
        release_id: release_id,
        kind: kind,
        unit_prices_by_currency: vec_map::empty(),
    }
}

public(package) fun add_unit_price_for_currency<Distributor, Format, Currency>(
    self: &mut ReleaseDistributionLicense<Distributor, Format>,
    unit_price: u64,
) {
    self.unit_prices_by_currency.insert(with_defining_ids<Currency>(), unit_price);
}

public(package) fun remove_unit_price_for_currency<Distributor, Format, Currency>(
    self: &mut ReleaseDistributionLicense<Distributor, Format>,
) {
    self.unit_prices_by_currency.remove(&with_defining_ids<Currency>());
}

public(package) fun attach_license<Distributor, Format>(parent: &mut UID, release_id: ID) {
    df::add(parent, ReleaseDistributionLicenseKey(), ReleaseDistributionLicenseGrant(release_id))
}

//=== Public View Functions ===

public fun release_id<Distributor, Format>(
    self: &ReleaseDistributionLicense<Distributor, Format>,
): ID {
    self.release_id
}

public fun quantity<Distributor, Format>(
    self: &ReleaseDistributionLicense<Distributor, Format>,
): u64 {
    match (self.kind) {
        ReleaseDistributionKind::Digital(quantity) => quantity,
        ReleaseDistributionKind::Physical(quantity) => quantity,
        _ => abort 0,
    }
}

public fun unit_price<Distributor, Format, Currency>(
    self: &ReleaseDistributionLicense<Distributor, Format>,
): u64 {
    let currency_type = &with_defining_ids<Currency>();
    assert!(self.unit_prices_by_currency.contains(currency_type));
    *self.unit_prices_by_currency.get(currency_type)
}

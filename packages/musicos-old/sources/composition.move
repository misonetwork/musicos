// Copyright (c) Sona Labs, Pte Ltd.
// SPDX-License-Identifier: Apache-2.0

module musicos::composition;

use coin_treasury::treasury_facility::TreasuryFacility;
use music::music::MUSIC;
use musicos::composition_contributor_role::CompositionContributorRole;
use musicos::contributor::{Contributor};
use musicos::revenue_pool;
use musicos::royalty_pool;
use musicos::protocol::Protocol;
use musicos::share::{Self, share_icon_url};
use musicos::witness::{Self, Witness};
use std::string::String;
use sui::derived_object::claim;
use sui::clock::Clock;
use sui::coin::{Coin, TreasuryCap};
use sui::coin_registry::{Currency, MetadataCap};
use sui::event::emit;
use sui::balance::Balance;
use sui::vec_map::{Self, VecMap};
use sui::vec_set::{Self, VecSet};
use interest_bps::bps::BPS;

//=== Structs ===

public struct Composition<phantom CompositionShare> has key {
    id: UID,
    // State of the composition.
    state: CompositionState,
    // Title of the composition.
    title: String,
    // Optional subtitle of the composition.
    subtitle: Option<String>,
    // Map of addresses to composition contributor roles.
    contributors: VecMap<ID, VecSet<CompositionContributorRole>>,
    // Optional map of language codes to Walrus Blob IDs of LRC files.
    lyrics: Option<String>,
    // Commission rate that Recordings must pay to the Composition.
    commission_rate: BPS,
    // Optional Walrus quilt ID that acts as a folder for the composition's Walrus-based assets.
    quilt_id: Option<String>,
    // MetadataCap for the composition's share currency.
    metadata_cap: MetadataCap<CompositionShare>,
}

public enum CompositionState has copy, drop, store {
    Created,
    Published(u64),
}

public struct CompositionAdminCap has key, store {
    id: UID,
    composition_id: ID,
}

public struct CompositionAdminCapKey() has copy, drop, store;

//=== Events ===

public struct CompositionCreatedEvent has copy, drop, store {
    composition_id: ID,
}

//=== Constants ===

const MAX_CONTRIBUTORS: u64 = 100;

//=== Errors ===

const EInvalidCompositionAdminCap: u64 = 0;
const EMaxArtifactsExceeded: u64 = 1;
const EMaxContributorsExceeded: u64 = 2;
const ENotContributor: u64 = 3;

//=== Public Functions ===

public fun new<CompositionShare>(
    commission_rate: BPS,
    title: String,
    currency: &mut Currency<CompositionShare>,
    metadata_cap: MetadataCap<CompositionShare>,
    treasury_cap: TreasuryCap<CompositionShare>,
    ctx: &mut TxContext,
): (Composition<CompositionShare>, CompositionAdminCap, Balance<CompositionShare>) {
    let mut composition = Composition<CompositionShare> {
        id: object::new(ctx),
        state: CompositionState::Created,
        title,
        subtitle: option::none(),
        contributors: vec_map::empty(),
        lyrics: option::none(),
        commission_rate,
        quilt_id: option::none(),
        metadata_cap,
    };

    let composition_admin_cap = CompositionAdminCap {
        id: claim(&mut composition.id, CompositionAdminCapKey()),
        composition_id: composition.id(),
    };

    let mut description = b"MusicOS Composition Shares for ".to_string();
    description.append(composition.id().to_address().to_string());

    let balance = share::intialize<CompositionShare>(
        b"MusicOS Composition Share".to_string(),
        description,
        share_icon_url!(),
        currency,
        &composition.metadata_cap,
        treasury_cap,
    );

    emit(CompositionCreatedEvent {
        composition_id: composition.id(),
    });

    (composition, composition_admin_cap, balance)
}

// TODO: Gate for protocol migration only.
public fun destroy<CompositionShare>(self: Composition<CompositionShare>, cap: CompositionAdminCap): MetadataCap<CompositionShare> {
    let Composition<CompositionShare> { id, metadata_cap,.. } = self;
    id.delete();
    let CompositionAdminCap { id, .. } = cap;
    id.delete();
    metadata_cap
}

// Publish a composition. Calling this function requires passing the Composition
// object by value. This guarantees that a published composition is a shared object.
#[allow(lint(share_owned))]
public fun publish<CompositionShare>(self: &mut Composition<CompositionShare>, cap: &CompositionAdminCap, fee: &mut Coin<MUSIC>, treasury_facility: &mut TreasuryFacility<MUSIC, Witness>, protocol: &Protocol, clock: &Clock) {
    self.authorize(cap);
    self.state = CompositionState::Published(clock.timestamp_ms());
    treasury_facility.burn(witness::new(), fee.balance_mut().split(protocol.composition_publishing_fee()));
}

public fun set_subtitle<CompositionShare>(self: &mut Composition<CompositionShare>, cap: &CompositionAdminCap, subtitle: String) {
    self.authorize(cap);
    self.subtitle.fill(subtitle)
}

public fun set_quilt_id<CompositionShare>(self: &mut Composition<CompositionShare>, cap: &CompositionAdminCap, quilt_id: String) {
    self.authorize(cap);
    self.quilt_id = self.quilt_id.swap_or_fill(quilt_id);
}

public fun add_contributor<CompositionShare>(
    self: &mut Composition<CompositionShare>,
    cap: &CompositionAdminCap,
    contributor: &Contributor,
    protocol: &Protocol,
) {
    self.authorize(cap);
    assert!(self.contributors.length() < protocol.max_composition_contributors() as u64, EMaxContributorsExceeded);
    self.contributors.insert(contributor.id(), vec_set::empty());
}

public fun remove_contributor<CompositionShare>(
    self: &mut Composition<CompositionShare>,
    cap: &CompositionAdminCap,
    contributor_id: &ID,
) {
    self.authorize(cap);
    self.contributors.remove(contributor_id);
}

public fun add_contributor_role<CompositionShare>(
    self: &mut Composition<CompositionShare>,
    cap: &CompositionAdminCap,
    contributor_id: &ID,
    role: CompositionContributorRole,
) {
    self.authorize(cap);
    self.contributors.get_mut(contributor_id).insert(role);
}

public fun remove_contributor_role<CompositionShare>(
    self: &mut Composition<CompositionShare>,
    cap: &CompositionAdminCap,
    contributor_id: &ID,
    role: CompositionContributorRole,
) {
    self.authorize(cap);
    self.contributors.get_mut(contributor_id).remove(&role);
}

#[allow(lint(share_owned))]
public fun initialize_revenue_pool<CompositionShare, RevenueCurrency>(self: &mut Composition<CompositionShare>) {
    let revenue_pool = revenue_pool::new<RevenueCurrency>(&mut self.id);
    transfer::public_share_object(revenue_pool);
}

#[allow(lint(share_owned))]
public fun initialize_royalty_pool<CompositionShare, RevenueCurrency>(self: &mut Composition<CompositionShare>) {
    let royalty_pool = royalty_pool::new<CompositionShare, RevenueCurrency>(&mut self.id);
    transfer::public_share_object(royalty_pool);
}

// Derive the address of the Composition's RevenuePool and transfer
// funds to the RevenuePool's balance accumulator.
public fun deposit_revenue<CompositionShare, RevenueCurrency>(self: &Composition<CompositionShare>, balance: Balance<RevenueCurrency>, ctx: &mut TxContext) {
    // Assert the RevenuePool for the provided Composition/Currency pair exists.
    revenue_pool::assert_exists<RevenueCurrency>(&self.id);
    // Transfer the funds to the RevenuePool's balance accumulator.
    // TODO: Migrate to accumulators when possible.
    //balance.send_funds(revenue_pool::derive_address<Currency>(self.id()));
    transfer::public_transfer(balance.into_coin(ctx), revenue_pool::derive_address<RevenueCurrency>(self.id()));
}

//=== Public View Functions ===

public fun id<CompositionShare>(self: &Composition<CompositionShare>): ID {
    self.id.to_inner()
}

public fun authorize<CompositionShare>(self: &Composition<CompositionShare>, cap: &CompositionAdminCap) {
    assert!(object::id(self) == cap.composition_id, EInvalidCompositionAdminCap);
}

public fun commission_rate<CompositionShare>(self: &Composition<CompositionShare>): BPS {
    self.commission_rate
}


//=== Package Functions ===

public(package) fun uid<CompositionShare>(self: &Composition<CompositionShare>): &UID {
    &self.id
}

public(package) fun uid_mut<CompositionShare>(self: &mut Composition<CompositionShare>): &mut UID {
    &mut self.id
}

//=== Private Functions ===

fun build_work_share_icon_url<Work: key>(work: &Work): String {
    let mut name = b"https://img.coda.network/workshare.webp".to_string();
    name.append(object::id(work).to_address().to_string());
    name
}

fun build_work_share_name<Work: key>(work: &Work): String {
    let mut name = b"CODASHARE-".to_string();
    name.append(object::id(work).to_address().to_string());
    name
}

fun build_work_share_description<Work: key>(work: &Work): String {
    let mut description = b"Coda shares for".to_string();
    description.append(" ");
    description.append(object::id(work).to_address().to_string());
    description.append(" ");
    description
}
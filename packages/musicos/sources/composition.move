// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module musicos::composition;

use currency_treasury::burn_facility::BurnFacility;
use interest_bps::bps::BPS;
use music::music::MUSIC;
use musicos::composition_contributor_role::CompositionContributorRole;
use musicos::contributor::Contributor;
use musicos::key::{Self, RewardPoolKey, RevenuePoolKey};
use musicos::protocol::Protocol;
use musicos::share;
use revenue_pool::revenue_pool::{Self, RevenuePool};
use reward_pool::reward_pool::{Self, RewardPool};
use std::string::String;
use sui::balance::Balance;
use sui::clock::Clock;
use sui::coin::TreasuryCap;
use sui::coin_registry::{Currency, MetadataCap};
use sui::derived_object::claim;
use sui::event::emit;
use sui::vec_map::{Self, VecMap};

//=== Structs ===

public struct Composition<phantom CompositionShare> has key {
    id: UID,
    state: CompositionState,
    title: String,
    subtitle: Option<String>,
    contributors: VecMap<ID, vector<CompositionContributorRole>>,
    split: BPS,
    share_metadata_cap: MetadataCap<CompositionShare>,
}

public struct CompositionAdminCap has key, store {
    id: UID,
    composition_id: ID,
}

public struct ShareCompositionPromise(ID)

//=== Derivation Keys ===

public struct CompositionAdminCapKey() has copy, drop, store;

//=== Events ===

public struct CompositionCreatedEvent has copy, drop {
    composition_id: ID,
}

public struct CompositionPublishedEvent has copy, drop {
    composition_id: ID,
}

public struct CompositionContributorAddedEvent has copy, drop {
    composition_id: ID,
    contributor_id: ID,
}

public struct CompositionContributorRemovedEvent has copy, drop {
    composition_id: ID,
    contributor_id: ID,
}

public struct CompositionSplitSetEvent has copy, drop {
    composition_id: ID,
    split: BPS,
}

//=== Enums ===

public enum CompositionState has copy, drop, store {
    Created,
    Published(u64),
}

//=== Constants ===

const MIN_ROLES_PER_CONTRIBUTOR: u64 = 1;
const MAX_ROLES_PER_CONTRIBUTOR: u64 = 20;

//=== Errors ===

const EUnauthorized: u64 = 0;
const ENotCreatedState: u64 = 1;
const EContributorRoleAlreadyExists: u64 = 2;
const EContributorRoleIndexOutOfBounds: u64 = 3;
const EMinRolesNotMet: u64 = 4;
const EExceedsMaxRoles: u64 = 5;
const EInvalidCompositionForPromise: u64 = 6;
const ENoContributors: u64 = 7;
const EInvalidCompositionFee: u64 = 8;

//=== Public Functions ===

public fun new<CompositionShare>(
    title: String,
    split: BPS,
    share_currency: &mut Currency<CompositionShare>,
    share_metadata_cap: MetadataCap<CompositionShare>,
    share_treasury_cap: TreasuryCap<CompositionShare>,
    ctx: &mut TxContext,
): (
    Composition<CompositionShare>,
    CompositionAdminCap,
    Balance<CompositionShare>,
    ShareCompositionPromise,
) {
    let mut composition = Composition {
        id: object::new(ctx),
        state: CompositionState::Created,
        title,
        subtitle: option::none(),
        contributors: vec_map::empty(),
        split,
        share_metadata_cap,
    };

    let composition_admin_cap = CompositionAdminCap {
        id: claim(&mut composition.id, CompositionAdminCapKey()),
        composition_id: composition.id(),
    };

    let mut description = b"MusicOS Composition Shares for 0x".to_string();
    description.append(composition.id().to_address().to_string());
    description.append(b".".to_string());

    let composition_shares = share::intialize<CompositionShare>(
        b"MusicOS Composition Share".to_string(),
        description,
        share_currency,
        &composition.share_metadata_cap,
        share_treasury_cap,
    );

    let share_composition_promise = ShareCompositionPromise(composition.id());

    emit(CompositionCreatedEvent {
        composition_id: composition.id(),
    });

    (composition, composition_admin_cap, composition_shares, share_composition_promise)
}

// Share a composition.
// Required State: Created
public fun share<CompositionShare>(
    self: Composition<CompositionShare>,
    share_composition_promise: ShareCompositionPromise,
) {
    match (self.state) {
        CompositionState::Created => {
            let ShareCompositionPromise(composition_id) = share_composition_promise;
            assert!(self.id() == composition_id, EInvalidCompositionForPromise);
            transfer::share_object(self);
        },
        _ => abort ENotCreatedState,
    }
}

// Publish a composition.
// Required State: Created
public fun publish<CompositionShare>(
    self: &mut Composition<CompositionShare>,
    cap: &CompositionAdminCap,
    fee: Balance<MUSIC>,
    burn_facility: &BurnFacility<MUSIC>,
    protocol: &Protocol,
    clock: &Clock,
) {
    self.authorize(cap);

    match (self.state) {
        CompositionState::Created => {
            // Assert the fee is correct.
            assert!(fee.value() == protocol.composition_publishing_fee(), EInvalidCompositionFee);
            fee.send_funds(burn_facility.id().to_address());

            // Assert the composition has at least one contributor.
            assert!(!self.contributors.is_empty(), ENoContributors);

            self.state = CompositionState::Published(clock.timestamp_ms());

            emit(CompositionPublishedEvent {
                composition_id: self.id(),
            });
        },
        _ => abort ENotCreatedState,
    }
}

// Set the title of a composition.
// Required State: Created
public fun set_title<CompositionShare>(
    self: &mut Composition<CompositionShare>,
    cap: &CompositionAdminCap,
    title: String,
) {
    self.authorize(cap);

    match (self.state) {
        CompositionState::Created => {
            self.title = title;
        },
        _ => abort ENotCreatedState,
    }
}

// Set the subtitle of a composition.
// Required State: Created
public fun set_subtitle<CompositionShare>(
    self: &mut Composition<CompositionShare>,
    cap: &CompositionAdminCap,
    subtitle: String,
) {
    self.authorize(cap);

    match (self.state) {
        CompositionState::Created => {
            self.subtitle.swap_or_fill(subtitle);
        },
        _ => abort ENotCreatedState,
    }
}

// Set the composition split of a composition.
public fun set_split<CompositionShare>(
    self: &mut Composition<CompositionShare>,
    cap: &CompositionAdminCap,
    split: BPS,
) {
    self.authorize(cap);

    self.split = split;

    emit(CompositionSplitSetEvent {
        composition_id: self.id(),
        split: split,
    });
}

// Add a contributor to a composition.
// Required State: Created
public fun add_contributor<CompositionShare>(
    self: &mut Composition<CompositionShare>,
    cap: &CompositionAdminCap,
    contributor: &Contributor,
    roles: vector<CompositionContributorRole>,
) {
    self.authorize(cap);

    match (self.state) {
        CompositionState::Created => {
            assert!(roles.length() >= MIN_ROLES_PER_CONTRIBUTOR, EMinRolesNotMet);
            assert!(roles.length() <= MAX_ROLES_PER_CONTRIBUTOR, EExceedsMaxRoles);

            self.contributors.insert(contributor.id(), roles);

            emit(CompositionContributorAddedEvent {
                composition_id: self.id(),
                contributor_id: contributor.id(),
            });
        },
        _ => abort ENotCreatedState,
    }
}

// Remove a contributor from a composition.
// Required State: Created
public fun remove_contributor<CompositionShare>(
    self: &mut Composition<CompositionShare>,
    cap: &CompositionAdminCap,
    contributor_id: ID,
) {
    self.authorize(cap);

    match (self.state) {
        CompositionState::Created => {
            self.contributors.remove(&contributor_id);

            emit(CompositionContributorRemovedEvent {
                composition_id: self.id(),
                contributor_id: contributor_id,
            });
        },
        _ => abort ENotCreatedState,
    }
}

// Add a role to a contributor.
// Required State: Created
public fun add_role_to_contributor<CompositionShare>(
    self: &mut Composition<CompositionShare>,
    cap: &CompositionAdminCap,
    contributor_id: ID,
    role: CompositionContributorRole,
) {
    self.authorize(cap);

    match (self.state) {
        CompositionState::Created => {
            let roles = self.contributors.get_mut(&contributor_id);

            assert!(!roles.contains(&role), EContributorRoleAlreadyExists);
            assert!(roles.length() < MAX_ROLES_PER_CONTRIBUTOR, EExceedsMaxRoles);

            roles.push_back(role);
        },
        _ => abort ENotCreatedState,
    }
}

// Remove a role from a contributor.
// Required State: Created
public fun remove_role_from_contributor<CompositionShare>(
    self: &mut Composition<CompositionShare>,
    cap: &CompositionAdminCap,
    contributor_id: ID,
    role_idx: u64,
) {
    self.authorize(cap);

    match (self.state) {
        CompositionState::Created => {
            let roles = self.contributors.get_mut(&contributor_id);
            assert!(role_idx < roles.length(), EContributorRoleIndexOutOfBounds);
            assert!(roles.length() > MIN_ROLES_PER_CONTRIBUTOR, EMinRolesNotMet);
            roles.swap_remove(role_idx);
        },
        _ => abort ENotCreatedState,
    }
}

public fun new_revenue_pool<CompositionShare, Currency>(self: &mut Composition<CompositionShare>) {
    let revenue_pool = revenue_pool::new<Currency, RevenuePoolKey<Currency>>(
        &mut self.id,
        key::new_revenue_pool_key<Currency>(),
    );
    transfer::public_share_object(revenue_pool);
}

public fun new_reward_pool<CompositionShare, Currency>(self: &mut Composition<CompositionShare>) {
    let reward_pool = reward_pool::new<CompositionShare, Currency, RewardPoolKey<Currency>>(
        &mut self.id,
        key::new_reward_pool_key<Currency>(),
    );
    transfer::public_share_object(reward_pool);
}

//=== Package Functions ===

public(package) fun uid_mut<CompositionShare>(self: &mut Composition<CompositionShare>): &mut UID {
    &mut self.id
}

//=== Public View Functions ===

public fun id<CompositionShare>(self: &Composition<CompositionShare>): ID {
    self.id.to_inner()
}

public fun title<CompositionShare>(self: &Composition<CompositionShare>): &String {
    &self.title
}

public fun subtitle<CompositionShare>(self: &Composition<CompositionShare>): &Option<String> {
    &self.subtitle
}

public fun contributors<CompositionShare>(
    self: &Composition<CompositionShare>,
): &VecMap<ID, vector<CompositionContributorRole>> {
    &self.contributors
}

public fun split<CompositionShare>(self: &Composition<CompositionShare>): BPS {
    self.split
}

//=== Private Functions ===

public(package) fun authorize<CompositionShare>(
    self: &Composition<CompositionShare>,
    cap: &CompositionAdminCap,
) {
    assert!(self.id() == cap.composition_id, EUnauthorized);
}

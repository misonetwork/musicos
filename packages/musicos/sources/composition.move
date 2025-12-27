// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module musicos::composition;

use interest_bps::bps::BPS;
use musicos::composition_contributor_role::CompositionContributorRole;
use musicos::contributor::Contributor;
use musicos::protocol::Protocol;
use musicos::share;
use std::string::String;
use std::type_name::{Self, TypeName};
use sui::balance::Balance;
use sui::clock::Clock;
use sui::coin::TreasuryCap;
use sui::coin_registry::{Currency, MetadataCap};
use sui::event::emit;
use sui::vec_map::{Self, VecMap};

//=== Structs ===

public struct Composition<phantom CompositionShare> has key {
    id: UID,
    state: CompositionState,
    title: String,
    subtitle: Option<String>,
    contributors: VecMap<ID, vector<CompositionContributorRole>>,
    commission_rate: BPS,
    share_metadata_cap: MetadataCap<CompositionShare>,
}

public struct CompositionAdminCap has key, store {
    id: UID,
    composition_id: ID,
}

public struct ShareCompositionPromise {
    composition_id: ID,
}

//=== Events ===

public struct CompositionCreatedEvent has copy, drop {
    composition_id: ID,
    share_type: TypeName,
}

public struct CompositionContributorAddedEvent has copy, drop {
    composition_id: ID,
    contributor_id: ID,
}

public struct CompositionContributorRemovedEvent has copy, drop {
    composition_id: ID,
    contributor_id: ID,
}

public struct CompositionCommissionRateSetEvent has copy, drop {
    composition_id: ID,
    commission_rate: BPS,
}

//=== Enums ===

public enum CompositionState has copy, drop, store {
    Initialized,
    Created,
    Published(u64),
}

//=== Errors ===

const EUnauthorized: u64 = 0;
const ENotCreatedState: u64 = 1;
const EContributorRoleAlreadyExists: u64 = 2;
const EContributorRoleIndexOutOfBounds: u64 = 3;
const EMinRolesNotMet: u64 = 4;
const EMaxRolesExceeded: u64 = 5;
const EInvalidComposition: u64 = 6;

//=== Public Functions ===

public fun new<CompositionShare>(
    title: String,
    subtitle: Option<String>,
    commission_rate: BPS,
    share_currency: &mut Currency<CompositionShare>,
    share_metadata_cap: MetadataCap<CompositionShare>,
    share_treasury_cap: TreasuryCap<CompositionShare>,
    ctx: &mut TxContext,
): (Composition<CompositionShare>, CompositionAdminCap, Balance<CompositionShare>) {
    let composition = Composition {
        id: object::new(ctx),
        state: CompositionState::Initialized,
        title,
        subtitle,
        contributors: vec_map::empty(),
        commission_rate,
        share_metadata_cap,
    };

    let composition_admin_cap = CompositionAdminCap {
        id: object::new(ctx),
        composition_id: composition.id(),
    };

    let mut description = b"MusicOS Composition Shares for ".to_string();
    description.append(composition.id().to_address().to_string());

    let composition_shares = share::intialize<CompositionShare>(
        b"MusicOS Composition Share".to_string(),
        description,
        share_currency,
        &composition.share_metadata_cap,
        share_treasury_cap,
    );

    emit(CompositionCreatedEvent {
        composition_id: composition.id(),
        share_type: type_name::with_defining_ids<CompositionShare>(),
    });

    (composition, composition_admin_cap, composition_shares)
}

// Share a composition.
// Required State: Initialized
public fun share<CompositionShare>(
    mut self: Composition<CompositionShare>,
    promise: ShareCompositionPromise,
) {
    match (self.state) {
        CompositionState::Initialized => {
            let ShareCompositionPromise { composition_id } = promise;
            assert!(self.id() == composition_id, EInvalidComposition);
            self.state = CompositionState::Created;
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
    clock: &Clock,
) {
    self.authorize(cap);

    match (self.state) {
        CompositionState::Created => {
            self.state = CompositionState::Published(clock.timestamp_ms());
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

// Set the commission rate of a composition.
public fun set_commission_rate<CompositionShare>(
    self: &mut Composition<CompositionShare>,
    cap: &CompositionAdminCap,
    commission_rate: BPS,
) {
    self.authorize(cap);

    self.commission_rate = commission_rate;

    emit(CompositionCommissionRateSetEvent {
        composition_id: self.id(),
        commission_rate: commission_rate,
    });
}

// Add a contributor to a composition.
// Required State: Created
public fun add_contributor<CompositionShare>(
    self: &mut Composition<CompositionShare>,
    cap: &CompositionAdminCap,
    contributor: &Contributor,
    roles: vector<CompositionContributorRole>,
    protocol: &Protocol,
) {
    self.authorize(cap);

    match (self.state) {
        CompositionState::Created => {
            assert!(roles.length() >= protocol.min_contributor_roles(), EMinRolesNotMet);
            assert!(roles.length() <= protocol.max_contributor_roles(), EMaxRolesExceeded);
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
    protocol: &Protocol,
) {
    self.authorize(cap);

    match (self.state) {
        CompositionState::Created => {
            let roles = self.contributors.get_mut(&contributor_id);
            assert!(!roles.contains(&role), EContributorRoleAlreadyExists);
            assert!(roles.length() < protocol.max_contributor_roles(), EMaxRolesExceeded);
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
    protocol: &Protocol,
) {
    self.authorize(cap);

    match (self.state) {
        CompositionState::Created => {
            let roles = self.contributors.get_mut(&contributor_id);
            assert!(role_idx < roles.length(), EContributorRoleIndexOutOfBounds);
            assert!(roles.length() > protocol.min_contributor_roles(), EMinRolesNotMet);
            roles.swap_remove(role_idx);
        },
        _ => abort ENotCreatedState,
    }
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

public fun commission_rate<CompositionShare>(self: &Composition<CompositionShare>): BPS {
    self.commission_rate
}

//=== Private Functions ===

public(package) fun authorize<CompositionShare>(
    self: &Composition<CompositionShare>,
    cap: &CompositionAdminCap,
) {
    assert!(self.id() == cap.composition_id, EUnauthorized);
}

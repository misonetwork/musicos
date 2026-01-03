// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module musicos::contributor;

use sui::derived_object::claim;
use sui::vec_set::{Self, VecSet};

//=== Structs ===

public struct CONTRIBUTOR() has drop;

public struct Contributor has key {
    id: UID,
    kind: ContributorKind,
    state: ContributorState,
}

public struct ContributorAdminCap has key, store {
    id: UID,
    contributor_id: ID,
}
//=== Derivation Keys ===

public struct ContributorAdminCapKey(ID) has copy, drop, store;

//=== Enums ===

public enum ContributorKind has copy, drop, store {
    Individual,
    Group(VecSet<ID>),
}

public enum ContributorState has copy, drop, store {
    Created,
    Active,
}

//=== Errors ===

const EUnauthorized: u64 = 0;
const ENotGroupKind: u64 = 1;

//=== Public Functions ===

public fun new(kind: ContributorKind, ctx: &mut TxContext): ContributorAdminCap {
    let mut contributor = Contributor {
        id: object::new(ctx),
        kind,
        state: ContributorState::Created,
    };

    let contributor_id = contributor.id();

    let contributor_admin_cap = ContributorAdminCap {
        id: claim(&mut contributor.id, ContributorAdminCapKey(contributor_id)),
        contributor_id: contributor.id(),
    };

    transfer::share_object(contributor);

    contributor_admin_cap
}

public fun add_contributor(
    self: &mut Contributor,
    cap: &ContributorAdminCap,
    contributor: &Contributor,
) {
    self.authorize(cap);

    match (&mut self.kind) {
        ContributorKind::Group(members) => {
            members.insert(contributor.id());
        },
        _ => abort ENotGroupKind,
    }
}

public fun remove_contributor(
    self: &mut Contributor,
    cap: &ContributorAdminCap,
    contributor_id: ID,
) {
    self.authorize(cap);

    match (&mut self.kind) {
        ContributorKind::Group(members) => {
            members.remove(&contributor_id);
        },
        _ => abort ENotGroupKind,
    }
}

// TODO: Only allow for protocol migration.
public fun destroy(self: Contributor, cap: ContributorAdminCap) {
    self.authorize(&cap);

    let Contributor { id, .. } = self;
    id.delete();

    let ContributorAdminCap { id, .. } = cap;
    id.delete();
}

public fun new_individual_kind(): ContributorKind {
    ContributorKind::Individual
}

public fun new_group_kind(): ContributorKind {
    ContributorKind::Group(vec_set::empty())
}

//=== Public View Functions ===

public fun id(contributor: &Contributor): ID {
    object::id(contributor)
}

//=== Private Functions ===

fun authorize(self: &Contributor, cap: &ContributorAdminCap) {
    assert!(cap.contributor_id == self.id(), EUnauthorized);
}

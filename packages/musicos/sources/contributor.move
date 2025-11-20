// Copyright (c) Sona Labs, Pte Ltd.
// SPDX-License-Identifier: Apache-2.0

module musicos::contributor;

use music::music::MUSIC;
use musicos::protocol::Protocol;
use musicos::treasury::Treasury;
use std::string::String;
use sui::coin::Coin;
use sui::derived_object::claim;
use sui::transfer::Receiving;
use sui::vec_set::VecSet;

//=== Structs ===

public struct Contributor has key {
    id: UID,
    name: ContributorName,
    kind: ContributorKind,
    website: Option<String>,
}

public struct ContributorAdminCap has key, store {
    id: UID,
    contributor_id: ID,
}

// Identity struct that stores a contributor's address and name.
public struct ContributorID has copy, drop, store {
    addr: address,
    name: String,
}

public struct ContributorRegistry has key {
    id: UID,
    count: u64,
}

//=== Keys ===

public struct ContributorKey(String, u16) has copy, drop, store;
public struct ContributorAdminCapKey() has copy, drop, store;

//=== Enums ===

public enum ContributorKind has copy, drop, store {
    Individual,
    Group,
}

public enum ContributorName has copy, drop, store {
    Unverified(String),
    VerificationRequested(String, u64),
    Verifying(String, u64),
    Verified(String),
}

const EUnauthorized: u64 = 0;
const ENotUnverifiedState: u64 = 1;
const ENotVerifyingState: u64 = 2;
const ENotVerifiedState: u64 = 3;

//=== Public Functions ===

public fun new(name: String, kind: ContributorKind, ctx: &mut TxContext) {
    let mut contributor = Contributor {
        id: object::new(ctx),
        name: ContributorName::Unverified(name),
        kind,
        website: option::none(),
    };

    let contributor_admin_cap = ContributorAdminCap {
        id: claim(&mut contributor.id, ContributorAdminCapKey()),
        contributor_id: contributor.id(),
    };

    transfer::share_object(contributor);
    transfer::share_object(contributor_admin_cap);
}

public fun new_individual_kind(name: String): ContributorKind {
    ContributorKind::Individual
}

public fun new_group_kind(name: String): ContributorKind {
    ContributorKind::Group
}

public fun request_verification(
    self: &mut Contributor,
    cap: &ContributorAdminCap,
    fee: Coin<MUSIC>,
    treasury: &mut Treasury,
) {
    self.authorize(cap);
    treasury.deposit(fee.into_balance());
}

public fun submit_verification<Authority: drop>(
    self: &mut Contributor,
    _: Authority,
    protocol: &Protocol,
    ctx: &TxContext,
) {
    match (self.name) {
        ContributorName::Unverified(name) => {
            protocol.assert_is_contributor_verification_authority<Authority>();
            self.name = ContributorName::Verifying(name, ctx.epoch() + 2)
        },
        _ => abort ENotUnverifiedState,
    }
}

public fun revoke_verification<Authority: drop>(
    self: &mut Contributor,
    _: Authority,
    protocol: &Protocol,
) {
    match (self.name) {
        ContributorName::Verifying(name, _) => {
            protocol.assert_is_contributor_verification_authority<Authority>();
            self.name = ContributorName::Unverified(name)
        },
        _ => abort ENotVerifyingState,
    }
}

public fun complete_verification(self: &mut Contributor, ctx: &TxContext) {
    match (self.name) {
        ContributorName::Verifying(name, epoch) => {
            if (ctx.epoch() >= epoch) {
                self.name = ContributorName::Verified(name);
            }
        },
        _ => abort ENotVerifyingState,
    }
}

// Create a new ContributorID object for the Contributor.
public fun contributor_id(self: &Contributor): ContributorID {
    ContributorID {
        addr: self.id().to_address(),
        name: self.name(),
    }
}

public fun receive<T: key + store>(self: &mut Contributor, obj_to_receive: Receiving<T>): T {
    transfer::public_receive(&mut self.id, obj_to_receive)
}

public fun receive_coin<T>(self: &mut Contributor, coin_to_receive: Receiving<Coin<T>>): Coin<T> {
    transfer::public_receive(&mut self.id, coin_to_receive)
}

//=== Public View Functions ===

public fun id(self: &Contributor): ID {
    self.id.to_inner()
}

public fun name(self: &Contributor): String {
    match (self.name) {
        ContributorName::Unverified(name) => name,
        ContributorName::VerificationRequested(name, _) => name,
        ContributorName::Verifying(name, _) => name,
        ContributorName::Verified(name) => name,
    }
}

public fun is_individual_kind(self: &Contributor): bool {
    match (self.kind) {
        ContributorKind::Individual => true,
        ContributorKind::Group => false,
    }
}

public fun is_group_kind(self: &Contributor): bool {
    match (self.kind) {
        ContributorKind::Individual => false,
        ContributorKind::Group => true,
    }
}

public fun assert_is_verified(self: &Contributor) {
    match (&self.name) {
        ContributorName::Verified(_) => (),
        _ => abort ENotVerifiedState,
    }
}

//=== Private Functions ===

fun authorize(self: &Contributor, cap: &ContributorAdminCap) {
    assert!(cap.contributor_id == self.id(), EUnauthorized);
}

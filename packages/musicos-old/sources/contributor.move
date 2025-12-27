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
use sui::vec_set::{Self, VecSet};

public use fun contributor_admin_cap_contributor_id as ContributorAdminCap.contributor_id;

//=== Structs ===

// TODO: Enforce max member count for groups.
/// A `Contributor` is an individual or a group that can be referenced in
/// the MusicOS compositions and recordings, and higher-level applications.
public struct Contributor has key {
    id: UID,
    name: ContributorName,
    kind: ContributorKind,
    description: Option<String>,
    links: vector<String>,
}

public struct ContributorAdminCap has key, store {
    id: UID,
    contributor_id: ID,
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
    Group(VecSet<ID>),
}

public enum ContributorLink has copy, drop, store {
    AmazonMusic(String),
    AppleMusic(String),
    BandCamp(String),
    Deezer(String),
    Discord(String),
    Email(String),
    Facebook(String),
    GitHub(String),
    Instagram(String),
    LinkedIn(String),
    Medium(String),
    Newsletter(String),
    SoundCloud(String),
    Spotify(String),
    Tidal(String),
    TikTok(String),
    Website(String),
    YouTube(String),
    YouTubeMusic(String),
    X(String),
}

public enum ContributorName has copy, drop, store {
    Unverified(String),
    VerificationRequested(String, u64),
    Verifying(String, u64),
    Verified(String),
}

//=== Errors ===

const EUnauthorized: u64 = 0;
const ENotUnverifiedState: u64 = 1;
const ENotVerifyingState: u64 = 2;
const ENotVerifiedState: u64 = 3;
const EMaxContributorGroupSizeExceeded: u64 = 4;
const EContributorAlreadyInGroup: u64 = 5;
const EContributorNotInGroup: u64 = 6;

//=== Public Functions ===

public fun new(name: String, kind: ContributorKind, ctx: &mut TxContext): ContributorAdminCap {
    let mut contributor = Contributor {
        id: object::new(ctx),
        name: ContributorName::Unverified(name),
        description: option::none(),
        kind,
        links: vector[],
    };

    let contributor_admin_cap = ContributorAdminCap {
        id: claim(&mut contributor.id, ContributorAdminCapKey()),
        contributor_id: contributor.id(),
    };

    transfer::share_object(contributor);

    contributor_admin_cap
}

public fun new_individual_kind(): ContributorKind {
    ContributorKind::Individual
}

public fun new_group_kind(): ContributorKind {
    ContributorKind::Group(vec_set::empty())
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

public fun receive<Object: key + store>(
    self: &mut Contributor,
    obj_to_receive: Receiving<Object>,
): Object {
    transfer::public_receive(&mut self.id, obj_to_receive)
}

public fun receive_coin<Currency>(
    self: &mut Contributor,
    coin_to_receive: Receiving<Coin<Currency>>,
): Coin<Currency> {
    transfer::public_receive(&mut self.id, coin_to_receive)
}

public fun add_member(
    self: &mut Contributor,
    cap: &ContributorAdminCap,
    contributor: &Contributor,
    protocol: &Protocol,
) {
    self.authorize(cap);

    match (&mut self.kind) {
        ContributorKind::Group(members) => {
            let contributor_id = contributor.id();
            // Assert the contributor isn't already in the group.
            assert!(!members.contains(&contributor_id), EContributorAlreadyInGroup);
            // Assert the group has space for the new contributor.
            assert!(
                members.length() < protocol.max_contributor_group_size() as u64,
                EMaxContributorGroupSizeExceeded,
            );
            members.insert(contributor.id());
        },
        _ => abort 0,
    }
}

public fun remove_member(self: &mut Contributor, cap: &ContributorAdminCap, contributor_id: ID) {
    self.authorize(cap);

    match (&mut self.kind) {
        ContributorKind::Group(members) => {
            assert!(members.contains(&contributor_id), EContributorNotInGroup);
            members.remove(&contributor_id);
        },
        _ => abort 0,
    }
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
        ContributorKind::Group(..) => false,
    }
}

public fun is_group_kind(self: &Contributor): bool {
    match (self.kind) {
        ContributorKind::Individual => false,
        ContributorKind::Group(..) => true,
    }
}

public fun is_name_verified(self: &Contributor): bool {
    match (&self.name) {
        ContributorName::Verified(_) => true,
        _ => false,
    }
}

public fun assert_is_name_verified(self: &Contributor) {
    assert!(self.is_name_verified(), ENotVerifiedState);
}

public fun contributor_admin_cap_contributor_id(cap: &ContributorAdminCap): ID {
    cap.contributor_id
}

//=== Private Functions ===

fun authorize(self: &Contributor, cap: &ContributorAdminCap) {
    assert!(cap.contributor_id == self.id(), EUnauthorized);
}

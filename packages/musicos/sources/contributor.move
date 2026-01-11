// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Represents artists, producers, and other contributors in the MusicOS protocol.
/// Contributors can be individuals or groups (bands, orchestras, etc.).
/// Each contributor has an admin capability for managing their profile.
///
/// Key features:
/// - Individual and group contributor types
/// - Extensible metadata via dynamic fields
/// - Capability-based authorization for modifications
/// - Groups can contain multiple individual contributors
module musicos::contributor;

use std::string::String;
use sui::derived_object::claim;
use sui::dynamic_field as df;
use sui::vec_set::{Self, VecSet};

//=== Structs ===

/// One-time witness for the contributor module.
public struct CONTRIBUTOR() has drop;

/// A contributor (artist, producer, etc.) in the music ecosystem.
/// Can represent an individual or a group of contributors.
public struct Contributor has key {
    /// Unique identifier for this contributor.
    id: UID,
    /// Whether this is an individual or group contributor.
    kind: ContributorKind,
    /// Current lifecycle state of the contributor.
    state: ContributorState,
    /// Display name of the contributor.
    name: String,
}

/// Capability that authorizes modifications to a specific contributor.
/// Created when a contributor is registered and transferred to the owner.
public struct ContributorAdminCap has key, store {
    /// Unique identifier for this capability.
    id: UID,
    /// ID of the contributor this capability controls.
    contributor_id: ID,
}

/// Type-safe key for storing metadata on a contributor via dynamic fields.
public struct ContributorMetadataKey<phantom Metadata: drop + store>() has copy, drop, store;

//=== Derivation Keys ===

/// Key for deriving the admin capability's deterministic address.
public struct ContributorAdminCapKey(
    /// ID of the contributor.
    ID,
) has copy, drop, store;

//=== Enums ===

/// The type of contributor: individual person or group.
public enum ContributorKind has copy, drop, store {
    /// A single person (artist, producer, etc.).
    Individual,
    /// A group containing multiple individual contributors.
    Group(
        /// Set of individual contributor IDs in this group.
        VecSet<ID>,
    ),
}

/// Lifecycle state of a contributor.
public enum ContributorState has copy, drop, store {
    /// Contributor has been created but not yet activated.
    Created,
    /// Contributor is active and can participate in recordings/compositions.
    Active,
}

//=== Errors ===

/// The provided admin capability does not match this contributor.
const EUnauthorized: u64 = 0;
/// Operation requires an individual contributor, but a group was provided.
const ENotIndividualKind: u64 = 1;
/// Operation requires a group contributor, but an individual was provided.
const ENotGroupKind: u64 = 2;
/// Attempted to add a contributor that is already a member of the group.
const EDuplicateContributor: u64 = 3;

//=== Public Functions ===

/// Creates a new contributor with the specified kind and name.
/// Returns the admin capability for managing the contributor.
/// The contributor is shared and starts in the Created state.
public fun new(kind: ContributorKind, name: String, ctx: &mut TxContext): ContributorAdminCap {
    let mut contributor = Contributor {
        id: object::new(ctx),
        kind,
        state: ContributorState::Created,
        name,
    };

    let contributor_id = contributor.id();

    let contributor_admin_cap = ContributorAdminCap {
        id: claim(&mut contributor.id, ContributorAdminCapKey(contributor_id)),
        contributor_id: contributor.id(),
    };

    transfer::share_object(contributor);

    contributor_admin_cap
}

/// Adds an individual contributor to a group.
/// Requires the admin capability for the group.
/// The contributor being added must be an individual (not another group).
public fun add_contributor(
    self: &mut Contributor,
    cap: &ContributorAdminCap,
    contributor: &Contributor,
) {
    self.authorize(cap);

    match (&mut self.kind) {
        ContributorKind::Group(contributors) => {
            // Assert the contributor that is being added is an individual.
            contributor.assert_is_individual_kind();
            // Assert the contributor that is being added is not already a contributors to the group.
            assert!(!contributors.contains(&contributor.id()), EDuplicateContributor);
            // Add the contributor to the group.
            contributors.insert(contributor.id());
        },
        _ => abort ENotGroupKind,
    }
}

/// Removes a contributor from a group by their ID.
/// Requires the admin capability for the group.
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
/// Destroys a contributor and its admin capability.
/// Requires the matching admin capability.
public fun destroy(self: Contributor, cap: ContributorAdminCap) {
    self.authorize(&cap);

    let Contributor { id, .. } = self;
    id.delete();

    let ContributorAdminCap { id, .. } = cap;
    id.delete();
}

/// Adds typed metadata to a contributor via dynamic fields.
/// Requires the admin capability.
public fun add_metadata<Metadata: drop + store>(
    self: &mut Contributor,
    cap: &ContributorAdminCap,
    metadata: Metadata,
) {
    self.authorize(cap);

    df::add(&mut self.id, ContributorMetadataKey<Metadata>(), metadata)
}

/// Removes and returns typed metadata from a contributor.
/// Requires the admin capability.
public fun remove_metadata<Metadata: drop + store>(
    self: &mut Contributor,
    cap: &ContributorAdminCap,
): Metadata {
    self.authorize(cap);

    df::remove<ContributorMetadataKey<Metadata>, Metadata>(
        &mut self.id,
        ContributorMetadataKey<Metadata>(),
    )
}

/// Sets typed metadata on a contributor, replacing any existing value.
/// Requires the admin capability.
public fun set_metadata<Metadata: drop + store>(
    self: &mut Contributor,
    cap: &ContributorAdminCap,
    metadata: Metadata,
) {
    self.authorize(cap);

    df::remove_if_exists<ContributorMetadataKey<Metadata>, Metadata>(
        &mut self.id,
        ContributorMetadataKey<Metadata>(),
    );

    df::add(&mut self.id, ContributorMetadataKey<Metadata>(), metadata)
}

/// Returns a reference to typed metadata attached to a contributor.
public fun borrow_metadata<Metadata: drop + store>(self: &Contributor): &Metadata {
    df::borrow<ContributorMetadataKey<Metadata>, Metadata>(
        &self.id,
        ContributorMetadataKey<Metadata>(),
    )
}

/// Checks if a contributor has the specified metadata type attached.
public fun has_metadata<Metadata: drop + store>(self: &Contributor): bool {
    df::exists_with_type<ContributorMetadataKey<Metadata>, Metadata>(
        &self.id,
        ContributorMetadataKey<Metadata>(),
    )
}

/// Creates a new individual contributor kind.
public fun new_individual_kind(): ContributorKind {
    ContributorKind::Individual
}

/// Creates a new group contributor kind with an empty member set.
public fun new_group_kind(): ContributorKind {
    ContributorKind::Group(vec_set::empty())
}

//=== Public View Functions ===

/// Returns the ID of this contributor.
public fun id(contributor: &Contributor): ID {
    object::id(contributor)
}

/// Returns true if this contributor is an individual.
public fun is_individual_kind(contributor: &Contributor): bool {
    match (&contributor.kind) {
        ContributorKind::Individual => true,
        _ => false,
    }
}

/// Returns true if this contributor is a group.
public fun is_group_kind(contributor: &Contributor): bool {
    match (&contributor.kind) {
        ContributorKind::Group(_) => true,
        _ => false,
    }
}

/// Aborts if this contributor is not an individual.
public fun assert_is_individual_kind(contributor: &Contributor) {
    assert!(is_individual_kind(contributor), ENotIndividualKind);
}

/// Aborts if this contributor is not a group.
public fun assert_is_group_kind(contributor: &Contributor) {
    assert!(is_group_kind(contributor), ENotGroupKind);
}

//=== Private Functions ===

/// Verifies that the admin capability matches this contributor.
fun authorize(self: &Contributor, cap: &ContributorAdminCap) {
    assert!(cap.contributor_id == self.id(), EUnauthorized);
}

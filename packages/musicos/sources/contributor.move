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

use musicos::plugin::PluginCap;
use sui::derived_object::claim;
use sui::event::emit;
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
}

/// Capability that authorizes modifications to a specific contributor.
/// Created when a contributor is registered and transferred to the owner.
public struct ContributorAdminCap has key, store {
    /// Unique identifier for this capability.
    id: UID,
    /// ID of the contributor this capability controls.
    contributor_id: ID,
    /// Address of the sender of the capability.
    sender: address,
}

/// Witness type sourced from the contributor module.
public struct ContributorWitness() has drop;

//=== Derivation Keys ===

/// Key for deriving the admin capability's deterministic address.
public struct ContributorAdminCapKey(
    /// ID of the contributor.
    ID,
) has copy, drop, store;

//=== Enums ===

/// The type of self: individual person or group.
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

//=== Events ===

public struct ContributorCreatedEvent has copy, drop {
    /// ID of the newly created contributor.
    contributor_id: ID,
}

//=== Errors ===

/// The provided admin capability does not match this contributor.
const EUnauthorized: u64 = 0;
/// Attempted to add a contributor that is already a member of the group.
const EDuplicateContributor: u64 = 30;
/// Operation requires an individual contributor, but a group was provided.
const ENotIndividualKind: u64 = 31;
/// Operation requires a group contributor, but an individual was provided.
const ENotGroupKind: u64 = 32;

//=== Public Functions ===

/// Creates a new contributor with the specified kind and name.
/// Returns the admin capability for managing the contributor.
/// The contributor is shared and starts in the Created state.
public fun new(kind: ContributorKind, ctx: &mut TxContext): ContributorAdminCap {
    let mut contributor = Contributor {
        id: object::new(ctx),
        kind,
        state: ContributorState::Created,
    };

    let contributor_id = contributor.id();

    let contributor_admin_cap = ContributorAdminCap {
        id: claim(&mut contributor.id, ContributorAdminCapKey(contributor_id)),
        contributor_id,
        sender: ctx.sender(),
    };

    emit(ContributorCreatedEvent {
        contributor_id: contributor.id(),
    });

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
// TODO: Validate MigrationWitness.
/// Destroys a contributor and its admin capability.
/// Requires the matching admin capability.
public fun destroy<MigrationWitness: drop>(
    self: Contributor,
    cap: ContributorAdminCap,
    _: MigrationWitness,
) {
    self.authorize(&cap);

    let Contributor { id, .. } = self;
    id.delete();

    let ContributorAdminCap { id, .. } = cap;
    id.delete();
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
public fun id(self: &Contributor): ID {
    self.id.to_inner()
}

/// Returns true if this contributor is an individual.
public fun is_individual_kind(self: &Contributor): bool {
    match (&self.kind) {
        ContributorKind::Individual => true,
        _ => false,
    }
}

/// Returns true if this contributor is a group.
public fun is_group_kind(self: &Contributor): bool {
    match (&self.kind) {
        ContributorKind::Group(_) => true,
        _ => false,
    }
}

/// Aborts if this contributor is not an individual.
public fun assert_is_individual_kind(self: &Contributor) {
    assert!(is_individual_kind(self), ENotIndividualKind);
}

/// Aborts if this contributor is not a group.
public fun assert_is_group_kind(self: &Contributor) {
    assert!(is_group_kind(self), ENotGroupKind);
}

//=== UID Functions ===

public fun uid_with_plugin<PluginWitness: drop>(
    self: &Contributor,
    cap: &ContributorAdminCap,
    _plugin_cap: PluginCap<ContributorWitness, PluginWitness>,
): &UID {
    self.authorize(cap);
    &self.id
}

public fun uid_mut_with_plugin<PluginWitness: drop>(
    self: &mut Contributor,
    cap: &ContributorAdminCap,
    _plugin_cap: PluginCap<ContributorWitness, PluginWitness>,
): &mut UID {
    self.authorize(cap);
    &mut self.id
}

//=== Private Functions ===

/// Verifies that the admin capability matches this contributor.
public fun authorize(self: &Contributor, cap: &ContributorAdminCap) {
    assert!(cap.contributor_id == self.id(), EUnauthorized);
}

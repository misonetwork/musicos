// Copyright (c) Studio Mirai, LLC
// Copyright (c) Unconfirmed Labs, LLC
// Copyright (c) Alex Clapworthy
// SPDX-License-Identifier: Apache-2.0

/// Represents artists, producers, and other parties in MusicOS.
/// Parties can be individuals or groups (bands, orchestras, etc.).
/// Each party has an admin capability for managing their profile.
///
/// Key features:
/// - Individual and group party types
/// - Extensible metadata via dynamic fields
/// - Capability-based authorization for modifications
/// - Groups can contain multiple individual parties
module musicos::party;

use std::string::String;
use sui::derived_object::claim;
use sui::event::emit;
use sui::vec_set::{Self, VecSet};

//=== Structs ===

/// One-time witness for the party module.
public struct PARTY() has drop;

/// A party (artist, producer, etc.) in the music ecosystem.
/// Can represent an individual or a group of parties.
public struct Party has key {
    /// Unique identifier for this party.
    id: UID,
    /// Whether this is an individual or group party.
    kind: PartyKind,
    /// Human-readable name of the party.
    /// Note this name is not "official" or "verified" in any way.
    /// Verification should be performed by the application layer.
    name: String,
}

/// Capability that authorizes modifications to a specific party.
/// Created when a party is registered and transferred to the owner.
public struct PartyAdminCap has key, store {
    /// Unique identifier for this capability.
    id: UID,
    /// ID of the party this capability controls.
    party_id: ID,
}

//=== Derivation Keys ===

/// Key for deriving the admin capability's deterministic address.
public struct PartyAdminCapKey(
    /// ID of the party.
    ID,
) has copy, drop, store;

//=== Enums ===

/// The type of self: individual person or group.
public enum PartyKind has copy, drop, store {
    /// A single person (artist, producer, etc.).
    Individual,
    /// A group containing multiple individual parties.
    Group(
        /// Set of individual party IDs in this group.
        VecSet<ID>,
    ),
}

//=== Events ===

public struct PartyCreatedEvent has copy, drop {
    /// ID of the newly created party.
    party_id: ID,
    /// Name of the party.
    name: String,
}

/// Emitted when a party is added to a group.
public struct PartyAddedToGroupEvent has copy, drop {
    /// ID of the group.
    group_id: ID,
    /// ID of the party added to the group.
    party_id: ID,
}

/// Emitted when a party is removed from a group.
public struct PartyRemovedFromGroupEvent has copy, drop {
    /// ID of the group.
    group_id: ID,
    /// ID of the party removed from the group.
    party_id: ID,
}

//=== Errors ===

/// The provided admin capability does not match this party.
const EUnauthorized: u64 = 0;
/// Attempted to add a party that is already a member of the group.
const EDuplicateParty: u64 = 30;
/// Operation requires an individual party, but a group was provided.
const ENotIndividualKind: u64 = 31;
/// Operation requires a group party, but an individual was provided.
const ENotGroupKind: u64 = 32;

//=== Public Functions ===

/// Creates a new party with the specified kind and name.
/// Returns the admin capability for managing the party.
/// The party is shared and starts in the Created state.
public fun new(
    kind: PartyKind,
    name: String,
    ctx: &mut TxContext,
): (Party, PartyAdminCap) {
    let mut party = Party {
        id: object::new(ctx),
        kind,
        name,
    };

    let party_id = party.id();

    let party_admin_cap = PartyAdminCap {
        id: claim(&mut party.id, PartyAdminCapKey(party_id)),
        party_id,
    };

    emit(PartyCreatedEvent {
        party_id: party.id(),
        name,
    });

    (party, party_admin_cap)
}

// Turn the party into a shared object.
public fun share(self: Party, cap: &PartyAdminCap) {
    self.authorize(cap);
    transfer::share_object(self);
}

// Set the human-readable name of the party.
public fun set_name(self: &mut Party, cap: &PartyAdminCap, name: String) {
    self.authorize(cap);
    self.name = name;
}

/// Adds an individual party to a group.
/// Requires the admin capability for the group.
/// The party being added must be an individual (not another group).
public fun add_party(
    self: &mut Party,
    cap: &PartyAdminCap,
    party: &Party,
) {
    self.authorize(cap);

    match (&mut self.kind) {
        PartyKind::Group(parties) => {
            // Assert the party that is being added is an individual.
            party.assert_is_individual_kind();
            // Assert the party that is being added is not already a member of the group.
            assert!(!parties.contains(&party.id()), EDuplicateParty);
            // Add the party to the group.
            parties.insert(party.id());

            emit(PartyAddedToGroupEvent {
                group_id: self.id(),
                party_id: party.id(),
            });
        },
        _ => abort ENotGroupKind,
    }
}

/// Removes a party from a group by their ID.
/// Requires the admin capability for the group.
public fun remove_party(
    self: &mut Party,
    cap: &PartyAdminCap,
    party_id: ID,
) {
    self.authorize(cap);

    match (&mut self.kind) {
        PartyKind::Group(members) => {
            members.remove(&party_id);

            emit(PartyRemovedFromGroupEvent {
                group_id: self.id(),
                party_id,
            });
        },
        _ => abort ENotGroupKind,
    }
}

/// Creates a new individual party kind.
public fun new_individual_kind(): PartyKind {
    PartyKind::Individual
}

/// Creates a new group party kind with an empty member set.
public fun new_group_kind(): PartyKind {
    PartyKind::Group(vec_set::empty())
}

//=== Public View Functions ===

/// Returns the ID of this party.
public fun id(self: &Party): ID {
    self.id.to_inner()
}

/// Returns true if this party is an individual.
public fun is_individual_kind(self: &Party): bool {
    match (&self.kind) {
        PartyKind::Individual => true,
        _ => false,
    }
}

/// Returns true if this party is a group.
public fun is_group_kind(self: &Party): bool {
    match (&self.kind) {
        PartyKind::Group(_) => true,
        _ => false,
    }
}

/// Returns the human-readable name of this party.
public fun name(self: &Party): String {
    self.name
}

/// Aborts if this party is not an individual.
public fun assert_is_individual_kind(self: &Party) {
    assert!(is_individual_kind(self), ENotIndividualKind);
}

/// Aborts if this party is not a group.
public fun assert_is_group_kind(self: &Party) {
    assert!(is_group_kind(self), ENotGroupKind);
}

/// Returns a reference to the group members.
/// Aborts if this party is not a group.
public fun group_members(self: &Party): &VecSet<ID> {
    match (&self.kind) {
        PartyKind::Group(members) => members,
        _ => abort ENotGroupKind,
    }
}

//=== UID Functions ===

/// Returns a reference to the party's UID for reading dynamic fields.
/// Requires the admin capability.
public fun uid(self: &Party, cap: &PartyAdminCap): &UID {
    self.authorize(cap);
    &self.id
}

/// Returns a mutable reference to the party's UID for dynamic field operations.
/// Requires the admin capability.
public fun uid_mut(self: &mut Party, cap: &PartyAdminCap): &mut UID {
    self.authorize(cap);
    &mut self.id
}

//=== Private Functions ===

/// Verifies that the admin capability matches this party.
fun authorize(self: &Party, cap: &PartyAdminCap) {
    assert!(cap.party_id == self.id(), EUnauthorized);
}

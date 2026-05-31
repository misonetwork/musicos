// Copyright (c) Unconfirmed Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Represents a musical composition (song, instrumental work) in MusicOS.
/// Compositions are the underlying written works that recordings are based on.
/// Each composition has its own share token for ownership distribution.
///
/// ### Key Features:
///
/// - Share token initialization with fixed supply (100M tokens, 6 decimals)
/// - Party management with role assignments (Composer, Lyricist, Songwriter)
/// - State machine: Initialized -> Published (immutable after publish)
/// - Revenue and reward pool creation for reward distribution
/// - Deterministic addresses via derived object pattern
module musicos::composition;

use bps::bps::{Self, BPS};
use musicos::composition_party_role::CompositionPartyRole;
use partyos::credit::Credit;
use partyos::party::Party;
use share::share;
use std::string::String;
use sui::balance::Balance;
use sui::clock::Clock;
use sui::coin::TreasuryCap;
use sui::coin_registry::Currency;
use sui::derived_object::claim;
use sui::event::emit;
use sui::vec_map::{Self, VecMap};

// === Structs ===

/// A musical composition representing the underlying written work.
/// The phantom CompositionShare type parameter links to the share token.
public struct Composition<phantom CompositionShare> has key {
    /// Unique identifier for this composition.
    id: UID,
    /// Current lifecycle state.
    state: CompositionState,
    /// Primary title of the composition.
    title: String,
    /// Map of party IDs to their roles on this composition.
    credits: VecMap<ID, Credit<CompositionPartyRole>>,
    /// Revenue split rate allocated to this composition vs recording (in basis points).
    split_bps: BPS,
}

/// Capability that authorizes modifications to a specific composition.
/// Initialized when a composition is registered and transferred to the owner.
/// Address is derived from the composition for client-side discoverability.
public struct CompositionAdminCap<phantom CompositionShare> has key, store {
    /// Unique identifier for this capability.
    id: UID,
}

// === Derivation Keys ===

/// Key for deriving the admin capability's deterministic address from the composition.
public struct CompositionAdminCapKey() has copy, drop, store;

// === Enums ===

/// Lifecycle state of a composition.
public enum CompositionState has copy, drop, store {
    /// Composition is initialized but not published.
    Initialized,
    /// Composition is published and immutable. Includes publication timestamp.
    Published(
        /// Timestamp (ms) when published.
        u64,
    ),
}

// === Events ===

/// Emitted when a composition is published.
public struct CompositionPublishedEvent<phantom CompositionShare> has copy, drop {
    composition_id: ID,
    title: String,
    split_bps_value: u16,
    published_at_ms: u64,
    published_by: address,
}

/// Emitted when a party is added to a composition.
public struct CompositionPartyAddedEvent has copy, drop {
    composition_id: ID,
    party_id: ID,
    credit_display_name: String,
}

/// Emitted for each role assigned to a credited party on a composition.
public struct CompositionCreditRoleAssignedEvent has copy, drop {
    composition_id: ID,
    party_id: ID,
    role_name: String,
}

// === Constants ===

/// Minimum number of roles a party must have.
const MIN_ROLES_PER_PARTY: u64 = 1;
/// Maximum number of roles a party can have.
const MAX_ROLES_PER_PARTY: u64 = 5;
/// Maximum number of credits allowed on a composition.
const MAX_CREDITS: u64 = 50;
/// Maximum length of a title in bytes.
const MAX_TITLE_LENGTH: u64 = 300;

// === Errors ===

// State errors (10-19)
/// Operation requires Initialized state but composition is in a different state.
const ENotInitializedState: u64 = 10;

// Validation errors (20-29)
/// Party must have at least one role.
const EMinRolesNotMet: u64 = 20;

// Constraint errors (30-39)
/// Party has too many roles.
const EExceedsMaxRoles: u64 = 30;
/// Composition has too many credits.
const EMaxCreditsExceeded: u64 = 32;
/// Title exceeds maximum length.
const EMaxTitleLengthExceeded: u64 = 33;
/// String must not be empty.
const EEmptyString: u64 = 35;

// Conflict errors (40-49)
/// Party already has a credit on this composition.
const EPartyAlreadyCredited: u64 = 40;

// Reference errors (50-59)
/// Composition must have at least one party to publish.
const ENoParties: u64 = 50;

// === Public Functions ===

// === Lifecycle ===

/// Creates a new composition with the given title and split.
/// Initializes share tokens (100M supply, 6 decimals) and returns:
/// - The composition object
/// - Admin capability for the owner
/// - Initial share token balance
/// - Promise that must be consumed by calling `share()`
public fun new<CompositionShare>(
    title: String,
    split_value: u16,
    share_currency: &mut Currency<CompositionShare>,
    share_treasury_cap: TreasuryCap<CompositionShare>,
    ctx: &mut TxContext,
): (
    Composition<CompositionShare>,
    CompositionAdminCap<CompositionShare>,
    Balance<CompositionShare>,
) {
    assert!(!title.is_empty(), EEmptyString);
    assert!(title.length() <= MAX_TITLE_LENGTH, EMaxTitleLengthExceeded);

    let mut composition = Composition<CompositionShare> {
        id: object::new(ctx),
        state: CompositionState::Initialized,
        title,
        credits: vec_map::empty(),
        split_bps: bps::new(split_value),
    };

    let composition_admin_cap = CompositionAdminCap<CompositionShare> {
        id: claim(&mut composition.id, CompositionAdminCapKey()),
    };

    let composition_shares = share::initialize<CompositionShare>(
        share_currency,
        share_treasury_cap,
    );

    (composition, composition_admin_cap, composition_shares)
}

/// Publishes the composition, making it immutable.
/// Requires at least one party.
/// Required State: Initialized
public fun publish<CompositionShare>(
    mut self: Composition<CompositionShare>,
    _: &CompositionAdminCap<CompositionShare>,
    clock: &Clock,
    ctx: &TxContext,
) {
    match (self.state) {
        CompositionState::Initialized => {
            assert!(!self.credits.is_empty(), ENoParties);

            let published_at_ms = clock.timestamp_ms();
            self.state = CompositionState::Published(published_at_ms);

            emit(CompositionPublishedEvent<CompositionShare> {
                composition_id: self.id(),
                title: *self.title(),
                split_bps_value: self.split_bps.value(),
                published_at_ms,
                published_by: ctx.sender(),
            });

            transfer::share_object(self);
        },
        _ => abort ENotInitializedState,
    }
}

// === People ===

/// Adds a party to the composition with specified roles.
/// Each party must have 1-20 roles.
/// Required State: Initialized
public fun add_credit<CompositionShare>(
    self: &mut Composition<CompositionShare>,
    _: &CompositionAdminCap<CompositionShare>,
    party: &Party,
    credit: Credit<CompositionPartyRole>,
) {
    match (self.state) {
        CompositionState::Initialized => {
            assert!(credit.roles().length() >= MIN_ROLES_PER_PARTY, EMinRolesNotMet);
            assert!(credit.roles().length() <= MAX_ROLES_PER_PARTY, EExceedsMaxRoles);
            assert!(self.credits.length() < MAX_CREDITS, EMaxCreditsExceeded);

            let party_id = party.id();
            // Abort early if party already has a credit on this composition.
            assert!(!self.credits.contains(&party_id), EPartyAlreadyCredited);
            self.credits.insert(party_id, credit);

            let composition_id = self.id();
            emit(CompositionPartyAddedEvent {
                composition_id,
                party_id,
                credit_display_name: *credit.display_name(),
            });

            let roles = credit.roles();
            let mut i = 0;
            while (i < roles.length()) {
                emit(CompositionCreditRoleAssignedEvent {
                    composition_id,
                    party_id,
                    role_name: roles[i].name(),
                });
                i = i + 1;
            };
        },
        _ => abort ENotInitializedState,
    }
}

// === Financial ===

/// Sets the revenue split rate for this composition.
/// The split determines what percentage of track revenue goes to the composition
/// vs the recording. Must be set before publishing. Note that updating the split_bps
/// only impacts future recordings of the composition.
/// Required State: Initialized
public fun set_split_bps<CompositionShare>(
    self: &mut Composition<CompositionShare>,
    _: &CompositionAdminCap<CompositionShare>,
    split_value: u16,
) {
    match (self.state) {
        CompositionState::Initialized => {
            self.split_bps = bps::new(split_value);
        },
        _ => abort ENotInitializedState,
    }
}

// === Public View Functions ===

/// Returns the composition's object ID.
public fun id<CompositionShare>(self: &Composition<CompositionShare>): ID {
    self.id.to_inner()
}

/// Returns the current lifecycle state.
public fun state<CompositionShare>(self: &Composition<CompositionShare>): CompositionState {
    self.state
}

/// Returns true if the composition is in the Initialized state.
public fun is_initialized_state<CompositionShare>(self: &Composition<CompositionShare>): bool {
    match (self.state) { CompositionState::Initialized => true, _ => false }
}

/// Returns true if the composition is in the Published state.
public fun is_published_state<CompositionShare>(self: &Composition<CompositionShare>): bool {
    match (self.state) { CompositionState::Published(_) => true, _ => false }
}

/// Returns the primary title.
public fun title<CompositionShare>(self: &Composition<CompositionShare>): &String {
    &self.title
}

/// Returns the party-to-credit mapping.
public fun credits<CompositionShare>(
    self: &Composition<CompositionShare>,
): &VecMap<ID, Credit<CompositionPartyRole>> {
    &self.credits
}

/// Returns the revenue split rate in basis points.
public fun split_bps<CompositionShare>(self: &Composition<CompositionShare>): BPS {
    self.split_bps
}

// === UID Functions ===

/// Returns a reference to the composition's UID for reading dynamic fields.
public fun uid<CompositionShare>(self: &Composition<CompositionShare>): &UID {
    &self.id
}

/// Returns a mutable reference to the composition's UID.
/// Requires the admin capability.
public fun uid_mut<CompositionShare>(
    self: &mut Composition<CompositionShare>,
    _: &CompositionAdminCap<CompositionShare>,
): &mut UID {
    &mut self.id
}

public(package) fun uid_mut_internal<CompositionShare>(
    self: &mut Composition<CompositionShare>,
): &mut UID {
    &mut self.id
}

// === Test Only ===

#[test_only]
public fun new_for_testing<CompositionShare>(
    title: String,
    split_value: u16,
    ctx: &mut TxContext,
): (Composition<CompositionShare>, CompositionAdminCap<CompositionShare>) {
    assert!(!title.is_empty(), EEmptyString);
    assert!(title.length() <= MAX_TITLE_LENGTH, EMaxTitleLengthExceeded);

    let mut composition = Composition<CompositionShare> {
        id: object::new(ctx),
        state: CompositionState::Initialized,
        title,
        credits: vec_map::empty(),
        split_bps: bps::new(split_value),
    };

    let composition_admin_cap = CompositionAdminCap<CompositionShare> {
        id: claim(&mut composition.id, CompositionAdminCapKey()),
    };

    (composition, composition_admin_cap)
}

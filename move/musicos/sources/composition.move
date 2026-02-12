// Copyright (c) Studio Mirai, LLC
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

use interest_bps::bps::{Self, BPS};
use musicos::composition_party_role::CompositionPartyRole;
use musicos::credit::Credit;
use musicos::extension;
use musicos::party::Party;
use musicos::share;
use std::string::String;
use sui::balance::Balance;
use sui::clock::Clock;
use sui::coin::TreasuryCap;
use sui::coin_registry::Currency;
use sui::derived_object::claim;
use sui::event::emit;
use sui::vec_map::{Self, VecMap};
use walrus_data::walrus_data::WalrusData;

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
    /// Additional titles (translations, alternate names).
    alternate_titles: vector<String>,
    /// Map of party IDs to their roles on this composition.
    credits: VecMap<ID, Credit<CompositionPartyRole>>,
    /// Revenue split rate allocated to this composition vs recording (in basis points).
    split_bps: BPS,
    /// Optional lyrics data reference.
    lyrics: Option<WalrusData>,
    /// Optional chart data reference.
    chart: Option<WalrusData>,
    /// Optional score data reference.
    score: Option<WalrusData>,
    /// Optional audio demo of the composition.
    demo: Option<WalrusData>,
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

/// Emitted when a new composition is created.
public struct CompositionInitializedEvent has copy, drop {
    /// ID of the created composition.
    composition_id: ID,
}

/// Emitted when a composition is published.
public struct CompositionPublishedEvent<phantom CompositionShare> has copy, drop {
    /// ID of the published composition.
    composition_id: ID,
}

/// Emitted when a party is added to a composition.
public struct CompositionPartyAddedEvent has copy, drop {
    /// ID of the composition.
    composition_id: ID,
    /// ID of the added party.
    party_id: ID,
}

/// Emitted when an extension is registered for a composition.
public struct CompositionExtensionRegisteredEvent<phantom Extension: drop> has copy, drop {
    /// ID of the composition.
    composition_id: ID,
}

/// Emitted when an extension is unregistered from a composition.
public struct CompositionExtensionUnregisteredEvent<phantom Extension: drop> has copy, drop {
    /// ID of the composition.
    composition_id: ID,
}

/// Emitted when the composition split is updated.
public struct CompositionSplitSetEvent has copy, drop {
    /// ID of the composition.
    composition_id: ID,
    /// New split value in basis points.
    split_value: u64,
}

// === Constants ===

/// Minimum number of roles a party must have.
const MIN_ROLES_PER_PARTY: u64 = 1;
/// Maximum number of roles a party can have.
const MAX_ROLES_PER_PARTY: u64 = 20;

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

// Conflict errors (40-49)
/// Party already has a credit on this composition.
const EPartyAlreadyCredited: u64 = 40;

// Reference errors (50-59)
/// Composition must have at least one party to publish.
const ENoParties: u64 = 50;
/// Composition must have at least one of demo, chart, or score to publish.
const ENoContent: u64 = 51;

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
    split_value: u64,
    share_currency: &mut Currency<CompositionShare>,
    share_treasury_cap: TreasuryCap<CompositionShare>,
    ctx: &mut TxContext,
): (
    Composition<CompositionShare>,
    CompositionAdminCap<CompositionShare>,
    Balance<CompositionShare>,
) {
    let mut composition = Composition<CompositionShare> {
        id: object::new(ctx),
        state: CompositionState::Initialized,
        title,
        alternate_titles: vector[],
        credits: vec_map::empty(),
        split_bps: bps::new(split_value),
        lyrics: option::none(),
        chart: option::none(),
        score: option::none(),
        demo: option::none(),
    };

    let composition_admin_cap = CompositionAdminCap<CompositionShare> {
        id: claim(&mut composition.id, CompositionAdminCapKey()),
    };

    let composition_shares = share::initialize<CompositionShare>(
        share_currency,
        share_treasury_cap,
    );

    emit(CompositionInitializedEvent {
        composition_id: composition.id(),
    });

    (composition, composition_admin_cap, composition_shares)
}

/// Publishes the composition, making it immutable.
/// Requires at least one party and at least one of lyrics, chart, score, or demo.
/// Required State: Initialized
public fun publish<CompositionShare>(
    mut self: Composition<CompositionShare>,
    _: &CompositionAdminCap<CompositionShare>,
    clock: &Clock,
) {
    match (self.state) {
        CompositionState::Initialized => {
            assert!(!self.credits.is_empty(), ENoParties);

            // Assert the composition has at least one of lyrics, chart, score, or demo.
            assert!(
                self.lyrics.is_some() || self.chart.is_some() || self.score.is_some() || self.demo.is_some(),
                ENoContent,
            );

            self.state = CompositionState::Published(clock.timestamp_ms());

            emit(CompositionPublishedEvent<CompositionShare> {
                composition_id: self.id(),
            });

            transfer::share_object(self);
        },
        _ => abort ENotInitializedState,
    }
}

// === Title ===

/// Adds an alternate title to the composition.
/// Required State: Initialized
public fun add_alternate_title<CompositionShare>(
    self: &mut Composition<CompositionShare>,
    _: &CompositionAdminCap<CompositionShare>,
    alternate_title: String,
) {
    match (self.state) {
        CompositionState::Initialized => {
            self.alternate_titles.push_back(alternate_title);
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

            let party_id = party.id();
            // Abort early if party already has a credit on this composition.
            assert!(!self.credits.contains(&party_id), EPartyAlreadyCredited);
            self.credits.insert(party_id, credit);

            emit(CompositionPartyAddedEvent {
                composition_id: self.id(),
                party_id,
            });
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
    split_value: u64,
) {
    match (self.state) {
        CompositionState::Initialized => {
            self.split_bps = bps::new(split_value);

            emit(CompositionSplitSetEvent {
                composition_id: self.id(),
                split_value: self.split_bps.value(),
            });
        },
        _ => abort ENotInitializedState,
    }
}

// === Content ===

/// Sets the lyrics data reference for the composition.
/// Required State: Initialized
public fun set_lyrics<CompositionShare>(
    self: &mut Composition<CompositionShare>,
    _: &CompositionAdminCap<CompositionShare>,
    lyrics: WalrusData,
) {
    match (self.state) {
        CompositionState::Initialized => {
            self.lyrics = option::some(lyrics);
        },
        _ => abort ENotInitializedState,
    }
}

/// Clears the lyrics data reference from the composition.
/// Required State: Initialized
public fun clear_lyrics<CompositionShare>(
    self: &mut Composition<CompositionShare>,
    _: &CompositionAdminCap<CompositionShare>,
) {
    match (self.state) {
        CompositionState::Initialized => {
            self.lyrics = option::none();
        },
        _ => abort ENotInitializedState,
    }
}

/// Sets the demo audio reference for the composition.
/// Required State: Initialized
public fun set_demo<CompositionShare>(
    self: &mut Composition<CompositionShare>,
    _: &CompositionAdminCap<CompositionShare>,
    demo: WalrusData,
) {
    match (self.state) {
        CompositionState::Initialized => {
            self.demo = option::some(demo);
        },
        _ => abort ENotInitializedState,
    }
}

/// Clears the demo audio reference from the composition.
/// Required State: Initialized
public fun clear_demo<CompositionShare>(
    self: &mut Composition<CompositionShare>,
    _: &CompositionAdminCap<CompositionShare>,
) {
    match (self.state) {
        CompositionState::Initialized => {
            self.demo = option::none();
        },
        _ => abort ENotInitializedState,
    }
}

/// Sets the chart data reference for the composition.
/// Required State: Initialized
public fun set_chart<CompositionShare>(
    self: &mut Composition<CompositionShare>,
    _: &CompositionAdminCap<CompositionShare>,
    chart: WalrusData,
) {
    match (self.state) {
        CompositionState::Initialized => {
            self.chart = option::some(chart);
        },
        _ => abort ENotInitializedState,
    }
}

/// Clears the chart data reference from the composition.
/// Required State: Initialized
public fun clear_chart<CompositionShare>(
    self: &mut Composition<CompositionShare>,
    _: &CompositionAdminCap<CompositionShare>,
) {
    match (self.state) {
        CompositionState::Initialized => {
            self.chart = option::none();
        },
        _ => abort ENotInitializedState,
    }
}

/// Sets the score data reference for the composition.
/// Required State: Initialized
public fun set_score<CompositionShare>(
    self: &mut Composition<CompositionShare>,
    _: &CompositionAdminCap<CompositionShare>,
    score: WalrusData,
) {
    match (self.state) {
        CompositionState::Initialized => {
            self.score = option::some(score);
        },
        _ => abort ENotInitializedState,
    }
}

/// Clears the score data reference from the composition.
/// Required State: Initialized
public fun clear_score<CompositionShare>(
    self: &mut Composition<CompositionShare>,
    _: &CompositionAdminCap<CompositionShare>,
) {
    match (self.state) {
        CompositionState::Initialized => {
            self.score = option::none();
        },
        _ => abort ENotInitializedState,
    }
}

// === Extensions ===

/// Registers an extension for the composition with associated config.
public fun register_extension<CompositionShare, Extension: drop, Config: drop + store>(
    self: &mut Composition<CompositionShare>,
    _: &CompositionAdminCap<CompositionShare>,
    _extension: Extension,
    config: Config,
) {
    extension::register<Extension, Config>(&mut self.id, config);

    emit(CompositionExtensionRegisteredEvent<Extension> {
        composition_id: self.id(),
    });
}

/// Unregisters an extension from the composition and returns its config.
public fun unregister_extension<CompositionShare, Extension: drop, Config: drop + store>(
    self: &mut Composition<CompositionShare>,
    _: &CompositionAdminCap<CompositionShare>,
    _extension: Extension,
): Config {
    let config = extension::unregister<Extension, Config>(&mut self.id);

    emit(CompositionExtensionUnregisteredEvent<Extension> {
        composition_id: self.id(),
    });

    config
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

/// Returns the primary title.
public fun title<CompositionShare>(self: &Composition<CompositionShare>): &String {
    &self.title
}

/// Returns the list of alternate titles.
public fun alternate_titles<CompositionShare>(
    self: &Composition<CompositionShare>,
): &vector<String> {
    &self.alternate_titles
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

/// Returns the optional lyrics data reference.
public fun lyrics<CompositionShare>(self: &Composition<CompositionShare>): &Option<WalrusData> {
    &self.lyrics
}

/// Returns the optional demo audio reference.
public fun demo<CompositionShare>(self: &Composition<CompositionShare>): &Option<WalrusData> {
    &self.demo
}

/// Returns the optional chart data reference.
public fun chart<CompositionShare>(self: &Composition<CompositionShare>): &Option<WalrusData> {
    &self.chart
}

/// Returns the optional score data reference.
public fun score<CompositionShare>(self: &Composition<CompositionShare>): &Option<WalrusData> {
    &self.score
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

/// Returns a mutable reference to the composition's UID with an extension.
public fun uid_mut_with_extension<CompositionShare, Extension: drop>(
    self: &mut Composition<CompositionShare>,
    _extension: Extension,
): &mut UID {
    extension::assert_registered<Extension>(&self.id);
    &mut self.id
}

public(package) fun uid_mut_internal<CompositionShare>(
    self: &mut Composition<CompositionShare>,
): &mut UID {
    &mut self.id
}

// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Represents a musical composition (song, instrumental work) in the MusicOS protocol.
/// Compositions are the underlying written works that recordings are based on.
/// Each composition has its own share token for ownership distribution.
///
/// Key features:
/// - Share token initialization with fixed supply (100M tokens, 6 decimals)
/// - Contributor management with role assignments (Composer, Lyricist, Songwriter)
/// - State machine: Initialized -> Published (immutable after publish)
/// - Revenue and royalty pool creation for royalty distribution
/// - Deterministic addresses via derived object pattern
module musicos::composition;

use musicos::artifact::Artifact;
use interest_bps::bps::{Self, BPS};
use musicos::composition_artifact_kind::CompositionArtifactKind;
use musicos::composition_contributor_role::CompositionContributorRole;
use musicos::credit::Credit;
use musicos::contributor::Contributor;
use musicos::data::Data;
use musicos::plugin::PluginCap;
use musicos::share;
use musicos::snapshot::Snapshot;
use revenue_pool::revenue_pool;
use royalty_pool::royalty_pool;
use std::string::String;
use sui::balance::Balance;
use sui::clock::Clock;
use sui::coin::TreasuryCap;
use sui::coin_registry::{Currency, MetadataCap};
use sui::derived_object::claim;
use sui::event::emit;
use sui::vec_map::{Self, VecMap};
use sui::coin_registry::CurrencyInitializer;

//=== Structs ===

/// A musical composition representing the underlying written work.
/// The phantom CompositionShare type parameter links to the share token.
public struct Composition<phantom CompositionShare> has key {
    /// Unique identifier for this composition.
    id: UID,
    /// Current lifecycle state.
    state: CompositionState,
    /// Capability for updating share token metadata.
    share_metadata_cap: MetadataCap<CompositionShare>,
    /// Primary title of the composition.
    title: String,
    /// Additional titles (translations, alternate names).
    alternate_titles: vector<String>,
    /// Map of contributor IDs to their roles on this composition.
    credits: VecMap<ID, Credit<CompositionContributorRole>>,
    /// Revenue split rate allocated to this composition vs recording (in basis points).
    split_bps: BPS,
    /// Optional lyrics data reference.
    lyrics: Option<Data>,
    /// Attached artifacts (sheet music, liner notes, etc.).
    artifacts: vector<Artifact<CompositionArtifactKind>>,
    /// Point-in-time content snapshots.
    snapshots: vector<Snapshot>,
}

/// Capability that authorizes modifications to a specific composition.
/// Initialized when a composition is registered and transferred to the owner.
public struct CompositionAdminCap has key, store {
    /// Unique identifier for this capability.
    id: UID,
    /// ID of the composition this capability controls.
    composition_id: ID,
}

/// Witness type sourced from the composition module.
public struct CompositionWitness() has drop;

//=== Derivation Keys ===

/// Key for deriving the admin capability's deterministic address.
public struct CompositionAdminCapKey() has copy, drop, store;

//=== Fees ===

/// Marker type for publish composition fee payments.
public struct PublishCompositionFee() has drop;

//=== Events ===

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

/// Emitted when a contributor is added to a composition.
public struct CompositionContributorAddedEvent has copy, drop {
    /// ID of the composition.
    composition_id: ID,
    /// ID of the added contributor.
    contributor_id: ID,
}

/// Emitted when the composition split is updated.
public struct CompositionSplitSetEvent has copy, drop {
    /// ID of the composition.
    composition_id: ID,
    /// New split value in basis points.
    split_value: u64,
}

//=== Enums ===

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

//=== Constants ===

/// Minimum number of roles a contributor must have.
const MIN_ROLES_PER_CONTRIBUTOR: u64 = 1;
/// Maximum number of roles a contributor can have.
const MAX_ROLES_PER_CONTRIBUTOR: u64 = 20;
// Maximum split value for a composition.
const MAX_COMPOSITION_SPLIT_VALUE: u64 = 5_000;

//=== Errors ===

/// The provided admin capability does not match this composition.
const EUnauthorized: u64 = 0;
/// Operation requires Initialized state but composition is created.
const ENotInitializedState: u64 = 1;
/// Contributor has too many roles.
const EExceedsMaxRoles: u64 = 10;
/// Contributor must have at least one role.
const EMinRolesNotMet: u64 = 11;
/// Invalid composition split value.
const EInvalidSplitValue: u64 = 13;
/// Composition must have at least one contributor to publish.
const ENoContributors: u64 = 20;
/// Composition must have at least one artifact to publish.
const ENoArtifacts: u64 = 21;
/// Composition must have at least one snapshot to publish.
const ENoSnapshots: u64 = 22;


//=== Public Functions ===

// --- Lifecycle ---

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
    share_metadata_cap: MetadataCap<CompositionShare>,
    share_treasury_cap: TreasuryCap<CompositionShare>,
    ctx: &mut TxContext,
): (
    Composition<CompositionShare>,
    CompositionAdminCap,
    Balance<CompositionShare>,
) {
    assert!(split_value <= MAX_COMPOSITION_SPLIT_VALUE, EInvalidSplitValue);

    let mut composition = Composition {
        id: object::new(ctx),
        state: CompositionState::Initialized,
        share_metadata_cap,
        title,
        alternate_titles: vector[],
        credits: vec_map::empty(),
        split_bps: bps::new(split_value),
        lyrics: option::none(),
        artifacts: vector[],
        snapshots: vector[],
    };

    let composition_admin_cap = CompositionAdminCap {
        id: claim(&mut composition.id, CompositionAdminCapKey()),
        composition_id: composition.id(),
    };

    let mut description: String = "MusicOS Composition Shares for 0x";
    description.append(composition.id().to_address().to_string());
    description.append(".");

    let composition_shares = share::intialize<CompositionShare>(
        "MusicOS Composition Share",
        description,
        share_currency,
        &composition.share_metadata_cap,
        share_treasury_cap,
    );

    emit(CompositionInitializedEvent {
        composition_id: composition.id(),
    });

    (composition, composition_admin_cap, composition_shares)
}

/// Publishes the composition, making it immutable.
/// Requires at least one contributor, artifact, and snapshot.
/// Required State: Initialized
public fun publish<CompositionShare>(
    mut self: Composition<CompositionShare>,
    cap: &CompositionAdminCap,
    clock: &Clock,
) {
    self.authorize(cap);

    match (self.state) {
        CompositionState::Initialized => {
            assert!(!self.credits.is_empty(), ENoContributors);
            assert!(!self.artifacts.is_empty(), ENoArtifacts);
            assert!(!self.snapshots.is_empty(), ENoSnapshots);

            self.state = CompositionState::Published(clock.timestamp_ms());

            emit(CompositionPublishedEvent<CompositionShare> {
                composition_id: self.id(),
            });

            transfer::share_object(self);
        },
        _ => abort ENotInitializedState,
    }
}

// --- Title ---

/// Adds an alternate title to the composition.
/// Required State: Initialized
public fun add_alternate_title<CompositionShare>(
    self: &mut Composition<CompositionShare>,
    cap: &CompositionAdminCap,
    alternate_title: String,
) {
    self.authorize(cap);

    match (self.state) {
        CompositionState::Initialized => {
            self.alternate_titles.push_back(alternate_title);
        },
        _ => abort ENotInitializedState,
    }
}

// --- People ---

/// Adds a contributor to the composition with specified roles.
/// Each contributor must have 1-20 roles.
/// Required State: Initialized
public fun add_credit<CompositionShare>(
    self: &mut Composition<CompositionShare>,
    cap: &CompositionAdminCap,
    contributor: &Contributor,
    credit: Credit<CompositionContributorRole>,
) {
    self.authorize(cap);

    match (self.state) {
        CompositionState::Initialized => {
            assert!(credit.roles().length() >= MIN_ROLES_PER_CONTRIBUTOR, EMinRolesNotMet);
            assert!(credit.roles().length() <= MAX_ROLES_PER_CONTRIBUTOR, EExceedsMaxRoles);

            self.credits.insert(contributor.id(), credit);

            emit(CompositionContributorAddedEvent {
                composition_id: self.id(),
                contributor_id: contributor.id(),
            });
        },
        _ => abort ENotInitializedState,
    }
}

// --- Financial ---

/// Sets the revenue split rate for this composition.
/// The split determines what percentage of track revenue goes to the composition
/// vs the recording. Can be updated at any time (even after publish).
public fun set_split_bps<CompositionShare>(
    self: &mut Composition<CompositionShare>,
    cap: &CompositionAdminCap,
    split_value: u64,
) {
    self.authorize(cap);

    self.split_bps = bps::new(split_value);

    emit(CompositionSplitSetEvent {
        composition_id: self.id(),
        split_value: self.split_bps.value(),
    });
}

// --- Content ---

/// Sets the lyrics data reference for the composition.
/// Required State: Initialized
public fun set_lyrics<CompositionShare>(
    self: &mut Composition<CompositionShare>,
    cap: &CompositionAdminCap,
    data: Data,
) {
    self.authorize(cap);

    match (self.state) {
        CompositionState::Initialized => {
            self.lyrics.swap_or_fill(data);
        },
        _ => abort ENotInitializedState,
    }
}

// --- Attachments ---

/// Adds an artifact to the composition.
/// Required State: Initialized
public fun add_artifact<CompositionShare>(
    self: &mut Composition<CompositionShare>,
    cap: &CompositionAdminCap,
    artifact: Artifact<CompositionArtifactKind>,
) {
    self.authorize(cap);

    match (self.state) {
        CompositionState::Initialized => {
            self.artifacts.push_back(artifact);
        },
        _ => abort ENotInitializedState,
    }
}

/// Adds a snapshot to the composition.
/// Required State: Initialized
public fun add_snapshot<CompositionShare>(
    self: &mut Composition<CompositionShare>,
    cap: &CompositionAdminCap,
    snapshot: Snapshot,
) {
    self.authorize(cap);

    match (self.state) {
        CompositionState::Initialized => {
            self.snapshots.push_back(snapshot);
        },
        _ => abort ENotInitializedState,
    }
}

// --- Pools ---

/// Creates a new revenue pool for this composition.
/// Revenue pools receive incoming payments before distribution.
public fun new_revenue_pool<CompositionShare, Currency>(self: &mut Composition<CompositionShare>) {
    let revenue_pool = revenue_pool::new<Currency>(&mut self.id);
    transfer::public_share_object(revenue_pool);
}

/// Creates a new royalty pool for this composition.
/// Reward pools distribute revenue to share token holders.
public fun new_royalty_pool<CompositionShare, Currency>(self: &mut Composition<CompositionShare>) {
    let royalty_pool = royalty_pool::new<CompositionShare, Currency>(&mut self.id);
    transfer::public_share_object(royalty_pool);
}

//=== Public View Functions ===

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
public fun alternate_titles<CompositionShare>(self: &Composition<CompositionShare>): &vector<String> {
    &self.alternate_titles
}

/// Returns the contributor-to-credit mapping.
public fun credits<CompositionShare>(self: &Composition<CompositionShare>): &VecMap<ID, Credit<CompositionContributorRole>> {
    &self.credits
}

/// Returns the revenue split rate in basis points.
public fun split_bps<CompositionShare>(self: &Composition<CompositionShare>): BPS {
    self.split_bps
}

/// Returns the optional lyrics data reference.
public fun lyrics<CompositionShare>(self: &Composition<CompositionShare>): &Option<Data> {
    &self.lyrics
}

/// Returns the list of attached artifacts.
public fun artifacts<CompositionShare>(self: &Composition<CompositionShare>): &vector<Artifact<CompositionArtifactKind>> {
    &self.artifacts
}

/// Returns the list of snapshots.
public fun snapshots<CompositionShare>(self: &Composition<CompositionShare>): &vector<Snapshot> {
    &self.snapshots
}

//=== Package Functions ===

/// Verifies that the admin capability matches this composition.
/// Aborts with EUnauthorized if the capability doesn't match.
public(package) fun authorize<CompositionShare>(
    self: &Composition<CompositionShare>,
    cap: &CompositionAdminCap,
) {
    assert!(self.id() == cap.composition_id, EUnauthorized);
}

//=== UID Functions ===

public fun uid_with_plugin<CompositionShare, PluginWitness: drop>(self: &Composition<CompositionShare>, cap: &CompositionAdminCap, _plugin_cap: PluginCap<CompositionWitness, PluginWitness>): &UID {
    self.authorize(cap);
    &self.id
}

public fun uid_mut_with_plugin<CompositionShare, PluginWitness: drop>(self: &mut Composition<CompositionShare>, cap: &CompositionAdminCap, _plugin_cap: PluginCap<CompositionWitness, PluginWitness>): &mut UID {
    self.authorize(cap);
    &mut self.id
}

public(package) fun uid_mut_internal<CompositionShare>(self: &mut Composition<CompositionShare>): &mut UID {
    &mut self.id
}
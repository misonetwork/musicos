// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Represents a musical composition (song, instrumental work) in the MusicOS protocol.
/// Compositions are the underlying written works that recordings are based on.
/// Each composition has its own share token for ownership distribution.
///
/// Key features:
/// - Share token initialization with fixed supply (100M tokens, 6 decimals)
/// - Contributor management with role assignments (Composer, Lyricist, Songwriter)
/// - State machine: Created -> Published (immutable after publish)
/// - Revenue and reward pool creation for royalty distribution
/// - Deterministic addresses via derived object pattern
module musicos::composition;

use musicos::artifact::Artifact;
use musicos::bps::BPS;
use musicos::composition_artifact_kind::CompositionArtifactKind;
use musicos::composition_contributor_role::CompositionContributorRole;
use musicos::contributor::Contributor;
use musicos::data::Data;
use musicos::share;
use musicos::snapshot::Snapshot;
use revenue_pool::revenue_pool;
use reward_pool::reward_pool;
use std::string::String;
use sui::balance::Balance;
use sui::clock::Clock;
use sui::coin::TreasuryCap;
use sui::coin_registry::{Currency, MetadataCap};
use sui::derived_object::claim;
use sui::event::emit;
use sui::vec_map::{Self, VecMap};

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
    contributors: VecMap<ID, vector<CompositionContributorRole>>,
    /// Revenue split rate (in BPS) allocated to this composition vs recording.
    split: BPS,
    /// Optional lyrics data reference.
    lyrics: Option<Data>,
    /// Attached artifacts (sheet music, liner notes, etc.).
    artifacts: vector<Artifact<CompositionArtifactKind>>,
    /// Point-in-time content snapshots.
    snapshots: vector<Snapshot>,
}

/// Capability that authorizes modifications to a specific composition.
/// Created when a composition is registered and transferred to the owner.
public struct CompositionAdminCap has key, store {
    /// Unique identifier for this capability.
    id: UID,
    /// ID of the composition this capability controls.
    composition_id: ID,
}

//=== Derivation Keys ===

/// Key for deriving the admin capability's deterministic address.
public struct CompositionAdminCapKey() has copy, drop, store;

//=== Fees ===

/// Marker type for publish composition fee payments.
public struct PublishCompositionFee() has drop;

//=== Events ===

/// Emitted when a new composition is created.
public struct CompositionCreatedEvent has copy, drop {
    /// ID of the created composition.
    composition_id: ID,
}

/// Emitted when a composition is published.
public struct CompositionPublishedEvent has copy, drop {
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

/// Emitted when a contributor is removed from a composition.
public struct CompositionContributorRemovedEvent has copy, drop {
    /// ID of the composition.
    composition_id: ID,
    /// ID of the removed contributor.
    contributor_id: ID,
}

/// Emitted when the composition split is updated.
public struct CompositionSplitSetEvent has copy, drop {
    /// ID of the composition.
    composition_id: ID,
    /// New split value in basis points.
    split: BPS,
}

//=== Enums ===

/// Lifecycle state of a composition.
public enum CompositionState has copy, drop, store {
    /// Composition is initialized but not yet created.
    Initialized,
    /// Composition has been created but not yet published.
    Created,
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

//=== Errors ===

/// The provided admin capability does not match this composition.
const EUnauthorized: u64 = 0;
/// Operation requires Created state but composition is published.
const ENotCreatedState: u64 = 1;
/// Attempted to add a role that the contributor already has.
const EContributorRoleAlreadyExists: u64 = 2;
/// Role index is out of bounds for this contributor.
const EContributorRoleIndexOutOfBounds: u64 = 3;
/// Contributor must have at least one role.
const EMinRolesNotMet: u64 = 4;
/// Contributor has too many roles.
const EExceedsMaxRoles: u64 = 5;
/// Composition must have at least one contributor to publish.
const ENoContributors: u64 = 7;

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
    split: BPS,
    share_currency: &mut Currency<CompositionShare>,
    share_metadata_cap: MetadataCap<CompositionShare>,
    share_treasury_cap: TreasuryCap<CompositionShare>,
    ctx: &mut TxContext,
): (
    Composition<CompositionShare>,
    CompositionAdminCap,
    Balance<CompositionShare>,
) {
    let mut composition = Composition {
        id: object::new(ctx),
        state: CompositionState::Initialized,
        share_metadata_cap,
        title,
        alternate_titles: vector[],
        contributors: vec_map::empty(),
        split,
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

    emit(CompositionCreatedEvent {
        composition_id: composition.id(),
    });

    (composition, composition_admin_cap, composition_shares)
}

/// Converts the composition into a shared object.
/// Consumes the promise returned by `new()`.
/// Required State: Created
public fun share<CompositionShare>(
    mut self: Composition<CompositionShare>,
) {
    match (self.state) {
        CompositionState::Initialized => {
            self.state = CompositionState::Created;
            transfer::share_object(self);
        },
        _ => abort ENotCreatedState,
    }
}


/// Publishes the composition, making it immutable.
/// Requires at least one contributor to be assigned.
/// Required State: Created
public fun publish<CompositionShare>(
    self: &mut Composition<CompositionShare>,
    cap: &CompositionAdminCap,
    clock: &Clock,
) {
    self.authorize(cap);

    match (self.state) {
        CompositionState::Created => {
            // Assert the composition has at least one contributor.
            assert!(!self.contributors.is_empty(), ENoContributors);

            self.state = CompositionState::Published(clock.timestamp_ms());

            emit(CompositionPublishedEvent {
                composition_id: self.id(),
            });
        },
        _ => abort ENotCreatedState,
    }
}

// --- Title ---

/// Sets the primary title of the composition.
/// Required State: Created
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

/// Adds an alternate title to the composition.
/// Required State: Created
public fun add_alternate_title<CompositionShare>(
    self: &mut Composition<CompositionShare>,
    cap: &CompositionAdminCap,
    alternate_title: String,
) {
    self.authorize(cap);

    match (self.state) {
        CompositionState::Created => {
            self.alternate_titles.push_back(alternate_title);
        },
        _ => abort ENotCreatedState,
    }
}

/// Removes an alternate title by index.
/// Required State: Created
public fun remove_alternate_title<CompositionShare>(
    self: &mut Composition<CompositionShare>,
    cap: &CompositionAdminCap,
    alternate_title_idx: u64,
) {
    self.authorize(cap);

    match (self.state) {
        CompositionState::Created => {
            self.alternate_titles.swap_remove(alternate_title_idx);
        },
        _ => abort ENotCreatedState,
    }
}

// --- People ---

/// Adds a contributor to the composition with specified roles.
/// Each contributor must have 1-20 roles.
/// Required State: Created
public fun add_contributor<CompositionShare>(
    self: &mut Composition<CompositionShare>,
    cap: &CompositionAdminCap,
    contributor: &Contributor,
    roles: vector<CompositionContributorRole>,
) {
    self.authorize(cap);

    match (self.state) {
        CompositionState::Created => {
            assert!(roles.length() >= MIN_ROLES_PER_CONTRIBUTOR, EMinRolesNotMet);
            assert!(roles.length() <= MAX_ROLES_PER_CONTRIBUTOR, EExceedsMaxRoles);

            self.contributors.insert(contributor.id(), roles);

            emit(CompositionContributorAddedEvent {
                composition_id: self.id(),
                contributor_id: contributor.id(),
            });
        },
        _ => abort ENotCreatedState,
    }
}

/// Removes a contributor from the composition.
/// Required State: Created
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

/// Adds a role to an existing contributor.
/// Required State: Created
public fun add_role_to_contributor<CompositionShare>(
    self: &mut Composition<CompositionShare>,
    cap: &CompositionAdminCap,
    contributor_id: ID,
    role: CompositionContributorRole,
) {
    self.authorize(cap);

    match (self.state) {
        CompositionState::Created => {
            let roles = self.contributors.get_mut(&contributor_id);

            assert!(!roles.contains(&role), EContributorRoleAlreadyExists);
            assert!(roles.length() < MAX_ROLES_PER_CONTRIBUTOR, EExceedsMaxRoles);

            roles.push_back(role);
        },
        _ => abort ENotCreatedState,
    }
}

/// Removes a role from a contributor by role index.
/// Contributor must retain at least one role.
/// Required State: Created
public fun remove_role_from_contributor<CompositionShare>(
    self: &mut Composition<CompositionShare>,
    cap: &CompositionAdminCap,
    contributor_id: ID,
    role_idx: u64,
) {
    self.authorize(cap);

    match (self.state) {
        CompositionState::Created => {
            let roles = self.contributors.get_mut(&contributor_id);
            assert!(role_idx < roles.length(), EContributorRoleIndexOutOfBounds);
            assert!(roles.length() > MIN_ROLES_PER_CONTRIBUTOR, EMinRolesNotMet);
            roles.swap_remove(role_idx);
        },
        _ => abort ENotCreatedState,
    }
}

// --- Financial ---

/// Sets the revenue split rate for this composition.
/// The split determines what percentage of track revenue goes to the composition
/// vs the recording. Can be updated at any time (even after publish).
public fun set_split<CompositionShare>(
    self: &mut Composition<CompositionShare>,
    cap: &CompositionAdminCap,
    split: BPS,
) {
    self.authorize(cap);

    self.split = split;

    emit(CompositionSplitSetEvent {
        composition_id: self.id(),
        split: split,
    });
}

// --- Content ---

/// Sets the lyrics data reference for the composition.
/// Required State: Created
public fun set_lyrics<CompositionShare>(
    self: &mut Composition<CompositionShare>,
    cap: &CompositionAdminCap,
    data: Data,
) {
    self.authorize(cap);

    match (self.state) {
        CompositionState::Created => {
            self.lyrics.swap_or_fill(data);
        },
        _ => abort ENotCreatedState,
    }
}

// --- Attachments ---

/// Adds an artifact to the composition.
/// Required State: Created
public fun add_artifact<CompositionShare>(
    self: &mut Composition<CompositionShare>,
    cap: &CompositionAdminCap,
    artifact: Artifact<CompositionArtifactKind>,
) {
    self.authorize(cap);

    match (self.state) {
        CompositionState::Created => {
            self.artifacts.push_back(artifact);
        },
        _ => abort ENotCreatedState,
    }
}

/// Removes an artifact by index and returns it.
/// Required State: Created
public fun remove_artifact<CompositionShare>(
    self: &mut Composition<CompositionShare>,
    cap: &CompositionAdminCap,
    artifact_idx: u64,
): Artifact<CompositionArtifactKind> {
    self.authorize(cap);

    match (self.state) {
        CompositionState::Created => {
            self.artifacts.swap_remove(artifact_idx)
        },
        _ => abort ENotCreatedState,
    }
}

/// Adds a snapshot to the composition.
/// Required State: Created
public fun add_snapshot<CompositionShare>(
    self: &mut Composition<CompositionShare>,
    cap: &CompositionAdminCap,
    snapshot: Snapshot,
) {
    self.authorize(cap);

    match (self.state) {
        CompositionState::Created => {
            self.snapshots.push_back(snapshot);
        },
        _ => abort ENotCreatedState,
    }
}

/// Removes a snapshot by index and returns it.
/// Required State: Created
public fun remove_snapshot<CompositionShare>(
    self: &mut Composition<CompositionShare>,
    cap: &CompositionAdminCap,
    snapshot_idx: u64,
): Snapshot {
    self.authorize(cap);

    match (self.state) {
        CompositionState::Created => {
            self.snapshots.swap_remove(snapshot_idx)
        },
        _ => abort ENotCreatedState,
    }
}

// --- Pools ---

/// Creates a new revenue pool for this composition.
/// Revenue pools receive incoming payments before distribution.
public fun new_revenue_pool<CompositionShare, Currency>(self: &mut Composition<CompositionShare>) {
    let revenue_pool = revenue_pool::new<Currency>(&mut self.id);
    transfer::public_share_object(revenue_pool);
}

/// Creates a new reward pool for this composition.
/// Reward pools distribute revenue to share token holders.
public fun new_reward_pool<CompositionShare, Currency>(self: &mut Composition<CompositionShare>) {
    let reward_pool = reward_pool::new<CompositionShare, Currency>(&mut self.id);
    transfer::public_share_object(reward_pool);
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

/// Returns the contributor-to-roles mapping.
public fun contributors<CompositionShare>(self: &Composition<CompositionShare>): &VecMap<ID, vector<CompositionContributorRole>> {
    &self.contributors
}

/// Returns the revenue split rate in basis points.
public fun split<CompositionShare>(self: &Composition<CompositionShare>): BPS {
    self.split
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

// TODO: Check whether contain() distinguishes enum variants.
/// Checks if a contributor has a specific role on this composition.
public fun contributor_has_role<CompositionShare>(
    self: &Composition<CompositionShare>,
    contributor_id: ID,
    role: CompositionContributorRole,
): bool {
    self.contributors.get(&contributor_id).contains(&role)
}

//=== Package Functions ===

/// Returns a mutable reference to the composition's UID.
/// Package-internal use only.
public(package) fun uid_mut<CompositionShare>(self: &mut Composition<CompositionShare>): &mut UID {
    &mut self.id
}

/// Verifies that the admin capability matches this composition.
/// Aborts with EUnauthorized if the capability doesn't match.
public(package) fun authorize<CompositionShare>(
    self: &Composition<CompositionShare>,
    cap: &CompositionAdminCap,
) {
    assert!(self.id() == cap.composition_id, EUnauthorized);
}

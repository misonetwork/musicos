// Copyright (c) Unconfirmed Labs, LLC
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
use musicos::audio::Audio;
use musicos::composition_party_role::CompositionPartyRole;
use ori::walrus_data::WalrusData;
use partyos::credit::Credit;
use partyos::party::Party;
use share::share;
use std::string::String;
use std::type_name::TypeName;
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
    demo: Option<Audio>,
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
    alternate_titles: vector<String>,
    split_bps_value: u16,
    has_lyrics: bool,
    has_chart: bool,
    has_score: bool,
    has_demo: bool,
    demo_duration_ms: Option<u64>,
    demo_blob_id: Option<u256>,
    credits_count: u64,
    published_at_ms: u64,
}

/// Emitted when a party is added to a composition.
public struct CompositionPartyAddedEvent has copy, drop {
    composition_id: ID,
    party_id: ID,
    credit_display_name: String,
    credit_roles_count: u64,
}

/// Emitted for each role assigned to a credited party on a composition.
public struct CompositionCreditRoleEvent has copy, drop {
    composition_id: ID,
    party_id: ID,
    role_name: String,
}

/// Emitted when the composition split is updated.
public struct CompositionSplitSetEvent has copy, drop {
    /// ID of the composition.
    composition_id: ID,
    /// New split value in basis points.
    split_value: u64,
}

/// Emitted when an alternate title is added to a composition.
public struct CompositionAlternateTitleAddedEvent has copy, drop {
    composition_id: ID,
    alternate_title: String,
}

/// Emitted when lyrics are set on a composition.
public struct CompositionLyricsSetEvent has copy, drop {
    composition_id: ID,
    is_walrus_blob: bool,
    walrus_id: u256,
}

/// Emitted when the demo audio is set on a composition.
public struct CompositionDemoSetEvent has copy, drop {
    composition_id: ID,
    blob_id: u256,
    channels: u8,
    bit_depth: u8,
    sample_rate_hz: u32,
    samples: u64,
    duration_ms: u64,
}

/// Emitted when the chart data is set on a composition.
public struct CompositionChartSetEvent has copy, drop {
    composition_id: ID,
    is_walrus_blob: bool,
    walrus_id: u256,
}

/// Emitted when the score data is set on a composition.
public struct CompositionScoreSetEvent has copy, drop {
    composition_id: ID,
    is_walrus_blob: bool,
    walrus_id: u256,
}

// === Constants ===

/// Minimum number of roles a party must have.
const MIN_ROLES_PER_PARTY: u64 = 1;
/// Maximum number of roles a party can have.
const MAX_ROLES_PER_PARTY: u64 = 5;
/// Maximum number of alternate titles allowed on a composition.
const MAX_ALTERNATE_TITLES: u64 = 5;
/// Maximum number of credits allowed on a composition.
const MAX_CREDITS: u64 = 50;
/// Maximum length of a title in bytes.
const MAX_TITLE_LENGTH: u64 = 300;
/// Maximum length of an alternate title in bytes.
const MAX_ALTERNATE_TITLE_LENGTH: u64 = 300;

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
/// Composition has too many alternate titles.
const EMaxAlternateTitlesExceeded: u64 = 31;
/// Composition has too many credits.
const EMaxCreditsExceeded: u64 = 32;
/// Title exceeds maximum length.
const EMaxTitleLengthExceeded: u64 = 33;
/// Alternate title exceeds maximum length.
const EMaxAlternateTitleLengthExceeded: u64 = 34;
/// String must not be empty.
const EEmptyString: u64 = 35;

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
    assert!(!title.is_empty(), EEmptyString);
    assert!(title.length() <= MAX_TITLE_LENGTH, EMaxTitleLengthExceeded);

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

            let published_at_ms = clock.timestamp_ms();
            self.state = CompositionState::Published(published_at_ms);

            let (demo_duration_ms, demo_blob_id) = if (self.demo.is_some()) {
                let demo = self.demo.borrow();
                (option::some(demo.duration_ms()), option::some(demo.data().blob_id()))
            } else {
                (option::none(), option::none())
            };

            emit(CompositionPublishedEvent<CompositionShare> {
                composition_id: self.id(),
                title: *self.title(),
                alternate_titles: self.alternate_titles,
                split_bps_value: (self.split_bps.value() as u16),
                has_lyrics: self.lyrics.is_some(),
                has_chart: self.chart.is_some(),
                has_score: self.score.is_some(),
                has_demo: self.demo.is_some(),
                demo_duration_ms,
                demo_blob_id,
                credits_count: self.credits.length(),
                published_at_ms,
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
            assert!(!alternate_title.is_empty(), EEmptyString);
            assert!(
                alternate_title.length() <= MAX_ALTERNATE_TITLE_LENGTH,
                EMaxAlternateTitleLengthExceeded,
            );
            assert!(
                self.alternate_titles.length() < MAX_ALTERNATE_TITLES,
                EMaxAlternateTitlesExceeded,
            );
            self.alternate_titles.push_back(alternate_title);

            emit(CompositionAlternateTitleAddedEvent {
                composition_id: self.id(),
                alternate_title,
            });
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

            let credit_display_name = *credit.display_name();
            let composition_id = self.id();
            let roles = credit.roles();

            emit(CompositionPartyAddedEvent {
                composition_id,
                party_id,
                credit_display_name,
                credit_roles_count: roles.length(),
            });

            let mut i = 0;
            while (i < roles.length()) {
                emit(CompositionCreditRoleEvent {
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
            let is_walrus_blob = lyrics.is_blob();
            let walrus_id = if (is_walrus_blob) { lyrics.blob_id() } else { lyrics.quilt_id() };
            self.lyrics = option::some(lyrics);

            emit(CompositionLyricsSetEvent {
                composition_id: self.id(),
                is_walrus_blob,
                walrus_id,
            });
        },
        _ => abort ENotInitializedState,
    }
}

/// Sets the demo audio reference for the composition.
/// Required State: Initialized
public fun set_demo<CompositionShare>(
    self: &mut Composition<CompositionShare>,
    _: &CompositionAdminCap<CompositionShare>,
    audio: Audio,
) {
    match (self.state) {
        CompositionState::Initialized => {
            let blob_id = audio.data().blob_id();
            let channels = audio.channels();
            let bit_depth = audio.bit_depth();
            let sample_rate_hz = audio.sample_rate_hz();
            let samples = audio.samples();
            let duration_ms = audio.duration_ms();
            self.demo = option::some(audio);

            emit(CompositionDemoSetEvent {
                composition_id: self.id(),
                blob_id,
                channels,
                bit_depth,
                sample_rate_hz,
                samples,
                duration_ms,
            });
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
            let is_walrus_blob = chart.is_blob();
            let walrus_id = if (is_walrus_blob) { chart.blob_id() } else { chart.quilt_id() };
            self.chart = option::some(chart);

            emit(CompositionChartSetEvent {
                composition_id: self.id(),
                is_walrus_blob,
                walrus_id,
            });
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
            let is_walrus_blob = score.is_blob();
            let walrus_id = if (is_walrus_blob) { score.blob_id() } else { score.quilt_id() };
            self.score = option::some(score);

            emit(CompositionScoreSetEvent {
                composition_id: self.id(),
                is_walrus_blob,
                walrus_id,
            });
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
public fun demo<CompositionShare>(self: &Composition<CompositionShare>): &Option<Audio> {
    &self.demo
}

/// Returns the ingester type of the composition's demo audio file.
public fun demo_ingester_type<CompositionShare>(
    self: &Composition<CompositionShare>,
): Option<TypeName> {
    self.demo.map_ref!(|audio| *audio.ingester_type())
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

public(package) fun uid_mut_internal<CompositionShare>(
    self: &mut Composition<CompositionShare>,
): &mut UID {
    &mut self.id
}

// === Test Only ===

#[test_only]
public fun new_for_testing<CompositionShare>(
    title: String,
    split_value: u64,
    ctx: &mut TxContext,
): (Composition<CompositionShare>, CompositionAdminCap<CompositionShare>) {
    assert!(!title.is_empty(), EEmptyString);
    assert!(title.length() <= MAX_TITLE_LENGTH, EMaxTitleLengthExceeded);

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

    (composition, composition_admin_cap)
}

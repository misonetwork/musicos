// TODO: Remove Coda branding from composition share coin.
module musicos::composition;

use musicos::artifact::Artifact;
use musicos::composition_artifact_variant::CompositionArtifactVariant;
use musicos::composition_contributor_role::CompositionContributorRole;
use musicos::contributor_identifier::ContributorIdentifier;
use musicos::revenue_pool::{Self, RevenuePool, RevenuePoolRegistry};
use std::string::String;
use std::type_name::TypeName;
use sui::clock::Clock;
use sui::coin::{TreasuryCap, Coin};
use sui::coin_registry::{Currency, MetadataCap};
use sui::derived_object::{derive_address};
use sui::event::emit;
use sui::balance::Balance;
use sui::vec_map::{Self, VecMap};
use sui::vec_set::{Self, VecSet};

//=== Structs ===

public struct Composition has key, store {
    id: UID,
    source: CompositionSource,
    state: CompositionState,
    // Title of the composition.
    title: String,
    // Optional subtitle of the composition.
    subtitle: Option<String>,
    // Optional Walrus quilt ID that acts as a folder for the composition's Walrus-based assets.
    quilt_id: Option<String>,
    // Map of addresses to composition contributor roles.
    contributors: VecMap<ContributorIdentifier, VecSet<CompositionContributorRole>>,
    // Optional map of language codes to Walrus Blob IDs of LRC files.
    lyrics: Option<String>,
    // List of composition artifacts.
    artifacts: vector<Artifact<CompositionArtifactVariant>>,
}

public enum CompositionSource has copy, drop, store {
    Original,
    Adaptation(ID),
}

public enum CompositionState has copy, drop, store {
    Created,
    Published(u64),
}

public struct CompositionAdminCap has key, store {
    id: UID,
    composition_id: ID,
}

//=== Events ===

public struct CompositionCreatedEvent has copy, drop, store {
    composition_id: ID,
}

//=== Constants ===

const MAX_ARTIFACTS: u64 = 20;
const MAX_CONTRIBUTORS: u64 = 100;
const WORK_SHARE_DECIMALS: u8 = 6;
const WORK_SHARE_SUPPLY: u64 = 100_000_000;

//=== Errors ===

const EInvalidCompositionAdminCap: u64 = 0;
const EMaxArtifactsExceeded: u64 = 1;
const EMaxContributorsExceeded: u64 = 2;
const EUnauthorized: u64 = 0;
const EWorkNotRegistered: u64 = 1;
const ENotZeroTotalSupply: u64 = 2;
const EInvalidDecimals: u64 = 3;
const EInvalidSymbol: u64 = 4;

//=== Public Functions ===

#[allow(lint(share_owned))]
public fun initialize_revenue_pool<Currency>(self: &mut Composition) {
    let revenue_pool = revenue_pool::new<Currency>(&mut self.id);
    transfer::public_share_object(revenue_pool);
}

public fun new<ShareCurrency>(
    title: String,
    source: CompositionSource,
    currency: &mut Currency<ShareCurrency>,
    metadata_cap: MetadataCap<ShareCurrency>,
    mut treasury_cap: TreasuryCap<ShareCurrency>,
    ctx: &mut TxContext,
): (Composition, CompositionAdminCap, Balance<ShareCurrency>) {
    assert!(currency.total_supply().borrow() == 0, ENotZeroTotalSupply);
    assert!(currency.decimals() == WORK_SHARE_DECIMALS, EInvalidDecimals);
    assert!(currency.symbol() == b"COMPOSITION_SHARE".to_string(), EInvalidSymbol);

    currency.delete_metadata_cap(metadata_cap);

    let composition = Composition {
        id: object::new(ctx),
        source,
        state: CompositionState::Created,
        title,
        subtitle: option::none(),
        quilt_id: option::none(),
        contributors: vec_map::empty(),
        lyrics: option::none(),
        artifacts: vector[],
    };

    let composition_id = object::id(&composition);

    let composition_admin_cap = CompositionAdminCap {
        id: object::new(ctx),
        composition_id,
    };

    emit(CompositionCreatedEvent {
        composition_id,
    });

    let balance = treasury_cap.mint_balance(WORK_SHARE_SUPPLY);
    currency.make_supply_fixed(treasury_cap);

    (composition, composition_admin_cap, balance)
}

public fun destroy(self: Composition, cap: CompositionAdminCap) {
    let Composition { id, .. } = self;
    id.delete();
    let CompositionAdminCap { id, .. } = cap;
    id.delete();
}

// Publish a composition. Calling this function requires passing the Composition
// object by value. This guarantees that a published composition is a shared object.
#[allow(lint(share_owned))]
public fun publish(mut self: Composition, cap: &CompositionAdminCap, clock: &Clock) {
    self.authorize(cap);
    self.state = CompositionState::Published(clock.timestamp_ms());
    transfer::public_share_object(self);
}

public fun set_subtitle(self: &mut Composition, cap: &CompositionAdminCap, subtitle: String) {
    self.authorize(cap);
    self.subtitle.fill(subtitle)
}

public fun set_quilt_id(self: &mut Composition, cap: &CompositionAdminCap, quilt_id: String) {
    self.authorize(cap);
    self.quilt_id = self.quilt_id.swap_or_fill(quilt_id);
}

public fun add_contributor(
    self: &mut Composition,
    cap: &CompositionAdminCap,
    contributor_identifier: ContributorIdentifier,
) {
    self.authorize(cap);
    assert!(self.contributors.length() < MAX_CONTRIBUTORS, EMaxContributorsExceeded);
    self.contributors.insert(contributor_identifier, vec_set::empty());
}

public fun remove_contributor(
    self: &mut Composition,
    cap: &CompositionAdminCap,
    contributor_identifier: ContributorIdentifier,
) {
    self.authorize(cap);
    self.contributors.remove(&contributor_identifier);
}

public fun add_contributor_role(
    self: &mut Composition,
    cap: &CompositionAdminCap,
    contributor_identifier: ContributorIdentifier,
    role: CompositionContributorRole,
) {
    self.authorize(cap);
    self.contributors.get_mut(&contributor_identifier).insert(role);
}

public fun remove_contributor_role(
    self: &mut Composition,
    cap: &CompositionAdminCap,
    contributor_identifier: ContributorIdentifier,
    role: CompositionContributorRole,
) {
    self.authorize(cap);
    self.contributors.get_mut(&contributor_identifier).remove(&role);
}

public fun add_artifact(
    self: &mut Composition,
    cap: &CompositionAdminCap,
    artifact: Artifact<CompositionArtifactVariant>,
) {
    self.authorize(cap);
    assert!(self.artifacts.length() < MAX_ARTIFACTS, EMaxArtifactsExceeded);
    self.artifacts.push_back(artifact);
}

public fun remove_artifact(
    self: &mut Composition,
    cap: &CompositionAdminCap,
    artifact_idx: u64,
): Artifact<CompositionArtifactVariant> {
    self.authorize(cap);
    self.artifacts.remove(artifact_idx)
}

// Derive the address of the Composition's RevenuePool and transfer
// funds to the RevenuePool's balance accumulator.
public fun deposit_revenue<Currency>(self: &Composition, balance: Balance<Currency>) {
    // Assert the RevenuePool for the provided Composition/Currency pair exists.
    revenue_pool::assert_exists<Currency>(&self.id);
    // Transfer the funds to the RevenuePool's balance accumulator.
    balance.send_funds(revenue_pool::derive_address<Currency>(self.id()));
}

//=== Public View Functions ===

public fun id(self: &Composition): ID {
    self.id.to_inner()
}

public fun new_original_source(): CompositionSource {
    CompositionSource::Original
}

public fun new_adaptation_source(composition: &Composition): CompositionSource {
    CompositionSource::Adaptation(object::id(composition))
}

public fun authorize(self: &Composition, cap: &CompositionAdminCap) {
    assert!(object::id(self) == cap.composition_id, EInvalidCompositionAdminCap);
}

//=== Package Functions ===

public(package) fun uid(self: &Composition): &UID {
    &self.id
}

public(package) fun uid_mut(self: &mut Composition): &mut UID {
    &mut self.id
}

//=== Private Functions ===

fun build_work_share_icon_url<Work: key>(work: &Work): String {
    let mut name = b"https://img.coda.network/workshare.webp".to_string();
    name.append(object::id(work).to_address().to_string());
    name
}

fun build_work_share_name<Work: key>(work: &Work): String {
    let mut name = b"CODASHARE-".to_string();
    name.append(object::id(work).to_address().to_string());
    name
}

fun build_work_share_description<Work: key>(work: &Work): String {
    let mut description = b"Coda shares for".to_string();
    description.append(" ");
    description.append(object::id(work).to_address().to_string());
    description.append(" ");
    description
}
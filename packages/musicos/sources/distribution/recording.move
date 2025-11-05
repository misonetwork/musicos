module musicos::recording;

use musicos::artifact::Artifact;
use musicos::bps::BPS;
use musicos::composition::Composition;
use musicos::constants::{share_currency_decimals, share_currency_supply};
use musicos::contributor_identifier::ContributorIdentifier;
use musicos::genre::Genre;
use musicos::mix::Mix;
use musicos::recording_artifact_variant::RecordingArtifactVariant;
use musicos::recording_contributor_role::RecordingContributorRole;
use musicos::recording_decryption_license::{Self, RecordingDecryptionLicense};
use musicos::snapshot::Snapshot;
use std::string::String;
use sui::balance::Balance;
use sui::coin::TreasuryCap;
use sui::coin_registry::{Currency, MetadataCap};
use sui::derived_object::{claim, exists};
use sui::event::emit;
use sui::vec_map::{Self, VecMap};
use sui::vec_set::{Self, VecSet};

//=== Structs ===

public struct Recording<phantom RecordingShare> has key, store {
    id: UID,
    state: RecordingState,
    composition_id: ID,
    composition_commission_rate: BPS,
    genre: String,
    contributors: VecMap<ContributorIdentifier, VecSet<RecordingContributorRole>>,
    primary_mix: Mix,
    alternate_mixes: vector<Mix>,
    artifacts: vector<Artifact<RecordingArtifactVariant>>,
    snapshots: vector<Snapshot>,
    metadata_cap: MetadataCap<RecordingShare>,
}

// (derivation_idx)
public struct RecordingDerivationKey(u32) has copy, drop, store;

public struct RecordingAdminCap has key, store {
    id: UID,
    recording_id: ID,
}

//=== Enums ===

public enum RecordingState has copy, drop, store {
    Created,
    Published(u64),
}

//=== Constants ===

const MAX_ALTERNATE_MIXES: u64 = 5;
const MAX_ARTIFACTS: u64 = 30;
const MAX_CONTRIBUTORS: u64 = 200;
const MAX_ROLES_PER_CONTRIBUTOR: u64 = 10;
const MAX_SNAPSHOTS: u64 = 50;

//=== Errors ===

const EInvalidRecordingAdminCap: u64 = 0;
const ENotSequentialDerivationIndex: u64 = 1;
const EMaxMixesExceeded: u64 = 2;
const EMaxArtifactsExceeded: u64 = 3;
const EMaxSnapshotsExceeded: u64 = 4;
const EInvalidDecimals: u64 = 5;
const EInvalidSymbol: u64 = 6;
const EExceedsMaxSupply: u64 = 7;

//=== Events ===

public struct RecordingCreatedEvent has copy, drop {
    composition_id: ID,
    recording_id: ID,
}

//=== Public Functions ===

public fun new<CompositionShare, RecordingShare>(
    composition: &mut Composition<CompositionShare>,
    mix: Mix,
    derivation_idx: u32,
    genre: &Genre,
    currency: &mut Currency<RecordingShare>,
    metadata_cap: MetadataCap<RecordingShare>,
    mut treasury_cap: TreasuryCap<RecordingShare>,
    ctx: &mut TxContext,
): (Recording<RecordingShare>, RecordingAdminCap, Balance<RecordingShare>) {
    assert!(currency.decimals() == share_currency_decimals!(), EInvalidDecimals);
    assert!(currency.symbol() == b"RECORDING_SHARE".to_string(), EInvalidSymbol);

    // Mint the composition share balance.
    let balance = treasury_cap.mint_balance(share_currency_supply!());
    currency.make_supply_fixed(treasury_cap);
    assert!(currency.total_supply().borrow() == share_currency_supply!(), EExceedsMaxSupply);

    // If the derivation index is not 0, assert the UID associated with the previous
    // derivation index has been claimed and exists. This ensures UIDs generated for
    // Recordings are sequential in nature.
    if (derivation_idx > 0) {
        assert!(
            exists(composition.uid(), RecordingDerivationKey(derivation_idx - 1)),
            ENotSequentialDerivationIndex,
        );
    };

    let composition_id = composition.id();

    let recording = Recording<RecordingShare> {
        id: claim(composition.uid_mut(), RecordingDerivationKey(derivation_idx)),
        state: RecordingState::Created,
        composition_id,
        composition_commission_rate: composition.commission_rate(),
        genre: genre.name(),
        contributors: vec_map::empty(),
        primary_mix: mix,
        alternate_mixes: vector[],
        artifacts: vector[],
        snapshots: vector[],
        metadata_cap,
    };

    let recording_admin_cap = RecordingAdminCap {
        id: object::new(ctx),
        recording_id: recording.id.to_inner(),
    };

    emit(RecordingCreatedEvent {
        composition_id,
        recording_id: recording.id.to_inner(),
    });

    (recording, recording_admin_cap, balance)
}

public fun destroy<RecordingShare>(
    self: Recording<RecordingShare>,
    cap: RecordingAdminCap,
): MetadataCap<RecordingShare> {
    let Recording { id, metadata_cap, .. } = self;
    id.delete();
    let RecordingAdminCap { id, .. } = cap;
    id.delete();
    metadata_cap
}

public fun add_alternate_mix<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap,
    mix: Mix,
) {
    self.authorize(cap);
    assert!(self.alternate_mixes.length() < MAX_ALTERNATE_MIXES, EMaxMixesExceeded);
    self.alternate_mixes.push_back(mix);
}

public fun remove_alternate_mix<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap,
    mix_idx: u64,
): Mix {
    self.authorize(cap);
    self.alternate_mixes.remove(mix_idx)
}

public fun add_contributor<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap,
    contributor_identifier: ContributorIdentifier,
) {
    self.authorize(cap);
    self.contributors.insert(contributor_identifier, vec_set::empty());
}

public fun remove_contributor<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap,
    contributor_identifier: ContributorIdentifier,
): (ContributorIdentifier, VecSet<RecordingContributorRole>) {
    self.authorize(cap);
    self.contributors.remove(&contributor_identifier)
}

public fun add_contributor_role<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap,
    contributor_identifier: ContributorIdentifier,
    role: RecordingContributorRole,
) {
    self.authorize(cap);
    self.contributors.get_mut(&contributor_identifier).insert(role);
}

public fun remove_contributor_role<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap,
    contributor_identifier: ContributorIdentifier,
    role: RecordingContributorRole,
) {
    self.authorize(cap);
    self.contributors.get_mut(&contributor_identifier).remove(&role);
}

public fun add_artifact<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap,
    artifact: Artifact<RecordingArtifactVariant>,
) {
    self.authorize(cap);
    assert!(self.artifacts.length() < MAX_ARTIFACTS, EMaxArtifactsExceeded);
    self.artifacts.push_back(artifact);
}

public fun remove_artifact<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap,
    artifact_idx: u64,
): Artifact<RecordingArtifactVariant> {
    self.authorize(cap);
    self.artifacts.remove(artifact_idx)
}

public fun add_snapshot<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap,
    snapshot: Snapshot,
) {
    self.authorize(cap);
    assert!(self.snapshots.length() < MAX_SNAPSHOTS, EMaxSnapshotsExceeded);
    self.snapshots.push_back(snapshot);
}

public fun remove_snapshot<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap,
    snapshot_idx: u64,
): Snapshot {
    self.authorize(cap);
    self.snapshots.remove(snapshot_idx)
}

public fun new_license<RecordingShare>(
    self: &Recording<RecordingShare>,
    cap: &RecordingAdminCap,
    timestamp: u64,
): RecordingDecryptionLicense {
    self.authorize(cap);
    recording_decryption_license::new(self.id(), timestamp)
}

//=== Public View Functions ===

public fun id<RecordingShare>(self: &Recording<RecordingShare>): ID {
    self.id.to_inner()
}

public fun composition_id<RecordingShare>(self: &Recording<RecordingShare>): ID {
    self.composition_id
}

public fun composition_commission_rate<RecordingShare>(self: &Recording<RecordingShare>): BPS {
    self.composition_commission_rate
}

public fun primary_mix<RecordingShare>(self: &Recording<RecordingShare>): &Mix {
    &self.primary_mix
}

public fun alternate_mixes<RecordingShare>(self: &Recording<RecordingShare>): &vector<Mix> {
    &self.alternate_mixes
}

public fun is_created_state<RecordingShare>(self: &Recording<RecordingShare>): bool {
    match (self.state) {
        RecordingState::Created => true,
        _ => false,
    }
}

public fun is_published_state<RecordingShare>(self: &Recording<RecordingShare>): bool {
    match (self.state) {
        RecordingState::Published(_) => true,
        _ => false,
    }
}

public fun authorize<RecordingShare>(self: &Recording<RecordingShare>, cap: &RecordingAdminCap) {
    assert!(self.id() == cap.recording_id, EInvalidRecordingAdminCap);
}

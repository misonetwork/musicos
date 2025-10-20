module musicos::recording;

use musicos::artifact::Artifact;
use musicos::composition::Composition;
use musicos::contributor_identifier::ContributorIdentifier;
use musicos::mix::Mix;
use musicos::recording_artifact_variant::RecordingArtifactVariant;
use musicos::recording_contributor_role::RecordingContributorRole;
use musicos::snapshot::Snapshot;
use sui::derived_object::{claim, exists};
use sui::event::emit;
use sui::vec_map::{Self, VecMap};
use sui::vec_set::{Self, VecSet};

//=== Structs ===

public struct Recording has key, store {
    id: UID,
    state: RecordingState,
    composition_id: ID,
    contributors: VecMap<ContributorIdentifier, VecSet<RecordingContributorRole>>,
    primary_mix: Mix,
    alternate_mixes: vector<Mix>,
    artifacts: vector<Artifact<RecordingArtifactVariant>>,
    snapshots: vector<Snapshot>,
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

//=== Events ===

public struct RecordingCreatedEvent has copy, drop {
    composition_id: ID,
    recording_id: ID,
}

//=== Public Functions ===

public fun new(composition: &mut Composition, mix: Mix, derivation_idx: u32): Recording {
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

    let recording = Recording {
        id: claim(composition.uid_mut(), RecordingDerivationKey(derivation_idx)),
        state: RecordingState::Created,
        composition_id,
        contributors: vec_map::empty(),
        primary_mix: mix,
        alternate_mixes: vector[],
        artifacts: vector[],
        snapshots: vector[],
    };

    emit(RecordingCreatedEvent {
        composition_id,
        recording_id: recording.id.to_inner(),
    });

    recording
}

public fun destroy(self: Recording, cap: RecordingAdminCap) {
    let Recording { id, .. } = self;
    id.delete();
    let RecordingAdminCap { id, .. } = cap;
    id.delete();
}

public fun add_alternate_mix(self: &mut Recording, cap: &RecordingAdminCap, mix: Mix) {
    self.authorize(cap);
    assert!(self.alternate_mixes.length() < MAX_ALTERNATE_MIXES, EMaxMixesExceeded);
    self.alternate_mixes.push_back(mix);
}

public fun remove_alternate_mix(self: &mut Recording, cap: &RecordingAdminCap, mix_idx: u64): Mix {
    self.authorize(cap);
    self.alternate_mixes.remove(mix_idx)
}

public fun add_contributor(
    self: &mut Recording,
    cap: &RecordingAdminCap,
    contributor_identifier: ContributorIdentifier,
) {
    self.authorize(cap);
    self.contributors.insert(contributor_identifier, vec_set::empty());
}

public fun remove_contributor(
    self: &mut Recording,
    cap: &RecordingAdminCap,
    contributor_identifier: ContributorIdentifier,
): (ContributorIdentifier, VecSet<RecordingContributorRole>) {
    self.authorize(cap);
    self.contributors.remove(&contributor_identifier)
}

public fun add_contributor_role(
    self: &mut Recording,
    cap: &RecordingAdminCap,
    contributor_identifier: ContributorIdentifier,
    role: RecordingContributorRole,
) {
    self.authorize(cap);
    self.contributors.get_mut(&contributor_identifier).insert(role);
}

public fun remove_contributor_role(
    self: &mut Recording,
    cap: &RecordingAdminCap,
    contributor_identifier: ContributorIdentifier,
    role: RecordingContributorRole,
) {
    self.authorize(cap);
    self.contributors.get_mut(&contributor_identifier).remove(&role);
}

public fun add_artifact(
    self: &mut Recording,
    cap: &RecordingAdminCap,
    artifact: Artifact<RecordingArtifactVariant>,
) {
    self.authorize(cap);
    assert!(self.artifacts.length() < MAX_ARTIFACTS, EMaxArtifactsExceeded);
    self.artifacts.push_back(artifact);
}

public fun remove_artifact(
    self: &mut Recording,
    cap: &RecordingAdminCap,
    artifact_idx: u64,
): Artifact<RecordingArtifactVariant> {
    self.authorize(cap);
    self.artifacts.remove(artifact_idx)
}

public fun add_snapshot(self: &mut Recording, cap: &RecordingAdminCap, snapshot: Snapshot) {
    self.authorize(cap);
    assert!(self.snapshots.length() < MAX_SNAPSHOTS, EMaxSnapshotsExceeded);
    self.snapshots.push_back(snapshot);
}

public fun remove_snapshot(
    self: &mut Recording,
    cap: &RecordingAdminCap,
    snapshot_idx: u64,
): Snapshot {
    self.authorize(cap);
    self.snapshots.remove(snapshot_idx)
}

//=== Public View Functions ===

public fun id(self: &Recording): ID {
    self.id.to_inner()
}

public fun composition_id(self: &Recording): ID {
    self.composition_id
}

public fun primary_mix(self: &Recording): &Mix {
    &self.primary_mix
}

public fun alternate_mixes(self: &Recording): &vector<Mix> {
    &self.alternate_mixes
}

public fun is_created_state(self: &Recording): bool {
    match (self.state) {
        RecordingState::Created => true,
        _ => false,
    }
}

public fun is_published_state(self: &Recording): bool {
    match (self.state) {
        RecordingState::Published(_) => true,
        _ => false,
    }
}

public fun authorize(self: &Recording, cap: &RecordingAdminCap) {
    assert!(self.id() == cap.recording_id, EInvalidRecordingAdminCap);
}

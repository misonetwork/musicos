module musicos::recording;

use musicos::artifact::Artifact;
use musicos::composition::Composition;
use musicos::mix::Mix;
use musicos::recording_artifact_variant::RecordingArtifactVariant;
use musicos::recording_contributor_role::RecordingContributorRole;
use musicos::snapshot::Snapshot;
use sui::clock::Clock;
use sui::derived_object::claim;
use sui::event::emit;
use sui::vec_map::{Self, VecMap};
use sui::vec_set::VecSet;

//=== Structs ===

public struct Recording has key, store {
    id: UID,
    state: RecordingState,
    composition_id: ID,
    contributors: VecMap<address, VecSet<RecordingContributorRole>>,
    primary_mix: Mix,
    alternate_mixes: vector<Mix>,
    artifacts: vector<Artifact<RecordingArtifactVariant>>,
    snapshots: vector<Snapshot>,
}

public enum RecordingState has copy, drop, store {
    Created,
    Published(u64),
}

public struct RecordingAdminCap has key, store {
    id: UID,
    recording_id: ID,
}

//=== Constants ===

const MAX_MIXES: u64 = 10;

//=== Errors ===

const EInvalidRecordingAdminCap: u64 = 0;
const EMaxMixesExceeded: u64 = 1;

//=== Events ===

public struct RecordingCreatedEvent has copy, drop {
    recording_id: ID,
}

//=== Public Functions ===

public fun new(composition: &mut Composition, mix: Mix, clock: &Clock): Recording {
    let composition_id = object::id(composition);

    let recording = Recording {
        id: claim(composition.uid_mut(), composition_id),
        state: RecordingState::Created,
        composition_id,
        contributors: vec_map::empty(),
        primary_mix: mix,
        alternate_mixes: vector[],
        artifacts: vector[],
        snapshots: vector[],
    };

    let recording_id = object::id(&recording);

    composition.add_recording_id(recording_id, clock);

    emit(RecordingCreatedEvent {
        recording_id,
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
    assert!(self.alternate_mixes.length() < MAX_MIXES, EMaxMixesExceeded);
    self.alternate_mixes.push_back(mix);
}

public fun remove_alternate_mix(self: &mut Recording, cap: &RecordingAdminCap, mix_idx: u64): Mix {
    self.authorize(cap);
    self.alternate_mixes.remove(mix_idx)
}

public fun swap_alternate_mixes(
    self: &mut Recording,
    cap: &RecordingAdminCap,
    a_idx: u64,
    b_idx: u64,
) {
    self.authorize(cap);
    self.alternate_mixes.swap(a_idx, b_idx);
}

public fun uid_mut(self: &mut Recording, cap: &RecordingAdminCap): &mut UID {
    self.authorize(cap);
    &mut self.id
}

//=== Public View Functions ===

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
    assert!(object::id(self) == cap.recording_id, EInvalidRecordingAdminCap);
}

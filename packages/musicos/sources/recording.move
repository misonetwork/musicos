// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module musicos::recording;

use interest_bps::bps::BPS;
use musicos::audio::Audio;
use musicos::composition::Composition;
use musicos::contributor::Contributor;
use musicos::genre::Genre;
use musicos::protocol::Protocol;
use musicos::recording_contributor_role::RecordingContributorRole;
use musicos::share;
use musicos::stem::Stem;
use std::string::String;
use std::type_name::{Self, TypeName};
use sui::balance::Balance;
use sui::clock::Clock;
use sui::coin::TreasuryCap;
use sui::coin_registry::{Currency, MetadataCap};
use sui::derived_object::claim;
use sui::event::emit;
use sui::vec_map::{Self, VecMap};
use sui::vec_set::{Self, VecSet};

//=== Structs ===

public struct Recording<phantom RecordingShare> has key {
    id: UID,
    state: RecordingState,
    composition_id: ID,
    composition_split: BPS,
    genre_id: ID,
    contributors: VecMap<ID, vector<RecordingContributorRole>>,
    master: Audio,
    stems: vector<Stem>,
    share_metadata_cap: MetadataCap<RecordingShare>,
}

public struct RecordingAdminCap has key, store {
    id: UID,
    recording_id: ID,
}

public struct RecordingKey(vector<u8>) has copy, drop, store;

//=== Events ===

public struct RecordingCreatedEvent has copy, drop {
    recording_id: ID,
    share_type: TypeName,
    composition_id: ID,
    genre_id: ID,
}

public struct RecordingStemAddedEvent has copy, drop {
    recording_id: ID,
    audio_digest: vector<u8>,
}

public struct RecordingStemRemovedEvent has copy, drop {
    recording_id: ID,
    audio_digest: vector<u8>,
}

//=== Enums ===

public enum RecordingState has copy, drop, store {
    Initialized,
    Created,
    Published(u64),
}

//=== Errors ===

const EUnauthorized: u64 = 0;
const ENotCreatedState: u64 = 1;
const EMaxStemsExceeded: u64 = 2;

//=== Public Functions ===

public fun new<RecordingShare, CompositionShare>(
    composition: &mut Composition<CompositionShare>,
    genre: &Genre,
    master: Audio,
    share_currency: &mut Currency<RecordingShare>,
    share_metadata_cap: MetadataCap<RecordingShare>,
    share_treasury_cap: TreasuryCap<RecordingShare>,
    protocol: &Protocol,
    ctx: &mut TxContext,
): (Recording<RecordingShare>, RecordingAdminCap, Balance<RecordingShare>) {
    protocol.assert_is_active_state();

    let composition_id = composition.id();
    let genre_id = genre.id();

    let recording = Recording<RecordingShare> {
        id: claim(composition.uid_mut(), RecordingKey(*master.digest())),
        state: RecordingState::Initialized,
        composition_id,
        composition_split: composition.split(),
        genre_id: genre_id,
        contributors: vec_map::empty(),
        master,
        stems: vector[],
        share_metadata_cap,
    };

    let recording_admin_cap = RecordingAdminCap {
        id: object::new(ctx),
        recording_id: recording.id(),
    };

    let mut description = b"MusicOS Recording Shares for ".to_string();
    description.append(recording.id().to_address().to_string());

    let recording_shares = share::intialize<RecordingShare>(
        b"MusicOS Recording Share".to_string(),
        description,
        share_currency,
        &recording.share_metadata_cap,
        share_treasury_cap,
    );

    emit(RecordingCreatedEvent {
        recording_id: recording.id(),
        share_type: type_name::with_defining_ids<RecordingShare>(),
        composition_id,
        genre_id,
    });

    (recording, recording_admin_cap, recording_shares)
}

// Adds a stem to a recording.
// Required State: Created
public fun add_stem<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap,
    stem: Stem,
    protocol: &Protocol,
) {
    self.authorize(cap);

    match (self.state) {
        RecordingState::Created => {
            assert!(
                self.stems.length() < protocol.max_stems_per_recording() as u64,
                EMaxStemsExceeded,
            );

            emit(RecordingStemAddedEvent {
                recording_id: self.id(),
                audio_digest: *stem.audio().digest(),
            });

            self.stems.push_back(stem);
        },
        _ => abort ENotCreatedState,
    }
}

// Removes a stem from a recording.
// Required State: Created
public fun remove_stem<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap,
    stem_idx: u64,
): Stem {
    self.authorize(cap);

    match (self.state) {
        RecordingState::Created => {
            let stem = self.stems.swap_remove(stem_idx);

            emit(RecordingStemRemovedEvent {
                recording_id: self.id(),
                audio_digest: *stem.audio().digest(),
            });

            stem
        },
        _ => abort ENotCreatedState,
    }
}

//=== Public View Functions ===

public fun id<RecordingShare>(recording: &Recording<RecordingShare>): ID {
    recording.id.to_inner()
}

public fun composition_id<RecordingShare>(recording: &Recording<RecordingShare>): ID {
    recording.composition_id
}

public fun composition_split<RecordingShare>(recording: &Recording<RecordingShare>): BPS {
    recording.composition_split
}

public fun genre_id<RecordingShare>(recording: &Recording<RecordingShare>): ID {
    recording.genre_id
}

public fun master<RecordingShare>(recording: &Recording<RecordingShare>): &Audio {
    &recording.master
}

public fun stems<RecordingShare>(recording: &Recording<RecordingShare>): &vector<Stem> {
    &recording.stems
}

//=== Private Functions ===

public(package) fun authorize<RecordingShare>(
    self: &Recording<RecordingShare>,
    cap: &RecordingAdminCap,
) {
    assert!(self.id() == cap.recording_id, EUnauthorized);
}

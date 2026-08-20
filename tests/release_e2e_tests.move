// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// End-to-end test of the production release flow across transaction
/// boundaries and actors, against a bare parent `UID` (core no longer owns a
/// shared coordinator; a future extension package supplies the canonical
/// one — see release.move's module doc):
///
/// 1. A songwriter publishes a composition.
/// 2. An artist publishes a recording of it.
/// 3. The artist consents to the *predicted* release id (digest-derived via
///    `derive_target_release_id`) by calling `track::new` directly with the
///    recording admin capability — there is no separable authorization
///    object to negotiate over or hand off; that is now an offer extension's
///    job.
/// 4. A label creates the release through `release::new` (claiming the
///    digest-derived UID from the parent) and publishes it — which verifies
///    every track was aimed at exactly this release.
/// 5. Anyone can read the published release and its assigned track.
#[test_only]
module miso::release_e2e_tests;

use miso::composition::{Self, Composition};
use miso::recording::{Self, Recording};
use miso::release::{Self, Release};
use miso::test_helpers::{Self, CompositionShare, RecordingShare};
use miso::track;
use std::unit_test::{assert_eq, destroy};
use sui::test_scenario;

const SONGWRITER: address = @0xA1;
const ARTIST: address = @0xA2;
const LABEL: address = @0xA3;
const READER: address = @0xBEEF;

const ROYALTY_RATE_BPS: u16 = 1500;
const NONCE: u256 = 42;

#[test]
fun full_track_release_flow_publishes_at_derived_id() {
    let mut scenario = test_scenario::begin(SONGWRITER);
    let mut parent = object::new(scenario.ctx());
    let parent_id = parent.to_inner();

    // === Tx 1 (SONGWRITER): create and publish the composition ===
    scenario.next_tx(SONGWRITER);
    let (comp, comp_cap) = composition::new_for_testing<CompositionShare>(
        b"Song".to_string(),
        ROYALTY_RATE_BPS,
        scenario.ctx(),
    );
    let clock = sui::clock::create_for_testing(scenario.ctx());
    comp.publish(&comp_cap, &clock); // shares the composition
    clock.destroy_for_testing();
    destroy(comp_cap);

    // === Tx 2 (ARTIST): create and publish a recording of it ===
    scenario.next_tx(ARTIST);
    let comp = scenario.take_shared<Composition<CompositionShare>>();
    let (rec, rec_cap) = recording::new_for_testing<RecordingShare, CompositionShare>(
        comp.id(),
        scenario.ctx(),
    );
    let clock = sui::clock::create_for_testing(scenario.ctx());
    rec.publish(&rec_cap, &clock); // shares the recording
    clock.destroy_for_testing();
    test_scenario::return_shared(comp);

    // === Tx 3 (ARTIST): consent to the predicted release id via track::new ===
    scenario.next_tx(ARTIST);
    let comp = scenario.take_shared<Composition<CompositionShare>>();
    let rec = scenario.take_shared<Recording<RecordingShare, CompositionShare>>();
    let recording_id = rec.id();
    let predicted_release_id = release::derive_target_release_id(
        vector[recording_id],
        vector[10000u64],
        NONCE,
        parent_id,
    );
    let t = track::new(&rec_cap, &rec, predicted_release_id, 10000);
    test_scenario::return_shared(comp);
    test_scenario::return_shared(rec);

    // === Tx 4 (LABEL): assemble and publish the release ===
    scenario.next_tx(LABEL);
    let (rel, rel_cap) = release::new(
        b"Single".to_string(),
        vector[t],
        NONCE,
        &mut parent,
    );
    // The claimed UID must equal the prediction the track was bound to.
    assert_eq!(rel.id(), predicted_release_id);
    let clock = sui::clock::create_for_testing(scenario.ctx());
    rel.publish(&rel_cap, &clock); // verifies track assignment, shares
    clock.destroy_for_testing();
    destroy(rel_cap);

    // === Tx 5 (READER): the published release is publicly consistent ===
    scenario.next_tx(READER);
    let rel = scenario.take_shared<Release>();
    assert!(rel.is_published_state());
    assert_eq!(rel.id(), predicted_release_id);
    assert_eq!(*rel.title(), b"Single".to_string());
    assert_eq!(rel.tracks().length(), 1);
    assert!(rel.tracks().any!(|track| track.recording_id() == recording_id));
    let track_ref = &rel.tracks()[0];
    assert!(track_ref.is_assigned_state());
    assert_eq!(track_ref.recording_id(), recording_id);
    assert_eq!(track_ref.split_bps().value(), 10000);
    test_scenario::return_shared(rel);

    destroy(rec_cap);
    parent.delete();
    scenario.end();
}

/// A track whose creator consented to a different release cannot be
/// published in this one — the digest binding is enforced at
/// `release::publish`.
#[test, expected_failure(abort_code = 0, location = miso::track)] // EUnauthorizedAssignment
fun publish_aborts_when_track_targets_a_different_release() {
    let mut scenario = test_scenario::begin(SONGWRITER);
    let mut parent = object::new(scenario.ctx());
    let parent_id = parent.to_inner();

    // One actor for brevity — the binding doesn't depend on senders.
    scenario.next_tx(SONGWRITER);
    let (_comp, _comp_cap) = composition::new_for_testing<CompositionShare>(
        b"Song".to_string(),
        ROYALTY_RATE_BPS,
        scenario.ctx(),
    );
    let (rec, rec_cap) = recording::new_for_testing<RecordingShare, CompositionShare>(
        _comp.id(),
        scenario.ctx(),
    );

    scenario.next_tx(SONGWRITER);
    // Track consented to the release that nonce 1 would produce...
    let wrong_release_id = release::derive_target_release_id(
        vector[rec.id()],
        vector[10000u64],
        1,
        parent_id,
    );
    let t = track::new(&rec_cap, &rec, wrong_release_id, 10000);
    // ...but the release is created with nonce 2: different derived id.
    let (rel, rel_cap) = release::new(
        b"Single".to_string(),
        vector[t],
        2,
        &mut parent,
    );
    let clock = sui::clock::create_for_testing(scenario.ctx());
    rel.publish(&rel_cap, &clock); // aborts: track targets a different release

    // Unreachable, but the compiler requires all non-drop values consumed.
    abort
}

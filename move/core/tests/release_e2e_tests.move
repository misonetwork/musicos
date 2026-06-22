// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// End-to-end test of the production release flow across transaction
/// boundaries and actors, against the real (init-created, shared)
/// `ReleaseRegistry`:
///
/// 1. A songwriter publishes a composition.
/// 2. An artist publishes a recording of it.
/// 3. The artist creates a `Deal` bound to the *predicted* release id
///    (digest-derived via `derive_release_id`) and sends it to a label.
/// 4. The label accepts the deal into a track, creates the release through
///    `release::new` (claiming the digest-derived UID from the registry),
///    and publishes it — which verifies every track was aimed at exactly
///    this release.
/// 5. Anyone can read the published release and its assigned track.
#[test_only]
module miso::release_e2e_tests;

use miso::composition::{Self, Composition};
use miso::deal::{Self, Deal};
use miso::disc;
use miso::recording::{Self, Recording};
use miso::release::{Self, Release, ReleaseRegistry};
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
fun full_deal_track_release_flow_publishes_at_derived_id() {
    let mut scenario = test_scenario::begin(SONGWRITER);
    release::init_for_testing(scenario.ctx());

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
        b"Song".to_string(),
        scenario.ctx(),
    );
    let clock = sui::clock::create_for_testing(scenario.ctx());
    rec.publish(&rec_cap, &clock); // shares the recording
    clock.destroy_for_testing();
    test_scenario::return_shared(comp);

    // === Tx 3 (ARTIST): strike a deal bound to the predicted release id ===
    scenario.next_tx(ARTIST);
    let comp = scenario.take_shared<Composition<CompositionShare>>();
    let rec = scenario.take_shared<Recording<RecordingShare, CompositionShare>>();
    let registry = scenario.take_shared<ReleaseRegistry>();
    let recording_id = rec.id();
    let predicted_release_id = release::derive_release_id(
        vector[recording_id],
        vector[10000u64],
        NONCE,
        &registry,
    );
    let d = deal::new(
        &rec_cap,
        &rec,
        predicted_release_id,
        10000,
        scenario.ctx(),
    );
    transfer::public_transfer(d, LABEL);
    test_scenario::return_shared(comp);
    test_scenario::return_shared(rec);
    test_scenario::return_shared(registry);

    // === Tx 4 (LABEL): accept the deal into a track, create and publish ===
    scenario.next_tx(LABEL);
    let d = scenario.take_from_sender<Deal<RecordingShare, CompositionShare>>();
    // The builder holds only the deal; it takes the (shared) recording to read
    // its address when constructing the track.
    let rec = scenario.take_shared<Recording<RecordingShare, CompositionShare>>();
    let t = track::new(d, &rec); // accepts the deal, emits DealAcceptedEvent
    test_scenario::return_shared(rec);
    let mut registry = scenario.take_shared<ReleaseRegistry>();
    let (mut rel, rel_cap) = release::new(
        b"Single".to_string(),
        vector[disc::new(vector[t], option::none())],
        NONCE,
        &mut registry,
    );
    // The claimed UID must equal the prediction the deal was bound to.
    assert_eq!(rel.id(), predicted_release_id);
    rel.set_subtitle(&rel_cap, b"Deluxe Edition".to_string());
    let clock = sui::clock::create_for_testing(scenario.ctx());
    rel.publish(&rel_cap, &clock); // verifies track assignment, shares
    clock.destroy_for_testing();
    // Exactly one accept, no rejects, in this transaction's event stream.
    assert_eq!(sui::event::events_by_type<deal::DealAcceptedEvent<RecordingShare, CompositionShare>>().length(), 1);
    assert_eq!(sui::event::events_by_type<deal::DealRejectedEvent<RecordingShare, CompositionShare>>().length(), 0);
    test_scenario::return_shared(registry);
    destroy(rel_cap);

    // === Tx 5 (READER): the published release is publicly consistent ===
    scenario.next_tx(READER);
    let rel = scenario.take_shared<Release>();
    assert!(rel.is_published_state());
    assert_eq!(rel.id(), predicted_release_id);
    assert_eq!(*rel.subtitle(), option::some(b"Deluxe Edition".to_string()));
    assert_eq!(rel.total_tracks(), 1);
    assert!(rel.contains_recording(recording_id));
    let track_ref = &rel.discs()[0].tracks()[0];
    assert!(track_ref.is_assigned_state());
    assert_eq!(track_ref.recording_id(), recording_id);
    assert_eq!(track_ref.split_bps().value(), 10000);
    test_scenario::return_shared(rel);

    destroy(rec_cap);
    scenario.end();
}

/// A track whose deal targeted a different release cannot be published in
/// this one — the digest binding is enforced at `release::publish`.
#[test, expected_failure(abort_code = 0, location = miso::track)] // EUnauthorizedAssignment
fun publish_aborts_when_track_targets_a_different_release() {
    let mut scenario = test_scenario::begin(SONGWRITER);
    release::init_for_testing(scenario.ctx());

    // One actor for brevity — the binding doesn't depend on senders.
    scenario.next_tx(SONGWRITER);
    let (_comp, _comp_cap) = composition::new_for_testing<CompositionShare>(
        b"Song".to_string(),
        ROYALTY_RATE_BPS,
        scenario.ctx(),
    );
    let (rec, rec_cap) = recording::new_for_testing<RecordingShare, CompositionShare>(
        b"Song".to_string(),
        scenario.ctx(),
    );

    scenario.next_tx(SONGWRITER);
    let mut registry = scenario.take_shared<ReleaseRegistry>();
    // Deal bound to the release that nonce 1 would produce...
    let wrong_release_id = release::derive_release_id(
        vector[rec.id()],
        vector[10000u64],
        1,
        &registry,
    );
    let d = deal::new(
        &rec_cap,
        &rec,
        wrong_release_id,
        10000,
        scenario.ctx(),
    );
    // ...but the release is created with nonce 2: different derived id.
    let t = track::new(d, &rec);
    let (rel, rel_cap) = release::new(
        b"Single".to_string(),
        vector[disc::new(vector[t], option::none())],
        2,
        &mut registry,
    );
    let clock = sui::clock::create_for_testing(scenario.ctx());
    rel.publish(&rel_cap, &clock); // aborts: track targets a different release

    // Unreachable, but the compiler requires all non-drop values consumed.
    abort
}

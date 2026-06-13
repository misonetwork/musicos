// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Post-publish immutability tests: every embedded-field mutator must abort on
/// a published (shared) object, while the dynamic-field extension surface
/// (`uid_mut`) must keep working — that asymmetry is the protocol's core
/// frozen-vs-evolvable contract.
#[test_only]
module musicos::post_publish_tests;

use musicos::composition::{Self, Composition};
use musicos::composition_party_role;
use musicos::recording::{Self, Recording};
use musicos::recording_party_role;
use musicos::release::{Self, Release};
use musicos::test_helpers::{Self, CompositionShare, RecordingShare};
use partyos::credit;
use std::unit_test::destroy;
use sui::dynamic_field;
use sui::test_scenario;

const OWNER: address = @0xA1;

// State error mirrored from the core modules.
const ENotInitializedState: u64 = 10;

/// Publishes a minimal composition and returns its admin cap (object is shared).
fun publish_composition(
    scenario: &mut test_scenario::Scenario,
): composition::CompositionAdminCap<CompositionShare> {
    let ctx = scenario.ctx();
    let (mut comp, cap) =
        composition::new_for_testing<CompositionShare>(b"Song".to_string(), 1500, ctx);
    let (party, party_cap) = test_helpers::individual(ctx);
    comp.add_credit(
        &cap,
        &party,
        credit::new(b"W".to_string(), vector[composition_party_role::new_composer_role()]),
    );
    let clock = sui::clock::create_for_testing(ctx);
    comp.publish(&cap, &clock);
    clock.destroy_for_testing();
    destroy(party);
    destroy(party_cap);
    cap
}

/// Publishes a minimal recording and returns its admin cap (object is shared).
fun publish_recording(
    scenario: &mut test_scenario::Scenario,
): recording::RecordingAdminCap<RecordingShare> {
    let ctx = scenario.ctx();
    let (mut rec, cap) = recording::new_for_testing<RecordingShare, CompositionShare>(
        b"Song".to_string(),
        test_helpers::cover_art(),
        ctx,
    );
    let (party, party_cap) = test_helpers::individual(ctx);
    rec.add_credit(
        &cap,
        &party,
        credit::new(
            b"A".to_string(),
            vector[recording_party_role::new_vocalist_role(option::none())],
        ),
    );
    rec.add_primary_artist(&cap, &party);
    let clock = sui::clock::create_for_testing(ctx);
    rec.publish(&cap, &clock);
    clock.destroy_for_testing();
    destroy(party);
    destroy(party_cap);
    cap
}

/// Publishes a minimal release and returns its admin cap (object is shared).
fun publish_release(scenario: &mut test_scenario::Scenario): release::ReleaseAdminCap {
    let ctx = scenario.ctx();
    let (mut rel, cap) = release::new_for_testing(
        b"Album".to_string(),
        test_helpers::cover_art(),
        vector[musicos::disc::new(
            vector[musicos::track::new_for_testing(
                test_helpers::fake_id(ctx),
                test_helpers::fake_id(ctx),
                10000,
            )],
            option::none(),
        )],
        ctx,
    );
    rel.prefill_credits_for_testing(1, ctx);
    let clock = sui::clock::create_for_testing(ctx);
    rel.publish(&cap, &clock);
    clock.destroy_for_testing();
    cap
}

// === Composition ===

#[test, expected_failure(abort_code = ENotInitializedState, location = musicos::composition)]
fun composition_add_credit_after_publish_aborts() {
    let mut scenario = test_scenario::begin(OWNER);
    let cap = publish_composition(&mut scenario);

    scenario.next_tx(OWNER);
    let mut comp = scenario.take_shared<Composition<CompositionShare>>();
    let (party, party_cap) = test_helpers::individual(scenario.ctx());
    comp.add_credit(
        &cap,
        &party,
        credit::new(b"L".to_string(), vector[composition_party_role::new_lyricist_role()]),
    );

    destroy(comp);
    destroy(cap);
    destroy(party);
    destroy(party_cap);
    abort
}

#[test, expected_failure(abort_code = ENotInitializedState, location = musicos::composition)]
fun composition_publish_twice_aborts() {
    let mut scenario = test_scenario::begin(OWNER);
    let cap = publish_composition(&mut scenario);

    scenario.next_tx(OWNER);
    let comp = scenario.take_shared<Composition<CompositionShare>>();
    let clock = sui::clock::create_for_testing(scenario.ctx());
    comp.publish(&cap, &clock);

    clock.destroy_for_testing();
    destroy(cap);
    abort
}

/// The extension surface stays open after publish: `uid_mut` works on a
/// published composition and dynamic fields can be attached and read back.
#[test]
fun composition_uid_mut_works_after_publish() {
    let mut scenario = test_scenario::begin(OWNER);
    let cap = publish_composition(&mut scenario);

    scenario.next_tx(OWNER);
    let mut comp = scenario.take_shared<Composition<CompositionShare>>();
    assert!(comp.is_published_state());
    assert!(!comp.is_initialized_state());
    let _state = comp.state();
    dynamic_field::add(comp.uid_mut(&cap), b"extension", 42u64);
    assert!(dynamic_field::exists_(comp.uid(), b"extension"));
    assert!(*dynamic_field::borrow<vector<u8>, u64>(comp.uid(), b"extension") == 42);
    test_scenario::return_shared(comp);

    destroy(cap);
    scenario.end();
}

// === Recording ===

#[test, expected_failure(abort_code = ENotInitializedState, location = musicos::recording)]
fun recording_set_title_version_after_publish_aborts() {
    let mut scenario = test_scenario::begin(OWNER);
    let cap = publish_recording(&mut scenario);

    scenario.next_tx(OWNER);
    let mut rec = scenario.take_shared<Recording<RecordingShare, CompositionShare>>();
    rec.set_title_version(&cap, b"Radio Edit".to_string());

    destroy(rec);
    destroy(cap);
    abort
}

#[test, expected_failure(abort_code = ENotInitializedState, location = musicos::recording)]
fun recording_add_credit_after_publish_aborts() {
    let mut scenario = test_scenario::begin(OWNER);
    let cap = publish_recording(&mut scenario);

    scenario.next_tx(OWNER);
    let mut rec = scenario.take_shared<Recording<RecordingShare, CompositionShare>>();
    let (party, party_cap) = test_helpers::individual(scenario.ctx());
    rec.add_credit(
        &cap,
        &party,
        credit::new(
            b"B".to_string(),
            vector[recording_party_role::new_producer_role(option::none())],
        ),
    );

    destroy(rec);
    destroy(cap);
    destroy(party);
    destroy(party_cap);
    abort
}

// === Release ===

#[test, expected_failure(abort_code = ENotInitializedState, location = musicos::release)]
fun release_set_subtitle_after_publish_aborts() {
    let mut scenario = test_scenario::begin(OWNER);
    let cap = publish_release(&mut scenario);

    scenario.next_tx(OWNER);
    let mut rel = scenario.take_shared<Release>();
    rel.set_subtitle(&cap, b"Deluxe Edition".to_string());

    destroy(rel);
    destroy(cap);
    abort
}

#[test, expected_failure(abort_code = ENotInitializedState, location = musicos::release)]
fun release_add_credit_after_publish_aborts() {
    let mut scenario = test_scenario::begin(OWNER);
    let cap = publish_release(&mut scenario);

    scenario.next_tx(OWNER);
    let mut rel = scenario.take_shared<Release>();
    let (party, party_cap) = test_helpers::individual(scenario.ctx());
    rel.add_credit(
        &cap,
        &party,
        credit::new(
            b"G".to_string(),
            vector[musicos::release_party_role::new_featured_role()],
        ),
    );

    destroy(rel);
    destroy(cap);
    destroy(party);
    destroy(party_cap);
    abort
}

#[test, expected_failure(abort_code = ENotInitializedState, location = musicos::recording)]
fun recording_set_subtitle_after_publish_aborts() {
    let mut scenario = test_scenario::begin(OWNER);
    let cap = publish_recording(&mut scenario);

    scenario.next_tx(OWNER);
    let mut rec = scenario.take_shared<Recording<RecordingShare, CompositionShare>>();
    rec.set_subtitle(&cap, b"Too Late".to_string());

    destroy(rec);
    destroy(cap);
    abort
}

#[test, expected_failure(abort_code = ENotInitializedState, location = musicos::recording)]
fun recording_add_primary_artist_after_publish_aborts() {
    let mut scenario = test_scenario::begin(OWNER);
    let cap = publish_recording(&mut scenario);

    scenario.next_tx(OWNER);
    let mut rec = scenario.take_shared<Recording<RecordingShare, CompositionShare>>();
    let (party, party_cap) = test_helpers::individual(scenario.ctx());
    rec.add_primary_artist(&cap, &party);

    destroy(rec);
    destroy(cap);
    destroy(party);
    destroy(party_cap);
    abort
}

#[test, expected_failure(abort_code = ENotInitializedState, location = musicos::recording)]
fun recording_add_featured_artist_after_publish_aborts() {
    let mut scenario = test_scenario::begin(OWNER);
    let cap = publish_recording(&mut scenario);

    scenario.next_tx(OWNER);
    let mut rec = scenario.take_shared<Recording<RecordingShare, CompositionShare>>();
    let (party, party_cap) = test_helpers::individual(scenario.ctx());
    rec.add_featured_artist(&cap, &party);

    destroy(rec);
    destroy(cap);
    destroy(party);
    destroy(party_cap);
    abort
}

#[test, expected_failure(abort_code = ENotInitializedState, location = musicos::recording)]
fun recording_publish_twice_aborts() {
    let mut scenario = test_scenario::begin(OWNER);
    let cap = publish_recording(&mut scenario);

    scenario.next_tx(OWNER);
    let rec = scenario.take_shared<Recording<RecordingShare, CompositionShare>>();
    let clock = sui::clock::create_for_testing(scenario.ctx());
    rec.publish(&cap, &clock);

    clock.destroy_for_testing();
    destroy(cap);
    abort
}

#[test, expected_failure(abort_code = ENotInitializedState, location = musicos::release)]
fun release_publish_twice_aborts() {
    let mut scenario = test_scenario::begin(OWNER);
    let cap = publish_release(&mut scenario);

    scenario.next_tx(OWNER);
    let rel = scenario.take_shared<Release>();
    let clock = sui::clock::create_for_testing(scenario.ctx());
    rel.publish(&cap, &clock);

    clock.destroy_for_testing();
    destroy(cap);
    abort
}

/// Masters and other extensions attach to recordings after publish — the
/// dynamic-field surface must stay open while embedded fields are frozen.
#[test]
fun recording_uid_mut_works_after_publish() {
    let mut scenario = test_scenario::begin(OWNER);
    let cap = publish_recording(&mut scenario);

    scenario.next_tx(OWNER);
    let mut rec = scenario.take_shared<Recording<RecordingShare, CompositionShare>>();
    assert!(rec.is_published_state());
    assert!(!rec.is_initialized_state());
    let _state = rec.state();
    dynamic_field::add(rec.uid_mut(&cap), b"master", 7u64);
    assert!(dynamic_field::exists_(rec.uid(), b"master"));
    test_scenario::return_shared(rec);

    destroy(cap);
    scenario.end();
}

#[test]
fun release_uid_mut_works_after_publish() {
    let mut scenario = test_scenario::begin(OWNER);
    let cap = publish_release(&mut scenario);

    scenario.next_tx(OWNER);
    let mut rel = scenario.take_shared<Release>();
    assert!(rel.is_published_state());
    assert!(!rel.is_initialized_state());
    let _state = rel.state();
    let _art = rel.cover_art();
    dynamic_field::add(rel.uid_mut(&cap), b"metadata", 9u64);
    assert!(dynamic_field::exists_(rel.uid(), b"metadata"));
    test_scenario::return_shared(rel);

    destroy(cap);
    scenario.end();
}

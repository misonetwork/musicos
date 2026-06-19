// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module genre::genre_tests;

// Alias the module so the bare address `genre` resolves in
// `#[expected_failure(location = genre::genre)]` (avoids the addr==module
// name collision).
use genre::genre as g;
use genre::genre::{GenreRegistry, GenreRegistryCap, Genre};
use miso::recording::{Self, Recording, RecordingAdminCap};
use miso::test_helpers::{RecordingShare, CompositionShare};
use std::unit_test::destroy;
use sui::test_scenario::{Self as ts, Scenario};

const CURATOR: address = @0xC0;

// === Helpers ===

fun new_recording(
    scenario: &mut Scenario,
): (Recording<RecordingShare, CompositionShare>, RecordingAdminCap<RecordingShare>) {
    recording::new_for_testing(b"Test Recording".to_string(), scenario.ctx())
}

/// Creates a genre in the registry (cap-gated) and returns its derived id.
fun create_genre(scenario: &mut Scenario, name: vector<u8>): ID {
    let cap = scenario.take_from_sender<GenreRegistryCap>();
    let mut registry = scenario.take_shared<GenreRegistry>();
    let id = g::derive_genre_id(&registry, name.to_string());
    g::new(&cap, &mut registry, name.to_string());
    ts::return_shared(registry);
    scenario.return_to_sender(cap);
    id
}

// === Vocabulary ===

#[test]
fun test_create_genre_and_derive() {
    let mut scenario = ts::begin(CURATOR);
    g::init_for_testing(scenario.ctx());

    scenario.next_tx(CURATOR);
    let genre_id = create_genre(&mut scenario, b"HIP_HOP");

    // The frozen Genre lives at the derived id, with the canonical name.
    scenario.next_tx(CURATOR);
    let genre = scenario.take_immutable_by_id<Genre>(genre_id);
    assert!(g::id(&genre) == genre_id);
    assert!(g::name(&genre) == b"HIP_HOP".to_string());
    ts::return_immutable(genre);

    scenario.end();
}

#[test]
#[expected_failure]
fun test_create_duplicate_aborts() {
    let mut scenario = ts::begin(CURATOR);
    g::init_for_testing(scenario.ctx());

    // Both creates on one registry borrow so the second hits the real dedup
    // abort (derived-object id already claimed), not test-scenario inventory.
    scenario.next_tx(CURATOR);
    let cap = scenario.take_from_sender<GenreRegistryCap>();
    let mut registry = scenario.take_shared<GenreRegistry>();
    g::new(&cap, &mut registry, b"HIP_HOP".to_string());
    g::new(&cap, &mut registry, b"HIP_HOP".to_string()); // same name -> aborts
    ts::return_shared(registry);
    scenario.return_to_sender(cap);

    scenario.end();
}

#[test]
#[expected_failure(abort_code = 20, location = genre::genre)] // EEmptyName
fun test_empty_name_aborts() {
    let mut scenario = ts::begin(CURATOR);
    g::init_for_testing(scenario.ctx());

    scenario.next_tx(CURATOR);
    create_genre(&mut scenario, b"");

    scenario.end();
}

#[test]
#[expected_failure(abort_code = 22, location = genre::genre)] // EInvalidNameChar
fun test_invalid_name_char_aborts() {
    let mut scenario = ts::begin(CURATOR);
    g::init_for_testing(scenario.ctx());

    scenario.next_tx(CURATOR);
    create_genre(&mut scenario, b"Hip-Hop"); // lowercase + hyphen -> rejected

    scenario.end();
}

// === Assignment ===

#[test]
fun test_set_primary_genre() {
    let mut scenario = ts::begin(CURATOR);
    g::init_for_testing(scenario.ctx());

    scenario.next_tx(CURATOR);
    let genre_id = create_genre(&mut scenario, b"HIP_HOP");

    scenario.next_tx(CURATOR);
    let genre = scenario.take_immutable_by_id<Genre>(genre_id);
    let (mut recording, cap) = new_recording(&mut scenario);

    assert!(!g::has_genre(&recording));
    g::set_primary_genre(&mut recording, &cap, &genre, scenario.ctx());
    assert!(g::has_genre(&recording));
    assert!(g::primary_genre(&recording) == option::some(genre_id));
    assert!(g::secondary_genres(&recording).is_empty());

    ts::return_immutable(genre);
    destroy(recording);
    destroy(cap);
    scenario.end();
}

#[test]
fun test_replace_primary_genre_after_period() {
    let mut scenario = ts::begin(CURATOR);
    g::init_for_testing(scenario.ctx());

    scenario.next_tx(CURATOR);
    let g1 = create_genre(&mut scenario, b"HIP_HOP");
    scenario.next_tx(CURATOR);
    let g2 = create_genre(&mut scenario, b"ELECTRONIC");

    scenario.next_tx(CURATOR);
    let genre1 = scenario.take_immutable_by_id<Genre>(g1);
    let genre2 = scenario.take_immutable_by_id<Genre>(g2);
    let (mut recording, cap) = new_recording(&mut scenario);

    g::set_primary_genre(&mut recording, &cap, &genre1, scenario.ctx());

    // Wait out the 30-epoch hold period, then the change is allowed.
    30u64.do!(|_| { scenario.next_epoch(CURATOR); });
    g::set_primary_genre(&mut recording, &cap, &genre2, scenario.ctx());
    assert!(g::primary_genre(&recording) == option::some(g2));

    ts::return_immutable(genre1);
    ts::return_immutable(genre2);
    destroy(recording);
    destroy(cap);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = 31, location = genre::genre)] // EPrimaryGenreLocked
fun test_change_primary_too_soon_aborts() {
    let mut scenario = ts::begin(CURATOR);
    g::init_for_testing(scenario.ctx());

    scenario.next_tx(CURATOR);
    let g1 = create_genre(&mut scenario, b"HIP_HOP");
    scenario.next_tx(CURATOR);
    let g2 = create_genre(&mut scenario, b"ELECTRONIC");

    scenario.next_tx(CURATOR);
    let genre1 = scenario.take_immutable_by_id<Genre>(g1);
    let genre2 = scenario.take_immutable_by_id<Genre>(g2);
    let (mut recording, cap) = new_recording(&mut scenario);

    g::set_primary_genre(&mut recording, &cap, &genre1, scenario.ctx());
    // Only a few epochs later — still locked.
    scenario.next_epoch(CURATOR);
    g::set_primary_genre(&mut recording, &cap, &genre2, scenario.ctx());

    ts::return_immutable(genre1);
    ts::return_immutable(genre2);
    destroy(recording);
    destroy(cap);
    scenario.end();
}

#[test]
fun test_add_and_remove_secondary_genres() {
    let mut scenario = ts::begin(CURATOR);
    g::init_for_testing(scenario.ctx());

    scenario.next_tx(CURATOR);
    let g1 = create_genre(&mut scenario, b"HIP_HOP");
    scenario.next_tx(CURATOR);
    let g2 = create_genre(&mut scenario, b"ELECTRONIC");
    scenario.next_tx(CURATOR);
    let g3 = create_genre(&mut scenario, b"AMBIENT");

    scenario.next_tx(CURATOR);
    let genre1 = scenario.take_immutable_by_id<Genre>(g1);
    let genre2 = scenario.take_immutable_by_id<Genre>(g2);
    let genre3 = scenario.take_immutable_by_id<Genre>(g3);
    let (mut recording, cap) = new_recording(&mut scenario);

    g::set_primary_genre(&mut recording, &cap, &genre1, scenario.ctx());
    g::add_secondary_genre(&mut recording, &cap, &genre2);
    g::add_secondary_genre(&mut recording, &cap, &genre3);
    assert!(g::secondary_genres(&recording) == vector[g2, g3]);

    g::remove_secondary_genre(&mut recording, &cap, &genre2);
    assert!(g::secondary_genres(&recording) == vector[g3]);

    ts::return_immutable(genre1);
    ts::return_immutable(genre2);
    ts::return_immutable(genre3);
    destroy(recording);
    destroy(cap);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = 30, location = genre::genre)] // ENoPrimaryGenre
fun test_secondary_before_primary_aborts() {
    let mut scenario = ts::begin(CURATOR);
    g::init_for_testing(scenario.ctx());

    scenario.next_tx(CURATOR);
    let g1 = create_genre(&mut scenario, b"HIP_HOP");

    scenario.next_tx(CURATOR);
    let genre1 = scenario.take_immutable_by_id<Genre>(g1);
    let (mut recording, cap) = new_recording(&mut scenario);

    g::add_secondary_genre(&mut recording, &cap, &genre1); // no primary yet

    ts::return_immutable(genre1);
    destroy(recording);
    destroy(cap);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = 40, location = genre::genre)] // ESecondaryIsPrimary
fun test_secondary_equal_primary_aborts() {
    let mut scenario = ts::begin(CURATOR);
    g::init_for_testing(scenario.ctx());

    scenario.next_tx(CURATOR);
    let g1 = create_genre(&mut scenario, b"HIP_HOP");

    scenario.next_tx(CURATOR);
    let genre1 = scenario.take_immutable_by_id<Genre>(g1);
    let (mut recording, cap) = new_recording(&mut scenario);

    g::set_primary_genre(&mut recording, &cap, &genre1, scenario.ctx());
    g::add_secondary_genre(&mut recording, &cap, &genre1); // same as primary

    ts::return_immutable(genre1);
    destroy(recording);
    destroy(cap);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = 41, location = genre::genre)] // EGenreAlreadySecondary
fun test_duplicate_secondary_aborts() {
    let mut scenario = ts::begin(CURATOR);
    g::init_for_testing(scenario.ctx());

    scenario.next_tx(CURATOR);
    let g1 = create_genre(&mut scenario, b"HIP_HOP");
    scenario.next_tx(CURATOR);
    let g2 = create_genre(&mut scenario, b"ELECTRONIC");

    scenario.next_tx(CURATOR);
    let genre1 = scenario.take_immutable_by_id<Genre>(g1);
    let genre2 = scenario.take_immutable_by_id<Genre>(g2);
    let (mut recording, cap) = new_recording(&mut scenario);

    g::set_primary_genre(&mut recording, &cap, &genre1, scenario.ctx());
    g::add_secondary_genre(&mut recording, &cap, &genre2);
    g::add_secondary_genre(&mut recording, &cap, &genre2); // duplicate

    ts::return_immutable(genre1);
    ts::return_immutable(genre2);
    destroy(recording);
    destroy(cap);
    scenario.end();
}

// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module cover_art::cover_art_tests;

use cover_art::cover_art as cover;
use cover_art::recording_cover_art;
use cover_art::release_cover_art;
use miso::disc;
use miso::recording::{Self, Recording, RecordingAdminCap};
use miso::release::{Self, Release, ReleaseAdminCap};
use miso::test_helpers::{Self, RecordingShare, CompositionShare};
use miso::track;
use std::unit_test::destroy;
use sui::test_scenario;

const A: address = @0xA1;

fun mk_recording(
    ctx: &mut TxContext,
): (Recording<RecordingShare, CompositionShare>, RecordingAdminCap<RecordingShare>) {
    recording::new_for_testing(b"Song".to_string(), ctx)
}

fun mk_release(ctx: &mut TxContext): (Release, ReleaseAdminCap) {
    let rec_id = test_helpers::fake_id(ctx);
    let rel_id = test_helpers::fake_id(ctx);
    let d = disc::new(vector[track::new_for_testing(rec_id, rel_id, 10000)], option::none());
    release::new_for_testing(b"Album".to_string(), vector[d], ctx)
}

#[test]
fun recording_cover_art_set_read_replace_unset() {
    let mut ts = test_scenario::begin(A);
    let (mut rec, cap) = mk_recording(ts.ctx());

    assert!(!recording_cover_art::has_cover_art(&rec));
    recording_cover_art::set(&mut rec, &cap, cover::new_for_testing());
    assert!(recording_cover_art::has_cover_art(&rec));
    assert!(recording_cover_art::cover_art(&rec).animated().is_none());

    // replace is idempotent on presence
    recording_cover_art::set(&mut rec, &cap, cover::new_for_testing());
    assert!(recording_cover_art::has_cover_art(&rec));

    recording_cover_art::unset(&mut rec, &cap);
    assert!(!recording_cover_art::has_cover_art(&rec));

    destroy(rec); destroy(cap);
    ts.end();
}

#[test]
fun release_cover_and_disc_cover_art_round_trip() {
    let mut ts = test_scenario::begin(A);
    let (mut rel, cap) = mk_release(ts.ctx());
    assert!(!release_cover_art::has_cover_art(&rel));

    release_cover_art::set_cover(&mut rel, &cap, cover::new_for_testing());
    assert!(release_cover_art::has_cover_art(&rel));
    assert!(release_cover_art::cover(&rel).is_some());

    // disc 0 exists in this 1-disc release
    release_cover_art::set_disc_cover_art(&mut rel, &cap, 0, cover::new_for_testing());
    assert!(release_cover_art::has_disc_cover_art(&rel, 0));
    assert!(release_cover_art::disc_cover_art(&rel, 0).animated().is_none());

    release_cover_art::unset_cover(&mut rel, &cap);
    assert!(release_cover_art::cover(&rel).is_none());
    release_cover_art::unset_disc_cover_art(&mut rel, &cap, 0);
    assert!(!release_cover_art::has_disc_cover_art(&rel, 0));

    destroy(rel); destroy(cap);
    ts.end();
}

#[test, expected_failure(abort_code = 2, location = cover_art::release_cover_art)] // EDiscIndexOutOfBounds
fun set_disc_cover_art_rejects_out_of_bounds_index() {
    let mut ts = test_scenario::begin(A);
    let (mut rel, cap) = mk_release(ts.ctx()); // 1 disc → index 1 is invalid
    release_cover_art::set_disc_cover_art(&mut rel, &cap, 1, cover::new_for_testing());
    abort
}

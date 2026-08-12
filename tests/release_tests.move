#[test_only]
module miso::release_tests;

use miso::release;
use miso::test_helpers;
use miso::track;
use std::unit_test::{assert_eq, destroy};

// Error codes from release.move
const EUnauthorized: u64 = 0;
const EInvalidTrackSplitsSum: u64 = 20;
const EMaxTracksExceeded: u64 = 31;
const EMaxTitleLengthExceeded: u64 = 34;
const EEmptyString: u64 = 35;
const ENoTracks: u64 = 51;

// Must match release.move
const MAX_TRACKS: u64 = 255;
const MAX_TITLE_LENGTH: u64 = 300;

/// Helper to create a single test track.
fun test_track(ctx: &mut TxContext): track::Track {
    track::new_for_testing(
        test_helpers::fake_id(ctx),
        test_helpers::fake_id(ctx),
        10000, // 100% split (single track)
    )
}

/// Helper to create an ordered tracklist of n tracks sharing splits evenly.
fun test_tracks(track_count: u64, split_bps: u16, ctx: &mut TxContext): vector<track::Track> {
    vector::tabulate!(track_count, |_index| track::new_for_testing(
        test_helpers::fake_id(ctx),
        test_helpers::fake_id(ctx),
        split_bps,
    ))
}

// === Title Length ===

#[test, expected_failure(abort_code = EMaxTitleLengthExceeded, location = miso::release)]
fun test_new_title_too_long() {
    let ctx = &mut tx_context::dummy();
    let mut registry = release::new_release_registry_for_testing(ctx);
    let (rel, cap) = release::new(
        test_helpers::long_string(MAX_TITLE_LENGTH + 1),
        vector[test_track(ctx)],
        0u256,
        &mut registry,
    );
    destroy(rel);
    destroy(cap);
    destroy(registry);
}

// === Max Tracks ===

#[test, expected_failure(abort_code = EMaxTracksExceeded, location = miso::release)]
fun test_new_exceeds_max_tracks() {
    let ctx = &mut tx_context::dummy();
    let mut registry = release::new_release_registry_for_testing(ctx);

    // MAX_TRACKS + 1 = 256 tracks in one flat tracklist.
    // Splits: 256 x 39 BPS = 9984; the first 16 get 40 BPS (16 extra = 10000).
    let tracks = vector::tabulate!(MAX_TRACKS + 1, |index| track::new_for_testing(
        test_helpers::fake_id(ctx),
        test_helpers::fake_id(ctx),
        if (index < 16) 40 else 39,
    ));

    let (rel, cap) = release::new(
        b"Too Many Tracks".to_string(),
        tracks,
        0u256,
        &mut registry,
    );
    destroy(rel);
    destroy(cap);
    destroy(registry);
}

/// Helper to create a minimal release.
fun test_release(ctx: &mut TxContext): (release::Release, release::ReleaseAdminCap) {
    release::new_for_testing(
        b"Album".to_string(),
        test_tracks(1, 10000, ctx),
        ctx,
    )
}

// === Creation Validation ===

#[test, expected_failure(abort_code = EEmptyString, location = miso::release)]
fun test_new_empty_title() {
    let ctx = &mut tx_context::dummy();
    let mut registry = release::new_release_registry_for_testing(ctx);
    let (rel, cap) = release::new(
        b"".to_string(),
        vector[test_track(ctx)],
        0u256,
        &mut registry,
    );
    destroy(rel);
    destroy(cap);
    destroy(registry);
}

#[test, expected_failure(abort_code = ENoTracks, location = miso::release)]
fun test_new_no_tracks() {
    let ctx = &mut tx_context::dummy();
    let mut registry = release::new_release_registry_for_testing(ctx);
    let (rel, cap) = release::new(
        b"Empty".to_string(),
        vector[],
        0u256,
        &mut registry,
    );
    destroy(rel);
    destroy(cap);
    destroy(registry);
}

#[test, expected_failure(abort_code = EInvalidTrackSplitsSum, location = miso::release)]
fun test_new_splits_below_total() {
    let ctx = &mut tx_context::dummy();
    let mut registry = release::new_release_registry_for_testing(ctx);
    let (rel, cap) = release::new(
        b"Underweight".to_string(),
        test_tracks(1, 9999, ctx), // 99.99%
        0u256,
        &mut registry,
    );
    destroy(rel);
    destroy(cap);
    destroy(registry);
}

#[test, expected_failure(abort_code = EInvalidTrackSplitsSum, location = miso::release)]
fun test_new_splits_above_total() {
    let ctx = &mut tx_context::dummy();
    let mut registry = release::new_release_registry_for_testing(ctx);
    let (rel, cap) = release::new(
        b"Overweight".to_string(),
        test_tracks(2, 5001, ctx), // 100.02%
        0u256,
        &mut registry,
    );
    destroy(rel);
    destroy(cap);
    destroy(registry);
}

/// The same digest (recording set + splits + nonce) can only ever be claimed once.
#[test, expected_failure] // aborts in sui::derived_object on the duplicate claim
fun test_duplicate_digest_aborts() {
    let ctx = &mut tx_context::dummy();
    let mut registry = release::new_release_registry_for_testing(ctx);
    let rec_id = test_helpers::fake_id(ctx);
    let rel_id = test_helpers::fake_id(ctx);

    let (rel1, cap1) = release::new(
        b"First".to_string(),
        vector[track::new_for_testing(rec_id, rel_id, 10000)],
        7u256,
        &mut registry,
    );
    // Identical recording ids, splits, and nonce: identical digest.
    let (rel2, cap2) = release::new(
        b"Second".to_string(),
        vector[track::new_for_testing(rec_id, rel_id, 10000)],
        7u256,
        &mut registry,
    );
    destroy(rel1);
    destroy(cap1);
    destroy(rel2);
    destroy(cap2);
    destroy(registry);
}

// === Authorization ===

#[test, expected_failure(abort_code = EUnauthorized, location = miso::release)]
fun test_uid_mut_wrong_cap_aborts() {
    let ctx = &mut tx_context::dummy();
    let (mut rel1, cap1) = test_release(ctx);
    let (rel2, cap2) = test_release(ctx);

    let _uid = rel1.uid_mut(&cap2);

    destroy(rel1);
    destroy(cap1);
    destroy(rel2);
    destroy(cap2);
}

// === Views ===

#[test]
fun test_views() {
    let ctx = &mut tx_context::dummy();
    let (rel, cap) = test_release(ctx);

    assert!(rel.is_initialized_state());
    assert!(!rel.is_published_state());
    assert_eq!(*rel.title(), b"Album".to_string());
    assert_eq!(rel.tracks().length(), 1);
    assert_eq!(cap.release_id(), rel.id());

    destroy(rel);
    destroy(cap);
}

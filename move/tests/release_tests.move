#[test_only]
module musicos::release_tests;

use musicos::disc;
use musicos::release;
use musicos::test_helpers;
use musicos::track;
use std::unit_test::{assert_eq, destroy};

// Error codes from release.move
const EUnauthorized: u64 = 0;
const EInvalidTrackSplitsSum: u64 = 20;
const EMaxDiscsExceeded: u64 = 30;
const EMaxTracksExceeded: u64 = 31;
const EMaxTitleLengthExceeded: u64 = 34;
const EEmptyString: u64 = 35;
const EMaxSubtitleLengthExceeded: u64 = 36;
const ENoDiscs: u64 = 51;

// Must match release.move
const MAX_DISCS: u64 = 20;
const MAX_TRACKS: u64 = 255;
const MAX_TITLE_LENGTH: u64 = 300;
const MAX_SUBTITLE_LENGTH: u64 = 300;

/// Helper to create a single test track.
fun test_track(ctx: &mut TxContext): track::Track {
    track::new_for_testing(
        test_helpers::fake_id(ctx),
        test_helpers::fake_id(ctx),
        10000, // 100% split (single track)
    )
}

/// Helper to create a disc with n tracks that share splits evenly.
fun test_disc_with_n_tracks(n: u64, split_bps: u16, ctx: &mut TxContext): disc::Disc {
    let mut tracks = vector[];
    n.do!(|_| {
        tracks.push_back(track::new_for_testing(
            test_helpers::fake_id(ctx),
            test_helpers::fake_id(ctx),
            split_bps,
        ));
    });
    disc::new(tracks, option::none())
}

// === Title Length ===

#[test, expected_failure(abort_code = EMaxTitleLengthExceeded, location = musicos::release)]
fun test_new_title_too_long() {
    let ctx = &mut tx_context::dummy();
    let mut registry = release::new_release_registry_for_testing(ctx);
    let discs = vector[disc::new(vector[test_track(ctx)], option::none())];
    let (rel, cap) = release::new(
        test_helpers::long_string(MAX_TITLE_LENGTH + 1),
        discs,
        0u256,
        &mut registry,
    );
    destroy(rel);
    destroy(cap);
    destroy(registry);
}

// === Max Discs ===

#[test, expected_failure(abort_code = EMaxDiscsExceeded, location = musicos::release)]
fun test_new_exceeds_max_discs() {
    let ctx = &mut tx_context::dummy();
    let mut registry = release::new_release_registry_for_testing(ctx);

    // Create MAX_DISCS + 1 discs, each with 1 track
    // Total tracks = 21, splits: 21 tracks need to sum to 10000 BPS
    // Use 476 BPS each (476 * 21 = 9996) + 4 extra on the last = 10000
    let mut discs = vector[];
    (MAX_DISCS + 1).do!(|i| {
        let split = if (i < MAX_DISCS) 476 else 480;
        discs.push_back(test_disc_with_n_tracks(1, split, ctx));
    });

    let (rel, cap) = release::new(
        b"Too Many Discs".to_string(),
        discs,
        0u256,
        &mut registry,
    );
    destroy(rel);
    destroy(cap);
    destroy(registry);
}

// === Max Tracks ===

#[test, expected_failure(abort_code = EMaxTracksExceeded, location = musicos::release)]
fun test_new_exceeds_max_tracks() {
    let ctx = &mut tx_context::dummy();
    let mut registry = release::new_release_registry_for_testing(ctx);

    // Create MAX_TRACKS + 1 tracks across multiple discs (each disc holds up to 50)
    let total_tracks = MAX_TRACKS + 1; // 256
    let num_full_discs = total_tracks / 50; // 5 full discs of 50
    let remainder = total_tracks % 50; // 6 leftover tracks
    let num_discs = if (remainder > 0) num_full_discs + 1 else num_full_discs;
    // Splits: 256 tracks, 39 BPS each = 9984. First 16 get 40 BPS (16 extra = 10000).
    let mut discs = vector[];
    let mut global_idx = 0u64;
    let mut d = 0u64;
    while (d < num_discs) {
        let n_tracks: u64 = if (d < num_full_discs) 50 else remainder;
        let mut tracks = vector[];
        let mut t = 0u64;
        while (t < n_tracks) {
            let split = if (global_idx < 16) 40 else 39;
            tracks.push_back(track::new_for_testing(
                test_helpers::fake_id(ctx),
                test_helpers::fake_id(ctx),
                split,
            ));
            global_idx = global_idx + 1;
            t = t + 1;
        };
        discs.push_back(disc::new(tracks, option::none()));
        d = d + 1;
    };

    let (rel, cap) = release::new(
        b"Too Many Tracks".to_string(),
        discs,
        0u256,
        &mut registry,
    );
    destroy(rel);
    destroy(cap);
    destroy(registry);
}

// === Subtitle ===

/// Helper to create a minimal release for subtitle tests.
fun test_release(ctx: &mut TxContext): (release::Release, release::ReleaseAdminCap) {
    release::new_for_testing(
        b"Album".to_string(),
        vector[test_disc_with_n_tracks(1, 10000, ctx)],
        ctx,
    )
}

#[test]
fun test_set_subtitle() {
    let ctx = &mut tx_context::dummy();
    let (mut rel, cap) = test_release(ctx);

    rel.set_subtitle(&cap, b"Deluxe Edition".to_string());
    assert_eq!(*rel.subtitle(), option::some(b"Deluxe Edition".to_string()));

    destroy(rel);
    destroy(cap);
}

#[test]
fun test_set_subtitle_twice() {
    let ctx = &mut tx_context::dummy();
    let (mut rel, cap) = test_release(ctx);

    rel.set_subtitle(&cap, b"Deluxe Edition".to_string());
    rel.set_subtitle(&cap, b"Remastered".to_string());
    assert_eq!(*rel.subtitle(), option::some(b"Remastered".to_string()));

    destroy(rel);
    destroy(cap);
}

#[test]
fun test_set_subtitle_at_max_length() {
    let ctx = &mut tx_context::dummy();
    let (mut rel, cap) = test_release(ctx);

    rel.set_subtitle(&cap, test_helpers::long_string(MAX_SUBTITLE_LENGTH));
    assert!(rel.subtitle().is_some());

    destroy(rel);
    destroy(cap);
}

#[test, expected_failure(abort_code = EEmptyString, location = musicos::release)]
fun test_set_subtitle_empty() {
    let ctx = &mut tx_context::dummy();
    let (mut rel, cap) = test_release(ctx);

    rel.set_subtitle(&cap, b"".to_string());

    destroy(rel);
    destroy(cap);
}

#[test, expected_failure(abort_code = EMaxSubtitleLengthExceeded, location = musicos::release)]
fun test_set_subtitle_too_long() {
    let ctx = &mut tx_context::dummy();
    let (mut rel, cap) = test_release(ctx);

    rel.set_subtitle(&cap, test_helpers::long_string(MAX_SUBTITLE_LENGTH + 1));

    destroy(rel);
    destroy(cap);
}

// === Creation Validation ===

#[test, expected_failure(abort_code = EEmptyString, location = musicos::release)]
fun test_new_empty_title() {
    let ctx = &mut tx_context::dummy();
    let mut registry = release::new_release_registry_for_testing(ctx);
    let discs = vector[disc::new(vector[test_track(ctx)], option::none())];
    let (rel, cap) = release::new(
        b"".to_string(),
        discs,
        0u256,
        &mut registry,
    );
    destroy(rel);
    destroy(cap);
    destroy(registry);
}

#[test, expected_failure(abort_code = ENoDiscs, location = musicos::release)]
fun test_new_no_discs() {
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

#[test, expected_failure(abort_code = EInvalidTrackSplitsSum, location = musicos::release)]
fun test_new_splits_below_total() {
    let ctx = &mut tx_context::dummy();
    let mut registry = release::new_release_registry_for_testing(ctx);
    let discs = vector[test_disc_with_n_tracks(1, 9999, ctx)]; // 99.99%
    let (rel, cap) = release::new(
        b"Underweight".to_string(),
        discs,
        0u256,
        &mut registry,
    );
    destroy(rel);
    destroy(cap);
    destroy(registry);
}

#[test, expected_failure(abort_code = EInvalidTrackSplitsSum, location = musicos::release)]
fun test_new_splits_above_total() {
    let ctx = &mut tx_context::dummy();
    let mut registry = release::new_release_registry_for_testing(ctx);
    let discs = vector[test_disc_with_n_tracks(2, 5001, ctx)]; // 100.02%
    let (rel, cap) = release::new(
        b"Overweight".to_string(),
        discs,
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

    let disc1 = disc::new(
        vector[track::new_for_testing(rec_id, rel_id, 10000)],
        option::none(),
    );
    let disc2 = disc::new(
        vector[track::new_for_testing(rec_id, rel_id, 10000)],
        option::none(),
    );

    let (rel1, cap1) = release::new(
        b"First".to_string(),
        vector[disc1],
        7u256,
        &mut registry,
    );
    // Identical recording ids, splits, and nonce: identical digest.
    let (rel2, cap2) = release::new(
        b"Second".to_string(),
        vector[disc2],
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

#[test, expected_failure(abort_code = EUnauthorized, location = musicos::release)]
fun test_set_subtitle_wrong_cap_aborts() {
    let ctx = &mut tx_context::dummy();
    let (mut rel1, cap1) = test_release(ctx);
    let (rel2, cap2) = test_release(ctx);

    rel1.set_subtitle(&cap2, b"Hijacked".to_string());

    destroy(rel1);
    destroy(cap1);
    destroy(rel2);
    destroy(cap2);
}

#[test, expected_failure(abort_code = EUnauthorized, location = musicos::release)]
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
    assert_eq!(rel.total_tracks(), 1);
    assert_eq!(cap.release_id(), rel.id());

    destroy(rel);
    destroy(cap);
}

#[test_only]
module musicos::release_tests;

use partyos::credit;
use musicos::disc;
use musicos::release;
use musicos::release_kind;
use musicos::release_party_role;
use musicos::test_helpers::{Self, CompositionShare, RecordingShare, V};
use musicos::track;
use std::unit_test::destroy;

// Error codes from release.move
const EMaxDiscsExceeded: u64 = 30;
const EMaxTracksExceeded: u64 = 31;
const EMaxDescriptionLengthExceeded: u64 = 32;
const EMaxCreditsExceeded: u64 = 33;
const EMaxTitleLengthExceeded: u64 = 34;

// Must match release.move
const MAX_DESCRIPTION_LENGTH: u64 = 500;
const MAX_DISCS: u64 = 20;
const MAX_TRACKS: u64 = 255;
const MAX_CREDITS: u64 = 50;
const MAX_TITLE_LENGTH: u64 = 300;

/// Helper to create a single test track.
fun test_track(ctx: &mut TxContext): track::Track {
    track::new_for_testing<CompositionShare, RecordingShare, V>(
        test_helpers::fake_id(ctx),
        test_helpers::fake_id(ctx),
        test_helpers::fake_id(ctx),
        b"Track".to_string(),
        180000,
        test_helpers::cover_art(),
        10000, // 100% split (single track)
        5000,
    )
}

/// Helper to create a disc with n tracks that share splits evenly.
fun test_disc_with_n_tracks(n: u64, split_bps: u64, ctx: &mut TxContext): disc::Disc {
    let mut tracks = vector[];
    n.do!(|_| {
        tracks.push_back(track::new_for_testing<CompositionShare, RecordingShare, V>(
            test_helpers::fake_id(ctx),
            test_helpers::fake_id(ctx),
            test_helpers::fake_id(ctx),
            b"Track".to_string(),
            180000,
            test_helpers::cover_art(),
            split_bps,
            5000,
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
        release_kind::new_album_kind(),
        test_helpers::long_string(MAX_TITLE_LENGTH + 1),
        b"Description".to_string(),
        test_helpers::cover_art(),
        discs,
        0u256,
        &mut registry,
        ctx,
    );
    destroy(rel);
    destroy(cap);
    destroy(registry);
}

// === Description Length ===

#[test, expected_failure(abort_code = EMaxDescriptionLengthExceeded, location = musicos::release)]
fun test_new_description_too_long() {
    let ctx = &mut tx_context::dummy();
    let mut registry = release::new_release_registry_for_testing(ctx);
    let discs = vector[disc::new(vector[test_track(ctx)], option::none())];
    let (rel, cap) = release::new(
        release_kind::new_album_kind(),
        b"Title".to_string(),
        test_helpers::long_string(MAX_DESCRIPTION_LENGTH + 1),
        test_helpers::cover_art(),
        discs,
        0u256,
        &mut registry,
        ctx,
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
        release_kind::new_album_kind(),
        b"Too Many Discs".to_string(),
        b"Description".to_string(),
        test_helpers::cover_art(),
        discs,
        0u256,
        &mut registry,
        ctx,
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
            tracks.push_back(track::new_for_testing<CompositionShare, RecordingShare, V>(
                test_helpers::fake_id(ctx),
                test_helpers::fake_id(ctx),
                test_helpers::fake_id(ctx),
                b"Track".to_string(),
                180000,
                test_helpers::cover_art(),
                split,
                5000,
            ));
            global_idx = global_idx + 1;
            t = t + 1;
        };
        discs.push_back(disc::new(tracks, option::none()));
        d = d + 1;
    };

    let (rel, cap) = release::new(
        release_kind::new_album_kind(),
        b"Too Many Tracks".to_string(),
        b"Description".to_string(),
        test_helpers::cover_art(),
        discs,
        0u256,
        &mut registry,
        ctx,
    );
    destroy(rel);
    destroy(cap);
    destroy(registry);
}

// === Max Credits ===

#[test, expected_failure(abort_code = EMaxCreditsExceeded, location = musicos::release)]
fun test_add_credit_exceeds_max() {
    let ctx = &mut tx_context::dummy();
    let discs = vector[disc::new(vector[test_track(ctx)], option::none())];
    let (mut rel, cap) = release::new_for_testing(
        release_kind::new_album_kind(),
        b"Title".to_string(),
        b"Description".to_string(),
        test_helpers::cover_art(),
        discs,
        ctx,
    );

    // Pre-fill to MAX_CREDITS
    rel.prefill_credits_for_testing(MAX_CREDITS, ctx);

    // One more should fail
    let (party, party_cap) = test_helpers::individual(ctx);
    rel.add_credit(
        &cap,
        &party,
        credit::new(
            b"One Too Many".to_string(),
            vector[release_party_role::new_featured_role()],
        ),
    );

    destroy(party);
    destroy(party_cap);
    destroy(rel);
    destroy(cap);
}

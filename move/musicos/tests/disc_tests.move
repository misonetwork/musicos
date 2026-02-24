#[test_only]
module musicos::disc_tests;

use musicos::disc;
use musicos::test_helpers::{Self, CompositionShare, RecordingShare, V};
use musicos::track;
use std::unit_test::{assert_eq, destroy};

// Error codes from disc.move
const EMaxTracksExceeded: u64 = 30;

// Must match disc.move
const MAX_TRACKS_PER_DISC: u64 = 50;

/// Helper to create a test track.
fun test_track(ctx: &mut TxContext): track::Track {
    track::new_for_testing<CompositionShare, RecordingShare, V>(
        test_helpers::fake_id(ctx),
        test_helpers::fake_id(ctx),
        test_helpers::fake_id(ctx),
        b"Track".to_string(),
        180000,
        test_helpers::cover_art(),
        10000,
        5000,
    )
}

#[test]
fun test_new_at_max_tracks() {
    let ctx = &mut tx_context::dummy();

    let mut tracks = vector[];
    MAX_TRACKS_PER_DISC.do!(|_| {
        tracks.push_back(test_track(ctx));
    });

    let d = disc::new(tracks, option::none());
    assert_eq!(d.tracks().length(), MAX_TRACKS_PER_DISC);
    destroy(d);
}

#[test, expected_failure(abort_code = EMaxTracksExceeded, location = musicos::disc)]
fun test_new_exceeds_max_tracks() {
    let ctx = &mut tx_context::dummy();

    let mut tracks = vector[];
    (MAX_TRACKS_PER_DISC + 1).do!(|_| {
        tracks.push_back(test_track(ctx));
    });

    let d = disc::new(tracks, option::none());
    destroy(d);
}

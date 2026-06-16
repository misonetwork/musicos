#[test_only]
module musicos::disc_tests;

use musicos::disc;
use musicos::test_helpers;
use musicos::track;
use std::unit_test::{assert_eq, destroy};

// Error codes from disc.move
const EMaxTracksExceeded: u64 = 30;
const EMaxTitleLengthExceeded: u64 = 31;
const EEmptyString: u64 = 32;

// Must match disc.move
const MAX_TRACKS_PER_DISC: u64 = 50;
const MAX_TITLE_LENGTH: u64 = 300;

/// Helper to create a test track.
fun test_track(ctx: &mut TxContext): track::Track {
    track::new_for_testing(
        test_helpers::fake_id(ctx),
        test_helpers::fake_id(ctx),
        10000,
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

// === Title ===

#[test]
fun test_new_with_title() {
    let ctx = &mut tx_context::dummy();
    let d = disc::new(vector[test_track(ctx)], option::some(b"Disc One".to_string()));
    assert_eq!(*d.title(), option::some(b"Disc One".to_string()));
    destroy(d);
}

#[test, expected_failure(abort_code = EEmptyString, location = musicos::disc)]
fun test_new_empty_title() {
    let ctx = &mut tx_context::dummy();
    let d = disc::new(vector[test_track(ctx)], option::some(b"".to_string()));
    destroy(d);
}

#[test, expected_failure(abort_code = EMaxTitleLengthExceeded, location = musicos::disc)]
fun test_new_title_too_long() {
    let ctx = &mut tx_context::dummy();
    let d = disc::new(
        vector[test_track(ctx)],
        option::some(test_helpers::long_string(MAX_TITLE_LENGTH + 1)),
    );
    destroy(d);
}

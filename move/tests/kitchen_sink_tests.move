#[test_only]
module musicos::kitchen_sink_tests;

use musicos::disc;
use musicos::recording;
use musicos::release;
use musicos::test_helpers::{Self, CompositionShare, RecordingShare};
use musicos::track;
use std::unit_test::destroy;

// === Tests ===

/// Kitchen sink test: creates a recording with the embedded fields at maximum
/// bounds.
/// - title_version at 100 bytes (MAX_TITLE_VERSION_LENGTH)
/// - subtitle at 200 bytes (MAX_SUBTITLE_LENGTH)
/// - Successfully publishes
#[test]
fun test_recording_kitchen_sink() {
    let ctx = &mut tx_context::dummy();

    // Create recording
    let (mut rec, cap) = recording::new_for_testing<RecordingShare, CompositionShare>(
        b"Kitchen Sink Recording".to_string(),
        ctx,
    );

    // Set all optional fields at max bounds
    rec.set_title_version(&cap, test_helpers::long_string(100)); // MAX_TITLE_VERSION_LENGTH
    rec.set_subtitle(&cap, test_helpers::long_string(200));       // MAX_SUBTITLE_LENGTH

    // Publish - proves all max bounds are achievable together
    let clock = sui::clock::create_for_testing(ctx);
    rec.publish(&cap, &clock);

    // Cleanup
    clock.destroy_for_testing();
    destroy(cap);
}

/// Kitchen sink test: creates a release with the structural fields at maximum
/// bounds.
/// - 20 discs (MAX_DISCS) with 255 total tracks (MAX_TRACKS)
///   - 15 discs x 13 tracks = 195, 5 discs x 12 tracks = 60, total = 255
/// - Track splits sum to exactly 10000 BPS (55 x 40 + 200 x 39 = 10000)
/// - Title at 300 bytes (MAX_TITLE_LENGTH)
/// - Successfully publishes
#[test]
fun test_release_kitchen_sink() {
    let ctx = &mut tx_context::dummy();

    // Build 255 tracks distributed across 20 discs.
    // Split math: 55 x 40 BPS + 200 x 39 BPS = 2200 + 7800 = 10000 BPS (100%)
    // Disc math: 15 discs x 13 tracks + 5 discs x 12 tracks = 195 + 60 = 255
    // Tracks are created with a dummy release_id; release::new_for_testing patches them.
    let dummy_release_id = test_helpers::fake_id(ctx);
    let mut discs = vector[];
    let mut global_idx: u64 = 0;

    // First 15 discs with 13 tracks each
    let mut d: u64 = 0;
    while (d < 15) {
        let mut disc_tracks = vector[];
        let mut t: u64 = 0;
        while (t < 13) {
            let split_bps = if (global_idx < 55) 40 else 39;
            disc_tracks.push_back(track::new_for_testing(
                test_helpers::fake_id(ctx),
                dummy_release_id,
                split_bps,
            ));
            global_idx = global_idx + 1;
            t = t + 1;
        };
        discs.push_back(disc::new(disc_tracks, option::none()));
        d = d + 1;
    };

    // Last 5 discs with 12 tracks each
    d = 0;
    while (d < 5) {
        let mut disc_tracks = vector[];
        let mut t: u64 = 0;
        while (t < 12) {
            let split_bps = if (global_idx < 55) 40 else 39;
            disc_tracks.push_back(track::new_for_testing(
                test_helpers::fake_id(ctx),
                dummy_release_id,
                split_bps,
            ));
            global_idx = global_idx + 1;
            t = t + 1;
        };
        discs.push_back(disc::new(disc_tracks, option::none()));
        d = d + 1;
    };

    // Create release with max title.
    // new_for_testing patches all tracks to point to the real release ID.
    let (rel, rel_cap) = release::new_for_testing(
        test_helpers::long_string(300), // MAX_TITLE_LENGTH
        discs,
        ctx,
    );

    // Publish - proves all max bounds are achievable together
    let clock = sui::clock::create_for_testing(ctx);
    rel.publish(&rel_cap, &clock);

    // Cleanup
    clock.destroy_for_testing();
    destroy(rel_cap);
}

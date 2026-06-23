#[test_only]
module miso::recording_tests;

use miso::composition;
use miso::recording;
use miso::test_helpers::{Self, RecordingShare, CompositionShare};
use std::unit_test::destroy;

// Error codes from recording.move
const EMaxTitleVersionLengthExceeded: u64 = 36;
const EMaxSubtitleLengthExceeded: u64 = 37;
const EEmptyString: u64 = 38;

// Must match recording.move
const MAX_TITLE_VERSION_LENGTH: u64 = 100;
const MAX_SUBTITLE_LENGTH: u64 = 300;

/// Helper to create a test recording.
fun new_test_recording(ctx: &mut TxContext): (
    recording::Recording<RecordingShare, CompositionShare>,
    recording::RecordingAdminCap<RecordingShare>,
) {
    recording::new_for_testing<RecordingShare, CompositionShare>(
        b"Test Song".to_string(),
        ctx,
    )
}

// === String Bounds ===

#[test]
fun test_set_title_version() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, cap) = new_test_recording(ctx);

    rec.set_title_version(&cap, b"Radio Edit".to_string());
    assert!(rec.title_version().is_some());

    destroy(rec);
    destroy(cap);
}

#[test]
fun test_set_title_version_at_max_length() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, cap) = new_test_recording(ctx);

    rec.set_title_version(&cap, test_helpers::long_string(MAX_TITLE_VERSION_LENGTH));
    assert!(rec.title_version().is_some());

    destroy(rec);
    destroy(cap);
}

#[test, expected_failure(abort_code = EEmptyString, location = miso::recording)]
fun test_set_title_version_empty() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, cap) = new_test_recording(ctx);
    rec.set_title_version(&cap, b"".to_string());
    destroy(rec);
    destroy(cap);
}

#[test, expected_failure(abort_code = EMaxTitleVersionLengthExceeded, location = miso::recording)]
fun test_set_title_version_too_long() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, cap) = new_test_recording(ctx);
    rec.set_title_version(&cap, test_helpers::long_string(MAX_TITLE_VERSION_LENGTH + 1));
    destroy(rec);
    destroy(cap);
}

#[test]
fun test_set_subtitle() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, cap) = new_test_recording(ctx);

    rec.set_subtitle(&cap, b"A Love Song".to_string());
    assert!(rec.subtitle().is_some());

    destroy(rec);
    destroy(cap);
}

#[test]
fun test_set_subtitle_at_max_length() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, cap) = new_test_recording(ctx);

    rec.set_subtitle(&cap, test_helpers::long_string(MAX_SUBTITLE_LENGTH));
    assert!(rec.subtitle().is_some());

    destroy(rec);
    destroy(cap);
}

#[test, expected_failure(abort_code = EEmptyString, location = miso::recording)]
fun test_set_subtitle_empty() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, cap) = new_test_recording(ctx);
    rec.set_subtitle(&cap, b"".to_string());
    destroy(rec);
    destroy(cap);
}

#[test, expected_failure(abort_code = EMaxSubtitleLengthExceeded, location = miso::recording)]
fun test_set_subtitle_too_long() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, cap) = new_test_recording(ctx);
    rec.set_subtitle(&cap, test_helpers::long_string(MAX_SUBTITLE_LENGTH + 1));
    destroy(rec);
    destroy(cap);
}


// === Publish ===

#[test]
fun test_publish_recording() {
    let ctx = &mut tx_context::dummy();
    let (rec, cap) = new_test_recording(ctx);

    let clock = sui::clock::create_for_testing(ctx);
    rec.publish(&cap, &clock);

    clock.destroy_for_testing();
    destroy(cap);
}

// === Title Version / Subtitle can be updated (swap_or_fill) ===

#[test]
fun test_set_title_version_twice() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, cap) = new_test_recording(ctx);

    rec.set_title_version(&cap, b"Radio Edit".to_string());
    rec.set_title_version(&cap, b"Extended Mix".to_string());
    assert!(rec.title_version().is_some());

    destroy(rec);
    destroy(cap);
}

#[test]
fun test_set_subtitle_twice() {
    let ctx = &mut tx_context::dummy();
    let (mut rec, cap) = new_test_recording(ctx);

    rec.set_subtitle(&cap, b"First Subtitle".to_string());
    rec.set_subtitle(&cap, b"Updated Subtitle".to_string());
    assert!(rec.subtitle().is_some());

    destroy(rec);
    destroy(cap);
}

// Recordings are independent objects (fresh `object::new`), not derived children
// keyed by a per-composition index: two recordings created under one composition
// have distinct ids and require no contiguity/derivation. Concurrency- and
// id-independence behavior is covered by `production_constructor_tests`.

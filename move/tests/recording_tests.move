#[test_only]
module miso::recording_tests;

use miso::recording;
use miso::test_helpers::{RecordingShare, CompositionShare};
use std::unit_test::destroy;

/// Helper to create a test recording.
fun new_test_recording(ctx: &mut TxContext): (
    recording::Recording<RecordingShare, CompositionShare>,
    recording::RecordingAdminCap<RecordingShare>,
) {
    recording::new_for_testing<RecordingShare, CompositionShare>(ctx)
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

// A recording carries no naming fields: its display title is its composition's
// title, read by reference, and richer naming lives in the metadata extension.
// Naming behavior is therefore untestable here by design.

// Recordings are independent objects (fresh `object::new`), not derived children
// keyed by a per-composition index: two recordings created under one composition
// have distinct ids and require no contiguity/derivation. Concurrency- and
// id-independence behavior is covered by `production_constructor_tests`.

#[test_only]
module miso::deal_tests;

use miso::composition;
use miso::deal;
use miso::recording;
use miso::test_helpers::{Self, CompositionShare, RecordingShare};
use miso::track;
use std::unit_test::{assert_eq, destroy};

/// Helper: a composition and a recording of it, with their admin caps.
fun composition_and_recording(
    ctx: &mut TxContext,
): (
    composition::Composition<CompositionShare>,
    composition::CompositionAdminCap<CompositionShare>,
    recording::Recording<RecordingShare, CompositionShare>,
    recording::RecordingAdminCap<RecordingShare>,
) {
    let (comp, comp_cap) =
        composition::new_for_testing<CompositionShare>(b"Song".to_string(), 1500, ctx);
    let (rec, rec_cap) = recording::new_for_testing<RecordingShare, CompositionShare>(ctx);
    (comp, comp_cap, rec, rec_cap)
}

#[test]
fun test_new_with_defaults() {
    let ctx = &mut tx_context::dummy();
    let (comp, comp_cap, rec, rec_cap) = composition_and_recording(ctx);
    let release_id = test_helpers::fake_id(ctx);

    let d = deal::new(
        &rec_cap,
        &rec,
        release_id,
        10000,
        ctx,
    );

    assert_eq!(d.release_id(), release_id);
    assert_eq!(d.track_split_bps().value(), 10000);

    d.reject();
    destroy(comp);
    destroy(comp_cap);
    destroy(rec);
    destroy(rec_cap);
}

// === Lifecycle Events ===

#[test]
fun test_reject_emits_rejected_event() {
    let ctx = &mut tx_context::dummy();
    let (comp, comp_cap, rec, rec_cap) = composition_and_recording(ctx);

    let d = deal::new(
        &rec_cap,
        &rec,
        test_helpers::fake_id(ctx),
        10000,
        ctx,
    );
    d.reject();

    assert_eq!(sui::event::events_by_type<deal::DealRejectedEvent<RecordingShare, CompositionShare>>().length(), 1);
    assert_eq!(sui::event::events_by_type<deal::DealAcceptedEvent<RecordingShare, CompositionShare>>().length(), 0);

    destroy(comp);
    destroy(comp_cap);
    destroy(rec);
    destroy(rec_cap);
}

#[test]
fun test_accept_via_track_new_emits_accepted_event() {
    let ctx = &mut tx_context::dummy();
    let (comp, comp_cap, rec, rec_cap) = composition_and_recording(ctx);
    let release_id = test_helpers::fake_id(ctx);

    let d = deal::new(
        &rec_cap,
        &rec,
        release_id,
        10000,
        ctx,
    );

    // Accepting = consuming the deal into a track via the production constructor.
    let t = track::new(d, &rec);
    assert_eq!(t.recording_id(), rec.id());
    assert_eq!(t.split_bps().value(), 10000);
    assert!(t.is_unassigned_state());
    assert!(!t.is_assigned_state());

    assert_eq!(sui::event::events_by_type<deal::DealAcceptedEvent<RecordingShare, CompositionShare>>().length(), 1);
    assert_eq!(sui::event::events_by_type<deal::DealRejectedEvent<RecordingShare, CompositionShare>>().length(), 0);

    destroy(t);
    destroy(comp);
    destroy(comp_cap);
    destroy(rec);
    destroy(rec_cap);
}

#[test, expected_failure(abort_code = 0, location = bps::bps)] // bps EOverflow
fun test_new_split_above_100_percent_aborts() {
    let ctx = &mut tx_context::dummy();
    let (comp, _comp_cap, rec, rec_cap) = composition_and_recording(ctx);

    let d = deal::new(
        &rec_cap,
        &rec,
        test_helpers::fake_id(ctx),
        10001, // > 10_000 BPS
        ctx,
    );

    d.reject();
    destroy(comp);
    destroy(_comp_cap);
    destroy(rec);
    destroy(rec_cap);
}

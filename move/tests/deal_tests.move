#[test_only]
module musicos::deal_tests;

use musicos::composition;
use musicos::deal;
use musicos::recording;
use musicos::test_helpers::{Self, CompositionShare, RecordingShare};
use musicos::track;
use std::unit_test::{assert_eq, destroy};

// Error codes from deal.move
const ECompositionIdMismatch: u64 = 0;
const EMaxTrackTitleLengthExceeded: u64 = 30;
const EEmptyString: u64 = 31;

// Must match deal.move
const MAX_TRACK_TITLE_LENGTH: u64 = 300;

/// Helper: a composition and a recording of it, with their admin caps.
fun composition_and_recording(
    ctx: &mut TxContext,
): (
    composition::Composition<CompositionShare>,
    composition::CompositionAdminCap<CompositionShare>,
    recording::Recording<RecordingShare>,
    recording::RecordingAdminCap<RecordingShare>,
) {
    let (comp, comp_cap) =
        composition::new_for_testing<CompositionShare>(b"Song".to_string(), 1500, ctx);
    let (rec, rec_cap) = recording::new_for_testing<RecordingShare>(
        b"Song".to_string(),
        comp.id(),
        1500,
        test_helpers::cover_art(),
        ctx,
    );
    (comp, comp_cap, rec, rec_cap)
}

#[test]
fun test_new_with_defaults() {
    let ctx = &mut tx_context::dummy();
    let (comp, comp_cap, rec, rec_cap) = composition_and_recording(ctx);
    let release_id = test_helpers::fake_id(ctx);

    let d = deal::new(
        &rec_cap,
        &comp,
        &rec,
        release_id,
        10000,
        option::none(),
        option::none(),
        ctx,
    );

    // Defaults are captured from the recording.
    assert_eq!(*d.track_title(), b"Song".to_string());
    assert_eq!(d.release_id(), release_id);
    assert_eq!(d.composition_id(), comp.id());
    assert_eq!(d.recording_id(), rec.id());
    assert_eq!(d.track_split_bps().value(), 10000);
    assert_eq!(d.composition_royalty_rate().value(), 1500);

    d.reject();
    destroy(comp);
    destroy(comp_cap);
    destroy(rec);
    destroy(rec_cap);
}

#[test]
fun test_new_with_title_override() {
    let ctx = &mut tx_context::dummy();
    let (comp, comp_cap, rec, rec_cap) = composition_and_recording(ctx);

    let d = deal::new(
        &rec_cap,
        &comp,
        &rec,
        test_helpers::fake_id(ctx),
        10000,
        option::some(b"Song (Live)".to_string()),
        option::none(),
        ctx,
    );

    assert_eq!(*d.track_title(), b"Song (Live)".to_string());

    d.reject();
    destroy(comp);
    destroy(comp_cap);
    destroy(rec);
    destroy(rec_cap);
}

#[test, expected_failure(abort_code = EEmptyString, location = musicos::deal)]
fun test_new_empty_title_override() {
    let ctx = &mut tx_context::dummy();
    let (comp, _comp_cap, rec, rec_cap) = composition_and_recording(ctx);

    let d = deal::new(
        &rec_cap,
        &comp,
        &rec,
        test_helpers::fake_id(ctx),
        10000,
        option::some(b"".to_string()),
        option::none(),
        ctx,
    );

    d.reject();
    destroy(comp);
    destroy(_comp_cap);
    destroy(rec);
    destroy(rec_cap);
}

#[test, expected_failure(abort_code = EMaxTrackTitleLengthExceeded, location = musicos::deal)]
fun test_new_title_override_too_long() {
    let ctx = &mut tx_context::dummy();
    let (comp, _comp_cap, rec, rec_cap) = composition_and_recording(ctx);

    let d = deal::new(
        &rec_cap,
        &comp,
        &rec,
        test_helpers::fake_id(ctx),
        10000,
        option::some(test_helpers::long_string(MAX_TRACK_TITLE_LENGTH + 1)),
        option::none(),
        ctx,
    );

    d.reject();
    destroy(comp);
    destroy(_comp_cap);
    destroy(rec);
    destroy(rec_cap);
}

#[test, expected_failure(abort_code = ECompositionIdMismatch, location = musicos::deal)]
fun test_new_composition_mismatch() {
    let ctx = &mut tx_context::dummy();
    let (comp, comp_cap) =
        composition::new_for_testing<CompositionShare>(b"Song".to_string(), 1500, ctx);

    // A recording that points at a different composition.
    let (rec, rec_cap) = recording::new_for_testing<RecordingShare>(
        b"Other Song".to_string(),
        test_helpers::fake_id(ctx),
        1500,
        test_helpers::cover_art(),
        ctx,
    );

    let d = deal::new(
        &rec_cap,
        &comp,
        &rec,
        test_helpers::fake_id(ctx),
        10000,
        option::none(),
        option::none(),
        ctx,
    );

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
        &comp,
        &rec,
        test_helpers::fake_id(ctx),
        10000,
        option::none(),
        option::none(),
        ctx,
    );
    d.reject();

    assert_eq!(sui::event::events_by_type<deal::DealRejectedEvent>().length(), 1);
    assert_eq!(sui::event::events_by_type<deal::DealAcceptedEvent>().length(), 0);

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
        &comp,
        &rec,
        release_id,
        10000,
        option::none(),
        option::none(),
        ctx,
    );

    // Accepting = consuming the deal into a track via the production constructor.
    let t = track::new(d);
    assert_eq!(t.recording_id(), rec.id());
    assert_eq!(t.composition_id(), comp.id());
    assert_eq!(*t.title(), b"Song".to_string());
    assert_eq!(t.split_bps().value(), 10000);
    assert!(t.is_unassigned_state());
    assert!(!t.is_assigned_state());
    assert_eq!(*t.composition_share_type(), std::type_name::with_defining_ids<CompositionShare>());
    assert_eq!(*t.recording_share_type(), std::type_name::with_defining_ids<RecordingShare>());
    assert_eq!(t.cover_art().still().blob_id(), 1);

    assert_eq!(sui::event::events_by_type<deal::DealAcceptedEvent>().length(), 1);
    assert_eq!(sui::event::events_by_type<deal::DealRejectedEvent>().length(), 0);

    destroy(t);
    destroy(comp);
    destroy(comp_cap);
    destroy(rec);
    destroy(rec_cap);
}

#[test]
fun test_new_with_cover_art_override() {
    let ctx = &mut tx_context::dummy();
    let (comp, comp_cap, rec, rec_cap) = composition_and_recording(ctx);

    let override_art = musicos::cover_art::new(
        ori::walrus_data::new_blob(77),
        option::some(ori::walrus_data::new_blob(78)), // animated branch of DealCreatedEvent
    );
    let d = deal::new(
        &rec_cap,
        &comp,
        &rec,
        test_helpers::fake_id(ctx),
        10000,
        option::none(),
        option::some(override_art),
        ctx,
    );

    assert_eq!(d.track_cover_art().still().blob_id(), 77);
    assert_eq!(d.track_cover_art().animated().borrow().blob_id(), 78);

    d.reject();
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
        &comp,
        &rec,
        test_helpers::fake_id(ctx),
        10001, // > 10_000 BPS
        option::none(),
        option::none(),
        ctx,
    );

    d.reject();
    destroy(comp);
    destroy(_comp_cap);
    destroy(rec);
    destroy(rec_cap);
}

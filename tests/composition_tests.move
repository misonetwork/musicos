#[test_only]
module miso::composition_tests;

use miso::composition;
use miso::test_helpers::{Self, CompositionShare};
use std::unit_test::{assert_eq, destroy};

// Error codes from composition.move
const EAboveMaxRoyaltyRate: u64 = 22;
const EMaxTitleLengthExceeded: u64 = 33;
const EEmptyString: u64 = 35;

// Must match composition.move
const MAX_TITLE_LENGTH: u64 = 300;

// === Lifecycle ===

#[test]
fun test_new_composition() {
    let ctx = &mut tx_context::dummy();
    let (comp, cap) = composition::new_for_testing<CompositionShare>(
        b"My Song".to_string(),
        1500,
        ctx,
    );
    assert_eq!(*comp.title(), b"My Song".to_string());
    destroy(comp);
    destroy(cap);
}

#[test]
fun test_new_composition_title_at_max_length() {
    let ctx = &mut tx_context::dummy();
    let title = test_helpers::long_string(MAX_TITLE_LENGTH);
    let (comp, cap) = composition::new_for_testing<CompositionShare>(title, 1500, ctx);
    assert_eq!(comp.title().length(), MAX_TITLE_LENGTH);
    destroy(comp);
    destroy(cap);
}

#[test]
fun test_publish_composition() {
    let ctx = &mut tx_context::dummy();
    let (comp, cap) = composition::new_for_testing<CompositionShare>(b"My Song".to_string(), 1500, ctx);

    // Publish
    let clock = sui::clock::create_for_testing(ctx);
    comp.publish(&cap, &clock);

    clock.destroy_for_testing();
    destroy(cap);
}

// === Royalty rate ===

#[test]
fun test_set_royalty_rate() {
    let ctx = &mut tx_context::dummy();
    let (mut comp, cap) = composition::new_for_testing<CompositionShare>(b"My Song".to_string(), 1500, ctx);
    let composition_id = comp.id();

    comp.set_royalty_rate(&cap, 2000, ctx);
    assert_eq!(comp.royalty_rate().value(), 2000);

    let mut events = sui::event::events_by_type<
        composition::CompositionRoyaltySetEvent<CompositionShare>,
    >();
    assert_eq!(events.length(), 1);
    let (event_composition_id, previous_rate, rate, changed_by) =
        composition::royalty_set_event_fields(events.pop_back());
    assert_eq!(event_composition_id, composition_id);
    assert_eq!(previous_rate, 1500);
    assert_eq!(rate, 2000);
    assert_eq!(changed_by, ctx.sender());

    destroy(comp);
    destroy(cap);
}

/// There is no rate-change cooldown: back-to-back changes in the same
/// transaction all take effect (recorders are protected by the snapshot at
/// recording creation plus the `max_royalty_rate_bps` slippage guard).
#[test]
fun test_set_royalty_rate_repeatedly() {
    let ctx = &mut tx_context::dummy();
    let (mut comp, cap) = composition::new_for_testing<CompositionShare>(b"My Song".to_string(), 1500, ctx);

    comp.set_royalty_rate(&cap, 1200, ctx);
    comp.set_royalty_rate(&cap, 1800, ctx);
    assert_eq!(comp.royalty_rate().value(), 1800);

    destroy(comp);
    destroy(cap);
}

#[test]
fun test_set_royalty_rate_to_zero() {
    let ctx = &mut tx_context::dummy();
    let (mut comp, cap) = composition::new_for_testing<CompositionShare>(b"My Song".to_string(), 1500, ctx);
    comp.set_royalty_rate(&cap, 0, ctx); // no floor — 0% is allowed
    assert_eq!(comp.royalty_rate().value(), 0);
    destroy(comp);
    destroy(cap);
}

#[test, expected_failure(abort_code = EAboveMaxRoyaltyRate, location = miso::composition)]
fun test_set_royalty_rate_above_cap() {
    let ctx = &mut tx_context::dummy();
    let (mut comp, cap) = composition::new_for_testing<CompositionShare>(b"My Song".to_string(), 1500, ctx);
    comp.set_royalty_rate(&cap, 2001, ctx); // above 20% cap
    destroy(comp);
    destroy(cap);
}

#[test]
fun test_new_at_zero_and_cap() {
    let ctx = &mut tx_context::dummy();
    let (comp_zero, cap_zero) =
        composition::new_for_testing<CompositionShare>(b"My Song".to_string(), 0, ctx);
    let (comp_cap, cap_cap) =
        composition::new_for_testing<CompositionShare>(b"My Song".to_string(), 2000, ctx);
    assert_eq!(comp_zero.royalty_rate().value(), 0);
    assert_eq!(comp_cap.royalty_rate().value(), 2000);
    destroy(comp_zero);
    destroy(cap_zero);
    destroy(comp_cap);
    destroy(cap_cap);
}

#[test, expected_failure(abort_code = EAboveMaxRoyaltyRate, location = miso::composition)]
fun test_new_above_cap() {
    let ctx = &mut tx_context::dummy();
    let (comp, cap) = composition::new_for_testing<CompositionShare>(b"My Song".to_string(), 2001, ctx);
    destroy(comp);
    destroy(cap);
}

// === Boundary Error Conditions ===

#[test, expected_failure(abort_code = EEmptyString, location = miso::composition)]
fun test_new_empty_title() {
    let ctx = &mut tx_context::dummy();
    let (comp, cap) = composition::new_for_testing<CompositionShare>(b"".to_string(), 1500, ctx);
    destroy(comp);
    destroy(cap);
}

#[test, expected_failure(abort_code = EMaxTitleLengthExceeded, location = miso::composition)]
fun test_new_title_too_long() {
    let ctx = &mut tx_context::dummy();
    let (comp, cap) = composition::new_for_testing<CompositionShare>(
        test_helpers::long_string(MAX_TITLE_LENGTH + 1),
        1500,
        ctx,
    );
    destroy(comp);
    destroy(cap);
}

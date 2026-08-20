#[test_only]
module miso::composition_tests;

use miso::composition;
use miso::test_helpers::{Self, CompositionShare};
use std::unit_test::{assert_eq, destroy};

// Error codes from composition.move
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

// The royalty rate is immutable — set once in `new`, no setter exists. The
// tests below pin the accepted range at creation: [0, 10000], no floor, no
// protocol ceiling; whether a rate is acceptable is a recorder's client-side
// concern.

/// There is no protocol ceiling on the rate — any value up to 100% is valid.
#[test]
fun test_new_above_former_cap() {
    let ctx = &mut tx_context::dummy();
    let (comp, cap) =
        composition::new_for_testing<CompositionShare>(b"My Song".to_string(), 8000, ctx);
    assert_eq!(comp.royalty_rate().value(), 8000);
    destroy(comp);
    destroy(cap);
}

#[test]
fun test_new_at_zero_and_max() {
    let ctx = &mut tx_context::dummy();
    let (comp_zero, cap_zero) =
        composition::new_for_testing<CompositionShare>(b"My Song".to_string(), 0, ctx);
    let (comp_max, cap_max) =
        composition::new_for_testing<CompositionShare>(b"My Song".to_string(), 10000, ctx);
    assert_eq!(comp_zero.royalty_rate().value(), 0);
    assert_eq!(comp_max.royalty_rate().value(), 10000);
    destroy(comp_zero);
    destroy(cap_zero);
    destroy(comp_max);
    destroy(cap_max);
}

#[test, expected_failure(abort_code = 0, location = bps::bps)] // bps::EOverflow
fun test_new_above_100_percent() {
    let ctx = &mut tx_context::dummy();
    let (comp, cap) = composition::new_for_testing<CompositionShare>(b"My Song".to_string(), 10001, ctx);
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

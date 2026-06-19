#[test_only]
module miso::composition_tests;

use miso::composition;
use miso::test_helpers::{Self, CompositionShare};
use std::unit_test::{assert_eq, destroy};

// Error codes from composition.move
const ERoyaltyRateCooldown: u64 = 11;
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

    // A rate set in epoch N is changeable from epoch N+2 onward.
    ctx.increment_epoch_number();
    ctx.increment_epoch_number();
    comp.set_royalty_rate(&cap, 2000, ctx);
    assert_eq!(comp.royalty_rate().value(), 2000);
    assert_eq!(comp.royalty_rate_last_changed_epoch(), ctx.epoch());

    destroy(comp);
    destroy(cap);
}

#[test]
fun test_set_royalty_rate_after_full_epoch_elapsed() {
    let ctx = &mut tx_context::dummy();
    let (mut comp, cap) = composition::new_for_testing<CompositionShare>(b"My Song".to_string(), 1500, ctx);

    ctx.increment_epoch_number();
    ctx.increment_epoch_number();
    comp.set_royalty_rate(&cap, 1200, ctx);
    ctx.increment_epoch_number();
    ctx.increment_epoch_number();
    comp.set_royalty_rate(&cap, 1800, ctx);
    assert_eq!(comp.royalty_rate().value(), 1800);

    destroy(comp);
    destroy(cap);
}

#[test, expected_failure(abort_code = ERoyaltyRateCooldown, location = miso::composition)]
fun test_set_royalty_rate_in_creation_epoch() {
    let ctx = &mut tx_context::dummy();
    let (mut comp, cap) = composition::new_for_testing<CompositionShare>(b"My Song".to_string(), 1500, ctx);
    // The creation epoch counts as the rate's last change.
    comp.set_royalty_rate(&cap, 2000, ctx);
    destroy(comp);
    destroy(cap);
}

#[test, expected_failure(abort_code = ERoyaltyRateCooldown, location = miso::composition)]
fun test_set_royalty_rate_one_epoch_after_creation() {
    let ctx = &mut tx_context::dummy();
    let (mut comp, cap) = composition::new_for_testing<CompositionShare>(b"My Song".to_string(), 1500, ctx);

    // One epoch is not enough: the rate must live one *full* epoch first.
    ctx.increment_epoch_number();
    comp.set_royalty_rate(&cap, 2000, ctx);

    destroy(comp);
    destroy(cap);
}

#[test, expected_failure(abort_code = ERoyaltyRateCooldown, location = miso::composition)]
fun test_set_royalty_rate_one_epoch_after_change() {
    let ctx = &mut tx_context::dummy();
    let (mut comp, cap) = composition::new_for_testing<CompositionShare>(b"My Song".to_string(), 1500, ctx);

    ctx.increment_epoch_number();
    ctx.increment_epoch_number();
    comp.set_royalty_rate(&cap, 1200, ctx);
    ctx.increment_epoch_number();
    comp.set_royalty_rate(&cap, 1800, ctx); // only one epoch since the change

    destroy(comp);
    destroy(cap);
}

#[test]
fun test_set_royalty_rate_to_zero() {
    let ctx = &mut tx_context::dummy();
    let (mut comp, cap) = composition::new_for_testing<CompositionShare>(b"My Song".to_string(), 1500, ctx);
    ctx.increment_epoch_number();
    ctx.increment_epoch_number();
    comp.set_royalty_rate(&cap, 0, ctx); // no floor — 0% is allowed
    assert_eq!(comp.royalty_rate().value(), 0);
    destroy(comp);
    destroy(cap);
}

#[test, expected_failure(abort_code = EAboveMaxRoyaltyRate, location = miso::composition)]
fun test_set_royalty_rate_above_cap() {
    let ctx = &mut tx_context::dummy();
    let (mut comp, cap) = composition::new_for_testing<CompositionShare>(b"My Song".to_string(), 1500, ctx);
    ctx.increment_epoch_number();
    ctx.increment_epoch_number();
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

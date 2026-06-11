#[test_only]
module musicos::composition_tests;

use musicos::composition;
use musicos::composition_party_role;
use partyos::credit;
use musicos::test_helpers::{Self, CompositionShare};
use std::unit_test::{assert_eq, destroy};

// Error codes from composition.move
const ERoyaltyRateCooldown: u64 = 11;
const EMinRolesNotMet: u64 = 20;
const EExceedsMaxRoles: u64 = 30;
const EBelowMinRoyaltyRate: u64 = 21;
const EAboveMaxRoyaltyRate: u64 = 22;
const EMaxCreditsExceeded: u64 = 32;
const EMaxTitleLengthExceeded: u64 = 33;
const EEmptyString: u64 = 35;
const EPartyAlreadyCredited: u64 = 40;
const ENoParties: u64 = 50;

// Must match composition.move
const MAX_CREDITS: u64 = 50;
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
    assert!(comp.credits().is_empty());
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
    let (mut comp, cap) = composition::new_for_testing<CompositionShare>(b"My Song".to_string(), 1500, ctx);

    // Add a credit (required for publish)
    let (party, party_cap) = test_helpers::individual(ctx);
    let cred = credit::new(
        b"Artist".to_string(),
        vector[composition_party_role::new_composer_role()],
    );
    comp.add_credit(&cap, &party, cred);

    // Publish
    let clock = sui::clock::create_for_testing(ctx);
    comp.publish(&cap, &clock);

    clock.destroy_for_testing();
    destroy(cap);
    destroy(party);
    destroy(party_cap);
}

// Note: In the expected_failure test (test_publish_no_parties), cap cleanup is
// not needed because the abort handles value cleanup automatically.

// === Credits ===

#[test]
fun test_add_credit() {
    let ctx = &mut tx_context::dummy();
    let (mut comp, cap) = composition::new_for_testing<CompositionShare>(b"My Song".to_string(), 1500, ctx);
    let (party, party_cap) = test_helpers::individual(ctx);

    let cred = credit::new(
        b"Artist".to_string(),
        vector[composition_party_role::new_composer_role()],
    );
    comp.add_credit(&cap, &party, cred);

    assert_eq!(comp.credits().length(), 1);

    destroy(comp);
    destroy(cap);
    destroy(party);
    destroy(party_cap);
}

#[test]
fun test_add_credit_with_max_roles() {
    let ctx = &mut tx_context::dummy();
    let (mut comp, cap) = composition::new_for_testing<CompositionShare>(b"My Song".to_string(), 1500, ctx);
    let (party, party_cap) = test_helpers::individual(ctx);

    // Create credit with MAX_ROLES_PER_PARTY roles (all distinct)
    let roles = vector[
        composition_party_role::new_adapter_role(),
        composition_party_role::new_arranger_role(),
        composition_party_role::new_composer_role(),
        composition_party_role::new_lyricist_role(),
        composition_party_role::new_songwriter_role(),
    ];
    // 5 distinct roles matching MAX_ROLES_PER_PARTY = 5
    let cred = credit::new(b"Artist".to_string(), roles);
    comp.add_credit(&cap, &party, cred);

    assert_eq!(comp.credits().length(), 1);

    destroy(comp);
    destroy(cap);
    destroy(party);
    destroy(party_cap);
}

#[test]
fun test_add_max_credits() {
    let ctx = &mut tx_context::dummy();
    let (mut comp, cap) = composition::new_for_testing<CompositionShare>(b"My Song".to_string(), 1500, ctx);

    MAX_CREDITS.do!(|_| {
        let (party, party_cap) = test_helpers::individual(ctx);
        let cred = credit::new(
            b"Artist".to_string(),
            vector[composition_party_role::new_composer_role()],
        );
        comp.add_credit(&cap, &party, cred);
        destroy(party);
        destroy(party_cap);
    });

    assert_eq!(comp.credits().length(), MAX_CREDITS);

    destroy(comp);
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

#[test, expected_failure(abort_code = ERoyaltyRateCooldown, location = musicos::composition)]
fun test_set_royalty_rate_in_creation_epoch() {
    let ctx = &mut tx_context::dummy();
    let (mut comp, cap) = composition::new_for_testing<CompositionShare>(b"My Song".to_string(), 1500, ctx);
    // The creation epoch counts as the rate's last change.
    comp.set_royalty_rate(&cap, 2000, ctx);
    destroy(comp);
    destroy(cap);
}

#[test, expected_failure(abort_code = ERoyaltyRateCooldown, location = musicos::composition)]
fun test_set_royalty_rate_one_epoch_after_creation() {
    let ctx = &mut tx_context::dummy();
    let (mut comp, cap) = composition::new_for_testing<CompositionShare>(b"My Song".to_string(), 1500, ctx);

    // One epoch is not enough: the rate must live one *full* epoch first.
    ctx.increment_epoch_number();
    comp.set_royalty_rate(&cap, 2000, ctx);

    destroy(comp);
    destroy(cap);
}

#[test, expected_failure(abort_code = ERoyaltyRateCooldown, location = musicos::composition)]
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

#[test, expected_failure(abort_code = EBelowMinRoyaltyRate, location = musicos::composition)]
fun test_set_royalty_rate_below_floor() {
    let ctx = &mut tx_context::dummy();
    let (mut comp, cap) = composition::new_for_testing<CompositionShare>(b"My Song".to_string(), 1500, ctx);
    ctx.increment_epoch_number();
    ctx.increment_epoch_number();
    comp.set_royalty_rate(&cap, 999, ctx); // below 10% floor
    destroy(comp);
    destroy(cap);
}

#[test, expected_failure(abort_code = EAboveMaxRoyaltyRate, location = musicos::composition)]
fun test_set_royalty_rate_above_cap() {
    let ctx = &mut tx_context::dummy();
    let (mut comp, cap) = composition::new_for_testing<CompositionShare>(b"My Song".to_string(), 1500, ctx);
    ctx.increment_epoch_number();
    ctx.increment_epoch_number();
    comp.set_royalty_rate(&cap, 2001, ctx); // above 20% cap
    destroy(comp);
    destroy(cap);
}

#[test, expected_failure(abort_code = EBelowMinRoyaltyRate, location = musicos::composition)]
fun test_new_below_floor() {
    let ctx = &mut tx_context::dummy();
    let (comp, cap) = composition::new_for_testing<CompositionShare>(b"My Song".to_string(), 500, ctx);
    destroy(comp);
    destroy(cap);
}

#[test]
fun test_new_at_floor_and_cap() {
    let ctx = &mut tx_context::dummy();
    let (comp_floor, cap_floor) =
        composition::new_for_testing<CompositionShare>(b"My Song".to_string(), 1000, ctx);
    let (comp_cap, cap_cap) =
        composition::new_for_testing<CompositionShare>(b"My Song".to_string(), 2000, ctx);
    assert_eq!(comp_floor.royalty_rate().value(), 1000);
    assert_eq!(comp_cap.royalty_rate().value(), 2000);
    destroy(comp_floor);
    destroy(cap_floor);
    destroy(comp_cap);
    destroy(cap_cap);
}

#[test, expected_failure(abort_code = EAboveMaxRoyaltyRate, location = musicos::composition)]
fun test_new_above_cap() {
    let ctx = &mut tx_context::dummy();
    let (comp, cap) = composition::new_for_testing<CompositionShare>(b"My Song".to_string(), 2001, ctx);
    destroy(comp);
    destroy(cap);
}

// === Boundary Error Conditions ===

#[test, expected_failure(abort_code = EEmptyString, location = musicos::composition)]
fun test_new_empty_title() {
    let ctx = &mut tx_context::dummy();
    let (comp, cap) = composition::new_for_testing<CompositionShare>(b"".to_string(), 1500, ctx);
    destroy(comp);
    destroy(cap);
}

#[test, expected_failure(abort_code = EMaxTitleLengthExceeded, location = musicos::composition)]
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

#[test, expected_failure(abort_code = EMaxCreditsExceeded, location = musicos::composition)]
fun test_add_credit_exceeds_max() {
    let ctx = &mut tx_context::dummy();
    let (mut comp, cap) = composition::new_for_testing<CompositionShare>(b"My Song".to_string(), 1500, ctx);

    // Add MAX_CREDITS credits
    MAX_CREDITS.do!(|_| {
        let (party, party_cap) = test_helpers::individual(ctx);
        let cred = credit::new(
            b"Artist".to_string(),
            vector[composition_party_role::new_composer_role()],
        );
        comp.add_credit(&cap, &party, cred);
        destroy(party);
        destroy(party_cap);
    });

    // One more should fail
    let (party, party_cap) = test_helpers::individual(ctx);
    let cred = credit::new(
        b"One Too Many".to_string(),
        vector[composition_party_role::new_composer_role()],
    );
    comp.add_credit(&cap, &party, cred);

    destroy(party);
    destroy(party_cap);
    destroy(comp);
    destroy(cap);
}

// partyos::credit::new now rejects roleless credits before composition::add_credit runs.
#[test, expected_failure(abort_code = 32, location = partyos::credit)] // ENoRoles
fun test_add_credit_no_roles() {
    let ctx = &mut tx_context::dummy();
    let (mut comp, cap) = composition::new_for_testing<CompositionShare>(b"My Song".to_string(), 1500, ctx);
    let (party, party_cap) = test_helpers::individual(ctx);

    let cred = credit::new(b"Artist".to_string(), vector[]);
    comp.add_credit(&cap, &party, cred);

    destroy(comp);
    destroy(cap);
    destroy(party);
    destroy(party_cap);
}

#[test, expected_failure(abort_code = EPartyAlreadyCredited, location = musicos::composition)]
fun test_add_credit_duplicate_party() {
    let ctx = &mut tx_context::dummy();
    let (mut comp, cap) = composition::new_for_testing<CompositionShare>(b"My Song".to_string(), 1500, ctx);
    let (party, party_cap) = test_helpers::individual(ctx);

    let cred1 = credit::new(
        b"Artist".to_string(),
        vector[composition_party_role::new_composer_role()],
    );
    comp.add_credit(&cap, &party, cred1);

    let cred2 = credit::new(
        b"Artist".to_string(),
        vector[composition_party_role::new_lyricist_role()],
    );
    comp.add_credit(&cap, &party, cred2); // same party

    destroy(comp);
    destroy(cap);
    destroy(party);
    destroy(party_cap);
}

// === Publish Error Conditions ===

#[test, expected_failure(abort_code = ENoParties, location = musicos::composition)]
fun test_publish_no_parties() {
    let ctx = &mut tx_context::dummy();
    let (mut comp, cap) = composition::new_for_testing<CompositionShare>(b"My Song".to_string(), 1500, ctx);

    let clock = sui::clock::create_for_testing(ctx);
    comp.publish(&cap, &clock);

    clock.destroy_for_testing();
    destroy(cap);
}

#[test, expected_failure(abort_code = EExceedsMaxRoles, location = musicos::composition)]
fun test_add_credit_exceeds_max_roles() {
    let ctx = &mut tx_context::dummy();
    let (mut comp, cap) = composition::new_for_testing<CompositionShare>(b"My Song".to_string(), 1500, ctx);
    let (party, party_cap) = test_helpers::individual(ctx);

    // All six distinct roles: one more than MAX_ROLES_PER_PARTY (5).
    let cred = credit::new(b"Artist".to_string(), vector[
        composition_party_role::new_adapter_role(),
        composition_party_role::new_arranger_role(),
        composition_party_role::new_composer_role(),
        composition_party_role::new_lyricist_role(),
        composition_party_role::new_songwriter_role(),
        composition_party_role::new_translator_role(),
    ]);
    comp.add_credit(&cap, &party, cred);

    destroy(comp);
    destroy(cap);
    destroy(party);
    destroy(party_cap);
}

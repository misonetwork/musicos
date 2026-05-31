#[test_only]
module musicos::composition_tests;

use musicos::composition;
use musicos::composition_party_role;
use partyos::credit;
use musicos::test_helpers::{Self, CompositionShare};
use std::unit_test::{assert_eq, destroy};

// Error codes from composition.move
const EMinRolesNotMet: u64 = 20;
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
        5000,
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
    let (comp, cap) = composition::new_for_testing<CompositionShare>(title, 5000, ctx);
    assert_eq!(comp.title().length(), MAX_TITLE_LENGTH);
    destroy(comp);
    destroy(cap);
}

#[test]
fun test_publish_composition() {
    let ctx = &mut tx_context::dummy();
    let (mut comp, cap) = composition::new_for_testing<CompositionShare>(b"My Song".to_string(), 5000, ctx);

    // Add a credit (required for publish)
    let (party, party_cap) = test_helpers::individual(ctx);
    let cred = credit::new(
        b"Artist".to_string(),
        vector[composition_party_role::new_composer_role()],
    );
    comp.add_credit(&cap, &party, cred);

    // Publish
    let clock = sui::clock::create_for_testing(ctx);
    comp.publish(&cap, &clock, ctx);

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
    let (mut comp, cap) = composition::new_for_testing<CompositionShare>(b"My Song".to_string(), 5000, ctx);
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
    let (mut comp, cap) = composition::new_for_testing<CompositionShare>(b"My Song".to_string(), 5000, ctx);
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
    let (mut comp, cap) = composition::new_for_testing<CompositionShare>(b"My Song".to_string(), 5000, ctx);

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

// === Split ===

#[test]
fun test_set_split_bps() {
    let ctx = &mut tx_context::dummy();
    let (mut comp, cap) = composition::new_for_testing<CompositionShare>(b"My Song".to_string(), 5000, ctx);

    comp.set_split_bps(&cap, 3000);
    assert_eq!(comp.split_bps().value(), 3000);

    destroy(comp);
    destroy(cap);
}

// === Boundary Error Conditions ===

#[test, expected_failure(abort_code = EEmptyString, location = musicos::composition)]
fun test_new_empty_title() {
    let ctx = &mut tx_context::dummy();
    let (comp, cap) = composition::new_for_testing<CompositionShare>(b"".to_string(), 5000, ctx);
    destroy(comp);
    destroy(cap);
}

#[test, expected_failure(abort_code = EMaxTitleLengthExceeded, location = musicos::composition)]
fun test_new_title_too_long() {
    let ctx = &mut tx_context::dummy();
    let (comp, cap) = composition::new_for_testing<CompositionShare>(
        test_helpers::long_string(MAX_TITLE_LENGTH + 1),
        5000,
        ctx,
    );
    destroy(comp);
    destroy(cap);
}

#[test, expected_failure(abort_code = EMaxCreditsExceeded, location = musicos::composition)]
fun test_add_credit_exceeds_max() {
    let ctx = &mut tx_context::dummy();
    let (mut comp, cap) = composition::new_for_testing<CompositionShare>(b"My Song".to_string(), 5000, ctx);

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

#[test, expected_failure(abort_code = EMinRolesNotMet, location = musicos::composition)]
fun test_add_credit_no_roles() {
    let ctx = &mut tx_context::dummy();
    let (mut comp, cap) = composition::new_for_testing<CompositionShare>(b"My Song".to_string(), 5000, ctx);
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
    let (mut comp, cap) = composition::new_for_testing<CompositionShare>(b"My Song".to_string(), 5000, ctx);
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
    let (mut comp, cap) = composition::new_for_testing<CompositionShare>(b"My Song".to_string(), 5000, ctx);

    let clock = sui::clock::create_for_testing(ctx);
    comp.publish(&cap, &clock, ctx);

    clock.destroy_for_testing();
    destroy(cap);
}

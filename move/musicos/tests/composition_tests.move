#[test_only]
module musicos::composition_tests;

use musicos::composition;
use musicos::composition_party_role;
use musicos::credit;
use musicos::test_helpers::{Self, CompositionShare};
use std::unit_test::{assert_eq, destroy};
use ori::walrus_data;

// Error codes from composition.move
const EMinRolesNotMet: u64 = 20;
const EMaxAlternateTitlesExceeded: u64 = 31;
const EMaxCreditsExceeded: u64 = 32;
const EMaxTitleLengthExceeded: u64 = 33;
const EMaxAlternateTitleLengthExceeded: u64 = 34;
const EEmptyString: u64 = 35;
const EPartyAlreadyCredited: u64 = 40;
const ENoParties: u64 = 50;
const ENoContent: u64 = 51;

// Must match composition.move
const MAX_ALTERNATE_TITLES: u64 = 5;
const MAX_CREDITS: u64 = 50;
const MAX_TITLE_LENGTH: u64 = 300;
const MAX_ALTERNATE_TITLE_LENGTH: u64 = 300;

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
    assert!(comp.alternate_titles().is_empty());
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

    // Add content (required for publish)
    comp.set_lyrics(&cap, walrus_data::new_blob(1));

    // Publish
    let clock = sui::clock::create_for_testing(ctx);
    comp.publish(&cap, &clock);

    clock.destroy_for_testing();
    destroy(cap);
    destroy(party);
    destroy(party_cap);
}

// Note: In expected_failure tests (test_publish_no_parties, test_publish_no_content),
// cap cleanup is not needed because the abort handles value cleanup automatically.

// === Alternate Titles ===

#[test]
fun test_add_alternate_title() {
    let ctx = &mut tx_context::dummy();
    let (mut comp, cap) = composition::new_for_testing<CompositionShare>(b"My Song".to_string(), 5000, ctx);

    comp.add_alternate_title(&cap, b"Mi Cancion".to_string());
    assert_eq!(comp.alternate_titles().length(), 1);

    destroy(comp);
    destroy(cap);
}

#[test]
fun test_add_alternate_title_at_max_count() {
    let ctx = &mut tx_context::dummy();
    let (mut comp, cap) = composition::new_for_testing<CompositionShare>(b"My Song".to_string(), 5000, ctx);

    MAX_ALTERNATE_TITLES.do!(|i| {
        let mut title = b"Title ".to_string();
        title.append(i.to_string());
        comp.add_alternate_title(&cap, title);
    });

    assert_eq!(comp.alternate_titles().length(), MAX_ALTERNATE_TITLES);

    destroy(comp);
    destroy(cap);
}

#[test]
fun test_add_alternate_title_at_max_length() {
    let ctx = &mut tx_context::dummy();
    let (mut comp, cap) = composition::new_for_testing<CompositionShare>(b"My Song".to_string(), 5000, ctx);

    comp.add_alternate_title(&cap, test_helpers::long_string(MAX_ALTERNATE_TITLE_LENGTH));
    assert_eq!(comp.alternate_titles().length(), 1);

    destroy(comp);
    destroy(cap);
}

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

// === Content ===

#[test]
fun test_set_and_clear_content() {
    let ctx = &mut tx_context::dummy();
    let (mut comp, cap) = composition::new_for_testing<CompositionShare>(b"My Song".to_string(), 5000, ctx);

    // Set lyrics
    comp.set_lyrics(&cap, walrus_data::new_blob(1));
    assert!(comp.lyrics().is_some());

    // Set chart
    comp.set_chart(&cap, walrus_data::new_blob(2));
    assert!(comp.chart().is_some());

    // Set score
    comp.set_score(&cap, walrus_data::new_blob(3));
    assert!(comp.score().is_some());

    // Set demo (requires verified Audio)
    comp.set_demo(&cap, test_helpers::audio());
    assert!(comp.demo().is_some());

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

#[test, expected_failure(abort_code = EEmptyString, location = musicos::composition)]
fun test_add_alternate_title_empty() {
    let ctx = &mut tx_context::dummy();
    let (mut comp, cap) = composition::new_for_testing<CompositionShare>(b"My Song".to_string(), 5000, ctx);
    comp.add_alternate_title(&cap, b"".to_string());
    destroy(comp);
    destroy(cap);
}

#[test, expected_failure(abort_code = EMaxAlternateTitleLengthExceeded, location = musicos::composition)]
fun test_add_alternate_title_too_long() {
    let ctx = &mut tx_context::dummy();
    let (mut comp, cap) = composition::new_for_testing<CompositionShare>(b"My Song".to_string(), 5000, ctx);
    comp.add_alternate_title(&cap, test_helpers::long_string(MAX_ALTERNATE_TITLE_LENGTH + 1));
    destroy(comp);
    destroy(cap);
}

#[test, expected_failure(abort_code = EMaxAlternateTitlesExceeded, location = musicos::composition)]
fun test_add_alternate_title_exceeds_max() {
    let ctx = &mut tx_context::dummy();
    let (mut comp, cap) = composition::new_for_testing<CompositionShare>(b"My Song".to_string(), 5000, ctx);

    // Fill to max
    MAX_ALTERNATE_TITLES.do!(|i| {
        let mut title = b"Title ".to_string();
        title.append(i.to_string());
        comp.add_alternate_title(&cap, title);
    });

    // One more should fail
    comp.add_alternate_title(&cap, b"One Too Many".to_string());

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
    comp.set_lyrics(&cap, walrus_data::new_blob(1));

    let clock = sui::clock::create_for_testing(ctx);
    comp.publish(&cap, &clock);

    clock.destroy_for_testing();
    destroy(cap);
}

#[test, expected_failure(abort_code = ENoContent, location = musicos::composition)]
fun test_publish_no_content() {
    let ctx = &mut tx_context::dummy();
    let (mut comp, cap) = composition::new_for_testing<CompositionShare>(b"My Song".to_string(), 5000, ctx);

    // Add a credit but no content
    let (party, party_cap) = test_helpers::individual(ctx);
    let cred = credit::new(
        b"Artist".to_string(),
        vector[composition_party_role::new_composer_role()],
    );
    comp.add_credit(&cap, &party, cred);

    let clock = sui::clock::create_for_testing(ctx);
    comp.publish(&cap, &clock);

    clock.destroy_for_testing();
    destroy(cap);
    destroy(party);
    destroy(party_cap);
}

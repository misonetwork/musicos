#[test_only]
module musicos::stem_tests;

use musicos::stem;
use musicos::test_helpers;
use std::unit_test::{assert_eq, destroy};

// Error codes from stem.move
const EMaxContributorsReached: u64 = 0;
const EContributorExists: u64 = 1;
const EContributorNotFound: u64 = 2;
const EMaxNameLengthExceeded: u64 = 3;
const EMaxDescriptionLengthExceeded: u64 = 4;
const EEmptyString: u64 = 5;

// Must match stem.move
const MAX_CONTRIBUTORS: u64 = 10;
const MAX_NAME_LENGTH: u64 = 100;
const MAX_DESCRIPTION_LENGTH: u64 = 500;

// === Happy Path ===

#[test]
fun test_new_valid_stem() {
    let s = stem::new(test_helpers::audio(), b"Vocals".to_string());
    assert_eq!(*s.name(), b"Vocals".to_string());
    assert!(s.description().is_none());
    assert!(s.contributors().is_empty());
}

#[test]
fun test_new_name_at_max_length() {
    let name = test_helpers::long_string(MAX_NAME_LENGTH);
    let s = stem::new(test_helpers::audio(), name);
    assert_eq!(s.name().length(), MAX_NAME_LENGTH);
}

#[test]
fun test_set_description() {
    let mut s = stem::new(test_helpers::audio(), b"Vocals".to_string());
    s.set_description(b"Lead Vocals".to_string());
    assert!(s.description().is_some());
}

#[test]
fun test_set_description_at_max_length() {
    let mut s = stem::new(test_helpers::audio(), b"Vocals".to_string());
    let desc = test_helpers::long_string(MAX_DESCRIPTION_LENGTH);
    s.set_description(desc);
    assert!(s.description().is_some());
}

#[test]
fun test_add_contributor() {
    let ctx = &mut tx_context::dummy();
    let (party, cap) = test_helpers::individual(ctx);
    let mut s = stem::new(test_helpers::audio(), b"Vocals".to_string());

    s.add_contributor(&party);

    assert_eq!(s.contributors().length(), 1);
    assert!(s.contributors().contains(&party.id()));

    destroy(party);
    destroy(cap);
}

#[test]
fun test_add_max_contributors() {
    let ctx = &mut tx_context::dummy();
    let mut s = stem::new(test_helpers::audio(), b"Vocals".to_string());
    let mut parties = vector[];
    let mut caps = vector[];

    MAX_CONTRIBUTORS.do!(|_| {
        let (party, cap) = test_helpers::individual(ctx);
        s.add_contributor(&party);
        parties.push_back(party);
        caps.push_back(cap);
    });

    assert_eq!(s.contributors().length(), MAX_CONTRIBUTORS);

    parties.destroy!(|p| destroy(p));
    caps.destroy!(|c| destroy(c));
}

#[test]
fun test_remove_contributor() {
    let ctx = &mut tx_context::dummy();
    let (party, cap) = test_helpers::individual(ctx);
    let mut s = stem::new(test_helpers::audio(), b"Vocals".to_string());

    s.add_contributor(&party);
    assert_eq!(s.contributors().length(), 1);

    s.remove_contributor(0);
    assert_eq!(s.contributors().length(), 0);

    destroy(party);
    destroy(cap);
}

// === Boundary Tests ===

#[test, expected_failure(abort_code = EMaxContributorsReached, location = musicos::stem)]
fun test_add_contributor_exceeds_max() {
    let ctx = &mut tx_context::dummy();
    let mut s = stem::new(test_helpers::audio(), b"Vocals".to_string());
    let mut parties = vector[];
    let mut caps = vector[];

    // Add MAX_CONTRIBUTORS
    MAX_CONTRIBUTORS.do!(|_| {
        let (party, cap) = test_helpers::individual(ctx);
        s.add_contributor(&party);
        parties.push_back(party);
        caps.push_back(cap);
    });

    // Adding one more should fail
    let (party, cap) = test_helpers::individual(ctx);
    s.add_contributor(&party);

    destroy(party);
    destroy(cap);
    parties.destroy!(|p| destroy(p));
    caps.destroy!(|c| destroy(c));
}

// === Error Conditions ===

#[test, expected_failure(abort_code = EEmptyString, location = musicos::stem)]
fun test_new_empty_name() {
    stem::new(test_helpers::audio(), b"".to_string());
}

#[test, expected_failure(abort_code = EMaxNameLengthExceeded, location = musicos::stem)]
fun test_new_name_too_long() {
    stem::new(test_helpers::audio(), test_helpers::long_string(MAX_NAME_LENGTH + 1));
}

#[test, expected_failure(abort_code = EEmptyString, location = musicos::stem)]
fun test_set_description_empty() {
    let mut s = stem::new(test_helpers::audio(), b"Vocals".to_string());
    s.set_description(b"".to_string());
}

#[test, expected_failure(abort_code = EMaxDescriptionLengthExceeded, location = musicos::stem)]
fun test_set_description_too_long() {
    let mut s = stem::new(test_helpers::audio(), b"Vocals".to_string());
    s.set_description(test_helpers::long_string(MAX_DESCRIPTION_LENGTH + 1));
}

/// Tests that set_description can only be called once (uses fill() not swap_or_fill()).
/// This documents the current behavior - description is write-once.
#[test, expected_failure]
fun test_set_description_twice() {
    let mut s = stem::new(test_helpers::audio(), b"Vocals".to_string());
    s.set_description(b"First".to_string());
    s.set_description(b"Second".to_string()); // should abort - fill() on Some
}

#[test, expected_failure(abort_code = EContributorExists, location = musicos::stem)]
fun test_add_contributor_duplicate() {
    let ctx = &mut tx_context::dummy();
    let (party, cap) = test_helpers::individual(ctx);
    let mut s = stem::new(test_helpers::audio(), b"Vocals".to_string());

    s.add_contributor(&party);
    s.add_contributor(&party); // duplicate

    destroy(party);
    destroy(cap);
}

#[test, expected_failure(abort_code = EContributorNotFound, location = musicos::stem)]
fun test_remove_contributor_out_of_bounds() {
    let mut s = stem::new(test_helpers::audio(), b"Vocals".to_string());
    s.remove_contributor(0); // no contributors
}

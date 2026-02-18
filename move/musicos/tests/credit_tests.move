#[test_only]
module musicos::credit_tests;

use musicos::composition_party_role;
use musicos::credit;
use musicos::test_helpers;
use std::unit_test::assert_eq;

// Error codes from credit.move
const EMaxDisplayNameLengthExceeded: u64 = 30;
const EEmptyString: u64 = 31;
const EDuplicateRoles: u64 = 40;

// Must match credit.move
const MAX_DISPLAY_NAME_LENGTH: u64 = 200;

// === Happy Path ===

#[test]
fun test_new_valid_credit() {
    let roles = vector[composition_party_role::new_composer_role()];
    let credit = credit::new(b"John Doe".to_string(), roles);
    assert_eq!(*credit.display_name(), b"John Doe".to_string());
    assert_eq!(credit.roles().length(), 1);
}

#[test]
fun test_new_multiple_roles() {
    let roles = vector[
        composition_party_role::new_composer_role(),
        composition_party_role::new_lyricist_role(),
        composition_party_role::new_songwriter_role(),
    ];
    let credit = credit::new(b"Jane Smith".to_string(), roles);
    assert_eq!(credit.roles().length(), 3);
}

#[test]
fun test_new_display_name_at_max_length() {
    let name = test_helpers::long_string(MAX_DISPLAY_NAME_LENGTH);
    let roles = vector[composition_party_role::new_composer_role()];
    let credit = credit::new(name, roles);
    assert_eq!(credit.display_name().length(), MAX_DISPLAY_NAME_LENGTH);
}

// === Error Conditions ===

#[test, expected_failure(abort_code = EEmptyString, location = musicos::credit)]
fun test_new_empty_display_name() {
    credit::new(
        b"".to_string(),
        vector[composition_party_role::new_composer_role()],
    );
}

#[test, expected_failure(abort_code = EMaxDisplayNameLengthExceeded, location = musicos::credit)]
fun test_new_display_name_too_long() {
    credit::new(
        test_helpers::long_string(MAX_DISPLAY_NAME_LENGTH + 1),
        vector[composition_party_role::new_composer_role()],
    );
}

#[test, expected_failure(abort_code = EDuplicateRoles, location = musicos::credit)]
fun test_new_duplicate_roles() {
    credit::new(
        b"John Doe".to_string(),
        vector[
            composition_party_role::new_composer_role(),
            composition_party_role::new_composer_role(),
        ],
    );
}

#[test_only]
module musicos::musical_key_tests;

use musicos::musical_key;
use std::unit_test::assert_eq;

// Error codes from musical_key.move
const EInvalidNote: u64 = 20;
const EInvalidAccidental: u64 = 21;
const EInvalidMode: u64 = 22;

// === Happy Path ===

#[test]
fun test_new_valid() {
    let key = musical_key::new(
        musical_key::new_note_c(),
        musical_key::new_accidental_natural(),
        musical_key::new_mode_major(),
    );
    assert_eq!(key.note(), musical_key::new_note_c());
    assert_eq!(key.accidental(), musical_key::new_accidental_natural());
    assert_eq!(key.mode(), musical_key::new_mode_major());
}

#[test]
fun test_new_f_sharp_minor() {
    let key = musical_key::new(
        musical_key::new_note_f(),
        musical_key::new_accidental_sharp(),
        musical_key::new_mode_minor(),
    );
    assert_eq!(key.note(), musical_key::new_note_f());
    assert_eq!(key.accidental(), musical_key::new_accidental_sharp());
    assert_eq!(key.mode(), musical_key::new_mode_minor());
}

#[test]
fun test_new_from_strings_valid() {
    let key = musical_key::new_from_strings(
        b"c".to_string(),
        b"natural".to_string(),
        b"major".to_string(),
    );
    assert_eq!(key.note(), musical_key::new_note_c());
    assert_eq!(key.accidental(), musical_key::new_accidental_natural());
    assert_eq!(key.mode(), musical_key::new_mode_major());
}

#[test]
fun test_new_from_strings_all_notes() {
    musical_key::new_from_strings(b"c".to_string(), b"natural".to_string(), b"major".to_string());
    musical_key::new_from_strings(b"d".to_string(), b"natural".to_string(), b"major".to_string());
    musical_key::new_from_strings(b"e".to_string(), b"natural".to_string(), b"major".to_string());
    musical_key::new_from_strings(b"f".to_string(), b"natural".to_string(), b"major".to_string());
    musical_key::new_from_strings(b"g".to_string(), b"natural".to_string(), b"major".to_string());
    musical_key::new_from_strings(b"a".to_string(), b"natural".to_string(), b"major".to_string());
    musical_key::new_from_strings(b"b".to_string(), b"natural".to_string(), b"major".to_string());
}

#[test]
fun test_new_from_strings_all_accidentals() {
    let natural = musical_key::new_from_strings(b"c".to_string(), b"natural".to_string(), b"major".to_string());
    assert_eq!(natural.accidental(), musical_key::new_accidental_natural());

    let sharp = musical_key::new_from_strings(b"f".to_string(), b"sharp".to_string(), b"minor".to_string());
    assert_eq!(sharp.accidental(), musical_key::new_accidental_sharp());

    let flat = musical_key::new_from_strings(b"b".to_string(), b"flat".to_string(), b"major".to_string());
    assert_eq!(flat.accidental(), musical_key::new_accidental_flat());
}

#[test]
fun test_new_from_strings_all_modes() {
    let major = musical_key::new_from_strings(b"c".to_string(), b"natural".to_string(), b"major".to_string());
    assert_eq!(major.mode(), musical_key::new_mode_major());

    let minor = musical_key::new_from_strings(b"a".to_string(), b"natural".to_string(), b"minor".to_string());
    assert_eq!(minor.mode(), musical_key::new_mode_minor());
}

// === Error Conditions ===

#[test, expected_failure(abort_code = EInvalidNote, location = musicos::musical_key)]
fun test_new_from_strings_invalid_note() {
    musical_key::new_from_strings(b"x".to_string(), b"natural".to_string(), b"major".to_string());
}

#[test, expected_failure(abort_code = EInvalidNote, location = musicos::musical_key)]
fun test_new_from_strings_uppercase_note() {
    musical_key::new_from_strings(b"C".to_string(), b"natural".to_string(), b"major".to_string());
}

#[test, expected_failure(abort_code = EInvalidAccidental, location = musicos::musical_key)]
fun test_new_from_strings_invalid_accidental() {
    musical_key::new_from_strings(b"c".to_string(), b"double_sharp".to_string(), b"major".to_string());
}

#[test, expected_failure(abort_code = EInvalidMode, location = musicos::musical_key)]
fun test_new_from_strings_invalid_mode() {
    musical_key::new_from_strings(b"c".to_string(), b"natural".to_string(), b"dorian".to_string());
}

#[test_only]
module musicos::genre_tests;

use musicos::genre;
use musicos::test_helpers;
use std::unit_test::destroy;

// Error codes from genre.move
const EInvalidCharacter: u64 = 20;
const EMaxNameLengthExceeded: u64 = 21;

// Must match genre.move
const MAX_NAME_LENGTH: u64 = 50;

// === Happy Path ===

#[test]
fun test_new_genre() {
    let ctx = &mut tx_context::dummy();
    let mut registry = genre::new_genre_registry_for_testing(ctx);

    genre::new(b"COUNTRY".to_string(), &mut registry);

    destroy(registry);
}

#[test]
fun test_new_genre_with_underscore() {
    let ctx = &mut tx_context::dummy();
    let mut registry = genre::new_genre_registry_for_testing(ctx);

    genre::new(b"DRUM_AND_BASS".to_string(), &mut registry);

    destroy(registry);
}

#[test]
fun test_genre_name_at_max_length() {
    let ctx = &mut tx_context::dummy();
    let mut registry = genre::new_genre_registry_for_testing(ctx);

    // Create a 50-character genre name (all uppercase A's)
    let name = test_helpers::long_string(MAX_NAME_LENGTH);
    genre::new(name, &mut registry);

    destroy(registry);
}

// === Error Conditions ===

#[test, expected_failure(abort_code = EInvalidCharacter, location = musicos::genre)]
fun test_genre_name_empty() {
    let ctx = &mut tx_context::dummy();
    let mut registry = genre::new_genre_registry_for_testing(ctx);

    genre::new(b"".to_string(), &mut registry);

    destroy(registry);
}

#[test, expected_failure(abort_code = EMaxNameLengthExceeded, location = musicos::genre)]
fun test_genre_name_too_long() {
    let ctx = &mut tx_context::dummy();
    let mut registry = genre::new_genre_registry_for_testing(ctx);

    genre::new(test_helpers::long_string(MAX_NAME_LENGTH + 1), &mut registry);

    destroy(registry);
}

#[test, expected_failure(abort_code = EInvalidCharacter, location = musicos::genre)]
fun test_genre_name_lowercase() {
    let ctx = &mut tx_context::dummy();
    let mut registry = genre::new_genre_registry_for_testing(ctx);

    genre::new(b"rock".to_string(), &mut registry);

    destroy(registry);
}

#[test, expected_failure(abort_code = EInvalidCharacter, location = musicos::genre)]
fun test_genre_name_with_space() {
    let ctx = &mut tx_context::dummy();
    let mut registry = genre::new_genre_registry_for_testing(ctx);

    genre::new(b"HIP HOP".to_string(), &mut registry);

    destroy(registry);
}

#[test, expected_failure(abort_code = EInvalidCharacter, location = musicos::genre)]
fun test_genre_name_with_numbers() {
    let ctx = &mut tx_context::dummy();
    let mut registry = genre::new_genre_registry_for_testing(ctx);

    genre::new(b"POP123".to_string(), &mut registry);

    destroy(registry);
}

#[test, expected_failure(abort_code = EInvalidCharacter, location = musicos::genre)]
fun test_genre_name_with_special_chars() {
    let ctx = &mut tx_context::dummy();
    let mut registry = genre::new_genre_registry_for_testing(ctx);

    genre::new(b"ROCK&ROLL".to_string(), &mut registry);

    destroy(registry);
}

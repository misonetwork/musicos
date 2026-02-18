#[test_only]
module musicos::time_signature_tests;

use musicos::time_signature;
use std::unit_test::assert_eq;

// Error codes from time_signature.move
const EInvalidBeatsPerMeasure: u64 = 20;
const EInvalidBeatUnit: u64 = 21;

// === Happy Path ===

#[test]
fun test_new_common_time() {
    let ts = time_signature::new(4, 4);
    assert_eq!(ts.beats_per_measure(), 4);
    assert_eq!(ts.beat_unit(), 4);
}

#[test]
fun test_new_waltz_time() {
    let ts = time_signature::new(3, 4);
    assert_eq!(ts.beats_per_measure(), 3);
    assert_eq!(ts.beat_unit(), 4);
}

#[test]
fun test_new_compound_time() {
    let ts = time_signature::new(6, 8);
    assert_eq!(ts.beats_per_measure(), 6);
    assert_eq!(ts.beat_unit(), 8);
}

#[test]
fun test_new_max_values() {
    let ts = time_signature::new(255, 255);
    assert_eq!(ts.beats_per_measure(), 255);
    assert_eq!(ts.beat_unit(), 255);
}

// === Error Conditions ===

#[test, expected_failure(abort_code = EInvalidBeatsPerMeasure, location = musicos::time_signature)]
fun test_new_zero_beats_per_measure() {
    time_signature::new(0, 4);
}

#[test, expected_failure(abort_code = EInvalidBeatUnit, location = musicos::time_signature)]
fun test_new_zero_beat_unit() {
    time_signature::new(4, 0);
}

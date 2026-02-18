#[test_only]
module musicos::audio_tests;

use musicos::audio;
use musicos::test_helpers;
use std::unit_test::assert_eq;
use std::type_name;

// Error codes from audio.move
const EInvalidChannels: u64 = 21;
const EInvalidBitDepth: u64 = 22;
const EInvalidSampleRate: u64 = 23;
const EInvalidSamples: u64 = 24;
const ESamplesOverflow: u64 = 25;

/// Test witness type for verification tests.
public struct TestVerifierWitness() has drop;

// Must match audio.move
const MAX_SAMPLES: u64 = 18_446_744_073_709_551;

// === Happy Path ===

#[test]
fun test_new_and_verify() {
    let unverified = audio::new(
        2, 16, 44100, 441000,
        test_helpers::walrus(),
    );
    let audio = audio::verify(unverified, TestVerifierWitness());
    assert_eq!(audio.channels(), 2);
    assert_eq!(audio.bit_depth(), 16);
    assert_eq!(audio.sample_rate_hz(), 44100);
    assert_eq!(audio.samples(), 441000);
    assert_eq!(*audio.verifier_type(), type_name::with_defining_ids<TestVerifierWitness>());
}

#[test]
fun test_new_mono_audio() {
    let audio = audio::verify(audio::new(1, 16, 44100, 1000, test_helpers::walrus()), TestVerifierWitness());
    assert_eq!(audio.channels(), 1);
}

#[test]
fun test_new_all_valid_bit_depths() {
    let audio_8 = audio::verify(audio::new(1, 8, 44100, 1000, test_helpers::walrus()), TestVerifierWitness());
    assert_eq!(audio_8.bit_depth(), 8);

    let audio_16 = audio::verify(audio::new(1, 16, 44100, 1000, test_helpers::walrus()), TestVerifierWitness());
    assert_eq!(audio_16.bit_depth(), 16);

    let audio_24 = audio::verify(audio::new(1, 24, 44100, 1000, test_helpers::walrus()), TestVerifierWitness());
    assert_eq!(audio_24.bit_depth(), 24);

    let audio_32 = audio::verify(audio::new(1, 32, 44100, 1000, test_helpers::walrus()), TestVerifierWitness());
    assert_eq!(audio_32.bit_depth(), 32);
}

#[test]
fun test_new_samples_at_max() {
    let audio = audio::verify(audio::new(1, 16, 44100, MAX_SAMPLES, test_helpers::walrus()), TestVerifierWitness());
    assert_eq!(audio.samples(), MAX_SAMPLES);
}

#[test]
fun test_duration_ms() {
    // 44100 samples at 44100 Hz = exactly 1000 ms
    let audio = audio::verify(audio::new(2, 16, 44100, 44100, test_helpers::walrus()), TestVerifierWitness());
    assert_eq!(audio.duration_ms(), 1000);

    // 88200 samples at 44100 Hz = exactly 2000 ms
    let audio2 = audio::verify(audio::new(2, 16, 44100, 88200, test_helpers::walrus()), TestVerifierWitness());
    assert_eq!(audio2.duration_ms(), 2000);

    // 48000 samples at 48000 Hz = exactly 1000 ms
    let audio3 = audio::verify(audio::new(1, 24, 48000, 48000, test_helpers::walrus()), TestVerifierWitness());
    assert_eq!(audio3.duration_ms(), 1000);
}

#[test]
fun test_unverified_audio_accessors() {
    let unverified = audio::new(2, 24, 48000, 96000, test_helpers::walrus());
    assert_eq!(unverified.unverified_channels(), 2);
    assert_eq!(unverified.unverified_bit_depth(), 24);
    assert_eq!(unverified.unverified_sample_rate_hz(), 48000);
    assert_eq!(unverified.unverified_samples(), 96000);
    // Consume the hot potato
    audio::verify(unverified, TestVerifierWitness());
}

// === Error Conditions ===

#[test, expected_failure(abort_code = EInvalidChannels, location = musicos::audio)]
fun test_new_zero_channels() {
    audio::verify(audio::new(0, 16, 44100, 1000, test_helpers::walrus()), TestVerifierWitness());
}

#[test, expected_failure(abort_code = EInvalidBitDepth, location = musicos::audio)]
fun test_new_invalid_bit_depth_12() {
    audio::verify(audio::new(2, 12, 44100, 1000, test_helpers::walrus()), TestVerifierWitness());
}

#[test, expected_failure(abort_code = EInvalidBitDepth, location = musicos::audio)]
fun test_new_invalid_bit_depth_0() {
    audio::verify(audio::new(2, 0, 44100, 1000, test_helpers::walrus()), TestVerifierWitness());
}

#[test, expected_failure(abort_code = EInvalidSampleRate, location = musicos::audio)]
fun test_new_zero_sample_rate() {
    audio::verify(audio::new(2, 16, 0, 1000, test_helpers::walrus()), TestVerifierWitness());
}

#[test, expected_failure(abort_code = EInvalidSamples, location = musicos::audio)]
fun test_new_zero_samples() {
    audio::verify(audio::new(2, 16, 44100, 0, test_helpers::walrus()), TestVerifierWitness());
}

#[test, expected_failure(abort_code = ESamplesOverflow, location = musicos::audio)]
fun test_new_samples_overflow() {
    audio::verify(audio::new(2, 16, 44100, MAX_SAMPLES + 1, test_helpers::walrus()), TestVerifierWitness());
}

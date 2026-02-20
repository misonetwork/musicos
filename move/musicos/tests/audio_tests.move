#[test_only]
module musicos::audio_tests;

use musicos::audio;
use std::unit_test::assert_eq;
use std::type_name;
use walrus_data::walrus_data;

// Error codes from audio.move
const EInvalidChannels: u64 = 21;
const EInvalidBitDepth: u64 = 22;
const EInvalidSampleRate: u64 = 23;
const EInvalidSamples: u64 = 24;
const ESamplesOverflow: u64 = 25;

/// Test witness type for ingestion tests.
public struct TestIngesterWitness() has drop;

// Must match audio.move
const MAX_SAMPLES: u64 = 18_446_744_073_709_551;

/// Dummy 32-byte PCM digest for tests.
const DUMMY_PCM_DIGEST: vector<u8> = x"0000000000000000000000000000000000000000000000000000000000000000";

// === Happy Path ===

#[test]
fun test_new() {
    let audio = audio::new(
        2, 16, 44100, 441000,
        DUMMY_PCM_DIGEST,
        walrus_data::new_blob(1),
        TestIngesterWitness(),
    );
    assert_eq!(audio.channels(), 2);
    assert_eq!(audio.bit_depth(), 16);
    assert_eq!(audio.sample_rate_hz(), 44100);
    assert_eq!(audio.samples(), 441000);
    assert_eq!(audio.data().blob_id(), 1);
    assert_eq!(*audio.ingester_type(), type_name::with_defining_ids<TestIngesterWitness>());
}

#[test]
fun test_new_mono_audio() {
    let audio = audio::new(1, 16, 44100, 1000, DUMMY_PCM_DIGEST, walrus_data::new_blob(1), TestIngesterWitness());
    assert_eq!(audio.channels(), 1);
}

#[test]
fun test_new_all_valid_bit_depths() {
    let audio_8 = audio::new(1, 8, 44100, 1000, DUMMY_PCM_DIGEST, walrus_data::new_blob(1), TestIngesterWitness());
    assert_eq!(audio_8.bit_depth(), 8);

    let audio_16 = audio::new(1, 16, 44100, 1000, DUMMY_PCM_DIGEST, walrus_data::new_blob(1), TestIngesterWitness());
    assert_eq!(audio_16.bit_depth(), 16);

    let audio_24 = audio::new(1, 24, 44100, 1000, DUMMY_PCM_DIGEST, walrus_data::new_blob(1), TestIngesterWitness());
    assert_eq!(audio_24.bit_depth(), 24);

    let audio_32 = audio::new(1, 32, 44100, 1000, DUMMY_PCM_DIGEST, walrus_data::new_blob(1), TestIngesterWitness());
    assert_eq!(audio_32.bit_depth(), 32);
}

#[test]
fun test_new_samples_at_max() {
    let audio = audio::new(1, 16, 44100, MAX_SAMPLES, DUMMY_PCM_DIGEST, walrus_data::new_blob(1), TestIngesterWitness());
    assert_eq!(audio.samples(), MAX_SAMPLES);
}

#[test]
fun test_duration_ms() {
    // 44100 samples at 44100 Hz = exactly 1000 ms
    let audio = audio::new(2, 16, 44100, 44100, DUMMY_PCM_DIGEST, walrus_data::new_blob(1), TestIngesterWitness());
    assert_eq!(audio.duration_ms(), 1000);

    // 88200 samples at 44100 Hz = exactly 2000 ms
    let audio2 = audio::new(2, 16, 44100, 88200, DUMMY_PCM_DIGEST, walrus_data::new_blob(1), TestIngesterWitness());
    assert_eq!(audio2.duration_ms(), 2000);

    // 48000 samples at 48000 Hz = exactly 1000 ms
    let audio3 = audio::new(1, 24, 48000, 48000, DUMMY_PCM_DIGEST, walrus_data::new_blob(1), TestIngesterWitness());
    assert_eq!(audio3.duration_ms(), 1000);
}

// === Error Conditions ===

#[test, expected_failure(abort_code = EInvalidChannels, location = musicos::audio)]
fun test_new_zero_channels() {
    audio::new(0, 16, 44100, 1000, DUMMY_PCM_DIGEST, walrus_data::new_blob(1), TestIngesterWitness());
}

#[test, expected_failure(abort_code = EInvalidBitDepth, location = musicos::audio)]
fun test_new_invalid_bit_depth_12() {
    audio::new(2, 12, 44100, 1000, DUMMY_PCM_DIGEST, walrus_data::new_blob(1), TestIngesterWitness());
}

#[test, expected_failure(abort_code = EInvalidBitDepth, location = musicos::audio)]
fun test_new_invalid_bit_depth_0() {
    audio::new(2, 0, 44100, 1000, DUMMY_PCM_DIGEST, walrus_data::new_blob(1), TestIngesterWitness());
}

#[test, expected_failure(abort_code = EInvalidSampleRate, location = musicos::audio)]
fun test_new_zero_sample_rate() {
    audio::new(2, 16, 0, 1000, DUMMY_PCM_DIGEST, walrus_data::new_blob(1), TestIngesterWitness());
}

#[test, expected_failure(abort_code = EInvalidSamples, location = musicos::audio)]
fun test_new_zero_samples() {
    audio::new(2, 16, 44100, 0, DUMMY_PCM_DIGEST, walrus_data::new_blob(1), TestIngesterWitness());
}

#[test, expected_failure(abort_code = ESamplesOverflow, location = musicos::audio)]
fun test_new_samples_overflow() {
    audio::new(2, 16, 44100, MAX_SAMPLES + 1, DUMMY_PCM_DIGEST, walrus_data::new_blob(1), TestIngesterWitness());
}

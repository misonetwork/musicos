// Copyright (c) Studio Mirai, LLC
// SPDX-License-Identifier: Apache-2.0

/// Represents audio files in MusicOS with technical metadata.
///
/// ### Key Features:
///
/// - Audio format parameters (channels, bit depth, sample rate)
/// - Content-addressed via pcm_digest for integrity verification
module musicos::audio;

use walrus_data::walrus_data::WalrusData;

// === Structs ===

/// An audio file with technical metadata and content-addressed integrity.
public struct Audio has drop, store {
    /// Number of audio channels (1 = mono, 2 = stereo).
    channels: u8,
    /// Bits per sample (8, 16, 24, or 32).
    bit_depth: u8,
    /// Sample rate in hertz (e.g., 44100, 48000, 96000).
    sample_rate_hz: u32,
    /// Total number of PCM samples in the audio.
    samples: u64,
    /// Reference to the audio data stored on Walrus.
    data: WalrusData,
    /// Blake2b-256 digest of the raw PCM data for integrity verification.
    pcm_digest: vector<u8>,
}

// === Constants ===

const PCM_DIGEST_LENGTH: u64 = 32;
/// Maximum number of samples to prevent overflow in duration_ms (u64::MAX / 1_000).
const MAX_SAMPLES: u64 = 18_446_744_073_709_551;

// === Errors ===

// Validation errors (20-29)
/// PCM digest must be exactly 32 bytes.
const EInvalidPcmDigestLength: u64 = 20;
/// Audio must have at least one channel.
const EInvalidChannels: u64 = 21;
/// Bit depth must be 8, 16, 24, or 32.
const EInvalidBitDepth: u64 = 22;
/// Sample rate must be greater than zero.
const EInvalidSampleRate: u64 = 23;
/// Audio must have at least one sample.
const EInvalidSamples: u64 = 24;
/// Sample count would cause overflow in duration calculation.
const ESamplesOverflow: u64 = 25;

// === Public Functions ===

/// Creates a new Audio object with the given parameters.
public fun new(
    channels: u8,
    bit_depth: u8,
    sample_rate_hz: u32,
    samples: u64,
    data: WalrusData,
    pcm_digest: vector<u8>,
): Audio {
    assert!(pcm_digest.length() == PCM_DIGEST_LENGTH, EInvalidPcmDigestLength);
    assert!(channels > 0, EInvalidChannels);
    assert!(
        bit_depth == 8 || bit_depth == 16 || bit_depth == 24 || bit_depth == 32,
        EInvalidBitDepth,
    );
    assert!(sample_rate_hz > 0, EInvalidSampleRate);
    assert!(samples > 0, EInvalidSamples);
    assert!(samples <= MAX_SAMPLES, ESamplesOverflow);

    Audio {
        channels,
        bit_depth,
        sample_rate_hz,
        samples,
        data,
        pcm_digest,
    }
}

// === Public View Functions ===

/// Returns the number of audio channels (1 = mono, 2 = stereo).
public fun channels(self: &Audio): u8 {
    self.channels
}

/// Returns the bit depth of the audio (16, 24, or 32 bits).
public fun bit_depth(self: &Audio): u8 {
    self.bit_depth
}

/// Returns the sample rate in Hz.
public fun sample_rate_hz(self: &Audio): u32 {
    self.sample_rate_hz
}

/// Returns the total number of samples in the audio.
public fun samples(self: &Audio): u64 {
    self.samples
}

/// Returns a reference to the external storage data.
public fun data(self: &Audio): &WalrusData {
    &self.data
}

/// Returns the content pcm_digest for integrity verification.
public fun pcm_digest(self: &Audio): &vector<u8> {
    &self.pcm_digest
}

/// Returns the duration of the audio in milliseconds (truncated).
/// Multiplies first to preserve precision before integer division.
public fun duration_ms(self: &Audio): u64 {
    self.samples * 1_000 / (self.sample_rate_hz as u64)
}

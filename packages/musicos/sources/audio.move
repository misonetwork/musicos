// Copyright (c) Studio Mirai, LLC
// Copyright (c) Unconfirmed Labs, LLC
// Copyright (c) Alex Clapworthy
// SPDX-License-Identifier: Apache-2.0

/// Represents audio files in MusicOS with technical metadata.
///
/// Key features:
/// - Audio format parameters (channels, bit depth, sample rate)
/// - Content-addressed via pcm_digest for integrity verification
module musicos::audio;

use walrus_data::walrus_data::WalrusData;

//=== Structs ===

public struct Audio has drop, store {
    channels: u8,
    bit_depth: u8,
    sample_rate_hz: u32,
    samples: u64,
    data: WalrusData,
    pcm_digest: vector<u8>,
}

//=== Constants ===

const PCM_DIGEST_LENGTH: u64 = 32;

//=== Public Functions ===

const EInvalidPcmDigestLength: u64 = 0;

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

    Audio {
        channels,
        bit_depth,
        sample_rate_hz,
        samples,
        data,
        pcm_digest,
    }
}

//=== Public View Functions ===

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

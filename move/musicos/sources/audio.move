// Copyright (c) Studio Mirai, LLC
// SPDX-License-Identifier: Apache-2.0

/// Represents audio files in MusicOS with technical metadata.
///
/// ### Key Features:
///
/// - Audio format parameters (channels, bit depth, sample rate)
/// - Walrus blob storage reference
/// - Hot potato verification: `new()` returns an `UnverifiedAudio` that must
///   be consumed by a verifier's `verify()` call to produce a storable `Audio`.
module musicos::audio;

use std::type_name::{Self, TypeName};
use sui::event::emit;
use walrus_data::walrus_data::WalrusData;

// === Structs ===

/// A verified audio file with technical metadata.
/// Can only be created by verifying an `UnverifiedAudio`.
public struct Audio has copy, drop, store {
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
    /// The verifier that attested this audio.
    verifier: TypeName,
}

/// An unverified audio file. Has no abilities — must be consumed by calling
/// `verify()` before the transaction ends.
public struct UnverifiedAudio {
    channels: u8,
    bit_depth: u8,
    sample_rate_hz: u32,
    samples: u64,
    data: WalrusData,
}

// === Events ===

/// Emitted when an audio file is verified.
public struct AudioVerifiedEvent<phantom Verifier: drop> has copy, drop {
    blob_id: u256,
}

// === Constants ===

/// Maximum number of samples to prevent overflow in duration_ms (u64::MAX / 1_000).
const MAX_SAMPLES: u64 = 18_446_744_073_709_551;

// === Errors ===

// Validation errors (20-29)
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

/// Creates a new unverified audio. Returns a hot potato that must be
/// consumed by calling `verify()` before the transaction completes.
public fun new(
    channels: u8,
    bit_depth: u8,
    sample_rate_hz: u32,
    samples: u64,
    data: WalrusData,
): UnverifiedAudio {
    assert!(channels > 0, EInvalidChannels);
    assert!(
        bit_depth == 8 || bit_depth == 16 || bit_depth == 24 || bit_depth == 32,
        EInvalidBitDepth,
    );
    assert!(sample_rate_hz > 0, EInvalidSampleRate);
    assert!(samples > 0, EInvalidSamples);
    assert!(samples <= MAX_SAMPLES, ESamplesOverflow);

    UnverifiedAudio {
        channels,
        bit_depth,
        sample_rate_hz,
        samples,
        data,
    }
}

/// Consumes an `UnverifiedAudio` and returns a verified `Audio`.
/// The verifier witness type identifies who performed the verification.
public fun verify<Verifier: drop>(unverified: UnverifiedAudio, _verifier: Verifier): Audio {
    let UnverifiedAudio { channels, bit_depth, sample_rate_hz, samples, data } = unverified;

    emit(AudioVerifiedEvent<Verifier> {
        blob_id: data.blob_id(),
    });

    Audio {
        channels,
        bit_depth,
        sample_rate_hz,
        samples,
        data,
        verifier: type_name::with_defining_ids<Verifier>(),
    }
}

// === UnverifiedAudio View Functions ===

/// Returns the number of audio channels.
public fun unverified_channels(self: &UnverifiedAudio): u8 {
    self.channels
}

/// Returns the bit depth.
public fun unverified_bit_depth(self: &UnverifiedAudio): u8 {
    self.bit_depth
}

/// Returns the sample rate in Hz.
public fun unverified_sample_rate_hz(self: &UnverifiedAudio): u32 {
    self.sample_rate_hz
}

/// Returns the total number of samples.
public fun unverified_samples(self: &UnverifiedAudio): u64 {
    self.samples
}

/// Returns a reference to the Walrus data.
public fun unverified_data(self: &UnverifiedAudio): &WalrusData {
    &self.data
}

// === Audio View Functions ===

/// Returns the number of audio channels (1 = mono, 2 = stereo).
public fun channels(self: &Audio): u8 {
    self.channels
}

/// Returns the bit depth of the audio (8, 16, 24, or 32 bits).
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

/// Returns a reference to the Walrus data.
public fun data(self: &Audio): &WalrusData {
    &self.data
}

/// Returns the duration of the audio in milliseconds (truncated).
/// Multiplies first to preserve precision before integer division.
public fun duration_ms(self: &Audio): u64 {
    self.samples * 1_000 / (self.sample_rate_hz as u64)
}

/// Returns a reference to the verifier type name.
public fun verifier_type(self: &Audio): &TypeName {
    &self.verifier
}

// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Represents validated audio files in MusicOS with technical metadata.
/// Audio creation is permissioned through the protocol's authority system,
/// ensuring only authorized services can create valid audio objects.
///
/// Key features:
/// - Validated audio format parameters (channels, bit depth, sample rate)
/// - Content-addressed via pcm_digest for integrity verification
/// - Authority-gated creation through protocol configuration
///
/// Supported formats:
/// - Channels: Mono (1), Stereo (2)
/// - Bit depths: 16, 24, 32 bit
/// - Sample rates: 44.1kHz, 48kHz, 96kHz, 192kHz
module musicos::audio;

use musicos::data::Data;
use musicos::protocol::Protocol;
use std::type_name::with_defining_ids;

//=== Structs ===

/// Represents a validated audio file with technical metadata.
public struct Audio has drop, store {
    channels: u8,
    bit_depth: u8,
    sample_rate_hz: u32,
    samples: u64,
    data: Data,
    pcm_digest: vector<u8>,
}

//=== Constants ===

const SUPPORTED_BIT_DEPTHS: vector<u8> = vector[16, 24, 32];
const SUPPORTED_CHANNELS: vector<u8> = vector[1, 2]; // Mono, Stereo
const SUPPORTED_SAMPLE_RATES_HZ: vector<u32> = vector[44_100, 48_000, 96_000, 192_000];

//=== Errors ===

/// The authority type is not registered for audio creation in the protocol.
const EInvalidAudioCreationAuthority: u64 = 0;
/// The bit depth is not supported (must be 16, 24, or 32).
const EUnsupportedBitDepth: u64 = 20;
/// The channel count is not supported (must be 1 or 2).
const EUnsupportedChannels: u64 = 21;
/// The sample rate is not supported (must be 44100, 48000, 96000, or 192000).
const EUnsupportedSampleRate: u64 = 22;

//=== Public Functions ===

/// Creates a new validated Audio object.
/// Requires an authority witness type registered in the protocol.
/// Validates that channels, bit depth, and sample rate are supported values.
public fun new<Authority: drop>(
    _: Authority,
    channels: u8,
    bit_depth: u8,
    sample_rate_hz: u32,
    samples: u64,
    data: Data,
    pcm_digest: vector<u8>,
    protocol: &Protocol,
): Audio {
    assert!(
        protocol.audio_creation_authority_types().contains(&with_defining_ids<Authority>()),
        EInvalidAudioCreationAuthority,
    );

    assert!(supported_bit_depths!().contains(&bit_depth), EUnsupportedBitDepth);
    assert!(supported_channels!().contains(&channels), EUnsupportedChannels);
    assert!(supported_sample_rates_hz!().contains(&sample_rate_hz), EUnsupportedSampleRate);

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
public fun data(self: &Audio): &Data {
    &self.data
}

/// Returns the content pcm_digest for integrity verification.
public fun pcm_digest(self: &Audio): &vector<u8> {
    &self.pcm_digest
}

/// Returns the duration of the audio in seconds.
public fun duration_s(self: &Audio): u64 {
    self.samples / (self.sample_rate_hz as u64)
}

//=== Public Macro Functions ===

/// Returns the list of supported bit depths.
public macro fun supported_bit_depths(): vector<u8> {
    SUPPORTED_BIT_DEPTHS
}

/// Returns the list of supported channel counts.
public macro fun supported_channels(): vector<u8> {
    SUPPORTED_CHANNELS
}

/// Returns the list of supported sample rates in Hz.
public macro fun supported_sample_rates_hz(): vector<u32> {
    SUPPORTED_SAMPLE_RATES_HZ
}

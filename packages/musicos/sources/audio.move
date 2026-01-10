// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module musicos::audio;

use musicos::protocol::Protocol;
use std::type_name::with_defining_ids;

//=== Structs ===

public struct Audio has drop, store {
    channels: u8,
    bit_depth: u8,
    sample_rate_hz: u32,
    samples: u64,
    blob_id: u256,
    digest: vector<u8>,
}

//=== Constants ===

const SUPPORTED_BIT_DEPTHS: vector<u8> = vector[16, 24, 32];
const SUPPORTED_CHANNELS: vector<u8> = vector[1, 2]; // Mono, Stereo
const SUPPORTED_SAMPLE_RATES_HZ: vector<u32> = vector[44_100, 48_000, 96_000, 192_000];

//=== Errors ===

const EInvalidAudioCreationAuthority: u64 = 0;
const EUnsupportedBitDepth: u64 = 0;
const EUnsupportedChannels: u64 = 1;
const EUnsupportedSampleRate: u64 = 1;

//=== Public Functions ===

public fun new<Authority: drop>(
    _: Authority,
    channels: u8,
    bit_depth: u8,
    sample_rate_hz: u32,
    samples: u64,
    blob_id: u256,
    digest: vector<u8>,
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
        blob_id,
        digest,
    }
}

//=== Public View Functions ===

public fun channels(self: &Audio): u8 {
    self.channels
}

public fun bit_depth(self: &Audio): u8 {
    self.bit_depth
}

public fun sample_rate_hz(self: &Audio): u32 {
    self.sample_rate_hz
}

public fun samples(self: &Audio): u64 {
    self.samples
}

public fun blob_id(self: &Audio): u256 {
    self.blob_id
}

public fun digest(self: &Audio): &vector<u8> {
    &self.digest
}

public fun duration(self: &Audio): u64 {
    self.samples / (self.sample_rate_hz as u64)
}

public macro fun supported_bit_depths(): vector<u8> {
    SUPPORTED_BIT_DEPTHS
}

public macro fun supported_channels(): vector<u8> {
    SUPPORTED_CHANNELS
}

public macro fun supported_sample_rates_hz(): vector<u32> {
    SUPPORTED_SAMPLE_RATES_HZ
}

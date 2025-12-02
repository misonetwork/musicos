// Copyright (c) Sona Labs, Pte Ltd.
// SPDX-License-Identifier: Apache-2.0

module musicos::pcm;

use interest_bps::bps::BPS;

//=== Structs ===

public struct Pcm has drop, store {
    channels: vector<PcmChannel>,
    channel_layout: PcmChannelLayout,
    samples: u64,
    sample_rate: u32,
    bit_depth: u8,
    digest: vector<u8>,
}

public struct PcmChannel has drop, store {
    energy: BPS,
}

public enum PcmChannelLayout has copy, drop, store {
    Mono,
    Stereo,
    Surround(vector<PcmSurroundChannelRole>),
}

public enum PcmSurroundChannelRole has copy, drop, store {
    L,
    R,
    C,
    Lfe,
    Ls,
    Rs,
    Lb,
    Rb,
}

//=== Constants ===

const MAX_CHANNELS: u8 = 2;
const SUPPORTED_BIT_DEPTHS: vector<u8> = vector[16, 24, 32];
const SUPPORTED_SAMPLE_RATES: vector<u32> = vector[
    44_100, 48_000, 96_000, 192_000, 384_000, 768_000,
];

//=== Errors ===

const EUnsupportedBitDepth: u64 = 0;
const EUnsupportedSampleRate: u64 = 0;
const EInvalidSamples: u64 = 0;
const EInvalidChannelCount: u64 = 0;

//=== Public Functions ===

public fun new(
    channels: vector<PcmChannel>,
    channel_layout: PcmChannelLayout,
    digest: vector<u8>,
    sample_rate: u32,
    bit_depth: u8,
    samples: u64,
): Pcm {
    assert!(samples > 0, EInvalidSamples);
    assert!(SUPPORTED_BIT_DEPTHS.contains(&bit_depth), EUnsupportedBitDepth);
    assert!(SUPPORTED_SAMPLE_RATES.contains(&sample_rate), EUnsupportedSampleRate);

    match (channel_layout) {
        PcmChannelLayout::Mono => assert!(channels.length() == 1, EInvalidChannelCount),
        PcmChannelLayout::Stereo => assert!(channels.length() == 2, EInvalidChannelCount),
        // TODO: Add additional surround channel validation.
        PcmChannelLayout::Surround(channel_roles) => {
            assert!(channels.length() == channel_roles.length(), EInvalidChannelCount);
        },
    };

    Pcm {
        channels,
        channel_layout,
        digest,
        sample_rate,
        bit_depth,
        samples,
    }
}

//=== Public View Functions ===

public fun channels(self: &Pcm): u8 {
    self.channels
}

public fun digest(self: &Pcm): &vector<u8> {
    &self.digest
}

public fun sample_rate(self: &Pcm): u32 {
    self.sample_rate
}

public fun bit_depth(self: &Pcm): u8 {
    self.bit_depth
}

public fun samples(self: &Pcm): u64 {
    self.samples
}

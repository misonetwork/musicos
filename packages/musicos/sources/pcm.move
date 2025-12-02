// Copyright (c) Sona Labs, Pte Ltd.
// SPDX-License-Identifier: Apache-2.0
module musicos::pcm;

//=== Structs ===

public struct Pcm has drop, store {
    channel_layout: PcmChannelLayout,
    samples: u64,
    sample_rate: u32,
    bit_depth: u8,
    digest: vector<u8>,
}

public enum PcmChannelLayout has copy, drop, store {
    Mono,
    Stereo,
    Surround(vector<PcmChannelRole>),
}

public enum PcmChannelRole has copy, drop, store {
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

const SUPPORTED_BIT_DEPTHS: vector<u8> = vector[16, 24, 32];
const SUPPORTED_SAMPLE_RATES: vector<u32> = vector[
    44_100, 48_000, 96_000, 192_000, 384_000, 768_000,
];

//=== Errors ===

const EUnsupportedBitDepth: u64 = 0;
const EUnsupportedSampleRate: u64 = 0;
const EInvalidSamples: u64 = 0;

//=== Public Functions ===

public fun new(
    channel_layout: PcmChannelLayout,
    digest: vector<u8>,
    sample_rate: u32,
    bit_depth: u8,
    samples: u64,
): Pcm {
    let supported_bit_depths = SUPPORTED_BIT_DEPTHS;
    let supported_sample_rates = SUPPORTED_SAMPLE_RATES;
    assert!(samples > 0, EInvalidSamples);
    assert!(supported_bit_depths.contains(&bit_depth), EUnsupportedBitDepth);
    assert!(supported_sample_rates.contains(&sample_rate), EUnsupportedSampleRate);

    Pcm {
        channel_layout,
        digest,
        sample_rate,
        bit_depth,
        samples,
    }
}

//=== Public View Functions ===

public fun channel_layout(self: &Pcm): &PcmChannelLayout {
    &self.channel_layout
}

public fun channel_count(self: &Pcm): u8 {
    match (&self.channel_layout) {
        PcmChannelLayout::Mono => 1,
        PcmChannelLayout::Stereo => 2,
        PcmChannelLayout::Surround(channel_roles) => (channel_roles.length() as u8),
    }
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

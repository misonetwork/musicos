module musicos::pcm;

use musicos::data::Data;

//=== Structs ===

public struct Pcm has copy, drop, store {
    channels: u8,
    sample_rate: u32,
    bit_depth: u8,
    samples: u64,
    data: Data,
}

//=== Constants ===

const MAX_CHANNELS: u8 = 64;
const SUPPORTED_BIT_DEPTHS: vector<u8> = vector[16, 24, 32];
const SUPPORTED_SAMPLE_RATES: vector<u32> = vector[
    44_100, 48_000, 96_000, 192_000, 384_000, 768_000,
];

//=== Errors ===

const EUnsupportedBitDepth: u64 = 0;
const EUnsupportedSampleRate: u64 = 0;
const EInvalidSamples: u64 = 0;

//=== Public Functions ===

public fun new(channels: u8, sample_rate: u32, bit_depth: u8, samples: u64, data: Data): Pcm {
    assert!(samples > 0, EInvalidSamples);
    assert!(SUPPORTED_BIT_DEPTHS.contains(&bit_depth), EUnsupportedBitDepth);
    assert!(SUPPORTED_SAMPLE_RATES.contains(&sample_rate), EUnsupportedSampleRate);

    Pcm {
        channels,
        sample_rate,
        bit_depth,
        samples,
        data,
    }
}

//=== Public View Functions ===

public fun channels(self: &Pcm): u8 {
    self.channels
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

public fun data(self: &Pcm): &Data {
    &self.data
}

// Copyright (c) Sona Labs, Pte Ltd.
// SPDX-License-Identifier: Apache-2.0

module musicos::audio_stream;

public struct AudioStream has drop, store {
    channels: u8,
    bit_depth: u8,
    samples: u64,
    sample_rate: u32,
    digest: vector<u8>,
}

public fun new(
    channels: u8,
    bit_depth: u8,
    samples: u64,
    sample_rate: u32,
    digest: vector<u8>,
): AudioStream {
    AudioStream {
        channels,
        bit_depth,
        samples,
        sample_rate,
        digest,
    }
}

public fun channels(self: &AudioStream): u8 {
    self.channels
}

public fun bit_depth(self: &AudioStream): u8 {
    self.bit_depth
}

public fun samples(self: &AudioStream): u64 {
    self.samples
}

public fun sample_rate(self: &AudioStream): u32 {
    self.sample_rate
}

public fun digest(self: &AudioStream): vector<u8> {
    self.digest
}

public fun duration(self: &AudioStream): u64 {
    self.samples / (self.sample_rate as u64)
}

public fun duration_ms(self: &AudioStream): u64 {
    (self.samples * 1_000) / (self.sample_rate as u64)
}

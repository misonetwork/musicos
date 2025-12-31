// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module musicos::audio;

use interest_math::i32::I32;
use musicos::protocol::Protocol;
use std::type_name::with_defining_ids;

//=== Structs ===

public struct Audio has drop, store {
    stream: AudioStream,
    features: AudioFeatures,
}

public struct AudioStream has drop, store {
    channels: u8,
    bit_depth: u8,
    sample_rate_hz: u32,
    samples: u64,
    digest: vector<u8>,
}

public struct AudioFeatures has drop, store {
    spectral_centroid: I32,
}

const EInvalidAudioCreationAuthority: u64 = 0;

//=== Public Functions ===

public fun new<Authority: drop>(
    _: Authority,
    stream: AudioStream,
    features: AudioFeatures,
    protocol: &Protocol,
): Audio {
    assert!(
        protocol.audio_creation_authorities().contains(&with_defining_ids<Authority>()),
        EInvalidAudioCreationAuthority,
    );

    Audio {
        stream,
        features,
    }
}

public fun new_stream(
    channels: u8,
    bit_depth: u8,
    sample_rate_hz: u32,
    samples: u64,
    digest: vector<u8>,
): AudioStream {
    AudioStream {
        channels,
        bit_depth,
        sample_rate_hz,
        samples,
        digest,
    }
}

public fun new_features(spectral_centroid: I32): AudioFeatures {
    AudioFeatures {
        spectral_centroid,
    }
}

//=== Public View Functions ===

public fun channels(self: &Audio): u8 {
    self.stream.channels
}

public fun bit_depth(self: &Audio): u8 {
    self.stream.bit_depth
}

public fun sample_rate_hz(self: &Audio): u32 {
    self.stream.sample_rate_hz
}

public fun samples(self: &Audio): u64 {
    self.stream.samples
}

public fun digest(self: &Audio): &vector<u8> {
    &self.stream.digest
}

public fun spectral_centroid(self: &Audio): I32 {
    self.features.spectral_centroid
}

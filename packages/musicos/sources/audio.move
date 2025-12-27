// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module musicos::audio;

use interest_math::i32::I32;

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

public fun new(stream: AudioStream, features: AudioFeatures): Audio {
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

public fun digest(self: &Audio): &vector<u8> {
    &self.stream.digest
}

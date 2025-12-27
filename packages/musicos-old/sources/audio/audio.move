// Copyright (c) Sona Labs, Pte Ltd.
// SPDX-License-Identifier: Apache-2.0

module musicos::audio;

use musicos::audio_features::AudioFeatures;
use musicos::audio_stream::AudioStream;

//=== Structs ===

public struct Audio has drop, store {
    stream: AudioStream,
    features: AudioFeatures,
}

//=== Constants ===

const MAX_CHANNELS: u8 = 2;

//=== Errors ===

const EInvalidChannelCount: u64 = 0;

//=== Public Functions ===

public fun new(stream: AudioStream, features: AudioFeatures): Audio {
    assert!(stream.channels() <= MAX_CHANNELS, EInvalidChannelCount);
    assert!(stream.channels() as u64 == features.channel_energies().length(), EInvalidChannelCount);

    Audio {
        features,
        stream,
    }
}

public fun features(self: &Audio): &AudioFeatures {
    &self.features
}

public fun stream(self: &Audio): &AudioStream {
    &self.stream
}

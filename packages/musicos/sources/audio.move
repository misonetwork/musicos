// Copyright (c) Sona Labs, Pte Ltd.
// SPDX-License-Identifier: Apache-2.0

module musicos::audio;

use interest_math::i32::I32;
use musicos::bit_rate::BitRate;
use musicos::codec::Codec;
use musicos::pcm::Pcm;

//=== Structs ===

public struct Audio has copy, drop, store {
    pcm: Pcm,
    codec: Codec,
    chroma_vectors: vector<u16>,
    fundamental_frequency: u16,
    harmonic_ratio: u16,
    mfccs: vector<I32>,
    spectral_centroid: u16,
    spectral_flatness: u16,
    spectral_rolloff: u16,
    spectral_spread: u16,
    tempo: u16,
    zero_crossing_rate: u16,
}

public enum AudioEncryptionState has copy, drop, store {
    Unencrypted,
    Encrypted(vector<u8>),
}

//=== Public Functions ===

public fun new(
    pcm: Pcm,
    codec: Codec,
    chroma_vectors: vector<u16>,
    fundamental_frequency: u16,
    harmonic_ratio: u16,
    mfccs: vector<I32>,
    spectral_centroid: u16,
    spectral_flatness: u16,
    spectral_rolloff: u16,
    spectral_spread: u16,
    tempo: u16,
    zero_crossing_rate: u16,
): Audio {
    Audio {
        pcm,
        codec,
        chroma_vectors,
        fundamental_frequency,
        harmonic_ratio,
        mfccs,
        spectral_centroid,
        spectral_flatness,
        spectral_rolloff,
        spectral_spread,
        tempo,
        zero_crossing_rate,
    }
}

public fun pcm(self: &Audio): &Pcm {
    &self.pcm
}

public fun codec(self: &Audio): &Codec {
    &self.codec
}

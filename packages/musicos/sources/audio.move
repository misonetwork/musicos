// Copyright (c) Sona Labs, Pte Ltd.
// SPDX-License-Identifier: Apache-2.0
module musicos::audio;

use interest_bps::bps::{Self, BPS};
use interest_math::i32::I32;
use musicos::codec::Codec;
use musicos::pcm::Pcm;

//=== Structs ===

public struct Audio has drop, store {
    pcm: Pcm,
    codec: Codec,
    statistics: AudioStatistics,
}

public struct AudioStatistics has drop, store {
    loudness: AudioLoudnessStatistics,
    tonal: AudioTonalStatistics,
    spectral: AudioSpectralStatistics,
    timbre: AudioTimbreStatistics,
    rhythm: AudioRhythmStatistics,
}

public struct AudioLoudnessStatistics has drop, store {
    // per-channel or global loudness features
    channel_energies: vector<BPS>,
    channel_mean_rms: vector<BPS>,
    mean_rms: BPS,
    peak_linear: BPS,
    crest_factor: BPS,
    dynamic_range: BPS,
    channel_imbalance: BPS,
}

public struct AudioTonalStatistics has drop, store {
    chroma_vectors: vector<u16>,
    fundamental_frequency_hz: u16,
    harmonic_ratio: BPS,
}

public struct AudioSpectralStatistics has drop, store {
    spectral_centroid_hz: u16,
    spectral_flatness: BPS,
    spectral_rolloff_hz: u16,
    spectral_spread_hz: u16,
}

public struct AudioTimbreStatistics has drop, store {
    mfccs: vector<I32>,
}

public struct AudioRhythmStatistics has drop, store {
    tempo_bpm: u16,
    zero_crossing_rate: BPS,
}

//=== Errors ===

const EInvalidChannelEnergy: u64 = 0;
const EInvalidChannelCount: u64 = 1;

//=== Constants ===

const MAX_CHANNELS: u64 = 2;

//=== Public Functions ===

public fun new(
    pcm: Pcm,
    codec: Codec,
    channel_energies: vector<BPS>,
    channel_mean_rms: vector<BPS>,
    mean_rms: BPS,
    peak_linear: BPS,
    crest_factor: BPS,
    dynamic_range: BPS,
    channel_imbalance: BPS,
    chroma_vectors: vector<u16>,
    fundamental_frequency_hz: u16,
    harmonic_ratio: BPS,
    spectral_centroid_hz: u16,
    spectral_flatness: BPS,
    spectral_rolloff_hz: u16,
    spectral_spread_hz: u16,
    mfccs: vector<I32>,
    tempo_bpm: u16,
    zero_crossing_rate: BPS,
): Audio {
    // Assert the number of channels doesn't exceed two channels (stereo).
    assert!(channel_energies.length() == MAX_CHANNELS, EInvalidChannelCount);
    // Assert the channel energies add up to 100%.
    assert!(
        channel_energies.fold!(0, |acc, bps| acc + bps.value()) == bps::max_value!(),
        EInvalidChannelEnergy,
    );

    let statistics = AudioStatistics {
        loudness: AudioLoudnessStatistics {
            channel_energies,
            channel_mean_rms,
            mean_rms,
            peak_linear,
            crest_factor,
            dynamic_range,
            channel_imbalance,
        },
        tonal: AudioTonalStatistics {
            chroma_vectors,
            fundamental_frequency_hz,
            harmonic_ratio,
        },
        spectral: AudioSpectralStatistics {
            spectral_centroid_hz,
            spectral_flatness,
            spectral_rolloff_hz,
            spectral_spread_hz,
        },
        timbre: AudioTimbreStatistics {
            mfccs,
        },
        rhythm: AudioRhythmStatistics {
            tempo_bpm,
            zero_crossing_rate,
        },
    };

    Audio {
        pcm,
        codec,
        statistics,
    }
}

public fun pcm(self: &Audio): &Pcm {
    &self.pcm
}

public fun codec(self: &Audio): &Codec {
    &self.codec
}

public fun channel_energies(self: &Audio): &vector<BPS> {
    &self.statistics.loudness.channel_energies
}

public fun channel_mean_rms(self: &Audio): &vector<BPS> {
    &self.statistics.loudness.channel_mean_rms
}

public fun mean_rms(self: &Audio): BPS {
    self.statistics.loudness.mean_rms
}

public fun peak_linear(self: &Audio): BPS {
    self.statistics.loudness.peak_linear
}

public fun crest_factor(self: &Audio): BPS {
    self.statistics.loudness.crest_factor
}

public fun dynamic_range(self: &Audio): BPS {
    self.statistics.loudness.dynamic_range
}

public fun channel_imbalance(self: &Audio): BPS {
    self.statistics.loudness.channel_imbalance
}

public fun chroma_vectors(self: &Audio): &vector<u16> {
    &self.statistics.tonal.chroma_vectors
}

public fun fundamental_frequency_hz(self: &Audio): u16 {
    self.statistics.tonal.fundamental_frequency_hz
}

public fun harmonic_ratio(self: &Audio): BPS {
    self.statistics.tonal.harmonic_ratio
}

public fun spectral_centroid_hz(self: &Audio): u16 {
    self.statistics.spectral.spectral_centroid_hz
}

public fun spectral_flatness(self: &Audio): BPS {
    self.statistics.spectral.spectral_flatness
}

public fun spectral_rolloff_hz(self: &Audio): u16 {
    self.statistics.spectral.spectral_rolloff_hz
}

public fun spectral_spread_hz(self: &Audio): u16 {
    self.statistics.spectral.spectral_spread_hz
}

public fun mfccs(self: &Audio): &vector<I32> {
    &self.statistics.timbre.mfccs
}

public fun tempo_bpm(self: &Audio): u16 {
    self.statistics.rhythm.tempo_bpm
}

public fun zero_crossing_rate(self: &Audio): BPS {
    self.statistics.rhythm.zero_crossing_rate
}

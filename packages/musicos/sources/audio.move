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
    channel_energies: vector<BPS>,
    mean_rms_dbfs: I32,
    peak_dbfs: I32,
    dynamic_range_db: I32,
    spectral_centroid_hz: u16,
    spectral_flatness: BPS,
    tempo_bpm: u16,
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
    mean_rms_dbfs: I32,
    peak_dbfs: I32,
    dynamic_range_db: I32,
    spectral_centroid_hz: u16,
    spectral_flatness: BPS,
    tempo_bpm: u16,
): Audio {
    // Assert the number of channels doesn't exceed two channels (stereo).
    assert!(channel_energies.length() == MAX_CHANNELS, EInvalidChannelCount);
    // Assert the channel energies add up to 100%.
    assert!(
        channel_energies.fold!(0, |acc, bps| acc + bps.value()) == bps::max_value!(),
        EInvalidChannelEnergy,
    );

    let statistics = AudioStatistics {
        channel_energies,
        mean_rms_dbfs,
        peak_dbfs,
        dynamic_range_db,
        spectral_centroid_hz,
        spectral_flatness,
        tempo_bpm,
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
    &self.statistics.channel_energies
}

public fun mean_rms_dbfs(self: &Audio): I32 {
    self.statistics.mean_rms_dbfs
}

public fun peak_dbfs(self: &Audio): I32 {
    self.statistics.peak_dbfs
}

public fun dynamic_range_db(self: &Audio): I32 {
    self.statistics.dynamic_range_db
}

public fun spectral_centroid_hz(self: &Audio): u16 {
    self.statistics.spectral_centroid_hz
}

public fun spectral_flatness(self: &Audio): BPS {
    self.statistics.spectral_flatness
}

public fun tempo_bpm(self: &Audio): u16 {
    self.statistics.tempo_bpm
}

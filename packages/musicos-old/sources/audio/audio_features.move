// Copyright (c) Sona Labs, Pte Ltd.
// SPDX-License-Identifier: Apache-2.0

module musicos::audio_features;

use interest_bps::bps::BPS;
use interest_math::i32::I32;

public struct AudioFeatures has drop, store {
    channel_energies: vector<BPS>,
    mean_rms_dbfs: I32,
    peak_dbfs: I32,
    dynamic_range_db: I32,
    spectral_centroid_hz: u16,
    spectral_flatness: BPS,
    tempo_bpm: u16,
}

public fun new(
    channel_energies: vector<BPS>,
    mean_rms_dbfs: I32,
    peak_dbfs: I32,
    dynamic_range_db: I32,
    spectral_centroid_hz: u16,
    spectral_flatness: BPS,
    tempo_bpm: u16,
): AudioFeatures {
    AudioFeatures {
        channel_energies,
        mean_rms_dbfs,
        peak_dbfs,
        dynamic_range_db,
        spectral_centroid_hz,
        spectral_flatness,
        tempo_bpm,
    }
}

public fun channel_energies(self: &AudioFeatures): vector<BPS> {
    self.channel_energies
}

public fun mean_rms_dbfs(self: &AudioFeatures): I32 {
    self.mean_rms_dbfs
}

public fun peak_dbfs(self: &AudioFeatures): I32 {
    self.peak_dbfs
}

public fun dynamic_range_db(self: &AudioFeatures): I32 {
    self.dynamic_range_db
}

public fun spectral_centroid_hz(self: &AudioFeatures): u16 {
    self.spectral_centroid_hz
}

public fun spectral_flatness(self: &AudioFeatures): BPS {
    self.spectral_flatness
}

public fun tempo_bpm(self: &AudioFeatures): u16 {
    self.tempo_bpm
}

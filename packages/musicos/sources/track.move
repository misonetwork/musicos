// Copyright (c) Sona Labs, Pte Ltd.
// SPDX-License-Identifier: Apache-2.0

module musicos::track;

use interest_bps::bps::BPS;
use musicos::recording::{Recording, RecordingAdminCap};
use musicos::utils::calculate_duration;
use std::string::String;

//=== Structs ===

public struct Track has drop, store {
    composition_id: ID,
    composition_commission_rate: BPS,
    recording_id: ID,
    duration: u64,
    genre_id: ID,
}

//=== Public Functions ===

public fun new<RecordingShare>(
    cap: &RecordingAdminCap,
    recording: &Recording<RecordingShare>,
): Track {
    recording.authorize(cap);
    Track {
        composition_id: recording.composition_id(),
        composition_commission_rate: recording.composition_commission_rate(),
        recording_id: recording.id(),
        duration: calculate_duration(
            recording.primary_mix().audio().pcm().samples(),
            recording.primary_mix().audio().pcm().sample_rate(),
        ),
        genre_id: recording.genre_id(),
    }
}

//=== Public View Functions ===

public fun composition_id(self: &Track): ID {
    self.composition_id
}

public fun composition_commission_rate(self: &Track): BPS {
    self.composition_commission_rate
}

public fun recording_id(self: &Track): ID {
    self.recording_id
}

public fun duration(self: &Track): u64 {
    self.duration
}

public fun genre_id(self: &Track): ID {
    self.genre_id
}

// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module musicos::track;

use interest_bps::bps::BPS;
use musicos::recording::{Recording, RecordingAdminCap};
use std::string::String;

//=== Structs ===

public struct Track has drop, store {
    composition_id: ID,
    composition_split: BPS,
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
        composition_split: recording.composition_split(),
        recording_id: recording.id(),
        duration: recording.master().duration(),
        genre_id: recording.genre_id(),
    }
}

//=== Public View Functions ===

public fun composition_id(self: &Track): ID {
    self.composition_id
}

public fun composition_split(self: &Track): BPS {
    self.composition_split
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

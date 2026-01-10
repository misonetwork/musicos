// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module musicos::track;

use musicos::bps::BPS;
use musicos::recording::{Recording, RecordingAdminCap};
use std::string::String;

//=== Structs ===

public struct Track has drop, store {
    composition_id: ID,
    composition_split: BPS,
    recording_id: ID,
    duration: u64,
    genre_id: ID,
    // Optional track-level artwork that overrides the release-level artwork.
    artwork: Option<u256>,
}

//=== Public Functions ===

public fun new<RecordingShare>(
    cap: &RecordingAdminCap,
    recording: &Recording<RecordingShare>,
    artwork: Option<u256>,
): Track {
    recording.authorize(cap);

    Track {
        composition_id: recording.composition_id(),
        composition_split: recording.composition_split(),
        recording_id: recording.id(),
        duration: recording.master().duration(),
        genre_id: recording.genre_id(),
        artwork,
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

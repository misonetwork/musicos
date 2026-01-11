// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module musicos::track;

use musicos::bps::BPS;
use musicos::composition::Composition;
use musicos::cover_art::CoverArt;
use musicos::recording::{Recording, RecordingAdminCap};
use std::string::String;
use std::type_name::{with_defining_ids, TypeName};

//=== Structs ===

public struct Track has drop, store {
    composition_id: ID,
    composition_share_type: TypeName,
    composition_split: BPS,
    recording_id: ID,
    recording_share_type: TypeName,
    duration: u64,
    genre_id: ID,
    // Optional track-level artwork that overrides the release-level artwork.
    cover_art: Option<CoverArt>,
}

//=== Errors ===

const ECompositionRecordingMismatch: u64 = 0;

//=== Public Functions ===

public fun new<RecordingShare>(
    cap: &RecordingAdminCap,
    recording: &Recording<RecordingShare>,
    cover_art: Option<CoverArt>,
): Track {
    recording.authorize(cap);

    Track {
        composition_id: recording.composition_id(),
        composition_share_type: *recording.composition_share_type(),
        composition_split: *recording.composition_split(),
        recording_id: recording.id(),
        recording_share_type: with_defining_ids<RecordingShare>(),
        duration: recording.master().duration(),
        genre_id: recording.genre_id(),
        cover_art,
    }
}

//=== Public View Functions ===

public fun composition_id(self: &Track): ID {
    self.composition_id
}

public fun composition_share_type(self: &Track): &TypeName {
    &self.composition_share_type
}

public fun composition_split(self: &Track): &BPS {
    &self.composition_split
}

public fun recording_id(self: &Track): ID {
    self.recording_id
}

public fun recording_share_type(self: &Track): &TypeName {
    &self.recording_share_type
}

public fun duration(self: &Track): u64 {
    self.duration
}

public fun genre_id(self: &Track): ID {
    self.genre_id
}

public fun cover_art(self: &Track): &Option<CoverArt> {
    &self.cover_art
}

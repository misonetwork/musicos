// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Represents a track on a release, linking a recording to its position
/// in the tracklist. Each track captures metadata from the recording at
/// the time of release creation for efficient access during playback.
///
/// Key features:
/// - Caches recording metadata for quick access
/// - Supports optional track-specific cover art
/// - Stores composition split for royalty calculations
module musicos::track;

use musicos::bps::BPS;
use musicos::cover_art::CoverArt;
use musicos::recording::{Recording, RecordingAdminCap};
use std::type_name::{with_defining_ids, TypeName};

//=== Structs ===

/// A track on a release containing a recording and its metadata.
/// Metadata is captured at track creation time for efficient access.
public struct Track has drop, store {
    /// ID of the underlying composition.
    composition_id: ID,
    /// Type of the composition's share token.
    composition_share_type: TypeName,
    /// Split of revenue allocated to composition vs recording.
    composition_split: BPS,
    /// ID of the recording on this track.
    recording_id: ID,
    /// Type of the recording's share token.
    recording_share_type: TypeName,
    /// Duration of the track in milliseconds.
    duration_s: u64,
    /// Genre of the recording.
    genre_id: ID,
    /// Covert art for the track. Inherited from the recording by default.
    cover_art: CoverArt,
}

//=== Public Functions ===

/// Creates a new track from a recording.
/// Requires the recording admin capability.
/// Captures the recording's metadata at creation time.
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
        duration_s: recording.master().duration_s(),
        genre_id: recording.genre_id(),
        cover_art: cover_art.destroy_with_default(*recording.cover_art()),
    }
}

//=== Public View Functions ===

/// Returns the ID of the underlying composition.
public fun composition_id(self: &Track): ID {
    self.composition_id
}

/// Returns the type of the composition's share token.
public fun composition_share_type(self: &Track): &TypeName {
    &self.composition_share_type
}

/// Returns the composition's revenue split in basis points.
public fun composition_split(self: &Track): &BPS {
    &self.composition_split
}

/// Returns the ID of the recording.
public fun recording_id(self: &Track): ID {
    self.recording_id
}

/// Returns the type of the recording's share token.
public fun recording_share_type(self: &Track): &TypeName {
    &self.recording_share_type
}

/// Returns the duration of the track in seconds.
public fun duration_s(self: &Track): u64 {
    self.duration_s
}

/// Returns the genre ID of the recording.
public fun genre_id(self: &Track): ID {
    self.genre_id
}

/// Returns the cover art for the track.
public fun cover_art(self: &Track): &CoverArt {
    &self.cover_art
}

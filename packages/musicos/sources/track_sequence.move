// Copyright (c) Studio Mirai, LLC
// SPDX-License-Identifier: Apache-2.0

/// Manages the playback order of tracks across multiple discs in a release.
/// Provides navigation functions for moving between tracks sequentially,
/// wrapping around from the last track to the first and vice versa.
module musicos::track_sequence;

use musicos::disc::Disc;
use musicos::track_position::{Self, TrackPosition};

//=== Structs ===

/// Represents the complete track ordering for a release.
/// Supports efficient navigation between tracks across multiple discs.
public struct TrackSequence has drop, store {
    /// Number of tracks on each disc, indexed by disc number.
    tracks_per_disc: vector<u64>,
    /// Flattened list of all track positions in playback order.
    track_positions: vector<TrackPosition>,
    // Total duration of the sequence in milliseconds.
    duration_ms: u64,
}

//=== Constants ===

/// Maximum number of tracks allowed in a single release.
const MAX_TRACK_SEQUENCE_LENGTH: u64 = 255;

//=== Errors ===

/// Total track count exceeds the maximum allowed (255).
const EMaxSequenceLengthExceeded: u64 = 10;
/// Disc index exceeds the number of discs in the release.
const EDiscIndexOutOfBounds: u64 = 11;
/// Track index exceeds the number of tracks on the disc.
const ETrackIndexOutOfBounds: u64 = 12;
/// Sequence index exceeds the total number of tracks.
const ESequenceIndexOutOfBounds: u64 = 13;
/// Release must contain at least one disc.
const ENoDiscs: u64 = 20;

//=== Package Functions ===

/// Creates a new track sequence from a vector of discs.
/// Builds an ordered list of all track positions for navigation.
/// Returns the track sequence and total duration in milliseconds (since we're looping through the tracks).
/// Aborts if there are no discs or if total tracks exceed 255.
public(package) fun new(discs: &vector<Disc>): TrackSequence {
    assert!(!discs.is_empty(), ENoDiscs);

    let mut tracks_per_disc: vector<u64> = vector[];
    let mut track_positions: vector<TrackPosition> = vector[];
    let mut duration_ms: u64 = 0;

    discs.length().do!(|disc_idx| {
        let disc = &discs[disc_idx];
        let tracks = disc.tracks();

        tracks.length().do!(|track_idx| {
            let track_position = track_position::new(disc_idx, track_idx);
            track_positions.push_back(track_position);
            duration_ms = duration_ms + tracks[track_idx].duration_ms();
        });

        tracks_per_disc.push_back(tracks.length());
    });

    // Assert the length of the track sequence doesn't exceed the allowed maximum.
    assert!(
        track_positions.length() <= MAX_TRACK_SEQUENCE_LENGTH,
        EMaxSequenceLengthExceeded,
    );

    let track_sequence = TrackSequence {
        tracks_per_disc,
        track_positions,
        duration_ms,
    };

    track_sequence
}

//=== Public View Functions ===

/// Returns the position of the next track in sequence.
/// Advances to the next track on the current disc, or to the first track
/// of the next disc if at the end of a disc. Wraps to the first track
/// of the first disc when reaching the end of the release.
public fun next(self: &TrackSequence, disc_idx: u64, track_idx: u64): TrackPosition {
    let disc_count = self.tracks_per_disc.length();
    assert!(disc_idx < disc_count, EDiscIndexOutOfBounds);

    let track_count = self.tracks_per_disc[disc_idx];
    assert!(track_idx < track_count, ETrackIndexOutOfBounds);

    if (track_idx + 1 < track_count) {
        track_position::new(disc_idx, track_idx + 1)
    } else if (disc_idx + 1 < disc_count) {
        track_position::new(disc_idx + 1, 0)
    } else {
        track_position::new(0, 0)
    }
}

/// Returns the position of the previous track in sequence.
/// Moves to the previous track on the current disc, or to the last track
/// of the previous disc if at the start of a disc. Wraps to the last track
/// of the last disc when at the beginning of the release.
public fun previous(self: &TrackSequence, disc_idx: u64, track_idx: u64): TrackPosition {
    let disc_count = self.tracks_per_disc.length();
    assert!(disc_idx < disc_count, EDiscIndexOutOfBounds);

    let track_count = self.tracks_per_disc[disc_idx];
    assert!(track_idx < track_count, ETrackIndexOutOfBounds);

    if (track_idx > 0) {
        track_position::new(disc_idx, track_idx - 1)
    } else if (disc_idx > 0) {
        let prev_track_count = self.tracks_per_disc[disc_idx - 1];
        track_position::new(disc_idx - 1, prev_track_count - 1)
    } else {
        let last_track_count = self.tracks_per_disc[disc_count - 1];
        track_position::new(disc_count - 1, last_track_count - 1)
    }
}

/// Returns the total number of tracks across all discs.
public fun length(self: &TrackSequence): u64 {
    self.track_positions.length()
}

/// Returns the track position at the given sequence index.
/// The sequence index is a flattened position across all discs.
public fun track_position(self: &TrackSequence, track_sequence_idx: u64): &TrackPosition {
    assert!(track_sequence_idx < self.track_positions.length(), ESequenceIndexOutOfBounds);
    &self.track_positions[track_sequence_idx]
}

/// Returns a reference to all track positions in sequence order.
public fun track_positions(self: &TrackSequence): &vector<TrackPosition> {
    &self.track_positions
}

/// Returns the number of tracks on each disc.
public fun tracks_per_disc(self: &TrackSequence): &vector<u64> {
    &self.tracks_per_disc
}

/// Returns the total duration of the sequence in milliseconds.
public fun duration_ms(self: &TrackSequence): u64 {
    self.duration_ms
}

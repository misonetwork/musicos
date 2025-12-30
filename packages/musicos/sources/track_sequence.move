// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module musicos::track_sequence;

use musicos::disc::Disc;

//=== Errors ===

const ENoDiscs: u64 = 0;
const EDiscIndexOutOfBounds: u64 = 1;
const ETrackIndexOutOfBounds: u64 = 2;

//=== Structs ===

public struct TrackSequence has drop, store {
    // Number of tracks on each disc.
    tracks_per_disc: vector<u8>,
    // Total number of tracks in the sequence.
    length: u16,
}

//=== Package Functions ===

// Create a new track sequence.
public(package) fun new(discs: &vector<Disc>): TrackSequence {
    assert!(!discs.is_empty(), ENoDiscs);

    let mut tracks_per_disc: vector<u8> = vector[];
    let mut length: u16 = 0;

    discs.do_ref!(|disc| {
        let track_count = disc.tracks().length();
        tracks_per_disc.push_back(track_count as u8);
        length = length + (track_count as u16);
    });

    TrackSequence {
        tracks_per_disc,
        length,
    }
}

//=== Public View Functions ===

// Get the next disc and track indexes given the current disc and track indexes.
public fun next(self: &TrackSequence, disc_idx: u8, track_idx: u8): (u8, u8) {
    let disc_idx_u64 = disc_idx as u64;

    let disc_count = self.tracks_per_disc.length();
    assert!(disc_idx_u64 < disc_count, EDiscIndexOutOfBounds);

    let track_count = self.tracks_per_disc[disc_idx_u64];
    assert!(track_idx < track_count, ETrackIndexOutOfBounds);

    if (track_idx + 1 < track_count) {
        (disc_idx, track_idx + 1)
    } else if (disc_idx_u64 + 1 < disc_count) {
        (disc_idx + 1, 0)
    } else {
        (0, 0)
    }
}

// Get the previous disc and track indexes given the current disc and track indexes.
public fun previous(self: &TrackSequence, disc_idx: u8, track_idx: u8): (u8, u8) {
    let disc_idx_u64 = disc_idx as u64;

    let disc_count = self.tracks_per_disc.length();
    assert!(disc_idx_u64 < disc_count, EDiscIndexOutOfBounds);

    let track_count = self.tracks_per_disc[disc_idx_u64];
    assert!(track_idx < track_count, ETrackIndexOutOfBounds);

    if (track_idx > 0) {
        (disc_idx, track_idx - 1)
    } else if (disc_idx_u64 > 0) {
        let prev_disc_idx = (disc_idx_u64 - 1) as u8;
        let prev_track_count = self.tracks_per_disc[disc_idx_u64 - 1];
        (prev_disc_idx, prev_track_count - 1)
    } else {
        let last_disc_idx = (disc_count - 1) as u8;
        let last_track_count = self.tracks_per_disc[disc_count - 1];
        (last_disc_idx, last_track_count - 1)
    }
}

// Length of the track sequence.
public fun length(self: &TrackSequence): u16 {
    self.length
}

// Number of tracks on each disc.
public fun tracks_per_disc(self: &TrackSequence): &vector<u8> {
    &self.tracks_per_disc
}

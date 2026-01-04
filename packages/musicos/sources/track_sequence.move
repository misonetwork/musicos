// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module musicos::track_sequence;

use musicos::disc::Disc;
use musicos::track_identifier::{Self, TrackIdentifier};

//=== Structs ===

public struct TrackSequence has drop, store {
    // Number of tracks on each disc.
    tracks_per_disc: vector<u8>,
    lookup: vector<TrackIdentifier>,
}

//=== Constants ===

const MAX_TRACK_SEQUENCE_LENGTH: u8 = 150;

//=== Errors ===

const ENoDiscs: u64 = 0;
const EDiscIndexOutOfBounds: u64 = 1;
const ETrackIndexOutOfBounds: u64 = 2;
const EMaxSequenceLengthExceeded: u64 = 3;
const ESequenceIndexOutOfBounds: u64 = 4;

//=== Package Functions ===

// Create a new track sequence.
public(package) fun new(discs: &vector<Disc>): TrackSequence {
    assert!(!discs.is_empty(), ENoDiscs);

    let mut tracks_per_disc: vector<u8> = vector[];
    let mut lookup: vector<TrackIdentifier> = vector[];

    discs.length().do!(|disc_idx| {
        let disc = &discs[disc_idx];
        let track_count = disc.tracks().length();

        track_count.do!(|track_idx| {
            lookup.push_back(track_identifier::new(disc_idx as u8, track_idx as u8));
        });

        tracks_per_disc.push_back(track_count as u8);
    });

    // Assert the length of the track sequence doesn't exceed the allowed maximum.
    assert!(lookup.length() <= MAX_TRACK_SEQUENCE_LENGTH as u64, EMaxSequenceLengthExceeded);

    TrackSequence {
        tracks_per_disc,
        lookup,
    }
}

//=== Public View Functions ===

// Get the next disc and track indexes given the current disc and track indexes.
public fun next(self: &TrackSequence, disc_idx: u8, track_idx: u8): TrackIdentifier {
    let disc_idx_u64 = disc_idx as u64;

    let disc_count = self.tracks_per_disc.length();
    assert!(disc_idx_u64 < disc_count, EDiscIndexOutOfBounds);

    let track_count = self.tracks_per_disc[disc_idx_u64];
    assert!(track_idx < track_count, ETrackIndexOutOfBounds);

    if (track_idx + 1 < track_count) {
        track_identifier::new(disc_idx, track_idx + 1)
    } else if (disc_idx_u64 + 1 < disc_count) {
        track_identifier::new(disc_idx + 1, 0)
    } else {
        track_identifier::new(0, 0)
    }
}

// Get the previous disc and track indexes given the current disc and track indexes.
public fun previous(self: &TrackSequence, disc_idx: u8, track_idx: u8): TrackIdentifier {
    let disc_idx_u64 = disc_idx as u64;

    let disc_count = self.tracks_per_disc.length();
    assert!(disc_idx_u64 < disc_count, EDiscIndexOutOfBounds);

    let track_count = self.tracks_per_disc[disc_idx_u64];
    assert!(track_idx < track_count, ETrackIndexOutOfBounds);

    if (track_idx > 0) {
        track_identifier::new(disc_idx, track_idx - 1)
    } else if (disc_idx_u64 > 0) {
        let prev_disc_idx = (disc_idx_u64 - 1) as u8;
        let prev_track_count = self.tracks_per_disc[disc_idx_u64 - 1];
        track_identifier::new(prev_disc_idx, prev_track_count - 1)
    } else {
        let last_disc_idx = (disc_count - 1) as u8;
        let last_track_count = self.tracks_per_disc[disc_count - 1];
        track_identifier::new(last_disc_idx, last_track_count - 1)
    }
}

// Length of the track sequence.
public fun length(self: &TrackSequence): u8 {
    self.lookup.length() as u8
}

// Get the disc and track indexes for a given sequence index.
public fun track_identifier(self: &TrackSequence, sequence_idx: u8): &TrackIdentifier {
    let sequence_idx_u64 = sequence_idx as u64;
    assert!(sequence_idx_u64 < self.lookup.length(), ESequenceIndexOutOfBounds);
    &self.lookup[sequence_idx_u64]
}

// Number of tracks on each disc.
public fun tracks_per_disc(self: &TrackSequence): &vector<u8> {
    &self.tracks_per_disc
}

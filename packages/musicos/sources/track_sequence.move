// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module musicos::track_sequence;

use musicos::disc::Disc;
use musicos::track::Track;
use musicos::track_identifier::TrackIdentifier;
use musicos::track_info::TrackInfo;
use sui::vec_map::{Self, VecMap};

//=== Errors ===

const ENoDiscs: u64 = 0;
const EDiscIndexOutOfBounds: u64 = 1;
const ETrackIndexOutOfBounds: u64 = 2;

//=== Structs ===

public struct TrackSequence has drop, store {
    disc_track_counts: vector<u8>,
    disc_prefix: vector<u16>,
    length: u16,
}

public fun new(discs: &vector<Disc>): TrackSequence {
    assert!(!discs.is_empty(), ENoDiscs);

    let mut disc_track_counts: vector<u8> = vector[];
    let mut disc_prefix: vector<u16> = vector[];
    let mut length: u16 = 0;

    discs.length().do!(|disc_idx| {
        let disc = &discs[disc_idx];
        disc_prefix.push_back(length);
        let track_count = disc.tracks().length();
        disc_track_counts.push_back(track_count as u8);
        length = length + (track_count as u16);
    });

    TrackSequence {
        disc_track_counts,
        disc_prefix,
        length,
    }
}

public fun next(self: &TrackSequence, disc_idx: u8, track_idx: u8): (u8, u8) {
    let disc_idx_u64 = disc_idx as u64;

    let disc_count = self.disc_track_counts.length();
    assert!(disc_idx_u64 < disc_count, EDiscIndexOutOfBounds);
    let track_count = self.disc_track_counts[disc_idx_u64];
    assert!(track_idx < track_count, ETrackIndexOutOfBounds);

    if (track_idx + 1 < track_count) {
        return (disc_idx, track_idx + 1)
    };

    let next_disc_idx_u64 = disc_idx_u64 + 1;
    if (next_disc_idx_u64 < disc_count) {
        return (disc_idx + 1, 0)
    };

    (0, 0)
}

public fun prev(self: &TrackSequence, disc_idx: u8, track_idx: u8): (u8, u8) {
    let disc_idx_u64 = disc_idx as u64;

    let disc_count = self.disc_track_counts.length();
    assert!(disc_idx_u64 < disc_count, EDiscIndexOutOfBounds);
    let track_count = self.disc_track_counts[disc_idx_u64];
    assert!(track_idx < track_count, ETrackIndexOutOfBounds);

    if (track_idx > 0) {
        return (disc_idx, track_idx - 1)
    };

    if (disc_idx_u64 > 0) {
        let prev_disc_idx_u64 = disc_idx_u64 - 1;
        let prev_track_count = self.disc_track_counts[prev_disc_idx_u64];
        return ((prev_disc_idx_u64 as u8), prev_track_count - 1)
    };

    let last_disc_idx_u64 = disc_count - 1;
    let last_track_count = self.disc_track_counts[last_disc_idx_u64];
    ((last_disc_idx_u64 as u8), last_track_count - 1)
}

public fun index(self: &TrackSequence, disc_idx: u8, track_idx: u8): u16 {
    let disc_idx_u64: u64 = disc_idx as u64;

    let disc_count: u64 = self.disc_track_counts.length();
    assert!(disc_idx_u64 < disc_count, EDiscIndexOutOfBounds);

    let track_count: u8 = self.disc_track_counts[disc_idx_u64];
    assert!(track_idx < track_count, ETrackIndexOutOfBounds);

    self.disc_prefix[disc_idx_u64] + (track_idx as u16)
}

public fun length(self: &TrackSequence): u16 {
    self.length
}

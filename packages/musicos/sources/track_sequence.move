// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module musicos::track_sequence;

use musicos::track_identifier::TrackIdentifier;
use sui::vec_map::{Self, VecMap};

//=== Errors ===

const EEmptySequence: u64 = 0;
const EDuplicateTrack: u64 = 1;

//=== Structs ===

public struct TrackSequence(VecMap<TrackIdentifier, u64>) has copy, drop, store;

//=== Package Functions ===

public(package) fun new(keys: vector<TrackIdentifier>): TrackSequence {
    let len = keys.length();
    assert!(len > 0, EEmptySequence);

    let mut inner = vec_map::empty();
    len.do!(|i| {
        let key = &keys[i];
        assert!(!inner.contains(key), EDuplicateTrack);
        inner.insert(*key, i);
    });

    TrackSequence(inner)
}

//=== Package View Functions ===

public(package) fun next(self: &TrackSequence, current: &TrackIdentifier): &TrackIdentifier {
    let len = self.0.length();
    assert!(len > 0, EEmptySequence);
    let cur = *self.0.get(current);
    let next_idx = (cur + 1) % len;
    let (next_track, _) = self.0.get_entry_by_idx(next_idx);
    next_track
}

public(package) fun previous(self: &TrackSequence, current: &TrackIdentifier): &TrackIdentifier {
    let len = self.0.length();
    assert!(len > 0, EEmptySequence);
    let cur = *self.0.get(current);
    let prev_idx = (cur + len - 1) % len;
    let (prev_track, _) = self.0.get_entry_by_idx(prev_idx);
    prev_track
}

public fun length(self: &TrackSequence): u64 {
    self.0.length()
}

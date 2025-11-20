// Copyright (c) Sona Labs, Pte Ltd.
// SPDX-License-Identifier: Apache-2.0

module musicos::track_identifier;

public struct TrackIdentifier(u8, u8) has copy, drop, store;

public fun new(disc_index: u8, track_index: u8): TrackIdentifier {
    TrackIdentifier(disc_index, track_index)
}

public(package) fun disc_idx(self: &TrackIdentifier): u8 {
    self.0
}

public(package) fun track_idx(self: &TrackIdentifier): u8 {
    self.1
}

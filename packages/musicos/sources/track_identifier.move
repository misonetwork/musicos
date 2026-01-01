// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module musicos::track_identifier;

//=== Structs ===

public struct TrackIdentifier(u8, u8) has drop, store;

//=== Package Functions ===

public(package) fun new(disc_index: u8, track_index: u8): TrackIdentifier {
    TrackIdentifier(disc_index, track_index)
}

//=== Package View Functions ===

public(package) fun disc_idx(self: &TrackIdentifier): u8 {
    self.0
}

public(package) fun track_idx(self: &TrackIdentifier): u8 {
    self.1
}

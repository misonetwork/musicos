// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Uniquely identifies a track within a release by its disc and track indices.
/// Used internally for track navigation and sequencing in multi-disc releases.
module musicos::track_position;

//=== Structs ===

/// A compact struct for a track's position within a release.
/// Stores the disc index and track index as a tuple.
public struct TrackPosition(
    /// Zero-based index of the disc within the release.
    u8,
    /// Zero-based index of the track within the disc.
    u8,
) has copy, drop, store;

//=== Package Functions ===

/// Creates a new track identifier with the specified disc and track indices.
public(package) fun new(disc_index: u8, track_index: u8): TrackPosition {
    TrackPosition(disc_index, track_index)
}

//=== Package View Functions ===

/// Returns the disc index component of this identifier.
public(package) fun disc_idx(self: &TrackPosition): u8 {
    self.0
}

/// Returns the track index component of this identifier.
public(package) fun track_idx(self: &TrackPosition): u8 {
    self.1
}

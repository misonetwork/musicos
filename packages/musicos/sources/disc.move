// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Represents a disc within a release, containing an ordered list of tracks.
/// Multi-disc releases (like double albums) are modeled as multiple Disc objects.
///
/// Key features:
/// - Maximum of 50 tracks per disc
/// - Automatic duration calculation from tracks
/// - Optional disc-specific artwork
module musicos::disc;

use musicos::track::Track;
use std::string::String;

//=== Structs ===

/// A disc containing an ordered list of tracks.
/// Duration is automatically calculated from the sum of track durations.
public struct Disc has drop, store {
    /// Ordered list of tracks on this disc.
    tracks: vector<Track>,
    /// Optional disc-specific artwork (e.g., for multi-disc sets with different covers).
    artwork: Option<String>,
    /// Total duration of all tracks in milliseconds.
    duration: u64,
}

//=== Constants ===

/// Maximum number of tracks allowed on a single disc.
const MAX_TRACKS_PER_DISC: u8 = 50;

//=== Errors ===

/// Number of tracks exceeds the maximum allowed (50).
const EMaxTracksExceeded: u64 = 0;

//=== Public Functions ===

/// Creates a new disc from a vector of tracks.
/// Automatically calculates the total duration.
/// Aborts if more than 50 tracks are provided.
public fun new(tracks: vector<Track>): Disc {
    assert!(tracks.length() <= MAX_TRACKS_PER_DISC as u64, EMaxTracksExceeded);

    let mut duration = 0;
    tracks.do_ref!(|track| {
        duration = duration + track.duration();
    });

    Disc {
        tracks,
        artwork: option::none(),
        duration,
    }
}

/// Sets or updates the disc-specific artwork.
public fun set_artwork(self: &mut Disc, artwork: String) {
    self.artwork.swap_or_fill(artwork);
}

//=== Public View Functions ===

/// Returns the optional disc-specific artwork.
public fun artwork(self: &Disc): Option<String> {
    self.artwork
}

/// Returns a reference to a track by its index on this disc.
public fun track(self: &Disc, track_idx: u8): &Track {
    &self.tracks[track_idx as u64]
}

/// Returns a reference to all tracks on this disc.
public fun tracks(self: &Disc): &vector<Track> {
    &self.tracks
}

/// Returns the total duration of this disc in milliseconds.
public fun duration(self: &Disc): u64 {
    self.duration
}

// Copyright (c) Studio Mirai, LLC
// SPDX-License-Identifier: Apache-2.0

/// Represents a disc within a release, containing an ordered list of tracks.
/// Multi-disc releases (like double albums) are modeled as multiple Disc objects.
///
/// ### Key Features:
///
/// - Maximum of 50 tracks per disc
/// - Automatic duration calculation from tracks
/// - Optional disc-specific artwork
module musicos::disc;

use musicos::cover_art::CoverArt;
use musicos::track::Track;
use std::string::String;

// === Structs ===

/// A disc containing an ordered list of tracks.
/// Duration is automatically calculated from the sum of track durations.
public struct Disc has drop, store {
    /// Ordered list of tracks on this disc.
    tracks: vector<Track>,
    /// Optional disc-specific artwork (e.g., for multi-disc sets with different covers).
    artwork: Option<CoverArt>,
    /// Title of the disc.
    title: Option<String>,
    /// Total duration of all tracks in milliseconds.
    duration_ms: u64,
}

// === Constants ===

/// Maximum number of tracks allowed on a single disc.
const MAX_TRACKS_PER_DISC: u64 = 50;

// === Errors ===

// Constraint errors (30-39)
/// Number of tracks exceeds the maximum allowed (50).
const EMaxTracksExceeded: u64 = 30;

// === Public Functions ===

/// Creates a new disc from a vector of tracks.
/// Automatically calculates the total duration.
/// Aborts if more than 50 tracks are provided.
public fun new(tracks: vector<Track>, title: Option<String>): Disc {
    assert!(tracks.length() <= MAX_TRACKS_PER_DISC, EMaxTracksExceeded);

    let mut duration_ms = 0;
    tracks.do_ref!(|track| {
        duration_ms = duration_ms + track.duration_ms();
    });

    Disc {
        tracks,
        artwork: option::none(),
        title,
        duration_ms,
    }
}

/// Sets or updates the disc-specific artwork.
public fun set_artwork(self: &mut Disc, artwork: CoverArt) {
    self.artwork.swap_or_fill(artwork);
}

// === Public View Functions ===

/// Returns a reference to all tracks on this disc.
public fun tracks(self: &Disc): &vector<Track> {
    &self.tracks
}

/// Returns the optional disc-specific artwork.
public fun artwork(self: &Disc): &Option<CoverArt> {
    &self.artwork
}

/// Returns the total duration of this disc in milliseconds.
public fun duration_ms(self: &Disc): u64 {
    self.duration_ms
}

/// Returns the optional title of this disc.
public fun title(self: &Disc): &Option<String> {
    &self.title
}

// === Package Functions ===

/// Returns a mutable reference to the tracks vector.
/// Used internally for track assignment during release creation.
public(package) fun tracks_mut(self: &mut Disc): &mut vector<Track> {
    &mut self.tracks
}

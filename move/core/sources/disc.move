// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Represents a disc within a release, containing an ordered list of tracks.
/// Multi-disc releases (like double albums) are modeled as multiple Disc objects.
///
/// ### Key Features:
///
/// - Maximum of 50 tracks per disc
/// - Automatic duration calculation from tracks
///
/// Artwork is intentionally NOT part of core: it is display metadata whose
/// format evolves over time (static → animated → future formats), so it lives
/// in the `artwork` extension (keyed by disc index on the release) rather than
/// frozen in an immutable struct here.
module miso::disc;

use miso::track::Track;
use std::string::String;

// === Structs ===

/// A disc containing an ordered list of tracks.
public struct Disc has drop, store {
    /// Ordered list of tracks on this disc.
    tracks: vector<Track>,
    /// Title of the disc.
    title: Option<String>,
}

// === Constants ===

/// Maximum number of tracks allowed on a single disc.
const MAX_TRACKS_PER_DISC: u64 = 50;
/// Maximum length of a disc title in bytes.
const MAX_TITLE_LENGTH: u64 = 300;

// === Errors ===

// Constraint errors (30-39)
/// Number of tracks exceeds the maximum allowed (50).
const EMaxTracksExceeded: u64 = 30;
/// Title exceeds maximum length.
const EMaxTitleLengthExceeded: u64 = 31;
/// String must not be empty.
const EEmptyString: u64 = 32;

// === Public Functions ===

/// Creates a new disc from a vector of tracks.
/// Aborts if more than 50 tracks are provided, or if a title is provided
/// that is empty or longer than 300 bytes. Discs are embedded in a release
/// and frozen at publish, so the title must be valid at construction.
public fun new(tracks: vector<Track>, title: Option<String>): Disc {
    assert!(tracks.length() <= MAX_TRACKS_PER_DISC, EMaxTracksExceeded);
    if (title.is_some()) {
        let t = title.borrow();
        assert!(!t.is_empty(), EEmptyString);
        assert!(t.length() <= MAX_TITLE_LENGTH, EMaxTitleLengthExceeded);
    };

    Disc {
        tracks,
        title,
    }
}

// === Public View Functions ===

/// Returns a reference to all tracks on this disc.
public fun tracks(self: &Disc): &vector<Track> {
    &self.tracks
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

// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module musicos::disc;

use musicos::protocol::Protocol;
use musicos::track::Track;
use std::string::String;

//=== Structs ===

public struct Disc has drop, store {
    tracks: vector<Track>,
    artwork: Option<String>,
    duration: u64,
}

//=== Constants ===

const MAX_TRACKS_PER_DISC: u8 = 50;

//=== Errors ===

const EMaxTracksExceeded: u64 = 0;

//=== Public Functions ===

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

public fun set_artwork(self: &mut Disc, artwork: String) {
    self.artwork.swap_or_fill(artwork);
}

//=== Public View Functions ===

public fun artwork(self: &Disc): Option<String> {
    self.artwork
}

public fun track(self: &Disc, track_idx: u8): &Track {
    &self.tracks[track_idx as u64]
}

public fun tracks(self: &Disc): &vector<Track> {
    &self.tracks
}

public fun duration(self: &Disc): u64 {
    self.duration
}

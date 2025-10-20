module musicos::disc;

use musicos::track::Track;

//=== Structs ===

public struct Disc has drop, store {
    tracks: vector<Track>,
    duration: u64,
}

//=== Constants ===

const MAX_TRACKS: u64 = 50;

//=== Errors ===

const EMaxTracksExceeded: u64 = 0;

//=== Public Functions ===

public fun new(tracks: vector<Track>): Disc {
    assert!(tracks.length() <= MAX_TRACKS, EMaxTracksExceeded);

    let mut duration: u64 = 0;
    tracks.do_ref!(|track| duration = duration + track.duration());

    let disc = Disc {
        tracks,
        duration,
    };

    disc
}

//=== Public View Functions ===

public fun tracks(self: &Disc): &vector<Track> {
    &self.tracks
}

public fun duration(self: &Disc): u64 {
    self.duration
}

module musicos::disc_spec;

#[spec_only]
use prover::prover::{requires, ensures};
use musicos::disc;
use musicos::track::Track;

#[spec(prove, ignore_abort)]
fun new_enforces_max_tracks(tracks: vector<Track>, title: Option<std::string::String>): disc::Disc {
    requires(tracks.length() <= 50);
    let result = disc::new(tracks, title);
    ensures(result.tracks().length() <= 50);
    result
}

#[spec(prove, ignore_abort)]
fun new_aborts_too_many_tracks(tracks: vector<Track>, title: Option<std::string::String>) {
    requires(tracks.length() > 50);
    let _result = disc::new(tracks, title);
    ensures(false);
}

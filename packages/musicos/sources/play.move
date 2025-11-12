module musicos::play;

use musicos::protocol::Protocol;
use std::string::String;
use sui::event::emit;

public struct Play {
    composition_id: ID,
    recording_id: ID,
    duration: u64,
    genre: String,
}

public struct PlayCreatedEvent has copy, drop {
    composition_id: ID,
    recording_id: ID,
    duration: u64,
}

public fun new<Authority: drop>(
    _: Authority,
    composition_id: ID,
    recording_id: ID,
    duration: u64,
    genre: String,
    protocol: &Protocol,
): Play {
    protocol.assert_is_play_authority<Authority>();

    emit(PlayCreatedEvent {
        composition_id,
        recording_id,
        duration,
    });

    Play {
        composition_id,
        recording_id,
        duration,
        genre,
    }
}

public fun composition_id(self: &Play): ID {
    self.composition_id
}

public fun recording_id(self: &Play): ID {
    self.recording_id
}

public fun duration(self: &Play): u64 {
    self.duration
}

public fun genre(self: &Play): String {
    self.genre
}

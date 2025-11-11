module musicos::play;

use musicos::protocol::Protocol;
use sui::event::emit;

public struct Play {
    composition_id: ID,
    recording_id: ID,
    duration: u64,
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
    }
}

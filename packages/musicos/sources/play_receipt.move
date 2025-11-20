module musicos::play_receipt;

use musicos::protocol::Protocol;
use std::string::String;
use sui::event::emit;

public struct PlayReceipt {
    composition_id: ID,
    recording_id: ID,
    playtime: u64,
    genre_id: ID,
}

public struct PlayReceiptCreatedEvent has copy, drop {
    composition_id: ID,
    recording_id: ID,
    playtime: u64,
}

public fun new<Authority: drop>(
    _: Authority,
    composition_id: ID,
    recording_id: ID,
    playtime: u64,
    genre_id: ID,
    protocol: &Protocol,
): PlayReceipt {
    protocol.assert_is_play_authority<Authority>();

    emit(PlayReceiptCreatedEvent {
        composition_id,
        recording_id,
        playtime,
    });

    PlayReceipt {
        composition_id,
        recording_id,
        playtime,
        genre_id,
    }
}

public fun composition_id(self: &PlayReceipt): ID {
    self.composition_id
}

public fun recording_id(self: &PlayReceipt): ID {
    self.recording_id
}

public fun playtime(self: &PlayReceipt): u64 {
    self.playtime
}

public fun genre_id(self: &PlayReceipt): ID {
    self.genre_id
}

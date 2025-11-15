module musicos::play_receipt;

use musicos::protocol::Protocol;
use std::string::String;
use sui::event::emit;

public struct PlayReceipt {
    composition_id: ID,
    recording_id: ID,
    duration: u64,
    genre: String,
}

public struct PlayReceiptCreatedEvent has copy, drop {
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
): PlayReceipt {
    protocol.assert_is_play_authority<Authority>();

    emit(PlayReceiptCreatedEvent {
        composition_id,
        recording_id,
        duration,
    });

    PlayReceipt {
        composition_id,
        recording_id,
        duration,
        genre,
    }
}

public fun composition_id(self: &PlayReceipt): ID {
    self.composition_id
}

public fun recording_id(self: &PlayReceipt): ID {
    self.recording_id
}

public fun duration(self: &PlayReceipt): u64 {
    self.duration
}

public fun genre(self: &PlayReceipt): String {
    self.genre
}

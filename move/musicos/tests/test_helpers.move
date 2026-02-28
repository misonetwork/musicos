#[test_only]
module musicos::test_helpers;

use musicos::audio;
use musicos::cover_art;
use musicos::party::{Self, Party, PartyAdminCap};
use std::string::String;
use walrus_data::walrus_data;

/// Phantom type for composition share tokens in tests.
public struct CompositionShare() has drop;
/// Phantom type for recording share tokens in tests.
public struct RecordingShare() has drop;
/// Phantom type for audio ingester witness in tests.
public struct V() has drop;

/// Creates a WalrusData reference for testing.
public fun walrus(): walrus_data::WalrusData {
    walrus_data::new_blob(1)
}

/// Creates a verified Audio object for testing (stereo, 16-bit, 44100 Hz, 10 seconds).
public fun audio(): audio::Audio {
    audio::new(2, 16, 44100, 441000, walrus_data::new_blob(1), V())
}

/// Creates a valid CoverArt object for testing.
public fun cover_art(): cover_art::CoverArt {
    cover_art::new(walrus(), option::none())
}

/// Creates an individual party with a default name for testing.
public fun individual(ctx: &mut TxContext): (Party, PartyAdminCap) {
    party::new(party::new_individual_kind(), b"Test Artist".to_string(), ctx)
}

/// Creates an individual party with a custom name for testing.
public fun individual_named(name: String, ctx: &mut TxContext): (Party, PartyAdminCap) {
    party::new(party::new_individual_kind(), name, ctx)
}

/// Creates a group party with a default name for testing.
public fun group(ctx: &mut TxContext): (Party, PartyAdminCap) {
    party::new(party::new_group_kind(), b"Test Group".to_string(), ctx)
}

/// Creates a string of the given length filled with 'A' characters.
public fun long_string(len: u64): String {
    let mut s = vector<u8>[];
    len.do!(|_| s.push_back(65));
    s.to_string()
}

/// Creates a fake ID for testing by creating and immediately deleting a UID.
public fun fake_id(ctx: &mut TxContext): ID {
    let uid = object::new(ctx);
    let id = uid.to_inner();
    uid.delete();
    id
}

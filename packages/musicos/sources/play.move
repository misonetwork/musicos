// Copyright (c) Sona Labs, Pte Ltd.
// SPDX-License-Identifier: Apache-2.0

module musicos::play;

use musicos::protocol::Protocol;
use std::type_name::{TypeName, with_defining_ids};
use sui::clock::Clock;
use sui::event::emit;

//=== Structs ===

public struct Play<phantom Player> {
    // Unique identifier for the play receipt.
    // We use a fresh address instead of a UID because `Play` is a hot potato.
    play_id: ID,
    play_authority_type: TypeName,
    player_id: Option<ID>,
    composition_id: ID,
    recording_id: ID,
    genre_id: ID,
    played_by: address,
    play_epoch: u64,
    play_timestamp_ms: u64,
    played_duration: u64,
    track_duration: u64,
}

//=== Events ===

public struct PlayCreatedEvent<phantom Player> has copy, drop {
    play_id: ID,
    play_authority_type: TypeName,
    player_id: Option<ID>,
    composition_id: ID,
    recording_id: ID,
    genre_id: ID,
    played_by: address,
    play_epoch: u64,
    play_timestamp_ms: u64,
    played_duration: u64,
    track_duration: u64,
}

//=== Errors ===

const ENotPlayAuthority: u64 = 0;

//=== Public Functions ===

public fun new<Authority: drop, Player>(
    _: Authority,
    player_id: Option<ID>,
    composition_id: ID,
    recording_id: ID,
    genre_id: ID,
    played_duration: u64,
    track_duration: u64,
    protocol: &Protocol,
    clock: &Clock,
    ctx: &mut TxContext,
): Play<Player> {
    let play_authority_type = with_defining_ids<Authority>();
    // TODO: Maybe move to protocol.move?
    assert!(protocol.play_authority_types().contains(&play_authority_type), ENotPlayAuthority);

    let play_id = ctx.fresh_object_address().to_id();
    let played_by = ctx.sender();
    let play_epoch = ctx.epoch();
    let play_timestamp_ms = clock.timestamp_ms();

    emit(PlayCreatedEvent<Player> {
        play_id,
        play_authority_type,
        player_id,
        composition_id,
        recording_id,
        genre_id,
        played_by,
        play_epoch,
        play_timestamp_ms,
        played_duration,
        track_duration,
    });

    Play {
        play_id,
        play_authority_type,
        player_id,
        composition_id,
        recording_id,
        genre_id,
        played_by,
        play_epoch,
        play_timestamp_ms,
        played_duration,
        track_duration,
    }
}

//=== Public View Functions ===

public fun play_id<Player>(self: &Play<Player>): ID {
    self.play_id
}

public fun play_authority_type<Player>(self: &Play<Player>): TypeName {
    self.play_authority_type
}

public fun player_id<Player>(self: &Play<Player>): Option<ID> {
    self.player_id
}

public fun composition_id<Player>(self: &Play<Player>): ID {
    self.composition_id
}

public fun recording_id<Player>(self: &Play<Player>): ID {
    self.recording_id
}

public fun genre_id<Player>(self: &Play<Player>): ID {
    self.genre_id
}

public fun played_by<Player>(self: &Play<Player>): address {
    self.played_by
}

public fun play_epoch<Player>(self: &Play<Player>): u64 {
    self.play_epoch
}

public fun play_timestamp_ms<Player>(self: &Play<Player>): u64 {
    self.play_timestamp_ms
}

public fun played_duration<Player>(self: &Play<Player>): u64 {
    self.played_duration
}

public fun track_duration<Player>(self: &Play<Player>): u64 {
    self.track_duration
}

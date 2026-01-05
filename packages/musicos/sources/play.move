// Copyright (c) Sona Labs, Pte Ltd.
// SPDX-License-Identifier: Apache-2.0

module musicos::play;

use musicos::protocol::Protocol;
use std::type_name::with_defining_ids;
use sui::clock::Clock;
use sui::event::emit;

//=== Structs ===

public struct Play<phantom Authority: drop> has drop {
    play_id: address,
    player_id: Option<ID>,
    composition_id: ID,
    recording_id: ID,
    genre_id: ID,
    played_by: address,
    play_epoch: u64,
    play_timestamp_ms: u64,
    playtime: u64,
    track_duration: u64,
}

//=== Events ===

public struct PlayCreatedEvent<phantom Authority: drop> has copy, drop {
    play_id: address,
    player_id: Option<ID>,
    composition_id: ID,
    recording_id: ID,
    genre_id: ID,
    played_by: address,
    play_epoch: u64,
    play_timestamp_ms: u64,
    playtime: u64,
    track_duration: u64,
}

//=== Errors ===

const ENotPlayAuthority: u64 = 0;

//=== Public Functions ===

public fun new<Authority: drop>(
    _: Authority,
    player_id: Option<ID>,
    composition_id: ID,
    recording_id: ID,
    genre_id: ID,
    playtime: u64,
    track_duration: u64,
    protocol: &Protocol,
    clock: &Clock,
    ctx: &mut TxContext,
): Play<Authority> {
    assert!(
        protocol.play_authority_types().contains(&with_defining_ids<Authority>()),
        ENotPlayAuthority,
    );

    let play_id = ctx.fresh_object_address();
    let played_by = ctx.sender();
    let play_epoch = ctx.epoch();
    let play_timestamp_ms = clock.timestamp_ms();

    emit(PlayCreatedEvent<Authority> {
        play_id,
        player_id,
        composition_id,
        recording_id,
        genre_id,
        played_by,
        play_epoch,
        play_timestamp_ms,
        playtime,
        track_duration,
    });

    Play {
        play_id,
        player_id,
        composition_id,
        recording_id,
        genre_id,
        played_by,
        play_epoch,
        play_timestamp_ms,
        playtime,
        track_duration,
    }
}

//=== Public View Functions ===

public fun play_id<Authority: drop>(self: &Play<Authority>): address {
    self.play_id
}

public fun player_id<Authority: drop>(self: &Play<Authority>): Option<ID> {
    self.player_id
}

public fun composition_id<Authority: drop>(self: &Play<Authority>): ID {
    self.composition_id
}

public fun recording_id<Authority: drop>(self: &Play<Authority>): ID {
    self.recording_id
}

public fun genre_id<Authority: drop>(self: &Play<Authority>): ID {
    self.genre_id
}

public fun played_by<Authority: drop>(self: &Play<Authority>): address {
    self.played_by
}

public fun play_epoch<Authority: drop>(self: &Play<Authority>): u64 {
    self.play_epoch
}

public fun play_timestamp_ms<Authority: drop>(self: &Play<Authority>): u64 {
    self.play_timestamp_ms
}

public fun playtime<Authority: drop>(self: &Play<Authority>): u64 {
    self.playtime
}

public fun track_duration<Authority: drop>(self: &Play<Authority>): u64 {
    self.track_duration
}

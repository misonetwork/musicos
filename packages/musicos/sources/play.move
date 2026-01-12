// Copyright (c) Sona Labs, Pte Ltd.
// SPDX-License-Identifier: Apache-2.0

/// Records a playback event for a recording in the MusicOS protocol.
/// Plays track when and how long a recording was streamed, enabling
/// royalty calculations and analytics. Only authorized authorities
/// (registered in the Protocol) can create play events.
///
/// Key features:
/// - Authority-gated play creation via phantom type parameter
/// - Timestamped playback tracking with duration metrics
/// - Event emission for off-chain indexing and analytics
module musicos::play;

use musicos::protocol::Protocol;
use std::type_name::with_defining_ids;
use sui::clock::Clock;
use sui::event::emit;

//=== Structs ===

/// A record of a single playback event for a recording.
/// The phantom Authority type ensures only registered authorities can create plays.
public struct Play<phantom Authority: drop> has drop {
    /// Unique identifier for this play event.
    play_id: address,
    /// Optional identifier of the player/user who initiated playback.
    player_id: Option<ID>,
    /// The composition that was played.
    composition_id: ID,
    /// The recording that was played.
    recording_id: ID,
    /// The genre of the recording.
    genre_id: ID,
    /// Address of the account that triggered the play.
    played_by: address,
    /// Epoch when the play occurred.
    play_epoch: u64,
    /// Timestamp in milliseconds when the play occurred.
    play_timestamp_ms: u64,
    /// Duration of playback in seconds.
    playtime_s: u64,
    /// Total duration of the track in seconds.
    track_duration_s: u64,
}

//=== Events ===

/// Emitted when a new play event is recorded.
public struct PlayCreatedEvent<phantom Authority: drop> has copy, drop {
    /// Unique identifier for this play event.
    play_id: address,
    /// Optional identifier of the player/user who initiated playback.
    player_id: Option<ID>,
    /// The composition that was played.
    composition_id: ID,
    /// The recording that was played.
    recording_id: ID,
    /// The genre of the recording.
    genre_id: ID,
    /// Address of the account that triggered the play.
    played_by: address,
    /// Epoch when the play occurred.
    play_epoch: u64,
    /// Timestamp in milliseconds when the play occurred.
    play_timestamp_ms: u64,
    /// Duration of playback in seconds.
    playtime_s: u64,
    /// Total duration of the track in seconds.
    track_duration_s: u64,
}

//=== Errors ===

/// The provided authority type is not registered as a play authority.
const ENotPlayAuthority: u64 = 0;

//=== Public Functions ===

/// Creates a new play event for a recording.
/// Requires a witness of an authorized Authority type registered in the Protocol.
/// Emits a PlayCreatedEvent for off-chain tracking.
public fun new<Authority: drop>(
    _: Authority,
    player_id: Option<ID>,
    composition_id: ID,
    recording_id: ID,
    genre_id: ID,
    playtime_s: u64,
    track_duration_s: u64,
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
        playtime_s,
        track_duration_s,
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
        playtime_s,
        track_duration_s,
    }
}

//=== Public View Functions ===

/// Returns the unique identifier of this play event.
public fun play_id<Authority: drop>(self: &Play<Authority>): address {
    self.play_id
}

/// Returns the optional player/user identifier.
public fun player_id<Authority: drop>(self: &Play<Authority>): Option<ID> {
    self.player_id
}

/// Returns the ID of the composition that was played.
public fun composition_id<Authority: drop>(self: &Play<Authority>): ID {
    self.composition_id
}

/// Returns the ID of the recording that was played.
public fun recording_id<Authority: drop>(self: &Play<Authority>): ID {
    self.recording_id
}

/// Returns the genre ID of the recording.
public fun genre_id<Authority: drop>(self: &Play<Authority>): ID {
    self.genre_id
}

/// Returns the address that triggered the play.
public fun played_by<Authority: drop>(self: &Play<Authority>): address {
    self.played_by
}

/// Returns the epoch when the play occurred.
public fun play_epoch<Authority: drop>(self: &Play<Authority>): u64 {
    self.play_epoch
}

/// Returns the timestamp in milliseconds when the play occurred.
public fun play_timestamp_ms<Authority: drop>(self: &Play<Authority>): u64 {
    self.play_timestamp_ms
}

/// Returns the duration of playback in seconds.
public fun playtime_s<Authority: drop>(self: &Play<Authority>): u64 {
    self.playtime_s
}

/// Returns the total track duration in seconds.
public fun track_duration_s<Authority: drop>(self: &Play<Authority>): u64 {
    self.track_duration_s
}

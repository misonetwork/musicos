// Copyright (c) Unconfirmed Labs, LLC
// SPDX-License-Identifier: Apache-2.0

/// Represents a deal authorizing a recording to be included in a release.
/// Deals are created by recording owners to grant permission for their
/// recordings to appear on specific releases with agreed-upon revenue splits.
///
/// ### Flow:
///
/// - A recording owner creates a `Deal` specifying the target release,
///   track split, and optional overrides for title and cover art.
/// - The deal is consumed by `track::new` to create a track, transferring
///   the recording's metadata and authorization into the release.
/// - Deals can be destroyed if no longer needed.
module musicos::deal;

use interest_bps::bps::{Self, BPS};
use musicos::composition::Composition;
use musicos::cover_art::CoverArt;
use musicos::recording::{Recording, RecordingAdminCap};
use std::string::String;
use std::type_name::{TypeName, with_defining_ids};
use sui::event::emit;

// === Structs ===

/// A deal authorizing a recording's inclusion in a release.
/// Contains all metadata needed to create a track from the recording.
public struct Deal has key, store {
    /// Unique identifier for this deal.
    id: UID,
    /// ID of the target release this deal authorizes.
    release_id: ID,
    /// ID of the underlying composition.
    composition_id: ID,
    /// Type of the composition's share token.
    composition_share_type: TypeName,
    /// Revenue split for the composition in basis points.
    composition_split_bps: BPS,
    /// Ingester of the composition's demo audio file.
    composition_demo_ingester_type: Option<TypeName>,
    /// ID of the recording being authorized.
    recording_id: ID,
    /// Type of the recording's share token.
    recording_share_type: TypeName,
    /// Duration of the recording in milliseconds.
    recording_duration_ms: u64,
    /// Ingester of the recording's master audio file.
    recording_master_ingester_type: TypeName,
    /// Ingester types of the recording's stem audio files.
    recording_stem_ingester_types: vector<TypeName>,
    /// Title for the track (defaults to recording title).
    track_title: String,
    /// Revenue split allocated to this track in basis points.
    track_split_bps: BPS,
    /// Cover art for the track (defaults to recording cover art).
    track_cover_art: CoverArt,
}

/// Emitted when a new deal is created.
public struct DealCreatedEvent has copy, drop {
    /// ID of the deal.
    deal_id: ID,
    /// ID of the target release.
    release_id: ID,
    /// ID of the recording.
    recording_id: ID,
    /// ID of the composition.
    composition_id: ID,
}

/// Emitted when a deal is destroyed.
public struct DealDestroyedEvent has copy, drop {
    /// ID of the deal.
    deal_id: ID,
    /// ID of the target release.
    release_id: ID,
    /// ID of the recording.
    recording_id: ID,
    /// ID of the composition.
    composition_id: ID,
}

// === Public Functions ===

/// Creates a new deal authorizing a recording for inclusion in a release.
/// Requires the recording admin capability. Captures recording metadata
/// at creation time. Optional title and cover art override the recording defaults.
public fun new<CompositionShare, RecordingShare>(
    _: &RecordingAdminCap<RecordingShare>,
    composition: &Composition<CompositionShare>,
    recording: &Recording<RecordingShare>,
    release_id: ID,
    track_split_bps_value: u64,
    track_title: Option<String>,
    track_cover_art: Option<CoverArt>,
    ctx: &mut TxContext,
): Deal {
    let recording_id = recording.id();
    let composition_id = recording.composition_id();

    let deal = Deal {
        id: object::new(ctx),
        release_id,
        composition_id,
        composition_share_type: *recording.composition_share_type(),
        composition_split_bps: recording.composition_split_bps(),
        composition_demo_ingester_type: composition.demo_ingester_type(),
        recording_id,
        recording_share_type: with_defining_ids<RecordingShare>(),
        recording_duration_ms: recording.master().duration_ms(),
        recording_master_ingester_type: *recording.master().ingester_type(),
        recording_stem_ingester_types: recording.stem_ingester_types(),
        track_title: track_title.destroy_or!(*recording.title()),
        track_split_bps: bps::new(track_split_bps_value),
        track_cover_art: track_cover_art.destroy_with_default(*recording.cover_art()),
    };

    emit(DealCreatedEvent {
        deal_id: deal.id(),
        release_id,
        recording_id: recording.id(),
        composition_id: recording.composition_id(),
    });

    deal
}

/// Destroys a deal, emitting a `DealDestroyedEvent`.
/// Used when a deal is no longer needed or the negotiation falls through.
public fun destroy(self: Deal) {
    let Deal { id, release_id, recording_id, composition_id, .. } = self;

    emit(DealDestroyedEvent {
        deal_id: id.to_inner(),
        release_id,
        recording_id,
        composition_id,
    });

    id.delete();
}

// === Public View Functions ===

/// Returns the deal's object ID.
public fun id(self: &Deal): ID {
    self.id.to_inner()
}

/// Returns the ID of the target release.
public fun release_id(self: &Deal): ID {
    self.release_id
}

/// Returns the ID of the underlying composition.
public fun composition_id(self: &Deal): ID {
    self.composition_id
}

/// Returns the type of the composition's share token.
public fun composition_share_type(self: &Deal): &TypeName {
    &self.composition_share_type
}

/// Returns the ingester of the composition's demo audio file.
public fun composition_demo_ingester_type(self: &Deal): &Option<TypeName> {
    &self.composition_demo_ingester_type
}

/// Returns the composition's revenue split in basis points.
public fun composition_split_bps(self: &Deal): BPS {
    self.composition_split_bps
}

/// Returns the ID of the recording being authorized.
public fun recording_id(self: &Deal): ID {
    self.recording_id
}

/// Returns the type of the recording's share token.
public fun recording_share_type(self: &Deal): &TypeName {
    &self.recording_share_type
}

/// Returns the duration of the recording in milliseconds.
public fun recording_duration_ms(self: &Deal): u64 {
    self.recording_duration_ms
}

/// Returns the ingester of the recording's master audio file.
public fun recording_master_ingester_type(self: &Deal): &TypeName {
    &self.recording_master_ingester_type
}

/// Returns the ingester types of the recording's stem audio files.
public fun recording_stem_ingester_types(self: &Deal): &vector<TypeName> {
    &self.recording_stem_ingester_types
}

/// Returns the track title.
public fun track_title(self: &Deal): &String {
    &self.track_title
}

/// Returns the track's revenue split in basis points.
public fun track_split_bps(self: &Deal): BPS {
    self.track_split_bps
}

/// Returns a reference to the track's cover art.
public fun track_cover_art(self: &Deal): &CoverArt {
    &self.track_cover_art
}

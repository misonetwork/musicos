// Copyright (c) Miso Labs, Inc.
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

use bps::bps::{Self, BPS};
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
    /// Royalty rate owed to the composition.
    composition_royalty_rate: BPS,
    /// ID of the recording being authorized.
    recording_id: ID,
    /// Type of the recording's share token.
    recording_share_type: TypeName,
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
    /// Title for the track (may override recording title).
    track_title: String,
    /// Track-level revenue split in basis points.
    track_split_bps_value: u16,
    /// Static cover art blob ID for the track.
    track_cover_art_static_blob_id: u256,
    /// Animated cover art blob ID for the track, if present.
    track_cover_art_animated_blob_id: Option<u256>,
}

/// Emitted when a deal is accepted: consumed by `track::new` into a track for
/// its target release. In the honest path this lands in the same transaction
/// as the release's `ReleasePublishedEvent` (a track cannot outlive its
/// transaction unless wrapped), so indexers should treat acceptance as
/// provisional until the release publishes.
public struct DealAcceptedEvent has copy, drop {
    /// ID of the deal.
    deal_id: ID,
    /// ID of the target release.
    release_id: ID,
    /// ID of the recording.
    recording_id: ID,
    /// ID of the composition.
    composition_id: ID,
}

/// Emitted when a deal is rejected: destroyed without being included in a
/// release, whether declined by the holder or withdrawn by its creator.
/// Terminal — the deal no longer exists.
public struct DealRejectedEvent has copy, drop {
    /// ID of the deal.
    deal_id: ID,
    /// ID of the target release.
    release_id: ID,
    /// ID of the recording.
    recording_id: ID,
    /// ID of the composition.
    composition_id: ID,
}

// === Constants ===

/// Maximum length of a track title in bytes (matches recording/composition titles).
const MAX_TRACK_TITLE_LENGTH: u64 = 300;

// === Errors ===

/// Composition ID mismatch between recording and composition.
const ECompositionIdMismatch: u64 = 0;

// Constraint errors (30-39)
/// Track title exceeds maximum length.
const EMaxTrackTitleLengthExceeded: u64 = 30;
/// String must not be empty.
const EEmptyString: u64 = 31;

// === Public Functions ===

/// Creates a new deal authorizing a recording for inclusion in a release.
/// Requires the recording admin capability. Captures recording metadata
/// at creation time. Optional title and cover art override the recording defaults.
public fun new<CompositionShare, RecordingShare>(
    _: &RecordingAdminCap<RecordingShare>,
    composition: &Composition<CompositionShare>,
    recording: &Recording<RecordingShare>,
    release_id: ID,
    track_split_bps_value: u16,
    track_title: Option<String>,
    track_cover_art: Option<CoverArt>,
    ctx: &mut TxContext,
): Deal {
    let recording_id = recording.id();
    let composition_id = composition.id();

    assert!(composition_id == recording.composition_id(), ECompositionIdMismatch);

    // The track title becomes immutable release content; an override must meet
    // the same rules as the recording title it replaces.
    let track_title = track_title.destroy_or!(*recording.title());
    assert!(!track_title.is_empty(), EEmptyString);
    assert!(track_title.length() <= MAX_TRACK_TITLE_LENGTH, EMaxTrackTitleLengthExceeded);

    let deal = Deal {
        id: object::new(ctx),
        release_id,
        composition_id,
        composition_share_type: with_defining_ids<CompositionShare>(),
        composition_royalty_rate: recording.composition_royalty_rate(),
        recording_id,
        recording_share_type: with_defining_ids<RecordingShare>(),
        track_title,
        track_split_bps: bps::new(track_split_bps_value),
        track_cover_art: track_cover_art.destroy_with_default(*recording.cover_art()),
    };

    let track_cover_art_animated_blob_id = if (deal.track_cover_art.animated().is_some()) {
        option::some(deal.track_cover_art.animated().borrow().blob_id())
    } else {
        option::none()
    };

    emit(DealCreatedEvent {
        deal_id: deal.id(),
        release_id,
        recording_id: recording.id(),
        composition_id: recording.composition_id(),
        track_title: deal.track_title,
        track_split_bps_value: deal.track_split_bps.value(),
        track_cover_art_static_blob_id: deal.track_cover_art.still().blob_id(),
        track_cover_art_animated_blob_id,
    });

    deal
}

/// Accepts the deal, consuming it into a track. Called only by `track::new`.
/// Emits a `DealAcceptedEvent`.
public(package) fun accept(self: Deal) {
    emit(DealAcceptedEvent {
        deal_id: self.id(),
        release_id: self.release_id,
        recording_id: self.recording_id,
        composition_id: self.composition_id,
    });

    self.destroy_internal();
}

/// Rejects the deal, destroying it without inclusion in a release.
/// Used when the holder declines or the negotiation falls through.
/// Emits a `DealRejectedEvent`.
public fun reject(self: Deal) {
    emit(DealRejectedEvent {
        deal_id: self.id(),
        release_id: self.release_id,
        recording_id: self.recording_id,
        composition_id: self.composition_id,
    });

    self.destroy_internal();
}

/// Unpacks and deletes the deal without emitting anything. Event emission is
/// the caller's job — `accept` and `reject` are the only callers, so every
/// deal death is announced exactly once, with its meaning.
fun destroy_internal(self: Deal) {
    let Deal { id, .. } = self;
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

/// Returns the royalty rate owed to the composition.
public fun composition_royalty_rate(self: &Deal): BPS {
    self.composition_royalty_rate
}

/// Returns the ID of the recording being authorized.
public fun recording_id(self: &Deal): ID {
    self.recording_id
}

/// Returns the type of the recording's share token.
public fun recording_share_type(self: &Deal): &TypeName {
    &self.recording_share_type
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

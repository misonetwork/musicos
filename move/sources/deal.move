// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Represents a deal authorizing a recording to be included in a release.
/// Deals are created by recording owners to grant permission for their
/// recordings to appear on specific releases with agreed-upon revenue splits.
///
/// ### Flow:
///
/// - A recording owner creates a `Deal` specifying the target release and
///   track split.
/// - The deal is consumed by `track::new` to create a track, transferring
///   the recording's authorization into the release.
/// - Deals can be destroyed if no longer needed.
///
/// `Deal<RecordingShare, CompositionShare>` carries the recording's and
/// composition's identities as phantom type parameters rather than stored
/// values — a `Deal` is consumed one-to-one into a `Track` and is never
/// collected, so it has no reason to flatten to `TypeName`s early. The
/// recording↔composition pairing is type-enforced at `new` via the
/// `Recording<RecordingShare, CompositionShare>` argument — no ID is stored and
/// no runtime assert is needed.
///
/// A deal carries only what is genuinely release-specific and non-derivable:
/// the target `release_id`, the `recording_id` (the revenue routing target),
/// and the `track_split_bps`. Display metadata (title, cover art) is *not*
/// duplicated here — it is derived from the recording.
module musicos::deal;

use bps::bps::{Self, BPS};
use musicos::recording::{Recording, RecordingAdminCap};
use sui::event::emit;

// === Structs ===

/// A deal authorizing a recording's inclusion in a release.
public struct Deal<phantom RecordingShare, phantom CompositionShare> has key, store {
    /// Unique identifier for this deal.
    id: UID,
    /// ID of the target release this deal authorizes.
    release_id: ID,
    /// ID of the recording being authorized. Kept as an `ID` (not a type) because
    /// revenue routing needs the recording's address, which a type can't provide.
    recording_id: ID,
    /// Revenue split allocated to this track in basis points.
    track_split_bps: BPS,
}

/// Emitted when a new deal is created. The recording and composition identities
/// are the event's `RecordingShare`/`CompositionShare` phantoms.
public struct DealCreatedEvent<phantom RecordingShare, phantom CompositionShare> has copy, drop {
    /// ID of the deal.
    deal_id: ID,
    /// ID of the target release.
    release_id: ID,
    /// ID of the recording.
    recording_id: ID,
    /// Track-level revenue split in basis points.
    track_split_bps_value: u16,
}

/// Emitted when a deal is accepted: consumed by `track::new` into a track for
/// its target release. In the honest path this lands in the same transaction
/// as the release's `ReleasePublishedEvent` (a track cannot outlive its
/// transaction unless wrapped), so indexers should treat acceptance as
/// provisional until the release publishes.
public struct DealAcceptedEvent<phantom RecordingShare, phantom CompositionShare> has copy, drop {
    /// ID of the deal.
    deal_id: ID,
    /// ID of the target release.
    release_id: ID,
    /// ID of the recording.
    recording_id: ID,
}

/// Emitted when a deal is rejected: destroyed without being included in a
/// release, whether declined by the holder or withdrawn by its creator.
/// Terminal — the deal no longer exists.
public struct DealRejectedEvent<phantom RecordingShare, phantom CompositionShare> has copy, drop {
    /// ID of the deal.
    deal_id: ID,
    /// ID of the target release.
    release_id: ID,
    /// ID of the recording.
    recording_id: ID,
}

// === Public Functions ===

/// Creates a new deal authorizing a recording for inclusion in a release.
/// Requires the recording admin capability.
///
/// The composition is identified by the recording's `CompositionShare` phantom,
/// so the recording↔composition pairing is compile-time enforced — there is no
/// `Composition` argument and no runtime ID check.
public fun new<RecordingShare, CompositionShare>(
    _: &RecordingAdminCap<RecordingShare>,
    recording: &Recording<RecordingShare, CompositionShare>,
    release_id: ID,
    track_split_bps_value: u16,
    ctx: &mut TxContext,
): Deal<RecordingShare, CompositionShare> {
    let recording_id = recording.id();

    let deal = Deal<RecordingShare, CompositionShare> {
        id: object::new(ctx),
        release_id,
        recording_id,
        track_split_bps: bps::new(track_split_bps_value),
    };

    emit(DealCreatedEvent<RecordingShare, CompositionShare> {
        deal_id: deal.id(),
        release_id,
        recording_id,
        track_split_bps_value,
    });

    deal
}

/// Accepts the deal, consuming it into a track. Called only by `track::new`.
/// Emits a `DealAcceptedEvent`.
public(package) fun accept<RecordingShare, CompositionShare>(
    self: Deal<RecordingShare, CompositionShare>,
) {
    emit(DealAcceptedEvent<RecordingShare, CompositionShare> {
        deal_id: self.id(),
        release_id: self.release_id,
        recording_id: self.recording_id,
    });

    self.destroy_internal();
}

/// Rejects the deal, destroying it without inclusion in a release.
/// Used when the holder declines or the negotiation falls through.
/// Emits a `DealRejectedEvent`.
public fun reject<RecordingShare, CompositionShare>(
    self: Deal<RecordingShare, CompositionShare>,
) {
    emit(DealRejectedEvent<RecordingShare, CompositionShare> {
        deal_id: self.id(),
        release_id: self.release_id,
        recording_id: self.recording_id,
    });

    self.destroy_internal();
}

/// Unpacks and deletes the deal without emitting anything. Event emission is
/// the caller's job — `accept` and `reject` are the only callers, so every
/// deal death is announced exactly once, with its meaning.
fun destroy_internal<RecordingShare, CompositionShare>(
    self: Deal<RecordingShare, CompositionShare>,
) {
    let Deal { id, .. } = self;
    id.delete();
}

// === Public View Functions ===

/// Returns the deal's object ID.
public fun id<RecordingShare, CompositionShare>(
    self: &Deal<RecordingShare, CompositionShare>,
): ID {
    self.id.to_inner()
}

/// Returns the ID of the target release.
public fun release_id<RecordingShare, CompositionShare>(
    self: &Deal<RecordingShare, CompositionShare>,
): ID {
    self.release_id
}

/// Returns the ID of the recording being authorized.
public fun recording_id<RecordingShare, CompositionShare>(
    self: &Deal<RecordingShare, CompositionShare>,
): ID {
    self.recording_id
}

/// Returns the track's revenue split in basis points.
public fun track_split_bps<RecordingShare, CompositionShare>(
    self: &Deal<RecordingShare, CompositionShare>,
): BPS {
    self.track_split_bps
}

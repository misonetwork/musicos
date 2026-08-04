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
/// A deal stores only what is genuinely release-specific and not carried by the
/// type parameters: the target `release_id` and the `track_split_bps`. The
/// recording is identified by the phantom, so no `recording_id` is stored —
/// `track::new` reads the recording's address from the matching `Recording` it
/// is handed (the phantoms force it to be the right one). Display metadata
/// (title, cover art) is *not* duplicated here — it is derived from the recording.
module miso::deal;

use bps::bps::{Self, BPS};
use miso::recording::{Recording, RecordingAdminCap};
use sui::event::emit;

// === Structs ===

/// A deal authorizing a recording's inclusion in a release.
public struct Deal<phantom RecordingShare, phantom CompositionShare> has key, store {
    /// Unique identifier for this deal.
    id: UID,
    /// ID of the target release this deal authorizes.
    release_id: ID,
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
}

/// Emitted when a deal is rejected: destroyed without being included in a
/// release, whether declined by the holder or withdrawn by its creator.
/// Terminal — the deal no longer exists.
public struct DealRejectedEvent<phantom RecordingShare, phantom CompositionShare> has copy, drop {
    /// ID of the deal.
    deal_id: ID,
    /// ID of the target release.
    release_id: ID,
}

// === Public Functions ===

/// Creates a new deal authorizing a recording for inclusion in a release.
/// Requires the recording admin capability.
///
/// The composition is identified by the recording's `CompositionShare` phantom,
/// so the recording↔composition pairing is compile-time enforced — there is no
/// `Composition` argument and no runtime ID check.
///
/// ### What signing a deal consents to
///
/// `release_id` is derived from the release digest, so targeting it consents
/// to that release's exact economics and membership: the ordered list of
/// `(recording, split)` pairs and the creator's nonce, nothing more. The
/// release's title, artwork, credits, and display grouping are chosen by the
/// release creator — before or after this deal is signed — and are not bound
/// by the digest. Presentation is trusted and publicly attributable, not
/// cryptographically committed.
///
/// The recording need not be `Published`: its admin can strike deals inside
/// the recording's own creating transaction (an `Initialized` recording cannot
/// escape that transaction, so across transactions deals always reference
/// `Published`, shared recordings).
///
/// ### A transferred deal is out of its creator's hands
///
/// A deal has no expiry and cannot be withdrawn by its creator: only the
/// holder can `reject` it, or accept it — at any future time — into exactly
/// the consented release via `track::new`. The digest binding confines a stale
/// deal's blast radius to that one release. Acceptance is itself provisional
/// until the release publishes: an accepted deal's track can be embedded in a
/// release that never publishes, with no extraction path — the deal is then
/// consumed while the recording never ships, and the recording admin's
/// recourse is a new deal for a new release.
///
/// `recording` is deliberately unread (hence the `#[allow]`): it exists to
/// compile-time-bind the `RecordingShare`/`CompositionShare` phantom pairing.
#[allow(unused_variable)]
public fun new<RecordingShare, CompositionShare>(
    _: &RecordingAdminCap<RecordingShare>,
    recording: &Recording<RecordingShare, CompositionShare>,
    release_id: ID,
    track_split_bps_value: u16,
    ctx: &mut TxContext,
): Deal<RecordingShare, CompositionShare> {
    let deal = Deal<RecordingShare, CompositionShare> {
        id: object::new(ctx),
        release_id,
        track_split_bps: bps::new(track_split_bps_value),
    };

    // The recording and composition identities ride on the
    // `RecordingShare`/`CompositionShare` phantoms (the `recording` argument
    // binds them and enforces the pairing at compile time); the routing address
    // is read from the `Recording` again at `track::new`. No ids are emitted.
    emit(DealCreatedEvent<RecordingShare, CompositionShare> {
        deal_id: deal.id(),
        release_id,
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

/// Returns the track's revenue split in basis points.
public fun track_split_bps<RecordingShare, CompositionShare>(
    self: &Deal<RecordingShare, CompositionShare>,
): BPS {
    self.track_split_bps
}

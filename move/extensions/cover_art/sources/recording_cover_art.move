// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Recording cover art: a single `CoverArt` attached as a dynamic field on the
/// recording's UID, set/cleared via the recording's cap-gated `uid_mut`.
module cover_art::recording_cover_art;

use cover_art::cover_art::CoverArt;
use miso::recording::{Recording, RecordingAdminCap};
use sui::dynamic_field as df;

// === Errors ===

/// No cover art is attached to this recording.
const ENoCoverArt: u64 = 1;

// === Dynamic field key ===

/// Dynamic-field key — one cover per recording.
public struct CoverArtKey() has copy, drop, store;

// === Write API ===

/// Sets (or replaces) the recording's cover art.
public fun set<RecordingShare, CompositionShare>(
    self: &mut Recording<RecordingShare, CompositionShare>,
    cap: &RecordingAdminCap<RecordingShare>,
    art: CoverArt,
) {
    let uid = self.uid_mut(cap);
    if (df::exists(uid, CoverArtKey())) {
        let slot: &mut CoverArt = df::borrow_mut(uid, CoverArtKey());
        *slot = art;
    } else {
        df::add(uid, CoverArtKey(), art);
    }
}

/// Removes the recording's cover art, if any.
public fun unset<RecordingShare, CompositionShare>(
    self: &mut Recording<RecordingShare, CompositionShare>,
    cap: &RecordingAdminCap<RecordingShare>,
) {
    let uid = self.uid_mut(cap);
    if (df::exists(uid, CoverArtKey())) {
        let _: CoverArt = df::remove(uid, CoverArtKey());
    };
}

// === Public View Functions ===

/// Returns whether the recording has cover art attached.
public fun has_cover_art<RecordingShare, CompositionShare>(
    self: &Recording<RecordingShare, CompositionShare>,
): bool {
    df::exists(self.uid(), CoverArtKey())
}

/// Returns the recording's cover art. Aborts if none is attached.
public fun cover_art<RecordingShare, CompositionShare>(
    self: &Recording<RecordingShare, CompositionShare>,
): &CoverArt {
    assert!(df::exists(self.uid(), CoverArtKey()), ENoCoverArt);
    df::borrow(self.uid(), CoverArtKey())
}

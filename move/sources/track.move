// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Represents a track on a release, linking a recording to its position
/// in the tracklist.
///
/// A `Track` is the minimal positioned (recording, revenue-share) pair:
/// - `recording_id` — the routing target for the track's revenue, and the
///   handle through which all other metadata (title, cover art, and the
///   recording/composition share-type identities) is reached.
/// - `split_bps` — this track's share of the release's revenue; genuinely
///   release-specific and not derivable from the recording.
/// - `state` — the assign-once lifecycle that carries (then sheds) each deal's
///   target release commitment; see `TrackState`.
///
/// `Track` is intentionally monomorphic: a `Release` holds a `vector<Track>`
/// of tracks from many different recordings/compositions, so it cannot be
/// generic over their share types. It stores no title, cover art, or
/// share-type — all derived from the recording via `recording_id`.
module musicos::track;

use bps::bps::BPS;
#[test_only]
use bps::bps;
use musicos::deal::Deal;

// === Structs ===

/// A track on a release: a positioned pointer to a recording with a revenue split.
public struct Track has drop, store {
    /// Current state of the track.
    state: TrackState,
    /// ID of the recording on this track. The routing target for the track's
    /// revenue; also the handle a consumer uses to fetch the recording (whose
    /// type carries the recording and composition share-type identities).
    recording_id: ID,
    /// This track's share of the release's revenue, in basis points. All
    /// tracks in a release sum to 100%. The composition's cut is settled as
    /// recording-share ownership at recording creation, so it is not split out
    /// here — a track routes its full share to the recording.
    split_bps: BPS,
}

// === Enums ===

/// Lifecycle state of a track within a release. A track is born `Unassigned`,
/// carrying the target `release_id` its originating `Deal` committed to (the
/// release id is a digest of the whole tracklist, so this is the recording
/// owner's consent to the exact release configuration). At publish the release
/// verifies the match and transitions the track to `Assigned`, which carries
/// no id — shedding the 32-byte commitment once it has served its purpose.
public enum TrackState has copy, drop, store {
    /// Track has been created but not yet assigned to a release. Carries the
    /// target release id the originating deal committed to.
    Unassigned(ID),
    /// Track has been assigned to its target release.
    Assigned,
}

// === Errors ===

/// Track's target release ID does not match the assigning release.
const EUnauthorizedAssignment: u64 = 0;
/// Track has already been assigned to a release.
const EAlreadyAssigned: u64 = 1;

// === Public Functions ===

/// Creates a new track by accepting a deal. The deal itself is the
/// authorization — it was created by the recording's admin and carries the
/// recording's identity and the agreed split. Emits a `DealAcceptedEvent`.
///
/// The deal's `RecordingShare`/`CompositionShare` phantoms are erased here: a
/// `Track` is monomorphic so it can live in a release's heterogeneous
/// `vector<Track>`. The recording remains reachable via `recording_id`.
public fun new<RecordingShare, CompositionShare>(
    deal: Deal<RecordingShare, CompositionShare>,
): Track {
    let track = Track {
        state: TrackState::Unassigned(deal.release_id()),
        recording_id: deal.recording_id(),
        split_bps: deal.track_split_bps(),
    };

    deal.accept();

    return track
}

/// Assigns the track to a release by verifying the release UID matches
/// the track's target release ID. Can only be called once per track.
public(package) fun assign(self: &mut Track, release_uid: &UID) {
    match (self.state) {
        TrackState::Unassigned(release_id) => {
            assert!(release_uid.to_inner() == release_id, EUnauthorizedAssignment);
            self.state = TrackState::Assigned;
        },
        TrackState::Assigned => abort EAlreadyAssigned,
    }
}

// === Public View Functions ===

/// Returns the ID of the recording.
public fun recording_id(self: &Track): ID {
    self.recording_id
}

/// Returns this track's share of the release's revenue (in basis points).
public fun split_bps(self: &Track): BPS {
    self.split_bps
}

/// Returns true if the track is in the Assigned state.
public fun is_assigned_state(self: &Track): bool {
    match (self.state) { TrackState::Assigned => true, _ => false }
}

/// Returns true if the track is in the Unassigned state.
public fun is_unassigned_state(self: &Track): bool {
    match (self.state) { TrackState::Unassigned(_) => true, _ => false }
}

// === Test Only ===

#[test_only]
public fun new_for_testing(recording_id: ID, release_id: ID, split_bps_value: u16): Track {
    Track {
        state: TrackState::Unassigned(release_id),
        recording_id,
        split_bps: bps::new(split_bps_value),
    }
}

#[test_only]
public fun set_release_id_for_testing(self: &mut Track, release_id: ID) {
    self.state = TrackState::Unassigned(release_id);
}

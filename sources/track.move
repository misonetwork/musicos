// Copyright (c) Unconfirmed Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Represents a track on a release, linking a recording to its position
/// in the tracklist. Each track captures metadata from the recording at
/// the time of release creation for efficient access during playback.
///
/// ### Key Features:
///
/// - Caches recording metadata for quick access
/// - Supports optional track-specific cover art
/// - Stores composition split for royalty calculations
module musicos::track;

use bps::bps::BPS;
#[test_only]
use bps::bps;
use musicos::cover_art::CoverArt;
use musicos::deal::Deal;
use std::string::String;
use std::type_name::TypeName;

// === Structs ===

/// A track on a release containing a recording and its metadata.
/// Metadata is captured at track creation time for efficient access.
public struct Track has drop, store {
    /// Current state of the track.
    state: TrackState,
    /// ID of the underlying composition.
    composition_id: ID,
    /// Type of the composition's share token.
    composition_share_type: TypeName,
    /// Split of revenue allocated to composition vs recording (in basis points).
    composition_split_bps: BPS,
    /// ID of the recording on this track.
    recording_id: ID,
    /// Type of the recording's share token.
    recording_share_type: TypeName,
    /// Ingester of the recording's master audio file.
    recording_master_ingester_type: TypeName,
    /// Ingester types of the recording's stem audio files.
    recording_stem_ingester_types: vector<TypeName>,
    /// Description of the track.
    title: String,
    /// Duration of the track in milliseconds.
    duration_ms: u64,
    /// Covert art for the track. Inherited from the recording by default.
    cover_art: CoverArt,
    /// Split of revenue allocated to composition vs recording (in basis points).
    split_bps: BPS,
}

// === Enums ===

/// Lifecycle state of a track within a release.
public enum TrackState has copy, drop, store {
    /// Track has been created but not yet assigned to a release.
    Unassigned { release_id: ID },
    /// Track has been assigned to its target release.
    Assigned,
}

// === Errors ===

/// Track's target release ID does not match the assigning release.
const EUnauthorizedAssignment: u64 = 0;
/// Track has already been assigned to a release.
const EAlreadyAssigned: u64 = 1;

// === Public Functions ===

/// Creates a new track from a recording.
/// Requires the recording admin capability.
/// Captures the recording's metadata at creation time.
public fun new(deal: Deal): Track {
    let track = Track {
        state: TrackState::Unassigned { release_id: deal.release_id() },
        composition_id: deal.composition_id(),
        composition_share_type: *deal.composition_share_type(),
        composition_split_bps: deal.composition_split_bps(),
        recording_id: deal.recording_id(),
        recording_share_type: *deal.recording_share_type(),
        recording_master_ingester_type: *deal.recording_master_ingester_type(),
        recording_stem_ingester_types: *deal.recording_stem_ingester_types(),
        title: *deal.track_title(),
        duration_ms: deal.recording_duration_ms(),
        cover_art: *deal.track_cover_art(),
        split_bps: deal.track_split_bps(),
    };

    deal.destroy();

    return track
}

/// Assigns the track to a release by verifying the release UID matches
/// the track's target release ID. Can only be called once per track.
public(package) fun assign(self: &mut Track, release_uid: &UID) {
    match (self.state) {
        TrackState::Unassigned { release_id } => {
            assert!(release_uid.to_inner() == release_id, EUnauthorizedAssignment);
            self.state = TrackState::Assigned;
        },
        TrackState::Assigned => abort EAlreadyAssigned,
    }
}

// === Public View Functions ===

/// Returns the ID of the underlying composition.
public fun composition_id(self: &Track): ID {
    self.composition_id
}

/// Returns the type of the composition's share token.
public fun composition_share_type(self: &Track): &TypeName {
    &self.composition_share_type
}

/// Returns the composition's revenue split in basis points.
public fun composition_split_bps(self: &Track): BPS {
    self.composition_split_bps
}


/// Returns the ID of the recording.
public fun recording_id(self: &Track): ID {
    self.recording_id
}

/// Returns the type of the recording's share token.
public fun recording_share_type(self: &Track): &TypeName {
    &self.recording_share_type
}

/// Returns the ingester of the recording's master audio file.
public fun recording_master_ingester_type(self: &Track): &TypeName {
    &self.recording_master_ingester_type
}

/// Returns the ingester types of the recording's stem audio files.
public fun recording_stem_ingester_types(self: &Track): &vector<TypeName> {
    &self.recording_stem_ingester_types
}

/// Returns the title of the track.
public fun title(self: &Track): &String {
    &self.title
}

/// Returns the duration of the track in milliseconds.
public fun duration_ms(self: &Track): u64 {
    self.duration_ms
}

/// Returns the cover art for the track.
public fun cover_art(self: &Track): &CoverArt {
    &self.cover_art
}

/// Returns the split of revenue allocated to composition vs recording (in basis points).
public fun split_bps(self: &Track): BPS {
    self.split_bps
}

/// Returns true if the track is in the Assigned state.
public fun is_assigned_state(self: &Track): bool {
    match (self.state) { TrackState::Assigned => true, _ => false }
}

/// Returns true if the track is in the Unassigned state.
public fun is_unassigned_state(self: &Track): bool {
    match (self.state) { TrackState::Unassigned { .. } => true, _ => false }
}

// === Test Only ===

#[test_only]
public fun new_for_testing<CompositionShare, RecordingShare, V: drop>(
    composition_id: ID,
    recording_id: ID,
    release_id: ID,
    title: String,
    duration_ms: u64,
    cover_art: CoverArt,
    split_bps_value: u16,
    composition_split_bps_value: u16,
): Track {
    Track {
        state: TrackState::Unassigned { release_id },
        composition_id,
        composition_share_type: std::type_name::with_defining_ids<CompositionShare>(),
        composition_split_bps: bps::new(composition_split_bps_value),
        recording_id,
        recording_share_type: std::type_name::with_defining_ids<RecordingShare>(),
        recording_master_ingester_type: std::type_name::with_defining_ids<V>(),
        recording_stem_ingester_types: vector[],
        title,
        duration_ms,
        cover_art,
        split_bps: bps::new(split_bps_value),
    }
}

#[test_only]
public fun set_release_id_for_testing(self: &mut Track, release_id: ID) {
    self.state = TrackState::Unassigned { release_id };
}

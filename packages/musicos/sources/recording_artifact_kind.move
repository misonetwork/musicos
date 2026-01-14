// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Defines the types of artifacts that can be attached to recordings.
/// Used as a phantom type parameter for type-safe artifact categorization.
module musicos::recording_artifact_kind;

use musicos::data::Data;
use std::string::String;

/// Types of artifacts that can be attached to a recording.
public enum RecordingArtifactKind has copy, drop, store {
    LinerNote(Data),
    MixNote(Data),
    MusicVideo(Data),
    Project(Data),
    SessionNote(Data),
    Visualizer(Data),
}

public fun new_project_kind(data: Data): RecordingArtifactKind {
    RecordingArtifactKind::Project(data)
}

public fun new_liner_note_kind(data: Data): RecordingArtifactKind {
    RecordingArtifactKind::LinerNote(data)
}

public fun new_mix_note_kind(data: Data): RecordingArtifactKind {
    RecordingArtifactKind::MixNote(data)
}

public fun new_music_video_kind(data: Data): RecordingArtifactKind {
    RecordingArtifactKind::MusicVideo(data)
}

public fun new_session_note_kind(data: Data): RecordingArtifactKind {
    RecordingArtifactKind::SessionNote(data)
}

public fun new_visualizer_kind(data: Data): RecordingArtifactKind {
    RecordingArtifactKind::Visualizer(data)
}

public fun data(kind: &RecordingArtifactKind): &Data {
    match (kind) {
        RecordingArtifactKind::LinerNote(data) => data,
        RecordingArtifactKind::MixNote(data) => data,
        RecordingArtifactKind::MusicVideo(data) => data,
        RecordingArtifactKind::Project(data) => data,
        RecordingArtifactKind::SessionNote(data) => data,
        RecordingArtifactKind::Visualizer(data) => data,
    }
}

public fun name(kind: &RecordingArtifactKind): String {
    match (kind) {
        RecordingArtifactKind::LinerNote(_) => "Liner Note",
        RecordingArtifactKind::MixNote(_) => "Mix Note",
        RecordingArtifactKind::MusicVideo(_) => "Music Video",
        RecordingArtifactKind::Project(_) => "Project",
        RecordingArtifactKind::SessionNote(_) => "Session Note",
        RecordingArtifactKind::Visualizer(_) => "Visualizer",
    }
}
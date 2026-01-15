// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Defines the types of artifacts that can be attached to recordings.
module musicos::recording_artifact_kind;

use std::string::String;

/// Types of artifacts that can be attached to a recording.
public enum RecordingArtifactKind has copy, drop, store {
    LinerNote,
    MixNote,
    MusicVideo,
    Project,
    SessionNote,
    Visualizer,
}

public fun new_project_kind(): RecordingArtifactKind {
    RecordingArtifactKind::Project
}

public fun new_liner_note_kind(): RecordingArtifactKind {
    RecordingArtifactKind::LinerNote
}

public fun new_mix_note_kind(): RecordingArtifactKind {
    RecordingArtifactKind::MixNote
}

public fun new_music_video_kind(): RecordingArtifactKind {
    RecordingArtifactKind::MusicVideo
}

public fun new_session_note_kind(): RecordingArtifactKind {
    RecordingArtifactKind::SessionNote
}

public fun new_visualizer_kind(): RecordingArtifactKind {
    RecordingArtifactKind::Visualizer
}

public fun name(kind: &RecordingArtifactKind): String {
    match (kind) {
        RecordingArtifactKind::LinerNote => "Liner Note",
        RecordingArtifactKind::MixNote => "Mix Note",
        RecordingArtifactKind::MusicVideo => "Music Video",
        RecordingArtifactKind::Project => "Project",
        RecordingArtifactKind::SessionNote => "Session Note",
        RecordingArtifactKind::Visualizer => "Visualizer",
    }
}

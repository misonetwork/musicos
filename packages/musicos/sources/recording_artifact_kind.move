// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Defines the types of artifacts that can be attached to recordings.
/// Used as a phantom type parameter for type-safe artifact categorization.
module musicos::recording_artifact_kind;

/// Types of artifacts that can be attached to a recording.
public enum RecordingArtifactKind has copy, drop, store {
    /// Lyrics associated with the recording.
    Lyrics,
}

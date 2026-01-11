// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Defines the types of artifacts that can be attached to compositions.
/// Used as a phantom type parameter for type-safe artifact categorization.
module musicos::composition_artifact_kind;

/// Types of artifacts that can be attached to a composition.
public enum CompositionArtifactKind has copy, drop, store {
    /// Lyrics associated with the composition.
    Lyrics,
}

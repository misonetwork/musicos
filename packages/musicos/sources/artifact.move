// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Represents supplementary files attached to compositions or recordings.
/// Artifacts can include sheet music, liner notes, or other supporting materials.
/// The phantom type parameter allows type-safe categorization of artifacts.
///
/// Key features:
/// - Type-safe categorization via phantom type parameter
/// - External data storage reference
/// - Optional description for context
module musicos::artifact;

use musicos::data::Data;
use std::string::String;

/// A supplementary file attached to a composition or recording.
/// The ArtifactKind phantom type ensures type-safe categorization.
public struct Artifact<phantom ArtifactKind: copy + drop + store> has copy, drop, store {
    /// Reference to the artifact's external storage location.
    data: Data,
    /// Optional description explaining the artifact's contents.
    description: Option<String>,
}

/// Returns a reference to the artifact's external data.
public fun data<ArtifactKind: copy + drop + store>(self: &Artifact<ArtifactKind>): &Data {
    &self.data
}

/// Returns the optional description of the artifact.
public fun description<ArtifactKind: copy + drop + store>(
    self: &Artifact<ArtifactKind>,
): &Option<String> {
    &self.description
}

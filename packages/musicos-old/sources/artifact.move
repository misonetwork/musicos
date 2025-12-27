// Copyright (c) Sona Labs, Pte Ltd.
// SPDX-License-Identifier: Apache-2.0

module musicos::artifact;

use musicos::contributor::Contributor;
use std::string::String;

public struct Artifact<phantom ArtifactKind> has copy, drop, store {
    contributor_id: ID,
    blob_id: String,
    description: Option<String>,
}

public fun new<ArtifactKind>(
    contributor: &Contributor,
    blob_id: String,
    description: Option<String>,
): Artifact<ArtifactKind> {
    Artifact {
        contributor_id: contributor.id(),
        blob_id,
        description,
    }
}

public fun blob_id<ArtifactKind>(self: &Artifact<ArtifactKind>): String {
    self.blob_id
}

public fun contributor_id<ArtifactKind>(self: &Artifact<ArtifactKind>): ID {
    self.contributor_id
}

public fun description<ArtifactKind>(self: &Artifact<ArtifactKind>): Option<String> {
    self.description
}

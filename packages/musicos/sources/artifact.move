// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module musicos::artifact;

use musicos::contributor::Contributor;
use std::string::String;

public struct Artifact<phantom ArtifactKind> has drop, store {
    blob_id: String,
    description: Option<String>,
}

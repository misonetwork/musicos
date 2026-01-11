// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module musicos::artifact;

use musicos::data::Data;
use std::string::String;

public struct Artifact<phantom ArtifactKind: copy + drop + store> has copy, drop, store {
    data: Data,
    description: Option<String>,
}

public fun data<ArtifactKind: copy + drop + store>(self: &Artifact<ArtifactKind>): &Data {
    &self.data
}

public fun description<ArtifactKind: copy + drop + store>(
    self: &Artifact<ArtifactKind>,
): &Option<String> {
    &self.description
}

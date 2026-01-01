// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module musicos::snapshot;

use std::string::String;

//=== Structs ===

public struct Snapshot has drop, store {
    kind: SnapshotKind,
    contributor_id: ID,
    blob_id: String,
}

//=== Enums ===

public enum SnapshotKind has copy, drop, store {
    Audio(String),
    Image(String),
    Text(String),
    Video(String),
}

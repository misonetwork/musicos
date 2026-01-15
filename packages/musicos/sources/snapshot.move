// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Represents a point-in-time capture of content associated with a
/// composition or recording. Snapshots can store various media types
/// (audio, image, text, video) and are linked to a specific contributor.
module musicos::snapshot;

use std::string::String;
use walrus_data::walrus_data::WalrusData;

//=== Structs ===

/// A snapshot of content at a specific point in time.
/// Used to preserve historical versions of associated media.
#[allow(unused_field)]
public struct Snapshot has drop, store {
    /// The type and format of the snapshot content.
    kind: SnapshotKind,
    /// ID of the contributor who created this snapshot.
    contributor_id: ID,
    /// Reference to the blob storage location.
    data: WalrusData,
}

//=== Enums ===

/// The type of content stored in a snapshot.
/// Each variant includes the MIME type or format identifier.
public enum SnapshotKind has copy, drop, store {
    /// Audio content (e.g., "audio/wav", "audio/mp3").
    Audio(
        /// MIME type or format identifier.
        String,
    ),
    /// Image content (e.g., "image/png", "image/jpeg").
    Image(
        /// MIME type or format identifier.
        String,
    ),
    /// Text content (e.g., "text/plain", "text/markdown").
    Text(
        /// MIME type or format identifier.
        String,
    ),
    /// Video content (e.g., "video/mp4", "video/webm").
    Video(
        /// MIME type or format identifier.
        String,
    ),
}

public fun kind(self: &Snapshot): &SnapshotKind {
    &self.kind
}

public fun contributor_id(self: &Snapshot): ID {
    self.contributor_id
}

public fun data(self: &Snapshot): &WalrusData {
    &self.data
}

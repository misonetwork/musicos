// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Represents external data storage references for MusicOS.
/// Data objects point to content stored on external storage systems
/// using Walrus blob IDs and optional Quilt IDs for chunked data.
///
/// Key features:
/// - Reference to Walrus blob storage via blob_id
/// - Optional Quilt ID for large file chunking
/// - Lightweight, copyable reference type
module musicos::data;

/// A reference to externally stored data.
/// Contains an optional quilt_id for chunked storage and a required blob_id.
public struct Data(Option<u256>, u256) has copy, drop, store;

/// Creates a new Data reference.
/// `quilt_id` - Optional identifier for chunked data storage.
/// `blob_id` - Required identifier for the blob in external storage.
public fun new(quilt_id: Option<u256>, blob_id: u256): Data {
    Data(quilt_id, blob_id)
}

/// Returns the optional Quilt ID for chunked data storage.
public fun quilt_id(data: &Data): Option<u256> {
    data.0
}

/// Returns the blob ID pointing to the data in external storage.
public fun blob_id(data: &Data): u256 {
    data.1
}

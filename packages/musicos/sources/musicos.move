// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Core module for the MusicOS protocol.
/// Provides the foundational types and entry point for the MusicOS system.
///
/// Key features:
/// - One-time witness (MUSICOS) for package identification
/// - MusicOS marker type for protocol operations
module musicos::musicos;

//=== Structs ===

/// One-time witness for the MusicOS package.
public struct MUSICOS() has drop;

/// Marker type representing the MusicOS protocol.
/// Used as a witness or capability in protocol operations.
public struct MusicOS() has drop;

//=== Public Functions ===

/// Creates a new MusicOS marker instance.
public fun new(): MusicOS {
    MusicOS()
}

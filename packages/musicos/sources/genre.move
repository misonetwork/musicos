// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Manages music genres in the MusicOS protocol.
/// Genres are registered in a shared GenreRegistry and used to categorize
/// recordings. Each genre has a unique name within the registry.
///
/// Key features:
/// - Admin-controlled genre creation
/// - Deterministic addresses via derived object pattern
/// - Event emission for genre creation tracking
module musicos::genre;

use musicos::admin::AdminCap;
use std::string::String;
use sui::derived_object::claim;
use sui::event::emit;

//=== Structs ===

/// One-time witness for the genre module.
public struct GENRE() has drop;

/// Represents a music genre (e.g., "Rock", "Jazz", "Electronic").
public struct Genre has key {
    /// Unique identifier for this genre.
    id: UID,
    /// Human-readable name of the genre.
    name: String,
}

/// Key used for deriving deterministic genre addresses from the registry.
public struct GenreKey(String) has copy, drop, store;

/// Shared registry that tracks all genres in the protocol.
/// Genres are derived from this object to ensure uniqueness.
public struct GenreRegistry has key {
    /// Unique identifier for the registry.
    id: UID,
}

//=== Events ===

/// Emitted when a new genre is created.
public struct GenreCreatedEvent has copy, drop {
    /// ID of the newly created genre.
    genre_id: ID,
    /// Name of the genre.
    name: String,
}

//=== Init Function ===

/// Initializes the genre module by creating and sharing the GenreRegistry.
fun init(_otw: GENRE, ctx: &mut TxContext) {
    let genre_registry = GenreRegistry {
        id: object::new(ctx),
    };

    transfer::share_object(genre_registry);
}

//=== Public Functions ===

/// Creates a new genre with the given name.
/// Requires admin capability and registers the genre in the shared registry.
/// Emits a GenreCreatedEvent upon successful creation.
public fun new(_: &AdminCap, name: String, genre_registry: &mut GenreRegistry) {
    let genre = Genre {
        id: claim(&mut genre_registry.id, GenreKey(name)),
        name,
    };

    emit(GenreCreatedEvent {
        genre_id: genre.id(),
        name,
    });

    transfer::share_object(genre);
}

//=== Public View Functions ===

/// Returns the unique identifier of the genre.
public fun id(self: &Genre): ID {
    self.id.to_inner()
}

/// Returns the name of the genre.
public fun name(self: &Genre): &String {
    &self.name
}

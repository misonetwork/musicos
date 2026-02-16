// Copyright (c) Studio Mirai, LLC
// SPDX-License-Identifier: Apache-2.0

/// Manages music genres in the MusicOS protocol.
/// Genres are registered in a shared GenreRegistry and used to categorize
/// recordings. Each genre has a unique name within the registry.
///
/// ### Key Features:
///
/// - Admin-controlled genre creation
/// - Deterministic addresses via derived object pattern
/// - Event emission for genre creation tracking
module musicos::genre;

use std::string::String;
use sui::derived_object::claim;
use sui::event::emit;

// === Structs ===

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

// === Constants (validation) ===

/// Maximum length of a genre name in bytes.
const MAX_NAME_LENGTH: u64 = 50;

// === Errors ===

// Validation errors (20-29)
/// Genre name contains an invalid character (must be A-Z or _).
const EInvalidCharacter: u64 = 20;
/// Genre name exceeds maximum length.
const EMaxNameLengthExceeded: u64 = 21;

// === Events ===

/// Emitted when a new genre is created.
public struct GenreCreatedEvent has copy, drop {
    /// ID of the newly created genre.
    genre_id: ID,
    /// Name of the genre.
    name: String,
}

// === Constants ===

/// Default genres created during module initialization.
const LAUNCH_GENRES: vector<vector<u8>> = vector[
    b"ALTERNATIVE",
    b"CLASSICAL",
    b"DANCE",
    b"ELECTRONIC",
    b"GLOBAL",
    b"HIP_HOP",
    b"JAZZ",
    b"POP",
    b"RNB",
    b"ROCK",
    b"SOUNDTRACK",
];

// === Init Function ===

/// Initializes the genre module by creating and sharing the GenreRegistry.
fun init(_otw: GENRE, ctx: &mut TxContext) {
    let mut genre_registry = GenreRegistry {
        id: object::new(ctx),
    };

    // Create and share the default genres.
    LAUNCH_GENRES.destroy!(|genre| {
        let genre = new_impl(genre.to_string(), &mut genre_registry);
        transfer::share_object(genre);
    });

    transfer::share_object(genre_registry);
}

// === Public Functions ===

/// Creates a new genre with the given name.
/// Requires admin capability and registers the genre in the shared registry.
/// Emits a GenreCreatedEvent upon successful creation.
public fun new(name: String, genre_registry: &mut GenreRegistry) {
    let genre = new_impl(name, genre_registry);
    transfer::share_object(genre);
}

// === Public View Functions ===

/// Returns the unique identifier of the genre.
public fun id(self: &Genre): ID {
    self.id.to_inner()
}

/// Returns the name of the genre.
public fun name(self: &Genre): &String {
    &self.name
}

// === Private Functions ===

/// Internal implementation for creating a new genre.
/// Validates the name and derives a deterministic address from the registry.
fun new_impl(name: String, genre_registry: &mut GenreRegistry): Genre {
    assert_valid_name(&name);

    let genre = Genre {
        id: claim(&mut genre_registry.id, GenreKey(name)),
        name,
    };

    emit(GenreCreatedEvent {
        genre_id: genre.id(),
        name,
    });

    genre
}

/// Asserts that the genre name contains only valid characters (A-Z, _).
fun assert_valid_name(name: &String) {
    let bytes = name.as_bytes();
    assert!(!bytes.is_empty(), EInvalidCharacter);
    assert!(bytes.length() <= MAX_NAME_LENGTH, EMaxNameLengthExceeded);
    assert!(bytes.all!(|c| (*c >= 65 && *c <= 90) || *c == 95), EInvalidCharacter);
}

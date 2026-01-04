// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module musicos::genre;

use std::string::String;
use sui::derived_object::claim;
use sui::event::emit;

//=== Structs ===

public struct GENRE() has drop;

public struct Genre has key {
    id: UID,
    name: String,
}

public struct GenreKey(String) has copy, drop, store;

public struct GenreRegistry has key {
    id: UID,
}

//=== Events ===

public struct GenreCreatedEvent has copy, drop {
    genre_id: ID,
    name: String,
}

//=== Init Function ===

fun init(_otw: GENRE, ctx: &mut TxContext) {
    let genre_registry = GenreRegistry {
        id: object::new(ctx),
    };

    transfer::share_object(genre_registry);
}

//=== Public Functions ===

// TODO: Gate behind admin.
public fun new(name: String, genre_registry: &mut GenreRegistry) {
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

public fun id(self: &Genre): ID {
    self.id.to_inner()
}

public fun name(self: &Genre): String {
    self.name
}

// Copyright (c) Sona Labs, Pte Ltd.
// SPDX-License-Identifier: Apache-2.0

module musicos::genre;

use musicos::admin::AdminCap;
use std::string::String;
use sui::derived_object::{claim, derive_address as derive_address_impl};

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

public struct CreateGenreCapability has drop {}

//=== Constants ===

const DEFAULT_GENRES: vector<vector<u8>> = vector[b"POP", b"ROCK", b"HIP_HOP", b"R&B", b"EDM"];

//=== Errors ===

const EInvalidCharacter: u64 = 0;

//=== Init Function ===

fun init(_otw: GENRE, ctx: &mut TxContext) {
    let mut registry = GenreRegistry {
        id: object::new(ctx),
    };

    DEFAULT_GENRES.do!(|name| {
        let genre = new_impl(name.to_string(), &mut registry);
        transfer::share_object(genre);
    });

    transfer::share_object(registry);
}

//=== Public Functions ===

public fun new(_: &AdminCap, name: String, registry: &mut GenreRegistry) {
    let genre = new_impl(name, registry);
    transfer::share_object(genre);
}

public fun derive_address(name: String, registry: &GenreRegistry): address {
    derive_address_impl(registry.id.to_inner(), GenreKey(name))
}

//=== Public View Functions ===

public fun id(self: &Genre): ID {
    self.id.to_inner()
}

public fun name(self: &Genre): String {
    self.name
}

//=== Private Functions ===

fun assert_is_valid_name(name: &vector<u8>) {
    let valid_chars = vector[b"ABCDEFGHIJKLMNOPQRSTUVWXYZ_"];
    // name.do_ref!(|byte| { assert!(valid_chars.contains(&byte), EInvalidCharacter) });
    //name.as_bytes().do_ref!(|byte| { assert!(chars.contains(byte), EInvalidCharacter) });
}

fun new_impl(name: String, registry: &mut GenreRegistry): Genre {
    Genre {
        id: claim(&mut registry.id, GenreKey(name)),
        name,
    }
}

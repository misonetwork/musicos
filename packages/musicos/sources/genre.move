module musicos::genre;

use std::string::String;
use sui::derived_object::claim;
use sui::party;

//=== Structs ===

public struct GENRE() has drop;

public struct Genre has key {
    id: UID,
    name: String,
}

public struct GenreKey(String) has copy, drop, store;

public struct CreateGenreCap has key, store {
    id: UID,
}

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

    let create_genre_cap = CreateGenreCap {
        id: object::new(ctx),
    };
    transfer::public_transfer(create_genre_cap, ctx.sender());

    transfer::share_object(registry);
}

//=== Public Functions ===

public fun new(_: &CreateGenreCap, name: String, registry: &mut GenreRegistry) {
    let genre = new_impl(name, registry);
    transfer::share_object(genre);
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

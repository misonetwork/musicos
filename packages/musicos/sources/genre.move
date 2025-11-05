module musicos::genre;

use std::string::String;
use sui::derived_object::claim;
use sui::party;

//=== Structs ===

public struct GENRE() has drop;

public struct Genre has key {
    id: UID,
    name: String,
    description: String,
}

public struct CreateGenreCap has key, store {
    id: UID,
}

public struct GenreRegistry has key {
    id: UID,
}

public struct CreateGenreCapability has drop {}

//=== Errors ===

const EInvalidCharacter: u64 = 0;

//=== Init Function ===

fun init(otw: GENRE, ctx: &mut TxContext) {
    let create_genre_cap = CreateGenreCap {
        id: object::new(ctx),
    };
    party::single_owner(ctx.sender()).public_transfer!(create_genre_cap);
}

//=== Public Functions ===

public fun new(
    _: &CreateGenreCap,
    name: String,
    description: String,
    registry: &mut GenreRegistry,
) {
    let genre = Genre {
        id: claim(&mut registry.id, name),
        name,
        description,
    };

    transfer::share_object(genre);
}

//=== Public View Functions ===

public fun id(self: &Genre): ID {
    self.id.to_inner()
}

public fun name(self: &Genre): String {
    self.name
}

public fun description(self: &Genre): String {
    self.description
}

//=== Private Functions ===

fun assert_is_valid_name(name: &String) {
    let chars = vector[b"ABCDEFGHIJKLMNOPQRSTUVWXYZ"];
    //name.as_bytes().do_ref!(|byte| { assert!(chars.contains(byte), EInvalidCharacter) });
}

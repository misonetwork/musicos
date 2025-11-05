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

const DEFAULT_GENRES: vector<vector<u8>> = vector[
    b"POP",
    b"ROCK",
    b"HIP_HOP",
    b"R&B",
    b"EDM",
    b"HOUSE",
    b"TECHNO",
    b"TRANCE",
    b"DRUM & BASS",
    b"DUBSTEP",
    b"TRAP",
    b"INDIE",
    b"ALTERNATIVE",
    b"METAL",
    b"JAZZ",
    b"BLUES",
    b"SOUL",
    b"FUNK",
    b"COUNTRY",
    b"FOLK",
    b"REGGAE",
    b"REGGAETON",
    b"LATIN POP",
    b"AFROBEAT",
    b"AMAPIANO",
    b"K_POP",
    b"J_POP",
    b"LO_FI",
    b"CHILLOUT",
    b"AMBIENT",
    b"CLASSICAL",
    b"OPERA",
    b"SOUNDTRACK",
    b"FILM_SCORE",
    b"GOSPEL",
    b"DISCO",
    b"PUNK",
    b"EMO",
    b"GRUNGE",
    b"SHOEGAZE",
    b"POST_ROCK",
    b"PROGRESSIVE_ROCK",
    b"HARD_ROCK",
    b"SOFT_ROCK",
    b"SYNTHPOP",
    b"ELECTRO",
    b"INDUSTRIAL",
    b"TECH_HOUSE",
    b"DEEP_HOUSE",
    b"MINIMAL",
    b"FUTURE_BASS",
    b"BASS_MUSIC",
    b"VAPORWAVE",
    b"HYPERPOP",
    b"GLITCH",
    b"IDM",
    b"CHILLWAVE",
    b"DREAM_POP",
    b"NEO_SOUL",
    b"TRAP_SOUL",
    b"BOOM_BAP",
    b"DRILL",
    b"UK_GARAGE",
    b"JUNGLE",
    b"BREAKBEAT",
    b"DOWNTEMPO",
    b"PSYTRANCE",
    b"PROGRESSIVE HOUSE",
    b"TROPICAL HOUSE",
    b"EURODANCE",
    b"SYNTHWAVE",
    b"NEW_WAVE",
    b"COLDWAVE",
    b"NOISE",
    b"EXPERIMENTAL",
    b"AVANT_GARDE",
    b"WORLD",
    b"AFRO_FUSION",
    b"HIGHLIFE",
    b"BOSSA_NOVA",
    b"SAMBA",
    b"TANGO",
    b"FLAMENCO",
    b"BLUEGRASS",
    b"AMERICANA",
    b"COUNTRY_POP",
    b"COUNTRY_ROCK",
    b"ALTERNATIVE COUNTRY",
    b"CELTIC",
    b"SKA",
    b"DANCEHALL",
    b"MOOMBAHTON",
    b"BHAJAN",
    b"INDIAN_CLASSICAL",
    b"GAMELAN",
    b"KLEZMER",
    b"MIDDLE_EASTERN",
    b"CHILL_HOP",
    b"BEDROOM_POP",
    b"CINEMATIC",
];

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

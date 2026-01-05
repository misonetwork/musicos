module musicos::musicos;

//=== Structs ===

public struct MUSICOS() has drop;

public struct MusicOS() has drop;

public struct AdminCap has key, store {
    id: UID,
}

//=== Init Function ===

fun init(_otw: MUSICOS, ctx: &mut TxContext) {
    let admin_cap = AdminCap {
        id: object::new(ctx),
    };

    transfer::public_transfer(admin_cap, ctx.sender());
}

//=== Public Functions ===

public fun new(): MusicOS {
    MusicOS()
}

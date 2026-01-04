module musicos::admin;

//=== Structs ===

public struct ADMIN() has drop;

public struct AdminCap has key, store {
    id: UID,
}

//=== Init Function ===

fun init(_otw: ADMIN, ctx: &mut TxContext) {
    let admin_cap = AdminCap {
        id: object::new(ctx),
    };

    transfer::public_transfer(admin_cap, ctx.sender());
}

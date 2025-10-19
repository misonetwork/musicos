module musicos::master;

use musicos::disc::Disc;

//=== Structs ===

public struct Master has key {
    id: UID,
    duration: u64,
    discs: vector<Disc>,
}

public struct MasterAdminCap has key, store {
    id: UID,
    master_id: ID,
}

//=== Errors ===

const EInvalidMasterAdminCap: u64 = 0;

//=== Public Functions ===

public fun new(discs: vector<Disc>, ctx: &mut TxContext): (Master, MasterAdminCap) {
    let mut duration: u64 = 0;
    discs.do_ref!(|disc| duration = duration + disc.duration());

    let master = Master {
        id: object::new(ctx),
        duration,
        discs,
    };

    let master_admin_cap = MasterAdminCap {
        id: object::new(ctx),
        master_id: object::id(&master),
    };

    (master, master_admin_cap)
}

//=== Public View Functions ===

public fun id(self: &Master): ID {
    object::id(self)
}

public fun discs(self: &Master): &vector<Disc> {
    &self.discs
}

public fun authorize(self: &Master, cap: &MasterAdminCap) {
    assert!(object::id(self) == cap.master_id, EInvalidMasterAdminCap);
}

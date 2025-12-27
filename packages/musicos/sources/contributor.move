// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module musicos::contributor;

public struct Contributor has key {
    id: UID,
    kind: ContributorKind,
}

public struct ContributorAdminCap has key, store {
    id: UID,
    contributor_id: ID,
}

public enum ContributorKind has copy, drop, store {
    Individual,
    Group,
}

public fun new(ctx: &mut TxContext): ContributorAdminCap {
    let contributor = Contributor {
        id: object::new(ctx),
        kind: ContributorKind::Individual,
    };

    let contributor_admin_cap = ContributorAdminCap {
        id: object::new(ctx),
        contributor_id: contributor.id(),
    };

    transfer::share_object(contributor);

    contributor_admin_cap
}

public fun id(contributor: &Contributor): ID {
    object::id(contributor)
}

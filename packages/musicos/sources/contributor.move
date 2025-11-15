// radiohead.group.contributor.musicos.sui
// thomyorke.individual.contributor.musicos.sui
module musicos::contributor;

use musicos::contributor_id::{Self, ContributorID};
use std::string::String;

public struct Contributor has key {
    id: UID,
    kind: ContributorKind,
    name: String,
}

public struct ContributorAdminCap has key, store {
    id: UID,
}

public enum ContributorKind has copy, drop, store {
    Individual,
    Group,
}

public fun new_id(self: &Contributor): ContributorID {
    contributor_id::new(self.id().to_address(), self.name)
}

public fun is_individual(self: &Contributor): bool {
    match (self.kind) {
        ContributorKind::Individual => true,
        _ => false,
    }
}

public fun is_group(self: &Contributor): bool {
    match (self.kind) {
        ContributorKind::Group => true,
        _ => false,
    }
}

public fun id(self: &Contributor): ID {
    self.id.to_inner()
}

public fun name(self: &Contributor): String {
    self.name
}

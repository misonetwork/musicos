module musicos::contributor_id;

use std::string::String;

public struct ContributorID has copy, drop, store {
    addr: address,
    name: String,
}

public(package) fun new(addr: address, name: String): ContributorID {
    ContributorID {
        addr,
        name,
    }
}

public fun addr(self: &ContributorID): address {
    self.addr
}

public fun name(self: &ContributorID): String {
    self.name
}

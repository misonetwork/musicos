module musicos::credit;

use std::string::String;

public struct Credit<Role: copy + drop + store> has copy, drop, store {
    display_name: String,
    roles: vector<Role>,
}

public(package) fun new<Role: copy + drop + store>(
    display_name: String,
    roles: vector<Role>,
): Credit<Role> {
    Credit { display_name, roles }
}

public fun display_name<Role: copy + drop + store>(self: &Credit<Role>): &String {
    &self.display_name
}

public fun roles<Role: copy + drop + store>(self: &Credit<Role>): &vector<Role> {
    &self.roles
}

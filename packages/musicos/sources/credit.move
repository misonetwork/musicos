module musicos::credit;

use std::string::String;

//=== Structs ===

public struct Credit<Role: copy + drop + store> has copy, drop, store {
    display_name: String,
    roles: vector<Role>,
}

//=== Errors ===

const EDuplicateRole: u64 = 0;

//=== Public Functions ===

public fun new<Role: copy + drop + store>(display_name: String): Credit<Role> {
    Credit { display_name, roles: vector[] }
}

public fun add_role<Role: copy + drop + store>(self: &mut Credit<Role>, role: Role) {
    assert!(!self.roles.contains(&role), EDuplicateRole);
    self.roles.push_back(role);
}

public fun remove_role<Role: copy + drop + store>(self: &mut Credit<Role>, role_idx: u64): Role {
    self.roles.remove(role_idx)
}

//=== Public View Functions ===

public fun display_name<Role: copy + drop + store>(self: &Credit<Role>): &String {
    &self.display_name
}

public fun roles<Role: copy + drop + store>(self: &Credit<Role>): &vector<Role> {
    &self.roles
}

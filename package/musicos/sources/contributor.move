module musicos::contributor;

public struct Contributor<Role> has drop, store {
    roles: vector<Role>,
}

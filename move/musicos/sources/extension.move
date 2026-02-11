module musicos::extension;

use sui::dynamic_field as df;

//=== Structs ===

public struct Extension<phantom E: drop>() has copy, drop, store;

//=== Constants ===

const EAlreadyRegistered: u64 = 0;
const ENotRegistered: u64 = 1;

//=== Package Functions ===

public(package) fun register<E: drop>(parent: &mut UID) {
    df::add(parent, Extension<E>(), true);
}

public(package) fun unregister<E: drop>(parent: &mut UID) {
    df::remove<Extension<E>, bool>(parent, Extension<E>());
}

//=== Public View Functions ===

public fun is_registered<E: drop>(parent: &UID): bool {
    df::exists_with_type<Extension<E>, bool>(parent, Extension<E>())
}

public fun is_unregistered<E: drop>(parent: &UID): bool {
    !df::exists_with_type<Extension<E>, bool>(parent, Extension<E>())
}

//=== Assert Functions ===

public fun assert_registered<E: drop>(parent: &UID) {
    assert!(is_registered<E>(parent), ENotRegistered);
}

public fun assert_unregistered<E: drop>(parent: &UID) {
    assert!(is_unregistered<E>(parent), EAlreadyRegistered);
}

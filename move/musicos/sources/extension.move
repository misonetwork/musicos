module musicos::extension;

use sui::dynamic_field as df;

//=== Structs ===

public struct Extension<phantom E: drop>() has copy, drop, store;

//=== Errors ===

const EAlreadyRegistered: u64 = 0;
const ENotRegistered: u64 = 1;

//=== Package Functions ===

public(package) fun register<E: drop, Config: store>(parent: &mut UID, config: Config) {
    assert_unregistered<E>(parent);
    df::add(parent, Extension<E>(), config);
}

public(package) fun unregister<E: drop, Config: store>(parent: &mut UID): Config {
    assert_registered<E>(parent);
    df::remove<Extension<E>, Config>(parent, Extension<E>())
}

//=== Public View Functions ===

public fun is_registered<E: drop>(parent: &UID): bool {
    df::exists_(parent, Extension<E>())
}

public fun is_unregistered<E: drop>(parent: &UID): bool {
    !df::exists_(parent, Extension<E>())
}

//=== Config Access Functions ===

/// Borrow the extension's config.
public fun config<E: drop, Config: store>(parent: &UID): &Config {
    assert_registered<E>(parent);
    df::borrow(parent, Extension<E>())
}

/// Mutably borrow the extension's config.
/// Caller must obtain `&mut UID` through the parent object's gated access.
public fun config_mut<E: drop, Config: store>(parent: &mut UID): &mut Config {
    assert_registered<E>(parent);
    df::borrow_mut(parent, Extension<E>())
}

//=== Assert Functions ===

public fun assert_registered<E: drop>(parent: &UID) {
    assert!(is_registered<E>(parent), ENotRegistered);
}

public fun assert_unregistered<E: drop>(parent: &UID) {
    assert!(is_unregistered<E>(parent), EAlreadyRegistered);
}

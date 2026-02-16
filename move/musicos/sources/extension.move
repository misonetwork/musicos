// Copyright (c) Studio Mirai, LLC
// SPDX-License-Identifier: Apache-2.0

/// Implements the MusicOS Extensions functionality. It allows third-party
/// modules to register capabilities on core MusicOS objects (Parties,
/// Compositions, Recordings, and Releases) through a dynamic field-based
/// extension system.
///
/// A MusicOS Extension is a module that builds additional functionality on
/// top of a core object without modifying or blocking the base. Common
/// use cases include reward pools, revenue distribution, and metadata
/// enrichment.
///
/// ### Flow:
///
/// - An extension is registered by the object owner via the parent object's
/// `register_extension` function, which requires the corresponding admin
/// capability (`PartyAdminCap`, `CompositionAdminCap`,
/// `RecordingAdminCap`, or `ReleaseAdminCap`).
/// - When registered, the extension stores its configuration as a typed
/// dynamic field on the parent object's UID.
/// - A registered extension can access the parent object's `UID` mutably
/// through `uid_mut_with_extension`, enabling it to attach additional
/// dynamic fields or interact with on-chain primitives (e.g., funds
/// accumulators).
/// - An extension can be unregistered by the object owner at any time,
/// which removes the extension's configuration from the parent object.
///
/// ### Notes:
///
/// - Extensions use phantom type parameters to ensure type-safe
/// registration and lookup. Each extension module defines its own witness
/// type (e.g., `Extension() has drop`).
/// - The `Extension<E>` key struct serves as a typed dynamic field key,
/// preventing collisions between different extensions on the same object.
/// - Extension configuration data must have the `store` ability and is
/// stored as the value of the dynamic field.
module musicos::extension;

use sui::dynamic_field as df;

// === Structs ===

/// A typed dynamic field key used to store extension configuration on a
/// parent object's UID. The phantom type `E` identifies the extension
/// witness, ensuring each extension has a unique storage slot.
public struct Extension<phantom E: drop>() has copy, drop, store;

// === Errors ===

/// Trying to register an extension that is already registered on the
/// parent object.
const EAlreadyRegistered: u64 = 0;

/// Trying to access or unregister an extension that is not registered on
/// the parent object.
const ENotRegistered: u64 = 1;

// === Package Functions ===

/// Register an extension on a parent object by attaching its configuration
/// as a dynamic field. Aborts if the extension is already registered.
///
/// Can only be called from within the `musicos` package (e.g., from
/// `composition::register_extension`).
public(package) fun register<E: drop, Config: drop + store>(parent: &mut UID, config: Config) {
    assert_unregistered<E>(parent);
    df::add(parent, Extension<E>(), config);
}

/// Unregister an extension from a parent object, removing and returning
/// its configuration. Aborts if the extension is not registered.
///
/// Can only be called from within the `musicos` package (e.g., from
/// `composition::unregister_extension`).
public(package) fun unregister<E: drop, Config: drop + store>(parent: &mut UID): Config {
    assert_registered<E>(parent);
    df::remove<Extension<E>, Config>(parent, Extension<E>())
}

// === View Functions ===

/// Check whether an extension of type `E` is registered on the parent
/// object.
public fun is_registered<E: drop>(parent: &UID): bool {
    df::exists_(parent, Extension<E>())
}

/// Check whether an extension of type `E` is not registered on the parent
/// object. Convenience inverse of `is_registered`.
public fun is_unregistered<E: drop>(parent: &UID): bool {
    !df::exists_(parent, Extension<E>())
}

// === Config Access ===

/// Get immutable access to the extension's configuration. Aborts if the
/// extension is not registered.
public fun config<E: drop, Config: drop + store>(parent: &UID): &Config {
    assert_registered<E>(parent);
    df::borrow(parent, Extension<E>())
}

/// Get mutable access to the extension's configuration. Aborts if the
/// extension is not registered.
///
/// The caller must obtain `&mut UID` through the parent object's gated
/// access (e.g., `uid_mut_with_extension`), which verifies that the
/// extension is authorized.
public fun config_mut<E: drop, Config: drop + store>(parent: &mut UID): &mut Config {
    assert_registered<E>(parent);
    df::borrow_mut(parent, Extension<E>())
}

// === Assertions ===

/// Assert that an extension of type `E` is registered on the parent
/// object. Aborts with `ENotRegistered` if not.
public fun assert_registered<E: drop>(parent: &UID) {
    assert!(is_registered<E>(parent), ENotRegistered);
}

/// Assert that an extension of type `E` is not registered on the parent
/// object. Aborts with `EAlreadyRegistered` if it is.
public fun assert_unregistered<E: drop>(parent: &UID) {
    assert!(is_unregistered<E>(parent), EAlreadyRegistered);
}

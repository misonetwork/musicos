// Copyright (c) Studio Mirai, LLC
// SPDX-License-Identifier: Apache-2.0

module musicos::extension;

use sui::dynamic_field as df;

//=== Errors ===

const EUnauthorizedExtension: u64 = 0;

//=== Structs ===

public struct Extension<phantom E: drop>() has copy, drop, store;

//=== Public Functions ===

public fun authorize<E: drop>(uid: &mut UID, _: E) {
    df::add(uid, new<E>(), true);
}

public fun revoke<E: drop>(uid: &mut UID, _: E) {
    df::remove<Extension<E>, bool>(uid, new<E>());
}

//=== Package Functions ===

public(package) fun assert_authorized<E: drop>(uid: &UID, _: E) {
    assert!(df::exists_with_type<Extension<E>, bool>(uid, new<E>()), EUnauthorizedExtension);
}

//=== Private Functions ===

fun new<E: drop>(): Extension<E> {
    Extension()
}

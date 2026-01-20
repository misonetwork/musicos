// Copyright (c) Studio Mirai, LLC
// SPDX-License-Identifier: Apache-2.0

module musicos::plugin;

use sui::dynamic_field as df;

//=== Errors ===

const EUnauthorizedPlugin: u64 = 0;

//=== Structs ===

public struct Plugin<phantom P: drop>() has copy, drop, store;

//=== Public Functions ===

public fun authorize<P: drop>(uid: &mut UID) {
    df::add(uid, new<P>(), true);
}

public fun revoke<P: drop>(uid: &mut UID) {
    df::remove<Plugin<P>, bool>(uid, new<P>());
}

//=== Package Functions ===

public(package) fun assert_authorized<P: drop>(uid: &UID) {
    assert!(df::exists_with_type<Plugin<P>, bool>(uid, new<P>()), EUnauthorizedPlugin);
}

//=== Private Functions ===

fun new<P: drop>(): Plugin<P> {
    Plugin()
}

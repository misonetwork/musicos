// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module musicos::witness;

//=== Structs ===

public struct Witness() has drop;

//=== Package Functions ===

public(package) fun new(): Witness {
    Witness()
}

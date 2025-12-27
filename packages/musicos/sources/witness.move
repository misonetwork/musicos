// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module musicos::witness;

public struct Witness() has drop;

public(package) fun new(): Witness {
    Witness()
}

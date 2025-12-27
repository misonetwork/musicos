// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module musicos::genre;

use std::string::String;

public struct Genre has key {
    id: UID,
    name: String,
}

public fun id(self: &Genre): ID {
    self.id.to_inner()
}

public fun name(self: &Genre): String {
    self.name
}

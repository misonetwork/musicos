// Copyright (c) Sona Labs, Pte Ltd.
// SPDX-License-Identifier: Apache-2.0

module musicos::data;

use std::string::String;

// (quilt_id, blob_id)
public struct Data(Option<String>, String) has copy, drop, store;

public fun new(quilt_id: Option<String>, blob_id: String): Data {
    Data(quilt_id, blob_id)
}

const ENoQuiltId: u64 = 0;

public fun quilt_id(self: &Data): String {
    assert!(self.0.is_some(), ENoQuiltId);
    *self.0.borrow()
}

public fun blob_id(self: &Data): String {
    self.1
}

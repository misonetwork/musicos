// Copyright (c) Sona Labs, Pte Ltd.
// SPDX-License-Identifier: Apache-2.0

module musicos::snapshot;

use std::string::String;

public enum Snapshot has copy, drop, store {
    Audio(String),
    Image(String),
    Text(String),
    Video(String),
}

// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module musicos::protocol;

public struct Protocol has key {
    id: UID,
    max_contributor_roles: u64,
    min_contributor_roles: u64,
    max_recording_stems: u64,
}

public fun max_contributor_roles(self: &Protocol): u64 {
    self.max_contributor_roles
}

public fun min_contributor_roles(self: &Protocol): u64 {
    self.min_contributor_roles
}

public fun max_recording_stems(self: &Protocol): u64 {
    self.max_recording_stems
}

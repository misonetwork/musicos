// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module musicos::protocol;

public struct Protocol has key {
    id: UID,
    max_roles_per_contributor: u64,
    min_roles_per_contributor: u64,
    max_stems_per_recording: u8,
    max_discs_per_release: u64,
    max_tracks_per_disc: u64,
}

public fun max_roles_per_contributor(self: &Protocol): u64 {
    self.max_roles_per_contributor
}

public fun min_roles_per_contributor(self: &Protocol): u64 {
    self.min_roles_per_contributor
}

public fun max_stems_per_recording(self: &Protocol): u8 {
    self.max_stems_per_recording
}

public fun max_discs_per_release(self: &Protocol): u64 {
    self.max_discs_per_release
}

public fun max_tracks_per_disc(self: &Protocol): u64 {
    self.max_tracks_per_disc
}

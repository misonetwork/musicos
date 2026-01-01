// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module musicos::protocol;

use interest_bps::bps::{Self, BPS};
use std::type_name::{TypeName, with_defining_ids};
use sui::vec_set::{Self, VecSet};

//=== Structs ===

public struct PROTOCOL() has drop;

public struct Protocol has key, store {
    id: UID,
    // Authority types for creating Audio structs.
    audio_creation_authority_types: VecSet<TypeName>,
    // Authority types for verifying Contributor objects.
    contributor_verification_authority_types: VecSet<TypeName>,
    facilitator_commission_rate: BPS,
    facilitator_history_window_length: u8,
    facilitator_types: VecSet<TypeName>,
    max_roles_per_contributor: u8,
    min_roles_per_contributor: u8,
    max_stems_per_recording: u8,
    max_discs_per_release: u8,
    max_tracks_per_disc: u8,
    max_track_sequence_length: u8,
}

//=== Constants ===

const DEFAULT_FACILITATOR_HISTORY_WINDOW_LENGTH: u8 = 100;
const DEFAULT_FACILITATOR_COMMISSION_RATE_VALUE: u64 = 10; // 0.1%
const DEFAULT_MAX_ROLES_PER_CONTRIBUTOR: u8 = 10;
const DEFAULT_MIN_ROLES_PER_CONTRIBUTOR: u8 = 1;
const DEFAULT_MAX_STEMS_PER_RECORDING: u8 = 50;
const DEFAULT_MAX_DISCS_PER_RELEASE: u8 = 10;
const DEFAULT_MAX_TRACKS_PER_DISC: u8 = 50;
const DEFAULT_MAX_TRACK_SEQUENCE_LENGTH: u8 = 250;
const MAX_FACILITATOR_COMMISSION_RATE_VALUE: u64 = 50; // 0.5%

//=== Errors ===

const EExceedsMaxFacilitatorCommissionRate: u64 = 0;

fun init(_otw: PROTOCOL, ctx: &mut TxContext) {
    let protocol = Protocol {
        id: object::new(ctx),
        audio_creation_authority_types: vec_set::empty(),
        contributor_verification_authority_types: vec_set::empty(),
        facilitator_history_window_length: DEFAULT_FACILITATOR_HISTORY_WINDOW_LENGTH,
        facilitator_commission_rate: bps::new(DEFAULT_FACILITATOR_COMMISSION_RATE_VALUE),
        facilitator_types: vec_set::empty(),
        max_roles_per_contributor: DEFAULT_MAX_ROLES_PER_CONTRIBUTOR,
        min_roles_per_contributor: DEFAULT_MIN_ROLES_PER_CONTRIBUTOR,
        max_stems_per_recording: DEFAULT_MAX_STEMS_PER_RECORDING,
        max_discs_per_release: DEFAULT_MAX_DISCS_PER_RELEASE,
        max_tracks_per_disc: DEFAULT_MAX_TRACKS_PER_DISC,
        max_track_sequence_length: DEFAULT_MAX_TRACK_SEQUENCE_LENGTH,
    };

    transfer::share_object(protocol);
}

//=== Public Functions ===

public fun add_audio_creation_authority_type<Authority: drop>(self: &mut Protocol) {
    self.audio_creation_authority_types.insert(with_defining_ids<Authority>());
}

public fun remove_audio_creation_authority_type<Authority: drop>(self: &mut Protocol) {
    self.audio_creation_authority_types.remove(&with_defining_ids<Authority>());
}

public fun add_contributor_verification_authority_type<Authority: drop>(self: &mut Protocol) {
    self.contributor_verification_authority_types.insert(with_defining_ids<Authority>());
}

public fun remove_contributor_verification_authority_type<Authority: drop>(self: &mut Protocol) {
    self.contributor_verification_authority_types.remove(&with_defining_ids<Authority>());
}

public fun set_facilitator_commission_rate(self: &mut Protocol, rate: BPS) {
    assert!(
        rate.value() <= MAX_FACILITATOR_COMMISSION_RATE_VALUE,
        EExceedsMaxFacilitatorCommissionRate,
    );
    self.facilitator_commission_rate = rate;
}

public fun set_facilitator_history_window_length(self: &mut Protocol, length: u8) {
    self.facilitator_history_window_length = length;
}

public fun add_facilitator_type<Facilitator: drop>(self: &mut Protocol) {
    self.facilitator_types.insert(with_defining_ids<Facilitator>());
}

public fun remove_facilitator_type<Facilitator: drop>(self: &mut Protocol) {
    self.facilitator_types.remove(&with_defining_ids<Facilitator>());
}

public fun set_max_roles_per_contributor(self: &mut Protocol, count: u8) {
    self.max_roles_per_contributor = count;
}

public fun set_min_roles_per_contributor(self: &mut Protocol, count: u8) {
    self.min_roles_per_contributor = count;
}

public fun set_max_stems_per_recording(self: &mut Protocol, count: u8) {
    self.max_stems_per_recording = count;
}

public fun set_max_discs_per_release(self: &mut Protocol, count: u8) {
    self.max_discs_per_release = count;
}

public fun set_max_tracks_per_disc(self: &mut Protocol, count: u8) {
    self.max_tracks_per_disc = count;
}

public fun set_max_track_sequence_length(self: &mut Protocol, length: u8) {
    self.max_track_sequence_length = length;
}

//=== Public View Functions ===

public fun audio_creation_authority_types(self: &Protocol): &VecSet<TypeName> {
    &self.audio_creation_authority_types
}

public fun contributor_verification_authority_types(self: &Protocol): &VecSet<TypeName> {
    &self.contributor_verification_authority_types
}

public fun facilitator_commission_rate(self: &Protocol): BPS {
    self.facilitator_commission_rate
}

public fun facilitator_history_window_length(self: &Protocol): u8 {
    self.facilitator_history_window_length
}

public fun facilitator_types(self: &Protocol): &VecSet<TypeName> {
    &self.facilitator_types
}

public fun max_roles_per_contributor(self: &Protocol): u8 {
    self.max_roles_per_contributor
}

public fun min_roles_per_contributor(self: &Protocol): u8 {
    self.min_roles_per_contributor
}

public fun max_stems_per_recording(self: &Protocol): u8 {
    self.max_stems_per_recording
}

public fun max_discs_per_release(self: &Protocol): u8 {
    self.max_discs_per_release
}

public fun max_tracks_per_disc(self: &Protocol): u8 {
    self.max_tracks_per_disc
}

public fun max_track_sequence_length(self: &Protocol): u8 {
    self.max_track_sequence_length
}

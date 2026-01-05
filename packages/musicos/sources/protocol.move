// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module musicos::protocol;

use musicos::musicos::AdminCap;
use std::type_name::{TypeName, with_defining_ids};
use sui::vec_set::{Self, VecSet};

//=== Structs ===

public struct PROTOCOL() has drop;

public struct Protocol has key, store {
    id: UID,
    state: ProtocolState,
    // Authority types for creating Audio structs.
    audio_creation_authority_types: VecSet<TypeName>,
    // Authority types for verifying Contributor objects.
    contributor_verification_authority_types: VecSet<TypeName>,
    play_authority_types: VecSet<TypeName>,
    royalty_distribution_duration_epochs: u64,
    composition_creation_fee: u64,
    recording_creation_fee: u64,
}

//=== Enums ===

public enum ProtocolState has copy, drop, store {
    Genesis,
    Active,
    Paused,
    // End epoch for deprecation delay.
    Deprecating(u64),
    // Authority type for migration.
    Deprecated(TypeName),
}

//=== Constants ===

const DEFAULT_ROYALTY_DISTRIBUTION_DURATION_EPOCHS: u64 = 10;
const DEPRECATION_DELAY_EPOCHS: u64 = 5;

//=== Errors ===

const ENotActiveState: u64 = 1;
const ENotPausedState: u64 = 2;
const ENotDeprecatingState: u64 = 3;
const ENotDeprecatedState: u64 = 4;
const EDeprecationDelayNotElapsed: u64 = 5;
const EAlreadyDeprecatedState: u64 = 6;

//=== Init Function ===

fun init(_otw: PROTOCOL, ctx: &mut TxContext) {
    let protocol = Protocol {
        id: object::new(ctx),
        state: ProtocolState::Genesis,
        audio_creation_authority_types: vec_set::empty(),
        contributor_verification_authority_types: vec_set::empty(),
        play_authority_types: vec_set::empty(),
        royalty_distribution_duration_epochs: DEFAULT_ROYALTY_DISTRIBUTION_DURATION_EPOCHS,
        composition_creation_fee: 0,
        recording_creation_fee: 0,
    };

    transfer::share_object(protocol);
}

//=== Public Functions ===

public fun set_active_state(self: &mut Protocol, _: &AdminCap) {
    match (self.state) {
        ProtocolState::Deprecated(..) => {
            abort EAlreadyDeprecatedState
        },
        _ => {},
    };

    self.state = ProtocolState::Active;
}

public fun set_paused_state(self: &mut Protocol, _: &AdminCap) {
    match (self.state) {
        ProtocolState::Active => {
            self.state = ProtocolState::Paused;
        },
        _ => abort ENotActiveState,
    };
}

public fun set_deprecating_state(self: &mut Protocol, _: &AdminCap, ctx: &TxContext) {
    match (self.state) {
        ProtocolState::Active => {
            self.state = ProtocolState::Deprecating(ctx.epoch() + DEPRECATION_DELAY_EPOCHS);
        },
        _ => abort ENotActiveState,
    };
}

public fun set_deprecated_state<MigrationAuthority: drop>(
    self: &mut Protocol,
    _: &AdminCap,
    ctx: &TxContext,
) {
    match (self.state) {
        ProtocolState::Deprecating(end_epoch) => {
            assert!(ctx.epoch() > end_epoch, EDeprecationDelayNotElapsed);
            self.state = ProtocolState::Deprecated(with_defining_ids<MigrationAuthority>());
        },
        _ => abort ENotActiveState,
    }
}

public fun add_audio_creation_authority_type<Authority: drop>(self: &mut Protocol, _: &AdminCap) {
    self.audio_creation_authority_types.insert(with_defining_ids<Authority>());
}

public fun remove_audio_creation_authority_type<Authority: drop>(
    self: &mut Protocol,
    _: &AdminCap,
) {
    self.audio_creation_authority_types.remove(&with_defining_ids<Authority>());
}

public fun add_contributor_verification_authority_type<Authority: drop>(
    self: &mut Protocol,
    _: &AdminCap,
) {
    self.contributor_verification_authority_types.insert(with_defining_ids<Authority>());
}

public fun remove_contributor_verification_authority_type<Authority: drop>(
    self: &mut Protocol,
    _: &AdminCap,
) {
    self.contributor_verification_authority_types.remove(&with_defining_ids<Authority>());
}

public fun set_royalty_distribution_duration_epochs(
    self: &mut Protocol,
    _: &AdminCap,
    duration: u64,
) {
    self.royalty_distribution_duration_epochs = duration;
}

public fun set_composition_creation_fee(self: &mut Protocol, _: &AdminCap, fee: u64) {
    self.composition_creation_fee = fee;
}

public fun set_recording_creation_fee(self: &mut Protocol, _: &AdminCap, fee: u64) {
    self.recording_creation_fee = fee;
}

//=== Public View Functions ===

public fun is_genesis_state(self: &Protocol): bool {
    match (&self.state) {
        ProtocolState::Genesis => true,
        _ => false,
    }
}

public fun is_active_state(self: &Protocol): bool {
    match (&self.state) {
        ProtocolState::Active => true,
        _ => false,
    }
}

public fun is_paused_state(self: &Protocol): bool {
    match (&self.state) {
        ProtocolState::Paused => true,
        _ => false,
    }
}

public fun is_deprecating_state(self: &Protocol): bool {
    match (&self.state) {
        ProtocolState::Deprecating(..) => true,
        _ => false,
    }
}

public fun is_deprecated_state(self: &Protocol): bool {
    match (&self.state) {
        ProtocolState::Deprecated(..) => true,
        _ => false,
    }
}

public fun audio_creation_authority_types(self: &Protocol): &VecSet<TypeName> {
    &self.audio_creation_authority_types
}

public fun contributor_verification_authority_types(self: &Protocol): &VecSet<TypeName> {
    &self.contributor_verification_authority_types
}

public fun play_authority_types(self: &Protocol): &VecSet<TypeName> {
    &self.play_authority_types
}

public fun royalty_distribution_duration_epochs(self: &Protocol): u64 {
    self.royalty_distribution_duration_epochs
}

public fun composition_creation_fee(self: &Protocol): u64 {
    self.composition_creation_fee
}

public fun recording_creation_fee(self: &Protocol): u64 {
    self.recording_creation_fee
}

//=== Assert Functions ===

public fun assert_is_active_state(self: &Protocol) {
    assert!(is_active_state(self), ENotActiveState);
}

public fun assert_is_paused_state(self: &Protocol) {
    assert!(is_paused_state(self), ENotPausedState);
}

public fun assert_is_deprecating_state(self: &Protocol) {
    assert!(is_deprecating_state(self), ENotDeprecatingState);
}

public fun assert_is_deprecated_state(self: &Protocol) {
    assert!(is_deprecated_state(self), ENotDeprecatedState);
}

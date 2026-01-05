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
    state: ProtocolState,
    // Authority types for creating Audio structs.
    audio_creation_authority_types: VecSet<TypeName>,
    // Authority types for verifying Contributor objects.
    contributor_verification_authority_types: VecSet<TypeName>,
    play_authority_types: VecSet<TypeName>,
    royalty_distribution_duration_epochs: u64,
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

const DEFAULT_FACILITATOR_HISTORY_WINDOW_LENGTH: u8 = 100;
const DEFAULT_FACILITATOR_COMMISSION_RATE_VALUE: u64 = 10; // 0.1%
const DEFAULT_MAX_ROLES_PER_CONTRIBUTOR: u8 = 10;
const DEFAULT_MIN_ROLES_PER_CONTRIBUTOR: u8 = 1;
const DEFAULT_MAX_STEMS_PER_RECORDING: u8 = 50;
const DEFAULT_MAX_DISCS_PER_RELEASE: u8 = 10;
const DEFAULT_MAX_TRACKS_PER_DISC: u8 = 50;
const DEFAULT_MAX_TRACK_SEQUENCE_LENGTH: u8 = 250;
const DEFAULT_ROYALTY_DISTRIBUTION_DURATION_EPOCHS: u64 = 10;
const MAX_FACILITATOR_COMMISSION_RATE_VALUE: u64 = 50; // 0.5%
const DEPRECATION_DELAY_EPOCHS: u64 = 5;

//=== Errors ===

const EExceedsMaxFacilitatorCommissionRate: u64 = 0;
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
    };

    transfer::share_object(protocol);
}

//=== Public Functions ===

public fun set_active_state(self: &mut Protocol) {
    match (self.state) {
        ProtocolState::Deprecated(..) => {
            abort EAlreadyDeprecatedState
        },
        _ => {},
    };

    self.state = ProtocolState::Active;
}

public fun set_paused_state(self: &mut Protocol) {
    match (self.state) {
        ProtocolState::Active => {
            self.state = ProtocolState::Paused;
        },
        _ => abort ENotActiveState,
    };
}

public fun set_deprecating_state(self: &mut Protocol, ctx: &TxContext) {
    match (self.state) {
        ProtocolState::Active => {
            self.state = ProtocolState::Deprecating(ctx.epoch() + DEPRECATION_DELAY_EPOCHS);
        },
        _ => abort ENotActiveState,
    };
}

public fun set_deprecated_state<MigrationAuthority: drop>(self: &mut Protocol, ctx: &TxContext) {
    match (self.state) {
        ProtocolState::Deprecating(end_epoch) => {
            assert!(ctx.epoch() > end_epoch, EDeprecationDelayNotElapsed);
            self.state = ProtocolState::Deprecated(with_defining_ids<MigrationAuthority>());
        },
        _ => abort ENotActiveState,
    }
}

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

public fun set_royalty_distribution_duration_epochs(self: &mut Protocol, duration: u64) {
    self.royalty_distribution_duration_epochs = duration;
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

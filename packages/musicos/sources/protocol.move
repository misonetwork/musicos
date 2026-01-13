// Copyright (c) Sona Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// The central configuration object for the MusicOS protocol.
/// Controls protocol state, authorized authority types, commission rates,
/// and other global settings. Only one Protocol instance exists (shared object).
///
/// Key features:
/// - Lifecycle states: Genesis -> Active <-> Paused -> Deprecating -> Deprecated
/// - Authority type registration for audio creation, contributor verification, and plays
/// - Configurable commission rate and royalty distribution duration
/// - Admin-controlled state transitions
module musicos::protocol;

use interest_bps::bps::{Self, BPS};
use musicos::admin::AdminCap;
use std::type_name::{TypeName, with_defining_ids};
use sui::vec_set::{Self, VecSet};

//=== Structs ===

/// One-time witness for the protocol module.
public struct PROTOCOL() has drop;

/// The global protocol configuration object.
/// Shared and accessible to all protocol operations.
public struct Protocol has key, store {
    /// Unique identifier for the protocol.
    id: UID,
    /// Current lifecycle state of the protocol.
    state: ProtocolState,
    /// Commission rate charged by the protocol on distributions (in basis points).
    commission_rate: BPS,
    /// Authority types allowed to create Audio structs.
    audio_creation_authority_types: VecSet<TypeName>,
    /// Authority types allowed to verify Contributor objects.
    contributor_verification_authority_types: VecSet<TypeName>,
    /// Authority types allowed to record play events.
    play_authority_types: VecSet<TypeName>,
    /// Number of epochs for royalty distribution windows.
    royalty_distribution_duration_epochs: u64,
}

//=== Enums ===

/// The lifecycle state of the protocol.
public enum ProtocolState has copy, drop, store {
    /// Initial state before activation.
    Genesis,
    /// Protocol is active and accepting operations.
    Active,
    /// Protocol is temporarily paused.
    Paused,
    /// Protocol is being deprecated; includes end epoch for delay period.
    Deprecating(
        /// Epoch after which deprecation can be finalized.
        u64,
    ),
    /// Protocol is deprecated; includes migration authority type.
    Deprecated(
        /// Type of the authority that can perform migration.
        TypeName,
    ),
}

//=== Constants ===

/// Default number of epochs for royalty distribution windows.
const DEFAULT_ROYALTY_DISTRIBUTION_DURATION_EPOCHS: u64 = 10;
/// Default commission rate: 100 BPS = 1%.
const DEFAULT_COMMISSION_RATE_VALUE: u64 = 100;
/// Number of epochs to wait before finalizing deprecation.
const DEPRECATION_DELAY_EPOCHS: u64 = 5;

//=== Errors ===

/// Protocol is not in Active state.
const ENotActiveState: u64 = 3;
/// Protocol is not in Paused state.
const ENotPausedState: u64 = 5;
/// Protocol is not in Deprecating state.
const ENotDeprecatingState: u64 = 6;
/// Protocol is not in Deprecated state.
const ENotDeprecatedState: u64 = 7;
/// Protocol is already deprecated and cannot change state.
const EAlreadyDeprecatedState: u64 = 8;
/// Deprecation delay period has not elapsed.
const EDeprecationDelayNotElapsed: u64 = 9;

//=== Init Function ===

/// Initializes the protocol with default settings.
/// Creates a shared Protocol object in Genesis state.
fun init(_otw: PROTOCOL, ctx: &mut TxContext) {
    let protocol = Protocol {
        id: object::new(ctx),
        state: ProtocolState::Genesis,
        audio_creation_authority_types: vec_set::empty(),
        contributor_verification_authority_types: vec_set::empty(),
        play_authority_types: vec_set::empty(),
        royalty_distribution_duration_epochs: DEFAULT_ROYALTY_DISTRIBUTION_DURATION_EPOCHS,
        commission_rate: bps::new(DEFAULT_COMMISSION_RATE_VALUE),
    };

    transfer::share_object(protocol);
}

//=== Public Functions ===

/// Transitions the protocol to Active state.
/// Can be called from any state except Deprecated.
/// Requires admin capability.
public fun set_active_state(self: &mut Protocol, _: &AdminCap) {
    match (self.state) {
        ProtocolState::Deprecated(..) => {
            abort EAlreadyDeprecatedState
        },
        _ => {},
    };

    self.state = ProtocolState::Active;
}

/// Pauses the protocol, preventing most operations.
/// Can only be called when Active. Requires admin capability.
public fun set_paused_state(self: &mut Protocol, _: &AdminCap) {
    match (self.state) {
        ProtocolState::Active => {
            self.state = ProtocolState::Paused;
        },
        _ => abort ENotActiveState,
    };
}

/// Initiates protocol deprecation with a delay period.
/// Can only be called when Active. Requires admin capability.
public fun set_deprecating_state(self: &mut Protocol, _: &AdminCap, ctx: &TxContext) {
    match (self.state) {
        ProtocolState::Active => {
            self.state = ProtocolState::Deprecating(ctx.epoch() + DEPRECATION_DELAY_EPOCHS);
        },
        _ => abort ENotActiveState,
    };
}

/// Finalizes protocol deprecation after the delay period.
/// Sets the migration authority type for future migrations.
/// Requires admin capability.
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

/// Registers an authority type that can create Audio structs.
/// Requires admin capability.
public fun add_audio_creation_authority_type<Authority: drop>(self: &mut Protocol, _: &AdminCap) {
    self.audio_creation_authority_types.insert(with_defining_ids<Authority>());
}

/// Removes an authority type from audio creation permissions.
/// Requires admin capability.
public fun remove_audio_creation_authority_type<Authority: drop>(
    self: &mut Protocol,
    _: &AdminCap,
) {
    self.audio_creation_authority_types.remove(&with_defining_ids<Authority>());
}

/// Registers an authority type that can verify contributors.
/// Requires admin capability.
public fun add_contributor_verification_authority_type<Authority: drop>(
    self: &mut Protocol,
    _: &AdminCap,
) {
    self.contributor_verification_authority_types.insert(with_defining_ids<Authority>());
}

/// Removes an authority type from contributor verification permissions.
/// Requires admin capability.
public fun remove_contributor_verification_authority_type<Authority: drop>(
    self: &mut Protocol,
    _: &AdminCap,
) {
    self.contributor_verification_authority_types.remove(&with_defining_ids<Authority>());
}

/// Sets the number of epochs for royalty distribution windows.
/// Requires admin capability.
public fun set_royalty_distribution_duration_epochs(
    self: &mut Protocol,
    _: &AdminCap,
    duration_epochs: u64,
) {
    self.royalty_distribution_duration_epochs = duration_epochs;
}

//=== Public View Functions ===

/// Returns the protocol's object ID.
public fun id(self: &Protocol): ID {
    self.id.to_inner()
}

/// Returns the set of authority types that can create Audio structs.
public fun audio_creation_authority_types(self: &Protocol): &VecSet<TypeName> {
    &self.audio_creation_authority_types
}

/// Returns the set of authority types that can verify contributors.
public fun contributor_verification_authority_types(self: &Protocol): &VecSet<TypeName> {
    &self.contributor_verification_authority_types
}

/// Returns the set of authority types that can record plays.
public fun play_authority_types(self: &Protocol): &VecSet<TypeName> {
    &self.play_authority_types
}

/// Returns the number of epochs for royalty distribution windows.
public fun royalty_distribution_duration_epochs(self: &Protocol): u64 {
    self.royalty_distribution_duration_epochs
}

/// Returns the protocol's commission rate in basis points.
public fun commission_rate(self: &Protocol): BPS {
    self.commission_rate
}

/// Returns true if the protocol is in Genesis state.
public fun is_genesis_state(self: &Protocol): bool {
    match (&self.state) {
        ProtocolState::Genesis => true,
        _ => false,
    }
}

/// Returns true if the protocol is in Active state.
public fun is_active_state(self: &Protocol): bool {
    match (&self.state) {
        ProtocolState::Active => true,
        _ => false,
    }
}

/// Returns true if the protocol is in Paused state.
public fun is_paused_state(self: &Protocol): bool {
    match (&self.state) {
        ProtocolState::Paused => true,
        _ => false,
    }
}

/// Returns true if the protocol is in Deprecating state.
public fun is_deprecating_state(self: &Protocol): bool {
    match (&self.state) {
        ProtocolState::Deprecating(..) => true,
        _ => false,
    }
}

/// Returns true if the protocol is in Deprecated state.
public fun is_deprecated_state(self: &Protocol): bool {
    match (&self.state) {
        ProtocolState::Deprecated(..) => true,
        _ => false,
    }
}

//=== Package Functions ===

/// Returns a mutable reference to the protocol's UID.
/// Package-internal use only.
public(package) fun uid_mut(self: &mut Protocol): &mut UID {
    &mut self.id
}

//=== Package View Functions ===

/// Returns a reference to the protocol's UID.
/// Package-internal use only.
public(package) fun uid(self: &Protocol): &UID {
    &self.id
}

//=== Assert Functions ===

/// Aborts if the protocol is not in Active state.
public fun assert_is_active_state(self: &Protocol) {
    assert!(is_active_state(self), ENotActiveState);
}

/// Aborts if the protocol is not in Paused state.
public fun assert_is_paused_state(self: &Protocol) {
    assert!(is_paused_state(self), ENotPausedState);
}

/// Aborts if the protocol is not in Deprecating state.
public fun assert_is_deprecating_state(self: &Protocol) {
    assert!(is_deprecating_state(self), ENotDeprecatingState);
}

/// Aborts if the protocol is not in Deprecated state.
public fun assert_is_deprecated_state(self: &Protocol) {
    assert!(is_deprecated_state(self), ENotDeprecatedState);
}

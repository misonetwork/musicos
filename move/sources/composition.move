// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Represents a musical composition (song, instrumental work) in MusicOS.
/// Compositions are the underlying written works that recordings are based on.
/// Each composition has its own share token for ownership distribution.
///
/// ### Key Features:
///
/// - Share token initialization with fixed supply (10M tokens, 6 decimals)
/// - State machine: Initialized -> Published (embedded fields immutable after
///   publish; dynamic fields remain extensible via `uid_mut`)
/// - Deterministic addresses via derived object pattern
///
/// Attribution (credits) is intentionally NOT part of core: it is
/// display-oriented, varies across platforms, and is never read by the
/// economics. It lives in a first-party credits extension attached via
/// `uid_mut`, so core takes no dependency on an identity package and core
/// publish enforces no attribution.
module musicos::composition;

use bps::bps::{Self, BPS};
use share::share;
use std::string::String;
use sui::balance::Balance;
use sui::clock::Clock;
use sui::coin::TreasuryCap;
use sui::coin_registry::Currency;
use sui::derived_object::claim;
use sui::event::emit;

// === Structs ===

/// A musical composition representing the underlying written work.
/// The phantom CompositionShare type parameter links to the share token.
public struct Composition<phantom CompositionShare> has key {
    /// Unique identifier for this composition.
    id: UID,
    /// Current lifecycle state.
    state: CompositionState,
    /// Primary title of the composition.
    title: String,
    /// Royalty rate this composition earns from each recording's revenue,
    /// paired with the epoch it was last changed in. Each rate stays in
    /// effect for at least one full epoch.
    royalty_rate: CompositionRoyaltyRate,
}

/// Capability that authorizes modifications to a specific composition.
/// Initialized when a composition is registered and transferred to the owner.
/// Address is derived from the composition for client-side discoverability.
public struct CompositionAdminCap<phantom CompositionShare> has key, store {
    /// Unique identifier for this capability.
    id: UID,
}

/// The royalty rate paired with the epoch in which it was last set.
/// A rate change requires a full epoch to have elapsed since the last change —
/// a rate set in epoch N is changeable from epoch N+2 onward — so every rate
/// is in effect for at least one complete epoch. This bounds how a rate change
/// can surprise a recording creator and makes bait-and-revert oscillation
/// uneconomical: once a change lands, it is pinned in full public view for the
/// remainder of that epoch plus the entire next one.
public struct CompositionRoyaltyRate(BPS, u64) has copy, drop, store;

// === Derivation Keys ===

/// Key for deriving the admin capability's deterministic address from the composition.
public struct CompositionAdminCapKey() has copy, drop, store;

// === Enums ===

/// Lifecycle state of a composition.
public enum CompositionState has copy, drop, store {
    /// Composition is initialized but not published.
    Initialized,
    /// Composition is published and immutable. Includes publication timestamp.
    Published(
        /// Timestamp (ms) when published.
        u64,
    ),
}

// === Events ===

/// Emitted once when a composition is published. A pure pointer: it carries the
/// composition's identity. A composition's membership is immutable after
/// publishing, so an indexer treats this as a signal to fetch the full object by
/// `composition_id`; all indexed data — including the publish timestamp — lives
/// in the object itself (the royalty rate may change later and is tracked
/// separately via `CompositionRoyaltySetEvent`).
public struct CompositionPublishedEvent<phantom CompositionShare> has copy, drop {
    composition_id: ID,
}

/// Emitted when the composition's royalty rate is set or changed.
public struct CompositionRoyaltySetEvent has copy, drop {
    composition_id: ID,
    royalty_rate_bps: u16,
}

// === Constants ===

/// Maximum length of a title in bytes.
const MAX_TITLE_LENGTH: u64 = 300;
/// Protocol-immutable ceiling for a composition's royalty rate (20%). Anyone may
/// record a published composition at the posted rate — a compulsory license —
/// which is only meaningful if the rate is bounded; an uncapped rate would let a
/// composition retroactively price out the cover right entirely. ~20% matches the
/// composition side's share of streaming rights-holder revenue off-chain
/// (publishing earns ~12-15% of gross vs ~52-58% to recordings).
///
/// There is intentionally no floor: the rate may be as low as 0%. A composition
/// that captures no defined songwriting contribution — e.g. a purely generative
/// recording with no authored underlying work — can legitimately carry a 0%
/// rate, in which case it is granted no recording shares at creation.
const MAX_ROYALTY_RATE_BPS: u16 = 2000;

// === Errors ===

// State errors (10-19)
/// Operation requires Initialized state but composition is in a different state.
const ENotInitializedState: u64 = 10;
/// Royalty rate was changed less than one full epoch ago.
const ERoyaltyRateCooldown: u64 = 11;

// Validation errors (20-29)
/// Royalty rate is above the protocol maximum.
const EAboveMaxRoyaltyRate: u64 = 22;

// Constraint errors (30-39)
/// Title exceeds maximum length.
const EMaxTitleLengthExceeded: u64 = 33;
/// String must not be empty.
const EEmptyString: u64 = 35;

// === Public Functions ===

// === Lifecycle ===

/// Creates a new composition with the given title and royalty rate.
/// The royalty rate must not exceed `MAX_ROYALTY_RATE_BPS`; there is no floor,
/// so 0% is permitted (e.g. a generative recording with no authored composition).
/// Initializes share tokens (10M supply, 6 decimals) and returns:
/// - The composition object
/// - Admin capability for the owner
/// - Initial share token balance
public fun new<CompositionShare>(
    title: String,
    royalty_rate_bps: u16,
    share_currency: &mut Currency<CompositionShare>,
    share_treasury_cap: TreasuryCap<CompositionShare>,
    ctx: &mut TxContext,
): (
    Composition<CompositionShare>,
    CompositionAdminCap<CompositionShare>,
    Balance<CompositionShare>,
) {
    assert!(!title.is_empty(), EEmptyString);
    assert!(title.length() <= MAX_TITLE_LENGTH, EMaxTitleLengthExceeded);
    assert!(royalty_rate_bps <= MAX_ROYALTY_RATE_BPS, EAboveMaxRoyaltyRate);

    let mut composition = Composition<CompositionShare> {
        id: object::new(ctx),
        state: CompositionState::Initialized,
        title,
        royalty_rate: CompositionRoyaltyRate(bps::new(royalty_rate_bps), ctx.epoch()),
    };

    let composition_admin_cap = CompositionAdminCap<CompositionShare> {
        id: claim(&mut composition.id, CompositionAdminCapKey()),
    };

    let composition_shares = share::initialize<CompositionShare>(
        share_currency,
        share_treasury_cap,
    );

    (composition, composition_admin_cap, composition_shares)
}

/// Publishes the composition, making its embedded fields immutable.
/// Required State: Initialized
///
/// Note: core enforces no attribution requirement — credits live in the credits
/// extension and may be attached before or after publish via `uid_mut`.
public fun publish<CompositionShare>(
    mut self: Composition<CompositionShare>,
    _: &CompositionAdminCap<CompositionShare>,
    clock: &Clock,
) {
    match (self.state) {
        CompositionState::Initialized => {
            let published_at_ms = clock.timestamp_ms();
            self.state = CompositionState::Published(published_at_ms);

            emit(CompositionPublishedEvent<CompositionShare> {
                composition_id: self.id(),
            });

            transfer::share_object(self);
        },
        _ => abort ENotInitializedState,
    }
}

// === Financial ===

/// Sets the royalty rate this composition earns from each recording.
/// Must not exceed `MAX_ROYALTY_RATE_BPS` (there is no floor; 0% is allowed),
/// and only after a full epoch has elapsed since the last change — a rate set in epoch
/// N is changeable from epoch N+2 onward, so every rate is in effect for at
/// least one complete epoch. The rate can be changed in any lifecycle state,
/// including after publishing — because each recording snapshots the rate
/// when it is created, a change only affects recordings created afterward
/// (existing recordings keep the rate they captured).
public fun set_royalty_rate<CompositionShare>(
    self: &mut Composition<CompositionShare>,
    _: &CompositionAdminCap<CompositionShare>,
    royalty_rate_bps: u16,
    ctx: &TxContext,
) {
    assert!(royalty_rate_bps <= MAX_ROYALTY_RATE_BPS, EAboveMaxRoyaltyRate);
    assert!(ctx.epoch() > self.royalty_rate.1 + 1, ERoyaltyRateCooldown);
    self.royalty_rate = CompositionRoyaltyRate(bps::new(royalty_rate_bps), ctx.epoch());

    emit(CompositionRoyaltySetEvent {
        composition_id: self.id(),
        royalty_rate_bps,
    });
}

// === Public View Functions ===

/// Returns the composition's object ID.
public fun id<CompositionShare>(self: &Composition<CompositionShare>): ID {
    self.id.to_inner()
}

/// Returns the current lifecycle state.
public fun state<CompositionShare>(self: &Composition<CompositionShare>): CompositionState {
    self.state
}

/// Returns true if the composition is in the Initialized state.
public fun is_initialized_state<CompositionShare>(self: &Composition<CompositionShare>): bool {
    match (self.state) {
        CompositionState::Initialized => true,
        _ => false,
    }
}

/// Returns true if the composition is in the Published state.
public fun is_published_state<CompositionShare>(self: &Composition<CompositionShare>): bool {
    match (self.state) {
        CompositionState::Published(_) => true,
        _ => false,
    }
}

/// Returns the primary title.
public fun title<CompositionShare>(self: &Composition<CompositionShare>): &String {
    &self.title
}

/// Returns the royalty rate this composition earns from each recording.
public fun royalty_rate<CompositionShare>(self: &Composition<CompositionShare>): BPS {
    self.royalty_rate.0
}

/// Returns the epoch in which the royalty rate was last changed.
public fun royalty_rate_last_changed_epoch<CompositionShare>(
    self: &Composition<CompositionShare>,
): u64 {
    self.royalty_rate.1
}

// === UID Functions ===

/// Returns a reference to the composition's UID for reading dynamic fields.
public fun uid<CompositionShare>(self: &Composition<CompositionShare>): &UID {
    &self.id
}

/// Returns a mutable reference to the composition's UID.
/// Requires the admin capability. Works in any lifecycle state — dynamic
/// fields are the extension surface and stay admin-mutable after publish;
/// only the embedded fields are frozen.
public fun uid_mut<CompositionShare>(
    self: &mut Composition<CompositionShare>,
    _: &CompositionAdminCap<CompositionShare>,
): &mut UID {
    &mut self.id
}

public(package) fun uid_mut_internal<CompositionShare>(
    self: &mut Composition<CompositionShare>,
): &mut UID {
    &mut self.id
}

// === Test Only ===

#[test_only]
public fun new_for_testing<CompositionShare>(
    title: String,
    royalty_rate_bps: u16,
    ctx: &mut TxContext,
): (Composition<CompositionShare>, CompositionAdminCap<CompositionShare>) {
    assert!(!title.is_empty(), EEmptyString);
    assert!(title.length() <= MAX_TITLE_LENGTH, EMaxTitleLengthExceeded);
    assert!(royalty_rate_bps <= MAX_ROYALTY_RATE_BPS, EAboveMaxRoyaltyRate);

    let mut composition = Composition<CompositionShare> {
        id: object::new(ctx),
        state: CompositionState::Initialized,
        title,
        royalty_rate: CompositionRoyaltyRate(bps::new(royalty_rate_bps), ctx.epoch()),
    };

    let composition_admin_cap = CompositionAdminCap<CompositionShare> {
        id: claim(&mut composition.id, CompositionAdminCapKey()),
    };

    (composition, composition_admin_cap)
}

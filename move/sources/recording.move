// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Represents an audio recording of a composition in Miso.
/// Recordings are the audio performances that are distributed and played.
/// Each recording has its own share token for ownership distribution.
///
/// ### Key Features:
///
/// - Share token initialization with fixed supply (10M tokens, 6 decimals)
/// - State machine: Initialized -> Published (embedded fields immutable after
///   publish; dynamic fields remain extensible via `uid_mut`, e.g. masters,
///   and credits/attribution attached by the credits extension)
/// - Deterministic addresses via derived object pattern
///
/// Attribution (credits, primary/featured artists) is intentionally NOT part of
/// core: it is display-oriented, varies across platforms, and is never read by
/// the economics. It lives in a first-party credits extension attached via
/// `uid_mut`, so core takes no dependency on an identity package and core
/// publish enforces no attribution.
///
/// A recording carries no name of its own. Its display title is its
/// composition's title, read by reference — composition titles are immutable,
/// so an embedded copy would carry no information. Anything that names this
/// particular take — "(Live)", "Radio Edit", a translated title — has more
/// than one correct rendering, which makes it presentation, and presentation
/// lives in the metadata extension, never in the frozen core. Core stores what
/// a recording *is*; extensions describe it.
///
/// ### Lifecycle and trust model
///
/// A recording is `key`-only with no `drop`: a fresh `Initialized` object
/// cannot be transferred, wrapped, publicly shared, or discarded, and its only
/// by-value consumer is `publish`. Create-and-publish is therefore atomic by
/// construction — an `Initialized` recording cannot outlive its creating
/// transaction, and every recording that exists on-chain is `Published` and
/// shared. There is deliberately no keep function; staged building must fit
/// one transaction.
///
/// `uid_mut` works in any lifecycle state and is permanent root over ALL
/// dynamic fields on the object — including fields attached by other
/// extensions. "Immutable after publish" covers the embedded fields only;
/// extension-layer data stays admin-mutable in perpetuity. This is the
/// designed extension surface, and it is the one trust assumption that never
/// expires: integrators should model the cap holder as able to mutate or
/// delete any extension data, forever.
///
/// The recording carries its parent composition's identity as the
/// `CompositionShare` phantom type parameter — the composition's share type is
/// its durable identity (a share currency is published independently of miso
/// and survives a fresh republish, whereas an object ID does not). This makes
/// the recording↔composition lineage compile-time enforced wherever the two
/// meet, and it is the sole link: the composition's object id is not stored on
/// the recording. Off-chain consumers that need the composition object resolve
/// its share type to an id via `composition::CompositionPublishedEvent`, which
/// binds the two.
///
/// A recording is its own freshly-created object (`object::new`), not a derived
/// child of its composition: `recording::new` takes a read-only `&Composition`
/// (only to read its royalty rate and id), so publishing recordings under a
/// composition neither contends on the composition's shared-object version nor
/// collides on a per-composition index.
module miso::recording;

use miso::composition::Composition;
use miso_share::share;
use sui::balance::Balance;
use sui::clock::Clock;
use sui::coin::TreasuryCap;
use sui::coin_registry::Currency;
use sui::derived_object::claim;
use sui::event::emit;

// === Structs ===

/// An audio recording of a composition. The `RecordingShare` phantom links to
/// this recording's own share token; the `CompositionShare` phantom is the
/// durable identity of the parent composition (its share type).
public struct Recording<phantom RecordingShare, phantom CompositionShare> has key {
    /// Unique identifier for this recording.
    id: UID,
    /// Current lifecycle state.
    state: RecordingState,
}

/// Capability that authorizes modifications to a specific recording.
/// Initialized when a recording is registered and transferred to the owner.
/// Address is derived from the recording for client-side discoverability.
///
/// Parameterized only by `RecordingShare` (not `CompositionShare`): the share
/// type already uniquely identifies the recording, and the cap authorizes
/// recording-scoped operations that have no bearing on the parent composition.
/// Keeping it single-param stops the composition identity from contaminating
/// every place a cap is held or passed.
public struct RecordingAdminCap<phantom RecordingShare> has key, store {
    /// Unique identifier for this capability.
    id: UID,
}

// === Derivation Keys ===

/// Key for deriving the admin capability's deterministic address from the recording.
public struct RecordingAdminCapKey() has copy, drop, store;

// === Enums ===

/// Lifecycle state of a recording.
public enum RecordingState has copy, drop, store {
    /// Recording is being set up and can be modified.
    Initialized,
    /// Recording is published and immutable. Includes publication timestamp.
    Published(
        /// Timestamp (ms) when published.
        u64,
    ),
}

// === Events ===

/// Emitted once when a recording is published. A pure pointer: it carries the
/// recording's identity, with the parent composition encoded as the
/// `CompositionShare` phantom. A recording's embedded fields are immutable after
/// publishing, so an indexer treats this as a signal to fetch the full object by
/// `recording_id`; all indexed data — including the publish timestamp — lives in
/// the object itself. Dynamic fields (e.g. masters attached by ingesters,
/// credits attached by the credits extension) may still change afterward.
public struct RecordingPublishedEvent<phantom RecordingShare, phantom CompositionShare> has copy, drop {
    recording_id: ID,
}

/// Emitted when a recording grants the composition its royalty-rate worth of
/// recording shares at creation. The composition's cut is settled as cap-table
/// ownership — `send_funds`ed to the composition's address — so its claim on
/// recording revenue is enforced by share ownership, not by any revenue
/// distributor choosing to honor a rate. The rate is not stored on the
/// recording: this event (in the creation transaction's effects) is its
/// canonical record. What the composition owner then does with the shares
/// (hold, stake, sell) is outside the protocol's scope. Both parties are
/// identified by the event's phantom type parameters — `RecordingShare` for the
/// granting recording, `CompositionShare` for the receiving composition — so the
/// payload carries no object ids.
public struct CompositionSharesGrantedEvent<phantom RecordingShare, phantom CompositionShare> has copy, drop {
    /// Recording-share base units granted to the composition.
    value: u64,
    /// The composition royalty rate applied at creation, in basis points.
    rate_bps: u16,
}

// === Errors ===

// State errors (10-19)
/// Operation requires Initialized state but recording is in a different state.
const ENotInitializedState: u64 = 10;

// Validation errors (20-29)
/// The composition's royalty rate exceeds the maximum the caller will accept.
/// A slippage guard against a rate change ordered ahead of `new` (see `new`).
const ERoyaltyRateAboveMax: u64 = 20;

// === Public Functions ===

// === Lifecycle ===

/// Creates a new recording for a composition.
///
/// Initializes share tokens (10M supply, 6 decimals), then splits the
/// composition's royalty-rate worth of those shares off the freshly minted
/// supply and `send_funds`es them to the composition's address. This settles
/// the composition's cut as cap-table ownership: the composition literally
/// owns its share of the recording, so its claim on recording revenue is
/// enforced by share ownership rather than by any revenue distributor choosing
/// to honor a rate. What the composition owner then does with the shares
/// (hold, stake, sell) is outside the protocol's scope.
///
/// `max_royalty_rate_bps` is a slippage guard: `new` reads the composition's
/// royalty rate live off a shared object, so a composition owner could land a
/// rate increase in a transaction ordered just before this one and capture more
/// of the recording's shares than the recorder saw. The call aborts if the
/// composition's current rate exceeds `max_royalty_rate_bps`, so the recorder
/// pins the most they will grant (pass the rate they observed, or `2000` to
/// accept up to the protocol maximum).
///
/// The composition need not be `Published`: within the composition's own
/// creating transaction its creator can already mint recordings against it.
/// Third parties only ever see `Published`, shared compositions (an
/// `Initialized` one cannot escape its creating transaction), so indexers may
/// observe a recording created "against an unpublished composition" only as
/// an intra-transaction ordering, never across transactions.
///
/// Returns:
/// - The recording object (typed to its parent composition's `CompositionShare`)
/// - Admin capability for the owner
/// - The creator's remaining share balance (full supply minus the
///   composition's cut)
public fun new<RecordingShare, CompositionShare>(
    composition: &Composition<CompositionShare>,
    share_currency: &mut Currency<RecordingShare>,
    share_treasury_cap: TreasuryCap<RecordingShare>,
    max_royalty_rate_bps: u16,
    ctx: &mut TxContext,
): (
    Recording<RecordingShare, CompositionShare>,
    RecordingAdminCap<RecordingShare>,
    Balance<RecordingShare>,
) {
    let composition_id = composition.id();
    let composition_royalty_rate = composition.royalty_rate();
    // Slippage guard: reject if the composition's live rate is above what the
    // caller agreed to, defeating a rate bump ordered ahead of this call.
    assert!(composition_royalty_rate.value() <= max_royalty_rate_bps, ERoyaltyRateAboveMax);

    // A recording is its own freshly-created object, not a derived child of its
    // composition. The composition is read-only (`&Composition`) — taken only to
    // snapshot its royalty rate and address — so concurrent recordings under the
    // same composition neither contend on its shared-object version nor collide
    // on an index. The composition↔recording link rides solely on the
    // `CompositionShare` phantom (durable identity).
    let mut recording = Recording<RecordingShare, CompositionShare> {
        id: object::new(ctx),
        state: RecordingState::Initialized,
    };

    let recording_admin_cap = RecordingAdminCap<RecordingShare> {
        id: claim(&mut recording.id, RecordingAdminCapKey()),
    };

    let mut recording_shares = share::initialize<RecordingShare>(
        share_currency,
        share_treasury_cap,
    );

    // Settle the composition's royalty rate as ownership rather than as a
    // distribution-time routing parameter: split the rate's worth of recording
    // shares off the freshly minted supply and send it to the composition's
    // address. The composition now owns its cut of the recording outright; the
    // remainder returns to the creator. The split is internal and the
    // composition's portion is never returned to the caller, so the creator
    // cannot retain it.
    //
    // A 0% rate (e.g. a generative recording with no authored composition) yields
    // no cut: skip the split/send so we don't open a zero-value share accumulator
    // for the composition. The grant event is still emitted as the canonical
    // record that the applied rate was zero.
    let composition_cut = composition_royalty_rate.apply(recording_shares.value());
    if (composition_cut > 0) {
        let composition_shares = recording_shares.split(composition_cut);
        composition_shares.send_funds(composition_id.to_address());
    };

    emit(CompositionSharesGrantedEvent<RecordingShare, CompositionShare> {
        value: composition_cut,
        rate_bps: composition_royalty_rate.value(),
    });

    (recording, recording_admin_cap, recording_shares)
}

/// Publishes the recording, making its embedded fields immutable.
/// Required State: Initialized
///
/// Note: core enforces no attribution requirement — credits live in the credits
/// extension and may be attached before or after publish via `uid_mut`.
public fun publish<RecordingShare, CompositionShare>(
    mut self: Recording<RecordingShare, CompositionShare>,
    _: &RecordingAdminCap<RecordingShare>,
    clock: &Clock,
) {
    match (self.state) {
        RecordingState::Initialized => {
            // Set the recording's publish timestamp.
            let published_at_ms = clock.timestamp_ms();
            self.state = RecordingState::Published(published_at_ms);

            emit(RecordingPublishedEvent<RecordingShare, CompositionShare> {
                recording_id: self.id(),
            });

            transfer::share_object(self);
        },
        _ => abort ENotInitializedState,
    };
}

// === Public View Functions ===

/// Returns the recording's object ID.
public fun id<RecordingShare, CompositionShare>(
    self: &Recording<RecordingShare, CompositionShare>,
): ID {
    self.id.to_inner()
}

/// Returns the current lifecycle state.
public fun state<RecordingShare, CompositionShare>(
    self: &Recording<RecordingShare, CompositionShare>,
): RecordingState {
    self.state
}

/// Returns true if the recording is in the Initialized state.
public fun is_initialized_state<RecordingShare, CompositionShare>(
    self: &Recording<RecordingShare, CompositionShare>,
): bool {
    match (self.state) { RecordingState::Initialized => true, _ => false }
}

/// Returns true if the recording is in the Published state.
public fun is_published_state<RecordingShare, CompositionShare>(
    self: &Recording<RecordingShare, CompositionShare>,
): bool {
    match (self.state) { RecordingState::Published(_) => true, _ => false }
}

// === UID Functions ===

/// Returns a reference to the recording's UID for reading dynamic fields.
public fun uid<RecordingShare, CompositionShare>(
    self: &Recording<RecordingShare, CompositionShare>,
): &UID {
    &self.id
}

/// Returns a mutable reference to the recording's UID.
/// Requires the admin capability. Works in any lifecycle state — dynamic
/// fields are the extension surface (e.g. masters, credits) and stay
/// admin-mutable after publish; only the embedded fields are frozen. The
/// reference is root over every dynamic field on the object, including
/// fields attached by other extensions.
public fun uid_mut<RecordingShare, CompositionShare>(
    self: &mut Recording<RecordingShare, CompositionShare>,
    _: &RecordingAdminCap<RecordingShare>,
): &mut UID {
    &mut self.id
}

// === Test Only ===

#[test_only]
public fun new_for_testing<RecordingShare, CompositionShare>(
    ctx: &mut TxContext,
): (Recording<RecordingShare, CompositionShare>, RecordingAdminCap<RecordingShare>) {
    let mut recording = Recording<RecordingShare, CompositionShare> {
        id: object::new(ctx),
        state: RecordingState::Initialized,
    };

    let recording_admin_cap = RecordingAdminCap<RecordingShare> {
        id: claim(&mut recording.id, RecordingAdminCapKey()),
    };

    (recording, recording_admin_cap)
}

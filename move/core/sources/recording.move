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
/// The recording carries its parent composition's identity as the
/// `CompositionShare` phantom type parameter — the composition's share type is
/// its durable identity (a share currency is published independently of miso
/// and survives a fresh republish, whereas an object ID does not). This makes
/// the recording↔composition lineage compile-time enforced wherever the two
/// meet. The parent composition's object id is also stored as a plain field for
/// off-chain convenience (indexing the lineage by id), but it is not load-bearing
/// for the protocol — the `CompositionShare` phantom is the durable link.
///
/// A recording is its own freshly-created object (`object::new`), not a derived
/// child of its composition: `recording::new` takes a read-only `&Composition`
/// (only to read its royalty rate and id), so publishing recordings under a
/// composition neither contends on the composition's shared-object version nor
/// collides on a per-composition index.
module miso::recording;

use miso::composition::Composition;
use share::share;
use std::string::String;
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
    /// Object id of the parent composition. Off-chain convenience for indexing
    /// the recording↔composition lineage by id; the durable, protocol-enforced
    /// link is the `CompositionShare` phantom.
    composition_id: ID,
    /// Current lifecycle state.
    state: RecordingState,
    /// Primary title of the recording.
    title: String,
    /// Version suffix (e.g., "Radio Edit", "Extended Mix").
    title_version: Option<String>,
    /// Subtitle of the recording.
    subtitle: Option<String>,
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
/// (hold, stake, sell) is outside the protocol's scope. The composition's
/// object id is emitted here — where the `Composition` is still in hand — for
/// off-chain convenience; on-chain the durable identity is the `CompositionShare`
/// phantom.
public struct CompositionSharesGrantedEvent<phantom RecordingShare, phantom CompositionShare> has copy, drop {
    recording_id: ID,
    composition_id: ID,
    /// Recording-share base units granted to the composition.
    value: u64,
    /// The composition royalty rate applied at creation, in basis points.
    rate_bps: u16,
}

// === Constants ===

/// Maximum length of a title version in bytes.
const MAX_TITLE_VERSION_LENGTH: u64 = 100;
/// Maximum length of a subtitle in bytes.
const MAX_SUBTITLE_LENGTH: u64 = 300;

// === Errors ===

// State errors (10-19)
/// Operation requires Initialized state but recording is in a different state.
const ENotInitializedState: u64 = 10;

// Constraint errors (30-39)
/// Title version exceeds maximum length.
const EMaxTitleVersionLengthExceeded: u64 = 36;
/// Subtitle exceeds maximum length.
const EMaxSubtitleLengthExceeded: u64 = 37;
/// String must not be empty.
const EEmptyString: u64 = 38;

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
/// Returns:
/// - The recording object (typed to its parent composition's `CompositionShare`)
/// - Admin capability for the owner
/// - The creator's remaining share balance (full supply minus the
///   composition's cut)
public fun new<RecordingShare, CompositionShare>(
    composition: &Composition<CompositionShare>,
    share_currency: &mut Currency<RecordingShare>,
    share_treasury_cap: TreasuryCap<RecordingShare>,
    ctx: &mut TxContext,
): (
    Recording<RecordingShare, CompositionShare>,
    RecordingAdminCap<RecordingShare>,
    Balance<RecordingShare>,
) {
    let composition_id = composition.id();
    let composition_royalty_rate = composition.royalty_rate();

    // A recording is its own freshly-created object, not a derived child of its
    // composition. The composition is read-only (`&Composition`) — taken only to
    // snapshot its royalty rate and id — so concurrent recordings under the same
    // composition neither contend on its shared-object version nor collide on an
    // index. The composition↔recording link rides on the `CompositionShare`
    // phantom (durable identity) and the stored `composition_id` (off-chain index).
    let mut recording = Recording<RecordingShare, CompositionShare> {
        id: object::new(ctx),
        composition_id,
        state: RecordingState::Initialized,
        title: *composition.title(),
        title_version: option::none(),
        subtitle: option::none(),
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
        recording_id: recording.id(),
        composition_id,
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

// === Title ===

/// Sets the title version (e.g., "Radio Edit", "Extended Mix").
/// Required State: Initialized
public fun set_title_version<RecordingShare, CompositionShare>(
    self: &mut Recording<RecordingShare, CompositionShare>,
    _: &RecordingAdminCap<RecordingShare>,
    title_version: String,
) {
    match (self.state) {
        RecordingState::Initialized => {
            assert!(!title_version.is_empty(), EEmptyString);
            assert!(
                title_version.length() <= MAX_TITLE_VERSION_LENGTH,
                EMaxTitleVersionLengthExceeded,
            );
            self.title_version.swap_or_fill(title_version);
        },
        _ => abort ENotInitializedState,
    }
}

/// Sets the subtitle of the recording.
/// Required State: Initialized
public fun set_subtitle<RecordingShare, CompositionShare>(
    self: &mut Recording<RecordingShare, CompositionShare>,
    _: &RecordingAdminCap<RecordingShare>,
    subtitle: String,
) {
    match (self.state) {
        RecordingState::Initialized => {
            assert!(!subtitle.is_empty(), EEmptyString);
            assert!(subtitle.length() <= MAX_SUBTITLE_LENGTH, EMaxSubtitleLengthExceeded);
            self.subtitle.swap_or_fill(subtitle);
        },
        _ => abort ENotInitializedState,
    }
}

// === Public View Functions ===

/// Returns the recording's object ID.
public fun id<RecordingShare, CompositionShare>(
    self: &Recording<RecordingShare, CompositionShare>,
): ID {
    self.id.to_inner()
}

/// Returns the object id of the parent composition. Off-chain convenience for
/// indexing the lineage by id; the durable link is the `CompositionShare` phantom.
public fun composition_id<RecordingShare, CompositionShare>(
    self: &Recording<RecordingShare, CompositionShare>,
): ID {
    self.composition_id
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

/// Returns the primary title.
public fun title<RecordingShare, CompositionShare>(
    self: &Recording<RecordingShare, CompositionShare>,
): &String {
    &self.title
}

/// Returns the optional title version.
public fun title_version<RecordingShare, CompositionShare>(
    self: &Recording<RecordingShare, CompositionShare>,
): &Option<String> {
    &self.title_version
}

/// Returns the optional subtitle.
public fun subtitle<RecordingShare, CompositionShare>(
    self: &Recording<RecordingShare, CompositionShare>,
): &Option<String> {
    &self.subtitle
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
/// admin-mutable after publish; only the embedded fields are frozen.
public fun uid_mut<RecordingShare, CompositionShare>(
    self: &mut Recording<RecordingShare, CompositionShare>,
    _: &RecordingAdminCap<RecordingShare>,
): &mut UID {
    &mut self.id
}

// === Test Only ===

#[test_only]
public fun new_for_testing<RecordingShare, CompositionShare>(
    title: String,
    ctx: &mut TxContext,
): (Recording<RecordingShare, CompositionShare>, RecordingAdminCap<RecordingShare>) {
    let mut recording = Recording<RecordingShare, CompositionShare> {
        id: object::new(ctx),
        // No parent composition in hand here; use the fresh object id as a
        // self-referential placeholder. Tests that need a real link use the
        // production `recording::new`.
        composition_id: object::id_from_address(@0x0),
        state: RecordingState::Initialized,
        title,
        title_version: option::none(),
        subtitle: option::none(),
    };

    let recording_admin_cap = RecordingAdminCap<RecordingShare> {
        id: claim(&mut recording.id, RecordingAdminCapKey()),
    };

    (recording, recording_admin_cap)
}

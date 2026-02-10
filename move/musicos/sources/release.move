// Copyright (c) Unconfirmed Labs, LLC
// SPDX-License-Identifier: Apache-2.0

/// Represents a music release (album, EP, or single) in MusicOS.
/// A release is a collection of tracks organized into discs, with cover art
/// and revenue distribution configuration.
///
/// Key features:
/// - Support for albums, EPs, and singles
/// - Multi-disc releases with track sequencing
/// - Configurable per-track revenue splits
/// - Revenue distribution to composition and recording royalty pools
/// - State machine: Initialized -> Published
module musicos::release;

use interest_bps::bps;
use musicos::cover_art::CoverArt;
use musicos::credit::Credit;
use musicos::disc::Disc;
use musicos::party::Party;
use musicos::release_party_role::ReleasePartyRole;
use musicos::track_position::TrackPosition;
use std::string::String;
use std::type_name::TypeName;
use sui::balance::Balance;
use sui::bcs::to_bytes;
use sui::clock::Clock;
use sui::derived_object::claim;
use sui::event::emit;
use sui::hash::blake2b256;
use sui::vec_map::{Self, VecMap};

public use fun release_admin_cap_release_id as ReleaseAdminCap.release_id;

//=== Structs ===

public struct RELEASE() has drop;

/// A music release containing one or more discs of tracks.
public struct Release has key {
    /// Unique identifier for this release.
    id: UID,
    /// Type of release (Album, EP, or Single).
    kind: ReleaseKind,
    /// Current lifecycle state.
    state: ReleaseState,
    /// Title of the release.
    title: String,
    /// Optional subtitle (e.g., "Deluxe Edition").
    subtitle: Option<String>,
    /// Description of the release.
    description: String,
    /// Attribution information for the release.
    credits: VecMap<ID, Credit<ReleasePartyRole>>,
    /// Collection of discs containing tracks.
    discs: vector<Disc>,
    /// Cover artwork for the release.
    cover_art: CoverArt,
}

/// Key for release UID derivation.
public struct ReleaseKey(vector<u8>) has copy, drop, store;

/// A registry that acts as a parent object for release UID derivation.
public struct ReleaseRegistry has key {
    id: UID,
}

/// Capability that authorizes modifications to a specific release.
/// Initialized when a release is registered and transferred to the owner.
public struct ReleaseAdminCap has key, store {
    /// Unique identifier for this capability.
    id: UID,
    /// ID of the release this capability controls.
    release_id: ID,
}

// Derivation key for ReleaseAdminCap.
public struct ReleaseAdminCapKey() has copy, drop, store;

/// Revenue split information for a single track.
#[allow(unused_field)]
public struct TrackSplit has copy, drop, store {
    /// Position of the track in the release.
    track_position: TrackPosition,
    /// ID of the track's composition.
    composition_id: ID,
    /// Share token type for the composition.
    composition_share_type: TypeName,
    /// Revenue amount for the composition.
    composition_split_value: u64,
    /// ID of the track's recording.
    recording_id: ID,
    /// Share token type for the recording.
    recording_share_type: TypeName,
    /// Revenue amount for the recording.
    recording_split_value: u64,
}

//=== Enums ===

/// The type of music release.
public enum ReleaseKind has copy, drop, store {
    /// Full-length album (typically 7+ tracks).
    Album,
    /// Extended play (typically 3-6 tracks).
    EP,
    /// Single release (typically 1-2 tracks).
    Single,
}

/// Lifecycle state of a release.
public enum ReleaseState has copy, drop, store {
    /// Release is initialized but not yet created.
    Initialized(
        /// Indicates if the release has a primary credit.
        bool,
    ),
    /// Release is published and immutable. Includes publication timestamp.
    Published(
        /// Timestamp (ms) when published.
        u64,
    ),
}

//=== Events ===

/// Emitted when a release is published.
public struct ReleasePublishedEvent has copy, drop {
    /// ID of the published release.
    release_id: ID,
    /// Timestamp (ms) when published.
    timestamp_ms: u64,
    /// Address of the sender.
    sender: address,
}

/// Emitted when revenue is distributed for a track.
public struct ReleaseRevenueDistributedEvent<phantom C> has copy, drop {
    /// ID of the release.
    release_id: ID,
    /// ID of the composition receiving revenue.
    composition_id: ID,
    /// Amount distributed to the composition.
    composition_split_value: u64,
    /// ID of the recording receiving revenue.
    recording_id: ID,
    /// Amount distributed to the recording.
    recording_split_value: u64,
}

/// Emitted when a track payment is completed.
#[allow(unused_field)]
public struct ReleaseTrackPaidEvent<phantom C, phantom CS, phantom RecordingShare> has copy, drop {
    /// ID of the release.
    release_id: ID,
    /// Total value distributed.
    distribution_value: u64,
}

//=== Constants ===

const CREDIT_ROLE_COUNT: u64 = 1;
const MAX_DESCRIPTION_LENGTH: u64 = 500;
const MAX_DISCS: u64 = 20;
const MAX_TRACKS: u64 = 255;

//=== Errors ===

// Authorization errors (0-9)
/// The provided admin capability does not match this release.
const EUnauthorized: u64 = 0;

// State errors (10-19)
/// Operation requires Initialized state.
const ENotInitializedState: u64 = 10;
/// Operation requires Published state.
const ENotPublishedState: u64 = 11;

// Validation errors (20-29)
/// Track splits don't sum to 100% (10,000 BPS).
const EInvalidTrackSplitsSum: u64 = 20;

// Constraint errors (30-39)
/// Too many discs in release.
const EMaxDiscsExceeded: u64 = 30;
/// Too many tracks in release.
const EMaxTracksExceeded: u64 = 31;
/// Too long description in release.
const EMaxDescriptionLengthExceeded: u64 = 32;

// Reference errors (50-59)
/// Revenue pool has no funds to distribute.
const ENoRevenueToDistribute: u64 = 50;
/// Release must contain at least one disc.
const ENoDiscs: u64 = 51;
/// Release must contain at least one credit.
const ENoPrimaryCredit: u64 = 52;
/// Invalid number of roles in credit.
const EInvalidCreditRoleCount: u64 = 53;

//=== Init Function ===

fun init(_otw: RELEASE, ctx: &mut TxContext) {
    let registry = ReleaseRegistry {
        id: object::new(ctx),
    };

    transfer::share_object(registry);
}

//=== Public Functions ===

/// Creates a new release with the given configuration.
/// Returns the release and admin capability.
public fun new(
    kind: ReleaseKind,
    title: String,
    description: String,
    cover_art: CoverArt,
    discs: vector<Disc>,
    registry: &mut ReleaseRegistry,
    ctx: &TxContext,
): (Release, ReleaseAdminCap) {
    assert!(description.length() <= MAX_DESCRIPTION_LENGTH, EMaxDescriptionLengthExceeded);
    // Assert that the release has at least one disc.
    assert!(!discs.is_empty(), ENoDiscs);
    // Assert that the release doesn't have too many discs.
    assert!(discs.length() <= MAX_DISCS, EMaxDiscsExceeded);

    // Extract digest inputs and validate splits
    let (recording_ids, track_split_values, split_sum) = extract_digest_inputs(&discs);

    // Assert total tracks don't exceed maximum
    assert!(recording_ids.length() <= MAX_TRACKS, EMaxTracksExceeded);

    // Assert that the track splits sum to 100% (10,000 BPS).
    assert!(split_sum == bps::max_value!(), EInvalidTrackSplitsSum);

    // Calculate the release digest and claim the release UID.
    let release_digest = calculate_release_digest(recording_ids, track_split_values, ctx);
    let release_uid = claim(&mut registry.id, ReleaseKey(release_digest));

    let mut release = Release {
        id: release_uid,
        kind,
        state: ReleaseState::Initialized(false),
        title,
        subtitle: option::none(),
        description,
        credits: vec_map::empty(),
        discs,
        cover_art,
    };

    let release_admin_cap = ReleaseAdminCap {
        id: claim(&mut release.id, ReleaseAdminCapKey()),
        release_id: release.id(),
    };

    (release, release_admin_cap)
}

public fun add_credit(
    self: &mut Release,
    cap: &ReleaseAdminCap,
    party: &Party,
    credit: Credit<ReleasePartyRole>,
) {
    self.authorize(cap);

    match (&mut self.state) {
        ReleaseState::Initialized(has_primary_credit) => {
            // Assert the credit has a single role (releases only support "Primary" or "Featured").
            assert!(credit.roles().length() == CREDIT_ROLE_COUNT, EInvalidCreditRoleCount);

            // Loop through the credit roles and check if the credit has a primary role.
            // If yes, set the has_primary_credit flag to true.
            credit.roles().do_ref!(|role| {
                if (role.is_primary_role()) {
                    *has_primary_credit = true;
                }
            });

            // Insert the credit into the release credits map.
            self.credits.insert(party.id(), credit);
        },
        _ => abort ENotInitializedState,
    }
}

/// Publishes the release, making it immutable.
/// Track splits must be set and sum to 100% before publishing.
/// Required State: Initialized
public fun publish(mut self: Release, cap: &ReleaseAdminCap, clock: &Clock, ctx: &TxContext) {
    self.authorize(cap);

    match (self.state) {
        ReleaseState::Initialized(has_primary_credit) => {
            // Assert that the release has a primary credit.
            assert!(has_primary_credit, ENoPrimaryCredit);
            // Assert that the tracks are assigned to the release.
            self.assert_track_assignments();

            let timestamp_ms = clock.timestamp_ms();

            // Update the release state to published.
            self.state = ReleaseState::Published(timestamp_ms);

            emit(ReleasePublishedEvent {
                release_id: self.id(),
                timestamp_ms,
                sender: ctx.sender(),
            });

            transfer::share_object(self);
        },
        _ => abort ENotInitializedState,
    }
}

/// Distributes revenue to the release's composition and recording.
/// Splits revenue according to track splits.
/// Each track's revenue is further split between its composition and recording based on their split ratio.
/// Required State: Published
public fun distribute_revenue<C>(self: &mut Release, mut revenue: Balance<C>) {
    match (self.state) {
        ReleaseState::Published(_) => {
            let release_id = self.id();

            //let withdrawal = withdraw_funds_from_object<C>(&mut self.id, value);
            //let mut revenue = redeem_funds(withdrawal);

            assert!(revenue.value() > 0, ENoRevenueToDistribute);

            // Store the distribution's principal value.
            let distribution_value = revenue.value();

            // Iterate through all discs and tracks
            self.discs.do_ref!(|disc| {
                disc.tracks().do_ref!(|track| {
                    let track_split_bps = track.split_bps();

                    if (track_split_bps.value() > 0) {
                        let rec_split_value = track_split_bps.calc(distribution_value);
                        let mut rec_split_balance = revenue.split(rec_split_value);

                        // Calculate the composition's revenue share
                        let comp_split_value = track.composition_split_bps().calc(rec_split_value);
                        let comp_split_balance = rec_split_balance.split(comp_split_value);

                        let composition_id = track.composition_id();
                        let recording_id = track.recording_id();

                        emit(ReleaseRevenueDistributedEvent<C> {
                            release_id,
                            composition_id,
                            composition_split_value: comp_split_balance.value(),
                            recording_id,
                            recording_split_value: rec_split_balance.value(),
                        });

                        rec_split_balance.send_funds(recording_id.to_address());
                        comp_split_balance.send_funds(composition_id.to_address());
                    };
                });
            });

            // Transfer dust back to the release.
            revenue.send_funds(release_id.to_address());
        },
        _ => abort ENotPublishedState,
    }
}

/// Verifies that the admin capability matches this release.
public fun authorize(self: &Release, cap: &ReleaseAdminCap) {
    assert!(self.id() == cap.release_id, EUnauthorized);
}

/// Creates an Album release kind.
public fun new_album_kind(): ReleaseKind {
    ReleaseKind::Album
}

/// Creates an EP release kind.
public fun new_ep_kind(): ReleaseKind {
    ReleaseKind::EP
}

/// Creates a Single release kind.
public fun new_single_kind(): ReleaseKind {
    ReleaseKind::Single
}

//=== Public View Functions ===

/// Returns the release's object ID.
public fun id(self: &Release): ID {
    self.id.to_inner()
}

/// Returns the release kind (Album, EP, or Single).
public fun kind(self: &Release): ReleaseKind {
    self.kind
}

/// Returns the release state.
public fun state(self: &Release): ReleaseState {
    self.state
}

/// Returns the release title.
public fun title(self: &Release): &String {
    &self.title
}

/// Returns the optional subtitle.
public fun subtitle(self: &Release): &Option<String> {
    &self.subtitle
}

/// Returns the release description.
public fun description(self: &Release): &String {
    &self.description
}

/// Returns a reference to the release credits.
public fun credits(self: &Release): &VecMap<ID, Credit<ReleasePartyRole>> {
    &self.credits
}

/// Returns a reference to all discs.
public fun discs(self: &Release): &vector<Disc> {
    &self.discs
}

/// Returns a reference to the cover art.
public fun cover_art(self: &Release): &CoverArt {
    &self.cover_art
}

/// Returns the total number of tracks across all discs.
public fun total_tracks(self: &Release): u64 {
    let mut count = 0;
    self.discs.do_ref!(|disc| {
        count = count + disc.tracks().length();
    });
    count
}

/// Returns the total duration of all tracks in milliseconds.
public fun duration_ms(self: &Release): u64 {
    let mut duration = 0;
    self.discs.do_ref!(|disc| {
        duration = duration + disc.duration_ms();
    });
    duration
}

/// Returns the release ID associated with the admin capability.
public fun release_admin_cap_release_id(cap: &ReleaseAdminCap): ID {
    cap.release_id
}

//=== UID Functions ===

/// Returns a reference to the release's UID for reading dynamic fields.
public fun uid(self: &Release): &UID {
    &self.id
}

/// Returns a mutable reference to the release's UID.
/// Requires the admin capability.
public fun uid_mut(self: &mut Release, cap: &ReleaseAdminCap): &mut UID {
    self.authorize(cap);
    &mut self.id
}

//=== Private Functions ===

/// Extracts the recording IDs, split values, and split sum from discs.
/// Used for release digest calculation and split validation.
fun extract_digest_inputs(discs: &vector<Disc>): (vector<ID>, vector<u64>, u64) {
    let mut recording_ids: vector<ID> = vector[];
    let mut track_split_values: vector<u64> = vector[];
    let mut split_sum: u64 = 0;

    discs.do_ref!(|disc| {
        disc.tracks().do_ref!(|track| {
            recording_ids.push_back(track.recording_id());
            let split_value = track.split_bps().value();
            track_split_values.push_back(split_value);
            split_sum = split_sum + split_value;
        });
    });

    (recording_ids, track_split_values, split_sum)
}

fun calculate_release_digest(
    recording_ids: vector<ID>,
    track_split_values: vector<u64>,
    ctx: &TxContext,
): vector<u8> {
    let mut hash_input = vector<u8>[];
    hash_input.append(to_bytes(&recording_ids));
    hash_input.append(to_bytes(&track_split_values));
    hash_input.append(to_bytes(&ctx.epoch()));

    blake2b256(&hash_input)
}

fun assert_track_assignments(self: &mut Release) {
    self.discs.do_mut!(|disc| {
        disc.tracks_mut().do_mut!(|track| { track.assign(&self.id); });
    });
}

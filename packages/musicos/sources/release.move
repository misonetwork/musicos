module musicos::release;

use interest_bps::bps::{Self, BPS};
use musicos::disc::Disc;
use musicos::obligation::Obligation;
use musicos::release_distribution_license::{
    Self,
    ReleaseDistributionLicense,
    ReleaseDistributionKind
};
use musicos::revenue_pool::{Self, RevenuePool};
use musicos::royalty_pool;
use musicos::track_identifier::{Self, TrackIdentifier};
use musicos::track_sequence::{Self, TrackSequence};
use std::string::String;
use std::type_name::{TypeName, with_defining_ids};
use sui::balance::Balance;
use sui::clock::Clock;
use sui::derived_object::claim;
use sui::dynamic_field as df;
use sui::event::emit;
use sui::random::Random;
use sui::vec_map::{Self, VecMap};

//=== Structs ===

public struct Release has key {
    id: UID,
    state: ReleaseState,
    title: String,
    subtitle: Option<String>,
    duration: u64,
    discs: vector<Disc>,
    track_sequence: TrackSequence,
    track_splits: VecMap<TrackIdentifier, BPS>,
    obligations: vector<Obligation>,
}

public struct ReleaseAdminCap has key, store {
    id: UID,
    release_id: ID,
}

public struct ReleaseAdminCapKey() has copy, drop, store;

public struct ReleaseNetSettlementInstruction<phantom Currency> {
    release_id: ID,
    balance: Balance<Currency>,
}

//=== Enums ===

public enum ReleaseState has copy, drop, store {
    Created(u64),
    Published(u64),
}

//=== Events ===

public struct ReleaseCreatedEvent has copy, drop {
    release_id: ID,
    timestamp: u64,
}

public struct ReleaseObligationPaidEvent has copy, drop {
    release_id: ID,
    value: u64,
    recipient: address,
}

public struct ReleaseObligationSettledEvent has copy, drop {
    release_id: ID,
    address: address,
}

public struct ReleasePublishedEvent has copy, drop {
    release_id: ID,
    timestamp: u64,
}

public struct ReleaseRevenueForwardedEvent has copy, drop {
    release_id: ID,
    currency_type: TypeName,
    composition_id: ID,
    composition_royalty_value: u64,
    recording_id: ID,
    recording_royalty_value: u64,
}

public struct ReleaseRevenuePoolInitializedEvent has copy, drop {
    release_id: ID,
    revenue_pool_id: ID,
    currency_type: TypeName,
}

const EInvalidTrackSplitSum: u64 = 0;
const EUnauthorized: u64 = 1;
const EMaxObligationsReached: u64 = 2;
const ENotCreatedState: u64 = 3;
const ENoObligations: u64 = 4;
const ENotPublishedState: u64 = 5;
const EInvalidReleaseId: u64 = 6;
const EMaxObligationRateExceeded: u64 = 7;

//=== Constants ===

const MAX_OBLIGATIONS: u64 = 10;

//=== Public Functions ===

public fun new(
    title: String,
    discs: vector<Disc>,
    track_splits: vector<BPS>,
    clock: &Clock,
    ctx: &mut TxContext,
): (Release, ReleaseAdminCap) {
    // Assert the sum of the track splits adds up to 100%.
    let mut track_splits_sum = 0;
    track_splits.do_ref!(|split| {
        track_splits_sum = track_splits_sum + (*split).value();
    });
    assert!(track_splits_sum == bps::max_value!(), EInvalidTrackSplitSum);

    // Build track identifiers from the discs.
    let track_identifiers = build_track_identifiers(&discs);

    let timestamp = clock.timestamp_ms();

    let mut release = Release {
        id: object::new(ctx),
        state: ReleaseState::Created(timestamp),
        title,
        subtitle: option::none(),
        duration: 0,
        discs,
        track_sequence: track_sequence::new(track_identifiers),
        track_splits: vec_map::from_keys_values(track_identifiers, track_splits),
        obligations: vector[],
    };

    let release_admin_cap = ReleaseAdminCap {
        id: claim(&mut release.id, ReleaseAdminCapKey()),
        release_id: release.id(),
    };

    emit(ReleaseCreatedEvent {
        release_id: release.id(),
        timestamp,
    });

    (release, release_admin_cap)
}

public fun publish(self: &mut Release, cap: &ReleaseAdminCap, clock: &Clock, ctx: &mut TxContext) {
    match (self.state) {
        ReleaseState::Created(_) => {
            self.state = ReleaseState::Published(clock.timestamp_ms());

            emit(ReleasePublishedEvent {
                release_id: self.id(),
                timestamp: clock.timestamp_ms(),
            });
        },
        _ => abort ENotCreatedState,
    }
}

// Initialize a revenue pool for the Release.
entry fun initialize_revenue_pool<Currency>(self: &mut Release) {
    let revenue_pool = revenue_pool::new<Currency>(&mut self.id);

    emit(ReleaseRevenuePoolInitializedEvent {
        release_id: self.id(),
        revenue_pool_id: revenue_pool.id(),
        currency_type: with_defining_ids<Currency>(),
    });

    transfer::public_share_object(revenue_pool);
}

// Forward revenue from a Release's revenue pool to the track's composition and recording royalty pools.
entry fun forward_revenue<Currency>(
    self: &Release,
    revenue_pool: &mut RevenuePool<Currency>,
    random: &Random,
    ctx: &mut TxContext,
) {
    let total_revenue = revenue_pool.balance_mut();
    let principal_value = total_revenue.value();

    let mut rg = random.new_generator(ctx);
    let mut track_identifiers = *self.track_sequence.inner();
    rg.shuffle(&mut track_identifiers);

    track_identifiers.do_ref!(|track_identifier| {
        let disc_idx = track_identifier.disc_idx();
        let track_idx = track_identifier.track_idx();
        let track = &self.discs[disc_idx as u64].tracks()[track_idx as u64];
        let track_split = *self.track_splits.get(track_identifier);

        let comp_id = track.composition_id();
        let comp_royalty_pool = royalty_pool::derive_address<Currency>(comp_id);
        let recording_id = track.recording_id();
        let recording_royalty_pool = royalty_pool::derive_address<Currency>(recording_id);

        let track_value = track_split.calc(principal_value);
        let mut track_balance = total_revenue.split(track_value);
        let composition_royalty_value = track.composition_commission_rate().calc(track_value);
        let comp_royalty_balance = track_balance.split(composition_royalty_value);

        emit(ReleaseRevenueForwardedEvent {
            release_id: self.id(),
            currency_type: with_defining_ids<Currency>(),
            composition_id: comp_id,
            composition_royalty_value: comp_royalty_balance.value(),
            recording_id: recording_id,
            recording_royalty_value: track_balance.value(),
        });

        // Send the composition's royalty balance to its royalty pool.
        comp_royalty_balance.send_funds(comp_royalty_pool);
        // Send the track's remaining balance to the recording's royalty pool.
        track_balance.send_funds(recording_royalty_pool);
    });
}

// Derive the address of the Release's RevenuePool and transfer
// funds to the RevenuePool's balance accumulator.
public fun deposit_revenue<Currency>(
    self: &Release,
    instruction: ReleaseNetSettlementInstruction<Currency>,
) {
    // Destructure the instruction.
    let ReleaseNetSettlementInstruction { release_id, balance } = instruction;
    // Authorize the Release.
    self.authorize_id(release_id);
    // Assert the RevenuePool for the provided Release exists.
    revenue_pool::assert_exists<Currency>(&self.id);
    // Transfer revenue to the Release's revenue pool.
    balance.send_funds(revenue_pool::derive_address<Currency>(release_id));
}

public fun new_distribution_license<Distributor: drop, Packager: key, Format: key, Currency>(
    self: &Release,
    cap: &ReleaseAdminCap,
    kind: ReleaseDistributionKind,
    unit_price: u64,
): ReleaseDistributionLicense<Distributor, Format, Packager, Currency> {
    match (self.state) {
        ReleaseState::Published(_) => {
            release_distribution_license::new<Distributor, Packager, Format, Currency>(
                cap.release_id,
                kind,
                unit_price,
            )
        },
        _ => abort ENotPublishedState,
    }
}

public fun add_obligation(self: &mut Release, obligation: Obligation) {
    match (self.state) {
        ReleaseState::Created(_) => {
            assert!(self.obligations.length() < MAX_OBLIGATIONS, EMaxObligationsReached);
            self.obligations.push_back(obligation);
            self.assert_obligation_rates_sum();
        },
        _ => abort ENotCreatedState,
    };
}

public fun remove_obligation(self: &mut Release, obligation_idx: u64) {
    match (self.state) {
        ReleaseState::Created(_) => {
            self.obligations.remove(obligation_idx);
        },
        _ => abort ENotCreatedState,
    };
}

public fun pay_obligations<Currency>(
    self: &mut Release,
    mut balance: Balance<Currency>,
    clock: &Clock,
): ReleaseNetSettlementInstruction<Currency> {
    // Settle obligations if they exist.
    // If there are no obligations to process, the receipt is returned immediately.
    if (!self.obligations.is_empty()) {
        let release_id = self.id();

        let principal_value = balance.value();
        let mut is_refresh_obligations = false;

        self.obligations.do_mut!(|obligation| {
            if (obligation.is_active()) {
                // Settle the obligation (returns the amount settled and whether the settlement is complete).
                let (paid_value, is_settled) = obligation.settle(
                    principal_value,
                    &mut balance,
                    clock,
                );

                emit(ReleaseObligationPaidEvent {
                    release_id,
                    value: paid_value,
                    recipient: obligation.recipient(),
                });

                // If the settlement is complete, set the flag to refresh the obligations.
                if (is_settled) {
                    emit(ReleaseObligationSettledEvent {
                        release_id,
                        address: obligation.recipient(),
                    });

                    is_refresh_obligations = true;
                };
            };
        });

        // If the obligations were refreshed, filter out the settled obligations.
        if (is_refresh_obligations) {
            self.obligations = self.obligations.filter!(|o| o.is_active());
        };
    };

    ReleaseNetSettlementInstruction {
        release_id: self.id(),
        balance,
    }
}

//=== Public View Functions ===

public fun id(self: &Release): ID {
    self.id.to_inner()
}

public fun title(self: &Release): String {
    self.title
}

public fun subtitle(self: &Release): Option<String> {
    self.subtitle
}

public fun duration(self: &Release): u64 {
    self.duration
}

public fun disc(self: &Release, disc_idx: u8): &Disc {
    &self.discs[disc_idx as u64]
}

public fun discs(self: &Release): &vector<Disc> {
    &self.discs
}

public fun is_created_state(self: &Release): bool {
    match (self.state) {
        ReleaseState::Created(_) => true,
        _ => false,
    }
}

public fun is_published_state(self: &Release): bool {
    match (self.state) {
        ReleaseState::Published(_) => true,
        _ => false,
    }
}

//=== Private Functions ===

fun authorize(self: &Release, cap: &ReleaseAdminCap) {
    assert!(cap.release_id == self.id(), EUnauthorized);
}

fun authorize_id(self: &Release, release_id: ID) {
    assert!(self.id() == release_id, EUnauthorized);
}

fun authorize_with_cap(cap: &ReleaseAdminCap, release_id: ID) {
    assert!(cap.release_id == release_id, EUnauthorized);
}

fun build_track_identifiers(discs: &vector<Disc>): vector<TrackIdentifier> {
    let mut track_identifiers: vector<TrackIdentifier> = vector[];
    discs.length().do!(|disc_idx| {
        let disc = &discs[disc_idx];
        disc.tracks().length().do!(|track_idx| {
            let track_identifier = track_identifier::new(disc_idx as u8, track_idx as u8);
            track_identifiers.push_back(track_identifier);
        });
    });
    track_identifiers
}

//=== Assert Functions ===

public fun assert_is_created_state(self: &Release) {
    assert!(self.is_created_state(), ENotCreatedState);
}

public fun assert_is_published_state(self: &Release) {
    assert!(self.is_published_state(), ENotPublishedState);
}

// Assert that the sum of the obligation rates is less than or equal to the maximum BPS value (10_000).
public fun assert_obligation_rates_sum(self: &Release) {
    let mut acc = 0;
    self.obligations.do_ref!(|o| { acc = acc + o.rate().value() });
    assert!(acc <= bps::max_value!(), EMaxObligationRateExceeded);
}

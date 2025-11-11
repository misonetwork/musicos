module musicos::release;

use interest_bps::bps::{Self, BPS};
use musicos::disc::Disc;
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

public struct Release has key, store {
    id: UID,
    title: String,
    subtitle: Option<String>,
    created_at: u64,
    duration: u64,
    discs: vector<Disc>,
    track_sequence: TrackSequence,
    track_splits: VecMap<TrackIdentifier, BPS>,
}

public struct ReleaseAdminCap has key, store {
    id: UID,
    release_id: ID,
}

public struct ReleaseAdminCapKey() has copy, drop, store;

//=== Events ===

public struct ReleaseCreatedEvent has copy, drop {
    release_id: ID,
}

public struct ReleaseRevenueForwardedEvent has copy, drop {
    release_id: ID,
    currency_type: TypeName,
    composition_id: ID,
    composition_royalty_value: u64,
    recording_id: ID,
    recording_royalty_value: u64,
}

const EInvalidTrackSplitSum: u64 = 0;
const EUnauthorized: u64 = 1;

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

    let mut release = Release {
        id: object::new(ctx),
        title,
        subtitle: option::none(),
        created_at: clock.timestamp_ms(),
        duration: 0,
        discs,
        track_sequence: track_sequence::new(track_identifiers),
        track_splits: vec_map::from_keys_values(track_identifiers, track_splits),
    };

    let release_admin_cap = ReleaseAdminCap {
        id: claim(&mut release.id, ReleaseAdminCapKey()),
        release_id: release.id(),
    };

    emit(ReleaseCreatedEvent {
        release_id: release.id(),
    });

    (release, release_admin_cap)
}

// Initialize a RevenuePool for the Release.
public fun initialize_revenue_pool<RevenueCurrency>(self: &mut Release) {
    let revenue_pool = revenue_pool::new<RevenueCurrency>(&mut self.id);
    transfer::public_share_object(revenue_pool);
}

entry fun forward_revenue<RevenueCurrency>(
    self: &Release,
    revenue_pool: &mut RevenuePool<RevenueCurrency>,
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
        let comp_royalty_pool = royalty_pool::derive_address<RevenueCurrency>(comp_id);
        let recording_id = track.recording_id();
        let recording_royalty_pool = royalty_pool::derive_address<RevenueCurrency>(recording_id);

        let track_value = track_split.calc(principal_value);
        let mut track_balance = total_revenue.split(track_value);
        let composition_royalty_value = track.composition_commission_rate().calc(track_value);
        let comp_royalty_balance = track_balance.split(composition_royalty_value);

        emit(ReleaseRevenueForwardedEvent {
            release_id: self.id(),
            currency_type: with_defining_ids<RevenueCurrency>(),
            composition_id: comp_id,
            composition_royalty_value: comp_royalty_balance.value(),
            recording_id: recording_id,
            recording_royalty_value: track_balance.value(),
        });

        transfer::public_transfer(comp_royalty_balance.into_coin(ctx), comp_royalty_pool);
        transfer::public_transfer(track_balance.into_coin(ctx), recording_royalty_pool);

        // TODO: Migrate to accumulators when possible.balance_mut
        //comp_royalty_balance.send_funds(comp_royalty_pool);
        //track_balance.send_funds(recording_royalty_pool);
    });
}

// Derive the address of the Release's RevenuePool and transfer
// funds to the RevenuePool's balance accumulator.
public fun deposit_revenue<RevenueCurrency>(
    self: &Release,
    balance: Balance<RevenueCurrency>,
    ctx: &mut TxContext,
) {
    // Assert the RevenuePool for the provided Release exists.
    revenue_pool::assert_exists<RevenueCurrency>(&self.id);
    // Transfer the funds to the RevenuePool's balance accumulator.
    // balance.send_funds(revenue_pool::derive_address<RevenueCurrency>(self.id()));
    // TODO: Migrate to accumulators when possible.
    transfer::public_transfer(
        balance.into_coin(ctx),
        revenue_pool::derive_address<RevenueCurrency>(self.id()),
    );
}

public fun new_distribution_license<Distributor, Format>(
    cap: &ReleaseAdminCap,
    kind: ReleaseDistributionKind,
): ReleaseDistributionLicense<Distributor, Format> {
    release_distribution_license::new<Distributor, Format>(cap.release_id, kind)
}

public fun add_distribution_license_unit_price_for_currency<Distributor, Format, Currency>(
    cap: &ReleaseAdminCap,
    license: &mut ReleaseDistributionLicense<Distributor, Format>,
    unit_price: u64,
) {
    authorize_with_cap(cap, license.release_id<Distributor, Format>());
    license.add_unit_price_for_currency<Distributor, Format, Currency>(unit_price);
}

//=== Public View Functions ===

public fun id(self: &Release): ID {
    self.id.to_inner()
}

public fun disc(self: &Release, disc_idx: u8): &Disc {
    &self.discs[disc_idx as u64]
}

public fun discs(self: &Release): &vector<Disc> {
    &self.discs
}

//=== Private Functions ===

fun authorize(self: &Release, cap: &ReleaseAdminCap) {
    assert!(cap.release_id == self.id(), EUnauthorized);
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

module musicos::release;

use interest_bps::bps::{Self, BPS};
use musicos::recording::{Recording, RecordingAdminCap};
use musicos::revenue_pool;
use musicos::track::Track;
use std::string::String;
use sui::balance::Balance;
use sui::clock::Clock;
use sui::derived_object::claim;
use sui::event::emit;

//=== Structs ===

public struct Release has key, store {
    id: UID,
    title: String,
    subtitle: Option<String>,
    created_at: u64,
    duration: u64,
    tracks: vector<Track>,
    composition_commission_rate: BPS,
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

//=== Public Functions ===

public fun new(
    title: String,
    tracks: vector<Track>,
    //track_splits: vector<BPS>,
    composition_commission_rate: BPS,
    clock: &Clock,
    ctx: &mut TxContext,
): (Release, ReleaseAdminCap) {
    let mut release = Release {
        id: object::new(ctx),
        title,
        subtitle: option::none(),
        created_at: clock.timestamp_ms(),
        duration: 0,
        tracks,
        composition_commission_rate,
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
public fun initialize_revenue_pool<Currency>(self: &mut Release) {
    let revenue_pool = revenue_pool::new<Currency>(&mut self.id);
    transfer::public_share_object(revenue_pool);
}

// Derive the address of the Release's RevenuePool and transfer
// funds to the RevenuePool's balance accumulator.
public fun deposit_revenue<Currency>(self: &Release, balance: Balance<Currency>) {
    // Assert the RevenuePool for the provided Release exists.
    revenue_pool::assert_exists<Currency>(&self.id);
    // Transfer the funds to the RevenuePool's balance accumulator.
    balance.send_funds(revenue_pool::derive_address<Currency>(self.id()));
}

//=== Public View Functions ===

public fun id(self: &Release): ID {
    self.id.to_inner()
}

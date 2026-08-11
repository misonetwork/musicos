// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Tests for the production `composition::new` and `recording::new`
/// constructors — the real entry points that wire `share::initialize`
/// (fixed 10M supply, consumed treasury cap) and, for recordings, the fresh
/// `object::new` id plus the read-only `&Composition` royalty snapshot.
#[test_only]
module miso::production_constructor_tests;

use miso::composition;
use miso::recording;
use miso::share::{Self as test_share, Share};
use miso::test_helpers::{Self, CompositionShare};
use std::unit_test::{assert_eq, destroy};

/// 10,000,000.000000 tokens at 6 decimals — must match share::SUPPLY.
const SHARE_SUPPLY: u64 = 10_000_000_000_000;

#[test]
fun composition_new_initializes_fixed_share_supply() {
    let ctx = &mut tx_context::dummy();
    let (mut currency, treasury_cap) = test_share::currency_for_testing(ctx);

    let (comp, cap, shares) = composition::new<Share>(
        b"Production Song".to_string(),
        1500,
        &mut currency,
        treasury_cap,
        ctx,
    );

    // The full fixed supply is returned to the creator.
    assert_eq!(shares.value(), SHARE_SUPPLY);
    assert_eq!(*comp.title(), b"Production Song".to_string());
    assert_eq!(comp.royalty_rate().value(), 1500);
    assert!(comp.is_initialized_state());
    assert!(!comp.is_published_state());

    destroy(comp);
    destroy(cap);
    destroy(shares);
    destroy(currency);
}

#[test, expected_failure(abort_code = 22, location = miso::composition)] // EAboveMaxRoyaltyRate
fun composition_new_above_cap_aborts() {
    let ctx = &mut tx_context::dummy();
    let (mut currency, treasury_cap) = test_share::currency_for_testing(ctx);

    let (comp, cap, shares) = composition::new<Share>(
        b"Greedy Song".to_string(),
        2001,
        &mut currency,
        treasury_cap,
        ctx,
    );

    destroy(comp);
    destroy(cap);
    destroy(shares);
    destroy(currency);
}

#[test]
fun recording_new_settles_composition_cut() {
    let ctx = &mut tx_context::dummy();
    let (comp, comp_cap) =
        composition::new_for_testing<CompositionShare>(b"Song".to_string(), 1500, ctx);
    let (mut currency, treasury_cap) = test_share::currency_for_testing(ctx);

    let (rec, rec_cap, shares) = recording::new<Share, CompositionShare>(
        &comp,
        &mut currency,
        treasury_cap,
        2000,
        ctx,
    );

    // The creator keeps the full supply minus the composition's royalty-rate
    // cut (15% of 10M), which `recording::new` splits off and sends to the
    // composition's address.
    assert_eq!(shares.value(), SHARE_SUPPLY - 1_500_000_000_000);
    assert!(rec.is_initialized_state());
    assert!(!rec.is_published_state());

    let mut events = sui::event::events_by_type<
        recording::CompositionSharesGrantedEvent<Share, CompositionShare>,
    >();
    assert_eq!(events.length(), 1);
    let (recording_id, composition_id, value, rate_bps, granted_by) =
        recording::composition_shares_granted_event_fields(events.pop_back());
    assert_eq!(recording_id, rec.id());
    assert_eq!(composition_id, comp.id());
    assert_eq!(value, 1_500_000_000_000);
    assert_eq!(rate_bps, 1500);
    assert_eq!(granted_by, ctx.sender());

    destroy(comp);
    destroy(comp_cap);
    destroy(rec);
    destroy(rec_cap);
    destroy(shares);
    destroy(currency);
}

#[test]
fun recording_new_zero_rate_grants_no_shares() {
    let ctx = &mut tx_context::dummy();
    let (comp, comp_cap) =
        composition::new_for_testing<CompositionShare>(b"Generative Track".to_string(), 0, ctx);
    let (mut currency, treasury_cap) = test_share::currency_for_testing(ctx);

    let (rec, rec_cap, shares) = recording::new<Share, CompositionShare>(
        &comp,
        &mut currency,
        treasury_cap,
        2000,
        ctx,
    );

    // A 0% composition royalty grants the composition no recording shares: the
    // split/send is skipped, so the creator retains the entire supply.
    assert_eq!(shares.value(), SHARE_SUPPLY);

    destroy(comp);
    destroy(comp_cap);
    destroy(rec);
    destroy(rec_cap);
    destroy(shares);
    destroy(currency);
}

#[test]
fun composition_new_at_zero_rate_succeeds() {
    let ctx = &mut tx_context::dummy();
    let (mut currency, treasury_cap) = test_share::currency_for_testing(ctx);

    // No floor: a generative composition with no authored work may carry a 0% rate.
    let (comp, cap, shares) = composition::new<Share>(
        b"Generative Work".to_string(),
        0,
        &mut currency,
        treasury_cap,
        ctx,
    );

    assert_eq!(comp.royalty_rate().value(), 0);

    destroy(comp);
    destroy(cap);
    destroy(shares);
    destroy(currency);
}

/// Two recordings under one composition are independent objects with distinct
/// ids and no ordering/derivation between them — the composition is read-only,
/// so this is exactly the concurrency-safe path (no index, no `&mut` contention).
#[test]
fun recording_new_independent_ids_succeed() {
    let ctx = &mut tx_context::dummy();
    let (comp, comp_cap) =
        composition::new_for_testing<CompositionShare>(b"Song".to_string(), 1500, ctx);

    let (mut currency0, treasury_cap0) = test_share::currency_for_testing(ctx);
    let (rec0, rec_cap0, shares0) = recording::new<Share, CompositionShare>(
        &comp,
        &mut currency0,
        treasury_cap0,
        2000,
        ctx,
    );

    let (mut currency1, treasury_cap1) = test_share::currency_for_testing(ctx);
    let (rec1, rec_cap1, shares1) = recording::new<Share, CompositionShare>(
        &comp,
        &mut currency1,
        treasury_cap1,
        2000,
        ctx,
    );

    assert!(rec0.id() != rec1.id());

    destroy(comp);
    destroy(comp_cap);
    destroy(rec0);
    destroy(rec_cap0);
    destroy(shares0);
    destroy(currency0);
    destroy(rec1);
    destroy(rec_cap1);
    destroy(shares1);
    destroy(currency1);
}

#[test, expected_failure(abort_code = 35, location = miso::composition)] // EEmptyString
fun composition_new_empty_title_aborts() {
    let ctx = &mut tx_context::dummy();
    let (mut currency, treasury_cap) = test_share::currency_for_testing(ctx);

    let (comp, cap, shares) = composition::new<Share>(
        b"".to_string(),
        1500,
        &mut currency,
        treasury_cap,
        ctx,
    );

    destroy(comp);
    destroy(cap);
    destroy(shares);
    destroy(currency);
}

#[test, expected_failure(abort_code = 33, location = miso::composition)] // EMaxTitleLengthExceeded
fun composition_new_title_too_long_aborts() {
    let ctx = &mut tx_context::dummy();
    let (mut currency, treasury_cap) = test_share::currency_for_testing(ctx);

    let (comp, cap, shares) = composition::new<Share>(
        test_helpers::long_string(301),
        1500,
        &mut currency,
        treasury_cap,
        ctx,
    );

    destroy(comp);
    destroy(cap);
    destroy(shares);
    destroy(currency);
}

/// Slippage guard: if the composition's rate exceeds the `max_royalty_rate_bps`
/// the recorder passes — the front-run case where an owner bumps the rate ahead
/// of this call — `recording::new` aborts rather than granting the larger cut.
#[test, expected_failure(abort_code = 20, location = miso::recording)] // ERoyaltyRateAboveMax
fun recording_new_aborts_when_rate_exceeds_max() {
    let ctx = &mut tx_context::dummy();
    // Composition sits at 15%; the recorder will accept at most 10%.
    let (comp, comp_cap) =
        composition::new_for_testing<CompositionShare>(b"Song".to_string(), 1500, ctx);
    let (mut currency, treasury_cap) = test_share::currency_for_testing(ctx);

    let (rec, rec_cap, shares) = recording::new<Share, CompositionShare>(
        &comp,
        &mut currency,
        treasury_cap,
        1000,
        ctx,
    );

    destroy(comp);
    destroy(comp_cap);
    destroy(rec);
    destroy(rec_cap);
    destroy(shares);
    destroy(currency);
}

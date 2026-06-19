// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Tests for the production `composition::new` and `recording::new`
/// constructors — the real entry points that wire `share::initialize`
/// (fixed 10M supply, consumed treasury cap) and, for recordings, the
/// `RecordingKey` derived-object claim on the parent composition.
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
    assert_eq!(comp.royalty_rate_last_changed_epoch(), ctx.epoch());
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
fun recording_new_snapshots_composition_and_claims_idx_zero() {
    let ctx = &mut tx_context::dummy();
    let (mut comp, comp_cap) =
        composition::new_for_testing<CompositionShare>(b"Song".to_string(), 1500, ctx);
    let (mut currency, treasury_cap) = test_share::currency_for_testing(ctx);

    let (rec, rec_cap, shares) = recording::new<Share, CompositionShare>(
        &mut comp,
        0,
        &mut currency,
        treasury_cap,
    );

    // Title is captured from the composition. The creator keeps the full
    // supply minus the composition's royalty-rate cut (15% of 10M), which
    // `recording::new` splits off and sends to the composition's address.
    assert_eq!(shares.value(), SHARE_SUPPLY - 1_500_000_000_000);
    assert_eq!(*rec.title(), b"Song".to_string());
    assert!(rec.is_initialized_state());
    assert!(!rec.is_published_state());

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
    let (mut comp, comp_cap) =
        composition::new_for_testing<CompositionShare>(b"Generative Track".to_string(), 0, ctx);
    let (mut currency, treasury_cap) = test_share::currency_for_testing(ctx);

    let (rec, rec_cap, shares) = recording::new<Share, CompositionShare>(
        &mut comp,
        0,
        &mut currency,
        treasury_cap,
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

#[test, expected_failure(abort_code = 53, location = miso::recording)] // ERecordingGap
fun recording_new_nonzero_first_idx_aborts() {
    let ctx = &mut tx_context::dummy();
    let (mut comp, _comp_cap) =
        composition::new_for_testing<CompositionShare>(b"Song".to_string(), 1500, ctx);
    let (mut currency, treasury_cap) = test_share::currency_for_testing(ctx);

    // idx 1 with no idx 0: production constructor enforces contiguity.
    let (rec, rec_cap, shares) = recording::new<Share, CompositionShare>(
        &mut comp,
        1,
        &mut currency,
        treasury_cap,
    );

    destroy(comp);
    destroy(_comp_cap);
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

/// idx 1 succeeds once idx 0 exists — the contiguity check's passing branch
/// through the production constructor.
#[test]
fun recording_new_contiguous_indices_succeed() {
    let ctx = &mut tx_context::dummy();
    let (mut comp, comp_cap) =
        composition::new_for_testing<CompositionShare>(b"Song".to_string(), 1500, ctx);

    let (mut currency0, treasury_cap0) = test_share::currency_for_testing(ctx);
    let (rec0, rec_cap0, shares0) = recording::new<Share, CompositionShare>(
        &mut comp,
        0,
        &mut currency0,
        treasury_cap0,
    );

    let (mut currency1, treasury_cap1) = test_share::currency_for_testing(ctx);
    let (rec1, rec_cap1, shares1) = recording::new<Share, CompositionShare>(
        &mut comp,
        1,
        &mut currency1,
        treasury_cap1,
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

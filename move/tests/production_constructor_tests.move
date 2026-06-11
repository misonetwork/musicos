// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// Tests for the production `composition::new` and `recording::new`
/// constructors — the real entry points that wire `share::initialize`
/// (fixed 10M supply, consumed treasury cap) and, for recordings, the
/// `RecordingKey` derived-object claim on the parent composition.
#[test_only]
module musicos::production_constructor_tests;

use musicos::composition;
use musicos::recording;
use musicos::share::{Self as test_share, Share};
use musicos::test_helpers::{Self, CompositionShare};
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
    assert!(comp.credits().is_empty());

    destroy(comp);
    destroy(cap);
    destroy(shares);
    destroy(currency);
}

#[test, expected_failure(abort_code = 22, location = musicos::composition)] // EAboveMaxRoyaltyRate
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
        test_helpers::cover_art(),
        &mut currency,
        treasury_cap,
    );

    // Snapshot semantics: title and royalty rate captured from the composition.
    assert_eq!(shares.value(), SHARE_SUPPLY);
    assert_eq!(*rec.title(), b"Song".to_string());
    assert_eq!(rec.composition_id(), comp.id());
    assert_eq!(rec.composition_royalty_rate().value(), 1500);
    assert!(rec.is_initialized_state());
    assert!(!rec.is_published_state());

    destroy(comp);
    destroy(comp_cap);
    destroy(rec);
    destroy(rec_cap);
    destroy(shares);
    destroy(currency);
}

#[test, expected_failure(abort_code = 53, location = musicos::recording)] // ERecordingGap
fun recording_new_nonzero_first_idx_aborts() {
    let ctx = &mut tx_context::dummy();
    let (mut comp, _comp_cap) =
        composition::new_for_testing<CompositionShare>(b"Song".to_string(), 1500, ctx);
    let (mut currency, treasury_cap) = test_share::currency_for_testing(ctx);

    // idx 1 with no idx 0: production constructor enforces contiguity.
    let (rec, rec_cap, shares) = recording::new<Share, CompositionShare>(
        &mut comp,
        1,
        test_helpers::cover_art(),
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

#[test, expected_failure(abort_code = 21, location = musicos::composition)] // EBelowMinRoyaltyRate
fun composition_new_below_floor_aborts() {
    let ctx = &mut tx_context::dummy();
    let (mut currency, treasury_cap) = test_share::currency_for_testing(ctx);

    let (comp, cap, shares) = composition::new<Share>(
        b"Stingy Song".to_string(),
        999,
        &mut currency,
        treasury_cap,
        ctx,
    );

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
        test_helpers::cover_art(),
        &mut currency0,
        treasury_cap0,
    );

    let (mut currency1, treasury_cap1) = test_share::currency_for_testing(ctx);
    let (rec1, rec_cap1, shares1) = recording::new<Share, CompositionShare>(
        &mut comp,
        1,
        test_helpers::cover_art(),
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

#[test, expected_failure(abort_code = 35, location = musicos::composition)] // EEmptyString
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

#[test, expected_failure(abort_code = 33, location = musicos::composition)] // EMaxTitleLengthExceeded
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

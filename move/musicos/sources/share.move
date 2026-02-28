// Copyright (c) Subsonic Labs, LLC
// SPDX-License-Identifier: Apache-2.0

/// Initializes share tokens for compositions and recordings.
/// Each composition and recording mints its own fungible share tokens
/// that represent ownership stakes for reward distribution.
///
/// ### Key Features:
///
/// - Fixed supply of 10,000,000.000000 tokens per entity
/// - 6 decimal places for precise ownership fractions
/// - Standardized metadata (symbol: "SHARE")
/// - Immutable supply after initialization
module musicos::share;

use std::string::String;
use std::type_name::with_defining_ids;
use sui::balance::Balance;
use sui::bcs;
use sui::coin::TreasuryCap;
use sui::coin_registry::{Currency, new_currency};

// === Constants ===

/// Suffix that all valid share type names must end with.
const SHARE_TYPE: vector<u8> = b"::share::Share";

// === Errors ===

/// Currency does not have 6 decimals.
const EInvalidDecimals: u64 = 20;
/// Currency symbol is not "SHARE".
const EInvalidSymbol: u64 = 21;
/// Currency already has non-zero supply.
const ENotZeroSupply: u64 = 22;
/// Currency's MetadataCap has not been deleted.
const EMetadataCapNotDeleted: u64 = 23;
/// Share type is invalid.
const EInvalidShareType: u64 = 24;
/// Currency's icon URL is invalid.
const EInvalidIconUrl: u64 = 25;

// === Package Functions ===

/// Initializes share tokens for a composition or recording.
/// Validates the currency configuration, mints the fixed supply, and makes
/// the supply immutable. Returns the full token balance.
public(package) fun initialize<Share>(
    share_currency: &mut Currency<Share>,
    mut share_treasury_cap: TreasuryCap<Share>,
): Balance<Share> {
    // Assert the share type is valid. This ensures the share type ends with "share::Share"
    assert_valid_share_type<Share>();
    // Assert the currency's MetadataCap has been deleted,
    // which prevents currency metadata from being modified after initialization.
    assert!(share_currency.is_metadata_cap_deleted(), EMetadataCapNotDeleted);
    // Assert the currency has the correct number of decimals.
    assert!(share_currency.decimals() == share_currency_decimals!(), EInvalidDecimals);
    // Assert the currency has the correct symbol.
    assert!(share_currency.symbol() == share_symbol!(), EInvalidSymbol);
    // Assert the currency has the correct icon URL.
    assert!(share_currency.icon_url() == share_icon_url!(), EInvalidIconUrl);
    // Assert the currency has no existing supply.
    assert!(share_treasury_cap.supply().value() == 0, ENotZeroSupply);

    // Mint the share balance.
    let balance = share_treasury_cap.mint_balance(share_currency_supply!());

    // Make the supply fixed.
    share_currency.make_supply_fixed(share_treasury_cap);

    balance
}

// === Package Macro Functions ===

/// Returns the number of decimals for share currencies (6).
public(package) macro fun share_currency_decimals(): u8 { 6 }

/// Returns the fixed supply for share currencies (10,000,000.000000).
public(package) macro fun share_currency_supply(): u64 { 10_000_000_000_000 }

/// Returns the standard symbol for share currencies ("SHARE").
public(package) macro fun share_symbol(): String { "SHARE" }

/// Returns the icon URL for share currencies (base64-encoded PNG).
public(package) macro fun share_icon_url(): String {
    "data:image/webp;base64,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"
}

// === Private Functions ===

/// Asserts that the share type name ends with the expected suffix.
fun assert_valid_share_type<Share>() {
    let t = with_defining_ids<Share>();
    let bytes = bcs::to_bytes(&t);
    let share_type = SHARE_TYPE;

    let bytes_len = bytes.length();
    let suffix_len = share_type.length();

    // Ensure bytes_len is at least suffix_len to avoid underflow.
    assert!(bytes_len >= suffix_len, EInvalidShareType);

    suffix_len.do!(|i| {
        assert!(bytes[bytes_len - suffix_len + i] == share_type[i], EInvalidShareType);
    });
}

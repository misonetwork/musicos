// Copyright (c) Studio Mirai, LLC
// Copyright (c) Unconfirmed Labs, LLC
// Copyright (c) Alex Clapworthy
// SPDX-License-Identifier: Apache-2.0

/// Initializes share tokens for compositions and recordings.
/// Each composition and recording mints its own fungible share tokens
/// that represent ownership stakes for reward distribution.
///
/// Key features:
/// - Fixed supply of 10,000,000.000000 tokens per entity
/// - 6 decimal places for precise ownership fractions
/// - Standardized metadata (symbol: "SHARE")
/// - Immutable supply after initialization
module musicos::share;

use std::string::String;
use std::type_name::with_defining_ids;
use sui::balance::Balance;
use sui::coin::TreasuryCap;
use sui::coin_registry::{Currency, new_currency};

//=== Constants ===

const SHARE_TYPE: vector<u8> = b"share::Share";

//=== Errors ===

/// Currency does not have 6 decimals.
const EInvalidDecimals: u64 = 20;
/// Currency symbol is not "SHARE".
const EInvalidSymbol: u64 = 21;
/// Currency already has non-zero supply.
const ENotZeroSupply: u64 = 22;
// Currency's MetadataCap has not been deleted.
const EMetadataCapNotDeleted: u64 = 23;
// Share type is invalid.
const EInvalidShareType: u64 = 24;

//=== Package Functions ===

/// TODO: Add assertions for metadata name, description, and icon URL.
/// Initializes a share currency for a composition or recording.
/// Sets metadata, mints the fixed supply, and locks the supply.
/// Returns the minted balance to be held by the creator.
public(package) fun intialize<Share>(
    share_currency: &mut Currency<Share>,
    mut share_treasury_cap: TreasuryCap<Share>,
): Balance<Share> {
    // Assert the share type is valid. This ensures the share type ends with "share::Share"
    assert_valid_share_type<Share>();
    // Assert the currency's MetadataCap has been deleted.
    assert!(share_currency.is_metadata_cap_deleted(), EMetadataCapNotDeleted);
    // Assert the currency has the correct number of decimals.
    assert!(share_currency.decimals() == share_currency_decimals!(), EInvalidDecimals);
    // Assert the currency has the correct symbol.
    assert!(share_currency.symbol() == share_symbol!(), EInvalidSymbol);
    // Assert the currency has no existing supply.
    assert!(share_treasury_cap.supply().value() == 0, ENotZeroSupply);

    // Mint the share balance.
    let balance = share_treasury_cap.mint_balance(share_currency_supply!());

    // Make the supply fixed.
    share_currency.make_supply_fixed(share_treasury_cap);

    balance
}

//=== Package Macro Functions ===

/// Returns the number of decimals for share currencies (6).
public(package) macro fun share_currency_decimals(): u8 { 6 }

/// Returns the fixed supply for share currencies (10,000,000.000000).
public(package) macro fun share_currency_supply(): u64 { 10_000_000_000_000 }

/// Returns the standard symbol for share currencies ("SHARE").
public(package) macro fun share_symbol(): String { "SHARE" }

/// Returns the icon URL for share currencies (base64-encoded PNG).
public(package) macro fun share_icon_url(): String {
    "data:image/png;base64,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"
}

fun assert_valid_share_type<Share>() {
    let t = with_defining_ids<Share>();
    let t_name_str = t.into_string().to_string();
    assert!(t_name_str.length() == 80, EInvalidShareType);
    let t_addr_str = t.address_string().to_string();
    let module_type_str = t_name_str.substring(t_addr_str.length() + 2, t_name_str.length());
    assert!(module_type_str == SHARE_TYPE.to_string(), EInvalidShareType);
}

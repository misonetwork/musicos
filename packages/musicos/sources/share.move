module musicos::share;

use musicos::constants::{share_currency_supply, share_currency_decimals};
use std::string::String;
use sui::balance::Balance;
use sui::coin::TreasuryCap;
use sui::coin_registry::{Currency, MetadataCap};

const EExceedsMaxSupply: u64 = 0;
const EInvalidDecimals: u64 = 1;

public(package) fun new<Share>(
    name: String,
    description: String,
    icon_url: String,
    currency: &mut Currency<Share>,
    metadata_cap: &MetadataCap<Share>,
    mut treasury_cap: TreasuryCap<Share>,
): Balance<Share> {
    assert!(currency.decimals() == share_currency_decimals!(), EInvalidDecimals);

    currency.set_description(metadata_cap, description);
    currency.set_icon_url(metadata_cap, icon_url);
    currency.set_name(metadata_cap, name);

    // Mint the composition share balance.
    let balance = treasury_cap.mint_balance(share_currency_supply!());
    currency.make_supply_fixed(treasury_cap);
    assert!(currency.total_supply().borrow() == share_currency_supply!(), EExceedsMaxSupply);

    balance
}

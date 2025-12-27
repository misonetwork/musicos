// Copyright (c) Sona Labs, Pte Ltd.
// SPDX-License-Identifier: Apache-2.0

module musicos::protocol;

use std::type_name::{TypeName, with_defining_ids};
use sui::vec_set::VecSet;

//=== Structs ===

public struct Protocol has key {
    id: UID,
    state: ProtocolState,
    composition_publishing_fee: u64,
    recording_publishing_fee: u64,
    contributor_verification_authority: TypeName,
    play_authorities: VecSet<TypeName>,
    // Settlement currencies that can be used for commerce transactions on MusicOS.
    settlement_currencies: VecSet<TypeName>,
    max_composition_contributors: u16,
    max_composition_artifacts: u16,
    max_composition_snapshots: u16,
    max_recording_contributors: u16,
    max_recording_artifacts: u16,
    max_recording_snapshots: u16,
    min_royalty_distribution_threshold: u64,
}

//=== Enums ===

public enum ProtocolState has copy, drop, store {
    Genesis,
    Active,
    Paused,
    Stopped,
    Deprecated,
}

//=== Errors ===

const EInvalidSettlementCurrency: u64 = 0;
const EInvalidPlayAuthority: u64 = 1;
const EInvalidArtistVerificationAuthority: u64 = 2;

//=== Public View Functions ===

public fun composition_publishing_fee(self: &Protocol): u64 {
    self.composition_publishing_fee
}

public fun recording_publishing_fee(self: &Protocol): u64 {
    self.recording_publishing_fee
}

public fun max_composition_contributors(self: &Protocol): u16 {
    self.max_composition_contributors
}

public fun min_royalty_distribution_threshold(self: &Protocol): u64 {
    self.min_royalty_distribution_threshold
}

public fun max_composition_artifacts(self: &Protocol): u16 {
    self.max_composition_artifacts
}

public fun max_composition_snapshots(self: &Protocol): u16 {
    self.max_composition_snapshots
}

public fun max_recording_contributors(self: &Protocol): u16 {
    self.max_recording_contributors
}

public fun max_recording_artifacts(self: &Protocol): u16 {
    self.max_recording_artifacts
}

public fun max_recording_snapshots(self: &Protocol): u16 {
    self.max_recording_snapshots
}

//=== Assert Functions ===

public fun assert_is_settlement_currency<Currency>(self: &Protocol) {
    assert!(
        self.settlement_currencies.contains(&with_defining_ids<Currency>()),
        EInvalidSettlementCurrency,
    )
}

public fun assert_is_play_authority<Authority>(self: &Protocol) {
    assert!(self.play_authorities.contains(&with_defining_ids<Authority>()), EInvalidPlayAuthority)
}

public fun assert_is_contributor_verification_authority<Authority>(self: &Protocol) {
    assert!(
        self.contributor_verification_authority == with_defining_ids<Authority>(),
        EInvalidArtistVerificationAuthority,
    )
}

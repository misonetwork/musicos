module musicos::artist;

use music::music::MUSIC;
use musicos::protocol::Protocol;
use musicos::treasury::Treasury;
use std::string::String;
use sui::coin::Coin;
use sui::vec_set::VecSet;

//=== Structs ===

public struct Artist has key {
    id: UID,
    name: ArtistName,
    website: Option<String>,
    contributors: VecSet<String>,
}

public struct ArtistKey(String, u16) has copy, drop, store;

public enum ArtistName has copy, drop, store {
    Unverified(String),
    VerificationRequested(String, u64),
    Verifying(String, u64),
    Verified(String),
}

public struct ArtistRegistry has key {
    id: UID,
    count: u64,
}

public struct ArtistAdminCap has key, store {
    id: UID,
    artist_id: ID,
}

const EUnauthorized: u64 = 0;
const ENotUnverifiedState: u64 = 1;
const ENotVerifyingState: u64 = 2;
const ENotVerifiedState: u64 = 3;

//=== Public Functions ===

public fun request_verification(
    self: &mut Artist,
    cap: &ArtistAdminCap,
    fee: Coin<MUSIC>,
    treasury: &mut Treasury,
) {
    self.authorize(cap);
    treasury.deposit(fee.into_balance());
}

public fun submit_verification<Authority: drop>(
    self: &mut Artist,
    _: Authority,
    protocol: &Protocol,
    ctx: &TxContext,
) {
    match (self.name) {
        ArtistName::Unverified(name) => {
            protocol.assert_is_artist_verification_authority<Authority>();
            self.name = ArtistName::Verifying(name, ctx.epoch() + 2)
        },
        _ => abort ENotUnverifiedState,
    }
}

public fun revoke_verification<Authority: drop>(
    self: &mut Artist,
    _: Authority,
    protocol: &Protocol,
) {
    match (self.name) {
        ArtistName::Verifying(name, _) => {
            protocol.assert_is_artist_verification_authority<Authority>();
            self.name = ArtistName::Unverified(name)
        },
        _ => abort ENotVerifyingState,
    }
}

public fun complete_verification(self: &mut Artist, ctx: &TxContext) {
    match (self.name) {
        ArtistName::Verifying(name, epoch) => {
            if (ctx.epoch() >= epoch) {
                self.name = ArtistName::Verified(name);
            }
        },
        _ => abort ENotVerifyingState,
    }
}

public fun id(self: &Artist): ID {
    self.id.to_inner()
}

public fun name(self: &Artist): String {
    match (self.name) {
        ArtistName::Unverified(name) => name,
        ArtistName::VerificationRequested(name, _) => name,
        ArtistName::Verifying(name, _) => name,
        ArtistName::Verified(name) => name,
    }
}

public fun assert_is_verified(self: &Artist) {
    match (&self.name) {
        ArtistName::Verified(_) => (),
        _ => abort ENotVerifiedState,
    }
}

fun authorize(self: &Artist, cap: &ArtistAdminCap) {
    assert!(cap.artist_id == self.id(), EUnauthorized);
}

// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// The marquee operations plugin for a vaulted `RecordingAdminCap`.
///
/// A recording owner who does not want to babysit their catalogue places the
/// recording's `RecordingAdminCap` inside a `miso_vault::vault::Vault` and
/// authorizes an operator (a label, a distribution agent, an autonomous bot).
/// This plugin then lets that operator drive the recording on the owner's
/// behalf, with the vault enforcing the trust boundary at two tiers:
///
/// - **Consent tier (`submit_deal`).** Submitting a deal binds the recording
///   into a release at an agreed revenue split — a high-stakes, economically
///   irreversible act. The operator may *relay* it, but only the recording
///   owner (the vault's principal) can *authorize* it: the owner signs a
///   canonical intent message off-chain with the raw Ed25519 key whose public
///   half is stored on the vault (`admin_pubkey`), and this plugin verifies that
///   signature on-chain before minting the `Deal`. The vault's nonce set makes
///   each signed intent single-use, and an explicit expiry bounds its lifetime.
///   A configurable economic floor (`min_split_bps`) is enforced on-chain so a
///   compromised or careless operator cannot relay a deal below the owner's
///   stated minimum even with a valid signature for that split.
///
/// - **Autonomous tier (royalty sweeps + `set_extension`).** Folding inbound
///   revenue into the royalty pool and writing operational metadata are
///   reversible, low-stakes, high-frequency acts. These require only a live
///   `OperatorCap` (the vault borrows the cap under operator authority) — no
///   per-call signed intent — so an agent can sweep continuously without the
///   owner in the loop.
///
/// The plugin's witness type is `Key`: a single `drop`-only witness that fixes
/// the type parameter `K` at install (the vault keys the `Config` df by its own
/// `vault::PluginKey<Key>` wrapper), gates the witness-checked cap borrow, and
/// gates nonce consumption. Installing with `Key()`, borrowing with `Key()`, and
/// consuming a nonce with `Key()` all reference the same `with_defining_ids<Key>()`
/// type tag, so the vault's installation guard, borrow gate, and replay guard are
/// all keyed to this package.
module recording_ops::recording_ops;

use miso::deal;
use miso::recording::{Recording, RecordingAdminCap};
use miso_vault::vault::{Self, Vault, VaultAdminCap, OperatorCap};
use recording_royalty_pool::recording_royalty_pool;
use royalty_pool::pool::{Self, RoyaltyPool};
use std::bcs;
use std::string::String;
use sui::clock::Clock;
use sui::coin::Coin;
use sui::dynamic_field as df;
use sui::ed25519;
use sui::event::emit;
use sui::transfer::Receiving;

// === Errors ===

/// The requested track split is below the owner-configured economic floor.
const ESplitTooLow: u64 = 0;
/// The signed intent has expired (its expiry is at or before now).
const EIntentExpired: u64 = 1;
/// The principal's Ed25519 signature over the canonical intent does not verify.
const EBadIntent: u64 = 2;

// === Constants ===

/// Domain-separation tag for the `submit_deal` signed intent, version 1. The
/// off-chain signer MUST prefix the canonical message with these exact bytes.
const SUBMIT_DEAL_INTENT_TAG: vector<u8> = b"miso:submit_deal:v1";

// === Structs ===

/// The plugin's witness type. It serves three roles:
/// - fixes the type parameter `K` at install (the vault keys the `Config` df by
///   its own `vault::PluginKey<Key>` wrapper, and tags this plugin in `plugins`),
/// - the witness `W` for the vault's witness-gated cap borrow, and
/// - the witness `W` for the vault's witness-gated nonce consumption.
///
/// A `drop`-only witness: the vault — not this module — owns the config df key,
/// so `Key` is never the df key itself. The vault's `plugins` set, borrow gate,
/// and nonce gate are all keyed to `with_defining_ids<Key>()` — i.e. to this
/// package — so no other package can borrow this vault's cap through this plugin
/// or burn its nonces. A client resolves this vault's config under
/// `recording_ops::recording_ops::Key` / `::Config`.
public struct Key() has drop;

/// Per-vault configuration for this plugin. The owner sets it at install time.
public struct Config has store, drop {
    /// Economic floor: the minimum acceptable track split, in basis points,
    /// that the operator may relay a deal for. Enforced on-chain in addition to
    /// the principal's signature, so a valid signature for a sub-floor split is
    /// still rejected.
    min_split_bps: u16,
}

// === Events ===

/// Emitted when a deal is submitted through the consent tier: the principal's
/// signed intent verified, the nonce consumed, and the `Deal` minted and routed
/// to the assembler.
public struct DealSubmitted has copy, drop {
    /// The vault whose `RecordingAdminCap` authorized the deal.
    vault_id: ID,
    /// The minted deal's object id.
    deal_id: ID,
    /// The target release the deal binds the recording into.
    release_id: ID,
    /// The agreed track split, in basis points.
    split_bps: u16,
    /// The address the minted `Deal` was routed to (the release assembler).
    assembler: address,
    /// The single-use nonce the principal's signed intent carried.
    nonce: u64,
}

// === Install ===

/// Install this plugin on a vault holding a `RecordingAdminCap<RS>`. Owner-only
/// (requires the `VaultAdminCap`). Records the economic floor the operator must
/// respect when relaying deals.
public fun install<RS>(
    v: &mut Vault<RecordingAdminCap<RS>>,
    admin: &VaultAdminCap,
    min_split_bps: u16,
) {
    vault::add_plugin(v, admin, Key(), Config { min_split_bps });
}

/// Uninstall the plugin, returning the stored `Config`. Owner-only (requires the
/// `VaultAdminCap`). A convenience wrapper: because the vault owns the config df
/// key (`vault::PluginKey<Key>`), the owner can equivalently uninstall directly
/// via `vault::remove_plugin<_, Key, Config>` without this module's help, so the
/// wrapped `RecordingAdminCap` can never be permanently trapped.
public fun uninstall<RS>(
    v: &mut Vault<RecordingAdminCap<RS>>,
    admin: &VaultAdminCap,
): Config {
    vault::remove_plugin<_, Key, Config>(v, admin)
}

// === Consent tier: submit_deal ===

/// Build the canonical `submit_deal` intent message the principal signs.
///
/// EXACT ENCODING (an off-chain signer must reproduce this bit-for-bit and sign
/// the result with the RAW Ed25519 primitive — NOT `signPersonalMessage`, which
/// wraps the payload in a BCS `PersonalMessage` envelope and would not verify
/// here):
///
/// ```text
///   msg = b"miso:submit_deal:v1"          // 19 bytes, the domain tag, no length prefix
///       ++ vault_id_bytes                  // 32 bytes, object::id(v) as raw address bytes
///       ++ release_id_bytes                // 32 bytes, the release ID as raw address bytes
///       ++ bcs::to_bytes(&split_bps)       // 2 bytes, u16 little-endian
///       ++ bcs::to_bytes(&nonce)           // 8 bytes, u64 little-endian
///       ++ bcs::to_bytes(&intent_expires_ms) // 8 bytes, u64 little-endian
/// ```
///
/// Total length is fixed at 19 + 32 + 32 + 2 + 8 + 8 = 101 bytes. The two IDs
/// are appended as their raw 32-byte address representations (NOT BCS-wrapped:
/// `id.to_bytes()` returns the bare 32 bytes). The three scalars ARE
/// BCS-encoded, which for fixed-width integers is just little-endian bytes.
///
/// Exposed `public` so tests and the off-chain integration eval share one
/// source of truth for the encoding.
public fun build_intent_msg(
    vault_id: ID,
    release_id: ID,
    split_bps: u16,
    nonce: u64,
    intent_expires_ms: u64,
): vector<u8> {
    let mut msg = SUBMIT_DEAL_INTENT_TAG;
    msg.append(vault_id.to_bytes());
    msg.append(release_id.to_bytes());
    msg.append(bcs::to_bytes(&split_bps));
    msg.append(bcs::to_bytes(&nonce));
    msg.append(bcs::to_bytes(&intent_expires_ms));
    msg
}

/// Submit a deal on the recording owner's behalf, gated by the owner's on-chain
/// verified signed intent.
///
/// The operator relays; the owner authorizes. The owner signs the canonical
/// intent (see `build_intent_msg`) off-chain with the raw Ed25519 key whose
/// public half is the vault's `admin_pubkey`; this function verifies that
/// signature before minting the `Deal`. Steps, in order:
///
/// 1. Read the installed `Config` (aborts if the plugin is not installed) and
///    enforce the economic floor: `split_bps >= min_split_bps`.
/// 2. Enforce the intent has not expired: `intent_expires_ms > now`.
/// 3. Rebuild the canonical intent message and verify the principal's signature
///    over it against the vault's `admin_pubkey`.
/// 4. Consume the nonce (witness-gated replay guard) so the signed intent is
///    single-use.
/// 5. Borrow the `RecordingAdminCap` under operator authority, mint the `Deal`,
///    return the cap.
/// 6. Route the `Deal` (key + store) to the assembler and emit `DealSubmitted`.
///
/// `entry` is intentional and matches the operator's relay call site (a PTB
/// command), even though `public` already permits PTB calls.
#[allow(lint(public_entry))]
public entry fun submit_deal<RS, CS>(
    v: &mut Vault<RecordingAdminCap<RS>>,
    rec: &Recording<RS, CS>,
    op: &OperatorCap,
    release_id: ID,
    split_bps: u16,
    assembler: address,
    intent_sig: vector<u8>,
    nonce: u64,
    intent_expires_ms: u64,
    clk: &Clock,
    ctx: &mut TxContext,
) {
    // 1. Economic floor. Read the installed config (aborts if not installed)
    //    and reject any split below the owner's stated minimum — enforced
    //    independently of the signature, so even a validly-signed sub-floor
    //    split is refused.
    let cfg = vault::config<RecordingAdminCap<RS>, Key, Config>(v);
    let min_split_bps = cfg.min_split_bps;
    assert!(split_bps >= min_split_bps, ESplitTooLow);

    // 2. Expiry. The signed intent must still be live.
    assert!(intent_expires_ms > clk.timestamp_ms(), EIntentExpired);

    // 3. Verify the principal's signature over the canonical intent. Binding the
    //    vault id, release, split, nonce, and expiry into the signed bytes means
    //    a signature for one (vault, release, split, nonce, expiry) tuple cannot
    //    be replayed against any other.
    let msg = build_intent_msg(
        object::id(v),
        release_id,
        split_bps,
        nonce,
        intent_expires_ms,
    );
    assert!(ed25519::ed25519_verify(&intent_sig, vault::admin_pubkey(v), &msg), EBadIntent);

    // 4. Replay guard: burn the nonce (witness-gated to this plugin).
    vault::consume_nonce(v, Key(), nonce);

    // 5. Borrow the cap under operator authority, mint the deal, return the cap.
    let (cap, b) = vault::borrow_cap_plugin(v, op, Key(), clk);
    let deal = deal::new(&cap, rec, release_id, split_bps, ctx);
    let deal_id = deal.id();
    vault::return_cap(v, cap, b);

    // 6. Route the deal to the assembler and announce the submission.
    transfer::public_transfer(deal, assembler);

    emit(DealSubmitted {
        vault_id: object::id(v),
        deal_id,
        release_id,
        split_bps,
        assembler,
        nonce,
    });
}

// === Autonomous tier: royalty sweeps ===

/// Initialize the recording's royalty pool for `Cur` and share it. Operator-only
/// (no signed intent): a reversible, idempotent-per-currency setup step. Borrows
/// the cap, derives the pool from the recording's UID via the royalty-pool
/// extension, shares it, and returns the cap. Aborts if a pool for this
/// `(recording, Cur)` already exists (its derived address is already claimed).
public fun init_royalty_pool<RS, CS, Cur>(
    v: &mut Vault<RecordingAdminCap<RS>>,
    rec: &mut Recording<RS, CS>,
    op: &OperatorCap,
    clk: &Clock,
) {
    let (cap, b) = vault::borrow_cap_plugin(v, op, Key(), clk);
    let pool = recording_royalty_pool::initialize_pool<RS, CS, Cur>(rec, &cap);
    pool::share(pool);
    vault::return_cap(v, cap, b);
}

/// Sweep `Coin<Cur>` royalties that were sent to the recording's address into
/// its royalty pool. Operator-only (no signed intent): folding inbound revenue
/// is reversible and low-stakes. Borrows the cap, receives the coins and
/// deposits the combined balance, returns the cap.
public fun sweep_received<RS, CS, Cur>(
    v: &mut Vault<RecordingAdminCap<RS>>,
    rec: &mut Recording<RS, CS>,
    op: &OperatorCap,
    coins: vector<Receiving<Coin<Cur>>>,
    pool: &mut RoyaltyPool<RS, Cur>,
    clk: &Clock,
) {
    let (cap, b) = vault::borrow_cap_plugin(v, op, Key(), clk);
    recording_royalty_pool::receive_and_deposit<RS, CS, Cur>(rec, &cap, coins, pool);
    vault::return_cap(v, cap, b);
}

/// Sweep `value` base units accrued in the recording's funds accumulator into
/// its royalty pool. Operator-only (no signed intent). Borrows the cap, redeems
/// and deposits, returns the cap.
public fun sweep_accrued<RS, CS, Cur>(
    v: &mut Vault<RecordingAdminCap<RS>>,
    rec: &mut Recording<RS, CS>,
    op: &OperatorCap,
    value: u64,
    pool: &mut RoyaltyPool<RS, Cur>,
    clk: &Clock,
) {
    let (cap, b) = vault::borrow_cap_plugin(v, op, Key(), clk);
    recording_royalty_pool::redeem_and_deposit<RS, CS, Cur>(rec, &cap, value, pool);
    vault::return_cap(v, cap, b);
}

// === Autonomous tier: operational metadata ===

/// Write a `String`-keyed bytes value into the recording's dynamic-field
/// namespace. Operator-only (no signed intent): operational metadata is
/// reversible and low-stakes. Borrows the cap, reaches the recording's
/// `uid_mut` through it, writes (or overwrites) the field, returns the cap.
public fun set_extension<RS, CS>(
    v: &mut Vault<RecordingAdminCap<RS>>,
    rec: &mut Recording<RS, CS>,
    op: &OperatorCap,
    key: String,
    value: vector<u8>,
    clk: &Clock,
) {
    let (cap, b) = vault::borrow_cap_plugin(v, op, Key(), clk);
    let uid = rec.uid_mut(&cap);
    if (df::exists_with_type<String, vector<u8>>(uid, key)) {
        let prev: &mut vector<u8> = df::borrow_mut(uid, key);
        *prev = value;
    } else {
        df::add(uid, key, value);
    };
    vault::return_cap(v, cap, b);
}

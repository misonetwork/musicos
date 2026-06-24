// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// A generic, standalone vault that wraps an admin capability and delegates
/// *bounded, revocable* use of it to "operator" addresses.
///
/// The vault is a shared object holding the capability inside a
/// `sui::borrow::Referent`. Operators receive a soulbound `OperatorCap` and may
/// hot-potato-borrow the capability for the duration of a single transaction;
/// the `Borrow` hot potato forces the cap to be returned before the tx ends.
///
/// Authorization is binary: an `OperatorCap` is only live while its object id is
/// present in the vault's `operators` set. Removing it (`revoke_operator`) makes
/// the operator instantly inert, even though the holder still owns the (now
/// useless) object. `OperatorCap` is key-only (no `store`), so it is soulbound
/// and the holder cannot transfer it.
///
/// Plugins are other packages that install per-vault `Config` values in dynamic
/// fields keyed by a *vault-owned* `PluginKey<K>` wrapper, parameterized by the
/// plugin's witness type `K`. Because the vault constructs the df key (the plugin
/// never names it), the owner can install and — critically — *uninstall* any
/// plugin purely by type parameter, with no cooperation from the plugin module.
/// This is what makes the `withdraw` escape hatch structurally un-loseable: even
/// a plugin that ships no `uninstall` (or whose package is gone) can be torn down
/// by the owner via `remove_plugin<Cap, K, Config>`. The `plugins` set tracks the
/// installed witness types both for discoverability and as a teardown guard:
/// `withdraw` can only run on a vault with no plugins installed, preventing
/// orphaned dynamic fields.
///
/// The cap path is split: the admin (`VaultAdminCap` holder) may borrow the cap
/// unconditionally, while an installed plugin may borrow it (witness-gated)
/// through a live, unexpired `OperatorCap`. Plugins additionally gate high-stakes
/// ops on the principal's signed intent: `verify_and_consume_intent` reconstructs
/// the Sui *personal-message* digest the principal's wallet (or agent key) signed,
/// verifies it against the `admin_pubkey` under the vault's `scheme`
/// (Ed25519 or secp256r1/P-256 — the latter covering WebCrypto and passkey
/// principals), and replay-protects the intent via the `used_nonces` set — all in
/// one call.
///
/// The owner holds a `VaultAdminCap` (a recovery key) and always retains an
/// unconditional escape hatch via `withdraw`.
module miso_vault::vault;

use std::type_name::{Self, TypeName};
use sui::borrow::{Self, Referent, Borrow};
use sui::clock::Clock;
use sui::dynamic_field as df;
use sui::ecdsa_r1;
use sui::ed25519;
use sui::event;
use sui::hash;
use sui::vec_set::{Self, VecSet};

// === Errors ===

/// The supplied `VaultAdminCap` does not control this vault.
const ENotAdmin: u64 = 0;
/// Cannot withdraw the cap while plugins are still installed.
const EPluginsInstalled: u64 = 1;
/// The `OperatorCap` was minted for a different vault.
const EWrongVault: u64 = 2;
/// The `OperatorCap` has been revoked (removed from the `operators` registry).
const ERevoked: u64 = 3;
/// The `OperatorCap` has expired.
const EExpired: u64 = 4;
/// The plugin (witness type) is not installed on this vault.
const EPluginNotInstalled: u64 = 5;
/// The supplied nonce has already been consumed (replay).
const ENonceUsed: u64 = 6;
/// The principal's signature over the personal-message intent does not verify.
const EBadIntent: u64 = 7;
/// The `scheme` passed to `wrap_with_scheme` is not a supported signature scheme,
/// or the `admin_pubkey` length does not match the scheme's expected key size.
const EBadScheme: u64 = 8;

// === Signature schemes ===
//
// The signature scheme of the principal key whose signed intents the vault
// verifies. These mirror Sui's wire flags for ergonomics, but the vault only
// needs them to dispatch verification — it never builds a Sui multisig/wire
// signature, so the only requirement is internal consistency.

/// Ed25519 personal-message intents. Pubkey is a raw 32-byte Ed25519 key;
/// verification is `ed25519_verify` over the 32-byte personal-message digest.
const SCHEME_ED25519: u8 = 0;
/// Secp256r1 (NIST P-256) personal-message intents — the scheme produced by
/// `@mysten/sui`'s `Secp256r1Keypair` and by a WebCrypto P-256 key wrapped in the
/// SDK's generic `Signer`. Pubkey is a compressed 33-byte SEC1 point; verification
/// is `secp256r1_verify(.., HASH_SHA256)` over the 32-byte personal-message digest
/// (the native re-hashes that digest with sha256 internally — see
/// `verify_and_consume_intent`).
const SCHEME_SECP256R1: u8 = 2;

/// Expected raw public-key length for `SCHEME_ED25519` (32-byte Ed25519 key).
const ED25519_PUBKEY_LEN: u64 = 32;
/// Expected raw public-key length for `SCHEME_SECP256R1` (compressed 33-byte
/// SEC1 point — the format `secp256r1_verify` expects, and exactly what
/// `Secp256r1Keypair.getPublicKey().toRawBytes()` returns).
const SECP256R1_PUBKEY_LEN: u64 = 33;

/// `hash` flag for `ecdsa_r1::secp256r1_verify` selecting SHA-256 as the internal
/// message hash. Mirrors the framework's private `SHA256` constant. Secp256r1
/// signers (incl. `Secp256r1Keypair.sign`) sign `sha256(digest)`, so the native
/// must re-apply sha256 to the digest we hand it.
const HASH_SHA256: u8 = 1;

// === Structs ===

/// A shared object wrapping a capability `Cap` and brokering bounded,
/// revocable access to it. `Cap` is a real type parameter (the cap lives
/// inside the `Referent`), hence it must be `key + store`.
public struct Vault<Cap: key + store> has key {
    id: UID,
    /// The wrapped capability, lent out via the `sui::borrow` hot-potato API.
    cap: Referent<Cap>,
    /// The principal / vault owner's public key. Plugins use this to verify the
    /// principal's signed intents for high-stakes operations. Its scheme (and so
    /// its expected length / verify algorithm) is given by `scheme`: a raw 32-byte
    /// Ed25519 key for `SCHEME_ED25519`, or a compressed 33-byte SEC1 point for
    /// `SCHEME_SECP256R1`.
    admin_pubkey: vector<u8>,
    /// The signature scheme of `admin_pubkey` — `SCHEME_ED25519` or
    /// `SCHEME_SECP256R1`. `verify_and_consume_intent` dispatches on this to the
    /// matching on-chain verifier.
    scheme: u8,
    /// Authorized `OperatorCap` object ids. Membership is the revocation
    /// registry: remove == instant revoke.
    operators: VecSet<ID>,
    /// Installed plugin witness types (`type_name` of each plugin's `K`).
    /// Teardown guard + discoverability.
    plugins: VecSet<TypeName>,
    /// Consumed signed-intent nonces. Replay protection for plugin ops.
    used_nonces: VecSet<u64>,
}

/// The recovery key for a vault. Holder may authorize/revoke operators, manage
/// plugins, and unconditionally withdraw the wrapped cap.
public struct VaultAdminCap has key, store {
    id: UID,
    vault_id: ID,
}

/// A soulbound (key-only, no `store`) authorization granting an operator address
/// the right to borrow the vault's cap until `expires_ms`, while the operator's
/// id remains in the vault's `operators` set.
public struct OperatorCap has key {
    id: UID,
    vault_id: ID,
    expires_ms: u64,
}

// === Events ===

public struct VaultCreated has copy, drop {
    vault_id: ID,
}

public struct OperatorAuthorized has copy, drop {
    vault_id: ID,
    operator_id: ID,
    operator: address,
    expires_ms: u64,
}

public struct OperatorRevoked has copy, drop {
    vault_id: ID,
    operator_id: ID,
}

// === Lifecycle ===

/// Wrap `cap` in a new shared `Vault` whose principal signs intents with
/// **Ed25519**, and return the `VaultAdminCap` for the caller to route.
/// `admin_pubkey` is the principal's raw 32-byte Ed25519 public key used by
/// plugins to verify the principal's signed intents. Emits `VaultCreated`.
///
/// This is the back-compatible default; it delegates to `wrap_with_scheme` with
/// `SCHEME_ED25519`. For a secp256r1/passkey principal, call `wrap_with_scheme`
/// with `SCHEME_SECP256R1` and a compressed 33-byte key.
public fun wrap<Cap: key + store>(
    cap: Cap,
    admin_pubkey: vector<u8>,
    ctx: &mut TxContext,
): VaultAdminCap {
    wrap_with_scheme(cap, admin_pubkey, SCHEME_ED25519, ctx)
}

/// Wrap `cap` in a new shared `Vault`, selecting the signature `scheme` of the
/// principal whose signed intents the vault will verify, and return the
/// `VaultAdminCap`. `scheme` must be `SCHEME_ED25519` (raw 32-byte key) or
/// `SCHEME_SECP256R1` (compressed 33-byte SEC1 point); the `admin_pubkey` length
/// is validated against the scheme up front, so a misconfigured key fails at
/// creation rather than silently at first intent. Emits `VaultCreated`.
public fun wrap_with_scheme<Cap: key + store>(
    cap: Cap,
    admin_pubkey: vector<u8>,
    scheme: u8,
    ctx: &mut TxContext,
): VaultAdminCap {
    assert!(is_valid_scheme_pubkey(scheme, &admin_pubkey), EBadScheme);
    let vault = Vault {
        id: object::new(ctx),
        cap: borrow::new(cap, ctx),
        admin_pubkey,
        scheme,
        operators: vec_set::empty(),
        plugins: vec_set::empty(),
        used_nonces: vec_set::empty(),
    };
    let vault_id = object::id(&vault);
    let admin = VaultAdminCap { id: object::new(ctx), vault_id };
    event::emit(VaultCreated { vault_id });
    transfer::share_object(vault);
    admin
}

/// Admin escape hatch: consume the vault and recover the wrapped cap. Requires
/// the vault to be free of plugins so no dynamic fields are orphaned.
public fun withdraw<Cap: key + store>(v: Vault<Cap>, admin: &VaultAdminCap): Cap {
    assert!(admin.vault_id == object::id(&v), ENotAdmin);
    assert!(v.plugins.is_empty(), EPluginsInstalled);
    let Vault {
        id,
        cap,
        admin_pubkey: _,
        scheme: _,
        operators: _,
        plugins: _,
        used_nonces: _,
    } = v;
    object::delete(id);
    borrow::destroy(cap)
}

// === Operator authorization ===

/// Mint a soulbound `OperatorCap` for `operator`, register it in `operators`,
/// and transfer it to `operator`. Emits `OperatorAuthorized`.
public fun authorize_operator<Cap: key + store>(
    v: &mut Vault<Cap>,
    admin: &VaultAdminCap,
    operator: address,
    expires_ms: u64,
    ctx: &mut TxContext,
) {
    assert!(admin.vault_id == object::id(v), ENotAdmin);
    let vault_id = object::id(v);
    let op = OperatorCap { id: object::new(ctx), vault_id, expires_ms };
    let operator_id = object::id(&op);
    v.operators.insert(operator_id);
    event::emit(OperatorAuthorized { vault_id, operator_id, operator, expires_ms });
    transfer::transfer(op, operator);
}

/// Revoke an operator by removing its id from the registry. The holder's
/// `OperatorCap` object becomes instantly inert. Emits `OperatorRevoked`.
public fun revoke_operator<Cap: key + store>(
    v: &mut Vault<Cap>,
    admin: &VaultAdminCap,
    operator_id: ID,
) {
    assert!(admin.vault_id == object::id(v), ENotAdmin);
    v.operators.remove(&operator_id);
    event::emit(OperatorRevoked { vault_id: object::id(v), operator_id });
}

/// Holder cleanup of a dead or revoked operator. No checks: it is the holder's
/// own object to destroy.
public fun destroy_operator(op: OperatorCap) {
    let OperatorCap { id, vault_id: _, expires_ms: _ } = op;
    object::delete(id);
}

// === Borrow ===

/// Admin borrow of the wrapped cap. Unconditional for the admin. The returned
/// `Borrow` hot potato must be returned via `return_cap` in the same tx.
public fun borrow_cap_admin<Cap: key + store>(
    v: &mut Vault<Cap>,
    admin: &VaultAdminCap,
): (Cap, Borrow) {
    assert!(admin.vault_id == object::id(v), ENotAdmin);
    borrow::borrow(&mut v.cap)
}

/// Plugin borrow of the wrapped cap. Witness-gated: only an installed plugin
/// (whose witness type `W` is in `plugins`) may borrow, and only through a live,
/// unexpired `OperatorCap` for this vault. The returned `Borrow` hot potato must
/// be returned via `return_cap` in the same tx.
public fun borrow_cap_plugin<Cap: key + store, W: drop>(
    v: &mut Vault<Cap>,
    op: &OperatorCap,
    _w: W,
    clk: &Clock,
): (Cap, Borrow) {
    assert!(v.plugins.contains(&type_name::with_defining_ids<W>()), EPluginNotInstalled);
    assert!(op.vault_id == object::id(v), EWrongVault);
    assert!(v.operators.contains(&object::id(op)), ERevoked);
    assert!(op.expires_ms > clk.timestamp_ms(), EExpired);
    borrow::borrow(&mut v.cap)
}

/// Return a previously borrowed cap together with its `Borrow` hot potato.
public fun return_cap<Cap: key + store>(v: &mut Vault<Cap>, cap: Cap, b: Borrow) {
    borrow::put_back(&mut v.cap, cap, b);
}

// === Signed intents ===

/// Verify the principal's signed intent over `msg` and consume its `nonce` in one
/// step. This is the high-stakes authorization primitive: a plugin builds the
/// canonical intent bytes for the operation it is about to perform, and this
/// function proves the vault's principal authorized exactly those bytes and that
/// the authorization is single-use.
///
/// The principal signs `msg` with the Sui **personal-message** scheme — i.e. what
/// every Sui wallet's `signPersonalMessage` and the SDK's
/// `Keypair.signPersonalMessage` produce — so both human wallets and autonomous
/// agent keys can author intents with their normal signing flow. The signature is
/// a raw signature (extract it from a serialized wallet signature off-chain) over
/// the personal-message digest reconstructed here: 64-byte Ed25519, or 64-byte
/// secp256r1 `(r, s)`, per the vault's `scheme`.
///
/// Digest reconstruction (the exact bytes a Sui signer hashes for a
/// personal message), identical across schemes:
///
/// ```text
///   preimage = [3, 0, 0]                    // Intent: scope=PersonalMessage(3), version=V0(0), app=Sui(0)
///            ++ bcs(PersonalMessage{ message: msg })
///   digest   = blake2b256(preimage)         // 32 bytes
/// ```
///
/// `PersonalMessage` wraps a single `vector<u8>` field, so its BCS encoding is
/// exactly the BCS encoding of `msg` itself: a ULEB128 length prefix followed by
/// the raw bytes. We therefore append `bcs::to_bytes(&msg)` directly. The signer
/// signs the 32-byte `digest`, so the verifier is given the digest (NOT the
/// preimage).
///
/// Per-scheme verification of that 32-byte `digest`:
/// - `SCHEME_ED25519`: `ed25519_verify(sig, pubkey, digest)`. Ed25519 hashes
///   internally as part of the scheme, so the digest is passed as-is.
/// - `SCHEME_SECP256R1`: `secp256r1_verify(sig, pubkey, digest, HASH_SHA256)`.
///   Unlike ed25519, the secp256r1 native takes the *raw* message plus a hash
///   flag and hashes it itself. A secp256r1 personal-message signer signs
///   `sha256(digest)` (e.g. `Secp256r1Keypair.sign` does `sha256(data)` over the
///   personal-message digest `data`), so we hand the native the digest and the
///   `HASH_SHA256` flag, and it re-applies sha256 to match.
///
/// Aborts with `EBadIntent` if the signature does not verify against the vault's
/// `admin_pubkey` under `scheme`, or with `ENonceUsed` if the nonce was already
/// consumed.
public fun verify_and_consume_intent<Cap: key + store>(
    v: &mut Vault<Cap>,
    msg: vector<u8>,
    sig: vector<u8>,
    nonce: u64,
) {
    let digest = personal_message_digest(&msg);
    assert!(verify_intent_sig(v.scheme, &v.admin_pubkey, &digest, &sig), EBadIntent);
    assert!(!v.used_nonces.contains(&nonce), ENonceUsed);
    v.used_nonces.insert(nonce);
}

/// Reconstruct the Sui personal-message digest the signer produced:
///   `blake2b256( [3,0,0] ‖ bcs(PersonalMessage{ message: msg }) )`.
/// `bcs` of a `vector<u8>` is `ULEB128(len) ‖ bytes`, which equals
/// `bcs(PersonalMessage{ message: msg })` since the struct has that one field, so
/// we append `bcs::to_bytes(&msg)` directly. Scheme-independent: every Sui signer
/// hashes this same 32-byte digest for a personal message.
fun personal_message_digest(msg: &vector<u8>): vector<u8> {
    let mut preimage = vector[3u8, 0u8, 0u8]; // Intent: PersonalMessage(3), V0(0), Sui(0)
    preimage.append(std::bcs::to_bytes(msg));
    hash::blake2b256(&preimage)
}

/// Verify a raw personal-message signature over `digest` for `pubkey` under
/// `scheme`. Returns `false` for an unknown scheme (so an unsupported scheme can
/// never spuriously authorize). Centralizing the dispatch here keeps
/// `verify_and_consume_intent` and any future intent surfaces consistent.
fun verify_intent_sig(
    scheme: u8,
    pubkey: &vector<u8>,
    digest: &vector<u8>,
    sig: &vector<u8>,
): bool {
    if (scheme == SCHEME_ED25519) {
        // Ed25519 verifies the 32-byte digest directly (it hashes internally as
        // part of the scheme); the signer signs the digest.
        ed25519::ed25519_verify(sig, pubkey, digest)
    } else if (scheme == SCHEME_SECP256R1) {
        // secp256r1_verify hashes its `msg` argument internally with the selected
        // hash before ECDSA-verifying. The signer signed `sha256(digest)`, so we
        // pass the digest as `msg` with `HASH_SHA256` and the native re-derives
        // the same pre-image.
        ecdsa_r1::secp256r1_verify(sig, pubkey, digest, HASH_SHA256)
    } else {
        false
    }
}

/// Whether `pubkey`'s length is consistent with `scheme`. Used at `wrap` time to
/// reject a misconfigured principal key up front. (`ed25519_verify` /
/// `secp256r1_verify` also reject wrong-length keys at verify time, but failing at
/// creation is the friendlier and safer contract.)
fun is_valid_scheme_pubkey(scheme: u8, pubkey: &vector<u8>): bool {
    if (scheme == SCHEME_ED25519) {
        pubkey.length() == ED25519_PUBKEY_LEN
    } else if (scheme == SCHEME_SECP256R1) {
        pubkey.length() == SECP256R1_PUBKEY_LEN
    } else {
        false
    }
}

// === Plugins ===

/// The vault-owned dynamic-field key under which a plugin's `Config` is stored,
/// parameterized (phantom) by the plugin's witness type `K`. Crucially this key
/// is constructed *by the vault*, not by the plugin — the plugin never names the
/// df key, it only supplies its witness type. That is what lets the owner add and
/// remove ANY plugin purely by type parameter (`add_plugin`/`remove_plugin`),
/// with no cooperation from the plugin module, keeping the `withdraw` escape
/// hatch structurally un-loseable.
public struct PluginKey<phantom K> has copy, drop, store {}

/// Install a plugin: store `cfg` in a dynamic field keyed by the vault-owned
/// `PluginKey<K>` and record the witness type `K` in the `plugins` set. The
/// plugin passes its witness value `_w: K` only to fix the type parameter `K`
/// at the call site; the vault owns the resulting df key.
public fun add_plugin<Cap: key + store, K: drop, Config: store>(
    v: &mut Vault<Cap>,
    admin: &VaultAdminCap,
    _w: K,
    cfg: Config,
) {
    assert!(admin.vault_id == object::id(v), ENotAdmin);
    df::add(&mut v.id, PluginKey<K> {}, cfg);
    v.plugins.insert(type_name::with_defining_ids<K>());
}

/// Uninstall a plugin: remove the witness type `K` from `plugins` and return the
/// stored `Config`. Owner-only and keyed purely by the type parameter `K` — no
/// witness VALUE and no plugin cooperation required, so the owner can tear down
/// ANY installed plugin (even one whose module is unavailable) directly through
/// the vault. This is the structural guarantee that the cap can always later be
/// `withdraw`n.
public fun remove_plugin<Cap: key + store, K: drop, Config: store>(
    v: &mut Vault<Cap>,
    admin: &VaultAdminCap,
): Config {
    assert!(admin.vault_id == object::id(v), ENotAdmin);
    v.plugins.remove(&type_name::with_defining_ids<K>());
    df::remove(&mut v.id, PluginKey<K> {})
}

/// Operate-time read of a plugin's config, keyed purely by the type parameter
/// `K`. Aborts if the plugin is not installed. Permissionless by design.
public fun config<Cap: key + store, K: drop, Config: store>(v: &Vault<Cap>): &Config {
    df::borrow(&v.id, PluginKey<K> {})
}

/// Admin-gated mutable access to a plugin's config, keyed purely by the type
/// parameter `K`.
public fun config_mut<Cap: key + store, K: drop, Config: store>(
    v: &mut Vault<Cap>,
    admin: &VaultAdminCap,
): &mut Config {
    assert!(admin.vault_id == object::id(v), ENotAdmin);
    df::borrow_mut(&mut v.id, PluginKey<K> {})
}

// === Views ===

/// The vault's object id.
public fun vault_id<Cap: key + store>(v: &Vault<Cap>): ID {
    object::id(v)
}

/// The principal's public key, used by plugins to verify signed intents. Its
/// scheme (and so its byte format) is reported by `scheme`.
public fun admin_pubkey<Cap: key + store>(v: &Vault<Cap>): &vector<u8> {
    &v.admin_pubkey
}

/// The signature scheme of `admin_pubkey` — `scheme_ed25519()` or
/// `scheme_secp256r1()`.
public fun scheme<Cap: key + store>(v: &Vault<Cap>): u8 {
    v.scheme
}

/// The Ed25519 scheme tag (raw 32-byte key; `ed25519_verify` over the digest).
public fun scheme_ed25519(): u8 { SCHEME_ED25519 }

/// The secp256r1 / NIST P-256 scheme tag (compressed 33-byte SEC1 point;
/// `secp256r1_verify(.., HASH_SHA256)` over the digest). The scheme produced by
/// `@mysten/sui`'s `Secp256r1Keypair` and by WebCrypto P-256 keys.
public fun scheme_secp256r1(): u8 { SCHEME_SECP256R1 }

/// Whether `operator_id` is currently an authorized operator of the vault.
public fun is_operator<Cap: key + store>(v: &Vault<Cap>, operator_id: ID): bool {
    v.operators.contains(&operator_id)
}

/// Whether a plugin with witness type `K` is installed.
public fun has_plugin<Cap: key + store, K: drop>(v: &Vault<Cap>): bool {
    v.plugins.contains(&type_name::with_defining_ids<K>())
}

/// The vault id an `OperatorCap` was minted for.
public fun operator_vault_id(op: &OperatorCap): ID {
    op.vault_id
}

/// The vault id a `VaultAdminCap` controls.
public fun admin_vault_id(admin: &VaultAdminCap): ID {
    admin.vault_id
}

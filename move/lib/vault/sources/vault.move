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
/// through a live, unexpired `OperatorCap`. Plugins additionally verify the
/// principal's signed intents off the `admin_pubkey` and replay-protect them via
/// the `used_nonces` set (`consume_nonce`).
///
/// The owner holds a `VaultAdminCap` (a recovery key) and always retains an
/// unconditional escape hatch via `withdraw`.
module miso_vault::vault;

use std::type_name::{Self, TypeName};
use sui::borrow::{Self, Referent, Borrow};
use sui::clock::Clock;
use sui::dynamic_field as df;
use sui::event;
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

// === Structs ===

/// A shared object wrapping a capability `Cap` and brokering bounded,
/// revocable access to it. `Cap` is a real type parameter (the cap lives
/// inside the `Referent`), hence it must be `key + store`.
public struct Vault<Cap: key + store> has key {
    id: UID,
    /// The wrapped capability, lent out via the `sui::borrow` hot-potato API.
    cap: Referent<Cap>,
    /// The principal / vault owner's Ed25519 public key. Plugins use this to
    /// verify the principal's signed intents for high-stakes operations.
    admin_pubkey: vector<u8>,
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

/// Wrap `cap` in a new shared `Vault` and return the `VaultAdminCap` for the
/// caller to route. `admin_pubkey` is the principal's Ed25519 public key used by
/// plugins to verify the principal's signed intents. Emits `VaultCreated`.
public fun wrap<Cap: key + store>(
    cap: Cap,
    admin_pubkey: vector<u8>,
    ctx: &mut TxContext,
): VaultAdminCap {
    let vault = Vault {
        id: object::new(ctx),
        cap: borrow::new(cap, ctx),
        admin_pubkey,
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
    let Vault { id, cap, admin_pubkey: _, operators: _, plugins: _, used_nonces: _ } = v;
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

// === Signed-intent nonces ===

/// Witness-gated consumption of a signed-intent nonce. Only an installed plugin
/// (witness type `W` in `plugins`) may consume nonces, inside its op flow.
/// Aborts on replay. Asserting both installation and uniqueness keeps the
/// principal's signed intents single-use.
public fun consume_nonce<Cap: key + store, W: drop>(
    v: &mut Vault<Cap>,
    _w: W,
    nonce: u64,
) {
    assert!(v.plugins.contains(&type_name::with_defining_ids<W>()), EPluginNotInstalled);
    assert!(!v.used_nonces.contains(&nonce), ENonceUsed);
    v.used_nonces.insert(nonce);
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

/// The principal's Ed25519 public key, used by plugins to verify signed intents.
public fun admin_pubkey<Cap: key + store>(v: &Vault<Cap>): &vector<u8> {
    &v.admin_pubkey
}

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

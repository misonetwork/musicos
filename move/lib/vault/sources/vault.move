// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// A generic, standalone vault that wraps an admin capability and delegates
/// *bounded, revocable* use of it to "agent" addresses.
///
/// The vault is a shared object holding the capability inside a
/// `sui::borrow::Referent`. Agents receive a soulbound `AgentAuth` and may
/// hot-potato-borrow the capability for the duration of a single transaction;
/// the `Borrow` hot potato forces the cap to be returned before the tx ends.
///
/// Authorization is binary: an `AgentAuth` is only live while its object id is
/// present in the vault's `auths` set. Removing it (`revoke_agent`) makes the
/// auth instantly inert, even though the holder still owns the (now useless)
/// object. `AgentAuth` is key-only (no `store`), so it is soulbound and the
/// holder cannot transfer it.
///
/// Plugins are other packages that install per-vault `Config` values in dynamic
/// fields keyed by a `Key` type. The `plugins` set tracks the installed `Key`
/// types both for discoverability and as a teardown guard: `withdraw` can only
/// run on a vault with no plugins installed, preventing orphaned dynamic fields.
///
/// The owner holds an `OwnerCap` (a recovery key) and always retains an
/// unconditional escape hatch via `withdraw`.
module miso_vault::vault;

use std::type_name::{Self, TypeName};
use sui::borrow::{Self, Referent, Borrow};
use sui::clock::Clock;
use sui::dynamic_field as df;
use sui::event;
use sui::vec_set::{Self, VecSet};

// === Errors ===

/// The supplied `OwnerCap` does not own this vault.
const ENotOwner: u64 = 0;
/// Cannot withdraw the cap while plugins are still installed.
const EPluginsInstalled: u64 = 1;
/// The `AgentAuth` was minted for a different vault.
const EWrongVault: u64 = 2;
/// The `AgentAuth` has been revoked (removed from the `auths` registry).
const ERevoked: u64 = 3;
/// The `AgentAuth` has expired.
const EExpired: u64 = 4;

// === Structs ===

/// A shared object wrapping a capability `Cap` and brokering bounded,
/// revocable access to it. `Cap` is a real type parameter (the cap lives
/// inside the `Referent`), hence it must be `key + store`.
public struct Vault<Cap: key + store> has key {
    id: UID,
    /// The wrapped capability, lent out via the `sui::borrow` hot-potato API.
    cap: Referent<Cap>,
    /// Authorized `AgentAuth` object ids. Membership is the revocation
    /// registry: remove == instant revoke.
    auths: VecSet<ID>,
    /// Installed plugin `Key` types. Teardown guard + discoverability.
    plugins: VecSet<TypeName>,
}

/// The recovery key for a vault. Holder may authorize/revoke agents, manage
/// plugins, and unconditionally withdraw the wrapped cap.
public struct OwnerCap has key, store {
    id: UID,
    vault_id: ID,
}

/// A soulbound (key-only, no `store`) authorization granting an agent address
/// the right to borrow the vault's cap until `expires_ms`, while the auth's id
/// remains in the vault's `auths` set.
public struct AgentAuth has key {
    id: UID,
    vault_id: ID,
    expires_ms: u64,
}

// === Events ===

public struct VaultCreated has copy, drop {
    vault_id: ID,
}

public struct AgentAuthorized has copy, drop {
    vault_id: ID,
    auth_id: ID,
    agent: address,
    expires_ms: u64,
}

public struct AgentRevoked has copy, drop {
    vault_id: ID,
    auth_id: ID,
}

// === Lifecycle ===

/// Wrap `cap` in a new shared `Vault` and return the `OwnerCap` for the caller
/// to route. Emits `VaultCreated`.
public fun wrap<Cap: key + store>(cap: Cap, ctx: &mut TxContext): OwnerCap {
    let vault = Vault {
        id: object::new(ctx),
        cap: borrow::new(cap, ctx),
        auths: vec_set::empty(),
        plugins: vec_set::empty(),
    };
    let vault_id = object::id(&vault);
    let owner = OwnerCap { id: object::new(ctx), vault_id };
    event::emit(VaultCreated { vault_id });
    transfer::share_object(vault);
    owner
}

/// Owner escape hatch: consume the vault and recover the wrapped cap. Requires
/// the vault to be free of plugins so no dynamic fields are orphaned.
public fun withdraw<Cap: key + store>(v: Vault<Cap>, o: &OwnerCap): Cap {
    assert!(o.vault_id == object::id(&v), ENotOwner);
    assert!(v.plugins.is_empty(), EPluginsInstalled);
    let Vault { id, cap, auths: _, plugins: _ } = v;
    object::delete(id);
    borrow::destroy(cap)
}

// === Agent authorization ===

/// Mint a soulbound `AgentAuth` for `agent`, register it in `auths`, and
/// transfer it to `agent`. Emits `AgentAuthorized`.
public fun authorize_agent<Cap: key + store>(
    v: &mut Vault<Cap>,
    o: &OwnerCap,
    agent: address,
    expires_ms: u64,
    ctx: &mut TxContext,
) {
    assert!(o.vault_id == object::id(v), ENotOwner);
    let vault_id = object::id(v);
    let auth = AgentAuth { id: object::new(ctx), vault_id, expires_ms };
    let auth_id = object::id(&auth);
    v.auths.insert(auth_id);
    event::emit(AgentAuthorized { vault_id, auth_id, agent, expires_ms });
    transfer::transfer(auth, agent);
}

/// Revoke an agent by removing its auth id from the registry. The holder's
/// `AgentAuth` object becomes instantly inert. Emits `AgentRevoked`.
public fun revoke_agent<Cap: key + store>(v: &mut Vault<Cap>, o: &OwnerCap, auth_id: ID) {
    assert!(o.vault_id == object::id(v), ENotOwner);
    v.auths.remove(&auth_id);
    event::emit(AgentRevoked { vault_id: object::id(v), auth_id });
}

/// Holder cleanup of a dead or revoked auth. No checks: it is the holder's own
/// object to destroy.
public fun destroy_auth(auth: AgentAuth) {
    let AgentAuth { id, vault_id: _, expires_ms: _ } = auth;
    object::delete(id);
}

// === Borrow ===

/// Borrow the wrapped cap. The returned `Borrow` hot potato must be returned
/// via `put_back` in the same transaction. Aborts if the auth is for another
/// vault, has been revoked, or has expired.
public fun borrow<Cap: key + store>(
    v: &mut Vault<Cap>,
    auth: &AgentAuth,
    clk: &Clock,
): (Cap, Borrow) {
    assert!(auth.vault_id == object::id(v), EWrongVault);
    assert!(v.auths.contains(&object::id(auth)), ERevoked);
    assert!(auth.expires_ms > clk.timestamp_ms(), EExpired);
    borrow::borrow(&mut v.cap)
}

/// Return a previously borrowed cap together with its `Borrow` hot potato.
public fun put_back<Cap: key + store>(v: &mut Vault<Cap>, cap: Cap, b: Borrow) {
    borrow::put_back(&mut v.cap, cap, b);
}

// === Plugins ===

/// Install a plugin: store `cfg` in a dynamic field keyed by `key` and record
/// the `Key` type in the `plugins` set.
public fun add_plugin<Cap: key + store, Key: copy + drop + store, Config: store>(
    v: &mut Vault<Cap>,
    o: &OwnerCap,
    key: Key,
    cfg: Config,
) {
    assert!(o.vault_id == object::id(v), ENotOwner);
    df::add(&mut v.id, key, cfg);
    v.plugins.insert(type_name::with_defining_ids<Key>());
}

/// Uninstall a plugin: remove the `Key` type from `plugins` and return the
/// stored `Config`.
public fun remove_plugin<Cap: key + store, Key: copy + drop + store, Config: store>(
    v: &mut Vault<Cap>,
    o: &OwnerCap,
    key: Key,
): Config {
    assert!(o.vault_id == object::id(v), ENotOwner);
    v.plugins.remove(&type_name::with_defining_ids<Key>());
    df::remove(&mut v.id, key)
}

/// Operate-time read of a plugin's config. Aborts if the plugin is not
/// installed. Permissionless by design.
public fun config<Cap: key + store, Key: copy + drop + store, Config: store>(
    v: &Vault<Cap>,
    key: Key,
): &Config {
    df::borrow(&v.id, key)
}

/// Owner-gated mutable access to a plugin's config.
public fun config_mut<Cap: key + store, Key: copy + drop + store, Config: store>(
    v: &mut Vault<Cap>,
    o: &OwnerCap,
    key: Key,
): &mut Config {
    assert!(o.vault_id == object::id(v), ENotOwner);
    df::borrow_mut(&mut v.id, key)
}

// === Views ===

/// The vault's object id.
public fun vault_id<Cap: key + store>(v: &Vault<Cap>): ID {
    object::id(v)
}

/// Whether `auth_id` is currently an authorized agent of the vault.
public fun is_agent<Cap: key + store>(v: &Vault<Cap>, auth_id: ID): bool {
    v.auths.contains(&auth_id)
}

/// Whether a plugin keyed by type `Key` is installed.
public fun has_plugin<Cap: key + store, Key: copy + drop + store>(v: &Vault<Cap>): bool {
    v.plugins.contains(&type_name::with_defining_ids<Key>())
}

/// The vault id an `AgentAuth` was minted for.
public fun auth_vault_id(auth: &AgentAuth): ID {
    auth.vault_id
}

/// The vault id an `OwnerCap` controls.
public fun owner_vault_id(o: &OwnerCap): ID {
    o.vault_id
}

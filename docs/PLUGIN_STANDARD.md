# Miso Vault Plugin Standard

A **plugin** is a package that delegates *bounded, revocable* use of a vaulted
capability (`miso_vault::vault::Vault<Cap>`) to operator addresses. This document
is the convention every plugin in `move/extensions/*_ops` follows. A copy-paste
skeleton lives at `move/extensions/_plugin_template/`, and a conformance lint
(`scripts/lint-plugins.sh`) enforces the load-bearing parts.

## Why the standard exists: the un-loseable escape hatch

The vault keys each plugin's `Config` in a dynamic field under a **vault-owned**
wrapper, `vault::PluginKey<K>`, parameterized by the plugin's witness type `K`.
The plugin never names the dynamic-field key — it only supplies its `K` *witness*
type. Because the vault constructs the key, the vault owner can install and,
crucially, **uninstall any plugin purely by type parameter**:

```move
public fun remove_plugin<Cap: key + store, K: drop, Config: store>(
    v: &mut Vault<Cap>,
    admin: &VaultAdminCap,
): Config
```

No witness value. No call into the plugin module. So even a plugin that ships no
`uninstall` — or whose package has been deleted — can be torn down by the owner
directly through the vault. `withdraw` only runs on a plugin-free vault, so this
is what makes the owner's escape hatch **structurally un-loseable**: the wrapped
cap can always be recovered.

(The earlier design keyed the df by the plugin's own `Key` value, whose
constructor is module-private — so only the plugin could remove it. A plugin that
forgot to ship `uninstall` permanently trapped the cap. The vault-owned
`PluginKey<K>` flip fixes that class of bug at the structural level.)

## The convention

### One plugin == one module

Each plugin is a single Move module in its own package
(`move/extensions/<name>_ops/`).

### `Key` — a `drop`-only witness

```move
public struct Key() has drop;
```

- Canonical name: **`Key`**.
- Ability: **`drop` only**. It must NOT have `store` — the vault, not the plugin,
  owns the config dynamic-field key (`vault::PluginKey<Key>`), so `Key` is never
  itself a df key.
- Roles: (1) fixes the type parameter `K` at `install`; (2) the witness `W` for
  `vault::borrow_cap_plugin` — the real auth proof, since only this package can
  construct `Key`; (3) if the plugin uses signed intents, the witness for
  `vault::consume_nonce`.

### `Config` — `store + drop`

```move
public struct Config has store, drop { /* owner-set policy knobs */ }
```

- Canonical name: **`Config`**.
- Abilities: **`store`** (it lives in a dynamic field) and **`drop`** (so
  `uninstall` / `remove_plugin` can return it and callers can discard it).
- Holds the owner-set bounds the operator is constrained by (a ceiling, a floor, a
  payout address, …). An empty `Config` is fine when the policy is entirely
  on-chain elsewhere (see `release_ops`).

### `install` / `uninstall`

```move
public fun install<Cap: key + store>(v: &mut Vault<Cap>, admin: &VaultAdminCap, /* knobs */) {
    vault::add_plugin(v, admin, Key(), Config { /* knobs */ });
}

public fun uninstall<Cap: key + store>(v: &mut Vault<Cap>, admin: &VaultAdminCap): Config {
    vault::remove_plugin<_, Key, Config>(v, admin)
}
```

- `install` passes `Key()` **by value** (to fix the type param) plus the `Config`.
- `uninstall` is a **convenience** wrapper — the owner can call
  `vault::remove_plugin<Cap, Key, Config>` directly. Always provide it anyway for a
  clean PTB call site.

### Operate functions

```move
public fun operate<Cap: key + store>(v: &mut Vault<Cap>, op: &OperatorCap, clk: &Clock) {
    let _bound = vault::config<_, Key, Config>(v).knob;          // read policy BY TYPE PARAM
    let (cap, b) = vault::borrow_cap_plugin(v, op, Key(), clk);  // borrow with witness VALUE
    // ... drive `cap` ...
    vault::return_cap(v, cap, b);                                // return in the SAME fn
}
```

- Read config **by type param**: `vault::config<_, Key, Config>(v)` — no witness
  value.
- Borrow with the **witness value**: `vault::borrow_cap_plugin(v, op, Key(), clk)`.
- **Every `borrow_cap_plugin` must be paired with a `return_cap` in the same
  function.** The `Borrow` hot potato forces this at the type level; the lint
  enforces the textual pairing as a fast guard.

## Vault API the plugin uses (signatures)

```move
// vault-owned df-key wrapper, parameterized by the plugin witness type K
public struct PluginKey<phantom K> has copy, drop, store {}

public fun add_plugin<Cap: key + store, K: drop, Config: store>(
    v: &mut Vault<Cap>, admin: &VaultAdminCap, _w: K, cfg: Config,
);
public fun remove_plugin<Cap: key + store, K: drop, Config: store>(
    v: &mut Vault<Cap>, admin: &VaultAdminCap,
): Config;
public fun config<Cap: key + store, K: drop, Config: store>(v: &Vault<Cap>): &Config;
public fun config_mut<Cap: key + store, K: drop, Config: store>(
    v: &mut Vault<Cap>, admin: &VaultAdminCap,
): &mut Config;
public fun has_plugin<Cap: key + store, K: drop>(v: &Vault<Cap>): bool;

// UNCHANGED — still takes the witness VALUE (the real auth proof):
public fun borrow_cap_plugin<Cap: key + store, W: drop>(
    v: &mut Vault<Cap>, op: &OperatorCap, _w: W, clk: &Clock,
): (Cap, Borrow);
public fun consume_nonce<Cap: key + store, W: drop>(v: &mut Vault<Cap>, _w: W, nonce: u64);
public fun return_cap<Cap: key + store>(v: &mut Vault<Cap>, cap: Cap, b: Borrow);
```

## How a client resolves a vault's plugins

A vault tracks its installed plugins as `TypeName`s in its `plugins` set; each
entry is `with_defining_ids<Key>()` for some plugin's `Key`. A client identifies a
plugin by the fully-qualified pair `<pkg>::<module>::Key` and reads its config type
as `<pkg>::<module>::Config`.

This mirrors **Sui's transfer policy**, where rules are resolved by their `Rule`
witness type and their associated `Config` type — same `Rule`/`Config`
(here `Key`/`Config`) pattern, same "the framework owns the dynamic-field key"
property.

## The four reference plugins

| Plugin | Vaulted `Cap` | `Config` | Notable |
|--------|---------------|----------|---------|
| `composition_ops` | `CompositionAdminCap<CS>` | royalty ceiling | autonomous royalty rate + metadata |
| `recording_ops`   | `RecordingAdminCap<RS>`   | split floor    | consent tier (signed intent + nonces) + sweeps |
| `release_ops`     | `ReleaseAdminCap`         | empty marker   | revenue distribution by on-chain splits |
| `revenue_ops`     | `Stake<Share>`            | payout address | claim/register/unregister against a royalty pool |

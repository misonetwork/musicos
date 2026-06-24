# `_plugin_template` — reference skeleton for a `miso_vault` plugin

This directory is a **commented reference, not a buildable package**. There is no
`Move.toml` here on purpose: `sources/plugin_template.move` does not resolve the
`miso_vault` dependency and is not meant to compile on its own. It exists to show
the canonical shape of a vault plugin in one place.

To create a real plugin:

1. Copy this into `move/extensions/<name>_ops/`.
2. Add a `Move.toml` with a `miso_vault = { local = "../../lib/vault" }` dependency
   (plus whatever core/extension deps your operate functions need).
3. Rename the module and the `Key` / `Config` types; fill in real operate functions.
4. Make sure it passes `scripts/lint-plugins.sh` from the repo root.

## The convention (see `docs/PLUGIN_STANDARD.md` for the full version)

- **One plugin == one module.**
- Exactly one **`Key`** — a `drop`-only witness (NOT `store`; the vault owns the
  config dynamic-field key via `vault::PluginKey<Key>`).
- Exactly one **`Config`** — `store + drop`.
- **`install`** calls `vault::add_plugin(v, admin, Key(), Config { .. })`.
- **`uninstall`** calls `vault::remove_plugin<_, Key, Config>(v, admin)` (no
  witness value). It is a convenience: the owner can call `vault::remove_plugin`
  directly with no plugin cooperation, which is what makes the vault's `withdraw`
  escape hatch un-loseable.
- **Operate functions** read config by type param (`vault::config<_, Key, Config>(v)`)
  and borrow the cap with the witness value (`vault::borrow_cap_plugin(v, op, Key(), clk)`),
  returning it with `vault::return_cap(v, cap, b)` in the **same function**.

## How a client resolves a vault's plugins

A vault's installed plugins are tracked as `TypeName`s in its `plugins` set. Each
entry is `with_defining_ids<Key>()` for some plugin's `Key`. A client identifies a
plugin by the fully-qualified pair `<pkg>::<module>::Key` and reads its config type
as `<pkg>::<module>::Config` — exactly mirroring how Sui's transfer policy resolves
rules by `Rule` / `Config`.

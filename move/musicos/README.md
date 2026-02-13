# MusicOS

Permissionless music protocol on Sui.

## Overview

MusicOS provides the core data model for music rights and distribution: Compositions, Recordings, Releases, and Parties. Each object supports an extension system that allows third-party modules to attach functionality without modifying the core protocol.

## Extension Architecture

### Why Raw `&mut UID` Access

MusicOS is a permissionless protocol — anyone can build and deploy extension packages. Extensions get raw `&mut UID` access to the parent object via `uid_mut_with_extension`, gated by a witness type and a per-object registration check.

This is a deliberate choice. Sui's core primitives — fund accumulators, derived objects, coin receiving — all operate on `&mut UID`. New primitives may be added to the Sui framework over time. If MusicOS wrapped each UID operation into a delegated function on the core module, every new Sui primitive would require a core protocol upgrade. Raw `&mut UID` access ensures extensions can adopt new Sui capabilities immediately, without waiting for or depending on the core package.

The tradeoff is that a registered extension has broad access to the parent's UID — it could theoretically interfere with other extensions' dynamic fields. This is an accepted consequence of the permissionless model. The `CompositionAdminCap` (or `RecordingAdminCap`, `ReleaseAdminCap`) holder decides which extensions to register on their objects and accepts the trust implications.

### The WordPress Model

MusicOS is designed like WordPress: an open-source, self-hosted protocol where you install whatever plugins you want. The admin cap holder is the site admin — they choose which extensions to register and bear responsibility for that choice.

A more managed layer (analogous to WordPress.com) can be built on top of MusicOS. This layer would handle custody of admin capabilities and enforce extension whitelists, providing guardrails for users who want them without restricting the protocol's permissionless nature.

### How Extensions Work

**Registration** requires the admin capability:

```move
composition.register_extension(
    &composition_admin_cap,
    my_extension::Extension(),
    config,
);
```

**UID access** requires the extension's witness type (only the defining module can construct it) and a registration check:

```move
public fun uid_mut_with_extension<Extension: drop>(
    self: &mut Composition<S>,
    _extension: Extension,
): &mut UID {
    extension::assert_registered<Extension>(&self.id);
    &mut self.id
}
```

**Unregistration** requires the admin capability:

```move
let config = composition.unregister_extension<_, my_extension::Extension, Config>(
    &composition_admin_cap,
    my_extension::Extension(),
);
```

Extensions can be registered and unregistered regardless of the object's lifecycle state. This is intentional — extensions like reward pools are designed to operate on published (shared) objects.

### Extension Key Design

Each extension's config is stored as a typed dynamic field using a phantom-parameterized key:

```move
public struct Extension<phantom E: drop>() has copy, drop, store;
```

The phantom type `E` identifies the extension, ensuring each extension has a unique storage slot on the parent object. The `public(package)` visibility on `register` and `unregister` ensures only the `musicos` package can add or remove these keys through the gated entry points.

### Comparison with Other Models

| Model | UID Access | Isolation | Best For |
|-------|-----------|-----------|----------|
| **MusicOS (raw UID)** | `&mut UID` via witness + registration | By convention | Permissionless protocols needing full Sui primitive access |
| **Stake (Bag)** | None — extensions get `&mut Bag` | Structural | Generic primitives with untrusted extensions |
| **Sona Player (registry)** | `&mut UID` via witness + Settings | By convention | Managed systems with centralized extension control |

## Core Objects

| Module | Description |
|--------|-------------|
| `composition` | Musical works with share tokens, party credits, and revenue splits |
| `recording` | Audio recordings linked to compositions, with stems and cover art |
| `release` | Collections of tracks organized into discs, with revenue distribution |
| `party` | Individuals or groups credited on compositions, recordings, and releases |
| `extension` | Core extension registration system |

## License

Apache-2.0

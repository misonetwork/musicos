# Miso Protocol

[![License: Apache 2.0](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)
[![Move](https://img.shields.io/badge/Move-2024-black.svg)](https://docs.sui.io/concepts/sui-move-concepts)

> A permissionless music protocol on [Sui](https://sui.io), written in Move.

Miso models the core objects of recorded music — **compositions**, **recordings**, and **releases** — as on-chain objects whose ownership is expressed through per-object share tokens. Anyone can register a work; no gatekeeper, allowlist, or central registry of artists.

## Repository layout

This repository is a monorepo containing the core protocol and its shared TypeScript SDK:

| Path | Package | Description |
|------|---------|-------------|
| [`move/`](./move) | `miso` (Move 2024) | The on-chain core protocol package. Build/test with `sui move` from this directory. |
| [`sdk/`](./sdk) | [`@misonetwork/miso-protocol`](./sdk) (TypeScript) | Typed queries, transaction builders, and BCS event parsers that mirror the core Move ABI. |

Keeping the SDK alongside the Move package lets ABI changes (struct fields, event layouts, entry-function arguments) and their TypeScript counterparts move in a single change set.

First-party **extensions** — credits, cover art, genre, royalty pools, revenue distributor, attribution, and more — live in a separate repo, [`miso-protocol-extensions`](https://github.com/misonetwork/miso-protocol-extensions). Each is a standalone Move package that attaches to core objects via cap-gated `&mut UID` access, without modifying or re-publishing the core.

## Data model

The protocol separates the *work* layer from the *distribution* layer:

| Object | Layer | What it is |
|--------|-------|------------|
| **`Composition`** | work | The underlying written work (song / instrumental). Core carries its title and the royalty rate it earns from recordings; songwriting credits attach via a credits extension. |
| **`Recording`** | work | A specific master recording of a composition. It carries no name of its own — its display title is its composition's title, and version naming ("Radio Edit", "(Live)") is extension metadata. Credits, language, advisory flags, the master audio, and cover art attach as extensions or dynamic fields. |
| **`Release`** | distribution | A distributable package (Album / EP / Single) assembled from recordings — a flat, ordered tracklist with per-track revenue splits. Display grouping (discs, vinyl sides), cover art, and credits attach as extensions. |

Supporting types: **`Deal`** (authorizes a recording's inclusion in one exact release with a revenue split; consumed to mint a `Track`) and **`Track`** (a recording placed on a release). Cover art, credits, naming metadata, and party roles live in the extensions layer, not the core package.

### Consent

A release's id is **derived from a digest of its exact economics**: the ordered
list of `(recording, split)` pairs plus a creator nonce. A `Deal` targets that
derived id, so signing a deal consents to the release's precise membership,
splits, and running order — and nothing else. The stored tracklist has the same
shape as the digest pre-image: nothing structural is chosen after consent
except the release's title. Presentation (artwork, credits, display grouping)
is chosen by the release creator and is publicly attributable rather than
cryptographically committed.

Audio itself is **not** part of the core package — the master attaches to a `Recording` as a dynamic field, minted by an attested ingester (see the standalone [`misonetwork/audio`](https://github.com/misonetwork/audio) primitive). The core takes no audio dependency.

### Lifecycle

Compositions, recordings, and releases are **build-then-freeze**: they are created in an `Initialized` state, configured via their admin capability, then `publish()`ed — after which they are immutable. `publish()` emits a single lean event carrying just the object's id (and parent link), which an indexer uses as a signal to fetch the now-final object.

### Ownership

Ownership is expressed through **share tokens** (via the [`miso_share`](https://github.com/misonetwork/miso-share) package): each composition and recording initializes a fixed-supply share currency, and the set of share holders *is* the set of rightsholders. There are no separate label / publisher / rightsholder fields — ownership is the revenue claim.

## Design principles

- **Core stores what a thing *is*; extensions describe it.** Constitutive state — identity declarations and everything the economics read — lives in the frozen core. Anything with more than one correct rendering (version naming, disc grouping, artwork, credits) is presentation and lives in the mutable extension layer. Core names exactly two things: the work (`Composition.title`) and the package (`Release.title`).
- **The digest binds what signers agree to; publish freezes what the creator declared; extensions carry what anyone might rephrase.** Three tiers, three guarantees.
- **Create-and-publish is atomic by construction.** Core objects are `key`-only with no `drop`: an `Initialized` object cannot outlive its creating transaction, so every core object that exists on-chain is published and shared.
- **Classifications are attestations, not core fields.** Subjective labels where an external party is the better authority (e.g. genre) live in an attestation/extension layer rather than on the core object.
- **Permissionless and territory-agnostic** — the territory is the internet; there are no region locks.
- **V1 has no derivative-work edges** — a composition maps to many recordings; remix/sample/cover relationships between works are out of scope for now.

## Modules

```
composition   recording   release
deal          track
```

## Dependencies

| Dependency | Source | Purpose |
|------------|--------|---------|
| `bps`   | `unconfirmedlabs/bps` | Basis-point math |
| `miso_share` | [`misonetwork/miso-share`](https://github.com/misonetwork/miso-share) | Fixed-supply share/ownership currency |

The core package is intentionally lean — `audio`, `partyos`, `ori`, and `gengo` are no longer core dependencies; that functionality now lives in the extensions repo.

## Build & test

The core Move package lives in [`move/`](./move):

```sh
cd move
sui move build
sui move test
```

First-party extensions live in [`miso-protocol-extensions`](https://github.com/misonetwork/miso-protocol-extensions); each is a standalone package that builds the same way.

The TypeScript SDK lives in [`sdk/`](./sdk):

```sh
cd sdk
bun install
bun run typecheck
```

## Deployment

The current Testnet deployment is immutable: it was published and its
`UpgradeCap` destroyed atomically.

- `miso`: `0x5bb3ec642b1f7debd8bc2acbc16232abe893844d5978431d1cc0fbdddad73b97`
- `ReleaseRegistry` (shared): `0x3f202b6f89cf635f54bd7ddee7a21e73c77b88a10f1fc451571e9e931997e8d6`
- `bps` (immutable): `0x0f170226c83d612e407732f46170d02530fbc76bc626221642c4142d86759bff`
- `miso_share` (immutable): `0x7e7c860158dd0dd840133b68a608854e30101d496781bb835dc747f410732390`

Current package and object ids for every network live in
[`misonetwork/miso-deployments`](https://github.com/misonetwork/miso-deployments),
the canonical deployment manifest across all Miso repos — reference it rather
than hardcoding ids. [`move/Published.toml`](./move/Published.toml) records
this package's own publish metadata and is what dependent Move packages build
against.

## Contributing

Issues and pull requests are welcome. By contributing you agree that your contributions are licensed under the project's Apache 2.0 license.

## License

[Apache 2.0](LICENSE) © Miso Labs, Inc.

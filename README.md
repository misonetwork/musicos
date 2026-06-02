# MusicOS

[![License: Apache 2.0](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)
[![Move](https://img.shields.io/badge/Move-2024-black.svg)](https://docs.sui.io/concepts/sui-move-concepts)

> A permissionless music protocol on [Sui](https://sui.io), written in Move.

MusicOS models the core objects of recorded music — **compositions**, **recordings**, and **releases** — as on-chain objects whose ownership is expressed through per-object share tokens. Anyone can register a work; no gatekeeper, allowlist, or central registry of artists.

## Repository layout

This repository is a monorepo containing the protocol and its first-party TypeScript SDK:

| Path | Package | Description |
|------|---------|-------------|
| [`move/`](./move) | `musicos` (Move 2024) | The on-chain protocol package. Build/test with `sui move` from this directory. |
| [`sdk/`](./sdk) | [`@unconfirmed/musicos`](./sdk) (TypeScript) | Typed queries, transaction builders, and BCS event parsers that mirror the Move ABI. |

Keeping the SDK alongside the Move package lets ABI changes (struct fields, event layouts, entry-function arguments) and their TypeScript counterparts move in a single change set.

## Data model

The protocol separates the *work* layer from the *distribution* layer:

| Object | Layer | What it is |
|--------|-------|------------|
| **`Composition`** | work | The underlying written work (song / instrumental). Carries its title(s), songwriting credits, and the royalty rate it earns from recordings. |
| **`Recording`** | work | A specific master recording of a composition. Carries its credits, primary/featured artists, language, explicit/instrumental flags, master audio, and cover art. |
| **`Release`** | distribution | A distributable package (Album / EP / Single) assembled from recordings — ordered discs of tracks with cover art, credits, and per-track revenue splits. |

Supporting types: **`Deal`** (authorizes a recording's inclusion in a release with a revenue split; consumed to mint a `Track`), **`Track`** (a recording placed on a release), **`Disc`** (an ordered list of tracks), **`CoverArt`**, and the three party-role enums (`composition_party_role`, `recording_party_role`, `release_party_role`).

Audio itself is **not** defined here — it's a standalone primitive, [`misonetwork/audio`](https://github.com/misonetwork/audio) (module `audio::audio`), which any protocol can embed and any attested ingester can mint. A `Recording` holds an `audio::audio::Audio` as its master.

### Lifecycle

Compositions, recordings, and releases are **build-then-freeze**: they are created in an `Initialized` state, configured via their admin capability, then `publish()`ed — after which they are immutable. `publish()` emits a single lean event carrying just the object's id (and parent link), which an indexer uses as a signal to fetch the now-final object.

### Ownership

Ownership is expressed through **share tokens** (via the [`share`](https://github.com/unconfirmedlabs/share) package): each composition and recording initializes a fixed-supply share currency, and the set of share holders *is* the set of rightsholders. There are no separate label / publisher / rightsholder fields — ownership is the revenue claim.

## Design principles

- **Everything on-chain; the core stores only verifiable or constitutive state.** Objective, creator-declared facts and the things that *constitute* an object (titles, credits, the master, release format) are core fields. The protocol does not store self-attested historical claims (e.g. original release dates, territories).
- **Classifications are attestations, not core fields.** Subjective labels where an external party is the better authority (e.g. genre) live in an attestation/extension layer rather than on the core object.
- **Supplementary artifacts attach as dynamic fields**, keeping the core objects thin.
- **Permissionless and territory-agnostic** — the territory is the internet; there are no region locks.
- **V1 has no derivative-work edges** — a composition maps to many recordings; remix/sample/cover relationships between works are out of scope for now.

## Modules

```
composition              recording              release
composition_party_role   recording_party_role   release_party_role
                                                 deal · track · disc · release_kind
cover_art
```

## Dependencies

| Dependency | Source | Purpose |
|------------|--------|---------|
| `audio`    | `misonetwork/audio` | Attested audio primitive (recording master) |
| `share`    | `misonetwork/share` | Fixed-supply share/ownership currency |
| `partyos`  | `misonetwork/partyos` | Party identity & credits |
| `ori`      | `unconfirmedlabs/ori` | Walrus data references |
| `gengo`    | `unconfirmedlabs/gengo` | Language codes |
| `bps`      | `unconfirmedlabs/bps` | Basis-point math |

## Build & test

The Move package lives in [`move/`](./move):

```sh
cd move
sui move build
sui move test
```

The TypeScript SDK lives in [`sdk/`](./sdk):

```sh
cd sdk
bun install
bun run typecheck
```

## Deployment

| Network | Package ID |
|---------|------------|
| testnet | `0x440c9032781ead7ba93402f615aed165dd3f6f5c159d16b22c0c1b6b83a1a87c` |

See [`move/Published.toml`](./move/Published.toml) for the current published metadata.

## Contributing

Issues and pull requests are welcome. By contributing you agree that your contributions are licensed under the project's Apache 2.0 license.

## License

[Apache 2.0](LICENSE) © Miso Labs, Inc.

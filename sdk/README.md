# @misonetwork/miso

TypeScript SDK for the [Miso](https://github.com/misonetwork/miso-protocol) protocol on [Sui](https://sui.io).

This package lives in the [`misonetwork/miso-protocol`](https://github.com/misonetwork/miso-protocol) monorepo alongside the Move protocol package it mirrors (in [`../move`](../move)), so the on-chain ABI and its TypeScript types stay in lockstep.

Miso is a permissionless on-chain music protocol that models compositions, recordings, and releases — and their associated rights and royalties — as Sui objects. This SDK provides typed queries, transaction builders, BCS event parsers, Zod validation schemas, and a composable client extension.

## Installation

```bash
bun add @misonetwork/miso @mysten/sui
```

## Quick Start

```ts
import { SuiGrpcClient } from "@mysten/sui/grpc";
import { miso } from "@misonetwork/miso";

const client = new SuiGrpcClient({ network: "testnet" })
  .$extend(miso({ misoPackageId: "0x..." }));

// Fetch a recording
const recording = await client.miso.getRecordingById("0x...");
console.log(recording.title, recording.state);

// Derive an admin cap ID (pure, no network call)
const adminCapId = client.miso.deriveRecordingAdminCapId("0x...");
```

## Client Extension

The SDK provides a `miso()` client extension that works with any Sui client implementing the Core API:

```ts
import { SuiGrpcClient } from "@mysten/sui/grpc";
import { SuiGraphQLClient } from "@mysten/sui/graphql";
import { miso } from "@misonetwork/miso";

const graphqlClient = new SuiGraphQLClient({
  url: "https://sui-testnet.mystenlabs.com/graphql",
  network: "testnet",
});

const client = new SuiGrpcClient({ network: "testnet" })
  .$extend(miso({
    misoPackageId: "0x...",
    graphqlClient, // Required for type-based queries (getByShareType, getOwned*, etc.)
  }));
```

### API Priority

Methods use the most efficient transport available:

| Transport | When Used | Examples |
|-----------|-----------|----------|
| **Core API** | Single-object fetch by ID, derivation | `getRecordingById`, `deriveCompositionAdminCapId` |
| **Core API** | Non-generic type queries | `getOwnedReleaseAdminCaps` |
| **GraphQL** | Generic type queries (partial type matching) | `getOwnedCompositionAdminCaps`, `getRecordingByShareType` |

## Data Model

Miso stores only protocol-verifiable state. Each entity follows a build-then-freeze
lifecycle (`Initialized → Published`) and is immutable once published.

- **Composition** — the underlying written work. Earns an immutable-floored `royaltyRate` from each recording.
- **Recording** — an audio performance of a composition. Embeds a verified `master` `Audio` and `coverArt`.
- **Release** — a collection of `Disc`s of `Track`s (album, EP, or single), assembled from `Deal`s.
- **Audio** — a standalone, witness-gated primitive (`audio::audio`). Created only via an ingester that attests its `format` and `pcmDigest`.

On publish, each entity emits a single lean pointer event carrying just its identity;
indexers subscribe to that pointer and fetch the immutable object by ID.

## Queries

### Compositions

```ts
// Core API (by ID)
const comp = await client.miso.getCompositionById("0x...");
const capId = client.miso.deriveCompositionAdminCapId("0x...");
const cap = await client.miso.getCompositionAdminCapById(capId);
const shareType = await client.miso.getCompositionShareType("0x...");

// GraphQL (by type or owner)
const comp2 = await client.miso.getCompositionByShareType("0x...::share::SHARE");
const cap2 = await client.miso.getCompositionAdminCapByShareType("0x...::share::SHARE");
const caps = await client.miso.getOwnedCompositionAdminCaps(ownerAddress);
```

### Recordings

```ts
// Core API (by ID)
const rec = await client.miso.getRecordingById("0x...");
const recs = await client.miso.getRecordingsByIds(["0x...", "0x..."]);
const recCapId = client.miso.deriveRecordingAdminCapId("0x...");
const recCap = await client.miso.getRecordingAdminCapById(recCapId);
const recShareType = await client.miso.getRecordingShareType("0x...");

// GraphQL (by type or owner)
const rec2 = await client.miso.getRecordingByShareType("0x...::share::SHARE");
const recCap2 = await client.miso.getRecordingAdminCapByShareType("0x...::share::SHARE");
const recCaps = await client.miso.getOwnedRecordingAdminCaps(ownerAddress);
const administered = await client.miso.getAdministeredRecordings(ownerAddress);
```

### Releases

```ts
// Core API (by ID)
const release = await client.miso.getReleaseById("0x...");
const relCapId = client.miso.deriveReleaseAdminCapId("0x...");
const relCap = await client.miso.getReleaseAdminCapById(relCapId);
const relCaps = await client.miso.getOwnedReleaseAdminCaps(ownerAddress);

// GraphQL
const registry = await client.miso.getReleaseRegistry();
```

### Parties & Share Currencies

```ts
const party = await client.miso.getParty("0x...");
const shareType = await client.miso.getShareCurrencyType("0x...");
const treasuryCap = await client.miso.getShareCurrencyTreasuryCap("0x...", ownerAddress);
```

## Transaction Builders

Build Sui transactions for Miso operations. The `client.miso.tx.*` builders inject
the client automatically; the standalone exports take it explicitly.

```ts
// Publish a composition (creates the share token, adds credits, distributes shares, publishes)
const tx = await client.miso.tx.publishComposition({
  shareCurrencyId: "0x...",
  treasuryCapOwner: ownerAddress,
  title: "Song Title",
  royaltyRateBps: 1000, // 10% — the protocol floor
  credits: [{ partyId: "0x...", displayName: "Writer", roles: ["Composer"] }],
  shareRecipients: [{ address: ownerAddress, value: 10_000_000_000_000 }],
  adminAddress: ownerAddress,
  misoPackageId: "0x...",
  partyOsPackageId: "0x...",
  minatoPackageId: "0x...",
});

// Publish a recording. The core object carries identity, attribution, economics,
// and cover art; masters and descriptive metadata (language, explicitness, …)
// attach afterwards as dynamic fields via extensions (e.g. the audio ingester).
const tx2 = await client.miso.tx.publishRecording({
  compositionId: "0x...",
  compositionShareType: "0x...::share::SHARE",
  shareCurrencyId: "0x...",
  treasuryCapOwner: ownerAddress,
  coverArt: { stillData: { blobId: "987654321" } },
  credits: [{ partyId: "0x...", displayName: "Artist", roles: [{ type: "Vocalist", level: "Lead" }], isPrimaryArtist: true }],
  shareRecipients: [{ address: ownerAddress, value: 10_000_000_000_000 }],
  adminAddress: ownerAddress,
  misoPackageId: "0x...",
  partyOsPackageId: "0x...",
  walrusDataPackageId: "0x...",
  minatoPackageId: "0x...",
});

// Create a Deal (a recording owner authorizing inclusion on a release), then a Release.
const tx3 = client.miso.tx.createDeal({
  recordingId: "0x...",
  recordingAdminCapId: "0x...",
  compositionId: "0x...",
  compositionShareType: "0x...::share::SHARE",
  recordingShareType: "0x...::share::SHARE",
  releaseId: "0x...",      // pre-derived to match release::new
  trackSplitBps: 10_000,
  recipientAddress: releaseCreator,
  misoPackageId: "0x...",
});
```

### Masters and descriptive metadata

Masters are not part of the core `Recording` object: they attach post-publish as dynamic
fields through the audio-ingester extension (which attests the audio in a Nautilus
enclave). Descriptive metadata — language, instrumental status, explicitness, genre —
likewise lives in extension metadata standards rather than in the frozen core. Use the
ingester's own SDK for attaching masters.

## Event Parsers

Miso uses a lean publish-only event model: published objects emit a single pointer event,
and indexers fetch the immutable object by ID. Parse the BCS-encoded events from transaction
results:

```ts
// Pointer events (carry only identities)
const comp = client.miso.parse.compositionPublishedEvent(bcsBytes);  // { compositionId }
const rec = client.miso.parse.recordingPublishedEvent(bcsBytes);     // { recordingId, compositionId }
const rel = client.miso.parse.releasePublishedEvent(bcsBytes);       // { releaseId }

// Non-pointer events
const royalty = client.miso.parse.compositionRoyaltySetEvent(bcsBytes); // royalty rate can change post-publish
const audio = client.miso.parse.audioIngestedEvent(bcsBytes);           // includes format + pcmDigest
const deal = client.miso.parse.dealCreatedEvent(bcsBytes);
const dealGone = client.miso.parse.dealDestroyedEvent(bcsBytes);
```

## Standalone Functions

All client methods are also available as standalone functions for use without the `$extend()` pattern:

```ts
import {
  getRecordingById,
  deriveCompositionAdminCapId,
  getReleaseById,
} from "@misonetwork/miso";

const recording = await getRecordingById(suiClient, "0x...");
const capId = deriveCompositionAdminCapId("0x...", misoPackageId);
```

## Validation Schemas

Zod schemas for validating Miso types:

```ts
import {
  RecordingSchema,
  CompositionSchema,
  ReleaseSchema,
  AudioSchema,
  CompositionCreditSchema,
  RecordingCreditSchema,
} from "@misonetwork/miso/schemas";

const result = RecordingSchema.safeParse(data);
```

## Types

All Miso domain types are exported:

```ts
import type {
  // Core entities
  Composition, Recording, Release, Party,
  // Admin caps
  CompositionAdminCap, RecordingAdminCap, ReleaseAdminCap,
  // Supporting types
  CoverArt, Disc, Track, BPS, WalrusData,
  // Credits & roles
  CompositionCredit, RecordingCredit, ReleaseCredit,
  CompositionPartyRole, RecordingPartyRole, ReleasePartyRole,
  // State machines
  CompositionState, RecordingState, ReleaseState,
  // Events
  CompositionPublishedEvent, CompositionRoyaltySetEvent,
  RecordingPublishedEvent, ReleasePublishedEvent,
  DealCreatedEvent, DealAcceptedEvent, DealRejectedEvent,
} from "@misonetwork/miso";
```

## Derived Objects

Miso uses Sui's derived object pattern for admin caps. The SDK provides pure derivation
functions that compute object IDs without network calls:

| Function | Derivation Key | Parent Object |
|----------|---------------|---------------|
| `deriveCompositionAdminCapId` | `CompositionAdminCapKey()` | Composition |
| `deriveRecordingAdminCapId` | `RecordingAdminCapKey()` | Recording |
| `deriveReleaseAdminCapId` | `ReleaseAdminCapKey()` | Release |

## License

Apache-2.0

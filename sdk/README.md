# @unconfirmed/musicos

TypeScript SDK for the [MusicOS](https://github.com/misonetwork/musicos) protocol on [Sui](https://sui.io).

This package lives in the [`misonetwork/musicos`](https://github.com/misonetwork/musicos) monorepo alongside the Move protocol package it mirrors (in [`../move`](../move)), so the on-chain ABI and its TypeScript types stay in lockstep.

MusicOS is a permissionless on-chain music protocol that models compositions, recordings, and releases — and their associated rights and royalties — as Sui objects. This SDK provides typed queries, transaction builders, BCS event parsers, Zod validation schemas, and a composable client extension.

## Installation

```bash
bun add @unconfirmed/musicos @mysten/sui
```

## Quick Start

```ts
import { SuiGrpcClient } from "@mysten/sui/grpc";
import { musicos } from "@unconfirmed/musicos";

const client = new SuiGrpcClient({ network: "testnet" })
  .$extend(musicos({ musicOsPackageId: "0x..." }));

// Fetch a recording
const recording = await client.musicos.getRecordingById("0x...");
console.log(recording.title, recording.state);

// Derive an admin cap ID (pure, no network call)
const adminCapId = client.musicos.deriveRecordingAdminCapId("0x...");
```

## Client Extension

The SDK provides a `musicos()` client extension that works with any Sui client implementing the Core API:

```ts
import { SuiGrpcClient } from "@mysten/sui/grpc";
import { SuiGraphQLClient } from "@mysten/sui/graphql";
import { musicos } from "@unconfirmed/musicos";

const graphqlClient = new SuiGraphQLClient({
  url: "https://sui-testnet.mystenlabs.com/graphql",
  network: "testnet",
});

const client = new SuiGrpcClient({ network: "testnet" })
  .$extend(musicos({
    musicOsPackageId: "0x...",
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

MusicOS stores only protocol-verifiable state. Each entity follows a build-then-freeze
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
const comp = await client.musicos.getCompositionById("0x...");
const capId = client.musicos.deriveCompositionAdminCapId("0x...");
const cap = await client.musicos.getCompositionAdminCapById(capId);
const shareType = await client.musicos.getCompositionShareType("0x...");

// GraphQL (by type or owner)
const comp2 = await client.musicos.getCompositionByShareType("0x...::share::SHARE");
const cap2 = await client.musicos.getCompositionAdminCapByShareType("0x...::share::SHARE");
const caps = await client.musicos.getOwnedCompositionAdminCaps(ownerAddress);
```

### Recordings

```ts
// Core API (by ID)
const rec = await client.musicos.getRecordingById("0x...");
const recs = await client.musicos.getRecordingsByIds(["0x...", "0x..."]);
const recCapId = client.musicos.deriveRecordingAdminCapId("0x...");
const recCap = await client.musicos.getRecordingAdminCapById(recCapId);
const recShareType = await client.musicos.getRecordingShareType("0x...");

// GraphQL (by type or owner)
const rec2 = await client.musicos.getRecordingByShareType("0x...::share::SHARE");
const recCap2 = await client.musicos.getRecordingAdminCapByShareType("0x...::share::SHARE");
const recCaps = await client.musicos.getOwnedRecordingAdminCaps(ownerAddress);
const administered = await client.musicos.getAdministeredRecordings(ownerAddress);
```

### Releases

```ts
// Core API (by ID)
const release = await client.musicos.getReleaseById("0x...");
const relCapId = client.musicos.deriveReleaseAdminCapId("0x...");
const relCap = await client.musicos.getReleaseAdminCapById(relCapId);
const relCaps = await client.musicos.getOwnedReleaseAdminCaps(ownerAddress);

// GraphQL
const registry = await client.musicos.getReleaseRegistry();
```

### Parties & Share Currencies

```ts
const party = await client.musicos.getParty("0x...");
const shareType = await client.musicos.getShareCurrencyType("0x...");
const treasuryCap = await client.musicos.getShareCurrencyTreasuryCap("0x...", ownerAddress);
```

## Transaction Builders

Build Sui transactions for MusicOS operations. The `client.musicos.tx.*` builders inject
the client automatically; the standalone exports take it explicitly.

```ts
// Publish a composition (creates the share token, adds credits, distributes shares, publishes)
const tx = await client.musicos.tx.publishComposition({
  shareCurrencyId: "0x...",
  treasuryCapOwner: ownerAddress,
  title: "Song Title",
  royaltyRateBps: 1000, // 10% — the protocol floor
  credits: [{ partyId: "0x...", displayName: "Writer", roles: ["Composer"] }],
  shareRecipients: [{ address: ownerAddress, value: 10_000_000_000_000 }],
  adminAddress: ownerAddress,
  musicOsPackageId: "0x...",
  partyOsPackageId: "0x...",
  minatoPackageId: "0x...",
});

// Publish a recording. `master` carries the enclave-attested audio: pass `format`,
// `pcmDigest`, `signature`, and `timestampMs` through verbatim from the ingester response.
const tx2 = await client.musicos.tx.publishRecording({
  compositionId: "0x...",
  compositionShareType: "0x...::share::SHARE",
  shareCurrencyId: "0x...",
  treasuryCapOwner: ownerAddress,
  isExplicit: false,
  isInstrumental: false,
  master: {
    channels: 2,
    bitDepth: 16,
    sampleRateHz: 44_100,
    samples: 9_876_543,
    blobId: "123456789",        // Walrus blob ID as a u256 decimal string
    format: "flac",             // attested by the enclave
    pcmDigest: [/* 32 bytes */], // attested by the enclave
    signature: [/* 64 bytes */], // enclave Ed25519 signature
    timestampMs: 1_700_000_000_000,
  },
  coverArt: { staticData: { blobId: "987654321" } },
  credits: [{ partyId: "0x...", displayName: "Artist", roles: [{ type: "Vocalist", level: "Lead" }], isPrimaryArtist: true }],
  shareRecipients: [{ address: ownerAddress, value: 10_000_000_000_000 }],
  adminAddress: ownerAddress,
  musicOsPackageId: "0x...",
  partyOsPackageId: "0x...",
  walrusDataPackageId: "0x...",
  audioIngesterPackageId: "0x...",
  enclaveId: "0x...",
  minatoPackageId: "0x...",
});

// Create a Deal (a recording owner authorizing inclusion on a release), then a Release.
const tx3 = client.musicos.tx.createDeal({
  recordingId: "0x...",
  recordingAdminCapId: "0x...",
  compositionId: "0x...",
  compositionShareType: "0x...::share::SHARE",
  recordingShareType: "0x...::share::SHARE",
  releaseId: "0x...",      // pre-derived to match release::new
  trackSplitBps: 10_000,
  recipientAddress: releaseCreator,
  musicOsPackageId: "0x...",
});
```

### Audio attestation

`Audio` can only be created through an ingester that cryptographically attests the file.
The ingester (a Nautilus enclave) decodes the audio, computes the Walrus blob ID and a
BLAKE2b-256 `pcmDigest`, then Ed25519-signs an `AudioVerificationPayload`. The builders
forward those attested values into `audio_ingester::ingest` in the exact order the enclave
signed them (`…, blobId, format, pcmDigest, timestampMs, signature, enclave`). Because the
signature covers `format` and `pcmDigest`, they are attested rather than caller-asserted —
pass the ingester's response through unchanged or signature verification will fail.

## Event Parsers

MusicOS uses a lean publish-only event model: published objects emit a single pointer event,
and indexers fetch the immutable object by ID. Parse the BCS-encoded events from transaction
results:

```ts
// Pointer events (carry only identities)
const comp = client.musicos.parse.compositionPublishedEvent(bcsBytes);  // { compositionId }
const rec = client.musicos.parse.recordingPublishedEvent(bcsBytes);     // { recordingId, compositionId }
const rel = client.musicos.parse.releasePublishedEvent(bcsBytes);       // { releaseId }

// Non-pointer events
const royalty = client.musicos.parse.compositionRoyaltySetEvent(bcsBytes); // royalty rate can change post-publish
const audio = client.musicos.parse.audioIngestedEvent(bcsBytes);           // includes format + pcmDigest
const deal = client.musicos.parse.dealCreatedEvent(bcsBytes);
const dealGone = client.musicos.parse.dealDestroyedEvent(bcsBytes);
```

## Standalone Functions

All client methods are also available as standalone functions for use without the `$extend()` pattern:

```ts
import {
  getRecordingById,
  deriveCompositionAdminCapId,
  getReleaseById,
} from "@unconfirmed/musicos";

const recording = await getRecordingById(suiClient, "0x...");
const capId = deriveCompositionAdminCapId("0x...", musicOsPackageId);
```

## Validation Schemas

Zod schemas for validating MusicOS types:

```ts
import {
  RecordingSchema,
  CompositionSchema,
  ReleaseSchema,
  AudioSchema,
  CompositionCreditSchema,
  RecordingCreditSchema,
} from "@unconfirmed/musicos/schemas";

const result = RecordingSchema.safeParse(data);
```

## Types

All MusicOS domain types are exported:

```ts
import type {
  // Core entities
  Composition, Recording, Release, Party,
  // Admin caps
  CompositionAdminCap, RecordingAdminCap, ReleaseAdminCap,
  // Supporting types
  Audio, CoverArt, Disc, Track, BPS, ReleaseKind, WalrusData,
  // Credits & roles
  CompositionCredit, RecordingCredit, ReleaseCredit,
  CompositionPartyRole, RecordingPartyRole, ReleasePartyRole,
  // State machines
  CompositionState, RecordingState, ReleaseState,
  // Events
  CompositionPublishedEvent, CompositionRoyaltySetEvent,
  RecordingPublishedEvent, ReleasePublishedEvent,
  AudioIngestedEvent, DealCreatedEvent, DealDestroyedEvent,
} from "@unconfirmed/musicos";
```

## Derived Objects

MusicOS uses Sui's derived object pattern for admin caps. The SDK provides pure derivation
functions that compute object IDs without network calls:

| Function | Derivation Key | Parent Object |
|----------|---------------|---------------|
| `deriveCompositionAdminCapId` | `CompositionAdminCapKey()` | Composition |
| `deriveRecordingAdminCapId` | `RecordingAdminCapKey()` | Recording |
| `deriveReleaseAdminCapId` | `ReleaseAdminCapKey()` | Release |

## License

Apache-2.0

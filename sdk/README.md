# @misonetwork/miso-protocol

TypeScript SDK for the [Miso](https://github.com/misonetwork/miso-protocol) protocol on [Sui](https://sui.io).

This package lives in the [`misonetwork/miso-protocol`](https://github.com/misonetwork/miso-protocol) monorepo alongside the Move protocol package it mirrors (in [`../move`](../move)), so the on-chain ABI and its TypeScript types stay in lockstep.

Miso is a permissionless on-chain music protocol that models compositions, recordings, and releases — and their associated rights and royalties — as Sui objects. This SDK provides typed queries, composable transaction builders, BCS event parsers, Zod validation schemas, extension helpers (credits, cover art, royalty pools, pressings), and a client extension.

## Installation

```bash
bun add @misonetwork/miso-protocol @mysten/sui
```

## Quick Start

```ts
import { SuiGrpcClient } from "@mysten/sui/grpc";
import { miso } from "@misonetwork/miso-protocol";

const client = new SuiGrpcClient({ network: "testnet" })
  .$extend(miso({ misoPackageId: "0x..." }));

// Fetch a recording
const recording = await client.miso.getRecordingById("0x...");
console.log(recording.state); // display title comes from the parent composition

// Derive an admin cap ID (pure, no network call)
const adminCapId = client.miso.deriveRecordingAdminCapId("0x...");
```

## Client Extension

The SDK provides a `miso()` client extension that works with any Sui client implementing the Core API:

```ts
import { SuiGrpcClient } from "@mysten/sui/grpc";
import { SuiGraphQLClient } from "@mysten/sui/graphql";
import { miso } from "@misonetwork/miso-protocol";

const graphqlClient = new SuiGraphQLClient({
  url: "https://sui-testnet.mystenlabs.com/graphql",
  network: "testnet",
});

const client = new SuiGrpcClient({ network: "testnet" })
  .$extend(miso({
    misoPackageId: "0x...",
    minatoPackageId: "0x...", // Required for the share-dispersing tx builders (publishComposition, publishRecording, publishCompositionAndRecording)
    graphqlClient,            // Required for type-based queries (getByShareType, getOwned*, getReleaseRegistry, getAdministeredRecordings)
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

- **Composition** — the underlying written work. Earns an immutable-floored `royaltyRate` from each recording. Backed by its own share currency.
- **Recording** — an audio performance of a composition. Backed by its own share currency. Carries no name of its own — its display title is its composition's title; richer naming lives in the metadata extension.
- **Release** — a flat, ordered tracklist of `Track`s (album, EP, or single), assembled from `Deal`s. Display grouping (discs/sides) lives in extensions.
- **Deal** — a recording admin's transferable authorization to include the recording on one exact release id.

Everything else — credits, cover art, royalty pools, masters, descriptive
metadata — attaches to the frozen core objects as dynamic fields through
extension packages (see [Extensions](#extensions)).

On publish, each entity emits a single lean pointer event carrying just its identity;
indexers subscribe to that pointer and fetch the immutable object by ID.

## Queries

All client methods are also available as standalone functions (taking the client
explicitly) from the package root.

### Compositions

```ts
// Core API (by ID)
const comp = await client.miso.getCompositionById("0x...");
const comps = await client.miso.getCompositionsByIds(["0x...", "0x..."]);
const capId = client.miso.deriveCompositionAdminCapId("0x...");
const cap = await client.miso.getCompositionAdminCapById(capId);
const shareType = await client.miso.getCompositionShareType("0x...");

// GraphQL (by type or owner)
const comp2 = await client.miso.getCompositionByShareType("0x...::share::Share");
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
const rec2 = await client.miso.getRecordingByShareType("0x...::share::Share");
const recCaps = await client.miso.getOwnedRecordingAdminCaps(ownerAddress);
const administered = await client.miso.getAdministeredRecordings(ownerAddress);
```

### Deals

```ts
// Share types are read from the object's `Deal<RecordingShare, CompositionShare>` type parameters.
const deal = await client.miso.getDealById("0x...");
// { id, releaseId, trackSplitBps, recordingShareType, compositionShareType }
```

### Releases

```ts
// Core API (by ID)
const release = await client.miso.getReleaseById("0x...");
const releases = await client.miso.getReleasesByIds(["0x...", "0x..."]);
const relCapId = client.miso.deriveReleaseAdminCapId("0x...");
const relCap = await client.miso.getReleaseAdminCapById(relCapId);
const relCaps = await client.miso.getOwnedReleaseAdminCaps(ownerAddress);

// GraphQL
const registryId = await client.miso.getReleaseRegistry();
```

### Share currencies

```ts
const shareType = await client.miso.getShareCurrencyType("0x...");  // Currency<T> object id → T
const treasuryCapId = await client.miso.getShareCurrencyTreasuryCap("0x...", ownerAddress);
```

### Missing objects: null vs throw

Core-object getters (`getCompositionById`, `getDealById`, …) **throw** when the
object is missing — a miss means a broken reference. Extension readers
(`getCompositionCredits`, `getReleaseCover`, …) return **`null`** — extension
data is optional by design. `getPressing` is a deliberate null-returning
exception: consumers probe pasted/stored pressing ids. The exported
`isNotFound(e)` helper distinguishes a missing-object error from a transport
failure across all Sui client transports:

```ts
import { isNotFound } from "@misonetwork/miso-protocol";

try {
  await client.miso.getReleaseById(id);
} catch (e) {
  if (isNotFound(e)) { /* no such object */ } else throw e;
}
```

Also exported: `extractTypeParam("p::m::T<A>")` → `"A"` and
`extractTypeParams2("p::m::T<A, B>")` → `["A", "B"]` for reading share types
out of object type tags.

## Transaction Builders

Builders follow the thunk pattern: each returns a `TxThunk` —
`(tx: Transaction) => void | Promise<void>` — that appends commands to a
caller-owned `Transaction`, so flows compose in a single PTB. The
`client.miso.tx.*` builders inject the client's `misoPackageId` (and
`minatoPackageId` where shares are dispersed); the standalone exports take
package ids explicitly.

```ts
import { buildTx, signAndExecute } from "@misonetwork/miso-protocol";

// Publish a composition: mints its share supply, disperses it to
// shareRecipients via minato, publishes (shares) the composition, and
// transfers the CompositionAdminCap to adminAddress.
const thunk = client.miso.tx.publishComposition({
  title: "Song Title",
  royaltyRateBps: 1000, // 10%
  shareType: "0x...::share::Share",   // the composition's share currency
  shareCurrencyId: "0x...",           // its Currency<Share> object
  shareTreasuryCapId: "0x...",        // its TreasuryCap<Share> (consumed)
  shareRecipients: [{ address: ownerAddress, value: 10_000_000_000_000 }],
  adminAddress: ownerAddress,
});

const tx = await buildTx(thunk);
await signAndExecute(client, signer, tx);
```

```ts
// Publish a recording against an already-on-chain composition. The core object
// carries identity and economics; credits, cover art, masters, and descriptive
// metadata attach afterwards via extensions.
client.miso.tx.publishRecording({
  compositionId: "0x...",
  compositionShareType: "0x...::share::Share", // the parent composition's share type
  shareType: "0x...::share::Share",            // the recording's own share currency
  shareCurrencyId: "0x...",
  shareTreasuryCapId: "0x...",
  shareRecipients: [{ address: ownerAddress, value: 10_000_000_000_000 }],
  adminAddress: ownerAddress,
  maxRoyaltyRateBps: 1000, // slippage guard — pass the composition rate you observed
});

// Composition + recording atomically in one PTB (borrow-before-share).
client.miso.tx.publishCompositionAndRecording({
  title: "Song Title",
  royaltyRateBps: 1000,
  composition: { shareType, shareCurrencyId, shareTreasuryCapId, shareRecipients, adminAddress },
  recording: { shareType, shareCurrencyId, shareTreasuryCapId, shareRecipients, adminAddress },
});
```

### Deals

```ts
// A recording owner authorizes inclusion on one exact release id (pre-derived —
// see `view.deriveReleaseId`), and sends the Deal to whoever assembles the release.
client.miso.tx.createDeal({
  recordingId: "0x...",
  recordingAdminCapId: "0x...", // or `recordingAdminCap` as an in-PTB argument
  recordingShareType: "0x...::share::Share",
  compositionShareType: "0x...::share::Share",
  releaseId: "0x...", // pre-derived to match release::new
  trackSplitBps: 5000,
  recipientAddress: releaseCreator,
});

// Reject (destroy) a deal without including it. Emits DealRejectedEvent.
client.miso.tx.rejectDeal({
  dealId: "0x...",
  recordingShareType: "0x...::share::Share",
  compositionShareType: "0x...::share::Share",
});
```

### Releases

```ts
// Publish a release where the sender holds every recording's admin cap
// (deals are created inline).
client.miso.tx.publishRelease({
  title: "Album Title",
  tracks: [{
      recordingId: "0x...",
      recordingAdminCapId: "0x...",
      recordingShareType: "0x...::share::Share",
      compositionShareType: "0x...::share::Share",
      splitBps: 5000,
  }],
  releaseRegistryId: "0x...",
  releaseId: "0x...",    // pre-derived (must match the on-chain derivation)
  releaseNonce: "42",    // u256 as a decimal string
  adminAddress: ownerAddress,
});

// Publish a release from pre-made Deals held by the sender.
client.miso.tx.publishReleaseFromDeals({
  title: "Album Title",
  deals: [{
      dealId: "0x...",
      recordingId: "0x...", // track::new takes &Recording alongside the deal
      recordingShareType: "0x...::share::Share",
      compositionShareType: "0x...::share::Share",
    }],
  }],
  releaseRegistryId: "0x...",
  releaseNonce: "42",
  adminAddress: ownerAddress,
});
```

### Deriving the release id (`view`)

Deals embed the exact release id, which the chain derives from the full
tracklist + nonce. Compute it up front via `simulateTransaction`:

```ts
const releaseId = await client.miso.view.deriveReleaseId({
  sender: ownerAddress,          // any address; not charged
  recordingIds: ["0x...", "0x..."], // in track order
  splitBps: [5000, 5000],           // aligned to recordingIds
  nonce: "42",
  releaseRegistryId: "0x...",
});
```

### Composable primitives

For custom PTBs, the primitives behind the convenience builders are exported:
`newComposition` / `finalizeComposition`, `newRecording` / `finalizeRecording`
(the borrow-before-share pattern), and `disperseShares`.

### Whole-graph publishing (`publishReleaseGraph`)

`publishReleaseGraph` builds an entire release graph — every composition and
recording, optional royalty pools, deals/tracks, and the release, with
the release id derived **on-chain** — in one atomic PTB:

```ts
import { publishReleaseGraph } from "@misonetwork/miso-protocol";

const thunk = publishReleaseGraph({
  compositions: [{ shareType, shareCurrencyId, shareTreasuryCapId, title: "Song", royaltyRateBps: 1000, shareRecipients, adminAddress }],
  recordings: [{ shareType, shareCurrencyId, shareTreasuryCapId, compositionShareType, parentCompositionIndex: 0, shareRecipients, adminAddress }],
  release: {
    title: "Album",
    nonce: "42",
    adminAddress,
    releaseRegistryId: "0x...",
    // Tracks come in three shapes: fresh (created in this PTB, by index),
    // cap-backed (existing recording + admin cap), and deal-backed (pre-made
    // Deal in hand). Deal-backed tracks cannot mix with fresh ones.
    tracks: [{ recordingIndex: 0, splitBps: 10000 }],
  },
  misoPackageId: "0x...",
  minatoPackageId: "0x...",
});
```

## Extensions

### Credits (`credits.ts`)

Contributor credits pair a party with a display name and one or more
domain-specific roles, attached to a work as a dynamic field and gated by the
work's admin cap. Three role vocabularies:

- **Composition** (writing, 1–5 roles, no level): `Adapter`, `Arranger`, `Composer`, `Lyricist`, `Songwriter`, `Translator`, or `{ type: "Custom", name }`.
- **Recording** (production/performance, 1–10 roles): 28 leveled roles (`Producer`, `Vocalist`, `Engineer`, …) each with an optional seniority `level` (`Lead`, `Featured`, `Executive`, …), plus `{ type: "Instrumentalist", instrument, level? }`, `{ type: "Custom", name, level? }`, and the unleveled `ArtistsAndRepertoire` / `Copyist`.
- **Release** (top-line billing, exactly one role): `"Primary"` or `"Featured"`.

Writers validate client-side, mirroring the Move aborts: display name
non-empty and ≤200 UTF-8 bytes; role counts within the caps above; no
duplicate roles.

```ts
import {
  addCompositionCredit, addRecordingCredit, addReleaseCredit,
  addRecordingPrimaryArtist, addRecordingFeaturedArtist,
  getCompositionCredits, getRecordingCredits, getReleaseCredits,
} from "@misonetwork/miso-protocol";

const thunk = addRecordingCredit({
  recordingId: "0x...",
  recordingAdminCapId: "0x...",
  partyId: "0x...",
  displayName: "Jane Doe",
  roles: [{ type: "Vocalist", level: "Lead" }, { type: "Instrumentalist", instrument: "Guitar" }],
  recordingShareType: "0x...::share::Share",
  compositionShareType: "0x...::share::Share",
  recordingCreditsPackageId: "0x...",
  misoCreditPackageId: "0x...",
});

// Designate an already-credited party (same params minus displayName/roles/misoCreditPackageId):
addRecordingPrimaryArtist({ recordingId, recordingAdminCapId, partyId, recordingShareType, compositionShareType, recordingCreditsPackageId });

// Reads return null when no credits field is attached.
const credits = await getCompositionCredits(client, compositionId, compositionCreditsPackageId);
// CreditView[]: { partyId, displayName, roles: string[] } — e.g. "Producer (Lead)", "Instrumentalist: Guitar"
const rc = await getRecordingCredits(client, recordingId, recordingCreditsPackageId);
// { credits: CreditView[], primaryArtistIds: string[], featuredArtistIds: string[] }
```

`addCompositionCredit` takes `compositionId`/`compositionAdminCapId`/`compositionShareType`/`compositionCreditsPackageId`;
`addReleaseCredit` takes `releaseId`/`releaseAdminCapId` and a single `role`.

### Cover art (`cover.ts`)

A release's cover is a Walrus blob referenced on-chain via `ori::WalrusData`,
attached under the `release_cover_art` extension:

```ts
import { setReleaseCover, getReleaseCover } from "@misonetwork/miso-protocol";

const thunk = setReleaseCover({
  releaseId: "0x...",
  releaseAdminCapId: "0x...",
  stillBlobId: "987654321",   // Walrus blob id as u256 (decimal string or bigint)
  animatedBlobId: null,        // optional animated cover
  coverArtPackageId: "0x...",
  releaseCoverArtPackageId: "0x...",
  oriPackageId: "0x...",
});

const cover = await getReleaseCover(client, releaseId, releaseCoverArtPackageId);
// ReleaseCoverView | null: { still, animated } as normalized Walrus refs
// ({ kind: "blob", blobId } | { kind: "quiltPatch", quiltId, version, startIndex, endIndex })
```

### Pressing (`pressing.ts`)

A `Pressing<Currency>` is a shared object selling copies of a release's records
at a fixed or floor price within an optional sale window:

```ts
import { createPressing, buyRecord, getPressing } from "@misonetwork/miso-protocol";

createPressing({
  registryId: "0x...",         // the shared PressingRegistry
  releaseId: "0x...",
  releaseAdminCapId: "0x...",
  price: { kind: "fixed", amount: 5_000_000n }, // or { kind: "floor", ... }
  currencyType: "0x2::sui::SUI",
  edition: 0,                   // optional; editions must be gap-free
  startTimestampMs: 0,          // optional
  endTimestampMs: null,         // optional; null = evergreen
  misoPressingPackageId: "0x...",
});

buyRecord({
  pressingId: "0x...",
  paymentCoinIds: ["0x..."],   // merged, then split to `amount`
  amount: 5_000_000n,
  currencyType: "0x2::sui::SUI",
  settingsId: "0x...",         // the miso_record Settings shared object
  recipient: buyerAddress,
  misoPressingPackageId: "0x...",
});

const p = await getPressing(client, pressingId); // PressingView | null (null when it doesn't exist)
```

### Royalty pools (`extensions/royalty-pool.ts`)

`attachCompositionRoyaltyPool(tx, params)` / `attachRecordingRoyaltyPool(tx, params)`
create and share a `RoyaltyPool<Share, Currency>` for a work inside its publish
PTB (after `new*`, before `finalize*`). `publishReleaseGraph` accepts them as
`royaltyPool` nodes.

## Share Currency Provisioning (`share.ts`)

Every composition and recording is backed by its own fixed-supply share
currency: an independently published `share` package (bytecode template
embedded as `SHARE_TEMPLATE`, initializer patched via `patchInitializer`).
Publish and initialize are necessarily two transactions:

```ts
// Sequential (one currency, two txs):
const currency = await client.miso.createShareCurrency(signer, {
  name: "Song Shares",
  description: "…",
});
// → { packageId, currencyId, shareType, treasuryCapId, gasUsed }

// Batched (many currencies, via a ParallelTransactionExecutor):
import { publishShareCurrencies, initializeShareCurrencies } from "@misonetwork/miso-protocol";
const { packageIds } = await publishShareCurrencies(executor, initializerAddress, 10);
const { currencies } = await initializeShareCurrencies(executor, signerAddress, packageIds, (pkg) => ({
  name: "…", description: "…",
}));
```

## Execution (`execute.ts`)

Builders only append to a `Transaction`; this module submits:

```ts
import { buildTx, signAndExecute, execThunks, executeViaExecutor, publishedPackageId, createdByType, balanceDelta } from "@misonetwork/miso-protocol";

const result = await execThunks(client, signer, thunkA, thunkB); // build + sign + execute + wait
// ExecResult: { digest, changedObjects, objectTypes, balanceChanges, gasUsed }

// Object-change extractors:
const pkgId = publishedPackageId(result);
const currencyId = createdByType(result, "::coin_registry::Currency<");
const delta = balanceDelta(result, address, "0x2::sui::SUI");
```

`executeViaExecutor(executor, ...thunks)` submits a non-idempotent PTB through a
`ParallelTransactionExecutor` exactly once (no auto-retry — see its doc comment).

## Event Parsers

Miso uses a lean publish-only event model: published objects emit a single pointer event,
and indexers fetch the immutable object by ID. Parse the BCS-encoded events from transaction
results:

```ts
// Pointer events (carry only identities)
const comp = client.miso.parse.compositionPublishedEvent(bcsBytes);  // { compositionId }
const rec = client.miso.parse.recordingPublishedEvent(bcsBytes);     // { recordingId }
const rel = client.miso.parse.releasePublishedEvent(bcsBytes);       // { releaseId }

// Non-pointer events
const royalty = client.miso.parse.compositionRoyaltySetEvent(bcsBytes); // { royaltyRateBps }
const created = client.miso.parse.dealCreatedEvent(bcsBytes);   // { dealId, releaseId, trackSplitBps }
const accepted = client.miso.parse.dealAcceptedEvent(bcsBytes); // { dealId, releaseId }
const rejected = client.miso.parse.dealRejectedEvent(bcsBytes); // { dealId, releaseId }
```

The same functions are exported standalone as `parseCompositionPublishedEvent`, etc.

## Validation Schemas

Zod schemas for validating Miso domain types and parsed events:

```ts
import {
  CompositionSchema, RecordingSchema, ReleaseSchema, TrackSchema,
  CompositionStateSchema, RecordingStateSchema, ReleaseStateSchema,
  CompositionPublishedEventSchema, CompositionRoyaltySetEventSchema,
  RecordingPublishedEventSchema, ReleasePublishedEventSchema,
  DealCreatedEventSchema, DealAcceptedEventSchema, DealRejectedEventSchema,
} from "@misonetwork/miso-protocol/schemas";

const result = RecordingSchema.safeParse(data);
```

## Types

All Miso domain types are exported:

```ts
import type {
  // Core entities
  Composition, Recording, Release, Deal, Track, BPS,
  // Admin caps
  CompositionAdminCap, RecordingAdminCap, ReleaseAdminCap,
  // State machines
  CompositionState, RecordingState, ReleaseState, TrackState,
  // Events
  CompositionPublishedEvent, CompositionRoyaltySetEvent,
  RecordingPublishedEvent, ReleasePublishedEvent,
  DealCreatedEvent, DealAcceptedEvent, DealRejectedEvent,
  // Credits & roles (from ./credits)
  CreditView, RecordingCreditsView,
  CompositionRole, RecordingRole, RecordingRoleLevel, ReleaseRole,
  // Extension views
  ReleaseCoverView, CoverImageRef, PressingView,
} from "@misonetwork/miso-protocol";
```

## Generated Bindings (`contracts`)

The codegen-generated, ABI-bound bindings (BCS structs + type-safe Move calls)
are exported under the `contracts` namespace — core protocol modules
(`composition`, `recording`, `release`, `deal`, `track`, `disc`) plus the
extension packages (`pressing`, `royaltyPool`, `compositionRoyaltyPool`,
`recordingRoyaltyPool`, `coverArt`, `releaseCoverArt`, `compositionCredits`,
`recordingCredits`, `releaseCredits`, and their role modules):

```ts
import { contracts } from "@misonetwork/miso-protocol";

const parsed = contracts.composition.Composition.parse(bcsBytes);
tx.add(contracts.deal.reject({ package: misoPackageId, typeArguments, arguments: [dealId] }));
```

On the client, `client.miso.call.*` exposes the core modules with the package
id pre-bound, and `client.miso.bcs.*` the core BCS structs.

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

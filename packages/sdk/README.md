# @musicos/sdk

TypeScript SDK for interacting with MusicOS smart contracts on Sui.

## Installation

```bash
npm install @musicos/sdk @mysten/sui
```

## Quick Start

```typescript
import { MusicOSClient } from "@musicos/sdk";
import { SuiClient } from "@mysten/sui/client";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";

// Initialize client
const client = new MusicOSClient({
  packageId: "0x...", // MusicOS package ID
});

const suiClient = new SuiClient({ url: "https://fullnode.testnet.sui.io" });
const keypair = Ed25519Keypair.generate();

// Create a contributor (artist)
const createTx = client.contributors.create({
  kind: "individual",
  name: "Artist Name",
});

await suiClient.signAndExecuteTransaction({
  transaction: createTx,
  signer: keypair,
});
```

## Features

### Contributors

Create and manage artists, producers, and groups:

```typescript
// Create an individual contributor
const tx = client.contributors.create({
  kind: "individual",
  name: "John Doe",
});

// Create a group (band)
const groupTx = client.contributors.create({
  kind: "group",
  name: "The Band",
});

// Add members to a group
const addMemberTx = client.contributors.addMember({
  groupId: "0x...",
  adminCapId: "0x...",
  memberId: "0x...", // Individual contributor ID
});
```

### Compositions

Create musical compositions with share tokens:

```typescript
// Create a composition (requires pre-created share currency)
const tx = client.compositions.create({
  title: "My Song",
  splitBps: 5000, // 50% to composition, 50% to recording
  shareCurrencyId: "0x...",
  shareTreasuryCapId: "0x...",
  shareType: "0xabc::my_comp_share::SHARE",
});

// Add a credit
const creditTx = client.compositions.addCredit({
  compositionId: "0x...",
  adminCapId: "0x...",
  contributorId: "0x...",
  credit: {
    displayName: "John Doe",
    roles: ["composer", "lyricist"],
  },
  shareType: "0xabc::my_comp_share::SHARE",
});

// Publish (makes it immutable)
const publishTx = client.compositions.publish({
  compositionId: "0x...",
  adminCapId: "0x...",
  shareType: "0xabc::my_comp_share::SHARE",
});
```

### Recordings

Create audio recordings with the fluent builder:

```typescript
import { RecordingBuilder } from "@musicos/sdk";

const tx = new RecordingBuilder({
  packageId: "0x...",
  compositionId: "0x...",
  compositionShareType: "0xabc::my_comp_share::SHARE",
  genreId: "0x...", // Genre object ID (e.g., ROCK)
  master: {
    channels: 2,
    bitDepth: 24,
    sampleRateHz: 48000,
    samples: 14400000n,
    data: { blobId: "walrus-blob-id", endEpoch: 100 },
    pcmDigest: new Uint8Array(32),
  },
  coverArt: {
    static: { blobId: "cover-blob-id", endEpoch: 100 },
  },
  shareCurrencyId: "0x...",
  shareTreasuryCapId: "0x...",
  shareType: "0xdef::my_rec_share::SHARE",
})
  .title("My Song (Radio Edit)")
  .titleVersion("Radio Edit")
  .language("en")
  .addCredit(artistId, {
    displayName: "Artist Name",
    roles: [{ type: "vocalist", level: "lead" }],
  })
  .addCredit(producerId, {
    displayName: "Producer Name",
    roles: [{ type: "producer" }],
  })
  .addPrimaryArtist(artistId)
  .tempoBpm(120)
  .musicalKey({ note: "C", accidental: "natural", mode: "major" })
  .timeSignature(4, 4)
  .buildAndPublish();
```

### Releases

Create albums, EPs, and singles:

```typescript
const tx = client.releases.create({
  kind: "album",
  title: "My Album",
  coverArt: {
    static: { blobId: "album-cover-blob", endEpoch: 100 },
  },
  discs: [
    {
      tracks: [
        {
          recordingId: "0x...",
          recordingAdminCapId: "0x...",
          recordingShareType: "0xdef::my_rec_share::SHARE",
        },
        // ... more tracks
      ],
    },
  ],
});

// Set revenue splits (must sum to 10000 = 100%)
const splitsTx = client.releases.setTrackSplitsBps({
  releaseId: "0x...",
  adminCapId: "0x...",
  splits: [5000, 3000, 2000], // 50%, 30%, 20%
});

// Publish the release
const publishTx = client.releases.publish({
  releaseId: "0x...",
  adminCapId: "0x...",
});
```

## Types

The SDK exports all TypeScript types for type-safe development:

```typescript
import type {
  Audio,
  CoverArt,
  MusicalKey,
  RecordingRole,
  CompositionRole,
  // ... many more
} from "@musicos/sdk";
```

## Utilities

Helper functions for building Move structs:

```typescript
import {
  makeAudio,
  makeCoverArt,
  makeMusicalKey,
  calculateDurationMs,
} from "@musicos/sdk";
```

## License

Apache-2.0

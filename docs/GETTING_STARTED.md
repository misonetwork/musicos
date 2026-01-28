# Getting Started with MusicOS

This guide walks you through creating and publishing music on the MusicOS protocol.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Quick Start](#quick-start)
4. [Step-by-Step Tutorial](#step-by-step-tutorial)
5. [Common Workflows](#common-workflows)
6. [Troubleshooting](#troubleshooting)

---

## Prerequisites

Before you begin, ensure you have:

- **Node.js** 18+ installed
- **A Sui wallet** with SUI tokens for gas fees
- **Access to Walrus** for storing audio files and artwork
- Basic familiarity with TypeScript and blockchain transactions

---

## Installation

### Install the SDK

```bash
npm install @musicos/sdk @mysten/sui
```

### Set Up Your Environment

```typescript
import { MusicOSClient } from "@musicos/sdk";
import { SuiClient, getFullnodeUrl } from "@mysten/sui/client";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";

// Initialize Sui client
const suiClient = new SuiClient({
  url: getFullnodeUrl("testnet")
});

// Initialize MusicOS client
const musicOS = new MusicOSClient({
  packageId: "0x...", // MusicOS package ID on your network
});

// Your wallet keypair (for signing transactions)
const keypair = Ed25519Keypair.deriveKeypair("your mnemonic phrase here");
```

---

## Quick Start

Here's the simplest possible example - creating a contributor (artist):

```typescript
import { MusicOSClient } from "@musicos/sdk";
import { SuiClient } from "@mysten/sui/client";

const suiClient = new SuiClient({ url: "https://fullnode.testnet.sui.io" });
const musicOS = new MusicOSClient({ packageId: "0x..." });

// Create an individual contributor
const tx = musicOS.contributors.create({
  kind: "individual",
  name: "Jane Doe",
});

// Sign and execute
const result = await suiClient.signAndExecuteTransaction({
  transaction: tx,
  signer: keypair,
});

console.log("Created contributor:", result.digest);
```

---

## Step-by-Step Tutorial

This tutorial walks through creating a complete single release from scratch.

### Step 1: Create Contributors

First, create the artists and producers who will be credited on your music.

```typescript
// Create the main artist
const artistTx = musicOS.contributors.create({
  kind: "individual",
  name: "Alex Rivera",
});

const artistResult = await suiClient.signAndExecuteTransaction({
  transaction: artistTx,
  signer: keypair,
});

// Extract the created contributor ID from events
const artistId = extractCreatedObjectId(artistResult, "Party");

// Create the producer
const producerTx = musicOS.contributors.create({
  kind: "individual",
  name: "Sam Chen",
});

const producerResult = await suiClient.signAndExecuteTransaction({
  transaction: producerTx,
  signer: keypair,
});

const producerId = extractCreatedObjectId(producerResult, "Party");
```

### Step 2: Create a Share Token for the Composition

Each composition needs its own fungible token for ownership shares. This is done by publishing a Move module.

```move
// composition_share.move
module your_package::composition_share {
    use sui::coin;

    public struct COMPOSITION_SHARE has drop {}

    fun init(witness: COMPOSITION_SHARE, ctx: &mut TxContext) {
        let (treasury_cap, metadata) = coin::create_currency(
            witness,
            6,                    // decimals
            b"SHARE",            // symbol
            b"Composition Share", // name
            b"",                 // description
            option::none(),      // icon_url
            ctx,
        );

        // Transfer to sender
        transfer::public_transfer(treasury_cap, tx_context::sender(ctx));
        transfer::public_share_object(metadata);
    }
}
```

After publishing, you'll have:
- `shareCurrencyId` - The Currency object ID
- `shareTreasuryCapId` - The TreasuryCap object ID
- `shareType` - The full type string (e.g., `0xabc::composition_share::COMPOSITION_SHARE`)

### Step 3: Create the Composition

```typescript
const compositionTx = musicOS.compositions.create({
  title: "Midnight Dreams",
  splitBps: 5000, // 50% to composition, 50% to recording
  shareCurrencyId: "0x...",      // From Step 2
  shareTreasuryCapId: "0x...",   // From Step 2
  shareType: "0x...::composition_share::COMPOSITION_SHARE",
});

const compResult = await suiClient.signAndExecuteTransaction({
  transaction: compositionTx,
  signer: keypair,
});

const compositionId = extractCreatedObjectId(compResult, "Composition");
const compositionAdminCapId = extractCreatedObjectId(compResult, "CompositionAdminCap");

// The share tokens are returned to your address
const compositionShareBalance = extractCreatedObjectId(compResult, "Coin");
```

### Step 4: Add Credits to the Composition

```typescript
const creditTx = musicOS.compositions.addCredit({
  compositionId,
  adminCapId: compositionAdminCapId,
  contributorId: artistId,
  credit: {
    displayName: "Alex Rivera",
    roles: ["composer", "lyricist"],
  },
  shareType: "0x...::composition_share::COMPOSITION_SHARE",
});

await suiClient.signAndExecuteTransaction({
  transaction: creditTx,
  signer: keypair,
});
```

### Step 5: Publish the Composition

```typescript
const publishCompTx = musicOS.compositions.publish({
  compositionId,
  adminCapId: compositionAdminCapId,
  shareType: "0x...::composition_share::COMPOSITION_SHARE",
});

await suiClient.signAndExecuteTransaction({
  transaction: publishCompTx,
  signer: keypair,
});
```

### Step 6: Create a Share Token for the Recording

Similar to Step 2, create another share token module for the recording.

### Step 7: Create the Recording

Use the `RecordingBuilder` for a cleaner API:

```typescript
import { RecordingBuilder } from "@musicos/sdk";

const recordingTx = new RecordingBuilder({
  packageId: "0x...",
  compositionId,
  compositionShareType: "0x...::composition_share::COMPOSITION_SHARE",
  genreId: "0x...", // Genre object ID (e.g., ROCK)
  master: {
    channels: 2,
    bitDepth: 24,
    sampleRateHz: 48000,
    samples: 14400000n, // 5 minutes at 48kHz
    data: {
      blobId: "walrus-blob-id-for-audio",
      endEpoch: 100
    },
    pcmDigest: audioDigest, // 32-byte hash of PCM data
  },
  coverArt: {
    static: {
      blobId: "walrus-blob-id-for-cover",
      endEpoch: 100
    },
  },
  shareCurrencyId: "0x...",
  shareTreasuryCapId: "0x...",
  shareType: "0x...::recording_share::RECORDING_SHARE",
})
  .title("Midnight Dreams")
  .titleVersion("Original Mix")
  .language("en")
  .explicit(false)
  .instrumental(false)
  // Add artist credit
  .addCredit(artistId, {
    displayName: "Alex Rivera",
    roles: [{ type: "vocalist", level: "lead" }],
  })
  // Add producer credit
  .addCredit(producerId, {
    displayName: "Sam Chen",
    roles: [{ type: "producer" }, { type: "mixingEngineer" }],
  })
  // Mark as primary artist
  .addPrimaryArtist(artistId)
  // Musical metadata
  .tempoBpm(120)
  .musicalKey({ note: "A", accidental: "natural", mode: "minor" })
  .timeSignature(4, 4)
  // Build and publish in one transaction
  .buildAndPublish();

const recResult = await suiClient.signAndExecuteTransaction({
  transaction: recordingTx,
  signer: keypair,
});

const recordingId = extractCreatedObjectId(recResult, "Recording");
const recordingAdminCapId = extractCreatedObjectId(recResult, "RecordingAdminCap");
```

### Step 8: Create the Release

```typescript
const releaseTx = musicOS.releases.create({
  kind: "single",
  title: "Midnight Dreams - Single",
  coverArt: {
    static: { blobId: "walrus-blob-id-for-release-cover", endEpoch: 100 },
  },
  discs: [
    {
      tracks: [
        {
          recordingId,
          recordingAdminCapId,
          recordingShareType: "0x...::recording_share::RECORDING_SHARE",
        },
      ],
    },
  ],
});

const releaseResult = await suiClient.signAndExecuteTransaction({
  transaction: releaseTx,
  signer: keypair,
});

const releaseId = extractCreatedObjectId(releaseResult, "Release");
const releaseAdminCapId = extractCreatedObjectId(releaseResult, "ReleaseAdminCap");
```

### Step 9: Set Track Splits and Publish

```typescript
// Set track splits (100% to our single track)
const splitsTx = musicOS.releases.setTrackSplitsBps({
  releaseId,
  adminCapId: releaseAdminCapId,
  splits: [10000], // 100% to track 1
});

await suiClient.signAndExecuteTransaction({
  transaction: splitsTx,
  signer: keypair,
});

// Publish the release
const publishReleaseTx = musicOS.releases.publish({
  releaseId,
  adminCapId: releaseAdminCapId,
});

await suiClient.signAndExecuteTransaction({
  transaction: publishReleaseTx,
  signer: keypair,
});
```

Your music is now published on-chain.

---

## Common Workflows

### Creating an Album

```typescript
const releaseTx = musicOS.releases.create({
  kind: "album",
  title: "Full Album Title",
  coverArt: { /* ... */ },
  discs: [
    {
      tracks: [
        { recordingId: track1Id, recordingAdminCapId: cap1, recordingShareType: type1 },
        { recordingId: track2Id, recordingAdminCapId: cap2, recordingShareType: type2 },
        { recordingId: track3Id, recordingAdminCapId: cap3, recordingShareType: type3 },
        // ... up to 50 tracks per disc
      ],
    },
  ],
});

// Set splits (must sum to 10000)
const splitsTx = musicOS.releases.setTrackSplitsBps({
  releaseId,
  adminCapId,
  splits: [1500, 2000, 1500, 2000, 1500, 1500], // Percentages for each track
});
```

### Creating a Band (Group)

```typescript
// Create individual members first
const member1Tx = musicOS.contributors.create({ kind: "individual", name: "Member 1" });
const member2Tx = musicOS.contributors.create({ kind: "individual", name: "Member 2" });

// Create the group
const bandTx = musicOS.contributors.create({ kind: "group", name: "The Band" });

// Add members to the group
const addMemberTx = musicOS.contributors.addMember({
  groupId: bandId,
  adminCapId: bandAdminCapId,
  memberId: member1Id,
});
```

### Distributing Revenue

When your release receives payments:

```typescript
// Revenue is sent to the release address
// Then call distribute_revenue to split it

const distributeTx = musicOS.releases.distributeRevenue({
  releaseId,
  coinType: "0x2::sui::SUI",
  value: 1000000000, // 1 SUI
});

await suiClient.signAndExecuteTransaction({
  transaction: distributeTx,
  signer: keypair,
});

// Revenue is now split:
// - Between tracks (based on track_splits_bps)
// - Between composition and recording (based on composition_split_bps)
// - Into their respective reward pools
```

### Adding Multiple Genres

```typescript
const builder = new RecordingBuilder({ /* ... */ })
  // Primary genre is set in constructor via genreId
  .addSecondaryGenre(electronicGenreId)
  .addSecondaryGenre(popGenreId);
```

### Adding Audio Stems

```typescript
const builder = new RecordingBuilder({ /* ... */ })
  .addStem({
    description: "Vocals",
    audio: {
      channels: 2,
      bitDepth: 24,
      sampleRateHz: 48000,
      samples: 14400000n,
      data: { blobId: "vocals-blob", endEpoch: 100 },
      pcmDigest: vocalsDigest,
    },
  })
  .addStem({
    description: "Drums",
    audio: { /* ... */ },
  })
  .addStem({
    description: "Bass",
    audio: { /* ... */ },
  });
// Up to 10 stems per recording
```

---

## Troubleshooting

### Common Errors

#### `ENotInitializedState` (Error 1)

**Cause:** Trying to modify an entity that has already been published.

**Solution:** All modifications must be made before calling `publish()`. Published entities are immutable.

#### `ENoParties` (Error 20)

**Cause:** Trying to publish without adding any credits.

**Solution:** Add at least one credit before publishing:
```typescript
musicOS.compositions.addCredit({ /* ... */ });
```

#### `ENoPrimaryArtistAssigned` (Error 21)

**Cause:** Trying to publish a recording without a primary artist.

**Solution:** Mark at least one credited party as a primary artist:
```typescript
builder.addCredit(artistId, { /* ... */ })
       .addPrimaryArtist(artistId);
```

#### `EInvalidTrackSplitsSum` (Error 21)

**Cause:** Track splits don't sum to exactly 10000 (100%).

**Solution:** Ensure all splits add up to 10000:
```typescript
// Wrong: 5000 + 3000 = 8000
splits: [5000, 3000]

// Correct: 5000 + 3000 + 2000 = 10000
splits: [5000, 3000, 2000]
```

#### `EPartyNotCredited` (Error 22)

**Cause:** Trying to mark someone as primary/featured artist before adding their credit.

**Solution:** Add the credit first:
```typescript
// Wrong order:
builder.addPrimaryArtist(artistId);  // Error!

// Correct order:
builder.addCredit(artistId, { /* ... */ })
       .addPrimaryArtist(artistId);  // Works!
```

#### `EUnauthorized` (Error 0)

**Cause:** Using the wrong admin capability for an entity.

**Solution:** Ensure you're using the admin cap that was created with the entity:
```typescript
// Each entity has its own admin cap
musicOS.compositions.publish({
  compositionId: comp1Id,
  adminCapId: comp1AdminCapId,  // Must match!
});
```

### Debugging Tips

1. **Check transaction digest:** Use Sui Explorer to view detailed transaction results
2. **Verify object IDs:** Ensure you're using the correct IDs from creation transactions
3. **Review state:** Check if the entity is in the expected state before operations
4. **Validate splits:** Use a simple sum to verify splits equal 10000

### Getting Help

- **GitHub Issues:** https://github.com/anthropics/claude-code/issues
- **Documentation:** See the [Architecture](./ARCHITECTURE.md) and [API Reference](./API_REFERENCE.md)

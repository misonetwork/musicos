# MusicOS Architecture Documentation

This document provides a detailed technical overview of the MusicOS protocol architecture, smart contract design, and implementation patterns.

## Table of Contents

1. [System Overview](#system-overview)
2. [Domain Model](#domain-model)
3. [Smart Contract Modules](#smart-contract-modules)
4. [State Machine Design](#state-machine-design)
5. [Share Token System](#share-token-system)
6. [Revenue Distribution](#revenue-distribution)
7. [Authorization Model](#authorization-model)
8. [Extension System](#extension-system)
9. [TypeScript SDK](#typescript-sdk)
10. [Integration Patterns](#integration-patterns)

---

## System Overview

MusicOS is a blockchain-based music protocol built on the **Sui network** that manages the complete lifecycle of music assets—from compositions and recordings to releases—with transparent, automated royalty distribution.

### Design Principles

1. **Immutability** - Published works become permanent, unalterable on-chain records
2. **Transparency** - All state changes emit events for full auditability
3. **Precision** - Basis points (BPS) system ensures accurate financial calculations
4. **Modularity** - Clean separation of concerns across 19 specialized modules
5. **Extensibility** - Dynamic fields and plugin extensions enable growth without protocol changes
6. **Authorization** - Capability-based security at every level

### Technology Stack

- **Blockchain**: Sui Network (Move language)
- **External Storage**: Walrus for audio files and artwork
- **SDK**: TypeScript with `@mysten/sui` client library
- **Financial Math**: `interest_bps` library for basis point calculations
- **Internationalization**: ISO 639-1 language codes via `language_code` library

---

## Domain Model

The MusicOS domain model reflects the real-world music industry hierarchy:

```
┌─────────────────────────────────────────────────────────────────┐
│                           RELEASE                                │
│  (Album / EP / Single)                                          │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                        DISC(s)                           │   │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐                 │   │
│  │  │  TRACK  │  │  TRACK  │  │  TRACK  │  ...            │   │
│  │  └────┬────┘  └────┬────┘  └────┬────┘                 │   │
│  └───────┼────────────┼────────────┼───────────────────────┘   │
└──────────┼────────────┼────────────┼────────────────────────────┘
           │            │            │
           ▼            ▼            ▼
      ┌─────────┐  ┌─────────┐  ┌─────────┐
      │RECORDING│  │RECORDING│  │RECORDING│
      └────┬────┘  └────┬────┘  └────┬────┘
           │            │            │
           ▼            ▼            ▼
      ┌───────────┐ ┌───────────┐ ┌───────────┐
      │COMPOSITION│ │COMPOSITION│ │COMPOSITION│
      └───────────┘ └───────────┘ └───────────┘
```

### Entity Relationships

| Entity | Description | Ownership |
|--------|-------------|-----------|
| **Composition** | The underlying written musical work (song, lyrics) | Has own share token |
| **Recording** | An audio performance of a composition | Has own share token, references composition |
| **Release** | A published collection of tracks | Contains discs and tracks |
| **Disc** | Organization unit within a release | Contains tracks (max 50) |
| **Track** | Links a recording to its position in a release | Caches composition/recording metadata |
| **Party** | Individual or group participant | Can be credited on compositions/recordings |

---

## Smart Contract Modules

MusicOS consists of 19 Move modules organized into functional categories:

### Core Domain Entities

#### `composition.move`

The foundational module for musical works.

**Struct: `Composition<CompositionShare>`**
```move
public struct Composition<phantom CompositionShare> has key {
    id: UID,
    state: CompositionState,
    title: String,
    alternate_titles: vector<String>,
    credits: VecMap<ID, Credit<CompositionPartyRole>>,
    split_bps: BPS,
    lyrics: Option<WalrusData>,
}
```

**Key Functions:**
| Function | Description | State Required |
|----------|-------------|----------------|
| `new()` | Creates composition with share tokens | - |
| `publish()` | Makes composition immutable, shares object | Initialized |
| `add_credit()` | Adds party with roles | Initialized |
| `set_split_bps()` | Sets revenue split rate | Initialized |
| `add_alternate_title()` | Adds alternate title | Initialized |
| `set_lyrics()` | Sets lyrics reference | Initialized |

**Events:**
- `CompositionInitializedEvent` - Emitted on creation
- `CompositionPublishedEvent` - Emitted on publish
- `CompositionPartyAddedEvent` - Emitted when party added
- `CompositionSplitSetEvent` - Emitted when split updated

---

#### `recording.move`

Audio performances of compositions with extensive metadata.

**Struct: `Recording<RecordingShare>`**
```move
public struct Recording<phantom RecordingShare> has key {
    id: UID,
    state: RecordingState,
    title: String,
    title_version: Option<String>,
    subtitle: Option<String>,
    composition_id: ID,
    composition_share_type: TypeName,
    composition_split_bps: BPS,
    primary_genre_id: ID,
    secondary_genre_ids: VecSet<ID>,
    primary_artist_ids: VecSet<ID>,
    featured_artist_ids: VecSet<ID>,
    credits: VecMap<ID, Credit<RecordingPartyRole>>,
    language: Option<LanguageCode>,
    is_explicit: bool,
    is_instrumental: bool,
    musical_key: Option<MusicalKey>,
    time_signature: Option<TimeSignature>,
    tempo_bpm: Option<u16>,
    master: Audio,
    stems: vector<Stem>,
    cover_art: CoverArt,
}
```

**Key Functions:**
| Function | Description | State Required |
|----------|-------------|----------------|
| `new()` | Creates recording linked to composition | - |
| `publish()` | Makes recording immutable | Initialized |
| `add_credit()` | Adds party with roles (1-10 roles) | Initialized |
| `add_primary_artist()` | Marks party as primary artist | Initialized |
| `add_featured_artist()` | Marks party as featured artist | Initialized |
| `set_primary_genre()` | Sets primary genre | Initialized |
| `add_secondary_genre()` | Adds secondary genre | Initialized |
| `set_musical_key()` | Sets musical key (e.g., C Major) | Initialized |
| `set_time_signature()` | Sets time signature (e.g., 4/4) | Initialized |
| `set_tempo_bpm()` | Sets tempo in BPM | Initialized |
| `add_stem()` | Adds audio stem (up to 10) | Initialized |

**Important:** When a recording is created, it captures the composition's `split_bps` at that moment. Subsequent changes to the composition's split do not affect existing recordings.

---

#### `release.move`

Published collections of tracks with revenue distribution.

**Struct: `Release`**
```move
public struct Release has key {
    id: UID,
    kind: ReleaseKind,
    state: ReleaseState,
    title: String,
    subtitle: Option<String>,
    discs: vector<Disc>,
    track_sequence: TrackSequence,
    track_splits_bps: vector<BPS>,
    cover_art: CoverArt,
}
```

**Release Kinds:**
- `Album` - Full-length release (typically 7+ tracks)
- `EP` - Extended play (typically 3-6 tracks)
- `Single` - One or two tracks

**Key Functions:**
| Function | Description | State Required |
|----------|-------------|----------------|
| `new()` | Creates release with discs and tracks | - |
| `publish()` | Makes release immutable | Initialized |
| `set_track_splits_bps()` | Sets per-track revenue splits | Initialized |
| `distribute_revenue<C>()` | Distributes funds to composition/recording pools | Published |

**Constraints:**
- Maximum 20 discs per release
- Maximum 50 tracks per disc
- Track splits must sum to exactly 10,000 BPS (100%)

---

### Supporting Data Structures

#### `party.move`

Represents individuals and groups in the music ecosystem.

```move
public enum PartyKind has copy, drop, store {
    Individual,
    Group,
}

public struct Party has key {
    id: UID,
    kind: PartyKind,
    name: String,
}
```

Groups can contain references to individual parties as members.

---

#### `credit.move`

Generic credit system for assigning roles to parties.

```move
public struct Credit<R> has copy, drop, store {
    display_name: String,
    roles: vector<R>,
}
```

Validates that:
- At least 1 role is assigned
- No duplicate roles exist

---

#### `audio.move`

Represents audio file metadata and integrity verification.

```move
public struct Audio has copy, drop, store {
    channels: u8,
    bit_depth: u8,
    sample_rate_hz: u32,
    samples: u64,
    data: WalrusData,
    pcm_digest: vector<u8>,
}
```

**Supported Audio Specifications:**
- Channels: 1 (mono), 2 (stereo)
- Bit Depth: 16, 24, 32
- Sample Rates: 44100, 48000, 88200, 96000, 176400, 192000 Hz

**Duration Calculation:**
```
duration_ms = (samples * 1000) / sample_rate_hz
```

The `pcm_digest` is a 32-byte hash for content integrity verification.

---

#### `stem.move`

Individual audio stems (isolated tracks).

```move
public struct Stem has copy, drop, store {
    description: String,
    audio: Audio,
}
```

Recordings can have up to 10 stems (e.g., vocals, drums, bass, guitars).

---

#### `cover_art.move`

Artwork for releases and recordings.

```move
public struct CoverArt has copy, drop, store {
    static_image: WalrusData,
    animated: Option<WalrusData>,
}
```

- `static_image` is required
- `animated` is optional (for GIFs or video loops)

---

### Musical Metadata

#### `musical_key.move`

```move
public enum Note has copy, drop, store { C, D, E, F, G, A, B }
public enum Accidental has copy, drop, store { Natural, Sharp, Flat }
public enum Mode has copy, drop, store { Major, Minor }

public struct MusicalKey has copy, drop, store {
    note: Note,
    accidental: Accidental,
    mode: Mode,
}
```

Examples: C Major, F# Minor, Bb Major

---

#### `time_signature.move`

```move
public struct TimeSignature has copy, drop, store {
    beats_per_measure: u8,
    beat_unit: u8,
}
```

Examples: 4/4 (beats_per_measure=4, beat_unit=4), 6/8, 3/4

---

#### `genre.move`

Manages music genre classification.

```move
public struct Genre has key, store {
    id: UID,
    name: String,
}

public struct GenreRegistry has key {
    id: UID,
    genres: Table<String, ID>,
}
```

**Default Genres (21):**
AFRICAN, ALTERNATIVE, BLUES, CHILDREN, CHRISTIAN, CLASSICAL, COUNTRY, DANCE, EASY_LISTENING, ELECTRONIC, FOLK, HIPHOP, HOLIDAY, INDIE, JAZZ, LATIN, METAL, POP, RNB, ROCK, WORLD

---

### Role Systems

#### `composition_party_role.move`

Roles for composition contributors:

| Role | Description |
|------|-------------|
| `Composer` | Created the musical composition |
| `Lyricist` | Wrote the lyrics |
| `Songwriter` | Combined composer and lyricist |
| `Arranger` | Arranged the composition |
| `Translator` | Translated lyrics to another language |
| `Adapter` | Adapted the work |

---

#### `recording_party_role.move`

Recording roles with optional level indicators.

**Role Types (27+):**
Actor, Arranger, A&R, Choir, ChoirMaster, Conductor, Contractor, Copyist, Editor, Ensemble, Instrumentalist (with instrument name), MasteringEngineer, MixingEngineer, MusicDirector, MusicSupervisor, Narrator, Orchestra, Orchestrator, Producer, Programmer, RecordingEngineer, RemixingEngineer, SoundDesigner, Vocalist

**Level Types:**
Additional, Assistant, Associate, Backing, Executive, Featured, Lead, Primary, Principal

---

## State Machine Design

All core entities follow a strict state machine pattern:

### Composition States

```
┌─────────────┐         ┌─────────────┐
│ Initialized │ ──────► │  Published  │
└─────────────┘         └─────────────┘
                              │
                              ▼
                        (Immutable)
```

### Recording States

```
┌─────────────┐         ┌─────────────┐
│ Initialized │ ──────► │  Published  │
└─────────────┘         └─────────────┘
                              │
                              ▼
                        (Immutable)
```

### Release States

```
┌─────────────┐         ┌─────────────┐
│ Initialized │ ──────► │  Published  │
└─────────────┘         └─────────────┘
                              │
                              ▼
                        (Immutable)
```

**State Transition Rules:**

1. Modifications only allowed in `Initialized` state
2. `publish()` transitions to `Published` state with timestamp
3. Published entities become shared objects (globally accessible)
4. No reverse transitions - publishing is permanent

---

## Share Token System

Each composition and recording has its own fungible share token for ownership representation.

### Token Specifications

| Property | Value |
|----------|-------|
| Total Supply | 100,000,000 tokens |
| Decimals | 6 |
| Symbol | "SHARE" |

This means 100,000,000.000000 total tokens per entity.

### Token Lifecycle

1. **Initialization**: Tokens minted during `new()` call
2. **Distribution**: Initial balance returned to creator
3. **Ownership**: Share holders receive proportional revenue
4. **Immutable Supply**: No additional tokens can be minted after initialization

### Share Module (`share.move`)

```move
public fun intialize<S>(
    share_currency: &mut Currency<S>,
    share_treasury_cap: TreasuryCap<S>,
): Balance<S>
```

Validates:
- Correct decimals (6)
- Correct symbol ("SHARE")
- Zero initial supply (treasury cap unused)

---

## Revenue Distribution

### Basis Points (BPS) System

- 1 BPS = 0.01%
- 10,000 BPS = 100%
- Enables precise fractional calculations without floating point

### Distribution Flow

```
        Revenue Received to Release
                   │
                   ▼
         ┌─────────────────┐
         │  Track Splits   │ ◄── Per-track percentage (must sum to 100%)
         └─────────────────┘
                   │
     ┌─────────────┼─────────────┐
     ▼             ▼             ▼
  Track 1      Track 2       Track N
     │             │             │
     └─────────────┼─────────────┘
                   │
                   ▼
         ┌─────────────────┐
         │ Composition     │ ◄── composition_split_bps from recording
         │ Split           │
         └─────────────────┘
                   │
         ┌────────┴────────┐
         ▼                 ▼
   ┌───────────┐    ┌───────────┐
   │Composition│    │ Recording │
   │   Pool    │    │   Pool    │
   └───────────┘    └───────────┘
         │                 │
         ▼                 ▼
    Share Holders     Share Holders
```

### distribute_revenue() Implementation

```move
public fun distribute_revenue<C>(self: &mut Release, value: u64)
```

1. Withdraws funds from release's balance
2. Iterates through each track in sequence
3. Calculates track's share based on `track_splits_bps`
4. Splits track revenue between composition and recording based on `composition_split_bps`
5. Sends funds to composition and recording addresses
6. Returns dust (rounding remainder) to release

---

## Authorization Model

MusicOS uses capability-based authorization for secure access control.

### Admin Capabilities

Each entity has a corresponding admin capability:

| Entity | Capability | Derivation Key |
|--------|-----------|----------------|
| Composition | `CompositionAdminCap<CS>` | `CompositionAdminCapKey` |
| Recording | `RecordingAdminCap<RS>` | `RecordingAdminCapKey` |
| Release | `ReleaseAdminCap` | `RelaseAdminCapKey` |
| Party | `PartyAdminCap` | `PartyAdminCapKey` |

### Derived Object Pattern

Admin capabilities use Sui's derived object pattern for deterministic addresses:

```move
let admin_cap = CompositionAdminCap {
    id: claim(&mut composition.id, CompositionAdminCapKey()),
};
```

This allows clients to compute capability addresses without on-chain lookups.

### Authorization Flow

```
┌─────────────┐      ┌─────────────────┐      ┌──────────────┐
│   Caller    │ ───► │  Admin Cap      │ ───► │   Entity     │
│             │      │  (proves auth)  │      │  (modified)  │
└─────────────┘      └─────────────────┘      └──────────────┘
```

Every mutating function requires the corresponding admin capability.

---

## Extension System

MusicOS supports extensibility through dynamic fields and authorized extensions.

### `extension.move`

```move
public fun assert_authorized<E: drop>(uid: &UID, witness: E)
```

Extensions can be authorized by attaching a dynamic field to an entity's UID. When authorized, extensions can access `uid_mut_authorized()` to modify entity state.

### Extension Authorization Flow

1. Entity owner adds extension authorization via dynamic field
2. Extension module provides a witness type
3. Extension calls `uid_mut_authorized()` with witness
4. Extension performs authorized modifications

### Reward Pool Extensions

Two official extensions for revenue distribution:

#### `composition_reward_pool`

Creates staking reward pools for composition share holders:
- Permissionless pool creation
- Proportional revenue distribution to staked shares
- Events: `CompositionRevenuePoolCreatedEvent`

#### `recording_reward_pool`

Similar functionality for recording shares:
- Creates reward pools from recording funds
- Distributes to recording share holders
- Events: `RecordingRevenuePoolCreatedEvent`

---

## TypeScript SDK

The SDK provides a type-safe interface for interacting with MusicOS contracts.

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    MusicOSClient                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │Contributors │  │Compositions │  │ Recordings  │     │
│  │   Client    │  │   Client    │  │   Client    │     │
│  └─────────────┘  └─────────────┘  └─────────────┘     │
│  ┌─────────────┐  ┌─────────────┐                      │
│  │  Releases   │  │   Genres    │                      │
│  │   Client    │  │   Client    │                      │
│  └─────────────┘  └─────────────┘                      │
└─────────────────────────────────────────────────────────┘
```

### Usage Pattern

```typescript
import { MusicOSClient } from "@musicos/sdk";
import { SuiClient } from "@mysten/sui/client";

// Initialize
const client = new MusicOSClient({ packageId: "0x..." });
const suiClient = new SuiClient({ url: "https://fullnode.testnet.sui.io" });

// Build transaction
const tx = client.compositions.create({
  title: "My Song",
  splitBps: 5000,
  shareCurrencyId: "0x...",
  shareTreasuryCapId: "0x...",
  shareType: "0x...::share::SHARE",
});

// Execute
await suiClient.signAndExecuteTransaction({
  transaction: tx,
  signer: keypair,
});
```

### RecordingBuilder

Fluent API for building complex recording transactions:

```typescript
const tx = new RecordingBuilder({
  packageId: "0x...",
  compositionId: "0x...",
  compositionShareType: "0x...::share::SHARE",
  genreId: "0x...",
  master: { /* audio details */ },
  coverArt: { /* artwork details */ },
  shareCurrencyId: "0x...",
  shareTreasuryCapId: "0x...",
  shareType: "0x...::share::SHARE",
})
  .title("Song Title")
  .titleVersion("Radio Edit")
  .language("en")
  .addCredit(artistId, { displayName: "Artist", roles: [{ type: "vocalist", level: "lead" }] })
  .addPrimaryArtist(artistId)
  .tempoBpm(120)
  .musicalKey({ note: "C", accidental: "natural", mode: "major" })
  .timeSignature(4, 4)
  .buildAndPublish();
```

### Utility Functions

| Function | Purpose |
|----------|---------|
| `makeAudio()` | Constructs Audio Move struct |
| `makeCoverArt()` | Constructs CoverArt Move struct |
| `makeMusicalKey()` | Constructs MusicalKey Move struct |
| `makeRecordingRole()` | Constructs role with level |
| `calculateDurationMs()` | Calculates audio duration |
| `parseTypeString()` | Parses Move type strings |
| `validateShareType()` | Validates share token types |

---

## Integration Patterns

### Creating a Complete Music Release

1. **Create Parties** (artists, producers, engineers)
   ```typescript
   client.contributors.create({ kind: "individual", name: "Artist" })
   ```

2. **Create Composition Share Token** (separate coin module)

3. **Create Composition**
   ```typescript
   client.compositions.create({
     title: "Song Title",
     splitBps: 5000, // 50% to composition
     shareCurrencyId, shareTreasuryCapId, shareType
   })
   ```

4. **Add Composition Credits**
   ```typescript
   client.compositions.addCredit({
     compositionId, adminCapId, contributorId,
     credit: { displayName: "Composer", roles: ["composer"] }
   })
   ```

5. **Publish Composition**
   ```typescript
   client.compositions.publish({ compositionId, adminCapId })
   ```

6. **Create Recording Share Token**

7. **Create Recording** (links to composition)
   ```typescript
   new RecordingBuilder({ compositionId, ... }).buildAndPublish()
   ```

8. **Create Release with Tracks**
   ```typescript
   client.releases.create({
     kind: "single",
     title: "Single Release",
     coverArt: { ... },
     discs: [{ tracks: [{ recordingId, ... }] }]
   })
   ```

9. **Set Track Splits** (must sum to 10000)
   ```typescript
   client.releases.setTrackSplitsBps({
     releaseId, adminCapId,
     splits: [10000] // 100% to single track
   })
   ```

10. **Publish Release**
    ```typescript
    client.releases.publish({ releaseId, adminCapId })
    ```

### Revenue Distribution Flow

1. Funds sent to release address
2. Call `distribute_revenue<SUI>(releaseId, amount)`
3. Revenue split to composition and recording pools
4. Share holders claim from reward pools

---

## Error Handling

### Error Code Categories

| Range | Category | Examples |
|-------|----------|----------|
| 0 | Authorization | `EUnauthorized` - capability mismatch |
| 1-9 | State Machine | `ENotInitializedState`, `ENotPublishedState` |
| 10-19 | Bounds/Limits | `EMaxDiscsReached`, `EExceedsMaxRoles` |
| 20-29 | Validation | `EInvalidTrackSplitsSum`, `ENoParties` |
| 30-39 | Existence/Conflict | `EDuplicateParty`, `EAlreadyPrimaryArtist` |

### Common Error Scenarios

| Error | Cause | Solution |
|-------|-------|----------|
| `ENotInitializedState` | Modifying published entity | Cannot modify after publish |
| `ENoParties` | Publishing without credits | Add at least one credit first |
| `ENoPrimaryArtistAssigned` | Publishing recording without primary artist | Call `add_primary_artist()` |
| `EInvalidTrackSplitsSum` | Track splits don't equal 10000 | Ensure splits sum to exactly 10000 BPS |
| `EPartyNotCredited` | Adding artist not in credits | Call `add_credit()` first |

---

## Appendix: Move Dependencies

```toml
[dependencies]
Sui = { ... }
interest_bps = { ... }    # Basis point calculations
language_code = { ... }   # ISO 639-1 language codes
walrus_data = { ... }     # External storage references
```

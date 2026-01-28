# MusicOS API Reference

Complete API documentation for MusicOS Move modules and TypeScript SDK.

## Table of Contents

1. [Move Modules](#move-modules)
   - [Composition](#composition)
   - [Recording](#recording)
   - [Release](#release)
   - [Party](#party)
   - [Audio](#audio)
   - [Genre](#genre)
2. [TypeScript SDK](#typescript-sdk)
   - [MusicOSClient](#musicosclient)
   - [ContributorClient](#contributorclient)
   - [CompositionClient](#compositionclient)
   - [RecordingClient](#recordingclient)
   - [ReleaseClient](#releaseclient)
   - [RecordingBuilder](#recordingbuilder)
3. [Types Reference](#types-reference)
4. [Constants](#constants)

---

## Move Modules

### Composition

Module: `musicos::composition`

#### Types

```move
/// A musical composition representing the underlying written work.
public struct Composition<phantom CompositionShare> has key {
    id: UID,
    state: CompositionState,
    title: String,
    alternate_titles: vector<String>,
    credits: VecMap<ID, Credit<CompositionPartyRole>>,
    split_bps: BPS,
    lyrics: Option<WalrusData>,
}

/// Capability that authorizes modifications to a composition.
public struct CompositionAdminCap<phantom CompositionShare> has key, store {
    id: UID,
}

/// Lifecycle state of a composition.
public enum CompositionState has copy, drop, store {
    Initialized,
    Published(u64), // timestamp_ms
}
```

#### Functions

##### `new`

Creates a new composition with share tokens.

```move
public fun new<CompositionShare>(
    title: String,
    split_value: u64,
    share_currency: &mut Currency<CompositionShare>,
    share_treasury_cap: TreasuryCap<CompositionShare>,
    ctx: &mut TxContext,
): (
    Composition<CompositionShare>,
    CompositionAdminCap<CompositionShare>,
    Balance<CompositionShare>,
)
```

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| `title` | `String` | Primary title of the composition |
| `split_value` | `u64` | Revenue split in basis points (0-10000) |
| `share_currency` | `&mut Currency<CompositionShare>` | Currency metadata for share token |
| `share_treasury_cap` | `TreasuryCap<CompositionShare>` | Treasury capability (consumed) |
| `ctx` | `&mut TxContext` | Transaction context |

**Returns:**
- `Composition<CompositionShare>` - The created composition
- `CompositionAdminCap<CompositionShare>` - Admin capability for modifications
- `Balance<CompositionShare>` - Initial share token balance (100M tokens)

**Events:** `CompositionInitializedEvent`

---

##### `publish`

Publishes the composition, making it immutable and shared.

```move
public fun publish<CompositionShare>(
    self: Composition<CompositionShare>,
    _: &CompositionAdminCap<CompositionShare>,
    clock: &Clock,
)
```

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| `self` | `Composition<CompositionShare>` | The composition to publish |
| `_` | `&CompositionAdminCap<CompositionShare>` | Admin capability (for authorization) |
| `clock` | `&Clock` | Sui clock for timestamp |

**Requirements:**
- State must be `Initialized`
- Must have at least one credit

**Events:** `CompositionPublishedEvent`

**Errors:**
- `ENotInitializedState` (1) - Not in Initialized state
- `ENoParties` (20) - No credits added

---

##### `add_credit`

Adds a party credit to the composition.

```move
public fun add_credit<CompositionShare>(
    self: &mut Composition<CompositionShare>,
    _: &CompositionAdminCap<CompositionShare>,
    party: &Party,
    credit: Credit<CompositionPartyRole>,
)
```

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| `self` | `&mut Composition<CompositionShare>` | The composition to modify |
| `_` | `&CompositionAdminCap<CompositionShare>` | Admin capability |
| `party` | `&Party` | The party to credit |
| `credit` | `Credit<CompositionPartyRole>` | Credit with display name and roles |

**Requirements:**
- State must be `Initialized`
- Credit must have 1-20 roles

**Events:** `CompositionPartyAddedEvent`

**Errors:**
- `ENotInitializedState` (1)
- `EMinRolesNotMet` (11) - Less than 1 role
- `EExceedsMaxRoles` (10) - More than 20 roles

---

##### `set_split_bps`

Sets the revenue split rate for the composition.

```move
public fun set_split_bps<CompositionShare>(
    self: &mut Composition<CompositionShare>,
    _: &CompositionAdminCap<CompositionShare>,
    split_value: u64,
)
```

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| `self` | `&mut Composition<CompositionShare>` | The composition to modify |
| `_` | `&CompositionAdminCap<CompositionShare>` | Admin capability |
| `split_value` | `u64` | Split in basis points (0-10000) |

**Note:** Only affects future recordings. Existing recordings retain their captured split.

**Events:** `CompositionSplitSetEvent`

---

##### `add_alternate_title`

Adds an alternate title to the composition.

```move
public fun add_alternate_title<CompositionShare>(
    self: &mut Composition<CompositionShare>,
    _: &CompositionAdminCap<CompositionShare>,
    alternate_title: String,
)
```

---

##### `set_lyrics`

Sets the lyrics data reference.

```move
public fun set_lyrics<CompositionShare>(
    self: &mut Composition<CompositionShare>,
    _: &CompositionAdminCap<CompositionShare>,
    data: WalrusData,
)
```

---

#### View Functions

```move
public fun id<CS>(self: &Composition<CS>): ID
public fun state<CS>(self: &Composition<CS>): CompositionState
public fun title<CS>(self: &Composition<CS>): &String
public fun alternate_titles<CS>(self: &Composition<CS>): &vector<String>
public fun credits<CS>(self: &Composition<CS>): &VecMap<ID, Credit<CompositionPartyRole>>
public fun split_bps<CS>(self: &Composition<CS>): BPS
public fun lyrics<CS>(self: &Composition<CS>): &Option<WalrusData>
public fun uid<CS>(self: &Composition<CS>): &UID
```

---

### Recording

Module: `musicos::recording`

#### Types

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

public struct RecordingAdminCap<phantom RecordingShare> has key, store {
    id: UID,
}

public enum RecordingState has copy, drop, store {
    Initialized,
    Published(u64), // timestamp_ms
}
```

#### Functions

##### `new`

Creates a new recording linked to a composition.

```move
public fun new<RecordingShare, CS>(
    composition: &mut Composition<CS>,
    genre: &Genre,
    is_explicit: bool,
    is_instrumental: bool,
    master: Audio,
    cover_art: CoverArt,
    share_currency: &mut Currency<RecordingShare>,
    share_treasury_cap: TreasuryCap<RecordingShare>,
): (Recording<RecordingShare>, RecordingAdminCap<RecordingShare>, Balance<RecordingShare>)
```

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| `composition` | `&mut Composition<CS>` | The underlying composition |
| `genre` | `&Genre` | Primary genre |
| `is_explicit` | `bool` | Contains explicit content |
| `is_instrumental` | `bool` | Has no vocals |
| `master` | `Audio` | Master audio file metadata |
| `cover_art` | `CoverArt` | Cover artwork |
| `share_currency` | `&mut Currency<RecordingShare>` | Currency metadata |
| `share_treasury_cap` | `TreasuryCap<RecordingShare>` | Treasury cap (consumed) |

**Note:** Captures `composition_split_bps` at creation time.

---

##### `publish`

Publishes the recording.

```move
public fun publish<RecordingShare>(
    self: Recording<RecordingShare>,
    _: &RecordingAdminCap<RecordingShare>,
    clock: &Clock,
)
```

**Requirements:**
- At least one credit
- At least one primary artist

**Errors:**
- `ENotInitializedState` (1)
- `ENoParties` (20) - No credits
- `ENoPrimaryArtistAssigned` (21) - No primary artist

---

##### `add_credit`

```move
public fun add_credit<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    _: &RecordingAdminCap<RecordingShare>,
    party: &Party,
    credit: Credit<RecordingPartyRole>,
)
```

**Requirements:** Credit must have 1-10 roles.

---

##### `add_primary_artist`

Marks a credited party as a primary artist.

```move
public fun add_primary_artist<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    _: &RecordingAdminCap<RecordingShare>,
    party: &Party,
)
```

**Requirements:**
- Party must already be credited
- Party cannot be a featured artist

**Errors:**
- `EPartyNotCredited` (22)
- `EAlreadyFeaturedArtist` (23)

---

##### `add_featured_artist`

Marks a credited party as a featured artist.

```move
public fun add_featured_artist<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    _: &RecordingAdminCap<RecordingShare>,
    party: &Party,
)
```

**Errors:**
- `EPartyNotCredited` (22)
- `EAlreadyPrimaryArtist` (24)

---

##### Genre Functions

```move
public fun set_primary_genre<RS>(self: &mut Recording<RS>, _: &RecordingAdminCap<RS>, genre: &Genre)
public fun add_secondary_genre<RS>(self: &mut Recording<RS>, _: &RecordingAdminCap<RS>, genre: &Genre)
public fun remove_secondary_genre<RS>(self: &mut Recording<RS>, _: &RecordingAdminCap<RS>, genre_id: ID)
```

**Errors:**
- `EAlreadyAssignedAsSecondaryGenre` (25) - Genre already secondary
- `EAlreadyAssignedAsPrimaryGenre` (26) - Genre already primary

---

##### Title Functions

```move
public fun set_title<RS>(self: &mut Recording<RS>, _: &RecordingAdminCap<RS>, title: String)
public fun set_title_version<RS>(self: &mut Recording<RS>, _: &RecordingAdminCap<RS>, title_version: String)
public fun set_subtitle<RS>(self: &mut Recording<RS>, _: &RecordingAdminCap<RS>, subtitle: String)
public fun set_language<RS>(self: &mut Recording<RS>, _: &RecordingAdminCap<RS>, language: LanguageCode)
```

---

##### Musical Metadata Functions

```move
public fun set_musical_key<RS>(self: &mut Recording<RS>, _: &RecordingAdminCap<RS>, musical_key: MusicalKey)
public fun set_time_signature<RS>(self: &mut Recording<RS>, _: &RecordingAdminCap<RS>, time_signature: TimeSignature)
public fun set_tempo_bpm<RS>(self: &mut Recording<RS>, _: &RecordingAdminCap<RS>, tempo_bpm: u16)
public fun add_stem<RS>(self: &mut Recording<RS>, _: &RecordingAdminCap<RS>, stem: Stem)
```

---

#### View Functions

```move
public fun id<RS>(self: &Recording<RS>): ID
public fun state<RS>(self: &Recording<RS>): RecordingState
public fun title<RS>(self: &Recording<RS>): &String
public fun title_version<RS>(self: &Recording<RS>): &Option<String>
public fun subtitle<RS>(self: &Recording<RS>): &Option<String>
public fun composition_id<RS>(self: &Recording<RS>): ID
public fun composition_share_type<RS>(self: &Recording<RS>): &TypeName
public fun composition_split_bps<RS>(self: &Recording<RS>): BPS
public fun primary_genre_id<RS>(self: &Recording<RS>): ID
public fun secondary_genre_ids<RS>(self: &Recording<RS>): &VecSet<ID>
public fun primary_artist_ids<RS>(self: &Recording<RS>): &VecSet<ID>
public fun featured_artist_ids<RS>(self: &Recording<RS>): &VecSet<ID>
public fun credits<RS>(self: &Recording<RS>): &VecMap<ID, Credit<RecordingPartyRole>>
public fun language<RS>(self: &Recording<RS>): &Option<LanguageCode>
public fun is_explicit<RS>(self: &Recording<RS>): bool
public fun is_instrumental<RS>(self: &Recording<RS>): bool
public fun musical_key<RS>(self: &Recording<RS>): &Option<MusicalKey>
public fun time_signature<RS>(self: &Recording<RS>): &Option<TimeSignature>
public fun tempo_bpm<RS>(self: &Recording<RS>): &Option<u16>
public fun master<RS>(self: &Recording<RS>): &Audio
public fun cover_art<RS>(self: &Recording<RS>): &CoverArt
public fun is_primary_artist<RS>(self: &Recording<RS>, party_id: ID): bool
public fun is_featured_artist<RS>(self: &Recording<RS>, party_id: ID): bool
```

---

### Release

Module: `musicos::release`

#### Types

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

public struct ReleaseAdminCap has key, store {
    id: UID,
    release_id: ID,
}

public enum ReleaseKind has copy, drop, store {
    Album,
    EP,
    Single,
}

public enum ReleaseState has copy, drop, store {
    Initialized,
    Published(u64), // timestamp_ms
}
```

#### Functions

##### `new`

Creates a new release.

```move
public fun new(
    kind: ReleaseKind,
    title: String,
    cover_art: CoverArt,
    discs: vector<Disc>,
    ctx: &mut TxContext,
): (Release, ReleaseAdminCap)
```

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| `kind` | `ReleaseKind` | Album, EP, or Single |
| `title` | `String` | Release title |
| `cover_art` | `CoverArt` | Cover artwork |
| `discs` | `vector<Disc>` | Collection of discs with tracks |
| `ctx` | `&mut TxContext` | Transaction context |

**Constraints:**
- Maximum 20 discs

---

##### `publish`

Publishes the release.

```move
public fun publish(
    self: Release,
    cap: &ReleaseAdminCap,
    clock: &Clock,
    ctx: &TxContext,
)
```

**Requirements:**
- Track splits must be set
- Track splits must sum to 10000 BPS

**Errors:**
- `EUnauthorized` (0)
- `ENotInitializedState` (1)
- `EInvalidTrackSplitsLength` (20)
- `EInvalidTrackSplitsSum` (21)

---

##### `set_track_splits_bps`

Sets revenue splits for each track.

```move
public fun set_track_splits_bps(
    self: &mut Release,
    cap: &ReleaseAdminCap,
    track_splits_bps_values: vector<u64>,
)
```

**Requirements:**
- Number of splits must match number of tracks
- Splits must sum to 10000 (100%)

---

##### `distribute_revenue`

Distributes funds to composition and recording pools.

```move
public fun distribute_revenue<C>(
    self: &mut Release,
    value: u64,
)
```

**Parameters:**
| Name | Type | Description |
|------|------|-------------|
| `self` | `&mut Release` | The release |
| `value` | `u64` | Amount to distribute |

**Requirements:**
- State must be `Published`
- Release must have funds

**Events:** `ReleaseRevenueDistributedEvent<C>` for each track

**Errors:**
- `ENotPublishedState` (2)
- `ENoRevenueToDistribute` (22)

---

#### View Functions

```move
public fun id(self: &Release): ID
public fun kind(self: &Release): ReleaseKind
public fun state(self: &Release): ReleaseState
public fun title(self: &Release): &String
public fun subtitle(self: &Release): &Option<String>
public fun discs(self: &Release): &vector<Disc>
public fun track_sequence(self: &Release): &TrackSequence
public fun track_splits_bps(self: &Release): &vector<BPS>
public fun cover_art(self: &Release): &CoverArt
```

---

### Party

Module: `musicos::party`

#### Types

```move
public struct Party has key {
    id: UID,
    kind: PartyKind,
    name: String,
}

public struct PartyAdminCap has key, store {
    id: UID,
}

public enum PartyKind has copy, drop, store {
    Individual,
    Group,
}
```

#### Functions

```move
public fun new(kind: PartyKind, name: String, ctx: &mut TxContext): (Party, PartyAdminCap)
public fun set_name(self: &mut Party, _: &PartyAdminCap, name: String)
```

**Events:** `PartyCreatedEvent`

---

### Audio

Module: `musicos::audio`

#### Types

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

#### Functions

```move
public fun new(
    channels: u8,
    bit_depth: u8,
    sample_rate_hz: u32,
    samples: u64,
    data: WalrusData,
    pcm_digest: vector<u8>,
): Audio
```

**Validation:**
- Channels: 1 or 2
- Bit depth: 16, 24, or 32
- Sample rate: 44100, 48000, 88200, 96000, 176400, or 192000

```move
public fun duration_ms(self: &Audio): u64
public fun channels(self: &Audio): u8
public fun bit_depth(self: &Audio): u8
public fun sample_rate_hz(self: &Audio): u32
public fun samples(self: &Audio): u64
public fun data(self: &Audio): &WalrusData
public fun pcm_digest(self: &Audio): &vector<u8>
```

---

### Genre

Module: `musicos::genre`

#### Functions

```move
public fun new(name: String, registry: &mut GenreRegistry, ctx: &mut TxContext): Genre
public fun id(self: &Genre): ID
public fun name(self: &Genre): &String
```

---

## TypeScript SDK

### MusicOSClient

Main entry point for the SDK.

```typescript
import { MusicOSClient } from "@musicos/sdk";

const client = new MusicOSClient({
  packageId: "0x...",
});

// Access domain clients
client.contributors  // ContributorClient
client.compositions  // CompositionClient
client.recordings    // RecordingClient
client.releases      // ReleaseClient
client.genres        // GenreClient
```

#### Constructor

```typescript
new MusicOSClient(config: MusicOSConfig)
```

```typescript
interface MusicOSConfig {
  packageId: string;
}
```

#### Static Methods

```typescript
static forNetwork(
  network: NetworkPreset,
  overrides?: Partial<MusicOSConfig>
): MusicOSClient
```

**NetworkPreset:** `"mainnet" | "testnet" | "devnet" | "localnet"`

---

### ContributorClient

Manages party (contributor) objects.

#### `create`

```typescript
create(params: CreateContributorParams): Transaction
```

```typescript
interface CreateContributorParams {
  kind: "individual" | "group";
  name: string;
}
```

#### `addMember`

```typescript
addMember(params: AddGroupMemberParams): Transaction
```

```typescript
interface AddGroupMemberParams {
  groupId: string;
  adminCapId: string;
  memberId: string;
}
```

---

### CompositionClient

Manages composition objects.

#### `create`

```typescript
create(params: CreateCompositionParams): Transaction
```

```typescript
interface CreateCompositionParams {
  title: string;
  splitBps: number;
  shareCurrencyId: string;
  shareTreasuryCapId: string;
  shareType: string;
}
```

#### `publish`

```typescript
publish(params: PublishCompositionParams): Transaction
```

```typescript
interface PublishCompositionParams {
  compositionId: string;
  adminCapId: string;
  shareType: string;
}
```

#### `addCredit`

```typescript
addCredit(params: AddCompositionCreditParams): Transaction
```

```typescript
interface AddCompositionCreditParams {
  compositionId: string;
  adminCapId: string;
  contributorId: string;
  credit: CompositionCredit;
  shareType: string;
}

interface CompositionCredit {
  displayName: string;
  roles: CompositionRole[];
}

type CompositionRole =
  | "composer"
  | "lyricist"
  | "songwriter"
  | "arranger"
  | "translator"
  | "adapter";
```

#### `setSplit`

```typescript
setSplit(params: SetCompositionSplitParams): Transaction
```

```typescript
interface SetCompositionSplitParams {
  compositionId: string;
  adminCapId: string;
  splitBps: number;
  shareType: string;
}
```

#### `addAlternateTitle`

```typescript
addAlternateTitle(params: AddAlternateTitleParams): Transaction
```

#### `setLyrics`

```typescript
setLyrics(params: SetLyricsParams): Transaction
```

---

### RecordingClient

Manages recording objects.

#### `create`

```typescript
create(params: CreateRecordingParams): Transaction
```

```typescript
interface CreateRecordingParams {
  compositionId: string;
  compositionShareType: string;
  genreId: string;
  isExplicit: boolean;
  isInstrumental: boolean;
  master: Audio;
  coverArt: CoverArt;
  shareCurrencyId: string;
  shareTreasuryCapId: string;
  shareType: string;
}

interface Audio {
  channels: number;
  bitDepth: number;
  sampleRateHz: number;
  samples: bigint;
  data: WalrusData;
  pcmDigest: Uint8Array;
}

interface CoverArt {
  static: WalrusData;
  animated?: WalrusData;
}

interface WalrusData {
  blobId: string;
  endEpoch: number;
}
```

#### `publish`

```typescript
publish(params: PublishRecordingParams): Transaction
```

#### `addCredit`

```typescript
addCredit(params: AddRecordingCreditParams): Transaction
```

```typescript
interface RecordingCredit {
  displayName: string;
  roles: RecordingRole[];
}

interface RecordingRole {
  type: RecordingRoleType;
  level?: RecordingContributorLevel;
  instrument?: string; // For "instrumentalist" type
}

type RecordingRoleType =
  | "actor" | "arranger" | "ar" | "choir" | "choirMaster"
  | "conductor" | "contractor" | "copyist" | "editor" | "ensemble"
  | "instrumentalist" | "masteringEngineer" | "mixingEngineer"
  | "musicDirector" | "musicSupervisor" | "narrator" | "orchestra"
  | "orchestrator" | "producer" | "programmer" | "recordingEngineer"
  | "remixingEngineer" | "soundDesigner" | "vocalist";

type RecordingContributorLevel =
  | "additional" | "assistant" | "associate" | "backing"
  | "executive" | "featured" | "lead" | "primary" | "principal";
```

#### `addPrimaryArtist`

```typescript
addPrimaryArtist(params: RecordingArtistParams): Transaction
```

#### `addFeaturedArtist`

```typescript
addFeaturedArtist(params: RecordingArtistParams): Transaction
```

#### Musical Metadata Methods

```typescript
setMusicalKey(params: SetMusicalKeyParams): Transaction
setTimeSignature(params: SetTimeSignatureParams): Transaction
setTempo(params: SetTempoParams): Transaction
addStem(params: AddStemParams): Transaction
```

---

### ReleaseClient

Manages release objects.

#### `create`

```typescript
create(params: CreateReleaseParams): Transaction
```

```typescript
interface CreateReleaseParams {
  kind: ReleaseKind;
  title: string;
  coverArt: CoverArt;
  discs: Disc[];
}

type ReleaseKind = "album" | "ep" | "single";

interface Disc {
  tracks: Track[];
  coverArt?: CoverArt;
}

interface Track {
  recordingId: string;
  recordingAdminCapId: string;
  recordingShareType: string;
  coverArt?: CoverArt;
}
```

#### `publish`

```typescript
publish(params: PublishReleaseParams): Transaction
```

#### `setTrackSplitsBps`

```typescript
setTrackSplitsBps(params: SetTrackSplitsParams): Transaction
```

```typescript
interface SetTrackSplitsParams {
  releaseId: string;
  adminCapId: string;
  splits: number[]; // Must sum to 10000
}
```

#### `distributeRevenue`

```typescript
distributeRevenue(params: DistributeRevenueParams): Transaction
```

---

### RecordingBuilder

Fluent builder for creating and configuring recordings.

```typescript
import { RecordingBuilder } from "@musicos/sdk";

const tx = new RecordingBuilder({
  packageId: "0x...",
  compositionId: "0x...",
  compositionShareType: "0x...::share::SHARE",
  genreId: "0x...",
  master: {
    channels: 2,
    bitDepth: 24,
    sampleRateHz: 48000,
    samples: 14400000n,
    data: { blobId: "...", endEpoch: 100 },
    pcmDigest: new Uint8Array(32),
  },
  coverArt: {
    static: { blobId: "...", endEpoch: 100 },
  },
  shareCurrencyId: "0x...",
  shareTreasuryCapId: "0x...",
  shareType: "0x...::share::SHARE",
})
  .title("Song Title")
  .titleVersion("Radio Edit")
  .subtitle("From Album X")
  .language("en")
  .explicit(false)
  .instrumental(false)
  .addCredit(partyId, {
    displayName: "Artist Name",
    roles: [{ type: "vocalist", level: "lead" }],
  })
  .addPrimaryArtist(partyId)
  .tempoBpm(120)
  .musicalKey({ note: "C", accidental: "natural", mode: "major" })
  .timeSignature(4, 4)
  .addStem({
    description: "Vocals",
    audio: { /* audio details */ },
  })
  .build();         // Returns transaction (recording not published)
  // OR
  .buildAndPublish(); // Returns transaction (recording will be published)
```

#### Builder Methods

| Method | Description |
|--------|-------------|
| `title(string)` | Set recording title |
| `titleVersion(string)` | Set title version (e.g., "Radio Edit") |
| `subtitle(string)` | Set subtitle |
| `language(string)` | Set language code (ISO 639-1) |
| `explicit(boolean)` | Set explicit content flag |
| `instrumental(boolean)` | Set instrumental flag |
| `addCredit(partyId, credit)` | Add party credit |
| `addPrimaryArtist(partyId)` | Mark party as primary artist |
| `addFeaturedArtist(partyId)` | Mark party as featured artist |
| `setPrimaryGenre(genreId)` | Change primary genre |
| `addSecondaryGenre(genreId)` | Add secondary genre |
| `tempoBpm(number)` | Set tempo in BPM |
| `musicalKey(MusicalKey)` | Set musical key |
| `timeSignature(beats, unit)` | Set time signature |
| `addStem(Stem)` | Add audio stem |
| `build()` | Build transaction (unpublished) |
| `buildAndPublish()` | Build transaction (published) |

---

## Types Reference

### Common Types

```typescript
interface WalrusData {
  blobId: string;
  endEpoch: number;
}

interface CoverArt {
  static: WalrusData;
  animated?: WalrusData;
}

interface MusicalKey {
  note: "C" | "D" | "E" | "F" | "G" | "A" | "B";
  accidental: "natural" | "sharp" | "flat";
  mode: "major" | "minor";
}

interface TimeSignature {
  beatsPerMeasure: number;
  beatUnit: number;
}

interface Audio {
  channels: number;      // 1 or 2
  bitDepth: number;      // 16, 24, or 32
  sampleRateHz: number;  // 44100, 48000, 88200, 96000, 176400, 192000
  samples: bigint;
  data: WalrusData;
  pcmDigest: Uint8Array; // 32 bytes
}

interface Stem {
  description: string;
  audio: Audio;
}
```

### Utility Functions

```typescript
// Audio duration calculation
function calculateDurationMs(audio: Audio): number;
function calculateDurationSeconds(audio: Audio): number;

// Move struct constructors
function makeWalrusData(blobId: string, endEpoch: number): TransactionArgument;
function makeCoverArt(coverArt: CoverArt): TransactionArgument;
function makeAudio(audio: Audio): TransactionArgument;
function makeStem(stem: Stem): TransactionArgument;
function makeMusicalKey(key: MusicalKey): TransactionArgument;
function makeTimeSignature(beats: number, unit: number): TransactionArgument;
function makeCompositionRole(role: CompositionRole): TransactionArgument;
function makeRecordingRole(role: RecordingRole): TransactionArgument;

// Type utilities
function parseTypeString(typeString: string): { package: string; module: string; name: string };
function validateShareType(shareType: string): boolean;

// Constants
const SUI_CLOCK_OBJECT_ID: string;
```

---

## Constants

### Share Token

| Constant | Value |
|----------|-------|
| Total Supply | 100,000,000 |
| Decimals | 6 |
| Symbol | "SHARE" |

### Basis Points

| Value | Percentage |
|-------|------------|
| 1 | 0.01% |
| 100 | 1% |
| 1000 | 10% |
| 5000 | 50% |
| 10000 | 100% |

### Limits

| Limit | Value |
|-------|-------|
| Max discs per release | 20 |
| Max tracks per disc | 50 |
| Max stems per recording | 10 |
| Max roles per composition credit | 20 |
| Max roles per recording credit | 10 |
| Max total tracks per release | 255 |

### Default Genres

```typescript
const DEFAULT_GENRES = [
  "AFRICAN", "ALTERNATIVE", "BLUES", "CHILDREN", "CHRISTIAN",
  "CLASSICAL", "COUNTRY", "DANCE", "EASY_LISTENING", "ELECTRONIC",
  "FOLK", "HIPHOP", "HOLIDAY", "INDIE", "JAZZ",
  "LATIN", "METAL", "POP", "RNB", "ROCK", "WORLD"
] as const;
```

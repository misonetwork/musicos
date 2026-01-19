# MusicOS

A blockchain-based music protocol built on the Sui network for managing the complete lifecycle of music—from compositions and recordings to releases—with transparent, automated royalty distribution.

Developed by **Studio Mirai, LLC**.

## Overview

MusicOS is a comprehensive smart contract system that tokenizes music rights and facilitates fair revenue distribution among all contributors in the music value chain. It provides on-chain management for:

- **Compositions** - The written musical works (songs, instrumentals)
- **Recordings** - Audio performances of compositions
- **Releases** - Published collections of tracks (albums, EPs, singles)
- **Contributors** - Individuals and groups who create and produce music
- **Revenue Distribution** - Automated royalty splits via basis points (BPS)

## Core Concepts

### Domain Model

```
┌─────────────────────────────────────────────────────────────┐
│                         RELEASE                             │
│  (Album / EP / Single)                                      │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                      DISC(s)                         │   │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐             │   │
│  │  │  TRACK  │  │  TRACK  │  │  TRACK  │  ...        │   │
│  │  └────┬────┘  └────┬────┘  └────┬────┘             │   │
│  └───────┼────────────┼────────────┼───────────────────┘   │
└──────────┼────────────┼────────────┼────────────────────────┘
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

### Compositions

A composition represents the underlying musical work—the song itself, independent of any recording.

**Properties:**

- Title and alternate titles
- Lyrics (optional)
- Contributors with roles (Composer, Lyricist, Songwriter)
- Split rates for royalty distribution
- Artifacts (sheet music, etc.)

### Recordings

A recording is a specific audio performance of a composition, capturing the master audio and all production details.

**Properties:**

- Master audio file with technical metadata (channels, bit depth, sample rate)
- Genre classification (primary and secondary)
- Artists and featured artists
- Production contributors (Producer, Engineer, Vocalist, etc.)
- Stems (up to 10 separate audio tracks)
- Musical metadata (key, time signature, tempo)

### Releases

A release is a published collection of tracks organized into discs—the final product distributed to listeners.

**Types:**

- **Album** - Full-length release
- **EP** - Extended play (shorter collection)
- **Single** - One or two tracks

**Properties:**

- Multiple discs (up to 50 tracks per disc)
- Cover art (static and animated)
- Track sequence navigation
- Per-track revenue splits

### Contributors

Contributors are individuals or groups who participate in creating music.

**Types:**

- Individual contributors
- Group contributors

**Composition Roles:**

- Composer
- Lyricist
- Songwriter

**Recording Roles:**

- Producer
- Mixing Engineer
- Mastering Engineer
- Recording Engineer
- Vocalist
- Instrumentalist (with instrument specification)
- Arranger
- Sound Designer
- Music Director
- And more...

**Role Levels:**

- Lead, Principal, Featured, Executive
- Associate, Assistant, Additional, Backing

## Revenue Distribution

MusicOS uses a **Basis Points (BPS)** system for precise revenue calculations:

- 1 BPS = 0.01%
- 10,000 BPS = 100%

### Distribution Flow

```
Revenue Received
       │
       ▼
┌──────────────────┐
│ Protocol         │ ◄── Configurable commission (default 1%)
│ Commission       │
└──────────────────┘
       │
       ▼
┌──────────────────┐
│ Track Splits     │ ◄── Percentage per track in release
└──────────────────┘
       │
       ├──────────────────┐
       ▼                  ▼
┌─────────────┐    ┌─────────────┐
│ Composition │    │  Recording  │
│ Share Pool  │    │ Share Pool  │
└─────────────┘    └─────────────┘
       │                  │
       ▼                  ▼
   Shareholders      Shareholders
```

### Share Tokens

Each composition and recording mints its own share tokens:

- **Total Supply:** 100,000,000 tokens per entity
- **Decimals:** 6
- Shares can be held and traded for ownership claims
- Revenue automatically distributed to token holders

## State Management

Entities follow a strict lifecycle with immutability after publication:

### Composition States

```
Created → Published
```

### Recording States

```
Created → Published
```

### Release States

```
Initialized → Created → Published
```

Once published, compositions and recordings become **immutable**—ensuring permanent, auditable records on-chain.

## Usage

### Publishing a Composition

1. Create composition with admin capability
2. Add contributors with their roles
3. Set lyrics (optional)
4. Configure split percentages
5. Publish (requires at least one contributor and valid splits)
6. Create revenue and reward pools

### Creating a Recording

1. Create recording linked to an existing composition
2. Provide master audio (validated by protocol)
3. Add recording contributors with roles
4. Add stems (optional, up to 10)
5. Publish recording

### Releasing Music

1. Create discs with tracks (linking to recordings)
2. Configure track splits (must sum to 100%)
3. Add cover art
4. Publish release
5. Revenue from streams is automatically distributed

## Architecture

### Module Structure

| Module        | Purpose                          |
| ------------- | -------------------------------- |
| `musicos`     | Main entry point                 |
| `protocol`    | Protocol state and configuration |
| `composition` | Composition management           |
| `recording`   | Recording management             |
| `release`     | Release management               |
| `track`       | Individual track entries         |
| `disc`        | Disc organization                |
| `contributor` | Contributor management           |
| `share`       | Share token system               |
| `bps`         | Basis points calculations        |
| `audio`       | Audio file handling              |
| `play`        | Play/listening tracking          |
| `genre`       | Genre classification             |
| `artifact`    | Supplementary files              |
| `stem`        | Audio stem management            |

### Security Model

- **Capability-based authorization** - Admin caps control access
- **Derived objects** - Secure capability chaining
- **Validation at every step** - Contributor counts, split sums, audio specs
- **Event emission** - All state changes are auditable on-chain

### Extensibility

- **Dynamic fields** - Add metadata without protocol changes
- **Pluggable authorities** - Audio creation, play tracking, contributor verification
- **Artifact system** - Support for additional file types

## Integration

MusicOS integrates with:

- **Sui Framework** - Events, dynamic fields, derived objects, clock
- **ISO 639-1** - Language code support
- **Revenue/Reward Pools** - Financial distribution
- **MUSIC Token** - Native token integration

## Key Principles

1. **Immutability** - Published works are permanent and unalterable
2. **Transparency** - All transactions and state changes are on-chain
3. **Precision** - BPS system ensures accurate financial calculations
4. **Modularity** - Clean separation of concerns across modules
5. **Extensibility** - Dynamic fields and pluggable systems allow growth
6. **Authorization** - Capability-based security at every level

## Error Code System

MusicOS uses a standardized error code numbering system across all modules. Error codes are grouped by category to provide consistent, predictable error handling.

### Error Code Ranges

| Range | Category | Description |
|-------|----------|-------------|
| 0 | Authorization | Permission and capability failures |
| 1-9 | State Machine | Invalid state transitions |
| 10-19 | Bounds/Limits | Index out of bounds, max limits exceeded |
| 20-29 | Validation | Invalid input, format, or configuration |
| 30-39 | Existence/Conflict | Duplicate entries, missing entities |

### Error Codes by Module

#### Authorization (0)
- `EUnauthorized` (0) - Admin capability does not match the entity
- `EInvalidAudioCreationAuthority` (0) - Authority type not registered for audio creation

#### State Machine (1-9)
- `ENotInitializedState` (1) - Operation requires Initialized state
- `ENotCreatedState` (2) - Operation requires Created state
- `ENotActiveState` (3) - Protocol/plugin not in Active state
- `ENotPublishedState` (4) - Operation requires Published state
- `ENotPausedState` (5) - Protocol not in Paused state
- `ENotDeprecatingState` (6) - Protocol not in Deprecating state
- `ENotDeprecatedState` (7) - Protocol not in Deprecated state
- `EAlreadyDeprecatedState` (8) - Protocol already deprecated
- `EDeprecationDelayNotElapsed` (9) - Deprecation delay period not complete
- `ENotEnabledState` (3) - Plugin not in Enabled state
- `ENotDisabledState` (4) - Plugin not in Disabled state

#### Bounds/Limits (10-19)
- `EMaxDiscsReached` (10) - Release exceeds maximum disc count
- `EMaxTracksExceeded` (10) - Disc exceeds maximum track count
- `EMaxStemsExceeded` (10) - Recording exceeds maximum stem count
- `EMaxSequenceLengthExceeded` (10) - Track sequence exceeds 255 tracks
- `EExceedsMaxRoles` (10) - Contributor role count exceeds maximum
- `EMinRolesNotMet` (11) - Contributor role count below minimum
- `EDiscIndexOutOfBounds` (11) - Disc index exceeds disc count
- `EContributorRoleIndexOutOfBounds` (12) - Role index exceeds role count
- `ETrackIndexOutOfBounds` (12) - Track index exceeds track count
- `ESequenceIndexOutOfBounds` (13) - Sequence index exceeds total tracks

#### Validation (20-29)
- `ENoDiscs` (20) - Release must contain at least one disc
- `ENoContributors` (20) - Entity must have at least one contributor
- `EInvalidTrackSplitsLength` (20) - Track splits count doesn't match track count
- `EInvalidTrackSplitsSum` (21) - Track splits don't sum to 100% (10,000 BPS)
- `ENoRevenueToDistribute` (22) - Revenue pool has no funds
- `EUnsupportedBitDepth` (20) - Audio bit depth not supported
- `EUnsupportedChannels` (21) - Audio channel count not supported
- `EUnsupportedSampleRate` (22) - Audio sample rate not supported
- `EOverflow` (20) - BPS calculation overflow
- `EUnderflow` (21) - BPS calculation underflow
- `EDivideByZero` (22) - BPS division by zero
- `EInvalidDecimals` (20) - Share token decimals invalid
- `EInvalidSymbol` (21) - Share token symbol invalid
- `ENotZeroSupply` (22) - Share token supply must be zero

#### Existence/Conflict (30-39)
- `EDuplicateContributor` (30) - Contributor already exists in entity
- `EContributorRoleAlreadyExists` (30) - Role already assigned to contributor
- `ENotIndividualKind` (31) - Operation requires Individual contributor
- `ENotGroupKind` (32) - Operation requires Group contributor

### Design Principles

1. **Consistency** - Same error type uses same code across modules
2. **Predictability** - Error ranges indicate error category
3. **Debugging** - Code range helps identify error source quickly
4. **Extensibility** - Gaps in ranges allow new errors without renumbering

## License

Apache 2.0 - Studio Mirai, LLC

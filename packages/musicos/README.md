# MusicOS

A blockchain-based music protocol built on the Sui network for managing the complete lifecycle of music—from compositions and recordings to releases—with transparent, automated royalty distribution.

Developed by **Sona Labs**.

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

## License

Proprietary - Sona Labs

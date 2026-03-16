# MusicOS: A Permissionless Protocol for Programmable Music Rights and Distribution

**Version 1.0 — February 2026**

Subsonic Labs, LLC — os@subsoniclabs.io

---

## Abstract

The music industry operates on infrastructure built for the physical distribution era: opaque royalty pipelines, fragmented ownership databases, and intermediaries whose value increasingly derives from positional control rather than creative contribution. An estimated $2.5 billion in royalties go unclaimed annually due to incomplete or conflicting metadata, while artists remain structurally unable to verify how revenue flows from consumption to payment. The emergence of generative AI compounds the problem by commoditizing audio production itself, eroding the already-thin margin artists capture from distribution.

We present MusicOS, a permissionless protocol on the Sui blockchain that provides a comprehensive on-chain data model for music compositions, recordings, releases, and the parties involved in their creation. Unlike prior blockchain music projects that operate as platforms, MusicOS is infrastructure: a self-hosted, extensible protocol — analogous to WordPress — where any participant can deploy extensions without permission from a central authority. MusicOS introduces _programmable music_, a paradigm in which audio files are inseparable from the on-chain economic logic governing their ownership, revenue distribution, and licensing terms. By encoding the full structure of music rights — the distinction between compositions and recordings, multi-party credit attribution, basis-point revenue splits, and share-token ownership — directly into smart contracts, MusicOS creates a verifiable, deterministic, and agent-compatible distribution layer for the music industry.

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Background and Motivation](#2-background-and-motivation)
   - 2.1 [The Structure of Music Rights](#21-the-structure-of-music-rights)
   - 2.2 [Infrastructure Failures in the Current Industry](#22-infrastructure-failures-in-the-current-industry)
   - 2.3 [The Commoditization of Audio](#23-the-commoditization-of-audio)
   - 2.4 [Limitations of Existing Blockchain Approaches](#24-limitations-of-existing-blockchain-approaches)
3. [Protocol Design](#3-protocol-design)
   - 3.1 [Design Principles](#31-design-principles)
   - 3.2 [Core Objects](#32-core-objects)
   - 3.3 [Object Lifecycle and State Machines](#33-object-lifecycle-and-state-machines)
   - 3.4 [The Party and Credit System](#34-the-party-and-credit-system)
   - 3.5 [Audio Verification](#35-audio-verification)
   - 3.6 [Deterministic Object Addressing](#36-deterministic-object-addressing)
4. [The Extension System](#4-the-extension-system)
   - 4.1 [Motivation: The WordPress Model](#41-motivation-the-wordpress-model)
   - 4.2 [Registration and Witness-Gated Access](#42-registration-and-witness-gated-access)
   - 4.3 [Raw UID Access and Future Compatibility](#43-raw-uid-access-and-future-compatibility)
   - 4.4 [Extension Isolation and Trust Model](#44-extension-isolation-and-trust-model)
5. [Revenue Distribution and Token Economics](#5-revenue-distribution-and-token-economics)
   - 5.1 [Share Tokens](#51-share-tokens)
   - 5.2 [Basis-Point Revenue Splits](#52-basis-point-revenue-splits)
   - 5.3 [Release Revenue Distribution](#53-release-revenue-distribution)
   - 5.4 [Reward Pools](#54-reward-pools)
   - 5.5 [Multi-Currency Support](#55-multi-currency-support)
6. [The Deal Protocol](#6-the-deal-protocol)
7. [Decentralized Media Storage](#7-decentralized-media-storage)
8. [Agent Compatibility and Programmable Music](#8-agent-compatibility-and-programmable-music)
   - 8.1 [From DDEX Messaging to Declarative Execution](#81-from-ddex-messaging-to-declarative-execution)
   - 8.2 [Agent-Native Interfaces](#82-agent-native-interfaces)
   - 8.3 [Programmable Music as a New Distribution Format](#83-programmable-music-as-a-new-distribution-format)
9. [Comparison with Related Work](#9-comparison-with-related-work)
10. [Discussion](#10-discussion)
    - 10.1 [Trust Assumptions](#101-trust-assumptions)
    - 10.2 [Limitations and Trade-offs](#102-limitations-and-trade-offs)
    - 10.3 [Future Work](#103-future-work)
11. [Conclusion](#11-conclusion)

---

## 1. Introduction

The global recorded music industry generated $28.6 billion in revenue in 2023 [1], yet the infrastructure connecting creators to that revenue remains remarkably primitive. Ownership data is scattered across disconnected databases maintained by performing rights organizations (PROs), mechanical licensing bodies, publishers, labels, and distributors — each operating with incomplete and often contradictory records. When a song is streamed, the revenue it generates passes through a chain of intermediaries, each applying proprietary calculations that the rights holders themselves cannot independently verify. The result is an industry where the people who create music are structurally the least informed about how it is monetized.

This paper introduces MusicOS, a permissionless protocol built on the Sui blockchain that provides the foundational data model and economic logic for music rights management and distribution. MusicOS does not aim to replace the music industry's participants — artists, labels, publishers, distributors, and platforms all have meaningful roles — but rather to replace the _infrastructure_ those participants operate on. The distinction is important: MusicOS is not an application but a protocol, not a platform but a substrate.

The protocol makes three primary contributions:

1. **A faithful on-chain data model for music rights.** MusicOS encodes the actual structure of music industry rights — the legal distinction between compositions (written works) and recordings (audio performances), multi-party credit attribution with role-specific classifications, and hierarchical revenue splits — rather than simplifying it into token-gated access or NFT collectibles.

2. **A permissionless extension architecture.** Inspired by WordPress, MusicOS allows any developer to deploy extension packages that attach new functionality to core protocol objects without requiring modification to or permission from the core protocol. Extensions interact with parent objects through witness-gated UID access, enabling immediate adoption of new Sui framework primitives without core protocol upgrades.

3. **Programmable music as a distribution format.** By binding audio files stored on decentralized storage (Walrus) to on-chain economic logic — ownership shares, revenue splits, credit attribution, and extension-defined behavior — MusicOS creates a new kind of distributable artifact: one where the music and its economics are inseparable and machine-readable.

The remainder of this paper is organized as follows. Section 2 provides background on the structure of music rights and the infrastructure failures that motivate MusicOS. Section 3 presents the core protocol design. Section 4 details the extension system. Section 5 describes the revenue distribution model and token economics. Section 6 covers the deal protocol for recording-to-release authorization. Section 7 discusses decentralized media storage via Walrus. Section 8 introduces the concept of agent compatibility and programmable music. Section 9 compares MusicOS with related work. Section 10 discusses trust assumptions, limitations, and future directions.

---

## 2. Background and Motivation

### 2.1 The Structure of Music Rights

To understand why music industry infrastructure is broken, one must first understand how music rights actually work. Every piece of recorded music involves at least two distinct sets of rights:

**Composition rights** cover the underlying written work — the melody, harmony, and lyrics. These are held by songwriters and publishers. A single composition can have multiple recordings (a cover version, a remix, a live performance), and each recording generates revenue that must be split between the composition rights holders and the recording rights holders.

**Recording rights** (often called "master rights") cover the specific audio performance of a composition. These are held by performing artists and labels. A recording cannot exist without an underlying composition, and the revenue it generates is subject to a pre-negotiated split between the composition and recording sides.

**Releases** (albums, EPs, singles) aggregate multiple recordings into distributable products. Each recording on a release may have different rights holders, different composition-recording splits, and different revenue allocations.

This three-layer structure — composition, recording, release — is not an implementation detail. It is the legal and economic reality of the music industry, codified in copyright law across virtually every jurisdiction. Any protocol that claims to represent music rights must model this structure faithfully. Flattening it into "one NFT per song" discards the information that the industry's economic relationships depend on.

### 2.2 Infrastructure Failures in the Current Industry

The music industry's infrastructure failures are interconnected and self-reinforcing:

**The black box problem.** When a listener streams a song on Spotify, Apple Music, or any other digital service provider (DSP), the revenue generated by that stream enters a pipeline that the rights holders cannot independently audit. DSPs report usage to distributors, who report to labels, who report to artists — each step introducing latency, opacity, and the potential for error or extraction. An artist receiving a quarterly royalty statement has no mechanism to verify its accuracy against the underlying consumption data.

**The unmatched royalties crisis.** The Music Modernization Act of 2018 established the Mechanical Licensing Collective (MLC) in the United States to address the problem of unmatched mechanical royalties — payments owed to songwriters and publishers that cannot be distributed because the ownership data is incomplete or conflicting. As of recent reporting, the MLC holds hundreds of millions of dollars in unmatched royalties [2]. This is not a bug in an otherwise functional system; it is the predictable consequence of an industry that has never had a single, authoritative, openly verifiable source of ownership data.

**Licensing complexity as a barrier.** The distinction between composition rights and recording rights means that any entity wishing to use a piece of music commercially must often negotiate with multiple rights holders across multiple organizations. PROs (ASCAP, BMI, SESAC) handle public performance rights for compositions. The MLC handles mechanical rights. Labels handle master use licenses. Publishers handle synchronization rights. Each operates its own database, its own payment schedule, and its own fee structure. The result is a system where licensing a single song for a single use case can require navigating half a dozen organizations with no shared infrastructure.

**Data fragmentation.** There is no canonical global database of music ownership. The International Standard Recording Code (ISRC) identifies recordings, and the International Standard Work Code (ISWC) identifies compositions, but these identifiers are inconsistently applied, frequently duplicated, and not programmatically linked to ownership or payment information. The metadata that connects a stream to a payment is maintained in proprietary databases that do not interoperate.

### 2.3 The Commoditization of Audio

These infrastructure failures exist against a backdrop of accelerating change. Generative AI has reduced the marginal cost of audio production toward zero. Tools for AI-assisted composition, arrangement, and mastering are widely available and improving rapidly. The implications for artists are stark: if the primary unit of distribution is the audio file, and audio files are becoming trivially cheap to produce, then the economic position of human creators within the distribution pipeline will continue to erode.

This is not an argument against AI in music. It is an argument for expanding what music distribution means. When audio alone is a commodity, the value that human artists contribute — creative intent, cultural context, collaborative relationships, the social and economic networks surrounding a work — must be captured in the distribution format itself. An audio file sitting on a server captures none of this. A programmable on-chain object that binds the audio to its ownership structure, credit attribution, revenue logic, and extensible metadata captures all of it.

MusicOS proposes that the unit of music distribution should not be the audio file. It should be the _programmable composition-recording-release structure_ — a machine-readable, economically complete representation of a musical work and all the relationships it embodies.

### 2.4 Limitations of Existing Blockchain Approaches

Several blockchain-based music projects have emerged in recent years, each addressing some aspect of the problems described above. Audius provides a decentralized streaming platform. Sound.xyz enables artists to sell limited-edition recordings as NFTs. Royal allows fans to purchase fractional streaming royalty rights. These projects have demonstrated demand for blockchain-based music infrastructure, but they share common limitations:

**Platform, not protocol.** Most blockchain music projects are applications with their own user interfaces, token economies, and governance structures. They are destinations, not infrastructure. An artist using Audius is using Audius; they are not building on a permissionless protocol that any application can integrate.

**Simplified data models.** Existing projects typically model music as a single asset (an NFT, a token, a stream) rather than faithfully representing the composition-recording-release hierarchy that governs real-world music rights. This simplification may be adequate for collectibles and fan engagement, but it cannot support the full range of music industry operations — mechanical licensing, synchronization rights, multi-party revenue splits, and inter-organizational data exchange.

**Permissioned extension.** Adding new functionality to existing blockchain music platforms typically requires the platform's cooperation. There is no mechanism for independent developers to extend the protocol's capabilities without modifying the core codebase or obtaining approval from its maintainers.

MusicOS addresses each of these limitations. It is a protocol, not a platform. It models the full structure of music rights. And its extension system allows anyone to build on top of it without permission.

---

## 3. Protocol Design

### 3.1 Design Principles

MusicOS is built on the Sui blockchain using the Move programming language. The protocol's design is guided by four principles:

**Fidelity to real-world rights structures.** The on-chain data model must faithfully represent the legal and economic relationships that govern music rights. Simplifications that discard information needed for real-world operations are rejected in favor of completeness.

**Immutability after publication.** Core music metadata — compositions, recordings, and releases — follow a state machine from mutable (Initialized) to immutable (Published). Once published, an object becomes a shared object on Sui, readable by anyone and modifiable by no one. This ensures that the authoritative record of a musical work cannot be retroactively altered.

**Capability-based authorization.** Every mutable operation on a MusicOS object requires a corresponding admin capability (`CompositionAdminCap`, `RecordingAdminCap`, `ReleaseAdminCap`, `PartyAdminCap`). Capabilities are standard Sui objects that can be transferred, shared, or held in custody, enabling flexible governance models without hard-coding authorization logic into the protocol.

**Extensibility without permission.** The core protocol provides the data model and lifecycle management. All additional functionality — revenue distribution, reward pools, metadata enrichment, licensing automation — is implemented as extensions that any developer can deploy independently.

### 3.2 Core Objects

MusicOS defines four primary on-chain objects:

**Composition\<S\>.** Represents the underlying written work (melody, lyrics, harmony). Parameterized by a phantom share token type `S` that links the composition to its ownership token. Contains the title, alternate titles, credits (a mapping of party IDs to roles), a basis-point revenue split, and optional content references (lyrics, chart, score, demo audio) stored on Walrus.

```
Composition<S> {
    id: UID,
    state: Initialized | Published(timestamp),
    title: String,
    alternate_titles: vector<String>,         // max 5
    credits: VecMap<ID, Credit<Role>>,        // max 50
    split_bps: BPS,                           // composition's share of revenue
    lyrics: Option<WalrusData>,
    chart: Option<WalrusData>,
    score: Option<WalrusData>,
    demo: Option<Audio>,
}
```

**Recording\<S\>.** Represents an audio performance of a composition. Contains rich musical metadata (genre, key, tempo, time signature), the master audio file, individual audio stems (minimum 2), cover art, and credit attribution with 23 role types. Each recording references its parent composition and captures the composition's revenue split at creation time.

```
Recording<S> {
    id: UID,
    state: Initialized | Published(timestamp),
    title: String,
    composition_id: ID,
    composition_split_bps: BPS,               // captured at creation
    primary_genre_id: ID,
    secondary_genre_ids: VecSet<ID>,          // max 3
    primary_artist_ids: VecSet<ID>,           // max 20
    featured_artist_ids: VecSet<ID>,          // max 50
    credits: VecMap<ID, Credit<Role>>,        // max 150
    language: Option<LanguageCode>,
    is_explicit: bool,
    is_instrumental: bool,
    lyrics: Option<WalrusData>,               // WebVTT format
    musical_key: Option<MusicalKey>,
    time_signature: Option<TimeSignature>,
    tempo_bpm: Option<u16>,
    master: Audio,                            // required
    stems: vector<Stem>,                      // min 2, max 100
    cover_art: CoverArt,
}
```

**Release.** Represents a distributable collection of recordings — an album, EP, or single. Organizes tracks into discs, supports release-level credits (Primary and Featured artists), and contains the revenue distribution logic that splits incoming payments across tracks and their underlying compositions and recordings.

```
Release {
    id: UID,
    kind: Album | EP | Single,
    state: Initialized(has_primary) | Published(timestamp),
    title: String,
    subtitle: Option<String>,
    description: String,
    credits: VecMap<ID, Credit<Role>>,        // max 50
    discs: vector<Disc>,                      // max 20
    cover_art: CoverArt,
}
```

**Party.** Represents any entity involved in the creation or management of music — an individual artist, producer, engineer, or a group (band, orchestra, choir). Groups can contain references to individual party members.

```
Party {
    id: UID,
    kind: Individual | Group(VecSet<ID>),     // groups: max 200 members
    name: String,
}
```

### 3.3 Object Lifecycle and State Machines

Compositions, recordings, and releases follow a two-state lifecycle:

```
Initialized ──publish()──> Published
```

In the **Initialized** state, the object is owned by its creator and can be freely modified: adding credits, setting metadata, attaching content. All mutating functions enforce state guards and abort if called on a published object.

The **publish()** transition is irreversible. It validates completeness constraints (compositions must have at least one credit and one content attachment; recordings must have credits, a primary artist, and at least two stems; releases must have a primary credit and valid track assignments), records a publication timestamp from the Sui Clock, and converts the object into a Sui shared object — publicly readable and permanently immutable.

This lifecycle ensures that published music metadata constitutes a permanent, tamper-proof record. Extensions can attach additional data to published objects via dynamic fields, but the core metadata is fixed.

### 3.4 The Party and Credit System

Attribution in the music industry is not a simple list of names. A recording typically involves dozens of credited parties, each with specific roles: producer, vocalist, mixing engineer, mastering engineer, instrumentalist, and many others. MusicOS models this with a generic credit system:

```
Credit<Role> {
    roles: vector<Role>,
}
```

The `Role` type parameter is specialized per context:

- **CompositionPartyRole**: Composer, Lyricist, Songwriter, Arranger, Adapter, Translator
- **RecordingPartyRole**: 23 role variants including Producer, Vocalist, MixingEngineer, MasteringEngineer, Instrumentalist, Conductor, and others. Many roles support optional level qualifiers (Lead, Featured, Assistant, etc.)
- **ReleasePartyRole**: Primary, Featured

A party must be credited on a recording before they can be designated as a primary or featured artist. Stem contributors must be credited on the recording before their contributions can be registered. These referential integrity constraints ensure that the credit graph is internally consistent.

### 3.5 Audio Verification

MusicOS uses a _hot potato pattern_ for audio verification — a technique unique to the Move programming language where an object with no abilities (it cannot be stored, copied, dropped, or transferred) must be consumed within the same transaction that created it.

```
new() → UnverifiedAudio     // no abilities — must be consumed
verify<V>(unverified, witness) → Audio    // storable, copyable
```

The `UnverifiedAudio` struct has no abilities, meaning the Sui runtime will reject any transaction that creates one without also consuming it via `verify()`. The verifier's witness type is recorded in the resulting `Audio` struct, creating a permanent on-chain attestation of who verified the audio data and its technical parameters (channels, bit depth, sample rate, sample count).

This pattern enables pluggable verification — different verifiers can implement different validation strategies (format checking, watermark detection, content fingerprinting) while the core protocol guarantees that _some_ verification occurred before any audio is stored.

### 3.6 Deterministic Object Addressing

MusicOS uses Sui's derived object mechanism to generate deterministic addresses for admin capabilities and recordings. A `CompositionAdminCap` is derived from its parent composition's UID, meaning the capability's address can be computed client-side from the composition's address alone — no indexer query required.

Similarly, a recording's address is derived from its parent composition's UID using the master audio's verifier type as a derivation key. This creates a discoverable, deterministic mapping from compositions to their recordings.

Releases use a content-addressed derivation: the release UID is derived from a Blake2b-256 hash of its recording IDs, track split values, and a caller-provided nonce (`u256`). This ensures that collaborators can coordinate a deterministic release address offchain before creating Deals.

---

## 4. The Extension System

### 4.1 Motivation: The WordPress Model

MusicOS is designed like WordPress: an open-source, self-hosted protocol where you install whatever plugins you want. The admin capability holder is the site admin — they choose which extensions to register and accept the trust implications of that choice.

This design reflects a deliberate philosophy: the core protocol should provide the data model and lifecycle management, while all application-specific behavior lives in extensions. Revenue distribution, reward pools, licensing automation, metadata enrichment, discovery algorithms, and social features are all extension concerns. The core protocol provides the hooks; the ecosystem provides the functionality.

A more managed layer — analogous to WordPress.com — can be built on top of MusicOS. This layer would handle custody of admin capabilities and enforce extension whitelists, providing guardrails for participants who want them without restricting the protocol's permissionless nature.

### 4.2 Registration and Witness-Gated Access

Extensions are registered on a per-object basis. The object owner (holder of the admin capability) calls `register_extension` with three arguments: the admin capability (proving ownership), an extension witness (identifying the extension module), and a configuration value (extension-specific settings).

```move
composition.register_extension(
    &composition_admin_cap,
    my_extension::Extension(),
    config,
);
```

Once registered, an extension can access the parent object's UID mutably through `uid_mut_with_extension`, which performs two checks: that the caller provides the extension's witness type (only the defining module can construct it) and that the extension is registered on this specific object.

```move
public fun uid_mut_with_extension<E: drop>(
    self: &mut Composition<S>,
    _extension: E,
): &mut UID {
    extension::assert_registered<E>(&self.id);
    &mut self.id
}
```

### 4.3 Raw UID Access and Future Compatibility

A critical design decision in MusicOS is that extensions receive raw `&mut UID` access to the parent object rather than a restricted API surface. This is deliberate: Sui's core primitives — fund accumulators, derived objects, coin receiving, dynamic fields — all operate on `&mut UID`. New primitives are added to the Sui framework regularly. If MusicOS wrapped each UID operation into a delegated function on the core module, every new Sui primitive would require a core protocol upgrade before extensions could use it.

Raw UID access ensures extensions can adopt new Sui capabilities immediately, without waiting for or depending on the core package. The protocol evolves with the blockchain rather than lagging behind it.

### 4.4 Extension Isolation and Trust Model

The trade-off of raw UID access is that a registered extension has broad access to the parent's UID — it could theoretically interfere with other extensions' dynamic fields. This is an accepted consequence of the permissionless model.

Extension isolation is achieved through convention rather than enforcement:

- Each extension's configuration is stored using a phantom-parameterized dynamic field key: `Extension<phantom E: drop>()`. The phantom type `E` ensures each extension has a unique storage slot.
- Extensions can be registered and unregistered regardless of the object's lifecycle state. This is intentional — extensions like reward pools are designed to operate on published (shared) objects.
- The `register` and `unregister` functions are `public(package)`, ensuring only the MusicOS core package can add or remove extension keys through the gated entry points on each core object.

The trust model is explicit: the admin capability holder is responsible for evaluating which extensions to register. This mirrors the real-world responsibility of a WordPress administrator choosing which plugins to install.

| Model                 | UID Access                            | Isolation     | Best For                                                   |
| --------------------- | ------------------------------------- | ------------- | ---------------------------------------------------------- |
| **MusicOS (raw UID)** | `&mut UID` via witness + registration | By convention | Permissionless protocols needing full Sui primitive access |
| **Bag-based**         | None — extensions get `&mut Bag`      | Structural    | Generic primitives with untrusted extensions               |
| **Registry-based**    | `&mut UID` via witness + Settings     | By convention | Managed systems with centralized extension control         |

---

## 5. Revenue Distribution and Token Economics

### 5.1 Share Tokens

Each composition and recording mints its own fungible share token at creation time. These tokens represent ownership stakes that determine how revenue is distributed.

**Parameters:**

- **Supply:** 10,000,000.000000 tokens (fixed, immutable after initialization)
- **Decimals:** 6 (enabling fractional ownership to one-millionth precision)
- **Symbol:** SHARE

The share token is initialized through a validation pipeline that enforces currency configuration correctness: the `Currency` object must have exactly 6 decimals, the symbol must be "SHARE", the metadata capability must have been deleted (preventing later modification), and the supply must be zero prior to minting. After minting the full supply, the treasury capability is consumed to make the supply permanently fixed.

Share tokens are standard Sui fungible tokens. They can be transferred, split, merged, held in custody, or governed by any on-chain logic — including extension-defined logic such as vesting schedules, lockups, or automated market makers.

### 5.2 Basis-Point Revenue Splits

All revenue percentages in MusicOS are expressed in basis points (BPS), where 1 BPS = 0.01% and 10,000 BPS = 100%. This convention is standard in financial services and provides sufficient precision for music industry revenue splits without introducing floating-point arithmetic.

Two types of splits govern revenue flow:

**Composition split (`split_bps`).** Set on the composition, this determines what percentage of a track's revenue is allocated to the composition side vs. the recording side. For example, a split of 5,000 BPS means 50% of track revenue flows to composition share holders and 50% to recording share holders. This split is captured on the recording at creation time, ensuring it cannot be retroactively changed by the composition owner.

**Track split (`split_bps` on Track).** Set when a track is added to a release, this determines what percentage of the release's total revenue is allocated to each track. All track splits on a release must sum to exactly 10,000 BPS (100%), enforced at release creation time.

### 5.3 Release Revenue Distribution

When revenue is distributed on a release, the protocol executes a deterministic two-level split:

```
Revenue enters Release
    │
    ├── Track 1: revenue × track_1_split_bps
    │   ├── Composition: track_1_amount × composition_split_bps
    │   └── Recording:   track_1_amount × (1 - composition_split_bps)
    │
    ├── Track 2: revenue × track_2_split_bps
    │   ├── Composition: track_2_amount × composition_split_bps
    │   └── Recording:   track_2_amount × (1 - composition_split_bps)
    │
    └── ... (all tracks)

Rounding dust → returned to Release
```

Revenue is forwarded to composition and recording objects via Sui's fund accumulator pattern (hikida), where it becomes available for share-token-based claiming through reward pool extensions. The entire flow — from release-level revenue to per-share-holder claims — is executed on-chain, deterministic, and independently verifiable.

### 5.4 Reward Pools

The composition and recording reward pool extensions enable proportional revenue distribution to share token holders:

1. The object owner registers the reward pool extension.
2. Anyone can create a currency-specific reward pool attached to the object.
3. Revenue accumulated in the object's fund accumulator is redeemed and deposited into the reward pool.
4. Share token holders stake their tokens and claim rewards proportional to their stake.

The reward pools use an _open distribution_ model — any share holder can stake and claim without additional authorization. This ensures that revenue distribution is permissionless once the extension is registered.

**Example:** A composition has 10,000,000 SHARE tokens distributed among three songwriters: Alice (5,000,000), Bob (3,000,000), and Carol (2,000,000). When 1,000 SUI in revenue is deposited into the composition's reward pool, Alice can claim 500 SUI, Bob can claim 300 SUI, and Carol can claim 200 SUI — proportional to their stakes.

### 5.5 Multi-Currency Support

Each currency type receives its own independent reward pool. A single composition or recording can simultaneously accumulate and distribute revenue in SUI, USDC, or any other Sui-native token. This is implemented through generic type parameters on the reward pool functions, requiring no protocol changes to support new currencies.

---

## 6. The Deal Protocol

The connection between recordings and releases is mediated by the **Deal** object — an explicit, on-chain authorization from a recording owner to include their recording on a specific release.

```
Recording Owner ──creates Deal──> Deal ──consumed by──> Track ──added to──> Release
```

A deal captures the recording's metadata at creation time (composition ID, revenue splits, audio verifier types, duration, cover art) and binds it to a target release ID and a track-level revenue split. The recording owner creates the deal using their `RecordingAdminCap`, providing explicit authorization for the recording's inclusion.

When a track is created, it consumes the deal (the deal object is destroyed), transferring the authorization and metadata into the track structure. Tracks are then organized into discs and assembled into a release. This flow models the real-world process of licensing a recording for inclusion on a release: the master rights holder (recording owner) explicitly authorizes the use on specific terms.

Deals can be destroyed without being consumed if negotiations fall through, emitting a `DealDestroyedEvent` for off-chain tracking.

---

## 7. Decentralized Media Storage

Audio files, lyrics, charts, scores, and cover art are not stored on-chain. Instead, MusicOS stores references to data on **Walrus**, a decentralized blob storage network built on Sui [3]. Each media reference is a `WalrusData` struct containing a Walrus blob ID that can be used to retrieve the data from the Walrus network.

This separation of concerns — on-chain metadata and economic logic, off-chain media storage — reflects the different requirements of each data type:

- **Metadata and economics** require strong consistency, deterministic execution, and permanent immutability. These properties are provided by the Sui blockchain.
- **Media files** require high-bandwidth storage and retrieval at low cost. These properties are provided by Walrus's erasure-coded storage network, which achieves a 4-5x replication factor while tolerating up to two-thirds of storage nodes being unavailable [3].

The combination ensures that a published MusicOS object is a complete, self-contained representation of a musical work: the on-chain object contains all the metadata and economic logic, while the Walrus references provide access to the actual audio and visual content.

---

## 8. Agent Compatibility and Programmable Music

### 8.1 From DDEX Messaging to Declarative Execution

The music industry's closest existing analog to a distribution protocol is DDEX (Digital Data Exchange), a set of XML-based messaging standards used by labels, distributors, and DSPs to communicate metadata and delivery instructions. DDEX defines the _messages_ — what information is exchanged — but not the _execution_ — what happens when a message is received, how it is validated, or what downstream processes it triggers. Each participant in a DDEX exchange implements their own interpretation of the messages, resulting in inconsistent behavior across the industry.

MusicOS inverts this model. Rather than defining messages that participants interpret independently, MusicOS defines _state transitions_ that execute deterministically on a shared runtime. Creating a composition, adding a credit, publishing a recording, distributing revenue — these are not messages to be interpreted but transactions to be executed. The Sui blockchain guarantees that every participant observes the same state and the same execution semantics.

This shift from messaging to declarative execution has profound implications for automation.

### 8.2 Agent-Native Interfaces

AI agents require deterministic, programmatically accessible interfaces. They cannot navigate ambiguous messaging protocols or interpret inconsistently implemented workflows. MusicOS provides exactly what agents need:

- **Deterministic state transitions.** Every function has explicit preconditions (state guards, authorization checks, constraint validations) and postconditions (state changes, event emissions). An agent can reason about what a function will do before calling it.
- **On-chain verifiability.** Every operation produces a verifiable on-chain state change. An agent does not need to trust an API response; it can verify the state directly.
- **Composable transactions.** Sui's programmable transaction blocks allow agents to compose multi-step workflows — create a deal, create a track, assemble a disc, publish a release — into a single atomic transaction.
- **Event-driven coordination.** Every significant state change emits a typed event (e.g., `CompositionPublishedEvent`, `ReleaseRevenueDistributedEvent`), enabling agents to subscribe to and react to protocol activity.

An AI agent managing an artist's catalog could autonomously: monitor revenue accumulation, trigger distributions, negotiate deal terms by creating and destroying deal objects, and publish new releases — all through direct interaction with MusicOS smart contracts, or through an API layer built on top of the protocol for a more ergonomic experience.

### 8.3 Programmable Music as a New Distribution Format

The convergence of these properties — a faithful data model, deterministic economics, decentralized storage, and agent compatibility — produces something that does not exist in the current music industry: a _programmable_ distribution format.

In the traditional industry, distributing music means delivering an audio file and a metadata sidecar (typically DDEX XML) to a DSP. The audio is a commodity. The metadata is loosely structured and inconsistently interpreted. The economics are opaque and intermediated.

In MusicOS, distributing music means publishing an on-chain object that _is_ the authoritative record of the work: who created it, who owns it, how revenue flows, what audio and visual content is associated with it, and what extensions govern its behavior. The object is machine-readable, independently verifiable, and economically self-executing. It is not a file accompanied by metadata; it is a programmable entity that embodies the full creative, economic, and legal context of a musical work.

This is particularly important in an era of AI-generated content. When the cost of producing audio approaches zero, the scarce resource is not the audio itself but the human creative and economic context surrounding it. Programmable music captures that context on-chain, making it inseparable from the work it describes.

---

## 9. Comparison with Related Work

|                          | **MusicOS**                                                      | **Audius**          | **Sound.xyz**              | **Royal**                      | **DDEX**                                       |
| ------------------------ | ---------------------------------------------------------------- | ------------------- | -------------------------- | ------------------------------ | ---------------------------------------------- |
| **Type**                 | Protocol                                                         | Platform            | Platform                   | Platform                       | Messaging standard                             |
| **Data model**           | Composition / Recording / Release hierarchy                      | Tracks              | Tracks (NFTs)              | Tracks (fractional)            | XML schemas                                    |
| **Rights structure**     | Full (composition vs. recording, role-based credits, BPS splits) | Simplified          | Simplified                 | Simplified                     | Comprehensive (messages only)                  |
| **Extensibility**        | Permissionless extensions via witness-gated UID access           | Platform-controlled | Platform-controlled        | Platform-controlled            | N/A                                            |
| **Revenue distribution** | On-chain, deterministic, share-token-based                       | Platform-mediated   | Secondary market royalties | Streaming royalty pass-through | Defined in messages, implemented by each party |
| **Audio storage**        | Walrus (decentralized)                                           | IPFS / Audius nodes | Arweave                    | Centralized                    | N/A (delivery, not storage)                    |
| **Agent compatibility**  | Native (deterministic state transitions)                         | API-dependent       | API-dependent              | API-dependent                  | Message interpretation varies                  |
| **Blockchain**           | Sui (Move)                                                       | Solana / Ethereum   | Ethereum / Optimism        | Ethereum / Polygon             | N/A                                            |

MusicOS occupies a unique position: it provides DDEX-level data model fidelity with blockchain-native execution semantics and permissionless extensibility. It is neither a consumer-facing platform nor a messaging standard, but a protocol layer that both platforms and agents can build on.

---

## 10. Discussion

### 10.1 Trust Assumptions

MusicOS inherits the security guarantees of the Sui blockchain: safety and liveness under the assumption that at most one-third of validators (by stake) are Byzantine. Within this assumption, all MusicOS state transitions are deterministic and verifiable.

The extension system introduces an additional trust assumption: the admin capability holder must evaluate and accept the trust implications of each extension they register. A malicious extension with raw UID access could interfere with other extensions' dynamic fields on the same object. This trust model is explicit and mirrors the real-world responsibility of a system administrator managing plugin installations.

The audio verification system ensures that all audio data has been verified by at least one verifier, but the protocol does not prescribe what verification means. A verifier could check format compliance, perform content fingerprinting, or simply attest that the data exists. The verifier's identity (type name) is permanently recorded, enabling relying parties to evaluate the trustworthiness of the verification.

### 10.2 Limitations and Trade-offs

**On-chain metadata size.** Recording objects with maximum credits (150), stems (100), and secondary genres (3) are substantial on-chain objects. While Sui's object model handles this efficiently, gas costs for creating fully-populated objects are non-trivial.

**Composition split immutability on recordings.** A recording captures the composition's `split_bps` at creation time. If the composition owner later wishes to change the split (before publishing the composition), existing recordings retain the old split. This is intentional — it prevents retroactive changes to negotiated terms — but it requires that splits be finalized before recordings are created.

**No on-chain dispute resolution.** MusicOS does not include mechanisms for resolving ownership disputes, takedown requests, or copyright claims. These are inherently off-chain processes that involve legal jurisdictions and human judgment. MusicOS provides the verifiable data substrate that such processes can reference, but it does not replace them.

**Extension interference.** The raw UID access model accepts the possibility of extension interference in exchange for future compatibility. Managed layers built on top of MusicOS can mitigate this through extension whitelisting and auditing.

### 10.3 Future Work

Several directions for future development are under consideration:

- **Licensing extensions.** Smart contract-based licensing that allows programmatic negotiation of synchronization, mechanical, and performance rights, with terms and payments executed entirely on-chain.
- **Cross-chain bridges.** Enabling MusicOS objects to be referenced or mirrored on other blockchains, expanding the protocol's reach beyond the Sui ecosystem.
- **Decentralized identity integration.** Linking party objects to verifiable credentials and decentralized identity standards, enabling trustworthy attribution without centralized verification.
- **Streaming integration.** Extensions that connect MusicOS releases to DSPs, enabling real-time revenue attribution and distribution as streams occur.
- **Governance frameworks.** On-chain governance for shared objects (e.g., multi-party compositions where no single party holds the admin capability), enabling collective decision-making through share-token-weighted voting.

---

## 11. Conclusion

The music industry's infrastructure was built for an era of physical distribution and centralized intermediation. It has not meaningfully evolved to serve an era of digital abundance, AI-generated content, and programmable economic relationships. The consequences are measurable: billions in unmatched royalties, opaque revenue pipelines, and a distribution format — the audio file — that captures none of the creative, economic, or social context that gives music its value.

MusicOS provides an alternative foundation. By encoding the full structure of music rights into a permissionless, extensible on-chain protocol, MusicOS makes the ownership, attribution, and economics of music verifiable, deterministic, and programmable. It does not seek to replace the music industry's participants but to give them infrastructure worthy of the creative work they support.

The protocol is deployed on Sui testnet and available under the Apache 2.0 license.

---

## References

[1] IFPI. _Global Music Report 2024._ International Federation of the Phonographic Industry, 2024.

[2] U.S. Copyright Office. _Mechanical Licensing Collective: Annual Report._ Library of Congress, 2023.

[3] G. Danezis, G. Giuliari, E. Kokoris Kogias, M. Legner, J.-P. Smith, A. Sonnino, and K. Wüst. "Walrus: An Efficient Decentralized Storage Network." _arXiv:2505.05370_, 2025.

[4] Sui Foundation. _The Move Programming Language._ 2024.

[5] DDEX. _Digital Data Exchange Standards._ https://ddex.net.

---

_MusicOS is open-source software licensed under Apache 2.0. The protocol is developed by Subsonic Labs, LLC._

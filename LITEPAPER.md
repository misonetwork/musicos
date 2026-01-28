# MusicOS Litepaper

**A Decentralized Protocol for Transparent Music Rights and Royalty Distribution**

*Version 1.0 | January 2026*

---

## Abstract

MusicOS is an admin-less, immutable smart contract protocol deployed on the Sui blockchain that fundamentally reimagines how music rights are managed and how royalties flow from listeners to creators. By tokenizing compositions and recordings as on-chain assets with programmable ownership shares, MusicOS eliminates the opacity, delays, and intermediary extraction that have plagued the music industry for decades. This litepaper examines the structural inefficiencies of the traditional music ecosystem and presents MusicOS as an open, neutral infrastructure layer for the future of music.

---

## Table of Contents

1. [The Problem: A Broken System](#the-problem-a-broken-system)
2. [Market Analysis](#market-analysis)
3. [The MusicOS Solution](#the-musicos-solution)
4. [Protocol Design](#protocol-design)
5. [Tokenomics and Share System](#tokenomics-and-share-system)
6. [Revenue Distribution](#revenue-distribution)
7. [Governance and Immutability](#governance-and-immutability)
8. [Technical Implementation](#technical-implementation)
9. [Use Cases](#use-cases)
10. [Roadmap](#roadmap)
11. [Conclusion](#conclusion)

---

## The Problem: A Broken System

The music industry generates over $47 billion annually in copyright value, yet the artists who create this value often receive a fraction of what their work earns. This isn't due to a lack of demand for music—it's the result of a system designed around intermediaries rather than creators.

### Payment Delays That Harm Artists

According to [The Times](https://bitsong.io/en/blog/how-real-time-royalties-are-revolutionizing-the-music-industry), artists routinely wait **up to nine months** to receive royalty payments. On average, streaming royalties take [two to six months](https://info.xposuremusic.com/article/how-long-does-it-take-to-get-paid-the-lag-between-streams-and-royalties) to reach artists after streams occur.

The timeline varies by intermediary:
- **Spotify/Apple Music**: 2-3 months after the streaming month ends
- **Performance Rights Organizations** (ASCAP, BMI): Quarterly or semi-annual payments, meaning 3-6+ months
- **Record Labels**: Typically pay twice per year
- **Music Publishers**: Pay 2-4 times annually

A stark example: The Copyright Royalty Board set royalty rates for 2018-2022, streaming services appealed in March 2019, and [artists weren't paid until February 2024](https://royaltyexchange.com/blog/the-impact-of-legislation-on-music-royalties-in-2024)—a full year after the payment period ended.

For independent artists living paycheck to paycheck, these delays aren't merely inconvenient—they're existential threats to their ability to continue creating.

### The Transparency Crisis

The [Regulatory Review](https://www.theregreview.org/2024/05/30/stern-the-inequalities-of-digital-music-streaming/) reports that streaming platforms' revenue models are complex and lack transparency, putting musicians at a clear disadvantage. Artists are often left in the dark about:

- How their royalties are calculated
- What deductions and fees intermediaries take
- Where their money goes before it reaches them
- Why certain streams don't generate payments

Record labels operate under [non-disclosure agreements](https://www.theregreview.org/2024/05/30/stern-the-inequalities-of-digital-music-streaming/) that prevent artists from understanding or comparing their deals. The most critical part of the chain—how money moves from platforms to artists—is deliberately opaque.

### Intermediaries Extract the Majority of Value

According to [MIDIA Research](https://musicbusinessresearch.wordpress.com/2024/09/16/the-music-streaming-economy-part-14-the-artists-share-of-the-music-streaming-pie/), the approximately $0.004 generated per stream is divided as follows:

| Recipient | Share |
|-----------|-------|
| Recording Side (label, distributor, artist) | 56% |
| Streaming Platform | 30% |
| Publishing Side (publisher, PRO, songwriter) | 14% |

Of that 14% publishing share, songwriters receive 68%—but this is split among 3-12 writers on typical hit songs, before managers and other parties take their cut.

The [UK Parliament's DCMS hearings](https://musicbusinessresearch.wordpress.com/2024/09/16/the-music-streaming-economy-part-14-the-artists-share-of-the-music-streaming-pie/) found that the median revenue share for performers in label deals is just **25%**, with some research indicating artist royalties range from **2% to 20%** regardless of career stage.

### Platform Policies Hurt Independent Artists

In 2024, Spotify implemented a policy requiring tracks to have at least 1,000 streams in the previous 12 months to generate royalties. Analysis by [Chris Robley](https://council.rollingstone.com/blog/spotify-under-fire-over-investments-and-artist-pay/) calculated this policy withheld approximately **$47 million** from small independent artists, redistributing it to larger acts.

Spotify's former chief economist estimates that [99% of the 99,000 new tracks uploaded in 2024](https://council.rollingstone.com/blog/spotify-under-fire-over-investments-and-artist-pay/) earned their recording artists less than $100 in royalties that year.

Meanwhile, by bundling music with audiobooks and podcasts, [Spotify reduced mechanical royalty payments](https://www.fordhamiplj.org/2024/12/09/music-royalty-rates-in-an-age-of-streaming/), costing songwriters an estimated **$150 million annually**—prompting a lawsuit from the Mechanical Licensing Collective in May 2024.

### Unclaimed and Lost Royalties

The music industry has [billions in unclaimed royalties](https://sports-entertainment.brooklaw.edu/music/delinquent-royalty-payments-a-conflict-with-royalty-distributions-in-music/) sitting in collection agencies. Traditional systems are vulnerable to:

- Mismatched metadata (artist name variations, misspellings)
- Outdated contact information
- Complex ownership chains that obscure rightful recipients
- Manual processes prone to errors and fraud
- Lack of real-time tracking to detect problems

When royalties can't be matched to recipients, they're often absorbed by intermediaries or distributed to larger rightsholders—never reaching the creators who earned them.

---

## Market Analysis

### Global Music Industry Size

The global value of music copyright reached [$47.2 billion in 2024](https://pivotaleconomics.com/undercurrents/music-copyright-2025), nearly doubling over the past decade. Digital streaming now accounts for over 80% of recorded music revenue in the United States.

### Growth of Independent Artists

Independent artists are the fastest-growing segment of the music industry:
- More music is being created and distributed than ever before
- Platforms like DistroKid, TuneCore, and CD Baby have democratized distribution
- Yet independent artists remain the most disadvantaged by current payment structures

### Demand for Fair Payment Solutions

The [Union of Musicians and Allied Workers' "Justice at Spotify" campaign](https://musicindustryweekly.com/streaming-royalties-fair-pay-artists/) calls for a minimum one-cent per-stream royalty. Artists including King Gizzard & the Lizard Wizard, Deerhoof, Xiu Xiu, and Massive Attack have [pulled their music from Spotify](https://www.feslr.com/post/how-spotify-s-broken-model-undermines-the-artists-who-built-it) in protest.

The [European Parliament voted overwhelmingly](https://musicindustryweekly.com/streaming-royalties-fair-pay-artists/) in favor of creating a legal framework to increase transparency and improve royalty payments. The [Living Wage for Musicians Act](https://www.fordhamiplj.org/2024/12/09/music-royalty-rates-in-an-age-of-streaming/) in the U.S. aims to establish direct streaming royalties funded by subscription fees.

The industry is ready for change. MusicOS provides the infrastructure.

---

## The MusicOS Solution

MusicOS is a protocol, not a platform. It provides neutral, open infrastructure for music rights management and royalty distribution without gatekeepers, rent-seekers, or centralized control.

### Core Principles

**1. Immutability**
Once published, compositions and recordings become permanent, unalterable on-chain records. No entity—including the protocol creators—can modify, censor, or remove published works.

**2. Transparency**
All ownership, all transactions, all state changes are recorded on-chain and publicly auditable. Artists always know exactly who owns what and where money flows.

**3. Programmability**
Smart contracts enforce royalty splits automatically. No manual calculations, no delayed processing, no "trust us" from intermediaries. Code is law.

**4. Neutrality**
MusicOS is deployed as an admin-less, immutable package on Sui. Studio Mirai, the protocol's creator, has no special privileges, no admin keys, no ability to gate access or extract fees. The protocol belongs to everyone.

**5. Composability**
MusicOS is a building block. Any application—streaming services, music marketplaces, fan platforms, licensing tools—can integrate with MusicOS permissionlessly.

### What MusicOS Is Not

- **Not a streaming service**: MusicOS doesn't host or stream music
- **Not a marketplace**: MusicOS doesn't facilitate discovery or sales
- **Not a label or distributor**: MusicOS doesn't sign artists or distribute music
- **Not a company seeking profit**: MusicOS has no token sale, no fees, no revenue model

MusicOS is infrastructure—like HTTP for the web or SMTP for email—that anyone can build upon.

---

## Protocol Design

### Domain Model

MusicOS models the real-world structure of music:

```
                    RELEASE
                 (Album/EP/Single)
                       │
              ┌────────┼────────┐
              │        │        │
            DISC     DISC     DISC
              │        │        │
          ┌───┼───┐    │    ┌───┼───┐
          │   │   │    │    │   │   │
        TRACK TRACK  TRACK TRACK TRACK
          │   │       │      │   │
          └───┼───────┼──────┼───┘
              │       │      │
          RECORDING RECORDING RECORDING
              │       │      │
              └───────┼──────┘
                      │
                COMPOSITION
```

### Composition

The underlying written musical work—the song itself, independent of any performance.

**On-chain properties:**
- Title and alternate titles
- Lyrics reference (stored on Walrus)
- Credits with roles (Composer, Lyricist, Songwriter, Arranger, Translator, Adapter)
- Revenue split rate (what percentage goes to composition vs recording)
- Share token for ownership representation

### Recording

A specific audio performance of a composition, capturing the master audio and production details.

**On-chain properties:**
- Master audio reference and technical metadata
- Genre classification (primary and secondary)
- Artists (primary and featured)
- Production credits with roles and levels (Producer, Engineer, Vocalist, etc.)
- Musical metadata (key, tempo, time signature)
- Audio stems (up to 10 isolated tracks)
- Cover art
- Share token for ownership representation

### Release

A published collection of tracks—the final product distributed to listeners.

**Types:** Album, EP, Single

**On-chain properties:**
- Multiple discs (up to 50 tracks per disc)
- Track sequence and navigation
- Per-track revenue splits (must sum to 100%)
- Cover artwork

### Party

Individuals or groups who participate in creating music.

**Types:** Individual, Group (which can contain Individual members)

---

## Tokenomics and Share System

### Share Tokens

Each composition and recording mints its own fungible share token upon creation:

| Property | Value |
|----------|-------|
| Total Supply | 100,000,000 tokens |
| Decimals | 6 (100,000,000.000000) |
| Symbol | "SHARE" |

Share tokens represent fractional ownership. The creator receives the full initial supply and can distribute shares to collaborators, investors, or fans as they see fit.

### No Protocol Token

MusicOS intentionally has no protocol-wide token:
- No governance token that concentrates power
- No utility token that extracts value
- No speculative asset that distorts incentives

Each piece of music is its own economic unit with its own shares. This mirrors real-world music rights where each song has distinct ownership.

### Share Distribution Examples

**Solo Artist:**
```
Artist holds 100% of composition shares
Artist holds 100% of recording shares
```

**Band with Producer:**
```
Composition shares:
  - Songwriter A: 50%
  - Songwriter B: 50%

Recording shares:
  - Band: 80%
  - Producer: 15%
  - Mixing Engineer: 5%
```

**Label Deal Simulation:**
```
Recording shares:
  - Artist: 25%
  - Label (as investor): 75%
```

The protocol doesn't dictate splits—it enables any arrangement the parties agree to.

---

## Revenue Distribution

### Basis Points System

MusicOS uses basis points (BPS) for precise financial calculations:
- 1 BPS = 0.01%
- 10,000 BPS = 100%

This allows splits like 33.33% (3,333 BPS) without floating-point errors.

### Distribution Flow

```
       Payment Received by Release
                  │
                  ▼
        ┌─────────────────┐
        │  Track Splits   │  Each track gets its % of revenue
        └────────┬────────┘
                 │
    ┌────────────┼────────────┐
    ▼            ▼            ▼
  Track 1     Track 2     Track N
    │            │            │
    └────────────┼────────────┘
                 │
                 ▼
        ┌─────────────────┐
        │ Composition     │  Split between composition
        │ Split           │  and recording
        └────────┬────────┘
                 │
        ┌────────┴────────┐
        ▼                 ▼
   Composition       Recording
   Share Pool        Share Pool
        │                 │
        ▼                 ▼
   Share Holders     Share Holders
```

### Instant, Programmable Payments

When a payment arrives:
1. `distribute_revenue()` is called on the release
2. Smart contract splits payment according to track splits
3. Each track's share is further split between composition and recording
4. Funds flow to composition and recording reward pools
5. Share holders claim from pools based on their ownership percentage

No manual calculation. No quarterly processing. No intermediary delays.

### Composition Split Capture

When a recording is created, it captures the composition's current split rate. This means:
- The split is locked at recording creation time
- Composition owners can't retroactively change splits on existing recordings
- Different recordings of the same composition can have different splits
- Predictable economics for all parties

---

## Governance and Immutability

### Admin-less Design

MusicOS is deployed as an **immutable package** on Sui. This means:

- **No admin keys**: No one can upgrade, pause, or modify the protocol
- **No special privileges**: Studio Mirai has no more access than any user
- **No gatekeeping**: Anyone can interact with the protocol permissionlessly
- **No censorship**: No entity can remove or block published works

This is a deliberate design choice. By removing ourselves from the equation, we eliminate:
- Conflict of interest (we can't favor certain users or extract fees)
- Single point of failure (no company to shut down, hack, or pressure)
- Regulatory capture (no entity to sue or regulate out of existence)
- Trust requirements (users don't need to trust us—only the code)

### Why Immutability Matters for Music

Published creative works should be permanent records. Historically, master recordings have been:
- Lost in fires (Universal Music fire destroyed 500,000+ recordings)
- Sold without artist consent
- Locked in legal disputes
- Modified without creator approval

MusicOS compositions and recordings, once published, exist as long as the Sui blockchain exists. No fire, no lawsuit, no corporate bankruptcy can erase them.

### State Machine Enforcement

All entities follow strict state transitions:

```
Created → Published → (Immutable Forever)
```

The protocol enforces:
- Modifications only allowed before publishing
- Publishing requires all necessary data (credits, splits)
- Published state cannot be reversed
- No party—including protocol creators—can bypass these rules

---

## Technical Implementation

### Built on Sui

MusicOS leverages Sui's unique capabilities:

**Object-Centric Model**
Each composition, recording, and release is a distinct on-chain object with its own ID, enabling direct references and efficient queries.

**Programmable Transaction Blocks**
Complex operations (create composition + add credits + publish) execute atomically in a single transaction.

**Parallel Execution**
Non-conflicting transactions process simultaneously, enabling high throughput for royalty distributions.

**Move Language Safety**
Sui Move's resource-oriented programming prevents common smart contract vulnerabilities and enforces ownership semantics.

### External Storage Integration

Audio files and artwork are stored on **Walrus**, Sui's decentralized storage layer:
- Files referenced by blob ID and epoch
- Content integrity verified via PCM digest (32-byte hash)
- Storage persistence independent of any single provider

### Extension System

MusicOS supports authorized extensions via dynamic fields:
- Reward pool extensions for revenue distribution
- Future extensions for licensing, verification, etc.
- Extensions require explicit authorization from entity owners
- Core protocol remains immutable while allowing innovation

### Module Structure

| Module | Purpose |
|--------|---------|
| `composition` | Composition management |
| `recording` | Recording management |
| `release` | Release management with revenue distribution |
| `party` | Individual and group management |
| `share` | Share token initialization |
| `audio` | Audio file metadata and validation |
| `genre` | Genre classification |
| `credit` | Credit assignment with roles |
| + 11 supporting modules | Musical metadata, navigation, extensions |

---

## Use Cases

### Independent Artists

**Before MusicOS:**
- Upload to distributor → wait months for payment
- No visibility into who owns what percentage
- Platform policies can demonetize without recourse

**With MusicOS:**
- Publish directly to chain
- Receive payments as they arrive
- Permanent, verifiable ownership record
- No platform can remove or demonetize

### Collaborative Projects

**Before MusicOS:**
- Verbal or paper agreements
- Disputes over who contributed what
- Splits enforced by trust (or lawyers)

**With MusicOS:**
- On-chain record of all contributors and roles
- Programmable splits enforced by smart contract
- Transparent, auditable ownership history
- Disputes settled by immutable record

### Labels and Publishers

**Before MusicOS:**
- Complex accounting systems
- Quarterly royalty calculations
- Audits required to verify payments

**With MusicOS:**
- Automated royalty distribution
- Real-time payment verification
- Reduced accounting overhead
- Transparent catalog management

### Music Platforms

**Before MusicOS:**
- Build proprietary rights management
- Handle complex royalty calculations
- Risk of payment errors and disputes

**With MusicOS:**
- Integrate with existing rights infrastructure
- Pay directly to compositions/recordings
- Automatic distribution to shareholders
- Reduced liability and complexity

### Fans and Investors

**Before MusicOS:**
- Limited ways to support artists directly
- No way to participate in music economics
- Opaque relationship with creators

**With MusicOS:**
- Purchase share tokens to support artists
- Receive proportional royalty distributions
- Verifiable ownership on-chain
- Direct economic relationship with music

---

## Roadmap

### Phase 1: Protocol Launch (Complete)

- Core smart contracts developed and audited
- TypeScript SDK for developer integration
- Documentation and developer resources
- Immutable deployment on Sui

### Phase 2: Ecosystem Development (In Progress)

- Reference implementations for common use cases
- Integration guides for platforms and services
- Developer grants and hackathons
- Community building

### Phase 3: Adoption and Integration

- Partnerships with independent distributors
- Integration with existing music platforms
- Tools for catalog migration
- Educational resources for artists

### Phase 4: Ecosystem Maturity

- Third-party applications building on MusicOS
- Interoperability with other blockchain music initiatives
- Industry standard adoption
- Global reach

---

## Conclusion

The music industry's problems—delayed payments, opaque royalties, intermediary extraction—are not bugs. They're features of a system designed before the technology existed to do better.

MusicOS doesn't ask the industry to change its ways. It provides an alternative: open infrastructure where ownership is clear, payments are instant, and no gatekeeper stands between creators and their earnings.

By deploying MusicOS as an admin-less, immutable protocol, we ensure that this infrastructure belongs to everyone. No company—including ours—can gate access, extract fees, or accumulate power. The protocol is a public good, like a road or a language.

The artists, labels, platforms, and fans who build on MusicOS will shape its future. We've provided the foundation. What gets built upon it is up to the ecosystem.

Music deserves better infrastructure. MusicOS provides it.

---

## References

1. [BitSong - Real-Time Royalties](https://bitsong.io/en/blog/how-real-time-royalties-are-revolutionizing-the-music-industry)
2. [Royalty Exchange - Impact of Legislation 2024](https://royaltyexchange.com/blog/the-impact-of-legislation-on-music-royalties-in-2024)
3. [The Regulatory Review - Inequalities of Digital Music Streaming](https://www.theregreview.org/2024/05/30/stern-the-inequalities-of-digital-music-streaming/)
4. [Music Business Research - Artists' Share of Streaming](https://musicbusinessresearch.wordpress.com/2024/09/16/the-music-streaming-economy-part-14-the-artists-share-of-the-music-streaming-pie/)
5. [Rolling Stone - Spotify Under Fire](https://council.rollingstone.com/blog/spotify-under-fire-over-investments-and-artist-pay/)
6. [Fordham IP Journal - Music Royalty Rates in Streaming Age](https://www.fordhamiplj.org/2024/12/09/music-royalty-rates-in-an-age-of-streaming/)
7. [Brooklyn Law - Delinquent Royalty Payments](https://sports-entertainment.brooklaw.edu/music/delinquent-royalty-payments-a-conflict-with-royalty-distributions-in-music/)
8. [Music Industry Weekly - Streaming Royalties Fair Pay](https://musicindustryweekly.com/streaming-royalties-fair-pay-artists/)
9. [FESLR - Spotify's Broken Model](https://www.feslr.com/post/how-spotify-s-broken-model-undermines-the-artists-who-built-it)
10. [Pivotal Economics - Music Copyright 2025](https://pivotaleconomics.com/undercurrents/music-copyright-2025)
11. [Xposure Music - Payment Delays](https://info.xposuremusic.com/article/how-long-does-it-take-to-get-paid-the-lag-between-streams-and-royalties)

---

## Contact

**Studio Mirai, LLC**

MusicOS is open source and available at: [github.com/studio-mirai/musicos](https://github.com/studio-mirai/musicos)

---

*This litepaper is provided for informational purposes only. MusicOS is experimental software. Users should conduct their own research and understand the risks of blockchain technology before use.*

# MusicOS

Permissionless music protocol on Sui.

## Overview

MusicOS provides the core data model for music rights and distribution: Compositions, Recordings, Releases, and Parties. Each object follows a state machine pattern (Initialized → Published) and supports an extension system via raw `&mut UID` access for third-party modules.

## Core Objects

| Module | Description |
|--------|-------------|
| `composition` | Musical works with share tokens, party credits, and revenue splits |
| `recording` | Audio recordings linked to compositions, with stems, genres, and cover art |
| `release` | Collections of tracks organized into discs, with BPS revenue distribution |
| `deal` | Authorization bridge linking recordings to releases with agreed splits |
| `track` | Track entries within a release, capturing recording metadata at creation time |
| `disc` | Ordered track container within a release (max 50 tracks per disc) |

## Formal Verification

MusicOS is formally verified using [sui-prover](https://github.com/unconfirmedlabs/sui-prover), a fork with native MVR support. Formal verification mathematically proves safety properties hold for **all possible inputs** — not just tested cases.

### Running Verification

```bash
# Install dependencies (one-time)
brew install z3 dotnet@8

# Build the prover from unconfirmedlabs/sui-prover
cargo install --path crates/sui-prover

# Run verification
DOTNET_ROOT=$(brew --prefix dotnet@8)/libexec \
BOOGIE_EXE=$(which boogie) \
Z3_EXE=$(which z3) \
sui-prover -v
```

### Verified Properties

**State machine immutability** — Every mutating function on Composition (7 functions), Recording (13 functions), and Release aborts when the object is in the Published state. Once published, objects are provably immutable.

**Credit system integrity**
- Each `add_credit` call increases credit count by exactly 1
- Duplicate party credits are rejected (abort on existing party ID)
- Release credits require exactly 1 role per credit

**Artist set disjointness** — A party cannot be both a primary and featured artist on the same recording. `add_primary_artist` aborts if the party is featured, and vice versa.

**Artist-credit linkage** — A party must be credited on a recording before being designated as a primary or featured artist.

**Instrumental/lyrics conflict** — `set_lyrics` aborts on instrumental recordings.

**Genre exclusivity** — A genre cannot be both primary and secondary on the same recording.

**Track assignment** — Track assignment is one-time (Unassigned → Assigned) and aborts on re-assignment.

**Disc bounds** — Disc creation enforces a maximum of 50 tracks and aborts when exceeded.

**Deal consistency** — Deal creation aborts when the composition ID doesn't match the recording's composition reference. On success, composition ID, recording ID, and release ID are preserved exactly.

**TimeSignature validation** — Construction requires non-zero beats per measure and beat unit, returning exact values on success.

### Spec Files

Specifications live alongside source files in `sources/`:

| File | Specs | Properties |
|------|-------|------------|
| `composition_spec.move` | 10 | State machine (7), credit count +1, duplicate rejection, alt title count +1 |
| `recording_spec.move` | 20 | State machine (13), credits (2), disjoint artists (2), artist linkage (2), instrumental/lyrics, genre exclusivity, stem count +1 |
| `release_spec.move` | 5 | State machine, authorization (2), credit count +1, duplicate rejection |
| `track_spec.move` | 2 | One-time assignment, abort on re-assign |
| `disc_spec.move` | 2 | Max 50 tracks enforced, abort on >50 |
| `deal_spec.move` | 2 | Composition ID mismatch abort, ID preservation |
| `time_signature_spec.move` | 3 | Correct values, abort on zero fields |

Each spec generates 3 verification checks (Check, Assume, SpecNoAbortCheck) for a total of **138 checks**.

## Extension Architecture

MusicOS is a permissionless protocol — anyone can build and deploy extension packages. Extensions get raw `&mut UID` access to the parent object, gated by admin capability.

This is a deliberate choice. Sui's core primitives — fund accumulators, derived objects, coin receiving — all operate on `&mut UID`. Raw access ensures extensions can adopt new Sui capabilities immediately without core protocol upgrades.

The admin cap holder decides which extensions to trust, similar to WordPress plugins. A managed layer can be built on top to enforce extension whitelists for users who want guardrails.

## License

Apache-2.0

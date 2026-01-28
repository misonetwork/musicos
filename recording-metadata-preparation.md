# Recording Metadata Preparation Guide

This document describes how to prepare metadata for creating a Recording on the Sona platform.

## JSON Schema

```json
{
  "compositionId": "<sui-object-id>",
  "titleVersion": "<string | optional>",
  "subtitle": "<string | optional>",
  "primaryGenreId": "<sui-object-id>",
  "secondaryGenreIds": ["<sui-object-id>"],
  "primaryArtists": ["<party-id>"],
  "featuredArtists": ["<party-id>"],
  "credits": [
    {
      "partyId": "<party-id>",
      "partyRoles": [
        {
          "role": {
            "name": "<role-name>",
            "level": "<role-level | optional>",
            "instrument": "<string | only for instrumentalist>"
          },
          "displayName": "<string>"
        }
      ]
    }
  ],
  "language": "<iso-639-1-code | optional>",
  "isExplicit": "<boolean>",
  "isInstrumental": "<boolean>",
  "musicalKey": {
    "note": "<note>",
    "accidental": "<accidental | optional>",
    "mode": "<mode>"
  },
  "timeSignature": {
    "beats_per_measure": "<1-255>",
    "beat_unit": "<1-255>"
  },
  "tempoBpm": "<0-65535 | optional>",
  "shareRecipients": [
    {
      "address": "<sui-address>",
      "value": "<1-10000000000000>"
    }
  ]
}
```

---

## Field Reference

### compositionId

**Required** — The Sui object ID of the Composition this Recording is based on.

### titleVersion

**Optional** — A version descriptor for the recording (e.g., "Acoustic Version", "Radio Edit", "Extended Mix").

### subtitle

**Optional** — Additional title information (e.g., "Live at Madison Square Garden", "feat. Artist Name").

### primaryGenreId

**Required** — The Sui object ID of the primary genre classification.

### secondaryGenreIds

**Optional** — Array of Sui object IDs for additional genre classifications.

### primaryArtists

**Required** — Array of Party IDs representing the main credited artist(s) on this recording.

### featuredArtists

**Optional** — Array of Party IDs representing featured artists who appear prominently but are not the primary artist.

### credits

**Required** — Array of credit entries for all contributors to the recording.

Each credit entry contains:

- `partyId` — The Sui object ID of the credited party
- `partyRoles` — Array of roles this party performed

Each role contains:

- `role.name` — The role type (see [Party Roles](#party-roles) below)
- `role.level` — Optional seniority level (see [Party Levels](#party-levels) below)
- `role.instrument` — **Required only for `instrumentalist` role** — The instrument played
- `displayName` — How this credit should be displayed (e.g., "Lead Vocals", "Drums", "Executive Producer")

### language

**Optional** — ISO 639-1 language code (e.g., "en", "es", "ja"). Omit for instrumental recordings.

### isExplicit

**Required** — `true` if the recording contains explicit content.

### isInstrumental

**Required** — `true` if the recording contains no vocals.

### musicalKey

**Optional** — The musical key of the recording.

| Field        | Values                                                     |
| ------------ | ---------------------------------------------------------- |
| `note`       | `c`, `d`, `e`, `f`, `g`, `a`, `b`                          |
| `accidental` | `natural`, `sharp`, `flat` (optional, defaults to natural) |
| `mode`       | `major`, `minor`                                           |

### timeSignature

**Required** — The time signature of the recording.

- `beats_per_measure` — Number of beats per measure (1-255)
- `beat_unit` — Note value that gets one beat (1-255, typically 4 for quarter note)

### tempoBpm

**Optional** — Tempo in beats per minute (0-65535).

### shareRecipients

**Required** — Array of share allocations for royalty distribution.

Each recipient entry contains:

- `address` — The Sui address of the share recipient
- `value` — Number of shares to allocate (1 to 10,000,000,000,000)

**Constraints:**

- Maximum of 250 recipients
- All `value` fields must sum to exactly **10,000,000,000,000** (10 trillion)

**Example allocations:**

| Split      | Value per recipient                    |
| ---------- | -------------------------------------- |
| 50/50      | 5,000,000,000,000 each                 |
| 80/20      | 8,000,000,000,000 and 2,000,000,000,000 |
| Equal 4-way | 2,500,000,000,000 each                 |

---

## Party Roles

| Role Name                | Description                                        | Supports Level |
| ------------------------ | -------------------------------------------------- | -------------- |
| `actor`                  | Performed voice acting or spoken word              | Yes            |
| `arranger`               | Arranged the musical parts                         | Yes            |
| `artists_and_repertoire` | A&R representative                                 | No             |
| `choir`                  | Performed as part of a choir                       | Yes            |
| `choir_master`           | Directed the choir performance                     | Yes            |
| `conductor`              | Conducted the orchestra or ensemble                | Yes            |
| `contractor`             | Hired and managed session musicians                | Yes            |
| `copyist`                | Prepared written music parts                       | No             |
| `editor`                 | Edited and compiled audio takes                    | Yes            |
| `ensemble`               | Performed as part of a musical ensemble            | Yes            |
| `instrumentalist`        | Played an instrument (requires `instrument` field) | Yes            |
| `mastering_engineer`     | Mastered the final audio                           | Yes            |
| `mixing_engineer`        | Mixed the multitrack recording                     | Yes            |
| `music_director`         | Directed the musical performance                   | Yes            |
| `music_supervisor`       | Oversaw music selection and licensing              | Yes            |
| `narrator`               | Narrated spoken content                            | Yes            |
| `orchestra`              | Performed as part of an orchestra                  | Yes            |
| `orchestrator`           | Created orchestral arrangements                    | Yes            |
| `producer`               | Oversaw creative and technical aspects             | Yes            |
| `programmer`             | Programmed beats, synths, or electronic elements   | Yes            |
| `recording_engineer`     | Operated recording equipment                       | Yes            |
| `remixing_engineer`      | Created a remix                                    | Yes            |
| `sound_designer`         | Created sound effects or sonic textures            | Yes            |
| `vocalist`               | Provided vocals                                    | Yes            |

---

## Party Levels

| Level        | Description                                 |
| ------------ | ------------------------------------------- |
| `additional` | Supplementary contributor                   |
| `assistant`  | Assistant to the primary party              |
| `associate`  | Associate-level contributor                 |
| `backing`    | Support role (e.g., backing vocals)         |
| `executive`  | Executive-level oversight                   |
| `featured`   | Featured prominently on the recording       |
| `lead`       | Lead/primary party in this role             |
| `primary`    | Primary artist on the recording             |
| `principal`  | Principal party with primary responsibility |

---

## Example

```json
{
  "compositionId": "0x1a2b3c4d5e6f7890abcdef1234567890abcdef1234567890abcdef12345678",
  "titleVersion": "Acoustic Version",
  "subtitle": "Live at Electric Lady Studios",
  "primaryGenreId": "0xaaaa1111222233334444555566667777888899990000aaaabbbbccccddddeee",
  "secondaryGenreIds": [
    "0xbbbb1111222233334444555566667777888899990000aaaabbbbccccddddeee"
  ],
  "primaryArtists": [
    "0x1111000011110000111100001111000011110000111100001111000011110000"
  ],
  "featuredArtists": [
    "0x2222000022220000222200002222000022220000222200002222000022220000"
  ],
  "credits": [
    {
      "partyId": "0x1111000011110000111100001111000011110000111100001111000011110000",
      "partyRoles": [
        {
          "role": { "name": "vocalist", "level": "lead" },
          "displayName": "Lead Vocals"
        },
        {
          "role": {
            "name": "instrumentalist",
            "instrument": "Guitar",
            "level": "lead"
          },
          "displayName": "Acoustic Guitar"
        }
      ]
    },
    {
      "partyId": "0x2222000022220000222200002222000022220000222200002222000022220000",
      "partyRoles": [
        {
          "role": { "name": "vocalist", "level": "featured" },
          "displayName": "Featured Vocals"
        }
      ]
    },
    {
      "partyId": "0x3333000033330000333300003333000033330000333300003333000033330000",
      "partyRoles": [
        {
          "role": { "name": "producer", "level": "executive" },
          "displayName": "Executive Producer"
        }
      ]
    },
    {
      "partyId": "0x4444000044440000444400004444000044440000444400004444000044440000",
      "partyRoles": [
        {
          "role": {
            "name": "instrumentalist",
            "instrument": "Bass",
            "level": "primary"
          },
          "displayName": "Bass"
        }
      ]
    },
    {
      "partyId": "0x5555000055550000555500005555000055550000555500005555000055550000",
      "partyRoles": [
        {
          "role": { "name": "mixing_engineer", "level": "lead" },
          "displayName": "Mix Engineer"
        },
        {
          "role": { "name": "recording_engineer" },
          "displayName": "Recording Engineer"
        }
      ]
    },
    {
      "partyId": "0x6666000066660000666600006666000066660000666600006666000066660000",
      "partyRoles": [
        {
          "role": { "name": "mastering_engineer" },
          "displayName": "Mastering"
        }
      ]
    }
  ],
  "language": "en",
  "isExplicit": false,
  "isInstrumental": false,
  "musicalKey": {
    "note": "g",
    "mode": "major"
  },
  "timeSignature": {
    "beats_per_measure": 4,
    "beat_unit": 4
  },
  "tempoBpm": 92,
  "shareRecipients": [
    {
      "address": "0xaaaa000000000000000000000000000000000000000000000000000000000001",
      "value": 5000000000000
    },
    {
      "address": "0xbbbb000000000000000000000000000000000000000000000000000000000002",
      "value": 3000000000000
    },
    {
      "address": "0xcccc000000000000000000000000000000000000000000000000000000000003",
      "value": 2000000000000
    }
  ]
}
```

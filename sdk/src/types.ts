// Copyright (c) Unconfirmed Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

// ============================================================================
// Common
// ============================================================================

/** Basis points value (0-10000, where 10000 = 100%). */
export interface BPS {
  value: number;
}

// ============================================================================
// Party
// ============================================================================

/** Type of party (individual or group). */
export type PartyKind =
  | { type: "Individual" }
  | { type: "Group"; memberIds: string[] };

/**
 * A party (artist, producer, etc.) in the music ecosystem.
 * Can represent an individual or a group of parties.
 */
export interface Party {
  /** Unique identifier for this party. */
  id: string;
  /** Whether this is an individual or group party. */
  kind: PartyKind;
  /** Human-readable name of the party. */
  name: string;
}

// ============================================================================
// Walrus Storage
// ============================================================================

/** Reference to data stored as a Walrus blob. MusicOS enforces blob-only storage for all creative assets. */
export type WalrusData = { type: "Blob"; blobId: string };

// ============================================================================
// Audio
// ============================================================================

/**
 * A verified audio file with technical metadata.
 *
 * Audio is a standalone, witness-gated primitive (`audio::audio::Audio`) that
 * MusicOS embeds (e.g. as a recording's master). It can only be created via an
 * ingester that attests the audio; the attested `format` and `pcmDigest` are
 * signed by the ingester enclave, not asserted by the caller.
 */
export interface Audio {
  /** The ingester type that attested this audio (a Move TypeName). */
  ingester: string;
  /** Codec/container short name of the stored blob (e.g. `flac`). Lowercase `a-z`/`0-9`. */
  format: string;
  /** Number of audio channels (1 = mono, 2 = stereo). */
  channels: number;
  /** Bit depth of the audio (8, 16, 24, or 32 bits). */
  bitDepth: number;
  /** Sample rate in Hz. */
  sampleRateHz: number;
  /** Total number of samples. */
  samples: number;
  /** BLAKE2b-256 of the canonical decoded PCM, as a 64-char lowercase hex string. */
  pcmDigest: string;
  /** Reference to the audio file on Walrus. */
  data: WalrusData;
}

/** Cover artwork with required static image and optional animation. */
export interface CoverArt {
  /** Required static image. */
  static: WalrusData;
  /** Optional animated version (GIF, video, etc.). */
  animated?: WalrusData;
}

// ============================================================================
// Party Roles
// ============================================================================

/** Roles that parties can hold on a composition. */
export type CompositionPartyRole =
  | { type: "Adapter" }
  | { type: "Arranger" }
  | { type: "Composer" }
  | { type: "Lyricist" }
  | { type: "Songwriter" }
  | { type: "Translator" };

/** Helper to extract composition role type names. */
export type CompositionPartyRoleType = CompositionPartyRole["type"];

/** All available composition party role types. */
export const COMPOSITION_PARTY_ROLES: readonly CompositionPartyRoleType[] = [
  "Adapter",
  "Arranger",
  "Composer",
  "Lyricist",
  "Songwriter",
  "Translator",
] as const;

/** Seniority or prominence level of a party on a recording. */
export type RecordingPartyRoleLevel =
  | "Additional"
  | "Assistant"
  | "Associate"
  | "Backing"
  | "Executive"
  | "Featured"
  | "Lead"
  | "Primary"
  | "Principal";

/** All available recording party role levels. */
export const RECORDING_PARTY_ROLE_LEVELS: readonly RecordingPartyRoleLevel[] = [
  "Additional",
  "Assistant",
  "Associate",
  "Backing",
  "Executive",
  "Featured",
  "Lead",
  "Primary",
  "Principal",
] as const;

/** Roles that parties can hold on a recording. */
export type RecordingPartyRole =
  | { type: "Actor"; level?: RecordingPartyRoleLevel }
  | { type: "Arranger"; level?: RecordingPartyRoleLevel }
  | { type: "ArtistsAndRepertoire" }
  | { type: "Choir"; level?: RecordingPartyRoleLevel }
  | { type: "ChoirMaster"; level?: RecordingPartyRoleLevel }
  | { type: "Conductor"; level?: RecordingPartyRoleLevel }
  | { type: "Contractor"; level?: RecordingPartyRoleLevel }
  | { type: "Copyist" }
  | { type: "Editor"; level?: RecordingPartyRoleLevel }
  | { type: "Ensemble"; level?: RecordingPartyRoleLevel }
  | { type: "Instrumentalist"; instrument: string; level?: RecordingPartyRoleLevel }
  | { type: "MasteringEngineer"; level?: RecordingPartyRoleLevel }
  | { type: "MixingEngineer"; level?: RecordingPartyRoleLevel }
  | { type: "MusicDirector"; level?: RecordingPartyRoleLevel }
  | { type: "MusicSupervisor"; level?: RecordingPartyRoleLevel }
  | { type: "Narrator"; level?: RecordingPartyRoleLevel }
  | { type: "Orchestra"; level?: RecordingPartyRoleLevel }
  | { type: "Orchestrator"; level?: RecordingPartyRoleLevel }
  | { type: "Producer"; level?: RecordingPartyRoleLevel }
  | { type: "Programmer"; level?: RecordingPartyRoleLevel }
  | { type: "RecordingEngineer"; level?: RecordingPartyRoleLevel }
  | { type: "RemixingEngineer"; level?: RecordingPartyRoleLevel }
  | { type: "SoundDesigner"; level?: RecordingPartyRoleLevel }
  | { type: "Vocalist"; level?: RecordingPartyRoleLevel };

/** Helper to extract recording role type names. */
export type RecordingPartyRoleType = RecordingPartyRole["type"];

/** All available recording party role types. */
export const RECORDING_PARTY_ROLES: readonly RecordingPartyRoleType[] = [
  "Actor",
  "Arranger",
  "ArtistsAndRepertoire",
  "Choir",
  "ChoirMaster",
  "Conductor",
  "Contractor",
  "Copyist",
  "Editor",
  "Ensemble",
  "Instrumentalist",
  "MasteringEngineer",
  "MixingEngineer",
  "MusicDirector",
  "MusicSupervisor",
  "Narrator",
  "Orchestra",
  "Orchestrator",
  "Producer",
  "Programmer",
  "RecordingEngineer",
  "RemixingEngineer",
  "SoundDesigner",
  "Vocalist",
] as const;

// ============================================================================
// Credits
// ============================================================================

/** Credit entry for a party on a composition or recording. */
export interface Credit<Role> {
  /** Display name for the credited party. */
  displayName: string;
  /** Roles assigned to the party. */
  roles: Role[];
}

/** Credit for a party on a composition. */
export type CompositionCredit = Credit<CompositionPartyRole>;

/** Credit for a party on a recording. */
export type RecordingCredit = Credit<RecordingPartyRole>;

/** Roles that parties can hold on a release. */
export type ReleasePartyRole =
  | { type: "Primary" }
  | { type: "Featured" };

/** Credit for a party on a release. */
export type ReleaseCredit = Credit<ReleasePartyRole>;

// ============================================================================
// Composition
// ============================================================================

/** Lifecycle state of a composition. */
export type CompositionState =
  | { type: "Initialized" }
  | { type: "Published"; timestampMs: number };

/**
 * A musical composition representing the underlying written work.
 *
 * Compositions are the written musical works (songs, instrumentals) that
 * recordings are based on. Each composition has its own share token for
 * ownership distribution.
 *
 * State machine: Initialized -> Published (immutable after publish)
 */
export interface Composition {
  /** Unique identifier for this composition. */
  id: string;
  /** Current lifecycle state. */
  state: CompositionState;
  /** Primary title of the composition. */
  title: string;
  /** Additional titles (translations, alternate names). */
  alternateTitles: string[];
  /** Map of party IDs to their credits on this composition. */
  credits: Record<string, CompositionCredit>;
  /** Royalty rate this composition earns from each recording's revenue (basis points). */
  royaltyRate: BPS;
}

/**
 * Emitted once when a composition is published. A pure pointer carrying only the
 * composition's identity — an indexer fetches the full immutable object by
 * `compositionId`.
 */
export interface CompositionPublishedEvent {
  compositionId: string;
}

/** Emitted when a composition's royalty rate is set or changed. */
export interface CompositionRoyaltySetEvent {
  compositionId: string;
  royaltyRateBps: number;
}

/**
 * Admin cap for a Composition, derived deterministically from the Composition object ID.
 *
 * The share type parameter T is extracted from the on-chain type
 * `CompositionAdminCap<T>` where T is the composition's share token type.
 */
export interface CompositionAdminCap {
  /** The object ID of the admin cap. */
  id: string;
  /** The share type parameter T from CompositionAdminCap<T>. */
  shareType: string;
}

// ============================================================================
// Recording
// ============================================================================

/** Lifecycle state of a recording. */
export type RecordingState =
  | { type: "Initialized" }
  | { type: "Published"; timestampMs: number };

/**
 * An audio recording of a composition.
 *
 * Recordings are the audio performances that are distributed and played.
 * Each recording has its own share token for ownership distribution.
 *
 * State machine: Initialized -> Published (immutable after publish)
 */
export interface Recording {
  /** Unique identifier for this recording. */
  id: string;
  /** Current lifecycle state. */
  state: RecordingState;
  /** Primary title of the recording. */
  title: string;
  /** Version suffix (e.g., "Radio Edit", "Extended Mix"). */
  titleVersion?: string;
  /** Subtitle of the recording. */
  subtitle?: string;
  /** ID of the underlying composition. */
  compositionId: string;
  /** Royalty rate owed to the composition, captured at creation time (basis points). */
  compositionRoyaltyRate: BPS;
  /** IDs of the primary artists on the recording. */
  primaryArtistIds: string[];
  /** IDs of the featured artists on the recording. */
  featuredArtistIds: string[];
  /** Map of party IDs to their credits on this recording. */
  credits: Record<string, RecordingCredit>;
  /** Language of the vocals (if any). ISO 639-1 code. */
  language?: string;
  /** Whether the recording contains explicit content. */
  isExplicit: boolean;
  /** Whether the recording is instrumental (no vocals). */
  isInstrumental: boolean;
  /** The final mixed/mastered audio file. */
  master: Audio;
  /** Cover art for the recording. */
  coverArt: CoverArt;
}

/**
 * Emitted once when a recording is published. A pure pointer carrying the
 * recording's identity and its parent composition (for routing) — an indexer
 * fetches the full immutable object by `recordingId`.
 */
export interface RecordingPublishedEvent {
  recordingId: string;
  compositionId: string;
}

/**
 * Admin cap for a Recording, derived deterministically from the Recording object ID.
 *
 * The share type parameter T is extracted from the on-chain type
 * `RecordingAdminCap<T>` where T is the recording's share token type.
 */
export interface RecordingAdminCap {
  /** The object ID of the admin cap. */
  id: string;
  /** The share type parameter T from RecordingAdminCap<T>. */
  shareType: string;
}

// ============================================================================
// Track
// ============================================================================

/** Lifecycle state of a track on a release. */
export type TrackState = "Unassigned" | "Assigned";

/**
 * A track on a release, linking a recording to its position in the tracklist.
 * Captures metadata from the recording at the time of release creation.
 */
export interface Track {
  /** Current state of the track (Unassigned until the release claims it, then Assigned). */
  state: TrackState;
  /** ID of the underlying composition. */
  compositionId: string;
  /** Type of the composition's share token. */
  compositionShareType: string;
  /** Royalty rate owed to the composition (basis points). */
  compositionRoyaltyRate: BPS;
  /** ID of the recording on this track. */
  recordingId: string;
  /** Type of the recording's share token. */
  recordingShareType: string;
  /** Ingester type of the recording's master audio file. */
  recordingMasterIngesterType: string;
  /** Title of the track. */
  title: string;
  /** Duration of the track in milliseconds. */
  durationMs: number;
  /** Cover art for the track (inherited from recording by default). */
  coverArt: CoverArt;
  /** Revenue split for this track within the release (in basis points). */
  splitBps: BPS;
}

// ============================================================================
// Disc
// ============================================================================

/**
 * A disc within a release, containing an ordered list of tracks.
 * Multi-disc releases (like double albums) are modeled as multiple Disc objects.
 */
export interface Disc {
  /** Ordered list of tracks on this disc. */
  tracks: Track[];
  /** Optional disc-specific artwork (e.g., for multi-disc sets with different covers). */
  artwork?: CoverArt;
  /** Optional disc title (e.g., for multi-disc sets). */
  title?: string;
  /** Total duration of all tracks in milliseconds. */
  durationMs: number;
}

// ============================================================================
// Release
// ============================================================================

/** Type of release (Album, Extended Play, or Single). */
export type ReleaseKind = "Album" | "ExtendedPlay" | "Single";

/** Lifecycle state of a release. */
export type ReleaseState =
  | { type: "Initialized" }
  | { type: "Published"; timestampMs: number };

/**
 * A music release (album, EP, or single).
 *
 * A release is a collection of tracks organized into discs, with cover art
 * and revenue distribution configuration.
 *
 * State machine: Initialized -> Published (immutable after publish)
 */
export interface Release {
  /** Unique identifier for this release. */
  id: string;
  /** Current lifecycle state. */
  state: ReleaseState;
  /** Type of release. */
  kind: ReleaseKind;
  /** Title of the release. */
  title: string;
  /** Description of the release (max 500 characters). */
  description: string;
  /** Optional subtitle (e.g., "Deluxe Edition"). */
  subtitle?: string;
  /** Map of party IDs to their credits on this release. */
  credits: Record<string, ReleaseCredit>;
  /** Collection of discs containing tracks. */
  discs: Disc[];
  /** Cover artwork for the release. */
  coverArt: CoverArt;
}

/**
 * Emitted once when a release is published. A pure pointer carrying only the
 * release's identity — an indexer fetches the full immutable object (discs,
 * tracks, credits) by `releaseId`.
 */
export interface ReleasePublishedEvent {
  releaseId: string;
}

/**
 * Admin cap for a Release, derived deterministically from the Release object ID.
 *
 * Unlike Composition and Recording admin caps, ReleaseAdminCap is not generic
 * (Release has no share type parameter) and stores a reference to its Release.
 */
export interface ReleaseAdminCap {
  /** The object ID of the admin cap. */
  id: string;
  /** The object ID of the Release this cap administers. */
  releaseId: string;
}

// ============================================================================
// Audio Events
// ============================================================================

/** Emitted when an audio file is ingested (from `audio::audio`). */
export interface AudioIngestedEvent {
  blobId: string;
  format: string;
  channels: number;
  bitDepth: number;
  sampleRateHz: number;
  samples: number;
  durationMs: number;
  /** BLAKE2b-256 of the canonical decoded PCM, as a 64-char lowercase hex string. */
  pcmDigest: string;
}

// ============================================================================
// Deal Events
// ============================================================================

export interface DealCreatedEvent {
  dealId: string;
  releaseId: string;
  recordingId: string;
  compositionId: string;
  trackTitle: string;
  trackSplitBps: BPS;
  trackCoverArtStaticBlobId: string;
  trackCoverArtAnimatedBlobId?: string;
}

export interface DealDestroyedEvent {
  dealId: string;
  releaseId: string;
  recordingId: string;
  compositionId: string;
}

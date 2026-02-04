// Copyright (c) Unconfirmed Labs, LLC
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
  | { type: "Group"; memberIds: Set<string> };

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

export interface PartyCreatedEvent {
  partyId: string;
  name: string;
}

export interface PartyAddedToGroupEvent {
  groupId: string;
  partyId: string;
}

export interface PartyRemovedFromGroupEvent {
  groupId: string;
  partyId: string;
}

// ============================================================================
// Walrus Storage
// ============================================================================

/**
 * Reference to data stored on Walrus.
 * Corresponds to Move tuple struct: WalrusData(Option<u256>, u256)
 */
export interface WalrusData {
  /** Optional quilt ID (u256 as string). */
  quiltId?: string;
  /** Walrus blob ID (u256 as string). */
  blobId: string;
}

// ============================================================================
// Audio
// ============================================================================

/** Audio file with technical metadata. */
export interface Audio {
  /** Number of audio channels (1 = mono, 2 = stereo). */
  channels: number;
  /** Bit depth of the audio (8, 16, 24, or 32 bits). */
  bitDepth: number;
  /** Sample rate in Hz. */
  sampleRateHz: number;
  /** Total number of samples. */
  samples: bigint;
  /** Reference to the audio file on Walrus. */
  data: WalrusData;
  /** SHA-256 digest of the raw PCM data for integrity verification. */
  pcmDigest: Uint8Array;
}

/** Cover artwork with required static image and optional animation. */
export interface CoverArt {
  /** Required static image. */
  static: WalrusData;
  /** Optional animated version (GIF, video, etc.). */
  animated?: WalrusData;
}

/** An individual audio stem within a recording. */
export interface Stem {
  /** The audio data for this stem. */
  audio: Audio;
  /** Description of the stem (e.g., "Vocals", "Drums", "Bass"). */
  description: string;
  /** IDs of parties who contributed to this stem. */
  contributors: string[];
}

// ============================================================================
// Musical Properties
// ============================================================================

/** Musical note letters. */
export type Note = "C" | "D" | "E" | "F" | "G" | "A" | "B";

/** Pitch modifiers. */
export type Accidental = "Natural" | "Sharp" | "Flat";

/** Musical modes. */
export type Mode = "Major" | "Minor";

/** Musical key combining root note, accidental, and mode. */
export interface MusicalKey {
  note: Note;
  accidental: Accidental;
  mode: Mode;
}

/** Time signature expressed as beats per measure over beat unit. */
export interface TimeSignature {
  /** Number of beats in each measure. */
  beatsPerMeasure: number;
  /** Note value that receives one beat (4 = quarter, 8 = eighth, etc.). */
  beatUnit: number;
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

// ============================================================================
// Composition
// ============================================================================

/** Lifecycle state of a composition. */
export type CompositionState =
  | { type: "Initialized" }
  | { type: "Published"; timestampMs: bigint };

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
  credits: Map<string, CompositionCredit>;
  /** Revenue split rate allocated to this composition vs recording (in basis points). */
  splitBps: BPS;
  /** Lyrics lines (no timestamps for composition-level lyrics). */
  lyrics: string[];
}

export interface CompositionInitializedEvent {
  compositionId: string;
}

export interface CompositionPublishedEvent {
  compositionId: string;
}

export interface CompositionPartyAddedEvent {
  compositionId: string;
  partyId: string;
}

export interface CompositionSplitSetEvent {
  compositionId: string;
  splitValue: number;
}

// ============================================================================
// Recording
// ============================================================================

/** Lifecycle state of a recording. */
export type RecordingState =
  | { type: "Initialized" }
  | { type: "Published"; timestampMs: bigint };

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
  /** Type of the composition's share token. */
  compositionShareType: string;
  /** Revenue split for the composition in basis points (captured at creation time). */
  compositionSplitBps: BPS;
  /** ID of the primary genre. */
  primaryGenreId: string;
  /** IDs of secondary genres. */
  secondaryGenreIds: Set<string>;
  /** IDs of the primary artists on the recording. */
  primaryArtistIds: Set<string>;
  /** IDs of the featured artists on the recording. */
  featuredArtistIds: Set<string>;
  /** Map of party IDs to their credits on this recording. */
  credits: Map<string, RecordingCredit>;
  /** Language of the vocals (if any). ISO 639-1 code. */
  language?: string;
  /** Whether the recording contains explicit content. */
  isExplicit: boolean;
  /** Whether the recording is instrumental (no vocals). */
  isInstrumental: boolean;
  /** Timed lyrics file reference (WebVTT format on Walrus). */
  lyrics?: WalrusData;
  /** Musical key of the recording. */
  musicalKey?: MusicalKey;
  /** Time signature of the recording. */
  timeSignature?: TimeSignature;
  /** Tempo in beats per minute. */
  tempoBpm?: number;
  /** The final mixed/mastered audio file. */
  master: Audio;
  /** The stems of the recording. */
  stems: Stem[];
  /** Cover art for the recording. */
  coverArt: CoverArt;
}

export interface RecordingPublishedEvent {
  recordingId: string;
}

export interface RecordingPartyAddedEvent {
  recordingId: string;
  partyId: string;
}

// ============================================================================
// Track
// ============================================================================

/** Lifecycle state of a track on a release. */
export type TrackState = "Pending" | "Assigned";

/**
 * A track on a release, linking a recording to its position in the tracklist.
 * Captures metadata from the recording at the time of release creation.
 */
export interface Track {
  /** Current state of the track (Pending until deal is assigned, then Assigned). */
  state: TrackState;
  /** ID of the underlying composition. */
  compositionId: string;
  /** Type of the composition's share token. */
  compositionShareType: string;
  /** Split of revenue allocated to composition vs recording (in basis points). */
  compositionSplitBps: BPS;
  /** ID of the recording on this track. */
  recordingId: string;
  /** Type of the recording's share token. */
  recordingShareType: string;
  /** Title of the track. */
  title: string;
  /** Duration of the track in milliseconds. */
  durationMs: bigint;
  /** Cover art for the track (inherited from recording by default). */
  coverArt: CoverArt;
  /** Revenue split for this track within the release (in basis points). */
  splitBps: BPS;
}

/** Position of a track within a release (disc and track indices). */
export interface TrackPosition {
  /** Zero-based index of the disc within the release. */
  discIdx: number;
  /** Zero-based index of the track within the disc. */
  trackIdx: number;
}

/** Navigation structure for track ordering across multiple discs. */
export interface TrackSequence {
  /** Number of tracks on each disc. */
  tracksPerDisc: number[];
  /** Flattened list of all track positions in playback order. */
  trackPositions: TrackPosition[];
  /** Total duration of the sequence in milliseconds. */
  durationMs: bigint;
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
  durationMs: bigint;
}

// ============================================================================
// Release
// ============================================================================

/** Type of music release. */
export type ReleaseKind = "Album" | "EP" | "Single";

/** Lifecycle state of a release. */
export type ReleaseState =
  | { type: "Initialized" }
  | { type: "Published"; timestampMs: bigint };

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
  /** Type of release (Album, EP, or Single). */
  kind: ReleaseKind;
  /** Current lifecycle state. */
  state: ReleaseState;
  /** Title of the release. */
  title: string;
  /** Description of the release (max 500 characters). */
  description: string;
  /** Optional subtitle (e.g., "Deluxe Edition"). */
  subtitle?: string;
  /** Collection of discs containing tracks. */
  discs: Disc[];
  /** Navigation structure for track ordering. */
  trackSequence: TrackSequence;
  /** Revenue split for each track in basis points (must sum to 100%). */
  trackSplitsBps: BPS[];
  /** Cover artwork for the release. */
  coverArt: CoverArt;
}

/** Revenue split information for a single track. */
export interface TrackSplit {
  /** Position of the track in the release. */
  trackPosition: TrackPosition;
  /** ID of the track's composition. */
  compositionId: string;
  /** Share token type for the composition. */
  compositionShareType: string;
  /** Revenue amount for the composition. */
  compositionSplitValue: bigint;
  /** ID of the track's recording. */
  recordingId: string;
  /** Share token type for the recording. */
  recordingShareType: string;
  /** Revenue amount for the recording. */
  recordingSplitValue: bigint;
}

export interface ReleasePublishedEvent {
  releaseId: string;
  timestampMs: bigint;
  sender: string;
}

export interface ReleaseRevenueDistributedEvent {
  releaseId: string;
  compositionId: string;
  compositionSplitValue: bigint;
  recordingId: string;
  recordingSplitValue: bigint;
}

export interface ReleaseTrackPaidEvent {
  releaseId: string;
  distributionValue: bigint;
}

// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

// ============================================================================
// Common
// ============================================================================

/** Basis points value (0-10000, where 10000 = 100%). */
export interface BPS {
  value: number;
}

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
  /** Royalty rate this composition earns from each recording's revenue (basis points, 0-2000). */
  royaltyRate: BPS;
  /** Epoch in which the royalty rate was last changed (changeable after one full elapsed epoch). */
  royaltyRateLastChangedEpoch: number;
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
  /**
   * Object id of the parent composition. Off-chain convenience for indexing the
   * recording↔composition lineage by id; the durable link is the share type.
   */
  compositionId: string;
  /** Current lifecycle state. */
  state: RecordingState;
  /** Primary title of the recording. */
  title: string;
  /** Version suffix (e.g., "Radio Edit", "Extended Mix"). */
  titleVersion?: string;
  /** Subtitle of the recording. */
  subtitle?: string;
}

/**
 * Emitted once when a recording is published. A pure pointer carrying only the
 * recording's identity — an indexer fetches the full immutable object by
 * `recordingId`.
 */
export interface RecordingPublishedEvent {
  recordingId: string;
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
 * The recording is the handle through which all other metadata (title, share
 * types, composition lineage) is reached.
 */
export interface Track {
  /** Current state of the track (Unassigned until the release claims it, then Assigned). */
  state: TrackState;
  /** ID of the recording on this track. */
  recordingId: string;
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
  /** Optional disc title (e.g., for multi-disc sets). */
  title?: string;
}

// ============================================================================
// Release
// ============================================================================

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
  /** Title of the release. */
  title: string;
  /** Optional subtitle (e.g., "Deluxe Edition"). */
  subtitle?: string;
  /** Collection of discs containing tracks. */
  discs: Disc[];
}

/**
 * Emitted once when a release is published. A pure pointer carrying only the
 * release's identity — an indexer fetches the full immutable object (discs,
 * tracks) by `releaseId`.
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
// Deal Events
// ============================================================================

export interface DealCreatedEvent {
  dealId: string;
  releaseId: string;
  recordingId: string;
  trackSplitBps: BPS;
}

/**
 * Emitted when a deal is accepted: consumed by `track::new` into a track for
 * its target release. Treat as provisional until the release publishes (in the
 * honest path both land in the same transaction).
 */
export interface DealAcceptedEvent {
  dealId: string;
  releaseId: string;
  recordingId: string;
}

/** Emitted when a deal is rejected: destroyed without inclusion in a release. Terminal. */
export interface DealRejectedEvent {
  dealId: string;
  releaseId: string;
  recordingId: string;
}

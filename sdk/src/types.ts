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
}

/**
 * Emitted once when a composition is published. A pure pointer carrying only the
 * composition's identity — an indexer fetches the full immutable object by
 * `compositionId`.
 */
export interface CompositionPublishedEvent {
  compositionId: string;
}

/**
 * Emitted when a composition's royalty rate is set or changed. The composition
 * is identified by the event's `CompositionShare` phantom type, not a field.
 */
export interface CompositionRoyaltySetEvent {
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
 * A recording carries no name of its own: its display title is its
 * composition's title, resolved through the recording's `CompositionShare`
 * type parameter. Richer naming ("(Live)", localized titles) lives in the
 * metadata extension.
 *
 * State machine: Initialized -> Published (immutable after publish)
 */
export interface Recording {
  /** Unique identifier for this recording. */
  id: string;
  /** Current lifecycle state. */
  state: RecordingState;
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
// Deal
// ============================================================================

/**
 * A deal authorizing a recording's inclusion in a specific release. Created by
 * the recording's admin, held (transferably) by whoever assembles the release,
 * and consumed by `track::new`. The recording/composition identities ride on
 * the object's type parameters; the recording's object id is NOT stored.
 */
export interface Deal {
  /** The object ID of the deal. */
  id: string;
  /** The exact release id this deal authorizes (a digest of the full tracklist + nonce). */
  releaseId: string;
  /** The agreed track split for this recording within the release. */
  trackSplitBps: BPS;
  /** The recording's share type (first type parameter of `Deal<R, C>`). */
  recordingShareType: string;
  /** The parent composition's share type (second type parameter of `Deal<R, C>`). */
  compositionShareType: string;
}

// ============================================================================
// Track
// ============================================================================

/** Lifecycle state of a track on a release. */
export type TrackState = "Unassigned" | "Assigned";

/**
 * A track on a release, linking a recording to its position in the tracklist.
 * The recording is the handle through which all other metadata (share types,
 * composition lineage, and — via the composition — the display title) is
 * reached.
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
// Release
// ============================================================================

/** Lifecycle state of a release. */
export type ReleaseState =
  | { type: "Initialized" }
  | { type: "Published"; timestampMs: number };

/**
 * A music release (album, EP, or single).
 *
 * A release is a flat, ordered tracklist with per-track revenue distribution
 * configuration. Display grouping (discs, vinyl sides), cover art, and edition
 * naming live in extensions — the stored tracklist has the same shape as the
 * digest pre-image every deal consented to.
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
  /** The ordered tracklist. */
  tracks: Track[];
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
}

/** Emitted when a deal is rejected: destroyed without inclusion in a release. Terminal. */
export interface DealRejectedEvent {
  dealId: string;
  releaseId: string;
}

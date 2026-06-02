// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

import { bcs } from "@mysten/sui/bcs";
import type {
  CompositionPublishedEvent,
  CompositionRoyaltySetEvent,
  RecordingPublishedEvent,
  ReleasePublishedEvent,
  AudioIngestedEvent,
  DealCreatedEvent,
  DealDestroyedEvent,
} from "./types.ts";

// ============================================================================
// Helpers
// ============================================================================

/** Lowercase hex-encodes a byte sequence (no `0x` prefix). */
function toHex(bytes: Iterable<number>): string {
  let out = "";
  for (const b of bytes) out += b.toString(16).padStart(2, "0");
  return out;
}

// ============================================================================
// Event BCS Definitions
//
// MusicOS uses a lean publish-only event model: build-then-freeze objects emit
// a single pointer event on publish, and indexers fetch the immutable object by
// ID. The only non-pointer events are CompositionRoyaltySetEvent (the royalty
// rate can change after publish), AudioIngestedEvent, and the Deal events.
// ============================================================================

const CompositionPublishedEventBcs = bcs.struct("CompositionPublishedEvent", {
  composition_id: bcs.Address,
});

const CompositionRoyaltySetEventBcs = bcs.struct("CompositionRoyaltySetEvent", {
  composition_id: bcs.Address,
  royalty_rate_bps: bcs.u16(),
});

const RecordingPublishedEventBcs = bcs.struct("RecordingPublishedEvent", {
  recording_id: bcs.Address,
  composition_id: bcs.Address,
});

const ReleasePublishedEventBcs = bcs.struct("ReleasePublishedEvent", {
  release_id: bcs.Address,
});

const AudioIngestedEventBcs = bcs.struct("AudioIngestedEvent", {
  blob_id: bcs.u256(),
  format: bcs.string(),
  channels: bcs.u8(),
  bit_depth: bcs.u8(),
  sample_rate_hz: bcs.u32(),
  samples: bcs.u64(),
  duration_ms: bcs.u64(),
  pcm_digest: bcs.vector(bcs.u8()),
});

const DealCreatedEventBcs = bcs.struct("DealCreatedEvent", {
  deal_id: bcs.Address,
  release_id: bcs.Address,
  recording_id: bcs.Address,
  composition_id: bcs.Address,
  track_title: bcs.string(),
  track_split_bps_value: bcs.u16(),
  track_cover_art_static_blob_id: bcs.u256(),
  track_cover_art_animated_blob_id: bcs.option(bcs.u256()),
});

const DealDestroyedEventBcs = bcs.struct("DealDestroyedEvent", {
  deal_id: bcs.Address,
  release_id: bcs.Address,
  recording_id: bcs.Address,
  composition_id: bcs.Address,
});

// ============================================================================
// Composition Event Parsers
// ============================================================================

export function parseCompositionPublishedEvent(bcsBytes: Uint8Array): CompositionPublishedEvent {
  const parsed = CompositionPublishedEventBcs.parse(bcsBytes);
  return { compositionId: parsed.composition_id };
}

export function parseCompositionRoyaltySetEvent(bcsBytes: Uint8Array): CompositionRoyaltySetEvent {
  const parsed = CompositionRoyaltySetEventBcs.parse(bcsBytes);
  return {
    compositionId: parsed.composition_id,
    royaltyRateBps: parsed.royalty_rate_bps,
  };
}

// ============================================================================
// Recording Event Parsers
// ============================================================================

export function parseRecordingPublishedEvent(bcsBytes: Uint8Array): RecordingPublishedEvent {
  const parsed = RecordingPublishedEventBcs.parse(bcsBytes);
  return {
    recordingId: parsed.recording_id,
    compositionId: parsed.composition_id,
  };
}

// ============================================================================
// Release Event Parsers
// ============================================================================

export function parseReleasePublishedEvent(bcsBytes: Uint8Array): ReleasePublishedEvent {
  const parsed = ReleasePublishedEventBcs.parse(bcsBytes);
  return { releaseId: parsed.release_id };
}

// ============================================================================
// Audio Event Parsers
// ============================================================================

export function parseAudioIngestedEvent(bcsBytes: Uint8Array): AudioIngestedEvent {
  const parsed = AudioIngestedEventBcs.parse(bcsBytes);
  return {
    blobId: parsed.blob_id.toString(),
    format: parsed.format,
    channels: parsed.channels,
    bitDepth: parsed.bit_depth,
    sampleRateHz: parsed.sample_rate_hz,
    samples: Number(parsed.samples),
    durationMs: Number(parsed.duration_ms),
    pcmDigest: toHex(parsed.pcm_digest),
  };
}

// ============================================================================
// Deal Event Parsers
// ============================================================================

export function parseDealCreatedEvent(bcsBytes: Uint8Array): DealCreatedEvent {
  const parsed = DealCreatedEventBcs.parse(bcsBytes);
  return {
    dealId: parsed.deal_id,
    releaseId: parsed.release_id,
    recordingId: parsed.recording_id,
    compositionId: parsed.composition_id,
    trackTitle: parsed.track_title,
    trackSplitBps: { value: parsed.track_split_bps_value },
    trackCoverArtStaticBlobId: parsed.track_cover_art_static_blob_id.toString(),
    trackCoverArtAnimatedBlobId: parsed.track_cover_art_animated_blob_id != null ? parsed.track_cover_art_animated_blob_id.toString() : undefined,
  };
}

export function parseDealDestroyedEvent(bcsBytes: Uint8Array): DealDestroyedEvent {
  const parsed = DealDestroyedEventBcs.parse(bcsBytes);
  return {
    dealId: parsed.deal_id,
    releaseId: parsed.release_id,
    recordingId: parsed.recording_id,
    compositionId: parsed.composition_id,
  };
}

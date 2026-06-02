// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

// Event parsers. The BCS layouts come from the codegen-generated structs (so
// they track the on-chain ABI automatically); these functions parse raw event
// bytes and map them to the public camelCase event types.

import { bcs } from "@mysten/sui/bcs";
import {
  CompositionPublishedEvent as CompositionPublishedEventBcs,
  CompositionRoyaltySetEvent as CompositionRoyaltySetEventBcs,
} from "./contracts/musicos/composition.ts";
import { RecordingPublishedEvent as RecordingPublishedEventBcs } from "./contracts/musicos/recording.ts";
import { ReleasePublishedEvent as ReleasePublishedEventBcs } from "./contracts/musicos/release.ts";
import {
  DealCreatedEvent as DealCreatedEventBcs,
  DealDestroyedEvent as DealDestroyedEventBcs,
} from "./contracts/musicos/deal.ts";
import type {
  CompositionPublishedEvent,
  CompositionRoyaltySetEvent,
  RecordingPublishedEvent,
  ReleasePublishedEvent,
  AudioIngestedEvent,
  DealCreatedEvent,
  DealDestroyedEvent,
} from "./types.ts";

// `AudioIngestedEvent` is emitted by the `audio` package and is not referenced
// by any MusicOS function signature, so codegen does not emit it. Its layout
// mirrors `audio::audio::AudioIngestedEvent`.
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

// === Composition ===

export function parseCompositionPublishedEvent(bytes: Uint8Array): CompositionPublishedEvent {
  const e = CompositionPublishedEventBcs.parse(bytes);
  return { compositionId: e.composition_id };
}

export function parseCompositionRoyaltySetEvent(bytes: Uint8Array): CompositionRoyaltySetEvent {
  const e = CompositionRoyaltySetEventBcs.parse(bytes);
  return { compositionId: e.composition_id, royaltyRateBps: e.royalty_rate_bps };
}

// === Recording ===

export function parseRecordingPublishedEvent(bytes: Uint8Array): RecordingPublishedEvent {
  const e = RecordingPublishedEventBcs.parse(bytes);
  return { recordingId: e.recording_id, compositionId: e.composition_id };
}

// === Release ===

export function parseReleasePublishedEvent(bytes: Uint8Array): ReleasePublishedEvent {
  const e = ReleasePublishedEventBcs.parse(bytes);
  return { releaseId: e.release_id };
}

// === Audio ===

export function parseAudioIngestedEvent(bytes: Uint8Array): AudioIngestedEvent {
  const e = AudioIngestedEventBcs.parse(bytes);
  return {
    blobId: e.blob_id.toString(),
    format: e.format,
    channels: e.channels,
    bitDepth: e.bit_depth,
    sampleRateHz: e.sample_rate_hz,
    samples: Number(e.samples),
    durationMs: Number(e.duration_ms),
    pcmDigest: e.pcm_digest.map((b) => b.toString(16).padStart(2, "0")).join(""),
  };
}

// === Deal ===

export function parseDealCreatedEvent(bytes: Uint8Array): DealCreatedEvent {
  const e = DealCreatedEventBcs.parse(bytes);
  return {
    dealId: e.deal_id,
    releaseId: e.release_id,
    recordingId: e.recording_id,
    compositionId: e.composition_id,
    trackTitle: e.track_title,
    trackSplitBps: { value: e.track_split_bps_value },
    trackCoverArtStaticBlobId: e.track_cover_art_static_blob_id.toString(),
    trackCoverArtAnimatedBlobId:
      e.track_cover_art_animated_blob_id != null ? e.track_cover_art_animated_blob_id.toString() : undefined,
  };
}

export function parseDealDestroyedEvent(bytes: Uint8Array): DealDestroyedEvent {
  const e = DealDestroyedEventBcs.parse(bytes);
  return {
    dealId: e.deal_id,
    releaseId: e.release_id,
    recordingId: e.recording_id,
    compositionId: e.composition_id,
  };
}

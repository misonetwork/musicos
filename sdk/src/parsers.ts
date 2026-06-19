// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

// Event parsers. The BCS layouts come from the codegen-generated structs (so
// they track the on-chain ABI automatically); these functions parse raw event
// bytes and map them to the public camelCase event types.

import {
  CompositionPublishedEvent as CompositionPublishedEventBcs,
  CompositionRoyaltySetEvent as CompositionRoyaltySetEventBcs,
} from "./contracts/miso/composition.ts";
import { RecordingPublishedEvent as RecordingPublishedEventBcs } from "./contracts/miso/recording.ts";
import { ReleasePublishedEvent as ReleasePublishedEventBcs } from "./contracts/miso/release.ts";
import {
  DealCreatedEvent as DealCreatedEventBcs,
  DealAcceptedEvent as DealAcceptedEventBcs,
  DealRejectedEvent as DealRejectedEventBcs,
} from "./contracts/miso/deal.ts";
import type {
  CompositionPublishedEvent,
  CompositionRoyaltySetEvent,
  RecordingPublishedEvent,
  ReleasePublishedEvent,
  DealCreatedEvent,
  DealAcceptedEvent,
  DealRejectedEvent,
} from "./types.ts";

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
  return { recordingId: e.recording_id };
}

// === Release ===

export function parseReleasePublishedEvent(bytes: Uint8Array): ReleasePublishedEvent {
  const e = ReleasePublishedEventBcs.parse(bytes);
  return { releaseId: e.release_id };
}

// === Deal ===

export function parseDealCreatedEvent(bytes: Uint8Array): DealCreatedEvent {
  const e = DealCreatedEventBcs.parse(bytes);
  return {
    dealId: e.deal_id,
    releaseId: e.release_id,
    recordingId: e.recording_id,
    trackSplitBps: { value: e.track_split_bps_value },
  };
}

export function parseDealAcceptedEvent(bytes: Uint8Array): DealAcceptedEvent {
  const e = DealAcceptedEventBcs.parse(bytes);
  return {
    dealId: e.deal_id,
    releaseId: e.release_id,
    recordingId: e.recording_id,
  };
}

export function parseDealRejectedEvent(bytes: Uint8Array): DealRejectedEvent {
  const e = DealRejectedEventBcs.parse(bytes);
  return {
    dealId: e.deal_id,
    releaseId: e.release_id,
    recordingId: e.recording_id,
  };
}

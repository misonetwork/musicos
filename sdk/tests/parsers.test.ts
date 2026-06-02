// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

// Drift gate: serialize each event with its generated BCS struct, then parse it
// back through the public parser and assert the mapped output. If the on-chain
// ABI changes, `bun run codegen` updates the generated struct and these
// round-trips fail loudly here.

import { test, expect } from "bun:test";
import { bcs } from "@mysten/sui/bcs";

import {
  CompositionPublishedEvent,
  CompositionRoyaltySetEvent,
} from "../src/contracts/musicos/composition.ts";
import { RecordingPublishedEvent } from "../src/contracts/musicos/recording.ts";
import { ReleasePublishedEvent } from "../src/contracts/musicos/release.ts";
import { DealCreatedEvent, DealDestroyedEvent } from "../src/contracts/musicos/deal.ts";
import * as parse from "../src/parsers.ts";

const A1 = "0x" + "11".repeat(32);
const A2 = "0x" + "22".repeat(32);
const A3 = "0x" + "33".repeat(32);
const A4 = "0x" + "44".repeat(32);

test("compositionPublishedEvent round-trips", () => {
  const bytes = CompositionPublishedEvent.serialize({ composition_id: A1 }).toBytes();
  expect(parse.parseCompositionPublishedEvent(bytes)).toEqual({ compositionId: A1 });
});

test("compositionRoyaltySetEvent round-trips", () => {
  const bytes = CompositionRoyaltySetEvent.serialize({ composition_id: A1, royalty_rate_bps: 1500 }).toBytes();
  expect(parse.parseCompositionRoyaltySetEvent(bytes)).toEqual({ compositionId: A1, royaltyRateBps: 1500 });
});

test("recordingPublishedEvent round-trips (id + parent composition)", () => {
  const bytes = RecordingPublishedEvent.serialize({ recording_id: A1, composition_id: A2 }).toBytes();
  expect(parse.parseRecordingPublishedEvent(bytes)).toEqual({ recordingId: A1, compositionId: A2 });
});

test("releasePublishedEvent round-trips", () => {
  const bytes = ReleasePublishedEvent.serialize({ release_id: A1 }).toBytes();
  expect(parse.parseReleasePublishedEvent(bytes)).toEqual({ releaseId: A1 });
});

test("dealCreatedEvent round-trips (split + cover-art blob ids)", () => {
  const bytes = DealCreatedEvent.serialize({
    deal_id: A1,
    release_id: A2,
    recording_id: A3,
    composition_id: A4,
    track_title: "Radio Edit",
    track_split_bps_value: 2500,
    track_cover_art_static_blob_id: "12345",
    track_cover_art_animated_blob_id: null,
  }).toBytes();
  expect(parse.parseDealCreatedEvent(bytes)).toEqual({
    dealId: A1,
    releaseId: A2,
    recordingId: A3,
    compositionId: A4,
    trackTitle: "Radio Edit",
    trackSplitBps: { value: 2500 },
    trackCoverArtStaticBlobId: "12345",
    trackCoverArtAnimatedBlobId: undefined,
  });
});

test("dealDestroyedEvent round-trips", () => {
  const bytes = DealDestroyedEvent.serialize({ deal_id: A1, release_id: A2, recording_id: A3, composition_id: A4 }).toBytes();
  expect(parse.parseDealDestroyedEvent(bytes)).toEqual({ dealId: A1, releaseId: A2, recordingId: A3, compositionId: A4 });
});

test("audioIngestedEvent round-trips (format + pcm_digest hex)", () => {
  // Mirrors audio::audio::AudioIngestedEvent field order.
  const AudioIngestedEvent = bcs.struct("AudioIngestedEvent", {
    blob_id: bcs.u256(),
    format: bcs.string(),
    channels: bcs.u8(),
    bit_depth: bcs.u8(),
    sample_rate_hz: bcs.u32(),
    samples: bcs.u64(),
    duration_ms: bcs.u64(),
    pcm_digest: bcs.vector(bcs.u8()),
  });
  const digest = Array.from({ length: 32 }, (_, i) => i + 1);
  const bytes = AudioIngestedEvent.serialize({
    blob_id: "999",
    format: "flac",
    channels: 2,
    bit_depth: 16,
    sample_rate_hz: 44100,
    samples: "441000",
    duration_ms: "10000",
    pcm_digest: digest,
  }).toBytes();
  const out = parse.parseAudioIngestedEvent(bytes);
  expect(out.blobId).toBe("999");
  expect(out.format).toBe("flac");
  expect(out.channels).toBe(2);
  expect(out.samples).toBe(441000);
  expect(out.pcmDigest).toBe(digest.map((b) => b.toString(16).padStart(2, "0")).join(""));
});

// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

// Drift gate: serialize each event with its generated BCS struct, then parse it
// back through the public parser and assert the mapped output. If the on-chain
// ABI changes, `bun run codegen` updates the generated struct and these
// round-trips fail loudly here.

import { test, expect } from "bun:test";

import {
  CompositionPublishedEvent,
  CompositionRoyaltySetEvent,
} from "../src/contracts/miso/composition.ts";
import { RecordingPublishedEvent } from "../src/contracts/miso/recording.ts";
import { ReleasePublishedEvent } from "../src/contracts/miso/release.ts";
import { DealCreatedEvent, DealAcceptedEvent, DealRejectedEvent } from "../src/contracts/miso/deal.ts";
import * as parse from "../src/parsers.ts";

const A1 = "0x" + "11".repeat(32);
const A2 = "0x" + "22".repeat(32);

test("compositionPublishedEvent round-trips", () => {
  const bytes = CompositionPublishedEvent.serialize({ composition_id: A1 }).toBytes();
  expect(parse.parseCompositionPublishedEvent(bytes)).toEqual({ compositionId: A1 });
});

test("compositionRoyaltySetEvent round-trips", () => {
  const bytes = CompositionRoyaltySetEvent.serialize({
    composition_id: A1,
    previous_royalty_rate_bps: 1000,
    royalty_rate_bps: 1500,
    changed_by: A2,
  }).toBytes();
  expect(parse.parseCompositionRoyaltySetEvent(bytes)).toEqual({ royaltyRateBps: 1500 });
});

test("recordingPublishedEvent round-trips (id only)", () => {
  const bytes = RecordingPublishedEvent.serialize({ recording_id: A1 }).toBytes();
  expect(parse.parseRecordingPublishedEvent(bytes)).toEqual({ recordingId: A1 });
});

test("releasePublishedEvent round-trips", () => {
  const bytes = ReleasePublishedEvent.serialize({ release_id: A1 }).toBytes();
  expect(parse.parseReleasePublishedEvent(bytes)).toEqual({ releaseId: A1 });
});

test("dealCreatedEvent round-trips (split only)", () => {
  const bytes = DealCreatedEvent.serialize({
    deal_id: A1,
    recording_id: A2,
    release_id: A2,
    track_split_bps_value: 2500,
    created_by: A1,
  }).toBytes();
  expect(parse.parseDealCreatedEvent(bytes)).toEqual({
    dealId: A1,
    releaseId: A2,
    trackSplitBps: { value: 2500 },
  });
});

test("dealAcceptedEvent round-trips", () => {
  const bytes = DealAcceptedEvent.serialize({ deal_id: A1, release_id: A2 }).toBytes();
  expect(parse.parseDealAcceptedEvent(bytes)).toEqual({ dealId: A1, releaseId: A2 });
});

test("dealRejectedEvent round-trips", () => {
  const bytes = DealRejectedEvent.serialize({ deal_id: A1, release_id: A2 }).toBytes();
  expect(parse.parseDealRejectedEvent(bytes)).toEqual({ dealId: A1, releaseId: A2 });
});

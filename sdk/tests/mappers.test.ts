// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

// Drift gate for object mapping: serialize a struct with its generated BCS
// definition, parse it, and run it through the internal mappers, asserting the
// public camelCase shape. Exercises enums, VecMap, BPS tuples, Options, and the
// still/pcmDigest fields.

import { test, expect } from "bun:test";

import { Audio } from "../src/contracts/musicos/deps/audio/audio.ts";
import { Composition } from "../src/contracts/musicos/composition.ts";
import { mapAudio, mapComposition, mapBps, mapWalrusData } from "../src/internal.ts";

const ADDR = "0x" + "ab".repeat(32);

test("mapAudio: format + pcm_digest hex + blob + ingester", () => {
  const digest = Array.from({ length: 32 }, (_, i) => i);
  const bytes = Audio.serialize({
    ingester: { name: "0000000000000000000000000000000000000000000000000000000000000002::ing::W" },
    format: "flac",
    channels: 2,
    bit_depth: 16,
    sample_rate_hz: 44100,
    samples: "441000",
    pcm_digest: digest,
    data: { Blob: "777" },
  }).toBytes();

  const audio = mapAudio(Audio.parse(bytes));
  expect(audio.format).toBe("flac");
  expect(audio.channels).toBe(2);
  expect(audio.bitDepth).toBe(16);
  expect(audio.sampleRateHz).toBe(44100);
  expect(audio.samples).toBe(441000);
  expect(audio.pcmDigest).toBe(digest.map((b) => b.toString(16).padStart(2, "0")).join(""));
  expect(audio.data).toEqual({ type: "Blob", blobId: "777" });
  expect(audio.ingester).toContain("::ing::W");
});

test("mapComposition: royaltyRate (BPS), credits (VecMap), state enum, alt titles", () => {
  const bytes = Composition.serialize({
    id: ADDR,
    state: { Initialized: true },
    title: "My Song",
    alternate_titles: ["Alt One"],
    credits: {
      contents: [{ key: ADDR, value: { display_name: "Writer", roles: [{ Composer: true }] } }],
    },
    royalty_rate: [1000],
  }).toBytes();

  const comp = mapComposition(ADDR, Composition.parse(bytes));
  expect(comp.id).toBe(ADDR);
  expect(comp.state).toEqual({ type: "Initialized" });
  expect(comp.title).toBe("My Song");
  expect(comp.alternateTitles).toEqual(["Alt One"]);
  expect(comp.royaltyRate).toEqual({ value: 1000 });
  expect(comp.credits[ADDR]).toEqual({ displayName: "Writer", roles: [{ type: "Composer" }] });
});

test("mapState maps Published with timestamp", () => {
  const bytes = Composition.serialize({
    id: ADDR,
    state: { Published: "1700000000000" },
    title: "x",
    alternate_titles: [],
    credits: { contents: [] },
    royalty_rate: [1000],
  }).toBytes();
  expect(mapComposition(ADDR, Composition.parse(bytes)).state).toEqual({
    type: "Published",
    timestampMs: 1700000000000,
  });
});

test("mapBps + mapWalrusData unit behavior", () => {
  expect(mapBps([2500])).toEqual({ value: 2500 });
  expect(mapWalrusData({ $kind: "Blob", Blob: "42" })).toEqual({ type: "Blob", blobId: "42" });
  expect(() => mapWalrusData({ $kind: "QuiltPatch", QuiltPatch: [] })).toThrow();
});

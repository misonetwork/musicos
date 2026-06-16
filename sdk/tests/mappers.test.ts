// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

// Drift gate for object mapping: serialize a struct with its generated BCS
// definition, parse it, and run it through the internal mappers, asserting the
// public camelCase shape. Exercises the BPS tuple, the royalty-rate tuple, and
// the lifecycle state enum.

import { test, expect } from "bun:test";

import { Composition } from "../src/contracts/musicos/composition.ts";
import { mapComposition, mapBps } from "../src/internal.ts";

const ADDR = "0x" + "ab".repeat(32);

test("mapComposition: royaltyRate (BPS + epoch), state enum", () => {
  const bytes = Composition.serialize({
    id: ADDR,
    state: { Initialized: true },
    title: "My Song",
    royalty_rate: [[1000], "7"],
  }).toBytes();

  const comp = mapComposition(ADDR, Composition.parse(bytes));
  expect(comp.id).toBe(ADDR);
  expect(comp.state).toEqual({ type: "Initialized" });
  expect(comp.title).toBe("My Song");
  expect(comp.royaltyRate).toEqual({ value: 1000 });
  expect(comp.royaltyRateLastChangedEpoch).toBe(7);
});

test("mapState maps Published with timestamp", () => {
  const bytes = Composition.serialize({
    id: ADDR,
    state: { Published: "1700000000000" },
    title: "x",
    royalty_rate: [[1000], "0"],
  }).toBytes();
  expect(mapComposition(ADDR, Composition.parse(bytes)).state).toEqual({
    type: "Published",
    timestampMs: 1700000000000,
  });
});

test("mapBps unit behavior", () => {
  expect(mapBps([2500])).toEqual({ value: 2500 });
});

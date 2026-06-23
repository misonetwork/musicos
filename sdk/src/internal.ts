// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

// Mappers from the generated BCS-parse output (snake_case, with @mysten/bcs
// conventions: enums as `{ $kind, [Variant]: payload }`, tuples as arrays,
// VecMap as `{ contents: [{ key, value }] }`, u64/u256 as strings, Address as
// hex) into the public camelCase domain types in `./types`.
//
// These are the single boundary between codegen output and the public API, so
// when the generated shapes change, type errors surface here.

import type {
  BPS,
  Composition,
  Disc,
  Recording,
  Release,
  Track,
  TrackState,
} from "./types.ts";

/* eslint-disable @typescript-eslint/no-explicit-any */
type Parsed = any;

// === Primitives ===

/** `BPS` is a Move tuple struct `(u16)`, parsed as `[number]`. */
export function mapBps(d: Parsed): BPS {
  return { value: Number(Array.isArray(d) ? d[0] : d) };
}

/** Lifecycle state enum (`Initialized | Published(u64)`). */
export function mapState(
  d: Parsed,
): { type: "Initialized" } | { type: "Published"; timestampMs: number } {
  if (d?.$kind === "Published") return { type: "Published", timestampMs: Number(d.Published) };
  return { type: "Initialized" };
}

// === Objects ===

export function mapComposition(id: string, d: Parsed): Composition {
  return {
    id,
    state: mapState(d.state),
    title: d.title,
    // CompositionRoyaltyRate is a Move tuple struct `(BPS, u64)` -> [bps, epoch].
    royaltyRate: mapBps(d.royalty_rate[0]),
    royaltyRateLastChangedEpoch: Number(d.royalty_rate[1]),
  };
}

export function mapRecording(id: string, d: Parsed): Recording {
  return {
    id,
    compositionId: d.composition_id,
    state: mapState(d.state),
    title: d.title,
    titleVersion: d.title_version ?? undefined,
    subtitle: d.subtitle ?? undefined,
  };
}

export function mapTrack(d: Parsed): Track {
  return {
    state: (d.state?.$kind ?? "Unassigned") as TrackState,
    recordingId: d.recording_id,
    splitBps: mapBps(d.split_bps),
  };
}

export function mapDisc(d: Parsed): Disc {
  return {
    tracks: (d.tracks ?? []).map(mapTrack),
    title: d.title ?? undefined,
  };
}

export function mapRelease(id: string, d: Parsed): Release {
  return {
    id,
    state: mapState(d.state),
    title: d.title,
    subtitle: d.subtitle ?? undefined,
    discs: (d.discs ?? []).map(mapDisc),
  };
}

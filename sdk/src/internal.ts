// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

// Internal shared helpers (not exported from the package root).
//
// 1) Mappers from the generated BCS-parse output (snake_case, with @mysten/bcs
//    conventions: enums as `{ $kind, [Variant]: payload }`, tuples as arrays,
//    VecMap as `{ contents: [{ key, value }] }`, u64/u256 as strings, Address as
//    hex) into the public camelCase domain types in `./types`. These are the
//    single boundary between codegen output and the public API, so when the
//    generated shapes change, type errors surface here.
//
// 2) PTB building blocks shared by the transaction builders (option-call
//    targets, `Option<String>` construction, and the release publish tail).

import type { Transaction, TransactionObjectArgument } from "@mysten/sui/transactions";
import * as release from "./contracts/miso/release.ts";
import type {
  BPS,
  Composition,
  Recording,
  Release as ReleaseType,
  Track,
  TrackState,
} from "./types.ts";

// === PTB building blocks ===

/** `0x1::option::none` / `0x1::option::some` moveCall targets. */
export const OPTION_NONE = "0x1::option::none";
export const OPTION_SOME = "0x1::option::some";

export interface ReleasePublishTail {
  title: string;
  /** u256 nonce as a decimal string (deterministic release id). */
  nonce: string;
  releaseRegistryId: string;
  /** Recipient of the `ReleaseAdminCap`. */
  adminAddress: string;
}

/**
 * The shared release publish tail: `release::new(title, tracks, nonce, registry)`
 * → `publish` (shares the release) → transfer the admin cap to `adminAddress`.
 */
export function buildAndPublishRelease(
  tx: Transaction,
  misoPackageId: string,
  params: ReleasePublishTail,
  trackVec: TransactionObjectArgument,
): void {
  const result = tx.add(
    release._new({
      package: misoPackageId,
      arguments: [tx.pure.string(params.title), trackVec, tx.pure.u256(BigInt(params.nonce)), tx.object(params.releaseRegistryId)],
    }),
  );
  const releaseArg = result[0]!;
  const adminCap = result[1]!;
  tx.add(release.publish({ package: misoPackageId, arguments: [releaseArg, adminCap] }));
  tx.transferObjects([adminCap], tx.pure.address(params.adminAddress));
}

// === Mappers ===

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
    state: mapState(d.state),
  };
}

export function mapTrack(d: Parsed): Track {
  return {
    state: (d.state?.$kind ?? "Unassigned") as TrackState,
    recordingId: d.recording_id,
    splitBps: mapBps(d.split_bps),
  };
}

export function mapRelease(id: string, d: Parsed): ReleaseType {
  return {
    id,
    state: mapState(d.state),
    title: d.title,
    tracks: (d.tracks ?? []).map(mapTrack),
  };
}

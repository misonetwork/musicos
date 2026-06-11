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
  CompositionCredit,
  CompositionPartyRole,
  CoverArt,
  Disc,
  PartyKind,
  Recording,
  RecordingCredit,
  RecordingPartyRole,
  RecordingPartyRoleLevel,
  Release,
  ReleaseCredit,
  ReleasePartyRole,
  Track,
  TrackState,
  WalrusData,
} from "./types.ts";

/* eslint-disable @typescript-eslint/no-explicit-any */
type Parsed = any;

// === Primitives ===

/** `BPS` is a Move tuple struct `(u16)`, parsed as `[number]`. */
export function mapBps(d: Parsed): BPS {
  return { value: Number(Array.isArray(d) ? d[0] : d) };
}

/** `WalrusData` enum — MusicOS enforces blob-only storage. Blob is a tuple
 * `(blob_id, confidentiality)`. */
export function mapWalrusData(d: Parsed): WalrusData {
  if (d?.$kind !== "Blob") throw new Error(`Expected a Walrus Blob, got: ${JSON.stringify(d)?.slice(0, 120)}`);
  const [blobId, conf] = d.Blob as [unknown, Parsed];
  const out: WalrusData = { type: "Blob", blobId: String(blobId) };
  if (conf?.$kind === "Encrypted") {
    out.encryption = {
      dek: (conf.Encrypted.dek ?? []).map((b: number) => b.toString(16).padStart(2, "0")).join(""),
    };
  }
  return out;
}

/** `std::type_name::TypeName` is a struct `{ name }`. */
export function mapTypeName(d: Parsed): string {
  return typeof d === "string" ? d : d?.name;
}

/** Lifecycle state enum (`Initialized | Published(u64)`). */
export function mapState(
  d: Parsed,
): { type: "Initialized" } | { type: "Published"; timestampMs: number } {
  if (d?.$kind === "Published") return { type: "Published", timestampMs: Number(d.Published) };
  return { type: "Initialized" };
}

/** `vec_set::VecSet<address>` -> string[]. */
export function mapVecSet(d: Parsed): string[] {
  return (d?.contents ?? []) as string[];
}

// === CoverArt ===

export function mapCoverArt(d: Parsed): CoverArt {
  return {
    still: mapWalrusData(d.still),
    animated: d.animated != null ? mapWalrusData(d.animated) : undefined,
  };
}

// === Roles ===

export function mapCompositionRole(d: Parsed): CompositionPartyRole {
  return { type: d.$kind } as CompositionPartyRole;
}

export function mapReleaseRole(d: Parsed): ReleasePartyRole {
  return { type: d.$kind } as ReleasePartyRole;
}

export function mapRecordingRole(d: Parsed): RecordingPartyRole {
  const kind = d.$kind as RecordingPartyRole["type"];
  if (kind === "Instrumentalist") {
    // Move tuple: (String, Option<Level>) -> [instrument, level|null]
    const [instrument, level] = d.Instrumentalist as [string, Parsed];
    return { type: kind, instrument, level: level?.$kind as RecordingPartyRoleLevel | undefined };
  }
  if (kind === "ArtistsAndRepertoire" || kind === "Copyist") {
    return { type: kind };
  }
  // The rest carry an Option<Level> payload.
  const level = d[kind];
  return { type: kind, level: level?.$kind as RecordingPartyRoleLevel | undefined } as RecordingPartyRole;
}

function mapCredits<R>(d: Parsed, roleMapper: (r: Parsed) => R): Record<string, { displayName: string; roles: R[] }> {
  const out: Record<string, { displayName: string; roles: R[] }> = {};
  for (const entry of d?.contents ?? []) {
    out[entry.key] = {
      displayName: entry.value.display_name,
      roles: (entry.value.roles ?? []).map(roleMapper),
    };
  }
  return out;
}

// === Objects ===

export function mapComposition(id: string, d: Parsed): Composition {
  return {
    id,
    state: mapState(d.state),
    title: d.title,
    credits: mapCredits<CompositionPartyRole>(d.credits, mapCompositionRole) as Record<string, CompositionCredit>,
    // CompositionRoyaltyRate is a Move tuple struct `(BPS, u64)` -> [bps, epoch].
    royaltyRate: mapBps(d.royalty_rate[0]),
    royaltyRateLastChangedEpoch: Number(d.royalty_rate[1]),
  };
}

export function mapRecording(id: string, d: Parsed): Recording {
  return {
    id,
    state: mapState(d.state),
    title: d.title,
    titleVersion: d.title_version ?? undefined,
    subtitle: d.subtitle ?? undefined,
    compositionId: d.composition_id,
    compositionRoyaltyRate: mapBps(d.composition_royalty_rate),
    primaryArtistIds: mapVecSet(d.primary_artist_ids),
    featuredArtistIds: mapVecSet(d.featured_artist_ids),
    credits: mapCredits<RecordingPartyRole>(d.credits, mapRecordingRole) as Record<string, RecordingCredit>,
    coverArt: mapCoverArt(d.cover_art),
  };
}

export function mapTrack(d: Parsed): Track {
  return {
    state: (d.state?.$kind ?? "Unassigned") as TrackState,
    compositionId: d.composition_id,
    compositionShareType: mapTypeName(d.composition_share_type),
    compositionRoyaltyRate: mapBps(d.composition_royalty_rate),
    recordingId: d.recording_id,
    recordingShareType: mapTypeName(d.recording_share_type),
    title: d.title,
    coverArt: mapCoverArt(d.cover_art),
    splitBps: mapBps(d.split_bps),
  };
}

export function mapDisc(d: Parsed): Disc {
  return {
    tracks: (d.tracks ?? []).map(mapTrack),
    artwork: d.artwork != null ? mapCoverArt(d.artwork) : undefined,
    title: d.title ?? undefined,
  };
}

export function mapRelease(id: string, d: Parsed): Release {
  return {
    id,
    state: mapState(d.state),
    title: d.title,
    subtitle: d.subtitle ?? undefined,
    credits: mapCredits<ReleasePartyRole>(d.credits, mapReleaseRole) as Record<string, ReleaseCredit>,
    discs: (d.discs ?? []).map(mapDisc),
    coverArt: mapCoverArt(d.cover_art),
  };
}

export function mapParty(id: string, d: Parsed): { id: string; kind: PartyKind; name: string } {
  const kind: PartyKind =
    d.kind?.$kind === "Group"
      ? { type: "Group", memberIds: d.kind.Group?.members?.contents ?? d.kind.Group?.contents ?? [] }
      : { type: "Individual" };
  return { id, kind, name: d.name };
}

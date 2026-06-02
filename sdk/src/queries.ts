// Copyright (c) Unconfirmed Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

import type { ClientWithCoreApi } from "@mysten/sui/client";
import type { SuiGraphQLClient } from "@mysten/sui/graphql";
import { graphql } from "@mysten/sui/graphql/schema";
import { deriveObjectID } from "@mysten/sui/utils";
import type { CompositionAdminCap, RecordingAdminCap, ReleaseAdminCap } from "./types.ts";

// ============================================================================
// Helpers
// ============================================================================

/**
 * Extracts the type parameter T from a generic on-chain type string like
 * `package::module::Type<T>`.
 */
function extractTypeParam(objectType: string): string {
  const match = objectType.match(/<(.+)>$/);
  if (!match?.[1]) {
    throw new Error(`Could not extract type parameter from: ${objectType}`);
  }
  return match[1];
}

// ============================================================================
// Shared GraphQL Queries
// ============================================================================

/** Query objects by type, returning address and JSON content. */
const ObjectsByTypeQuery = graphql(`
  query GetObjectsByType($type: String!) {
    objects(filter: { type: $type }) {
      nodes {
        address
        asMoveObject {
          contents {
            json
          }
        }
      }
    }
  }
`);

/** Query for finding singleton objects by type (registries, etc.). */
const SingletonByTypeQuery = graphql(`
  query GetSingletonByType($type: String!) {
    objects(filter: { type: $type }) {
      nodes {
        address
      }
    }
  }
`);

/**
 * Extracts the share type from a Currency object.
 *
 * Given a Currency<T> object ID, fetches the object and extracts the type parameter T.
 *
 * @param client - A Sui gRPC client
 * @param shareCurrencyId - The object ID of the Currency object
 * @returns The full share type string (e.g., "0x...::share::SHARE")
 *
 * @example
 * ```ts
 * const shareType = await getShareType(suiClient, "0x4ddc...");
 * // Returns: "0xa706...::share::SHARE"
 * ```
 */
export async function getShareCurrencyType(
  client: ClientWithCoreApi,
  shareCurrencyId: string
): Promise<string> {
  const { object } = await client.core.getObject({ objectId: shareCurrencyId });
  return extractTypeParam(object.type);
}

/**
 * Finds the TreasuryCap for a share currency owned by a specific address.
 *
 * @param client - A Sui gRPC client
 * @param shareCurrencyId - The object ID of the Currency object
 * @param owner - The address that should own the TreasuryCap
 * @returns The object ID of the TreasuryCap
 */
export async function getShareCurrencyTreasuryCap(
  client: ClientWithCoreApi,
  shareCurrencyId: string,
  owner: string
): Promise<string> {
  const shareCurrencyType = await getShareCurrencyType(client, shareCurrencyId);
  const { objects } = await client.core.listOwnedObjects({
    owner,
    type: `0x2::coin::TreasuryCap<${shareCurrencyType}>`,
  });

  if (objects.length === 0) {
    throw new Error(`No TreasuryCap found for ${shareCurrencyType} owned by ${owner}`);
  }

  return objects[0]!.objectId;
}

/**
 * Extracts the share type from a Recording object.
 *
 * Given a Recording<T> object ID, fetches the object and extracts the type parameter T.
 *
 * @param client - A Sui gRPC client
 * @param recordingId - The object ID of the Recording object
 * @returns The full share type string (e.g., "0x...::share::Share")
 */
export async function getRecordingShareType(
  client: ClientWithCoreApi,
  recordingId: string
): Promise<string> {
  const { object } = await client.core.getObject({ objectId: recordingId });
  return extractTypeParam(object.type);
}

/**
 * Fetches the ReleaseRegistry object ID.
 *
 * @param client - A Sui GraphQL client
 * @param musicOsPackageId - The MusicOS package ID
 * @returns The object ID of the ReleaseRegistry
 */
export async function getReleaseRegistry(
  client: SuiGraphQLClient,
  musicOsPackageId: string
): Promise<string> {
  const registryType = `${musicOsPackageId}::release::ReleaseRegistry`;

  const result = await client.query({
    query: SingletonByTypeQuery,
    variables: { type: registryType },
  });

  const node = result.data?.objects?.nodes?.[0];
  if (!node?.address) {
    throw new Error("ReleaseRegistry not found");
  }

  return node.address;
}

const ObjectQuery = graphql(`
  query GetObject($address: SuiAddress!) {
    object(address: $address) {
      address
      asMoveObject {
        contents {
          json
        }
      }
    }
  }
`);



// ============================================================================
// Response Parsers
// Plain functions that transform raw on-chain JSON to typed objects.
// ============================================================================

import type {
  WalrusData,
  Audio, BPS, CoverArt,
  Track, Disc, Recording, Composition, Release, Party,
  RecordingCredit, CompositionCredit, ReleaseCredit,
  ReleaseKind, ReleaseState, RecordingState, CompositionState,
  TrackState, PartyKind,
} from "./types.ts";

type Json = Record<string, any>;

function parseWalrusData(d: any): WalrusData {
  if (!d) throw new Error("WalrusData is null");
  // Already parsed
  if (d.type === "Blob") return d;
  // Enum with @variant tag
  if (d["@variant"] === "Blob") return { type: "Blob", blobId: String(d.pos0) };
  // Positional tuple struct: Blob(u256) has 1 pos field
  if ("pos0" in d) return { type: "Blob", blobId: String(d.pos0) };
  // Named field formats
  if (d.blob_id != null) return { type: "Blob", blobId: String(d.blob_id) };
  if (d.blobId != null) return { type: "Blob", blobId: String(d.blobId) };
  throw new Error(`Unknown WalrusData format: ${JSON.stringify(d).slice(0, 200)}`);
}

function parseCoverArt(d: Json): CoverArt {
  return { static: parseWalrusData(d.static), animated: d.animated ? parseWalrusData(d.animated) : undefined };
}

function parseBPS(d: any): BPS {
  if (typeof d === "object" && "pos0" in d) return { value: parseInt(d.pos0, 10) };
  return { value: Number(d.value ?? d) };
}

function parseVariant(d: Json): string {
  return d["@variant"];
}

function parseState(d: Json): { type: "Initialized" } | { type: "Published"; timestampMs: number } {
  const v = parseVariant(d);
  if (v === "Published") return { type: "Published", timestampMs: Number(d.pos0) };
  return { type: "Initialized" };
}

/** Hex-encodes a `vector<u8>` rendered as a JSON number array (or passes through a hex string). */
function bytesToHex(v: unknown): string {
  if (typeof v === "string") return v.startsWith("0x") ? v.slice(2) : v;
  if (Array.isArray(v)) return v.map((b) => Number(b).toString(16).padStart(2, "0")).join("");
  return "";
}

function parseAudio(d: Json): Audio {
  return {
    ingester: d.ingester?.name ?? d.ingester,
    format: d.format,
    channels: Number(d.channels),
    bitDepth: Number(d.bit_depth),
    sampleRateHz: Number(d.sample_rate_hz),
    samples: Number(d.samples),
    pcmDigest: bytesToHex(d.pcm_digest),
    data: parseWalrusData(d.data),
  };
}

function parseRecordingRole(d: Json): any {
  const role: any = { type: d["@variant"] };
  if (d["@variant"] === "Instrumentalist") {
    role.instrument = d.pos0;
    if (d.pos1) role.level = d.pos1["@variant"];
  } else if (d.pos0 && typeof d.pos0 === "object" && "@variant" in d.pos0) {
    role.level = d.pos0["@variant"];
  }
  return role;
}

function parseCredits<T>(contents: any[], roleParser: (r: Json) => any): Record<string, T> {
  const result: Record<string, any> = {};
  for (const entry of contents) {
    result[entry.key] = {
      displayName: entry.value.display_name,
      roles: (entry.value.roles ?? []).map(roleParser),
    };
  }
  return result;
}

function parseTrack(d: Json): Track {
  return {
    state: d.state?.["@variant"] as TrackState,
    compositionId: d.composition_id,
    compositionShareType: d.composition_share_type?.name ?? d.composition_share_type,
    compositionRoyaltyRate: parseBPS(d.composition_royalty_rate),
    recordingId: d.recording_id,
    recordingShareType: d.recording_share_type?.name ?? d.recording_share_type,
    recordingMasterIngesterType: d.recording_master_ingester_type?.name ?? d.recording_master_ingester_type,
    title: d.title,
    durationMs: Number(d.duration_ms),
    coverArt: parseCoverArt(d.cover_art),
    splitBps: parseBPS(d.split_bps),
  };
}

function parseDisc(d: Json): Disc {
  return {
    tracks: (d.tracks ?? []).map(parseTrack),
    artwork: d.artwork ? parseCoverArt(d.artwork) : undefined,
    title: d.title ?? undefined,
    durationMs: Number(d.duration_ms),
  };
}

function parseRecordingJson(d: Json): Omit<Recording, "id"> {
  return {
    state: parseState(d.state) as RecordingState,
    title: d.title,
    titleVersion: d.title_version ?? undefined,
    subtitle: d.subtitle ?? undefined,
    compositionId: d.composition_id,
    compositionRoyaltyRate: parseBPS(d.composition_royalty_rate),
    primaryArtistIds: d.primary_artist_ids?.contents ?? [],
    featuredArtistIds: d.featured_artist_ids?.contents ?? [],
    credits: parseCredits<RecordingCredit>(d.credits?.contents ?? [], parseRecordingRole),
    language: d.language?.pos0 ?? undefined,
    isExplicit: Boolean(d.is_explicit),
    isInstrumental: Boolean(d.is_instrumental),
    master: parseAudio(d.master),
    coverArt: parseCoverArt(d.cover_art),
  };
}

function parseCompositionJson(d: Json): Omit<Composition, "id"> {
  return {
    state: parseState(d.state) as CompositionState,
    title: d.title,
    alternateTitles: d.alternate_titles ?? [],
    credits: parseCredits<CompositionCredit>(d.credits?.contents ?? [], (r) => ({ type: r["@variant"] })),
    royaltyRate: parseBPS(d.royalty_rate),
  };
}


function parseReleaseJson(d: Json): Omit<Release, "id"> {
  return {
    kind: d.kind?.["@variant"] as ReleaseKind,
    state: parseState(d.state) as ReleaseState,
    title: d.title,
    description: d.description ?? "",
    subtitle: d.subtitle ?? undefined,
    credits: parseCredits<ReleaseCredit>(d.credits?.contents ?? [], (r) => ({ type: r["@variant"] })),
    discs: (d.discs ?? []).map(parseDisc),
    coverArt: parseCoverArt(d.cover_art),
  };
}

function parsePartyJson(d: Json): Omit<Party, "id"> {
  const kindVariant = d.kind?.["@variant"];
  const kind: PartyKind = kindVariant === "Group"
    ? { type: "Group", memberIds: d.kind?.pos0?.contents ?? [] }
    : { type: "Individual" };
  return { kind, name: d.name };
}

const MultiObjectQuery = graphql(`
  query GetMultipleObjects($ids: [SuiAddress!]!) {
    objects(filter: { objectIds: $ids }) {
      nodes {
        address
        asMoveObject {
          contents {
            json
          }
        }
      }
    }
  }
`);

/**
 * Fetches a release by its object ID using Core API.
 *
 * @param client - A Sui client with Core API (SuiGrpcClient or similar)
 * @param releaseId - The object ID of the Release
 * @returns The Release object
 */
/**
 * Fetches multiple releases by their IDs in a single request using Core API.
 */
export async function getReleasesByIds(
  client: ClientWithCoreApi,
  releaseIds: string[]
): Promise<Record<string, Release>> {
  const objects = await getObjects(client, releaseIds);
  const releases: Record<string, Release> = {};

  for (const [id, json] of Object.entries(objects)) {
    const parsed = parseReleaseJson(json as Json);
    releases[id] = { id, ...parsed } as Release;
  }

  return releases;
}

/**
 * Fetches a release by its object ID. Convenience wrapper around getReleasesByIds.
 */
export async function getReleaseById(
  client: ClientWithCoreApi,
  releaseId: string
): Promise<Release> {
  const releases = await getReleasesByIds(client, [releaseId]);
  const release = releases[releaseId];
  if (!release) throw new Error(`Release not found: ${releaseId}`);
  return release;
}

/**
 * Fetches a party by its object ID using Core API.
 *
 * @param client - A Sui client with Core API (SuiGrpcClient or similar)
 * @param partyId - The object ID of the Party
 * @returns The Party object
 */
export async function getParty(client: ClientWithCoreApi, partyId: string): Promise<Party> {
  const { object } = await client.core.getObject({ objectId: partyId, include: { json: true } });
  if (!object.json) throw new Error(`Party not found: ${partyId}`);

  const parsed = parsePartyJson(object.json as Json);
  return { id: partyId, ...parsed };
}

/**
 * @deprecated Use getRelease with Core API client instead.
 * Fetches a release by its object ID using GraphQL.
 */
export async function getReleaseGraphQL(
  client: SuiGraphQLClient,
  releaseId: string
): Promise<Release> {
  const result = await client.query({
    query: ObjectQuery,
    variables: { address: releaseId },
  });

  const json = result.data?.object?.asMoveObject?.contents?.json;
  if (!json) {
    throw new Error(`Release not found: ${releaseId}`);
  }

  const parsed = parseReleaseJson(json as Json);
  return { id: releaseId, ...parsed } as Release;
}

/**
 * Fetches a recording by its object ID. Convenience wrapper around getRecordingsByIds.
 */
export async function getRecordingById(
  client: ClientWithCoreApi,
  recordingId: string
): Promise<Recording> {
  const recordings = await getRecordingsByIds(client, [recordingId]);
  const recording = recordings[recordingId];
  if (!recording) throw new Error(`Recording not found: ${recordingId}`);
  return recording;
}

/**
 * Fetches multiple compositions by their IDs in a single request using Core API.
 */
export async function getCompositionsByIds(
  client: ClientWithCoreApi,
  compositionIds: string[]
): Promise<Record<string, Composition>> {
  const objects = await getObjects(client, compositionIds);
  const compositions: Record<string, Composition> = {};

  for (const [id, json] of Object.entries(objects)) {
    const parsed = parseCompositionJson(json as Json);
    compositions[id] = { id, ...parsed } as Composition;
  }

  return compositions;
}

/**
 * Fetches a composition by its object ID. Convenience wrapper around getCompositionsByIds.
 */
export async function getCompositionById(
  client: ClientWithCoreApi,
  compositionId: string
): Promise<Composition> {
  const compositions = await getCompositionsByIds(client, [compositionId]);
  const composition = compositions[compositionId];
  if (!composition) throw new Error(`Composition not found: ${compositionId}`);
  return composition;
}

/**
 * Fetches a composition by its share type using GraphQL.
 *
 * Each composition has a unique share token type T. This queries for
 * the `Composition<T>` object matching the given share type.
 *
 * @param client - A Sui GraphQL client
 * @param shareType - The full share type (e.g., "0x...::share::SHARE")
 * @param musicOsPackageId - The MusicOS package ID
 * @returns The Composition object
 */
export async function getCompositionByShareType(
  client: SuiGraphQLClient,
  shareType: string,
  musicOsPackageId: string,
): Promise<Composition> {
  const compositionType = `${musicOsPackageId}::composition::Composition<${shareType}>`;

  const result = await client.query({
    query: ObjectsByTypeQuery,
    variables: { type: compositionType },
  });

  const nodes = (result.data as { objects?: { nodes?: Array<{ address: string; asMoveObject?: { contents?: { json?: unknown } } }> } })?.objects?.nodes;
  const node = nodes?.[0];
  const json = node?.asMoveObject?.contents?.json;
  if (!json || !node?.address) {
    throw new Error(`Composition not found for share type: ${shareType}`);
  }

  const parsed = parseCompositionJson(json as Json);
  return { id: node.address, ...parsed } as Composition;
}

/**
 * Fetches a CompositionAdminCap by its object ID using Core API.
 *
 * Extracts the share type parameter T from the on-chain type
 * `CompositionAdminCap<T>`.
 *
 * @param client - A Sui client with Core API
 * @param adminCapId - The object ID of the CompositionAdminCap
 * @returns The CompositionAdminCap with its share type
 */
export async function getCompositionAdminCapById(
  client: ClientWithCoreApi,
  adminCapId: string,
): Promise<CompositionAdminCap> {
  const { object } = await client.core.getObject({ objectId: adminCapId });
  return { id: adminCapId, shareType: extractTypeParam(object.type) };
}

/**
 * Fetches a CompositionAdminCap by its share type using GraphQL.
 *
 * Queries for the `CompositionAdminCap<T>` object matching the given
 * share type. There is exactly one admin cap per composition.
 *
 * @param client - A Sui GraphQL client
 * @param shareType - The full share type (e.g., "0x...::share::SHARE")
 * @param musicOsPackageId - The MusicOS package ID
 * @returns The CompositionAdminCap with its share type
 */
export async function getCompositionAdminCapByShareType(
  client: SuiGraphQLClient,
  shareType: string,
  musicOsPackageId: string,
): Promise<CompositionAdminCap> {
  const capType = `${musicOsPackageId}::composition::CompositionAdminCap<${shareType}>`;

  const result = await client.query({
    query: ObjectsByTypeQuery,
    variables: { type: capType },
  });

  const nodes = (result.data as { objects?: { nodes?: Array<{ address: string }> } })?.objects?.nodes;
  const node = nodes?.[0];
  if (!node?.address) {
    throw new Error(`CompositionAdminCap not found for share type: ${shareType}`);
  }

  return { id: node.address, shareType };
}

/**
 * Fetches all CompositionAdminCaps owned by an address.
 *
 * Uses GraphQL because CompositionAdminCap is always generic and Core API
 * `listOwnedObjects` does not support partial generic type matching.
 *
 * @param client - A Sui GraphQL client
 * @param owner - The address to scan for admin caps
 * @param musicOsPackageId - The MusicOS package ID
 * @returns Array of CompositionAdminCap objects owned by the address
 */
export async function getOwnedCompositionAdminCaps(
  client: SuiGraphQLClient,
  owner: string,
  musicOsPackageId: string,
): Promise<CompositionAdminCap[]> {
  const capType = `${musicOsPackageId}::composition::CompositionAdminCap`;
  const result = await client.listOwnedObjects({ owner, type: capType });

  const caps: CompositionAdminCap[] = [];
  for (const obj of result.objects) {
    const match = obj.type?.match(/<(.+)>$/);
    if (match?.[1]) {
      caps.push({
        id: obj.objectId,
        shareType: match[1],
      });
    }
  }

  return caps;
}

/**
 * Derives the CompositionAdminCap object ID from a Composition object ID.
 *
 * The admin cap is a derived object using `CompositionAdminCapKey` as the
 * derivation key. This is a pure function — no network calls required.
 *
 * @param compositionId - The Composition object ID
 * @param musicOsPackageId - The MusicOS package ID
 * @returns The derived CompositionAdminCap object ID
 */
export function deriveCompositionAdminCapId(
  compositionId: string,
  musicOsPackageId: string,
): string {
  const keyType = `${musicOsPackageId}::composition::CompositionAdminCapKey`;
  return deriveObjectID(compositionId, keyType, UNIT_STRUCT_KEY_BYTES);
}

/**
 * Fetches a recording by its share type using GraphQL.
 *
 * Each recording has a unique share token type T. This queries for
 * the `Recording<T>` object matching the given share type.
 *
 * @param client - A Sui GraphQL client
 * @param shareType - The full share type (e.g., "0x...::share::SHARE")
 * @param musicOsPackageId - The MusicOS package ID
 * @returns The Recording object
 */
export async function getRecordingByShareType(
  client: SuiGraphQLClient,
  shareType: string,
  musicOsPackageId: string,
): Promise<Recording> {
  const recordingType = `${musicOsPackageId}::recording::Recording<${shareType}>`;

  const result = await client.query({
    query: ObjectsByTypeQuery,
    variables: { type: recordingType },
  });

  const nodes = (result.data as { objects?: { nodes?: Array<{ address: string; asMoveObject?: { contents?: { json?: unknown } } }> } })?.objects?.nodes;
  const node = nodes?.[0];
  const json = node?.asMoveObject?.contents?.json;
  if (!json || !node?.address) {
    throw new Error(`Recording not found for share type: ${shareType}`);
  }

  const parsed = parseRecordingJson(json as Json);
  return { id: node.address, ...parsed } as Recording;
}

/**
 * Fetches a RecordingAdminCap by its object ID using Core API.
 *
 * Extracts the share type parameter T from the on-chain type
 * `RecordingAdminCap<T>`.
 *
 * @param client - A Sui client with Core API
 * @param adminCapId - The object ID of the RecordingAdminCap
 * @returns The RecordingAdminCap with its share type
 */
export async function getRecordingAdminCapById(
  client: ClientWithCoreApi,
  adminCapId: string,
): Promise<RecordingAdminCap> {
  const { object } = await client.core.getObject({ objectId: adminCapId });
  return { id: adminCapId, shareType: extractTypeParam(object.type) };
}

/**
 * Fetches a RecordingAdminCap by its share type using GraphQL.
 *
 * Queries for the `RecordingAdminCap<T>` object matching the given
 * share type. There is exactly one admin cap per recording.
 *
 * @param client - A Sui GraphQL client
 * @param shareType - The full share type (e.g., "0x...::share::SHARE")
 * @param musicOsPackageId - The MusicOS package ID
 * @returns The RecordingAdminCap with its share type
 */
export async function getRecordingAdminCapByShareType(
  client: SuiGraphQLClient,
  shareType: string,
  musicOsPackageId: string,
): Promise<RecordingAdminCap> {
  const capType = `${musicOsPackageId}::recording::RecordingAdminCap<${shareType}>`;

  const result = await client.query({
    query: ObjectsByTypeQuery,
    variables: { type: capType },
  });

  const nodes = (result.data as { objects?: { nodes?: Array<{ address: string }> } })?.objects?.nodes;
  const node = nodes?.[0];
  if (!node?.address) {
    throw new Error(`RecordingAdminCap not found for share type: ${shareType}`);
  }

  return { id: node.address, shareType };
}

/**
 * Fetches all RecordingAdminCaps owned by an address.
 *
 * Uses GraphQL because RecordingAdminCap is always generic and Core API
 * `listOwnedObjects` does not support partial generic type matching.
 *
 * @param client - A Sui GraphQL client
 * @param owner - The address to scan for admin caps
 * @param musicOsPackageId - The MusicOS package ID
 * @returns Array of RecordingAdminCap objects owned by the address
 */
export async function getOwnedRecordingAdminCaps(
  client: SuiGraphQLClient,
  owner: string,
  musicOsPackageId: string,
): Promise<RecordingAdminCap[]> {
  const capType = `${musicOsPackageId}::recording::RecordingAdminCap`;
  const result = await client.listOwnedObjects({ owner, type: capType });

  const caps: RecordingAdminCap[] = [];
  for (const obj of result.objects) {
    const match = obj.type?.match(/<(.+)>$/);
    if (match?.[1]) {
      caps.push({
        id: obj.objectId,
        shareType: match[1],
      });
    }
  }

  return caps;
}

/**
 * Derives the RecordingAdminCap object ID from a Recording object ID.
 *
 * The admin cap is a derived object using `RecordingAdminCapKey` as the
 * derivation key. This is a pure function — no network calls required.
 *
 * @param recordingId - The Recording object ID
 * @param musicOsPackageId - The MusicOS package ID
 * @returns The derived RecordingAdminCap object ID
 */
export function deriveRecordingAdminCapId(
  recordingId: string,
  musicOsPackageId: string,
): string {
  const keyType = `${musicOsPackageId}::recording::RecordingAdminCapKey`;
  return deriveObjectID(recordingId, keyType, UNIT_STRUCT_KEY_BYTES);
}

/**
 * @deprecated Use getRecordingById with Core API client instead.
 * Fetches a recording by its object ID using GraphQL.
 */
export async function getRecordingGraphQL(
  client: SuiGraphQLClient,
  recordingId: string
): Promise<Recording> {
  const result = await client.query({
    query: ObjectQuery,
    variables: { address: recordingId },
  });

  const json = result.data?.object?.asMoveObject?.contents?.json;
  if (!json) {
    throw new Error(`Recording not found: ${recordingId}`);
  }

  const parsed = parseRecordingJson(json as Json);
  return { id: recordingId, ...parsed } as Recording;
}

/**
 * Fetches multiple objects by their IDs in a single request using Core API.
 *
 * @param client - A Sui client with Core API (SuiGrpcClient or similar)
 * @param objectIds - Array of object IDs to fetch
 * @returns Map of object ID to its JSON contents
 */
export async function getObjects(
  client: ClientWithCoreApi,
  objectIds: string[]
): Promise<Record<string, unknown>> {
  if (objectIds.length === 0) {
    return {};
  }

  const { objects: results } = await client.core.getObjects({ objectIds, include: { json: true } });

  const objects: Record<string, unknown> = {};
  for (const obj of results) {
    if (obj instanceof Error) continue;
    if (obj.json) {
      objects[obj.objectId] = obj.json;
    }
  }

  return objects;
}

/**
 * @deprecated Use getObjects with Core API client instead.
 * Fetches multiple objects by their IDs in a single request using GraphQL.
 */
export async function getObjectsGraphQL(
  client: SuiGraphQLClient,
  objectIds: string[]
): Promise<Record<string, unknown>> {
  if (objectIds.length === 0) {
    return {};
  }

  const result = await client.query({
    query: MultiObjectQuery,
    variables: { ids: objectIds },
  });

  const objects: Record<string, unknown> = {};
  for (const node of result.data?.objects?.nodes ?? []) {
    const json = node.asMoveObject?.contents?.json;
    if (json && node.address) {
      objects[node.address] = json;
    }
  }

  return objects;
}

/**
 * Fetches multiple recordings by their IDs in a single request using Core API.
 *
 * @param client - A Sui client with Core API (SuiGrpcClient or similar)
 * @param recordingIds - Array of recording object IDs
 * @returns Map of recording ID to Recording object
 */
export async function getRecordingsByIds(
  client: ClientWithCoreApi,
  recordingIds: string[]
): Promise<Record<string, Recording>> {
  const objects = await getObjects(client, recordingIds);
  const recordings: Record<string, Recording> = {};

  for (const [id, json] of Object.entries(objects)) {
    const parsed = parseRecordingJson(json as Json);
    recordings[id] = { id, ...parsed } as Recording;
  }

  return recordings;
}


// ============================================================================
// Composition Share Type
// ============================================================================

/**
 * Extracts the share type from a Composition object.
 *
 * Given a Composition<T> object ID, fetches the object and extracts the type parameter T.
 *
 * @param client - A Sui client with Core API
 * @param compositionId - The object ID of the Composition object
 * @returns The full share type string (e.g., "0x...::share::SHARE")
 */
export async function getCompositionShareType(
  client: ClientWithCoreApi,
  compositionId: string
): Promise<string> {
  const { object } = await client.core.getObject({ objectId: compositionId });
  return extractTypeParam(object.type);
}

// ============================================================================
// Admin Cap Resolution
// ============================================================================

/** Key bytes for Move unit structs (single 0x00 for the dummy_field: bool = false). */
const UNIT_STRUCT_KEY_BYTES = new Uint8Array([0x00]);

// ============================================================================
// Administered Recording Queries
// ============================================================================


/**
 * Fetches all Recordings administered by an address.
 *
 * Discovers recordings by finding `RecordingAdminCap<T>` objects owned
 * by the address, extracting the share type `T` from each cap's type, then
 * querying for the corresponding `Recording<T>` objects.
 *
 * @param client - A Sui GraphQL client
 * @param owner - The address to scan for admin caps
 * @param musicOsPackageId - The MusicOS package ID
 * @returns Array of Recording objects the address administers
 */
export async function getAdministeredRecordings(
  client: SuiGraphQLClient,
  owner: string,
  musicOsPackageId: string,
): Promise<Recording[]> {
  const capType = `${musicOsPackageId}::recording::RecordingAdminCap`;
  const result = await client.listOwnedObjects({ owner, type: capType });

  // Extract share type T from each RecordingAdminCap<T>
  const shareTypes: string[] = [];
  for (const obj of result.objects) {
    const match = obj.type?.match(/<(.+)>$/);
    if (match?.[1]) shareTypes.push(match[1]);
  }

  if (shareTypes.length === 0) return [];

  // For each share type, find the Recording<T> shared object
  const recordings: Recording[] = [];
  for (const shareType of shareTypes) {
    const recordingType = `${musicOsPackageId}::recording::Recording<${shareType}>`;
    const queryResult = await client.query({
      query: ObjectsByTypeQuery,
      variables: { type: recordingType },
    });

    for (const node of queryResult.data?.objects?.nodes ?? []) {
      const json = node.asMoveObject?.contents?.json;
      if (!json || !node.address) continue;
      const parsed = parseRecordingJson(json as Json);
      recordings.push({ id: node.address, ...parsed } as Recording);
    }
  }

  return recordings;
}

// ============================================================================
// Release Admin Cap
// ============================================================================

/**
 * Derives the ReleaseAdminCap object ID from a Release object ID.
 *
 * The admin cap is a derived object using `ReleaseAdminCapKey` as the
 * derivation key. This is a pure function — no network calls required.
 *
 * @param releaseId - The Release object ID
 * @param musicOsPackageId - The MusicOS package ID
 * @returns The derived ReleaseAdminCap object ID
 */
export function deriveReleaseAdminCapId(
  releaseId: string,
  musicOsPackageId: string,
): string {
  const keyType = `${musicOsPackageId}::release::ReleaseAdminCapKey`;
  return deriveObjectID(releaseId, keyType, UNIT_STRUCT_KEY_BYTES);
}

/**
 * Fetches a ReleaseAdminCap by its object ID using Core API.
 *
 * Unlike Composition and Recording admin caps, ReleaseAdminCap is not generic
 * and stores a `release_id` field referencing the administered Release.
 *
 * @param client - A Sui client with Core API
 * @param adminCapId - The object ID of the ReleaseAdminCap
 * @returns The ReleaseAdminCap with its release ID
 */
export async function getReleaseAdminCapById(
  client: ClientWithCoreApi,
  adminCapId: string,
): Promise<ReleaseAdminCap> {
  const { object } = await client.core.getObject({ objectId: adminCapId, include: { json: true } });
  const json = object.json as { release_id: string } | null;
  if (!json?.release_id) throw new Error(`ReleaseAdminCap not found: ${adminCapId}`);

  return { id: adminCapId, releaseId: json.release_id };
}

/**
 * Fetches all ReleaseAdminCaps owned by an address.
 *
 * Uses Core API because ReleaseAdminCap is not generic (unlike Composition
 * and Recording admin caps), so `listOwnedObjects` can match the exact type.
 *
 * @param client - A Sui client with Core API
 * @param owner - The address to scan for admin caps
 * @param musicOsPackageId - The MusicOS package ID
 * @returns Array of ReleaseAdminCap objects owned by the address
 */
export async function getOwnedReleaseAdminCaps(
  client: ClientWithCoreApi,
  owner: string,
  musicOsPackageId: string,
): Promise<ReleaseAdminCap[]> {
  const capType = `${musicOsPackageId}::release::ReleaseAdminCap`;
  const { objects } = await client.core.listOwnedObjects({ owner, type: capType });

  if (objects.length === 0) return [];

  const objectIds = objects.map((obj) => obj.objectId);
  const { objects: details } = await client.core.getObjects({ objectIds, include: { json: true } });

  const caps: ReleaseAdminCap[] = [];
  for (const obj of details) {
    if (obj instanceof Error) continue;
    const json = obj.json as { release_id: string } | null;
    if (json?.release_id) {
      caps.push({ id: obj.objectId, releaseId: json.release_id });
    }
  }

  return caps;
}

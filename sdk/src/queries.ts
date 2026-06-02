// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

// Object reads. Single-object fetches use the Core API with `include: content`
// and parse the BCS contents through the codegen-generated structs (so parsing
// tracks the on-chain ABI). Generic-type discovery (by share type / by owner)
// uses GraphQL to find object addresses, then reads them through the Core path.

import type { ClientWithCoreApi } from "@mysten/sui/client";
import type { SuiGraphQLClient } from "@mysten/sui/graphql";
import { graphql } from "@mysten/sui/graphql/schema";
import { deriveObjectID } from "@mysten/sui/utils";

import { Composition as CompositionBcs } from "./contracts/musicos/composition.ts";
import { Recording as RecordingBcs } from "./contracts/musicos/recording.ts";
import { Release as ReleaseBcs } from "./contracts/musicos/release.ts";
import { mapComposition, mapRecording, mapRelease, mapParty } from "./internal.ts";
import type {
  Composition,
  CompositionAdminCap,
  Party,
  Recording,
  RecordingAdminCap,
  Release,
  ReleaseAdminCap,
} from "./types.ts";

// ============================================================================
// Helpers
// ============================================================================

/** Extracts the type parameter `T` from `package::module::Type<T>`. */
function extractTypeParam(objectType: string): string {
  const match = objectType.match(/<(.+)>$/);
  if (!match?.[1]) throw new Error(`Could not extract type parameter from: ${objectType}`);
  return match[1];
}

/** Key bytes for Move unit structs (single `0x00` for `dummy_field: bool = false`). */
const UNIT_STRUCT_KEY_BYTES = new Uint8Array([0x00]);

/** Fetches one object's BCS content bytes (or null if absent). */
async function getContent(client: ClientWithCoreApi, objectId: string): Promise<Uint8Array | null> {
  const { object } = await client.core.getObject({ objectId, include: { content: true } });
  return object.content ?? null;
}

// ============================================================================
// GraphQL discovery queries
// ============================================================================

/** Object addresses matching a fully-qualified type. */
const AddressesByTypeQuery = graphql(`
  query AddressesByType($type: String!) {
    objects(filter: { type: $type }) {
      nodes { address }
    }
  }
`);

// ============================================================================
// Composition
// ============================================================================

/** Fetches multiple compositions by ID in one Core request. */
export async function getCompositionsByIds(
  client: ClientWithCoreApi,
  compositionIds: string[],
): Promise<Record<string, Composition>> {
  if (compositionIds.length === 0) return {};
  const { objects } = await client.core.getObjects({ objectIds: compositionIds, include: { content: true } });
  const out: Record<string, Composition> = {};
  for (const obj of objects) {
    if (obj instanceof Error || !obj.content) continue;
    out[obj.objectId] = mapComposition(obj.objectId, CompositionBcs.parse(obj.content));
  }
  return out;
}

/** Fetches a composition by its object ID. */
export async function getCompositionById(client: ClientWithCoreApi, compositionId: string): Promise<Composition> {
  const content = await getContent(client, compositionId);
  if (!content) throw new Error(`Composition not found: ${compositionId}`);
  return mapComposition(compositionId, CompositionBcs.parse(content));
}

/** Extracts the share type `T` from a `Composition<T>` object. */
export async function getCompositionShareType(client: ClientWithCoreApi, compositionId: string): Promise<string> {
  const { object } = await client.core.getObject({ objectId: compositionId });
  return extractTypeParam(object.type);
}

/** Fetches a composition by its share type (GraphQL discovery + Core read). */
export async function getCompositionByShareType(
  client: ClientWithCoreApi,
  graphqlClient: SuiGraphQLClient,
  shareType: string,
  musicOsPackageId: string,
): Promise<Composition> {
  const type = `${musicOsPackageId}::composition::Composition<${shareType}>`;
  const address = await firstAddressOfType(graphqlClient, type);
  if (!address) throw new Error(`Composition not found for share type: ${shareType}`);
  return getCompositionById(client, address);
}

export async function getCompositionAdminCapById(
  client: ClientWithCoreApi,
  adminCapId: string,
): Promise<CompositionAdminCap> {
  const { object } = await client.core.getObject({ objectId: adminCapId });
  return { id: adminCapId, shareType: extractTypeParam(object.type) };
}

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
    if (match?.[1]) caps.push({ id: obj.objectId, shareType: match[1] });
  }
  return caps;
}

export function deriveCompositionAdminCapId(compositionId: string, musicOsPackageId: string): string {
  return deriveObjectID(compositionId, `${musicOsPackageId}::composition::CompositionAdminCapKey`, UNIT_STRUCT_KEY_BYTES);
}

// ============================================================================
// Recording
// ============================================================================

export async function getRecordingsByIds(
  client: ClientWithCoreApi,
  recordingIds: string[],
): Promise<Record<string, Recording>> {
  if (recordingIds.length === 0) return {};
  const { objects } = await client.core.getObjects({ objectIds: recordingIds, include: { content: true } });
  const out: Record<string, Recording> = {};
  for (const obj of objects) {
    if (obj instanceof Error || !obj.content) continue;
    out[obj.objectId] = mapRecording(obj.objectId, RecordingBcs.parse(obj.content));
  }
  return out;
}

export async function getRecordingById(client: ClientWithCoreApi, recordingId: string): Promise<Recording> {
  const content = await getContent(client, recordingId);
  if (!content) throw new Error(`Recording not found: ${recordingId}`);
  return mapRecording(recordingId, RecordingBcs.parse(content));
}

export async function getRecordingShareType(client: ClientWithCoreApi, recordingId: string): Promise<string> {
  const { object } = await client.core.getObject({ objectId: recordingId });
  return extractTypeParam(object.type);
}

export async function getRecordingByShareType(
  client: ClientWithCoreApi,
  graphqlClient: SuiGraphQLClient,
  shareType: string,
  musicOsPackageId: string,
): Promise<Recording> {
  const type = `${musicOsPackageId}::recording::Recording<${shareType}>`;
  const address = await firstAddressOfType(graphqlClient, type);
  if (!address) throw new Error(`Recording not found for share type: ${shareType}`);
  return getRecordingById(client, address);
}

export async function getRecordingAdminCapById(
  client: ClientWithCoreApi,
  adminCapId: string,
): Promise<RecordingAdminCap> {
  const { object } = await client.core.getObject({ objectId: adminCapId });
  return { id: adminCapId, shareType: extractTypeParam(object.type) };
}

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
    if (match?.[1]) caps.push({ id: obj.objectId, shareType: match[1] });
  }
  return caps;
}

export function deriveRecordingAdminCapId(recordingId: string, musicOsPackageId: string): string {
  return deriveObjectID(recordingId, `${musicOsPackageId}::recording::RecordingAdminCapKey`, UNIT_STRUCT_KEY_BYTES);
}

/** Recordings administered by `owner` (admin-cap discovery -> Core read). */
export async function getAdministeredRecordings(
  client: ClientWithCoreApi,
  graphqlClient: SuiGraphQLClient,
  owner: string,
  musicOsPackageId: string,
): Promise<Recording[]> {
  const caps = await getOwnedRecordingAdminCaps(graphqlClient, owner, musicOsPackageId);
  const recordings: Recording[] = [];
  for (const cap of caps) {
    const type = `${musicOsPackageId}::recording::Recording<${cap.shareType}>`;
    const address = await firstAddressOfType(graphqlClient, type);
    if (address) recordings.push(await getRecordingById(client, address));
  }
  return recordings;
}

// ============================================================================
// Release
// ============================================================================

export async function getReleasesByIds(
  client: ClientWithCoreApi,
  releaseIds: string[],
): Promise<Record<string, Release>> {
  if (releaseIds.length === 0) return {};
  const { objects } = await client.core.getObjects({ objectIds: releaseIds, include: { content: true } });
  const out: Record<string, Release> = {};
  for (const obj of objects) {
    if (obj instanceof Error || !obj.content) continue;
    out[obj.objectId] = mapRelease(obj.objectId, ReleaseBcs.parse(obj.content));
  }
  return out;
}

export async function getReleaseById(client: ClientWithCoreApi, releaseId: string): Promise<Release> {
  const content = await getContent(client, releaseId);
  if (!content) throw new Error(`Release not found: ${releaseId}`);
  return mapRelease(releaseId, ReleaseBcs.parse(content));
}

export async function getReleaseRegistry(client: SuiGraphQLClient, musicOsPackageId: string): Promise<string> {
  const address = await firstAddressOfType(client, `${musicOsPackageId}::release::ReleaseRegistry`);
  if (!address) throw new Error("ReleaseRegistry not found");
  return address;
}

export async function getReleaseAdminCapById(
  client: ClientWithCoreApi,
  adminCapId: string,
): Promise<ReleaseAdminCap> {
  const { object } = await client.core.getObject({ objectId: adminCapId, include: { json: true } });
  const json = object.json as { release_id: string } | null;
  if (!json?.release_id) throw new Error(`ReleaseAdminCap not found: ${adminCapId}`);
  return { id: adminCapId, releaseId: json.release_id };
}

export async function getOwnedReleaseAdminCaps(
  client: ClientWithCoreApi,
  owner: string,
  musicOsPackageId: string,
): Promise<ReleaseAdminCap[]> {
  const capType = `${musicOsPackageId}::release::ReleaseAdminCap`;
  const { objects } = await client.core.listOwnedObjects({ owner, type: capType });
  if (objects.length === 0) return [];
  const { objects: details } = await client.core.getObjects({
    objectIds: objects.map((o) => o.objectId),
    include: { json: true },
  });
  const caps: ReleaseAdminCap[] = [];
  for (const obj of details) {
    if (obj instanceof Error) continue;
    const json = obj.json as { release_id: string } | null;
    if (json?.release_id) caps.push({ id: obj.objectId, releaseId: json.release_id });
  }
  return caps;
}

export function deriveReleaseAdminCapId(releaseId: string, musicOsPackageId: string): string {
  return deriveObjectID(releaseId, `${musicOsPackageId}::release::ReleaseAdminCapKey`, UNIT_STRUCT_KEY_BYTES);
}

// ============================================================================
// Party & Share Currency
// ============================================================================

export async function getParty(client: ClientWithCoreApi, partyId: string): Promise<Party> {
  const { object } = await client.core.getObject({ objectId: partyId, include: { json: true } });
  if (!object.json) throw new Error(`Party not found: ${partyId}`);
  return mapParty(partyId, object.json);
}

/** Extracts the share type `T` from a `Currency<T>` object. */
export async function getShareCurrencyType(client: ClientWithCoreApi, shareCurrencyId: string): Promise<string> {
  const { object } = await client.core.getObject({ objectId: shareCurrencyId });
  return extractTypeParam(object.type);
}

/** Finds the `TreasuryCap` for a share currency owned by `owner`. */
export async function getShareCurrencyTreasuryCap(
  client: ClientWithCoreApi,
  shareCurrencyId: string,
  owner: string,
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

// ============================================================================
// Private
// ============================================================================

/** Returns the first object address of a fully-qualified type, or null. */
async function firstAddressOfType(client: SuiGraphQLClient, type: string): Promise<string | null> {
  const result = await client.query({ query: AddressesByTypeQuery, variables: { type } });
  return result.data?.objects?.nodes?.[0]?.address ?? null;
}

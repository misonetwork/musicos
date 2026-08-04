// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

// Object reads. Single-object fetches use the Core API with `include: content`
// and parse the BCS contents through the codegen-generated structs (so parsing
// tracks the on-chain ABI). Generic-type discovery (by share type / by owner)
// uses GraphQL to find object addresses, then reads them through the Core path.
//
// Missing-object convention (null vs throw):
//   - Core-object getters in this module (`getCompositionById`, `getDealById`,
//     `get*AdminCapById`, …) THROW when the object is missing. Callers pass ids
//     they obtained from the chain, so a miss means a broken reference — an
//     exceptional state, not a normal one.
//   - Extension dynamic-field readers (`getCompositionCredits`/`getRecordingCredits`/
//     `getReleaseCredits` in ./credits.ts, `getReleaseCover` in ./cover.ts) return
//     `null` — extension data is optional by design, and "not attached" is a
//     normal, expected state.
//   - `getDrop` (./drop.ts) is a deliberate null-returning EXCEPTION to
//     the core-getter rule: consumers probe pasted/stored drop ids and treat
//     absence as a normal state. See its doc comment.
// All null-returning readers use {@link isNotFound} to distinguish a missing
// object from a transport failure (which still throws).

import type { ClientWithCoreApi } from "@mysten/sui/client";
import type { SuiGraphQLClient } from "@mysten/sui/graphql";
import { graphql } from "@mysten/sui/graphql/schema";
import { deriveObjectID } from "@mysten/sui/utils";

import { Composition as CompositionBcs } from "./contracts/miso/composition.ts";
import { Deal as DealBcs } from "./contracts/miso/deal.ts";
import { Recording as RecordingBcs } from "./contracts/miso/recording.ts";
import { Release as ReleaseBcs } from "./contracts/miso/release.ts";
import { mapBps, mapComposition, mapRecording, mapRelease } from "./internal.ts";
import type {
  Composition,
  CompositionAdminCap,
  Deal,
  Recording,
  RecordingAdminCap,
  Release,
  ReleaseAdminCap,
} from "./types.ts";

// ============================================================================
// Helpers
// ============================================================================

/**
 * Extracts the type parameter `T` from `package::module::Type<T>`. For multi-
 * parameter types this returns everything between the outer angle brackets —
 * use {@link extractTypeParams2} to split two top-level parameters.
 */
export function extractTypeParam(objectType: string): string {
  const match = objectType.match(/<(.+)>$/);
  if (!match?.[1]) throw new Error(`Could not extract type parameter from: ${objectType}`);
  return match[1];
}

/** Splits the two top-level type parameters of `pkg::mod::Type<A, B>`. */
export function extractTypeParams2(objectType: string): [string, string] {
  const inner = extractTypeParam(objectType);
  let depth = 0;
  for (let i = 0; i < inner.length; i++) {
    const ch = inner[i];
    if (ch === "<") depth++;
    else if (ch === ">") depth--;
    else if (ch === "," && depth === 0) return [inner.slice(0, i).trim(), inner.slice(i + 1).trim()];
  }
  throw new Error(`Expected two type parameters in: ${objectType}`);
}

/**
 * True when `e` is a "this object does not exist" error from any of the Sui
 * client transports, so null-returning readers can distinguish absence from
 * transport failure. Matches, in order of preference:
 *
 *   1. Structured `ObjectError.code` values thrown by the JSON-RPC core client
 *      (`notExists`, `deleted`, `dynamicFieldNotFound`) and the GraphQL core
 *      client (`notFound`). The class itself is not exported by `@mysten/sui`,
 *      so we duck-type on `code`.
 *   2. The message shapes those clients (and the gRPC core client, which wraps
 *      the server's per-object status message in a plain `Error`) produce:
 *      "Object 0x… does not exist" / "Object 0x… not found" / "Object 0x… has
 *      been deleted" / "Dynamic field not found for object 0x…" / "No object
 *      found for id 0x…".
 *
 * Transport/protocol errors must NOT match: every message pattern requires
 * object-ish context ("object" / "dynamic field"), so e.g. a JSON-RPC
 * "Method not found" or a gRPC "peer not found" is never treated as a missing
 * object and propagates to the caller.
 */
export function isNotFound(e: unknown): boolean {
  if (typeof e === "object" && e !== null && "code" in e) {
    const code = (e as { code: unknown }).code;
    if (code === "notExists" || code === "deleted" || code === "dynamicFieldNotFound" || code === "notFound") {
      return true;
    }
  }
  const msg = e instanceof Error ? e.message : String(e);
  return (
    /\bobject\b[\s\S]*\b(?:not\s?found|does not exist|has been deleted)\b/i.test(msg) ||
    /\bdynamic field\b[\s\S]*\bnot\s?found\b/i.test(msg) ||
    /\bno object\b/i.test(msg)
  );
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
  misoPackageId: string,
): Promise<Composition> {
  const type = `${misoPackageId}::composition::Composition<${shareType}>`;
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
  misoPackageId: string,
): Promise<CompositionAdminCap[]> {
  const capType = `${misoPackageId}::composition::CompositionAdminCap`;
  const result = await client.listOwnedObjects({ owner, type: capType });
  const caps: CompositionAdminCap[] = [];
  for (const obj of result.objects) {
    const match = obj.type?.match(/<(.+)>$/);
    if (match?.[1]) caps.push({ id: obj.objectId, shareType: match[1] });
  }
  return caps;
}

export function deriveCompositionAdminCapId(compositionId: string, misoPackageId: string): string {
  return deriveObjectID(compositionId, `${misoPackageId}::composition::CompositionAdminCapKey`, UNIT_STRUCT_KEY_BYTES);
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
  misoPackageId: string,
): Promise<Recording> {
  const type = `${misoPackageId}::recording::Recording<${shareType}>`;
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
  misoPackageId: string,
): Promise<RecordingAdminCap[]> {
  const capType = `${misoPackageId}::recording::RecordingAdminCap`;
  const result = await client.listOwnedObjects({ owner, type: capType });
  const caps: RecordingAdminCap[] = [];
  for (const obj of result.objects) {
    const match = obj.type?.match(/<(.+)>$/);
    if (match?.[1]) caps.push({ id: obj.objectId, shareType: match[1] });
  }
  return caps;
}

export function deriveRecordingAdminCapId(recordingId: string, misoPackageId: string): string {
  return deriveObjectID(recordingId, `${misoPackageId}::recording::RecordingAdminCapKey`, UNIT_STRUCT_KEY_BYTES);
}

// ============================================================================
// Deal
// ============================================================================

/** Fetches a deal by its object ID (share types read from the type parameters). */
export async function getDealById(client: ClientWithCoreApi, dealId: string): Promise<Deal> {
  const { object } = await client.core.getObject({ objectId: dealId, include: { content: true } });
  if (!object.content) throw new Error(`Deal not found: ${dealId}`);
  const d = DealBcs.parse(object.content);
  const [recordingShareType, compositionShareType] = extractTypeParams2(object.type);
  return {
    id: dealId,
    releaseId: d.release_id,
    trackSplitBps: mapBps(d.track_split_bps),
    recordingShareType,
    compositionShareType,
  };
}

/** Recordings administered by `owner` (admin-cap discovery -> Core read). */
export async function getAdministeredRecordings(
  client: ClientWithCoreApi,
  graphqlClient: SuiGraphQLClient,
  owner: string,
  misoPackageId: string,
): Promise<Recording[]> {
  const caps = await getOwnedRecordingAdminCaps(graphqlClient, owner, misoPackageId);
  const recordings: Recording[] = [];
  for (const cap of caps) {
    const type = `${misoPackageId}::recording::Recording<${cap.shareType}>`;
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

export async function getReleaseRegistry(client: SuiGraphQLClient, misoPackageId: string): Promise<string> {
  const address = await firstAddressOfType(client, `${misoPackageId}::release::ReleaseRegistry`);
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
  misoPackageId: string,
): Promise<ReleaseAdminCap[]> {
  const capType = `${misoPackageId}::release::ReleaseAdminCap`;
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

export function deriveReleaseAdminCapId(releaseId: string, misoPackageId: string): string {
  return deriveObjectID(releaseId, `${misoPackageId}::release::ReleaseAdminCapKey`, UNIT_STRUCT_KEY_BYTES);
}

// ============================================================================
// Share Currency
// ============================================================================

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

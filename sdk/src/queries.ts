// Copyright (c) Unconfirmed Labs, LLC
// SPDX-License-Identifier: Apache-2.0

import type { SuiGrpcClient } from "@mysten/sui/grpc";
import type { SuiGraphQLClient } from "@mysten/sui/graphql";
import { graphql } from "@mysten/sui/graphql/schema";
import type { Release, Recording } from "./types.ts";

// Minimal client interface for Core API operations
interface SuiClientLike {
  getObject(params: {
    objectId: string;
    include?: { json?: boolean };
  }): Promise<{
    object?: {
      type?: string;
      json?: Record<string, unknown>;
    };
  }>;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  getObjects(params: { objectIds: string[]; include?: { json?: boolean } }): Promise<{ objects: any[] }>;
}

/** Represents a Genre object from MusicOS. */
export interface Genre {
  /** The object ID of the genre. */
  id: string;
  /** The name of the genre. */
  name: string;
}

const GenresQuery = graphql(`
  query GetGenres($type: String!) {
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

/**
 * Fetches all genres from the MusicOS protocol.
 *
 * @param client - A Sui GraphQL client
 * @param musicOsPackageId - The MusicOS package ID
 * @returns Array of genres with their IDs and names
 */
export async function getGenres(
  client: SuiGraphQLClient,
  musicOsPackageId: string
): Promise<Genre[]> {
  const genreType = `${musicOsPackageId}::genre::Genre`;

  const result = await client.query({
    query: GenresQuery,
    variables: { type: genreType },
  });

  const genres: Genre[] = [];
  for (const node of result.data?.objects?.nodes ?? []) {
    const json = node.asMoveObject?.contents?.json as { name: string } | undefined;
    if (json?.name && node.address) {
      genres.push({
        id: node.address,
        name: json.name,
      });
    }
  }

  return genres.sort((a, b) => a.name.localeCompare(b.name));
}

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
  client: SuiGrpcClient,
  shareCurrencyId: string
): Promise<string> {
  const result = await client.getObject({ objectId: shareCurrencyId });

  const objectType = result.object.type;

  // Type looks like: "0x2::coin_registry::Currency<0x...::share::SHARE>"
  // Extract the type parameter between < and >
  const match = objectType.match(/<(.+)>$/);

  if (!match || !match[1]) {
    throw new Error(`Could not extract share type from: ${objectType}`);
  }

  return match[1];
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
  client: SuiGrpcClient,
  shareCurrencyId: string,
  owner: string
): Promise<string> {
  const shareCurrencyType = await getShareCurrencyType(client, shareCurrencyId);
  const result = await client.listOwnedObjects({
    owner,
    type: `0x2::coin::TreasuryCap<${shareCurrencyType}>`,
  });

  if (result.objects.length === 0) {
    throw new Error(`No TreasuryCap found for ${shareCurrencyType} owned by ${owner}`);
  }

  return result.objects[0]!.objectId;
}

const GenreRegistryQuery = graphql(`
  query GetGenreRegistry($type: String!) {
    objects(filter: { type: $type }) {
      nodes {
        address
      }
    }
  }
`);

/**
 * Fetches the GenreRegistry object ID.
 *
 * @param client - A Sui GraphQL client
 * @param musicOsPackageId - The MusicOS package ID
 * @returns The object ID of the GenreRegistry
 */
export async function getGenreRegistry(
  client: SuiGraphQLClient,
  musicOsPackageId: string
): Promise<string> {
  const registryType = `${musicOsPackageId}::genre::GenreRegistry`;

  const result = await client.query({
    query: GenreRegistryQuery,
    variables: { type: registryType },
  });

  const node = result.data?.objects?.nodes?.[0];
  if (!node?.address) {
    throw new Error("GenreRegistry not found");
  }

  return node.address;
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
  client: SuiGrpcClient,
  recordingId: string
): Promise<string> {
  const result = await client.getObject({ objectId: recordingId });

  const objectType = result.object?.type;
  if (!objectType) {
    throw new Error(`Recording not found: ${recordingId}`);
  }

  // Type looks like: "0x...::recording::Recording<0x...::share::Share>"
  // Extract the type parameter between < and >
  const match = objectType.match(/<(.+)>$/);

  if (!match || !match[1]) {
    throw new Error(`Could not extract share type from: ${objectType}`);
  }

  return match[1];
}

const ReleaseRegistryQuery = graphql(`
  query GetReleaseRegistry($type: String!) {
    objects(filter: { type: $type }) {
      nodes {
        address
      }
    }
  }
`);

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
    query: ReleaseRegistryQuery,
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

import { z } from "zod";

// ============================================================================
// Response Parsing Schemas
// These transform the raw JSON from GraphQL to our TypeScript types
// ============================================================================

/** Raw WalrusData from chain: tuple struct with pos0 (quiltId) and pos1 (blobId) */
const WalrusDataResponseSchema = z.object({
  pos0: z.string().nullable(),
  pos1: z.string(),
}).transform((data) => ({
  quiltId: data.pos0 ?? undefined,
  blobId: data.pos1,
}));

const CoverArtResponseSchema = z.object({
  static: WalrusDataResponseSchema,
  animated: WalrusDataResponseSchema.nullable(),
}).transform((data) => ({
  static: data.static,
  animated: data.animated ?? undefined,
}));

/** Chain enums serialize with @variant field */
const ReleaseStateResponseSchema = z.discriminatedUnion("@variant", [
  z.object({ "@variant": z.literal("Initialized") }).transform(() => ({ type: "Initialized" as const })),
  z.object({ "@variant": z.literal("Published"), pos0: z.string() }).transform((data) => ({ type: "Published" as const, timestampMs: BigInt(data.pos0) })),
]);

const ReleaseKindResponseSchema = z.object({
  "@variant": z.enum(["Album", "EP", "Single"]),
}).transform((data) => data["@variant"]);

/** BPS on chain is a tuple struct with pos0 */
const BPSResponseSchema = z.object({
  pos0: z.string(),
}).transform((data) => ({ value: parseInt(data.pos0, 10) }));

/** Track state enum */
const TrackStateResponseSchema = z.object({
  "@variant": z.enum(["Pending", "Assigned"]),
}).transform((data) => data["@variant"]);

const TrackResponseSchema = z.object({
  state: TrackStateResponseSchema,
  composition_id: z.string(),
  composition_share_type: z.object({ name: z.string() }),
  composition_split_bps: BPSResponseSchema,
  recording_id: z.string(),
  recording_share_type: z.object({ name: z.string() }),
  duration_ms: z.string(),
  cover_art: CoverArtResponseSchema,
  title: z.string(),
  split_bps: BPSResponseSchema,
}).transform((data) => ({
  state: data.state,
  compositionId: data.composition_id,
  compositionShareType: data.composition_share_type.name,
  compositionSplitBps: data.composition_split_bps,
  recordingId: data.recording_id,
  recordingShareType: data.recording_share_type.name,
  durationMs: BigInt(data.duration_ms),
  coverArt: data.cover_art,
  title: data.title,
  splitBps: data.split_bps,
}));

const DiscResponseSchema = z.object({
  tracks: z.array(TrackResponseSchema),
  artwork: CoverArtResponseSchema.nullable(),
  title: z.string().nullable(),
  duration_ms: z.string(),
}).transform((data) => ({
  tracks: data.tracks,
  artwork: data.artwork ?? undefined,
  title: data.title ?? undefined,
  durationMs: BigInt(data.duration_ms),
}));

/** Recording state enum */
const RecordingStateResponseSchema = z.discriminatedUnion("@variant", [
  z.object({ "@variant": z.literal("Initialized") }).transform(() => ({ type: "Initialized" as const })),
  z.object({ "@variant": z.literal("Published"), pos0: z.string() }).transform((data) => ({ type: "Published" as const, timestampMs: BigInt(data.pos0) })),
]);

/** Musical key - uses pos0/pos1/pos2 tuple struct */
const MusicalKeyResponseSchema = z.object({
  pos0: z.object({ "@variant": z.enum(["C", "D", "E", "F", "G", "A", "B"]) }),
  pos1: z.object({ "@variant": z.enum(["Natural", "Sharp", "Flat"]) }),
  pos2: z.object({ "@variant": z.enum(["Major", "Minor"]) }),
}).transform((data) => ({
  note: data.pos0["@variant"],
  accidental: data.pos1["@variant"],
  mode: data.pos2["@variant"],
}));

/** Time signature - uses pos0/pos1 tuple struct */
const TimeSignatureResponseSchema = z.object({
  pos0: z.number(),
  pos1: z.number(),
}).transform((data) => ({
  beatsPerMeasure: data.pos0,
  beatUnit: data.pos1,
}));

/** Audio data */
const AudioResponseSchema = z.object({
  channels: z.number(),
  bit_depth: z.number(),
  sample_rate_hz: z.number(),
  samples: z.string(),
  data: WalrusDataResponseSchema,
  pcm_digest: z.string(),
}).transform((data) => ({
  channels: data.channels,
  bitDepth: data.bit_depth,
  sampleRateHz: data.sample_rate_hz,
  samples: BigInt(data.samples),
  data: data.data,
  pcmDigest: Uint8Array.from(atob(data.pcm_digest), (c) => c.charCodeAt(0)),
}));

/** Stem */
const StemResponseSchema = z.object({
  audio: AudioResponseSchema,
  description: z.string(),
  contributors: z.array(z.string()),
}).transform((data) => ({
  audio: data.audio,
  description: data.description,
  contributors: data.contributors,
}));

/** Recording party role level */
const RecordingPartyRoleLevelSchema = z.object({
  "@variant": z.enum(["Additional", "Assistant", "Associate", "Backing", "Executive", "Featured", "Lead", "Primary", "Principal"]),
}).transform((d) => d["@variant"]);

/** Recording party role */
const RecordingPartyRoleResponseSchema = z.object({
  "@variant": z.string(),
  pos0: z.union([RecordingPartyRoleLevelSchema, z.string()]).optional(),
  pos1: RecordingPartyRoleLevelSchema.optional(),
}).transform((data) => {
  const role: { type: string; level?: string; instrument?: string } = { type: data["@variant"] };
  if (data["@variant"] === "Instrumentalist") {
    role.instrument = data.pos0 as string;
    role.level = data.pos1;
  } else if (data.pos0) {
    role.level = data.pos0 as string;
  }
  return role;
});

/** Recording credit */
const RecordingCreditResponseSchema = z.object({
  display_name: z.string(),
  roles: z.array(RecordingPartyRoleResponseSchema),
}).transform((data) => ({
  displayName: data.display_name,
  roles: data.roles,
}));

/** Credit entry in VecMap format { key, value } */
const CreditEntrySchema = z.object({
  key: z.string(),
  value: RecordingCreditResponseSchema,
});

/** Recording response schema */
const RecordingResponseSchema = z.object({
  state: RecordingStateResponseSchema,
  title: z.string(),
  title_version: z.string().nullable(),
  subtitle: z.string().nullable(),
  composition_id: z.string(),
  composition_share_type: z.object({ name: z.string() }),
  composition_split_bps: BPSResponseSchema,
  primary_genre_id: z.string(),
  secondary_genre_ids: z.object({ contents: z.array(z.string()) }),
  primary_artist_ids: z.object({ contents: z.array(z.string()) }),
  featured_artist_ids: z.object({ contents: z.array(z.string()) }),
  credits: z.object({ contents: z.array(CreditEntrySchema) }),
  language: z.object({ pos0: z.string() }).nullable(),
  is_explicit: z.boolean(),
  is_instrumental: z.boolean(),
  lyrics: WalrusDataResponseSchema.nullable(),
  musical_key: MusicalKeyResponseSchema.nullable(),
  time_signature: TimeSignatureResponseSchema.nullable(),
  tempo_bpm: z.number().nullable(),
  master: AudioResponseSchema,
  stems: z.array(StemResponseSchema),
  cover_art: CoverArtResponseSchema,
}).transform((data) => ({
  state: data.state,
  title: data.title,
  titleVersion: data.title_version ?? undefined,
  subtitle: data.subtitle ?? undefined,
  compositionId: data.composition_id,
  compositionShareType: data.composition_share_type.name,
  compositionSplitBps: data.composition_split_bps,
  primaryGenreId: data.primary_genre_id,
  secondaryGenreIds: new Set(data.secondary_genre_ids.contents),
  primaryArtistIds: new Set(data.primary_artist_ids.contents),
  featuredArtistIds: new Set(data.featured_artist_ids.contents),
  credits: new Map(data.credits.contents.map((c) => [c.key, c.value])),
  language: data.language?.pos0,
  isExplicit: data.is_explicit,
  isInstrumental: data.is_instrumental,
  lyrics: data.lyrics ?? undefined,
  musicalKey: data.musical_key ?? undefined,
  timeSignature: data.time_signature ?? undefined,
  tempoBpm: data.tempo_bpm ?? undefined,
  master: data.master,
  stems: data.stems,
  coverArt: data.cover_art,
}));

const ReleaseResponseSchema = z.object({
  kind: ReleaseKindResponseSchema,
  state: ReleaseStateResponseSchema,
  title: z.string(),
  description: z.string(),
  subtitle: z.string().nullable(),
  discs: z.array(DiscResponseSchema),
  cover_art: CoverArtResponseSchema,
}).transform((data) => ({
  kind: data.kind,
  state: data.state,
  title: data.title,
  description: data.description,
  subtitle: data.subtitle ?? undefined,
  discs: data.discs,
  coverArt: data.cover_art,
}));

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
export async function getRelease(
  client: SuiClientLike,
  releaseId: string
): Promise<Release> {
  const result = await client.getObject({ objectId: releaseId, include: { json: true } });

  const json = result.object?.json;
  if (!json) {
    throw new Error(`Release not found: ${releaseId}`);
  }

  const parsed = ReleaseResponseSchema.parse(json);
  return { id: releaseId, ...parsed } as Release;
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

  const parsed = ReleaseResponseSchema.parse(json);
  return { id: releaseId, ...parsed } as Release;
}

/**
 * Fetches a recording by its object ID using Core API.
 *
 * @param client - A Sui client with Core API (SuiGrpcClient or similar)
 * @param recordingId - The object ID of the Recording
 * @returns The Recording object
 */
export async function getRecording(
  client: SuiClientLike,
  recordingId: string
): Promise<Recording> {
  const result = await client.getObject({ objectId: recordingId, include: { json: true } });

  const json = result.object?.json;
  if (!json) {
    throw new Error(`Recording not found: ${recordingId}`);
  }

  const parsed = RecordingResponseSchema.parse(json);
  return { id: recordingId, ...parsed } as Recording;
}

/**
 * @deprecated Use getRecording with Core API client instead.
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

  const parsed = RecordingResponseSchema.parse(json);
  return { id: recordingId, ...parsed } as Recording;
}

/**
 * Fetches a genre by its object ID using Core API.
 *
 * @param client - A Sui client with Core API (SuiGrpcClient or similar)
 * @param genreId - The object ID of the Genre
 * @returns The Genre object
 */
export async function getGenre(
  client: SuiClientLike,
  genreId: string
): Promise<Genre> {
  const result = await client.getObject({ objectId: genreId, include: { json: true } });

  const json = result.object?.json as { name: string } | undefined;
  if (!json?.name) {
    throw new Error(`Genre not found: ${genreId}`);
  }

  return {
    id: genreId,
    name: json.name,
  };
}

/**
 * @deprecated Use getGenre with Core API client instead.
 * Fetches a genre by its object ID using GraphQL.
 */
export async function getGenreGraphQL(
  client: SuiGraphQLClient,
  genreId: string
): Promise<Genre> {
  const result = await client.query({
    query: ObjectQuery,
    variables: { address: genreId },
  });

  const json = result.data?.object?.asMoveObject?.contents?.json as { name: string } | undefined;
  if (!json?.name) {
    throw new Error(`Genre not found: ${genreId}`);
  }

  return {
    id: genreId,
    name: json.name,
  };
}

/**
 * Fetches multiple objects by their IDs in a single request using Core API.
 *
 * @param client - A Sui client with Core API (SuiGrpcClient or similar)
 * @param objectIds - Array of object IDs to fetch
 * @returns Map of object ID to its JSON contents
 */
export async function getObjects(
  client: SuiClientLike,
  objectIds: string[]
): Promise<Map<string, unknown>> {
  if (objectIds.length === 0) {
    return new Map();
  }

  const result = await client.getObjects({ objectIds, include: { json: true } });

  const objects = new Map<string, unknown>();
  for (const obj of result.objects) {
    const json = obj.object?.json;
    if (json && obj.objectId) {
      objects.set(obj.objectId, json);
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
): Promise<Map<string, unknown>> {
  if (objectIds.length === 0) {
    return new Map();
  }

  const result = await client.query({
    query: MultiObjectQuery,
    variables: { ids: objectIds },
  });

  const objects = new Map<string, unknown>();
  for (const node of result.data?.objects?.nodes ?? []) {
    const json = node.asMoveObject?.contents?.json;
    if (json && node.address) {
      objects.set(node.address, json);
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
export async function getRecordings(
  client: SuiClientLike,
  recordingIds: string[]
): Promise<Map<string, Recording>> {
  const objects = await getObjects(client, recordingIds);
  const recordings = new Map<string, Recording>();

  for (const [id, json] of objects) {
    const parsed = RecordingResponseSchema.parse(json);
    recordings.set(id, { id, ...parsed } as Recording);
  }

  return recordings;
}

/**
 * @deprecated Use getRecordings with Core API client instead.
 * Fetches multiple recordings by their IDs in a single request using GraphQL.
 */
export async function getRecordingsGraphQL(
  client: SuiGraphQLClient,
  recordingIds: string[]
): Promise<Map<string, Recording>> {
  const objects = await getObjectsGraphQL(client, recordingIds);
  const recordings = new Map<string, Recording>();

  for (const [id, json] of objects) {
    const parsed = RecordingResponseSchema.parse(json);
    recordings.set(id, { id, ...parsed } as Recording);
  }

  return recordings;
}
// Copyright (c) Unconfirmed Labs, LLC
// SPDX-License-Identifier: Apache-2.0

import type { SuiGrpcClient } from "@mysten/sui/grpc";
import type { SuiGraphQLClient } from "@mysten/sui/graphql";
import { graphql } from "@mysten/sui/graphql/schema";

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
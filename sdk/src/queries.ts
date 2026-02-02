// Copyright (c) Unconfirmed Labs, LLC
// SPDX-License-Identifier: Apache-2.0

import type { SuiGrpcClient } from "@mysten/sui/grpc";

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
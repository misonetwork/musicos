// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

// Simulate-based reads (the `view` surface). These build a transaction and run it
// through the Core `simulateTransaction` API to read a computed value without
// changing state — used where the value is a pure function of inputs the chain
// derives (e.g. the deterministic release id).

import { Transaction } from "@mysten/sui/transactions";
import { bcs } from "@mysten/sui/bcs";
import type { ClientWithCoreApi } from "@mysten/sui/client";
import * as release from "./contracts/miso/release.ts";

export interface DeriveReleaseIdParams {
  /** Sender for the simulation (any address; not charged). */
  sender: string;
  /** Recording object ids, in track order. */
  recordingIds: string[];
  /** Per-track split basis points, aligned to `recordingIds`. */
  splitBps: number[];
  /** The release nonce (u256 as a decimal string). */
  nonce: string;
  /** The shared ReleaseRegistry object id. */
  releaseRegistryId: string;
}

/**
 * Derives the release id the on-chain `release::new` will produce for these
 * inputs, via a `simulateTransaction` call to `release::derive_release_id`. The
 * deals embedded in a release must reference this exact id, so it is computed up
 * front and threaded into the release publish builder.
 */
export async function deriveReleaseId(
  client: ClientWithCoreApi,
  misoPackageId: string,
  params: DeriveReleaseIdParams,
): Promise<string> {
  if (params.recordingIds.length !== params.splitBps.length) {
    throw new Error(`deriveReleaseId: recordingIds (${params.recordingIds.length}) and splitBps (${params.splitBps.length}) length mismatch.`);
  }

  const tx = new Transaction();
  tx.setSender(params.sender);
  tx.add(
    release.deriveReleaseId({
      package: misoPackageId,
      arguments: [params.recordingIds, params.splitBps.map((v) => BigInt(v)), BigInt(params.nonce), params.releaseRegistryId],
    }),
  );

  // gRPC/Core equivalent of devInspect: simulate with per-command return values.
  const res = await client.core.simulateTransaction({ transaction: tx, include: { commandResults: true } });
  if (res.$kind !== "Transaction") {
    throw new Error(`derive_release_id simulation failed: ${JSON.stringify(res.FailedTransaction.status)}`);
  }
  const returned = res.commandResults?.[0]?.returnValues?.[0]?.bcs;
  if (!returned) throw new Error("derive_release_id returned no value.");
  return bcs.Address.parse(returned);
}

// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

// First-party royalty-pool extension.
//
// A RoyaltyPool<Share, Currency> is an accumulator-based royalty-distribution pool
// bound to a composition or recording. It is created via the work's admin-gated
// `uid_mut(&AdminCap)` derived-object hook (`initialize_pool`), then shared
// (`pool::share`). Because `initialize_pool` borrows the work `&mut` (and the cap
// `&`) — not a shared on-chain input — it composes INSIDE the work's publish PTB:
// run it after `newComposition`/`newRecording` and before `finalize*` (which
// consumes the work into `share_object` and transfers the cap to the owner).
//
// Scope here is create + share only. Stake registration, funding (receive/redeem/
// deposit), and claiming are later owner/holder actions, not part of publishing.

import type { Transaction, TransactionObjectArgument } from "@mysten/sui/transactions";
import * as compositionRoyaltyPool from "../contracts/composition_royalty_pool/composition_royalty_pool.ts";
import * as recordingRoyaltyPool from "../contracts/recording_royalty_pool/recording_royalty_pool.ts";
import * as pool from "../contracts/royalty_pool/pool.ts";

/** On-chain package ids for the royalty-pool extension (from the deployment config). */
export interface RoyaltyPoolPackages {
  /** `composition_royalty_pool` package id. */
  compositionRoyaltyPoolPackageId: string;
  /** `recording_royalty_pool` package id. */
  recordingRoyaltyPoolPackageId: string;
  /** Base `royalty_pool` lib package id (holds `pool::share` and the pool type). */
  royaltyPoolPackageId: string;
}

export interface AttachCompositionRoyaltyPoolParams {
  /** The Composition — an in-PTB `newComposition` result, borrowed `&mut`. */
  composition: TransactionObjectArgument;
  /** The CompositionAdminCap, borrowed `&`. */
  adminCap: TransactionObjectArgument;
  /** The composition's share type (the pool's `Share` phantom = CompositionShare). */
  compositionShareType: string;
  /** Fully-qualified coin type the pool accumulates (the `Currency` phantom). */
  currency: string;
  compositionRoyaltyPoolPackageId: string;
  royaltyPoolPackageId: string;
}

/** Creates a royalty pool for a composition and shares it, appending to `tx`. */
export function attachCompositionRoyaltyPool(tx: Transaction, params: AttachCompositionRoyaltyPoolParams): void {
  const created = tx.add(
    compositionRoyaltyPool.initializePool({
      package: params.compositionRoyaltyPoolPackageId,
      typeArguments: [params.compositionShareType, params.currency],
      arguments: [params.composition, params.adminCap],
    }),
  );
  tx.add(
    pool.share({
      package: params.royaltyPoolPackageId,
      typeArguments: [params.compositionShareType, params.currency],
      arguments: [created],
    }),
  );
}

export interface AttachRecordingRoyaltyPoolParams {
  /** The Recording — an in-PTB `newRecording` result, borrowed `&mut`. */
  recording: TransactionObjectArgument;
  /** The RecordingAdminCap, borrowed `&`. */
  adminCap: TransactionObjectArgument;
  /** The recording's own share type (the pool's `Share` phantom = RecordingShare). */
  recordingShareType: string;
  /** The parent composition's share type (the recording's `CompositionShare` phantom). */
  compositionShareType: string;
  /** Fully-qualified coin type the pool accumulates (the `Currency` phantom). */
  currency: string;
  recordingRoyaltyPoolPackageId: string;
  royaltyPoolPackageId: string;
}

/** Creates a royalty pool for a recording and shares it, appending to `tx`. */
export function attachRecordingRoyaltyPool(tx: Transaction, params: AttachRecordingRoyaltyPoolParams): void {
  const created = tx.add(
    recordingRoyaltyPool.initializePool({
      package: params.recordingRoyaltyPoolPackageId,
      typeArguments: [params.recordingShareType, params.compositionShareType, params.currency],
      arguments: [params.recording, params.adminCap],
    }),
  );
  // The pool is RoyaltyPool<RecordingShare, Currency> — Share is the recording's own share type.
  tx.add(
    pool.share({
      package: params.royaltyPoolPackageId,
      typeArguments: [params.recordingShareType, params.currency],
      arguments: [created],
    }),
  );
}

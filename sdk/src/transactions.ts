// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

// Transaction builders, following the Sui SDK thunk pattern: each builder
// returns a `(tx: Transaction) => …` thunk that adds commands to a caller-owned
// `Transaction`, so flows compose. MusicOS calls go through the codegen-
// generated, type-safe call functions; calls into external packages (share,
// minato, framework) use raw `moveCall`.

import { Transaction, type TransactionObjectArgument } from "@mysten/sui/transactions";
import type { ClientWithCoreApi } from "@mysten/sui/client";
import { bcs } from "@mysten/sui/bcs";
import { deriveObjectID } from "@mysten/sui/utils";
import { getShareCurrencyType, getShareCurrencyTreasuryCap } from "./queries.ts";

import * as composition from "./contracts/musicos/composition.ts";
import * as recording from "./contracts/musicos/recording.ts";
import * as release from "./contracts/musicos/release.ts";
import * as deal from "./contracts/musicos/deal.ts";
import * as track from "./contracts/musicos/track.ts";
import * as disc from "./contracts/musicos/disc.ts";

/** A thunk that adds commands to a transaction. May be async (resolves at build time). */
export type TxThunk = (tx: Transaction) => void | Promise<void>;

const OPTION_NONE = "0x1::option::none";
const OPTION_SOME = "0x1::option::some";

// ============================================================================
// Shared inputs
// ============================================================================

export interface ShareRecipient {
  address: string;
  value: number;
}

function disperseShares(
  tx: Transaction,
  minatoPackageId: string,
  shareType: string,
  balance: TransactionObjectArgument,
  recipients: ShareRecipient[],
) {
  tx.moveCall({
    target: `${minatoPackageId}::minato::disperse_balance`,
    typeArguments: [shareType],
    arguments: [
      balance,
      tx.makeMoveVec({ type: "u64", elements: recipients.map((r) => tx.pure.u64(r.value)) }),
      tx.makeMoveVec({ type: "address", elements: recipients.map((r) => tx.pure.address(r.address)) }),
    ],
  });
  tx.moveCall({ target: "0x2::balance::destroy_zero", typeArguments: [shareType], arguments: [balance] });
}


// ============================================================================
// Share currency (external share / framework)
// ============================================================================

export interface PackageBytecode {
  modules: string[];
  dependencies: string[];
  digest: number[];
}

export function publishShareCurrency(bytecode: PackageBytecode): TxThunk {
  return (tx) => {
    const upgradeCap = tx.publish(bytecode);
    tx.moveCall({ target: "0x2::package::make_immutable", arguments: [upgradeCap] });
  };
}

const SUI_COIN_REGISTRY_ID = "0xc";

export interface InitializeShareCurrencyParams {
  shareCurrencyPackageId: string;
  name: string;
  description: string;
  iconUrl: string;
  treasuryCapRecipient: string;
}

export function initializeShareCurrency(params: InitializeShareCurrencyParams): TxThunk {
  const { shareCurrencyPackageId, name, description, iconUrl, treasuryCapRecipient } = params;
  return (tx) => {
    const treasuryCap = tx.moveCall({
      target: `${shareCurrencyPackageId}::share::initialize`,
      arguments: [tx.pure.string(name), tx.pure.string(description), tx.pure.string(iconUrl), tx.object(SUI_COIN_REGISTRY_ID)],
    });
    tx.transferObjects([treasuryCap], treasuryCapRecipient);
  };
}

// ============================================================================
// Composition
// ============================================================================

export interface PublishCompositionParams {
  client: ClientWithCoreApi;
  shareCurrencyId: string;
  treasuryCapOwner: string;
  title: string;
  royaltyRateBps: number;
  shareRecipients: ShareRecipient[];
  adminAddress: string;
  musicOsPackageId: string;
  minatoPackageId: string;
}

export function publishComposition(params: PublishCompositionParams): TxThunk {
  return async (tx) => {
    const { client, musicOsPackageId, minatoPackageId } = params;
    const shareType = await getShareCurrencyType(client, params.shareCurrencyId);
    const treasuryCapId = await getShareCurrencyTreasuryCap(client, params.shareCurrencyId, params.treasuryCapOwner);

    const result = tx.add(
      composition._new({
        package: musicOsPackageId,
        typeArguments: [shareType],
        arguments: [tx.pure.string(params.title), tx.pure.u16(params.royaltyRateBps), tx.object(params.shareCurrencyId), tx.object(treasuryCapId)],
      }),
    );
    const comp = result[0]!;
    const adminCap = result[1]!;
    const balance = result[2]!;

    disperseShares(tx, minatoPackageId, shareType, balance, params.shareRecipients);
    tx.add(composition.publish({ package: musicOsPackageId, typeArguments: [shareType], arguments: [comp, adminCap] }));
    tx.transferObjects([adminCap], params.adminAddress);
  };
}

// ============================================================================
// Recording
// ============================================================================

/**
 * Derives a recording's object id: the `idx`-th recording under a composition.
 * Mirrors `recording::RecordingKey(idx)` claimed off the composition's UID.
 */
export function deriveRecordingId(compositionId: string, idx: number | bigint, musicOsPackageId: string): string {
  const keyType = `${musicOsPackageId}::recording::RecordingKey`;
  const keyBytes = bcs.u64().serialize(BigInt(idx)).toBytes();
  return deriveObjectID(compositionId, keyType, keyBytes);
}

/** Whether an object currently exists on-chain. */
async function objectExists(client: ClientWithCoreApi, objectId: string): Promise<boolean> {
  try {
    const { object } = await client.core.getObject({ objectId });
    return object != null;
  } catch {
    return false; // not-found (or unreadable) → treat as absent
  }
}

/**
 * Finds the next free recording index for a composition by probing derived ids
 * `0,1,2,…` until one doesn't exist. Recording indices are contiguous, so this
 * is the count of existing recordings. Best-effort under concurrency: if another
 * publish claims the same index first, the tx aborts and the caller re-probes.
 */
export async function nextRecordingIndex(
  client: ClientWithCoreApi,
  compositionId: string,
  musicOsPackageId: string,
): Promise<number> {
  let idx = 0;
  while (await objectExists(client, deriveRecordingId(compositionId, idx, musicOsPackageId))) idx++;
  return idx;
}

export interface PublishRecordingParams {
  client: ClientWithCoreApi;
  compositionId: string;
  /** Recording index under the composition. Omit to auto-probe the next free one. */
  recordingIndex?: number;
  /** Share type of the parent composition (the recording's `CompositionShare` phantom). */
  compositionShareType: string;
  shareCurrencyId: string;
  treasuryCapOwner: string;
  shareRecipients: ShareRecipient[];
  adminAddress: string;
  titleVersion?: string;
  subtitle?: string;
  musicOsPackageId: string;
  minatoPackageId: string;
}

export function publishRecording(params: PublishRecordingParams): TxThunk {
  return async (tx) => {
    const { client, musicOsPackageId } = params;
    const shareType = await getShareCurrencyType(client, params.shareCurrencyId);
    const treasuryCapId = await getShareCurrencyTreasuryCap(client, params.shareCurrencyId, params.treasuryCapOwner);
    const typeArguments: [string, string] = [shareType, params.compositionShareType];

    const idx = params.recordingIndex ?? (await nextRecordingIndex(client, params.compositionId, musicOsPackageId));

    const result = tx.add(
      recording._new({
        package: musicOsPackageId,
        typeArguments,
        arguments: [tx.object(params.compositionId), tx.pure.u64(idx), tx.object(params.shareCurrencyId), tx.object(treasuryCapId)],
      }),
    );
    const rec = result[0]!;
    const adminCap = result[1]!;
    const balance = result[2]!;

    if (params.titleVersion !== undefined)
      tx.add(recording.setTitleVersion({ package: musicOsPackageId, typeArguments, arguments: [rec, adminCap, tx.pure.string(params.titleVersion)] }));
    if (params.subtitle !== undefined)
      tx.add(recording.setSubtitle({ package: musicOsPackageId, typeArguments, arguments: [rec, adminCap, tx.pure.string(params.subtitle)] }));

    tx.add(recording.publish({ package: musicOsPackageId, typeArguments, arguments: [rec, adminCap] }));
    disperseShares(tx, params.minatoPackageId, shareType, balance, params.shareRecipients);
    tx.transferObjects([adminCap], params.adminAddress);
  };
}

// ============================================================================
// Deal
// ============================================================================

export interface CreateDealParams {
  recordingId: string;
  recordingAdminCapId?: string;
  recordingAdminCap?: TransactionObjectArgument;
  /** Share type of the recording (the deal's `RecordingShare` phantom). */
  recordingShareType: string;
  /** Share type of the parent composition (the deal's `CompositionShare` phantom). */
  compositionShareType: string;
  releaseId: string;
  trackSplitBps: number;
  recipientAddress: string;
  musicOsPackageId: string;
}

function buildTitleOption(tx: Transaction, title?: string) {
  return title
    ? tx.moveCall({ target: OPTION_SOME, typeArguments: ["0x1::string::String"], arguments: [tx.pure.string(title)] })
    : tx.moveCall({ target: OPTION_NONE, typeArguments: ["0x1::string::String"], arguments: [] });
}

export function createDeal(params: CreateDealParams): TxThunk {
  return (tx) => {
    const adminCapArg = params.recordingAdminCap ?? tx.object(params.recordingAdminCapId!);
    const dealArg = tx.add(
      deal._new({
        package: params.musicOsPackageId,
        typeArguments: [params.recordingShareType, params.compositionShareType],
        arguments: [
          adminCapArg,
          tx.object(params.recordingId),
          tx.pure.id(params.releaseId),
          tx.pure.u16(params.trackSplitBps),
        ],
      }),
    );
    tx.transferObjects([dealArg], params.recipientAddress);
  };
}

export interface RejectDealParams {
  dealId: string;
  /** Share type of the recording (the deal's `RecordingShare` phantom). */
  recordingShareType: string;
  /** Share type of the parent composition (the deal's `CompositionShare` phantom). */
  compositionShareType: string;
  musicOsPackageId: string;
}

/** Rejects (destroys) a deal without including it in a release. Emits `DealRejectedEvent`. */
export function rejectDeal(params: RejectDealParams): TxThunk {
  return (tx) => {
    tx.add(deal.reject({
      package: params.musicOsPackageId,
      typeArguments: [params.recordingShareType, params.compositionShareType],
      arguments: [tx.object(params.dealId)],
    }));
  };
}

// ============================================================================
// Release
// ============================================================================

export interface TrackInput {
  recordingId: string;
  recordingAdminCapId: string;
  /** Share type of the recording (the deal/track `RecordingShare` phantom). */
  recordingShareType: string;
  /** Share type of the parent composition (the deal/track `CompositionShare` phantom). */
  compositionShareType: string;
  splitBps: number;
}

export interface DiscInput {
  tracks: TrackInput[];
  title?: string;
}

export interface PublishReleaseParams {
  title: string;
  /** Optional subtitle (e.g., "Deluxe Edition") — part of the release's identity. */
  subtitle?: string;
  discs: DiscInput[];
  releaseRegistryId: string;
  releaseId: string;
  releaseNonce: string;
  musicOsPackageId: string;
  adminAddress: string;
}

function buildDiscVec(
  tx: Transaction,
  musicOsPackageId: string,
  trackArgsByDisc: { title?: string; trackArgs: TransactionObjectArgument[] }[],
) {
  const discArgs = trackArgsByDisc.map(({ title, trackArgs }) => {
    const trackVec = tx.makeMoveVec({ type: `${musicOsPackageId}::track::Track`, elements: trackArgs });
    return tx.add(disc._new({ package: musicOsPackageId, arguments: [trackVec, buildTitleOption(tx, title)] }));
  });
  return tx.makeMoveVec({ type: `${musicOsPackageId}::disc::Disc`, elements: discArgs });
}

export function publishRelease(params: PublishReleaseParams): TxThunk {
  return (tx) => {
    const { musicOsPackageId } = params;
    const byDisc = params.discs.map((d) => ({
      title: d.title,
      trackArgs: d.tracks.map((t) => {
        const typeArguments: [string, string] = [t.recordingShareType, t.compositionShareType];
        const dealArg = tx.add(
          deal._new({
            package: musicOsPackageId,
            typeArguments,
            arguments: [tx.object(t.recordingAdminCapId), tx.object(t.recordingId), tx.pure.id(params.releaseId), tx.pure.u16(t.splitBps)],
          }),
        );
        return tx.add(track._new({ package: musicOsPackageId, typeArguments, arguments: [dealArg] }));
      }),
    }));
    const discVec = buildDiscVec(tx, musicOsPackageId, byDisc);
    const result = tx.add(
      release._new({
        package: musicOsPackageId,
        arguments: [tx.pure.string(params.title), discVec, tx.pure.u256(BigInt(params.releaseNonce)), tx.object(params.releaseRegistryId)],
      }),
    );
    const releaseArg = result[0]!;
    const adminCap = result[1]!;
    if (params.subtitle !== undefined)
      tx.add(release.setSubtitle({ package: musicOsPackageId, arguments: [releaseArg, adminCap, tx.pure.string(params.subtitle)] }));
    tx.add(release.publish({ package: musicOsPackageId, arguments: [releaseArg, adminCap] }));
    tx.transferObjects([adminCap], tx.pure.address(params.adminAddress));
  };
}

export interface DealInput {
  dealId: string;
  /** Share type of the recording (the deal/track `RecordingShare` phantom). */
  recordingShareType: string;
  /** Share type of the parent composition (the deal/track `CompositionShare` phantom). */
  compositionShareType: string;
}

export interface DiscFromDealsInput {
  deals: DealInput[];
  title?: string;
}

export interface PublishReleaseFromDealsParams {
  title: string;
  /** Optional subtitle (e.g., "Deluxe Edition") — part of the release's identity. */
  subtitle?: string;
  discs: DiscFromDealsInput[];
  releaseRegistryId: string;
  releaseNonce: string;
  musicOsPackageId: string;
  adminAddress: string;
}

export function publishReleaseFromDeals(params: PublishReleaseFromDealsParams): TxThunk {
  return (tx) => {
    const { musicOsPackageId } = params;
    const byDisc = params.discs.map((d) => ({
      title: d.title,
      trackArgs: d.deals.map((dl) =>
        tx.add(track._new({
          package: musicOsPackageId,
          typeArguments: [dl.recordingShareType, dl.compositionShareType],
          arguments: [tx.object(dl.dealId)],
        })),
      ),
    }));
    const discVec = buildDiscVec(tx, musicOsPackageId, byDisc);
    const result = tx.add(
      release._new({
        package: musicOsPackageId,
        arguments: [tx.pure.string(params.title), discVec, tx.pure.u256(BigInt(params.releaseNonce)), tx.object(params.releaseRegistryId)],
      }),
    );
    const releaseArg = result[0]!;
    const adminCap = result[1]!;
    if (params.subtitle !== undefined)
      tx.add(release.setSubtitle({ package: musicOsPackageId, arguments: [releaseArg, adminCap, tx.pure.string(params.subtitle)] }));
    tx.add(release.publish({ package: musicOsPackageId, arguments: [releaseArg, adminCap] }));
    tx.transferObjects([adminCap], tx.pure.address(params.adminAddress));
  };
}

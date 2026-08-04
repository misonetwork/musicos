// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

// Transaction builders, following the Sui SDK thunk pattern: each builder
// returns a `(tx: Transaction) => …` thunk that adds commands to a caller-owned
// `Transaction`, so flows compose. Miso calls go through the codegen-
// generated, type-safe call functions; calls into external packages (share,
// minato, framework) use raw `moveCall`.

import { Transaction, type TransactionObjectArgument } from "@mysten/sui/transactions";

import * as composition from "./contracts/miso/composition.ts";
import * as recording from "./contracts/miso/recording.ts";
import * as deal from "./contracts/miso/deal.ts";
import * as track from "./contracts/miso/track.ts";
import { buildAndPublishRelease } from "./internal.ts";

/** A thunk that adds commands to a transaction. May be async (resolves at build time). */
export type TxThunk = (tx: Transaction) => void | Promise<void>;

// ============================================================================
// Shared inputs
// ============================================================================

export interface ShareRecipient {
  address: string;
  value: number;
}

/**
 * Splits a share `Balance` across `recipients` via `minato::disperse_balance`, then
 * destroys the emptied balance. Exposed for consumers assembling custom share
 * distributions in their own PTBs.
 */
export function disperseShares(
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

/**
 * Share-currency binding for a work: the fully-qualified `share::Share` type, the
 * `Currency<Share>` object, and the `TreasuryCap<Share>`. All three are known once
 * the currency has been published + initialized, so builders take them explicitly
 * rather than reading them from chain — keeping the thunks synchronous and
 * composable (no RPC inside the transaction build).
 */
export interface ShareCurrencyBinding {
  /** The `${packageId}::share::Share` type. */
  shareType: string;
  /** The `Currency<Share>` object id. */
  shareCurrencyId: string;
  /** The `TreasuryCap<Share>` object id (held by the caller, consumed by `new`). */
  shareTreasuryCapId: string;
}

/** The three by-value results of `composition::new`, for threading onward in a PTB. */
export interface CompositionParts {
  composition: TransactionObjectArgument;
  adminCap: TransactionObjectArgument;
  /** The creator's freshly-minted share supply (a `Balance<Share>`). */
  balance: TransactionObjectArgument;
}

export interface NewCompositionParams extends ShareCurrencyBinding {
  title: string;
  royaltyRateBps: number;
  misoPackageId: string;
}

/**
 * PRIMITIVE. Appends `composition::new` and returns its by-value results without
 * dispersing, sharing, or transferring anything — the caller decides what happens
 * next (share it, keep it unshared to bundle with a recording, attach a dynamic
 * field via `uid_mut`, …). Composes with anything in the same PTB.
 */
export function newComposition(tx: Transaction, params: NewCompositionParams): CompositionParts {
  const result = tx.add(
    composition._new({
      package: params.misoPackageId,
      typeArguments: [params.shareType],
      arguments: [tx.pure.string(params.title), tx.pure.u16(params.royaltyRateBps), tx.object(params.shareCurrencyId), tx.object(params.shareTreasuryCapId)],
    }),
  );
  return { composition: result[0]!, adminCap: result[1]!, balance: result[2]! };
}

export interface FinalizeCompositionParams extends CompositionParts {
  /** The composition's `share::Share` type. */
  shareType: string;
  shareRecipients: ShareRecipient[];
  adminAddress: string;
  misoPackageId: string;
  minatoPackageId: string;
}

/**
 * PRIMITIVE. The opinionated finish for a composition: disperse its share supply to
 * `shareRecipients`, publish (share) it, and transfer its admin cap to
 * `adminAddress`. Consumers that want different economics skip this and act on the
 * {@link CompositionParts} directly.
 */
export function finalizeComposition(tx: Transaction, params: FinalizeCompositionParams): void {
  disperseShares(tx, params.minatoPackageId, params.shareType, params.balance, params.shareRecipients);
  tx.add(composition.publish({ package: params.misoPackageId, typeArguments: [params.shareType], arguments: [params.composition, params.adminCap] }));
  tx.transferObjects([params.adminCap], params.adminAddress);
}

export interface PublishCompositionParams extends ShareCurrencyBinding {
  title: string;
  royaltyRateBps: number;
  shareRecipients: ShareRecipient[];
  /** Sole owner of the shares + CompositionAdminCap (the zkLogin address). */
  adminAddress: string;
  misoPackageId: string;
  minatoPackageId: string;
}

/** Convenience: publish a composition end-to-end (newComposition → finalizeComposition). */
export function publishComposition(params: PublishCompositionParams): TxThunk {
  return (tx) => {
    const parts = newComposition(tx, {
      shareType: params.shareType,
      shareCurrencyId: params.shareCurrencyId,
      shareTreasuryCapId: params.shareTreasuryCapId,
      title: params.title,
      royaltyRateBps: params.royaltyRateBps,
      misoPackageId: params.misoPackageId,
    });
    finalizeComposition(tx, {
      ...parts,
      shareType: params.shareType,
      shareRecipients: params.shareRecipients,
      adminAddress: params.adminAddress,
      misoPackageId: params.misoPackageId,
      minatoPackageId: params.minatoPackageId,
    });
  };
}

// ============================================================================
// Recording
// ============================================================================

/** The three by-value results of `recording::new`, for threading onward in a PTB. */
export interface RecordingParts {
  recording: TransactionObjectArgument;
  adminCap: TransactionObjectArgument;
  /** The creator's remaining share supply after the composition's cut is split off. */
  balance: TransactionObjectArgument;
}

/** The protocol's maximum composition royalty rate (`MAX_ROYALTY_RATE_BPS`). */
export const PROTOCOL_MAX_ROYALTY_RATE_BPS = 2000;

export interface NewRecordingParams extends ShareCurrencyBinding {
  /** Share type of the parent composition (the recording's `CompositionShare` phantom). */
  compositionShareType: string;
  /**
   * Parent `Composition`, passed by immutable reference (`recording::new` reads only
   * its id + royalty rate). May be an on-chain object (`tx.object(id)`) or a still-
   * unshared, transaction-local `newComposition(...).composition` result.
   */
  composition: TransactionObjectArgument;
  /**
   * Slippage guard: the maximum composition royalty rate (bps) the recorder will
   * grant — `recording::new` aborts if the composition's live rate exceeds it.
   * Pass the rate you observed. Defaults to the protocol maximum (2000), which
   * accepts any legal rate.
   */
  maxRoyaltyRateBps?: number;
  misoPackageId: string;
}

/**
 * PRIMITIVE. Appends `recording::new` and returns its by-value results without
 * publishing/dispersing/transferring. Because it borrows the composition by
 * reference, it can run against a composition that is still an unshared PTB-local
 * value — the borrow-before-share pattern that lets a composition + recording share
 * one PTB.
 */
export function newRecording(tx: Transaction, params: NewRecordingParams): RecordingParts {
  const result = tx.add(
    recording._new({
      package: params.misoPackageId,
      typeArguments: [params.shareType, params.compositionShareType],
      arguments: [params.composition, tx.object(params.shareCurrencyId), tx.object(params.shareTreasuryCapId), tx.pure.u16(params.maxRoyaltyRateBps ?? PROTOCOL_MAX_ROYALTY_RATE_BPS)],
    }),
  );
  return { recording: result[0]!, adminCap: result[1]!, balance: result[2]! };
}

export interface FinalizeRecordingParams extends RecordingParts {
  /** The recording's own `share::Share` type. */
  recordingShareType: string;
  /** Share type of the parent composition. */
  compositionShareType: string;
  shareRecipients: ShareRecipient[];
  adminAddress: string;
  misoPackageId: string;
  minatoPackageId: string;
}

/**
 * PRIMITIVE. Opinionated finish for a recording: publish (share) it, disperse
 * its share supply, and transfer its admin cap to `adminAddress`. A recording
 * has no embedded metadata to set — naming lives in the metadata extension.
 */
export function finalizeRecording(tx: Transaction, params: FinalizeRecordingParams): void {
  const typeArguments: [string, string] = [params.recordingShareType, params.compositionShareType];
  tx.add(recording.publish({ package: params.misoPackageId, typeArguments, arguments: [params.recording, params.adminCap] }));
  disperseShares(tx, params.minatoPackageId, params.recordingShareType, params.balance, params.shareRecipients);
  tx.transferObjects([params.adminCap], params.adminAddress);
}

export interface PublishRecordingParams extends ShareCurrencyBinding {
  /**
   * Parent composition, referenced as an on-chain object. Read-only at
   * `recording::new` (only its royalty rate and id are read).
   */
  compositionId: string;
  /** Share type of the parent composition (the recording's `CompositionShare` phantom). */
  compositionShareType: string;
  shareRecipients: ShareRecipient[];
  adminAddress: string;
  /** Slippage guard for `recording::new` — pass the composition rate you observed (default: protocol max). */
  maxRoyaltyRateBps?: number;
  misoPackageId: string;
  minatoPackageId: string;
}

/** Convenience: publish a recording against an already-on-chain composition. */
export function publishRecording(params: PublishRecordingParams): TxThunk {
  return (tx) => {
    const parts = newRecording(tx, {
      shareType: params.shareType,
      shareCurrencyId: params.shareCurrencyId,
      shareTreasuryCapId: params.shareTreasuryCapId,
      compositionShareType: params.compositionShareType,
      composition: tx.object(params.compositionId),
      maxRoyaltyRateBps: params.maxRoyaltyRateBps,
      misoPackageId: params.misoPackageId,
    });
    finalizeRecording(tx, {
      ...parts,
      recordingShareType: params.shareType,
      compositionShareType: params.compositionShareType,
      shareRecipients: params.shareRecipients,
      adminAddress: params.adminAddress,
      misoPackageId: params.misoPackageId,
      minatoPackageId: params.minatoPackageId,
    });
  };
}

// ============================================================================
// Composition + Recording (single PTB)
// ============================================================================

export interface PublishCompositionAndRecordingParams {
  title: string;
  royaltyRateBps: number;
  /** Share-currency binding for the composition. */
  composition: ShareCurrencyBinding & { shareRecipients: ShareRecipient[]; adminAddress: string };
  /** Share-currency binding for the recording. */
  recording: ShareCurrencyBinding & { shareRecipients: ShareRecipient[]; adminAddress: string };
  misoPackageId: string;
  minatoPackageId: string;
}

/**
 * Publishes a composition and its recording in a single atomic PTB.
 *
 * The ordering is load-bearing: `recording::new` borrows the composition by
 * immutable reference, so it must run while the composition is still an unshared,
 * transaction-local value — i.e. AFTER `composition::new` but BEFORE
 * `composition::publish` (which moves the composition into `share_object`). Hence:
 * `composition::new` → `recording::new(&comp)` → finalize composition (publish) →
 * finalize recording (publish).
 */
export function publishCompositionAndRecording(params: PublishCompositionAndRecordingParams): TxThunk {
  return (tx) => {
    const comp = newComposition(tx, {
      shareType: params.composition.shareType,
      shareCurrencyId: params.composition.shareCurrencyId,
      shareTreasuryCapId: params.composition.shareTreasuryCapId,
      title: params.title,
      royaltyRateBps: params.royaltyRateBps,
      misoPackageId: params.misoPackageId,
    });

    // Borrow the still-unshared composition into recording::new before publishing it.
    // The composition is created in this PTB with a known rate, so the slippage
    // guard pins that exact value — front-running is structurally impossible here.
    const rec = newRecording(tx, {
      shareType: params.recording.shareType,
      shareCurrencyId: params.recording.shareCurrencyId,
      shareTreasuryCapId: params.recording.shareTreasuryCapId,
      compositionShareType: params.composition.shareType,
      composition: comp.composition,
      maxRoyaltyRateBps: params.royaltyRateBps,
      misoPackageId: params.misoPackageId,
    });

    finalizeComposition(tx, {
      ...comp,
      shareType: params.composition.shareType,
      shareRecipients: params.composition.shareRecipients,
      adminAddress: params.composition.adminAddress,
      misoPackageId: params.misoPackageId,
      minatoPackageId: params.minatoPackageId,
    });

    finalizeRecording(tx, {
      ...rec,
      recordingShareType: params.recording.shareType,
      compositionShareType: params.composition.shareType,
      shareRecipients: params.recording.shareRecipients,
      adminAddress: params.recording.adminAddress,
      misoPackageId: params.misoPackageId,
      minatoPackageId: params.minatoPackageId,
    });
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
  misoPackageId: string;
}

export function createDeal(params: CreateDealParams): TxThunk {
  if (!params.recordingAdminCap && !params.recordingAdminCapId) {
    throw new Error("createDeal: recordingAdminCapId or recordingAdminCap required");
  }
  return (tx) => {
    const adminCapArg = params.recordingAdminCap ?? tx.object(params.recordingAdminCapId!);
    const dealArg = tx.add(
      deal._new({
        package: params.misoPackageId,
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
  misoPackageId: string;
}

/** Rejects (destroys) a deal without including it in a release. Emits `DealRejectedEvent`. */
export function rejectDeal(params: RejectDealParams): TxThunk {
  return (tx) => {
    tx.add(deal.reject({
      package: params.misoPackageId,
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

export interface PublishReleaseParams {
  title: string;
  /** The ordered tracklist. Display grouping (discs/sides) is extension data. */
  tracks: TrackInput[];
  releaseRegistryId: string;
  releaseId: string;
  releaseNonce: string;
  misoPackageId: string;
  adminAddress: string;
}

function buildTrackVec(
  tx: Transaction,
  misoPackageId: string,
  trackArgs: TransactionObjectArgument[],
) {
  return tx.makeMoveVec({ type: `${misoPackageId}::track::Track`, elements: trackArgs });
}

export function publishRelease(params: PublishReleaseParams): TxThunk {
  return (tx) => {
    const { misoPackageId } = params;
    const trackArgs = params.tracks.map((t) => {
      const typeArguments: [string, string] = [t.recordingShareType, t.compositionShareType];
      const dealArg = tx.add(
        deal._new({
          package: misoPackageId,
          typeArguments,
          arguments: [tx.object(t.recordingAdminCapId), tx.object(t.recordingId), tx.pure.id(params.releaseId), tx.pure.u16(t.splitBps)],
        }),
      );
      return tx.add(track._new({ package: misoPackageId, typeArguments, arguments: [dealArg, tx.object(t.recordingId)] }));
    });
    buildAndPublishRelease(tx, misoPackageId, {
      title: params.title,
      nonce: params.releaseNonce,
      releaseRegistryId: params.releaseRegistryId,
      adminAddress: params.adminAddress,
    }, buildTrackVec(tx, misoPackageId, trackArgs));
  };
}

export interface DealInput {
  dealId: string;
  /** The recording the deal is for — `track::new` takes `&Recording` alongside the deal. */
  recordingId: string;
  /** Share type of the recording (the deal/track `RecordingShare` phantom). */
  recordingShareType: string;
  /** Share type of the parent composition (the deal/track `CompositionShare` phantom). */
  compositionShareType: string;
}

export interface PublishReleaseFromDealsParams {
  title: string;
  /** The ordered tracklist, one pre-made deal per track. */
  deals: DealInput[];
  releaseRegistryId: string;
  releaseNonce: string;
  misoPackageId: string;
  adminAddress: string;
}

export function publishReleaseFromDeals(params: PublishReleaseFromDealsParams): TxThunk {
  return (tx) => {
    const { misoPackageId } = params;
    const trackArgs = params.deals.map((dl) =>
      tx.add(track._new({
        package: misoPackageId,
        typeArguments: [dl.recordingShareType, dl.compositionShareType],
        arguments: [tx.object(dl.dealId), tx.object(dl.recordingId)],
      })),
    );
    buildAndPublishRelease(tx, misoPackageId, {
      title: params.title,
      nonce: params.releaseNonce,
      releaseRegistryId: params.releaseRegistryId,
      adminAddress: params.adminAddress,
    }, buildTrackVec(tx, misoPackageId, trackArgs));
  };
}

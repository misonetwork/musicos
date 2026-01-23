// Copyright (c) Studio Mirai, LLC
// SPDX-License-Identifier: Apache-2.0

import { Transaction } from "@mysten/sui/transactions";
import type {
  CreateCompositionParams,
  PublishCompositionParams,
  AddCompositionCreditParams,
  SetCompositionSplitParams,
  AddAlternateTitleParams,
  SetLyricsParams,
} from "../types/composition.js";
import { makeCompositionCredit, makeWalrusData } from "../utils/move-call.js";
import { SUI_CLOCK_OBJECT_ID } from "../utils/type-args.js";

/**
 * Client for managing compositions.
 */
export class CompositionClient {
  constructor(private readonly packageId: string) {}

  /**
   * Create a new composition.
   * Returns a transaction that creates the composition, admin cap, and share balance.
   *
   * Note: Caller must have already created the share currency and treasury cap.
   */
  create(params: CreateCompositionParams): Transaction {
    const tx = new Transaction();

    const [composition, adminCap, shareBalance] = tx.moveCall({
      target: `${this.packageId}::composition::new`,
      typeArguments: [params.shareType],
      arguments: [
        tx.pure.string(params.title),
        tx.pure.u64(params.splitBps),
        tx.object(params.shareCurrencyId),
        tx.object(params.shareTreasuryCapId),
      ],
    });

    // Convert balance to coin and transfer all to sender
    const shareCoin = tx.moveCall({
      target: "0x2::coin::from_balance",
      typeArguments: [params.shareType],
      arguments: [shareBalance],
    });

    tx.transferObjects([composition, adminCap, shareCoin], tx.pure.address("@sender"));

    return tx;
  }

  /**
   * Publish a composition (makes it immutable and shared).
   * Requires at least one contributor.
   */
  publish(params: PublishCompositionParams): Transaction {
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.packageId}::composition::publish`,
      typeArguments: [params.shareType],
      arguments: [
        tx.object(params.compositionId),
        tx.object(params.adminCapId),
        tx.object(SUI_CLOCK_OBJECT_ID),
      ],
    });

    return tx;
  }

  /**
   * Add a credit (contributor with roles) to a composition.
   */
  addCredit(params: AddCompositionCreditParams): Transaction {
    const tx = new Transaction();

    const credit = makeCompositionCredit(tx, this.packageId, params.credit);

    tx.moveCall({
      target: `${this.packageId}::composition::add_credit`,
      typeArguments: [params.shareType],
      arguments: [
        tx.object(params.compositionId),
        tx.object(params.adminCapId),
        tx.object(params.contributorId),
        credit,
      ],
    });

    return tx;
  }

  /**
   * Set the revenue split for this composition.
   */
  setSplitBps(params: SetCompositionSplitParams): Transaction {
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.packageId}::composition::set_split_bps`,
      typeArguments: [params.shareType],
      arguments: [
        tx.object(params.compositionId),
        tx.object(params.adminCapId),
        tx.pure.u64(params.splitBps),
      ],
    });

    return tx;
  }

  /**
   * Add an alternate title to the composition.
   */
  addAlternateTitle(params: AddAlternateTitleParams): Transaction {
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.packageId}::composition::add_alternate_title`,
      typeArguments: [params.shareType],
      arguments: [
        tx.object(params.compositionId),
        tx.object(params.adminCapId),
        tx.pure.string(params.title),
      ],
    });

    return tx;
  }

  /**
   * Set the lyrics data reference.
   */
  setLyrics(params: SetLyricsParams): Transaction {
    const tx = new Transaction();

    const walrusData = makeWalrusData(tx, this.packageId, params.lyrics);

    tx.moveCall({
      target: `${this.packageId}::composition::set_lyrics`,
      typeArguments: [params.shareType],
      arguments: [
        tx.object(params.compositionId),
        tx.object(params.adminCapId),
        walrusData,
      ],
    });

    return tx;
  }
}

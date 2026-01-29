// Copyright (c) Studio Mirai, LLC
// SPDX-License-Identifier: Apache-2.0

import { Transaction } from "@mysten/sui/transactions";
import type {
  CreateCompositionParams,
  PublishCompositionParams,
  AddCompositionCreditParams,
  SetCompositionSplitParams,
  AddAlternateTitleParams,
  AddLyricLinesParams,
} from "../types/composition.js";
import { makeCompositionCredit } from "../utils/move-call.js";
import { SUI_CLOCK_OBJECT_ID } from "../utils/type-args.js";
import {
  AddAlternateTitleParamsSchema,
  AddCompositionCreditParamsSchema,
  AddLyricLinesParamsSchema,
  CreateCompositionParamsSchema,
  PublishCompositionParamsSchema,
  SetCompositionSplitParamsSchema,
} from "../schemas/composition.js";

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
    const parsed = CreateCompositionParamsSchema.parse(params);
    const tx = new Transaction();

    const [composition, adminCap, shareBalance] = tx.moveCall({
      target: `${this.packageId}::composition::new`,
      typeArguments: [parsed.shareType],
      arguments: [
        tx.pure.string(parsed.title),
        tx.pure.u64(parsed.splitBps),
        tx.object(parsed.shareCurrencyId),
        tx.object(parsed.shareTreasuryCapId),
      ],
    });

    // Convert balance to coin and transfer all to sender
    const shareCoin = tx.moveCall({
      target: "0x2::coin::from_balance",
      typeArguments: [parsed.shareType],
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
    const parsed = PublishCompositionParamsSchema.parse(params);
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.packageId}::composition::publish`,
      typeArguments: [parsed.shareType],
      arguments: [
        tx.object(parsed.compositionId),
        tx.object(parsed.adminCapId),
        tx.object(SUI_CLOCK_OBJECT_ID),
      ],
    });

    return tx;
  }

  /**
   * Add a credit (contributor with roles) to a composition.
   */
  addCredit(params: AddCompositionCreditParams): Transaction {
    const parsed = AddCompositionCreditParamsSchema.parse(params);
    const tx = new Transaction();

    const credit = makeCompositionCredit(tx, this.packageId, parsed.credit);

    tx.moveCall({
      target: `${this.packageId}::composition::add_credit`,
      typeArguments: [parsed.shareType],
      arguments: [
        tx.object(parsed.compositionId),
        tx.object(parsed.adminCapId),
        tx.object(parsed.contributorId),
        credit,
      ],
    });

    return tx;
  }

  /**
   * Set the revenue split for this composition.
   */
  setSplitBps(params: SetCompositionSplitParams): Transaction {
    const parsed = SetCompositionSplitParamsSchema.parse(params);
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.packageId}::composition::set_split_bps`,
      typeArguments: [parsed.shareType],
      arguments: [
        tx.object(parsed.compositionId),
        tx.object(parsed.adminCapId),
        tx.pure.u64(parsed.splitBps),
      ],
    });

    return tx;
  }

  /**
   * Add an alternate title to the composition.
   */
  addAlternateTitle(params: AddAlternateTitleParams): Transaction {
    const parsed = AddAlternateTitleParamsSchema.parse(params);
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.packageId}::composition::add_alternate_title`,
      typeArguments: [parsed.shareType],
      arguments: [
        tx.object(parsed.compositionId),
        tx.object(parsed.adminCapId),
        tx.pure.string(parsed.title),
      ],
    });

    return tx;
  }

  /**
   * Add lyric lines.
   */
  addLyricLines(params: AddLyricLinesParams): Transaction {
    const parsed = AddLyricLinesParamsSchema.parse(params);
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.packageId}::composition::add_lyric_lines`,
      typeArguments: [parsed.shareType],
      arguments: [
        tx.object(parsed.compositionId),
        tx.object(parsed.adminCapId),
        tx.pure.vector("string", parsed.lines),
      ],
    });

    return tx;
  }
}

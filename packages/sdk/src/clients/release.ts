// Copyright (c) Studio Mirai, LLC
// SPDX-License-Identifier: Apache-2.0

import { Transaction } from "@mysten/sui/transactions";
import type {
  CreateReleaseParams,
  PublishReleaseParams,
  SetTrackSplitsParams,
  DistributeRevenueParams,
  Disc,
  Track,
} from "../types/release.js";
import { makeCoverArt, makeReleaseKind } from "../utils/move-call.js";
import { SUI_CLOCK_OBJECT_ID } from "../utils/type-args.js";
import {
  CreateReleaseParamsSchema,
  DistributeRevenueParamsSchema,
  PublishReleaseParamsSchema,
  SetTrackSplitsParamsSchema,
} from "../schemas/release.js";

/**
 * Client for managing releases.
 */
export class ReleaseClient {
  constructor(private readonly packageId: string) {}

  /**
   * Create a new release.
   * Returns a transaction that creates the release and admin capability.
   */
  create(params: CreateReleaseParams): Transaction {
    const parsed = CreateReleaseParamsSchema.parse(params);
    const tx = new Transaction();

    const coverArt = makeCoverArt(tx, this.packageId, parsed.coverArt);

    // Build discs
    const discs = parsed.discs.map((disc) => this.makeDisc(tx, disc));
    const discsVec = tx.makeMoveVec({
      type: `${this.packageId}::disc::Disc`,
      elements: discs,
    });

    // Create release kind
    const kind = makeReleaseKind(tx, parsed.kind);

    const [release, adminCap] = tx.moveCall({
      target: `${this.packageId}::release::new`,
      arguments: [kind, tx.pure.string(parsed.title), coverArt, discsVec],
    });

    tx.transferObjects([release, adminCap], tx.pure.address("@sender"));

    return tx;
  }

  /**
   * Publish a release (makes it immutable and shared).
   * Track splits must be set first.
   */
  publish(params: PublishReleaseParams): Transaction {
    const parsed = PublishReleaseParamsSchema.parse(params);
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.packageId}::release::publish`,
      arguments: [
        tx.object(parsed.releaseId),
        tx.object(parsed.adminCapId),
        tx.object(SUI_CLOCK_OBJECT_ID),
      ],
    });

    return tx;
  }

  /**
   * Set the revenue splits for each track.
   * Splits must sum to 10000 (100%).
   */
  setTrackSplitsBps(params: SetTrackSplitsParams): Transaction {
    const parsed = SetTrackSplitsParamsSchema.parse(params);
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.packageId}::release::set_track_splits_bps`,
      arguments: [
        tx.object(parsed.releaseId),
        tx.object(parsed.adminCapId),
        tx.pure.vector("u64", parsed.splits),
      ],
    });

    return tx;
  }

  /**
   * Distribute revenue from the release to composition and recording pools.
   */
  distributeRevenue(params: DistributeRevenueParams): Transaction {
    const parsed = DistributeRevenueParamsSchema.parse(params);
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.packageId}::release::distribute_revenue`,
      typeArguments: [parsed.coinType],
      arguments: [tx.object(parsed.releaseId), tx.pure.u64(parsed.amount)],
    });

    return tx;
  }

  /**
   * Build a Disc Move object from SDK types.
   */
  private makeDisc(
    tx: Transaction,
    disc: Disc
  ): ReturnType<typeof tx.moveCall> {
    const tracks = disc.tracks.map((track) => this.makeTrack(tx, track));
    const tracksVec = tx.makeMoveVec({
      type: `${this.packageId}::track::Track`,
      elements: tracks,
    });

    const discObj = tx.moveCall({
      target: `${this.packageId}::disc::new`,
      arguments: [tracksVec],
    });

    // Set artwork if provided
    if (disc.artwork) {
      tx.moveCall({
        target: `${this.packageId}::disc::set_artwork`,
        arguments: [discObj, tx.pure.string(disc.artwork)],
      });
    }

    return discObj;
  }

  /**
   * Build a Track Move object from SDK types.
   */
  private makeTrack(
    tx: Transaction,
    track: Track
  ): ReturnType<typeof tx.moveCall> {
    let coverArtOption;
    if (track.coverArt) {
      const coverArt = makeCoverArt(tx, this.packageId, track.coverArt);
      coverArtOption = tx.moveCall({
        target: "0x1::option::some",
        typeArguments: [`${this.packageId}::cover_art::CoverArt`],
        arguments: [coverArt],
      });
    } else {
      coverArtOption = tx.moveCall({
        target: "0x1::option::none",
        typeArguments: [`${this.packageId}::cover_art::CoverArt`],
      });
    }

    return tx.moveCall({
      target: `${this.packageId}::track::new`,
      typeArguments: [track.recordingShareType],
      arguments: [
        tx.object(track.recordingAdminCapId),
        tx.object(track.recordingId),
        coverArtOption,
      ],
    });
  }
}

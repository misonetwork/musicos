// Copyright (c) Studio Mirai, LLC
// SPDX-License-Identifier: Apache-2.0

import type { CoverArt } from "./common.js";

/**
 * Type of release.
 */
export type ReleaseKind = "album" | "ep" | "single";

/**
 * A track on a release.
 */
export interface Track {
  /** Recording object ID */
  recordingId: string;
  /** Recording admin cap object ID */
  recordingAdminCapId: string;
  /** Recording share type string */
  recordingShareType: string;
  /** Optional cover art override */
  coverArt?: CoverArt;
}

/**
 * A disc containing tracks.
 */
export interface Disc {
  /** Tracks on this disc (max 50) */
  tracks: Track[];
  /** Optional disc-specific artwork URL */
  artwork?: string;
}

/**
 * Parameters for creating a new release.
 */
export interface CreateReleaseParams {
  /** Type of release */
  kind: ReleaseKind;
  /** Release title */
  title: string;
  /** Cover artwork */
  coverArt: CoverArt;
  /** Discs containing tracks (max 20 discs) */
  discs: Disc[];
}

/**
 * Parameters for publishing a release.
 */
export interface PublishReleaseParams {
  /** Release object ID */
  releaseId: string;
  /** Admin capability object ID */
  adminCapId: string;
}

/**
 * Parameters for setting track splits.
 */
export interface SetTrackSplitsParams {
  /** Release object ID */
  releaseId: string;
  /** Admin capability object ID */
  adminCapId: string;
  /** Split values in basis points (must sum to 10000) */
  splits: number[];
}

/**
 * Parameters for distributing revenue.
 */
export interface DistributeRevenueParams {
  /** Release object ID */
  releaseId: string;
  /** Coin type string */
  coinType: string;
  /** Amount to distribute */
  amount: bigint;
}

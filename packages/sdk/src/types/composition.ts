// Copyright (c) Studio Mirai, LLC
// SPDX-License-Identifier: Apache-2.0

/**
 * Roles a contributor can have on a composition.
 */
export type CompositionRole =
  | "adapter"
  | "arranger"
  | "composer"
  | "lyricist"
  | "songwriter"
  | "translator";

/**
 * Credit for a contributor on a composition.
 */
export interface CompositionCredit {
  /** Display name for this credit */
  displayName: string;
  /** Roles held (1-20) */
  roles: CompositionRole[];
}

/**
 * Parameters for creating a new composition.
 */
export interface CreateCompositionParams {
  /** Primary title */
  title: string;
  /** Revenue split to composition in basis points (0-10000) */
  splitBps: number;
  /** Share currency object ID */
  shareCurrencyId: string;
  /** Share treasury cap object ID */
  shareTreasuryCapId: string;
  /** Share type string (e.g., "0xabc::my_share::SHARE") */
  shareType: string;
}

/**
 * Parameters for publishing a composition.
 */
export interface PublishCompositionParams {
  /** Composition object ID */
  compositionId: string;
  /** Admin capability object ID */
  adminCapId: string;
  /** Share type string */
  shareType: string;
}

/**
 * Parameters for adding a credit to a composition.
 */
export interface AddCompositionCreditParams {
  /** Composition object ID */
  compositionId: string;
  /** Admin capability object ID */
  adminCapId: string;
  /** Contributor object ID */
  contributorId: string;
  /** Credit details */
  credit: CompositionCredit;
  /** Share type string */
  shareType: string;
}

/**
 * Parameters for setting composition split.
 */
export interface SetCompositionSplitParams {
  /** Composition object ID */
  compositionId: string;
  /** Admin capability object ID */
  adminCapId: string;
  /** Split in basis points (0-10000) */
  splitBps: number;
  /** Share type string */
  shareType: string;
}

/**
 * Parameters for adding an alternate title.
 */
export interface AddAlternateTitleParams {
  /** Composition object ID */
  compositionId: string;
  /** Admin capability object ID */
  adminCapId: string;
  /** Alternate title to add */
  title: string;
  /** Share type string */
  shareType: string;
}

/**
 * Parameters for setting lyrics.
 */
export interface AddLyricLinesParams {
  /** Composition object ID */
  compositionId: string;
  /** Admin capability object ID */
  adminCapId: string;
  /** Lyric lines to append */
  lines: string[];
  /** Share type string */
  shareType: string;
}

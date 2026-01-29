// Copyright (c) Studio Mirai, LLC
// SPDX-License-Identifier: Apache-2.0

/**
 * Default genres available in MusicOS.
 */
export const DEFAULT_GENRES = [
  "AFRICAN",
  "AFROBEATS",
  "ALTERNATIVE",
  "AMBIENT",
  "ANIME",
  "ARABIC",
  "ASIAN",
  "BLUES",
  "CLASSICAL",
  "COUNTRY",
  "DANCE",
  "ELECTRONIC",
  "FOLK",
  "HIP_HOP",
  "JAZZ",
  "LATIN",
  "METAL",
  "POP",
  "R&B",
  "REGGAE",
  "ROCK",
] as const;

export type DefaultGenre = (typeof DEFAULT_GENRES)[number];

/**
 * Parameters for creating a new genre.
 */
export interface CreateGenreParams {
  /** Genre name (A-Z, _, & only) */
  name: string;
  /** Genre registry object ID */
  registryId: string;
}

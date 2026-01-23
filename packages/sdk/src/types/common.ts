// Copyright (c) Studio Mirai, LLC
// SPDX-License-Identifier: Apache-2.0

/**
 * Walrus storage data reference.
 */
export interface WalrusData {
  /** Walrus blob ID */
  blobId: string;
  /** Epoch when the blob expires */
  endEpoch: number;
}

/**
 * Cover artwork with required static image and optional animation.
 */
export interface CoverArt {
  /** Required static image */
  static: WalrusData;
  /** Optional animated version (GIF, video) */
  animated?: WalrusData;
}

/**
 * Musical note letters.
 */
export type Note = "C" | "D" | "E" | "F" | "G" | "A" | "B";

/**
 * Pitch modifiers.
 */
export type Accidental = "natural" | "sharp" | "flat";

/**
 * Musical modes.
 */
export type Mode = "major" | "minor";

/**
 * Musical key combining root note, accidental, and mode.
 */
export interface MusicalKey {
  note: Note;
  accidental: Accidental;
  mode: Mode;
}

/**
 * Time signature as beats per measure over beat unit.
 */
export interface TimeSignature {
  /** Number of beats per measure */
  beatsPerMeasure: number;
  /** Note value that gets one beat (4 = quarter, 8 = eighth) */
  beatUnit: number;
}

/**
 * SDK configuration options.
 */
export interface MusicOSConfig {
  /** MusicOS package ID */
  packageId: string;
  /** Optional extensions package ID */
  extensionsPackageId?: string;
  /** Genre registry object ID */
  genreRegistryId?: string;
}

/**
 * Network presets.
 */
export type NetworkPreset = "mainnet" | "testnet" | "devnet" | "localnet";

/**
 * Result from object creation containing IDs.
 */
export interface CreateResult {
  /** Object ID of the created entity */
  objectId: string;
  /** Admin capability object ID */
  adminCapId: string;
}

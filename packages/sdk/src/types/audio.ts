// Copyright (c) Studio Mirai, LLC
// SPDX-License-Identifier: Apache-2.0

import type { WalrusData } from "./common.js";

/**
 * Audio file metadata.
 */
export interface Audio {
  /** Number of channels (1 = mono, 2 = stereo) */
  channels: number;
  /** Bit depth (8, 16, 24, or 32) */
  bitDepth: number;
  /** Sample rate in Hz */
  sampleRateHz: number;
  /** Total number of samples */
  samples: bigint;
  /** Walrus storage reference */
  data: WalrusData;
  /** PCM content digest (32 bytes) for integrity verification */
  pcmDigest: Uint8Array;
}

/**
 * An audio stem with description.
 */
export interface Stem {
  /** Audio data */
  audio: Audio;
  /** Description of the stem (e.g., "Vocals", "Drums") */
  description: string;
  /** Optional contributor IDs associated with this stem */
  contributors?: string[];
}

/**
 * Calculate duration in milliseconds from audio parameters.
 */
export function calculateDurationMs(audio: Audio): bigint {
  return (audio.samples * 1000n) / BigInt(audio.sampleRateHz);
}

/**
 * Calculate duration in seconds from audio parameters.
 */
export function calculateDurationSeconds(audio: Audio): bigint {
  return audio.samples / BigInt(audio.sampleRateHz);
}

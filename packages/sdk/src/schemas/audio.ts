// Copyright (c) Studio Mirai, LLC
// SPDX-License-Identifier: Apache-2.0

import { z } from "zod";
import { CoverArtSchema, WalrusDataSchema } from "./common.js";
import { IdSchema, U32Schema, U64Schema, U8Schema } from "./primitives.js";

const PcmDigestSchema = z
  .instanceof(Uint8Array)
  .refine((value) => value.length === 32, {
    message: "pcmDigest must be 32 bytes",
  });

export const AudioSchema = z.object({
  channels: U8Schema.refine((value) => value > 0, {
    message: "channels must be > 0",
  }),
  bitDepth: z.union([
    z.literal(8),
    z.literal(16),
    z.literal(24),
    z.literal(32),
  ]),
  sampleRateHz: U32Schema.refine((value) => value > 0, {
    message: "sampleRateHz must be > 0",
  }),
  samples: U64Schema.refine((value) => value > 0n, {
    message: "samples must be > 0",
  }),
  data: WalrusDataSchema,
  pcmDigest: PcmDigestSchema,
});

export const StemSchema = z.object({
  audio: AudioSchema,
  description: z.string().min(1),
  contributors: z.array(IdSchema).default([]),
});

export const CoverArtOrNullSchema = CoverArtSchema.nullish();

// Copyright (c) Studio Mirai, LLC
// SPDX-License-Identifier: Apache-2.0

import { z } from "zod";
import { NonEmptyStringSchema, U8Schema } from "./primitives.js";

export const WalrusDataSchema = z.object({
  blobId: NonEmptyStringSchema,
  endEpoch: z.number().int().nonnegative(),
});

export const CoverArtSchema = z.object({
  static: WalrusDataSchema,
  animated: WalrusDataSchema.optional(),
});

export const MusicalKeySchema = z.object({
  note: z.enum(["C", "D", "E", "F", "G", "A", "B"]),
  accidental: z.enum(["natural", "sharp", "flat"]),
  mode: z.enum(["major", "minor"]),
});

export const TimeSignatureSchema = z.object({
  beatsPerMeasure: U8Schema.refine((value) => value > 0, {
    message: "beatsPerMeasure must be > 0",
  }),
  beatUnit: U8Schema.refine((value) => value > 0, {
    message: "beatUnit must be > 0",
  }),
});

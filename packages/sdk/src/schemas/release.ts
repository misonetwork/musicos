// Copyright (c) Studio Mirai, LLC
// SPDX-License-Identifier: Apache-2.0

import { z } from "zod";
import { CoverArtSchema } from "./common.js";
import { IdSchema, NonEmptyStringSchema } from "./primitives.js";

export const ReleaseKindSchema = z.enum(["album", "ep", "single"]);

export const TrackSchema = z.object({
  recordingId: IdSchema,
  recordingAdminCapId: IdSchema,
  recordingShareType: NonEmptyStringSchema,
  coverArt: CoverArtSchema.optional(),
});

export const DiscSchema = z.object({
  tracks: z.array(TrackSchema).max(50),
  artwork: z.string().optional(),
});

export const CreateReleaseParamsSchema = z.object({
  kind: ReleaseKindSchema,
  title: NonEmptyStringSchema,
  coverArt: CoverArtSchema,
  discs: z.array(DiscSchema).max(20),
});

export const PublishReleaseParamsSchema = z.object({
  releaseId: IdSchema,
  adminCapId: IdSchema,
});

export const SetTrackSplitsParamsSchema = z.object({
  releaseId: IdSchema,
  adminCapId: IdSchema,
  splits: z.array(z.number().int().min(0)),
});

export const DistributeRevenueParamsSchema = z.object({
  releaseId: IdSchema,
  coinType: NonEmptyStringSchema,
  amount: z.bigint(),
});

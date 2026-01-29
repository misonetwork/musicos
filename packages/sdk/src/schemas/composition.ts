// Copyright (c) Studio Mirai, LLC
// SPDX-License-Identifier: Apache-2.0

import { z } from "zod";
import { IdSchema, NonEmptyStringSchema } from "./primitives.js";

export const CompositionRoleSchema = z.enum([
  "adapter",
  "arranger",
  "composer",
  "lyricist",
  "songwriter",
  "translator",
]);

export const CompositionCreditSchema = z.object({
  displayName: NonEmptyStringSchema,
  roles: z.array(CompositionRoleSchema).min(1).max(20),
});

export const CreateCompositionParamsSchema = z.object({
  title: NonEmptyStringSchema,
  splitBps: z.number().int().min(0).max(10000),
  shareCurrencyId: IdSchema,
  shareTreasuryCapId: IdSchema,
  shareType: NonEmptyStringSchema,
});

export const PublishCompositionParamsSchema = z.object({
  compositionId: IdSchema,
  adminCapId: IdSchema,
  shareType: NonEmptyStringSchema,
});

export const AddCompositionCreditParamsSchema = z.object({
  compositionId: IdSchema,
  adminCapId: IdSchema,
  contributorId: IdSchema,
  credit: CompositionCreditSchema,
  shareType: NonEmptyStringSchema,
});

export const SetCompositionSplitParamsSchema = z.object({
  compositionId: IdSchema,
  adminCapId: IdSchema,
  splitBps: z.number().int().min(0).max(10000),
  shareType: NonEmptyStringSchema,
});

export const AddAlternateTitleParamsSchema = z.object({
  compositionId: IdSchema,
  adminCapId: IdSchema,
  title: NonEmptyStringSchema,
  shareType: NonEmptyStringSchema,
});

export const AddLyricLinesParamsSchema = z.object({
  compositionId: IdSchema,
  adminCapId: IdSchema,
  lines: z.array(NonEmptyStringSchema),
  shareType: NonEmptyStringSchema,
});

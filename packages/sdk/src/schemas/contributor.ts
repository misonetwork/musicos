// Copyright (c) Studio Mirai, LLC
// SPDX-License-Identifier: Apache-2.0

import { z } from "zod";
import { IdSchema, NonEmptyStringSchema } from "./primitives.js";

export const ContributorKindSchema = z.enum(["individual", "group"]);

export const CreateContributorParamsSchema = z.object({
  kind: ContributorKindSchema,
  name: NonEmptyStringSchema,
});

export const ShareContributorParamsSchema = z.object({
  contributorId: IdSchema,
  adminCapId: IdSchema,
});

export const SetContributorNameParamsSchema = z.object({
  contributorId: IdSchema,
  adminCapId: IdSchema,
  name: NonEmptyStringSchema,
});

export const AddGroupMemberParamsSchema = z.object({
  groupId: IdSchema,
  adminCapId: IdSchema,
  memberId: IdSchema,
});

export const RemoveGroupMemberParamsSchema = z.object({
  groupId: IdSchema,
  adminCapId: IdSchema,
  memberId: IdSchema,
});

// Copyright (c) Studio Mirai, LLC
// SPDX-License-Identifier: Apache-2.0

import { z } from "zod";
import { IdSchema, NonEmptyStringSchema } from "./primitives.js";

export const CreateGenreParamsSchema = z.object({
  name: NonEmptyStringSchema.regex(/^[A-Z_&]+$/, {
    message: "name must contain only A-Z, _, &",
  }),
  registryId: IdSchema,
});

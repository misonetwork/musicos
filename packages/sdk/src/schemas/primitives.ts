// Copyright (c) Studio Mirai, LLC
// SPDX-License-Identifier: Apache-2.0

import { z } from "zod";

export const NonEmptyStringSchema = z.string().min(1);
export const IdSchema = NonEmptyStringSchema;

export const U8Schema = z.number().int().nonnegative().max(255);
export const U16Schema = z.number().int().nonnegative().max(65535);
export const U32Schema = z.number().int().nonnegative().max(0xffffffff);

export const U64Schema = z
  .union([z.bigint(), z.number().int().nonnegative()])
  .transform((value) => (typeof value === "number" ? BigInt(value) : value));

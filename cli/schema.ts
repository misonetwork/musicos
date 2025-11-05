import { z } from "zod";

export const createCompositionParamsSchema = z.object({
  commissionRate: z.number().min(0).max(10_000),
  title: z.string().min(1),
});

export const createRecordingParamsSchema = z.object({
  title: z.string().min(1),
  compositionId: z.string().min(66).startsWith("0x"),
});

export type CreateCompositionParams = z.infer<
  typeof createCompositionParamsSchema
>;

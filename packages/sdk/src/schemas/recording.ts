// Copyright (c) Studio Mirai, LLC
// SPDX-License-Identifier: Apache-2.0

import { z } from "zod";
import { AudioSchema, StemSchema } from "./audio.js";
import { CoverArtSchema, MusicalKeySchema, TimeSignatureSchema } from "./common.js";
import { IdSchema, NonEmptyStringSchema, U16Schema } from "./primitives.js";

export const RecordingContributorLevelSchema = z.enum([
  "additional",
  "assistant",
  "associate",
  "backing",
  "executive",
  "featured",
  "lead",
  "primary",
  "principal",
]);

export const RecordingRoleTypeSchema = z.enum([
  "actor",
  "arranger",
  "artists_and_repertoire",
  "choir",
  "choir_master",
  "conductor",
  "contractor",
  "copyist",
  "editor",
  "ensemble",
  "instrumentalist",
  "mastering_engineer",
  "mixing_engineer",
  "music_director",
  "music_supervisor",
  "narrator",
  "orchestra",
  "orchestrator",
  "producer",
  "programmer",
  "recording_engineer",
  "remixing_engineer",
  "sound_designer",
  "vocalist",
]);

const RecordingRoleWithLevelSchema = z.object({
  type: z.enum([
    "actor",
    "arranger",
    "choir",
    "choir_master",
    "conductor",
    "contractor",
    "editor",
    "ensemble",
    "mastering_engineer",
    "mixing_engineer",
    "music_director",
    "music_supervisor",
    "narrator",
    "orchestra",
    "orchestrator",
    "producer",
    "programmer",
    "recording_engineer",
    "remixing_engineer",
    "sound_designer",
    "vocalist",
  ]),
  level: RecordingContributorLevelSchema.optional(),
});

export const RecordingRoleSchema = z.discriminatedUnion("type", [
  z.object({ type: z.literal("artists_and_repertoire") }),
  z.object({ type: z.literal("copyist") }),
  z.object({
    type: z.literal("instrumentalist"),
    instrument: NonEmptyStringSchema,
    level: RecordingContributorLevelSchema.optional(),
  }),
  RecordingRoleWithLevelSchema,
]);

export const RecordingCreditSchema = z.object({
  displayName: NonEmptyStringSchema,
  roles: z.array(RecordingRoleSchema).min(1).max(10),
});

export const CreateRecordingParamsSchema = z.object({
  compositionId: IdSchema,
  compositionShareType: NonEmptyStringSchema,
  genreId: IdSchema,
  isExplicit: z.boolean(),
  isInstrumental: z.boolean(),
  master: AudioSchema,
  coverArt: CoverArtSchema,
  shareCurrencyId: IdSchema,
  shareTreasuryCapId: IdSchema,
  shareType: NonEmptyStringSchema,
});

export const PublishRecordingParamsSchema = z.object({
  recordingId: IdSchema,
  adminCapId: IdSchema,
  shareType: NonEmptyStringSchema,
});

export const SetTitleVersionParamsSchema = z.object({
  recordingId: IdSchema,
  adminCapId: IdSchema,
  version: NonEmptyStringSchema,
  shareType: NonEmptyStringSchema,
});

export const SetSubtitleParamsSchema = z.object({
  recordingId: IdSchema,
  adminCapId: IdSchema,
  subtitle: NonEmptyStringSchema,
  shareType: NonEmptyStringSchema,
});

export const SetLanguageParamsSchema = z.object({
  recordingId: IdSchema,
  adminCapId: IdSchema,
  language: NonEmptyStringSchema,
  shareType: NonEmptyStringSchema,
});

export const AddRecordingCreditParamsSchema = z.object({
  recordingId: IdSchema,
  adminCapId: IdSchema,
  contributorId: IdSchema,
  credit: RecordingCreditSchema,
  shareType: NonEmptyStringSchema,
});

export const RecordingArtistParamsSchema = z.object({
  recordingId: IdSchema,
  adminCapId: IdSchema,
  contributorId: IdSchema,
  shareType: NonEmptyStringSchema,
});

export const RecordingGenreParamsSchema = z.object({
  recordingId: IdSchema,
  adminCapId: IdSchema,
  genreId: IdSchema,
  shareType: NonEmptyStringSchema,
});

export const SetMusicalKeyParamsSchema = z.object({
  recordingId: IdSchema,
  adminCapId: IdSchema,
  key: MusicalKeySchema,
  shareType: NonEmptyStringSchema,
});

export const SetTimeSignatureParamsSchema = z.object({
  recordingId: IdSchema,
  adminCapId: IdSchema,
  timeSignature: TimeSignatureSchema,
  shareType: NonEmptyStringSchema,
});

export const SetTempoParamsSchema = z.object({
  recordingId: IdSchema,
  adminCapId: IdSchema,
  bpm: U16Schema.refine((value) => value > 0, { message: "bpm must be > 0" }),
  shareType: NonEmptyStringSchema,
});

export const AddStemParamsSchema = z.object({
  recordingId: IdSchema,
  adminCapId: IdSchema,
  stem: StemSchema,
  shareType: NonEmptyStringSchema,
});

export const RecordingBuilderParamsSchema = CreateRecordingParamsSchema.omit({
  isExplicit: true,
  isInstrumental: true,
});

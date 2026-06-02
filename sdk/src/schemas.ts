// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

import { z } from "zod";
import { isValidSuiObjectId } from "@mysten/sui/utils";

// ============================================================================
// Walrus Storage
// ============================================================================

export const WalrusDataSchema = z.object({
  blobId: z.string().regex(/^\d+$/, "Blob ID must be a decimal string"),
});

// ============================================================================
// Party
// ============================================================================

export const PartyKindSchema = z.discriminatedUnion("type", [
  z.object({ type: z.literal("Individual") }),
  z.object({
    type: z.literal("Group"),
    memberIds: z.array(z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"))
      .min(1, "Group must have at least one member"),
  }),
]);

export const PartySchema = z.object({
  id: z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
  kind: PartyKindSchema,
  name: z.string().min(1, "Party name cannot be empty"),
});

// ============================================================================
// Audio
// ============================================================================

export const AudioSchema = z.object({
  ingester: z.string().min(1, "Ingester type cannot be empty"),
  format: z.string()
    .min(1, "Format cannot be empty")
    .max(16, "Format cannot exceed 16 bytes")
    .regex(/^[a-z0-9]+$/, "Format must be lowercase a-z and 0-9 only"),
  channels: z.number().int().min(1, "Audio must have at least 1 channel").max(255),
  bitDepth: z.union([z.literal(8), z.literal(16), z.literal(24), z.literal(32)]),
  sampleRateHz: z.number().int().min(1, "Sample rate must be greater than 0").max(4294967295),
  samples: z.number().int().min(1, "Samples must be at least 1"),
  pcmDigest: z.string().regex(/^[0-9a-f]{64}$/, "PCM digest must be 64 lowercase hex chars (BLAKE2b-256)"),
  data: WalrusDataSchema,
});

export const CoverArtSchema = z.object({
  still: WalrusDataSchema,
  animated: WalrusDataSchema.optional(),
});

// ============================================================================
// Party Roles
// ============================================================================

export const CompositionPartyRoleSchema = z.discriminatedUnion("type", [
  z.object({ type: z.literal("Adapter") }),
  z.object({ type: z.literal("Arranger") }),
  z.object({ type: z.literal("Composer") }),
  z.object({ type: z.literal("Lyricist") }),
  z.object({ type: z.literal("Songwriter") }),
  z.object({ type: z.literal("Translator") }),
]);

const recordingRoleLevelEnum = z.enum([
  "Additional", "Assistant", "Associate", "Backing", "Executive",
  "Featured", "Lead", "Primary", "Principal",
]);

export const RecordingPartyRoleSchema = z.discriminatedUnion("type", [
  z.object({ type: z.literal("Actor"), level: recordingRoleLevelEnum.optional() }),
  z.object({ type: z.literal("Arranger"), level: recordingRoleLevelEnum.optional() }),
  z.object({ type: z.literal("ArtistsAndRepertoire") }),
  z.object({ type: z.literal("Choir"), level: recordingRoleLevelEnum.optional() }),
  z.object({ type: z.literal("ChoirMaster"), level: recordingRoleLevelEnum.optional() }),
  z.object({ type: z.literal("Conductor"), level: recordingRoleLevelEnum.optional() }),
  z.object({ type: z.literal("Contractor"), level: recordingRoleLevelEnum.optional() }),
  z.object({ type: z.literal("Copyist") }),
  z.object({ type: z.literal("Editor"), level: recordingRoleLevelEnum.optional() }),
  z.object({ type: z.literal("Ensemble"), level: recordingRoleLevelEnum.optional() }),
  z.object({
    type: z.literal("Instrumentalist"),
    instrument: z.string().min(1, "Instrument cannot be empty"),
    level: recordingRoleLevelEnum.optional(),
  }),
  z.object({ type: z.literal("MasteringEngineer"), level: recordingRoleLevelEnum.optional() }),
  z.object({ type: z.literal("MixingEngineer"), level: recordingRoleLevelEnum.optional() }),
  z.object({ type: z.literal("MusicDirector"), level: recordingRoleLevelEnum.optional() }),
  z.object({ type: z.literal("MusicSupervisor"), level: recordingRoleLevelEnum.optional() }),
  z.object({ type: z.literal("Narrator"), level: recordingRoleLevelEnum.optional() }),
  z.object({ type: z.literal("Orchestra"), level: recordingRoleLevelEnum.optional() }),
  z.object({ type: z.literal("Orchestrator"), level: recordingRoleLevelEnum.optional() }),
  z.object({ type: z.literal("Producer"), level: recordingRoleLevelEnum.optional() }),
  z.object({ type: z.literal("Programmer"), level: recordingRoleLevelEnum.optional() }),
  z.object({ type: z.literal("RecordingEngineer"), level: recordingRoleLevelEnum.optional() }),
  z.object({ type: z.literal("RemixingEngineer"), level: recordingRoleLevelEnum.optional() }),
  z.object({ type: z.literal("SoundDesigner"), level: recordingRoleLevelEnum.optional() }),
  z.object({ type: z.literal("Vocalist"), level: recordingRoleLevelEnum.optional() }),
]);

// ============================================================================
// Credits
// ============================================================================

export const CompositionCreditSchema = z.object({
  displayName: z.string().min(1, "Display name cannot be empty"),
  roles: z.array(CompositionPartyRoleSchema)
    .min(1, "Credit must have at least 1 role")
    .max(5, "Credit cannot have more than 5 roles"),
});

export const RecordingCreditSchema = z.object({
  displayName: z.string().min(1, "Display name cannot be empty"),
  roles: z.array(RecordingPartyRoleSchema)
    .min(1, "Credit must have at least 1 role")
    .max(10, "Credit cannot have more than 10 roles"),
});

// ============================================================================
// Composition
// ============================================================================

export const CompositionStateSchema = z.discriminatedUnion("type", [
  z.object({ type: z.literal("Initialized") }),
  z.object({ type: z.literal("Published"), timestampMs: z.number().int().min(0) }),
]);

export const CompositionSchema = z.object({
  id: z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
  state: CompositionStateSchema,
  title: z.string().min(1, "Composition title cannot be empty"),
  alternateTitles: z.array(z.string()),
  credits: z.record(
    z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
    CompositionCreditSchema
  ),
  royaltyRate: z.object({ value: z.number().int().min(1000).max(10000) }),
});

export const CompositionPublishedEventSchema = z.object({
  compositionId: z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
});

export const CompositionRoyaltySetEventSchema = z.object({
  compositionId: z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
  royaltyRateBps: z.number().int().min(1000).max(10000),
});

// ============================================================================
// Recording
// ============================================================================

export const RecordingStateSchema = z.discriminatedUnion("type", [
  z.object({ type: z.literal("Initialized") }),
  z.object({ type: z.literal("Published"), timestampMs: z.number().int().min(0) }),
]);

const typeNameRegex = /^0x[a-fA-F0-9]+::[a-zA-Z_][a-zA-Z0-9_]*::[a-zA-Z_][a-zA-Z0-9_]*(<.*>)?$/;

export const RecordingSchema = z.object({
  id: z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
  state: RecordingStateSchema,
  title: z.string().min(1, "Recording title cannot be empty"),
  titleVersion: z.string().optional(),
  subtitle: z.string().optional(),
  compositionId: z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
  compositionRoyaltyRate: z.object({ value: z.number().int().min(0).max(10000) }),
  primaryArtistIds: z.array(z.string().refine(isValidSuiObjectId, "Invalid Sui object ID")),
  featuredArtistIds: z.array(z.string().refine(isValidSuiObjectId, "Invalid Sui object ID")),
  credits: z.record(
    z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
    RecordingCreditSchema
  ),
  language: z.string().length(2).regex(/^[a-z]{2}$/, "Language code must be 2 lowercase letters (ISO 639-1)").optional(),
  isExplicit: z.boolean(),
  isInstrumental: z.boolean(),
  master: AudioSchema,
  coverArt: CoverArtSchema,
});

export const RecordingPublishedEventSchema = z.object({
  recordingId: z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
  compositionId: z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
});

// ============================================================================
// Track
// ============================================================================

export const TrackSchema = z.object({
  state: z.enum(["Unassigned", "Assigned"]),
  compositionId: z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
  compositionShareType: z.string().regex(typeNameRegex, "Invalid Move type name"),
  compositionRoyaltyRate: z.object({ value: z.number().int().min(0).max(10000) }),
  recordingId: z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
  recordingShareType: z.string().regex(typeNameRegex, "Invalid Move type name"),
  recordingMasterIngesterType: z.string().regex(typeNameRegex, "Invalid Move type name"),
  title: z.string(),
  durationMs: z.number().int().min(0),
  coverArt: CoverArtSchema,
  splitBps: z.object({ value: z.number().int().min(0).max(10000) }),
});

// ============================================================================
// Disc
// ============================================================================

export const DiscSchema = z.object({
  tracks: z.array(TrackSchema).max(50, "Disc cannot have more than 50 tracks"),
  artwork: CoverArtSchema.optional(),
  title: z.string().optional(),
  durationMs: z.number().int().min(0),
});

// ============================================================================
// Release
// ============================================================================

export const ReleaseKindSchema = z.enum(["Album", "ExtendedPlay", "Single"]);

export const ReleaseStateSchema = z.discriminatedUnion("type", [
  z.object({ type: z.literal("Initialized") }),
  z.object({ type: z.literal("Published"), timestampMs: z.number().int().min(0) }),
]);

export const ReleaseSchema = z.object({
  id: z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
  state: ReleaseStateSchema,
  kind: ReleaseKindSchema,
  title: z.string().min(1, "Release title cannot be empty"),
  description: z.string().max(500, "Description cannot exceed 500 characters"),
  subtitle: z.string().optional(),
  credits: z.record(
    z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
    z.object({
      displayName: z.string().min(1, "Display name cannot be empty"),
      roles: z.array(z.discriminatedUnion("type", [
        z.object({ type: z.literal("Primary") }),
        z.object({ type: z.literal("Featured") }),
      ])).length(1, "Release credits must have exactly 1 role"),
    })
  ),
  discs: z.array(DiscSchema).max(20, "Release cannot have more than 20 discs"),
  coverArt: CoverArtSchema,
});

export const ReleasePublishedEventSchema = z.object({
  releaseId: z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
});

// ============================================================================
// Audio Events
// ============================================================================

export const AudioIngestedEventSchema = z.object({
  blobId: z.string(),
  format: z.string().min(1).max(16).regex(/^[a-z0-9]+$/),
  channels: z.number().int().min(1).max(255),
  bitDepth: z.number().int(),
  sampleRateHz: z.number().int().min(1),
  samples: z.number().int().min(0),
  durationMs: z.number().int().min(0),
  pcmDigest: z.string().regex(/^[0-9a-f]{64}$/),
});

// ============================================================================
// Deal Events
// ============================================================================

export const DealCreatedEventSchema = z.object({
  dealId: z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
  releaseId: z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
  recordingId: z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
  compositionId: z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
  trackTitle: z.string().min(1),
  trackSplitBps: z.object({ value: z.number().int().min(0).max(10000) }),
  trackCoverArtStaticBlobId: z.string(),
  trackCoverArtAnimatedBlobId: z.string().optional(),
});

export const DealDestroyedEventSchema = z.object({
  dealId: z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
  releaseId: z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
  recordingId: z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
  compositionId: z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
});

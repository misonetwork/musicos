// Copyright (c) Unconfirmed Labs, LLC
// SPDX-License-Identifier: Apache-2.0

import { z } from "zod";
import { isValidSuiAddress, isValidSuiObjectId } from "@mysten/sui/utils";

// ============================================================================
// Walrus Storage
// ============================================================================

export const WalrusDataSchema = z.object({
  blobId: z.string().regex(/^\d+$/, "Blob ID must be a decimal string"),
  size: z.number().int().min(0),
  mimeType: z.string().min(1),
});

// ============================================================================
// Party
// ============================================================================

export const PartyKindSchema = z.discriminatedUnion("type", [
  z.object({ type: z.literal("Individual") }),
  z.object({
    type: z.literal("Group"),
    memberIds: z.set(z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"))
      .min(1, "Group must have at least one member"),
  }),
]);

export const PartySchema = z.object({
  id: z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
  kind: PartyKindSchema,
  name: z.string().min(1, "Party name cannot be empty"),
});

export const PartyCreatedEventSchema = z.object({
  partyId: z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
  name: z.string().min(1),
});

export const PartyAddedToGroupEventSchema = z.object({
  groupId: z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
  partyId: z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
});

export const PartyRemovedFromGroupEventSchema = z.object({
  groupId: z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
  partyId: z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
});

// ============================================================================
// Audio
// ============================================================================

export const AudioSchema = z.object({
  channels: z.number().int().min(1, "Audio must have at least 1 channel").max(255),
  bitDepth: z.union([z.literal(8), z.literal(16), z.literal(24), z.literal(32)]),
  sampleRateHz: z.number().int().min(1, "Sample rate must be greater than 0").max(4294967295),
  samples: z.union([
    z.bigint().min(1n, "Samples must be at least 1"),
    z.number().int().min(1, "Samples must be at least 1"),
  ]),
  data: WalrusDataSchema,
  pcmDigest: z.instanceof(Uint8Array).refine(
    (arr) => arr.length === 32,
    "PCM digest must be exactly 32 bytes (SHA-256)"
  ),
});

export const CoverArtSchema = z.object({
  static: WalrusDataSchema,
  animated: WalrusDataSchema.optional(),
});

export const StemSchema = z.object({
  audio: AudioSchema,
  description: z.string().min(1, "Stem description cannot be empty"),
  contributors: z.array(z.string().refine(isValidSuiObjectId, "Invalid Sui object ID")),
});

// ============================================================================
// Musical Properties
// ============================================================================

export const MusicalKeySchema = z.object({
  note: z.enum(["C", "D", "E", "F", "G", "A", "B"]),
  accidental: z.enum(["Natural", "Sharp", "Flat"]),
  mode: z.enum(["Major", "Minor"]),
});

export const TimeSignatureSchema = z.object({
  beatsPerMeasure: z.number().int().min(1, "Beats per measure must be at least 1").max(255),
  beatUnit: z.number().int().min(1, "Beat unit must be at least 1").max(255),
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
    .max(20, "Credit cannot have more than 20 roles"),
});

export const RecordingCreditSchema = z.object({
  displayName: z.string().min(1, "Display name cannot be empty"),
  roles: z.array(RecordingPartyRoleSchema)
    .min(1, "Credit must have at least 1 role")
    .max(10, "Credit cannot have more than 10 roles"),
});

// ============================================================================
// Genre
// ============================================================================

export const GenreSchema = z.object({
  id: z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
  name: z.string()
    .min(1, "Genre name cannot be empty")
    .regex(/^[A-Z_&]+$/, "Genre name must contain only uppercase A-Z, underscore (_), and ampersand (&)"),
});

// ============================================================================
// Composition
// ============================================================================

export const CompositionStateSchema = z.discriminatedUnion("type", [
  z.object({ type: z.literal("Initialized") }),
  z.object({ type: z.literal("Published"), timestampMs: z.bigint().min(0n) }),
]);

export const CompositionSchema = z.object({
  id: z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
  state: CompositionStateSchema,
  title: z.string().min(1, "Composition title cannot be empty"),
  alternateTitles: z.array(z.string()),
  credits: z.map(
    z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
    CompositionCreditSchema
  ),
  splitBps: z.object({ value: z.number().int().min(0).max(10000) }),
  lyrics: z.array(z.string()),
});

export const CompositionInitializedEventSchema = z.object({
  compositionId: z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
});

export const CompositionPublishedEventSchema = z.object({
  compositionId: z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
});

export const CompositionPartyAddedEventSchema = z.object({
  compositionId: z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
  partyId: z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
});

export const CompositionSplitSetEventSchema = z.object({
  compositionId: z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
  splitValue: z.number().int().min(0).max(10000),
});

// ============================================================================
// Recording
// ============================================================================

export const RecordingStateSchema = z.discriminatedUnion("type", [
  z.object({ type: z.literal("Initialized") }),
  z.object({ type: z.literal("Published"), timestampMs: z.bigint().min(0n) }),
]);

const typeNameRegex = /^0x[a-fA-F0-9]+::[a-zA-Z_][a-zA-Z0-9_]*::[a-zA-Z_][a-zA-Z0-9_]*(<.*>)?$/;

export const RecordingSchema = z.object({
  id: z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
  state: RecordingStateSchema,
  title: z.string().min(1, "Recording title cannot be empty"),
  titleVersion: z.string().optional(),
  subtitle: z.string().optional(),
  compositionId: z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
  compositionShareType: z.string().regex(typeNameRegex, "Invalid Move type name"),
  compositionSplitBps: z.object({ value: z.number().int().min(0).max(10000) }),
  primaryGenreId: z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
  secondaryGenreIds: z.set(z.string().refine(isValidSuiObjectId, "Invalid Sui object ID")),
  primaryArtistIds: z.set(z.string().refine(isValidSuiObjectId, "Invalid Sui object ID")),
  featuredArtistIds: z.set(z.string().refine(isValidSuiObjectId, "Invalid Sui object ID")),
  credits: z.map(
    z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
    RecordingCreditSchema
  ),
  language: z.string().length(2).regex(/^[a-z]{2}$/, "Language code must be 2 lowercase letters (ISO 639-1)").optional(),
  isExplicit: z.boolean(),
  isInstrumental: z.boolean(),
  lyrics: WalrusDataSchema.optional(),
  musicalKey: MusicalKeySchema.optional(),
  timeSignature: TimeSignatureSchema.optional(),
  tempoBpm: z.number().int().min(0).max(65535).optional(),
  master: AudioSchema,
  stems: z.array(StemSchema),
  coverArt: CoverArtSchema,
});

export const RecordingPublishedEventSchema = z.object({
  recordingId: z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
});

export const RecordingPartyAddedEventSchema = z.object({
  recordingId: z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
  partyId: z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
});

// ============================================================================
// Track
// ============================================================================

export const TrackPositionSchema = z.object({
  discIdx: z.number().int().min(0),
  trackIdx: z.number().int().min(0),
});

export const TrackSchema = z.object({
  compositionId: z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
  compositionShareType: z.string().regex(typeNameRegex, "Invalid Move type name"),
  compositionSplitBps: z.object({ value: z.number().int().min(0).max(10000) }),
  recordingId: z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
  recordingShareType: z.string().regex(typeNameRegex, "Invalid Move type name"),
  durationMs: z.bigint().min(0n),
  coverArt: CoverArtSchema,
});

export const TrackSequenceSchema = z.object({
  tracksPerDisc: z.array(z.number().int().min(0)),
  trackPositions: z.array(TrackPositionSchema).max(255, "Release cannot have more than 255 tracks"),
  durationMs: z.bigint().min(0n),
});

// ============================================================================
// Disc
// ============================================================================

export const DiscSchema = z.object({
  tracks: z.array(TrackSchema).max(50, "Disc cannot have more than 50 tracks"),
  artwork: CoverArtSchema.optional(),
  durationMs: z.bigint().min(0n),
});

// ============================================================================
// Release
// ============================================================================

export const ReleaseKindSchema = z.enum(["Album", "EP", "Single"]);

export const ReleaseStateSchema = z.discriminatedUnion("type", [
  z.object({ type: z.literal("Initialized") }),
  z.object({ type: z.literal("Published"), timestampMs: z.bigint().min(0n) }),
]);

export const ReleaseSchema = z.object({
  id: z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
  kind: ReleaseKindSchema,
  state: ReleaseStateSchema,
  title: z.string().min(1, "Release title cannot be empty"),
  subtitle: z.string().optional(),
  discs: z.array(DiscSchema).max(20, "Release cannot have more than 20 discs"),
  trackSequence: TrackSequenceSchema,
  trackSplitsBps: z.array(z.object({ value: z.number().int().min(0).max(10000) })),
  coverArt: CoverArtSchema,
});

export const TrackSplitSchema = z.object({
  trackPosition: TrackPositionSchema,
  compositionId: z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
  compositionShareType: z.string().regex(typeNameRegex, "Invalid Move type name"),
  compositionSplitValue: z.bigint().min(0n),
  recordingId: z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
  recordingShareType: z.string().regex(typeNameRegex, "Invalid Move type name"),
  recordingSplitValue: z.bigint().min(0n),
});

export const ReleasePublishedEventSchema = z.object({
  releaseId: z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
  timestampMs: z.bigint().min(0n),
  sender: z.string().refine(isValidSuiAddress, "Invalid Sui address"),
});

export const ReleaseRevenueDistributedEventSchema = z.object({
  releaseId: z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
  compositionId: z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
  compositionSplitValue: z.bigint().min(0n),
  recordingId: z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
  recordingSplitValue: z.bigint().min(0n),
});

export const ReleaseTrackPaidEventSchema = z.object({
  releaseId: z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
  distributionValue: z.bigint().min(0n),
});

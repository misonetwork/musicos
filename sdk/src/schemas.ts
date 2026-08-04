// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

import { z } from "zod";
import { isValidSuiObjectId } from "@mysten/sui/utils";

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
  royaltyRate: z.object({ value: z.number().int().min(0).max(2000) }),
  royaltyRateLastChangedEpoch: z.number().int().min(0),
});

export const CompositionPublishedEventSchema = z.object({
  compositionId: z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
});

export const CompositionRoyaltySetEventSchema = z.object({
  royaltyRateBps: z.number().int().min(0).max(2000),
});

// ============================================================================
// Recording
// ============================================================================

export const RecordingStateSchema = z.discriminatedUnion("type", [
  z.object({ type: z.literal("Initialized") }),
  z.object({ type: z.literal("Published"), timestampMs: z.number().int().min(0) }),
]);

export const RecordingSchema = z.object({
  id: z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
  state: RecordingStateSchema,
});

export const RecordingPublishedEventSchema = z.object({
  recordingId: z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
});

// ============================================================================
// Track
// ============================================================================

export const TrackSchema = z.object({
  state: z.enum(["Unassigned", "Assigned"]),
  recordingId: z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
  splitBps: z.object({ value: z.number().int().min(0).max(10000) }),
});

// ============================================================================
// Release
// ============================================================================

export const ReleaseStateSchema = z.discriminatedUnion("type", [
  z.object({ type: z.literal("Initialized") }),
  z.object({ type: z.literal("Published"), timestampMs: z.number().int().min(0) }),
]);

export const ReleaseSchema = z.object({
  id: z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
  state: ReleaseStateSchema,
  title: z.string().min(1, "Release title cannot be empty"),
  tracks: z.array(TrackSchema).max(255, "Release cannot have more than 255 tracks"),
});

export const ReleasePublishedEventSchema = z.object({
  releaseId: z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
});

// ============================================================================
// Deal Events
// ============================================================================

export const DealCreatedEventSchema = z.object({
  dealId: z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
  releaseId: z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
  trackSplitBps: z.object({ value: z.number().int().min(0).max(10000) }),
});

const dealLifecycleEventShape = {
  dealId: z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
  releaseId: z.string().refine(isValidSuiObjectId, "Invalid Sui object ID"),
};

export const DealAcceptedEventSchema = z.object(dealLifecycleEventShape);

export const DealRejectedEventSchema = z.object(dealLifecycleEventShape);

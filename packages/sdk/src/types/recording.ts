// Copyright (c) Studio Mirai, LLC
// SPDX-License-Identifier: Apache-2.0

import type { CoverArt, MusicalKey, TimeSignature } from "./common.js";
import type { Audio, Stem } from "./audio.js";

/**
 * Seniority level for recording contributors.
 */
export type RecordingContributorLevel =
  | "additional"
  | "assistant"
  | "associate"
  | "backing"
  | "executive"
  | "featured"
  | "lead"
  | "primary"
  | "principal";

/**
 * Role types for recording contributors.
 */
export type RecordingRoleType =
  | "actor"
  | "arranger"
  | "artists_and_repertoire"
  | "choir"
  | "choir_master"
  | "conductor"
  | "contractor"
  | "copyist"
  | "editor"
  | "ensemble"
  | "instrumentalist"
  | "mastering_engineer"
  | "mixing_engineer"
  | "music_director"
  | "music_supervisor"
  | "narrator"
  | "orchestra"
  | "orchestrator"
  | "producer"
  | "programmer"
  | "recording_engineer"
  | "remixing_engineer"
  | "sound_designer"
  | "vocalist";

/**
 * A role on a recording with optional level and instrument.
 */
export interface RecordingRole {
  /** Type of role */
  type: RecordingRoleType;
  /** Optional seniority level */
  level?: RecordingContributorLevel;
  /** Instrument name (required for instrumentalist) */
  instrument?: string;
}

/**
 * Credit for a contributor on a recording.
 */
export interface RecordingCredit {
  /** Display name for this credit */
  displayName: string;
  /** Roles held (1-10) */
  roles: RecordingRole[];
}

/**
 * Parameters for creating a new recording.
 */
export interface CreateRecordingParams {
  /** Composition object ID */
  compositionId: string;
  /** Composition share type string */
  compositionShareType: string;
  /** Primary genre object ID */
  genreId: string;
  /** Whether recording contains explicit content */
  isExplicit: boolean;
  /** Whether recording is instrumental (no vocals) */
  isInstrumental: boolean;
  /** Master audio file */
  master: Audio;
  /** Cover artwork */
  coverArt: CoverArt;
  /** Share currency object ID */
  shareCurrencyId: string;
  /** Share treasury cap object ID */
  shareTreasuryCapId: string;
  /** Recording share type string */
  shareType: string;
}

/**
 * Parameters for publishing a recording.
 */
export interface PublishRecordingParams {
  /** Recording object ID */
  recordingId: string;
  /** Admin capability object ID */
  adminCapId: string;
  /** Share type string */
  shareType: string;
}

/**
 * Parameters for setting title version.
 */
export interface SetTitleVersionParams {
  /** Recording object ID */
  recordingId: string;
  /** Admin capability object ID */
  adminCapId: string;
  /** Version string (e.g., "Radio Edit") */
  version: string;
  /** Share type string */
  shareType: string;
}

/**
 * Parameters for setting subtitle.
 */
export interface SetSubtitleParams {
  /** Recording object ID */
  recordingId: string;
  /** Admin capability object ID */
  adminCapId: string;
  /** Subtitle */
  subtitle: string;
  /** Share type string */
  shareType: string;
}

/**
 * Parameters for setting language.
 */
export interface SetLanguageParams {
  /** Recording object ID */
  recordingId: string;
  /** Admin capability object ID */
  adminCapId: string;
  /** ISO 639-1 language code */
  language: string;
  /** Share type string */
  shareType: string;
}

/**
 * Parameters for adding a credit to a recording.
 */
export interface AddRecordingCreditParams {
  /** Recording object ID */
  recordingId: string;
  /** Admin capability object ID */
  adminCapId: string;
  /** Contributor object ID */
  contributorId: string;
  /** Credit details */
  credit: RecordingCredit;
  /** Share type string */
  shareType: string;
}

/**
 * Parameters for artist operations.
 */
export interface RecordingArtistParams {
  /** Recording object ID */
  recordingId: string;
  /** Admin capability object ID */
  adminCapId: string;
  /** Contributor object ID */
  contributorId: string;
  /** Share type string */
  shareType: string;
}

/**
 * Parameters for genre operations.
 */
export interface RecordingGenreParams {
  /** Recording object ID */
  recordingId: string;
  /** Admin capability object ID */
  adminCapId: string;
  /** Genre object ID */
  genreId: string;
  /** Share type string */
  shareType: string;
}

/**
 * Parameters for setting musical key.
 */
export interface SetMusicalKeyParams {
  /** Recording object ID */
  recordingId: string;
  /** Admin capability object ID */
  adminCapId: string;
  /** Musical key */
  key: MusicalKey;
  /** Share type string */
  shareType: string;
}

/**
 * Parameters for setting time signature.
 */
export interface SetTimeSignatureParams {
  /** Recording object ID */
  recordingId: string;
  /** Admin capability object ID */
  adminCapId: string;
  /** Time signature */
  timeSignature: TimeSignature;
  /** Share type string */
  shareType: string;
}

/**
 * Parameters for setting tempo.
 */
export interface SetTempoParams {
  /** Recording object ID */
  recordingId: string;
  /** Admin capability object ID */
  adminCapId: string;
  /** Tempo in BPM */
  bpm: number;
  /** Share type string */
  shareType: string;
}

/**
 * Parameters for adding a stem.
 */
export interface AddStemParams {
  /** Recording object ID */
  recordingId: string;
  /** Admin capability object ID */
  adminCapId: string;
  /** Stem to add */
  stem: Stem;
  /** Share type string */
  shareType: string;
}

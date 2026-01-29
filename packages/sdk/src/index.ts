// Copyright (c) Studio Mirai, LLC
// SPDX-License-Identifier: Apache-2.0

/**
 * MusicOS SDK - TypeScript client for MusicOS on Sui.
 *
 * @packageDocumentation
 */

// Main client
export { MusicOSClient } from "./client.js";

// Domain clients (for advanced use cases)
export {
  ContributorClient,
  CompositionClient,
  RecordingClient,
  ReleaseClient,
  GenreClient,
} from "./clients/index.js";

// Builders
export { RecordingBuilder } from "./builders/index.js";

// Types
export type {
  // Common
  WalrusData,
  CoverArt,
  Note,
  Accidental,
  Mode,
  MusicalKey,
  TimeSignature,
  MusicOSConfig,
  NetworkPreset,
  CreateResult,
  // Contributor
  ContributorKind,
  CreateContributorParams,
  ShareContributorParams,
  SetContributorNameParams,
  AddGroupMemberParams,
  RemoveGroupMemberParams,
  // Composition
  CompositionRole,
  CompositionCredit,
  CreateCompositionParams,
  PublishCompositionParams,
  AddCompositionCreditParams,
  SetCompositionSplitParams,
  AddAlternateTitleParams,
  AddLyricLinesParams,
  // Recording
  RecordingContributorLevel,
  RecordingRoleType,
  RecordingRole,
  RecordingCredit,
  CreateRecordingParams,
  PublishRecordingParams,
  SetTitleVersionParams,
  SetSubtitleParams,
  SetLanguageParams,
  AddRecordingCreditParams,
  RecordingArtistParams,
  RecordingGenreParams,
  SetMusicalKeyParams,
  SetTimeSignatureParams,
  SetTempoParams,
  AddStemParams,
  // Release
  ReleaseKind,
  Track,
  Disc,
  CreateReleaseParams,
  PublishReleaseParams,
  SetTrackSplitsParams,
  DistributeRevenueParams,
  // Genre
  CreateGenreParams,
  // Audio
  Audio,
  Stem,
} from "./types/index.js";

// Constants
export { DEFAULT_GENRES, type DefaultGenre } from "./types/genre.js";

// Utilities
export { calculateDurationMs, calculateDurationSeconds } from "./types/audio.js";
export {
  makeWalrusData,
  makeCoverArt,
  makeAudio,
  makeStem,
  makeMusicalKey,
  makeTimeSignature,
  makeCompositionRole,
  makeCompositionCredit,
  makeRecordingLevel,
  makeRecordingRole,
  makeRecordingCredit,
  makeReleaseKind,
} from "./utils/move-call.js";
export {
  parseTypeString,
  validateShareType,
  SUI_CLOCK_OBJECT_ID,
} from "./utils/type-args.js";

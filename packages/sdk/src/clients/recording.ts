// Copyright (c) Studio Mirai, LLC
// SPDX-License-Identifier: Apache-2.0

import { Transaction } from "@mysten/sui/transactions";
import type {
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
} from "../types/recording.js";
import {
  makeAudio,
  makeCoverArt,
  makeRecordingCredit,
  makeMusicalKey,
  makeTimeSignature,
  makeStem,
} from "../utils/move-call.js";
import { SUI_CLOCK_OBJECT_ID } from "../utils/type-args.js";
import {
  AddRecordingCreditParamsSchema,
  AddStemParamsSchema,
  CreateRecordingParamsSchema,
  PublishRecordingParamsSchema,
  RecordingArtistParamsSchema,
  RecordingGenreParamsSchema,
  SetLanguageParamsSchema,
  SetMusicalKeyParamsSchema,
  SetSubtitleParamsSchema,
  SetTempoParamsSchema,
  SetTimeSignatureParamsSchema,
  SetTitleVersionParamsSchema,
} from "../schemas/recording.js";

/**
 * Client for managing recordings.
 */
export class RecordingClient {
  constructor(private readonly packageId: string) {}

  /**
   * Create a new recording.
   * Returns a transaction that creates the recording, admin cap, and share balance.
   */
  create(params: CreateRecordingParams): Transaction {
    const parsed = CreateRecordingParamsSchema.parse(params);
    const tx = new Transaction();

    const master = makeAudio(tx, this.packageId, parsed.master);
    const coverArt = makeCoverArt(tx, this.packageId, parsed.coverArt);

    const [recording, adminCap, shareBalance] = tx.moveCall({
      target: `${this.packageId}::recording::new`,
      typeArguments: [parsed.shareType, parsed.compositionShareType],
      arguments: [
        tx.object(parsed.compositionId),
        tx.object(parsed.genreId),
        tx.pure.bool(parsed.isExplicit),
        tx.pure.bool(parsed.isInstrumental),
        master,
        coverArt,
        tx.object(parsed.shareCurrencyId),
        tx.object(parsed.shareTreasuryCapId),
      ],
    });

    // Convert balance to coin and transfer all to sender
    const shareCoin = tx.moveCall({
      target: "0x2::coin::from_balance",
      typeArguments: [parsed.shareType],
      arguments: [shareBalance],
    });

    tx.transferObjects([recording, adminCap, shareCoin], tx.pure.address("@sender"));

    return tx;
  }

  /**
   * Publish a recording (makes it immutable and shared).
   * Requires at least one contributor and one primary artist.
   */
  publish(params: PublishRecordingParams): Transaction {
    const parsed = PublishRecordingParamsSchema.parse(params);
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.packageId}::recording::publish`,
      typeArguments: [parsed.shareType],
      arguments: [
        tx.object(parsed.recordingId),
        tx.object(parsed.adminCapId),
        tx.object(SUI_CLOCK_OBJECT_ID),
      ],
    });

    return tx;
  }

  /**
   * Set the title version (e.g., "Radio Edit").
   */
  setTitleVersion(params: SetTitleVersionParams): Transaction {
    const parsed = SetTitleVersionParamsSchema.parse(params);
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.packageId}::recording::set_title_version`,
      typeArguments: [parsed.shareType],
      arguments: [
        tx.object(parsed.recordingId),
        tx.object(parsed.adminCapId),
        tx.pure.string(parsed.version),
      ],
    });

    return tx;
  }

  /**
   * Set the subtitle.
   */
  setSubtitle(params: SetSubtitleParams): Transaction {
    const parsed = SetSubtitleParamsSchema.parse(params);
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.packageId}::recording::set_subtitle`,
      typeArguments: [parsed.shareType],
      arguments: [
        tx.object(parsed.recordingId),
        tx.object(parsed.adminCapId),
        tx.pure.string(parsed.subtitle),
      ],
    });

    return tx;
  }

  /**
   * Set the language.
   */
  setLanguage(params: SetLanguageParams): Transaction {
    const parsed = SetLanguageParamsSchema.parse(params);
    const tx = new Transaction();

    // Create language code
    const languageCode = tx.moveCall({
      target: `${this.packageId}::language_code::new`,
      arguments: [tx.pure.string(parsed.language)],
    });

    tx.moveCall({
      target: `${this.packageId}::recording::set_language`,
      typeArguments: [parsed.shareType],
      arguments: [
        tx.object(parsed.recordingId),
        tx.object(parsed.adminCapId),
        languageCode,
      ],
    });

    return tx;
  }

  /**
   * Add a credit (contributor with roles) to a recording.
   */
  addCredit(params: AddRecordingCreditParams): Transaction {
    const parsed = AddRecordingCreditParamsSchema.parse(params);
    const tx = new Transaction();

    const credit = makeRecordingCredit(tx, this.packageId, parsed.credit);

    tx.moveCall({
      target: `${this.packageId}::recording::add_credit`,
      typeArguments: [parsed.shareType],
      arguments: [
        tx.object(parsed.recordingId),
        tx.object(parsed.adminCapId),
        tx.object(parsed.contributorId),
        credit,
      ],
    });

    return tx;
  }

  /**
   * Add a primary artist to the recording.
   * The contributor must already be credited on the recording.
   */
  addPrimaryArtist(params: RecordingArtistParams): Transaction {
    const parsed = RecordingArtistParamsSchema.parse(params);
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.packageId}::recording::add_primary_artist`,
      typeArguments: [parsed.shareType],
      arguments: [
        tx.object(parsed.recordingId),
        tx.object(parsed.adminCapId),
        tx.object(parsed.contributorId),
      ],
    });

    return tx;
  }

  /**
   * Add a featured artist to the recording.
   * The contributor must already be credited and not be a primary artist.
   */
  addFeaturedArtist(params: RecordingArtistParams): Transaction {
    const parsed = RecordingArtistParamsSchema.parse(params);
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.packageId}::recording::add_featured_artist`,
      typeArguments: [parsed.shareType],
      arguments: [
        tx.object(parsed.recordingId),
        tx.object(parsed.adminCapId),
        tx.object(parsed.contributorId),
      ],
    });

    return tx;
  }

  /**
   * Set the primary genre.
   */
  setPrimaryGenre(params: RecordingGenreParams): Transaction {
    const parsed = RecordingGenreParamsSchema.parse(params);
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.packageId}::recording::set_primary_genre`,
      typeArguments: [parsed.shareType],
      arguments: [
        tx.object(parsed.recordingId),
        tx.object(parsed.adminCapId),
        tx.object(parsed.genreId),
      ],
    });

    return tx;
  }

  /**
   * Add a secondary genre.
   */
  addSecondaryGenre(params: RecordingGenreParams): Transaction {
    const parsed = RecordingGenreParamsSchema.parse(params);
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.packageId}::recording::add_secondary_genre`,
      typeArguments: [parsed.shareType],
      arguments: [
        tx.object(parsed.recordingId),
        tx.object(parsed.adminCapId),
        tx.object(parsed.genreId),
      ],
    });

    return tx;
  }

  /**
   * Remove a secondary genre.
   */
  removeSecondaryGenre(params: RecordingGenreParams): Transaction {
    const parsed = RecordingGenreParamsSchema.parse(params);
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.packageId}::recording::remove_secondary_genre`,
      typeArguments: [parsed.shareType],
      arguments: [
        tx.object(parsed.recordingId),
        tx.object(parsed.adminCapId),
        tx.pure.id(parsed.genreId),
      ],
    });

    return tx;
  }

  /**
   * Set the musical key.
   */
  setMusicalKey(params: SetMusicalKeyParams): Transaction {
    const parsed = SetMusicalKeyParamsSchema.parse(params);
    const tx = new Transaction();

    const musicalKey = makeMusicalKey(tx, this.packageId, parsed.key);

    tx.moveCall({
      target: `${this.packageId}::recording::set_musical_key`,
      typeArguments: [parsed.shareType],
      arguments: [
        tx.object(parsed.recordingId),
        tx.object(parsed.adminCapId),
        musicalKey,
      ],
    });

    return tx;
  }

  /**
   * Set the time signature.
   */
  setTimeSignature(params: SetTimeSignatureParams): Transaction {
    const parsed = SetTimeSignatureParamsSchema.parse(params);
    const tx = new Transaction();

    const timeSignature = makeTimeSignature(tx, this.packageId, parsed.timeSignature);

    tx.moveCall({
      target: `${this.packageId}::recording::set_time_signature`,
      typeArguments: [parsed.shareType],
      arguments: [
        tx.object(parsed.recordingId),
        tx.object(parsed.adminCapId),
        timeSignature,
      ],
    });

    return tx;
  }

  /**
   * Set the tempo in BPM.
   */
  setTempoBpm(params: SetTempoParams): Transaction {
    const parsed = SetTempoParamsSchema.parse(params);
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.packageId}::recording::set_tempo_bpm`,
      typeArguments: [parsed.shareType],
      arguments: [
        tx.object(parsed.recordingId),
        tx.object(parsed.adminCapId),
        tx.pure.u16(parsed.bpm),
      ],
    });

    return tx;
  }

  /**
   * Add an audio stem to the recording.
   */
  addStem(params: AddStemParams): Transaction {
    const parsed = AddStemParamsSchema.parse(params);
    const tx = new Transaction();

    const stem = makeStem(tx, this.packageId, parsed.stem);

    tx.moveCall({
      target: `${this.packageId}::recording::add_stem`,
      typeArguments: [parsed.shareType],
      arguments: [
        tx.object(parsed.recordingId),
        tx.object(parsed.adminCapId),
        stem,
      ],
    });

    return tx;
  }
}

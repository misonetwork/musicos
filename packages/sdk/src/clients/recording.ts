// Copyright (c) Studio Mirai, LLC
// SPDX-License-Identifier: Apache-2.0

import { Transaction } from "@mysten/sui/transactions";
import type {
  CreateRecordingParams,
  PublishRecordingParams,
  SetRecordingTitleParams,
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
    const tx = new Transaction();

    const master = makeAudio(tx, this.packageId, params.master);
    const coverArt = makeCoverArt(tx, this.packageId, params.coverArt);

    const [recording, adminCap, shareBalance] = tx.moveCall({
      target: `${this.packageId}::recording::new`,
      typeArguments: [params.shareType, params.compositionShareType],
      arguments: [
        tx.object(params.compositionId),
        tx.object(params.genreId),
        tx.pure.bool(params.isExplicit),
        tx.pure.bool(params.isInstrumental),
        master,
        coverArt,
        tx.object(params.shareCurrencyId),
        tx.object(params.shareTreasuryCapId),
      ],
    });

    // Convert balance to coin and transfer all to sender
    const shareCoin = tx.moveCall({
      target: "0x2::coin::from_balance",
      typeArguments: [params.shareType],
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
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.packageId}::recording::publish`,
      typeArguments: [params.shareType],
      arguments: [
        tx.object(params.recordingId),
        tx.object(params.adminCapId),
        tx.object(SUI_CLOCK_OBJECT_ID),
      ],
    });

    return tx;
  }

  /**
   * Set the recording title.
   */
  setTitle(params: SetRecordingTitleParams): Transaction {
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.packageId}::recording::set_title`,
      typeArguments: [params.shareType],
      arguments: [
        tx.object(params.recordingId),
        tx.object(params.adminCapId),
        tx.pure.string(params.title),
      ],
    });

    return tx;
  }

  /**
   * Set the title version (e.g., "Radio Edit").
   */
  setTitleVersion(params: SetTitleVersionParams): Transaction {
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.packageId}::recording::set_title_version`,
      typeArguments: [params.shareType],
      arguments: [
        tx.object(params.recordingId),
        tx.object(params.adminCapId),
        tx.pure.string(params.version),
      ],
    });

    return tx;
  }

  /**
   * Set the subtitle.
   */
  setSubtitle(params: SetSubtitleParams): Transaction {
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.packageId}::recording::set_subtitle`,
      typeArguments: [params.shareType],
      arguments: [
        tx.object(params.recordingId),
        tx.object(params.adminCapId),
        tx.pure.string(params.subtitle),
      ],
    });

    return tx;
  }

  /**
   * Set the language.
   */
  setLanguage(params: SetLanguageParams): Transaction {
    const tx = new Transaction();

    // Create language code
    const languageCode = tx.moveCall({
      target: `${this.packageId}::language_code::new`,
      arguments: [tx.pure.string(params.language)],
    });

    tx.moveCall({
      target: `${this.packageId}::recording::set_language`,
      typeArguments: [params.shareType],
      arguments: [
        tx.object(params.recordingId),
        tx.object(params.adminCapId),
        languageCode,
      ],
    });

    return tx;
  }

  /**
   * Add a credit (contributor with roles) to a recording.
   */
  addCredit(params: AddRecordingCreditParams): Transaction {
    const tx = new Transaction();

    const credit = makeRecordingCredit(tx, this.packageId, params.credit);

    tx.moveCall({
      target: `${this.packageId}::recording::add_credit`,
      typeArguments: [params.shareType],
      arguments: [
        tx.object(params.recordingId),
        tx.object(params.adminCapId),
        tx.object(params.contributorId),
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
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.packageId}::recording::add_primary_artist`,
      typeArguments: [params.shareType],
      arguments: [
        tx.object(params.recordingId),
        tx.object(params.adminCapId),
        tx.object(params.contributorId),
      ],
    });

    return tx;
  }

  /**
   * Add a featured artist to the recording.
   * The contributor must already be credited and not be a primary artist.
   */
  addFeaturedArtist(params: RecordingArtistParams): Transaction {
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.packageId}::recording::add_featured_artist`,
      typeArguments: [params.shareType],
      arguments: [
        tx.object(params.recordingId),
        tx.object(params.adminCapId),
        tx.object(params.contributorId),
      ],
    });

    return tx;
  }

  /**
   * Remove a primary artist from the recording.
   */
  removePrimaryArtist(params: RecordingArtistParams): Transaction {
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.packageId}::recording::remove_primary_artist`,
      typeArguments: [params.shareType],
      arguments: [
        tx.object(params.recordingId),
        tx.object(params.adminCapId),
        tx.pure.id(params.contributorId),
      ],
    });

    return tx;
  }

  /**
   * Remove a featured artist from the recording.
   */
  removeFeaturedArtist(params: RecordingArtistParams): Transaction {
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.packageId}::recording::remove_featured_artist`,
      typeArguments: [params.shareType],
      arguments: [
        tx.object(params.recordingId),
        tx.object(params.adminCapId),
        tx.pure.id(params.contributorId),
      ],
    });

    return tx;
  }

  /**
   * Set the primary genre.
   */
  setPrimaryGenre(params: RecordingGenreParams): Transaction {
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.packageId}::recording::set_primary_genre`,
      typeArguments: [params.shareType],
      arguments: [
        tx.object(params.recordingId),
        tx.object(params.adminCapId),
        tx.object(params.genreId),
      ],
    });

    return tx;
  }

  /**
   * Add a secondary genre.
   */
  addSecondaryGenre(params: RecordingGenreParams): Transaction {
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.packageId}::recording::add_secondary_genre`,
      typeArguments: [params.shareType],
      arguments: [
        tx.object(params.recordingId),
        tx.object(params.adminCapId),
        tx.object(params.genreId),
      ],
    });

    return tx;
  }

  /**
   * Remove a secondary genre.
   */
  removeSecondaryGenre(params: RecordingGenreParams): Transaction {
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.packageId}::recording::remove_secondary_genre`,
      typeArguments: [params.shareType],
      arguments: [
        tx.object(params.recordingId),
        tx.object(params.adminCapId),
        tx.pure.id(params.genreId),
      ],
    });

    return tx;
  }

  /**
   * Set the musical key.
   */
  setMusicalKey(params: SetMusicalKeyParams): Transaction {
    const tx = new Transaction();

    const musicalKey = makeMusicalKey(tx, this.packageId, params.key);

    tx.moveCall({
      target: `${this.packageId}::recording::set_musical_key`,
      typeArguments: [params.shareType],
      arguments: [
        tx.object(params.recordingId),
        tx.object(params.adminCapId),
        musicalKey,
      ],
    });

    return tx;
  }

  /**
   * Set the time signature.
   */
  setTimeSignature(params: SetTimeSignatureParams): Transaction {
    const tx = new Transaction();

    const timeSignature = makeTimeSignature(tx, this.packageId, params.timeSignature);

    tx.moveCall({
      target: `${this.packageId}::recording::set_time_signature`,
      typeArguments: [params.shareType],
      arguments: [
        tx.object(params.recordingId),
        tx.object(params.adminCapId),
        timeSignature,
      ],
    });

    return tx;
  }

  /**
   * Set the tempo in BPM.
   */
  setTempoBpm(params: SetTempoParams): Transaction {
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.packageId}::recording::set_tempo_bpm`,
      typeArguments: [params.shareType],
      arguments: [
        tx.object(params.recordingId),
        tx.object(params.adminCapId),
        tx.pure.u16(params.bpm),
      ],
    });

    return tx;
  }

  /**
   * Add an audio stem to the recording.
   */
  addStem(params: AddStemParams): Transaction {
    const tx = new Transaction();

    const stem = makeStem(tx, this.packageId, params.stem);

    tx.moveCall({
      target: `${this.packageId}::recording::add_stem`,
      typeArguments: [params.shareType],
      arguments: [
        tx.object(params.recordingId),
        tx.object(params.adminCapId),
        stem,
      ],
    });

    return tx;
  }
}

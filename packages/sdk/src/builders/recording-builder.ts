// Copyright (c) Studio Mirai, LLC
// SPDX-License-Identifier: Apache-2.0

import { Transaction, type TransactionArgument } from "@mysten/sui/transactions";
import type { CoverArt, MusicalKey, TimeSignature } from "../types/common.js";
import type { Audio, Stem } from "../types/audio.js";
import type { RecordingCredit } from "../types/recording.js";
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
  IdSchema,
  MusicalKeySchema,
  NonEmptyStringSchema,
  RecordingBuilderParamsSchema,
  RecordingCreditSchema,
  StemSchema,
  TimeSignatureSchema,
  U16Schema,
} from "../schemas/index.js";

interface RecordingBuilderParams {
  packageId: string;
  compositionId: string;
  compositionShareType: string;
  genreId: string;
  master: Audio;
  coverArt: CoverArt;
  shareCurrencyId: string;
  shareTreasuryCapId: string;
  shareType: string;
}

interface CreditToAdd {
  contributorId: string;
  credit: RecordingCredit;
}

/**
 * Fluent builder for creating recordings with all their metadata.
 *
 * @example
 * ```ts
 * const tx = new RecordingBuilder({
 *   packageId: "0x...",
 *   compositionId: "0x...",
 *   // ... other required params
 * })
 *   .titleVersion("Radio Edit")
 *   .addCredit(artistId, { displayName: "Artist", roles: [{ type: "vocalist", level: "lead" }] })
 *   .addPrimaryArtist(artistId)
 *   .tempoBpm(120)
 *   .musicalKey({ note: "C", accidental: "natural", mode: "major" })
 *   .buildAndPublish();
 * ```
 */
export class RecordingBuilder {
  private readonly params: RecordingBuilderParams;
  private _isExplicit = false;
  private _isInstrumental = false;
  private _titleVersion?: string;
  private _subtitle?: string;
  private _language?: string;
  private _credits: CreditToAdd[] = [];
  private _primaryArtistIds: string[] = [];
  private _featuredArtistIds: string[] = [];
  private _primaryGenreId?: string;
  private _secondaryGenreIds: string[] = [];
  private _musicalKey?: MusicalKey;
  private _timeSignature?: TimeSignature;
  private _tempoBpm?: number;
  private _stems: Stem[] = [];

  constructor(params: RecordingBuilderParams) {
    this.params = RecordingBuilderParamsSchema.parse(params);
  }

  /** Mark as explicit content. */
  explicit(value = true): this {
    this._isExplicit = value;
    return this;
  }

  /** Mark as instrumental (no vocals). */
  instrumental(value = true): this {
    this._isInstrumental = value;
    return this;
  }

  /** Set the title version (e.g., "Radio Edit"). */
  titleVersion(version: string): this {
    this._titleVersion = NonEmptyStringSchema.parse(version);
    return this;
  }

  /** Set the subtitle. */
  subtitle(subtitle: string): this {
    this._subtitle = NonEmptyStringSchema.parse(subtitle);
    return this;
  }

  /** Set the language (ISO 639-1 code). */
  language(code: string): this {
    this._language = NonEmptyStringSchema.parse(code);
    return this;
  }

  /** Add a credit for a contributor. */
  addCredit(contributorId: string, credit: RecordingCredit): this {
    const parsedContributorId = IdSchema.parse(contributorId);
    const parsedCredit = RecordingCreditSchema.parse(credit);
    this._credits.push({ contributorId: parsedContributorId, credit: parsedCredit });
    return this;
  }

  /** Add a primary artist (must be added as credit first). */
  addPrimaryArtist(contributorId: string): this {
    this._primaryArtistIds.push(IdSchema.parse(contributorId));
    return this;
  }

  /** Add a featured artist (must be added as credit first). */
  addFeaturedArtist(contributorId: string): this {
    this._featuredArtistIds.push(IdSchema.parse(contributorId));
    return this;
  }

  /** Override the primary genre. */
  primaryGenre(genreId: string): this {
    this._primaryGenreId = IdSchema.parse(genreId);
    return this;
  }

  /** Add a secondary genre. */
  addSecondaryGenre(genreId: string): this {
    this._secondaryGenreIds.push(IdSchema.parse(genreId));
    return this;
  }

  /** Set the musical key. */
  musicalKey(key: MusicalKey): this {
    this._musicalKey = MusicalKeySchema.parse(key);
    return this;
  }

  /** Set the time signature. */
  timeSignature(beats: number, unit: number): this {
    this._timeSignature = TimeSignatureSchema.parse({
      beatsPerMeasure: beats,
      beatUnit: unit,
    });
    return this;
  }

  /** Set the tempo in BPM. */
  tempoBpm(bpm: number): this {
    this._tempoBpm = U16Schema.refine((value) => value > 0, {
      message: "bpm must be > 0",
    }).parse(bpm);
    return this;
  }

  /** Add an audio stem. */
  addStem(stem: Stem): this {
    this._stems.push(StemSchema.parse(stem));
    return this;
  }

  /**
   * Build a transaction that creates the recording but doesn't publish.
   * The recording, admin cap, and share coin are transferred to sender.
   */
  build(): Transaction {
    const tx = new Transaction();
    const pkg = this.params.packageId;

    // Create the recording
    const master = makeAudio(tx, pkg, this.params.master);
    const coverArt = makeCoverArt(tx, pkg, this.params.coverArt);

    const [recording, adminCap, shareBalance] = tx.moveCall({
      target: `${pkg}::recording::new`,
      typeArguments: [this.params.shareType, this.params.compositionShareType],
      arguments: [
        tx.object(this.params.compositionId),
        tx.object(this.params.genreId),
        tx.pure.bool(this._isExplicit),
        tx.pure.bool(this._isInstrumental),
        master,
        coverArt,
        tx.object(this.params.shareCurrencyId),
        tx.object(this.params.shareTreasuryCapId),
      ],
    });

    // Apply all the optional settings
    this.applySettings(tx, recording, adminCap);

    // Convert balance to coin
    const shareCoin = tx.moveCall({
      target: "0x2::coin::from_balance",
      typeArguments: [this.params.shareType],
      arguments: [shareBalance],
    });

    tx.transferObjects([recording, adminCap, shareCoin], tx.pure.address("@sender"));

    return tx;
  }

  /**
   * Build a transaction that creates, configures, and publishes the recording.
   * The admin cap and share coin are transferred to sender.
   */
  buildAndPublish(): Transaction {
    const tx = new Transaction();
    const pkg = this.params.packageId;

    // Create the recording
    const master = makeAudio(tx, pkg, this.params.master);
    const coverArt = makeCoverArt(tx, pkg, this.params.coverArt);

    const [recording, adminCap, shareBalance] = tx.moveCall({
      target: `${pkg}::recording::new`,
      typeArguments: [this.params.shareType, this.params.compositionShareType],
      arguments: [
        tx.object(this.params.compositionId),
        tx.object(this.params.genreId),
        tx.pure.bool(this._isExplicit),
        tx.pure.bool(this._isInstrumental),
        master,
        coverArt,
        tx.object(this.params.shareCurrencyId),
        tx.object(this.params.shareTreasuryCapId),
      ],
    });

    // Apply all the optional settings
    this.applySettings(tx, recording, adminCap);

    // Publish the recording
    tx.moveCall({
      target: `${pkg}::recording::publish`,
      typeArguments: [this.params.shareType],
      arguments: [recording, adminCap, tx.object(SUI_CLOCK_OBJECT_ID)],
    });

    // Convert balance to coin
    const shareCoin = tx.moveCall({
      target: "0x2::coin::from_balance",
      typeArguments: [this.params.shareType],
      arguments: [shareBalance],
    });

    tx.transferObjects([adminCap, shareCoin], tx.pure.address("@sender"));

    return tx;
  }

  private applySettings(
    tx: Transaction,
    recording: TransactionArgument,
    adminCap: TransactionArgument
  ): void {
    const pkg = this.params.packageId;
    const shareType = this.params.shareType;

    // Title version
    if (this._titleVersion) {
      tx.moveCall({
        target: `${pkg}::recording::set_title_version`,
        typeArguments: [shareType],
        arguments: [recording, adminCap, tx.pure.string(this._titleVersion)],
      });
    }

    // Subtitle
    if (this._subtitle) {
      tx.moveCall({
        target: `${pkg}::recording::set_subtitle`,
        typeArguments: [shareType],
        arguments: [recording, adminCap, tx.pure.string(this._subtitle)],
      });
    }

    // Language
    if (this._language) {
      const languageCode = tx.moveCall({
        target: `${pkg}::language_code::new`,
        arguments: [tx.pure.string(this._language)],
      });
      tx.moveCall({
        target: `${pkg}::recording::set_language`,
        typeArguments: [shareType],
        arguments: [recording, adminCap, languageCode],
      });
    }

    // Credits
    for (const { contributorId, credit } of this._credits) {
      const creditObj = makeRecordingCredit(tx, pkg, credit);
      tx.moveCall({
        target: `${pkg}::recording::add_credit`,
        typeArguments: [shareType],
        arguments: [recording, adminCap, tx.object(contributorId), creditObj],
      });
    }

    // Primary artists
    for (const contributorId of this._primaryArtistIds) {
      tx.moveCall({
        target: `${pkg}::recording::add_primary_artist`,
        typeArguments: [shareType],
        arguments: [recording, adminCap, tx.object(contributorId)],
      });
    }

    // Featured artists
    for (const contributorId of this._featuredArtistIds) {
      tx.moveCall({
        target: `${pkg}::recording::add_featured_artist`,
        typeArguments: [shareType],
        arguments: [recording, adminCap, tx.object(contributorId)],
      });
    }

    // Primary genre override
    if (this._primaryGenreId) {
      tx.moveCall({
        target: `${pkg}::recording::set_primary_genre`,
        typeArguments: [shareType],
        arguments: [recording, adminCap, tx.object(this._primaryGenreId)],
      });
    }

    // Secondary genres
    for (const genreId of this._secondaryGenreIds) {
      tx.moveCall({
        target: `${pkg}::recording::add_secondary_genre`,
        typeArguments: [shareType],
        arguments: [recording, adminCap, tx.object(genreId)],
      });
    }

    // Musical key
    if (this._musicalKey) {
      const musicalKey = makeMusicalKey(tx, pkg, this._musicalKey);
      tx.moveCall({
        target: `${pkg}::recording::set_musical_key`,
        typeArguments: [shareType],
        arguments: [recording, adminCap, musicalKey],
      });
    }

    // Time signature
    if (this._timeSignature) {
      const timeSignature = makeTimeSignature(tx, pkg, this._timeSignature);
      tx.moveCall({
        target: `${pkg}::recording::set_time_signature`,
        typeArguments: [shareType],
        arguments: [recording, adminCap, timeSignature],
      });
    }

    // Tempo
    if (this._tempoBpm !== undefined) {
      tx.moveCall({
        target: `${pkg}::recording::set_tempo_bpm`,
        typeArguments: [shareType],
        arguments: [recording, adminCap, tx.pure.u16(this._tempoBpm)],
      });
    }

    // Stems
    for (const stem of this._stems) {
      const stemObj = makeStem(tx, pkg, stem);
      tx.moveCall({
        target: `${pkg}::recording::add_stem`,
        typeArguments: [shareType],
        arguments: [recording, adminCap, stemObj],
      });
    }
  }
}

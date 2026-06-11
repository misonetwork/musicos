// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

import type { ClientWithCoreApi, SuiClientRegistration } from "@mysten/sui/client";
import type { SuiGraphQLClient } from "@mysten/sui/graphql";
import * as parsers from "./parsers.ts";
import * as queries from "./queries.ts";
import * as transactions from "./transactions.ts";
import type { Composition, CompositionAdminCap, Party, Recording, RecordingAdminCap, Release, ReleaseAdminCap } from "./types.ts";

// Generated call modules (type-safe Move calls) and BCS structs.
import * as composition from "./contracts/musicos/composition.ts";
import * as recording from "./contracts/musicos/recording.ts";
import * as release from "./contracts/musicos/release.ts";
import * as deal from "./contracts/musicos/deal.ts";
import * as track from "./contracts/musicos/track.ts";
import * as disc from "./contracts/musicos/disc.ts";
import * as coverArt from "./contracts/musicos/cover_art.ts";
import * as compositionRole from "./contracts/musicos/composition_party_role.ts";
import * as recordingRole from "./contracts/musicos/recording_party_role.ts";
import * as releaseRole from "./contracts/musicos/release_party_role.ts";

export interface MusicOSOptions<Name extends string = "musicos"> {
  /** Name for the client extension. Defaults to "musicos". */
  name?: Name;
  /** The MusicOS package ID. Required for type-based queries and derivation. */
  musicOsPackageId: string;
  /** Optional GraphQL client for type-based queries (getByShareType, getOwned*, etc.). */
  graphqlClient?: SuiGraphQLClient;
}

/**
 * Creates a MusicOS client extension for use with `$extend()`.
 *
 * @example
 * ```ts
 * const client = new SuiGrpcClient({ network: 'testnet' })
 *   .$extend(musicos({ musicOsPackageId: '0x...' }));
 * const composition = await client.musicos.getCompositionById('0x...');
 * ```
 */
export function musicos<const Name extends string = "musicos">(
  options: MusicOSOptions<Name>,
): SuiClientRegistration<ClientWithCoreApi, Name, MusicOSClient> {
  const name = (options.name ?? "musicos") as Name;
  return {
    name,
    register: (client) => new MusicOSClient(client, options),
  };
}

export class MusicOSClient {
  #client: ClientWithCoreApi;
  #graphqlClient?: SuiGraphQLClient;
  #musicOsPackageId: string;

  constructor(client: ClientWithCoreApi, options: Omit<MusicOSOptions, "name">) {
    this.#client = client;
    this.#graphqlClient = options.graphqlClient;
    this.#musicOsPackageId = options.musicOsPackageId;
  }

  // === Composition ===

  async getCompositionById(compositionId: string): Promise<Composition> {
    return queries.getCompositionById(this.#client, compositionId);
  }
  async getCompositionsByIds(ids: string[]): Promise<Record<string, Composition>> {
    return queries.getCompositionsByIds(this.#client, ids);
  }
  async getCompositionShareType(compositionId: string): Promise<string> {
    return queries.getCompositionShareType(this.#client, compositionId);
  }
  async getCompositionByShareType(shareType: string): Promise<Composition> {
    return queries.getCompositionByShareType(this.#client, this.#requireGraphQL(), shareType, this.#musicOsPackageId);
  }
  async getCompositionAdminCapById(adminCapId: string): Promise<CompositionAdminCap> {
    return queries.getCompositionAdminCapById(this.#client, adminCapId);
  }
  async getOwnedCompositionAdminCaps(owner: string): Promise<CompositionAdminCap[]> {
    return queries.getOwnedCompositionAdminCaps(this.#requireGraphQL(), owner, this.#musicOsPackageId);
  }
  deriveCompositionAdminCapId(compositionId: string): string {
    return queries.deriveCompositionAdminCapId(compositionId, this.#musicOsPackageId);
  }

  // === Recording ===

  async getRecordingById(recordingId: string): Promise<Recording> {
    return queries.getRecordingById(this.#client, recordingId);
  }
  async getRecordingsByIds(ids: string[]): Promise<Record<string, Recording>> {
    return queries.getRecordingsByIds(this.#client, ids);
  }
  async getRecordingShareType(recordingId: string): Promise<string> {
    return queries.getRecordingShareType(this.#client, recordingId);
  }
  async getRecordingByShareType(shareType: string): Promise<Recording> {
    return queries.getRecordingByShareType(this.#client, this.#requireGraphQL(), shareType, this.#musicOsPackageId);
  }
  async getRecordingAdminCapById(adminCapId: string): Promise<RecordingAdminCap> {
    return queries.getRecordingAdminCapById(this.#client, adminCapId);
  }
  async getOwnedRecordingAdminCaps(owner: string): Promise<RecordingAdminCap[]> {
    return queries.getOwnedRecordingAdminCaps(this.#requireGraphQL(), owner, this.#musicOsPackageId);
  }
  deriveRecordingAdminCapId(recordingId: string): string {
    return queries.deriveRecordingAdminCapId(recordingId, this.#musicOsPackageId);
  }
  async getAdministeredRecordings(owner: string): Promise<Recording[]> {
    return queries.getAdministeredRecordings(this.#client, this.#requireGraphQL(), owner, this.#musicOsPackageId);
  }

  // === Release ===

  async getReleaseById(releaseId: string): Promise<Release> {
    return queries.getReleaseById(this.#client, releaseId);
  }
  async getReleasesByIds(ids: string[]): Promise<Record<string, Release>> {
    return queries.getReleasesByIds(this.#client, ids);
  }
  async getReleaseAdminCapById(adminCapId: string): Promise<ReleaseAdminCap> {
    return queries.getReleaseAdminCapById(this.#client, adminCapId);
  }
  deriveReleaseAdminCapId(releaseId: string): string {
    return queries.deriveReleaseAdminCapId(releaseId, this.#musicOsPackageId);
  }
  async getOwnedReleaseAdminCaps(owner: string): Promise<ReleaseAdminCap[]> {
    return queries.getOwnedReleaseAdminCaps(this.#client, owner, this.#musicOsPackageId);
  }
  async getReleaseRegistry(): Promise<string> {
    return queries.getReleaseRegistry(this.#requireGraphQL(), this.#musicOsPackageId);
  }

  // === Party & Share Currency ===

  async getParty(partyId: string): Promise<Party> {
    return queries.getParty(this.#client, partyId);
  }
  async getShareCurrencyType(shareCurrencyId: string): Promise<string> {
    return queries.getShareCurrencyType(this.#client, shareCurrencyId);
  }
  async getShareCurrencyTreasuryCap(shareCurrencyId: string, owner: string): Promise<string> {
    return queries.getShareCurrencyTreasuryCap(this.#client, shareCurrencyId, owner);
  }

  // === Transaction builders (thunks) ===

  get tx() {
    const client = this.#client;
    return {
      createParty: transactions.createParty,
      publishShareCurrency: transactions.publishShareCurrency,
      initializeShareCurrency: transactions.initializeShareCurrency,
      publishComposition: (p: Omit<transactions.PublishCompositionParams, "client">) =>
        transactions.publishComposition({ ...p, client }),
      publishRecording: (p: Omit<transactions.PublishRecordingParams, "client">) =>
        transactions.publishRecording({ ...p, client }),
      createDeal: transactions.createDeal,
      rejectDeal: transactions.rejectDeal,
      publishRelease: transactions.publishRelease,
      publishReleaseFromDeals: transactions.publishReleaseFromDeals,
    };
  }

  // === Generated type-safe Move calls (for tx.add) ===

  get call() {
    return { composition, recording, release, deal, track, disc, coverArt, compositionRole, recordingRole, releaseRole };
  }

  // === Generated BCS structs (for parsing object/event content) ===

  get bcs() {
    return {
      Composition: composition.Composition,
      Recording: recording.Recording,
      Release: release.Release,
      Deal: deal.Deal,
      Track: track.Track,
      Disc: disc.Disc,
      CoverArt: coverArt.CoverArt,
      CompositionPublishedEvent: composition.CompositionPublishedEvent,
      CompositionRoyaltySetEvent: composition.CompositionRoyaltySetEvent,
      RecordingPublishedEvent: recording.RecordingPublishedEvent,
      ReleasePublishedEvent: release.ReleasePublishedEvent,
      DealCreatedEvent: deal.DealCreatedEvent,
      DealAcceptedEvent: deal.DealAcceptedEvent,
      DealRejectedEvent: deal.DealRejectedEvent,
    };
  }

  // === Event parsers ===

  get parse() {
    return {
      compositionPublishedEvent: parsers.parseCompositionPublishedEvent,
      compositionRoyaltySetEvent: parsers.parseCompositionRoyaltySetEvent,
      recordingPublishedEvent: parsers.parseRecordingPublishedEvent,
      releasePublishedEvent: parsers.parseReleasePublishedEvent,
      dealCreatedEvent: parsers.parseDealCreatedEvent,
      dealAcceptedEvent: parsers.parseDealAcceptedEvent,
      dealRejectedEvent: parsers.parseDealRejectedEvent,
    };
  }

  #requireGraphQL(): SuiGraphQLClient {
    if (!this.#graphqlClient) {
      throw new Error("GraphQL client required. Pass graphqlClient to musicos() options.");
    }
    return this.#graphqlClient;
  }
}

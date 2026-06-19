// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

import type { ClientWithCoreApi, SuiClientRegistration } from "@mysten/sui/client";
import type { SuiGraphQLClient } from "@mysten/sui/graphql";
import * as parsers from "./parsers.ts";
import * as queries from "./queries.ts";
import * as transactions from "./transactions.ts";
import type { Composition, CompositionAdminCap, Recording, RecordingAdminCap, Release, ReleaseAdminCap } from "./types.ts";

// Generated call modules (type-safe Move calls) and BCS structs.
import * as composition from "./contracts/miso/composition.ts";
import * as recording from "./contracts/miso/recording.ts";
import * as release from "./contracts/miso/release.ts";
import * as deal from "./contracts/miso/deal.ts";
import * as track from "./contracts/miso/track.ts";
import * as disc from "./contracts/miso/disc.ts";

export interface MisoOptions<Name extends string = "miso"> {
  /** Name for the client extension. Defaults to "miso". */
  name?: Name;
  /** The Miso package ID. Required for type-based queries and derivation. */
  misoPackageId: string;
  /** Optional GraphQL client for type-based queries (getByShareType, getOwned*, etc.). */
  graphqlClient?: SuiGraphQLClient;
}

/**
 * Creates a Miso client extension for use with `$extend()`.
 *
 * @example
 * ```ts
 * const client = new SuiGrpcClient({ network: 'testnet' })
 *   .$extend(miso({ misoPackageId: '0x...' }));
 * const composition = await client.miso.getCompositionById('0x...');
 * ```
 */
export function miso<const Name extends string = "miso">(
  options: MisoOptions<Name>,
): SuiClientRegistration<ClientWithCoreApi, Name, MisoClient> {
  const name = (options.name ?? "miso") as Name;
  return {
    name,
    register: (client) => new MisoClient(client, options),
  };
}

export class MisoClient {
  #client: ClientWithCoreApi;
  #graphqlClient?: SuiGraphQLClient;
  #misoPackageId: string;

  constructor(client: ClientWithCoreApi, options: Omit<MisoOptions, "name">) {
    this.#client = client;
    this.#graphqlClient = options.graphqlClient;
    this.#misoPackageId = options.misoPackageId;
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
    return queries.getCompositionByShareType(this.#client, this.#requireGraphQL(), shareType, this.#misoPackageId);
  }
  async getCompositionAdminCapById(adminCapId: string): Promise<CompositionAdminCap> {
    return queries.getCompositionAdminCapById(this.#client, adminCapId);
  }
  async getOwnedCompositionAdminCaps(owner: string): Promise<CompositionAdminCap[]> {
    return queries.getOwnedCompositionAdminCaps(this.#requireGraphQL(), owner, this.#misoPackageId);
  }
  deriveCompositionAdminCapId(compositionId: string): string {
    return queries.deriveCompositionAdminCapId(compositionId, this.#misoPackageId);
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
    return queries.getRecordingByShareType(this.#client, this.#requireGraphQL(), shareType, this.#misoPackageId);
  }
  async getRecordingAdminCapById(adminCapId: string): Promise<RecordingAdminCap> {
    return queries.getRecordingAdminCapById(this.#client, adminCapId);
  }
  async getOwnedRecordingAdminCaps(owner: string): Promise<RecordingAdminCap[]> {
    return queries.getOwnedRecordingAdminCaps(this.#requireGraphQL(), owner, this.#misoPackageId);
  }
  deriveRecordingAdminCapId(recordingId: string): string {
    return queries.deriveRecordingAdminCapId(recordingId, this.#misoPackageId);
  }
  async getAdministeredRecordings(owner: string): Promise<Recording[]> {
    return queries.getAdministeredRecordings(this.#client, this.#requireGraphQL(), owner, this.#misoPackageId);
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
    return queries.deriveReleaseAdminCapId(releaseId, this.#misoPackageId);
  }
  async getOwnedReleaseAdminCaps(owner: string): Promise<ReleaseAdminCap[]> {
    return queries.getOwnedReleaseAdminCaps(this.#client, owner, this.#misoPackageId);
  }
  async getReleaseRegistry(): Promise<string> {
    return queries.getReleaseRegistry(this.#requireGraphQL(), this.#misoPackageId);
  }

  // === Share Currency ===

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
    return { composition, recording, release, deal, track, disc };
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
      throw new Error("GraphQL client required. Pass graphqlClient to miso() options.");
    }
    return this.#graphqlClient;
  }
}

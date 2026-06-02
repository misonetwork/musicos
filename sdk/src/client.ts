// Copyright (c) Unconfirmed Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

import type { ClientWithCoreApi, SuiClientRegistration } from "@mysten/sui/client";
import type { SuiGraphQLClient } from "@mysten/sui/graphql";
import * as parsers from "./parsers.ts";
import * as queries from "./queries.ts";
import * as transactions from "./transactions.ts";
import type { Composition, CompositionAdminCap, RecordingAdminCap, ReleaseAdminCap, Recording, Release, Party } from "./types.ts";

export interface MusicOSOptions<Name extends string = "musicos"> {
  /** Name for the client extension. Defaults to "musicos". */
  name?: Name;
  /** The MusicOS package ID. Required for type-based queries and derivation. */
  musicOsPackageId: string;
  /** Optional GraphQL client for type-based queries (getByShareType, getOwned, etc.). */
  graphqlClient?: SuiGraphQLClient;
}

/**
 * Creates a MusicOS client extension for use with `$extend()`.
 *
 * @example
 * ```ts
 * const client = new SuiGrpcClient({ network: 'testnet' })
 *   .$extend(musicos({ musicOsPackageId: '0x...' }));
 *
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

  // ============================================================================
  // Composition (Core API)
  // ============================================================================

  async getCompositionById(compositionId: string): Promise<Composition> {
    return queries.getCompositionById(this.#client, compositionId);
  }

  async getCompositionAdminCapById(adminCapId: string): Promise<CompositionAdminCap> {
    return queries.getCompositionAdminCapById(this.#client, adminCapId);
  }

  deriveCompositionAdminCapId(compositionId: string): string {
    return queries.deriveCompositionAdminCapId(compositionId, this.#musicOsPackageId);
  }

  async getCompositionShareType(compositionId: string): Promise<string> {
    return queries.getCompositionShareType(this.#client, compositionId);
  }

  // ============================================================================
  // Composition (GraphQL)
  // ============================================================================

  async getCompositionByShareType(shareType: string): Promise<Composition> {
    return queries.getCompositionByShareType(this.#requireGraphQL(), shareType, this.#musicOsPackageId);
  }

  async getCompositionAdminCapByShareType(shareType: string): Promise<CompositionAdminCap> {
    return queries.getCompositionAdminCapByShareType(this.#requireGraphQL(), shareType, this.#musicOsPackageId);
  }

  async getOwnedCompositionAdminCaps(owner: string): Promise<CompositionAdminCap[]> {
    return queries.getOwnedCompositionAdminCaps(this.#requireGraphQL(), owner, this.#musicOsPackageId);
  }

  // ============================================================================
  // Recording (Core API)
  // ============================================================================

  async getRecordingById(recordingId: string): Promise<Recording> {
    return queries.getRecordingById(this.#client, recordingId);
  }

  async getRecordingsByIds(recordingIds: string[]): Promise<Record<string, Recording>> {
    return queries.getRecordingsByIds(this.#client, recordingIds);
  }

  async getRecordingAdminCapById(adminCapId: string): Promise<RecordingAdminCap> {
    return queries.getRecordingAdminCapById(this.#client, adminCapId);
  }

  deriveRecordingAdminCapId(recordingId: string): string {
    return queries.deriveRecordingAdminCapId(recordingId, this.#musicOsPackageId);
  }

  async getRecordingShareType(recordingId: string): Promise<string> {
    return queries.getRecordingShareType(this.#client, recordingId);
  }

  // ============================================================================
  // Recording (GraphQL)
  // ============================================================================

  async getRecordingByShareType(shareType: string): Promise<Recording> {
    return queries.getRecordingByShareType(this.#requireGraphQL(), shareType, this.#musicOsPackageId);
  }

  async getRecordingAdminCapByShareType(shareType: string): Promise<RecordingAdminCap> {
    return queries.getRecordingAdminCapByShareType(this.#requireGraphQL(), shareType, this.#musicOsPackageId);
  }

  async getOwnedRecordingAdminCaps(owner: string): Promise<RecordingAdminCap[]> {
    return queries.getOwnedRecordingAdminCaps(this.#requireGraphQL(), owner, this.#musicOsPackageId);
  }

  async getAdministeredRecordings(owner: string): Promise<Recording[]> {
    return queries.getAdministeredRecordings(this.#requireGraphQL(), owner, this.#musicOsPackageId);
  }

  // ============================================================================
  // Release (Core API)
  // ============================================================================

  async getReleaseById(releaseId: string): Promise<Release> {
    return queries.getReleaseById(this.#client, releaseId);
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

  // ============================================================================
  // Party, Share Currency (Core API)
  // ============================================================================

  async getParty(partyId: string): Promise<Party> {
    return queries.getParty(this.#client, partyId);
  }

  async getShareCurrencyType(shareCurrencyId: string): Promise<string> {
    return queries.getShareCurrencyType(this.#client, shareCurrencyId);
  }

  async getShareCurrencyTreasuryCap(shareCurrencyId: string, owner: string): Promise<string> {
    return queries.getShareCurrencyTreasuryCap(this.#client, shareCurrencyId, owner);
  }

  async getObjects(objectIds: string[]): Promise<Record<string, unknown>> {
    return queries.getObjects(this.#client, objectIds);
  }

  // ============================================================================
  // Registry (GraphQL)
  // ============================================================================

  async getReleaseRegistry(): Promise<string> {
    return queries.getReleaseRegistry(this.#requireGraphQL(), this.#musicOsPackageId);
  }

  // ============================================================================
  // Transaction Builders
  // ============================================================================

  get tx() {
    const client = this.#client;
    return {
      createParty: transactions.createParty,
      publishShareCurrency: transactions.publishShareCurrency,
      initializeShareCurrency: transactions.initializeShareCurrency,
      publishComposition: (params: Omit<transactions.PublishCompositionParams, "client">) =>
        transactions.publishComposition({ ...params, client }),
      publishRecording: (params: Omit<transactions.PublishRecordingParams, "client">) =>
        transactions.publishRecording({ ...params, client }),
      createDeal: transactions.createDeal,
      publishRelease: transactions.publishRelease,
      publishReleaseFromDeals: transactions.publishReleaseFromDeals,
    };
  }

  // ============================================================================
  // Event Parsers
  // ============================================================================

  get parse() {
    return {
      compositionPublishedEvent: parsers.parseCompositionPublishedEvent,
      compositionRoyaltySetEvent: parsers.parseCompositionRoyaltySetEvent,
      recordingPublishedEvent: parsers.parseRecordingPublishedEvent,
      releasePublishedEvent: parsers.parseReleasePublishedEvent,
      audioIngestedEvent: parsers.parseAudioIngestedEvent,
      dealCreatedEvent: parsers.parseDealCreatedEvent,
      dealDestroyedEvent: parsers.parseDealDestroyedEvent,
    };
  }

  // ============================================================================
  // Private
  // ============================================================================

  #requireGraphQL(): SuiGraphQLClient {
    if (!this.#graphqlClient) {
      throw new Error("GraphQL client required. Pass graphqlClient to musicos() options.");
    }
    return this.#graphqlClient;
  }
}

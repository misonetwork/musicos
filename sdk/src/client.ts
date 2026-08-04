// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

import type { ClientWithCoreApi, SuiClientRegistration } from "@mysten/sui/client";
import type { SuiGraphQLClient } from "@mysten/sui/graphql";
import type { Signer } from "@mysten/sui/cryptography";
import type { TxThunk } from "./transactions.ts";
import * as parsers from "./parsers.ts";
import * as queries from "./queries.ts";
import * as transactions from "./transactions.ts";
import * as share from "./share.ts";
import * as view from "./view.ts";
import type { Composition, CompositionAdminCap, Deal, Recording, RecordingAdminCap, Release, ReleaseAdminCap } from "./types.ts";

// Generated call modules (type-safe Move calls) and BCS structs.
import * as composition from "./contracts/miso/composition.ts";
import * as recording from "./contracts/miso/recording.ts";
import * as release from "./contracts/miso/release.ts";
import * as deal from "./contracts/miso/deal.ts";
import * as track from "./contracts/miso/track.ts";

export interface MisoOptions<Name extends string = "miso"> {
  /** Name for the client extension. Defaults to "miso". */
  name?: Name;
  /** The Miso package ID. Required for type-based queries and derivation. */
  misoPackageId: string;
  /**
   * The minato share-disperse package ID. Bound into `tx.publish*` builders so
   * callers don't repeat it; required for the composition/recording builders (they
   * disperse shares via minato).
   */
  minatoPackageId?: string;
  /** Optional GraphQL client for type-based queries (getByShareType, getOwned*, etc.). */
  graphqlClient?: SuiGraphQLClient;
}

/**
 * Wraps a builder so the client's `misoPackageId` is injected, dropping it from
 * the caller's params. Explicit call-sites (the free functions in
 * `./transactions`) remain available for full control.
 */
function bindPackages<P extends { misoPackageId: string }>(
  fn: (params: P) => TxThunk,
  misoPackageId: string,
): (params: Omit<P, "misoPackageId">) => TxThunk {
  return (params) => fn({ misoPackageId, ...params } as unknown as P);
}

/**
 * Like {@link bindPackages}, for builders that also disperse shares via minato.
 * `minatoPackageId` is optional on the client, so the guard throws at the
 * builder call — not at client construction — keeping the minato-free builders
 * (deals, releases) usable without it.
 */
function bindPackagesWithMinato<P extends { misoPackageId: string; minatoPackageId: string }>(
  fn: (params: P) => TxThunk,
  misoPackageId: string,
  minatoPackageId: string | undefined,
): (params: Omit<P, "misoPackageId" | "minatoPackageId">) => TxThunk {
  return (params) => {
    if (!minatoPackageId) {
      throw new Error(
        "MisoClient: minatoPackageId is required for tx builders that disperse shares " +
          "(publishComposition, publishRecording, publishCompositionAndRecording). Pass minatoPackageId to miso() options.",
      );
    }
    return fn({ misoPackageId, minatoPackageId, ...params } as unknown as P);
  };
}

/** Defaults `options.package` to `pkg` for every call-function in a generated module. */
function bindModulePackage<M extends object>(mod: M, pkg: string): M {
  const out: Record<string, unknown> = {};
  for (const [key, value] of Object.entries({ ...mod })) {
    out[key] =
      typeof value === "function"
        ? (options: { package?: string }) => (value as (o: unknown) => unknown)({ package: pkg, ...options })
        : value;
  }
  return out as M;
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
  #minatoPackageId?: string;

  constructor(client: ClientWithCoreApi, options: Omit<MisoOptions, "name">) {
    this.#client = client;
    this.#graphqlClient = options.graphqlClient;
    this.#misoPackageId = options.misoPackageId;
    this.#minatoPackageId = options.minatoPackageId;
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

  // === Deal ===

  async getDealById(dealId: string): Promise<Deal> {
    return queries.getDealById(this.#client, dealId);
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
    const miso = this.#misoPackageId;
    const minato = this.#minatoPackageId;
    return {
      // Package-id-free builders — pass through unchanged.
      publishShareCurrency: transactions.publishShareCurrency,
      initializeShareCurrency: transactions.initializeShareCurrency,
      // Miso builders — miso (and, where shares are dispersed, minato) package
      // ids bound from the client. The minato-binding builders throw when the
      // client was created without a minatoPackageId.
      publishComposition: bindPackagesWithMinato(transactions.publishComposition, miso, minato),
      publishRecording: bindPackagesWithMinato(transactions.publishRecording, miso, minato),
      publishCompositionAndRecording: bindPackagesWithMinato(transactions.publishCompositionAndRecording, miso, minato),
      createDeal: bindPackages(transactions.createDeal, miso),
      rejectDeal: bindPackages(transactions.rejectDeal, miso),
      publishRelease: bindPackages(transactions.publishRelease, miso),
      publishReleaseFromDeals: bindPackages(transactions.publishReleaseFromDeals, miso),
    };
  }

  // === Share currency provisioning (executes; Signer pattern) ===

  /** Publishes + initializes a fresh share currency (two txs). */
  async createShareCurrency(signer: Signer, params: share.CreateShareCurrencyParams): Promise<share.ShareCurrency> {
    return share.createShareCurrency(this.#client, signer, params);
  }

  // === Simulate-based reads (view) ===

  get view() {
    const client = this.#client;
    const misoPackageId = this.#misoPackageId;
    return {
      deriveReleaseId: (params: view.DeriveReleaseIdParams) => view.deriveReleaseId(client, misoPackageId, params),
    };
  }

  // === Generated type-safe Move calls (for tx.add) ===

  get call() {
    const pkg = this.#misoPackageId;
    return {
      composition: bindModulePackage(composition, pkg),
      recording: bindModulePackage(recording, pkg),
      release: bindModulePackage(release, pkg),
      deal: bindModulePackage(deal, pkg),
      track: bindModulePackage(track, pkg),
    };
  }

  // === Generated BCS structs (for parsing object/event content) ===

  get bcs() {
    return {
      Composition: composition.Composition,
      Recording: recording.Recording,
      Release: release.Release,
      Deal: deal.Deal,
      Track: track.Track,
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

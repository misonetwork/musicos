// Copyright (c) Studio Mirai, LLC
// SPDX-License-Identifier: Apache-2.0

import type { ClientWithCoreApi, SuiClientRegistration } from "@mysten/sui/client";
import { Transaction } from "@mysten/sui/transactions";
import * as parsers from "./parsers.ts";
import * as queries from "./queries.ts";
import * as transactions from "./transactions.ts";

export type MusicOSClient = ReturnType<typeof createMusicOSClient>;

export interface MusicOSExtensionOptions<Name extends string = "musicos"> {
  /** Name for the client extension. Defaults to "musicos". */
  name?: Name;
}

export function musicos<const Name extends string = "musicos">(
  options: MusicOSExtensionOptions<Name> = {}
): SuiClientRegistration<ClientWithCoreApi, Name, MusicOSClient> {
  const name = (options.name ?? "musicos") as Name;

  return {
    name,
    register: (client) => createMusicOSClient(client),
  };
}

function createMusicOSClient(client: ClientWithCoreApi) {
  return {
    // Core read helpers (Core API compatible).
    getShareCurrencyType: (shareCurrencyId: string) =>
      queries.getShareCurrencyType(client, shareCurrencyId),
    getShareCurrencyTreasuryCap: (shareCurrencyId: string, owner: string) =>
      queries.getShareCurrencyTreasuryCap(client, shareCurrencyId, owner),
    getRecordingShareType: (recordingId: string) => queries.getRecordingShareType(client, recordingId),
    getRelease: (releaseId: string) => queries.getRelease(client, releaseId),
    getRecording: (recordingId: string) => queries.getRecording(client, recordingId),
    getGenre: (genreId: string) => queries.getGenre(client, genreId),
    getObjects: (objectIds: string[]) => queries.getObjects(client, objectIds),
    getRecordings: (recordingIds: string[]) => queries.getRecordings(client, recordingIds),

    // Transaction builders (return full Transaction objects).
    tx: {
      createParty: (params: transactions.CreatePartyParams) => {
        const tx = new Transaction();
        tx.add(transactions.createPartyCall(params));
        return tx;
      },
      createGenre: (params: transactions.CreateGenreParams) => {
        const tx = new Transaction();
        tx.add(transactions.createGenreCall(params));
        return tx;
      },
      publishShareCurrency: () => {
        const tx = new Transaction();
        tx.add(transactions.publishShareCurrencyCall());
        return tx;
      },
      initializeShareCurrency: (params: transactions.InitializeShareCurrencyParams) => {
        const tx = new Transaction();
        tx.add(transactions.initializeShareCurrencyCall(params));
        return tx;
      },
      publishComposition: async (params: transactions.PublishCompositionParams) => {
        const tx = new Transaction();
        tx.add(transactions.publishCompositionCall(params));
        return tx;
      },
      publishRecording: async (params: transactions.PublishRecordingParams) => {
        const tx = new Transaction();
        tx.add(transactions.publishRecordingCall(params));
        return tx;
      },
      createDeal: (params: transactions.CreateDealParams) => {
        const tx = new Transaction();
        tx.add(transactions.createDealCall(params));
        return tx;
      },
      publishRelease: (params: transactions.PublishReleaseParams) => {
        const tx = new Transaction();
        tx.add(transactions.publishReleaseCall(params));
        return tx;
      },
      publishReleaseFromDeals: (params: transactions.PublishReleaseFromDealsParams) => {
        const tx = new Transaction();
        tx.add(transactions.publishReleaseFromDealsCall(params));
        return tx;
      },
      distributeReleaseRevenue: (params: transactions.DistributeReleaseRevenueParams) => {
        const tx = new Transaction();
        tx.add(transactions.distributeReleaseRevenueCall(params));
        return tx;
      },
    },

    // Call helpers (transaction thunks for tx.add()).
    call: {
      createParty: transactions.createPartyCall,
      createGenre: transactions.createGenreCall,
      publishShareCurrency: transactions.publishShareCurrencyCall,
      initializeShareCurrency: transactions.initializeShareCurrencyCall,
      publishComposition: transactions.publishCompositionCall,
      publishRecording: transactions.publishRecordingCall,
      createDeal: transactions.createDealCall,
      publishRelease: transactions.publishReleaseCall,
      publishReleaseFromDeals: transactions.publishReleaseFromDealsCall,
      distributeReleaseRevenue: transactions.distributeReleaseRevenueCall,
    },

    // BCS types for event parsing.
    bcs: {
      PartyCreatedEvent: parsers.PartyCreatedEventBcs,
      PartyAddedToGroupEvent: parsers.PartyAddedToGroupEventBcs,
      PartyRemovedFromGroupEvent: parsers.PartyRemovedFromGroupEventBcs,
    },
  };
}

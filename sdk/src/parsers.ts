// Copyright (c) Studio Mirai, LLC
// SPDX-License-Identifier: Apache-2.0

import { bcs } from "@mysten/sui/bcs";
import type { PartyCreatedEvent, PartyAddedToGroupEvent, PartyRemovedFromGroupEvent } from "./types.ts";

export const PartyCreatedEventBcs = bcs.struct("PartyCreatedEvent", {
  party_id: bcs.Address,
  name: bcs.String,
});

export const PartyAddedToGroupEventBcs = bcs.struct("PartyAddedToGroupEvent", {
  group_id: bcs.Address,
  party_id: bcs.Address,
});

export const PartyRemovedFromGroupEventBcs = bcs.struct("PartyRemovedFromGroupEvent", {
  group_id: bcs.Address,
  party_id: bcs.Address,
});

export function parsePartyCreatedEvent(bcsBytes: Uint8Array): PartyCreatedEvent {
  const parsed = PartyCreatedEventBcs.parse(bcsBytes);
  return {
    partyId: parsed.party_id,
    name: parsed.name,
  };
}

export function parsePartyAddedToGroupEvent(bcsBytes: Uint8Array): PartyAddedToGroupEvent {
  const parsed = PartyAddedToGroupEventBcs.parse(bcsBytes);
  return {
    groupId: parsed.group_id,
    partyId: parsed.party_id,
  };
}

export function parsePartyRemovedFromGroupEvent(bcsBytes: Uint8Array): PartyRemovedFromGroupEvent {
  const parsed = PartyRemovedFromGroupEventBcs.parse(bcsBytes);
  return {
    groupId: parsed.group_id,
    partyId: parsed.party_id,
  };
}

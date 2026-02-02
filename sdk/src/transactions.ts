// Copyright (c) Unconfirmed Labs, LLC
// SPDX-License-Identifier: Apache-2.0

import { bcs } from "@mysten/sui/bcs";
import type { SuiGrpcClient } from "@mysten/sui/grpc";
import { Transaction } from "@mysten/sui/transactions";
import { getShareCurrencyType, getShareCurrencyTreasuryCap } from "./queries.ts";
import type {
  CompositionPartyRoleType,
  RecordingPartyRole,
  RecordingPartyRoleLevel,
  MusicalKey,
  TimeSignature,
} from "./types.ts";

/** Sui Clock shared object address. */
const SUI_CLOCK_OBJECT_ID = "0x6";

// ============================================================================
// Party
// ============================================================================

/** Type of party. */
export type PartyKindInput = "Individual" | "Group";

/** Parameters for creating a party. */
export interface CreatePartyParams {
  /** Type of party (Individual or Group). */
  kind: PartyKindInput;
  /** Human-readable name of the party. */
  name: string;
  /** For groups: IDs of individual parties to add as members. */
  memberIds?: string[];
  /** The address to transfer the PartyAdminCap to. */
  adminAddress: string;
  /** The MusicOS package ID. */
  musicOsPackageId: string;
}

/**
 * Builds a transaction that creates and shares a party.
 *
 * For individuals, creates a simple party with no members.
 * For groups, optionally adds member parties after creation.
 *
 * Note: Group members must be existing shared Individual parties.
 *
 * @returns Transaction that, when executed, returns a PartyAdminCap to the sender.
 */
export function createParty(params: CreatePartyParams): Transaction {
  const { kind, name, memberIds, adminAddress, musicOsPackageId } = params;

  const tx = new Transaction();

  // Create the PartyKind
  const partyKind = tx.moveCall({
    target: `${musicOsPackageId}::party::new_${kind.toLowerCase()}_kind`,
    arguments: [],
  });

  // Create the party - returns (Party, PartyAdminCap)
  const partyResult = tx.moveCall({
    target: `${musicOsPackageId}::party::new`,
    arguments: [partyKind, tx.pure.string(name)],
  });
  const party = partyResult[0]!;
  const partyAdminCap = partyResult[1]!;

  // For groups, add member parties
  if (kind === "Group" && memberIds && memberIds.length > 0) {
    for (const memberId of memberIds) {
      tx.moveCall({
        target: `${musicOsPackageId}::party::add_party`,
        arguments: [party, partyAdminCap, tx.object(memberId)],
      });
    }
  }

  // Share the party
  tx.moveCall({
    target: `${musicOsPackageId}::party::share`,
    arguments: [party, partyAdminCap],
  });

  tx.transferObjects([partyAdminCap], tx.pure.address(adminAddress));

  return tx;
}

// ============================================================================
// Share
// ============================================================================

/** Compiled bytecode for the Share module. */
const SHARE_BYTECODE = { "modules": ["oRzrCwYAAAAKAQAMAgwgAywWBEIEBUY7B4EBuwEIvAJgBpwD9xkKkx0GDJkdJwAOAQ8CBwIIAg0CEAACCAABAwcAAgQMAQABAwAIAAMBAAEAAQQGBAAFBQIAAAsAAQABEQMEAAMJCAIBAAMMBgcBCAMFAgUCBwgDBwgGAQsCAQgAAAEKAgEIAQEIAAcHCAMCCAEIAQgBCAEHCAYCCwQBCQALAgEJAAILBAEJAAcIBgxDb2luUmVnaXN0cnkTQ3VycmVuY3lJbml0aWFsaXplcgVTaGFyZQZTdHJpbmcLVHJlYXN1cnlDYXAJVHhDb250ZXh0A1VJRARjb2luDWNvaW5fcmVnaXN0cnkgZmluYWxpemVfYW5kX2RlbGV0ZV9tZXRhZGF0YV9jYXACaWQKaW5pdGlhbGl6ZQxuZXdfY3VycmVuY3kGb2JqZWN0BXNoYXJlBnN0cmluZwp0eF9jb250ZXh0BHV0ZjgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIKAgYFU0hBUkUKAg4NTXVzaWNPUyBTaGFyZQoC2RnXGWRhdGE6aW1hZ2Uvd2VicDtiYXNlNjQsVWtsR1JvWUpBQUJYUlVKUVZsQTRUSGtKQUFBdi84Ri9BSVVGYk51T3ZaR2UvSC9TbUxXbmJsTGJ0bTNiSE5UZG5kcm11TnlwYmJ1cGJTTkhFZHYzb256ZjkvdU85MWw5RWYyZkFMTDhiL25mOHIvbGY4di9sdjh0LzF2K3QveHYrZC95ditWL3kvK1cveTMvVy83L3owQ25uSlhhOUJzM2Q5WFdBNmV2M1h2NDlHWFFxeGRQSDkyL2VmSFV3WjEvV3pGbi9OQ3VqY3JrOHVRcGwxSWQvN29tOEMzRWpIOXlhc084a1MxTCtIQ1JSODB4bSs2bFFNcnd5K3YrMHJhWUMrdWthNzE4Umlwa1Q3bXpZV3pqekJ4anF6VGpPaFQ2YXV2b21xNmNZcS8zMjN1b04rbk1qQWJ1UEZKcTBUc29PL0hvOTBXNXc2M1hKYWoreFlLcU5yN0lPRDBjaHZodWFYbWV5TGs4SHNiNWNFSTJkc2l3TUJIR21ySzFGaXM0ajQrR0FkL3U1c1FHalIvRG9GOE1jV0dCREZ0aDRDOTYyUFZmMjJBWSsyWGQ1N0VXUnI5ZTh4VzlEOE92ci9jNnhzSHdYOXQxbnNNa21NRHBwUEdkL29RWkxLanhYUGZCREFhU3Z2YzRBVlBZWDkrNUhJY3BUUERWZG82N1lBNDNrTFpmQlpQWVFOdU5oa2tNc3V1NkpxbG1ZUTVwK3R5Uk1JdUZOSjNUQlpqRmk2VHBaOEEwRHRKMDVWTk5RNktmbm5PNkRkTzRpZlQ4UkpqSEpub3VlNXg1ZU91bzU5YkNQTTRoTFY4R0pyS0luanRnSXE2UWxpOERFemxFeisweUVVbnB0RnhCbU1odHBPVVhtNG1tV3M0OVVobVJUMjVkUFhmeTFMa0xWMjg5RDQ2VDQ3MlRsdXNONlZOdnI1blFvVlNXTlBTWjluUUZLamJ0TyttWC9mY1NCRnBBV3Y2NFpOY20xZktpcjIzTFhyMy9rdVBCUWhUVGNwbFRaYm83SWpzSm5MWEYxSU1SWCtrYWFmbGhrSGQ3RlJMZlZtTFlsdEN2TUZ6UEhaZm1jQm1TMVZaMi9PbVVMNU9VWHN0NUpFa1Myb25rOXV1MElmSUxiQ2N0M3d4eUhzbEk4cWRwdkRyaWMxcnF1V1Z5TEhFa05UcTMyWlg4S2NGT2V1NkdGT05Jb1JuSFB2L1lRdEx5SGlreVRDYTEycHFmK1ZCSlBWY1RFcTRqOVZZNkF1QW02Zm5SRXR6MVVCQlI5Y3NZcWVuV1NsQ08xR3pybDFIVFhSWnZOZkd5TFU2NGxPek1sQlBDYnlabXJpSmVIVzdxS0Z5VUV6ZU5FbTRiY2ZNUzRVYXowenJobXJEVFB1RUtzTk41NFRLdzB6M2hYTm5wbVhDTzdCUWtuQTg3dlJjdU96dEZDRmVaL1hxejAzdmhsckxUSytIdXM5TVQ0WkNMbSs2S040bWJMb3IzMnM1TSs4UkRIMlphSTBHUUd5L05sUUR6ZVdtc0RLakpTcDJsZVBzTko1V1hBbmQ5R1NtZEhMaWFubzhvUWc3Y3k4RkhseVRCMjhwc3RGSVdKUGJqb2o3U0FPczllS2lZUkhoUW1vVWM0eVJDOG5nN0E5RWhtWUJMUlJsb3BGeEltdXJLUG9Va0E1NDI0UjU2SlJ1d3o1OTVGc21INUtYcFdhZU1Bb0RvU1Y2TVEvZFZBSVNNOWVTYmNXb0FRc2Q3YzAybUJFVUFrVE16OGd6OXBnd2dmbGt1bHZGWENKQ3lyZ2pEMEU2VkFOaFhnMThLcGFnRnVOakd4aXkwVWpYQTQ0R3V2SkloU2psQThLU01uRUpERlFRay9CckFLTFl6S2dLd3R4YWJVTUVFTlFFM2U3b3dDZjJnS3VEOTVFdzg0bkJZV1VEaXFoSWNRcG1EMVFYZ1NCMEdvWVpLQTY2MnQ3TUhUVlFiOEdTQUMzYzQ3RkFjOE80N1o5NGd6NXVxQTE3MnRMTUdaWHVsUE9CZWE5YWdJaEhxQXk3VzRneXFIbXNBd0k2Y2pFRzE0NDBBY1JPYytZSWFKaG9COEtnK1gxQ2RHRU1BdHVaZ0N5b1hhZ3lJN3NjV1ZPaUZNUUFIc25JRlpRbzBDSVIzNFFweVdXOFF3UGFNVEVFMFBNa2dFTnlBSzZqOEM0TUFwdG1aZ3Z3MkdRVk9wR2NLb25ZaEJvRm5oYm1DTXU0d0NFUTE1Z3FpcnVIR2dKUmViRUZaZHhrRDhBTmJFRFY2WkF5WXdSZmtQQ0hPRURDTkw0aHliak1FVEdJTW9ubzNqQUEvY0FZNWRIaG9BT2pFR1VTT2ZWNnFMNmsyYXhBNUQzK25Pa1RrNXcwaTkySFBGSWQ3WHN4QlpHOTdVVzNZNWNBZFJGUjl0OUl3aGtHSS9GZkVLQ3k1UEljUStZeDRyQ3c4OVdZUklsdmpBNnJDSDB4Q1JBV1d4cWdKRGRpRXlPZTc1MHA2NWNVblJQYldweFdFcFp4Q1JLWFdKU2tuSllCWGlMTE9ERmNNRG5BTGtjZlF4MnBCZlhZaHNyVUtWTW9aaGlHaXFyc1Vnc29zUXhUd2U2SXlkak1OVVpZNU1ZcEFYcTRoU2pzbFVnMVQrSWJJYjBhTUNwNDVNQTVSeGhYSjhxRW02eEQ1NzVadk9mTVFOWHdzMjNQMkllY2ZFK1ZDSWZZaENqZ24xdzhNUkxaUmlUTHQ0U0NpWW5ja0N1WWhjbHNsRC9Md0VGR2ZSR2s2Y0JGVmZDdkxMRGFpWEU4azJjRkhsUG0ySEhjWmliSUZTWkZnWXlRcUdTc0RjbklTRFpHaUhDczVISldoTVN0UmtWUUpldkVTclpWZ0ZETVZrMkFHTTlGbDhlWngwM0R4bG5GVElmRis0U1o2Szl4YWR0b3YzQnAyV2l6Y2IrdzBYTGdWN05SVHVDWHMxRWE0dWV6VVVyZ2YyYW1MY01QWWFaQnczZGhwbEhCTjJHbWxjSlhaNllSd09ka3BXTFJVUjI3S0JkR0RpSnNIQ1JmSVRudUZXOHRONmVLRkc4Tk40eUI4TTJaeUNoSXZIek1OaC9EUk5sN0tFaVhlTWRMcDVRWTRLVzh6eEorcTFmN0FzNzdPYXZzT0VqYlZhZTR4QUlKRytTaXNRYW9FcVdsMVduZDhNR2FKdjZwcVIwUENpNlRUVDN3SXdMRTJUaXBxbVFBWnAraTAzUGprNEFWRlZXTWJsd0lwSyttMEh6OE53UFd4dVZTUy9RVGtETFpyTklkbm53WGc0bGgvUlRpUGlvU2tLMGlqMThBWHZqZTNWaHJwYk8yZlFkcXFPbTNWbHdJUXZYTm9ZWm04Ump5RnZLOGROSnBIekZmNDEzY2JocFMweTJDdjgwc2taSjVHR3IwWEJJdzVOck50YnFIU3RscnhIbktuNU5CcEowWDRZTmlKeFgwcitINDlwNkpkRmx5Ri9OdElvK2VCNEtHQjZ5WVBiRlkydThkbmVlUW8zbVRJbk0zWEU2SEdPanB0aW1pZm1CTDI3TmExQzJkUG5MbHc3ZmFqZDBsUTYwWFM2QTdQcFZGN0U1MVdDMmIwS3VuMHRhYWtxVTd6akRValIwbW45NFlKVFMydTFjNllrVjlJcCtlRENYM25wOVdtbXBGMnBOTnRMMDNJTHRMcWRXQSszMmJRYSt0TVNGM1M2dDV4NW1NVzZmVitNSjJIN1pydHJPbDQ2RXQ2dlFETVpuZ0FhZllaWmlPdU1tbDIyMnVUa2R5WWRIczltTXZrZHFUZC96UVhpUzFKdS92RW00cjRCcVRmKzhOTXZxOUlHajdRVE56SlJScmVIeVp5ancvcCtKbm1JV1cwQStsNGU1QnBlRldWOUh3RG1NVlYzcVRwaSt3MUIwRk5TZU9YWEo5a2VNbHpQRW52WjU3MDJ0aU9CSkQrdHpmY21taFlGK3NRRS9yMlBwWnFSTmRiRVNkbUhuQTQyV0NPMWlOMjlPMnlJZHd3WW44clJUenBXRzNXTlNPNE5zaWJPRE5qNTFXdmxmWm9rajh4YVA1K0c5NnE2ZUxFRXNTbiticXZ2SldxbEZkcmVtUWlkdld1TVdMVnpXUUZwTjc2dFhkZTRsdm5ZdTBucnI4U0xVdjhsVCsrcStGSkxKeStkS3VSaTdhZGZ4SXJTdVNkZlV1R05zeG5KNGIyekZ1eFlhZUI0MmF0WExObDcvSEFHM2Z1UDNyNjR2WHJGMDhlM0wxNmV2K1cxUXNtRG14WHM2QUhXZjYzL0cvNTMvSy81WC9MLzViL0xmOWIvcmY4Yi9uZjhyL2xmOHYvbHY4dC8ydENBQT09AAIBCggFAAEAAAERCwAxBgcAEQEHAREBBwERAQcCEQEKATgADAILATgBCwICAA=="], "dependencies": ["0x0000000000000000000000000000000000000000000000000000000000000001", "0x0000000000000000000000000000000000000000000000000000000000000002"], "digest": [111, 119, 41, 53, 175, 54, 5, 218, 185, 5, 106, 131, 123, 71, 30, 9, 136, 54, 155, 237, 122, 21, 225, 93, 202, 20, 172, 139, 116, 20, 255, 87] };

/**
 * Builds a transaction that publishes a new Share token package.
 *
 * This publishes an immutable package containing the Share coin type that can
 * be used for composition or recording ownership distribution.
 *
 * @returns Transaction that, when executed, creates a new Share package.
 */
export function publishShareCurrency(): Transaction {
  const tx = new Transaction();

  const upgradeCap = tx.publish(SHARE_BYTECODE);
  tx.moveCall({
    target: "0x2::package::make_immutable",
    arguments: [upgradeCap],
  });

  return tx;
}

/** Parameters for initializing a share currency. */
export interface InitializeShareCurrencyParams {
  /** The share package ID (e.g., "0x..."). */
  shareCurrencyPackageId: string;
  /** The address to transfer the TreasuryCap to. */
  treasuryCapRecipient: string;
}

/**
 * Builds a transaction that initializes a share currency.
 *
 * This creates the currency metadata and mints the TreasuryCap, which is
 * transferred to the specified recipient address.
 *
 * @returns Transaction that, when executed, initializes the share currency.
 */
export function initializeShareCurrency(params: InitializeShareCurrencyParams): Transaction {
  const { shareCurrencyPackageId, treasuryCapRecipient } = params;

  const tx = new Transaction();

  const treasuryCap = tx.moveCall({
    target: `${shareCurrencyPackageId}::share::initialize`,
    arguments: [tx.object("0xc")],
  });

  tx.transferObjects([treasuryCap], treasuryCapRecipient);

  return tx;
}

// ============================================================================
// Composition
// ============================================================================

/** Input for adding a credit to a composition. */
export interface CompositionCreditInput {
  /** The Party object ID. */
  partyId: string;
  /** Display name for the credit. */
  displayName: string;
  /** Roles assigned to this party. */
  roles: CompositionPartyRoleType[];
}

/** Recipient for share distribution. */
export interface ShareRecipient {
  /** The recipient's Sui address. */
  address: string;
  /** The amount of shares to receive. */
  value: number;
}

/** Parameters for publishing a composition. */
export interface PublishCompositionParams {
  /** Sui gRPC client for querying share currency data. */
  client: SuiGrpcClient;
  /** The Currency object ID for the share. */
  shareCurrencyId: string;
  /** The address that owns the TreasuryCap. */
  treasuryCapOwner: string;
  /** Primary title of the composition. */
  title: string;
  /** Revenue split for the composition in basis points. */
  splitBps: number;
  /** Recipients for initial share distribution. Must sum to 10,000,000,000,000 (total supply). */
  shareRecipients: ShareRecipient[];
  /** The address to transfer the CompositionAdminCap to. */
  adminAddress: string;
  /** Optional alternate titles. */
  alternateTitles?: string[];
  /** Credits to add. At least one is required. */
  credits: CompositionCreditInput[];
  /** Optional lyrics lines. */
  lyrics?: string[];
  /** The MusicOS package ID. */
  musicOsPackageId: string;
}

/**
 * Builds a transaction that creates and publishes a composition.
 *
 * This transaction:
 * 1. Initializes the share token
 * 2. Creates the composition
 * 3. Adds credits, alternate titles, and lyrics
 * 4. Distributes shares to recipients
 * 5. Publishes the composition
 * 6. Transfers the CompositionAdminCap to the admin address
 */
export async function publishComposition(params: PublishCompositionParams): Promise<Transaction> {
  const {
    client,
    shareCurrencyId,
    treasuryCapOwner,
    title,
    splitBps,
    shareRecipients,
    adminAddress,
    alternateTitles,
    credits,
    lyrics,
    musicOsPackageId,
  } = params;

  // Query share currency data
  const shareType = await getShareCurrencyType(client, shareCurrencyId);
  const treasuryCapId = await getShareCurrencyTreasuryCap(client, shareCurrencyId, treasuryCapOwner);

  const tx = new Transaction();

  // Create the composition - returns (Composition, CompositionAdminCap, Balance<Share>)
  const compositionResult = tx.moveCall({
    target: `${musicOsPackageId}::composition::new`,
    arguments: [
      tx.pure.string(title),
      tx.pure.u64(splitBps),
      tx.object(shareCurrencyId),
      tx.object(treasuryCapId),
    ],
    typeArguments: [shareType],
  });

  const composition = compositionResult[0]!;
  const compositionAdminCap = compositionResult[1]!;
  const shareBalance = compositionResult[2]!;

  // Add alternate titles
  if (alternateTitles && alternateTitles.length > 0) {
    for (const altTitle of alternateTitles) {
      tx.moveCall({
        target: `${musicOsPackageId}::composition::add_alternate_title`,
        arguments: [composition, compositionAdminCap, tx.pure.string(altTitle)],
        typeArguments: [shareType],
      });
    }
  }

  // Add credits
  for (const creditInput of credits) {
    const roleResults = creditInput.roles.map((roleType) => {
      const roleFnName = compositionRoleToFunctionName(roleType);
      return tx.moveCall({
        target: `${musicOsPackageId}::composition_party_role::${roleFnName}`,
        arguments: [],
      });
    });

    const credit = tx.moveCall({
      target: `${musicOsPackageId}::credit::new`,
      arguments: [
        tx.pure.string(creditInput.displayName),
        tx.makeMoveVec({
          type: `${musicOsPackageId}::composition_party_role::CompositionPartyRole`,
          elements: roleResults,
        }),
      ],
      typeArguments: [`${musicOsPackageId}::composition_party_role::CompositionPartyRole`],
    });

    tx.moveCall({
      target: `${musicOsPackageId}::composition::add_credit`,
      arguments: [composition, compositionAdminCap, tx.object(creditInput.partyId), credit],
      typeArguments: [shareType],
    });
  }

  // Add lyrics
  if (lyrics && lyrics.length > 0) {
    tx.moveCall({
      target: `${musicOsPackageId}::composition::add_lyric_lines`,
      arguments: [composition, compositionAdminCap, tx.pure.vector("string", lyrics)],
      typeArguments: [shareType],
    });
  }

  // Convert balance to coin for distribution
  const shareCoin = tx.moveCall({
    target: "0x2::coin::from_balance",
    arguments: [shareBalance],
    typeArguments: [shareType],
  });

  // Distribute shares to recipients
  if (shareRecipients.length === 1) {
    tx.transferObjects([shareCoin], shareRecipients[0]!.address);
  } else if (shareRecipients.length > 1) {
    const splitAmounts = shareRecipients.slice(0, -1).map((r) => tx.pure.u64(r.value));
    const splitCoins = tx.splitCoins(shareCoin, splitAmounts);

    for (let i = 0; i < shareRecipients.length - 1; i++) {
      tx.transferObjects([splitCoins[i]!], shareRecipients[i]!.address);
    }
    tx.transferObjects([shareCoin], shareRecipients[shareRecipients.length - 1]!.address);
  }

  // Publish the composition
  tx.moveCall({
    target: `${musicOsPackageId}::composition::publish`,
    arguments: [composition, compositionAdminCap, tx.object(SUI_CLOCK_OBJECT_ID)],
    typeArguments: [shareType],
  });

  // Transfer admin cap to the specified address
  tx.transferObjects([compositionAdminCap], adminAddress);

  return tx;
}

/** Maps a CompositionPartyRoleType to its Move constructor function name. */
function compositionRoleToFunctionName(roleType: CompositionPartyRoleType): string {
  const mapping: Record<CompositionPartyRoleType, string> = {
    Adapter: "new_adapter_role",
    Arranger: "new_arranger_role",
    Composer: "new_composer_role",
    Lyricist: "new_lyricist_role",
    Songwriter: "new_songwriter_role",
    Translator: "new_translator_role",
  };
  return mapping[roleType];
}

// ============================================================================
// Recording
// ============================================================================

/** Audio data parameters. */
export interface AudioInput {
  /** Number of audio channels (1 = mono, 2 = stereo). */
  channels: number;
  /** Bit depth of the audio (8, 16, 24, or 32 bits). */
  bitDepth: number;
  /** Sample rate in Hz. */
  sampleRateHz: number;
  /** Total number of samples. */
  samples: number;
  /** Walrus blob ID (as u256 decimal string). */
  blobId: string;
  /** Optional Walrus quilt ID (as u256 decimal string). */
  quiltId?: string;
  /** SHA-256 digest of the raw PCM data (32 bytes). */
  pcmDigest: Uint8Array;
}

/** Cover art input. */
export interface CoverArtInput {
  /** Walrus blob ID for the static image (as u256 decimal string). */
  staticBlobId: string;
  /** Optional Walrus quilt ID for the static image (as u256 decimal string). */
  staticQuiltId?: string;
  /** Optional Walrus blob ID for animated version. */
  animatedBlobId?: string;
  /** Optional Walrus quilt ID for animated version (as u256 decimal string). */
  animatedQuiltId?: string;
}

/** Input for adding a credit to a recording. */
export interface RecordingCreditInput {
  /** The Party object ID. */
  partyId: string;
  /** Display name for the credit. */
  displayName: string;
  /** Roles assigned to this party. */
  roles: RecordingPartyRole[];
  /** Whether this party is a primary artist. */
  isPrimaryArtist?: boolean;
  /** Whether this party is a featured artist. */
  isFeaturedArtist?: boolean;
}

/** Parameters for publishing a recording. */
export interface PublishRecordingParams {
  /** Sui gRPC client for querying share currency data. */
  client: SuiGrpcClient;
  /** The Composition object ID that this recording is based on. */
  compositionId: string;
  /** The type argument for the composition's share token. */
  compositionShareType: string;
  /** The Currency object ID for the recording's share. */
  shareCurrencyId: string;
  /** The address that owns the TreasuryCap. */
  treasuryCapOwner: string;
  /** The Genre object ID for the primary genre. */
  primaryGenreId: string;
  /** Whether the recording contains explicit content. */
  isExplicit: boolean;
  /** Whether the recording is instrumental (no vocals). */
  isInstrumental: boolean;
  /** The master audio data. */
  master: AudioInput;
  /** Cover art for the recording. */
  coverArt: CoverArtInput;
  /** Recipients for initial share distribution. */
  shareRecipients: ShareRecipient[];
  /** The address to transfer the RecordingAdminCap to. */
  adminAddress: string;
  /** Credits to add. At least one with isPrimaryArtist is required. */
  credits: RecordingCreditInput[];
  /** Optional title version (e.g., "Radio Edit", "Extended Mix"). */
  titleVersion?: string;
  /** Optional subtitle. */
  subtitle?: string;
  /** Optional language code (ISO 639-1). */
  language?: string;
  /** Optional secondary genre IDs to add. */
  secondaryGenreIds?: string[];
  /** Optional musical key. */
  musicalKey?: MusicalKey;
  /** Optional time signature. */
  timeSignature?: TimeSignature;
  /** Optional tempo in BPM. */
  tempoBpm?: number;
  /** The MusicOS package ID. */
  musicOsPackageId: string;
  /** The walrus_data package ID. */
  walrusDataPackageId: string;
}

/**
 * Builds a transaction that creates and publishes a recording in a single transaction.
 *
 * This transaction:
 * 1. Creates the Audio and CoverArt structs
 * 2. Creates the recording linked to a composition
 * 3. Adds credits and artist designations
 * 4. Sets optional metadata (title version, subtitle, language, etc.)
 * 5. Publishes the recording
 * 6. Distributes shares to recipients
 * 7. Transfers the RecordingAdminCap to the admin address
 */
export async function publishRecording(params: PublishRecordingParams): Promise<Transaction> {
  const {
    client,
    compositionId,
    compositionShareType,
    shareCurrencyId,
    treasuryCapOwner,
    primaryGenreId,
    isExplicit,
    isInstrumental,
    master,
    coverArt,
    shareRecipients,
    adminAddress,
    credits,
    titleVersion,
    subtitle,
    language,
    secondaryGenreIds,
    musicalKey,
    timeSignature,
    tempoBpm,
    musicOsPackageId,
    walrusDataPackageId,
  } = params;

  // Query share currency data
  const shareType = await getShareCurrencyType(client, shareCurrencyId);
  const treasuryCapId = await getShareCurrencyTreasuryCap(client, shareCurrencyId, treasuryCapOwner);

  const tx = new Transaction();

  // Helper to create WalrusData with or without quilt
  const createWalrusData = (blobId: string, quiltId?: string) => {
    if (quiltId) {
      return tx.moveCall({
        target: `${walrusDataPackageId}::walrus_data::new_with_quilt`,
        arguments: [tx.pure.u256(BigInt(quiltId)), tx.pure.u256(BigInt(blobId))],
      });
    }
    return tx.moveCall({
      target: `${walrusDataPackageId}::walrus_data::new_without_quilt`,
      arguments: [tx.pure.u256(BigInt(blobId))],
    });
  };

  // Build the Audio struct
  const walrusData = createWalrusData(master.blobId, master.quiltId);

  const audio = tx.moveCall({
    target: `${musicOsPackageId}::audio::new`,
    arguments: [
      tx.pure.u8(master.channels),
      tx.pure.u8(master.bitDepth),
      tx.pure.u32(master.sampleRateHz),
      tx.pure.u64(master.samples),
      walrusData,
      tx.pure(bcs.vector(bcs.u8()).serialize(Array.from(master.pcmDigest)).toBytes()),
    ],
  });

  // Build the CoverArt struct
  const staticWalrusData = createWalrusData(coverArt.staticBlobId, coverArt.staticQuiltId);

  let animatedOption;
  if (coverArt.animatedBlobId) {
    const animatedWalrusData = createWalrusData(coverArt.animatedBlobId, coverArt.animatedQuiltId);
    animatedOption = tx.moveCall({
      target: "0x1::option::some",
      arguments: [animatedWalrusData],
      typeArguments: [`${walrusDataPackageId}::walrus_data::WalrusData`],
    });
  } else {
    animatedOption = tx.moveCall({
      target: "0x1::option::none",
      arguments: [],
      typeArguments: [`${walrusDataPackageId}::walrus_data::WalrusData`],
    });
  }

  const recordingCoverArt = tx.moveCall({
    target: `${musicOsPackageId}::cover_art::new`,
    arguments: [staticWalrusData, animatedOption],
  });

  // Create the recording - returns (Recording, RecordingAdminCap, Balance<Share>)
  const recordingResult = tx.moveCall({
    target: `${musicOsPackageId}::recording::new`,
    arguments: [
      tx.object(compositionId),
      tx.object(primaryGenreId),
      tx.pure.bool(isExplicit),
      tx.pure.bool(isInstrumental),
      audio,
      recordingCoverArt,
      tx.object(shareCurrencyId),
      tx.object(treasuryCapId),
    ],
    typeArguments: [shareType, compositionShareType],
  });

  const recording = recordingResult[0]!;
  const recordingAdminCap = recordingResult[1]!;
  const shareBalance = recordingResult[2]!;

  // Set title version
  if (titleVersion !== undefined) {
    tx.moveCall({
      target: `${musicOsPackageId}::recording::set_title_version`,
      arguments: [recording, recordingAdminCap, tx.pure.string(titleVersion)],
      typeArguments: [shareType],
    });
  }

  // Set subtitle
  if (subtitle !== undefined) {
    tx.moveCall({
      target: `${musicOsPackageId}::recording::set_subtitle`,
      arguments: [recording, recordingAdminCap, tx.pure.string(subtitle)],
      typeArguments: [shareType],
    });
  }

  // Set language
  if (language !== undefined) {
    tx.moveCall({
      target: `${musicOsPackageId}::recording::set_language`,
      arguments: [recording, recordingAdminCap, tx.pure.string(language)],
      typeArguments: [shareType],
    });
  }

  // Add credits and track which parties need artist designation
  const primaryArtistPartyIds: string[] = [];
  const featuredArtistPartyIds: string[] = [];

  for (const creditInput of credits) {
    // Build the roles vector
    const roleResults = creditInput.roles.map((role) =>
      buildRecordingRole(tx, musicOsPackageId, role)
    );

    // Create the Credit struct
    const credit = tx.moveCall({
      target: `${musicOsPackageId}::credit::new`,
      arguments: [
        tx.pure.string(creditInput.displayName),
        tx.makeMoveVec({
          type: `${musicOsPackageId}::recording_party_role::RecordingPartyRole`,
          elements: roleResults,
        }),
      ],
      typeArguments: [`${musicOsPackageId}::recording_party_role::RecordingPartyRole`],
    });

    // Add the credit to the recording
    tx.moveCall({
      target: `${musicOsPackageId}::recording::add_credit`,
      arguments: [recording, recordingAdminCap, tx.object(creditInput.partyId), credit],
      typeArguments: [shareType],
    });

    // Track artist designations
    if (creditInput.isPrimaryArtist) {
      primaryArtistPartyIds.push(creditInput.partyId);
    }
    if (creditInput.isFeaturedArtist) {
      featuredArtistPartyIds.push(creditInput.partyId);
    }
  }

  // Add primary artists (must be done after credits are added)
  for (const partyId of primaryArtistPartyIds) {
    tx.moveCall({
      target: `${musicOsPackageId}::recording::add_primary_artist`,
      arguments: [recording, recordingAdminCap, tx.object(partyId)],
      typeArguments: [shareType],
    });
  }

  // Add featured artists (must be done after credits are added)
  for (const partyId of featuredArtistPartyIds) {
    tx.moveCall({
      target: `${musicOsPackageId}::recording::add_featured_artist`,
      arguments: [recording, recordingAdminCap, tx.object(partyId)],
      typeArguments: [shareType],
    });
  }

  // Add secondary genres
  if (secondaryGenreIds && secondaryGenreIds.length > 0) {
    for (const genreId of secondaryGenreIds) {
      tx.moveCall({
        target: `${musicOsPackageId}::recording::add_secondary_genre`,
        arguments: [recording, recordingAdminCap, tx.object(genreId)],
        typeArguments: [shareType],
      });
    }
  }

  // Set musical key
  if (musicalKey !== undefined) {
    const musicalKeyResult = buildMusicalKey(tx, musicOsPackageId, musicalKey);
    tx.moveCall({
      target: `${musicOsPackageId}::recording::set_musical_key`,
      arguments: [recording, recordingAdminCap, musicalKeyResult],
      typeArguments: [shareType],
    });
  }

  // Set time signature
  if (timeSignature !== undefined) {
    const timeSignatureResult = tx.moveCall({
      target: `${musicOsPackageId}::time_signature::new`,
      arguments: [
        tx.pure.u8(timeSignature.beatsPerMeasure),
        tx.pure.u8(timeSignature.beatUnit),
      ],
    });
    tx.moveCall({
      target: `${musicOsPackageId}::recording::set_time_signature`,
      arguments: [recording, recordingAdminCap, timeSignatureResult],
      typeArguments: [shareType],
    });
  }

  // Set tempo BPM
  if (tempoBpm !== undefined) {
    tx.moveCall({
      target: `${musicOsPackageId}::recording::set_tempo_bpm`,
      arguments: [recording, recordingAdminCap, tx.pure.u16(tempoBpm)],
      typeArguments: [shareType],
    });
  }

  // Publish the recording (makes it a shared object)
  tx.moveCall({
    target: `${musicOsPackageId}::recording::publish`,
    arguments: [recording, recordingAdminCap, tx.object(SUI_CLOCK_OBJECT_ID)],
    typeArguments: [shareType],
  });

  // Convert balance to coin for distribution
  const shareCoin = tx.moveCall({
    target: "0x2::coin::from_balance",
    arguments: [shareBalance],
    typeArguments: [shareType],
  });

  // Distribute shares to recipients
  if (shareRecipients.length === 1) {
    tx.transferObjects([shareCoin], shareRecipients[0]!.address);
  } else if (shareRecipients.length > 1) {
    const splitAmounts = shareRecipients.slice(0, -1).map((r) => tx.pure.u64(r.value));
    const splitCoins = tx.splitCoins(shareCoin, splitAmounts);

    for (let i = 0; i < shareRecipients.length - 1; i++) {
      tx.transferObjects([splitCoins[i]!], shareRecipients[i]!.address);
    }
    tx.transferObjects([shareCoin], shareRecipients[shareRecipients.length - 1]!.address);
  }

  // Transfer admin cap to the specified address
  tx.transferObjects([recordingAdminCap], adminAddress);

  return tx;
}

/** Builds a RecordingPartyRole in the transaction. */
function buildRecordingRole(
  tx: Transaction,
  packageId: string,
  role: RecordingPartyRole
) {
  const levelArg = (level?: RecordingPartyRoleLevel) => {
    if (level === undefined) {
      return tx.moveCall({
        target: "0x1::option::none",
        arguments: [],
        typeArguments: [`${packageId}::recording_party_role::RecordingPartyRoleLevel`],
      });
    }
    const levelResult = tx.moveCall({
      target: `${packageId}::recording_party_role::${recordingLevelToFunctionName(level)}`,
      arguments: [],
    });
    return tx.moveCall({
      target: "0x1::option::some",
      arguments: [levelResult],
      typeArguments: [`${packageId}::recording_party_role::RecordingPartyRoleLevel`],
    });
  };

  switch (role.type) {
    case "Instrumentalist":
      return tx.moveCall({
        target: `${packageId}::recording_party_role::new_instrumentalist_role`,
        arguments: [tx.pure.string(role.instrument), levelArg(role.level)],
      });
    case "ArtistsAndRepertoire":
      return tx.moveCall({
        target: `${packageId}::recording_party_role::new_artists_and_repertoire_role`,
        arguments: [],
      });
    case "Copyist":
      return tx.moveCall({
        target: `${packageId}::recording_party_role::new_copyist_role`,
        arguments: [],
      });
    default:
      return tx.moveCall({
        target: `${packageId}::recording_party_role::${recordingRoleToFunctionName(role.type)}`,
        arguments: [levelArg(role.level)],
      });
  }
}

/** Builds a MusicalKey in the transaction. */
function buildMusicalKey(tx: Transaction, packageId: string, key: MusicalKey) {
  const noteResult = tx.moveCall({
    target: `${packageId}::musical_key::new_note_${key.note.toLowerCase()}`,
    arguments: [],
  });
  const accidentalResult = tx.moveCall({
    target: `${packageId}::musical_key::new_accidental_${key.accidental.toLowerCase()}`,
    arguments: [],
  });
  const modeResult = tx.moveCall({
    target: `${packageId}::musical_key::new_mode_${key.mode.toLowerCase()}`,
    arguments: [],
  });
  return tx.moveCall({
    target: `${packageId}::musical_key::new`,
    arguments: [noteResult, accidentalResult, modeResult],
  });
}

/** Maps a RecordingPartyRoleLevel to its Move constructor function name. */
function recordingLevelToFunctionName(level: RecordingPartyRoleLevel): string {
  const mapping: Record<RecordingPartyRoleLevel, string> = {
    Additional: "new_additional_role_level",
    Assistant: "new_assistant_role_level",
    Associate: "new_associate_role_level",
    Backing: "new_backing_role_level",
    Executive: "new_executive_role_level",
    Featured: "new_featured_role_level",
    Lead: "new_lead_role_level",
    Primary: "new_primary_role_level",
    Principal: "new_principal_role_level",
  };
  return mapping[level];
}

/** Maps a RecordingPartyRole type to its Move constructor function name. */
function recordingRoleToFunctionName(roleType: string): string {
  const mapping: Record<string, string> = {
    Actor: "new_actor_role",
    Arranger: "new_arranger_role",
    Choir: "new_choir_role",
    ChoirMaster: "new_choir_master_role",
    Conductor: "new_conductor_role",
    Contractor: "new_contractor_role",
    Editor: "new_editor_role",
    Ensemble: "new_ensemble_role",
    MasteringEngineer: "new_mastering_engineer_role",
    MixingEngineer: "new_mixing_engineer_role",
    MusicDirector: "new_music_director_role",
    MusicSupervisor: "new_music_supervisor_role",
    Narrator: "new_narrator_role",
    Orchestra: "new_orchestra_role",
    Orchestrator: "new_orchestrator_role",
    Producer: "new_producer_role",
    Programmer: "new_programmer_role",
    RecordingEngineer: "new_recording_engineer_role",
    RemixingEngineer: "new_remixing_engineer_role",
    SoundDesigner: "new_sound_designer_role",
    Vocalist: "new_vocalist_role",
  };
  return mapping[roleType] ?? roleType;
}

// ============================================================================
// Release
// ============================================================================

/** Input for a track on a release. */
export interface TrackInput {
  /** The Recording object ID (must be a published/shared recording). */
  recordingId: string;
  /** The RecordingAdminCap object ID. */
  recordingAdminCapId: string;
  /** The type argument for the recording's share token. */
  recordingShareType: string;
}

/** Input for a disc on a release. */
export interface DiscInput {
  /** Tracks on this disc, in order. */
  tracks: TrackInput[];
}

/** Type of release. */
export type ReleaseKindInput = "Album" | "EP" | "Single";

/** Parameters for publishing a release. */
export interface PublishReleaseParams {
  /** The walrus_data package ID. */
  walrusDataPackageId: string;
  /** Type of release (Album, EP, or Single). */
  kind: ReleaseKindInput;
  /** Title of the release. */
  title: string;
  /** Cover art for the release. */
  coverArt: CoverArtInput;
  /** Discs containing tracks, in order. */
  discs: DiscInput[];
  /**
   * Revenue split for each track in basis points.
   * Must have one entry per track (across all discs) and sum to 10000 (100%).
   */
  trackSplitsBps: number[];
  /** The MusicOS package ID. */
  musicOsPackageId: string;
}

/**
 * Builds a transaction that creates and publishes a release.
 *
 * This transaction:
 * 1. Creates Track objects from each recording
 * 2. Creates Disc objects from tracks
 * 3. Creates the Release with cover art
 * 4. Sets track revenue splits
 * 5. Publishes the release
 */
export function publishRelease(params: PublishReleaseParams): Transaction {
  const {
    walrusDataPackageId,
    kind,
    title,
    coverArt,
    discs,
    trackSplitsBps,
    musicOsPackageId,
  } = params;

  const tx = new Transaction();

  // Build disc vector
  const discResults: ReturnType<typeof tx.moveCall>[] = [];

  for (const discInput of discs) {
    // Build track vector for this disc
    const trackResults: ReturnType<typeof tx.moveCall>[] = [];

    for (const trackInput of discInput.tracks) {
      // Create Option<CoverArt> as none (use recording's cover art)
      const coverArtOption = tx.moveCall({
        target: "0x1::option::none",
        arguments: [],
        typeArguments: [`${musicOsPackageId}::cover_art::CoverArt`],
      });

      // Create the track
      const track = tx.moveCall({
        target: `${musicOsPackageId}::track::new`,
        arguments: [
          tx.object(trackInput.recordingAdminCapId),
          tx.object(trackInput.recordingId),
          coverArtOption,
        ],
        typeArguments: [trackInput.recordingShareType],
      });

      trackResults.push(track);
    }

    // Create vector<Track> and push all tracks
    const trackVec = tx.makeMoveVec({
      type: `${musicOsPackageId}::track::Track`,
      elements: trackResults,
    });

    // Create the disc
    const disc = tx.moveCall({
      target: `${musicOsPackageId}::disc::new`,
      arguments: [trackVec],
    });

    discResults.push(disc);
  }

  // Create vector<Disc>
  const discVec = tx.makeMoveVec({
    type: `${musicOsPackageId}::disc::Disc`,
    elements: discResults,
  });

  // Helper to create WalrusData with or without quilt
  const createWalrusData = (blobId: string, quiltId?: string) => {
    if (quiltId) {
      return tx.moveCall({
        target: `${walrusDataPackageId}::walrus_data::new_with_quilt`,
        arguments: [tx.pure.u256(BigInt(quiltId)), tx.pure.u256(BigInt(blobId))],
      });
    }
    return tx.moveCall({
      target: `${walrusDataPackageId}::walrus_data::new_without_quilt`,
      arguments: [tx.pure.u256(BigInt(blobId))],
    });
  };

  // Build cover art
  const staticWalrusData = createWalrusData(coverArt.staticBlobId, coverArt.staticQuiltId);

  let animatedOption;
  if (coverArt.animatedBlobId) {
    const animatedWalrusData = createWalrusData(coverArt.animatedBlobId, coverArt.animatedQuiltId);
    animatedOption = tx.moveCall({
      target: "0x1::option::some",
      arguments: [animatedWalrusData],
      typeArguments: [`${walrusDataPackageId}::walrus_data::WalrusData`],
    });
  } else {
    animatedOption = tx.moveCall({
      target: "0x1::option::none",
      arguments: [],
      typeArguments: [`${walrusDataPackageId}::walrus_data::WalrusData`],
    });
  }

  const releaseCoverArt = tx.moveCall({
    target: `${musicOsPackageId}::cover_art::new`,
    arguments: [staticWalrusData, animatedOption],
  });

  // Build ReleaseKind enum using BCS
  const releaseKind = buildReleaseKind(tx, kind);

  // Create the release - returns (Release, ReleaseAdminCap)
  const releaseResult = tx.moveCall({
    target: `${musicOsPackageId}::release::new`,
    arguments: [releaseKind, tx.pure.string(title), releaseCoverArt, discVec],
  });
  const release = releaseResult[0]!;
  const releaseAdminCap = releaseResult[1]!;

  // Set track splits
  tx.moveCall({
    target: `${musicOsPackageId}::release::set_track_splits_bps`,
    arguments: [release, releaseAdminCap, tx.pure.vector("u64", trackSplitsBps)],
  });

  // Publish the release
  tx.moveCall({
    target: `${musicOsPackageId}::release::publish`,
    arguments: [release, releaseAdminCap, tx.object(SUI_CLOCK_OBJECT_ID)],
  });

  return tx;
}

/** BCS schema for ReleaseKind enum. */
const ReleaseKindBcs = bcs.enum("ReleaseKind", {
  Album: null,
  EP: null,
  Single: null,
});

/** Builds a ReleaseKind enum value. */
function buildReleaseKind(tx: Transaction, kind: ReleaseKindInput) {
  const enumValue = { [kind]: true } as { Album: true } | { EP: true } | { Single: true };
  return tx.pure(ReleaseKindBcs.serialize(enumValue).toBytes());
}

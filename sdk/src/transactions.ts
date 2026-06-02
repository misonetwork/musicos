// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

import type { ClientWithCoreApi } from "@mysten/sui/client";
import { Transaction, type TransactionObjectArgument } from "@mysten/sui/transactions";
import {
  getShareCurrencyType,
  getShareCurrencyTreasuryCap,
} from "./queries.ts";
import type {
  CompositionPartyRoleType,
  RecordingPartyRole,
  RecordingPartyRoleLevel,
} from "./types.ts";

/** Sui Clock shared object address. */
const SUI_CLOCK_OBJECT_ID = "0x6";

/** Input for WalrusData - references a Walrus blob. */
export type WalrusDataInput = { blobId: string };

// ============================================================================
// WalrusData Helpers
// ============================================================================

/** Creates a WalrusData Move value in the transaction from a WalrusDataInput. */
function createWalrusData(tx: Transaction, walrusDataPackageId: string, input: WalrusDataInput) {
  return tx.moveCall({
    target: `${walrusDataPackageId}::walrus_data::new_blob`,
    arguments: [tx.pure.u256(BigInt(input.blobId))],
  });
}

/** Builds a CoverArt Move value in the transaction from a CoverArtInput. */
function buildCoverArt(tx: Transaction, walrusDataPackageId: string, musicOsPackageId: string, coverArt: CoverArtInput) {
  const staticWalrusData = createWalrusData(tx, walrusDataPackageId, coverArt.staticData);

  let animatedOption;
  if (coverArt.animatedData) {
    const animatedWalrusData = createWalrusData(tx, walrusDataPackageId, coverArt.animatedData);
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

  return tx.moveCall({
    target: `${musicOsPackageId}::cover_art::new`,
    arguments: [staticWalrusData, animatedOption],
  });
}

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
  /** The PartyOS package ID. */
  partyOsPackageId: string;
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
  const { kind, name, memberIds, adminAddress, partyOsPackageId } = params;

  const tx = new Transaction();

  // Create the PartyKind
  const partyKind = tx.moveCall({
    target: `${partyOsPackageId}::party::new_${kind.toLowerCase()}_kind`,
    arguments: [],
  });

  // Create the party - returns (Party, PartyAdminCap)
  const partyResult = tx.moveCall({
    target: `${partyOsPackageId}::party::new`,
    arguments: [partyKind, tx.pure.string(name)],
  });
  const party = partyResult[0]!;
  const partyAdminCap = partyResult[1]!;

  // For groups, add member parties
  if (kind === "Group" && memberIds && memberIds.length > 0) {
    for (const memberId of memberIds) {
      tx.moveCall({
        target: `${partyOsPackageId}::party::add_party`,
        arguments: [party, partyAdminCap, tx.object(memberId)],
      });
    }
  }

  // Share the party
  tx.moveCall({
    target: `${partyOsPackageId}::party::share`,
    arguments: [party, partyAdminCap],
  });

  tx.transferObjects([partyAdminCap], tx.pure.address(adminAddress));

  return tx;
}

// ============================================================================
// Share
// ============================================================================

/** Bytecode for a compiled Move package. */
export interface PackageBytecode {
  modules: string[];
  dependencies: string[];
  digest: number[];
}

/**
 * Builds a transaction that publishes a new Share token package.
 *
 * This publishes an immutable package containing the Share coin type that can
 * be used for composition or recording ownership distribution.
 *
 * @param bytecode - The compiled share package bytecode (with INITIALIZER already patched).
 * @returns Transaction that, when executed, creates a new Share package.
 */
export function publishShareCurrency(bytecode: PackageBytecode): Transaction {
  const tx = new Transaction();

  const upgradeCap = tx.publish(bytecode);
  tx.moveCall({
    target: "0x2::package::make_immutable",
    arguments: [upgradeCap],
  });

  return tx;
}

/** Sui CoinRegistry shared object address. */
const SUI_COIN_REGISTRY_ID = "0xc";

/** Parameters for initializing a share currency. */
export interface InitializeShareCurrencyParams {
  /** The share currency package ID (published via `publishShareCurrency`). */
  shareCurrencyPackageId: string;
  /** Display name for the share currency. */
  name: string;
  /** Description for the share currency. */
  description: string;
  /** Icon URL for the share currency (e.g., a walrus:// URL). */
  iconUrl: string;
  /** The address to transfer the TreasuryCap to. */
  treasuryCapRecipient: string;
}

/**
 * Builds a transaction that initializes a share currency.
 *
 * This registers the currency in the CoinRegistry and creates a TreasuryCap,
 * which is transferred to the specified recipient address.
 *
 * @returns Transaction that, when executed, initializes the share currency.
 */
export function initializeShareCurrency(params: InitializeShareCurrencyParams): Transaction {
  const { shareCurrencyPackageId, name, description, iconUrl, treasuryCapRecipient } = params;

  const tx = new Transaction();

  const treasuryCap = tx.moveCall({
    target: `${shareCurrencyPackageId}::share::initialize`,
    arguments: [
      tx.pure.string(name),
      tx.pure.string(description),
      tx.pure.string(iconUrl),
      tx.object(SUI_COIN_REGISTRY_ID),
    ],
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
  /** Sui client with Core API for querying share currency data. */
  client: ClientWithCoreApi;
  /** The Currency object ID for the share. */
  shareCurrencyId: string;
  /** The address that owns the TreasuryCap. */
  treasuryCapOwner: string;
  /** Primary title of the composition. */
  title: string;
  /** Royalty rate this composition earns from each recording, in basis points (min 1000 = 10%). */
  royaltyRateBps: number;
  /** Recipients for initial share distribution. Must sum to 10,000,000,000,000 (total supply). */
  shareRecipients: ShareRecipient[];
  /** The address to transfer the CompositionAdminCap to. */
  adminAddress: string;
  /** Optional alternate titles. */
  alternateTitles?: string[];
  /** Credits to add. At least one is required. */
  credits: CompositionCreditInput[];
  /** The MusicOS package ID. */
  musicOsPackageId: string;
  /** The PartyOS package ID (for credit creation). */
  partyOsPackageId: string;
  /** The Minato package ID (for balance dispersal). */
  minatoPackageId: string;
}

/**
 * Builds a transaction that creates and publishes a composition.
 *
 * This transaction:
 * 1. Initializes the share token
 * 2. Creates the composition
 * 3. Adds credits and alternate titles
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
    royaltyRateBps,
    shareRecipients,
    adminAddress,
    alternateTitles,
    credits,
    musicOsPackageId,
    partyOsPackageId,
    minatoPackageId,
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
      tx.pure.u16(royaltyRateBps),
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
      target: `${partyOsPackageId}::credit::new`,
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

  // Disperse shares to recipients
  tx.moveCall({
    target: `${minatoPackageId}::minato::disperse_balance`,
    arguments: [
      shareBalance,
      tx.makeMoveVec({ type: "u64", elements: shareRecipients.map((r) => tx.pure.u64(r.value)) }),
      tx.makeMoveVec({ type: "address", elements: shareRecipients.map((r) => tx.pure.address(r.address)) }),
    ],
    typeArguments: [shareType],
  });
  tx.moveCall({
    target: "0x2::balance::destroy_zero",
    arguments: [shareBalance],
    typeArguments: [shareType],
  });

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
// Audio Ingestion
// ============================================================================

/**
 * Creates an attested Audio object via the audio ingester enclave.
 *
 * The argument order must match `audio_ingester::ingest` exactly: the attested
 * `format` and `pcmDigest` slot in between `blobId` and `timestampMs`, mirroring
 * the field order of the enclave-signed `AudioVerificationPayload`.
 */
function createAttestedAudio(
  tx: Transaction,
  audioIngesterPackageId: string,
  enclaveId: string,
  input: AudioInput,
) {
  return tx.moveCall({
    target: `${audioIngesterPackageId}::audio_ingester::ingest`,
    arguments: [
      tx.pure.u8(input.channels),
      tx.pure.u8(input.bitDepth),
      tx.pure.u32(input.sampleRateHz),
      tx.pure.u64(input.samples),
      tx.pure.u256(BigInt(input.blobId)),
      tx.pure.string(input.format),
      tx.pure.vector("u8", input.pcmDigest),
      tx.pure.u64(input.timestampMs),
      tx.pure.vector("u8", input.signature),
      tx.object(enclaveId),
    ],
  });
}

// ============================================================================
// Recording
// ============================================================================

/**
 * Audio data parameters with enclave attestation.
 *
 * Every field except none is the enclave's attested output: `format` and
 * `pcmDigest` are signed by the enclave alongside the PCM properties, so they
 * must be passed through verbatim from the ingester response (not re-derived
 * client-side) or signature verification on `ingest` will fail.
 */
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
  /** Attested codec/container short name (e.g. `flac`). From the enclave response. */
  format: string;
  /** Attested BLAKE2b-256 of the canonical decoded PCM, as raw bytes. From the enclave response. */
  pcmDigest: number[];
  /** Enclave attestation signature bytes. */
  signature: number[];
  /** Timestamp in milliseconds from the attestation. */
  timestampMs: number;
}

/** Cover art input. */
export interface CoverArtInput {
  /** WalrusData for the static image. */
  staticData: WalrusDataInput;
  /** Optional WalrusData for the animated version. */
  animatedData?: WalrusDataInput;
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
  /** Sui client with Core API for querying share currency data. */
  client: ClientWithCoreApi;
  /** The Composition object ID that this recording is based on. */
  compositionId: string;
  /** The type argument for the composition's share token. */
  compositionShareType: string;
  /** The Currency object ID for the recording's share. */
  shareCurrencyId: string;
  /** The address that owns the TreasuryCap. */
  treasuryCapOwner: string;
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
  /** The MusicOS package ID. */
  musicOsPackageId: string;
  /** The PartyOS package ID (for credit creation). */
  partyOsPackageId: string;
  /** The walrus_data package ID. */
  walrusDataPackageId: string;
  /** The audio ingester package ID. */
  audioIngesterPackageId: string;
  /** The Enclave<AUDIO_INGESTER> object ID. */
  enclaveId: string;
  /** The Minato package ID (for balance dispersal). */
  minatoPackageId: string;
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
    musicOsPackageId,
    partyOsPackageId,
    walrusDataPackageId,
    audioIngesterPackageId,
    enclaveId,
    minatoPackageId,
  } = params;

  // Query share currency data
  const shareType = await getShareCurrencyType(client, shareCurrencyId);
  const treasuryCapId = await getShareCurrencyTreasuryCap(client, shareCurrencyId, treasuryCapOwner);

  const tx = new Transaction();

  // Build the Audio struct via enclave attestation
  const audio = createAttestedAudio(tx, audioIngesterPackageId, enclaveId, master);

  // Build the CoverArt struct
  const recordingCoverArt = buildCoverArt(tx, walrusDataPackageId, musicOsPackageId, coverArt);

  // Create the recording - returns (Recording, RecordingAdminCap, Balance<Share>)
  const recordingResult = tx.moveCall({
    target: `${musicOsPackageId}::recording::new`,
    arguments: [
      tx.object(compositionId),
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
      target: `${partyOsPackageId}::credit::new`,
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

  // Publish the recording (makes it a shared object)
  tx.moveCall({
    target: `${musicOsPackageId}::recording::publish`,
    arguments: [recording, recordingAdminCap, tx.object(SUI_CLOCK_OBJECT_ID)],
    typeArguments: [shareType],
  });

  // Disperse shares to recipients
  tx.moveCall({
    target: `${minatoPackageId}::minato::disperse_balance`,
    arguments: [
      shareBalance,
      tx.makeMoveVec({ type: "u64", elements: shareRecipients.map((r) => tx.pure.u64(r.value)) }),
      tx.makeMoveVec({ type: "address", elements: shareRecipients.map((r) => tx.pure.address(r.address)) }),
    ],
    typeArguments: [shareType],
  });
  tx.moveCall({
    target: "0x2::balance::destroy_zero",
    arguments: [shareBalance],
    typeArguments: [shareType],
  });

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
// Deal
// ============================================================================

/** Parameters for creating a deal. */
export interface CreateDealParams {
  /** Optional existing transaction to add commands to. Creates a new one if not provided. */
  tx?: Transaction;
  /** The Recording object ID (must be a published/shared recording). */
  recordingId: string;
  /** The RecordingAdminCap object ID (used when the cap is directly owned). */
  recordingAdminCapId?: string;
  /** Pre-resolved admin cap argument (used when the cap is vaulted). */
  recordingAdminCap?: TransactionObjectArgument;
  /** The Composition object ID that the recording is based on. */
  compositionId: string;
  /** The type argument for the composition's share token. */
  compositionShareType: string;
  /** The type argument for the recording's share token. */
  recordingShareType: string;
  /** The pre-derived Release ID that this deal is for. */
  releaseId: string;
  /** Revenue split for this track in basis points (0-10000). */
  trackSplitBps: number;
  /** Optional display title for the track. Defaults to the recording's title. */
  trackTitle?: string;
  /** Optional cover art for the track. Defaults to the recording's cover art. */
  trackCoverArt?: CoverArtInput;
  /** The address to transfer the Deal to. */
  recipientAddress: string;
  /** The MusicOS package ID. */
  musicOsPackageId: string;
  /** The walrus_data package ID (required if trackCoverArt is provided). */
  walrusDataPackageId?: string;
}

/**
 * Builds a transaction that creates a Deal and transfers it to the recipient.
 *
 * A Deal represents an agreement to include a recording on a release with specific
 * track information (title, split, cover art). The Deal is created by the recording
 * admin cap owner and transferred to the release creator.
 *
 * The releaseId must be pre-derived client-side using deriveReleaseId() to match
 * what release::new() will derive from the same track inputs and agreed nonce.
 */
export function createDeal(params: CreateDealParams): Transaction {
  const {
    recordingId,
    recordingAdminCapId,
    recordingAdminCap,
    compositionId,
    compositionShareType,
    recordingShareType,
    releaseId,
    trackSplitBps,
    trackTitle,
    trackCoverArt,
    recipientAddress,
    musicOsPackageId,
    walrusDataPackageId,
  } = params;

  const tx = params.tx ?? new Transaction();
  const adminCapArg = recordingAdminCap ?? tx.object(recordingAdminCapId!);

  // Create Option<String> for title
  const titleOption = trackTitle
    ? tx.moveCall({
        target: "0x1::option::some",
        arguments: [tx.pure.string(trackTitle)],
        typeArguments: ["0x1::string::String"],
      })
    : tx.moveCall({
        target: "0x1::option::none",
        arguments: [],
        typeArguments: ["0x1::string::String"],
      });

  // Create Option<CoverArt> for cover art
  let coverArtOption;
  if (trackCoverArt && walrusDataPackageId) {
    const coverArt = buildCoverArt(tx, walrusDataPackageId, musicOsPackageId, trackCoverArt);

    coverArtOption = tx.moveCall({
      target: "0x1::option::some",
      arguments: [coverArt],
      typeArguments: [`${musicOsPackageId}::cover_art::CoverArt`],
    });
  } else {
    coverArtOption = tx.moveCall({
      target: "0x1::option::none",
      arguments: [],
      typeArguments: [`${musicOsPackageId}::cover_art::CoverArt`],
    });
  }

  // Create the Deal. Argument order matches `deal::new`:
  // (recording_admin_cap, composition, recording, release_id, track_split_bps, title, cover_art).
  const deal = tx.moveCall({
    target: `${musicOsPackageId}::deal::new`,
    arguments: [
      adminCapArg,
      tx.object(compositionId),
      tx.object(recordingId),
      tx.pure.id(releaseId),
      tx.pure.u16(trackSplitBps),
      titleOption,
      coverArtOption,
    ],
    typeArguments: [compositionShareType, recordingShareType],
  });

  // Transfer the Deal to the recipient
  tx.transferObjects([deal], recipientAddress);

  return tx;
}

// ============================================================================
// Release
// ============================================================================

/** Input for a track on a release (Deal-based). */
export interface TrackInput {
  /** The Composition object ID. */
  compositionId: string;
  /** The type argument for the composition's share token. */
  compositionShareType: string;
  /** The Recording object ID (must be a published/shared recording). */
  recordingId: string;
  /** The RecordingAdminCap object ID. */
  recordingAdminCapId: string;
  /** The type argument for the recording's share token. */
  recordingShareType: string;
  /** Optional display title for the track. Defaults to the recording's title. */
  title?: string;
  /** Revenue split for this track in basis points. */
  splitBps: number;
}

/** Input for a disc on a release. */
export interface DiscInput {
  /** Tracks on this disc, in order. */
  tracks: TrackInput[];
  /** Optional title for the disc (e.g., for multi-disc sets). */
  title?: string;
}

/** Type of release. */
export type ReleaseKindInput = "Album" | "ExtendedPlay" | "Single";

/** Supported release party roles. */
export type ReleasePartyRoleInput = "Primary" | "Featured";

/** Input for adding a credit to a release. */
export interface ReleaseCreditInput {
  /** Party object ID to attribute. */
  partyId: string;
  /** Release role for this party (Primary or Featured). */
  role: ReleasePartyRoleInput;
  /** Display name for the credit. */
  displayName: string;
}

/** Parameters for publishing a release. */
export interface PublishReleaseParams {
  /** The walrus_data package ID. */
  walrusDataPackageId: string;
  /** Type of release (Album, ExtendedPlay, or Single). */
  kind: ReleaseKindInput;
  /** Title of the release. */
  title: string;
  /** Description of the release (max 500 characters). */
  description: string;
  /** Release-level credits. Must include at least one Primary role before publish. */
  credits: ReleaseCreditInput[];
  /** Cover art for the release. */
  coverArt: CoverArtInput;
  /** Discs containing tracks, in order. Each track must include its splitBps. */
  discs: DiscInput[];
  /** The ReleaseRegistry object ID. */
  releaseRegistryId: string;
  /** The pre-derived Release ID. Must match what release::new() will derive. */
  releaseId: string;
  /** Nonce used in release ID derivation (u256, decimal or 0x-prefixed hex string). */
  releaseNonce: string;
  /** The MusicOS package ID. */
  musicOsPackageId: string;
  /** The PartyOS package ID (for credit creation). */
  partyOsPackageId: string;
  /** Address to receive the ReleaseAdminCap. */
  adminAddress: string;
}

/**
 * Builds a transaction that creates and publishes a release using the Deal-based flow.
 *
 * This transaction:
 * 1. Creates Deal objects for each recording with the pre-derived release ID
 * 2. Creates Track objects from Deals
 * 3. Creates Disc objects from Tracks
 * 4. Creates the Release (which derives the same ID internally)
 * 5. Publishes the release
 *
 * Note: The releaseId must be pre-derived client-side using deriveReleaseId()
 * to match what release::new() will derive from the same track inputs and nonce.
 */
export function publishRelease(params: PublishReleaseParams): Transaction {
  const {
    walrusDataPackageId,
    kind,
    title,
    description,
    credits,
    coverArt,
    discs,
    releaseRegistryId,
    releaseId,
    releaseNonce,
    musicOsPackageId,
    partyOsPackageId,
    adminAddress,
  } = params;

  const tx = new Transaction();

  // Build disc vector
  const discResults: ReturnType<typeof tx.moveCall>[] = [];

  for (const discInput of discs) {
    // Build track vector for this disc
    const trackResults: ReturnType<typeof tx.moveCall>[] = [];

    for (const trackInput of discInput.tracks) {
      // Create Option<String> for title
      const titleOption = trackInput.title
        ? tx.moveCall({
            target: "0x1::option::some",
            arguments: [tx.pure.string(trackInput.title)],
            typeArguments: ["0x1::string::String"],
          })
        : tx.moveCall({
            target: "0x1::option::none",
            arguments: [],
            typeArguments: ["0x1::string::String"],
          });

      // Create Option<CoverArt> as none (use recording's cover art)
      const coverArtOption = tx.moveCall({
        target: "0x1::option::none",
        arguments: [],
        typeArguments: [`${musicOsPackageId}::cover_art::CoverArt`],
      });

      // Create the Deal with the pre-derived release ID
      const deal = tx.moveCall({
        target: `${musicOsPackageId}::deal::new`,
        arguments: [
          tx.object(trackInput.recordingAdminCapId),
          tx.object(trackInput.compositionId),
          tx.object(trackInput.recordingId),
          tx.pure.id(releaseId),
          tx.pure.u16(trackInput.splitBps),
          titleOption,
          coverArtOption,
        ],
        typeArguments: [trackInput.compositionShareType, trackInput.recordingShareType],
      });

      // Create the Track from the Deal
      const track = tx.moveCall({
        target: `${musicOsPackageId}::track::new`,
        arguments: [deal],
      });

      trackResults.push(track);
    }

    // Create vector<Track> and push all tracks
    const trackVec = tx.makeMoveVec({
      type: `${musicOsPackageId}::track::Track`,
      elements: trackResults,
    });

    // Create Option<String> for disc title
    const discTitleOption = discInput.title
      ? tx.moveCall({
          target: "0x1::option::some",
          arguments: [tx.pure.string(discInput.title)],
          typeArguments: ["0x1::string::String"],
        })
      : tx.moveCall({
          target: "0x1::option::none",
          arguments: [],
          typeArguments: ["0x1::string::String"],
        });

    // Create the disc
    const disc = tx.moveCall({
      target: `${musicOsPackageId}::disc::new`,
      arguments: [trackVec, discTitleOption],
    });

    discResults.push(disc);
  }

  // Create vector<Disc>
  const discVec = tx.makeMoveVec({
    type: `${musicOsPackageId}::disc::Disc`,
    elements: discResults,
  });

  // Build cover art
  const releaseCoverArt = buildCoverArt(tx, walrusDataPackageId, musicOsPackageId, coverArt);

  // Build ReleaseKind enum using BCS
  const releaseKind = buildReleaseKind(tx, kind, musicOsPackageId);

  // Create the release - returns (Release, ReleaseAdminCap)
  // The release::new() will derive the same ID as releaseId from tracks + releaseNonce.
  const releaseResult = tx.moveCall({
    target: `${musicOsPackageId}::release::new`,
    arguments: [
      releaseKind,
      tx.pure.string(title),
      tx.pure.string(description),
      releaseCoverArt,
      discVec,
      tx.pure.u256(BigInt(releaseNonce)),
      tx.object(releaseRegistryId),
    ],
  });
  const release = releaseResult[0]!;
  const releaseAdminCap = releaseResult[1]!;

  // Add release credits
  for (const creditInput of credits) {
    const role = tx.moveCall({
      target: `${musicOsPackageId}::release_party_role::new_${creditInput.role.toLowerCase()}_role`,
      arguments: [],
    });

    const credit = tx.moveCall({
      target: `${partyOsPackageId}::credit::new`,
      arguments: [
        tx.pure.string(creditInput.displayName),
        tx.makeMoveVec({
          type: `${musicOsPackageId}::release_party_role::ReleasePartyRole`,
          elements: [role],
        }),
      ],
      typeArguments: [`${musicOsPackageId}::release_party_role::ReleasePartyRole`],
    });

    tx.moveCall({
      target: `${musicOsPackageId}::release::add_credit`,
      arguments: [release, releaseAdminCap, tx.object(creditInput.partyId), credit],
    });
  }

  // Publish the release
  tx.moveCall({
    target: `${musicOsPackageId}::release::publish`,
    arguments: [release, releaseAdminCap, tx.object(SUI_CLOCK_OBJECT_ID)],
  });

  // Transfer the ReleaseAdminCap to the admin address
  tx.transferObjects([releaseAdminCap], tx.pure.address(adminAddress));

  return tx;
}

/** Builds a ReleaseKind enum value using Move helper functions. */
function buildReleaseKind(tx: Transaction, kind: ReleaseKindInput, musicOsPackageId: string) {
  const kindFnName = kind === "Album" ? "new_album_kind" : kind === "ExtendedPlay" ? "new_extended_play_kind" : "new_single_kind";
  return tx.moveCall({
    target: `${musicOsPackageId}::release_kind::${kindFnName}`,
    arguments: [],
  });
}

/** Input for a pre-created deal to be used in a release. */
export interface DealInput {
  /** The Deal object ID. */
  dealId: string;
}

/** Input for a disc using pre-created deals. */
export interface DiscFromDealsInput {
  /** Deals for tracks on this disc, in order. */
  deals: DealInput[];
  /** Optional title for the disc (e.g., for multi-disc sets). */
  title?: string;
}

/** Parameters for publishing a release from pre-created deals. */
export interface PublishReleaseFromDealsParams {
  /** The walrus_data package ID. */
  walrusDataPackageId: string;
  /** Type of release (Album, ExtendedPlay, or Single). */
  kind: ReleaseKindInput;
  /** Title of the release. */
  title: string;
  /** Description of the release (max 500 characters). */
  description: string;
  /** Release-level credits. Must include at least one Primary role before publish. */
  credits: ReleaseCreditInput[];
  /** Cover art for the release. */
  coverArt: CoverArtInput;
  /** Discs containing pre-created deals, in order. */
  discs: DiscFromDealsInput[];
  /** The ReleaseRegistry object ID. */
  releaseRegistryId: string;
  /** Nonce used in release ID derivation (u256, decimal or 0x-prefixed hex string). */
  releaseNonce: string;
  /** The MusicOS package ID. */
  musicOsPackageId: string;
  /** The PartyOS package ID (for credit creation). */
  partyOsPackageId: string;
  /** Address to receive the ReleaseAdminCap. */
  adminAddress: string;
}

/**
 * Builds a transaction that creates and publishes a release using pre-created Deal objects.
 *
 * This transaction:
 * 1. Takes pre-created Deal objects (owned by the caller)
 * 2. Creates Track objects from Deals
 * 3. Creates Disc objects from Tracks
 * 4. Creates the Release (deriving its ID from the tracks)
 * 5. Publishes the release
 *
 * Note: The Deal objects must have been created with matching release IDs that will
 * be derived from the same track configuration and nonce.
 */
export function publishReleaseFromDeals(params: PublishReleaseFromDealsParams): Transaction {
  const {
    walrusDataPackageId,
    kind,
    title,
    description,
    credits,
    coverArt,
    discs,
    releaseRegistryId,
    releaseNonce,
    musicOsPackageId,
    partyOsPackageId,
    adminAddress,
  } = params;

  const tx = new Transaction();

  // Build disc vector
  const discResults: ReturnType<typeof tx.moveCall>[] = [];

  for (const discInput of discs) {
    // Build track vector for this disc
    const trackResults: ReturnType<typeof tx.moveCall>[] = [];

    for (const dealInput of discInput.deals) {
      // Create the Track from the pre-existing Deal object
      const track = tx.moveCall({
        target: `${musicOsPackageId}::track::new`,
        arguments: [tx.object(dealInput.dealId)],
      });

      trackResults.push(track);
    }

    // Create vector<Track> and push all tracks
    const trackVec = tx.makeMoveVec({
      type: `${musicOsPackageId}::track::Track`,
      elements: trackResults,
    });

    // Create Option<String> for disc title
    const discTitleOption = discInput.title
      ? tx.moveCall({
          target: "0x1::option::some",
          arguments: [tx.pure.string(discInput.title)],
          typeArguments: ["0x1::string::String"],
        })
      : tx.moveCall({
          target: "0x1::option::none",
          arguments: [],
          typeArguments: ["0x1::string::String"],
        });

    // Create the disc
    const disc = tx.moveCall({
      target: `${musicOsPackageId}::disc::new`,
      arguments: [trackVec, discTitleOption],
    });

    discResults.push(disc);
  }

  // Create vector<Disc>
  const discVec = tx.makeMoveVec({
    type: `${musicOsPackageId}::disc::Disc`,
    elements: discResults,
  });

  // Build cover art
  const releaseCoverArt = buildCoverArt(tx, walrusDataPackageId, musicOsPackageId, coverArt);

  // Build ReleaseKind enum
  const releaseKind = buildReleaseKind(tx, kind, musicOsPackageId);

  // Create the release - returns (Release, ReleaseAdminCap)
  const releaseResult = tx.moveCall({
    target: `${musicOsPackageId}::release::new`,
    arguments: [
      releaseKind,
      tx.pure.string(title),
      tx.pure.string(description),
      releaseCoverArt,
      discVec,
      tx.pure.u256(BigInt(releaseNonce)),
      tx.object(releaseRegistryId),
    ],
  });
  const release = releaseResult[0]!;
  const releaseAdminCap = releaseResult[1]!;

  // Add release credits
  for (const creditInput of credits) {
    const role = tx.moveCall({
      target: `${musicOsPackageId}::release_party_role::new_${creditInput.role.toLowerCase()}_role`,
      arguments: [],
    });

    const credit = tx.moveCall({
      target: `${partyOsPackageId}::credit::new`,
      arguments: [
        tx.pure.string(creditInput.displayName),
        tx.makeMoveVec({
          type: `${musicOsPackageId}::release_party_role::ReleasePartyRole`,
          elements: [role],
        }),
      ],
      typeArguments: [`${musicOsPackageId}::release_party_role::ReleasePartyRole`],
    });

    tx.moveCall({
      target: `${musicOsPackageId}::release::add_credit`,
      arguments: [release, releaseAdminCap, tx.object(creditInput.partyId), credit],
    });
  }

  // Publish the release
  tx.moveCall({
    target: `${musicOsPackageId}::release::publish`,
    arguments: [release, releaseAdminCap, tx.object(SUI_CLOCK_OBJECT_ID)],
  });

  // Transfer the ReleaseAdminCap to the admin address
  tx.transferObjects([releaseAdminCap], tx.pure.address(adminAddress));

  return tx;
}


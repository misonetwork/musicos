// Copyright (c) Unconfirmed Labs, LLC
// SPDX-License-Identifier: Apache-2.0

import { bcs } from "@mysten/sui/bcs";
import { Transaction } from "@mysten/sui/transactions";
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
  /** The MusicOS package ID. */
  packageId: string;
  /** Type of party (Individual or Group). */
  kind: PartyKindInput;
  /** Human-readable name of the party. */
  name: string;
  /** For groups: IDs of individual parties to add as members. */
  memberIds?: string[];
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
  const { packageId, kind, name, memberIds } = params;

  const tx = new Transaction();

  // Create the PartyKind
  const partyKind = tx.moveCall({
    target: `${packageId}::party::new_${kind.toLowerCase()}_kind`,
    arguments: [],
  });

  // Create the party - returns (Party, PartyAdminCap)
  const partyResult = tx.moveCall({
    target: `${packageId}::party::new`,
    arguments: [partyKind, tx.pure.string(name)],
  });
  const party = partyResult[0]!;
  const partyAdminCap = partyResult[1]!;

  // For groups, add member parties
  if (kind === "Group" && memberIds && memberIds.length > 0) {
    for (const memberId of memberIds) {
      tx.moveCall({
        target: `${packageId}::party::add_party`,
        arguments: [party, partyAdminCap, tx.object(memberId)],
      });
    }
  }

  // Share the party
  tx.moveCall({
    target: `${packageId}::party::share`,
    arguments: [party, partyAdminCap],
  });

  return tx;
}

// ============================================================================
// Share
// ============================================================================

/** Compiled bytecode for the Share module. */
const SHARE_BYTECODE = {
  modules: [
    "oRzrCwYAAAAKAQAMAgwgAywWBEIEBUY7B4EBuwEIvAJgBpwDLQrJAwYMzwMnAA4BDwIHAggCDQIQAAIIAAEDBwACBAwBAAEDAAgAAwEAAQABBAYEAAUFAgAACwABAAERAwQAAwkIAgEAAwwGBwEIAwUCBQIHCAMHCAYBCwIBCAAAAQoCAQgBAQgABwcIAwIIAQgBCAEIAQcIBgILBAEJAAsCAQkAAgsEAQkABwgGDENvaW5SZWdpc3RyeRNDdXJyZW5jeUluaXRpYWxpemVyBVNoYXJlBlN0cmluZwtUcmVhc3VyeUNhcAlUeENvbnRleHQDVUlEBGNvaW4NY29pbl9yZWdpc3RyeSBmaW5hbGl6ZV9hbmRfZGVsZXRlX21ldGFkYXRhX2NhcAJpZAppbml0aWFsaXplDG5ld19jdXJyZW5jeQZvYmplY3QFc2hhcmUGc3RyaW5nCnR4X2NvbnRleHQEdXRmOAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgoCBgVTSEFSRQoCISBodHRwczovL3NvbmFtdXNpYy5jb20vc2hhcmUud2VicAACAQoIBQABAAABEQsAMQYHABEBBwARAQcAEQEHAREBCgE4AAwCCwE4AQsCAgA=",
  ],
  dependencies: [
    "0x0000000000000000000000000000000000000000000000000000000000000001",
    "0x0000000000000000000000000000000000000000000000000000000000000002",
  ],
  digest: [
    181, 60, 194, 192, 203, 221, 225, 71, 208, 175, 242, 205, 48, 229, 250, 139,
    223, 47, 109, 119, 81, 61, 140, 63, 21, 180, 115, 235, 29, 135, 43, 38,
  ],
};

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
  sharePackageId: string;
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
  const { sharePackageId, treasuryCapRecipient } = params;

  const tx = new Transaction();

  const treasuryCap = tx.moveCall({
    target: `${sharePackageId}::share::initialize`,
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
  value: bigint;
}

/** Parameters for publishing a composition. */
export interface PublishCompositionParams {
  /** The MusicOS package ID. */
  packageId: string;
  /** The share package ID (e.g., "0x..."). */
  sharePackageId: string;
  /** The share type argument (e.g., "0x...::share::Share"). */
  shareType: string;
  /** The Currency object ID for the share. */
  currencyId: string;
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
export function publishComposition(params: PublishCompositionParams): Transaction {
  const {
    packageId,
    sharePackageId,
    shareType,
    currencyId,
    title,
    splitBps,
    shareRecipients,
    adminAddress,
    alternateTitles,
    credits,
    lyrics,
  } = params;

  const tx = new Transaction();

  // Initialize the share token
  const treasuryCap = tx.moveCall({
    target: `${sharePackageId}::share::initialize`,
    arguments: [tx.object("0xc")],
  });

  // Create the composition - returns (Composition, CompositionAdminCap, Balance<Share>)
  const compositionResult = tx.moveCall({
    target: `${packageId}::composition::new`,
    arguments: [
      tx.pure.string(title),
      tx.pure.u64(splitBps),
      tx.object(currencyId),
      treasuryCap,
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
        target: `${packageId}::composition::add_alternate_title`,
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
        target: `${packageId}::composition_party_role::${roleFnName}`,
        arguments: [],
      });
    });

    const credit = tx.moveCall({
      target: `${packageId}::credit::new`,
      arguments: [
        tx.pure.string(creditInput.displayName),
        tx.makeMoveVec({
          type: `${packageId}::composition_party_role::CompositionPartyRole`,
          elements: roleResults,
        }),
      ],
      typeArguments: [`${packageId}::composition_party_role::CompositionPartyRole`],
    });

    tx.moveCall({
      target: `${packageId}::composition::add_credit`,
      arguments: [composition, compositionAdminCap, tx.object(creditInput.partyId), credit],
      typeArguments: [shareType],
    });
  }

  // Add lyrics
  if (lyrics && lyrics.length > 0) {
    tx.moveCall({
      target: `${packageId}::composition::add_lyric_lines`,
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
    target: `${packageId}::composition::publish`,
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
  /** The MusicOS package ID. */
  packageId: string;
  /** The Recording object ID. */
  recordingId: string;
  /** The type argument for the recording's share token. */
  recordingShareType: string;
  /** The RecordingAdminCap object ID. */
  adminCapId: string;
  /** Optional title version (e.g., "Radio Edit", "Extended Mix"). */
  titleVersion?: string;
  /** Optional subtitle. */
  subtitle?: string;
  /** Optional language code (ISO 639-1). */
  language?: string;
  /** Credits to add before publishing. At least one with isPrimaryArtist is required. */
  credits?: RecordingCreditInput[];
  /** Optional primary genre to set (overrides genre set at creation). */
  primaryGenreId?: string;
  /** Optional secondary genre IDs to add. */
  secondaryGenreIds?: string[];
  /** Optional musical key. */
  musicalKey?: MusicalKey;
  /** Optional time signature. */
  timeSignature?: TimeSignature;
  /** Optional tempo in BPM. */
  tempoBpm?: number;
}

/**
 * Builds a transaction that publishes a recording.
 *
 * This transaction optionally sets metadata, credits, genres, and musical properties
 * before calling publish. All optional setters are only included if the corresponding
 * parameter is provided.
 *
 * Note: At least one credit with isPrimaryArtist must be added for publish to succeed.
 */
export function publishRecording(params: PublishRecordingParams): Transaction {
  const {
    packageId,
    recordingId,
    recordingShareType,
    adminCapId,
    titleVersion,
    subtitle,
    language,
    credits,
    primaryGenreId,
    secondaryGenreIds,
    musicalKey,
    timeSignature,
    tempoBpm,
  } = params;

  const tx = new Transaction();

  const recordingArg = tx.object(recordingId);
  const adminCapArg = tx.object(adminCapId);

  // Set title version
  if (titleVersion !== undefined) {
    tx.moveCall({
      target: `${packageId}::recording::set_title_version`,
      arguments: [recordingArg, adminCapArg, tx.pure.string(titleVersion)],
      typeArguments: [recordingShareType],
    });
  }

  // Set subtitle
  if (subtitle !== undefined) {
    tx.moveCall({
      target: `${packageId}::recording::set_subtitle`,
      arguments: [recordingArg, adminCapArg, tx.pure.string(subtitle)],
      typeArguments: [recordingShareType],
    });
  }

  // Set language
  if (language !== undefined) {
    tx.moveCall({
      target: `${packageId}::recording::set_language`,
      arguments: [recordingArg, adminCapArg, tx.pure.string(language)],
      typeArguments: [recordingShareType],
    });
  }

  // Add credits and track which parties need artist designation
  const primaryArtistPartyIds: string[] = [];
  const featuredArtistPartyIds: string[] = [];

  if (credits && credits.length > 0) {
    for (const creditInput of credits) {
      // Build the roles vector
      const roleResults = creditInput.roles.map((role) =>
        buildRecordingRole(tx, packageId, role)
      );

      // Create the Credit struct
      const credit = tx.moveCall({
        target: `${packageId}::credit::new`,
        arguments: [
          tx.pure.string(creditInput.displayName),
          tx.makeMoveVec({
            type: `${packageId}::recording_party_role::RecordingPartyRole`,
            elements: roleResults,
          }),
        ],
        typeArguments: [`${packageId}::recording_party_role::RecordingPartyRole`],
      });

      // Add the credit to the recording
      tx.moveCall({
        target: `${packageId}::recording::add_credit`,
        arguments: [recordingArg, adminCapArg, tx.object(creditInput.partyId), credit],
        typeArguments: [recordingShareType],
      });

      // Track artist designations
      if (creditInput.isPrimaryArtist) {
        primaryArtistPartyIds.push(creditInput.partyId);
      }
      if (creditInput.isFeaturedArtist) {
        featuredArtistPartyIds.push(creditInput.partyId);
      }
    }
  }

  // Add primary artists (must be done after credits are added)
  for (const partyId of primaryArtistPartyIds) {
    tx.moveCall({
      target: `${packageId}::recording::add_primary_artist`,
      arguments: [recordingArg, adminCapArg, tx.object(partyId)],
      typeArguments: [recordingShareType],
    });
  }

  // Add featured artists (must be done after credits are added)
  for (const partyId of featuredArtistPartyIds) {
    tx.moveCall({
      target: `${packageId}::recording::add_featured_artist`,
      arguments: [recordingArg, adminCapArg, tx.object(partyId)],
      typeArguments: [recordingShareType],
    });
  }

  // Set primary genre
  if (primaryGenreId !== undefined) {
    tx.moveCall({
      target: `${packageId}::recording::set_primary_genre`,
      arguments: [recordingArg, adminCapArg, tx.object(primaryGenreId)],
      typeArguments: [recordingShareType],
    });
  }

  // Add secondary genres
  if (secondaryGenreIds && secondaryGenreIds.length > 0) {
    for (const genreId of secondaryGenreIds) {
      tx.moveCall({
        target: `${packageId}::recording::add_secondary_genre`,
        arguments: [recordingArg, adminCapArg, tx.object(genreId)],
        typeArguments: [recordingShareType],
      });
    }
  }

  // Set musical key
  if (musicalKey !== undefined) {
    const musicalKeyResult = buildMusicalKey(tx, packageId, musicalKey);
    tx.moveCall({
      target: `${packageId}::recording::set_musical_key`,
      arguments: [recordingArg, adminCapArg, musicalKeyResult],
      typeArguments: [recordingShareType],
    });
  }

  // Set time signature
  if (timeSignature !== undefined) {
    const timeSignatureResult = tx.moveCall({
      target: `${packageId}::time_signature::new`,
      arguments: [
        tx.pure.u8(timeSignature.beatsPerMeasure),
        tx.pure.u8(timeSignature.beatUnit),
      ],
    });
    tx.moveCall({
      target: `${packageId}::recording::set_time_signature`,
      arguments: [recordingArg, adminCapArg, timeSignatureResult],
      typeArguments: [recordingShareType],
    });
  }

  // Set tempo BPM
  if (tempoBpm !== undefined) {
    tx.moveCall({
      target: `${packageId}::recording::set_tempo_bpm`,
      arguments: [recordingArg, adminCapArg, tx.pure.u16(tempoBpm)],
      typeArguments: [recordingShareType],
    });
  }

  // Publish the recording
  tx.moveCall({
    target: `${packageId}::recording::publish`,
    arguments: [recordingArg, adminCapArg, tx.object(SUI_CLOCK_OBJECT_ID)],
    typeArguments: [recordingShareType],
  });

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

/** Input for cover art. */
export interface CoverArtInput {
  /** Walrus blob ID for the static image (as u256 decimal string). */
  staticBlobId: string;
  /** Optional Walrus blob ID for animated version. */
  animatedBlobId?: string;
}

/** Type of release. */
export type ReleaseKindInput = "Album" | "EP" | "Single";

/** Parameters for publishing a release. */
export interface PublishReleaseParams {
  /** The MusicOS package ID. */
  packageId: string;
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
    packageId,
    walrusDataPackageId,
    kind,
    title,
    coverArt,
    discs,
    trackSplitsBps,
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
        typeArguments: [`${packageId}::cover_art::CoverArt`],
      });

      // Create the track
      const track = tx.moveCall({
        target: `${packageId}::track::new`,
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
      type: `${packageId}::track::Track`,
      elements: trackResults,
    });

    // Create the disc
    const disc = tx.moveCall({
      target: `${packageId}::disc::new`,
      arguments: [trackVec],
    });

    discResults.push(disc);
  }

  // Create vector<Disc>
  const discVec = tx.makeMoveVec({
    type: `${packageId}::disc::Disc`,
    elements: discResults,
  });

  // Build cover art
  const staticWalrusData = tx.moveCall({
    target: `${walrusDataPackageId}::walrus_data::new_without_quilt`,
    arguments: [tx.pure.u256(BigInt(coverArt.staticBlobId))],
  });

  let animatedOption;
  if (coverArt.animatedBlobId) {
    const animatedWalrusData = tx.moveCall({
      target: `${walrusDataPackageId}::walrus_data::new_without_quilt`,
      arguments: [tx.pure.u256(BigInt(coverArt.animatedBlobId))],
    });
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
    target: `${packageId}::cover_art::new`,
    arguments: [staticWalrusData, animatedOption],
  });

  // Build ReleaseKind enum using BCS
  const releaseKind = buildReleaseKind(tx, kind);

  // Create the release - returns (Release, ReleaseAdminCap)
  const releaseResult = tx.moveCall({
    target: `${packageId}::release::new`,
    arguments: [releaseKind, tx.pure.string(title), releaseCoverArt, discVec],
  });
  const release = releaseResult[0]!;
  const releaseAdminCap = releaseResult[1]!;

  // Set track splits
  tx.moveCall({
    target: `${packageId}::release::set_track_splits_bps`,
    arguments: [release, releaseAdminCap, tx.pure.vector("u64", trackSplitsBps)],
  });

  // Publish the release
  tx.moveCall({
    target: `${packageId}::release::publish`,
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

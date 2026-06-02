// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

// Transaction builders, following the Sui SDK thunk pattern: each builder
// returns a `(tx: Transaction) => …` thunk that adds commands to a caller-owned
// `Transaction`, so flows compose. MusicOS calls go through the codegen-
// generated, type-safe call functions; calls into external packages (partyos,
// share, minato, the audio ingester, framework) use raw `moveCall`.

import { Transaction, type TransactionObjectArgument } from "@mysten/sui/transactions";
import type { ClientWithCoreApi } from "@mysten/sui/client";
import { getShareCurrencyType, getShareCurrencyTreasuryCap } from "./queries.ts";
import type {
  CompositionPartyRoleType,
  RecordingPartyRole,
  RecordingPartyRoleLevel,
} from "./types.ts";

import * as composition from "./contracts/musicos/composition.ts";
import * as recording from "./contracts/musicos/recording.ts";
import * as release from "./contracts/musicos/release.ts";
import * as deal from "./contracts/musicos/deal.ts";
import * as track from "./contracts/musicos/track.ts";
import * as disc from "./contracts/musicos/disc.ts";
import * as coverArtMod from "./contracts/musicos/cover_art.ts";
import * as compRole from "./contracts/musicos/composition_party_role.ts";
import * as recRole from "./contracts/musicos/recording_party_role.ts";
import * as relRole from "./contracts/musicos/release_party_role.ts";
import * as releaseKind from "./contracts/musicos/release_kind.ts";

/** A thunk that adds commands to a transaction. May be async (resolves at build time). */
export type TxThunk = (tx: Transaction) => void | Promise<void>;

const OPTION_NONE = "0x1::option::none";
const OPTION_SOME = "0x1::option::some";

// ============================================================================
// WalrusData / CoverArt helpers
// ============================================================================

/** Input for a Walrus blob reference. */
export type WalrusDataInput = { blobId: string };

/** Cover art input (a required still image, optional animated version). */
export interface CoverArtInput {
  stillData: WalrusDataInput;
  animatedData?: WalrusDataInput;
}

function buildWalrusData(tx: Transaction, walrusDataPackageId: string, input: WalrusDataInput) {
  return tx.moveCall({
    target: `${walrusDataPackageId}::walrus_data::new_blob`,
    arguments: [tx.pure.u256(BigInt(input.blobId))],
  });
}

function buildCoverArt(
  tx: Transaction,
  walrusDataPackageId: string,
  musicOsPackageId: string,
  input: CoverArtInput,
): TransactionObjectArgument {
  const still = buildWalrusData(tx, walrusDataPackageId, input.stillData);
  const walrusType = `${walrusDataPackageId}::walrus_data::WalrusData`;
  const animated = input.animatedData
    ? tx.moveCall({
        target: OPTION_SOME,
        typeArguments: [walrusType],
        arguments: [buildWalrusData(tx, walrusDataPackageId, input.animatedData)],
      })
    : tx.moveCall({ target: OPTION_NONE, typeArguments: [walrusType], arguments: [] });
  return tx.add(coverArtMod._new({ package: musicOsPackageId, arguments: [still, animated] }));
}

// ============================================================================
// Audio ingestion (external ingester package)
// ============================================================================

/**
 * Audio data with enclave attestation. `format`, `pcmDigest`, `signature`, and
 * `timestampMs` come from the ingester response and must be passed verbatim, in
 * the order the enclave signed, or `ingest` signature verification will fail.
 */
export interface AudioInput {
  channels: number;
  bitDepth: number;
  sampleRateHz: number;
  samples: number;
  /** Walrus blob ID (u256 decimal string). */
  blobId: string;
  /** Attested codec/container short name (e.g. `flac`). */
  format: string;
  /** Attested BLAKE2b-256 of the canonical decoded PCM, as raw bytes. */
  pcmDigest: number[];
  /** Enclave Ed25519 signature bytes. */
  signature: number[];
  /** Attestation timestamp (ms). */
  timestampMs: number;
}

/** Builds an attested `Audio` via the audio ingester enclave (external package). */
function createAttestedAudio(
  tx: Transaction,
  audioIngesterPackageId: string,
  enclaveId: string,
  input: AudioInput,
): TransactionObjectArgument {
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
// Role + credit helpers
// ============================================================================

function buildCompositionRole(tx: Transaction, pkg: string, role: CompositionPartyRoleType) {
  const args = { package: pkg, arguments: [] as [] };
  switch (role) {
    case "Adapter": return tx.add(compRole.newAdapterRole(args));
    case "Arranger": return tx.add(compRole.newArrangerRole(args));
    case "Composer": return tx.add(compRole.newComposerRole(args));
    case "Lyricist": return tx.add(compRole.newLyricistRole(args));
    case "Songwriter": return tx.add(compRole.newSongwriterRole(args));
    case "Translator": return tx.add(compRole.newTranslatorRole(args));
  }
}

function buildLevelOption(tx: Transaction, pkg: string, level?: RecordingPartyRoleLevel) {
  const levelType = `${pkg}::recording_party_role::RecordingPartyRoleLevel`;
  if (!level) return tx.moveCall({ target: OPTION_NONE, typeArguments: [levelType], arguments: [] });
  const a = { package: pkg, arguments: [] as [] };
  const lvl = tx.add(
    level === "Additional" ? recRole.newAdditionalRoleLevel(a)
    : level === "Assistant" ? recRole.newAssistantRoleLevel(a)
    : level === "Associate" ? recRole.newAssociateRoleLevel(a)
    : level === "Backing" ? recRole.newBackingRoleLevel(a)
    : level === "Executive" ? recRole.newExecutiveRoleLevel(a)
    : level === "Featured" ? recRole.newFeaturedRoleLevel(a)
    : level === "Lead" ? recRole.newLeadRoleLevel(a)
    : level === "Primary" ? recRole.newPrimaryRoleLevel(a)
    : recRole.newPrincipalRoleLevel(a),
  );
  return tx.moveCall({ target: OPTION_SOME, typeArguments: [levelType], arguments: [lvl] });
}

function buildRecordingRole(tx: Transaction, pkg: string, role: RecordingPartyRole) {
  if (role.type === "Instrumentalist") {
    return tx.add(recRole.newInstrumentalistRole({ package: pkg, arguments: [tx.pure.string(role.instrument), buildLevelOption(tx, pkg, role.level)] }));
  }
  if (role.type === "ArtistsAndRepertoire") return tx.add(recRole.newArtistsAndRepertoireRole({ package: pkg, arguments: [] }));
  if (role.type === "Copyist") return tx.add(recRole.newCopyistRole({ package: pkg, arguments: [] }));
  const lvl = [buildLevelOption(tx, pkg, role.level)] as [TransactionObjectArgument];
  switch (role.type) {
    case "Actor": return tx.add(recRole.newActorRole({ package: pkg, arguments: lvl }));
    case "Arranger": return tx.add(recRole.newArrangerRole({ package: pkg, arguments: lvl }));
    case "Choir": return tx.add(recRole.newChoirRole({ package: pkg, arguments: lvl }));
    case "ChoirMaster": return tx.add(recRole.newChoirMasterRole({ package: pkg, arguments: lvl }));
    case "Conductor": return tx.add(recRole.newConductorRole({ package: pkg, arguments: lvl }));
    case "Contractor": return tx.add(recRole.newContractorRole({ package: pkg, arguments: lvl }));
    case "Editor": return tx.add(recRole.newEditorRole({ package: pkg, arguments: lvl }));
    case "Ensemble": return tx.add(recRole.newEnsembleRole({ package: pkg, arguments: lvl }));
    case "MasteringEngineer": return tx.add(recRole.newMasteringEngineerRole({ package: pkg, arguments: lvl }));
    case "MixingEngineer": return tx.add(recRole.newMixingEngineerRole({ package: pkg, arguments: lvl }));
    case "MusicDirector": return tx.add(recRole.newMusicDirectorRole({ package: pkg, arguments: lvl }));
    case "MusicSupervisor": return tx.add(recRole.newMusicSupervisorRole({ package: pkg, arguments: lvl }));
    case "Narrator": return tx.add(recRole.newNarratorRole({ package: pkg, arguments: lvl }));
    case "Orchestra": return tx.add(recRole.newOrchestraRole({ package: pkg, arguments: lvl }));
    case "Orchestrator": return tx.add(recRole.newOrchestratorRole({ package: pkg, arguments: lvl }));
    case "Producer": return tx.add(recRole.newProducerRole({ package: pkg, arguments: lvl }));
    case "Programmer": return tx.add(recRole.newProgrammerRole({ package: pkg, arguments: lvl }));
    case "RecordingEngineer": return tx.add(recRole.newRecordingEngineerRole({ package: pkg, arguments: lvl }));
    case "RemixingEngineer": return tx.add(recRole.newRemixingEngineerRole({ package: pkg, arguments: lvl }));
    case "SoundDesigner": return tx.add(recRole.newSoundDesignerRole({ package: pkg, arguments: lvl }));
    case "Vocalist": return tx.add(recRole.newVocalistRole({ package: pkg, arguments: lvl }));
  }
}

function buildCredit(
  tx: Transaction,
  partyOsPackageId: string,
  roleTypeName: string,
  displayName: string,
  roleArgs: TransactionObjectArgument[],
) {
  return tx.moveCall({
    target: `${partyOsPackageId}::credit::new`,
    typeArguments: [roleTypeName],
    arguments: [tx.pure.string(displayName), tx.makeMoveVec({ type: roleTypeName, elements: roleArgs })],
  });
}

// ============================================================================
// Shared inputs
// ============================================================================

export interface ShareRecipient {
  address: string;
  value: number;
}

function disperseShares(
  tx: Transaction,
  minatoPackageId: string,
  shareType: string,
  balance: TransactionObjectArgument,
  recipients: ShareRecipient[],
) {
  tx.moveCall({
    target: `${minatoPackageId}::minato::disperse_balance`,
    typeArguments: [shareType],
    arguments: [
      balance,
      tx.makeMoveVec({ type: "u64", elements: recipients.map((r) => tx.pure.u64(r.value)) }),
      tx.makeMoveVec({ type: "address", elements: recipients.map((r) => tx.pure.address(r.address)) }),
    ],
  });
  tx.moveCall({ target: "0x2::balance::destroy_zero", typeArguments: [shareType], arguments: [balance] });
}

// ============================================================================
// Party (external partyos package)
// ============================================================================

export interface CreatePartyParams {
  kind: "Individual" | "Group";
  name: string;
  memberIds?: string[];
  adminAddress: string;
  partyOsPackageId: string;
}

export function createParty(params: CreatePartyParams): TxThunk {
  const { kind, name, memberIds, adminAddress, partyOsPackageId } = params;
  return (tx) => {
    const partyKind = tx.moveCall({ target: `${partyOsPackageId}::party::new_${kind.toLowerCase()}_kind`, arguments: [] });
    const result = tx.moveCall({ target: `${partyOsPackageId}::party::new`, arguments: [partyKind, tx.pure.string(name)] });
    const party = result[0]!;
    const partyAdminCap = result[1]!;
    if (kind === "Group" && memberIds?.length) {
      for (const memberId of memberIds) {
        tx.moveCall({ target: `${partyOsPackageId}::party::add_party`, arguments: [party, partyAdminCap, tx.object(memberId)] });
      }
    }
    tx.moveCall({ target: `${partyOsPackageId}::party::share`, arguments: [party, partyAdminCap] });
    tx.transferObjects([partyAdminCap], tx.pure.address(adminAddress));
  };
}

// ============================================================================
// Share currency (external share / framework)
// ============================================================================

export interface PackageBytecode {
  modules: string[];
  dependencies: string[];
  digest: number[];
}

export function publishShareCurrency(bytecode: PackageBytecode): TxThunk {
  return (tx) => {
    const upgradeCap = tx.publish(bytecode);
    tx.moveCall({ target: "0x2::package::make_immutable", arguments: [upgradeCap] });
  };
}

const SUI_COIN_REGISTRY_ID = "0xc";

export interface InitializeShareCurrencyParams {
  shareCurrencyPackageId: string;
  name: string;
  description: string;
  iconUrl: string;
  treasuryCapRecipient: string;
}

export function initializeShareCurrency(params: InitializeShareCurrencyParams): TxThunk {
  const { shareCurrencyPackageId, name, description, iconUrl, treasuryCapRecipient } = params;
  return (tx) => {
    const treasuryCap = tx.moveCall({
      target: `${shareCurrencyPackageId}::share::initialize`,
      arguments: [tx.pure.string(name), tx.pure.string(description), tx.pure.string(iconUrl), tx.object(SUI_COIN_REGISTRY_ID)],
    });
    tx.transferObjects([treasuryCap], treasuryCapRecipient);
  };
}

// ============================================================================
// Composition
// ============================================================================

export interface CompositionCreditInput {
  partyId: string;
  displayName: string;
  roles: CompositionPartyRoleType[];
}

export interface PublishCompositionParams {
  client: ClientWithCoreApi;
  shareCurrencyId: string;
  treasuryCapOwner: string;
  title: string;
  royaltyRateBps: number;
  shareRecipients: ShareRecipient[];
  adminAddress: string;
  alternateTitles?: string[];
  credits: CompositionCreditInput[];
  musicOsPackageId: string;
  partyOsPackageId: string;
  minatoPackageId: string;
}

export function publishComposition(params: PublishCompositionParams): TxThunk {
  return async (tx) => {
    const { client, musicOsPackageId, partyOsPackageId, minatoPackageId } = params;
    const shareType = await getShareCurrencyType(client, params.shareCurrencyId);
    const treasuryCapId = await getShareCurrencyTreasuryCap(client, params.shareCurrencyId, params.treasuryCapOwner);
    const roleType = `${musicOsPackageId}::composition_party_role::CompositionPartyRole`;

    const result = tx.add(
      composition._new({
        package: musicOsPackageId,
        typeArguments: [shareType],
        arguments: [tx.pure.string(params.title), tx.pure.u16(params.royaltyRateBps), tx.object(params.shareCurrencyId), tx.object(treasuryCapId)],
      }),
    );
    const comp = result[0]!;
    const adminCap = result[1]!;
    const balance = result[2]!;

    for (const title of params.alternateTitles ?? []) {
      tx.add(composition.addAlternateTitle({ package: musicOsPackageId, typeArguments: [shareType], arguments: [comp, adminCap, tx.pure.string(title)] }));
    }

    for (const credit of params.credits) {
      const roles = credit.roles.map((r) => buildCompositionRole(tx, musicOsPackageId, r));
      const creditArg = buildCredit(tx, partyOsPackageId, roleType, credit.displayName, roles);
      tx.add(composition.addCredit({ package: musicOsPackageId, typeArguments: [shareType], arguments: [comp, adminCap, tx.object(credit.partyId), creditArg] }));
    }

    disperseShares(tx, minatoPackageId, shareType, balance, params.shareRecipients);
    tx.add(composition.publish({ package: musicOsPackageId, typeArguments: [shareType], arguments: [comp, adminCap] }));
    tx.transferObjects([adminCap], params.adminAddress);
  };
}

// ============================================================================
// Recording
// ============================================================================

export interface RecordingCreditInput {
  partyId: string;
  displayName: string;
  roles: RecordingPartyRole[];
  isPrimaryArtist?: boolean;
  isFeaturedArtist?: boolean;
}

export interface PublishRecordingParams {
  client: ClientWithCoreApi;
  compositionId: string;
  compositionShareType: string;
  shareCurrencyId: string;
  treasuryCapOwner: string;
  isExplicit: boolean;
  isInstrumental: boolean;
  master: AudioInput;
  coverArt: CoverArtInput;
  shareRecipients: ShareRecipient[];
  adminAddress: string;
  credits: RecordingCreditInput[];
  titleVersion?: string;
  subtitle?: string;
  language?: string;
  musicOsPackageId: string;
  partyOsPackageId: string;
  walrusDataPackageId: string;
  audioIngesterPackageId: string;
  enclaveId: string;
  minatoPackageId: string;
}

export function publishRecording(params: PublishRecordingParams): TxThunk {
  return async (tx) => {
    const { client, musicOsPackageId, partyOsPackageId, walrusDataPackageId } = params;
    const shareType = await getShareCurrencyType(client, params.shareCurrencyId);
    const treasuryCapId = await getShareCurrencyTreasuryCap(client, params.shareCurrencyId, params.treasuryCapOwner);
    const roleType = `${musicOsPackageId}::recording_party_role::RecordingPartyRole`;

    const master = createAttestedAudio(tx, params.audioIngesterPackageId, params.enclaveId, params.master);
    const cover = buildCoverArt(tx, walrusDataPackageId, musicOsPackageId, params.coverArt);

    const result = tx.add(
      recording._new({
        package: musicOsPackageId,
        typeArguments: [shareType, params.compositionShareType],
        arguments: [tx.object(params.compositionId), tx.pure.bool(params.isExplicit), tx.pure.bool(params.isInstrumental), master, cover, tx.object(params.shareCurrencyId), tx.object(treasuryCapId)],
      }),
    );
    const rec = result[0]!;
    const adminCap = result[1]!;
    const balance = result[2]!;

    if (params.titleVersion !== undefined)
      tx.add(recording.setTitleVersion({ package: musicOsPackageId, typeArguments: [shareType], arguments: [rec, adminCap, tx.pure.string(params.titleVersion)] }));
    if (params.subtitle !== undefined)
      tx.add(recording.setSubtitle({ package: musicOsPackageId, typeArguments: [shareType], arguments: [rec, adminCap, tx.pure.string(params.subtitle)] }));
    if (params.language !== undefined)
      tx.add(recording.setLanguage({ package: musicOsPackageId, typeArguments: [shareType], arguments: [rec, adminCap, tx.pure.string(params.language)] }));

    const primaryArtistIds: string[] = [];
    const featuredArtistIds: string[] = [];
    for (const credit of params.credits) {
      const roles = credit.roles.map((r) => buildRecordingRole(tx, musicOsPackageId, r));
      const creditArg = buildCredit(tx, partyOsPackageId, roleType, credit.displayName, roles);
      tx.add(recording.addCredit({ package: musicOsPackageId, typeArguments: [shareType], arguments: [rec, adminCap, tx.object(credit.partyId), creditArg] }));
      if (credit.isPrimaryArtist) primaryArtistIds.push(credit.partyId);
      if (credit.isFeaturedArtist) featuredArtistIds.push(credit.partyId);
    }
    for (const partyId of primaryArtistIds)
      tx.add(recording.addPrimaryArtist({ package: musicOsPackageId, typeArguments: [shareType], arguments: [rec, adminCap, tx.object(partyId)] }));
    for (const partyId of featuredArtistIds)
      tx.add(recording.addFeaturedArtist({ package: musicOsPackageId, typeArguments: [shareType], arguments: [rec, adminCap, tx.object(partyId)] }));

    tx.add(recording.publish({ package: musicOsPackageId, typeArguments: [shareType], arguments: [rec, adminCap] }));
    disperseShares(tx, params.minatoPackageId, shareType, balance, params.shareRecipients);
    tx.transferObjects([adminCap], params.adminAddress);
  };
}

// ============================================================================
// Deal
// ============================================================================

export interface CreateDealParams {
  recordingId: string;
  recordingAdminCapId?: string;
  recordingAdminCap?: TransactionObjectArgument;
  compositionId: string;
  compositionShareType: string;
  recordingShareType: string;
  releaseId: string;
  trackSplitBps: number;
  trackTitle?: string;
  trackCoverArt?: CoverArtInput;
  recipientAddress: string;
  musicOsPackageId: string;
  walrusDataPackageId?: string;
}

function buildTitleOption(tx: Transaction, title?: string) {
  return title
    ? tx.moveCall({ target: OPTION_SOME, typeArguments: ["0x1::string::String"], arguments: [tx.pure.string(title)] })
    : tx.moveCall({ target: OPTION_NONE, typeArguments: ["0x1::string::String"], arguments: [] });
}

function buildCoverArtOption(tx: Transaction, musicOsPackageId: string, walrusDataPackageId: string | undefined, input?: CoverArtInput) {
  const coverType = `${musicOsPackageId}::cover_art::CoverArt`;
  if (input && walrusDataPackageId) {
    const cover = buildCoverArt(tx, walrusDataPackageId, musicOsPackageId, input);
    return tx.moveCall({ target: OPTION_SOME, typeArguments: [coverType], arguments: [cover] });
  }
  return tx.moveCall({ target: OPTION_NONE, typeArguments: [coverType], arguments: [] });
}

export function createDeal(params: CreateDealParams): TxThunk {
  return (tx) => {
    const adminCapArg = params.recordingAdminCap ?? tx.object(params.recordingAdminCapId!);
    const dealArg = tx.add(
      deal._new({
        package: params.musicOsPackageId,
        typeArguments: [params.compositionShareType, params.recordingShareType],
        arguments: [
          adminCapArg,
          tx.object(params.compositionId),
          tx.object(params.recordingId),
          tx.pure.id(params.releaseId),
          tx.pure.u16(params.trackSplitBps),
          buildTitleOption(tx, params.trackTitle),
          buildCoverArtOption(tx, params.musicOsPackageId, params.walrusDataPackageId, params.trackCoverArt),
        ],
      }),
    );
    tx.transferObjects([dealArg], params.recipientAddress);
  };
}

// ============================================================================
// Release
// ============================================================================

export type ReleaseKindInput = "Album" | "ExtendedPlay" | "Single";
export type ReleasePartyRoleInput = "Primary" | "Featured";

export interface ReleaseCreditInput {
  partyId: string;
  role: ReleasePartyRoleInput;
  displayName: string;
}

export interface TrackInput {
  compositionId: string;
  compositionShareType: string;
  recordingId: string;
  recordingAdminCapId: string;
  recordingShareType: string;
  title?: string;
  splitBps: number;
}

export interface DiscInput {
  tracks: TrackInput[];
  title?: string;
}

export interface PublishReleaseParams {
  walrusDataPackageId: string;
  kind: ReleaseKindInput;
  title: string;
  description: string;
  credits: ReleaseCreditInput[];
  coverArt: CoverArtInput;
  discs: DiscInput[];
  releaseRegistryId: string;
  releaseId: string;
  releaseNonce: string;
  musicOsPackageId: string;
  partyOsPackageId: string;
  adminAddress: string;
}

function buildReleaseKind(tx: Transaction, musicOsPackageId: string, kind: ReleaseKindInput) {
  const fn = kind === "Album" ? releaseKind.newAlbumKind : kind === "ExtendedPlay" ? releaseKind.newExtendedPlayKind : releaseKind.newSingleKind;
  return tx.add(fn({ package: musicOsPackageId, arguments: [] }));
}

function buildReleaseCredits(
  tx: Transaction,
  musicOsPackageId: string,
  partyOsPackageId: string,
  releaseArg: TransactionObjectArgument,
  adminCap: TransactionObjectArgument,
  credits: ReleaseCreditInput[],
) {
  const roleType = `${musicOsPackageId}::release_party_role::ReleasePartyRole`;
  for (const credit of credits) {
    const role = credit.role === "Primary" ? relRole.newPrimaryRole({ package: musicOsPackageId, arguments: [] }) : relRole.newFeaturedRole({ package: musicOsPackageId, arguments: [] });
    const roleArg = tx.add(role);
    const creditArg = buildCredit(tx, partyOsPackageId, roleType, credit.displayName, [roleArg]);
    tx.add(release.addCredit({ package: musicOsPackageId, arguments: [releaseArg, adminCap, tx.object(credit.partyId), creditArg] }));
  }
}

function buildDiscVec(
  tx: Transaction,
  musicOsPackageId: string,
  trackArgsByDisc: { title?: string; trackArgs: TransactionObjectArgument[] }[],
) {
  const discArgs = trackArgsByDisc.map(({ title, trackArgs }) => {
    const trackVec = tx.makeMoveVec({ type: `${musicOsPackageId}::track::Track`, elements: trackArgs });
    return tx.add(disc._new({ package: musicOsPackageId, arguments: [trackVec, buildTitleOption(tx, title)] }));
  });
  return tx.makeMoveVec({ type: `${musicOsPackageId}::disc::Disc`, elements: discArgs });
}

export function publishRelease(params: PublishReleaseParams): TxThunk {
  return (tx) => {
    const { musicOsPackageId } = params;
    const byDisc = params.discs.map((d) => ({
      title: d.title,
      trackArgs: d.tracks.map((t) => {
        const dealArg = tx.add(
          deal._new({
            package: musicOsPackageId,
            typeArguments: [t.compositionShareType, t.recordingShareType],
            arguments: [tx.object(t.recordingAdminCapId), tx.object(t.compositionId), tx.object(t.recordingId), tx.pure.id(params.releaseId), tx.pure.u16(t.splitBps), buildTitleOption(tx, t.title), buildCoverArtOption(tx, musicOsPackageId, undefined, undefined)],
          }),
        );
        return tx.add(track._new({ package: musicOsPackageId, arguments: [dealArg] }));
      }),
    }));
    const discVec = buildDiscVec(tx, musicOsPackageId, byDisc);
    const cover = buildCoverArt(tx, params.walrusDataPackageId, musicOsPackageId, params.coverArt);
    const kindArg = buildReleaseKind(tx, musicOsPackageId, params.kind);
    const result = tx.add(
      release._new({
        package: musicOsPackageId,
        arguments: [kindArg, tx.pure.string(params.title), tx.pure.string(params.description), cover, discVec, tx.pure.u256(BigInt(params.releaseNonce)), tx.object(params.releaseRegistryId)],
      }),
    );
    const releaseArg = result[0]!;
    const adminCap = result[1]!;
    buildReleaseCredits(tx, musicOsPackageId, params.partyOsPackageId, releaseArg, adminCap, params.credits);
    tx.add(release.publish({ package: musicOsPackageId, arguments: [releaseArg, adminCap] }));
    tx.transferObjects([adminCap], tx.pure.address(params.adminAddress));
  };
}

export interface DealInput {
  dealId: string;
}

export interface DiscFromDealsInput {
  deals: DealInput[];
  title?: string;
}

export interface PublishReleaseFromDealsParams {
  walrusDataPackageId: string;
  kind: ReleaseKindInput;
  title: string;
  description: string;
  credits: ReleaseCreditInput[];
  coverArt: CoverArtInput;
  discs: DiscFromDealsInput[];
  releaseRegistryId: string;
  releaseNonce: string;
  musicOsPackageId: string;
  partyOsPackageId: string;
  adminAddress: string;
}

export function publishReleaseFromDeals(params: PublishReleaseFromDealsParams): TxThunk {
  return (tx) => {
    const { musicOsPackageId } = params;
    const byDisc = params.discs.map((d) => ({
      title: d.title,
      trackArgs: d.deals.map((dl) => tx.add(track._new({ package: musicOsPackageId, arguments: [tx.object(dl.dealId)] }))),
    }));
    const discVec = buildDiscVec(tx, musicOsPackageId, byDisc);
    const cover = buildCoverArt(tx, params.walrusDataPackageId, musicOsPackageId, params.coverArt);
    const kindArg = buildReleaseKind(tx, musicOsPackageId, params.kind);
    const result = tx.add(
      release._new({
        package: musicOsPackageId,
        arguments: [kindArg, tx.pure.string(params.title), tx.pure.string(params.description), cover, discVec, tx.pure.u256(BigInt(params.releaseNonce)), tx.object(params.releaseRegistryId)],
      }),
    );
    const releaseArg = result[0]!;
    const adminCap = result[1]!;
    buildReleaseCredits(tx, musicOsPackageId, params.partyOsPackageId, releaseArg, adminCap, params.credits);
    tx.add(release.publish({ package: musicOsPackageId, arguments: [releaseArg, adminCap] }));
    tx.transferObjects([adminCap], tx.pure.address(params.adminAddress));
  };
}

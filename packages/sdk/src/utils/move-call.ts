// Copyright (c) Studio Mirai, LLC
// SPDX-License-Identifier: Apache-2.0

import { Transaction, type TransactionArgument } from "@mysten/sui/transactions";
import type { WalrusData, CoverArt, MusicalKey, TimeSignature } from "../types/common.js";
import type { Audio, Stem } from "../types/audio.js";
import type { CompositionRole, CompositionCredit } from "../types/composition.js";
import type { RecordingRole, RecordingCredit } from "../types/recording.js";
import type { ReleaseKind } from "../types/release.js";
import {
  AudioSchema,
  CoverArtSchema,
  CompositionCreditSchema,
  CompositionRoleSchema,
  MusicalKeySchema,
  ReleaseKindSchema,
  RecordingContributorLevelSchema,
  RecordingCreditSchema,
  RecordingRoleSchema,
  StemSchema,
  TimeSignatureSchema,
  WalrusDataSchema,
} from "../schemas/index.js";

/**
 * Create a WalrusData Move struct.
 */
export function makeWalrusData(
  tx: Transaction,
  packageId: string,
  data: WalrusData
): ReturnType<typeof tx.moveCall> {
  const parsed = WalrusDataSchema.parse(data);
  return tx.moveCall({
    target: `${packageId}::walrus_data::new`,
    arguments: [
      tx.pure.string(parsed.blobId),
      tx.pure.u64(parsed.endEpoch),
    ],
  });
}

/**
 * Create a CoverArt Move struct.
 */
export function makeCoverArt(
  tx: Transaction,
  packageId: string,
  coverArt: CoverArt
): ReturnType<typeof tx.moveCall> {
  const parsed = CoverArtSchema.parse(coverArt);
  const staticData = makeWalrusData(tx, packageId, parsed.static);

  let animatedOption;
  if (parsed.animated) {
    const animatedData = makeWalrusData(tx, packageId, parsed.animated);
    animatedOption = tx.moveCall({
      target: "0x1::option::some",
      typeArguments: [`${packageId}::walrus_data::WalrusData`],
      arguments: [animatedData],
    });
  } else {
    animatedOption = tx.moveCall({
      target: "0x1::option::none",
      typeArguments: [`${packageId}::walrus_data::WalrusData`],
    });
  }

  return tx.moveCall({
    target: `${packageId}::cover_art::new`,
    arguments: [staticData, animatedOption],
  });
}

/**
 * Create an Audio Move struct.
 */
export function makeAudio(
  tx: Transaction,
  packageId: string,
  audio: Audio
): ReturnType<typeof tx.moveCall> {
  const parsed = AudioSchema.parse(audio);
  const walrusData = makeWalrusData(tx, packageId, parsed.data);

  return tx.moveCall({
    target: `${packageId}::audio::new`,
    arguments: [
      tx.pure.u8(parsed.channels),
      tx.pure.u8(parsed.bitDepth),
      tx.pure.u32(parsed.sampleRateHz),
      tx.pure.u64(parsed.samples),
      walrusData,
      tx.pure.vector("u8", Array.from(parsed.pcmDigest)),
    ],
  });
}

/**
 * Create a Stem Move struct.
 */
export function makeStem(
  tx: Transaction,
  packageId: string,
  stem: Stem
): ReturnType<typeof tx.moveCall> {
  const parsed = StemSchema.parse(stem);
  const audio = makeAudio(tx, packageId, parsed.audio);
  const contributors = parsed.contributors.map((id) => tx.pure.id(id));
  const contributorsVec = tx.makeMoveVec({
    type: "0x2::object::ID",
    elements: contributors,
  });

  return tx.moveCall({
    target: `${packageId}::stem::new`,
    arguments: [audio, tx.pure.string(parsed.description), contributorsVec],
  });
}

/**
 * Create a MusicalKey Move struct.
 */
export function makeMusicalKey(
  tx: Transaction,
  packageId: string,
  key: MusicalKey
): ReturnType<typeof tx.moveCall> {
  const parsed = MusicalKeySchema.parse(key);
  return tx.moveCall({
    target: `${packageId}::musical_key::new_from_strings`,
    arguments: [
      tx.pure.string(parsed.note.toLowerCase()),
      tx.pure.string(parsed.accidental),
      tx.pure.string(parsed.mode),
    ],
  });
}

/**
 * Create a TimeSignature Move struct.
 */
export function makeTimeSignature(
  tx: Transaction,
  packageId: string,
  timeSignature: TimeSignature
): ReturnType<typeof tx.moveCall> {
  const parsed = TimeSignatureSchema.parse(timeSignature);
  return tx.moveCall({
    target: `${packageId}::time_signature::new`,
    arguments: [
      tx.pure.u8(parsed.beatsPerMeasure),
      tx.pure.u8(parsed.beatUnit),
    ],
  });
}

/**
 * Create a composition role enum variant.
 */
export function makeCompositionRole(
  tx: Transaction,
  packageId: string,
  role: CompositionRole
): ReturnType<typeof tx.moveCall> {
  const parsed = CompositionRoleSchema.parse(role);
  const fnName = `new_${parsed}_role`;
  return tx.moveCall({
    target: `${packageId}::composition_party_role::${fnName}`,
  });
}

/**
 * Create a composition credit.
 */
export function makeCompositionCredit(
  tx: Transaction,
  packageId: string,
  credit: CompositionCredit
): ReturnType<typeof tx.moveCall> {
  const parsed = CompositionCreditSchema.parse(credit);
  const roles = parsed.roles.map((role) =>
    makeCompositionRole(tx, packageId, role)
  );

  const rolesVec = tx.makeMoveVec({
    type: `${packageId}::composition_party_role::CompositionPartyRole`,
    elements: roles,
  });

  return tx.moveCall({
    target: `${packageId}::credit::new`,
    typeArguments: [`${packageId}::composition_party_role::CompositionPartyRole`],
    arguments: [tx.pure.string(parsed.displayName), rolesVec],
  });
}

/**
 * Create a recording contributor level enum variant.
 */
export function makeRecordingLevel(
  tx: Transaction,
  packageId: string,
  level: string
): ReturnType<typeof tx.moveCall> {
  const parsed = RecordingContributorLevelSchema.parse(level);
  const fnName = `new_${parsed}_role_level`;
  return tx.moveCall({
    target: `${packageId}::recording_party_role::${fnName}`,
  });
}

/**
 * Create a recording role enum variant.
 */
export function makeRecordingRole(
  tx: Transaction,
  packageId: string,
  role: RecordingRole
): ReturnType<typeof tx.moveCall> {
  const parsed = RecordingRoleSchema.parse(role);
  const fnName = `new_${parsed.type}_role`;

  // Handle roles with different signatures
  if (parsed.type === "artists_and_repertoire" || parsed.type === "copyist") {
    // These roles have no level
    return tx.moveCall({
      target: `${packageId}::recording_party_role::${fnName}`,
    });
  } else if (parsed.type === "instrumentalist") {
    // Instrumentalist requires instrument name
    const instrument = parsed.instrument;
    let levelOption;
    if (parsed.level) {
      const level = makeRecordingLevel(tx, packageId, parsed.level);
      levelOption = tx.moveCall({
        target: "0x1::option::some",
        typeArguments: [`${packageId}::recording_party_role::RecordingPartyRoleLevel`],
        arguments: [level],
      });
    } else {
      levelOption = tx.moveCall({
        target: "0x1::option::none",
        typeArguments: [`${packageId}::recording_party_role::RecordingPartyRoleLevel`],
      });
    }
    return tx.moveCall({
      target: `${packageId}::recording_party_role::${fnName}`,
      arguments: [tx.pure.string(instrument), levelOption],
    });
  } else {
    // Most roles take Option<Level>
    let levelOption;
    if (parsed.level) {
      const level = makeRecordingLevel(tx, packageId, parsed.level);
      levelOption = tx.moveCall({
        target: "0x1::option::some",
        typeArguments: [`${packageId}::recording_party_role::RecordingPartyRoleLevel`],
        arguments: [level],
      });
    } else {
      levelOption = tx.moveCall({
        target: "0x1::option::none",
        typeArguments: [`${packageId}::recording_party_role::RecordingPartyRoleLevel`],
      });
    }
    return tx.moveCall({
      target: `${packageId}::recording_party_role::${fnName}`,
      arguments: [levelOption],
    });
  }
}

/**
 * Create a recording credit.
 */
export function makeRecordingCredit(
  tx: Transaction,
  packageId: string,
  credit: RecordingCredit
): ReturnType<typeof tx.moveCall> {
  const parsed = RecordingCreditSchema.parse(credit);
  const roles = parsed.roles.map((role) =>
    makeRecordingRole(tx, packageId, role)
  );

  const rolesVec = tx.makeMoveVec({
    type: `${packageId}::recording_party_role::RecordingPartyRole`,
    elements: roles,
  });

  return tx.moveCall({
    target: `${packageId}::credit::new`,
    typeArguments: [`${packageId}::recording_party_role::RecordingPartyRole`],
    arguments: [tx.pure.string(parsed.displayName), rolesVec],
  });
}

/**
 * Create a ReleaseKind Move enum value.
 */
export function makeReleaseKind(
  tx: Transaction,
  kind: ReleaseKind
): TransactionArgument {
  const parsed = ReleaseKindSchema.parse(kind);
  const variant =
    parsed === "album" ? "Album" : parsed === "ep" ? "EP" : "Single";
  return tx.pure({ $kind: variant });
}

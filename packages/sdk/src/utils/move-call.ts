// Copyright (c) Studio Mirai, LLC
// SPDX-License-Identifier: Apache-2.0

import { Transaction } from "@mysten/sui/transactions";
import type { WalrusData, CoverArt, MusicalKey, TimeSignature } from "../types/common.js";
import type { Audio, Stem } from "../types/audio.js";
import type { CompositionRole, CompositionCredit } from "../types/composition.js";
import type { RecordingRole, RecordingCredit } from "../types/recording.js";

/**
 * Create a WalrusData Move struct.
 */
export function makeWalrusData(
  tx: Transaction,
  packageId: string,
  data: WalrusData
): ReturnType<typeof tx.moveCall> {
  return tx.moveCall({
    target: `${packageId}::walrus_data::new`,
    arguments: [
      tx.pure.string(data.blobId),
      tx.pure.u64(data.endEpoch),
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
  const staticData = makeWalrusData(tx, packageId, coverArt.static);

  let animatedOption;
  if (coverArt.animated) {
    const animatedData = makeWalrusData(tx, packageId, coverArt.animated);
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
  const walrusData = makeWalrusData(tx, packageId, audio.data);

  return tx.moveCall({
    target: `${packageId}::audio::new`,
    arguments: [
      tx.pure.u8(audio.channels),
      tx.pure.u8(audio.bitDepth),
      tx.pure.u32(audio.sampleRateHz),
      tx.pure.u64(audio.samples),
      walrusData,
      tx.pure.vector("u8", Array.from(audio.pcmDigest)),
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
  const audio = makeAudio(tx, packageId, stem.audio);

  return tx.moveCall({
    target: `${packageId}::stem::new`,
    arguments: [audio, tx.pure.string(stem.description)],
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
  const noteVariant = key.note.toUpperCase();
  const accidentalVariant = capitalizeFirst(key.accidental);
  const modeVariant = capitalizeFirst(key.mode);

  const note = tx.moveCall({
    target: `${packageId}::musical_key::${noteVariant}`,
  });
  const accidental = tx.moveCall({
    target: `${packageId}::musical_key::${accidentalVariant}`,
  });
  const mode = tx.moveCall({
    target: `${packageId}::musical_key::${modeVariant}`,
  });

  return tx.moveCall({
    target: `${packageId}::musical_key::new`,
    arguments: [note, accidental, mode],
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
  return tx.moveCall({
    target: `${packageId}::time_signature::new`,
    arguments: [
      tx.pure.u8(timeSignature.beatsPerMeasure),
      tx.pure.u8(timeSignature.beatUnit),
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
  const fnName = `new_${role}_role`;
  return tx.moveCall({
    target: `${packageId}::composition_contributor_role::${fnName}`,
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
  const roles = credit.roles.map((role) =>
    makeCompositionRole(tx, packageId, role)
  );

  const rolesVec = tx.makeMoveVec({
    type: `${packageId}::composition_contributor_role::CompositionContributorRole`,
    elements: roles,
  });

  return tx.moveCall({
    target: `${packageId}::credit::new`,
    typeArguments: [`${packageId}::composition_contributor_role::CompositionContributorRole`],
    arguments: [tx.pure.string(credit.displayName), rolesVec],
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
  const fnName = `new_${level}_level`;
  return tx.moveCall({
    target: `${packageId}::recording_contributor_role::${fnName}`,
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
  const fnName = `new_${role.type}_role`;

  // Handle roles with different signatures
  if (role.type === "artists_and_repertoire" || role.type === "copyist") {
    // These roles have no level
    return tx.moveCall({
      target: `${packageId}::recording_contributor_role::${fnName}`,
    });
  } else if (role.type === "instrumentalist") {
    // Instrumentalist requires instrument name
    const instrument = role.instrument || "Unknown";
    let levelOption;
    if (role.level) {
      const level = makeRecordingLevel(tx, packageId, role.level);
      levelOption = tx.moveCall({
        target: "0x1::option::some",
        typeArguments: [`${packageId}::recording_contributor_role::RecordingContributorLevel`],
        arguments: [level],
      });
    } else {
      levelOption = tx.moveCall({
        target: "0x1::option::none",
        typeArguments: [`${packageId}::recording_contributor_role::RecordingContributorLevel`],
      });
    }
    return tx.moveCall({
      target: `${packageId}::recording_contributor_role::${fnName}`,
      arguments: [tx.pure.string(instrument), levelOption],
    });
  } else {
    // Most roles take Option<Level>
    let levelOption;
    if (role.level) {
      const level = makeRecordingLevel(tx, packageId, role.level);
      levelOption = tx.moveCall({
        target: "0x1::option::some",
        typeArguments: [`${packageId}::recording_contributor_role::RecordingContributorLevel`],
        arguments: [level],
      });
    } else {
      levelOption = tx.moveCall({
        target: "0x1::option::none",
        typeArguments: [`${packageId}::recording_contributor_role::RecordingContributorLevel`],
      });
    }
    return tx.moveCall({
      target: `${packageId}::recording_contributor_role::${fnName}`,
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
  const roles = credit.roles.map((role) =>
    makeRecordingRole(tx, packageId, role)
  );

  const rolesVec = tx.makeMoveVec({
    type: `${packageId}::recording_contributor_role::RecordingContributorRole`,
    elements: roles,
  });

  return tx.moveCall({
    target: `${packageId}::credit::new`,
    typeArguments: [`${packageId}::recording_contributor_role::RecordingContributorRole`],
    arguments: [tx.pure.string(credit.displayName), rolesVec],
  });
}

function capitalizeFirst(s: string): string {
  return s.charAt(0).toUpperCase() + s.slice(1);
}

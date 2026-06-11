// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

// Barrel for the codegen-generated, ABI-bound bindings (BCS structs + type-safe
// Move calls). Re-exported from the package root as the `contracts` namespace.

export * as composition from "./contracts/musicos/composition.ts";
export * as recording from "./contracts/musicos/recording.ts";
export * as release from "./contracts/musicos/release.ts";
export * as deal from "./contracts/musicos/deal.ts";
export * as track from "./contracts/musicos/track.ts";
export * as disc from "./contracts/musicos/disc.ts";
export * as coverArt from "./contracts/musicos/cover_art.ts";
export * as compositionPartyRole from "./contracts/musicos/composition_party_role.ts";
export * as recordingPartyRole from "./contracts/musicos/recording_party_role.ts";
export * as releasePartyRole from "./contracts/musicos/release_party_role.ts";

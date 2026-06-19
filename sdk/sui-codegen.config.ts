import type { SuiCodegenConfig } from "@mysten/codegen";

// Generates type-safe BCS structs + Move-call bindings from the local Move
// packages in ../move. Because the bindings are generated from the live source,
// the generated layer is always in lockstep with the on-chain ABI.
const config: SuiCodegenConfig = {
  output: "./src/contracts",
  packages: [
    { package: "@local-pkg/miso", path: "../move/core" },
    // First-party extension packages (move/extensions/*).
    { package: "@local-pkg/recording_credits", path: "../move/extensions/recording_credits" },
    { package: "@local-pkg/composition_credits", path: "../move/extensions/composition_credits" },
    { package: "@local-pkg/release_credits", path: "../move/extensions/release_credits" },
    { package: "@local-pkg/cover_art", path: "../move/extensions/cover_art" },
    { package: "@local-pkg/genre", path: "../move/extensions/genre" },
    // NOTE: audio_ingester bindings are intentionally omitted — that package lives
    // in the external audio-ingester repo whose Move.toml must first be repointed
    // at this repo's renamed core (move/core). Re-add once that repo is updated.
  ],
};

export default config;

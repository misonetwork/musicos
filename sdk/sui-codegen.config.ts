import type { SuiCodegenConfig } from "@mysten/codegen";

// Generates type-safe BCS structs + Move-call bindings from the live Move source,
// so the generated layer is always in lockstep with the on-chain ABI.
//
// The core protocol package (`@local-pkg/miso`) plus first-party EXTENSION
// packages both live here — this SDK is the single home for Miso Move bindings.
//
// To add support for a new extension:
//   1. add its Move package(s) below (the extension module + any lib it needs);
//   2. run `bun run codegen` → bindings land in src/contracts/<package>/;
//   3. write a thin facade in src/extensions/<name>.ts and export it.
const config: SuiCodegenConfig = {
  output: "./src/contracts",
  packages: [
    { package: "@local-pkg/miso", path: "../move" },

    // Extensions
    { package: "@local-pkg/royalty_pool", path: "../../miso-protocol-extensions/lib/royalty_pool" },
    { package: "@local-pkg/composition_royalty_pool", path: "../../miso-protocol-extensions/composition_royalty_pool" },
    { package: "@local-pkg/recording_royalty_pool", path: "../../miso-protocol-extensions/recording_royalty_pool" },

    // Record layer — the drop (record sale) + cover art (a Walrus blob ref
    // via ori, attached to a Release by release_cover_art). Both drive the
    // album-publish CLI flow and the app's featured-drop render.
    { package: "@local-pkg/miso_drop", path: "../../miso-drop/move" },
    { package: "@local-pkg/cover_art", path: "../../miso-protocol-extensions/lib/cover_art" },
    // Caveat: release_cover_art transitively depends on ori (walrus_data), which
    // is NOT declared here, so its dep bindings land under the deployed package
    // address (src/contracts/release_cover_art/deps/0x340057f2…/walrus_data.ts)
    // rather than a readable name. @mysten/codegen has no address→name mapping
    // for transitive deps (only declared packages get names, and declaring ori
    // would generate full bindings for an external package). If ori is ever
    // redeployed, re-run codegen so the baked dep address tracks the new one.
    { package: "@local-pkg/release_cover_art", path: "../../miso-protocol-extensions/release_cover_art" },

    // Credits — contributor attribution (display name + roles) attached to a
    // work via a dynamic field, gated by the work's admin cap. The shared
    // `miso_credit::credit::Credit<Role>` type is pulled in as a dep. Drives the
    // credits CLI flow and the app's contributor render.
    { package: "@local-pkg/composition_credits", path: "../../miso-protocol-extensions/composition_credits" },
    { package: "@local-pkg/recording_credits", path: "../../miso-protocol-extensions/recording_credits" },
    { package: "@local-pkg/release_credits", path: "../../miso-protocol-extensions/release_credits" },
  ],
};

export default config;

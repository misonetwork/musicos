import type { SuiCodegenConfig } from "@mysten/codegen";

// Generates type-safe BCS structs + Move-call bindings from the local Move
// package in ../move. Because the bindings are generated from the live source,
// the generated layer is always in lockstep with the on-chain ABI.
const config: SuiCodegenConfig = {
  output: "./src/contracts",
  packages: [
    {
      package: "@local-pkg/musicos",
      path: "../move",
    },
  ],
};

export default config;

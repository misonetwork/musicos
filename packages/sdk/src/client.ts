// Copyright (c) Studio Mirai, LLC
// SPDX-License-Identifier: Apache-2.0

import type { MusicOSConfig, NetworkPreset } from "./types/common.js";
import { ContributorClient } from "./clients/contributor.js";
import { CompositionClient } from "./clients/composition.js";
import { RecordingClient } from "./clients/recording.js";
import { ReleaseClient } from "./clients/release.js";
import { GenreClient } from "./clients/genre.js";

/**
 * Known package deployments by network.
 */
const NETWORK_CONFIGS: Record<NetworkPreset, Partial<MusicOSConfig>> = {
  mainnet: {
    // TODO: Add mainnet package ID when deployed
    packageId: "",
  },
  testnet: {
    // TODO: Add testnet package ID when deployed
    packageId: "",
  },
  devnet: {
    // TODO: Add devnet package ID when deployed
    packageId: "",
  },
  localnet: {
    // Localnet uses dynamic package IDs
    packageId: "",
  },
};

/**
 * Main client for interacting with MusicOS contracts.
 *
 * @example
 * ```ts
 * import { MusicOSClient } from "@musicos/sdk";
 *
 * const client = new MusicOSClient({
 *   packageId: "0x...",
 * });
 *
 * // Create a contributor
 * const tx = client.contributors.create({
 *   kind: "individual",
 *   name: "Artist Name",
 * });
 *
 * // Sign and execute with your wallet
 * await suiClient.signAndExecuteTransaction({ transaction: tx, signer });
 * ```
 */
export class MusicOSClient {
  /** Configuration for this client instance. */
  readonly config: MusicOSConfig;

  /** Client for managing contributors. */
  readonly contributors: ContributorClient;

  /** Client for managing compositions. */
  readonly compositions: CompositionClient;

  /** Client for managing recordings. */
  readonly recordings: RecordingClient;

  /** Client for managing releases. */
  readonly releases: ReleaseClient;

  /** Client for managing genres. */
  readonly genres: GenreClient;

  /**
   * Create a new MusicOS client.
   *
   * @param config - Configuration options including package ID
   */
  constructor(config: MusicOSConfig) {
    if (!config.packageId) {
      throw new Error("packageId is required");
    }

    this.config = config;

    // Initialize domain clients
    this.contributors = new ContributorClient(config.packageId);
    this.compositions = new CompositionClient(config.packageId);
    this.recordings = new RecordingClient(config.packageId);
    this.releases = new ReleaseClient(config.packageId);
    this.genres = new GenreClient(config.packageId);
  }

  /**
   * Create a client for a known network preset.
   *
   * @param network - Network preset name
   * @param overrides - Optional config overrides
   */
  static forNetwork(
    network: NetworkPreset,
    overrides?: Partial<MusicOSConfig>
  ): MusicOSClient {
    const networkConfig = NETWORK_CONFIGS[network];
    if (!networkConfig.packageId && !overrides?.packageId) {
      throw new Error(
        `No package ID configured for network "${network}". Please provide packageId in overrides.`
      );
    }

    return new MusicOSClient({
      ...networkConfig,
      ...overrides,
    } as MusicOSConfig);
  }

  /**
   * Get the package ID this client is configured for.
   */
  get packageId(): string {
    return this.config.packageId;
  }
}

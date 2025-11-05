import { WalrusClient } from "@mysten/walrus";
import { SealClient } from "@mysten/seal";
import { SuiClient, getFullnodeUrl } from "@mysten/sui/client";
import { SuiJsonRpcClient } from "@mysten/sui/jsonRpc";
import { walrus } from "@mysten/walrus";

export const walrusClient = new SuiJsonRpcClient({
  url: getFullnodeUrl("mainnet"),
  network: "mainnet",
}).$extend(walrus());

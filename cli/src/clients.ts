import { SealClient } from "@mysten/seal";
import { SuiClient, getFullnodeUrl } from "@mysten/sui/client";
import { SuiJsonRpcClient } from "@mysten/sui/jsonRpc";
import { walrus } from "@mysten/walrus";

const serverObjectIds = [
  "0x4fcb014ba76e01797efbbad90e1fccb375c72e99a17b6d477943b1fedd087fc7",
];

export const suiClient = new SuiClient({
  url: "https://mirainet.tail34d64f.ts.net",
});

export const sealClient = new SealClient({
  suiClient,
  serverConfigs: serverObjectIds.map((id) => ({
    objectId: id,
    weight: 1,
  })),
  verifyKeyServers: false,
});

export const walrusClient = new SuiJsonRpcClient({
  url: getFullnodeUrl("mainnet"),
  network: "mainnet",
}).$extend(walrus());

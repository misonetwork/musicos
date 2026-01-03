import { SealClient } from "@mysten/seal";
import { SuiGraphQLClient } from "@mysten/sui/graphql";
import { SuiClient, getFullnodeUrl } from "@mysten/sui/client";
import { SuiJsonRpcClient } from "@mysten/sui/jsonRpc";
import { walrus } from "@mysten/walrus";
import { cleanEnv, str } from "envalid";

const env = cleanEnv(process.env, {
  SUI_RPC_URL: str(),
  SUI_GQL_URL: str(),
});

export const suiClient = new SuiClient({
  url: env.SUI_RPC_URL,
});

export const suiGqlClient = new SuiGraphQLClient({
  url: env.SUI_GQL_URL,
});

export const walrusClient = new SuiJsonRpcClient({
  url: getFullnodeUrl("mainnet"),
  network: "mainnet",
}).$extend(walrus());

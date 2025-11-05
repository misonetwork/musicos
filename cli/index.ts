import { SuiClient } from "@mysten/sui/client";
import { Transaction } from "@mysten/sui/transactions";
import { cleanEnv, num, str } from "envalid";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import { SUI_CLOCK_OBJECT_ID } from "@mysten/sui/utils";

const COIN_REGISTRY_OBJECT_ID =
  "0x000000000000000000000000000000000000000000000000000000000000000c";

const env = cleanEnv(process.env, {
  COMPOSITION_COMMISSION_RATE: num(),
  COMPOSITION_TITLE: str(),
  MUSICOS_PACKAGE_ID: str(),
  SHARE_CURRENCY_PACKAGE_ID: str(),
  SUI_MNEMONIC: str(),
  SUI_RPC_URL: str(),
});

const keypair = Ed25519Keypair.deriveKeypair(env.SUI_MNEMONIC);
const keypairAddress = keypair.getPublicKey().toSuiAddress();
console.log(keypairAddress);

const suiClient = new SuiClient({ url: env.SUI_RPC_URL });

type CreateCompositionShareCurrencyResult = {
  currencyId: string;
  metadataCapId: string;
  treasuryCapId: string;
};

async function createCompositionShareCurrency(): Promise<CreateCompositionShareCurrencyResult> {
  const tx = new Transaction();
  const [metadataCap, treasuryCap] = tx.moveCall({
    target: `${env.SHARE_CURRENCY_PACKAGE_ID}::composition_share::initialize_currency`,
    arguments: [tx.object(COIN_REGISTRY_OBJECT_ID)],
  });
  if (!metadataCap || !treasuryCap) {
    throw new Error("Failed to create composition share currency");
  }
  tx.transferObjects([metadataCap, treasuryCap], keypairAddress);
  const result = await suiClient.signAndExecuteTransaction({
    transaction: tx,
    signer: keypair,
    options: {
      showEffects: true,
      showObjectChanges: true,
    },
  });
  await suiClient.waitForTransaction({
    digest: result.digest,
  });

  let currencyId: string | undefined;
  let metadataCapId: string | undefined;
  let treasuryCapId: string | undefined;

  for (const objChange of result.objectChanges ?? []) {
    if (objChange.type === "created") {
      if (
        objChange.objectType ===
        `0x2::coin_registry::Currency<${env.SHARE_CURRENCY_PACKAGE_ID}::composition_share::CompositionShare>`
      ) {
        currencyId = objChange.objectId;
      }
      if (
        objChange.objectType ===
        `0x2::coin_registry::MetadataCap<${env.SHARE_CURRENCY_PACKAGE_ID}::composition_share::CompositionShare>`
      ) {
        metadataCapId = objChange.objectId;
      }
      if (
        objChange.objectType ===
        `0x2::coin::TreasuryCap<${env.SHARE_CURRENCY_PACKAGE_ID}::composition_share::CompositionShare>`
      ) {
        treasuryCapId = objChange.objectId;
      }
    }
  }
  if (!currencyId) {
    throw new Error("Failed to create composition share currency");
  }
  if (!metadataCapId) {
    throw new Error("Failed to create composition share currency metadata cap");
  }
  if (!treasuryCapId) {
    throw new Error("Failed to create composition share currency treasury cap");
  }
  console.log(`Currency ID: ${currencyId}`);
  console.log(`Metadata Cap ID: ${metadataCapId}`);
  console.log(`Treasury Cap ID: ${treasuryCapId}`);
  console.log(`TX Digest: ${result.digest}`);
  return { currencyId, metadataCapId, treasuryCapId };
}

async function createComposition(
  createCompositionShareCurrencyResult: CreateCompositionShareCurrencyResult
) {
  const compositionShareType = `${env.SHARE_CURRENCY_PACKAGE_ID}::composition_share::CompositionShare`;
  const tx = new Transaction();
  const commissionRateBps = tx.moveCall({
    target: `${env.MUSICOS_PACKAGE_ID}::bps::new`,
    arguments: [tx.pure.u64(env.COMPOSITION_COMMISSION_RATE)],
    typeArguments: [],
  });
  const [composition, compositionAdminCap, balance] = tx.moveCall({
    target: `${env.MUSICOS_PACKAGE_ID}::composition::new`,
    arguments: [
      commissionRateBps,
      tx.pure.string(env.COMPOSITION_TITLE),
      tx.object(createCompositionShareCurrencyResult.currencyId),
      tx.object(createCompositionShareCurrencyResult.metadataCapId),
      tx.object(createCompositionShareCurrencyResult.treasuryCapId),
    ],
    typeArguments: [compositionShareType],
  });
  if (!composition || !compositionAdminCap || !balance) {
    throw new Error("Failed to create composition");
  }
  tx.moveCall({
    target: `${env.MUSICOS_PACKAGE_ID}::composition::publish`,
    arguments: [
      composition,
      compositionAdminCap,
      tx.object(SUI_CLOCK_OBJECT_ID),
    ],
    typeArguments: [compositionShareType],
  });
  const coin = tx.moveCall({
    target: "0x2::coin::from_balance",
    arguments: [balance],
    typeArguments: [compositionShareType],
  });
  tx.transferObjects([compositionAdminCap, coin], keypairAddress);
  const result = await suiClient.signAndExecuteTransaction({
    transaction: tx,
    signer: keypair,
    options: {
      showEffects: true,
      showObjectChanges: true,
    },
  });
  await suiClient.waitForTransaction({
    digest: result.digest,
  });
  console.log(`TX Digest: ${result.digest}`);
  return result;
}

async function main() {
  console.log(`Initializing share currency for composition...`);
  const result = await createCompositionShareCurrency();
  console.log(`Creating composition...`);
  await createComposition(result);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});

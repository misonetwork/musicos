import { Command } from "commander";
import { cleanEnv, str } from "envalid";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import { Transaction } from "@mysten/sui/transactions";
import { graphql } from "@mysten/sui/graphql/schemas/latest";
import { suiClient, suiGqlClient } from "../clients";

const env = cleanEnv(process.env, {
  INTEREST_BPS_PACKAGE_ID: str(),
  MUSICOS_PACKAGE_ID: str(),
  SUI_MNEMONIC: str(),
});

const COMPOSITION_TYPE = `${env.MUSICOS_PACKAGE_ID}::composition::Composition`;
const COMPOSITION_ADMIN_CAP_TYPE = `${env.MUSICOS_PACKAGE_ID}::composition::CompositionAdminCap`;
const COIN_REGISTRY_ID = "0xc";

export function createCompositionCommand(): Command {
  const command = new Command("composition");

  command
    .command("create")
    .description("Create a composition.")
    .argument("<title>", "The title of the composition.")
    .argument("<split>", "The split rate that recordings must pay to the composition.")
    .argument("<sharePackageId>", "The package ID of the composition's share currency.")
    .action(async (title: string, split: number, sharePackageId: string) => {
      const keypair = Ed25519Keypair.deriveKeypair(env.SUI_MNEMONIC);

      const query = graphql(`
        query ($currencyType: String!, $treasuryCapType: String!, $metadataCapType: String!) {
          currency: objects(filter: { type: $currencyType }) {
            nodes {
              address
            }
          }
          metadataCap: objects(filter: { type: $metadataCapType }) {
            nodes {
              address
            }
          }
          treasuryCap: objects(filter: { type: $treasuryCapType }) {
            nodes {
              address
            }
          }
        }
      `);
      const variables = {
        currencyType: `0x2::coin_registry::Currency<${sharePackageId}::share::SHARE>`,
        metadataCapType: `0x2::coin_registry::MetadataCap<${sharePackageId}::share::SHARE>`,
        treasuryCapType: `0x2::coin::TreasuryCap<${sharePackageId}::share::SHARE>`,
      };
      const result = await suiGqlClient.query({ query, variables });

      const shareCurrencyId = result.data?.currency?.nodes?.[0]?.address;
      if (!shareCurrencyId) throw new Error("Share Currency not found");
      const shareMetadataCapId = result.data?.metadataCap?.nodes?.[0]?.address;
      if (!shareMetadataCapId) throw new Error("Share MetadataCap not found");
      const shareTreasuryCapId = result.data?.treasuryCap?.nodes?.[0]?.address;
      if (!shareTreasuryCapId) throw new Error("Share TreasuryCap not found");

      console.log(`Share Currency ID: ${shareCurrencyId}`);
      console.log(`Share MetadataCap ID: ${shareMetadataCapId}`);
      console.log(`Share TreasuryCap ID: ${shareTreasuryCapId}`);

      const tx = new Transaction();

      const splitBps = tx.moveCall({
        target: `${env.INTEREST_BPS_PACKAGE_ID}::bps::new`,
        arguments: [tx.pure.u64(split)],
      });
      const [composition, compositionAdminCap, shareBalance, shareCompositionPromise] = tx.moveCall({
        target: `${env.MUSICOS_PACKAGE_ID}::composition::new`,
        arguments: [
          tx.pure.string(title),
          splitBps,
          tx.object(shareCurrencyId),
          tx.object(shareMetadataCapId),
          tx.object(shareTreasuryCapId),
        ],
        typeArguments: [`${sharePackageId}::share::SHARE`],
      });
      if (!composition) throw new Error("Composition not found");
      if (!shareCompositionPromise) throw new Error("ShareCompositionPromise not found");
      tx.moveCall({
        target: `${env.MUSICOS_PACKAGE_ID}::composition::share`,
        arguments: [composition, shareCompositionPromise],
        typeArguments: [`${sharePackageId}::share::SHARE`],
      });
      if (!shareBalance) throw new Error("Share Balance not found");
      const shareCoin = tx.moveCall({
        target: "0x2::coin::from_balance",
        arguments: [shareBalance],
        typeArguments: [`${sharePackageId}::share::SHARE`],
      });
      if (!compositionAdminCap) throw new Error("Composition Admin Cap not found");
      if (!shareCoin) throw new Error("Share Coin not found");
      tx.transferObjects([compositionAdminCap, shareCoin], keypair.getPublicKey().toSuiAddress());
      const txResult = await suiClient.signAndExecuteTransaction({
        transaction: tx,
        signer: keypair,
      });
      console.log(`Composition created: ${txResult.digest}`);
    });

  command
    .command("add-contributor")
    .description("Add a contributor to a composition.")
    .action(async () => {
      // TODO: Implement composition add-contributor
      console.log("composition add-contributor - not implemented");
    });

  return command;
}

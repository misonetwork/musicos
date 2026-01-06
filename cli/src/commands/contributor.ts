import { Command } from "commander";
import { Transaction } from "@mysten/sui/transactions";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import { cleanEnv, str } from "envalid";
import { suiClient, suiGqlClient } from "../clients";
import { isValidSuiAddress } from "@mysten/sui/utils";
import { SuiGraphQLClient } from "@mysten/sui/graphql";
import { graphql } from "@mysten/sui/graphql/schemas/latest";

const env = cleanEnv(process.env, {
  MUSICOS_PACKAGE_ID: str(),
  SUI_MNEMONIC: str(),
});

const CONTRIBUTOR_TYPE = `${env.MUSICOS_PACKAGE_ID}::contributor::Contributor`;
const CONTRIBUTOR_ADMIN_CAP_TYPE = `${env.MUSICOS_PACKAGE_ID}::contributor::ContributorAdminCap`;

export function createContributorCommand(): Command {
  const command = new Command("contributor");

  command
    .command("create")
    .description("Create a contributor.")
    .argument("<kind>", "The kind of contributor to create (individual or group).")
    .argument("<name>", "The name of the contributor.")
    .argument("<recipient>", "The address to send the ContributorAdminCap to.")
    .action(async (kind: string, name: string, recipient: string) => {
      if (kind !== "individual" && kind !== "group") {
        throw new Error("Invalid value for <kind>. Must be either 'individual' or 'group'.");
      }
      if (!isValidSuiAddress(recipient)) {
        throw new Error("Invalid value for <recipient>. Must be a valid SUI address.");
      }
      try {
        const keypair = Ed25519Keypair.deriveKeypair(env.SUI_MNEMONIC);
        console.log(`Creating Contributor for address: ${recipient}`);

        const tx = new Transaction();
        const contributorKind = tx.moveCall({
          target: `${env.MUSICOS_PACKAGE_ID}::contributor::new_${kind}_kind`,
          arguments: [],
        });
        const contributorAdminCap = tx.moveCall({
          target: `${env.MUSICOS_PACKAGE_ID}::contributor::new`,
          arguments: [contributorKind, tx.pure.string(name)],
        });

        if (!contributorAdminCap) {
          throw new Error("Failed to create CreateAdminCap.");
        }

        tx.transferObjects([contributorAdminCap], recipient);

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

        let contributorId: string | undefined;
        let adminCapId: string | undefined;

        for (const objChange of result.objectChanges ?? []) {
          if (objChange.type === "created") {
            if (objChange.objectType === `${env.MUSICOS_PACKAGE_ID}::contributor::Contributor`) {
              contributorId = objChange.objectId;
            }
            if (objChange.objectType === `${env.MUSICOS_PACKAGE_ID}::contributor::ContributorAdminCap`) {
              adminCapId = objChange.objectId;
            }
          }
        }

        console.log(`\n✓ Contributor created successfully!`);
        if (contributorId) {
          console.log(`  Contributor ID: ${contributorId}`);
        }
        if (adminCapId) {
          console.log(`  Admin Cap ID: ${adminCapId}`);
        }
        console.log(`  Transaction Digest: ${result.digest}`);
      } catch (error) {
        console.error("Error creating contributor:", error);
        process.exit(1);
      }
    });

  command
    .command("list")
    .description("List contributors you have admin access to.")
    .option("-a, --address <address>", "Address to query (defaults to your wallet address)")
    .action(async (options: { address?: string }) => {
      const query = graphql(`
        query ($type: String) {
          objects(filter: { type: $type }) {
            nodes {
              asMoveObject {
                contents {
                  json
                }
              }
            }
          }
        }
      `);
      const result = await suiGqlClient.query({ query, variables: { type: CONTRIBUTOR_TYPE } });
      result.data?.objects?.nodes?.forEach((contributor) => {
        console.log(contributor.asMoveObject?.contents?.json);
      });
    });

  return command;
}

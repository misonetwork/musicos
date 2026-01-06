import { Command } from "commander";

export function createShareCommand(): Command {
  const command = new Command("share");

  command
    .command("create")
    .description("Create a share currency.")
    .action(async () => {
      // TODO: Implement share create
      console.log("share create - not implemented");
    });

  return command;
}


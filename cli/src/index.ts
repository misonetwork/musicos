#!/usr/bin/env bun

import { Command } from "commander";
import { createCompositionCommand } from "./commands/composition";
import { createContributorCommand } from "./commands/contributor";
import { createShareCommand } from "./commands/share";

const program = new Command();

program
  .name("musicos")
  .description("CLI for MusicOS protocol")
  .version("1.0.0");

// Add commands
program.addCommand(createCompositionCommand());
program.addCommand(createContributorCommand());
program.addCommand(createShareCommand());

// Parse command line arguments
program.parse();

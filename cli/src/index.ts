#!/usr/bin/env bun

import { Command } from "commander";
import { createContributorCommand } from "./commands/contributor";

const program = new Command();

program
  .name("musicos")
  .description("CLI for MusicOS protocol")
  .version("1.0.0");

// Add contributor command
program.addCommand(createContributorCommand());

// Parse command line arguments
program.parse();

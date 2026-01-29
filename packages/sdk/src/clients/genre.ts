// Copyright (c) Studio Mirai, LLC
// SPDX-License-Identifier: Apache-2.0

import { Transaction } from "@mysten/sui/transactions";
import type { CreateGenreParams } from "../types/genre.js";
import { CreateGenreParamsSchema } from "../schemas/genre.js";

/**
 * Client for managing genres.
 */
export class GenreClient {
  constructor(private readonly packageId: string) {}

  /**
   * Create a new genre.
   * The genre is automatically shared.
   */
  create(params: CreateGenreParams): Transaction {
    const parsed = CreateGenreParamsSchema.parse(params);
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.packageId}::genre::new`,
      arguments: [
        tx.pure.string(parsed.name),
        tx.object(parsed.registryId),
      ],
    });

    return tx;
  }
}

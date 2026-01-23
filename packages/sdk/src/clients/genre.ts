// Copyright (c) Studio Mirai, LLC
// SPDX-License-Identifier: Apache-2.0

import { Transaction } from "@mysten/sui/transactions";
import type { CreateGenreParams } from "../types/genre.js";

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
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.packageId}::genre::new`,
      arguments: [
        tx.pure.string(params.name),
        tx.pure.bool(params.isPrimary),
        tx.object(params.registryId),
      ],
    });

    return tx;
  }
}

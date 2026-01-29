// Copyright (c) Studio Mirai, LLC
// SPDX-License-Identifier: Apache-2.0

import { Transaction } from "@mysten/sui/transactions";
import type {
  CreateContributorParams,
  ShareContributorParams,
  SetContributorNameParams,
  AddGroupMemberParams,
  RemoveGroupMemberParams,
} from "../types/contributor.js";
import {
  AddGroupMemberParamsSchema,
  CreateContributorParamsSchema,
  RemoveGroupMemberParamsSchema,
  SetContributorNameParamsSchema,
  ShareContributorParamsSchema,
} from "../schemas/contributor.js";

/**
 * Client for managing contributors (artists, producers, groups).
 */
export class ContributorClient {
  constructor(private readonly packageId: string) {}

  /**
   * Create a new contributor.
   * Returns a transaction that creates the contributor and admin capability.
   */
  create(params: CreateContributorParams): Transaction {
    const parsed = CreateContributorParamsSchema.parse(params);
    const tx = new Transaction();

    // Create the contributor kind
    const kind = tx.moveCall({
      target: `${this.packageId}::party::new_${parsed.kind}_kind`,
    });

    // Create the contributor
    const [contributor, adminCap] = tx.moveCall({
      target: `${this.packageId}::party::new`,
      arguments: [kind, tx.pure.string(parsed.name)],
    });

    // Transfer both to sender
    tx.transferObjects([contributor, adminCap], tx.pure.address("@sender"));

    return tx;
  }

  /**
   * Share a contributor object (make it a shared object).
   */
  share(params: ShareContributorParams): Transaction {
    const parsed = ShareContributorParamsSchema.parse(params);
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.packageId}::party::share`,
      arguments: [
        tx.object(parsed.contributorId),
        tx.object(parsed.adminCapId),
      ],
    });

    return tx;
  }

  /**
   * Set the contributor's name.
   */
  setName(params: SetContributorNameParams): Transaction {
    const parsed = SetContributorNameParamsSchema.parse(params);
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.packageId}::party::set_name`,
      arguments: [
        tx.object(parsed.contributorId),
        tx.object(parsed.adminCapId),
        tx.pure.string(parsed.name),
      ],
    });

    return tx;
  }

  /**
   * Add an individual contributor to a group.
   */
  addMember(params: AddGroupMemberParams): Transaction {
    const parsed = AddGroupMemberParamsSchema.parse(params);
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.packageId}::party::add_party`,
      arguments: [
        tx.object(parsed.groupId),
        tx.object(parsed.adminCapId),
        tx.object(parsed.memberId),
      ],
    });

    return tx;
  }

  /**
   * Remove a member from a group.
   */
  removeMember(params: RemoveGroupMemberParams): Transaction {
    const parsed = RemoveGroupMemberParamsSchema.parse(params);
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.packageId}::party::remove_party`,
      arguments: [
        tx.object(parsed.groupId),
        tx.object(parsed.adminCapId),
        tx.pure.id(parsed.memberId),
      ],
    });

    return tx;
  }
}

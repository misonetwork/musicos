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
    const tx = new Transaction();

    // Create the contributor kind
    const kind = tx.moveCall({
      target: `${this.packageId}::contributor::new_${params.kind}_kind`,
    });

    // Create the contributor
    const [contributor, adminCap] = tx.moveCall({
      target: `${this.packageId}::contributor::new`,
      arguments: [kind, tx.pure.string(params.name)],
    });

    // Transfer both to sender
    tx.transferObjects([contributor, adminCap], tx.pure.address("@sender"));

    return tx;
  }

  /**
   * Share a contributor object (make it a shared object).
   */
  share(params: ShareContributorParams): Transaction {
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.packageId}::contributor::share`,
      arguments: [
        tx.object(params.contributorId),
        tx.object(params.adminCapId),
      ],
    });

    return tx;
  }

  /**
   * Set the contributor's name.
   */
  setName(params: SetContributorNameParams): Transaction {
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.packageId}::contributor::set_name`,
      arguments: [
        tx.object(params.contributorId),
        tx.object(params.adminCapId),
        tx.pure.string(params.name),
      ],
    });

    return tx;
  }

  /**
   * Add an individual contributor to a group.
   */
  addMember(params: AddGroupMemberParams): Transaction {
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.packageId}::contributor::add_contributor`,
      arguments: [
        tx.object(params.groupId),
        tx.object(params.adminCapId),
        tx.object(params.memberId),
      ],
    });

    return tx;
  }

  /**
   * Remove a member from a group.
   */
  removeMember(params: RemoveGroupMemberParams): Transaction {
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.packageId}::contributor::remove_contributor`,
      arguments: [
        tx.object(params.groupId),
        tx.object(params.adminCapId),
        tx.pure.id(params.memberId),
      ],
    });

    return tx;
  }
}

// Copyright (c) Studio Mirai, LLC
// SPDX-License-Identifier: Apache-2.0

/**
 * Type of contributor: individual person or group.
 */
export type ContributorKind = "individual" | "group";

/**
 * Parameters for creating a new contributor.
 */
export interface CreateContributorParams {
  /** Whether this is an individual or group */
  kind: ContributorKind;
  /** Human-readable name */
  name: string;
}

/**
 * Parameters for sharing a contributor object.
 */
export interface ShareContributorParams {
  /** Contributor object ID */
  contributorId: string;
  /** Admin capability object ID */
  adminCapId: string;
}

/**
 * Parameters for updating contributor name.
 */
export interface SetContributorNameParams {
  /** Contributor object ID */
  contributorId: string;
  /** Admin capability object ID */
  adminCapId: string;
  /** New name */
  name: string;
}

/**
 * Parameters for adding a member to a group.
 */
export interface AddGroupMemberParams {
  /** Group contributor object ID */
  groupId: string;
  /** Admin capability object ID */
  adminCapId: string;
  /** Individual contributor to add */
  memberId: string;
}

/**
 * Parameters for removing a member from a group.
 */
export interface RemoveGroupMemberParams {
  /** Group contributor object ID */
  groupId: string;
  /** Admin capability object ID */
  adminCapId: string;
  /** Member ID to remove */
  memberId: string;
}

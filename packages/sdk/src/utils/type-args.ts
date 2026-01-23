// Copyright (c) Studio Mirai, LLC
// SPDX-License-Identifier: Apache-2.0

/**
 * Parse a type string into its components.
 * e.g., "0xabc::my_module::MyType" -> { address: "0xabc", module: "my_module", name: "MyType" }
 */
export function parseTypeString(typeStr: string): {
  address: string;
  module: string;
  name: string;
} {
  const parts = typeStr.split("::");
  if (parts.length !== 3) {
    throw new Error(`Invalid type string: ${typeStr}`);
  }
  return {
    address: parts[0],
    module: parts[1],
    name: parts[2],
  };
}

/**
 * Validate that a share type ends with "::share::Share" pattern.
 */
export function validateShareType(shareType: string): void {
  if (!shareType.includes("::") || !shareType.endsWith("Share")) {
    throw new Error(
      `Invalid share type: ${shareType}. Expected format: "0x...::module::Share"`
    );
  }
}

/**
 * Get the SUI Clock object ID (always 0x6).
 */
export const SUI_CLOCK_OBJECT_ID = "0x6";

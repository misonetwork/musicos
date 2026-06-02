// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

// Structural drift gate for the (sync, client-free) tx builders: build the
// transaction and assert the generated Move calls are wired with the right
// module/function, type arguments, and argument counts. Catches arg-order and
// signature drift in the builders.

import { test, expect } from "bun:test";
import { Transaction } from "@mysten/sui/transactions";
import { createDeal, publishRelease } from "../src/transactions.ts";

const PKG = "0x" + "cd".repeat(32);
const A = "0x" + "ab".repeat(32);

interface MoveCallInfo {
  module: string;
  function: string;
  typeArguments: string[];
  argCount: number;
}

function moveCalls(tx: Transaction): MoveCallInfo[] {
  const data = tx.getData() as { commands: { $kind: string; MoveCall?: { module: string; function: string; typeArguments: string[]; arguments: unknown[] } }[] };
  return data.commands
    .filter((c) => c.$kind === "MoveCall" && c.MoveCall)
    .map((c) => ({
      module: c.MoveCall!.module,
      function: c.MoveCall!.function,
      typeArguments: c.MoveCall!.typeArguments,
      argCount: c.MoveCall!.arguments.length,
    }));
}

function kinds(tx: Transaction): string[] {
  return (tx.getData() as { commands: { $kind: string }[] }).commands.map((c) => c.$kind);
}

test("createDeal wires deal::new (7 args, both share types) and transfers the deal", () => {
  const tx = new Transaction();
  createDeal({
    recordingId: A,
    recordingAdminCapId: A,
    compositionId: A,
    compositionShareType: `${PKG}::s::S`,
    recordingShareType: `${PKG}::r::R`,
    releaseId: A,
    trackSplitBps: 5000,
    recipientAddress: A,
    musicOsPackageId: PKG,
  })(tx);

  const dealNew = moveCalls(tx).find((c) => c.module === "deal" && c.function === "new");
  expect(dealNew).toBeDefined();
  // (cap, composition, recording, release_id, split, title_opt, cover_opt)
  expect(dealNew!.argCount).toBe(7);
  expect(dealNew!.typeArguments).toEqual([`${PKG}::s::S`, `${PKG}::r::R`]);
  expect(kinds(tx)).toContain("TransferObjects");
});

test("publishRelease wires deal -> track -> disc -> release::new -> add_credit -> publish", () => {
  const tx = new Transaction();
  publishRelease({
    walrusDataPackageId: PKG,
    kind: "Album",
    title: "LP",
    description: "desc",
    credits: [{ partyId: A, role: "Primary", displayName: "Artist" }],
    coverArt: { stillData: { blobId: "1" } },
    discs: [
      {
        tracks: [
          { compositionId: A, compositionShareType: `${PKG}::s::S`, recordingId: A, recordingAdminCapId: A, recordingShareType: `${PKG}::r::R`, splitBps: 10000 },
        ],
      },
    ],
    releaseRegistryId: A,
    releaseId: A,
    releaseNonce: "0",
    musicOsPackageId: PKG,
    partyOsPackageId: PKG,
    adminAddress: A,
  })(tx);

  const calls = moveCalls(tx);
  const has = (module: string, fn: string) => calls.some((c) => c.module === module && c.function === fn);
  expect(has("deal", "new")).toBe(true);
  expect(has("track", "new")).toBe(true);
  expect(has("disc", "new")).toBe(true);
  expect(has("release", "new")).toBe(true);
  expect(has("release", "add_credit")).toBe(true);
  expect(has("release", "publish")).toBe(true);
  // release::new takes (kind, title, description, cover_art, discs, nonce, registry)
  expect(calls.find((c) => c.module === "release" && c.function === "new")!.argCount).toBe(7);
});

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

test("createDeal wires deal::new (4 args, both share types) and transfers the deal", () => {
  const tx = new Transaction();
  createDeal({
    recordingId: A,
    recordingAdminCapId: A,
    recordingShareType: `${PKG}::r::R`,
    compositionShareType: `${PKG}::s::S`,
    releaseId: A,
    trackSplitBps: 5000,
    recipientAddress: A,
    musicOsPackageId: PKG,
  })(tx);

  const dealNew = moveCalls(tx).find((c) => c.module === "deal" && c.function === "new");
  expect(dealNew).toBeDefined();
  // (cap, recording, release_id, split)
  expect(dealNew!.argCount).toBe(4);
  // typeArguments order is [RecordingShare, CompositionShare]
  expect(dealNew!.typeArguments).toEqual([`${PKG}::r::R`, `${PKG}::s::S`]);
  expect(kinds(tx)).toContain("TransferObjects");
});

test("publishRelease wires deal -> track -> disc -> release::new -> set_subtitle -> publish", () => {
  const tx = new Transaction();
  publishRelease({
    title: "LP",
    subtitle: "Deluxe Edition",
    discs: [
      {
        tracks: [
          { recordingId: A, recordingAdminCapId: A, recordingShareType: `${PKG}::r::R`, compositionShareType: `${PKG}::s::S`, splitBps: 10000 },
        ],
      },
    ],
    releaseRegistryId: A,
    releaseId: A,
    releaseNonce: "0",
    musicOsPackageId: PKG,
    adminAddress: A,
  })(tx);

  const calls = moveCalls(tx);
  const has = (module: string, fn: string) => calls.some((c) => c.module === module && c.function === fn);
  expect(has("deal", "new")).toBe(true);
  expect(has("track", "new")).toBe(true);
  expect(has("disc", "new")).toBe(true);
  expect(has("release", "new")).toBe(true);
  expect(has("release", "set_subtitle")).toBe(true);
  expect(has("release", "publish")).toBe(true);
  // track::new now carries both share types
  expect(calls.find((c) => c.module === "track" && c.function === "new")!.typeArguments).toEqual([`${PKG}::r::R`, `${PKG}::s::S`]);
  // release::new takes (title, discs, nonce, registry)
  expect(calls.find((c) => c.module === "release" && c.function === "new")!.argCount).toBe(4);
});

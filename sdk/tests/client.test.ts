// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

// Verifies the client extension binds the miso/minato package ids into its `tx`
// and `call` namespaces, so callers don't repeat them (and `call` never falls back
// to the codegen '@local-pkg/miso' placeholder). Building the transactions is
// offline — no network.

import { test, expect } from "bun:test";
import { SuiGrpcClient } from "@mysten/sui/grpc";
import { Transaction } from "@mysten/sui/transactions";
import { miso } from "../src/client.ts";

const MISO = "0x" + "cd".repeat(32);
const MINATO = "0x" + "ef".repeat(32);
const SHARE = "0x" + "ab".repeat(32) + "::share::Share";
const A = "0x" + "11".repeat(32);

function client() {
  return new SuiGrpcClient({ network: "testnet", baseUrl: "https://fullnode.testnet.sui.io:443" }).$extend(
    miso({ misoPackageId: MISO, minatoPackageId: MINATO }),
  );
}

interface Call {
  package?: string;
  module: string;
  function: string;
}

function moveCalls(tx: Transaction): Call[] {
  const data = tx.getData() as { commands: { $kind: string; MoveCall?: Call }[] };
  return data.commands.filter((c) => c.$kind === "MoveCall" && c.MoveCall).map((c) => c.MoveCall!);
}

test("client.tx.publishComposition binds miso + minato package ids", () => {
  const tx = new Transaction();
  client().miso.tx.publishComposition({
    title: "T",
    royaltyRateBps: 1000,
    shareType: SHARE,
    shareCurrencyId: A,
    shareTreasuryCapId: A,
    shareRecipients: [{ address: A, value: 1 }],
    adminAddress: A,
  })(tx);

  const calls = moveCalls(tx);
  const compNew = calls.find((c) => c.module === "composition" && c.function === "new");
  expect(compNew?.package).toBe(MISO); // miso bound
  const disperse = calls.find((c) => c.module === "minato" && c.function === "disperse_balance");
  expect(disperse?.package).toBe(MINATO); // minato bound
});

test("client.call.composition._new defaults package to misoPackageId (not the codegen placeholder)", () => {
  const tx = new Transaction();
  client().miso.call.composition._new({
    typeArguments: [SHARE],
    arguments: [tx.pure.string("x"), tx.pure.u16(1000), tx.object(A), tx.object(A)],
  })(tx);

  const compNew = moveCalls(tx).find((c) => c.module === "composition" && c.function === "new");
  expect(compNew?.package).toBe(MISO);
});

test("client without minatoPackageId throws on share-dispersing builders, not on deal/release builders", () => {
  const noMinato = new SuiGrpcClient({ network: "testnet", baseUrl: "https://fullnode.testnet.sui.io:443" }).$extend(
    miso({ misoPackageId: MISO }),
  );

  expect(() =>
    noMinato.miso.tx.publishComposition({
      title: "T",
      royaltyRateBps: 1000,
      shareType: SHARE,
      shareCurrencyId: A,
      shareTreasuryCapId: A,
      shareRecipients: [{ address: A, value: 1 }],
      adminAddress: A,
    }),
  ).toThrow(/MisoClient: minatoPackageId is required/);

  // Builders that never disperse shares must keep working without minato.
  const tx = new Transaction();
  noMinato.miso.tx.createDeal({
    recordingId: A,
    recordingAdminCapId: A,
    recordingShareType: SHARE,
    compositionShareType: SHARE,
    releaseId: A,
    trackSplitBps: 5000,
    recipientAddress: A,
  })(tx);
  expect(moveCalls(tx).find((c) => c.module === "deal" && c.function === "new")?.package).toBe(MISO);
});

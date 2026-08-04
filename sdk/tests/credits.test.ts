// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

// Client-side validation in the credits writers: each check mirrors a Move
// abort in miso_credit::credit::new or the extensions' add_credit (display
// name non-empty and ≤200 UTF-8 BYTES; 1–5 composition roles; 1–10 recording
// roles; no duplicate roles by full identity). All offline — no network.

import { test, expect } from "bun:test";
import { Transaction } from "@mysten/sui/transactions";
import {
  addCompositionCredit,
  addRecordingCredit,
  addReleaseCredit,
  type AddCompositionCreditParams,
  type AddRecordingCreditParams,
  type AddReleaseCreditParams,
  type CompositionRole,
  type RecordingRole,
} from "../src/credits.ts";

const PKG = "0x" + "cd".repeat(32);
const A = "0x" + "ab".repeat(32);
const SHARE = `${PKG}::share::Share`;

function compositionParams(over: Partial<AddCompositionCreditParams> = {}): AddCompositionCreditParams {
  return {
    compositionId: A,
    compositionAdminCapId: A,
    partyId: A,
    displayName: "Writer",
    roles: [{ type: "Composer" }],
    compositionShareType: SHARE,
    compositionCreditsPackageId: PKG,
    misoCreditPackageId: PKG,
    ...over,
  };
}

function recordingParams(over: Partial<AddRecordingCreditParams> = {}): AddRecordingCreditParams {
  return {
    recordingId: A,
    recordingAdminCapId: A,
    partyId: A,
    displayName: "Artist",
    roles: [{ type: "Producer" }],
    recordingShareType: SHARE,
    compositionShareType: SHARE,
    recordingCreditsPackageId: PKG,
    misoCreditPackageId: PKG,
    ...over,
  };
}

function releaseParams(over: Partial<AddReleaseCreditParams> = {}): AddReleaseCreditParams {
  return {
    releaseId: A,
    releaseAdminCapId: A,
    partyId: A,
    displayName: "Artist",
    role: "Primary",
    releaseCreditsPackageId: PKG,
    misoCreditPackageId: PKG,
    ...over,
  };
}

// ── Display name (all three writers) ──────────────────────────────────────────

test("addCompositionCredit rejects an empty display name", () => {
  expect(() => addCompositionCredit(compositionParams({ displayName: "" }))).toThrow(/displayName must not be empty/);
});

test("addRecordingCredit rejects an empty display name", () => {
  expect(() => addRecordingCredit(recordingParams({ displayName: "" }))).toThrow(/displayName must not be empty/);
});

test("addReleaseCredit rejects an empty display name", () => {
  expect(() => addReleaseCredit(releaseParams({ displayName: "" }))).toThrow(/displayName must not be empty/);
});

test("display name limit counts UTF-8 BYTES, not code points", () => {
  // 67 × "あ" = 67 chars but 201 UTF-8 bytes — over the 200-byte Move limit.
  const multibyte = "あ".repeat(67);
  expect(() => addCompositionCredit(compositionParams({ displayName: multibyte }))).toThrow(/200 bytes.*got 201/);
  expect(() => addRecordingCredit(recordingParams({ displayName: multibyte }))).toThrow(/200 bytes/);
  expect(() => addReleaseCredit(releaseParams({ displayName: multibyte }))).toThrow(/200 bytes/);
  // 200 ASCII chars = 200 bytes — at the limit, allowed.
  expect(() => addCompositionCredit(compositionParams({ displayName: "a".repeat(200) }))).not.toThrow();
});

// ── Role counts ───────────────────────────────────────────────────────────────

test("addCompositionCredit rejects an empty roles list", () => {
  expect(() => addCompositionCredit(compositionParams({ roles: [] }))).toThrow(/at least one role/);
});

test("addRecordingCredit rejects an empty roles list", () => {
  expect(() => addRecordingCredit(recordingParams({ roles: [] }))).toThrow(/at least one role/);
});

test("addCompositionCredit rejects more than 5 roles", () => {
  const roles: CompositionRole[] = [
    { type: "Adapter" },
    { type: "Arranger" },
    { type: "Composer" },
    { type: "Lyricist" },
    { type: "Songwriter" },
    { type: "Translator" },
  ];
  expect(() => addCompositionCredit(compositionParams({ roles }))).toThrow(/at most 5 roles.*got 6/);
  expect(() => addCompositionCredit(compositionParams({ roles: roles.slice(0, 5) }))).not.toThrow();
});

test("addRecordingCredit rejects more than 10 roles", () => {
  const roles: RecordingRole[] = [
    { type: "Producer" },
    { type: "Vocalist" },
    { type: "Engineer" },
    { type: "Editor" },
    { type: "Conductor" },
    { type: "Narrator" },
    { type: "Orchestra" },
    { type: "Performer" },
    { type: "Programmer" },
    { type: "Soloist" },
    { type: "Speaker" },
  ];
  expect(() => addRecordingCredit(recordingParams({ roles }))).toThrow(/at most 10 roles.*got 11/);
  expect(() => addRecordingCredit(recordingParams({ roles: roles.slice(0, 10) }))).not.toThrow();
});

// ── Duplicate roles (full identity: type + instrument + name + level) ─────────

test("addCompositionCredit rejects duplicate canonical roles", () => {
  expect(() =>
    addCompositionCredit(compositionParams({ roles: [{ type: "Composer" }, { type: "Composer" }] })),
  ).toThrow(/duplicate role/);
});

test("addCompositionCredit rejects duplicate Custom roles by name, allows distinct names", () => {
  expect(() =>
    addCompositionCredit(
      compositionParams({ roles: [{ type: "Custom", name: "Beat Maker" }, { type: "Custom", name: "Beat Maker" }] }),
    ),
  ).toThrow(/duplicate role/);
  expect(() =>
    addCompositionCredit(
      compositionParams({ roles: [{ type: "Custom", name: "Beat Maker" }, { type: "Custom", name: "Topliner" }] }),
    ),
  ).not.toThrow();
});

test("addRecordingCredit rejects duplicate leveled roles, allows same type at different levels", () => {
  expect(() =>
    addRecordingCredit(
      recordingParams({ roles: [{ type: "Producer", level: "Lead" }, { type: "Producer", level: "Lead" }] }),
    ),
  ).toThrow(/duplicate role/);
  // Different level (or no level) is a different Move value — allowed on-chain.
  expect(() =>
    addRecordingCredit(recordingParams({ roles: [{ type: "Producer", level: "Lead" }, { type: "Producer" }] })),
  ).not.toThrow();
});

test("addRecordingCredit dedupes Instrumentalist by instrument + level", () => {
  expect(() =>
    addRecordingCredit(
      recordingParams({
        roles: [
          { type: "Instrumentalist", instrument: "Guitar" },
          { type: "Instrumentalist", instrument: "Guitar" },
        ],
      }),
    ),
  ).toThrow(/duplicate role/);
  expect(() =>
    addRecordingCredit(
      recordingParams({
        roles: [
          { type: "Instrumentalist", instrument: "Guitar" },
          { type: "Instrumentalist", instrument: "Bass" },
        ],
      }),
    ),
  ).not.toThrow();
});

// ── Valid params still build ──────────────────────────────────────────────────

test("valid credit writers build offline without throwing", () => {
  const tx = new Transaction();
  addCompositionCredit(compositionParams())(tx);
  addRecordingCredit(
    recordingParams({ roles: [{ type: "Vocalist", level: "Lead" }, { type: "Instrumentalist", instrument: "Guitar" }] }),
  )(tx);
  addReleaseCredit(releaseParams())(tx);
  const kinds = (tx.getData() as { commands: { $kind: string }[] }).commands.map((c) => c.$kind);
  expect(kinds).toContain("MoveCall");
});

// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

// The exported query helpers that are pure (no network): type-param extraction
// and missing-object detection.

import { test, expect } from "bun:test";
import { extractTypeParam, extractTypeParams2, isNotFound } from "../src/queries.ts";

const PKG = "0x" + "cd".repeat(32);

// ── extractTypeParam / extractTypeParams2 ─────────────────────────────────────

test("extractTypeParam pulls the single type parameter", () => {
  expect(extractTypeParam(`${PKG}::composition::Composition<${PKG}::share::Share>`)).toBe(`${PKG}::share::Share`);
  expect(() => extractTypeParam(`${PKG}::release::Release`)).toThrow(/Could not extract/);
});

test("extractTypeParams2 splits two top-level parameters, respecting nesting", () => {
  const [a, b] = extractTypeParams2(`${PKG}::deal::Deal<${PKG}::r::R, ${PKG}::c::C>`);
  expect(a).toBe(`${PKG}::r::R`);
  expect(b).toBe(`${PKG}::c::C`);

  // A nested generic in the first slot must not split at its inner comma.
  const [x, y] = extractTypeParams2(`${PKG}::t::T<${PKG}::w::W<${PKG}::a::A, ${PKG}::b::B>, ${PKG}::c::C>`);
  expect(x).toBe(`${PKG}::w::W<${PKG}::a::A, ${PKG}::b::B>`);
  expect(y).toBe(`${PKG}::c::C`);

  expect(() => extractTypeParams2(`${PKG}::composition::Composition<${PKG}::share::Share>`)).toThrow(
    /Expected two type parameters/,
  );
});

// ── isNotFound ────────────────────────────────────────────────────────────────

test("isNotFound matches structured ObjectError codes from the JSON-RPC/GraphQL clients", () => {
  const withCode = (code: string) => Object.assign(new Error("boom"), { code });
  expect(isNotFound(withCode("notExists"))).toBe(true);
  expect(isNotFound(withCode("deleted"))).toBe(true);
  expect(isNotFound(withCode("dynamicFieldNotFound"))).toBe(true);
  expect(isNotFound(withCode("notFound"))).toBe(true);
  expect(isNotFound(withCode("displayError"))).toBe(false);
});

test("isNotFound matches the missing-object message shapes of each transport", () => {
  expect(isNotFound(new Error(`Object ${PKG} does not exist`))).toBe(true); // JSON-RPC
  expect(isNotFound(new Error(`Object ${PKG} not found`))).toBe(true); // GraphQL / gRPC
  expect(isNotFound(new Error(`Object ${PKG} has been deleted`))).toBe(true); // JSON-RPC
  expect(isNotFound(new Error(`Dynamic field not found for object ${PKG}`))).toBe(true); // JSON-RPC
  expect(isNotFound(new Error(`No object found for id ${PKG}`))).toBe(true); // codegen MoveStruct.get
});

test("isNotFound does NOT match transport/protocol errors", () => {
  expect(isNotFound(new Error("Method not found"))).toBe(false); // JSON-RPC -32601
  expect(isNotFound(new Error("peer not found"))).toBe(false);
  expect(isNotFound(new Error("route not found"))).toBe(false);
  expect(isNotFound(new Error("fetch failed"))).toBe(false);
  expect(isNotFound("not found")).toBe(false); // bare phrase, no object context
});

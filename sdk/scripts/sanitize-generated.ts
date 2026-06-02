// Post-processes @mysten/codegen output to fix identifiers that are JavaScript
// strict-mode reserved words.
//
// codegen escapes ordinary keywords (e.g. it emits `new` -> `_new`), but its
// reserved-word list misses strict-mode reserved words such as `static`. When a
// Move function or parameter is named `static`, codegen emits it verbatim as a
// function declaration name and as a labeled-tuple element, both of which are TS
// syntax errors (TS1214). This script suffixes those two positions with `_`.
//
// It deliberately does NOT touch:
//   - BCS struct field keys (e.g. `static: walrus_data.WalrusData`) — those are
//     valid object property names AND must keep their spelling to match the
//     on-chain field layout for parsing.
//   - interface property names (`static: TransactionArgument;`) — valid TS, and
//     named-argument calls map by these keys via `normalizeMoveArguments`.
//
// Wired into the `codegen` npm script so it re-runs on every regeneration.
import { Glob } from "bun";

// Strict-mode reserved words that codegen leaves unescaped as identifiers.
const RESERVED = ["static"];

const glob = new Glob("src/contracts/**/*.ts");
let patched = 0;

for await (const file of glob.scan(".")) {
  const original = await Bun.file(file).text();
  let out = original;

  for (const rw of RESERVED) {
    // (a) function declaration name: `export function static(` -> `static_(`
    out = out.replaceAll(`export function ${rw}(`, `export function ${rw}_(`);

    // (b) labeled positional-tuple element (8-space indent, `: <Arg>` value,
    //     optional trailing comma). This is the only ambiguous-looking case, so
    //     we anchor on the TransactionArgument value + tuple indentation, which
    //     never matches the 4-space interface properties or BCS struct keys.
    out = out.replace(
      new RegExp(
        `^(\\s{8,})${rw}(\\??): ((?:Raw)?TransactionArgument(?:<[^>]*>)?)(,?)$`,
        "gm",
      ),
      `$1${rw}_$2: $3$4`,
    );
  }

  if (out !== original) {
    await Bun.write(file, out);
    patched++;
  }
}

console.log(`sanitize-generated: patched ${patched} file(s)`);

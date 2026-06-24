#!/usr/bin/env bash
#
# lint-plugins.sh — conformance lint for miso_vault plugins.
#
# For every plugin source under `move/extensions/*_ops/sources/*.move` it asserts
# the canonical shape required by docs/PLUGIN_STANDARD.md:
#
#   1. declares a `Key` witness struct           (`public struct Key`)
#   2. declares a `Config` struct                (`public struct Config`)
#   3. exposes an `install` function             (`fun install`)
#   4. every `vault::borrow_cap_plugin(...)` is paired with a
#      `vault::return_cap(...)` in the SAME function body (the borrowed cap is
#      always returned in-function, so the hot potato can never escape).
#
# Exits non-zero on the first violation found (after reporting all of them).
#
# CI WIRING: add a step to the Move CI workflow that runs this from the repo root,
# e.g. in `.github/workflows/*.yml`:
#
#     - name: Lint vault plugins
#       run: bash scripts/lint-plugins.sh
#
# It needs only bash + awk (no Sui toolchain), so it can run as a fast pre-build
# gate before `sui move build` / `sui move test`.

set -euo pipefail

# Resolve repo root from this script's location so it works from any CWD.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

EXT_DIR="$REPO_ROOT/move/extensions"

fail=0
checked=0

# Collect plugin sources: move/extensions/*_ops/sources/*.move
shopt -s nullglob
plugin_sources=("$EXT_DIR"/*_ops/sources/*.move)
shopt -u nullglob

if [ ${#plugin_sources[@]} -eq 0 ]; then
  echo "lint-plugins: no plugin sources found under $EXT_DIR/*_ops/sources/" >&2
  exit 1
fi

for src in "${plugin_sources[@]}"; do
  rel="${src#"$REPO_ROOT"/}"
  checked=$((checked + 1))
  file_ok=1

  # 1-3: required declarations. Match `public struct Key`, `public struct Config`,
  # and `fun install` (allowing `public fun install` / `public entry fun install`).
  if ! grep -Eq '(public[[:space:]]+)?struct[[:space:]]+Key\b' "$src"; then
    echo "FAIL $rel: missing 'struct Key' (the drop-only plugin witness)"
    file_ok=0
  fi
  if ! grep -Eq '(public[[:space:]]+)?struct[[:space:]]+Config\b' "$src"; then
    echo "FAIL $rel: missing 'struct Config'"
    file_ok=0
  fi
  if ! grep -Eq '\bfun[[:space:]]+install\b' "$src"; then
    echo "FAIL $rel: missing 'fun install'"
    file_ok=0
  fi

  # 4: per-function borrow/return pairing. Walk the file tracking brace depth;
  # whenever a `public fun` / `fun` / `entry fun` opens at top level (depth 0 -> 1),
  # start a new function scope and count `borrow_cap_plugin` vs `return_cap` until
  # the matching closing brace returns to depth 0. Report any imbalance.
  pairing_report="$(
    awk '
      function flush() {
        if (in_fn && borrows != returns) {
          printf("FAIL %s: function %s has %d borrow_cap_plugin but %d return_cap (must pair in the same function)\n", REL, fnname, borrows, returns)
          bad = 1
        }
      }
      BEGIN { depth = 0; in_fn = 0; bad = 0 }
      {
        # Strip `//` line comments so commented mentions of borrow_cap_plugin /
        # return_cap (and stray braces in comments) are not counted as code.
        line = $0
        sub(/\/\/.*/, "", line)

        # Detect a function header at top level (not already inside a function).
        if (!in_fn && depth == 0 && match(line, /(^|[[:space:]])fun[[:space:]]+[A-Za-z_][A-Za-z0-9_]*/)) {
          # Extract the function name after the `fun` keyword.
          tmp = line
          sub(/.*[[:space:]]fun[[:space:]]+/, "", tmp)
          sub(/^fun[[:space:]]+/, "", tmp)
          sub(/[^A-Za-z0-9_].*/, "", tmp)
          fnname = tmp
          in_fn = 1
          borrows = 0
          returns = 0
        }
        if (in_fn) {
          n = gsub(/borrow_cap_plugin/, "&", line); borrows += n
          n = gsub(/return_cap/, "&", line); returns += n
        }
        # Update brace depth using the comment-stripped line.
        opens = gsub(/{/, "{", line)
        closes = gsub(/}/, "}", line)
        depth += opens - closes
        if (in_fn && depth <= 0) {
          flush()
          in_fn = 0
          depth = 0
        }
      }
      END { exit bad }
    ' REL="$rel" "$src"
  )" || file_ok=0
  # Print any pairing violations (awk emits one FAIL line per offending function).
  [ -n "$pairing_report" ] && echo "$pairing_report"

  if [ "$file_ok" -eq 1 ]; then
    echo "ok   $rel"
  else
    fail=1
  fi
done

echo
if [ "$fail" -ne 0 ]; then
  echo "lint-plugins: FAILED ($checked plugin source(s) checked)"
  exit 1
fi
echo "lint-plugins: PASS ($checked plugin source(s) checked)"

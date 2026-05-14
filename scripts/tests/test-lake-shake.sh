#!/usr/bin/env bash
#
# scripts/tests/test-lake-shake.sh
#
# Smoke test for the pre-push.sh `lake shake` step. Verifies:
#
# 1. The specific flags we depend on are recognised by the
#    installed `lake shake` (flag-interface stability against
#    toolchain bumps).
# 2. lake shake actually flags an injected unused mathlib import
#    in the live project (semantic stability — catches the case
#    where flags exist but their behaviour changes).
#
# Exit 0 if all checks pass; exit non-zero with the failure
# count otherwise. The semantic positive case temporarily injects
# an unused `import` into `Geb/Cslib.lean` (a normally-clean
# file), rebuilds, runs shake, and restores. A trap guarantees
# restoration on any exit including signals; if anything in the
# setup fails for environmental reasons (rebuild fails, etc.)
# the positive case skips with a WARN rather than failing the
# whole test.

set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# --------- Part 1: flag-interface ---------

help_output=$(lake shake --help 2>&1)
help_exit=$?

if [[ "$help_exit" -ne 0 ]]; then
  echo "FAIL: 'lake shake --help' exited $help_exit" >&2
  echo "  output: $help_output" >&2
  exit 1
fi

failed=0
checked=0

assert_flag() {
  local flag="$1"
  checked=$((checked + 1))
  if grep -qF -- "$flag" <<<"$help_output"; then
    echo "PASS: $flag"
  else
    echo "FAIL: $flag not in 'lake shake --help' output" >&2
    failed=$((failed + 1))
  fi
}

assert_flag "--add-public"
assert_flag "--keep-implied"
assert_flag "--keep-prefix"

# --------- Part 2: semantic positive case ---------
#
# Inject an unused `import Mathlib.Algebra.Group.Basic` into
# `Geb/Cslib.lean`, rebuild, run shake, restore. The expected
# behaviour: shake exits non-zero and names the unused import.

positive_case() {
  local target="$repo_root/Geb/Cslib.lean"
  local backup
  if ! backup=$(mktemp 2>/dev/null); then
    echo "WARN: mktemp failed; semantic positive case skipped"
    return
  fi
  if [[ ! -f "$target" ]]; then
    echo "WARN: $target not found; semantic positive case skipped"
    rm -f "$backup"
    return
  fi
  cp "$target" "$backup"

  # Restoration guaranteed on any function exit, including signals.
  # shellcheck disable=SC2064
  trap "cp '$backup' '$target' 2>/dev/null; rm -f '$backup'" RETURN

  # Inject the unused import on the line after `^module`. Rebuild
  # `Geb` (not just `Geb.Cslib`) so the parent root module's
  # olean is fresh relative to the modified subindex; otherwise
  # shake's olean-staleness sanity check would short-circuit.
  sed -i '/^module$/a import Mathlib.Algebra.Group.Basic' "$target"

  if ! (cd "$repo_root" && lake build Geb >/dev/null 2>&1); then
    echo "WARN: rebuild of Geb failed; semantic positive case skipped"
    return
  fi

  local shake_output shake_exit
  shake_output=$(cd "$repo_root" \
    && lake shake --add-public --keep-implied --keep-prefix Geb 2>&1)
  shake_exit=$?

  checked=$((checked + 1))
  if [[ "$shake_exit" -ne 0 ]] \
     && grep -qF "Mathlib.Algebra.Group.Basic" <<<"$shake_output"; then
    echo "PASS: lake shake detected injected unused import"
  else
    echo "FAIL: lake shake did NOT detect injected unused import" >&2
    echo "  exit: $shake_exit" >&2
    echo "  output: '$shake_output'" >&2
    failed=$((failed + 1))
  fi
}

positive_case

# Rebuild Geb once more after restoration so olean state matches
# the (restored) source for any downstream consumer of the
# pre-push run.
(cd "$repo_root" && lake build Geb >/dev/null 2>&1) || true

echo ""
echo "test-lake-shake.sh: $checked check(s) ran, $failed failure(s)"
exit "$failed"

#!/usr/bin/env bash
#
# scripts/lint-imports.sh
#
# Floodgate-CI per-branch import-rule linter.
#
# Each upstream-eligible subtree has an allowed-import list and a
# self-prefix that must not appear outside import lines. Files in
# Geb/Cslib/ (and tests) additionally must import `Cslib.Init` per
# CSLib's `checkInitImports` requirement. Every upstream-eligible
# `.lean` file must use Lean 4's module system (start with the
# `module` keyword), since `lake shake` minimised-imports
# enforcement only operates on module-form files.
#
#   Geb/Mathlib/, GebTests/Mathlib/  →  Mathlib.*, Geb.Mathlib.*
#   Geb/Cslib/,   GebTests/Cslib/    →  Mathlib.*, Cslib.*, Geb.Cslib.*
#                                       (plus mandatory `import Cslib.Init`)
#
# Bare umbrella imports (`import Mathlib`, `import Cslib`,
# whether plain or `public import` form) are forbidden in
# upstream-eligible files: extraction requires specific module
# imports.
#
# `public import` lines are recognised the same as plain `import`
# (the same allowed-prefix and forbidden-umbrella rules apply,
# and they count as import lines for the no-prefix-leakage rule).
#
# Exit 0 on clean. Exit 1 on any violation.

set -euo pipefail

errors=0
total=0

# check_subtree <leakage-prefix> <required-init> <find-root>... -- <allowed-prefix>...
#
# <required-init> is the module path of an init file every file
# in this subtree must import (e.g., "Cslib.Init"), or "" for
# subtrees with no such requirement.
check_subtree() {
  local leakage_prefix="$1"; shift
  local required_init="$1"; shift
  local find_roots=()
  while [[ "$1" != "--" ]]; do
    find_roots+=("$1"); shift
  done
  shift                      # drop --
  local allowed_prefixes=("$@")

  local allowed_str=""
  local p
  for p in "${allowed_prefixes[@]}"; do
    allowed_str+="${p}*, "
  done
  allowed_str="${allowed_str%, }"

  local files
  mapfile -t files < <(find "${find_roots[@]}" -type f -name '*.lean' 2>/dev/null || true)

  local f line canonical ok ln
  local prefix_re="${leakage_prefix//./\\.}"
  for f in "${files[@]}"; do
    total=$((total + 1))

    # Rule 0: module-form requirement. Every upstream-eligible
    # `.lean` file starts with the `module` keyword. Files that
    # omit it cannot participate in lake shake's minimised-imports
    # check (and aren't extractable to either upstream).
    if ! grep -qE '^module([[:space:]]|$|--)' "$f"; then
      echo "$f: missing 'module' header (required for upstream extractability and lake shake)" >&2
      errors=$((errors + 1))
    fi

    # Rule 1: imports. `public import` is canonicalised to
    # `import` before pattern matching; rules apply identically
    # to both forms.
    while IFS= read -r line; do
      case "$line" in
        'public import '*) canonical="${line#public }" ;;
        *) canonical="$line" ;;
      esac
      case "$canonical" in
        'import Mathlib'|'import Cslib')
          echo "$f: bare umbrella '$line' is forbidden in upstream-eligible files" >&2
          errors=$((errors + 1))
          continue
          ;;
      esac
      ok=0
      for p in "${allowed_prefixes[@]}"; do
        if [[ "$canonical" == "import ${p}"* ]]; then
          ok=1
          break
        fi
      done
      if [[ "$ok" -eq 0 ]]; then
        echo "$f: forbidden import '$line' (allowed: $allowed_str)" >&2
        errors=$((errors + 1))
      fi
    done < <(grep -E '^(public[[:space:]]+)?import ' "$f" || true)

    # Rule 1b: required init import. When the subtree mandates a
    # specific init module (e.g., CSLib's Cslib.Init), every file
    # imports it directly. Transitive satisfaction is not checked
    # here; CSLib's own `checkInitImports` performs the
    # post-extraction verification.
    if [[ -n "$required_init" ]]; then
      if ! grep -qE "^(public[[:space:]]+)?import ${required_init//./\\.}([[:space:]]|$)" "$f"; then
        echo "$f: missing required 'import $required_init'" >&2
        errors=$((errors + 1))
      fi
    fi

    # Rule 2: no-prefix-leakage. `public import` lines count as
    # imports for the exclusion regex.
    if grep -nE "\\b${prefix_re}" "$f" | grep -vE '^[0-9]+:(public[[:space:]]+)?import ' >/dev/null; then
      grep -nE "\\b${prefix_re}" "$f" | grep -vE '^[0-9]+:(public[[:space:]]+)?import ' | while IFS= read -r ln; do
        echo "$f:$ln: '${leakage_prefix}' outside ^import line" >&2
      done
      errors=$((errors + 1))
    fi
  done
}

check_subtree "Geb.Mathlib." "" Geb/Mathlib GebTests/Mathlib -- "Mathlib." "Geb.Mathlib."
check_subtree "Geb.Cslib." "Cslib.Init" Geb/Cslib GebTests/Cslib -- "Mathlib." "Cslib." "Geb.Cslib."

if [ "$errors" -gt 0 ]; then
  echo "lint-imports.sh: $errors violation(s) found" >&2
  exit 1
fi

echo "lint-imports.sh: clean ($total file(s) checked)"
exit 0

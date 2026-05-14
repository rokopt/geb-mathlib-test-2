#!/usr/bin/env bash
#
# scripts/extract-pr.sh
#
# Path 1 PR extraction. Given an upstream-eligible source path
# under `Geb/Mathlib/`, `GebTests/Mathlib/`, `Geb/Cslib/`, or
# `GebTests/Cslib/`, and a target upstream-fork worktree path,
# copy the file with `Geb.<Subtree>.` rewritten to `<Subtree>.`
# in import lines.
#
# Usage:
#   scripts/extract-pr.sh <src-path> <upstream-fork-root>
#
# Examples:
#   scripts/extract-pr.sh Geb/Mathlib/Foo/Bar.lean ../mathlib4-fork
#   # writes ../mathlib4-fork/Mathlib/Foo/Bar.lean with
#   # `Geb.Mathlib.` rewritten to `Mathlib.`
#
#   scripts/extract-pr.sh Geb/Cslib/Foo/Bar.lean ../cslib-fork
#   # writes ../cslib-fork/Cslib/Foo/Bar.lean with
#   # `Geb.Cslib.` rewritten to `Cslib.`
#
# Test-directory layouts (verified per upstream):
#   mathlib4: source under Mathlib/, tests under MathlibTest/
#     (singular; renamed from `test/` historically).
#   CSLib:    source under Cslib/, tests under CslibTests/
#     (plural; per CSLib's CONTRIBUTING.md).
# Re-verify before extracting the first real PR for each upstream;
# directory names could change.

set -euo pipefail

if [ $# -ne 2 ]; then
  echo "Usage: $0 <src-path> <upstream-fork-root>" >&2
  exit 1
fi

src="$1"
fork="$2"

if [ ! -f "$src" ]; then
  echo "extract-pr.sh: source file not found: $src" >&2
  exit 1
fi

if [ ! -d "$fork" ]; then
  echo "extract-pr.sh: upstream fork directory not found: $fork" >&2
  exit 1
fi

# Map source path to destination path; pick rewrite prefixes.
case "$src" in
  Geb/Mathlib/*)
    dst_rel="Mathlib/${src#Geb/Mathlib/}"
    rewrite_prefix='Geb\.Mathlib\.'
    target_prefix='Mathlib.'
    ;;
  GebTests/Mathlib/*)
    dst_rel="MathlibTest/${src#GebTests/Mathlib/}"
    rewrite_prefix='Geb\.Mathlib\.'
    target_prefix='Mathlib.'
    ;;
  Geb/Cslib/*)
    dst_rel="Cslib/${src#Geb/Cslib/}"
    rewrite_prefix='Geb\.Cslib\.'
    target_prefix='Cslib.'
    ;;
  GebTests/Cslib/*)
    dst_rel="CslibTests/${src#GebTests/Cslib/}"
    rewrite_prefix='Geb\.Cslib\.'
    target_prefix='Cslib.'
    ;;
  *)
    echo "extract-pr.sh: source path must be under Geb/Mathlib/, GebTests/Mathlib/, Geb/Cslib/, or GebTests/Cslib/" >&2
    exit 1
    ;;
esac

dst="$fork/$dst_rel"

mkdir -p "$(dirname "$dst")"

# Copy + rewrite. \b ensures we don't match Geb.MathlibFoo or
# Geb.CslibFoo accidentally; global within-line replacement (not
# anchored to import) so any in-file reference is rewritten —
# relying on the no-prefix-leakage rule (lint-imports.sh) ensuring
# only import-line occurrences exist.
sed -E "s/\\b${rewrite_prefix}/${target_prefix}/g" "$src" > "$dst"

echo "extract-pr.sh: $src -> $dst"

#!/usr/bin/env bash
#
# scripts/toolchain-watch.sh
#
# SessionStart hook: compares our lean-toolchain to mathlib master's
# and prints a one-line status. Exits 0 either way (never blocks
# session startup).

set -euo pipefail

# Skip if no toolchain file (e.g., session opened in a sibling dir)
if [ ! -f lean-toolchain ]; then
  echo "toolchain-watch: no lean-toolchain in cwd; skipping" >&2
  exit 0
fi

ours=$(tr -d '[:space:]' < lean-toolchain)

# Try to fetch mathlib master's toolchain; on failure, exit silently.
# The URL is overridable via TOOLCHAIN_WATCH_URL so tests can point
# the script at an unreachable address (RFC 5737 TEST-NET-1
# 192.0.2.0/24) without manipulating the machine's networking.
mathlib_url="${TOOLCHAIN_WATCH_URL:-https://raw.githubusercontent.com/leanprover-community/mathlib4/master/lean-toolchain}"
if ! theirs=$(curl --max-time 5 -fsSL "$mathlib_url" 2>/dev/null); then
  echo "toolchain-watch: could not reach mathlib master (offline?); skipping" >&2
  exit 0
fi
theirs=$(echo "$theirs" | tr -d '[:space:]')

if [ "$ours" = "$theirs" ]; then
  echo "toolchain-watch: in sync (${ours#leanprover/lean4:})"
else
  echo "toolchain-watch: behind — ours=${ours#leanprover/lean4:}, mathlib=${theirs#leanprover/lean4:}. Run lake update on a bump/* branch."
fi

exit 0

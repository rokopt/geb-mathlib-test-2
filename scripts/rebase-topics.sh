#!/usr/bin/env bash
#
# scripts/rebase-topics.sh
#
# Mass-rebase active topic branches onto the named base (typically
# `main` after a bump-PR merge).
#
# Usage:
#   scripts/rebase-topics.sh <new-base>
#
# Example:
#   scripts/rebase-topics.sh main

set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <new-base>" >&2
  exit 1
fi

new_base="$1"

# shellcheck source=scripts/lib/topic-revset.sh
. "$(dirname "$0")/lib/topic-revset.sh"

# Rebase the roots of all active topic-branch bookmarks onto the
# new base. `roots(...)` selects the earliest commit on each branch
# that's not already in the new base; `-s` rebases that commit and
# its descendants.
jj rebase -d "$new_base" -s "
  roots(
    ($TOPIC_BOOKMARKS_REVSET) ~ ::$new_base
  )"

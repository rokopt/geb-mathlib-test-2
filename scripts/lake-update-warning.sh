#!/usr/bin/env bash
#
# scripts/lake-update-warning.sh
#
# Print a warning when lake-manifest.json is modified outside a
# bump/* or chore/bootstrap branch. Intended for use in the
# pre-push checklist.
#
# Exit 0 always (informational only).

set -euo pipefail

if ! command -v jj >/dev/null 2>&1; then
  exit 0
fi

# Get current bookmark(s) one per line; trim each, then exact-prefix
# match against allowed forms.
allowed=0
while IFS= read -r bm; do
  case "$bm" in
    bump/*|chore/bootstrap)
      allowed=1
      break
      ;;
  esac
done < <(jj log -r @ -T 'bookmarks ++ "\n"' --no-graph 2>/dev/null \
         | tr ',' '\n' | sed 's/[[:space:]]*$//' | sed 's/^[[:space:]]*//')

if [ "$allowed" -eq 0 ]; then
  # Use `latest_common_ancestor(main, @)` which is the documented
  # jj revset form (jj 0.41+: confirm against
  # `https://docs.jj-vcs.dev/latest/revsets/` § "Revset functions"
  # at execute-time; if the function is renamed in a future jj,
  # adjust this script and `pre-push.sh` together). Falls back to
  # `main..@` if the function is unavailable in the active jj.
  if changed=$(jj diff --name-only -r 'latest_common_ancestor(main, @)..@' 2>/dev/null) \
       || changed=$(jj diff --name-only -r 'main..@' 2>/dev/null); then
    if echo "$changed" | grep -q '^lake-manifest.json$'; then
      echo "lake-update-warning: lake-manifest.json modified outside bump/* or chore/bootstrap branch" >&2
      echo "  Consider creating a bump/<lean-version> branch for mathlib SHA changes." >&2
    fi
  fi
fi

exit 0

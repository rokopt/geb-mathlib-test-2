#!/usr/bin/env bash
#
# scripts/pre-push.sh
#
# Run the pre-push checklist before any push to a remote. Exits
# non-zero on any failure; the user must explicitly authorise the
# push after a clean run.

set -euo pipefail

step() {
  echo "==> $*"
}

step "lake build"
lake build

step "lake test"
lake test

step "lake lint"
lake lint

# `lake shake` requires built oleans for every library it scans.
# `lake build` alone honours `defaultTargets` (Geb only), so build
# `GebTests` explicitly here.
step "lake build GebTests (prerequisite for lake shake)"
lake build GebTests

step "lake shake (minimised imports)"
lake shake --add-public --keep-implied --keep-prefix Geb GebTests

step "scripts/tests/test-lake-shake.sh"
bash scripts/tests/test-lake-shake.sh

step "scripts/lint-imports.sh"
bash scripts/lint-imports.sh

step "scripts/tests/test-lint-imports.sh"
bash scripts/tests/test-lint-imports.sh

step "scripts/hooks/tests/test-block-mutating-git.sh"
bash scripts/hooks/tests/test-block-mutating-git.sh

step "doctoc --check '**/*.md'"
if command -v doctoc >/dev/null 2>&1; then
  doctoc --check '**/*.md' \
    || { echo "doctoc TOCs out of date; run 'doctoc \"**/*.md\"' and re-commit." >&2; exit 1; }
else
  echo "doctoc not installed; skipping TOC check." >&2
fi

step "markdownlint-cli2 '**/*.md'"
markdownlint-cli2 '**/*.md'

step "scripts/check-axioms.sh"
bash scripts/check-axioms.sh Geb/ GebTests/

step "scripts/lake-update-warning.sh"
bash scripts/lake-update-warning.sh

step "docs-coverage check (concept docs in same branch)"
# Per spec § "Concept docs in same branch": any new concept added to
# source code must be documented in docs/index.md in the same branch.
# Stub implementation: surface a reminder when .lean files in
# Geb/Mathlib/, Geb/Cslib/, or Geb/Internal/ change without
# docs/index.md being touched in the same branch's diff. A full
# implementation would parse new top-level declarations and check
# docs/index.md mentions them; deferred to a future upgrade.
#
# Helper: get the diff against the merge-base with main, with a
# fallback for jj versions lacking `latest_common_ancestor`.
diff_against_main() {
  jj diff --name-only -r 'latest_common_ancestor(main, @)..@' 2>/dev/null \
    || jj diff --name-only -r 'main..@' 2>/dev/null \
    || true
}

if diff_against_main | grep -qE '^(Geb/Mathlib|Geb/Cslib|Geb/Internal)/.*\.lean$'; then
  if ! diff_against_main | grep -q '^docs/index.md$'; then
    echo "" >&2
    echo "REMINDER (docs-coverage):" >&2
    echo "  Lean files under Geb/Mathlib/, Geb/Cslib/, or" >&2
    echo "  Geb/Internal/ changed, but docs/index.md was not" >&2
    echo "  touched. Verify each new concept is reflected in" >&2
    echo "  docs/index.md." >&2
    echo "  Type 'yes' to acknowledge, anything else to abort:" >&2
    read -r ack
    [ "$ack" = "yes" ] || { echo "pre-push: aborted" >&2; exit 1; }
  fi
fi

# PR-candidate reminder: triggers on feat/, fix/, refactor/, migrate/
# bookmarks of @, with exact-prefix matching (per-bookmark loop) so
# names like `chore/feat-tooling` do not spuriously match.
is_pr_candidate=0
while IFS= read -r bm; do
  case "$bm" in
    feat/*|fix/*|refactor/*|migrate/*) is_pr_candidate=1; break ;;
  esac
done < <(jj log -r @ -T 'bookmarks ++ "\n"' --no-graph 2>/dev/null \
         | tr ',' '\n' | sed 's/[[:space:]]*$//' | sed 's/^[[:space:]]*//')

if [ "$is_pr_candidate" -eq 1 ]; then
  cat >&2 <<'EOF'

REMINDER (PR-candidate branch detected):

- PR descriptions, Zulip messages, and GitHub issue/PR comments
  must be authored by the user, not by an AI agent. (Mathlib's
  LLM policy: "use your own words.")
- The user must review the diff line-by-line before any push.

Type "yes" to confirm acknowledgement, anything else to abort:
EOF
  read -r confirm
  [ "$confirm" = "yes" ] || { echo "pre-push: aborted by user" >&2; exit 1; }
fi

# Lean-content reminder (informational; does not prompt).
if diff_against_main | grep -qE '\.lean$'; then
  echo "" >&2
  echo "REMINDER (Lean content changed):" >&2
  echo "  - Run lean4:golf on changed proofs (polish step)." >&2
  echo "  - Run lean4:review on the diff." >&2
  echo "  - For PR-candidate branches, run pr-review-toolkit:review-pr." >&2
fi

echo "pre-push: clean. The user must still review the diff line-by-line and authorise the push."

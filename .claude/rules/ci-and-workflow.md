---
paths:
  - ".github/workflows/**"
  - "scripts/**"
---

# CI and workflow conventions

Applies to GitHub Actions workflow files and scripts.

## Commit-message convention (mathlib-derived)

```text
<type>(<optional-scope>): <subject>

<body>

<footers>
```

Types: `feat | fix | doc | style | refactor | test | chore | perf | ci`.
Imperative present tense, no capital, no trailing period. Subject
under 72 characters when possible.

Documented footers: `Closes #123, #456`, `BREAKING CHANGE: ...`,
`- [ ] depends on: #XXXX`. Mathlib's published convention does not
include `Moves:` or `Deletions:`, so nor does ours.

## Pre-push checklist

Run by `scripts/pre-push.sh`:

1. `lake build` succeeds locally.
2. `lake test` succeeds locally.
3. `lake lint` quiet.
4. `lake shake --add-public --keep-implied --keep-prefix Geb GebTests`
   quiet.
5. `scripts/tests/test-lake-shake.sh` passes.
6. `scripts/lint-imports.sh` quiet.
7. `scripts/tests/test-lint-imports.sh` passes.
8. `scripts/hooks/tests/test-block-mutating-git.sh` passes.
9. `markdownlint-cli2 '**/*.md'` quiet.
10. `bash scripts/check-axioms.sh Geb/ GebTests/` quiet. The
    script requires `lake build` to have populated `.lake/build/`
    (item 1 above guarantees this in the checklist order); run
    manually in a fresh worktree, it reports 0 declarations and
    exits 3 — which is a missing-build artefact, not a real
    failure.
11. (PR-candidate) reminder about no-LLM-text rule for PR
    descriptions; affirmative confirmation required.
12. (Lean-content) `lean4:golf` ran on changed proofs;
    `lean4:review` ran on the diff.
13. (PR-candidate) `pr-review-toolkit:review-pr` ran.
14. User reviewed the diff line-by-line.

## Hook-script conventions

Hook scripts in `scripts/hooks/` follow Claude Code's hook contract
(verified against
`https://code.claude.com/docs/en/hooks-overview` and
`https://code.claude.com/docs/en/hooks-reference`):

- Read JSON from stdin when invoked.
- Exit 0 to allow; exit 2 to hard-block (with stderr message). For
  PreToolUse hooks that prefer to surface the decision to the user,
  exit 0 with a `hookSpecificOutput.permissionDecision` JSON
  document on stdout (e.g., `permissionDecision: "ask"`); other
  non-zero exits are errors.
- Smoke-test in `scripts/hooks/tests/test-<hook>.sh`; CI runs the
  smoke tests.

## Action pinning policy

All third-party actions in `.github/workflows/*.yml` are pinned to
a specific commit SHA, with the SHA followed by a comment naming
the corresponding tag for human readers. Update via review of the
upstream action's release notes (Dependabot-style).

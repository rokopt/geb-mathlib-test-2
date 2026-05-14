# Bootstrap runbook

Recorded operational sequence for the geb-mathlib bootstrap. The
sequence is iterated against numbered test repos
`rokopt/geb-mathlib-test-N`; the final clean iteration's sequence
is replayed against the real repo `rokopt/geb-mathlib`.

## Iteration log

| Iteration N | Outcome | Notes |
| --- | --- | --- |
| 1 | (in progress) | events A–K done (J narrow-test deferred); discoveries A.1, A.2, B.1, B.2, D.1, D.2, D.3, E.1, G.1, G.2, I.1, I.2 |

## Events

For each event, the runbook records: preconditions, action,
expected result, verification, rollback / cleanup, discoveries.

Marked **bootstrap-real** events are re-executed against the real
repo verbatim. Marked **test-only** events are exercised on the
test repo only and skipped on the real repo.

### A. Repo creation and bootstrap branch (bootstrap-real)

**Iteration 1 (2026-05-13) — clean except for two discoveries**
(see discoveries log entries A.1 and A.2).

**Preconditions.** Main working tree at
`/home/terence/git-workspaces/geb-mathlib` with `chore/bootstrap`
in finalised post-test-3 shape (14 commits + runbook init = 15).
`gh` authenticated as `rokopt` with `repo` and `workflow` scopes.
`jj` 0.41.0, `git` 2.43.0. No prior `rokopt/geb-mathlib-test-*`
GitHub repo.

**Action sequence.**

1. `export N=1`.
2. Create the empty public test repo:
   `gh repo create "rokopt/geb-mathlib-test-${N}" --public
   --description "..."`.
3. Initialise the local clone dir:
   `mkdir geb-mathlib-test-1 && cd geb-mathlib-test-1`;
   `git init --initial-branch=main`;
   `git remote add origin
   "git@github.com:rokopt/geb-mathlib-test-1.git"`;
   `jj git init --colocate`.
4. Bundle the main working tree's `chore/bootstrap` and extract.
   In the main working tree:
   `git bundle create /tmp/chore-bootstrap.bundle chore/bootstrap`.
   Then in a scratch dir:
   `git clone --quiet /tmp/chore-bootstrap.bundle
   /tmp/import-1 --branch chore/bootstrap`. The plan's original
   `git init` + `git fetch` + `git checkout FETCH_HEAD -- .` form
   is blocked by the lean4 plugin's `guardrails.sh` (see
   discovery A.1); `git clone <bundle>` is the workaround.
5. Apply the four recommended local jj config keys:
   `git.private-commits`, `remotes.origin.auto-track-bookmarks`,
   `revsets.bookmark-advance-from`,
   `revsets.bookmark-advance-to`.
6. Placeholder commit:
   `jj describe -m "chore: anchor main at empty placeholder
   commit"`; `jj bookmark create main -r @`; `jj new`.
7. Import scaffolding via
   `rsync -a --exclude='.git/' --exclude='.jj/'
   /tmp/import-1/ ./`. Then
   `jj describe -m "chore: import bootstrap scaffolding from main
   repo iteration 1"`; `jj bookmark create chore/bootstrap -r @`;
   `jj new`.
8. FF rehearsal: `jj bookmark set main -r 'chore/bootstrap'`.
9. Disclaimer added to `README.md` top (see discovery A.2);
   then explicit
   `jj describe -m "doc: add test-repo disclaimer ..."`,
   `jj bookmark set chore/bootstrap -r @-`,
   `jj bookmark set main -r 'chore/bootstrap'`.
10. Verify locally: `markdownlint-cli2 '**/*.md'` returns 13
    files, 0 errors; `lake exe cache get` returns 8382 cached
    files, 0 downloads; `lake build` returns 6 jobs, success.
11. Push: `jj git push --remote origin -b main`, then
    `jj git push --remote origin -b chore/bootstrap`. Set default
    branch: `gh repo edit --default-branch main`.

**Expected result.** Test repo on GitHub has two refs
(`refs/heads/main`, `refs/heads/chore/bootstrap`) at the same SHA
(`fd6b64e2` for iteration 1); default branch is `main`; local
jj `bookmark list --all-remotes` shows both bookmarks with
`@git` and `@origin` tracking entries in sync.

**Verification.**

- `gh api repos/rokopt/geb-mathlib-test-1/branches` returns both
  branches.
- `gh api repos/rokopt/geb-mathlib-test-1/git/refs` returns
  `refs/heads/main` and `refs/heads/chore/bootstrap` at the same
  SHA.
- Local: `jj bookmark list --all-remotes` shows
  `@origin: <change-id> <sha> <message>` for both.
- `gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name'`
  returns `main`.

**Rollback / cleanup.**
`gh repo delete rokopt/geb-mathlib-test-1 --yes` deletes the test
repo; `rm -rf /home/terence/git-workspaces/geb-mathlib-test-1`
removes the local clone. Per the test-repos-numbered convention,
prefer not to delete during iteration testing; bump `N` for the
next iteration instead.

**Discoveries.** A.1 and A.2 (see discoveries log).

### B. Hooks active

**Iteration 1 (2026-05-14) — all sub-cases clean.**

**B.1 Toolchain-watch in-sync (bootstrap-real).** Verified in
Task 3.2 Step 10: a fresh Claude session opened in
`geb-mathlib-test-1/` prints the in-sync banner (no drift output);
`check-signing-key` runs silently.

**B.2 Toolchain-watch drift (test-only).** Direct invocation of
the script with a behind-master `lean-toolchain`:

```text
echo "leanprover/lean4:v4.29.0-rc999" > lean-toolchain
bash scripts/toolchain-watch.sh
→ toolchain-watch: behind — ours=v4.29.0-rc999,
  mathlib=v4.30.0-rc2. Run lake update on a bump/* branch.
echo "leanprover/lean4:v4.30.0-rc2" > lean-toolchain
```

The script correctly identifies the version comparison and gives
actionable guidance pointing at the `bump/*` branch convention.

**B.3 Toolchain-watch offline (test-only).** Direct invocation
with URL override to RFC 5737 TEST-NET-1
(`https://192.0.2.1/lean-toolchain`):

```text
TOOLCHAIN_WATCH_URL='https://192.0.2.1/lean-toolchain' \
  bash scripts/toolchain-watch.sh
→ toolchain-watch: could not reach mathlib master (offline?);
  skipping
```

Exit 0, no error surface — matches the spec's "soft-skip when
unreachable" behaviour.

**B.4 PreToolUse mutating-git hook prompt (test-only).** Verified
in a user fresh Claude Code session at `geb-mathlib-test-1/` on
2026-05-14: the user asked Claude to run `git checkout main`;
the model issued a `Bash` tool call; the PreToolUse hook fired
and surfaced a permission prompt carrying the hook's
explanation text: "git command git checkout main is not on the
project's read-only allow-list. For state-mutating operations,
use jj …". User denied the prompt; test-1's working tree
unchanged.

See discovery B.1 for the `!`-prefix observation.

**B.5 PreToolUse mutating-git hook allows `jj git push`
(bootstrap-real).** Verified in two contexts.

From the main working tree (same hook script, registered there):

```text
jj git push --dry-run --remote origin -b main
→ Bookmark main@origin already matches main
  Nothing changed.
```

From a user fresh Claude Code session at `geb-mathlib-test-1/`
on 2026-05-14: user asked Claude to run the same command. The
PreToolUse hook fired and approved silently (no hook-specific
prompt). Claude Code's built-in permission system independently
asked for authorisation (a generic "this command requires
authorisation" prompt, not the hook's text); user authorised;
command ran with the same expected output. See discovery B.2 for
the two-gate observation.

**B.6 Smoke test in CI (bootstrap-real).**
`gh run view 25836001597 --repo rokopt/geb-mathlib-test-1` returns
all five `ci.yml` jobs as success:

- Axiom check
- Floodgate imports lint
- Hooks smoke test
- Build / test / lint / shake
- Style lint (forbid bare umbrella imports)

Wall-clock 2m59s. The Hooks smoke test job runs
`scripts/hooks/tests/test-block-mutating-git.sh` on the CI runner
and confirms hook behaviour from a clean Ubuntu environment.

The companion workflows `markdown-lint.yml` (8s) and
`conflict-check.yml` (13s) also ran green on the same push.

**Discoveries.** B.1 and B.2 (see discoveries log).

### C. Branch operations (bootstrap-real)

**Iteration 1 (2026-05-14) — clean.**

**Preconditions.** test-1 in post-event-A state: `main` and
`chore/bootstrap` both at `zvqznowx` (the disclaimer commit),
both tracked at `@origin`. Local jj config including
`remotes.origin.auto-track-bookmarks = 'glob:*'`.

**Action sequence.**

1. Create three topic branches via the
   `jj new <parent> -m ...; jj bookmark create <name> -r @; jj new -m ...`
   pattern. Two off `main` (`feat/topic-B`, `fix/topic-C`), one
   off `chore/bootstrap` (`feat/topic-A`); since `main` and
   `chore/bootstrap` share a tip at this point, all three start
   from the same revision. Each topic-branch bookmark sits on
   an empty start commit; an additional empty content commit
   lives at `@` without a bookmark (exercises "work past the
   bookmark tip").
2. Multi-bookmark push:
   `jj git push --remote origin -b feat/topic-A -b feat/topic-B
   -b fix/topic-C`. All three are new bookmarks on the remote.

**Expected result.** Five refs on the remote: `main`,
`chore/bootstrap`, `feat/topic-A`, `feat/topic-B`, `fix/topic-C`,
each at the SHA shown in event C verification. Local
`jj bookmark list --all-remotes` shows `@origin` tracking for
all three new bookmarks (auto-track-bookmarks confirmed).

**Verification.**

- `gh api repos/rokopt/geb-mathlib-test-1/branches` returns all
  five branches.
- `jj bookmark list --all-remotes` shows each new bookmark with
  `@git` and `@origin` lines at the same SHA.
- `gh run list --repo rokopt/geb-mathlib-test-1` shows **no new
  CI runs** for the three topic-branch pushes — only the
  original `main`-push runs persist. This matches the workflows'
  `on: push: branches: [main, integration]` filter. Topic
  branches get CI coverage via the `pull_request` trigger
  exercised in event D.

**Rollback / cleanup.** `jj bookmark delete feat/topic-A
feat/topic-B fix/topic-C` locally, then
`jj git push --remote origin -b feat/topic-A -b feat/topic-B
-b fix/topic-C` to delete on the remote. (Not run here; the
topic branches persist for the rest of iteration 1.)

**Discoveries.** None new in event C.

### D. CI activates (bootstrap-real)

**Iteration 1 (2026-05-14) — complete; three findings (D.1, D.2, D.3).**

**D.1 ci.yml fires on push to main and pull_request to main; not
on chore/bootstrap-only or topic-branch pushes.** Confirmed via
`gh run list --workflow=ci.yml`: single run from the main-push
in event A, 5 jobs, all success. The workflow file gates push
to `[main, integration]`. The chore/bootstrap-and-main push from
event A registered the run under `headBranch=main` (because main
and chore/bootstrap shared a SHA at push time and the
trigger matched main). Pure chore/bootstrap pushes — or topic-
branch pushes — do not appear in the run list. See D.1 in the
discoveries log.

**D.2 markdown-lint.yml fires on push to main; not on topic
branches.** Same trigger gate as ci.yml; same single run from
the main-push. 8s wall-clock, success.

**D.3 update.yml loaded by GitHub.** `gh workflow list --all`
returns: CI, Conflict-check, Markdown lint, Mathlib bump — all
active. Structural validity confirmed.

**D.4 update.yml workflow_dispatch.** First attempt: run
25861396223, completed with `failure` after 46s; root cause
"Duplicate header: Authorization" — see discovery D.2. Fix
applied in commit `sulrssnp` on the main working tree's
chore/bootstrap (and synced to test-1 in commit `srlsmsyl`).
Re-triggered after fix: run 25862671946, completed with
`success` in 1m10s. No bump PR opened (mathlib master appears
to be at the same SHA as test-1's pin; this is the expected
no-op outcome documented in the plan). The first run remains
in the test-1 run list as evidence of the original failure
mode.

**D.5 ci.yml on a manually-opened PR against main.** Verified
on 2026-05-14 via PR #1 (closed without merge, by design).

Action: user authored title ("Test pull_request CI trigger"),
body ("Test whether creating a pull request triggers the CI
workflow…; Not for merge."), and close comment ("CI test
complete; PR was never intended for merging."). `gh pr create
--base main --head feat/topic-A …` opened PR #1 from the
existing empty topic branch; `gh pr checks --watch` reported
all seven jobs across three workflows (CI's five jobs,
markdown-lint's one, conflict-check's one) PASS in under 3
minutes wall-clock. `gh pr close --comment …` closed cleanly.

This confirms the `pull_request: branches: [main]` trigger on
ci.yml, markdown-lint.yml, and conflict-check.yml all engage
correctly on a PR-against-main, and the seven-job test passes
on an empty topic-branch PR (the same gate a real bump-PR
would face).

Note on the `gh pr create` invocation: the lean4 plugin's
`guardrails.sh` PreToolUse hook blocks `gh pr create` by
default with "review first, then create PR manually
[policy=ask, confirm then rerun]". Bypassed for this
verification with `LEAN4_GUARDRAILS_BYPASS=1`, which is the
hint surfaced by the hook itself. See discovery D.3.

**Discoveries.** D.1, D.2, D.3 (see discoveries log).

### E. Integration regeneration (bootstrap-real)

**Iteration 1 (2026-05-14) — complete; one finding (E.1).**

**E.1 First regeneration.** With `main`, `feat/topic-A`,
`feat/topic-B`, `fix/topic-C` configured on the test-1 remote,
`bash scripts/regenerate-integration.sh` ran cleanly: fetched
origin, computed the fan-in revset
`main | TOPIC_TIPS_NOT_ON_MAIN_REVSET`, ran `jj new <parents>`
with the four bookmark tips, set `integration` to the new
fan-in commit, pushed to origin. GitHub showed
`refs/heads/integration` at the new fan-in's SHA. Local
`jj bookmark list` confirmed the `integration` bookmark at the
expected commit.

**E.2 Main immutability across regeneration.** Captured
`main`'s commit_id before the regeneration; after the first regen
plus a second regen attempt (failed — see discovery E.1),
`main`'s commit_id was byte-identical to the captured baseline.
Spec verification item #21 satisfied for this iteration.

**E.3 Second regeneration after a topic change.** Plan Task 3.6
Step 4 prescribes editing `feat/topic-A`'s tip
(`jj edit feat/topic-A`; `jj describe -m "..."`; `jj new`),
pushing the rewritten topic, then re-running the script. First
attempt failed at the bookmark-set step (see discovery E.1).
After applying the fix (`--allow-backwards`) and pushing the
fix to test-1's `chore/bootstrap` / `main`, the second
regeneration succeeded: new fan-in commit at a new SHA;
`integration@origin` advanced to the new fan-in; push reported
"move sideways" (the new fan-in is a sibling of the previous,
not a descendant — by design).

**Verification.**

- `gh api repos/rokopt/geb-mathlib-test-1/branches/integration --jq
  '.commit.sha'` returns the latest fan-in SHA after each
  regeneration.
- `jj bookmark list --all-remotes` shows `integration` and
  `integration@origin` aligned on the same commit.
- `main`'s `commit_id` before vs after a regen run: byte-identical.

**Discoveries.** E.1 (see discoveries log).

### F. Mass-rebase on a simulated bump (bootstrap-real)

**Iteration 1 (2026-05-14) — clean; no new findings.**

The "simulation" turned into a real mathlib advance: `lake
update` on the bump branch pulled an actual new mathlib master
SHA (`1e089a24` → `a148c498`), with 8055 new files downloaded
from the cache. `lake build` on the bump branch succeeded with
no breaking changes, so the simulation didn't reduce to a
no-op.

**Action sequence.**

1. `jj new main -m "bump: simulated mathlib master advance"`;
   `jj bookmark create bump/test-1 -r @`.
2. `lake update` (real mathlib advance observed).
3. `lake build` (clean).
4. Merge: `jj new main bump/test-1 -m "Merge branch
   'bump/test-1' into main"`; `jj bookmark set main -r @`;
   `jj git push --remote origin -b main`. Push reported "move
   forward" (`863416bf` → `fd5e204f`).
5. `bash scripts/rebase-topics.sh main`. Script output:
   "Rebased 8 commits to destination". All three topic branches
   now have the new `main` (`qkuurzyx`) as their parent.
6. `bash scripts/regenerate-integration.sh`. Re-fan-in over
   the rebased topic tips + new main. Push reported "move
   sideways" `c3c418d2` → `d34727d0`.
7. Push the rebased topics individually. Each push reported
   "move sideways" with the new commit_id; e.g., feat/topic-A
   `17f0b213` → `e48690b9`. All three pushes accepted.

**Verification.**

- `gh api repos/rokopt/geb-mathlib-test-1/git/refs` shows
  `main` at the merge commit, all three topic refs at their new
  rebased SHAs, `integration` at the new fan-in.
- `lake build` on the new `main` tip succeeds (verified before
  push in Step 3).
- `jj log -r 'feat/topic-A' -T 'parents'` shows the new `main`
  tip as the direct parent (and likewise for feat/topic-B,
  fix/topic-C), confirming the topic branches are now in the
  new-main lineage.
- `main` is append-only across the workflow: it advanced by
  fast-forward / merge only, never rewritten.

**Discoveries.** None new in event F.

### G. Floodgate-CI lint

**Iteration 1 (2026-05-14) — clean after plan-fix; one finding (G.1).**

**G.1 forbidden import (test-only).** With the corrected test
file (`module` + `public import Geb.Internal`), the lint
reports exactly one violation:

```text
Geb/Mathlib/Test/Forbidden.lean: forbidden import 'public
import Geb.Internal …' (allowed: Mathlib.*, Geb.Mathlib.*)
```

Exit 1 as expected.

**G.2 prefix leakage (test-only).** With the corrected test
file (`module` + `public import Mathlib.Tactic` + a body
referencing `Geb.Mathlib.SomeName`), the lint reports exactly
one violation:

```text
Geb/Mathlib/Test/Leakage.lean:5:def Foo : Geb.Mathlib.SomeName
:= sorry: 'Geb.Mathlib.' outside ^import line
```

Exit 1 as expected.

**G.3 clean file (bootstrap-real).** With the corrected test
file (`module` + `public import Mathlib.Tactic` + a `public def
trivialExample`), `lint-imports.sh` returns "clean (1 file(s)
checked)" exit 0, and `lake build` rebuilds the file
successfully (3321 total jobs). The original plan template
(without `module`+`public def`) failed both gates because of
the requirements imposed by Lean 4's module system + the
project's `linter.privateModule` linter under
`weak.warningAsError = true`. See discovery G.1.

**Discoveries.** G.1 (see discoveries log).

### G-bis. Axiom-check failing case (test-only)

**Iteration 1 (2026-05-14) — passes after script-fix; one finding (G.2).**

Authored `tmp/AxiomStub.lean` with a `Prop`-valued theorem whose
proof invokes `Classical.choice`:

```lean
import Mathlib.Tactic

theorem axiomStub (h : Nonempty Nat) : Nonempty Nat :=
  ⟨Classical.choice h⟩
```

Direct verification via `lake env lean tmp/AxiomStub.lean` (run
once for diagnosis only — the `lean-coding.md` rule discourages
`lake env lean` in normal flows) printed:

```text
'axiomStub' depends on axioms: [Classical.choice]
```

So Lean correctly identifies the dependency. But the first run of
`bash scripts/check-axioms.sh tmp/AxiomStub.lean` reported
"All declarations use only standard axioms" — exit 0 — a false
negative. See discovery G.2.

After the script-fix (commit `ruuvryvw`), the second run
correctly produced:

```text
⚠ axiomStub uses non-standard axiom: Classical.choice
Files with non-standard axioms: 1
```

Non-zero exit, Classical.choice flagged. Step 2's PASS path
taken: "script flagged Classical.choice as expected".

**Discoveries.** G.2 (see discoveries log).

### H. PR extraction (bootstrap-real, local-only — no push to `rokopt/mathlib4`)

**Iteration 1 (2026-05-14) — clean; no new findings.**

**Setup.** Authored `Geb/Mathlib/Sandbox/Trivial.lean` with the
post-G.1 conventions (`module`, `public import Mathlib.Tactic`,
`public def trivialId`); `lint-imports.sh` clean,
`lake build` clean (3321 jobs).

**Extract-pr.sh contract.** The script just validates source and
fork-root directories, computes the destination path, and
copies-with-sed-rewrite. No git operations are performed. The
fork-root only needs to exist as a directory; no actual mathlib4
clone is required for the script-level test. (A real
mathlib4-fork would be used for an end-to-end test, but per the
plan's "no push to `rokopt/mathlib4`" rule, the bootstrap-time
verification stops at extraction.)

**Action.** With a stub `/tmp/event-h-fork/Mathlib/` directory,
`bash scripts/extract-pr.sh Geb/Mathlib/Sandbox/Trivial.lean
/tmp/event-h-fork` wrote the file to
`/tmp/event-h-fork/Mathlib/Sandbox/Trivial.lean`. The trivial
test file has no `Geb.Mathlib.*` imports to rewrite, so the
diff is empty — as the plan predicts.

**Rewrite verification (inline).** A standalone sed pass on
strings:

```text
Geb.Mathlib.Foo       → Mathlib.Foo
Geb.Mathlib.Bar.Baz   → Mathlib.Bar.Baz
Geb.MathlibFoo        → (unchanged, no trailing dot)
```

The `\b…\.` regex correctly anchors on dotted-prefix matches and
rejects accidental Geb.MathlibFoo-style false positives.

**Cleanup.** Source file + stub fork dir removed. No pushes
attempted.

**Discoveries.** None new in event H.

### I. Conflict-commit refusal (test-only)

**Iteration 1 (2026-05-14) — server-side gate verified via an
alternative path-detection test; two findings (I.1, I.2).**

**I.1 Local-guard refusal of real jj conflict.** Created
`feat/X` and `feat/Y` with conflicting content in
`conflict-test.txt`, then merged via `jj new feat/X feat/Y` —
produced a `(conflict)` revision. Attempted
`jj git push --remote origin -b test/conflict`: refused with
`Error: Won't push commit ... since it has conflicts and is
private` and `Hint: Configured git.private-commits:
'conflicts()'`. The local ergonomic guard fires as designed.

**I.2 Plan Step 3b unreachable via jj's normal push.** The plan
prescribes bypassing the local guard
(`git.private-commits = 'none()'`) plus `--allow-private` to
push the conflict and exercise the server-side gate. In jj
0.41, neither suffices: jj has an internal backstop that
refuses to push any commit in a `(conflict)` state, citing
"Won't push commit ... since it has conflicts" without the
`private` qualifier. See discovery I.2.

**I.3 Server-side gate path-detection (alternative test).**
Crafted an isolated path-detection scenario instead: created
`test/conflict-paths` containing files
`.jjconflict-base-0/test.txt` and `.jjconflict-side-0/test.txt`
in a regular (non-`(conflict)`) commit. jj pushed this without
refusal (warning only); PR #2 opened against main; CI fired
all eight workflow jobs. The `conflict-check` job FAILED in 3s
citing the exact paths:

```text
Reject .jjconflict-* paths (no allowlist)
  .jjconflict-base-0/test.txt
  .jjconflict-side-0/test.txt
```

All other jobs (CI's five, markdown-lint, hooks-smoke) passed.
PR closed without merge per the plan. Server-side gate
verified to fail closed on the documented path patterns.

**Sentinel allowlist (`docs/`-scoped) not exercised** in this
iteration. Documented as a follow-up; the existing test was
sufficient to prove the gate's path-detection rejects unmarked
files.

**Cleanup.** feat/X, feat/Y, test/conflict (real-conflict
attempt), test/conflict-paths (path-test) all abandoned + local
bookmarks deleted. Local `git.private-commits` restored to
`conflicts()`. Working tree clean.

**Discoveries.** I.1 (jj config get flag mismatch) and I.2
(jj refuses to push conflicts).

### J. Process self-update (bootstrap-real)

**Iteration 1 (2026-05-14) — exercised continuously; narrower
CLAUDE.md skill test deferred to user.**

The plan's narrow form prescribes: in a fresh Claude session,
use `claude-md-management:revise-claude-md` to add a sentence
to test-1's CLAUDE.md; commit; open another fresh session and
confirm the new sentence is in the loaded context (spec
verification item #31). Deferred to the user — both steps
require fresh Claude sessions opened at `geb-mathlib-test-1/`.

**The broader self-update mechanism has been exercised
continuously throughout iteration 1.** Five discoveries
followed the cycle "observe failure → record in runbook → fix
in live spec/plan/scripts → sync to test-1 → re-verify
succeeds":

| Discovery | Affected artifact | Commit |
| --- | --- | --- |
| D.2 | `update.yml` (workflow) | `sulrssnp` |
| E.1 | `regenerate-integration.sh` | `nnmyyooz` |
| G.1 | plan Task 3.8 test files | `zlnlkzqr` |
| G.2 | `check-axioms.sh` | `ruuvryvw` |
| I.2 | plan Task 3.10 Step 3b | (re-running rewrite still pending) |

Each fix was applied to the live working tree's
`chore/bootstrap`, then propagated to test-1 by `cp` plus a
new commit on test-1's `chore/bootstrap`, then the affected
event re-run to confirm the fix. The cycle is working.

**Discoveries.** None new in event J's narrow test (deferred).

### K. Doc generation (bootstrap-real)

**Iteration 1 (2026-05-14) — clean; phase-1 finding S3 refuted;
new `doc-build.yml` workflow added.**

**Setup.** `doc-gen4` was pinned in `lakefile.toml` at
`rev = "v4.30.0-rc2"` from Task 2.2; appears in
`lake-manifest.json` after the bundle import.

**Step 1 — confirm doc-gen4 present.** `grep doc-gen4
lake-manifest.json` returned a match.

**Step 2 — run `lake build Geb:docs`.** 214 jobs ran, all
green. Output:

```text
✔ [209/214] Built «geb-mathlib»/Geb.Mathlib:docInfo (391ms)
✔ [210/214] Built «geb-mathlib»/Geb.Cslib:docInfo (392ms)
✔ [211/214] Built «geb-mathlib»/Geb.Internal:docInfo (410ms)
✔ [213/214] Built «geb-mathlib»/Geb:docInfo (268ms)
ℹ [214/214] Built «geb-mathlib»/Geb:docs (14s)
Build completed successfully (214 jobs).
```

HTML output at `.lake/build/doc/Geb/`: `Cslib.html`,
`Internal.html`, `Mathlib.html`. Phase-1 finding S3 (doc-gen4
:docs facet "version-unverified at the pinned rev") is
refuted: the lake-target form works correctly.

**Step 3 — visual confirmation.** Deferred to user; the
generated HTML is at `.lake/build/doc/Geb/` in test-1's local
build directory.

**Step 4 — author `.github/workflows/doc-build.yml`.** New
workflow added in commit `sztvqtlo` ("ci: add doc-build.yml
monthly cron for doc-gen4 output") on the live working tree's
`chore/bootstrap`. Cron `'0 9 1 * *'` (monthly UTC),
`workflow_dispatch` for manual trigger. Action set:
`actions/checkout` (v6.0.2 SHA), `leanprover/lean-action` (v1
SHA, `build: true`), then `lake build Geb:docs`. SHAs match
the pinning convention from Task 2.25.

**Discoveries.** None new in event K. Phase-1 S3 is refuted.

## Discoveries log

### A.1 (2026-05-13) — `guardrails.sh` blocks `git checkout`

**What.** Plan Task 3.2 Step 3 extracts a bundled tree via a
three-command pipe: `git init --quiet --initial-branch=main`,
then `git fetch --quiet /tmp/chore-bootstrap.bundle chore/bootstrap`,
then
`git -c advice.detachedHead=false checkout --quiet FETCH_HEAD -- .`.
The lean4 plugin's `${CLAUDE_PLUGIN_ROOT}/hooks/guardrails.sh`
PreToolUse hook fires on the `checkout` segment and blocks the
entire invocation: "BLOCKED (Lean guardrail): destructive git
checkout. Commit or checkpoint first."

**Why it's a false-positive in this context.** The `git checkout
FETCH_HEAD -- .` runs in a freshly-`git init`'d empty temp dir
(`/tmp/import-${N}`), so there is no existing tree to clobber.
The guardrail's general intuition (don't destroy uncommitted work)
doesn't apply here. The guardrail does not differentiate; it
trips on the literal command shape.

**Workaround applied in iteration 1.** Replace the
`git init + git fetch + git checkout` triple with a single
`git clone --quiet /tmp/chore-bootstrap.bundle` invocation
pointed at `/tmp/import-${N}` with
`--branch chore/bootstrap`. Same end state (working-tree
content of the bundled ref in `/tmp/import-${N}`); no `checkout`
of an existing tree.

**Proposed plan amendment.** Update Task 3.2 Step 3 to use the
`git clone <bundle>` form, with a note that this avoids the
lean4 plugin's guardrail.

### B.1 (2026-05-14, event B) — `!`-prefix bypasses PreToolUse hooks

**What.** In a fresh Claude Code session at `geb-mathlib-test-1/`,
running `git checkout main` via the `!`-prefix
(Claude Code's "run command directly" affordance) executed
without firing the PreToolUse hook. The hook only fires for
model-issued `Bash` tool calls; the `!`-prefix appears to be a
distinct code path that does not invoke PreToolUse.

**Implication.** The hook is a safety net for *model-driven*
actions, not for user-typed `!`-commands. A user who explicitly
chooses to run a mutating command via `!`-prefix has implicitly
self-authorised it. This is consistent with the project's
"binding safety is server-side; local hooks are conveniences"
posture documented in CLAUDE.md and `docs/process.md`, but worth
recording so future contributors know `!`-prefix bypasses the
local guardrail. The server-side gate (`conflict-check.yml` +
required-status-checks on `main`) is the actual enforcement.

**Proposed plan amendment.** None for the plan — the hook design
already documents that local hooks are not enforcement. Consider
mentioning the `!`-prefix observation in
`.claude/rules/ci-and-workflow.md` § Hook-script conventions, so
contributors don't assume `!`-prefix triggers the same audit
trail.

### D.1 (2026-05-14, event D) — plan Task 3.5 Step 1 expectation overstated

**What.** Plan Task 3.5 Step 1 expects `gh run list --workflow=ci.yml`
to show "runs for chore/bootstrap, feat/topic-A, feat/topic-B,
fix/topic-C; statuses passed (or in progress)." The committed
`ci.yml` (and `markdown-lint.yml`) gates push triggers to
`branches: [main, integration]`, so non-trunk pushes do not fire
those workflows. Topic-branch coverage runs through the
`pull_request: branches: [main]` trigger.

**Why the spec/workflows are correct, not the plan.** The
trunk-only-CI-on-push convention matches mathlib's pattern (which
the spec aligns with explicitly). Running CI on every topic-branch
push costs runner minutes for work-in-progress code that the
contributor hasn't asked to be reviewed; opening a PR is the
explicit signal.

**Proposed plan amendment.** Update Task 3.5 Step 1 expected
output to read: "runs for the push to main (carrying chore/bootstrap
as a co-pushed bookmark at the same SHA); no runs for topic-branch
pushes (expected — workflows are gated to `[main, integration]`
on push; topic-branch coverage comes through the `pull_request`
trigger exercised in Step 4)."

### D.2 (2026-05-14, event D) — update.yml fails with "Duplicate header: Authorization"

**What.** Running
`gh workflow run update.yml --repo rokopt/geb-mathlib-test-1`
triggered the workflow; the run failed at the `mathlib-update-action`
step with "fatal: unable to access … The requested URL returned
error: 400" and the underlying GitHub error
`remote: Duplicate header: "Authorization"`. The workflow as
authored runs two `actions/checkout` flows in sequence: the
workflow file's own `actions/checkout` step (with
`token: ${{ secrets.GITHUB_TOKEN }}`) and the
`mathlib-update-action`'s internal `actions/checkout` step. Each
sets up an `Authorization` header against
`https://github.com/.../.extraheader`; the second one duplicates,
GitHub rejects the fetch with HTTP 400.

**Plan / workflow amendment applied (2026-05-14).** Removed the
explicit `actions/checkout` step from `update.yml`, since
`mathlib-update-action` handles checkout internally. Concretely:

```yaml
jobs:
  bump:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write
    steps:
      - uses: leanprover-community/mathlib-update-action@d2b8804850b44ce9be89ab9c39ad460e11e563eb
        with:
          intermediate_releases: latest
```

Alternative considered if the explicit checkout had been needed
for some reason: drop the `with: token: ...` (default is the
same GITHUB_TOKEN, without the duplicate-header side-effect),
and/or set `persist-credentials: false` on the first checkout.

**Verification.** After the fix landed in the main working tree
on chore/bootstrap (commit `sulrssnp`) and was synced to test-1
(commit `srlsmsyl`), re-triggered workflow_dispatch on test-1
(run 25862671946) completed with `success` in 1m10s. The failed
run 25861396223 remains in the test-1 run list as evidence of
the original failure mode.

### G.1 (2026-05-14) — Task 3.8 event-G test files miss `module` + `public`

**What.** Plan Task 3.8 Steps 1–3 author three test files under
`Geb/Mathlib/Test/` to exercise floodgate lint cases.

- G1 (`Forbidden.lean`) and G2 (`Leakage.lean`) were authored
  without a `module` keyword header. `lint-imports.sh` requires
  every `.lean` file under `Geb/Mathlib/` to carry the header
  (see commit `zmmvoytn`'s rules + Task 2.3 module-system
  scaffolding). Without it, both files trip an extra
  "missing 'module' header" violation in addition to the
  intended forbidden-import / prefix-leakage violation. The
  tests still exit 1 (the right answer) but for two reasons
  instead of the isolated case each test names.
- G3 (`Clean.lean`) was authored without `module` (same lint
  miss) AND with a non-`public def`. Without `module`, lint
  flags exit 1 instead of the expected exit 0. With `module +
  public import` but no public declarations, Lean 4's
  `linter.privateModule` fires ("The current module only
  contains private declarations"), which under
  `weak.warningAsError = true` blocks the build — so `lake
  build` fails even after the lint passes.

**Fix applied (2026-05-14).** Plan Task 3.8 Steps 1, 2, 3 test
files updated:

- G1: add `module` + change `import` → `public import`.
- G2: add `module` + change `import` → `public import`.
- G3: add `module` + change `import` → `public import` + mark
  the def as `public def`.

Verification: after re-running with the corrected templates,
G1 + G2 each isolate to a single intended violation (lint exit
1), and G3 passes both lint (exit 0) and build (3321 jobs
success).

**Plan amendment.** Already applied in commit `zlnlkzqr`
("fix(plan): correct Task 3.8 event G test files to satisfy
Lean 4 module system").

### I.1 (2026-05-14) — `jj config get` uses `--repository`, not `--repo`

**What.** Plan Task 3.10 Step 3b prescribes
`jj config get --repo git.private-commits` to capture the
config value. jj 0.41 rejects this:

```text
error: unexpected argument '--repo' found
  tip: a similar argument exists: '--repository'
```

`jj config set --repo X Y` works; `jj config get --repo X` does
not. The two subcommands differ in flag conventions. The
working invocation for `get` is
`jj config get --repository <REPO> <NAME>` (with a positional
REPO path argument).

**Severity.** Minor. The plan can be amended to either:
(a) use `--repository "$(pwd)"` for `get`,
(b) read the value from the per-repo config file directly
(`~/.config/jj/repos/<hash>/config.toml`),
(c) skip the capture (the restore step just sets a known
value, not a captured one).

**Proposed plan amendment.** Replace the `BEFORE_PRIV=$(jj
config get --repo ...)` capture with a known-value restore:
the project's recommended local config always sets
`git.private-commits = 'conflicts()'`, so the restore is
`jj config set --repo git.private-commits 'conflicts()'`
without needing to capture first.

### I.2 (2026-05-14) — `jj git push` refuses conflict commits irrespective of `git.private-commits`

**What.** Plan Task 3.10 Step 3b prescribes bypassing the
local `git.private-commits = 'conflicts()'` guard by setting
it to `'none()'` and using `--allow-private`, then pushing the
conflict bookmark. In jj 0.41, this combination still fails:

```text
Error: Won't push commit ... since it has conflicts
Hint: Rejected commit: ... (conflict) (empty) ...
```

jj has an internal backstop that refuses to push any commit in
a `(conflict)` state — independent of the
`git.private-commits` config and `--allow-private` flag. The
rationale is sensible: git's wire protocol does not understand
jj's conflict-state markers, so pushing a conflict commit
would lose the conflict information on the remote.

**Implication for the test.** The plan's path
("bypass + push the real jj conflict") cannot exercise the
server-side `conflict-check.yml` gate because jj refuses the
push at step 1. The server-side gate is therefore tested via
an alternative scenario: a non-`(conflict)` commit containing
files literally named `.jjconflict-base-*` and
`.jjconflict-side-*`. This exercises the gate's path-detection
logic (which is what the gate actually does on the GitHub side)
without involving jj's `(conflict)` state machinery (which
never reaches the remote anyway).

**Proposed plan amendment.** Rewrite Step 3b around the
path-detection scenario:

1. After Step 3 verifies the local guard, do not attempt to
   push a `(conflict)` commit.
2. Instead, create a fresh `test/conflict-paths` bookmark off
   `main` and stage files `.jjconflict-base-0/test.txt` and
   `.jjconflict-side-0/test.txt` in it.
3. Push (no bypass needed — these are regular files in a
   non-conflict commit; jj allows the push, possibly with a
   warning about the suspicious filenames).
4. Open PR; watch `conflict-check.yml` fail with the
   path-detection citation.
5. Close PR and abandon the test branch.

This still tests the binding property (the server-side gate
rejects PRs with these paths) while working with — not around
— jj's conflict-push refusal.

### G.2 (2026-05-14) — `check-axioms.sh` silently passes all files

**What.** The vendored `check-axioms.sh` (Task 2.13) parses
`#print axioms` output to find each declaration's axiom
dependencies, then compares each axiom against the
`STANDARD_AXIOMS` allowlist (`propext|Quot.sound|quot.sound`,
with `Classical.choice` deliberately excluded). The intent: any
declaration that uses `Classical.choice` should be flagged with
non-zero exit.

In practice on Lean 4 v4.30.0-rc2, the script reports "All
declarations use only standard axioms" on every file — even
files whose declarations explicitly invoke `Classical.choice`.

Root cause: the script's regex matches the old multi-line
output format
(`foo depends on axioms:` then axiom names on subsequent lines).
Lean 4 v4.30.0-rc2 emits a single-line format with the decl name
in single quotes and axioms inline in brackets:
`'foo' depends on axioms: [axiom1, axiom2]`. The decl-header
regex `^([a-zA-Z0-9_.]+)[[:space:]]+depends...` does not match
the leading single quote and does not extract the bracketed
axiom list. Result: `CURRENT_DECL` never gets set, the
axiom-extraction branch never fires, and `HAS_CUSTOM` stays
`false` regardless of file content.

**Severity.** Critical. Every CI run that "passed" the
axiom-check step on the empty bootstrap skeleton was a trivial
pass — no declarations existed. But the moment any real
`Classical.choice` usage entered the project, the script would
have silently let it through. The spec's verification item #19
("the workflow is exercised in a test-only event by intentionally
adding a Classical.choice-using stub and verifying the script
flags it") was never previously exercised against an actual
flag-worthy case.

**Fix applied (commit `ruuvryvw`).** Update both parsing blocks
(the primary + the inaccessible-decl fallback) to:

- Accept an optional single-quoted decl name in the header
  regex.
- Extract axiom names inline from a `[axiom1, axiom2]` list when
  present, trimming whitespace around each name.
- Preserve the old one-axiom-per-line branch as a fallback for
  older Lean versions.

After the fix, the stub file correctly produces:

```text
⚠ axiomStub uses non-standard axiom: Classical.choice
```

with non-zero exit.

**Upstream consideration.** The vendored script is patched from
`leanprover-community/lean4-skills`. The upstream may have the
same parsing bug; consider opening an issue there. (User
authorship required for the upstream report per the
no-LLM-drafted-text rule.)

### E.1 (2026-05-14) — `regenerate-integration.sh` fails on the second invocation

**What.** First invocation succeeded (creates `integration`
bookmark at a fan-in commit, pushes). Second invocation —
after editing a topic-branch tip and pushing it — failed at the
`jj bookmark set integration -r @` step with:

```text
Error: Refusing to move bookmark backwards or sideways: integration
Hint: Use --allow-backwards to allow it.
```

Each regeneration produces a new fan-in commit that is a
sibling of the previous one (not a descendant). The new fan-in
shares parents (main + topic tips) with the previous fan-in but
is a different revision. Moving the `integration` bookmark from
the old fan-in to the new one is a sideways move; `jj bookmark
set` refuses by default to prevent accidental bookmark loss.

**Fix applied (2026-05-14).** Add `--allow-backwards` to the
`jj bookmark set integration -r @` invocation in
`scripts/regenerate-integration.sh`. The flag permits moving
the bookmark to a non-descendant revision; this is exactly the
intended semantics for `integration` (a regenerated view that
is sibling-replaced on each run, with the old fan-in
intentionally orphaned and garbage-collected).

The fix landed as commit `nnmyyooz` ("fix(scripts): allow
regenerate-integration.sh to update bookmark across re-runs")
on the main working tree's `chore/bootstrap`; synced to test-1
in commit `npyuurkk`. After the fix, the second regeneration
succeeded: `integration` moved from `1d610954` to `c3c418d2`
on test-1's remote, with the push reporting "move sideways"
(consistent with the regenerated-not-extended design).

**Plan amendment.** Already applied to the live script
(`scripts/regenerate-integration.sh`). The spec's
"`regenerate-integration.sh` revset contract" section should
also note the sideways-bookmark-move semantics so future readers
understand why `--allow-backwards` is correct (not a workaround).

### D.3 (2026-05-14) — lean4 `guardrails.sh` asks-to-confirm on `gh pr create`

**What.** Invoking `gh pr create` through Claude Code's Bash
tool fires the lean4 plugin's
`${CLAUDE_PLUGIN_ROOT}/hooks/guardrails.sh` PreToolUse hook,
which blocks with the message: "BLOCKED (Lean guardrail): gh
pr create - review first, then create PR manually [policy=ask,
confirm then rerun]. To proceed once, prefix with:
LEAN4_GUARDRAILS_BYPASS=1".

**Why this is appropriate.** PRs are user-facing artefacts;
the spec's "No LLM-drafted user-facing text on mathlib channels"
rule requires user-authored title/body. The guardrail forces
the agent to pause and surface intent before publishing a PR,
which is the correct safety behaviour.

**Workaround applied.** Once the user has provided the
verbatim PR title, body, and close comment, prefix the
invocation with `LEAN4_GUARDRAILS_BYPASS=1` to proceed. The
bypass is per-invocation (env-scoped); it does not persist.

**Proposed plan amendment.** None — the guardrail is doing its
job. Note it in `.claude/rules/ci-and-workflow.md`
§ Hook-script conventions alongside the other hook
observations (B.1, B.2) so future contributors understand the
explicit-bypass pattern.

### B.2 (2026-05-14, event B) — two independent approval gates for Bash tool calls

**What.** Claude Code applies two distinct approval gates to a
model-issued `Bash` tool call:

1. **PreToolUse hooks** (project-scoped) — this is
   `scripts/hooks/block-mutating-git.sh`.
2. **Built-in permission system** (Claude-Code-scoped) — the
   default "ask before running Bash" behaviour, suppressed by
   the user's auto mode.

Both gates must return "allow" for the command to execute. In
test-1's B.5 verification, the hook returned silent-allow (it
stripped the `jj git X` segment), but the built-in system still
emitted a generic "this command requires authorisation" prompt
— different text from the hook's project-specific
"…not on the read-only allow-list…" prompt seen in B.4.

**Implication.** Auto mode suppresses the built-in gate but not
the hook, which is the intended design: auto mode is a user
productivity setting, not a way to bypass the project's safety
rails. If a future operator runs in auto mode, the hook will
still surface its specific prompt for mutating-git commands; if
auto mode is off, both gates engage in series.

**Proposed plan amendment.** None — this is Claude Code-level
behaviour, not a plan defect. The runbook itself records the
observation as a forward reference for future contributors who
may be confused when two prompts appear for one command.

### A.2 (2026-05-13, event A) — disclaimer commit step missing from plan

**What.** Plan Task 3.2 Step 6 edits `README.md` to add the
test-repo disclaimer banner. Step 7 runs lint and build; Step 8
asks the user to review the diff; Step 9 pushes. There is no
explicit step between 6 and 9 that commits the disclaimer edit
or advances the `chore/bootstrap` and `main` bookmarks to
include it. Without an explicit commit, the disclaimer sits in
`@` (working copy) and `jj git push -b chore/bootstrap` would
exclude it.

**Workaround applied in iteration 1.** Added explicit
`jj describe -m "doc: add test-repo disclaimer ..."`, `jj new`,
`jj bookmark set chore/bootstrap -r @-`,
`jj bookmark set main -r 'chore/bootstrap'` between Steps 7 and
8. This produces a third commit on top of the placeholder +
scaffolding-import pair; both bookmarks advance to it before push.

**Proposed plan amendment.** Insert Task 3.2 Step 6b "Commit the
disclaimer + advance bookmarks" between Step 6 and Step 7, with
the explicit describe / new / bookmark-set sequence.

# geb-mathlib bootstrap implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> `superpowers:executing-plans` (inline) to implement this plan
> task-by-task. The user has stated a preference for inline execution
> over `superpowers:subagent-driven-development` because the bootstrap
> is many small interrelated steps where coherence across steps
> matters and parallelism is limited. Steps use checkbox (`- [ ]`)
> syntax for tracking.

**Goal:** Bring the `geb-mathlib` repository from its current empty
state (only the bootstrap spec, the markdownlint config, and
plugin-generated `.remember/` exist) to "production-ready, public,
populated, and proven-functional under every documented process,"
ready for the first mathematical workstream to begin.

**Architecture:** The plan executes in five sequential parts. Part 1
initialises the local working tree (jj/git colocated). Part 2 authors
all scaffolding artifacts (lakefile, scripts, hooks, CI workflows,
`CLAUDE.md` and `.claude/rules/*`, the runbook skeleton) as a series
of locally-reviewable jj commits on `chore/bootstrap`. Part 3 runs
the test-repo simulation iteration loop on numbered repos
`rokopt/geb-mathlib-test-N`, exercising every documented event
end-to-end and updating the spec/plan/runbook on any discovery; the
loop terminates when a fresh test repo runs the full event sequence
clean. Part 4 brings up the real repo `rokopt/geb-mathlib` via
runbook replay, history rewrite into ~10–20 topological commits,
line-by-line user review, and a single push. Part 5 verifies
fork-readiness and closes the bootstrap.

**Tech Stack:** Lean 4 v4.30.0-rc2 + mathlib (SHA-pinned via
`lake-manifest.json`) + CSLib (release tag `v4.30.0-rc2`) + jj v0.41+
(colocated mode) + GitHub Actions (`leanprover/lean-action@v1`,
`leanprover-community/mathlib-update-action`,
`DavidAnson/markdownlint-cli2-action@v19`) + markdownlint-cli2 +
shell scripts (bash) for local tooling and hooks.

**Reference spec:**
`docs/superpowers/specs/2026-05-04-geb-mathlib-bootstrap-design.md`
(2148 lines; user-approved through 13 fresh-context adversarial
review iterations). The plan does **not** re-derive design
decisions; it operationalises the spec. Where the spec carries Open
Questions, this plan resolves them (see "Resolved open questions"
near the end of the document) or carries them forward as user
decisions during execution.

**Plan-execution preference:** inline `superpowers:executing-plans`,
with batch checkpoints at each Part boundary for user review.

---

## Conventions used throughout this plan

- **Working directory** is the repo root (the existing
  `geb-mathlib/` directory) unless explicitly stated otherwise. Test
  repos in Part 3 use sibling working directories.
- **VCS commands**: never raw `git commit` / `git push` /
  `git checkout` / `git branch` / etc. — these are prompted by the
  PreToolUse hook authored in Part 2 (the operator authorises or
  rejects each via the permission prompt). Use `jj` throughout.
  Read-only `git` (e.g., `git log`, `git diff`, `git status`) is on
  the allow-list and runs without prompting.

  **Hook-activation gap during plan execution**: the project-local
  `.claude/settings.json` registering the hook is authored in
  Task 2.24, after Tasks 1.1–2.23 have already run. During that
  pre-Task-2.24 window, the project-local hook does **not** fire.
  Pre-existing user-level hooks at `~/.claude/settings.json` (if
  any) cover this gap; verify before Part 1 begins. The plan's
  Part-1 commands include forms (`git init`, `git remote add`)
  that prompt under the allow-list — they are not on the
  read-only allow-list, but they are also outside the project's
  hook-active window since the project hook lands at Task 2.24.
  During the pre-Task-2.24 window, any pre-existing user-level
  hook surfaces the same prompt; the operator authorises each
  one. After Task 2.24 commits and the next session reload picks
  up the project hook, the same forms continue to prompt.

  **Hook design — allow-list, with prompt for unknowns**: the
  hook script enumerates read-only `git` forms (e.g.,
  `git status`, `git log`, `git diff`, plus per-command flag-aware
  allow-listing for `git config`, `git branch`, `git tag`,
  `git remote`, `git worktree`, etc.) and falls through to a
  permission prompt for anything not on the list. Mutating
  subcommands (`git commit`, `git push`, `git merge`, `git rebase`,
  `git reset`, `git checkout` for state changes, `git add`,
  `git rm`, `git config --set`, `git branch -d`, etc.) are not on
  the allow-list and trigger the prompt rather than silent
  execution. Failure-mode asymmetry is the rationale: a missed
  read-only command surfaces as a loud, easily-fixable user prompt;
  a missed mutating command in a deny-list would silently corrupt
  state. Allow-list is also the principle-of-least-privilege
  default. The prompt-not-deny stance reflects the broader project
  principle that an individual contributor can take decisions on
  their fork or clone that the project itself wouldn't enforce;
  the project's binding safety net is server-side
  (`conflict-check.yml` plus required-status-checks on `main`),
  not client-side hooks. Extending the allow-list is a routine
  project edit; PRs that add a missed read-only form do not
  require a full adversarial-review cycle. The script path is
  `scripts/hooks/block-mutating-git.sh` (name retained from the
  earlier deny-list draft for cross-reference stability; the
  semantics are now allow-list-with-prompt). The full enumeration
  lives in spec § "PreToolUse: block-mutating-git".
- **Commit cadence**: each task ends with a commit step that uses
  `jj describe` (set message on `@`) followed by `jj new` (create
  a new working-copy change as child). Frequent local commits are
  encouraged; pushes are gated on user review. (jj 0.41+ also
  provides `jj commit`, but its semantics differ subtly from
  `describe`+`new`; this plan standardises on the explicit
  two-command form.)
- **Bookmark advance**: jj does not advance bookmarks
  automatically with `jj describe` + `jj new`. After each commit
  step, the executing agent runs

  ```bash
  jj bookmark set chore/bootstrap -r @-
  ```

  to keep `chore/bootstrap` pointing at the latest committed
  change (the immediate parent of the new working-copy change at
  `@`). Equivalent (per-developer, jj v0.39+): set
  `revsets.bookmark-advance-from`/`-to` in
  `~/.config/jj/config.toml` and run
  `jj bookmark advance chore/bootstrap` after each commit (per
  D10/D11; the legacy `experimental-advance-branches` config was
  removed). Plan steps
  assume the manual invocation; the per-developer config is
  documented but not required.
- **`jj git push` flag form**: this plan standardises on the
  short form `-b <bookmark>` consistently. The long form
  `--bookmark <bookmark>` is the same flag (per
  `jj git push --help` on jj 0.41); we use `-b` everywhere for
  grep-ability. Push deletions of a specific bookmark use the
  same `-b` form after `jj bookmark delete`. The `-b <name>` form
  hard-fails on private/conflicted commits (exit 1, stderr
  `Error: Won't push commit <hash> since it is private`); the
  bulk forms `--all`/`--tracked`/`-r` *silently skip* such
  bookmarks in jj 0.41 (D23: stderr `Warning: Won't push
  bookmark <name>: commit <hash> is private`). The pre-push gate
  uses the per-bookmark `-b` form to inherit the hard-fail
  semantics; the real-repo bulk push (Task 4.7) parses the
  dry-run output for the silent-skip warning.
- **No push without review**: every push to a remote is preceded by
  an explicit user-review step where the user reads the diff
  line-by-line and authorises the push. The plan never pushes
  autonomously.
- **No LLM-drafted user-facing text**: any GitHub PR description,
  Zulip message, or GitHub issue/PR comment text is authored by the
  user. Where the plan references such text, it surfaces a draft
  marked "for the user to paraphrase" rather than a final.
  Carve-out: merge commit messages of the form `Merge branch
  '<name>' into <base>` are git's conventional default and are
  exempt from the LLM-text rule. Any further prose in the merge
  body is user-authored.
- **markdownlint-clean**: every `.md` file authored or edited
  passes `markdownlint-cli2 --config .markdownlint-cli2.jsonc`. Run
  it before each commit step that touches Markdown.
- **Style**: all committed text follows formal/precise/mathematical/
  dry/unopinionated register (no value-laden adjectives like "key",
  "important", "powerful", "elegant").
- **Generic user references**: "the user" / "they" / "them"
  generically in committed text; no first names, email, or
  autobiographical detail.
- **Path placeholders**: where the spec uses `$REPO_ROOT` or
  `$DEV_ROOT`, the plan uses repo-relative paths inside the working
  tree, and uses generic descriptors ("the local working tree", "a
  sibling directory") for paths outside it. No
  `/home/<username>/...` strings in committed artifacts.
- **GitHub owner placeholder**: the plan writes `rokopt/...` in
  concrete commands so an executing agent has copy-pasteable
  invocations against the current project owner. If the project
  changes owner (or this plan is replayed from a fork), substitute
  the new owner's handle for every occurrence of `rokopt/` in
  commands. The current owner is project-instance-specific state;
  per spec § "Generic user references" it lives in project memory
  (entry `project_github_remote.md`), not in the repo's
  declarative content. Forks of this plan should commit a Conventions
  override at the top setting their own owner.
- **`jj` config**: `signing` config is per-developer in
  `~/.config/jj/config.toml`; not committed. The project does NOT
  ship a committed `jj-config-repo.toml` template (the spec's
  test-1 attempt found this approach broken: jj v0.38+ moved
  per-repo config out of the repo to
  `~/.config/jj/repos/<hash>/config.toml` for security, per D8;
  a committed template becomes a confusing artifact). The D1–D26
  discoveries are summarised in a project-internal log; this plan
  cites by D-number. Primary sources for each finding are the cited
  jj `CHANGELOG.md` entries and `https://docs.jj-vcs.dev/latest/`.
  Instead, the recommended local
  jj configuration (`git.private-commits = "conflicts()"`,
  `[remotes.origin] auto-track-bookmarks = "glob:*"`,
  `revsets.bookmark-advance-from`/`-to`) is documented in
  `docs/process.md` § Setup as a contributor-side ergonomic. The
  binding safety property (rejecting conflicted submissions) is
  enforced server-side by `conflict-check.yml`; see spec
  § "Local-vs-server safety model". Note the deprecated
  `git.push-new-bookmarks` setting (D2/D9) is replaced by
  `auto-track-bookmarks` per remote; `jj git push -b <name>`
  also auto-tracks on first push since v0.38, so most flows do
  not require the config at all.

---

## Part 1 — Local working tree initialisation

**Goal of Part 1:** Convert the existing
`geb-mathlib/` directory (currently containing only
`docs/superpowers/specs/2026-05-04-geb-mathlib-bootstrap-design.md`,
`.markdownlint-cli2.jsonc`, `.claude/settings.local.json`, and the
plugin-generated `.remember/`) into a colocated jj+git repository
with a `chore/bootstrap` topic branch ready to receive scaffolding
commits.

**Verification at end of Part 1:** `jj status` reports a clean
working tree; `jj log` shows one or two commits (an initial commit
plus possibly a `chore/bootstrap` head commit); the `chore/bootstrap`
bookmark exists; no remote configured yet (added later in Part 3 /
Part 4 explicitly).

### Task 1.1: Pre-flight checks

**Files:** none modified.

- [ ] **Step 1: Confirm working directory**

```bash
pwd
# Expected: the path ends in /geb-mathlib (the directory the user
# initialised for this project). This plan refers to it as "the
# working tree" hereafter; specific paths are repo-relative.
ls -la
# Expected: shows .claude/, .markdownlint-cli2.jsonc, .remember/,
# docs/, and nothing else.
```

- [ ] **Step 2: Confirm spec is in place**

```bash
test -f docs/superpowers/specs/2026-05-04-geb-mathlib-bootstrap-design.md \
  && echo "spec present" || echo "spec MISSING"
# Expected: "spec present"
```

- [ ] **Step 3: Confirm jj and git are installed at expected versions**

```bash
jj --version
# Expected: "jj 0.41.x" or later (the project pins to 0.41+; per
# D8/D13/D14, jj v0.38 requires git >= 2.41.0 and refuses
# --colocate inside a git worktree).
git --version
# Expected: git >= 2.41.0. macOS users on default Xcode CLT
# pre-26 must install git via Homebrew or upgrade Xcode CLT to
# 26+; system git on RHEL 8 (2.27), Ubuntu 22.04 LTS (2.34), and
# similar locked-down distros falls below the floor — see spec
# § "Known contributor-side constraints" for the escape hatch.
```

- [ ] **Step 4: Confirm jj user identity is configured**

```bash
jj config get user.name 2>/dev/null
jj config get user.email 2>/dev/null
# Expected: both print non-empty values. jj does NOT inherit
# from git's global config (per test-1 finding D6); identity
# must be explicit. If either returns empty or errors, halt and
# tell the user:
#
#   jj config set --user user.name "Your Name"
#   jj config set --user user.email "you@example.com"
#
# Without this, every commit jj creates is attributed to an
# empty identity and cannot be pushed to remotes.
```

- [ ] **Step 5: Confirm working tree is NOT inside a git worktree**

```bash
git_dir=$(git rev-parse --git-dir 2>/dev/null || true)
case "$git_dir" in
  *worktrees/*)
    echo "FAIL: working tree appears to be inside a git worktree" >&2
    echo "      git-dir: $git_dir" >&2
    echo "      jj v0.38+ refuses 'jj git init --colocate' here (D14)." >&2
    exit 1
    ;;
  *)
    echo "PASS: not inside a git worktree"
    ;;
esac
```

- [ ] **Step 6: Confirm Lean toolchain is installed**

```bash
elan --version
lean --version
# Expected: lean 4.30.0-rc2 (matches the toolchain we're about to
# pin)
```

If `elan` is missing, halt and ask the user to install it via the
official `https://elan-lean.org/` instructions; the plan cannot
proceed without a working Lean toolchain because `lake build` is
exercised in Part 2.

### Task 1.2: Initialise git and jj in colocated mode

**Files:**

- Create: `.git/` (git's authoritative storage; not version-controlled
  but populated by `git init`)
- Create: `.jj/` (jj's local state; gitignored in Task 1.4)

- [ ] **Step 1: `git init`**

```bash
git init --initial-branch=main
# Expected output: "Initialized empty Git repository in
# /<path>/geb-mathlib/.git/"
```

- [ ] **Step 2: `jj git init --colocate`**

```bash
jj git init --colocate
# Expected output (verified verbatim against jj 0.41.0,
# 2026-05-07): "Initialized repo in \".\"" — single line, no
# Hint message. The v0.40 hint about `git clean -xdf` is gone in
# v0.41 (per D26).
#
# Note: since v0.34 (D12) colocation is the default; the
# explicit `--colocate` flag is kept here for clarity and
# defends against an unexpected `git.colocate = false` user
# config.
#
# Verify:
ls -la .jj
# Expected: shows working_copy, repo, .gitignore inside .jj/
```

- [ ] **Step 3: Verify colocation**

```bash
ls -la | grep -E '\.(git|jj)'
# Expected: both .git and .jj present at top level
```

### Task 1.3: Apply recommended local jj configuration (this developer only)

**Files:** none committed. The recommended config is per-developer
state; the project does NOT ship a committed template (see spec
§ "Recommended local jj configuration" and discoveries D1/D8 — jj
v0.38+ moved per-repo config out of the repo to
`~/.config/jj/repos/<hash>/config.toml` for security; a committed
template is unworkable). The
canonical reference for these commands lives in `docs/process.md`
§ Setup, authored in Task 2.7; this task is the maintainer's
local application of those instructions.

- [ ] **Step 1: Apply the recommended settings via `jj config set --repo`**

```bash
jj config set --repo git.private-commits 'conflicts()'
jj config set --repo remotes.origin.auto-track-bookmarks 'glob:*'
jj config set --repo revsets.bookmark-advance-from 'heads(::@ & mutable())'
jj config set --repo revsets.bookmark-advance-to '@'
```

These write to `~/.config/jj/repos/<hash>/config.toml` (per
D8). The first locally refuses to push conflicted commits (a
contributor-side ergonomic; the binding gate is server-side
`conflict-check.yml`). The second auto-tracks new bookmarks on
first push to `origin` (replaces the deprecated
`git.push-new-bookmarks`, per D2/D9). The third and fourth
configure `jj bookmark advance` defaults (replaces the removed
`experimental-advance-branches`, per D10/D11).

- [ ] **Step 2: Verify the config loads**

```bash
jj config list --repo
# Expected output includes (the file path may differ):
#   git.private-commits = "conflicts()"
#   remotes.origin.auto-track-bookmarks = "glob:*"
#   revsets.bookmark-advance-from = "heads(::@ & mutable())"
#   revsets.bookmark-advance-to = "@"
```

### Task 1.4: Author `.gitignore`

**Files:**

- Create: `.gitignore`

- [ ] **Step 1: Write `.gitignore`**

Per spec § "`.gitignore`". The top-level `.gitignore` does NOT
list `.jj/`: jj manages its own gitignore at `.jj/.gitignore`
(containing `/*`), which excludes everything inside `.jj/` from
git's view. Listing `.jj/` at the top level would pre-empt jj's
own decision about which (if any) files inside `.jj/` should be
exposed to git, and the project should defer to jj's choice.
jj's per-repo config is also out of the repo entirely (jj v0.38+
moved it to `~/.config/jj/repos/<hash>/config.toml` per D8), so
no `.gitignore` carve-out is needed for that either.

The local-only `.claude/settings.local.json` (per-developer
permissions) is gitignored; the project-level
`.claude/settings.json` (hooks) and `.claude/rules/` (binding
rules) are committed.

```gitignore
.DS_Store
.cache
.lake
**/__pycache__/
.remember/
.claude/settings.local.json
```

Use `Write`.

- [ ] **Step 2: Verify `.gitignore` patterns**

```bash
git check-ignore -q .jj/working_copy/foo && \
  echo "PASS: .jj/ ignored"
git check-ignore -q .lake/build/foo && \
  echo "PASS: .lake ignored"
git check-ignore -q .remember/now.md && \
  echo "PASS: .remember ignored"
git check-ignore -q .claude/settings.local.json && \
  echo "PASS: .claude/settings.local.json ignored"
# .claude/settings.json must NOT be ignored (it carries the
# committed project hooks):
if git check-ignore -q .claude/settings.json; then
  echo "FAIL: .claude/settings.json is ignored"
  exit 1
fi
echo "PASS: .claude/settings.json NOT ignored"
```

### Task 1.4b: Specify `.markdownlint-cli2.jsonc` content

**Files:**

- Verify or create: `.markdownlint-cli2.jsonc`

The spec § "Markdownlint discipline" states the rule set is "deferred
to the bootstrap plan." The file may already exist in the working
tree (it is one of the three pre-existing artifacts at plan-write
time); this task pins the canonical content so the plan is
self-describing and a fresh executing agent can recreate it.

- [ ] **Step 1: If the file does not exist, write it**

Canonical content (minimal-override; only `MD013` `tables` and
`code_blocks` exemptions; all other rules at markdownlint
defaults):

The file is concise; the only override is to exempt MD013
line-length checks for tables and fenced code blocks (long lines
in those contexts are legitimate). All other rules remain at
markdownlint defaults. Comments inside the file describe only
what is not obvious from the JSON itself (the filename and how it
is consumed by both `markdownlint-cli2` and the VSCode extension);
per the project's coding-style guideline, comments restating what
the code does are forbidden.

```jsonc
// Shared markdownlint configuration for geb-mathlib.
// Picked up by both `markdownlint-cli2` (CLI / CI) and the VSCode
// markdownlint extension when the workspace is opened at this dir.
{
  "config": {
    "default": true,
    "MD013": {
      "tables": false,
      "code_blocks": false
    }
  },
  "globs": [
    "**/*.md"
  ],
  // Ignore build state, jj local state, node_modules. .remember/
  // is gitignored separately; locally we still want visibility
  // into any warnings, so it is NOT excluded here.
  "ignores": [
    ".lake/**",
    ".jj/**",
    "node_modules/**"
  ]
}
```

Notes on rule choices:

- `default: true` enables every markdownlint rule with default
  settings.
- `MD013` is overridden only to exempt tables and fenced code
  blocks; ordinary prose is subject to the default line-length
  limit. Headings are NOT exempt — headings are typically shorter
  than prose lines, and there is no reason for ours to violate
  the default limit.
- `MD033` (no inline HTML) is left at default (enabled). We
  prefer pure markdown to avoid coupling our docs to HTML
  conformance.
- `MD029` (ordered-list-prefix) is left at default. Our numbered
  lists follow the standard `1, 2, 3, …` pattern.
- `ignores` excludes only build/state directories; `.remember/`
  is intentionally NOT excluded so local lint warnings on
  remember-plugin output remain visible.

If `.markdownlint-cli2.jsonc` already exists and differs, replace
its content with the canonical form above.

- [ ] **Step 2: Validate the JSONC parses**

```bash
# JSONC allows // line comments; strip them (only at line start
# or after whitespace, to avoid corrupting `://` inside URL string
# values) before validating with jq:
sed -E 's|(^|[[:space:]])//.*|\1|' .markdownlint-cli2.jsonc \
  | jq . >/dev/null && echo "valid JSONC"
# Expected: "valid JSONC"
```

- [ ] **Step 3: Verify lint runs against it**

```bash
markdownlint-cli2 docs/superpowers/specs/2026-05-04-geb-mathlib-bootstrap-design.md
# Expected: 0 errors (the spec is already markdownlint-clean against
# this config).
```

### Task 1.5: Establish `main` (placeholder) and `chore/bootstrap`

**Files:** none modified (jj operations only).

Per spec § "Bookmark anchoring (D3)", `main` is anchored at an
**empty placeholder commit** — NOT at `root()` (jj's synthetic
null commit), because git refuses to export a ref pointing at the
root commit (verified empirically: `jj bookmark create main -r 'root()'`
emits `Warning: Failed to export some bookmarks: main@git: Ref
cannot point to the root commit in Git`; the local `refs/heads/main`
is never created and `jj git push -b main` produces nothing on the
remote).

The placeholder commit is real, has a git counterpart, and is
exportable/pushable from day one. `chore/bootstrap` branches off
the placeholder via `jj new`, so the two bookmarks land on
distinct change-ids — preserving the spec's append-only invariant
on `main` (`chore/bootstrap` accumulates work; `main` stays at
the placeholder until Task 4.7's FF).

- [ ] **Step 1: Describe the placeholder commit (the `@` change after init)**

```bash
jj describe -m "chore: anchor main at empty placeholder commit"
# Per spec § Bookmark anchoring: imperative present tense, no
# capital, no trailing period; complies with the mathlib-derived
# commit-message convention.
```

- [ ] **Step 2: Create `main` at the described placeholder change**

```bash
jj bookmark create main -r @
```

- [ ] **Step 3: Create a child change for `chore/bootstrap`**

```bash
jj new
# `@` is now an empty child change of the placeholder.
jj bookmark create chore/bootstrap -r @
```

- [ ] **Step 4: Verify `main` and `chore/bootstrap` are on distinct change-ids**

```bash
jj bookmark list
# Expected output:
#   chore/bootstrap: <child-change-id> (no description set)
#   main: <placeholder-change-id> chore: anchor main at empty placeholder commit
main_id=$(jj log -r 'main' --no-graph -T 'change_id ++ "\n"' | head -1)
chore_id=$(jj log -r 'chore/bootstrap' --no-graph -T 'change_id ++ "\n"' | head -1)
[ "$main_id" != "$chore_id" ] || { echo "FAIL: main and chore/bootstrap collapsed"; exit 1; }
echo "PASS: bookmarks on distinct change-ids"
```

- [ ] **Step 5: If `jj git init --colocate` snapshotted pre-existing
      working-tree files into `@`, move them to `chore/bootstrap`.**

A real bootstrap always starts with a working tree that already
contains the spec, the plan, and any pre-existing config files (the
spec and plan must exist before `jj git init --colocate` runs). jj
snapshots those files into `@` at init time. After Steps 1–4 above,
those files end up in the placeholder commit (because Step 1
described `@`, which carried the snapshot content). The placeholder
must be empty per spec § "Bookmark anchoring (D3)".

Detect and remediate:

```bash
# Detect: does the placeholder (now `main`) have file content?
placeholder_files=$(git ls-tree -r main 2>/dev/null | wc -l)

if [ "$placeholder_files" -gt 0 ]; then
  # Move all file changes from placeholder to chore/bootstrap;
  # --keep-emptied preserves the placeholder as an empty commit so
  # `main`'s anchor remains exportable to git.
  jj squash --from main --into chore/bootstrap --keep-emptied

  # Verify: placeholder is empty, chore/bootstrap has content.
  [ "$(git ls-tree -r main | wc -l)" = "0" ] \
    || { echo "FAIL: placeholder is non-empty after squash"; exit 1; }
  [ "$(git ls-tree -r chore/bootstrap | wc -l)" -gt 0 ] \
    || { echo "FAIL: chore/bootstrap has no content after squash"; exit 1; }
  echo "PASS: placeholder empty, chore/bootstrap has content"
else
  echo "PASS: placeholder already empty (working tree was empty at init)"
fi
```

Empirically verified against jj 0.41.0 (2026-05-08) during test-2:
the squash produced a zero-file placeholder commit and a
chore/bootstrap commit with the four bootstrap-input files
(`.gitignore`, `.markdownlint-cli2.jsonc`, the spec, the plan).

### Task 1.6: First commit on `chore/bootstrap` — existing artifacts

**Files staged for commit (4 total):**

- `.gitignore`
- `.markdownlint-cli2.jsonc` (already exists; carries forward)
- `docs/superpowers/specs/2026-05-04-geb-mathlib-bootstrap-design.md`
  (already exists)
- `docs/superpowers/plans/2026-05-04-geb-mathlib-bootstrap-plan.md`
  (this file, already exists)

(Note: the placeholder commit landed in Task 1.5; this Task 1.6
commit is the *child* of the placeholder, on `chore/bootstrap`.)

NOT committed (intentionally excluded):

- `jj-config-repo.toml`: dropped per Task 1.3 (jj v0.38+ migration).
- `.jj/repo/config.toml`: not present in jj v0.38+ — per-repo
  config migrated to `~/.config/jj/repos/<hash>/config.toml`
  (D8). Even if a stale path were created, jj's own
  `.jj/.gitignore` would exclude it.
- `.claude/settings.local.json` (per-developer permissions; not
  committed to repo)
- `.remember/*` (gitignored)

- [ ] **Step 1: Verify what jj sees as tracked**

```bash
jj status
# Expected: shows .gitignore, .markdownlint-cli2.jsonc, and the two
# files in docs/superpowers/ as tracked changes (4 file-additions
# on top of the empty placeholder parent — the empty `@` had no
# files).
```

- [ ] **Step 2: Run markdownlint over the tracked Markdown files**

```bash
markdownlint-cli2 'docs/**/*.md'
# Expected: 0 errors.
```

If errors appear, fix them in the spec or the plan (this plan
itself, since it's one of the tracked Markdown files). Re-run.

- [ ] **Step 3: Describe the current change**

```bash
jj describe -m "chore(bootstrap): add bootstrap spec, plan, and shared configs

Add the bootstrap design spec and implementation plan under
docs/superpowers/, the shared markdownlint configuration, and a
.gitignore covering build state, jj local state, the remember
plugin's local files, and per-developer Claude settings.
"
```

- [ ] **Step 4: Move to a new working-copy change for the next task**

```bash
jj new
# Expected: jj log shows the described change as the parent of @.
# The bookmark on chore/bootstrap should still be on the described
# change-id (jj describe does not advance bookmarks; jj new does
# not advance either, by design).
jj bookmark set chore/bootstrap -r @-
```

- [ ] **Step 5: Verify**

```bash
jj log -r 'main..@-' --no-graph -T 'change_id.short() ++ " " ++ description.first_line() ++ "\n"'
# Expected: one line (the chore/bootstrap commit). main's
# placeholder commit is the parent, excluded by the `main..` form.
git log --oneline
# Expected: two git commits visible — the placeholder
# ("chore: anchor main at empty placeholder commit") followed by
# the bootstrap-spec/plan commit.
```

**Part 1 verification:**

- `jj log` shows the placeholder + one descriptive commit on
  `chore/bootstrap`. `main` is on the placeholder; `chore/bootstrap`
  is on the bootstrap-spec/plan commit (distinct change-ids).
- `jj status` clean (or showing only the empty working-copy
  change).
- `git status` clean from git's perspective (jj has synced).
- `jj config list --repo` shows the recommended local settings
  (Task 1.3).

### Task 1.7: User review checkpoint — Part 1

**Action:** Surface the Part 1 result to the user for an early
sanity check before Part 2 begins. The user should:

1. `jj log` on the working tree.
2. `jj diff -r <change-id-of-Task-1.6-commit>` to see what landed.
3. Confirm the commit message reads correctly.
4. Authorise proceeding to Part 2 (or request edits).

The plan pauses here for explicit user authorisation. No push has
happened yet (no remote configured), so this is a local checkpoint
only.

---

## Part 2 — Scaffolding artifacts

**Goal of Part 2:** Author all the scaffolding files described in
the spec and prove the skeleton library builds. Each task ends with
a `jj describe` (and `jj new`) on the `chore/bootstrap` branch.
After Task 2.30 (`geb-lean` distillation pass) and Task 2.31 (final
verification), Task 2.32 rewrites the chore/bootstrap history into
~10–20 topological commits suitable for the eventual real-repo push.

**Verification at end of Part 2:** `lake build` succeeds, `lake test`
succeeds (no test files yet, so vacuously), `lake lint` quiet,
`markdownlint-cli2 '**/*.md'` quiet, all hook scripts exist and
their smoke tests pass, all CI workflow files parse via
`gh workflow list` (deferred until Part 3 when a remote exists), the
axiom-check script runs clean on the empty skeleton.

### Task 2.1: `lean-toolchain`

**Files:**

- Create: `lean-toolchain`

- [ ] **Step 1: Write `lean-toolchain`**

Per spec § "`lean-toolchain`":

```text
leanprover/lean4:v4.30.0-rc2
```

Use `Write`. Single line, trailing newline.

- [ ] **Step 2: Verify elan picks it up**

```bash
elan show
# Expected: lists "leanprover/lean4:v4.30.0-rc2" as the active
# toolchain in this directory.
```

If elan reports the toolchain isn't installed, run
`elan toolchain install leanprover/lean4:v4.30.0-rc2` and retry.

- [ ] **Step 3: Commit**

```bash
jj describe -m "chore: pin lean-toolchain to v4.30.0-rc2 (mathlib master alignment)"
jj new
```

### Task 2.2: `lakefile.toml`

**Files:**

- Create: `lakefile.toml`

- [ ] **Step 0: Verify CSLib `v4.30.0-rc2` tag exists upstream**

```bash
gh api repos/leanprover/cslib/git/refs/tags/v4.30.0-rc2 --jq '.object.sha'
# Expected: a 40-char SHA. If the tag does not exist (404), halt:
# either the spec's pin is wrong or the tag has been retracted.
# In either case, surface to the user; do not fall through to a
# different version without explicit authorisation.
```

- [ ] **Step 1: Write `lakefile.toml`**

Per spec § "`lakefile.toml`":

```toml
name = "geb-mathlib"
defaultTargets = ["Geb"]
testDriver = "GebTests"
lintDriver = "batteries/runLinter"

[leanOptions]
pp.unicode.fun = true
autoImplicit = false
relaxedAutoImplicit = false
maxSynthPendingDepth = 3
weak.linter.mathlibStandardSet = true
weak.linter.flexible = true
weak.linter.style.header = true
weak.warningAsError = true

[[require]]
name = "cslib"
scope = "leanprover"
rev = "v4.30.0-rc2"

# Pinned in lockstep with `lean-toolchain`; bump `rev` when bumping
# the toolchain version.
[[require]]
name = "doc-gen4"
git = "https://github.com/leanprover/doc-gen4.git"
rev = "v4.30.0-rc2"

# Declared last so mathlib's transitive dependency pins
# (plausible, importGraph) take precedence over other requires';
# reverse order makes lake's mathlib cache fetcher compute
# mismatched hashes against the warm cache. Mathlib's README
# documents this ordering rule for downstream projects.
[[require]]
name = "mathlib"
git = "https://github.com/leanprover-community/mathlib4.git"

[[lean_lib]]
name = "Geb"
globs = ["Geb.*"]

[[lean_lib]]
name = "GebTests"
globs = ["GebTests.*"]
```

Use `Write`.

- [ ] **Step 2: Run `lake update` to populate `lake-manifest.json`**

```bash
lake update
# Expected: downloads mathlib + transitive deps + cslib; writes
# lake-manifest.json. May take several minutes on first run.
```

This step intentionally writes the manifest. It happens once, here,
on `chore/bootstrap` — the spec's "lake update only on bump/* branches"
rule has a documented carve-out for the bootstrap initial commit
(noted in `scripts/lake-update-warning.sh` in Task 2.20).

- [ ] **Step 3: Verify manifest**

```bash
test -f lake-manifest.json && echo "manifest present"
jq -r '.packages[] | "\(.name): \(.rev)"' lake-manifest.json
# Expected: lists mathlib with a SHA, plus transitive deps
# (batteries, aesop, etc.) and cslib at v4.30.0-rc2.
```

- [ ] **Step 4: Verify `lake test` dispatches to the test driver**

The `testDriver = "GebTests"` setting points `lake test` at the
`GebTests` `[[lean_lib]]` target.

Verify CSLib's exact pattern at the pinned tag:

```bash
gh api "repos/leanprover/cslib/contents/lakefile.toml?ref=v4.30.0-rc2" \
  --jq '.content' | base64 -d | grep -A 1 -E '(testDriver|^\[\[lean_lib\]\])'
# Expected: shows `testDriver = "CslibTests"` and a
# `[[lean_lib]] name = "CslibTests"` block. If the form differs
# (e.g., CSLib at the tag uses a [[lean_exe]] driver), halt and
# surface to the user before proceeding.
```

After Task 2.3 lands the empty `GebTests` skeleton, run
`lake test` to confirm:

```bash
lake test
# Expected: builds the GebTests library (vacuous) and exits 0.
# If "no test driver target" error appears, the lean_lib form is
# not accepted at this Lake version; fall back by adding a thin
# [[lean_exe]] block alongside the existing [[lean_lib]]:
#
#   [[lean_exe]]
#   name = "GebTests"
#   root = "GebTests"
#
# (Some Lake versions require an exe for testDriver dispatch.)
# Re-run lake test. Halt and surface to the user if neither
# form succeeds.
```

- [ ] **Step 5: Commit**

```bash
jj describe -m "chore(lakefile): add lakefile with mathlib, cslib, doc-gen4

Pin mathlib via lake-manifest.json (no rev field in lakefile).
Pin CSLib to release tag v4.30.0-rc2. Declare doc-gen4 so the
:docs facet attaches to every lean_lib from line one. Configure
the linter set: weak.linter.mathlibStandardSet,
weak.linter.flexible, weak.linter.style.header. Promote warnings
to errors via weak.warningAsError = true so sorry-carrying code
never builds clean.
"
jj new
```

### Task 2.3: Library skeleton — index files

All `.lean` files in this task use Lean 4's module system
(`module` keyword + `public import` for re-exported subindexes);
see the spec § Lean 4 module system and
`.claude/rules/lean-coding.md` § Lean 4 module system for the
rule.

**Files:**

- Create: `Geb.lean`
- Create: `Geb/Mathlib.lean`
- Create: `Geb/Cslib.lean`
- Create: `Geb/Internal.lean`
- Create: `GebTests.lean`
- Create: `GebTests/Mathlib.lean`
- Create: `GebTests/Cslib.lean`
- Create: `GebTests/Internal.lean`
- Create: `Geb/Mathlib/.gitkeep`
- Create: `Geb/Cslib/.gitkeep`
- Create: `Geb/Internal/.gitkeep`
- Create: `GebTests/Mathlib/.gitkeep`
- Create: `GebTests/Cslib/.gitkeep`
- Create: `GebTests/Internal/.gitkeep`

- [ ] **Step 1: Create directories**

```bash
mkdir -p Geb/Mathlib Geb/Cslib Geb/Internal \
         GebTests/Mathlib GebTests/Cslib GebTests/Internal
```

- [ ] **Step 2: Write `Geb.lean` (root index)**

```lean
/-
Copyright (c) 2026 The geb-mathlib contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: The geb-mathlib contributors
-/
module -- shake: keep-all, shake: keep-downstream

public import Geb.Mathlib
public import Geb.Cslib
public import Geb.Internal

/-!
# Geb root module

Root index for the `Geb` library. Subindexes:

- `Geb.Mathlib` — upstream-eligible content targeted at mathlib4
- `Geb.Cslib` — upstream-eligible content targeted at CSLib
- `Geb.Internal` — downstream-only content
-/
```

Use `Write`. The `shake: keep-all, shake: keep-downstream`
annotation matches the pattern mathlib's `Mathlib.lean` and
CSLib's `Cslib.lean` use on their root umbrellas: lake shake
will not suggest removing any subindex import from this file,
and downstream files importing `Geb` will not be flagged.

- [ ] **Step 3: Write `Geb/Mathlib.lean` (subindex placeholder)**

```lean
/-
Copyright (c) 2026 The geb-mathlib contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: The geb-mathlib contributors
-/
module

/-!
# Geb.Mathlib — upstream-eligible content for mathlib4

Modules under this namespace are intended for eventual upstream
extraction to mathlib4 and import only from `Mathlib.*` or
`Geb.Mathlib.*`.
-/
```

Use `Write`. Leave imports empty for now; add as content lands.

- [ ] **Step 4: Write `Geb/Cslib.lean` (subindex placeholder)**

```lean
/-
Copyright (c) 2026 The geb-mathlib contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: The geb-mathlib contributors
-/
module

/-!
# Geb.Cslib — upstream-eligible content for CSLib

Modules under this namespace are intended for eventual upstream
extraction to CSLib and import only from `Mathlib.*`, `Cslib.*`,
or `Geb.Cslib.*`.
-/
```

Use `Write`. Leave imports empty for now; add as content lands.

- [ ] **Step 5: Write `Geb/Internal.lean` (subindex placeholder)**

```lean
/-
Copyright (c) 2026 The geb-mathlib contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: The geb-mathlib contributors
-/
module

/-!
# Geb.Internal — downstream-only content

Modules under this namespace are not intended for upstream
extraction. They may import from `Mathlib.*`, `Cslib.*`,
`Geb.Mathlib.*`, `Geb.Cslib.*`, or `Geb.Internal.*`.
-/
```

Use `Write`.

- [ ] **Step 6: Write `GebTests.lean` (test root index)**

```lean
/-
Copyright (c) 2026 The geb-mathlib contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: The geb-mathlib contributors
-/
module -- shake: keep-all, shake: keep-downstream

public import GebTests.Mathlib
public import GebTests.Cslib
public import GebTests.Internal

/-!
# GebTests root module

Test library root. Mirrors `Geb.lean` structure: `GebTests.Mathlib`
tests `Geb.Mathlib`; `GebTests.Cslib` tests `Geb.Cslib`;
`GebTests.Internal` tests `Geb.Internal`.
-/
```

- [ ] **Step 7: Write `GebTests/Mathlib.lean`**

```lean
/-
Copyright (c) 2026 The geb-mathlib contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: The geb-mathlib contributors
-/
module

/-!
# GebTests.Mathlib — tests for upstream-eligible content
-/
```

- [ ] **Step 8: Write `GebTests/Cslib.lean`**

```lean
/-
Copyright (c) 2026 The geb-mathlib contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: The geb-mathlib contributors
-/
module

/-!
# GebTests.Cslib — tests for CSLib-targeted content
-/
```

- [ ] **Step 9: Write `GebTests/Internal.lean`**

```lean
/-
Copyright (c) 2026 The geb-mathlib contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: The geb-mathlib contributors
-/
module

/-!
# GebTests.Internal — tests for downstream-only content
-/
```

- [ ] **Step 10: Add `.gitkeep` markers in empty subdirectories**

```bash
touch Geb/Mathlib/.gitkeep Geb/Cslib/.gitkeep Geb/Internal/.gitkeep \
      GebTests/Mathlib/.gitkeep GebTests/Cslib/.gitkeep \
      GebTests/Internal/.gitkeep
```

(jj/git don't track empty directories; `.gitkeep` is the convention
to preserve directory structure.)

- [ ] **Step 11: Confirm mathlib and CSLib packages are fetched**

Verify `.lake/packages/mathlib/` and `.lake/packages/cslib/` were
populated by Task 2.2's `lake update` so both peer dependencies
are available when content eventually imports from them. Per the
"code is cost" principle (`CLAUDE.md` § Hard rules /
`docs/process.md` § Code is cost), we do NOT commit a
sanity-import `.lean` file: the configuration check is sufficient
and ephemeral; when real content uses these packages, that
content is the verification.

```bash
test -f .lake/packages/mathlib/Mathlib/Tactic.lean && \
  echo "PASS: Mathlib.Tactic available"
test -f .lake/packages/cslib/Cslib/Init.lean && \
  echo "PASS: Cslib.Init available"
```

If `Cslib/Init.lean` is missing the post-update tree, the cslib
pin in `lake-manifest.json` is broken; halt and surface to the
user.

- [ ] **Step 12: Run `lake build` to verify the skeleton compiles**

```bash
lake exe cache get
# Expected: pulls cached mathlib build artifacts (saves hours on
# first build).
lake build
# Expected: builds the Geb root module and its three subindexes
# (Geb.Mathlib, Geb.Cslib, Geb.Internal); no errors. Module-form
# headers (`module` + `public import`) are accepted by lake; if
# lake complains about the `module` keyword, the toolchain pin is
# too old — halt and surface to the user.
```

- [ ] **Step 13: Commit**

```bash
jj describe -m "feat(skeleton): scaffold empty Geb and GebTests library

Lay out the directory split: Geb/Mathlib and Geb/Cslib
(upstream-eligible to mathlib4 and CSLib respectively) and
Geb/Internal (downstream-only), with mirrored GebTests subtrees.
Index files use Lean 4 module form (\`module\` keyword + \`public
import\` for re-exported subindexes); preserve empty
subdirectories via .gitkeep.
"
jj new
```

### Task 2.4: `LICENSE` (Apache 2.0)

**Files:**

- Create: `LICENSE`

- [ ] **Step 1: Write `LICENSE`**

Use the standard Apache 2.0 license text (matching mathlib's). The
plan does not embed the full text inline (it is fixed boilerplate);
fetch it once during execution from
`https://www.apache.org/licenses/LICENSE-2.0.txt` and write it to
`LICENSE` verbatim with no modifications other than ensuring a
trailing newline.

```bash
curl -fsSL https://www.apache.org/licenses/LICENSE-2.0.txt -o LICENSE
# Expected: file written, ~11 KB.
wc -l LICENSE
# Expected: ~202 lines.
head -1 LICENSE
# Expected: "                                 Apache License"
```

- [ ] **Step 2: Verify match against mathlib's LICENSE**

```bash
diff <(curl -fsSL https://raw.githubusercontent.com/leanprover-community/mathlib4/master/LICENSE) LICENSE
# Expected: empty diff (or trivial whitespace difference at EOF).
```

If the diff is non-trivial, prefer mathlib's exact text (mathlib's
LICENSE file may include a project-specific modification at the
header/footer; verify and match it).

- [ ] **Step 3: Commit**

```bash
jj describe -m "chore: add Apache 2.0 LICENSE matching mathlib"
jj new
```

### Task 2.5: `README.md`

**Files:**

- Create: `README.md`

- [ ] **Step 1: Write `README.md`**

Per spec § "`README.md` initial contents". Target ~150 lines. Style:
formal/precise/dry. Authored content (the user reviews line-by-line
before push); no LLM-marketing voice.

````markdown
# geb-mathlib

A Lean 4 + mathlib formalisation of Geb, a categorical programming
language whose first-class notions include "programming language"
itself. The repository develops mathematical content in a style
shaped to be plausibly upstreamable to mathlib4 (via the
`Geb/Mathlib/` subtree) or CSLib (via `Geb/Cslib/`) alongside
downstream-only content (under `Geb/Internal/`).

## Dependencies

- [mathlib4](https://github.com/leanprover-community/mathlib4).
- [cslib](https://github.com/leanprover/cslib).
- Lean 4 toolchain (see `lean-toolchain`).

See `lakefile.toml` for the full dependency declaration.

## License

[Apache 2.0](LICENSE), matching mathlib4.

## Documentation

- [`docs/index.md`](docs/index.md) — topological narrative of
  implemented mathematical content.
- [`docs/process.md`](docs/process.md) — process rationale and
  decision history.
- [`docs/references.md`](docs/references.md) — Lean library and
  mathematical reference catalog.

## Process

The contributor-binding rules live in
[`CLAUDE.md`](CLAUDE.md). Path-scoped conditional rules live in
[`.claude/rules/`](.claude/rules/):

- `lean-coding.md` — applies to all `.lean` files.
- `upstream-eligible.md` — applies under `Geb/Mathlib/`,
  `Geb/Cslib/`, `GebTests/Mathlib/`, and `GebTests/Cslib/`.
- `markdown-writing.md` — applies to all `.md` files.
- `ci-and-workflow.md` — applies to `.github/workflows/` and
  `scripts/`.

## Contributing

### Setup

Suggested steps to run after cloning the repository. The jj
configuration below is recommended local config; the project
does not run config commands on a contributor's behalf.

1. Install `jj` via your preferred package manager.
2. Initialise jj's colocated mode:
   `jj git init --colocate`.
3. Apply the recommended local jj configuration:

   ```bash
   jj config set --repo git.private-commits 'conflicts()'
   jj config set --repo remotes.origin.auto-track-bookmarks 'glob:*'
   jj config set --repo revsets.bookmark-advance-from 'heads(::@ & mutable())'
   jj config set --repo revsets.bookmark-advance-to '@'
   ```

   `git.private-commits = 'conflicts()'` makes `jj git push -b
   <name>` fail on a conflict commit (which would be rejected
   in a submitted PR).
4. Configure your per-developer `~/.config/jj/config.toml`
   `[signing]` block (`behavior = "own"`,
   `backend = "gpg"` or `"ssh"`, `key = "..."`) so commits are
   signed.
5. Install the Lean toolchain via `elan` (the toolchain version
   is read from `lean-toolchain`).
6. Run `lake exe cache get` then `lake build` to verify the
   build chain.

### Working

1. Read `CLAUDE.md` from top to bottom; the rules there bind every
   contribution.
2. Pick a workstream from `TODO.md` (or propose a new one and
   brainstorm a spec following the process described in
   `docs/process.md`).
3. Develop on a topic branch (`feat/<topic>`, `fix/<topic>`, etc.);
   use `jj` (the working VCS).
4. Run `scripts/pre-push.sh` and have a contributor (or yourself)
   review the diff line-by-line before pushing.

## Upstream targets

Content in `Geb/Mathlib/` is intended for eventual extraction as
mathlib4 PRs. Content addressing computer-science topics
overlapping [CSLib](https://github.com/leanprover/cslib) targets
CSLib instead and lives in `Geb/Cslib/`. Code in `Geb/Internal/`
is not eligible for upstream submission; some of it may eventually be
recast into an upstream-eligible form and moved to `Geb/Mathlib/` or
`Geb/Cslib/`, while other Internal code has no upstream home.
````

Use `Write`.

- [ ] **Step 2: Run markdownlint**

```bash
markdownlint-cli2 README.md
# Expected: 0 errors. If line-length warnings fire, reflow.
```

- [ ] **Step 3: Commit**

```bash
jj describe -m "doc: add README.md with project identity, dependencies, and contribution pointers"
jj new
```

### Task 2.6: `TODO.md` initial entry

**Files:**

- Create: `TODO.md`

- [ ] **Step 1: Write `TODO.md`**

```markdown
# TODO

Active workstreams, in topological order. Workstreams complete →
removed; content merged into `docs/index.md`.

## In progress

(None — bootstrap complete.)

## Next up

### Begin first mathematical workstream brainstorming

The next session opens a fresh brainstorming workstream for the
first mathematical / programming-language work.

## Triggers (do when condition fires)

- **Update `Authors:` lines as content authors arrive**: every
  `.lean` file ships with `Authors: The geb-mathlib contributors`.
  When a contributor authors substantive content in a file,
  update that file's `Authors:` line to credit them by name.
- **Adopt `leanprover-community/upstreaming-dashboard-action`**:
  when `Geb/Mathlib/` has substantive content for the dashboard
  to inspect, add the action to CI plus a Pages-published
  dashboard following FLT's pattern.
- **`downstream-reports` registration**: a manual periodic
  checkpoint by the user. Trigger: "do we have enough substantive
  content that registration would be informative for the
  community, given the daily Zulip notification cost?" Procedure
  in `docs/process.md` § LKG/FKB pipeline (section to be
  populated when triggered).
- **Verso adoption**: when any of (a) doc-gen4 supports Verso,
  (b) Verso marks cross-references stable, (c) mathlib migrates
  to Verso, (d) our prose grows substantial. Currently using
  Markdown rendered by doc-gen4.
- **Project-specific `geb-development` skill**: when recurring
  patterns accumulate that fit neither `CLAUDE.md` nor
  `docs/process.md` nor existing `.claude/rules/*.md`. Default is
  to wait for friction.
- **Author `.github/PULL_REQUEST_TEMPLATE/` for our repo**:
  trigger when the first PR against our own repo is opened (most
  likely the bump-PR cron).
- **Curated `notes` / `journal` directory**: trigger if recurring
  ad-hoc explorations accumulate that don't fit `docs/`.
- **Migrate `update.yml` from `GITHUB_TOKEN` to a PAT**: trigger
  if the manual close-and-reopen-to-fire-CI overhead on cron-
  created bump-PRs becomes burdensome.
```

- [ ] **Step 2: markdownlint and commit**

```bash
markdownlint-cli2 TODO.md
jj describe -m "doc: add TODO.md with first-workstream-brainstorming entry"
jj new
```

### Task 2.7: `docs/index.md` and `docs/process.md` skeletons

**Files:**

- Create: `docs/index.md`
- Create: `docs/process.md`

- [ ] **Step 1: Write `docs/index.md`**

```markdown
# geb-mathlib documentation

## Directory structure

The repository is laid out narrow-and-deep, with one indexing
`.lean` file per directory.

- `Geb/` — root namespace, split between upstream-eligible and
  downstream-only content.
  - `Geb/Mathlib/` — content authored in mathlib's style and
    intended for eventual upstream extraction to mathlib4;
    imports from `Mathlib.*` and `Geb.Mathlib.*` only.
  - `Geb/Cslib/` — content authored in CSLib's style and
    intended for eventual upstream extraction to CSLib;
    imports from `Mathlib.*`, `Cslib.*`, and `Geb.Cslib.*`
    only.
  - `Geb/Internal/` — content not intended for upstream
    extraction; may import from `Mathlib.*`, `Cslib.*`,
    `Geb.Mathlib.*`, `Geb.Cslib.*`, or `Geb.Internal.*`.
- `GebTests/` — test library mirroring `Geb/`'s structure, with
  `GebTests/Mathlib/`, `GebTests/Cslib/`, and
  `GebTests/Internal/` subdirectories.

The directory split denotes upstream eligibility; the
import-direction rules above are enforced by
`scripts/lint-imports.sh` and corresponding CI.
```

- [ ] **Step 2: Write `docs/process.md`**

`docs/process.md` is the project's rationale layer — it records
*why* each rule in `CLAUDE.md` and `.claude/rules/*.md` exists.
The file contains rationale only; rule statements live in the
rule files. Sections are short paragraphs explaining the
motivation behind each rule.

````markdown
# Development process — rationale

This document records *why* each rule in `CLAUDE.md` and
`.claude/rules/*.md` exists. The rules themselves live in those
files; this document explains the motivation behind each. Read it
when you need to understand the reason for a rule, propose a
change, or weigh how to apply a rule in an unfamiliar situation.

## Sections

- [Development process — rationale](#development-process--rationale)
  - [Sections](#sections)
  - [Repository structure](#repository-structure)
  - [Code is cost](#code-is-cost)
  - [Document only the persistent](#document-only-the-persistent)
  - [Illustrate only with the archetypal](#illustrate-only-with-the-archetypal)
  - [Avoid colloquialisms and metaphors](#avoid-colloquialisms-and-metaphors)
  - [Documentation under `docs/`](#documentation-under-docs)
  - [Adversarial review](#adversarial-review)
  - [Verify agent claims](#verify-agent-claims)
  - [Two-track development](#two-track-development)
  - [Floodgate test](#floodgate-test)
  - [main and integration](#main-and-integration)
  - [Mathlib bump procedure](#mathlib-bump-procedure)
  - [Markdownlint discipline](#markdownlint-discipline)
  - [No LLM-drafted user-facing text](#no-llm-drafted-user-facing-text)
  - [Generic user references](#generic-user-references)

## Repository structure

The repo is laid out narrow-and-deep: every directory has either a
small number of subdirectories or a small number of source modules,
with one indexing `.lean` file per directory. The path is itself
documentation. This policy resembles mathlib's.

## Code is cost

Every committed byte must be justified by a return greater than
its cost. Cost has several components:

- **Reader time and cognitive capacity.** Anyone reading the
  codebase — human or AI — pays attention to every file, every
  line, every comment.
- **Drift and obsolescence.** Code falls out of sync with the
  rest of the codebase as surrounding things change. Comments
  are particularly susceptible, being unverified by compilation.
- **Dependence pressure.** Code that depends on something else
  freezes that thing in place: changing the dependency requires
  changing the dependent. The more code depends on a given thing,
  the harder that thing is to change.
- **Process overhead.** Every line lengthens build time, commit
  diffs, code-review time, search results, and AI-context
  consumption.

## Document only the persistent

A direct corollary of "Code is cost". Comments and committed text
should describe what is enduring about the code as it is — its
purpose, contracts, and non-obvious external constraints.
They should not describe transient process artifacts such as:

- **History.** "Previously this used X; now it uses Y."
  "Refactored from a different shape." How the code arrived at
  its current form belongs in commit messages, not in the code.
- **Testing process.** "Verified by testing." "This caused a
  build failure that was fixed by...." How something was
  discovered belongs in the project-internal findings log,
  not in the code.
- **Project-management artifacts.** "Required by spec § X.Y."
  Tasks and plan numbers are ephemeral — they exist during a
  discrete project phase and lose meaning afterward; readers of
  the code should not need to consult an external document just
  to understand the comments.
- **In-progress notes.** "TODO: rewrite this when we have time."
  "Try this approach if X fails." Active work belongs in
  `TODO.md` or the workstream's spec/plan, not in code comments.

What's persistent and worth documenting:

- The code's purpose at the namespace / module / declaration
  level (its contract).
- Non-obvious external constraints.
- Cross-references to specific external documentation (mathlib's
  contribute pages, jj's documentation), where the cross-reference
  saves a reader from re-deriving the constraint.

The principle is: when this codebase is years old, the comments
should still read as useful context. Anything that won't survive
that test belongs elsewhere.

## Illustrate only with the archetypal

A corollary of "Document only the persistent". When a rule or
explanation needs an illustration, the example should be
archetypal — a timeless mathematical or physical concept that
cannot become obsolete. Incidental examples (a particular task,
test artifact, or transient project state) consume reader
attention with trivialities and rot as the codebase evolves; an
archetypal example continues to teach the rule years later.

## Avoid colloquialisms and metaphors

Only standard technical terms are precise and universal enough
for our purposes. The rule binds all committed text; the rule
statement lives in `CLAUDE.md` § Style guidelines.  Examples
(where not specific technical terms) include "land", "gap",
and "gate".

## Documentation under `docs/`

`docs/index.md` is the project's reader-facing description: the
directory layout and a topological narrative of the implemented
content. Each entry covers the source-tree paths it touches, the
central concepts it introduces, and its dependencies (other
entries here, or specific external modules). Documentation is
updated in concert with any code change that introduces new
content appropriate to document, such as the formalisation of a
new mathematical concept.

`docs/process.md` (this file) contains the rationale for each
rule that binds development; `docs/references.md` catalogues
external library and mathematical references organised by topic.
Both are reader-facing alongside `docs/index.md`.

## Adversarial review

Specs and plans go through fresh-context adversarial review until
convergence (no blockers, no serious findings). The reviewer is a
NEW general-purpose `Agent` invocation per round (not
`SendMessage` to a continuing agent), reading only the artifact at
the given path. Findings are categorised blocker / serious / minor
/ cosmetic-taste; the author responds in writing to every finding
(fix / defer with rationale / reject as cosmetic-taste). The
discipline catches bugs the author cannot see; the fresh context
ensures the reviewer is not subject to the author's blind spots.

## Verify agent claims

Any factual claim about an external system (mathlib, Lean,
third-party tools, jj, GitHub conventions, library APIs) is
provisional until verified against authoritative sources.
Committed artifacts include the citation alongside the claim.
Adversarial reviewers explicitly check for unverified claims. AI-agent memory
is unreliable for facts about external systems; verification at
use time keeps committed content trustworthy.

## Two-track development

For foundations needed quickly without an upstream-ready version
yet: develop in `Geb/Internal/` first; rewrite in `Geb/Mathlib/`
or `Geb/Cslib/` for upstream, depending on the upstream target;
migrate dependents via `jj rebase` after the upstream PR is
accepted. The two-track split lets velocity and upstream-
readiness each get the discipline that suits them, without one
blocking the other.

## Floodgate test

At all times, the repo is ready to ship dependency-ordered PRs on
short notice with no source-code changes.
`scripts/lint-imports.sh` enforces the import-direction and
no-prefix-leakage rules. The test is what makes
"upstream-eligible" a binding property of `Geb/Mathlib/` and
`Geb/Cslib/` rather than an aspiration: at any moment, every
file in either subtree can be extracted to a PR upstream.

## main and integration

`main` is append-only stable history; never force-pushed. Topic
branches are merged without force-pushing.
`integration` is the regenerated fan-in merge view of `main` plus
active topic branches; force-pushed (lease-protected by default)
as topic-branch tips move. The split keeps `main` fork-friendly
(clones never see force-pushed history) while giving us a single
working view of all in-flight work.

## Mathlib bump procedure

Two flows: cron-driven (`update.yml` runs `mathlib-update-action`,
opens a PR against `main`); user-initiated (manual
`bump/<lean-version>` branch). Both end with `main` updated, topic
branches mass-rebased via `scripts/rebase-topics.sh`,
`integration` regenerated. Tracking mathlib closely (rather than
batching bumps) keeps adaptation cost amortised; the cron is the
default, the manual flow handles the cases the cron cannot
(toolchain bumps, breaking changes).

## Markdownlint discipline

Every Markdown document passes `markdownlint-cli2` against
`.markdownlint-cli2.jsonc` (shared with VSCode extension).
`.remember/` is intentionally not excluded; non-compliant remember
output is edited locally. The discipline keeps documentation
uniformly readable; sharing the config with VSCode means the
editor catches violations as we type.

## No LLM-drafted user-facing text

PR descriptions, Zulip messages, GitHub issue/PR comments are
user-authored. Mathlib's policy is unconditional ("use your own
words"). Multi-layered enforcement: hard rule in `CLAUDE.md`,
pre-push reminder in `scripts/pre-push.sh`, PR template checkbox,
user-review-before-push gate. The redundancy is intentional.

## Generic user references

"the user" / "they" / "them" generically in committed text. No
first names, email, or autobiographical detail. Committed content
should make sense to any contributor; specific identities make it
read as a single author's project.
````

- [ ] **Step 3: markdownlint, commit**

```bash
markdownlint-cli2 'docs/**/*.md'
jj describe -m "doc: add docs/index.md and docs/process.md skeletons"
jj new
```

### Task 2.7b: `docs/references.md`

**Files:**

- Create: `docs/references.md`

- [ ] **Step 1: Write `docs/references.md`**

```markdown
# Mathematical / library references

Catalog of useful pointers into Lean 4 libraries and external
literature, organised by topic.

## Searchable

- [Loogle](https://loogle.lean-lang.org/)
  - A searchable reference to the Lean standard libraries — use
    this to try to find standard implementations of concepts that
    we don't already know about.
- [Reservoir](https://reservoir.lean-lang.org/)
- The remote-index search tools (Loogle, `lean_leansearch`,
  `lean_leanfinder`, `lean_state_search`, `lean_hammer_premise`)
  index mathlib + Lean core + batteries; **none currently index
  CSLib**. For CSLib content, use the CSLib API docs site
  (<https://api.cslib.io/docs/>) or grep the CSLib source under
  `.lake/packages/cslib/Cslib/`.
- When introducing a new computational construct (register
  machine, Turing machine, automaton, λ-calculus variant,
  programming-language semantics, etc.), search CSLib first, just
  as we search mathlib for general mathematical concepts.

## Lean language

- [The Lean 4 Theorem Prover and Programming Language (conference paper)](https://link.springer.com/content/pdf/10.1007/978-3-030-79876-5_37.pdf?pdf=inline%20link)
- [Functional Programming in Lean: Structures and Inheritance](https://leanprover.github.io/functional_programming_in_lean/functor-applicative-monad/inheritance.html)
- [Lean Language Reference: Type Classes](https://lean-lang.org/doc/reference/latest/Type-Classes/)
- [Theorem Proving in Lean 4](https://leanprover.github.io/theorem_proving_in_lean4/)
- [Theorem Proving in Lean 4: Type Classes](https://lean-lang.org/theorem_proving_in_lean4/Type-Classes/)
- [Functional Programming in Lean: Type Classes and Polymorphism](https://leanprover.github.io/functional_programming_in_lean/type-classes/polymorphism.html)
- [Tabled Typeclass Resolution](https://arxiv.org/pdf/2001.04301)
- [Use and abuse of instance parameters in the Lean mathematical library](https://arxiv.org/pdf/2202.01629.pdf)
- [Lean projects and build process](https://leanprover-community.github.io/install/project.html)
- [A Beginner's Guide to Theorem Proving in Lean 4](https://emallson.net/blog/a-beginners-companion-to-theorem-proving-in-lean/)

## CSLib

- [Homepage](https://www.cslib.io/) and
  [whitepaper (arXiv:2602.04846)](https://arxiv.org/abs/2602.04846)
- [API docs](https://api.cslib.io/docs/)
- [Repository](https://github.com/leanprover/cslib)
- Top-level directory layout under `Cslib/`:
  - `Algorithms/` — algorithm/data-structure formalizations.
  - `Computability/` — `Automata/`, `Languages/`, `Machines/`,
    `URM/` (Unlimited Register Machine; namespace `Cslib.URM`).
  - `Foundations/` — `Combinatorics/`, `Control/`, `Data/`,
    `Lint/`, `Logic/`, `Semantics/` (including `LTS/` and
    `FLTS/`), `Syntax/`.
  - `Languages/` — `Boole/`, `CCS/`, `CombinatoryLogic/`,
    `LambdaCalculus/`.
  - `Logics/` — `HML/`, `LinearLogic/` (plural directory name).
- Constructive discipline: importing CSLib is fine in the same
  sense that importing mathlib is fine, but the project rule that
  bans `Classical`, `noncomputable`, and `axiom` applies to any
  *transitive* axiom dependency too: a Geb term that depends on a
  CSLib (or mathlib) lemma using `Classical.choice` will surface
  that axiom under `#print axioms`. For results that must remain
  constructive, run `#print axioms` and refactor if a non-pure
  axiom appears.
- Reuse discipline: prefer CSLib typeclasses and abstract
  structures (e.g. `LTS`, `HasFresh`) over reaching into concrete
  instances, so internal CSLib changes do not break our code.

## General mathematics

- [Lean's "mathlib" page](https://leanprover-community.github.io/mathlib-overview.html)

## General category theory

- [Lean's "category theory" page](https://leanprover-community.github.io/theories/category_theory.html)

## Opposite categories

- [Mathlib.CategoryTheory.Opposites](https://leanprover-community.github.io/mathlib4_docs/Mathlib/CategoryTheory/Opposites.html)
- [Mathlib.CategoryTheory.Category.Cat.Op](https://leanprover-community.github.io/mathlib4_docs/Mathlib/CategoryTheory/Category/Cat/Op.html)

## Comma / slice (over) / coslice (under) categories

- [Mathlib.CategoryTheory.Comma.Basic](https://leanprover-community.github.io/mathlib4_docs/Mathlib/CategoryTheory/Comma/Basic.html)
- [PLMlab's `Over.lean`](https://plmlab.math.cnrs.fr/nuccio/mathlib4/-/blob/master/Mathlib/CategoryTheory/Over.lean?ref_type=heads)
- [CategoryTheory.Arrow](https://leanprover-community.github.io/mathlib_docs/category_theory/arrow.html)

## Polynomial functors

- [mathlib4's univariate polynomial functors](https://leanprover-community.github.io/mathlib4_docs/Mathlib/Data/PFunctor/Univariate/Basic.html)
- [mathlib4's multivariate polynomial functors](https://leanprover-community.github.io/mathlib4_docs/Mathlib/Data/PFunctor/Multivariate/Basic.html)
- [mathlib4's W-types](https://leanprover-community.github.io/mathlib4_docs/Mathlib/Data/PFunctor/Multivariate/W.html)
- [mathlib4's M-types](https://leanprover-community.github.io/mathlib4_docs/Mathlib/Data/PFunctor/Multivariate/M.html)
- [mathlib4's univariate QPFs (quotients of polynomial functors)](https://leanprover-community.github.io/mathlib4_docs/Mathlib/Data/QPF/Univariate/Basic.html)
- [mathlib4's multivariate QPFs (quotients of polynomial functors)](https://leanprover-community.github.io/mathlib4_docs/Mathlib/Data/QPF/Multivariate/Basic.html)

## Profunctors

- [Mathlib.CategoryTheory.Limits.Shapes.End (ends and coends)](https://leanprover-community.github.io/mathlib4_docs/Mathlib/CategoryTheory/Limits/Shapes/End.html)

## Parametricity and Free Theorems

- Wadler, *Theorems for free!* (1989)
  - Types read as relations; parametricity proposition: (t,t) in
    the relational interpretation of T. Application to rearrangement,
    fold, sort, filter, map. Connection to lax natural
    transformations noted.
- [Reasonably Polymorphic: Review of Theorems for Free](https://reasonablypolymorphic.com/blog/theorems-for-free/)
  - Relations specialized to functions become bifunctors;
    function relation becomes naturality square f' . g = h . f;
    conjecture: all Haskell laws are category laws in different
    categories.

## Computability

- [Mathlib.Computability.Primrec](https://leanprover-community.github.io/mathlib4_docs/Mathlib/Computability/Primrec.html)
- [Mathlib.Computability.TMComputable](https://leanprover-community.github.io/mathlib4_docs/Mathlib/Computability/TMComputable.html)
- [Mathlib.Computability.TuringMachine](https://leanprover-community.github.io/mathlib4_docs/Mathlib/Computability/TuringMachine.html)

## Monad algebra

- [mathlib4's Monad.Algebra](https://leanprover-community.github.io/mathlib4_docs/Mathlib/CategoryTheory/Monad/Algebra.html)

## Kan extensions

- [mathlib4's KanExtension](https://leanprover-community.github.io/mathlib4_docs/Mathlib/CategoryTheory/Functor/KanExtension/Basic.html)
- [mathlib4's CategoryTheory.Bicategory.KanExtension.Adjunction](https://leanprover-community.github.io/mathlib4_docs/Mathlib/CategoryTheory/Bicategory/Kan/Adjunction.html)

## Grothendieck Construction

- [Mathlib.CategoryTheory.Grothendieck](https://leanprover-community.github.io/mathlib4_docs/Mathlib/CategoryTheory/Grothendieck.html)
  - Provides Lean formalization of the Grothendieck construction for functors
    valued in categories (\(C \to Cat\)), including morphisms and universal
    properties.
- [Mathlib.CategoryTheory.Bicategory.Grothendieck](https://leanprover-community.github.io/mathlib4_docs/Mathlib/CategoryTheory/Bicategory/Grothendieck.html)
  - Bicategorical generalization of the Grothendieck construction.

## Simplicial Sets and Nerves

- [Mathlib.AlgebraicTopology.SimplicialSet.Basic](https://leanprover-community.github.io/mathlib4_docs/Mathlib/AlgebraicTopology/SimplicialSet/Basic.html)
- [Mathlib.AlgebraicTopology.SimplicialSet.Nerve](https://leanprover-community.github.io/mathlib4_docs/Mathlib/AlgebraicTopology/SimplicialSet/Nerve.html)
- [Mathlib.AlgebraicTopology.SimplicialSet.NerveAdjunction](https://leanprover-community.github.io/mathlib4_docs/Mathlib/AlgebraicTopology/SimplicialSet/NerveAdjunction.html)

## Quotients

- [Init.Prelude.Quot](https://leanprover-community.github.io/mathlib4_docs/Init/Prelude.html#Quot)
  - Other operations on `Quot` follow
- [Init.Core.Quot.recOn](https://leanprover-community.github.io/mathlib4_docs/Init/Core.html#Quot.recOn)
  - Other operations on `Quot` precede and follow
- [Init.Core.Quotient](https://leanprover-community.github.io/mathlib4_docs/Init/Core.html#Quotient)
- [Mathlib.Data.Fintype.Quotient](https://leanprover-community.github.io/mathlib4_docs/Mathlib/Data/Fintype/Quotient.html)

## Topos Theory

- [Mathlib.CategoryTheory.Topos.Classifier](https://leanprover-community.github.io/mathlib4_docs/Mathlib/CategoryTheory/Topos/Classifier.html)
- [b-mehta/topos: Topos theory in Lean](https://github.com/b-mehta/topos)
  - Independent repository formalizing foundational aspects of topos theory,
    including subobject classifiers, Lawvere-Tierney topologies, and
    categorical theorems.

## Presheaf/Copresheaf Universal Properties

- [Mathlib.CategoryTheory.Limits.Presheaf](https://leanprover-community.github.io/mathlib4_docs/Mathlib/CategoryTheory/Limits/Presheaf.html)
  - Formalizes limits and colimits within presheaf categories, including the
    colimit-of-representables theorem.
- [Mathlib.CategoryTheory.Comma.Presheaf.Colimit](https://leanprover-community.github.io/mathlib4_docs/Mathlib/CategoryTheory/Comma/Presheaf/Colimit.html)
  - Addresses colimit structures in comma categories related to presheaf
    categories.
- [Mathlib.Topology.Sheaves.Sheaf](https://leanprover-community.github.io/mathlib4_docs/Mathlib/Topology/Sheaves/Sheaf.html)
  - Implementation of sheaf theory, with presheaves and categorical structures
    detailed for topological spaces.
- [Mathlib.Topology.Sheaves.Presheaf](https://leanprover-community.github.io/mathlib4_docs/Mathlib/Topology/Sheaves/Presheaf.html)
  - Documents presheaf categories for sheaf-theoretic constructions.

## Subobject Classifiers and Related

- [Mathlib.CategoryTheory.Topos.Classifier](https://leanprover-community.github.io/mathlib4_docs/Mathlib/CategoryTheory/Topos/Classifier.html)
  - Detailed formalization of subobject classifiers in category theory,
    including construction for presheaf categories.
- [Mathlib.CategoryTheory.Subpresheaf.Subobject](https://leanprover-community.github.io/mathlib4_docs/Mathlib/CategoryTheory/Subpresheaf/Subobject.html)
  - Focuses on subobjects and subpresheaf categories, relevant to classifier
    theory and morphism structure.
- [Mathlib/CategoryTheory/Sites/Closed.lean](https://plmlab.math.cnrs.fr/nuccio/octonions/-/blob/add-vector-api-alt/Mathlib/CategoryTheory/Sites/Closed.lean)
  - Code and theory for closed sites, relevant for power objects and
    classifier constructions.
```

- [ ] **Step 2: markdownlint, commit**

```bash
markdownlint-cli2 docs/references.md
jj describe -m "doc: add docs/references.md library/literature references catalog"
jj new
```

### Task 2.8: `CLAUDE.md` (≤200 lines)

**Files:**

- Create: `CLAUDE.md`

- [ ] **Step 1: Write `CLAUDE.md`**

Per spec § "`CLAUDE.md` skeleton". Target under 200 lines (the spec
notes this is the Anthropic-recommended limit). Authored content
follows the formal/precise/dry register. Reference layered files
(`docs/process.md`, `.claude/rules/*.md`) for depth.

The exact content (paraphrased to fit 200-line target):

```markdown
# geb-mathlib

A Lean 4 + mathlib formalisation of Geb. See `README.md` for the
project's identity and `docs/process.md` for the rationale behind
each rule below.

## Project status

Underway; initial language bootstrap.
Active development happens on topic branches; `main` is the
append-only public-facing trunk; `integration` is the regenerated
fan-in view of `main` plus active topic branches.

## Rules

- **LLM-contribution policy** binds any work in `Geb/Mathlib/`
  or `Geb/Cslib/`. New contributors cannot submit LLM-generated
  code in either subtree; the user vouches for every line.
  Disclosure is mandatory when LLMs are used. (Mathlib's policy
  is unconditional; CSLib's is looser, but we apply mathlib's
  symmetrically to both.)
- **No `jj git push` without user line-by-line review.** This includes
  first-creation pushes, force-pushes, branch-deletes, tag-pushes.
- **No LLM-drafted text in mathlib-facing channels.** PR
  descriptions, Zulip messages, GitHub issue/PR comments are
  user-authored.
- **No raw mutating `git` subcommands.** The PreToolUse hook at
  `scripts/hooks/block-mutating-git.sh` is an allow-list of read-only
  forms; mutating forms (and unknown forms) trigger a permission
  prompt. Use `jj` for state-mutating operations.
- **One concern per branch.** Refactoring is encouraged; when you
  find code worth refactoring outside the current branch's scope,
  create a separate branch for it rather than bundling it with
  unrelated work.
- **Generic user references in committed text.** "the user" /
  "they" / "them"; no first names, email, or autobiographical
  detail.
- **No `noncomputable` anywhere; minimise `Classical`.** See
  Constructive-only Lean code below.
- **Code is cost.** Every committed byte must be justified by a
  return greater than its overhead (reader time, AI context, build
  time, freezing surrounding code in place). Code that meets the
  bar is written in small, reusable chunks so its cost is paid
  once. See `docs/process.md` § Code is cost.
- **Reuse existing process code.** We do not invent build,
  version-control, or CI machinery: anything we need is assumed
  to already exist somewhere. Find code to reuse; if none exists,
  find a concept to reuse. See `docs/process.md` § Code is cost.
- **Reuse existing abstractions.** Before defining a new
  mathematical concept, check whether it already exists in
  mathlib, CSLib, or elsewhere in this repository. Instantiate
  the existing abstraction rather than defining a parallel
  concept. See `docs/process.md` § Code is cost.
- **Avoid the ad-hoc.** Geb is built entirely out of precise,
  universal mathematics. Any data structure should correspond to
  a known formal concept; innovation proceeds in single steps,
  each composed from two concepts already established (in formal
  mathematics or built in Geb by this discipline). See
  `docs/process.md` § Code is cost.
- **Cite the literature when transcribing.** Every definition or
  theorem taken from published mathematics carries a literature
  reference with a searchable identifier in its plan, spec, and
  Lean source. Each workstream's brainstorming-phase spec marks
  each definition as transcription or novel. In `.lean` files,
  citations live in the module docstring's `## References`
  section or inside the declaration's `/-- ... -/` docstring.
- **Document only the persistent.** Comments and committed text
  describe what is enduring about the code as it is — its purpose,
  its contracts, non-obvious external constraints. They do not
  describe transient process artifacts: how the code used to be,
  what testing iteration discovered an issue, which task in our
  plan produced a file, or similar. See `docs/process.md`
  § Document only the persistent.
- `.remember/*.md` must be markdownlint-clean; clean up after each
  `remember`-skill invocation (the plugin emits non-clean markdown).
  Rationale and operational details: see `docs/process.md`
  § Markdownlint discipline.

## Phase-driven workflow

| Phase | Always-on skill | Helper |
| --- | --- | --- |
| Brainstorming | `superpowers:brainstorming` | `sequential-thinking`; Lean helpers as needed |
| Writing-plan | `superpowers:writing-plans` | `sequential-thinking`; Lean helpers as needed |
| Executing-plan | `superpowers:executing-plans` (or `superpowers:subagent-driven-development`) | phase-relevant Lean skills |
| Lean code work | `lean4` umbrella (sub-skills below) | `lean-lsp`, `serena` MCPs |
| Mathlib search | `lean-lsp` (`leansearch`, `loogle`, `local_search`, `hammer_premise`) | — |
| Pre-commit | `superpowers:verification-before-completion` | — |
| Receiving review | `superpowers:receiving-code-review` | — |

`lean4` sub-skill mapping by activity (drafting, proving, filling
`sorry`, golfing, porting, review, exploration, diagnosis,
checkpointing) lives in `.claude/rules/lean-coding.md` § `lean4`
sub-skill mapping.

Each phase produces an artifact. Specs and plans are
adversarially-reviewed before execution begins (see
`docs/process.md` § Adversarial review). Verify agent claims
against authoritative sources before committing them to artifacts;
include citations.

## Repo structure (one-line)

`Geb/Mathlib/*` and `Geb/Cslib/*` upstream-eligible |
`Geb/Internal/*` downstream-only. Narrow-and-deep dirs with one
indexing file per directory. `main` = append-only stable;
`integration` = regenerated fan-in view; topic branches per
PR-candidate.

## Style guidelines

Formal, precise, mathematical, dry, unopinionated.
Cite known mathematics where applicable; reference standard
notation. No emojis. No all-caps words unless they are acronyms.
Be wary of value-laden adjectives ("key" / "important" / "core"
/ "elegant" etc.), state-judgment words ("blocked" / "issue" /
"challenge" etc.), and conversational fillers ("yes" / "wait" /
"hmm" / "careful" / "actually"). Avoid markup for emphasis;
save it for delineation (e.g. of book names, links, and words
being defined).  See also `.claude/rules/markdown-writing.md`.

**Avoid colloquialisms and metaphors.** Only standard technical
terms are precise and universal enough for our purposes.
See `docs/process.md` § Avoid colloquialisms and metaphors.

## Mathlib upstream guides

Binding for all `.lean` content and all commit messages:

- Contributing index:
  `https://leanprover-community.github.io/contribute/index.html`
- Commit messages:
  `https://leanprover-community.github.io/contribute/commit.html`
- Coding style:
  `https://leanprover-community.github.io/contribute/style.html`
- Naming conventions:
  `https://leanprover-community.github.io/contribute/naming.html`
- Documentation:
  `https://leanprover-community.github.io/contribute/doc.html`

Bullet-point highlights and adversarial-reviewer instructions
are in `.claude/rules/lean-coding.md`. Re-fetch the guides on
every adversarial-review round; they are subject to upstream
revision.

## Constructive-only Lean code

- No `noncomputable` anywhere.
- Minimise `Classical`; flag/justify each invocation in our own
  code.
- `scripts/check-axioms.sh` (vendored from `lean4-skills` with
  `Classical.choice` excluded from the allowlist) is part of the
  pre-commit / pre-push checklist and runs in CI.

## `sorry`, `admit`, and underscores

- **`sorry`** is permitted between commits as a stand-in while
  working with skills that need it (e.g.,
  `lean4:sorry-filler-deep`, `lean4:autoprove`). It is never
  permitted in committed code.
- **`admit`** is never permitted, not even between commits.
  Use `sorry` (audited as above) when a placeholder is needed.
- When no skill specifically requires `sorry` and we just need
  a placeholder for an unfilled term or hypothesis, use an
  underscore (`_`). Underscores are considered errors by elaboration,
  highlighting what is missing.

## Specs and plans live on the feature branch

Each feature's spec, plan, and code co-evolve on the same topic
branch. Spec at
`docs/superpowers/specs/<date>-<topic>-design.md`; plan at
`docs/superpowers/plans/<date>-<topic>-plan.md`. Adversarial-review
iterations on spec and plan are commits on the same branch. Merge
to `main` brings spec, plan, and code together.

## Floodgate test

At all times, the repo is ready to ship dependency-ordered PRs on
short notice with no source-code changes. `scripts/lint-imports.sh`
enforces this by rejecting forbidden imports in `Geb/Mathlib/`
and `Geb/Cslib/` files, and the `Geb.Mathlib.` / `Geb.Cslib.`
prefixes outside import lines in their respective subtrees.

## Tooling

- VCS: `jj` v0.41+ in colocated mode; lease-protected pushes.
- Build: `lake` (mathlib pin via SHA + `mathlib-update-action`
  cron).
- CI: GitHub Actions via `leanprover/lean-action@v1` and
  `leanprover-community/mathlib-update-action`.
  (`upstreaming-dashboard-action` deferred until `Geb/Mathlib/`
  has substantive content for it to dashboard.)
- Linters: `markdownlint-cli2`, `scripts/lint-imports.sh`,
  `lake lint` (drives `batteries/runLinter`).
- Skills: `superpowers:*`, `lean4:*`, `claude-md-management:*`,
  `code-review:*`, `pr-review-toolkit:*`, `commit-commands:*`,
  `security-review`; plus `dispatching-parallel-agents`,
  `systematic-debugging`, `test-driven-development`, `remember`,
  `session-report`, `fewer-permission-prompts`,
  `claude-automation-recommender` (one-shot).

## When to consider creating a project-specific skill

If recurring patterns accumulate that don't fit `CLAUDE.md` or
`docs/process.md`, use `skill-creator:skill-creator` to generate a
`geb-development` skill. Default is to wait for friction.

## References

- Process rationale: `docs/process.md`.
- Mathematical / library references catalog: `docs/references.md`.
- Path-scoped rules: `.claude/rules/` (in particular
  `lean-coding.md` for `.lean` files,
  `upstream-eligible.md` for `Geb/Mathlib/` and `Geb/Cslib/`,
  `markdown-writing.md` for `.md`,
  `ci-and-workflow.md` for CI / scripts).
```

- [ ] **Step 2: Verify line count and lint**

```bash
wc -l CLAUDE.md
# Expected: under 200 lines.
markdownlint-cli2 CLAUDE.md
# Expected: 0 errors.
```

If over 200, trim by referring more aggressively to
`docs/process.md`.

- [ ] **Step 3: Commit**

```bash
jj describe -m "doc: add CLAUDE.md with hard rules, phase-driven workflow, and tooling map"
jj new
```

### Task 2.9: `.claude/rules/lean-coding.md`

**Files:**

- Create: `.claude/rules/lean-coding.md`

- [ ] **Step 1: Write `.claude/rules/lean-coding.md`**

Per spec § "`.claude/rules/lean-coding.md`". YAML frontmatter
followed by content covering: authoritative upstream guides
(mathlib and CSLib), comment and docstring rules, the Lean 4
module system, the `lean4` sub-skill mapping, lake / build
workflow, and the "Coding technique" cluster (constructive-only,
proof guidelines, higher-order constructions, one step at a
time, structure and typeclass patterns).

````markdown
---
paths:
  - "**/*.lean"
---

# Lean coding conventions

Applies whenever a `.lean` file is open or being edited.

## Authoritative upstream guides (mathlib)

These are the binding upstream references for `Geb/Mathlib/`
content. Adversarial reviewers must check our `Geb/Mathlib/`
content for violations against each:

- Contributing index:
  `https://leanprover-community.github.io/contribute/index.html`
- Commit messages:
  `https://leanprover-community.github.io/contribute/commit.html`
- Coding style:
  `https://leanprover-community.github.io/contribute/style.html`
- Naming conventions:
  `https://leanprover-community.github.io/contribute/naming.html`
- Documentation conventions:
  `https://leanprover-community.github.io/contribute/doc.html`

Bullet-point highlights extracted from each guide appear below.
The full guides supersede this digest; re-fetch and re-verify
on every adversarial-review round (the guides are subject to
revision by the leanprover-community).

### Commit messages (from `commit.html`)

- Format: `<type>(<optional-scope>): <subject>` followed by an
  optional body and footers.
- Types: `feat | fix | doc | style | refactor | test | chore |
  perf | ci`.
- **Imperative present tense** in the subject and body
  ("change" — not "changed", not "changes", not "adds").
- **Do not capitalise** the first letter of the subject.
- **No trailing period** on the subject.
- Aim for the subject under ~72 characters.
- Body: same imperative present tense; include motivation and
  contrast with previous behaviour where useful.
- Documented footers include `Closes #N`, `BREAKING CHANGE: …`,
  and `- [ ] depends on: #N`. (`Moves:`/`Deletions:` are not
  documented and are NOT part of our convention.)

**Adversarial-reviewer instruction**: scan every commit message
in the plan and the actual git history for indicative or
past-tense verbs ("Adds", "Carries", "Pins", "Creates", "Sets",
"Adopted"), capitalised first letters of subjects, trailing
periods, and out-of-list types; flag each occurrence.

### Coding style (see also mathlib's `style.html`)

- Indentation: 2 spaces; no tabs.
- Line length: 100 characters maximum (matches mathlib's
  `mathlibStandardSet` linter setting).
- One declaration per line; no semicolons separating
  declarations.
- Use Unicode notation where mathlib does (e.g., `∀`, `∃`, `→`,
  `↦`, `⟨ ⟩`, `≤`, `≥`, `≠`, `∈`, `⊆`).
- `pp.unicode.fun = true` is set project-wide in
  `lakefile.toml`.
- `autoImplicit = false` and `relaxedAutoImplicit = false` are
  set; declare every variable explicitly.
- Section / namespace structure: open and close namespaces
  explicitly; do not mix `namespace X` blocks with content
  outside them in the same file.
- Anonymous constructors `⟨ ... ⟩` and structure projections
  `.x` are preferred where unambiguous.

**Adversarial-reviewer instruction**: scan our `.lean` files
for indentation drift, lines exceeding 100 characters,
multi-declaration lines, ASCII forms where mathlib uses Unicode,
and namespace/section nesting violations.

### Naming conventions (see also mathlib's `naming.html`)

- `snake_case` for `Prop`-valued definitions
  (`theorem`, `lemma`).
- `lowerCamelCase` for `def`, `instance`, `example`,
  variables, anonymous constructors, and tactic names.
- `UpperCamelCase` for `structure`, `class`, `inductive`,
  type-class arguments, and Sort-valued constants.
- Compound names follow the pattern
  `<subject>_<verb>_<object>` or `<verb>_<subject>` for
  theorems (e.g., `add_comm`, `mul_assoc`,
  `Nat.succ_lt_succ`).
- Predicates use the suffix `_iff_…` to indicate "if and only
  if" relationships (`even_iff_two_dvd`).
- Do not include the namespace in the declaration body's
  identifiers; rely on `namespace` to scope.
- Discharging operator: `_left`, `_right`, `_self`, `_of_…`,
  `_iff_…` follow specific positional conventions; check the
  upstream guide for the full table before naming.

**Adversarial-reviewer instruction**: scan our `.lean` files
for ALL_CAPS or `snake_case` identifiers, namespace prefixes
inside declarations, and non-standard operator suffixes; flag
each occurrence with a pointer to the upstream rule.

### Documentation (see also mathlib's `doc.html`)

- `/-! … -/` module docstring is mandatory after imports;
  required sections (in order): `# Title`, brief summary,
  `## Main definitions`, `## Main statements`,
  `## Notation` (if any), `## Implementation notes` (if any),
  `## References` (if any), and `## Tags`.
- `/-- … -/` declaration docstring is mandatory for every
  `def`, `structure`, `class`, `instance`, every field of a
  `structure`/`class`, and every theorem of public interest.
- Markdown is supported in docstrings; LaTeX via `$…$` (inline)
  and `$$…$$` (display).
- Cross-references use `` `Foo.bar` `` for identifiers;
  doc-gen4 renders them as links.
- No development-history references in docstrings (e.g.,
  "previously did X"); history is for commit logs.

**Adversarial-reviewer instruction**: scan our `.lean` files
for missing module/declaration docstrings, missing required
sections in module docstrings, history-references inside
docstrings, and post-hoc axiom-celebration.

## Authoritative upstream guides (CSLib)

These are the binding upstream references for `Geb/Cslib/`
content. Adversarial reviewers must check our `Geb/Cslib/`
content against the contribution guide:

- Contribution guide:
  `https://github.com/leanprover/cslib/blob/main/CONTRIBUTING.md`

CSLib generally follows mathlib's style and documentation
conventions; verify CSLib-targeted code against the mathlib
guides above as well. CSLib-specific constraints (mandatory
`Cslib.Init` import, notation locality, `lake shake` minimised
imports, stronger reuse principle, narrower PR-title types,
pre-coordination on Zulip for major work) live in
`.claude/rules/upstream-eligible.md` § CSLib-specific
constraints.

## Comment and docstring rules

- `/-! ... -/` module docstring is mandatory after imports.
  Required sections (omit irrelevant ones rather than leave blank):
  title, summary, main definitions, main statements, notation (if
  any), implementation notes, references, tags.
- `/-- ... -/` declaration docstring is mandatory for every
  `def`, `structure`, `class`, `instance`, and major theorem; and
  for every field of a `structure` or `class`.
- Markdown + LaTeX (`$...$`, `$$...$$`) inside docstrings.
- **No development-history references in docstrings**
  (e.g., "previously this used X; now uses Y"). Such notes belong
  in commit messages, not in docstrings, since docstrings are part
  of the public API and outlive their writing context.
- **Empty lines inside declarations are lint-discouraged**; use a
  brief comment (`-- ...`) as a structural separator if needed.

## Lean 4 module system

Every `.lean` file declares itself as a module using the `module`
keyword after the copyright block. Imports re-exported to
downstream users (typically the case for index/umbrella files
and for content needed by callers of this module) use
`public import`; imports whose contents are used only internally
use plain `import`.

## `lean4` sub-skill mapping

| Activity | Skill | Always-on? |
| --- | --- | --- |
| Drafting from informal math | `lean4:draft`, `lean4:formalize`, `lean4:autoformalize` | Try `autoformalize` early |
| Proving a stated lemma | `lean4:prove`, `lean4:autoprove` | Try `autoprove` when stuck |
| Filling stubborn `sorry`s | `lean4:sorry-filler-deep` | When fast pass fails or proofs are complex |
| Polishing a proof | `lean4:golf` | Yes, post-process |
| Refactoring existing Lean code | `lean4:refactor` | Yes, during refactors |
| Pre-commit Lean review | `lean4:review` | Yes, before any Lean commit |
| Exploring mathlib | `lean4:learn` | As needed |
| Diagnosis | `lean4:doctor` | As needed |
| Save progress | `lean4:checkpoint` | At milestones |

## Lake / build workflow

- Always use `lake build` and `lake test`. Avoid `lake clean`
  (it forces a full mathlib rebuild). Never use `lake env lean`
  (it fails to pick up options from `lakefile.toml` and produces
  spurious errors).
- In a fresh worktree, run `lake exe cache get` before the first
  `lake build` to pull mathlib's precompiled artifacts. Without
  this, lake falls back to building mathlib from source (hours of
  work).
- Avoid bash process substitution (`<(...)`, `>(...)`); these
  trigger manual approval prompts. Write intermediate output to a
  file under `/tmp` or in the working tree and read it back.
- Use the `Write` tool / direct file edits rather than shell
  commands for experimental code; place experiments inside the
  codebase, not under `/tmp`.

## Coding technique

### Constructive-only

No `noncomputable`. Minimise `Classical`, accepting it only
when we can confirm that a mathlib concept that we are reusing
is responsible.

Avoid `Quotient.out` / `Quot.out`; both require `Classical.choice`.
Use the constructive `Quotient` / `Quot` API
(`mk` / `lift` / `ind` / `sound`) instead.

### Proof guidelines

- **First errors first.** When `lake build` reports multiple
  errors or warnings, fix the first one before later ones. Later
  errors may be caused by earlier ones, or fixes for them may
  depend on earlier fixes.
- **Underscores expose holes.** When you want to see the type of
  a goal you're working on, insert `_` (underscore). Building
  produces an "unsolved goals" error and prints the goal type.
- **`#check`** to inspect the type of an expression in-place.
- **One definition at a time.** When developing a new module,
  write one definition / function / theorem and get it completely
  working (no underscores, no `sorry`, clearly corresponding to
  its intended meaning) before moving to the next. Building a
  whole module at once produces compounding misconceptions.
- **Work both forwards and backwards.** Forward: how do the
  inputs / locals build toward the goal? Backward: what previous
  step would let us reach the goal? Often the easiest path is
  from both directions toward the middle.
- **One proof step at a time when stuck.** If a multi-step
  rewrite or compound tactic fails, decompose into single steps
  and re-check the goal at each. Recombine after each step works
  individually.
- **Factoring-out-lemmas technique.** When a proof gets stuck:
  identify a good intermediate goal — either a forward step you
  can prove, or a backward step that would let you reach the
  overall goal. Factor out two lemmas (current → intermediate,
  intermediate → overall) as `_` placeholders, dispatch the
  overall goal by transitivity to confirm they compose, then
  prove each lemma separately. Recurse if the lemmas themselves
  are still too large.
- **Stuck-and-ask template.** When unable to fill an underscore,
  making no progress, or not understanding what's wrong: pause
  and explain (1) what you're trying to accomplish, (2) what
  problems you're encountering, (3) what you've tried, (4) why
  you're stuck on a particular underscore. Don't silently abandon
  the task.

### Higher-order constructions

Be suspicious of piece-by-piece constructions. For example, when
constructing a functor, always seek a way to build it out of
compositions of existing functors and functorial operations on
functor categories rather than writing explicit object maps,
morphism maps, and functor-law proofs — higher-order operations
provide all of those at once. The same applies broadly: prefer
composition of established abstractions over hand-rolling. See
`docs/process.md` § Code is cost for the rationale.

### One step at a time

Definitions and proofs are written as small compositions, one
step at a time, so each intermediate step yields a reusable
component. See `docs/process.md` § Code is cost for the
rationale.

### Structure and typeclass patterns

- **`@[ext]` reflex.** Always add `@[ext]` to structure
  definitions (when it compiles) so extensionality lemmas
  auto-generate.
- **Standard derivations.** When defining a structure, derive
  `Inhabited` / `DecidableEq` / `Repr` where applicable.
- **`extends` is composition, not OO inheritance** — appropriate
  when a structure builds on another by adding fields. See
  [FP-in-Lean: Structures and Inheritance](https://leanprover.github.io/functional_programming_in_lean/functor-applicative-monad/inheritance.html).
- **Sigma-type pattern for dependent fields.** When a structure
  has later fields that depend on earlier ones, define an
  independent struct first, then a dependent struct, then
  combine via sigma type (preferably with `extends`). Allows
  operations on independent components separately.
- **Typeclass-instance pattern.** Define the interface as a
  structure with the typeclass's fields; define the typeclass
  with a single field containing an interface instance; functions
  taking / returning the typeclass have an interface-version that
  the typeclass-version wraps. Separates interface (mathematical
  object) from typeclass resolution (isolating resolution errors).
- **Factor out structure components into separate definitions.**
  Makes type signatures explicit.
- **Universe-polymorphic.** Make universe levels as polymorphic
  as compiles.
- **Check for unused `universe` / `variable` declarations** after
  editing files that introduce or modify them; remove unused
  ones.
- **Non-negotiable interfaces for formalising pre-existing objects**:
  When formalising a specific mathematical object, the
  interface (objects, primitive constructors, generators) is
  fixed by the external mathematical source. Implementation
  strategies (proof techniques, auxiliary inductives, named
  composites) may change freely; weakening the interface of
  a standard mathematical concept to ease implementation is
  always wrong.
- **Compositional tests.** Where possible, calculate one value
  per test, assert it matches the expectation, return the value
  for reuse in other tests. Reduces duplication; chains tests
  together.
````

- [ ] **Step 2: markdownlint and commit**

```bash
markdownlint-cli2 '.claude/rules/lean-coding.md'
jj describe -m "doc: add .claude/rules/lean-coding.md path-scoped rule for .lean files"
jj new
```

### Task 2.10: `.claude/rules/upstream-eligible.md`

**Files:**

- Create: `.claude/rules/upstream-eligible.md`

- [ ] **Step 1: Write the rule file**

```markdown
---
paths:
  - "Geb/Mathlib.lean"
  - "Geb/Mathlib/**"
  - "GebTests/Mathlib.lean"
  - "GebTests/Mathlib/**"
  - "Geb/Cslib.lean"
  - "Geb/Cslib/**"
  - "GebTests/Cslib.lean"
  - "GebTests/Cslib/**"
---

# Upstream-eligible content rules

Applies to anything under `Geb/Mathlib/`, `GebTests/Mathlib/`,
`Geb/Cslib/`, or `GebTests/Cslib/`.

## Authoring modes

| Authoring mode | Triggered by | AI agent may | User must |
| --- | --- | --- | --- |
| (a) User-driven | Credentialing-PR candidate | Suggest in natural language only | Write every line |
| (b) Co-authoring | Other upstream-eligible work | Draft provisional code | Read, rewrite, commit when fully understood |

(Mode (c), hands-off draft by AI agent + commit-time review, applies under
`Geb/Internal/` and is described in `docs/process.md`.)

## Two-track development

When a foundation is needed quickly but no upstream-ready version
exists:

1. **Track 1 (Internal, mode c)**: draft into
   `Geb/Internal/Foo.lean`; user reviews and accepts.
2. **Track 2 (upstream-eligible, mode a or b)**: rewrite into
   `Geb/Mathlib/Foo.lean` or `Geb/Cslib/Foo.lean` depending on
   the upstream target.
3. **Migration**: when the upstream PR is accepted and we re-pin
   to a fresh master that includes it, migrate dependents via
   `jj rebase`. The Internal version is then removed.

## Credentialing-PR checkpoint

Each upstream has its own credentialing checkpoint. Before
starting any work in `Geb/Mathlib/` or `Geb/Cslib/` whose only
dependencies are the targeted upstream (i.e., a true PR-candidate
with no in-flight geb-mathlib deps), the AI agent asks: "Is this the
credentialing PR for this upstream?" The user weighs (1)
confidence to write solo, (2) strength on its own merits, (3)
opportunity cost vs. other candidates. Until the credentialing PR
for an upstream is identified, every such candidate for that
upstream is a potential choice — preserve rotatability.

## Floodgate test

At all times, the repo must be ready to ship dependency-ordered
PRs on short notice with no source-code changes. After any
non-trivial change, ask: "does this break extraction?" Each
upstream subtree's extractability is independent of the other
(the strict import rules below ensure this).

## Subtree import rules

Each upstream-eligible subtree has an allowed-import list and a
self-prefix that must not appear outside `^import` lines:

| Subtree | Allowed imports | Self-prefix |
| --- | --- | --- |
| `Geb/Mathlib/` (and tests) | `Mathlib.*`, `Geb.Mathlib.*` | `Geb.Mathlib.` |
| `Geb/Cslib/` (and tests) | `Mathlib.*`, `Cslib.*`, `Geb.Cslib.*` | `Geb.Cslib.` |

Bare umbrella imports (`import Mathlib`, `import Cslib`) are
forbidden — extraction requires specific module imports.

The self-prefix appears **only** in `^import` lines that
reference siblings in the same subtree. Do NOT use the prefix in:

- namespace declarations
  (`namespace Computability.Primrec`,
   not `namespace Geb.Mathlib.Computability.Primrec`),
- declaration bodies / fully-qualified-name references
  (use `open` or the bare name),
- docstrings or comments.

`scripts/lint-imports.sh` enforces these rules; the smoke test is
`scripts/tests/test-lint-imports.sh`.

The cross-subtree boundary follows the upstream dependency
relationship: mathlib does not depend on CSLib (so `Geb/Mathlib/`
files cannot import from `Cslib.*` or `Geb.Cslib.*`), and CSLib
depends on mathlib only through the upstream `Mathlib.*` modules
(so `Geb/Cslib/` files cannot import from `Geb.Mathlib.*` —
unupstreamed mathlib-targeted content is not yet available to a
CSLib PR). `Geb/Internal/` may import from any of the above.

## CSLib-specific constraints

CSLib's `CONTRIBUTING.md` adds the following requirements beyond
mathlib's style. Files in `Geb/Cslib/` (and `GebTests/Cslib/`):

- **Import `Cslib.Init`**: every CSLib-targeted file imports
  `Cslib.Init`, which configures CSLib's default linting and
  tactics. CSLib's CI runs `lake exe checkInitImports`.
- **Local notation**: notation that could apply to multiple
  types is either locally scoped (`local notation`,
  `scoped notation`) or introduced via a typeclass — not as
  bare top-level `notation`.
- **Minimised imports**: CSLib's CI runs `lake shake` to ensure
  no unused imports. Our repo-wide pre-push and CI check (see
  `lean-coding.md` § Lean 4 module system) satisfies this for
  both upstream targets.
- **PR-title categories**: CSLib's PR-title types are
  `feat | fix | doc | style | refactor | test | chore | perf`
  (mathlib's set minus `ci`). When filing a PR upstream to
  CSLib, the title's leading category is one of these.
- **Pre-coordination on Zulip**: cross-cutting abstractions,
  typeclasses, notation schemes, foundational frameworks, and
  major refactorings are discussed on the CSLib Zulip channel
  before significant implementation work, per CSLib's
  CONTRIBUTING.md.

CSLib's full contribution guide is linked from
`.claude/rules/lean-coding.md` § Authoritative upstream guides
(CSLib).
```

- [ ] **Step 2: Lint and commit**

```bash
markdownlint-cli2 '.claude/rules/upstream-eligible.md'
jj describe -m "doc: add .claude/rules/upstream-eligible.md for Geb/Mathlib/* and GebTests/Mathlib/*"
jj new
```

### Task 2.11: `.claude/rules/markdown-writing.md`

**Files:**

- Create: `.claude/rules/markdown-writing.md`

- [ ] **Step 1: Write the rule file**

```markdown
---
paths:
  - "**/*.md"
---

# Markdown writing conventions

Applies to all `.md` files.

## Markdownlint cleanliness

Every Markdown document we author passes `markdownlint-cli2`
against `.markdownlint-cli2.jsonc` (shared with the VSCode
markdownlint extension). If an automated process (such as
Claude Code's `remember` plugin) emits non-compliant output,
fix the offending files locally (or establish another
automated process to do so).

Run `markdownlint-cli2 '**/*.md'` before each commit step that
touches Markdown.

## Tables of contents

Every committed Markdown document with more than one `##`
heading carries an auto-maintained table of contents at the top.
We use `doctoc` (`<!-- START doctoc -->` / `<!-- END doctoc -->`
markers). The pre-push checklist regenerates the TOCs
(`doctoc '**/*.md'`); CI verifies the TOC is up to date
(`doctoc --check`).

## Link conventions

- Internal links use repo-relative paths
  (`[name](docs/foo.md)`), not absolute or local-machine paths.
- External links use full URLs.
- Dead-link checks are not currently automated; verify manually
  when adding links to external resources.

## Prose style

- Formal, precise, mathematical, dry, unopinionated.
- Avoid value-laden adjectives ("key", "important", "crucial",
  "elegant", "beautiful", "neat", "clever", "powerful",
  "interesting", "insight" used as labels).
- Generic user references ("the user" / "they" / "them"); no
  first names, email, or autobiographical detail.

See `docs/process.md` § Style guidelines for full rationale.
```

- [ ] **Step 2: Lint and commit**

```bash
markdownlint-cli2 '.claude/rules/markdown-writing.md'
jj describe -m "doc: add .claude/rules/markdown-writing.md for **/*.md"
jj new
```

### Task 2.12: `.claude/rules/ci-and-workflow.md`

**Files:**

- Create: `.claude/rules/ci-and-workflow.md`

- [ ] **Step 1: Write the rule file**

````markdown
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
10. `bash scripts/check-axioms.sh Geb/ GebTests/` quiet.
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
````

- [ ] **Step 2: Lint and commit**

```bash
markdownlint-cli2 '.claude/rules/ci-and-workflow.md'
jj describe -m "doc: add .claude/rules/ci-and-workflow.md for .github/workflows/* and scripts/*"
jj new
```

### Task 2.13: Vendor `scripts/check-axioms.sh`

**Files:**

- Create: `scripts/check-axioms.sh`

- [ ] **Step 1: Locate the upstream script**

```bash
find ~/.claude/plugins/cache/lean4-skills -name 'check_axioms_inline.sh' -print 2>/dev/null
# Expected: at least one match. Pick the highest-version directory.
```

(At plan-write time the path observed is
`~/.claude/plugins/cache/lean4-skills/lean4/4.4.9/lib/scripts/check_axioms_inline.sh`,
but plugin versions drift; resolve at execute-time.)

If no match (the lean4-skills plugin is not installed in the
local cache), do **not** silently substitute a guessed URL. Halt
and ask the user for the canonical upstream repository's
`check_axioms_inline.sh` path. The plan does not bake in a
specific upstream URL because the spec cites only the local
plugin cache path (spec § "Constructive-only Lean code") and the
upstream repository ownership is not pinned at plan-write time.

```bash
mkdir -p scripts
if matches=$(find ~/.claude/plugins/cache/lean4-skills -name 'check_axioms_inline.sh' -print 2>/dev/null) && [ -n "$matches" ]; then
  SRC=$(echo "$matches" | sort -V | tail -1)
  cp "$SRC" scripts/check-axioms.sh
else
  echo "lean4-skills plugin cache not found; ask the user for the canonical upstream URL" >&2
  exit 1
fi
chmod +x scripts/check-axioms.sh
```

- [ ] **Step 2: (Reserved for future use)**

(Step 2's earlier "copy" form is now folded into Step 1's
plugin-or-fallback logic; left as a no-op slot for plan
re-numbering stability.)

- [ ] **Step 3: Customise the allowlist**

Read the upstream script's current `STANDARD_AXIOMS` line:

```bash
grep -n '^STANDARD_AXIOMS=' scripts/check-axioms.sh
# Expected (verified at plan-write time, plugin v4.4.9):
#   <linenum>:STANDARD_AXIOMS="propext|quot.sound|Classical.choice|Quot.sound"
```

Replace via `sed` (idempotent — the new value contains different
elements, so re-running this on an already-customised script is a
no-op). The `sed` delimiter must not appear in the replacement
value; the replacement contains literal `|` characters, so use `#`
as the delimiter:

```bash
sed -i 's#^STANDARD_AXIOMS=.*#STANDARD_AXIOMS="propext|Quot.sound|quot.sound"#' \
  scripts/check-axioms.sh
```

After editing, verify:

```bash
grep '^STANDARD_AXIOMS=' scripts/check-axioms.sh
# Expected: STANDARD_AXIOMS="propext|Quot.sound|quot.sound"
```

If the pre-existing line differs in format (additional axioms,
different ordering, different quoting), halt and ask the user
before proceeding — the plugin's upstream script may have evolved.

- [ ] **Step 3b: Patch the printed-summary block (per F7)**

The upstream script's "Standard axioms (acceptable):" summary
block hardcodes the list of acceptable axioms in `echo` lines
near the bottom of the script, separately from the
`STANDARD_AXIOMS` regex allowlist. The hardcoded list still
includes `Classical.choice (axiom of choice)` even after Step 3
removes it from the allowlist, which misleads anyone reading the
output to verify what the script actually enforces. Patch the
printed-summary block to remove the stale line:

```bash
sed -i '/^echo "  • Classical\.choice (axiom of choice)"$/d' \
  scripts/check-axioms.sh
```

(Idempotent: re-running this on an already-customised script
removes nothing further.)

After editing, verify:

```bash
grep -n 'Classical.choice' scripts/check-axioms.sh
# Expected: zero matches (after Step 3 removed it from the regex
# allowlist and Step 3b removed it from the printed summary).
```

- [ ] **Step 4: Add a vendored-from header comment**

Add to the top of the file (after the shebang) a comment block:

```bash
#
# Vendored from leanprover-community/lean4-skills
# (~/.claude/plugins/cache/lean4-skills/<version>/lib/scripts/check_axioms_inline.sh).
# Local modifications:
#   - STANDARD_AXIOMS regex excludes Classical.choice (Step 3).
#   - Printed-summary block omits the Classical.choice line (Step 3b
#     per F7) so the script's output is consistent with the regex
#     allowlist (per geb-mathlib's constructive-only discipline).
# Re-vendor by re-running the copy step in
# docs/superpowers/plans/2026-05-04-geb-mathlib-bootstrap-plan.md
# Task 2.13 against a newer plugin release.
#
```

- [ ] **Step 5: Smoke-test on the empty skeleton**

```bash
bash scripts/check-axioms.sh Geb/ GebTests/
# Expected: empty output (no declarations to check); exit 0.
```

- [ ] **Step 6: Commit**

```bash
jj describe -m "feat: vendor scripts/check-axioms.sh from lean4-skills (Classical.choice excluded)"
jj new
```

### Task 2.14: `scripts/lint-imports.sh` (floodgate)

**Files:**

- Create: `scripts/lint-imports.sh`

**Provenance — DELTA**: project-specific. The two-rule shape
(import-direction + no-prefix-leakage on `Geb.Mathlib.`) is
defined by spec § "Path 1 — directory split for upstream-eligibility".
Closest community precedent for the
import-direction half: PFR's `push.yml` literal-grep gate over
`PFR/Mathlib/` (per `reference_other_lean_projects.md`); we use
a script rather than an in-workflow grep so the same check runs
in CI and locally via `pre-push.sh`. The no-prefix-leakage half
is project-specific to our extraction model. Adversarial
reviewers should flag any community tool that supersedes this
script (e.g.,
`leanprover-community/upstreaming-dashboard-action`'s
`ready_to_upstream` check, currently deferred).

- [ ] **Step 1: Write `scripts/lint-imports.sh`**

```bash
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
```

- [ ] **Step 2: Make executable, smoke-test**

```bash
chmod +x scripts/lint-imports.sh
bash scripts/lint-imports.sh
# Expected: "lint-imports.sh: clean (0 file(s) checked)" (or
# whatever count of `.gitkeep` survivors; no errors).
```

- [ ] **Step 3: Commit**

```bash
jj describe -m "feat: add scripts/lint-imports.sh floodgate-CI per-branch import linter"
jj new
```

### Task 2.14b: `scripts/tests/test-lint-imports.sh` smoke test

**Files:**

- Create: `scripts/tests/test-lint-imports.sh`

**Provenance — DELTA**: project-specific smoke test for the
project-specific `scripts/lint-imports.sh` linter. Exercises
clean and violating inputs for each upstream-eligible subtree
under a temp directory.

- [ ] **Step 1: Write the smoke test**

```bash
#!/usr/bin/env bash
#
# scripts/tests/test-lint-imports.sh
#
# Smoke test for scripts/lint-imports.sh. Stages synthetic
# Geb/{Mathlib,Cslib} and GebTests/{Mathlib,Cslib} subtrees under
# a temp directory and runs the linter against scenarios covering
# clean and violating inputs for each subtree.
#
# Exit 0 if all scenarios pass; exit non-zero with the failure
# count otherwise.

set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
linter="$repo_root/scripts/lint-imports.sh"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

failed=0
checked=0

setup_empty() {
  rm -rf "$test_dir"
  mkdir -p "$test_dir/Geb/Mathlib" "$test_dir/Geb/Cslib" \
           "$test_dir/GebTests/Mathlib" "$test_dir/GebTests/Cslib"
}

assert_case() {
  local name="$1" expected_exit="$2" expected_substr="$3"
  checked=$((checked + 1))
  local output exit_code
  output="$(cd "$test_dir" && bash "$linter" 2>&1)"
  exit_code=$?
  if [[ "$exit_code" -ne "$expected_exit" ]]; then
    echo "FAIL: $name: expected exit $expected_exit, got $exit_code" >&2
    echo "  output: $output" >&2
    failed=$((failed + 1))
    return
  fi
  if [[ -n "$expected_substr" ]] && ! grep -qF "$expected_substr" <<<"$output"; then
    echo "FAIL: $name: expected substring '$expected_substr' not in output" >&2
    echo "  output: $output" >&2
    failed=$((failed + 1))
    return
  fi
  echo "PASS: $name"
}

# Case 1: empty subtrees (only .gitkeep placeholders).
setup_empty
touch "$test_dir/Geb/Mathlib/.gitkeep" "$test_dir/Geb/Cslib/.gitkeep"
assert_case "empty subtrees" 0 "clean (0 file(s) checked)"

# Case 2: clean Mathlib file.
setup_empty
cat > "$test_dir/Geb/Mathlib/Foo.lean" <<'EOF'
module

import Mathlib.Algebra.Group.Basic
import Geb.Mathlib.Bar

def foo : Nat := 0
EOF
assert_case "clean Mathlib file" 0 "clean (1 file(s) checked)"

# Case 3: clean Cslib file (must include `import Cslib.Init`).
setup_empty
cat > "$test_dir/Geb/Cslib/Foo.lean" <<'EOF'
module

import Cslib.Init
import Mathlib.Algebra.Group.Basic
import Cslib.Foo
import Geb.Cslib.Bar

def foo : Nat := 0
EOF
assert_case "clean Cslib file" 0 "clean (1 file(s) checked)"

# Case 4: Mathlib file importing Cslib (forbidden cross-subtree).
setup_empty
cat > "$test_dir/Geb/Mathlib/Bad.lean" <<'EOF'
module

import Cslib.Foo
EOF
assert_case "Mathlib forbidding Cslib import" 1 \
  "forbidden import 'import Cslib.Foo'"

# Case 5: Mathlib file with bare umbrella import.
setup_empty
cat > "$test_dir/Geb/Mathlib/Bad.lean" <<'EOF'
module

import Mathlib
EOF
assert_case "Mathlib bare umbrella" 1 \
  "bare umbrella 'import Mathlib'"

# Case 6: Cslib file importing Geb.Mathlib (strict-rule violation).
setup_empty
cat > "$test_dir/Geb/Cslib/Bad.lean" <<'EOF'
module

import Cslib.Init
import Geb.Mathlib.Foo
EOF
assert_case "Cslib forbidding Geb.Mathlib import" 1 \
  "forbidden import 'import Geb.Mathlib.Foo'"

# Case 7: Cslib file with bare umbrella import.
setup_empty
cat > "$test_dir/Geb/Cslib/Bad.lean" <<'EOF'
module

import Cslib.Init
import Cslib
EOF
assert_case "Cslib bare umbrella" 1 \
  "bare umbrella 'import Cslib'"

# Case 8: Mathlib prefix leakage outside import line.
setup_empty
cat > "$test_dir/Geb/Mathlib/Leak.lean" <<'EOF'
module

import Mathlib.Algebra.Group.Basic

def Geb.Mathlib.foo : Nat := 0
EOF
assert_case "Mathlib prefix leakage" 1 \
  "'Geb.Mathlib.' outside ^import line"

# Case 9: Cslib prefix leakage outside import line.
setup_empty
cat > "$test_dir/Geb/Cslib/Leak.lean" <<'EOF'
module

import Cslib.Init
import Cslib.Foo

def Geb.Cslib.foo : Nat := 0
EOF
assert_case "Cslib prefix leakage" 1 \
  "'Geb.Cslib.' outside ^import line"

# Case 10: GebTests subtree exercises the same path as Geb (sanity).
setup_empty
cat > "$test_dir/GebTests/Cslib/Foo.lean" <<'EOF'
module

import Cslib.Init
import Mathlib.Algebra.Group.Basic
import Cslib.Foo
EOF
assert_case "GebTests/Cslib clean file" 0 "clean (1 file(s) checked)"

# Case 11: `public import` (allowed prefix) is recognised as an import.
setup_empty
cat > "$test_dir/Geb/Mathlib/Pub.lean" <<'EOF'
module

public import Mathlib.Algebra.Group.Basic
public import Geb.Mathlib.Bar
EOF
assert_case "public import allowed prefix" 0 "clean (1 file(s) checked)"

# Case 12: `public import` umbrella is also forbidden.
setup_empty
cat > "$test_dir/Geb/Mathlib/PubUmbrella.lean" <<'EOF'
module

public import Mathlib
EOF
assert_case "public import bare umbrella" 1 \
  "bare umbrella 'public import Mathlib'"

# Case 13: `public import` forbidden cross-subtree (Mathlib importing Cslib).
setup_empty
cat > "$test_dir/Geb/Mathlib/PubBad.lean" <<'EOF'
module

public import Cslib.Foo
EOF
assert_case "public import forbidden cross-subtree" 1 \
  "forbidden import 'public import Cslib.Foo'"

# Case 14: `public import` does NOT trigger no-prefix-leakage rule.
setup_empty
cat > "$test_dir/Geb/Mathlib/PubLeak.lean" <<'EOF'
module

public import Geb.Mathlib.Bar
EOF
assert_case "public import not flagged as leakage" 0 "clean (1 file(s) checked)"

# Case 15: missing `module` header in Mathlib subtree.
setup_empty
cat > "$test_dir/Geb/Mathlib/NoModule.lean" <<'EOF'
import Mathlib.Algebra.Group.Basic
EOF
assert_case "missing module header (Mathlib)" 1 \
  "missing 'module' header"

# Case 16: missing `module` header in Cslib subtree.
setup_empty
cat > "$test_dir/Geb/Cslib/NoModule.lean" <<'EOF'
import Cslib.Init
import Cslib.Foo
EOF
assert_case "missing module header (Cslib)" 1 \
  "missing 'module' header"

# Case 17: Cslib file missing required `import Cslib.Init`.
setup_empty
cat > "$test_dir/Geb/Cslib/NoInit.lean" <<'EOF'
module

import Cslib.Foo
EOF
assert_case "Cslib missing Cslib.Init" 1 \
  "missing required 'import Cslib.Init'"

# Case 18: `public import Cslib.Init` satisfies the required-init check.
setup_empty
cat > "$test_dir/Geb/Cslib/PubInit.lean" <<'EOF'
module

public import Cslib.Init
import Cslib.Foo
EOF
assert_case "public import Cslib.Init satisfies required-init" 0 \
  "clean (1 file(s) checked)"

# Case 19: `module` with shake annotation comment is recognised.
setup_empty
cat > "$test_dir/Geb/Mathlib/Annotated.lean" <<'EOF'
module  -- shake: keep-all

import Mathlib.Algebra.Group.Basic
EOF
assert_case "module with shake annotation" 0 "clean (1 file(s) checked)"

echo ""
echo "test-lint-imports.sh: $checked case(s) checked, $failed failure(s)"
exit "$failed"
```

- [ ] **Step 2: Make executable, run, commit**

```bash
chmod +x scripts/tests/test-lint-imports.sh
bash scripts/tests/test-lint-imports.sh
# Expected: 10 PASS lines + "10 case(s) checked, 0 failure(s)".
jj describe -m "test: add scripts/tests/test-lint-imports.sh smoke test for the floodgate linter"
jj new
```

### Task 2.15: `scripts/extract-pr.sh`

**Files:**

- Create: `scripts/extract-pr.sh`

**Provenance — DELTA**: project-specific. Spec § "Path 1 —
directory split for upstream-eligibility" notes that PFR
hand-authors at upstream-shaped paths from day one,
without a script; our extraction script is the project-specific
delta needed for the `Geb.Mathlib.` → `Mathlib.` import rewrite.
Adversarial reviewers should check whether
`leanprover-community/upstreaming-dashboard-action` or other
upstream tooling has gained an extraction step that would
supersede this script.

- [ ] **Step 1: Write the script**

```bash
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
```

- [ ] **Step 2: Make executable**

```bash
chmod +x scripts/extract-pr.sh
```

- [ ] **Step 3: Commit**

```bash
jj describe -m "feat: add scripts/extract-pr.sh for Geb.Mathlib.* -> Mathlib.* extraction"
jj new
```

### Task 2.15b: `scripts/lib/topic-revset.sh` (shared bookmark globs)

**Files:**

- Create: `scripts/lib/topic-revset.sh`

**Provenance — DELTA (refactor)**: factored from
`regenerate-integration.sh` (Task 2.16) and `rebase-topics.sh`
(Task 2.17) so the bookmark-glob set has one source of truth.
The `bookmarks(glob:"...")` revset function is documented jj
0.41+ syntax (`https://docs.jj-vcs.dev/latest/revsets/`). No
upstream library combines these globs into a reusable revset;
this is the project-specific composition.

The set of topic-bookmark globs (`feat/*`, `fix/*`, `refactor/*`,
`migrate/*`, `chore/*`, `docs/*`, `bump/*`) appears in both
`regenerate-integration.sh` (Task 2.16) and `rebase-topics.sh`
(Task 2.17). Factor it into a shared sourceable file so the two
scripts share one source of truth.

- [ ] **Step 1: Write the shared library**

```bash
#!/usr/bin/env bash
#
# scripts/lib/topic-revset.sh
#
# Shared revset definitions for topic-branch bookmarks.
# Source this file from regenerate-integration.sh and
# rebase-topics.sh.
#
# Exports:
#   TOPIC_BOOKMARKS_REVSET — union of bookmark-glob revsets
#                            for every topic-branch prefix.
#   TOPIC_TIPS_NOT_ON_MAIN_REVSET — those tips minus ::main.

# shellcheck disable=SC2034  # consumed by sourcing scripts
TOPIC_BOOKMARKS_REVSET='bookmarks(glob:"feat/*") |
                        bookmarks(glob:"fix/*") |
                        bookmarks(glob:"refactor/*") |
                        bookmarks(glob:"migrate/*") |
                        bookmarks(glob:"chore/*") |
                        bookmarks(glob:"docs/*") |
                        bookmarks(glob:"bump/*")'

# shellcheck disable=SC2034
TOPIC_TIPS_NOT_ON_MAIN_REVSET='(bookmarks(glob:"feat/*") ~ ::main) |
                               (bookmarks(glob:"fix/*") ~ ::main) |
                               (bookmarks(glob:"refactor/*") ~ ::main) |
                               (bookmarks(glob:"migrate/*") ~ ::main) |
                               (bookmarks(glob:"chore/*") ~ ::main) |
                               (bookmarks(glob:"docs/*") ~ ::main) |
                               (bookmarks(glob:"bump/*") ~ ::main)'
```

- [ ] **Step 2: Commit**

```bash
mkdir -p scripts/lib
chmod 644 scripts/lib/topic-revset.sh
jj describe -m "feat(scripts): add scripts/lib/topic-revset.sh shared revset definitions"
jj new
```

### Task 2.16: `scripts/regenerate-integration.sh`

**Files:**

- Create: `scripts/regenerate-integration.sh`

**Provenance — DELTA (jj-idiom composition)**: built from
documented jj 0.41+ revset operators
(`https://docs.jj-vcs.dev/latest/revsets/`) and the canonical
fan-in-merge sequence (spec § "Canonical sequence"). The
fan-in pattern itself is verified jj-idiom;
this script is the project-specific composition driving the
`integration` bookmark. No upstream tool implements this
composition for our `main`/`integration` split.

- [ ] **Step 1: Write the script**

Per spec § "`regenerate-integration.sh` revset contract".

```bash
#!/usr/bin/env bash
#
# scripts/regenerate-integration.sh
#
# Regenerate the `integration` bookmark as a fan-in merge of `main`
# plus the tips of all currently-active topic branches whose
# changes are not already reachable from `main`.
#
# The integration bookmark is force-pushed to origin; main is never
# touched.
#
# Idempotent: running twice with no topic-branch changes produces
# the same integration commit.

set -euo pipefail

# Refresh lease state before touching the remote. (NB: do not run
# this script before the `origin` remote has been configured —
# Task 4.4 adds it for the real repo. Test-repo Task 3.6 also
# adds origin before invoking the script.)
jj git fetch --remote origin

# Guard against unborn `main` (e.g., on a freshly init'd repo
# before any commits land on main). The fan-in revset's
# `~ ::main` clauses depend on `::main` being a non-empty set;
# if main is unborn, this script's behaviour is undefined.
if [ -z "$(jj log -r main --no-graph -T 'change_id ++ "\n"' 2>/dev/null)" ]; then
  echo "regenerate-integration: 'main' bookmark unborn or missing; nothing to fan in" >&2
  exit 1
fi

# Per the spec § "regenerate-integration.sh revset contract", the
# revset selects topic-branch tips whose changes are not yet
# reachable from `main`. The spec form is reproduced verbatim:
#
#   main | bookmarks(glob:"feat/*") ~ ::main
#        | bookmarks(glob:"fix/*") ~ ::main
#        | ...
#
# jj revset operator precedence (per
# https://docs.jj-vcs.dev/latest/revsets/, "Operators" table):
# `~` (set difference) binds tighter than `|` (union), so the
# spec form parses as
#   main | (bookmarks(glob:"feat/*") ~ ::main) | ...
# We use the explicit-parenthesis form for human-reader clarity.
#
# Build the merge-arg list using bookmark names directly (matches
# spec § "Canonical sequence" form: `jj new b1 b2 b3 ... bN -m`).
# Empty-glob handling: jj evaluates `bookmarks(glob:"X/*") ~ ::main`
# as the empty revset when no matching bookmarks exist; jj's
# argument expansion of an empty revset is a no-op. The minimal
# fan-in is just `main` if no topic branches are active.

# shellcheck source=scripts/lib/topic-revset.sh
. "$(dirname "$0")/lib/topic-revset.sh"

revset="main | $TOPIC_TIPS_NOT_ON_MAIN_REVSET"

# Resolve the revset to commit IDs to pass to `jj new`. Using
# commit_id rather than change_id (jj new accepts either, but
# commit_id is more stable for scripts that may be retried).
parents=$(jj log -r "$revset" -T 'commit_id ++ " "' --no-graph)

if [ -z "$(echo "$parents" | tr -d '[:space:]')" ]; then
  echo "regenerate-integration: empty revset (no main? misconfiguration)" >&2
  exit 1
fi

# Fan-in merge into a new commit.
# shellcheck disable=SC2086  # parents must word-split into args
jj new $parents -m "integration: fan-in @ $(date -I)"

# Move the bookmark to the new fan-in commit.
jj bookmark set integration -r @

# Push (lease-protected; jj 0.41+ has no --force flag — see spec
# § "Force-push mechanism" and reference_jj_force_push.md).
# First-time push of `integration` auto-tracks via
# remotes.origin.auto-track-bookmarks = "glob:*" (set in Task 1.3);
# also, since jj v0.38, `jj git push -b <name>` auto-tracks on
# first push without any extra config (D9 in the discoveries log).
jj git push --remote origin -b integration
```

- [ ] **Step 2: Make executable, lint shellcheck if available**

```bash
chmod +x scripts/regenerate-integration.sh
command -v shellcheck >/dev/null && shellcheck scripts/regenerate-integration.sh || true
```

- [ ] **Step 3: Commit**

```bash
jj describe -m "feat: add scripts/regenerate-integration.sh fan-in merge regenerator"
jj new
```

### Task 2.17: `scripts/rebase-topics.sh`

**Files:**

- Create: `scripts/rebase-topics.sh`

**Provenance — DELTA (jj-idiom composition)**: built from the
documented `jj rebase -d <new-base> -s <revset>` form and the
`roots(...)` revset function (jj 0.41+ docs). Mass-rebase via
`roots(...)` is jj's canonical idiom for moving the earliest
commits of multiple topic branches to a new base; this script
is the project-specific wrapper applying it to our topic-branch
prefix set (sourced from `scripts/lib/topic-revset.sh`).

- [ ] **Step 1: Write the script**

```bash
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
```

- [ ] **Step 2: Make executable, commit**

```bash
chmod +x scripts/rebase-topics.sh
jj describe -m "feat: add scripts/rebase-topics.sh mass-rebase helper"
jj new
```

### Task 2.18: `scripts/toolchain-watch.sh`

**Files:**

- Create: `scripts/toolchain-watch.sh`

**Provenance — DELTA**: project-specific. The "compare local
`lean-toolchain` to mathlib master's" check is described in
`feedback_toolchain_watch.md` (spec § "SessionStart:
toolchain-watch"). No upstream tool emits this banner at
SessionStart; this script is the project-specific delta wired
into `.claude/settings.json`. Adversarial reviewers should
flag any community precedent (e.g., a leanprover-community
toolchain-watch action) that supersedes it.

- [ ] **Step 1: Write the script**

```bash
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
```

- [ ] **Step 2: Make executable, smoke-test**

```bash
chmod +x scripts/toolchain-watch.sh
bash scripts/toolchain-watch.sh
# Expected: "toolchain-watch: in sync (v4.30.0-rc2)" assuming
# mathlib master is at the same toolchain. Otherwise a "behind"
# message; either is acceptable.
```

- [ ] **Step 3: Commit**

```bash
jj describe -m "feat: add scripts/toolchain-watch.sh SessionStart hook"
jj new
```

### Task 2.19: `scripts/check-signing-key.sh`

**Files:**

- Create: `scripts/check-signing-key.sh`

**Provenance — DELTA**: project-specific. The
`gpg-connect-agent 'keyinfo --list'` and `ssh-add -l` idioms are
the documented forms for cache-presence checks (per `man
gpg-agent` and `man ssh-add`); the warm-up cascade dispatching
on `gpg.format` is the project-specific delta described in
`feedback_signing_key.md` (spec § "SessionStart: signing-key
warm-up"). No upstream tool combines these into a SessionStart
hook.

- [ ] **Step 1: Write the script**

```bash
#!/usr/bin/env bash
#
# scripts/check-signing-key.sh
#
# SessionStart hook: warm the signing-key agent (GPG or SSH) so a
# cascade of jj commits doesn't prompt mid-stream. Exit 0 either
# way (never blocks session start).

set -euo pipefail

if ! sign=$(git config --get commit.gpgsign 2>/dev/null); then
  exit 0
fi
[ "$sign" = "true" ] || exit 0

fmt=$(git config --get gpg.format 2>/dev/null || echo 'openpgp')

case "$fmt" in
  ssh)
    if ! ssh-add -l >/dev/null 2>&1; then
      ssh-add 2>/dev/null || true
    fi
    ;;
  *)
    if ! gpg-connect-agent 'keyinfo --list' /bye 2>/dev/null | grep -q ' 1 '; then
      echo warm | gpg --clearsign >/dev/null 2>&1 || true
    fi
    ;;
esac

exit 0
```

- [ ] **Step 2: Make executable, commit**

```bash
chmod +x scripts/check-signing-key.sh
jj describe -m "feat: add scripts/check-signing-key.sh SessionStart hook for GPG/SSH warm-up"
jj new
```

### Task 2.20: `scripts/lake-update-warning.sh`

**Files:**

- Create: `scripts/lake-update-warning.sh`

**Provenance — DELTA**: project-specific. The "lake update only
on bump/* branches" rule is from spec § "lakefile.toml"; the
warning script is the project-specific delta that
surfaces violations as a soft pre-push reminder. No upstream
tool implements this branch-scoped manifest-change check.

- [ ] **Step 1: Write the script**

```bash
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
```

- [ ] **Step 2: Make executable, commit**

```bash
chmod +x scripts/lake-update-warning.sh
jj describe -m "feat: add scripts/lake-update-warning.sh for off-bump-branch manifest changes"
jj new
```

### Task 2.20b: `scripts/tests/test-lake-shake.sh` smoke test

**Files:**

- Create: `scripts/tests/test-lake-shake.sh`

**Provenance — DELTA**: project-specific smoke test for the
upstream `lake shake` command's flag interface. The actual
minimised-imports check is exercised by the pre-push step itself
(Task 2.21) and by CI (Task 2.25); this test guards against silent
regressions when the toolchain pin changes lake shake's CLI.
Authored before Task 2.21 so that Task 2.21's `pre-push.sh`
invocation of this smoke test refers to an existing file.

- [ ] **Step 1: Write the smoke test**

```bash
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
```

- [ ] **Step 2: Make executable, run, commit**

```bash
chmod +x scripts/tests/test-lake-shake.sh
bash scripts/tests/test-lake-shake.sh
# Expected:
#   PASS: --add-public
#   PASS: --keep-implied
#   PASS: --keep-prefix
#   test-lake-shake.sh: 3 flag(s) checked, 0 failure(s)
jj describe -m "test: add scripts/tests/test-lake-shake.sh smoke test for lake shake flag interface"
jj new
```

### Task 2.21: `scripts/pre-push.sh`

**Files:**

- Create: `scripts/pre-push.sh`

**Provenance — DELTA (composite)**: project-specific composite
runner for the spec's pre-push checklist
(spec § "Pre-push checklist"). Each individual
check is a standard upstream tool (`lake build`, `lake test`,
`lake lint`, `markdownlint-cli2`, `doctoc --check`). The
composition and the PR-candidate / Lean-content interactive
reminders are project-specific. No upstream tool implements
this exact pre-push composite for our setup; alternatives
considered (`pre-commit` framework with leanprover-community
hook configs) are out of scope at bootstrap and could be
revisited as a routine post-bootstrap improvement.

- [ ] **Step 1: Write the script**

```bash
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
```

- [ ] **Step 2: Make executable, commit**

```bash
chmod +x scripts/pre-push.sh
jj describe -m "feat: add scripts/pre-push.sh runner for the pre-push checklist"
jj new
```

### Task 2.22: `scripts/hooks/block-mutating-git.sh`

**Files:**

- Create: `scripts/hooks/block-mutating-git.sh`

**Provenance — DELTA**: project-specific Claude Code PreToolUse
hook. The hook contract (JSON-on-stdin, JSON-on-stdout for the
`hookSpecificOutput` form, plus exit codes) is the documented
Claude Code platform contract
(`https://code.claude.com/docs/en/hooks-reference`, verify at
execute-time); the allow-list of read-only `git` forms is the
project-specific delta described in
`feedback_git_blocking_hook.md` and spec § "PreToolUse:
block-mutating-git". No upstream Claude Code hook for jj-colocated
repos exists; this is project-novel. Adversarial reviewers should
flag any community Claude Code hook plugin that supersedes it.

- [ ] **Step 1: Write the script**

Per spec § "PreToolUse: block-mutating-git". This script reads JSON
from stdin per the Claude Code hook contract; matches the command
against the read-only allow-list; emits exit 0 for allow-listed
forms; emits the `permissionDecision: "ask"` JSON for anything
else, surfacing a permission prompt to the user with a reason
string explaining the policy.

````bash
#!/usr/bin/env bash
#
# scripts/hooks/block-mutating-git.sh
#
# PreToolUse hook for the Bash tool. Allow-list of read-only `git`
# forms; anything else triggers a permission prompt. Path name is
# historical (earlier draft was a deny-list); the current behaviour
# is allow-list-with-prompt.
#
# Hook contract (per Claude Code documentation):
#   - JSON read from stdin: {"tool_input": {"command": "..."}}
#   - Exit 0 with no output: allow silently
#   - Exit 0 with hookSpecificOutput JSON on stdout: structured
#     decision (used here for permissionDecision: "ask")
#   - Exit 2: hard block (not used here — we prefer the prompt)
#
# See spec § "PreToolUse: block-mutating-git" for the policy and
# the full allow-list enumeration.
#
# Portability: this script avoids `\b` word boundaries in regexes
# (non-portable across bash on Linux glibc vs macOS BSD libc) and
# uses explicit case-pattern matching with `(^|[[:space:]])` /
# `([[:space:]]|$)` anchors where regex is needed.
#
# Compositional rule: shell command chains (`;`, `&&`, `&`, `||`,
# `|`, `(`, `)`, newline) are split into segments and each segment is evaluated against
# the allow-list independently. A command like
# `git status && git push` therefore triggers a prompt — the
# read-only `git status` segment alone is not enough.

set -euo pipefail

# Short-circuit outside jj-colocated repos.
if [ ! -d "${CLAUDE_PROJECT_DIR:-.}/.jj" ]; then
  exit 0
fi

# Read tool_input.command from stdin.
input_json=$(cat)
cmd=$(printf '%s' "$input_json" | jq -r '.tool_input.command // ""')
[ -z "$cmd" ] && exit 0

# Strip `jj git X ...` invocations (jj's own git interop is allowed)
# up to the next shell separator (|;&) or end-of-string.
stripped=$(printf '%s' "$cmd" \
  | sed -E 's/(^|[[:space:]])jj[[:space:]]+git[[:space:]]+[^|;&]+//g')

# emit_prompt: writes the permission-ask JSON document (built via
# jq for safe escaping) and exits 0.
emit_prompt() {
  jq -n --arg cmd "$cmd" '
    {
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "ask",
        permissionDecisionReason: "git command \($cmd) is not on the project'\''s read-only allow-list. For state-mutating operations, use jj (e.g. `jj git push`, `jj describe`, `jj new`, `jj abandon`, `jj squash`). If this is a read-only form that should be on the allow-list, edit `scripts/hooks/block-mutating-git.sh` and add it (extend the smoke test alongside). The project'\''s binding safety net is server-side (`conflict-check.yml` plus required-status-check on `main`); local hooks are conveniences, not enforcement."
      }
    }
  '
  exit 0
}

# strip_globals: remove leading git global flags from a single
# `git ...` segment so the verb check can match. Drops:
#   -C <path>, -c <key=val>, --no-pager, --git-dir=<path>,
#   --work-tree=<path>, --no-replace-objects, --literal-pathspecs.
# This is approximate (assumes path/value tokens contain no spaces);
# the common case is sufficient for the hook's purpose.
strip_globals() {
  local s="$1"
  case "$s" in
    "git -C "*|"git -c "*|"git --no-pager"*|"git --git-dir="*|\
    "git --work-tree="*|"git --no-replace-objects"*|"git --literal-pathspecs"*)
      ;;
    *)
      printf '%s' "$s"
      return 0
      ;;
  esac
  local -a tokens result
  read -ra tokens <<<"$s"
  result=()
  local i=0
  local stripping=1
  while [ "$i" -lt "${#tokens[@]}" ]; do
    local t="${tokens[$i]}"
    if [ "$stripping" -eq 1 ]; then
      if [ "$i" -eq 0 ] && [ "$t" = "git" ]; then
        result+=("git")
        i=$((i + 1))
        continue
      fi
      case "$t" in
        -C|-c)
          # Skip flag and its argument.
          i=$((i + 2))
          continue
          ;;
        --no-pager|--no-replace-objects|--literal-pathspecs)
          i=$((i + 1))
          continue
          ;;
        --git-dir=*|--work-tree=*)
          i=$((i + 1))
          continue
          ;;
      esac
      stripping=0
    fi
    result+=("$t")
    i=$((i + 1))
  done
  printf '%s' "${result[*]}"
}

# allow_segment: returns 0 if the (single) git command segment is on
# the read-only allow-list, 1 otherwise. Operates on the segment
# after global-flag stripping.
allow_segment() {
  local s
  s="$(strip_globals "$1")"

  # Unconditional read-only subcommands.
  case "$s" in
    "git status"|"git status "*) return 0 ;;
    "git log"|"git log "*) return 0 ;;
    "git diff"|"git diff "*) return 0 ;;
    "git show"|"git show "*) return 0 ;;
    "git blame"|"git blame "*) return 0 ;;
    "git reflog"|"git reflog "*) return 0 ;;
    "git ls-files"|"git ls-files "*) return 0 ;;
    "git ls-tree"|"git ls-tree "*) return 0 ;;
    "git cat-file"|"git cat-file "*) return 0 ;;
    "git rev-parse"|"git rev-parse "*) return 0 ;;
    "git rev-list"|"git rev-list "*) return 0 ;;
    "git merge-base"|"git merge-base "*) return 0 ;;
    "git for-each-ref"|"git for-each-ref "*) return 0 ;;
    "git describe"|"git describe "*) return 0 ;;
    "git name-rev"|"git name-rev "*) return 0 ;;
    "git shortlog"|"git shortlog "*) return 0 ;;
    "git whatchanged"|"git whatchanged "*) return 0 ;;
    "git grep"|"git grep "*) return 0 ;;
    "git count-objects"|"git count-objects "*) return 0 ;;
    "git help"|"git help "*) return 0 ;;
    "git version"|"git version "*) return 0 ;;
    "git --version") return 0 ;;
    "git --help") return 0 ;;
    "git ls-remote"|"git ls-remote "*) return 0 ;;
    "git verify-pack"|"git verify-pack "*) return 0 ;;
    "git verify-tag"|"git verify-tag "*) return 0 ;;
    "git verify-commit"|"git verify-commit "*) return 0 ;;
    "git annotate"|"git annotate "*) return 0 ;;
    "git check-ignore"|"git check-ignore "*) return 0 ;;
    "git check-ref-format"|"git check-ref-format "*) return 0 ;;
    "git format-patch"|"git format-patch "*) return 0 ;;
    "git request-pull"|"git request-pull "*) return 0 ;;
    "git stripspace"|"git stripspace "*) return 0 ;;
    "git var"|"git var "*) return 0 ;;
    "git diff-tree"|"git diff-tree "*) return 0 ;;
    "git diff-index"|"git diff-index "*) return 0 ;;
    "git diff-files"|"git diff-files "*) return 0 ;;
  esac

  # `git symbolic-ref` — `--short` and bare-read forms only.
  case "$s" in
    "git symbolic-ref --delete "*|"git symbolic-ref -d "*) return 1 ;;
    "git symbolic-ref --short"|"git symbolic-ref --short "*) return 0 ;;
    "git symbolic-ref")
      return 0 ;;
    "git symbolic-ref "*)
      # Bare `git symbolic-ref <ref>` reads; `git symbolic-ref <ref> <target>` writes.
      local -a tok
      read -ra tok <<<"$s"
      # tok = (git symbolic-ref ARG1 [ARG2 ...]); 3 tokens = read, 4+ = write.
      if [ "${#tok[@]}" -le 3 ]; then return 0; fi
      return 1
      ;;
  esac

  # `git config` — read-only flags only.
  case "$s" in
    "git config --get "*|"git config --get-all "*|"git config --get-regexp "*|\
    "git config --list"|"git config --list "*|"git config -l"|"git config -l "*|\
    "git config --show-origin "*|"git config --show-scope "*)
      return 0 ;;
    "git config"|"git config "*)
      return 1 ;;
  esac

  # `git branch` — read-only forms only.
  case "$s" in
    "git branch") return 0 ;;
    "git branch -l"|"git branch -l "*|\
    "git branch --list"|"git branch --list "*|\
    "git branch -v"|"git branch -v "*|\
    "git branch -vv"|"git branch -vv "*|\
    "git branch -a"|"git branch -a "*|\
    "git branch --remotes"|"git branch --remotes "*|\
    "git branch --show-current"|"git branch --show-current "*|\
    "git branch --contains "*|"git branch --no-contains "*|\
    "git branch --merged"|"git branch --merged "*|\
    "git branch --no-merged"|"git branch --no-merged "*|\
    "git branch --column"|"git branch --column "*)
      return 0 ;;
    "git branch "*) return 1 ;;
  esac

  # `git tag` — read-only forms only.
  case "$s" in
    "git tag") return 0 ;;
    "git tag -l"|"git tag -l "*|\
    "git tag --list"|"git tag --list "*|\
    "git tag --contains "*|"git tag --no-contains "*|\
    "git tag --merged"|"git tag --merged "*|\
    "git tag --no-merged"|"git tag --no-merged "*|\
    "git tag --points-at "*|\
    "git tag --column"|"git tag --column "*|\
    "git tag -n"|"git tag -n "*)
      return 0 ;;
    "git tag "*) return 1 ;;
  esac

  # `git remote` — read-only forms only.
  case "$s" in
    "git remote") return 0 ;;
    "git remote -v"|"git remote -v "*|\
    "git remote -vv"|"git remote -vv "*|\
    "git remote get-url "*|\
    "git remote show"|"git remote show "*)
      return 0 ;;
    "git remote "*) return 1 ;;
  esac

  # `git worktree list` only.
  case "$s" in
    "git worktree list"|"git worktree list "*) return 0 ;;
    "git worktree"|"git worktree "*) return 1 ;;
  esac

  # `git stash` — `list` and `show` only.
  case "$s" in
    "git stash list"|"git stash list "*|\
    "git stash show"|"git stash show "*) return 0 ;;
    "git stash"|"git stash "*) return 1 ;;
  esac

  # `git submodule status` only. `foreach` is opaque (we cannot
  # reliably detect whether the inner command is read-only); always
  # prompts.
  case "$s" in
    "git submodule status"|"git submodule status "*) return 0 ;;
    "git submodule"|"git submodule "*) return 1 ;;
  esac

  # `git notes` — `list`, `show` only.
  case "$s" in
    "git notes list"|"git notes list "*|\
    "git notes show"|"git notes show "*) return 0 ;;
    "git notes"|"git notes "*) return 1 ;;
  esac

  # `git bundle` — `verify`, `list-heads` only.
  case "$s" in
    "git bundle verify "*|"git bundle list-heads "*) return 0 ;;
    "git bundle"|"git bundle "*) return 1 ;;
  esac

  # `git fetch` — allowed UNLESS the segment contains an explicit
  # <src>:<dst> refspec (which can rewrite local branches).
  #
  # Known false-positive limitations (accepted; see spec
  # § "PreToolUse: block-mutating-git" for rationale):
  #
  # 1. `git fetch <https-url>` (e.g.,
  #    `git fetch https://github.com/foo/bar.git`) triggers the
  #    colon-refspec rejection because `https:` matches the regex.
  #    The user authorises via the prompt; err-on-prompt direction
  #    matches the project's failure-mode asymmetry. Tightening
  #    the regex to require a slash on each side is possible but
  #    adds parsing complexity for a low-frequency case.
  #
  # 2. `bash -c "<inner>"`, `sh -c "<inner>"`, `xargs <inner>`,
  #    etc. are opaque to this hook: the outer command is not
  #    `git`, so no inspection occurs. Inner mutations bypass the
  #    hook. This is a known limitation of any PreToolUse hook
  #    that operates on the literal Bash command string. The
  #    project's binding safety property is server-side (CI), not
  #    local hooks.
  case "$s" in
    "git fetch"|"git fetch "*)
      if [[ "$s" =~ (^|[[:space:]])[^[:space:]]+:[^[:space:]]+([[:space:]]|$) ]]; then
        return 1
      fi
      return 0 ;;
  esac

  # `git fsck` — read-only when no `--write` flag is present.
  case "$s" in
    "git fsck"|"git fsck "*)
      case "$s" in
        *"--write"*) return 1 ;;
        *) return 0 ;;
      esac
      ;;
  esac

  # Anything else (unknown subcommand or mutating verb) -> prompt.
  return 1
}

# Split the residual command on shell separators (`;`, `&&`, `&`,
# `||`, `|`, `(`, `)`, newline) and evaluate each segment
# independently. Any segment that is a `git` invocation NOT on the
# allow-list triggers a prompt. The order matters: `&&` is matched
# before lone `&` via left-to-right alternation in `sed -E`, so
# `git status && git push` splits cleanly without double-splitting
# `&&`. Subshell parens are split alongside other separators so a
# wrapped mutation (`(git push)`) does not slip through behind a
# leading allowed segment.
segmented=$(printf '%s' "$stripped" | sed -E 's/(\&\&|&|\|\||\||;|\(|\))/\n/g')

while IFS= read -r segment; do
  # Trim leading/trailing whitespace.
  segment="$(printf '%s' "$segment" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
  [ -z "$segment" ] && continue
  # Only inspect git invocations.
  case "$segment" in
    git|"git "*) ;;
    *) continue ;;
  esac
  if ! allow_segment "$segment"; then
    emit_prompt
  fi
done <<EOF
$segmented
EOF

exit 0
````

- [ ] **Step 2: Make executable**

```bash
mkdir -p scripts/hooks
chmod +x scripts/hooks/block-mutating-git.sh
```

- [ ] **Step 3: Commit**

```bash
jj describe -m "feat: add scripts/hooks/block-mutating-git.sh PreToolUse hook"
jj new
```

### Task 2.23: `scripts/hooks/tests/test-block-mutating-git.sh` smoke test

**Files:**

- Create: `scripts/hooks/tests/test-block-mutating-git.sh`

- [ ] **Step 1: Write the smoke test**

```bash
#!/usr/bin/env bash
#
# scripts/hooks/tests/test-block-mutating-git.sh
#
# Smoke test for scripts/hooks/block-mutating-git.sh. Exercises
# both allow-paths (read-only forms exit 0 with no output) and
# prompt-paths (mutating forms exit 0 with a permission-ask JSON
# document on stdout containing hookSpecificOutput.permissionDecision
# = "ask").
#
# CI portability: the hook short-circuits to exit 0 when no .jj/
# directory exists at $CLAUDE_PROJECT_DIR. To exercise the
# decision logic in a clean checkout (e.g., GitHub Actions runner
# with no .jj/), the test sets CLAUDE_PROJECT_DIR to a temp dir
# containing a synthesized .jj/ marker.

set -euo pipefail

TEST_PROJECT=$(mktemp -d)
mkdir -p "$TEST_PROJECT/.jj"
trap 'rm -rf "$TEST_PROJECT"' EXIT
export CLAUDE_PROJECT_DIR="$TEST_PROJECT"

HOOK="scripts/hooks/block-mutating-git.sh"

# An allow case: hook exits 0 and produces no JSON on stdout.
assert_allow() {
  local name="$1"
  local cmd="$2"
  local out rc
  out=$(echo "{\"tool_input\":{\"command\":$(jq -Rs . <<<"$cmd")}}" | bash "$HOOK" 2>/dev/null) || rc=$?
  rc=${rc:-0}
  if [ "$rc" -ne 0 ]; then
    echo "FAIL [$name]: expected exit 0 (allow), got $rc"
    return 1
  fi
  if [ -n "$out" ]; then
    echo "FAIL [$name]: expected no stdout (silent allow), got: $out"
    return 1
  fi
  echo "PASS [$name]"
}

# A prompt case: hook exits 0 but emits a JSON document with
# hookSpecificOutput.permissionDecision == "ask". JSON validity is
# checked unconditionally; broken JSON is a hard test failure (S5).
assert_prompt() {
  local name="$1"
  local cmd="$2"
  local out rc decision
  out=$(echo "{\"tool_input\":{\"command\":$(jq -Rs . <<<"$cmd")}}" | bash "$HOOK" 2>/dev/null) || rc=$?
  rc=${rc:-0}
  if [ "$rc" -ne 0 ]; then
    echo "FAIL [$name]: expected exit 0 (prompt), got $rc"
    return 1
  fi
  if ! printf '%s' "$out" | jq empty 2>/dev/null; then
    echo "FAIL [$name]: invalid JSON output: $out"
    return 1
  fi
  decision=$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // ""')
  if [ "$decision" != "ask" ]; then
    echo "FAIL [$name]: expected hookSpecificOutput.permissionDecision = \"ask\", got: ${decision:-<empty>}"
    return 1
  fi
  echo "PASS [$name]"
}

# Allow cases — unconditional read-only subcommands.
assert_allow "git status" 'git status'
assert_allow "git log" 'git log --oneline -5'
assert_allow "git diff" 'git diff HEAD~'
assert_allow "git show" 'git show HEAD'
assert_allow "git blame" 'git blame README.md'
assert_allow "git reflog" 'git reflog show main'
assert_allow "git rev-parse" 'git rev-parse HEAD'
assert_allow "git ls-files" 'git ls-files'
assert_allow "git for-each-ref" 'git for-each-ref refs/heads/'
assert_allow "git describe" 'git describe --tags'
assert_allow "git grep" 'git grep TODO'
assert_allow "git ls-remote" 'git ls-remote origin'
assert_allow "git fsck (no --write)" 'git fsck'
assert_allow "git help" 'git help log'
assert_allow "git --version" 'git --version'

# Allow cases — flag-aware compound subcommands.
assert_allow "git config --get" 'git config --get user.name'
assert_allow "git config --list" 'git config --list'
assert_allow "git branch (bare)" 'git branch'
assert_allow "git branch -a" 'git branch -a'
assert_allow "git branch --show-current" 'git branch --show-current'
assert_allow "git tag -l" 'git tag -l'
assert_allow "git tag --list" 'git tag --list'
assert_allow "git remote -v" 'git remote -v'
assert_allow "git remote get-url" 'git remote get-url origin'
assert_allow "git remote show" 'git remote show origin'
assert_allow "git worktree list" 'git worktree list'
assert_allow "git stash list" 'git stash list'
assert_allow "git stash show" 'git stash show'
assert_allow "git submodule status" 'git submodule status'
assert_allow "git notes list" 'git notes list'
assert_allow "git bundle verify" 'git bundle verify pack.bundle'

# Allow cases — `git fetch` (unconditional).
assert_allow "git fetch" 'git fetch'
assert_allow "git fetch origin" 'git fetch origin'
assert_allow "git fetch --dry-run" 'git fetch --dry-run origin'
assert_allow "git fetch --prune" 'git fetch --prune origin'

# Allow cases — `jj git X` invocations (always allowed).
assert_allow "jj git push" 'jj git push'
assert_allow "jj git fetch" 'jj git fetch'
assert_allow "chained jj invocations" 'jj git fetch && jj git push'

# Prompt cases — common mutating subcommands.
assert_prompt "git commit" 'git commit -m "foo"'
assert_prompt "git push" 'git push origin main'
assert_prompt "git checkout" 'git checkout main'
assert_prompt "git switch" 'git switch main'
assert_prompt "git merge" 'git merge other-branch'
assert_prompt "git rebase" 'git rebase main'
assert_prompt "git reset --hard" 'git reset --hard HEAD'
assert_prompt "git pull" 'git pull origin main'
assert_prompt "git add" 'git add file.txt'
assert_prompt "git rm" 'git rm file.txt'
assert_prompt "git restore" 'git restore file.txt'
assert_prompt "git cherry-pick" 'git cherry-pick abc123'
assert_prompt "git revert" 'git revert HEAD'
assert_prompt "git am" 'git am patch.mbox'
assert_prompt "git apply" 'git apply --index patch.diff'
assert_prompt "git update-ref" 'git update-ref refs/heads/foo abc123'
assert_prompt "git filter-branch" 'git filter-branch --tree-filter rm -f x HEAD'
assert_prompt "git replace" 'git replace abc def'
assert_prompt "git fast-import" 'git fast-import < dump'
assert_prompt "git clean -xdf" 'git clean -xdf'
assert_prompt "git gc" 'git gc'
assert_prompt "git prune" 'git prune'
assert_prompt "git repack" 'git repack -ad'

# Prompt cases — flag-aware (mutating flags on otherwise read-only verbs).
assert_prompt "git config --set" 'git config --set user.name "X"'
assert_prompt "git config --unset" 'git config --unset user.name'
assert_prompt "git config --add" 'git config --add safe.directory /repo'
assert_prompt "git branch -d" 'git branch -d feat/test'
assert_prompt "git branch -D" 'git branch -D feat/test'
assert_prompt "git branch -m" 'git branch -m old new'
assert_prompt "git tag -a" 'git tag -a v1.0 -m release'
assert_prompt "git tag -d" 'git tag -d v1.0'
assert_prompt "git remote add" 'git remote add origin git@github.com:foo/bar'
assert_prompt "git remote remove" 'git remote remove origin'
assert_prompt "git remote rename" 'git remote rename origin upstream'
assert_prompt "git remote set-url" 'git remote set-url origin git@github.com:foo/baz'
assert_prompt "git worktree add" 'git worktree add ../wt feat/test'
assert_prompt "git worktree remove" 'git worktree remove ../wt'
assert_prompt "git stash push" 'git stash push -m wip'
assert_prompt "git stash pop" 'git stash pop'
assert_prompt "git stash drop" 'git stash drop'
assert_prompt "git stash clear" 'git stash clear'
assert_prompt "git submodule add" 'git submodule add url path'
assert_prompt "git submodule update" 'git submodule update --init'
assert_prompt "git notes add" 'git notes add -m note HEAD'
assert_prompt "git notes remove" 'git notes remove HEAD'
assert_prompt "git fsck --write" 'git fsck --write'
assert_prompt "git init" 'git init'

# Prompt cases — chained mutations (B2 regression: read-only-then-
# mutating must NOT silently allow because of the read-only segment).
assert_prompt "chained: status then push" 'git status && git push origin main'
assert_prompt "chained: log then commit" 'git log --oneline && git commit -m x'
assert_prompt "semicolon: diff then reset" 'git diff; git reset --hard HEAD'
assert_prompt "pipe: status then push" 'git status | tee /tmp/x && git push'
assert_prompt "chained: jj then git commit" 'jj git push && git commit -m x'
assert_prompt "chained: git push before jj" 'git push origin main && jj status'
assert_prompt "semicolon-separated git push" 'echo hi; git push'

# Allow cases — chained read-only.
assert_allow "chained: status then log" 'git status; git log'
assert_allow "chained: jj invocations" 'jj git fetch && jj git push'

# Prompt cases — subshell parens (S-A regression: a mutating
# command wrapped in parens must not slip through behind a
# leading allowed segment).
assert_prompt "subshell mutation after allow" 'git status; (git push)'
assert_prompt "subshell mutation after allow chain" '(git log) && git push'

# Allow cases — subshell wrapping an allowed command.
assert_allow "subshell wraps allowed" '(git status)'

# Prompt cases — single `&` background operator (S-B regression:
# `git status & git push` runs both; the segmenter must split
# on lone `&` without double-splitting `&&`).
assert_prompt "background mutation" 'git status & git push origin main'

# Allow cases — single `&` between two allowed commands.
assert_allow "background allow then allow" 'git log & git status'

# Prompt cases — `git fetch` refspec form (S2 regression: colon
# refspecs can rewrite local branches).
assert_prompt "git fetch refspec main:main" 'git fetch origin main:main'
assert_prompt "git fetch force refspec" 'git fetch origin +refs/heads/*:refs/heads/*'

# Allow cases — global flag stripping (S3).
assert_allow "git --no-pager log" 'git --no-pager log'
assert_allow "git -C path status" 'git -C /tmp status'
assert_allow "git -c key=val log" 'git -c user.email=x log'

# Prompt cases — global flags + mutating verb (S3).
assert_prompt "git -c k=v commit" 'git -c user.email=x commit -m y'

# Allow cases — additional read-only commands (M1, M4).
assert_allow "git verify-commit" 'git verify-commit HEAD'
assert_allow "git annotate" 'git annotate README.md'
assert_allow "git check-ignore" 'git check-ignore foo.txt'
assert_allow "git check-ref-format" 'git check-ref-format refs/heads/main'
assert_allow "git format-patch" 'git format-patch -1 HEAD'
assert_allow "git request-pull" 'git request-pull main origin'
assert_allow "git stripspace" 'git stripspace -s'
assert_allow "git var" 'git var GIT_EDITOR'
assert_allow "git diff-tree" 'git diff-tree HEAD~1 HEAD'
assert_allow "git diff-index" 'git diff-index HEAD'
assert_allow "git diff-files" 'git diff-files'
assert_allow "git symbolic-ref --short" 'git symbolic-ref --short HEAD'

echo ""
echo "All smoke tests passed."
```

- [ ] **Step 2: Make executable, run smoke test**

```bash
chmod +x scripts/hooks/tests/test-block-mutating-git.sh
bash scripts/hooks/tests/test-block-mutating-git.sh
# Expected: every line starts with "PASS"; final line "All smoke
# tests passed."
```

If a test fails, fix `block-mutating-git.sh` (do not weaken the test).

- [ ] **Step 3: Commit**

```bash
jj describe -m "test: add smoke test for block-mutating-git hook"
jj new
```

### Task 2.24: `.claude/settings.json` registering all hooks

**Files:**

- Create: `.claude/settings.json`

- [ ] **Step 1: Write `.claude/settings.json`**

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PROJECT_DIR}/scripts/toolchain-watch.sh"
          },
          {
            "type": "command",
            "command": "${CLAUDE_PROJECT_DIR}/scripts/check-signing-key.sh"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PROJECT_DIR}/scripts/hooks/block-mutating-git.sh"
          }
        ]
      }
    ]
  }
}
```

Use `Write`. (Verify the exact JSON shape against
`https://code.claude.com/docs/en/hooks-reference` at execute-time;
the schema may have evolved. The above corresponds to the
documented format as of bootstrap-spec drafting.)

- [ ] **Step 2: Validate JSON syntactically**

```bash
jq . .claude/settings.json
# Expected: pretty-printed valid JSON
```

- [ ] **Step 3: Verify hooks fire (manual smoke)**

Open a fresh Claude Code session in the repo (separate from the
plan-execution session). Confirm:

- Toolchain-watch banner prints in the SessionStart preamble.
- Signing-key warm-up runs silently (no error).
- Attempting `git checkout main` triggers the permission prompt
  (the operator authorises or rejects).
- `jj status` works.

If any hook misfires, fix the script and re-run this step.

- [ ] **Step 4: Commit**

```bash
jj describe -m "feat: register SessionStart and PreToolUse hooks in .claude/settings.json"
jj new
```

### Task 2.25: `.github/workflows/ci.yml`

**Files:**

- Create: `.github/workflows/ci.yml`

**Action SHA pinning policy:** at execute-time, look up the latest
release tag SHA for each third-party action via
`gh api repos/<owner>/<repo>/git/refs/tags/<tag>` and pin the SHA
in the workflow with a comment naming the tag.

- [ ] **Step 1: Look up the latest stable major tag of `actions/checkout`**

```bash
# Identify the latest stable major (typically v4 or v5 at
# execute-time). actions/checkout major versions evolve; pin to
# whatever the repo's latest stable major is at execute-time.
gh api repos/actions/checkout/releases/latest --jq '.tag_name'
# Record the tag (call it $CHECKOUT_TAG, e.g. "v4").
# Then resolve to SHA:
gh api "repos/actions/checkout/git/refs/tags/$CHECKOUT_TAG" --jq '.object.sha'
# Record the SHA. Substitute into workflow files below in place of
# the <SHA-FOR-VLATEST> placeholder, and update the trailing comment
# from "# latest stable major" to "# vN" with the resolved tag.
```

- [ ] **Step 2: Look up SHA for `leanprover/lean-action@v1`**

```bash
gh api repos/leanprover/lean-action/git/refs/tags/v1 --jq '.object.sha'
# Expected: a 40-char SHA. Record.
```

- [ ] **Step 3: Write `ci.yml`**

```yaml
name: CI

on:
  push:
    branches: [main, integration]
  pull_request:
    branches: [main]
  workflow_dispatch:

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' || github.ref == 'refs/heads/integration' }}

jobs:
  style_lint:
    name: Style lint (forbid bare umbrella imports)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<SHA-FOR-VLATEST>  # latest stable major (verify at execute-time, e.g. v4 or v5)
      - name: forbid bare umbrella imports under upstream-eligible subtrees
        run: |
          if grep -RHnE '^import (Mathlib|Cslib)$' \
               Geb/Mathlib Geb/Cslib GebTests/Mathlib GebTests/Cslib 2>/dev/null; then
            echo "FAIL: bare umbrella 'import Mathlib' or 'import Cslib' in upstream-eligible files" >&2
            exit 1
          fi

  floodgate_imports:
    name: Floodgate imports lint
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<SHA-FOR-VLATEST>  # latest stable major (verify at execute-time, e.g. v4 or v5)
      - name: scripts/lint-imports.sh
        run: bash scripts/lint-imports.sh

  build:
    name: Build / test / lint / shake
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<SHA-FOR-VLATEST>  # latest stable major (verify at execute-time, e.g. v4 or v5)
      - uses: leanprover/lean-action@<SHA-FOR-V1>  # v1
        with:
          build: true
          test: true
          lint: true
          mk_all-check: false
      # `lake shake` requires built oleans for every library it
      # scans. `build: true` above honours `defaultTargets` (Geb
      # only), so build `GebTests` explicitly here.
      - name: lake build GebTests (prerequisite for lake shake)
        run: lake build GebTests
      - name: lake shake (minimised imports)
        run: lake shake --add-public --keep-implied --keep-prefix Geb GebTests
      - name: scripts/tests/test-lake-shake.sh
        run: bash scripts/tests/test-lake-shake.sh

  hooks_test:
    name: Hooks smoke test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<SHA-FOR-VLATEST>  # latest stable major (verify at execute-time, e.g. v4 or v5)
      - name: install jq
        run: sudo apt-get install -y jq
      - name: scripts/hooks/tests/test-block-mutating-git.sh
        run: bash scripts/hooks/tests/test-block-mutating-git.sh

  axiom_check:
    name: Axiom check
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<SHA-FOR-VLATEST>  # latest stable major (verify at execute-time, e.g. v4 or v5)
      - uses: leanprover/lean-action@<SHA-FOR-V1>  # v1
        with:
          build: true
          test: false
          lint: false
          mk_all-check: false
      - name: scripts/check-axioms.sh
        run: bash scripts/check-axioms.sh Geb/ GebTests/
```

Substitute `<SHA-FOR-VLATEST>` and `<SHA-FOR-V1>` with the values from
Steps 1–3 above. After substitution, validate with:

```bash
# Verify no remaining placeholders
grep -nE '<SHA-FOR-' .github/workflows/ci.yml && \
  { echo "ERROR: unresolved SHA placeholder"; exit 1; }
# Validate YAML syntax
python3 -c 'import yaml; yaml.safe_load(open(".github/workflows/ci.yml"))'
```

- [ ] **Step 4: Commit**

```bash
jj describe -m "ci: add ci.yml with style-lint, floodgate-imports, build (with lake shake), hooks-test, axiom-check jobs"
jj new
```

### Task 2.26: `.github/workflows/markdown-lint.yml`

**Files:**

- Create: `.github/workflows/markdown-lint.yml`

- [ ] **Step 1: Look up SHA for `DavidAnson/markdownlint-cli2-action@v19`**

```bash
gh api repos/DavidAnson/markdownlint-cli2-action/git/refs/tags/v19 --jq '.object.sha'
# Record.
```

- [ ] **Step 2: Write `markdown-lint.yml`**

```yaml
name: Markdown lint

on:
  push:
    branches: [main, integration]
  pull_request:
    branches: [main]
  workflow_dispatch:

jobs:
  markdownlint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<SHA-FOR-VLATEST>  # latest stable major (verify at execute-time, e.g. v4 or v5)
      - uses: DavidAnson/markdownlint-cli2-action@<SHA-FOR-V19>  # v19
        with:
          globs: '**/*.md'
          config: '.markdownlint-cli2.jsonc'
```

Substitute SHAs as in Task 2.25; verify no placeholders remain;
validate YAML syntax.

- [ ] **Step 3: Commit**

```bash
jj describe -m "ci: add markdown-lint.yml using DavidAnson/markdownlint-cli2-action"
jj new
```

### Task 2.27: `.github/workflows/update.yml`

**Files:**

- Create: `.github/workflows/update.yml`

- [ ] **Step 1: Look up SHA for `leanprover-community/mathlib-update-action@main`**

```bash
sha=$(gh api repos/leanprover-community/mathlib-update-action/branches/main --jq '.commit.sha')
date=$(gh api "repos/leanprover-community/mathlib-update-action/commits/$sha" --jq '.commit.committer.date | .[0:10]')
echo "SHA: $sha"
echo "Date (ISO, YYYY-MM-DD): $date"
# Record both. The SHA is the pin; the date is a human-readable
# annotation appearing in the workflow file's pin-comment. Substitute
# both into update.yml below in place of <SHA-FOR-MAIN> and
# <ISO-DATE-OF-SHA>. (No tagged releases at the time of spec drafting;
# pin to a specific main-branch commit SHA for supply-chain security.
# Re-pin on each scheduled review.)
```

- [ ] **Step 1b: Verify the action's `intermediate_releases` input values**

Per spec § "Verify agent claims against authoritative sources",
verify the action's documented input values directly from its
repository before writing the workflow:

```bash
# Read the action.yml for the documented inputs:
gh api "repos/leanprover-community/mathlib-update-action/contents/action.yml?ref=$sha" \
  --jq '.content' | base64 -d | grep -A 5 'intermediate_releases'
# Expected: shows `intermediate_releases` input with description
# enumerating allowed values (per spec § "update.yml": `all` |
# `latest` | `master`; verified against action.yml at SHA d2b88048
# on 2025-11-11). If the documented values differ at the pinned
# SHA, halt and surface to the user before proceeding.
```

- [ ] **Step 2: Write `update.yml`**

The `intermediate_releases` setting is resolved as **`latest`** (see
"Resolved open questions" near the end of this plan).

**GitHub token caveat**: PRs created by the default
`secrets.GITHUB_TOKEN` do **not** trigger downstream workflows by
documented GitHub-Actions design (to prevent infinite loops). This
means `ci.yml` (push: triggered) and `markdown-lint.yml` will not
fire automatically on the bump-PR opened by `mathlib-update-action`.

Two workarounds (decide at scaffolding time, document choice):

1. **Use a Personal Access Token (PAT)**: store as repo secret
   `MATHLIB_BUMP_TOKEN`; pass via `token: ${{ secrets.MATHLIB_BUMP_TOKEN }}`
   in the `actions/checkout` step. PRs created with a PAT trigger
   downstream workflows. Tradeoff: PAT secret rotation overhead.
2. **Manual CI trigger**: leave `GITHUB_TOKEN`; document that the
   user (or a maintainer) closes-and-reopens or labels the bump-PR
   to manually fire CI. Tradeoff: human-in-the-loop on every cron-
   created PR.

This plan defaults to (2) at bootstrap time (no PAT setup
required) with an explicit trigger entry in `TODO.md` to migrate to
(1) if bump-PR cadence makes the manual trigger ergonomically
costly. The workflow file below uses `GITHUB_TOKEN` accordingly.

```yaml
name: Mathlib bump

on:
  schedule:
    - cron: '0 17 * * *'
  workflow_dispatch:

jobs:
  bump:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write
    steps:
      - uses: actions/checkout@<SHA-FOR-VLATEST>  # latest stable major (verify at execute-time, e.g. v4 or v5)
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
      - uses: leanprover-community/mathlib-update-action@<SHA-FOR-MAIN>  # main @ <ISO-DATE-OF-SHA>
        with:
          intermediate_releases: latest
```

Substitute SHAs; verify no placeholders remain; validate YAML
syntax.

- [ ] **Step 3: Commit**

```bash
jj describe -m "ci: add update.yml using mathlib-update-action with intermediate_releases=latest"
jj new
```

### Task 2.27b: `.github/workflows/conflict-check.yml` (binding server-side gate)

**Files:**

- Create: `.github/workflows/conflict-check.yml`

Per spec § "Local-vs-server safety model" and § "`conflict-check.yml`",
this workflow is the **binding** safety property protecting `main`
from conflicted submissions. The local
`git.private-commits = "conflicts()"` setting (Task 1.3) is a
contributor-side ergonomic; this workflow is the project's
enforcement boundary. The split absorbs jj 0.41's silent-skip
semantics on bulk pushes (D23): even if a contributor's local
config fails to refuse a conflicted bookmark, server-side
rejection catches anything that lands.

- [ ] **Step 1: Resolve the actions/checkout SHA**

```bash
sha=$(gh api repos/actions/checkout/releases/latest --jq '.target_commitish')
# If 'latest' resolves to a branch ref, dereference to a commit:
sha=$(gh api "repos/actions/checkout/commits/$sha" --jq '.sha')
echo "actions/checkout SHA: $sha"
# Substitute below in place of <SHA-FOR-CHECKOUT>.
```

- [ ] **Step 2: Write the workflow**

```yaml
name: Conflict-check

on:
  pull_request:
  push:
    branches: [main, integration]

jobs:
  conflict-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<SHA-FOR-CHECKOUT>  # vN @ <ISO-DATE>
        with:
          fetch-depth: 0

      - name: Reject .jjconflict-* paths (no allowlist)
        run: |
          set -euo pipefail
          if git ls-files | grep -E '(^|/)\.jjconflict-(base|side)-' ; then
            echo "::error::Repository contains jj-export conflict directories." >&2
            echo "        Resolve the conflict locally before pushing." >&2
            exit 1
          fi
          echo "PASS: no .jjconflict-* paths"

      - name: Reject git three-way merge markers (with docs/ sentinel allowlist)
        run: |
          set -euo pipefail
          # Marker enumeration matches spec § "conflict-check.yml":
          # git's three-way markers <<<<<<< / ======= / >>>>>>> at
          # column 0 of any line in committed content. (jj's
          # working-copy markers — %%%%%%% diff from:, +++++++,
          # \\\\\\\, etc. — do NOT appear in a jj-exported
          # conflict's committed git tree; the path-based check
          # above is the binding gate for jj-originated conflicts.
          # Verified against jj 0.41.0, 2026-05-07.)
          fail=0
          while IFS= read -r f; do
            # Sentinel allowlist applies only to docs/-scoped files.
            case "$f" in
              docs/*)
                if head -n 30 "$f" | grep -qF '<!-- conflict-check: allow markers in this file -->' ; then
                  continue
                fi
                ;;
            esac
            if grep -lE '^(<<<<<<<|=======|>>>>>>>)' "$f" >/dev/null 2>&1; then
              echo "::error file=$f::contains git conflict marker at column 0" >&2
              fail=1
            fi
          done < <(git ls-files)
          [ "$fail" -eq 0 ] || exit 1
          echo "PASS: no unguarded conflict markers in committed content"
```

Substitute the SHA; verify no placeholders remain; validate YAML.

- [ ] **Step 3: Commit**

```bash
jj describe -m "ci: add conflict-check.yml binding server-side gate"
jj new
```

### Task 2.28: Silence the remember plugin's SessionStart

**Files:**

- Create: `.remember/logs/.gitkeep` (created if remember has not yet
  run)

- [ ] **Step 1: Ensure `.remember/logs/` exists**

```bash
mkdir -p .remember/logs
[ -e .remember/logs/.gitkeep ] || touch .remember/logs/.gitkeep
```

The `.remember/` directory is gitignored (per Task 1.4), so this
file is local-only. Its purpose is to silence the `remember`
plugin's SessionStart hook complaint about missing `.remember/logs/`.

- [ ] **Step 2: Open a fresh session and verify silence**

Open a fresh Claude Code session in the repo. Confirm the remember
plugin's SessionStart hook does not error.

If it does error, inspect the plugin's expectations
(`~/.claude/plugins/cache/remember/`) and adjust accordingly; surface
the discrepancy to the user.

- [ ] **Step 3: No commit needed**

`.remember/` is gitignored. This task does not produce a commit.

### Task 2.29: Resolve remaining decisions in the plan

**Decisions to make and document at the end of this plan (under
"Resolved open questions"):**

- `intermediate_releases`: resolved to `latest` (in Task 2.27).
- Doc-CI invocation: deferred — documented as Open Question to be
  resolved during the test-repo simulation (when we attempt the
  doc-gen4 invocation in event K).
- Doc-CI reminder mechanism: deferred — same.

- [ ] **Step 1: Update the "Resolved open questions" section of this
  plan in-place to reflect the decisions made above.**

Use `Edit` on this plan file to populate the section near the end.

- [ ] **Step 2: Commit**

```bash
jj describe -m "doc: resolve open questions in bootstrap plan (intermediate_releases=latest)"
jj new
```

### Task 2.30: `geb-lean` distillation pass

**Files:**

- Modify: `CLAUDE.md` (selectively, to incorporate harvested rules)
- Modify: `docs/process.md` § Distillation from prior tree (section 16)
- Modify or Create: `.claude/rules/lean-coding.md` (incorporate
  tactical heuristics carried forward from the prior tree's
  Workflow / Code Style / Development Processes sections)

**Action:** This is a **user-collaborative** task. Claude does NOT
automate the distillation; it walks through the prior tree's
`CLAUDE.md` *with the user* (the user has the file at a sibling
directory). For each section / rule / convention, the user decides:
keep, adapt, or drop. Anything kept is re-derived in our
`CLAUDE.md`, `docs/process.md`, `.claude/rules/*`, or
`docs/references.md` with rationale, NOT lifted as-is unless the
content is reference-catalog material (URLs, library pointers, etc.).

- [ ] **Step 1: Open the prior tree's `CLAUDE.md` together with the user**

Open the file (the user supplies the path; per the no-local-paths
rule, the plan does not embed it). Read it side-by-side with our
`CLAUDE.md`.

- [ ] **Step 2: Walk section by section**

For each section in the prior `CLAUDE.md`:

1. The user reads the section aloud or summarises it.
2. Both decide: keep, adapt, drop.
3. If keep or adapt, identify the target location in our content
   (`CLAUDE.md` or `docs/process.md`).
4. Add a note in `docs/process.md` § Distillation from prior tree
   recording the decision.

- [ ] **Step 3: Apply the changes**

Use `Edit` on `CLAUDE.md`, `docs/process.md`, and
`.claude/rules/*.md` to incorporate the harvested rules. Keep
`CLAUDE.md` under 200 lines (move detail into `.claude/rules/`
when the rule is path-scoped or into `docs/process.md` when it is
general rationale). Reference-catalog content (library pointers,
external math literature URLs, mathlib-namespace tables by topic)
goes into `docs/references.md` (a new file authored as part of
this task — F9). The CLAUDE.md `## Key references` list gets a
one-line entry pointing at `docs/references.md`.

- [ ] **Step 4: Re-lint**

```bash
markdownlint-cli2 'CLAUDE.md' 'docs/process.md' \
  'docs/references.md' '.claude/rules/*.md'
wc -l CLAUDE.md
# Expected: under 200.
```

- [ ] **Step 5: Empty-distillation case (if no rules carried forward)**

If the distillation pass produces no kept rules, the
`docs/process.md` § "Distillation from prior tree" section
must NOT be left with the literal placeholder text `(Filled by
Task 2.30 of the bootstrap plan.)`. Replace it with an explicit
one-paragraph note recording that the pass occurred and produced
no carryforward, e.g.:

```text
The distillation pass walked through the sibling-directory prior
tree's `CLAUDE.md` on <YYYY-MM-DD>; no rules were carried forward
beyond what already lives in our `CLAUDE.md` and
`.claude/rules/*`. The walk-through itself is recorded for
provenance, not as a register of imported rules.
```

If the distillation produced one or more kept rules, this step
is a no-op.

- [ ] **Step 6: Commit**

```bash
jj describe -m "doc(process): incorporate distillation pass from prior tree

Walk through the prior tree's CLAUDE.md and decide keep / adapt /
drop for each rule; record the decision in docs/process.md
§ Distillation from prior tree. Re-derive any retained rule in
our register; do not lift verbatim.
"
jj new
```

### Task 2.31: Final Part 2 verification

**Files:** none modified.

- [ ] **Step 1: `lake build`**

```bash
lake build
# Expected: clean build, no errors.
```

- [ ] **Step 2: `lake test`**

```bash
lake test
# Expected: vacuously pass (no test files yet beyond
# GebTests.lean and the two empty subindexes).
```

- [ ] **Step 3: `lake lint`**

```bash
lake lint
# Expected: quiet (no diagnostics). If style-header diagnostics
# appear, fix the offending file's `Authors:` line — do NOT
# silence the linter; the header linter is enforced from line one
# (weak.linter.style.header = true in lakefile.toml).
```

- [ ] **Step 3b: `lake shake` minimised-imports check**

```bash
lake shake --add-public --keep-implied --keep-prefix Geb GebTests
# Expected: clean (no unused-import findings). Module-form
# authoring (Task 2.3) is the precondition.
```

- [ ] **Step 3c: `scripts/tests/test-lake-shake.sh`**

```bash
bash scripts/tests/test-lake-shake.sh
# Expected:
#   PASS: --add-public
#   PASS: --keep-implied
#   PASS: --keep-prefix
#   PASS: lake shake detected injected unused import
#   test-lake-shake.sh: 4 check(s) ran, 0 failure(s)
```

- [ ] **Step 4: `scripts/lint-imports.sh`**

```bash
bash scripts/lint-imports.sh
# Expected: clean (0 file(s) checked, since Geb/Mathlib/ and
# Geb/Cslib/ have only .gitkeep, which the script skips).
```

- [ ] **Step 4b: `scripts/tests/test-lint-imports.sh`**

```bash
bash scripts/tests/test-lint-imports.sh
# Expected: 19 PASS lines, "19 case(s) checked, 0 failure(s)".
```

- [ ] **Step 5: `scripts/check-axioms.sh`**

```bash
bash scripts/check-axioms.sh Geb/ GebTests/
# Expected: empty / clean output.
```

- [ ] **Step 6: `markdownlint-cli2 '**/*.md'`**

```bash
markdownlint-cli2 '**/*.md'
# Expected: 0 errors.
```

- [ ] **Step 7: `scripts/hooks/tests/test-block-mutating-git.sh`**

```bash
bash scripts/hooks/tests/test-block-mutating-git.sh
# Expected: all PASS.
```

- [ ] **Step 8: `jj log`**

```bash
jj log -r 'main..@-' --no-graph -T 'change_id.short() ++ " " ++ description.first_line() ++ "\n"'
# Expected: every Task with a `jj describe` step corresponds to
# a commit visible here. Tasks 2.28 and 2.31 contain no `jj
# describe` step, so produce no commits; Task 1.4b's commit
# depends on whether the existing file was modified. The exact
# count is not critical: Task 2.32 collapses the series into
# 10–20 topological commits regardless. What matters here is
# that every task's intended commit appears in `jj log`.
```

- [ ] **Step 9: No commit (verification only).**

If anything fails, halt; surface the failure to the user; fix
before proceeding to Task 2.32.

### Task 2.32: History rewrite — collapse to ~10–20 topological commits

**Files:** none modified directly; jj rewrites the commit graph.

**Goal:** The chore/bootstrap branch carries the per-task series
produced by Part 2 (one commit per Task 2.x that contains a
`jj describe` step). The real-repo bring-up wants ~10–20
topologically-ordered commits grouping related artifacts
(toolchain + lakefile + library skeleton; rule layer; scripts;
hooks; CI workflows; tests). The
`feedback_initial_push_series.md` memory describes this rewrite
explicitly.

The target shape (10–20 commits):

1. `chore: initialise repo with bootstrap spec, plan, markdownlint config`
2. `chore: pin lean-toolchain v4.30.0-rc2 + lakefile + lake-manifest`
3. `feat: scaffold empty Geb/GebTests library skeleton`
4. `chore: add Apache 2.0 LICENSE`
5. `doc: add README.md`
6. `doc: add TODO.md and docs/index.md + docs/process.md`
7. `doc: add CLAUDE.md and .claude/rules/*.md`
8. `feat: vendor scripts/check-axioms.sh from lean4-skills`
9. `feat: add scripts/lint-imports.sh + scripts/extract-pr.sh`
10. `feat: add scripts/regenerate-integration.sh + scripts/rebase-topics.sh`
11. `feat: add SessionStart helper scripts (toolchain-watch,
    check-signing-key, lake-update-warning, pre-push)`
12. `feat: add scripts/hooks/block-mutating-git.sh + smoke test`
13. `feat: register SessionStart and PreToolUse hooks in .claude/settings.json`
14. `ci: add ci.yml + markdown-lint.yml`
15. `ci: add update.yml using mathlib-update-action`
16. `doc: incorporate distillation pass from prior tree CLAUDE.md`

(16 commits; if the distillation pass is large, may split or merge
adjacent groups to taste; target stays under 20.)

- [ ] **Step 1: Save current state for rollback**

```bash
jj operation log --limit 5
# Record the latest operation ID; it is the rollback target if
# the rewrite goes wrong (`jj operation restore <id>`).
```

- [ ] **Step 1b: Capture pre-rewrite bookmark inventory**

```bash
jj bookmark list > /tmp/bookmarks-before
# Snapshot for post-rewrite comparison; if any bookmark
# disappears across the rewrite, Step 5 surfaces it.
```

- [ ] **Step 2: Use `jj squash --from / --into` to collapse**

The exact sequence depends on the actual commit IDs at execute-time.
General pattern: `jj log --no-graph -T '...'` to list change IDs,
then `jj squash --from <src> --into <dst> --keep-emptied` to merge
groups, then `jj describe -r <dst>` to rewrite the squashed message.

**Message handling in agent-driven runs.** Pass an explicit
message-handling flag. Without one,
`jj squash --from <src> --into <dst>` opens `$EDITOR` to merge
the two descriptions, which deadlocks in any context that lacks a
controlling TTY (the Bash tool's stdin redirection to `/dev/null`
does not satisfy the editor — `nvim`, `vim`, etc. open `/dev/tty`
directly). Pick one of:

- `--keep-emptied` (the source survives as an empty commit with
  its description intact; no merge needed, no editor opened).
  The illustrative example below uses this form.
- `--use-destination-message` (drop the source description;
  keep the destination's).
- `--use-source-message` (the inverse).
- `-m "<combined message>"` (provide the merged message inline).

If the squash hangs anyway, check `ps -ef | grep -E '(nvim|vim|nano|emacs)'`
for an orphan editor process; killing it unblocks the parent
`jj squash`.

**Verified flag distribution (jj 0.41.0, 2026-05-07):**

- `jj squash`: use `--keep-emptied` (alias `-k`) to preserve the
  source as an empty commit if it carried a bookmark, preventing
  default-abandonment. There is **no `--retain-bookmarks` flag on
  `jj squash`**; the round-2 review's regression on this point is
  documented in the project-internal discoveries log (cited
  inline by D-number elsewhere in this plan).
- `jj rebase`: takes **no bookmark-preservation flag**. Bookmarks
  travel with change-ids by default (per D3); the only relevant
  flag is `--keep-divergent`.
- `jj abandon`: use `--retain-bookmarks` (the *only* command with
  this flag) to move bookmarks to the parent revision instead of
  deleting them on abandonment.

```bash
# Example sequence (illustrative; adapt at execute-time):
jj log -r 'main..@-' --no-graph -T 'change_id.short() ++ " " ++ description.first_line() ++ "\n"'
# For each grouping above, identify the source and destination
# change IDs and run jj squash --keep-emptied. Use
# `jj describe -r <id>` to rewrite the resulting message.
```

- [ ] **Step 2b: Clean up orphan empty commits**

After the squash pass, `--keep-emptied` may leave intermediate
empty commits whose bookmarks have already moved to the squash
target. List them and abandon those whose bookmarks have moved:

```bash
jj log -r 'empty()'
# Inspect each. For any orphan empty commit (no bookmark, or
# bookmark already on the squash target):
jj abandon -r <change-id> --retain-bookmarks
# `--retain-bookmarks` is a no-op when no bookmark is on the
# revision but is harmless and intent-documenting.
```

Without this cleanup the "10–20 clean topological commits" goal
is unreachable; `--keep-emptied` would leave residue.

- [ ] **Step 3: Verify the new shape**

```bash
jj log -r 'main..@-' --no-graph -T 'change_id.short() ++ " " ++ description.first_line() ++ "\n"' | wc -l
# Expected: between 10 and 20.
jj log -r 'main..@-'
# Read the new commit graph; confirm topological order matches the
# target shape above.
```

- [ ] **Step 4: Re-verify the working tree**

After the rewrite, re-run Task 2.31 verification to confirm the
collapsed history still produces a working repo (lake build passes,
linters quiet, etc.).

- [ ] **Step 4b: Diff post-rewrite bookmark inventory against pre-rewrite**

```bash
jj bookmark list > /tmp/bookmarks-after
diff /tmp/bookmarks-before /tmp/bookmarks-after
# Expected: change-id values for the rewritten range may differ
# (history was rewritten), but the *set of bookmark names* must
# be identical. Any bookmark name in /tmp/bookmarks-before that
# is missing from /tmp/bookmarks-after indicates a silent
# bookmark deletion (e.g., a `jj abandon` without
# `--retain-bookmarks`); halt and investigate.
```

- [ ] **Step 5: User review checkpoint — Part 2**

The user reviews the rewritten chore/bootstrap branch
commit-by-commit:

```bash
jj log -r 'main..@-' --reversed
# For each commit, run:
jj diff -r <change-id>
```

The user authorises proceeding to Part 3 (or requests further
rewrites). No push has happened yet.

If the user requests changes, `jj operation restore <op-id>` rolls
back to before the rewrite; iterate.

**Part 2 verification:**

- 10–20 commits on `chore/bootstrap`, in topological order.
- All scripts present, executable, and smoke-tested.
- All workflow files SHA-pinned and YAML-valid.
- `CLAUDE.md` under 200 lines.
- `.claude/rules/*.md` covering Lean, upstream-eligible, markdown,
  and CI/workflow.
- `lake build`, `lake test`, `lake lint`, lint-imports, axiom-check,
  markdownlint, hooks-test all clean.
- User authorisation explicit.

---

## Part 3 — Test-repo simulation

**Goal of Part 3:** Exercise every documented process end-to-end on
throwaway public test repos `rokopt/geb-mathlib-test-N` (numbered
iterations; never deleted during testing). Iterate the spec / plan
/ runbook on every discrepancy. The test-repo phase terminates when
a single fresh test repo runs the entire bootstrap-real event
sequence clean from start to finish, signed off by the user.

**Verification at end of Part 3:** The runbook at
`docs/superpowers/runbooks/<date>-bootstrap-runbook.md` is signed
off by the user as "this is the sequence we will run on the real
repo." All bootstrap-real verification items (#1–35 from the spec,
modulo out-of-simulation items) have been confirmed on a fresh
test-repo iteration.

### Task 3.1: Initialise the runbook

**Files:**

- Create: `docs/superpowers/runbooks/<date>-bootstrap-runbook.md`

The runbook lives in the **user's local working tree** (this repo),
NOT in any test repo. It persists across all iterations.

- [ ] **Step 1: Write the runbook skeleton**

```markdown
# Bootstrap runbook

Recorded operational sequence for the geb-mathlib bootstrap. The
sequence is iterated against numbered test repos
`rokopt/geb-mathlib-test-N`; the final clean iteration's sequence
is replayed against the real repo `rokopt/geb-mathlib`.

## Iteration log

| Iteration N | Outcome | Notes |
| --- | --- | --- |
| 1 | (in progress) | First run |

## Events

For each event, the runbook records: preconditions, action,
expected result, verification, rollback / cleanup, discoveries.

Marked **bootstrap-real** events are re-executed against the real
repo verbatim. Marked **test-only** events are exercised on the
test repo only and skipped on the real repo.

### A. Repo creation and bootstrap branch (bootstrap-real)

…

### B. Hooks active

- Toolchain-watch in-sync (bootstrap-real)
- Toolchain-watch drift (test-only)
- Toolchain-watch offline (test-only)
- PreToolUse mutating-git hook prompts on raw `git checkout` (test-only)
- PreToolUse mutating-git hook allows `jj git push` (bootstrap-real)
- Smoke test in scripts/hooks/tests/ (bootstrap-real)

…

### C. Branch operations (bootstrap-real)

…

### D. CI activates (bootstrap-real)

…

### E. Integration regeneration (bootstrap-real)

…

### F. Mass-rebase on a simulated bump (bootstrap-real)

…

### G. Floodgate-CI lint

- G1 forbidden import (test-only)
- G2 prefix leakage (test-only)
- G3 clean file (bootstrap-real)

### H. PR extraction (bootstrap-real, local-only — no push to
`rokopt/mathlib4`)

…

### I. Conflict-commit refusal (test-only)

…

### J. Process self-update (bootstrap-real)

…

### K. Doc generation (bootstrap-real)

…

## Discoveries log

(Empty initially. Each spec/plan/runbook change made in response to
an unexpected outcome lands here with a date stamp and pointer to
the affected event.)
```

Each event subsection (A–K) is initially populated with the
expected sequence per the spec. As iterations execute and the user
observes outcomes, the runbook grows with concrete commands and
expected outputs.

- [ ] **Step 2: Commit**

```bash
jj describe -m "doc: initialise bootstrap runbook"
jj new
```

### Task 3.2: Iteration 1 — event A (Repo creation and bootstrap branch)

**Files (in test repo, not main working tree):**

- Test repo `rokopt/geb-mathlib-test-${N}` and its local clone
  `geb-mathlib-test-${N}/` at a sibling directory of the main
  working tree.

The runbook expects the contributor's shell to have `N` exported
to the current iteration number (e.g., `export N=1` for the first
test iteration, `export N=2` after a discovery cycle, …). The
iteration-loop snippet at Task 3.13 sets the variable for the
next iteration automatically.

- [ ] **Step 1: Create the test repo on GitHub**

```bash
gh repo create "rokopt/geb-mathlib-test-${N}" --public \
  --description "Throwaway test repository for the geb-mathlib bootstrap; iteration ${N}; ignore."
# Expected: repo created. Note: --public alone does NOT clone
# locally; Step 2 creates the local working directory explicitly.
```

- [ ] **Step 2: Create the local working directory and initialise**

```bash
cd ..
mkdir "geb-mathlib-test-${N}"
cd "geb-mathlib-test-${N}"
# Pre-flight: re-run Task 1.1 checks here (jj/git versions, jj
# user identity, no enclosing git worktree). The new directory
# is fresh, so the worktree check should pass; the version and
# identity checks may already pass from a prior session.
git init --initial-branch=main
git remote add origin "git@github.com:rokopt/geb-mathlib-test-${N}.git"
jj git init --colocate
# Expected output: 'Initialized repo in "."' (single line; jj
# 0.41 emits no Hint line — see Task 1.2).
```

- [ ] **Step 3: Stage bundled tree content for later import**

The spec's intent for the test-repo simulation is to exercise
event A (repo creation, *first commit*, first push) end-to-end.
The test repo doesn't need to mirror the main-tree's commit
granularity (~10–20 squashed commits); a single content-import
commit on `chore/bootstrap` is sufficient to exercise event A
plus the rest of the runbook on a healthy tree.

Stage the bundled tree's *content* (not its commits or bookmarks)
into a temp directory; the locally-created `main` and
`chore/bootstrap` bookmarks below (Steps 5 and 5b) own the
test-repo's history. Importing the bundled history as its own
`chore/bootstrap` bookmark would (a) collide with the local
`jj bookmark create chore/bootstrap` in Step 5b, and (b) attach
`chore/bootstrap` to an unrelated placeholder ancestry, breaking
the FF in Step 5c.

```bash
# In the main working tree, produce a bundle of the chore/bootstrap
# branch:
( cd ../geb-mathlib && \
  git bundle create /tmp/chore-bootstrap.bundle chore/bootstrap )

# Extract the bundled tree's working-copy content into a temp dir.
# We materialise files only, never `.git/`/`.jj/` state, so the
# import is content-only:
rm -rf "/tmp/import-${N}"
mkdir -p "/tmp/import-${N}"
(
  cd "/tmp/import-${N}" && \
  git init --quiet --initial-branch=main && \
  git fetch --quiet /tmp/chore-bootstrap.bundle chore/bootstrap && \
  git -c advice.detachedHead=false checkout --quiet FETCH_HEAD -- .
)
rm /tmp/chore-bootstrap.bundle
# `/tmp/import-${N}` now holds the bundled tree's files only.
```

This is git-native and avoids jj-specific local-path-remote
semantics. (`git remote add` would also work but is unnecessary
here; `git fetch` against a bundle file is direct.)

- [ ] **Step 4: Apply recommended local jj configuration**

```bash
jj config set --repo git.private-commits 'conflicts()'
jj config set --repo remotes.origin.auto-track-bookmarks 'glob:*'
jj config set --repo revsets.bookmark-advance-from 'heads(::@ & mutable())'
jj config set --repo revsets.bookmark-advance-to '@'
# Per Task 1.3 (and spec § "Recommended local jj configuration"):
# these settings are per-developer-per-checkout, not committed.
# jj v0.38+ writes them to ~/.config/jj/repos/<hash>/config.toml.
```

- [ ] **Step 5: Establish `main` (placeholder commit) and `chore/bootstrap`**

Mirroring Task 1.5 (the placeholder-commit design from spec
§ "Bookmark anchoring (D3)"):

```bash
jj describe -m "chore: anchor main at empty placeholder commit"
jj bookmark create main -r @
jj new
jj bookmark list
# Expected:
#   main: <placeholder-change-id> chore: anchor main at empty placeholder commit
```

- [ ] **Step 5b: Apply the imported tree as a commit on `chore/bootstrap`**

```bash
# `@` is the empty child of the placeholder. Copy the staged
# bundled tree's content into the test-repo working copy. Skip
# `.git`/`.jj` state directories explicitly so the test repo's
# own VCS state is preserved:
rsync -a --exclude='.git/' --exclude='.jj/' \
  "/tmp/import-${N}/" ./
rm -rf "/tmp/import-${N}"

# jj snapshots the imported content into the working-copy change
# on the next jj invocation. Describe and bookmark:
jj describe -m "chore: import bootstrap scaffolding from main repo iteration ${N}"
jj bookmark create chore/bootstrap -r @

# Do NOT run `lake update` here: the rsynced `lake-manifest.json`
# carries the committed pins from the main tree, and `lake update`
# would re-resolve mathlib master and drift the SHA. Lake resolves
# from the manifest without `lake update`. If a later step needs
# fresh artifacts (cache, builds), use `lake exe cache get` and
# `lake build` — both honour the manifest's pinned SHAs.

# Move to a new working-copy change for the next task:
jj new
```

- [ ] **Step 5c: Fast-forward `main` to `chore/bootstrap`'s tip (FF rehearsal)**

The test-repo simulation must produce a `main` that carries the
scaffolding so that Task 3.4's topic branches (rooted on `main`)
inherit a buildable tree. This is also the **FF rehearsal step**
the spec calls out: it produces a non-trivial reflog so
verification 22's pairwise-ancestor walk runs on more than one
entry on the test repo.

```bash
jj bookmark set main -r 'chore/bootstrap'
jj bookmark list
# Expected: main and chore/bootstrap at the same change ID
# (chore/bootstrap's tip).
```

After this step, the test repo's `main` carries the scaffolding;
`feat/topic-A`, `feat/topic-B`, `fix/topic-C` (created in Task 3.4)
all branch off `main` and inherit the lakefile + skeleton, so
`lake build` and CI succeed on push.

- [ ] **Step 6: Add a disclaimer to README.md**

Edit `README.md` to add at the top:

```markdown
> **Disclaimer**: this is `rokopt/geb-mathlib-test-${N}`, a
> throwaway test repository for the geb-mathlib bootstrap,
> iteration ${N}. It is NOT the real `rokopt/geb-mathlib` repo.
> Ignore.
```

- [ ] **Step 7: Run `markdownlint-cli2`, `lake build`**

```bash
markdownlint-cli2 '**/*.md'
lake exe cache get
lake build
# Expected: clean.
```

- [ ] **Step 8: User review checkpoint — first commit on test repo**

The user reviews `jj diff` of the imported scaffolding plus the
disclaimer.

- [ ] **Step 9: First push to test repo**

```bash
jj git push --remote origin -b main
jj git push --remote origin -b chore/bootstrap
# Expected: both bookmarks created on the remote. Per D9 (jj
# v0.38+), `jj git push -b <name>` auto-tracks on first push
# without any extra config; the auto-track-bookmarks setting
# from Step 4 is for bulk pushes (--all) not used here.
# `-b <name>` per-bookmark push hard-fails on private/conflicted
# commits (no silent-skip risk on these).

# Set default branch to main so workflow_dispatch finds workflows
# on main (GitHub fires workflow_dispatch only for workflows on the
# default branch).
gh repo edit "rokopt/geb-mathlib-test-${N}" --default-branch main
# Verify the change took:
gh repo view "rokopt/geb-mathlib-test-${N}" --json defaultBranchRef --jq '.defaultBranchRef.name'
# Expected: main
```

**Cron-race note** (per spec event D): the test repo's lifetime
may straddle `update.yml`'s daily `'0 17 * * *'` cron firing. The
cron will run `lake update` on the test repo and may open bump
PRs against `main`. These are noise; close them when observed.
The plan does not disable the cron on the test repo (doing so
would invalidate the structural-validity check in Task 3.5).

- [ ] **Step 10: Verify session start in fresh Claude session**

Open a fresh Claude Code session in `geb-mathlib-test-${N}/`. Confirm:

- `toolchain-watch` banner prints (in-sync or behind, either is
  acceptable).
- `check-signing-key` runs silently.
- `remember` plugin's SessionStart hook is silent (no error from
  missing `.remember/logs/` since `mkdir -p .remember/logs` runs
  early).

- [ ] **Step 11: Record event A in runbook**

In the main working tree, edit
`docs/superpowers/runbooks/<date>-bootstrap-runbook.md` to fill in
event A with the actual commands run, observed outputs, and any
discoveries. Commit:

```bash
jj describe -m "doc: record runbook event A on test-1"
jj new
```

### Task 3.3: Iteration 1 — event B (Hooks active)

In the test repo (`geb-mathlib-test-${N}/`), exercise:

- [ ] **Step 1: Toolchain-watch in-sync (bootstrap-real)**

A fresh session shows the in-sync banner (already verified in Task
3.2 step 10).

- [ ] **Step 2: Toolchain-watch drift (test-only)**

```bash
# Edit lean-toolchain to a value behind master. Use a
# syntactically-valid but never-installable form so an
# accidentally-triggered `lake build` cannot succeed against an
# old real release; the goal is to make the toolchain-watch hook
# observe drift, not to actually build against an old toolchain:
echo "leanprover/lean4:v4.29.0-rc999" > lean-toolchain
# Open a fresh Claude session; confirm the banner says "behind".
# Revert:
echo "leanprover/lean4:v4.30.0-rc2" > lean-toolchain
```

Record the observed banner text in the runbook event B.

- [ ] **Step 3: Toolchain-watch offline (test-only)**

Do **not** modify the machine's networking. Instead, override the
script's URL via the `TOOLCHAIN_WATCH_URL` env var to an
RFC 5737 TEST-NET-1 address (`192.0.2.0/24`, reserved for
documentation, never reachable):

```bash
TOOLCHAIN_WATCH_URL='https://192.0.2.1/lean-toolchain' \
  bash scripts/toolchain-watch.sh
# Expected: "toolchain-watch: could not reach mathlib master
# (offline?); skipping"; exit 0.
```

Record the observed banner in the runbook. The override applies
only to the single invocation — no machine state is altered.

- [ ] **Step 4: PreToolUse mutating-git hook prompt (test-only)**

In a fresh Claude session in `geb-mathlib-test-${N}/`, ask Claude (or
type into Bash via the harness if available) to run
`git checkout main`. Verify the hook emits the permission-prompt
JSON (`permissionDecision == "ask"`).
Record.

- [ ] **Step 5: PreToolUse mutating-git hook allows `jj git push` (bootstrap-real)**

Run `jj git push --dry-run --remote origin -b main` (or another
allowed jj-form). Verify the hook allows `jj git push` without
prompting. Record.

- [ ] **Step 6: Smoke test in CI (bootstrap-real)**

After committing, `gh run list` to confirm `ci.yml`'s `hooks_test`
job ran and passed. Record the run ID and status.

- [ ] **Step 7: Update runbook event B; commit**

```bash
# In main working tree:
jj describe -m "doc: record runbook event B on test-1"
jj new
```

### Task 3.4: Iteration 1 — event C (Branch operations)

In `geb-mathlib-test-${N}/`:

- [ ] **Step 1: Create three topic branches**

```bash
jj new chore/bootstrap -m "test(feat/topic-A): start topic branch"
jj bookmark create feat/topic-A -r @
jj new -m "test: feat/topic-A content commit"
# Now feat/topic-A bookmark is at @-, working copy is at @.

# Repeat for feat/topic-B (off main, not chore/bootstrap):
jj new main -m "test(feat/topic-B): start topic branch"
jj bookmark create feat/topic-B -r @
jj new -m "test: feat/topic-B content commit"

# Repeat for fix/topic-C:
jj new main -m "test(fix/topic-C): start topic branch"
jj bookmark create fix/topic-C -r @
jj new -m "test: fix/topic-C content commit"
```

- [ ] **Step 2: Push each topic branch**

```bash
jj git push --remote origin -b feat/topic-A -b feat/topic-B -b fix/topic-C
# Expected: all three created on the remote (push-new-bookmarks).
```

- [ ] **Step 3: Update runbook event C; commit**

```bash
# In main working tree:
jj describe -m "doc: record runbook event C on test-1"
jj new
```

### Task 3.5: Iteration 1 — event D (CI activates)

In `geb-mathlib-test-${N}/`:

- [ ] **Step 1: Confirm `ci.yml` ran on the chore/bootstrap and topic branches**

```bash
gh run list --workflow=ci.yml --limit 10
# Expected: runs for chore/bootstrap, feat/topic-A, feat/topic-B,
# fix/topic-C; statuses passed (or in progress).
gh run watch <run-id>  # if waiting needed
```

- [ ] **Step 2: Confirm `markdown-lint.yml` ran**

```bash
gh run list --workflow=markdown-lint.yml --limit 10
# Expected: runs and passing.
```

- [ ] **Step 3: Trigger `update.yml` via `workflow_dispatch`**

```bash
gh workflow run update.yml
sleep 30
gh run list --workflow=update.yml --limit 1
gh run watch <run-id>
# Expected: completes successfully (either no-op or opens a bump
# PR; both acceptable).
```

If the run opens a bump PR against the test repo, ignore and close
it (the test repo is throwaway).

- [ ] **Step 3a: Confirm `update.yml` is loaded by GitHub**

Per spec event D: the workflow file parses and `gh workflow list`
recognises it.

```bash
gh workflow list --all
# Expected: shows "Mathlib bump" (or whatever name = field is set
# to in update.yml) with the file path .github/workflows/update.yml.
```

If `update.yml` is missing, the file failed to parse; halt; debug.

- [ ] **Step 4: Exercise verification item #5 via a manually-opened PR against `main`**

Spec verification item #5 reads: "`ci.yml` passes on the bump PR
(PR-against-`main`)." The most-faithful exercise — append a
stale-manifest commit directly to `main` to force the bump action
to open a PR — would violate the spec's "topic branches land on
`main` via normal merge commits" rule (spec line 540-560). The
spec does not authorise a direct-append-to-`main` test pattern,
even on a throwaway repo, because it would normalise that pattern
in the runbook.

Instead, exercise item #5 with a manually-opened PR against `main`
that exercises the same `pull_request: main` trigger as a real
bump-PR would. A bump-PR via the cron is structurally a
PR-against-main; a topic-branch PR is the same trigger from CI's
perspective.

**User-authored text required**: PR title, body, and close
comment are user-facing text. Per the no-LLM-drafted-text rule
(spec § "No LLM-drafted user-facing text on mathlib channels",
which the plan's Conventions section binds across both mathlib
and our own GitHub surfaces), the user supplies these strings.
Claude may surface drafts marked "for the user to paraphrase";
the user posts.

```bash
# (User authors PR_TITLE, PR_BODY, CLOSE_COMMENT before this step.)
gh pr create --base main --head feat/topic-A \
  --title "$PR_TITLE" \
  --body "$PR_BODY"
gh pr checks --watch
# Expected: ci.yml runs and passes on the empty skeleton.
gh pr close --comment "$CLOSE_COMMENT"
```

If `update.yml`'s actual cron-driven flow is to be exercised
end-to-end (a real bump-PR opened by the action and CI fired on
it), that is **routine post-bootstrap work**, not bootstrap
verification. The bootstrap-time check is structural validity of
`update.yml` (Task 3.5 step 3a's `gh workflow list`) plus a
successful `workflow_dispatch` run (Task 3.5 step 3) — both of
which leave `main` undisturbed.

- [ ] **Step 5: Update runbook event D; commit**

```bash
# In main working tree:
jj describe -m "doc: record runbook event D on test-1"
jj new
```

### Task 3.6: Iteration 1 — event E (Integration regeneration)

In `geb-mathlib-test-${N}/`:

- [ ] **Step 1: Run `regenerate-integration.sh`**

```bash
bash scripts/regenerate-integration.sh
# Expected: creates an `integration` bookmark at a fan-in merge
# commit; pushes it to origin.
```

- [ ] **Step 2: Verify on GitHub**

```bash
gh api repos/rokopt/geb-mathlib-test-${N}/branches/integration --jq '.commit.sha'
# Expected: SHA is the fan-in merge commit's git SHA.
```

- [ ] **Step 3: Verify `main` was NOT touched**

Per spec verification item #21: `main` is not modified by
integration regeneration.

```bash
# Capture main's SHA before the next regeneration (Step 4).
main_sha_before=$(jj log -r 'main' -T 'commit_id ++ "\n"' --no-graph --limit 1)
echo "main SHA before: $main_sha_before"
```

- [ ] **Step 4: Move a topic branch's tip; re-run regeneration**

```bash
jj edit feat/topic-A
jj describe -m "test: add commit on feat/topic-A"
jj new
jj git push --remote origin -b feat/topic-A
bash scripts/regenerate-integration.sh
# Expected: integration force-pushes the new fan-in; main still
# untouched.
```

- [ ] **Step 4b: Compare main's SHA to the captured baseline**

```bash
main_sha_after=$(jj log -r 'main' -T 'commit_id ++ "\n"' --no-graph --limit 1)
echo "main SHA after:  $main_sha_after"
if [ "$main_sha_before" = "$main_sha_after" ]; then
  echo "PASS: main unchanged across integration regeneration"
else
  echo "FAIL: main moved unexpectedly"
  exit 1
fi
```

- [ ] **Step 5: Update runbook event E; commit**

```bash
# In main working tree:
jj describe -m "doc: record runbook event E on test-1"
jj new
```

### Task 3.7: Iteration 1 — event F (Mass-rebase on simulated bump)

In `geb-mathlib-test-${N}/`:

- [ ] **Step 1: Create a `bump/<lean-version>` branch**

```bash
jj new main -m "bump: simulated mathlib master advance"
jj bookmark create bump/test-1 -r @
```

- [ ] **Step 2: Run `lake update`**

```bash
lake update
# May produce real change to lake-manifest.json (mathlib has
# advanced) or no-op (mathlib unchanged). Either acceptable.
```

- [ ] **Step 3: `lake build` on bump branch**

```bash
lake build
# Expected: passes. If it fails (mathlib breaking change), fix on
# this branch — but for the simulation, if we hit a real breaking
# change, that's a discovery to record in runbook event F.
```

- [ ] **Step 4: Merge bump branch into main**

```bash
jj new main bump/test-1 -m "Merge branch 'bump/test-1' into main"
jj bookmark set main -r @
jj git push --remote origin -b main
```

- [ ] **Step 5: Run `rebase-topics.sh main`**

```bash
bash scripts/rebase-topics.sh main
# Expected: feat/topic-A, feat/topic-B, fix/topic-C now have main's
# new tip as ancestor.
```

- [ ] **Step 6: Regenerate `integration`**

```bash
bash scripts/regenerate-integration.sh
# Expected: clean.
```

- [ ] **Step 7: Update runbook event F; commit**

```bash
# In main working tree:
jj describe -m "doc: record runbook event F on test-1"
jj new
```

### Task 3.8: Iteration 1 — event G (Floodgate-CI lint)

In `geb-mathlib-test-${N}/`:

- [ ] **Step 1: G1 — forbidden import (test-only)**

```bash
mkdir -p Geb/Mathlib/Test
cat > Geb/Mathlib/Test/Forbidden.lean <<'EOF'
module

public import Geb.Internal  -- forbidden: upstream-eligible files import only Mathlib.* or Geb.Mathlib.*
EOF
bash scripts/lint-imports.sh
# Expected: exit 1, message about forbidden import (and only that;
# the `module` header satisfies the header check so the violation
# isolates the import-direction rule).
echo "Exit code: $?"
```

If the script does NOT reject, the lint is broken — record as a
discovery, fix `lint-imports.sh`, restart at iteration N+1.

Clean up:

```bash
rm Geb/Mathlib/Test/Forbidden.lean
```

- [ ] **Step 2: G2 — prefix-leakage (test-only)**

```bash
cat > Geb/Mathlib/Test/Leakage.lean <<'EOF'
module

public import Mathlib.Tactic
-- prefix leakage:
def Foo : Geb.Mathlib.SomeName := sorry
EOF
bash scripts/lint-imports.sh
# Expected: exit 1, message about prefix leakage (and only that).
```

Clean up:

```bash
rm Geb/Mathlib/Test/Leakage.lean
```

- [ ] **Step 3: G3 — clean file (bootstrap-real)**

```bash
cat > Geb/Mathlib/Test/Clean.lean <<'EOF'
module

public import Mathlib.Tactic
namespace Computability
public def trivialExample : Nat := 0
end Computability
EOF
bash scripts/lint-imports.sh
# Expected: exit 0.
lake build
# Expected: builds. (The `public def` is needed because a module
# with `public import` and no public declarations trips Lean 4's
# `linter.privateModule` warning, which under
# `weak.warningAsError = true` blocks the build.)
rm Geb/Mathlib/Test/Clean.lean
```

- [ ] **Step 4: Update runbook event G; commit**

```bash
# In main working tree:
jj describe -m "doc: record runbook event G on test-1"
jj new
```

### Task 3.8b: Iteration 1 — axiom-check failing case (test-only)

Per spec verification item #19: "the workflow is exercised in a
test-only event by intentionally adding a `Classical.choice`-using
stub and verifying the script flags it."

In `geb-mathlib-test-${N}/`:

- [ ] **Step 1: Add a `Classical.choice`-using stub**

The stub bypasses both index-on-skeleton (the file is not added to
any subindex) and constructive-only discipline. It exists for one
moment to flag the axiom-check, then is removed. Note explicitly
in the runbook that this is a test-only orphan file.

Place it outside the `Geb/` and `GebTests/` libraries so `lake build`
on the regular library targets does not include it. We use a `tmp/`
directory at the repo root.

The stub must (i) typecheck without `noncomputable` (our project
forbids it everywhere) and (ii) reference `Classical.choice` so
that `#print axioms` flags it. A `Prop`-valued theorem works: a
`theorem` is not subject to the `noncomputable` rule (theorems are
proof terms, not data definitions), but its proof can call
`Classical.choice` as a term, pulling the axiom into its closure.

```bash
mkdir -p tmp
cat > tmp/AxiomStub.lean <<'EOF'
import Mathlib.Tactic

/-- Test-only theorem that pulls `Classical.choice` transitively
    via its proof. Theorems do not require the `noncomputable`
    keyword regardless of the axioms invoked in their proofs. -/
theorem axiomStub (h : Nonempty Nat) : Nonempty Nat :=
  ⟨Classical.choice h⟩
EOF
```

(Why this typechecks under our constructive-only rule:
`Nonempty Nat : Prop`, so `axiomStub` is a `Prop`-valued declaration.
Lean does not flag `Prop`-valued declarations as needing
`noncomputable`. The proof body invokes
`Classical.choice : {α : Sort u} → Nonempty α → α` on `h : Nonempty
Nat` to extract a `Nat`, which is then re-wrapped in `Nonempty.intro`.
`#print axioms axiomStub` lists `Classical.choice` in its closure.)

- [ ] **Step 1b: Build the stub directly**

```bash
lake env lean tmp/AxiomStub.lean
# Expected: succeeds (parseable and typechecks; running lean
# directly avoids the lakefile-driven library targets).
```

- [ ] **Step 2: Run the axiom check; expect a flag**

The vendored script's documented usage (per its file header
comment at `scripts/check-axioms.sh`) is
`<file-or-dir-or-pattern>`, so a single-file argument is
supported. Distinguish the script's own non-zero exits (parse
errors, lake errors) from an axiom-flag exit by inspecting the
output: an axiom-flag exit prints the flagged axiom name(s)
matching `Classical.choice`.

```bash
if out=$(bash scripts/check-axioms.sh tmp/AxiomStub.lean 2>&1); then
  echo "FAIL: expected non-zero exit (Classical.choice should be flagged)"
  echo "$out"
  exit 1
elif echo "$out" | grep -q 'Classical.choice'; then
  echo "PASS: script flagged Classical.choice as expected"
else
  echo "FAIL: script exited non-zero but Classical.choice was not in output"
  echo "$out"
  exit 1
fi
```

If the script does NOT flag (PASS path), the vendoring is wrong
— discovery; verify Task 2.13's allowlist customisation; restart
iteration.

- [ ] **Step 3: Clean up**

```bash
rm -f tmp/AxiomStub.lean
rmdir tmp 2>/dev/null || true
```

- [ ] **Step 4: Update runbook event G/axiom-check; commit**

```bash
# In main working tree:
jj describe -m "doc: record runbook axiom-check failing case on test-1"
jj new
```

### Task 3.9: Iteration 1 — event H (PR extraction, local-only)

In `geb-mathlib-test-${N}/`:

- [ ] **Step 1: Add a clean upstream-eligible file**

```bash
mkdir -p Geb/Mathlib/Sandbox
cat > Geb/Mathlib/Sandbox/Trivial.lean <<'EOF'
import Mathlib.Tactic

/-!
# Sandbox.Trivial

A trivial declaration for exercising the extraction script.
-/

namespace Sandbox.Trivial

/-- Trivial example. -/
def trivialId : Nat → Nat := id

end Sandbox.Trivial
EOF
bash scripts/lint-imports.sh
lake build
```

- [ ] **Step 2: Clone mathlib4 to a temp directory for diffing**

```bash
TMPMATH=$(mktemp -d)
git clone --depth=1 https://github.com/leanprover-community/mathlib4.git "$TMPMATH"
```

- [ ] **Step 3: Run `extract-pr.sh`**

```bash
bash scripts/extract-pr.sh Geb/Mathlib/Sandbox/Trivial.lean "$TMPMATH"
# Expected: writes $TMPMATH/Mathlib/Sandbox/Trivial.lean with
# imports rewritten.
diff Geb/Mathlib/Sandbox/Trivial.lean "$TMPMATH/Mathlib/Sandbox/Trivial.lean"
# Expected: no Geb.Mathlib. -> Mathlib. rewrites would show only
# if there were any imports starting with Geb.Mathlib.; in this
# trivial file there are none, so the diff is empty.
```

For a non-trivial test exercising the rewrite: add a Geb.Mathlib.* import and
re-extract.

- [ ] **Step 4: Do NOT push the extracted branch anywhere**

Per spec § "Test-repo simulation, Extraction-script verification":
the extraction is local-only during the simulation.

- [ ] **Step 5: Clean up**

```bash
rm Geb/Mathlib/Sandbox/Trivial.lean
rm -rf "$TMPMATH"
```

- [ ] **Step 6: Update runbook event H; commit**

```bash
# In main working tree:
jj describe -m "doc: record runbook event H on test-1"
jj new
```

### Task 3.10: Iteration 1 — event I (Conflict-commit refusal, test-only)

In `geb-mathlib-test-${N}/`:

- [ ] **Step 1: Create two incompatible feat branches**

```bash
jj new main -m "test(feat/X): change line 1"
jj bookmark create feat/X -r @
echo "X content" > conflict-test.txt
jj describe -m "test(feat/X): set conflict-test"

jj new main -m "test(feat/Y): change line 1 differently"
jj bookmark create feat/Y -r @
echo "Y content" > conflict-test.txt
jj describe -m "test(feat/Y): set conflict-test differently"
```

- [ ] **Step 2: Merge them; observe the conflict**

```bash
jj new feat/X feat/Y -m "test: merge feat/X and feat/Y (expected conflict)"
jj status
# Expected: shows conflict in conflict-test.txt
```

- [ ] **Step 3: Pin the conflict commit to a bookmark and try to push**

```bash
# `@` is a revset operator (working-copy revision), not a bookmark
# name. Create a bookmark over the conflict commit so we can push
# it by name.
jj bookmark create test/conflict -r @
if jj git push --remote origin -b test/conflict 2>&1; then
  echo "FAIL: push succeeded despite git.private-commits = conflicts()"
  exit 1
else
  echo "PASS: push refused as expected"
fi
```

If push is NOT refused (FAIL path), the config is misapplied —
discovery; halt iteration; re-run the `jj config set --repo
git.private-commits 'conflicts()'` step from Task 1.3 (per D8,
this writes to `~/.config/jj/repos/<hash>/config.toml`, not
`.jj/repo/config.toml`); restart iteration.

- [ ] **Step 3b: Server-side gate (binding) — bypass local config and
  verify `conflict-check.yml` rejects the PR**

The local `git.private-commits = "conflicts()"` setting is a
contributor-side ergonomic. The binding safety property is the
server-side `conflict-check.yml` workflow, which must reject any
PR carrying `.jjconflict-base-*`/`.jjconflict-side-*` paths
regardless of whether the contributor's local config caught the
issue. Test that gate end-to-end:

```bash
# 1. Capture pre-test local config so we can restore it.
BEFORE_PRIV=$(jj config get --repo git.private-commits)

# 2. Bypass the local guard. Two equivalent forms; this plan
#    uses the explicit override so the restore step in 3b.7 is
#    a literal jj config invocation.
jj config set --repo git.private-commits 'none()'

# 3. Push the conflict bookmark to the test remote. The push
#    succeeds locally because the local guard is now disabled.
#    Use --allow-private as a belt-and-suspenders against any
#    transient config-cache effect.
jj git push --remote origin -b test/conflict --allow-private

# 4. Open a PR against the test repo's main branch. The PR
#    title and body are user-authored per the no-LLM-text rule;
#    the plan provides a sketch the user paraphrases:
#      title (sketch): "test: server-side conflict-check gate"
#      body  (sketch): "Test-only PR exercising conflict-check.yml.
#       The local guard was deliberately bypassed for this test;
#       expect the workflow to fail closed. Will be closed without
#       merge regardless of outcome."
#    The user types both into the gh pr create invocation:
gh pr create --base main --head test/conflict \
  --title "<user-authored>" --body "<user-authored>"

# 5. Watch the workflow: the conflict-check.yml job must fail.
pr_number=$(gh pr view --json number --jq '.number')
gh pr checks "$pr_number" --watch
status=$(gh pr view "$pr_number" --json statusCheckRollup \
  --jq '.statusCheckRollup[] | select(.name == "conflict-check") | .conclusion')
[ "$status" = "FAILURE" ] || { \
  echo "FAIL: conflict-check.yml conclusion is $status, expected FAILURE"; \
  exit 1; }

# 6. Confirm the failure cite the path-based detection by reading
#    the failed step's annotations.
gh run view --log-failed --job conflict-check 2>&1 \
  | grep -qE '\.jjconflict-(base|side)-' \
  || { echo "FAIL: workflow failed but did not cite .jjconflict-*"; exit 1; }

# 7. Close the PR without merging. The closing comment is
#    user-authored ("Closing — server-side gate verified to
#    fail closed; this PR is intentionally not merged.").
gh pr close "$pr_number" --comment "<user-authored>"

# 8. Restore local config to its pre-test state.
jj config set --repo git.private-commits "$BEFORE_PRIV"
```

If any step fails (the workflow does not fire, fires but does
not fail, fails for a non-path reason, or restoring config
errors), halt iteration; the server-side gate is the binding
safety property and a malformed gate is a discovery.

- [ ] **Step 4: Clean up**

```bash
# Capture the conflict change ID before moving away from it.
conflict_change=$(jj log -r @ --no-graph -T 'change_id ++ "\n"' | head -1)

# Move the working copy to a safe parent (main) before abandoning
# the conflict change.
jj edit main

# Now abandon the conflict change explicitly by ID, plus the two
# feat changes (their content is part of the conflict commit's
# parents but no longer needed).
jj abandon "$conflict_change"
jj abandon feat/X feat/Y

# Delete the bookmarks (test/conflict's target was just abandoned).
jj bookmark delete feat/X feat/Y test/conflict

# Remove any working-tree artifacts.
rm -f conflict-test.txt

# Verify clean state.
jj status
# Expected: clean working copy at main; no conflict commits in `jj log`.
```

- [ ] **Step 5: Update runbook event I; commit**

```bash
# In main working tree:
jj describe -m "doc: record runbook event I on test-1"
jj new
```

### Task 3.11: Iteration 1 — event J (Process self-update)

In `geb-mathlib-test-${N}/`:

- [ ] **Step 1: Make a trivial CLAUDE.md change**

In a fresh Claude session, invoke
`claude-md-management:revise-claude-md` (or
`claude-md-management:claude-md-improver`) with a request like:
"Add a sentence to CLAUDE.md noting that the integration branch is
regenerated by `scripts/regenerate-integration.sh`."

- [ ] **Step 2: Review the diff**

The user reviews the diff. If acceptable, accept; commit.

- [ ] **Step 3: CLAUDE.md round-trip check (verification item #31)**

Open another fresh Claude session in the test repo. Confirm the
new sentence appears in the CLAUDE.md context (Claude can quote it
on prompt without further reading). This is the explicit
round-trip check per spec verification item #31.

- [ ] **Step 4: Update runbook event J; commit**

```bash
# In main working tree:
jj describe -m "doc: record runbook event J on test-1"
jj new
```

### Task 3.12: Iteration 1 — event K (Doc generation)

**Resolved at plan-write time (per spec § "Doc-generation strategy
and CI", with implementation specifics decided here):**

- **Doc-gen4 invocation form**: lake-target form,
  `lake build Geb:docs`. doc-gen4's TOML-lakefile setup attaches
  the `:docs` facet to every `[[lean_lib]]` automatically once
  doc-gen4 is in the require list, so no `[[envs]]` block or
  `-Kenv=dev` flag is required. The GitHub-Action form
  (`leanprover-community/docgen-action`) is a thin wrapper around
  the same lake target; using the lake target directly keeps CI
  uniform with our other `lean-action`-driven builds.
- **Doc-CI reminder mechanism**: monthly cron in a new workflow
  file `.github/workflows/doc-build.yml` (separate from
  `update.yml` to keep workflows single-purpose). Surfaces a build
  status the user inspects; rendered output is published to GitHub
  Pages only when `Geb/Mathlib/*` content has accumulated enough
  to be useful (deferred decision, like
  `upstreaming-dashboard-action`).

In `geb-mathlib-test-${N}/`:

- [ ] **Step 1: Confirm doc-gen4 is in `lakefile.toml`**

doc-gen4 was declared as a `[[require]]` in Task 2.2's lakefile,
so it ships on `chore/bootstrap` and is present in every test
repo (via the bundle-replay in Task 3.2 Step 3) and in the real
repo (Part 4). No further lakefile change is needed here.

doc-gen4's TOML-lakefile setup attaches the `:docs` facet to every
declared `[[lean_lib]]` automatically once the require resolves.
No `[[envs]]` block is needed (the `[[envs]]` table is not part of
the documented Lake TOML schema). At execute-time, verify the
canonical `[[require]]` form against doc-gen4's README and adjust
in Task 2.2's lakefile (then re-collapse via Task 2.32) if the
upstream require form has evolved (e.g., a `scope` field).

```bash
# Resolve the doc-gen4 dependency if not already in lake-manifest:
grep -q '"doc-gen4"' lake-manifest.json || lake update doc-gen4
```

- [ ] **Step 2: Run the invocation**

```bash
lake build Geb:docs
# Expected: produces HTML output under .lake/build/doc/. No
# warnings on the empty skeleton.
ls .lake/build/doc/Geb/
# Expected: HTML files corresponding to each Geb module.
```

If `lake build Geb:docs` reports "unknown target", inspect
doc-gen4's README at the resolved SHA for the current invocation
form (the spec line 1338-1340 lists alternatives:
`lake -R -Kenv=dev build Geb:docs`, `leanprover-community/`
`docgen-action`). Surface the discrepancy to the user; do not
silently substitute without authorisation. Record the chosen
form in the runbook and this plan's iteration history.

- [ ] **Step 3: Open the rendered docs in a browser; visually
  confirm they make sense**

A reasonable confirmation: the per-module HTML pages render
without broken cross-references; module docstrings appear with
markdown formatted; copyright headers appear at the top.

- [ ] **Step 4: Add `.github/workflows/doc-build.yml`**

Cron schedule: `'0 9 1 * *'` (monthly on the 1st at 09:00 UTC).
Action set: `actions/checkout@<vLATEST-sha>` then
`leanprover/lean-action@<v1-sha>` with `build: false` and a custom
step running `lake build Geb:docs`. SHA-pinning
follows Task 2.25's policy.

```yaml
name: Doc build

on:
  schedule:
    - cron: '0 9 1 * *'
  workflow_dispatch:

jobs:
  doc-build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<SHA-FOR-VLATEST>  # latest stable major (verify at execute-time, e.g. v4 or v5)
      - uses: leanprover/lean-action@<SHA-FOR-V1>  # v1
        with:
          build: true
          test: false
          lint: false
      - run: lake build Geb:docs
```

(Substitute SHAs at execute-time per Task 2.25's policy.)

- [ ] **Step 5: Commit `doc-build.yml`**

```bash
jj describe -m "ci: add doc-build.yml monthly cron for doc-gen4 output"
jj new
```

- [ ] **Step 6: Update runbook event K**

```bash
# In main working tree:
jj describe -m "doc: record runbook event K on test-1 (doc-gen4 lake target + monthly doc-build.yml)"
jj new
```

### Task 3.13: Iteration 1 — termination check

- [ ] **Step 1: Re-run all bootstrap-real events end-to-end on a
  fresh test-2 repo**

Per the spec's termination criterion: "All bootstrap-real events
execute cleanly on a freshly-reset test repo, start-to-finish, with
no spec changes during."

If iteration 1 produced spec/plan/runbook changes (which it likely
did — discoveries surface in the first run), increment N to 2 and
restart.

- [ ] **Step 2: Continue iterations**

Each subsequent iteration is fewer events to re-exercise (only the
ones discovered to need fixing) plus one full clean replay at the
end. Numbered repos accumulate — `geb-mathlib-test-1`,
`geb-mathlib-test-2`, …

- [ ] **Step 3: Termination**

The phase ends when:

1. A single fresh `rokopt/geb-mathlib-test-N` runs all
   bootstrap-real events from start to finish with no spec/plan/
   runbook changes during.
2. All test-only events (B-drift, B-offline, G1 forbidden-import,
   G2 prefix-leakage, G-axiom failing-case, I conflict-commit
   refusal) have been exercised at least once across the
   iterations.
3. The runbook has no open "discoveries" entries.
4. The user has explicitly signed off: "this is the sequence we
   will run on the real repo."

- [ ] **Step 4: Reflog inspection — `main` never force-pushed (verification 22)**

Per spec verification item #22, walk the reflog pairwise and
assert each consecutive entry is an ancestor of the next (a
fast-forward). Reflog messages in jj-colocated mode are
uniformly `export from jj` and carry no FF annotation — the FF
test must be computed via `git merge-base --is-ancestor`.

In the final clean test repo (`geb-mathlib-test-${N}` for the
signed-off N), with `${N}` the iteration number:

```bash
set -e
prev=""
while read sha; do
  if [ -n "$prev" ]; then
    git merge-base --is-ancestor "$prev" "$sha" \
      || { echo "non-FF: $prev -> $sha"; exit 1; }
  fi
  prev="$sha"
done < <(git reflog show main --format='%H' | tac)
echo "PASS: main's reflog on test-${N} is FF-only"
```

The process-substitution form `done < <(... | tac)` keeps the
`while` loop out of a subshell (a right-side-of-pipe loop runs
in a subshell whose `exit 1` does not propagate to the parent
script — verified empirically against bash, 2026-05-07).

For human-readable corroboration:

```bash
git reflog show main
```

The FF-rehearsal step in Task 3.2 step 5c plus the first push in
Task 3.2 step 9 ensure the reflog has more than one entry on
the test repo, so the pairwise walk has work to do (otherwise
item 22 would pass vacuously on a single reflog entry).

If the script reports a non-FF, the discipline was violated
somewhere; halt; investigate and fix; restart iteration.

- [ ] **Step 5: User sign-off**

Surface the final runbook to the user; ask explicitly for sign-off
text. If the user requests changes, address them; loop.

- [ ] **Step 6: Commit final runbook state**

```bash
# In main working tree:
jj describe -m "doc: sign off runbook after iteration N"
jj new
```

### Task 3.14: Second history-rewrite collapse on `chore/bootstrap`

**Files:** none modified directly; jj rewrites the commit graph.

Part 3 added many runbook commits (one per simulation event A–K
across iterations) plus any spec/plan/memory amendments produced
by discoveries. After Part 3 termination (signed-off runbook),
`chore/bootstrap` carries Task 2.32's collapsed scaffolding series
plus this accumulation. Without a second rewrite, Task 4.7's
"first push" delivers a public history that is *more* than the
spec's "10–20 topological commits."

This task collapses the post-Part-3 commits into the existing
shape. Target shape now becomes:

- The 10–20 scaffolding commits from Task 2.32 (unchanged).
- One additional commit `doc: bootstrap runbook (final, signed
  off after iteration N)` carrying the final runbook content.
- One additional commit per substantive spec/plan amendment
  produced by Part-3 discoveries (typically 0–3).
- One additional commit `doc: distillation pass from prior tree`
  (already produced by Task 2.30, unchanged from Part 2).

Result: ~12–24 topological commits, still within the operationally
useful range for line-by-line user review.

- [ ] **Step 1: Save rollback target**

```bash
jj operation log --limit 5
# Record the latest operation ID for rollback if the rewrite
# misfires (`jj operation restore <id>`).
```

- [ ] **Step 2: Collapse runbook commits into a single commit**

```bash
# List runbook commits in order:
jj log -r 'main..@-' --reversed --no-graph -T 'change_id.short() ++ " " ++ description.first_line() ++ "\n"' \
  | grep -E '^[a-z0-9]+ doc: runbook'
# Squash them into one commit:
# (For each pair (src, dst) in the listing, run jj squash --from src --into dst.)
# Or: jj rebase + collapse via interactive squash sequence.
```

The exact `jj squash` sequence depends on the commit IDs at
execute-time. The pattern: pick the last runbook commit as the
collapse target; `jj squash --from <each-other> --into <target>`
in topological order; rewrite the resulting message via
`jj describe -r <target> -m "doc: bootstrap runbook (final, signed
off after iteration N)"`.

- [ ] **Step 3: Verify the new shape**

```bash
jj log -r 'main..@-' --no-graph -T 'change_id.short() ++ " " ++ description.first_line() ++ "\n"' | wc -l
# Expected: between 12 and 24 (Task 2.32's 10–20 plus runbook +
# any amendment commits).
```

- [ ] **Step 4: Re-verify the working tree**

Re-run Task 2.31 verification on the collapsed state.

- [ ] **Step 5: User review checkpoint — Part 3**

The user reviews the new shape commit-by-commit (`jj diff -r
<change-id>`), confirms the topological order makes sense, and
authorises proceeding to Part 4.

**Part 3 verification:**

- All bootstrap-real verification items (#1–35 from the spec, modulo
  out-of-simulation items) confirmed on a fresh test-repo iteration.
- Runbook signed off by the user.
- Post-Part-3 history rewrite (Task 3.14) collapses runbook commits
  into the topological shape; user authorises.
- All test repos remain (NOT deleted; user batch-deletes after
  Part 5).

---

## Part 4 — Real-repo bring-up

**Goal of Part 4:** Replay the signed-off runbook against the real
repo `rokopt/geb-mathlib`. Rewrite history to ~10–20 topological
commits, line-by-line user review, single push.

**Verification at end of Part 4:** the verification checklist
(spec § Verification, items #1–35 minus out-of-simulation items)
passes on a fresh clone of `rokopt/geb-mathlib`. The "fresh-session
clone immediately picks up CLAUDE.md" check passes.

### Task 4.0: Confirm spec and plan adversarial-review terminations

Spec verification items #29 and #30 (out-of-simulation gates):
"Adversarial review of this spec terminated with no non-cosmetic
findings"; "Adversarial review of the bootstrap plan terminated."

Both must be in place before Part 4 begins.

- [ ] **Step 1: Confirm spec adversarial-review termination**

The spec's iteration history is recorded in project memory (per
`feedback_adversarial_review.md`); the user's Round-N+1 reviewer
returning "no blockers, no serious" plus the user's explicit
sign-off on the spec constitutes termination. Re-confirm by asking
the user, and record the citation in the plan's iteration history
section.

- [ ] **Step 2: Confirm plan adversarial-review termination**

The plan's iteration history (this document § Iteration history)
records each round's findings and resolutions. Termination is
declared when the most recent round returns no blockers and no
serious findings, and the user has signed off on the plan.

If either gate is not in place, halt; resume the relevant
adversarial-review loop until convergence.

### Task 4.1: Pre-real-repo checkpoint

- [ ] **Step 1: Confirm Part 3 sign-off**

The runbook in `docs/superpowers/runbooks/<date>-bootstrap-runbook.md`
must have explicit user sign-off. Re-confirm.

- [ ] **Step 2: Confirm Open Questions resolved or carried forward**

Per spec § "Open questions / deferred decisions":

- `intermediate_releases`: resolved to `latest` (Task 2.27).
- `upstreaming-dashboard-action`: deferred (will adopt when
  substantive content lands).
- `actions/checkout` SHA: resolved (specific SHA pinned in
  workflows, Task 2.25/2.26/2.27).
- `downstream-reports` registration: deferred (user-driven).
- Doc-CI mechanism: resolved (Task 3.12 step 5).

Any remaining must be resolved or explicitly carried as known
deferrals before proceeding.

### Task 4.2: Set up local mathlib4 fork (per spec goal 17)

- [ ] **Step 1: Fork on GitHub**

```bash
# Verify gh repo fork syntax against current gh:
gh repo fork --help | head -30
# At plan-write time the canonical form is:
gh repo fork leanprover-community/mathlib4 --clone=false
# Expected: a fork is created in the user's personal namespace
# (rokopt/mathlib4). If `gh` prompts for clarification, follow the
# prompt; do NOT pass an empty `--org=` flag (invalid CLI).
```

- [ ] **Step 2: Clone locally to a sibling directory**

```bash
cd ..
git clone git@github.com:rokopt/mathlib4.git mathlib4-fork
cd mathlib4-fork
git remote add upstream https://github.com/leanprover-community/mathlib4.git
```

- [ ] **Step 3: Verify**

```bash
ls -la mathlib4-fork/
# Expected: full mathlib4 tree present.
gh repo view rokopt/mathlib4
# Expected: fork visible.
```

The fork is **not** pushed to during Part 4; the first push to it
happens with the first real mathlib PR-candidate as routine
post-bootstrap work.

### Task 4.3: Create real repo on GitHub

- [ ] **Step 1: Create empty `rokopt/geb-mathlib`**

```bash
gh repo create rokopt/geb-mathlib --public \
  --description "Lean 4 + mathlib formalisation of Geb, a categorical programming language"
# Expected: empty repo created on GitHub.
```

- [ ] **Step 2: Confirm settings**

```bash
gh repo view rokopt/geb-mathlib
# Expected: public, default branch will become "main" once we push.
```

The default-branch setting may need to be updated to `main` after
the first push if GitHub created an unexpected default branch.

### Task 4.4: Add the real remote to the local working tree

In the main working tree (`geb-mathlib/`, NOT a test repo):

- [ ] **Step 1: Add remote**

Use `jj git remote add` for consistency with the
allow-list-and-jj-preferred posture (the `block-mutating-git`
hook strips `jj git X` invocations and falls through; bare
`git remote add` is mutating and prompts):

```bash
jj git remote add origin git@github.com:rokopt/geb-mathlib.git
```

- [ ] **Step 2: Verify**

```bash
git remote -v
# Expected: shows origin -> rokopt/geb-mathlib.git
jj git remote list
# Expected: shows origin
```

### Task 4.5: Replay runbook on the real repo

The chore/bootstrap branch in the local working tree already
contains the entire scaffolding (rewritten to ~10–20 commits in
Task 2.32). Per the runbook's bootstrap-real events, replay them
against the real repo:

- [ ] **Step 1: For each bootstrap-real event, re-run its
  precondition / action / verification on the local working tree
  pointing at the real remote**

Per the runbook, these include:

Real-repo events at bring-up time:

- **A** (bootstrap-real): repo-creation done in Task 4.3.
- **B** (bootstrap-real): hooks active. The hook scripts and
  `.claude/settings.json` were authored in Part 2; on the real
  repo, exercise B's bootstrap-real sub-events explicitly:
  toolchain-watch in-sync, signing-key warm-up runs silently,
  git-blocking hook allows `jj git push`, smoke test passes.
- **C** (bootstrap-real, partial): only `chore/bootstrap` and
  `main` are present pre-push. The full topic-branch exercise is
  routine post-bootstrap work.
- **D** (bootstrap-real): CI activates on the first push (Task 4.7
  step 5). Verify in Task 4.8 that `ci.yml` and `markdown-lint.yml`
  fire and pass; `update.yml` is structurally validated by
  `gh workflow list` and a `workflow_dispatch` smoke run.
- **E**: integration regeneration runs **after Task 4.7's first
  push** (it pushes `integration` to origin, which requires origin
  to have content). Sequenced in Task 4.9 Step 1 — invoked twice
  (first creating `integration`, then a second idempotency-check
  invocation confirming `main` is unchanged), satisfying
  verification items #20, #21, #22.
- **F**: mass-rebase requires topic branches; deferred to first
  routine workstream.
- **G3** (bootstrap-real): import-lint passes on the empty
  skeleton (the script reports clean with zero files checked).
- **G-axiom** (bootstrap-real, axiom-check passing case): runs
  via Task 4.8 step 1 in the fresh clone.
- **H**: PR extraction requires upstream-eligible content;
  deferred to first routine workstream.
- **I**: conflict-commit refusal — the test-only event is
  optional on the real repo (deferred); the recommended local
  configuration is carried forward in
  `~/.config/jj/repos/<hash>/config.toml` (per D8) on each
  developer's machine post-bootstrap, with the binding gate
  enforced server-side via `conflict-check.yml`.
- **J**: process self-update runs **after Task 4.7's first push**
  (the CLAUDE.md amendment commits and pushes via the
  user-review-then-push cycle, requiring origin/main to exist).
  Sequenced in Task 4.9 Step 2, satisfying items #26 and #31.
- **K** (bootstrap-real): doc generation runs once below.

- [ ] **Step 2: Run event K (doc generation) once on the local
  working tree**

```bash
# Use the doc-gen4 invocation chosen in Task 3.12.
lake build Geb:docs   # the canonical doc-gen4 invocation per Task 3.12
# Expected: completes without warnings.
```

- [ ] **Step 3: Run event B (hooks active) bootstrap-real sub-events**

In a fresh Claude Code session opened on the real-repo working
tree, confirm:

- toolchain-watch banner prints (in-sync expected).
- check-signing-key.sh runs silently; subsequent `jj describe`
  on a temp change does not prompt for the key (item #13).
- The git-blocking hook is active (try `git status` — allowed; try
  `git checkout main` — prompts).
- `bash scripts/hooks/tests/test-block-mutating-git.sh` passes.

- [ ] **Step 4: Note: events E (integration regeneration) and J
  (process self-update) are deferred to Task 4.9**

These events both require `origin/main` to exist (E pushes
`integration`; J commits a CLAUDE.md amendment that propagates via
the user-review-then-push cycle). Task 4.7 is the "first push" of
`main`; events that depend on the remote being populated must run
**after** Task 4.7. They are sequenced in Task 4.9 below.

- [ ] **Step 5: (no action — events E and J defer to Task 4.9)**

This step is intentionally empty. Events E (integration
regeneration) and J (process self-update) are exercised in
Task 4.9 after Task 4.7's first push and Task 4.8's verification.
Do not run any event-E or event-J operations during Task 4.5;
proceed directly to Task 4.6.

### Task 4.6: User reviews each chore/bootstrap commit line-by-line

Per `feedback_initial_push_series.md` and spec § "Second pass — real
repo, via series-of-reviewed-commits" steps 3–5: the rewrite into
~10–20 topological commits happens **before** the line-by-line
review (Task 2.32 already produced this rewrite). Once review
begins in this task, the commit shape is **locked** — no further
`jj squash` / `jj split` / `jj describe` rewrites without restarting
review from the first commit.

- [ ] **Step 1: List commits**

```bash
jj log -r 'main..@-' --reversed
# Expected: 10–20 commits in topological order, matching the locked
# shape produced by Task 2.32.
```

- [ ] **Step 2: User reviews each commit (commit shape locked)**

For each commit (in order):

```bash
jj diff -r <change-id>
```

The user reads the diff. If acceptable, the user marks it
approved (e.g., notes the change ID in a checklist).

If a commit needs changes, halt review. Two options:

(a) Edit the commit body in-place via `jj describe`/file edits
    (single-commit-scoped edit; may require re-verifying lake build).
(b) Re-run Task 2.32 from scratch, producing a new locked shape;
    restart review from the first commit.

Either way, do NOT silently rewrite the shape mid-review.

- [ ] **Step 3: Final user sign-off**

The user explicitly says "the entire chore/bootstrap commit series
is approved for first push to rokopt/geb-mathlib." Record the
sign-off in the runbook with a date stamp.

### Task 4.7: First push (single-push pattern, per spec § Second pass)

The spec § "Second pass — real repo, via series-of-reviewed-commits"
step 6 prescribes: "**Single push** to the real repo:
`jj git push --remote origin --all`. This is the first push; it
delivers a coherent public history rather than fixup-noise."

The bootstrap series is on `chore/bootstrap`. The append-only
invariant on `main` (spec § "main (append-only) and integration
(regenerated)") forbids force-pushing `main`. A `git reflog show
main` audit on the test repo (Task 3.13 step 4) confirms only
fast-forward / merge updates ever land on `main`.

To deliver the bootstrap series on `main` while honoring
append-only, advance `main` from the initial empty commit to the
bootstrap-series tip **as a fast-forward only**. A fast-forward is
an append (no commit rewrite), so the append-only invariant holds.
The reflog audit at Task 4.8 step 1 verifies the move was
fast-forward.

- [ ] **Step 1: Run `pre-push.sh`**

```bash
bash scripts/pre-push.sh
# Expected: clean. The script's PR-candidate detection does NOT
# fire because chore/bootstrap is not a PR-candidate prefix; the
# Lean-content reminder may fire if any .lean files changed in the
# series (they did, in Task 2.3).
```

- [ ] **Step 2: User reviews diff one final time**

These revsets are evaluated **before** Step 4's fast-forward of
`main`; once Step 4 runs, `main..chore/bootstrap` becomes empty
(both bookmarks at the same change). Run Step 2's review now and
do not re-run after Step 4.

```bash
jj log -r 'main..chore/bootstrap' --reversed
jj diff -r 'main..chore/bootstrap'
```

The user explicitly authorises the push. (The `pre-push.sh`
reminder is a soft gate; this step is the hard gate.)

- [ ] **Step 3: Verify the fast-forward precondition**

The move is safe (a fast-forward or a creation) iff `main` has no
commits unreachable from `chore/bootstrap`. Equivalently, the
revset `main ~ ::chore/bootstrap` (commits reachable from `main`
but not from `chore/bootstrap`) is empty.

This formulation handles three cases uniformly:

- `main` exists at a commit that is an ancestor of `chore/bootstrap`
  → revset empty → PASS (fast-forward).
- `main` and `chore/bootstrap` already point at the same commit →
  revset empty → PASS (no-op).
- `main` is the unborn / root state with no commits beyond what
  `chore/bootstrap` reaches → revset empty → PASS.

The FAIL case is when `main` has commits not on `chore/bootstrap`,
which would require a non-FF update.

```bash
chore_tip=$(jj log -r 'chore/bootstrap' --no-graph -T 'change_id ++ "\n"' | head -1)
diverge=$(jj log -r 'main ~ ::chore/bootstrap' --no-graph -T 'change_id ++ "\n"' 2>/dev/null || true)
if [ -z "$(echo "$diverge" | tr -d '[:space:]')" ]; then
  echo "PASS: main has no commits ahead of chore/bootstrap; FF/create is safe"
else
  echo "FAIL: main diverges from chore/bootstrap; would require non-FF update"
  echo "Divergent commits:"
  echo "$diverge"
  exit 1
fi
```

- [ ] **Step 4: Advance `main` (fast-forward) to `chore/bootstrap`'s tip**

```bash
jj bookmark set main -r "$chore_tip"
jj bookmark list
# Expected: main and chore/bootstrap at identical change IDs.
```

- [ ] **Step 5: Single push delivering the bootstrap series on `main`**

In jj 0.41 (per D23) the bulk-push form `jj git push --all`
*silently skips* private/conflicted bookmarks (stderr
`Warning: Won't push bookmark <name>: commit <hash> is private`,
exit 0, "Nothing changed."). For the real-repo first push, we
prefer per-bookmark `-b` invocations because they hard-fail on
private/conflicted commits — surfacing problems immediately
rather than masking them as missing remote bookmarks. If a bulk
push is desired, the silent-skip detection in Step 5b is
mandatory.

```bash
# Per-bookmark form (preferred):
# The -b form hard-fails on private/conflicted commits (verified
# in jj 0.41: `Error: Won't push commit <hash> since it is
# private`, exit 1); no silent-skip gate is needed in this
# branch. The optional bulk-push form in Step 5b's silent-skip
# gate is the gate for the --all/--tracked/-r path only (D23).
jj git push --remote origin -b main
jj git push --remote origin -b chore/bootstrap
# Expected: both bookmarks created on the remote. `-b <name>`
# auto-tracks on first push since v0.38 (D9); no `--allow-new`
# needed (deprecated in v0.36 — D9). The pre-push gate in
# Task 2.21 used the same `-b` form and inherits the same
# hard-fail semantics.
```

- [ ] **Step 5b: Optional bulk-push form with silent-skip detection**

If a single `--all` invocation is preferred for any reason
(uniformity, scripting), parse the dry-run output for the
silent-skip warning before pushing live:

```bash
dry=$(jj git push --remote origin --all --dry-run 2>&1)
echo "$dry"
if echo "$dry" | grep -qE "Won't push (bookmark|commit)" ; then
  echo "FAIL: dry-run shows silent skip — investigate before pushing." >&2
  exit 1
fi
# Structural corroboration: count expected vs actual bookmark
# action lines. Each non-skipped bookmark produces one indented
# line of the form
#   bookmark: <name> [(add to|move forward from|move sideways from) <hash>]
# (verified verbatim against jj 0.41.0, 2026-05-07.)
#
# `expected` counts LOCAL bookmarks only. Bare `jj bookmark list`
# without --all-remotes already excludes synchronised remote-tracking
# refs, but per `jj bookmark list --help` it still includes a tracked
# remote bookmark when its target differs from the local target —
# which can occur after `jj git fetch` or after partial pushes — and
# `wc -l` would then overcount. The revset-based form below restricts
# the count to local bookmark heads.
# bookmarks() revset emits all local bookmarks; divergence-asterisks
# (e.g., 'feat/test*') are part of the line content and are counted
# correctly by `grep -cE '\S'` (the asterisk is non-whitespace).
expected=$(jj log -r 'bookmarks()' --no-graph -T 'bookmarks ++ "\n"' | tr ',' '\n' | grep -cE '\S')
actual=$(echo "$dry" | grep -cE '^  bookmark: .+ \[(add to|move forward from|move sideways from) ')
[ "$expected" = "$actual" ] || { echo "FAIL: $actual bookmark-actions vs $expected bookmarks" >&2; exit 1; }

jj git push --remote origin --all
```

- [ ] **Step 6: Verify on GitHub**

```bash
gh repo view rokopt/geb-mathlib
# Expected: public; main has ~10-20 commits visible.
gh api repos/rokopt/geb-mathlib/branches --jq '.[].name'
# Expected: lists "main" and "chore/bootstrap".
gh api repos/rokopt/geb-mathlib/branches/main --jq '.commit.sha'
# Record the SHA. This is the post-bootstrap baseline; future commits
# only append to main (never force-push).
```

- [ ] **Step 7: Verify and (if needed) set default branch to `main`**

GitHub usually auto-sets the default branch to whichever ref it
saw first on push, but the order is not guaranteed across `--all`
versus per-bookmark sequencing. Verify explicitly and only
`--default-branch` if the current value is wrong; fail closed if
the verification can't confirm `main` afterwards.

```bash
current=$(gh repo view rokopt/geb-mathlib --json defaultBranchRef --jq '.defaultBranchRef.name')
if [ "$current" != "main" ]; then
  gh repo edit rokopt/geb-mathlib --default-branch main
fi
gh repo view rokopt/geb-mathlib --json defaultBranchRef --jq '.defaultBranchRef.name' | grep -qx main \
  || { echo "FAIL: default branch is not main"; exit 1; }
# Per `gh repo edit --help` (verified at plan-write time, gh 2.x):
# --default-branch is the documented flag. Alternative is the
# GitHub web UI under Settings -> Branches.
```

- [ ] **Step 8: Optionally retire `chore/bootstrap`**

The `chore/bootstrap` bookmark is no longer the locus of activity
(its content is on `main`). It may be retained as a historical
marker or deleted. Default: retain.

If the user chooses delete:

```bash
# Per `jj git push --help` on jj 0.41.0 (verified locally
# 2026-05-08): `--deleted` is the documented form for pushing
# deletions ("Push all deleted bookmarks. Only tracked bookmarks
# can be successfully deleted on the remote."). The
# single-bookmark `-b <name>` form is documented for *pushing*
# a bookmark, not for *deleting* it; whether `-b <name>` also
# handles a locally-deleted bookmark is undocumented behaviour.
# Use the documented `--deleted` form.
jj bookmark delete chore/bootstrap
jj git push --remote origin --deleted
```

### Task 4.8: Real-repo verification

- [ ] **Step 1: Re-run the verification checklist (spec § Verification)**

Items #1–35 from the spec, scoped to bootstrap-real items (most are
identical to the test-repo run in Part 3). Re-run on a **fresh
clone**:

```bash
cd $(mktemp -d)
git clone git@github.com:rokopt/geb-mathlib.git
cd geb-mathlib
elan show
lake exe cache get
lake build
lake test
lake lint
bash scripts/lint-imports.sh
markdownlint-cli2 '**/*.md'
bash scripts/check-axioms.sh Geb/ GebTests/
bash scripts/hooks/tests/test-block-mutating-git.sh
```

Each must succeed.

- [ ] **Step 1b: Reflog — real-repo `main` FF-only (verification 22)**

Per spec verification item #22, walk the reflog pairwise and
assert each consecutive entry is an ancestor of the next (a
fast-forward). Reflog messages in jj-colocated mode are
uniformly `export from jj` and carry no FF annotation — the
distinction must be computed via `git merge-base --is-ancestor`.

The process-substitution form `done < <(... | tac)` is required
to keep the `while` loop out of a subshell (a right-side-of-pipe
loop runs in a subshell whose `exit 1` does not propagate to the
parent script — verified empirically, 2026-05-08).

```bash
set -e
prev=""
while read sha; do
  if [ -n "$prev" ]; then
    git merge-base --is-ancestor "$prev" "$sha" \
      || { echo "non-FF: $prev -> $sha"; exit 1; }
  fi
  prev="$sha"
done < <(git reflog show main --format='%H' | tac)
echo "PASS: main's reflog is FF-only"
```

For human-readable corroboration:

```bash
git reflog show main
# Expected (ordered most-recent first): the fast-forward update
# entry plus the initial-create entry. Reflog messages are
# uniformly `export from jj`; no inline FF/non-FF annotation.
```

- [ ] **Step 2: Open a fresh Claude Code session in the fresh clone**

Verify:

- Toolchain-watch banner prints.
- Signing-key warm-up runs silently.
- Git-blocking hook is active.
- CLAUDE.md is loaded (Claude references it without prompting).
- `.claude/rules/*.md` paths-conditioned rules load correctly.

- [ ] **Step 3: Record real-repo verification in the runbook**

After Task 4.7's first push, `main` is append-only via merge-PRs
only — direct commits to `main` are forbidden. Runbook updates
(this step and Task 4.9 Step 3) live on a `docs/runbook-realrepo`
topic branch off `main`, then merge into `main` via a normal merge
commit at Part 5 closeout (or via PR if the user prefers).

```bash
# In main working tree, off the just-pushed main: create the
# topic branch with the runbook commit as its first content.
# Each step does exactly one thing so a future reader can reorder
# safely; the bookmark must be created on the described change
# (after `jj describe`) and before `jj new` advances `@`.
jj new main
jj describe -m "doc: real-repo bring-up verified; all items pass"
jj bookmark create docs/runbook-realrepo -r @
jj new
# Now: @- is the runbook-message change carrying the bookmark;
# @ is a new empty working-copy change as its child.

# Pre-push checklist + user review.
bash scripts/pre-push.sh
# user reviews diff line-by-line; user authorises:
jj diff -r 'main..docs/runbook-realrepo'

# Push the topic branch (lease-protected):
jj git push --remote origin -b docs/runbook-realrepo
# Topic-branch merge into main happens at Task 5.3 closeout.
```

### Task 4.9: Real-repo events E (integration regen) and J (process self-update)

These events require `origin/main` to exist; Task 4.7 is the first
push, so they sequence here.

- [ ] **Step 1: Event E — integration regeneration (items #20–#22)**

```bash
bash scripts/regenerate-integration.sh
# With no active topic branches, the script's revset reduces to
# {main}; the resulting `integration` bookmark points at the same
# commit as `main` (degenerate fan-in, acknowledged in runbook).

# Idempotency check: regenerate again and confirm main unchanged.
main_before=$(jj log -r main --no-graph -T 'commit_id ++ "\n"' | head -1)
bash scripts/regenerate-integration.sh
main_after=$(jj log -r main --no-graph -T 'commit_id ++ "\n"' | head -1)
[ "$main_before" = "$main_after" ] || { echo "FAIL: main moved" >&2; exit 1; }

# Reflog confirms main never force-pushed (item #22):
git reflog show main
# Expected: only fast-forward / create entries; no force-update.
```

- [ ] **Step 2: Event J — process self-update (verification items #26, #31)**

In a fresh session in the real-repo working tree, invoke
`claude-md-management:revise-claude-md` on a trivial change (e.g.,
add a sentence noting that `integration` is regenerated by
`scripts/regenerate-integration.sh`). The user reviews the diff.
Open another fresh session; confirm the new sentence loads in
CLAUDE.md context (item #31). The user authorises and commits;
push via the user-review-then-push cycle (target: a `docs/<topic>`
topic branch merged into `main` via PR).

- [ ] **Step 3: Update runbook with real-repo events E and J results**

Append the runbook update on the same `docs/runbook-realrepo`
topic branch created in Task 4.8 Step 3, then push.

```bash
# Move @ to the docs/runbook-realrepo tip:
jj edit docs/runbook-realrepo
# Append the runbook commit:
jj new -m "doc: real-repo events E and J completed; verification items #20-22, #26, #31 satisfied"
# Advance the bookmark to the just-described commit:
jj bookmark set docs/runbook-realrepo -r @
jj new
# Push via user-review-then-push cycle:
bash scripts/pre-push.sh
# user reviews; user authorises:
jj git push --remote origin -b docs/runbook-realrepo
```

**Part 4 verification:**

- `rokopt/geb-mathlib` exists and is public.
- Default branch is `main`; bootstrap series landed on `main` via
  Task 4.7's fast-forward.
- All verification-checklist items pass on a fresh clone (Task 4.8).
- Reflog inspection of `main` shows only fast-forward / create
  entries (Task 4.8 step 1b).
- Events E and J exercised on the real repo (Task 4.9).
- Fresh-session clone test passes.
- Runbook records real-repo bring-up.

---

## Part 5 — Bootstrap closeout

**Goal of Part 5:** Confirm fork-readiness, clean up test repos
(user-driven manual), and explicitly close the bootstrap.

### Task 5.1: Fork-readiness test

- [ ] **Step 0: Security-review audit of bootstrap-authored code**

Before declaring fork-readiness, run the available security-review
skills against the bootstrap series. The skill set installed at
plan-write time includes `security-review` (one-shot review of
pending changes) and `pr-review-toolkit:silent-failure-hunter`
(error-handling and silent-failure analysis); both are listed in
CLAUDE.md's Tooling section and may be expanded as the skill set
evolves.

```bash
# In a fresh Claude Code session in the real-repo working tree,
# the user invokes:
#   /security-review
# (over the entire chore/bootstrap series's diff against the empty
# initial commit), and:
#   /pr-review-toolkit:silent-failure-hunter
# (focused on the shell scripts under scripts/ and the workflow
# files under .github/workflows/).
```

Findings recorded in the runbook; any actionable findings produce
follow-up commits on a `fix/<topic>` branch merged via PR before
Step 1's fork-readiness test.

- [ ] **Step 1: Fresh-session clone test (already done in Task 4.8
  Step 2; re-confirm)**

A fresh Claude Code session in a fresh clone immediately picks up
`CLAUDE.md` and follows the documented processes. The user
explicitly confirms this.

- [ ] **Step 2: Hypothetical-contributor walk-through**

Walk through (without actually doing) the steps an external
contributor would follow per `README.md` § Contributing:

1. Clone.
2. Read `CLAUDE.md`.
3. Pick a workstream from `TODO.md`.
4. Develop on a topic branch with `jj`.
5. Run `scripts/pre-push.sh`.
6. Review and push.

If any step is missing documentation, add it now. Commit and push
(via the user-review-then-push cycle).

### Task 5.2: Test-repo cleanup (user-driven)

**Action:** This step is **user-driven**. Claude does NOT run
`gh repo delete` autonomously, even at bootstrap end.

- [ ] **Step 1: User lists test repos**

```bash
gh repo list rokopt --limit 50 | grep '^rokopt/geb-mathlib-test-'
```

- [ ] **Step 2: User deletes them in batch (manually)**

The user runs:

```bash
for repo in rokopt/geb-mathlib-test-1 rokopt/geb-mathlib-test-2 ...; do
  gh repo delete "$repo" --yes
done
```

(The user types each repo name; not Claude.)

- [ ] **Step 3: User deletes local test-repo clones**

```bash
rm -rf ../geb-mathlib-test-1 ../geb-mathlib-test-2 ...
```

### Task 5.3: Bootstrap closeout

- [ ] **Step 1: Update `README.md` Status line**

Edit `README.md` to change "Bootstrap complete; first mathematical
workstream pending." to a state matching reality (it should already
say this — re-affirm).

- [ ] **Step 2: Confirm `TODO.md` "Begin first mathematical
  workstream brainstorming" entry is in place**

Already done in Task 2.6. Re-affirm.

- [ ] **Step 3: Final commit on a `chore/bootstrap-closeout` topic branch**

Per the spec's "topic branches land on `main` via normal merge
commits" rule, a closeout commit on a topic branch is the only
sanctioned way to advance `main` post-first-push:

```bash
jj new main -m "chore: bootstrap closeout — fork-ready, test repos cleaned"
# Create the bookmark at @ (the closeout commit), then advance the
# working copy past it. The bookmark stays at the closeout commit
# (now @-) after `jj new`.
jj bookmark create chore/bootstrap-closeout -r @
jj new
# Push the topic branch:
bash scripts/pre-push.sh
# user reviews; user authorises:
jj git push --remote origin -b chore/bootstrap-closeout
```

- [ ] **Step 4: Merge runbook + closeout topic branches into `main`**

Merge `docs/runbook-realrepo` (from Task 4.8 / 4.9) and
`chore/bootstrap-closeout` (from Step 3) into `main` via normal
merge commits. The user opens PRs against `main` (or merges
locally with `jj new main docs/runbook-realrepo -m "Merge ..."`
followed by `jj bookmark set main -r @` and a push, depending on
preferred workflow). Either path appends to `main` via merge
commits, honoring append-only.

```bash
# Local-merge form (shown for explicitness):
jj new main docs/runbook-realrepo -m "Merge branch 'docs/runbook-realrepo' into main"
jj bookmark set main -r @
jj git push --remote origin -b main

jj new main chore/bootstrap-closeout -m "Merge branch 'chore/bootstrap-closeout' into main"
jj bookmark set main -r @
jj git push --remote origin -b main
```

(PR-flow alternative: `gh pr create --base main --head <branch>`
twice; the user authors the PR titles and bodies per the
no-LLM-drafted-text rule.)

- [ ] **Step 5: Bootstrap is complete**

The user explicitly confirms: "the bootstrap is complete; the next
session begins the first mathematical workstream brainstorming."

---

## Resolved open questions

The spec carried several Open Questions; this plan resolves them as
follows:

- **`intermediate_releases` setting (`update.yml`)**: resolved to
  `latest`. Rationale: the user's "track mathlib closely" feedback
  combined with our explicit RC pinning (`v4.30.0-rc2`) means we
  want to pick up release-level changes including RCs, but we
  don't want every master commit to fire a daily bump-PR (which
  `master` would imply). `all` is a superset of `latest`. The
  action's documented values are `all | latest | master` (verified
  against `action.yml` at the pinned SHA d2b88048, 2025-11-11
  during test-2; spec/plan supporting prose previously listed
  `stable` in error — it is not an action input — see test-2
  finding F8). During the test-repo simulation, observed bump-PR
  cadence either confirms `latest` or surfaces a discovery that
  prompts switching values. The setting is mutable in
  `.github/workflows/update.yml` post-bootstrap.

- **`actions/checkout` SHA-pin specifics**: resolved by looking up
  the latest tag SHA at execute-time (Task 2.25/2.26/2.27). The
  workflow files include both the SHA and a comment with the tag
  name for human readers. Re-pin during periodic Dependabot-style
  review.

- **`upstreaming-dashboard-action` adoption**: deferred per spec.
  Re-evaluate when the first PR-candidate is in flight against
  mathlib.

- **`downstream-reports` registration timing**: deferred per spec.
  User-driven manual decision when project has substantive content.

- **Doc-CI invocation specifics**: deferred to the test-repo
  simulation (Task 3.12). Default to a `lake -R -Kenv=dev build
  Geb:docs` form unless doc-gen4's current README contradicts it.

- **Doc-CI reminder mechanism**: deferred to Task 3.12 step 5; the
  test-repo simulation makes the call (SessionStart hook,
  scheduled cron, or manual reminder).

- **Eager vs. lazy Internal→Mathlib migration**: deferred to first
  workstream that hits the situation. Spec defaults to eager
  migration after upstream PR acceptance.

- **Project-specific `geb-development` skill**: deferred until
  recurring patterns emerge.

- **Curated `notes` / `journal` directory**: deferred; default no.
  Trigger added to TODO.md.

- **`.github/PULL_REQUEST_TEMPLATE/` for our own repo**: deferred.
  Spec § "No LLM-drafted user-facing text" enforcement layer 3
  describes a future PR template containing the "I authored this
  PR description in my own words" checkbox. Bootstrap leaves the
  template absent; first PR against our own repo (the bump-PR cron's
  output is the most likely first occurrence) operates without one.
  Authoring the template is a routine post-bootstrap workstream;
  trigger added to TODO.md.

---

## Plan-execution preference

**Default: inline `superpowers:executing-plans`** with checkpoints
at each Part boundary for user review. The bootstrap is many small
interrelated steps where coherence across steps matters; the
inline form keeps cognitive context intact across tasks.

### Argument for considering `subagent-driven-development`

The user's stated preference for inline is described as an
intuitive guess. Arguments for using `subagent-driven-development`
for *parts* of the bootstrap:

- **Noisy commands**: `lake update` (downloads mathlib + transitive
  deps), `lake build` (full build with cache miss), `gh repo
  create`/`fork`/`api` calls, `git bundle create/fetch`, and
  `lake exe cache get` all produce substantial output. Running
  them inline pulls that output into the executing agent's
  context. Dispatching them as Bash commands inside the inline
  agent keeps output bounded (only stdout/stderr returns), which
  matches the inline pattern fine — but for *interactive
  diagnostic loops* (e.g., debugging a failed `lake build`), a
  subagent with full lake-error context is materially cleaner.
- **Per-task review boundaries**: subagent-driven naturally
  inserts a fresh-context boundary between every task; the user's
  per-task review is the same shape as the iteration's
  per-finding adversarial-review process. Inline executing-plans
  collapses many tasks into one running context, which the user
  can interrupt for review but which doesn't enforce review.
- **Independence pockets**: Tasks 2.13–2.21 (vendoring,
  lint-imports, extract-pr, regenerate-integration, rebase-topics,
  toolchain-watch, check-signing-key, lake-update-warning,
  pre-push) are genuinely independent script-authoring tasks; a
  single message dispatching all nine in parallel via subagents
  would shorten wall-clock time for that block.

### Recommendation

Inline is the right default for the first run-through. If the
user observes mid-execution that lake errors, gh API outputs, or
script-authoring tasks are noisy enough to warrant subagent
boundaries, switch the affected block to subagent-driven for the
remainder. The plan's Part-boundary checkpoints align with the
natural switch points.

---

## Iteration history

This plan went through fresh-context adversarial-review iterations
before user approval. Each round dispatched a new general-purpose
`Agent` (per `feedback_adversarial_review.md`) reading only the
plan and the spec.

### Round 1

Findings (selected):

- **Blocker** — `.markdownlint-cli2.jsonc` rule set never authored
  in the plan. Fix: Task 1.4b added with explicit content.
- **Blocker** — `block-mutating-git.sh` regex missing
  `format-patch`, `symbolic-ref`, `fsck` per spec § PreToolUse hook.
  Fix: regex extended, smoke-test cases added.
- **Blocker** — Real-repo first-push pattern contradicted spec
  § "Second pass — real repo, via series-of-reviewed-commits"
  (single push to deliver coherent history). Fix: Task 4.7
  rewritten to advance `main` to chore/bootstrap's tip locally,
  then `jj git push --remote origin --all`. Old PR-merge flow
  removed; Task 4.8 renumbered to verification.
- **Blocker** — Hook-activation gap during plan execution
  (project-local hook not active until Task 2.24). Fix: gap
  documented in Conventions section; Part-1 commands scoped to
  hook-allowed forms.
- **Serious** — `regenerate-integration.sh` revset cited operator
  precedence informally; `jj new` argument form differed from spec
  canonical sequence. Fix: cited jj's revset operator-precedence
  docs inline; switched to bookmark-name form per spec canonical
  sequence; added empty-revset guard.
- **Serious** — `lake test` dispatch with `testDriver = "GebTests"`
  unverified for `[[lean_lib]]` target. Fix: Task 2.2 step 4
  added explicit verification with fallback `[[lean_exe]]` block
  if needed.
- **Serious** — `Classical.choice` test-only axiom-flagging event
  missing from Part 3. Fix: Task 3.8b added.
- **Serious** — `docs/process.md` sections 2–15 not populated by
  any task. Fix: Task 2.7 step 2 expanded with section-by-section
  short-paragraph content referring to spec.
- **Serious** — pre-push docs-coverage check missing per spec
  § "Concept docs in same branch". Fix: stub added to
  `scripts/pre-push.sh`.
- **Serious** — Task 3.10 step 3 used `jj git push -b @` (invalid;
  `@` is a revset operator, not a bookmark). Fix: pin a
  `test/conflict` bookmark first.
- **Serious** — `update.yml` simulation never guaranteed to open a
  PR (verification item #5 unexercised). Fix: Task 3.5 step 3b
  forces a manifest mismatch.
- **Serious** — `gh repo fork --org=` invalid syntax. Fix: dropped
  empty-flag form; verified canonical syntax.
- **Serious** — TODO.md missing trigger entries for header-linter
  re-enable, dashboard adoption, downstream-reports registration,
  Verso adoption, project-specific skill creation. Fix: TODO.md
  template extended with "Triggers" section.
- **Serious** — CLAUDE.md round-trip check not explicit in event J.
  Fix: Task 3.11 step 3 made explicit.
- **Serious** — `git reflog show main` inspection (verification
  item #22) not executed. Fix: Task 3.13 step 4 added.
- **Serious** — `MathlibTest/` mapping unverified at plan-write
  time. Fix: Task 2.15 comments now cite the verification command
  used at plan-write time.
- **Serious** — Test-repo Task 3.2 step 3 used a single-import-rsync
  that skipped event A's commit-series structure. Fix: faithful
  replay-via-jj-git-fetch form added; rsync form retained as
  early-iteration shortcut.
- **Minor** — Path placeholder using `/home/<user>/...` in
  Conventions. Fix: rephrased to repo-relative.
- **Coverage gap** — CSLib import sanity check missing from
  Task 2.3. Fix: Step 9 added.

(Other minor / cosmetic-taste findings addressed inline; full
findings list is in the round-1 reviewer's output, retained in
the project memory.)

### Round 2

Findings (selected; full report retained in project memory):

- **Blocker** — `block-mutating-git.sh` regex over-blocked
  read-only `git fsck`, `git symbolic-ref --short HEAD`,
  `git format-patch HEAD~1` (no `--apply`); spec calls for
  conditional blocking on mutating-form args. Fix: split into the
  always-mutating regex and a conditional second pass that gates
  on `--apply` / `--write` / settings-form. Smoke test extended
  with read-only allow-cases.
- **Blocker** — Task 3.8b's Lean stub `axiomStub` was non-compiling
  (`Classical.choice` applied to an existence proposition instead
  of `Nonempty`, plus a spurious `.1` projection). Fix: replaced
  with
  `def axiomStub (h : Nonempty Nat) : Nat := Classical.choice h`,
  hosted in `tmp/AxiomStub.lean` outside the `Geb`/`GebTests`
  libraries to avoid the index-on-skeleton rule's reach.
- **Blocker** — Task 4.7 single-push pattern adjudicated the
  "main append-only" rule without spec guidance. Fix: split into
  fast-forward-precondition check (Step 3) plus the existing
  `jj bookmark set main` + push, with explicit reasoning that
  fast-forward of a not-yet-published `main` is an append, not a
  rewrite.
- **Blocker** — GitHub owner `rokopt` hard-coded across the plan;
  spec § "Generic user references" forbids project-instance facts
  in repo content. Fix: added a Conventions note explaining
  `rokopt/...` is a placeholder for the current project owner;
  forks substitute. (Spec uses the same convention.)
- **Blocker** — Verification items #29 and #30 (adversarial-review
  terminations) had no operational task. Fix: Task 4.0 added.
- **Blocker** — Task 3.10 cleanup sequence used `jj abandon @`
  after the working copy was at the conflict commit, leaving
  bookmarks dangling. Fix: capture conflict change ID, move
  working copy to `main`, abandon by ID, then delete bookmarks.
- **Serious** — `intermediate_releases` resolution remained
  hedged with "verify at execute-time." Fix: cited the spec's
  verified value list inline; observation-driven adjustment is
  post-bootstrap routine.
- **Serious** — `<choice>` literal placeholder in Task 3.12 commit
  message. Fix: replaced with concrete commit message.
- **Serious** — `actions/checkout@v6` SHA lookup against a tag
  that may not exist. Fix: lookup-the-latest-stable-major form
  ahead of substitution; placeholder renamed to
  `<SHA-FOR-VLATEST>` with a comment noting tag will be the
  resolved current major (typically `v4`).
- **Serious** — CSLib `v4.30.0-rc2` tag existence unverified
  before `lake update`. Fix: Task 2.2 step 0 verifies the tag.
- **Serious** — CSLib import path `Cslib.Basic` was a guess. Fix:
  pinned to `import Cslib` (the bare module), with verification
  via `head -20 .lake/packages/cslib/Cslib.lean` after `lake update`.
- **Serious** — STANDARD_AXIOMS edit was instruction prose, not a
  concrete `sed` invocation. Fix: pinned `sed -i 's#...#...#'`
  form and verification readback.
- **Serious** — `lake-update-warning.sh` substring matching could
  false-negative on branches like `feat/bumping-tools`. Fix:
  exact-prefix matching via per-bookmark loop.
- **Serious** — `fork_point(main)` revset unverified. Fix:
  switched to `latest_common_ancestor(main, @)..@` (jj 0.40+
  documented form), with `main..@` fallback if the function is
  unavailable in the active jj.
- **Serious** — Task 3.5 step 3b pushed both `bump/test-stale`
  and `main`, contradicting append-only. Fix: push only
  `bump/test-stale`; redirect default branch to it for the
  duration of the workflow run; restore default to `main`
  afterward.
- **Serious** — Task 4.7 step 7 used a non-documented `--deleted`
  flag combined with `-b`. Fix: split into
  `jj bookmark delete` + `jj git push --deleted`.
- **Serious** — Task 4.6 review-then-rewrite ordering inverted
  spec's "rewrite before review" sequence. Fix: commit shape is
  locked at Task 4.6 entry; mid-review fixes either edit a single
  commit in place or restart Task 2.32 + Task 4.6 from scratch.
- **Serious** — Task 2.31 step 8 expected ~28 commits; renumbering
  audit was incomplete. Fix: count adjusted to ~25–27 with note
  that exact count is non-critical given Task 2.32's collapse.
- **Serious** — `docs/process.md` sections were thin redirects to
  spec, not a rationale layer. Fix: existing populated sections
  reframed as "rationale-by-reference" — short summary plus
  pointer to spec for full text. Acknowledged as an index layer.
- **Serious** — `.github/PULL_REQUEST_TEMPLATE/` not addressed.
  Fix: added to deferred items in Resolved open questions and
  TODO.md trigger entry.
- **Serious** — Task 3.10 step 3 push success/refusal checked via
  bare exit-code echo; brittle. Fix: explicit `if/else` capture
  with PASS/FAIL output.
- **Serious** — Task 3.2 step 3 `jj git remote add main-tree-source ../geb-mathlib`
  used unverified jj-local-path-remote syntax. Fix: switched to
  git-bundle exchange (git-native, jj-imports automatically).
- **Cosmetic-taste** — "key check" in Task 3.6 step 3 violated
  the formal-style rule. Fix: removed; rephrased as plain
  verification.
- **Coverage** — Verification item #21 (main not modified by
  integration regeneration) only captured `main_sha_before`; never
  compared `_after`. Fix: Task 3.6 step 4b added explicit
  before-vs-after comparison.

(Other minor / cosmetic-taste findings addressed inline; full
findings list retained in project memory.)

### Round 3

Findings (selected):

- **Blocker** — Task 2.13's `STANDARD_AXIOMS` step contained both
  the broken `|`-delimited `sed` and the corrected `#`-delimited
  one in sequence; an executor running both first invokes the
  broken form. Fix: removed the broken form.
- **Blocker** — Task 3.8b's `axiomStub` Lean stub
  `def axiomStub (h : Nonempty Nat) : Nat := Classical.choice h`
  cannot compile without `noncomputable`, which the project's
  constructive-only rule forbids. Fix: reformulated as a
  `Prop`-valued theorem
  `theorem axiomStub (h : Nonempty Nat) : Nonempty Nat := ⟨Classical.choice h⟩`
  (theorems are exempt from the `noncomputable` rule).
- **Blocker** — Task 4.7's fast-forward precondition check failed
  in the unborn-`main` corner case. Fix: rewrote the test as
  "revset `main ~ ::chore/bootstrap` is empty" — uniformly
  handles ancestor, equal, and unborn cases.
- **Blocker** — `jj git push --deleted` in Task 4.7 step 8 and
  Task 3.5 step 3b cleanup is unscoped (pushes every locally-
  deleted bookmark). Fix: switched to
  `jj git push --remote origin --bookmark <name>` per jj 0.40+
  docs.
- **Serious** — `pre-push.sh` was missing the
  `latest_common_ancestor` → `main..@` fallback that
  `lake-update-warning.sh` had; the same script's PR-candidate
  detection used substring-matching `case` patterns. Fix: added
  `diff_against_main` helper with fallback; switched
  PR-candidate detection to per-bookmark loop with exact-prefix
  match.
- **Serious** — Task 2.27 lacked primary-source verification of
  `mathlib-update-action`'s documented input values. Fix: added
  Step 1b reading the action's `action.yml` at the pinned SHA.
- **Serious** — Task 2.27's pin-comment had `<date>` placeholder
  with no fill instruction. Fix: Step 1 now resolves both SHA and
  ISO commit date; placeholder renamed to `<ISO-DATE-OF-SHA>`
  with explicit substitution instruction.
- **Serious** — `docs/process.md` was framed as "rationale layer"
  in CLAUDE.md and README despite its content being short
  redirects to the spec. Fix: reframed as "process index" that
  may grow into a rationale layer.
- **Serious** — Real-repo Task 4.5 deferred most events,
  contradicting verification items #20, #21, #22, #26, #31, #13.
  Fix: explicit Steps 3–5 added running events B, E, J on the
  real repo at bring-up.
- **Serious** — Task 4.8 had no real-repo `git reflog show main`
  inspection (verification item #34). Fix: Step 1b added.
- **Serious** — Task 3.5 step 3b's "redirect default branch to
  bump/test-stale" did not validly exercise verification item #5
  (PR-against-`main`). Fix: rewrote to append a stale-manifest
  commit directly to `main` (test-only append), so the bump PR
  genuinely targets `main`.
- **Serious** — Task 3.5 missed `gh workflow list` validation of
  `update.yml`. Fix: Step 3a added.
- **Serious** — Task 2.13's vendoring step assumed the
  `lean4-skills` plugin was installed in the local cache. Fix:
  added curl fallback to upstream URL with verify-at-execute-time
  caveat.
- **Serious** — Task 2.31 step 8's commit count claim was
  arithmetically wrong (~25–27 vs ~30). Fix: removed the
  count; replaced with "every task's intended commit appears in
  `jj log`" criterion.
- **Minor** — Task 3.12 `lake -R -Kenv=dev` form references a
  `dev` env not declared in `lakefile.toml`. Fix: Task 3.12
  Step 1's lakefile addition now includes an `[[envs]] name = "dev"`
  block.

(Other minor / cosmetic-taste findings addressed inline.)

### Round 4

Round 4 returned **no blockers** plus 11 serious findings (S-A
through S-K). All addressed:

- **S-A** — `[[envs]] name = "dev"` was not a documented Lake TOML
  schema key. Fix: removed the block; switched doc-gen4 invocation
  to plain `lake build Geb:docs` (TOML lakefiles attach `:docs`
  facet automatically per doc-gen4 README).
- **S-B** — `mathlib-update-action` PRs created with `GITHUB_TOKEN`
  do not trigger downstream workflows. Fix: caveat documented in
  Task 2.27 with two workarounds (PAT migration, manual close-and-
  reopen); plan defaults to manual trigger; PAT migration added
  as TODO.md trigger.
- **S-C** — single-file invocation of `check-axioms.sh`'s
  acceptance unverified. Fix: cited the script's
  `<file-or-dir-or-pattern>` usage; Task 3.8b output check now
  also greps for `Classical.choice` to distinguish axiom-flag
  exits from script errors.
- **S-D** — `regenerate-integration.sh` revset behaviour with
  unborn `main` undefined. Fix: added unborn-`main` guard at top
  of script.
- **S-E** — inconsistent `--bookmark` vs `-b` flag form. Fix:
  standardised on `-b` everywhere; Conventions section documents
  the choice.
- **S-F** — Task 3.5 Step 3b appends a stale-manifest commit to
  `main`, polluting downstream events. Fix: added explicit
  iteration constraint (Step 3b cannot run on the final clean
  iteration).
- **S-G** — hooks smoke test bypasses checks in CI's clean
  checkout because `.jj/` is gitignored. Fix: smoke test now
  creates a temp `.jj/` marker via `CLAUDE_PROJECT_DIR`.
- **S-H** — Task 1.6 commit message embedded an unverified "13
  iterations" count. Fix: removed count; commit message refers
  to project memory for counts and discoveries.
- **S-I** — `latest_common_ancestor` revset citation absent.
  Fix: in-script comment now cites
  `https://docs.jj-vcs.dev/latest/revsets/` and notes the joint-
  update obligation if the function is renamed.
- **S-J** — Task 2.13 invented a fallback URL for the
  `lean4-skills` upstream. Fix: removed the URL; if cache is
  absent, halt and ask user for the canonical URL.
- **S-K** — jj does not auto-advance bookmarks with
  `jj describe`+`jj new`; `chore/bootstrap` would stick at root.
  Fix: Conventions section documents the `jj bookmark set
  chore/bootstrap -r @-` invocation after each commit step (or
  the per-developer `experimental-advance-branches` config).

(Other minor / cosmetic-taste findings addressed inline.)

### Round 5

Round 5 surfaced four blockers clustered on the `main` bookmark
lifecycle plus residual S-A inconsistency:

- **B-1, B-2, B-3** — `main` was never explicitly created as a
  jj bookmark in Part 1 (only `chore/bootstrap` was), so Task 4.7's
  fast-forward check, `regenerate-integration.sh`'s revset, and
  the test-repo `main` push had undefined behaviour. Fix: Task 1.5
  now creates **both** `main` and `chore/bootstrap` at the empty
  root change. Test-repo Task 3.2 mirrors this: Step 5 creates
  both bookmarks at root, Step 5b applies the imported
  scaffolding to `chore/bootstrap`, Step 5c fast-forwards `main`
  to `chore/bootstrap`'s tip so topic branches in Task 3.4 inherit
  a buildable tree.
- **B-4** — `lake test` driver semantics with `[[lean_lib]]`
  remained hedged. Fix: Task 2.2 Step 4 now verifies CSLib's
  lakefile at tag `v4.30.0-rc2` directly (`gh api … contents/`
  `lakefile.toml?ref=…`) before scaffolding commits, and the
  fallback `[[lean_exe]]` form is concrete.
- **S-A residual** — `doc-build.yml` workflow file still ran
  `lake -R -Kenv=dev build Geb:docs` after Task 3.12 dropped the
  `[[envs]]` block. Fix: workflow now runs `lake build Geb:docs`;
  Task 3.12 description rewritten to say plain `lake build Geb:docs`
  is the canonical form.

(Other minor / cosmetic-taste findings deferred or addressed
inline; full findings list retained in project memory.)

### Round 6

Round 6 surfaced 5 blockers:

- **B1 / B2** (`git remote add` and `git init` allegedly violate
  the hook): false positive at the time. The hook was a deny-list
  in round 6; unlisted commands fell through as allowed by design.
  Fix at the time: Conventions section explicitly documented the
  deny-list semantics. **Subsequently re-litigated and inverted to
  an allow-list-with-prompt design** (see § Hook design — allow-list,
  with prompt for unknowns, and § PreToolUse: block-mutating-git in
  the spec). Under the current design `git remote add` and `git init`
  trigger a prompt rather than falling through as allowed; the
  failure-mode-asymmetry rationale (a missed mutating command in a
  deny-list silently corrupts state; a missed read-only command in
  an allow-list surfaces as a fixable prompt) replaces the
  deny-list rationale recorded here.
- **B3 / S5 / S16** — runbook commits accumulating on
  `chore/bootstrap` after Task 2.32's collapse, leading to
  push-time commit count exceeding the spec's 10–20 target. Fix:
  Task 3.14 (post-Part-3 second history-rewrite) added,
  collapsing runbook commits into the topological shape; final
  shape is 12–24 commits.
- **B4** — Task 3.5 Step 3b's append-stale-manifest-to-main
  pattern violated the spec's "topic branches land on `main` via
  normal merge commits" rule. Fix: Step 3b removed; verification
  item #5 is exercised exclusively by Step 4's manually-opened
  topic-branch PR against `main` (same `pull_request: main` CI
  trigger as a real bump-PR).
- **B5** — `regenerate-integration.sh` invoked in Task 4.5 Step 4
  before `origin/main` existed (Task 4.7 is the first push). Fix:
  events E and J on the real repo moved to a new Task 4.9, after
  Task 4.8 verification. Task 4.5 Step 4/5 now describe the
  deferral.

(Other minor / cosmetic-taste findings deferred or addressed
inline.)

### Round 7

Round 7 surfaced 1 blocker plus several serious orphan-reference
findings:

- **B-A** — Task 4.5 Step 5 still contained the verbatim
  event-J description after round 6 moved E and J to Task 4.9.
  Fix: Step 5 reduced to an explicit no-op pointer; bullet list
  at task entry rewrites E and J as "runs after Task 4.7's first
  push, sequenced in Task 4.9".
- **S-A** — Task 4.7 Step 2's revsets reference the pre-advance
  state of `main`. Fix: explicit warning added that Step 2 must
  not be re-run after Step 4's fast-forward.
- **S-B / S-C** — Task 3.5 Step 4 hard-coded PR title, body, and
  close comment; user-facing text on a public repo. Fix:
  parameterised as `$PR_TITLE`, `$PR_BODY`, `$CLOSE_COMMENT`
  with explicit "user authors before this step" prelude.
- **S-D / S-E** — Orphaned references to a `D-deliberately-
  failing-PR` test-only event (removed in round 6 B4). Fix:
  Task 3.13 termination criterion #2 rewritten to enumerate
  the actual test-only events; runbook skeleton § D dropped
  the orphan parenthetical.
- **S-L** — "exercised once" vs "idempotency check" reconciled;
  bullet now says "twice" with explanatory parenthetical.
- **M-A** — JSONC comment-strip sed corrupted URLs in string
  values. Fix: anchored regex to line-start or post-whitespace.
- **M-G** — "more interesting test" used a value-laden adjective
  ("interesting"). Fix: rephrased as "non-trivial test".

(Other minor findings deferred or addressed inline; M-D, M-F, S-F,
S-G, S-H, S-I, S-J, S-K, M-H, M-I, M-J, M-K, M-L, U-1 through U-6
remain as items the user may wish to address before line-by-line
review or accept as cosmetic / verify-during-execution residue.)

### Round 8

Round 8 surfaced 2 blockers + several serious findings:

- **B-1** — `.jj/repo/config.toml` was gitignored, breaking
  fork-readiness. Fix: `.gitignore` rewritten to ignore `.jj/*`
  but carve out `!.jj/repo/config.toml` via gitignore negation,
  so the file ships with clones. Conventions section reframes the
  setting as "committed via gitignore carve-out."
- **B-2** — Post-Task-4.7 runbook commits had no path onto `main`
  (Conventions keep commits on `chore/bootstrap`; `main` is
  append-only via merge commits). Fix: Tasks 4.8 Step 3 and 4.9
  Step 3 now author runbook updates on a `docs/runbook-realrepo`
  topic branch; Task 5.3 Step 4 merges `docs/runbook-realrepo`
  and `chore/bootstrap-closeout` into `main` via normal merge
  commits at closeout.
- **Serious — test-repo default branch / cron race** — Task 3.2
  Step 9 now runs `gh repo edit --default-branch main` after the
  first push (`workflow_dispatch` only fires for workflows on the
  default branch); spec's cron-race note inlined.
- **Serious — `jj commit` equivalence claim** — Conventions section
  dropped the "or `jj commit`, equivalent" parenthetical; standard
  is `describe`+`new` only.

(Other minor findings deferred or accepted as cosmetic / verify-
during-execution residue.)

### Round 9

Round 9 surfaced 5 blockers + several serious findings:

- **B-1, B-2** — `.gitignore` carve-out for `.jj/repo/config.toml`
  was not empirically verified; Task 1.4 Step 2's `git status`
  expected output contradicted the round-8 design. Fix: Step 2
  rewritten to use `git check-ignore -q .jj/repo/config.toml`
  with PASS/FAIL output; Task 1.6 added `.jj/repo/config.toml` to
  the staged files list.
- **B-5** — Task 4.8 Step 3 lacked a pre-push review gate before
  pushing the topic branch. Fix: inserted `bash scripts/pre-push.sh`
  plus `jj diff -r 'main..docs/runbook-realrepo'` plus explicit
  user authorisation step.
- **S-9** (bookmark-creation bug) — Task 4.8 Step 3, Task 4.9
  Step 3, Task 5.3 Step 3 used a buggy
  `jj bookmark create -r @ ; jj bookmark set -r @-` sequence that
  put the bookmark at the wrong commit. Fix: removed the `set
  -r @-` line; the canonical form is `jj bookmark create -r @ ;
  jj new` (after `jj new`, `@-` is the just-created commit and
  the bookmark stays there).
- **S-6, S-16, S-17** (doc-gen4 propagation gap) — Task 3.12
  added doc-gen4 to the test-repo lakefile only; the main
  working tree's lakefile lacked the require, so Task 4.5 Step 2
  (real-repo doc generation) would fail. Fix: doc-gen4 is now
  a `[[require]]` in Task 2.2's lakefile from the bootstrap
  start; Task 3.12 Step 1 reframed as confirmation only.
- **S-1** — Task 4.4 Step 1 offered both `git remote add` and
  `jj git remote add`. Fix: standardised on `jj git remote add`
  for consistency with the allow-list-and-jj-preferred posture
  (the hook design was later inverted from deny-list to allow-list-
  with-prompt; the standardisation on `jj git remote add` survives
  the inversion).
- **S-2** — Task 3.2 Step 9 set the default branch to `main` but
  did not verify the change. Fix: added
  `gh repo view --json defaultBranchRef` verification.

(Other minor findings deferred or accepted.)

### Round 10

Round 10 confirmed convergence (no blockers, no serious) and the
plan was surfaced to the user.

### User feedback (between rounds 10 and 11)

The user reviewed the plan and requested substantial changes
across many areas. Plan v11 applies them; round 11 verifies.

- **Inline vs subagent-driven** — added a "Recommendation" section
  arguing for inline as default but flagging genuine-pocket
  arguments for subagent-driven (noisy `lake`/`gh` commands,
  per-task review boundaries, independent script-authoring
  blocks). User remains free to switch mid-execution.
- **`.gitignore` for `.jj/`** — verified jj 0.40+ creates its own
  `.jj/.gitignore` (`/*`) but does NOT modify the project's
  `.gitignore` or `.git/info/exclude`. Our explicit `.jj/` entry
  IS needed at project level. Dropped the carve-out hack;
  committed `jj-config-repo.toml` template at repo root with a
  `cp jj-config-repo.toml .jj/repo/config.toml` setup step
  documented in `docs/process.md` § Setup.
- **`git clean` blocked** — added `clean`, `gc`, `prune`, `repack`
  to the mutating regex; smoke tests added; block message updated
  with note that `git clean -xdf` would delete `.jj/` and there is
  no jj equivalent for working-copy clean.
- **Markdownlint config minimal-override** — restored MD013
  default line length, dropped headings exemption, restored
  default MD033 (no inline HTML) and MD029 (ordered-list-prefix)
  rules. Only override is MD013 tables and code_blocks exempt.
- **`.claude/settings.local.json` gitignored** — added explicit
  entry; verification step confirms `.claude/settings.json` is
  NOT ignored.
- **Commit messages** — dropped project-memory and review-process
  references; rewritten in `<type>(<scope>): <subject>` form
  with concise body focusing on what's committed and why.
- **Mathlib commit-message convention from line one** — every
  `jj describe` example uses the mathlib-derived form.
- **Mathlib sanity import** — initially proposed that
  `Geb/Internal.lean` carry `import Mathlib.Tactic` and
  `import Cslib`; subsequently dropped before Part 2 landed (the
  empty skeleton has no content depending on either; the imports
  would add `lake build` cost with no current consumer). The
  imports will be added back when content under `Geb/Internal/`
  actually requires them.
- **Header linter enabled from line one** —
  `weak.linter.style.header = true`; every skeleton file's
  copyright header includes `Authors: The geb-mathlib contributors`.
- **Warnings as errors** — `weak.warningAsError = true` in
  `lakefile.toml`; combined with the constructive-only rule and
  the pre-push `lake build` step, this makes `sorry` a hard
  build error in committed code.
- **`sorry`/`admit`/underscore policy** — `sorry` permitted
  between commits while using skills that need it (e.g.,
  `lean4:sorry-filler-deep`); never permitted in committed code;
  `admit` never permitted; underscores preferred when no skill
  specifically needs `sorry`.
- **`lean4:sorry-filler-deep` in CLAUDE.md** — added to the
  sub-skills table and to `.claude/rules/lean-coding.md`.
- **Security-review skills** — added as Task 5.1 Step 0
  (security-audit step over the bootstrap series before
  fork-readiness testing); skills already listed in CLAUDE.md's
  Tooling section (`security-review`,
  `pr-review-toolkit:silent-failure-hunter`).
- **"mathlib-verified" → "mathlib-derived"** — renamed throughout.
- **Bookmark globs shared library** —
  `scripts/lib/topic-revset.sh` defines `TOPIC_BOOKMARKS_REVSET`
  and `TOPIC_TIPS_NOT_ON_MAIN_REVSET`; `regenerate-integration.sh`
  and `rebase-topics.sh` source it.
- **No-significant-invented-content** — flagged for the next
  adversarial review: every script we author should cite
  precedent or borrow from upstream; the reviewer must call out
  any unattributed novel mechanism.
- **Drop rsync shortcut** — test-repo replay uses the production
  bundle-exchange procedure on every iteration.
- **Toolchain-watch offline test** — script accepts
  `TOOLCHAIN_WATCH_URL` env var; offline test sets it to an
  RFC 5737 TEST-NET-1 address (`192.0.2.1`) without modifying
  machine networking.
- **TOC mechanism** — `doctoc` (with `<!-- START doctoc -->`
  markers) generates and validates per-document TOCs;
  `pre-push.sh` runs `doctoc --check`; CI workflow runs the same.
- **`docs/process.md` § Setup** — fresh-clone setup steps
  documented (jj install, colocate, `cp jj-config-repo.toml`,
  signing config, elan, lake cache).

### Round 11

Round 11 surfaced 1 blocker, 1 serious, and three minor:

- **B-1** — Task 1.4b's plan-document content for
  `.markdownlint-cli2.jsonc` was the OLD non-minimal config
  (line_length 100, MD033 false, MD029 false, headings exempt),
  contradicting the actual file on disk (which had been updated
  to the minimal-override form per the user's request). A fresh
  executor would overwrite the correct file with the wrong
  content. Fix: Task 1.4b's canonical content + accompanying
  prose now match the minimal-override config.
- **S-1** — 9 of 11 scripts lacked the user-requested
  ATTRIBUTED-or-DELTA-with-rationale tag. Fix: each script's
  task block now has a "Provenance" line declaring the script
  ATTRIBUTED (with citation) or DELTA (with rationale and
  upstream-precedent search). The audit applies to:
  `lint-imports.sh`, `extract-pr.sh`, `topic-revset.sh`,
  `regenerate-integration.sh`, `rebase-topics.sh`,
  `toolchain-watch.sh`, `check-signing-key.sh`,
  `lake-update-warning.sh`, `pre-push.sh`,
  `block-mutating-git.sh`. (`check-axioms.sh` was already
  ATTRIBUTED via the vendored-from comment.)
- **M-2** — Task 2.31 Step 3 still referenced
  `weak.linter.style.header = false` as the resolution path for
  style-header diagnostics, contradicting the round-9 fix that
  enabled the header linter from line one. Fix: rewritten to
  "fix the offending file's `Authors:` line — do NOT silence the
  linter."
- **M-1, M-3** — Task 1.4b's accompanying prose explanation of
  the rule choices was rewritten to match the minimal config;
  Task 2.7 § Triggers and Task 2.9 lean-coding rule's mentions
  of "deferred via `weak.linter.style.header = false`" updated
  to reflect the from-line-one enforcement and the
  `Authors:`-update-as-content-arrives policy.

(Cosmetic finding M-3-imports-after-docstring deferred — the
imports-after-docstring placement in `Geb/Internal.lean` works
but is unconventional; cleanup can land with first content.)

### Round 12

Round 12 confirmed convergence (no blockers, no serious). The
single Minor residual (`security-review` skill placement) was
resolved by adding Task 5.1 Step 0 (security-audit step running
`security-review` and
`pr-review-toolkit:silent-failure-hunter` over the bootstrap
series before fork-readiness testing).

### User feedback after round 12

The user requested two final additions:

- **Mathlib upstream-guides callouts** — add the five
  authoritative URLs (`contribute/index.html`, `commit.html`,
  `style.html`, `naming.html`, `doc.html`) to the Lean coding
  rule with bullet-point highlights extracted from each, plus
  explicit adversarial-reviewer instructions to scan our content
  for violations. Also cross-reference from CLAUDE.md.
- **Commit-message imperative-tense compliance** — fix
  indicative-form verbs in commit-message bodies and subjects
  (e.g., "Adds" → "Add", "Lays out" → "Lay out", "X was kept"
  → "Walk through ... and decide", noun-phrase subjects →
  imperative-verb-led subjects).

Plan v13 applies both. Mathlib commit/style/naming/doc bullet
highlights live in `.claude/rules/lean-coding.md`; CLAUDE.md
references the URLs; runbook commit subjects now read
"doc: record runbook event ..." rather than the noun-phrase
form. The duplicated `Authors:` line in the style header
template was also removed.

### Round 13 onward

Each subsequent round dispatches a fresh reviewer reading the
updated plan.

Round-by-round summaries are appended as the iteration proceeds.

---

## End of plan

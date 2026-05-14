# geb-mathlib bootstrap design

**Date drafted**: 2026-05-04 — 2026-05-05.
**Authoring**: drafted by Claude through extended brainstorming with
the user; subject to fresh-context adversarial review before approval.

## Context

`geb-mathlib` is a brand-new Lean 4 + mathlib repository that distils
a coherent core of the project lead's decade-plus Geb language project
— earlier implementations exist in Coq/Rocq (gone), Idris/Idris-2
(frozen 2021–22 but live as a *concept source*), Agda (vestigial),
Common Lisp (vestigial), and Lean 4 (the prior `geb-lean/` tree at a
sibling directory, ~160 modules, the active focus at the time of
bootstrap). This new repository is the first that aims to be
coherent, modern-mathlib-shaped, and plausibly upstreamable from
line one.

The framing is **"reconceived for mathlib"**: decide what
contributions Geb makes that mathlib doesn't already have, formalise
those, and lean on mathlib for everything else. *"Reconceived"*
applies to **expression** (Lean encoding, naming, tactic style, file
layout), not to **mathematical content** — for any declaration whose
meaning corresponds to specific mathematics already proven in the
prior trees, the underlying object is fixed and the same theorems
must remain provable in the new representation.

The user wants the *process* — not just the code — baked in from the
first commit, with explicit mechanisms for the process to revise
itself.

This spec defines the *bootstrap* — the full set of process and
infrastructure work required to bring the project to a state where
routine mathematical/programming-language work can begin. There are
no further "phases" to design here; the next thing after the
bootstrap completes is regular work that proceeds with the same
processes the bootstrap establishes. **Mathematical content is a
non-goal of the bootstrap** and is the subject of separate
brainstorming once the bootstrap is done.

## Goals

The bootstrap delivers a project that is **actually underway** —
public, populated, and proven-functional under every documented
process. The 20 goals below group informally into "Skeleton and
conventions" (#1–13), "Test-repo simulation phase" (#14–15), and
"Real-repo creation and proving" (#16–20):

1. A working repository skeleton where `lake build` succeeds on an
   essentially-empty library skeleton.
2. All hard process invariants encoded as a layered system of
   `CLAUDE.md` (always-on rules) + `.claude/rules/*.md` (path-scoped
   conditional rules) + `docs/process.md` (rationale layer).
3. Directory structure laid out: `Geb/Mathlib/` (upstream-eligible),
   `Geb/Internal/` (downstream-only), `GebTests/Mathlib/`,
   `GebTests/Internal/`, with empty index files.
4. Toolchain pinned to current mathlib master (`v4.30.0-rc2` at
   bootstrap time).
5. CI in place: `lake build` / `lake test` / `lake lint` / the
   floodgate-CI per-branch import-rule linter / `markdownlint-cli2` /
   doc-generation verification / git-blocking-hook smoke tests /
   `conflict-check.yml` (the binding server-side gate against
   jj-conflict artefacts).
6. Local tooling: `.markdownlint-cli2.jsonc`, `.gitignore`,
   `LICENSE` (Apache 2.0, matching mathlib), `README.md`.
7. Skeleton extraction script (`scripts/extract-pr.sh`), floodgate
   linter (`scripts/lint-imports.sh`), axiom-check
   (`scripts/check-axioms.sh`, vendored from `lean4-skills`).
8. SessionStart hook for toolchain-watch
   (`scripts/toolchain-watch.sh`).
9. PreToolUse hook that prompts on raw mutating `git` commands
   (allow-list of read-only forms; unknown forms surface a
   permission prompt; `scripts/hooks/block-mutating-git.sh`).
10. `.remember/logs/` directory exists (silences the `remember`
    plugin's SessionStart hook noise).
11. `TODO.md` at repo root with at least one "first mathematical
    workstream" entry pointing at the next-up brainstorming.
12. This spec and a bootstrap implementation plan (in
    `docs/superpowers/plans/`), both passing adversarial review.
13. Prior-tree `CLAUDE.md` distillation pass completed; harvested
    conventions encoded in our `CLAUDE.md`, `docs/process.md`,
    `.claude/rules/*.md`, and `docs/references.md` (the latter
    being the home for mathematical / library references
    catalogues per the F9 amendment).
14. A throwaway public test repository (e.g.,
    `rokopt/geb-mathlib-test-1`, `rokopt/geb-mathlib-test-2`, …,
    one per iteration) where every documented process is
    exercised end-to-end before the real repo exists. The test-repo
    simulation iterates the spec until each documented event works
    correctly. *(Detailed simulation event list and design are in
    the "Test-repo simulation" section below.)*
15. A "process that actually worked" runbook recording exactly the
    commands, expected outputs, and recovery steps for each
    simulated event. This runbook is the operational blueprint used
    to bring up the real repo.
16. The real public GitHub remote (`rokopt/geb-mathlib`) created.
17. Local `mathlib4` fork at a sibling directory, plus a GitHub fork
    at `rokopt/mathlib4` (forking publishes nothing of ours).
18. jj initialised in colocated mode in the real repo; bootstrap
    branch + first user-reviewed commit pushed.
19. The runbook from (15) re-executed against the real repo, with
    every event passing per its **defined success criterion** (some
    events have inherent at-bootstrap-time limitations — see
    `update.yml` below — and their success criterion at bootstrap
    time is "structural validity," with full empirical validation
    deferred to post-bootstrap routine work).
20. The bootstrap is **complete** when the real repo is healthy and
    the next action — a piece of regular mathematical/programming
    work — could begin without bootstrap-level surprises.

**`update.yml` bootstrap-time success criterion**: our workflow
uses `leanprover-community/mathlib-update-action`, which does NOT
require registration with `downstream-reports`. The cron simply
runs `lake update` and opens a PR if mathlib has advanced. So
`update.yml`'s success criterion at bootstrap time is:

- The workflow file parses.
- It runs to completion when triggered via `workflow_dispatch`
  (any completion — including no-op if mathlib hasn't advanced —
  is acceptable).
- All referenced actions resolve and are pinned correctly.

The `downstream-reports` LKG/FKB-snapshot pipeline is a SEPARATE
mechanism we do **not** adopt at bootstrap (see the deferred
`downstream-reports` registration discussion later in the spec).

## Non-goals

The bootstrap deliberately excludes:

- **Any mathematical Lean content** beyond an empty library skeleton
  (a single trivial sanity-check definition is the maximum).
- **The first PR-candidate branch** (a future-mathematical-work
  item; once the bootstrap is done it'll be created as routine
  work).
- **Identifying the credentialing PR** (recurring checkpoint per
  project rules; until a real PR-candidate exists, we don't pick).
- **Adopting `leanblueprint`** (deferred until our prose / theorem
  inventory grows substantial; watch for the trigger).
- **Project-specific Lean skills under `.claude/skills/`**
  (deferred until friction arises that no rule or doc covers).
- **Adopting Verso** (deferred until doc-gen4 supports it, or
  mathlib migrates, or our prose grows substantial; watch for any).
- **Registering `geb-mathlib` with
  `leanprover-community/downstream-reports`** (the LKG/FKB
  pipeline). Registration generates daily Zulip
  `NEW_FAILURE`/`RECOVERED` notifications; spamming the community
  with these from a small / early-stage project would not serve
  the community. Decision to register is deliberately deferred
  beyond bootstrap and beyond first content commit, decided
  manually and periodically by the user when the project has
  substantive content the community is likely to care about.
  Bootstrap leaves the infrastructure ready
  (`update.yml`'s action set is a one-line swap from
  `mathlib-update-action` to the `downstream-reports` actions)
  but does NOT register.

## Repo structure

```text
geb-mathlib/                                    # repo root (jj+git colocated)
├── .claude/
│   ├── settings.json                           # project hooks
│   └── rules/                                  # path-scoped conditional rules
│       ├── lean-coding.md                      # paths: ["**/*.lean"]
│       ├── upstream-eligible.md                # paths: ["Geb/Mathlib/**", "GebTests/Mathlib/**"]
│       ├── markdown-writing.md                 # paths: ["**/*.md"]
│       └── ci-and-workflow.md                  # paths: [".github/workflows/**", "scripts/**"]
├── .git/                                       # authoritative VCS storage
├── .jj/                                        # jj local state (gitignored)
├── .gitignore
├── .markdownlint-cli2.jsonc                    # shared markdownlint config
├── .remember/logs/                             # required by remember plugin (gitignored)
├── .github/
│   └── workflows/
│       ├── ci.yml                              # build/test/lint/floodgate/hooks
│       ├── markdown-lint.yml                   # markdownlint
│       ├── conflict-check.yml                  # rejects PRs with jj-conflict artefacts
│       └── update.yml                          # daily mathlib auto-bump cron
├── CLAUDE.md                                   # ≤200 lines; always-on rules
├── LICENSE                                     # Apache 2.0
├── README.md                                   # public-facing
├── TODO.md                                     # active workstreams (topological)
├── Geb.lean                                    # root index
├── Geb/
│   ├── Mathlib.lean                            # upstream-eligible subindex
│   ├── Mathlib/                                # upstream-eligible code
│   ├── Internal.lean                           # downstream-only subindex
│   └── Internal/                               # downstream-only code
├── GebTests.lean                               # tests root index
├── GebTests/
│   ├── Mathlib.lean
│   ├── Mathlib/                                # tests for Geb/Mathlib/*
│   ├── Internal.lean
│   └── Internal/                               # tests for Geb/Internal/*
├── docs/
│   ├── index.md                                # "what's implemented" topological narrative
│   ├── process.md                              # rationale layer (decision history)
│   ├── references.md                           # math / library references catalog (F9)
│   └── superpowers/
│       ├── specs/
│       │   └── 2026-05-04-geb-mathlib-bootstrap-design.md   (this file)
│       └── plans/
│           └── 2026-05-04-geb-mathlib-bootstrap-plan.md
├── lake-manifest.json                          # mathlib SHA pin (committed)
├── lakefile.toml                               # Lake package config
├── lean-toolchain                              # matches mathlib master's pin
└── scripts/
    ├── extract-pr.sh                           # Path 1 PR extraction
    ├── lint-imports.sh                         # floodgate-CI per-branch linter
    ├── regenerate-integration.sh               # rebuild integration as fan-in merge
    ├── rebase-topics.sh                        # mass-rebase on toolchain bumps
    ├── toolchain-watch.sh                      # SessionStart hook
    ├── pre-push.sh                             # local pre-push checklist runner
    ├── lake-update-warning.sh                  # warns if lake update outside bump/* branch
    ├── check-axioms.sh                         # vendored axiom-check (lean4-skills derivative)
    └── hooks/
        ├── block-mutating-git.sh               # PreToolUse hook
        └── tests/
            └── test-block-mutating-git.sh      # smoke test for the hook
```

Outside the repo, by convention:

```text
$DEV_ROOT/                                      # whatever directory holds the dev's repos
├── geb-mathlib/                                # this repo
├── geb/                                        # historical reference (existing)
└── mathlib4-fork/                              # local clone of rokopt/mathlib4 fork
```

### Directory-structure principle: narrow and deep

Every directory has either a small number of subdirectories (and one
indexing `.lean` file imports them) OR a small number of source modules
(and one indexing `.lean` file imports them). "Small" is informally
< 10. Each individual `.lean` file targets ~300 lines, with a hard
ceiling of 1500 (mathlib's limit). The directory tree is a first-class
navigational interface; `ls -R` should give an immediate visual
impression of what exists.

### Forward-looking `Geb/Lean` subdirectory pattern

Once Geb has enough syntax to write code in Geb that's interpreted by
Lean code, a concept directory may have `Geb/` and `Lean/`
subdirectories. Pre-allocate this slot in the hierarchy now so we
don't have to refactor when the language reaches self-hosting.

### `README.md` initial contents

`README.md` is the public-facing front page of the repo on GitHub.
It is the documentation index, written in our standard formal-
mathematical-dry register (see Style Guidelines in CLAUDE.md). At
bootstrap time, before any mathematical content exists, the README
documents what *does* exist — the processes and the bootstrap
runbook — and links to the substantive material.

Required structure:

1. **Project name and one-paragraph identity**: what `geb-mathlib`
   is (a Lean 4 + mathlib formalisation of Geb, a categorical
   programming language whose first-class notions include
   "programming language" itself).
2. **Status**: "Bootstrap complete; first mathematical workstream
   pending." Updated as content lands.
3. **Dependencies**: mathlib + CSLib at the pinned versions; link
   to lakefile.toml.
4. **License**: Apache 2.0 (matching mathlib).
5. **Index of project documentation**: links to `docs/index.md`
   (eventual implemented-content topological narrative — empty at
   bootstrap), `docs/process.md` (rationale layer),
   `docs/references.md` (mathematical / library references
   catalog; populated during the geb-lean distillation pass —
   F9), the bootstrap spec at
   `docs/superpowers/specs/2026-05-04-geb-mathlib-bootstrap-design.md`,
   and the bootstrap plan at
   `docs/superpowers/plans/2026-05-04-geb-mathlib-bootstrap-plan.md`.
   If the bootstrap runbook
   (`docs/superpowers/runbooks/<date>-bootstrap-runbook.md`)
   exists at first-push time, link to it too. (At bootstrap time
   it's iteratively produced during the test-repo simulation; by
   the time the real repo is pushed it has stabilised and is
   committed alongside the rest.)
6. **Index of project processes**: link to `CLAUDE.md` (rules
   binding contributors); list of `.claude/rules/` files (briefly
   what each governs).
7. **Contribution pointers**: how an external contributor would
   start (clone, follow `CLAUDE.md`, brainstorm a workstream,
   write spec/plan, implement, push). Acknowledges the
   "production-ready ⇒ fork-ready" goal: any external developer
   should be able to clone, read CLAUDE.md, and immediately follow
   our processes.
8. **Pointers to upstream targets**: links to mathlib4 and CSLib
   (with note on our extraction model).

Length target: ~150 lines. The README grows as content lands,
but only as an *index* — it doesn't duplicate content from `docs/`
or process files.

## Lakefile and toolchain

### `lean-toolchain`

Matches mathlib master's pin (verified daily by `update.yml` cron and
the SessionStart toolchain-watch hook):

```text
leanprover/lean4:v4.30.0-rc2
```

### `lakefile.toml`

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
weak.linter.style.header = true   # enforced from line one
weak.warningAsError = true        # promote warnings to errors

# CSLib (Computer Science Library for Lean 4) — peer dependency.
# `scope = "leanprover"` matches CSLib's README example for
# downstream consumers. `rev` is a release tag that CSLib
# publishes (CSLib's tagged releases align with Lean toolchain
# releases). The pinned tag `v4.30.0-rc2` was re-verified
# 2026-05-07 via `gh api
# repos/leanprover/cslib/git/refs/tags/v4.30.0-rc2`, resolving
# to commit SHA `95fdc7dc863ff83e9d6c3a68fcb2505540462a4d`
# (S3). CSLib itself pins mathlib using a SHA in its own
# lakefile; that's independent of how we pin CSLib here.
# **Dual-pin caveat**: if our mathlib pin (via lake-manifest)
# disagrees with the mathlib pin CSLib's release tag was built
# against, Lake will resolve to one of the two (typically
# top-level wins). We coordinate by reviewing the bump-PR diff
# each time.
[[require]]
name = "cslib"
scope = "leanprover"
rev = "v4.30.0-rc2"

# Doc-gen4 is declared at bootstrap so the `:docs` facet is
# attached to every `lean_lib` target from line one. The doc-build
# CI workflow and any local `lake build Geb:docs` invocation
# depend on this require being present on `chore/bootstrap`.
# `rev` is required because lake defaults to looking up `master`
# when omitted, but doc-gen4's default branch is `main`. The rev
# should bump in lockstep with `lean-toolchain`; doc-gen4
# publishes a tag matching each Lean release. (F5)
[[require]]
name = "doc-gen4"
git = "https://github.com/leanprover/doc-gen4.git"
rev = "v4.30.0-rc2"

# Mathlib: declared LAST so its transitive dependency pins
# (plausible, importGraph) take precedence over cslib's and
# doc-gen4's; otherwise `lake exe cache get` computes wrong
# hashes and the warm cache misses every build. Verified
# empirically during test-2 (mathlib-first produced
# `error: mathlib: failed to fetch cache` with
# version-mismatch warning). No explicit rev field:
# lake-manifest.json (committed) carries the SHA pin;
# mathlib-update-action's cron in update.yml watches the
# manifest and runs lake update to bump it. (F4)
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

**`lintDriver` and `testDriver` are RESTORED**: an earlier draft
omitted these based on a survey that excluded CSLib. Both FLT
*and* CSLib set them, and they are functional necessities (without
`lintDriver`, `lake lint` is a no-op; without `testDriver`,
`lake test` cannot route to the test library). Our settings:
`lintDriver = "batteries/runLinter"` (matching FLT and CSLib;
batteries is pulled in transitively via mathlib) and
`testDriver = "GebTests"` (our test library name). These are added
back at the package level just below `defaultTargets` in the
lakefile snippet.

**`lean_lib` configuration — module discovery**: each `[[lean_lib]]`
entry sets `globs = ["<name>.*"]`. Per Lake's documented glob
semantics (verified in `Lake/Config/Glob.lean`):

- `Foo.*` matches the bare top-level module `Foo` and all its
  submodules `Foo.X`, `Foo.Y.Z`, etc.
- `Foo.+` matches *only* submodules (excludes the bare `Foo`).

We use `.*` because `Geb.lean` and `GebTests.lean` are bare
top-level index modules we want included. CSLib uses
`globs = ["Cslib.*"]` for its main library and
`globs = ["CslibTests.+"]` for tests (tests have no bare
top-level module); we use `.*` for both because we have an index
file at the top level of each library.

**Linter-invocation consistency**: CI uses `lean-action`'s
`lint: true` which calls `lake lint` against the linter set
declared in `[leanOptions]`. Local pre-push (`scripts/pre-push.sh`)
uses the same `lake lint` command. Earlier draft text mentioning
`lake exe linter` referred to the same thing (it was the older
mathlib-internal name); we standardise on `lake lint` everywhere
in this spec for clarity.

**`[[require]]` ordering**: `mathlib` is declared LAST among the
three requires (cslib, doc-gen4, mathlib). Mathlib pins specific
SHAs for transitive dependencies (`plausible`, `importGraph`) that
cslib and doc-gen4 also depend on; if mathlib is not declared
last, lake resolves transitive deps to the non-mathlib SHAs and
`lake exe cache get` computes wrong hashes — every build misses
the warm cache and falls back to building mathlib from source.
Verified empirically during test-2 (F4): mathlib-first produced
`error: mathlib: failed to fetch cache` with a version-mismatch
warning; reordering to mathlib-last produced clean cache fetches
(8386 files) with transitive deps resolved to mathlib's preferred
SHAs (`plausible 293af9b`, `importGraph fd70b40`). Mathlib's own
README documents this ordering for downstream projects.

`leanOptions` reflect a synthesis from a 7-project survey
(FLT, sphere-eversion, MIL, PFR, PNT&, equational_theories,
LeanProject template) and CSLib:

- **Universal across surveyed projects**: `pp.unicode.fun`,
  `autoImplicit = false`, `relaxedAutoImplicit = false`.
- **Standard linter set**: `weak.linter.mathlibStandardSet`,
  `weak.linter.flexible`. The `weak.` prefix is used by FLT
  AND by CSLib; some other projects use plain `linter.X`.
  We adopt `weak.` (matches the more recently-active projects).
- `maxSynthPendingDepth = 3` matches mathlib and FLT.
- **Divergence from FLT — `warn.sorry`**: FLT sets
  `warn.sorry = false` (silences sorry warnings). We deliberately
  diverge: we want sorry warnings visible during development as a
  signal of incomplete proofs, so we leave it at the default
  (warnings emit). FLT's choice makes sense for a project that
  treats sorry as an intentional placeholder mid-development; for
  us, every sorry is a tracked debt we want loud.
- We set `weak.linter.style.header = true` from line one. The
  mathlib header linter requires a complete `Authors:` line on
  every `.lean` file; rather than disable it through the
  bootstrap and re-enable later (FLT's "accruing technical debt"
  approach), the bootstrap scaffolding's empty index files carry
  the placeholder line `Authors: The geb-mathlib contributors`,
  which satisfies the linter from line one. When real Lean
  content lands and an actual author has touched a file, the
  `Authors:` line is updated to that contributor's name as part
  of the workstream that introduces the content.
- We set `weak.warningAsError = true` to promote every
  Lean warning project-wide (including `sorry` warnings,
  unused-variable diagnostics, and linter warnings) into build
  failures. Combined with the constructive-only discipline
  (no `noncomputable`; minimise `Classical`; see § "Constructive-only
  Lean code"), this makes a `sorry` in committed code a hard
  build failure rather than a soft warning, supporting the
  spec's invariant that `lake build` succeeds with no
  diagnostics on every committed state.

`defaultTargets` includes only `Geb`, not `GebTests`. Tests run via
`lake test` (driven by `testDriver = "GebTests"`) so they don't
slow down every `lake build`.

**Mathlib pinning model**: the lakefile declares the dependency
without a `rev =` field; the SHA pin lives in `lake-manifest.json`
(committed). `mathlib-update-action`'s cron drives bumps by
running `lake update` and committing the manifest change. This
matches the LeanProject template's pattern. Note: CSLib uses an
explicit `rev = "<sha>"` form; either is valid. We follow
LeanProject's simpler form (one source of truth — the manifest).

**CSLib pinning**: `rev = "v4.30.0-rc2"` pins to a CSLib release
tag. CSLib publishes tagged releases aligned with Lean toolchain
releases (verified: tag `v4.30.0-rc2` exists, released
2026-04-18). The `scope = "leanprover"` matches CSLib's README
example for downstream consumers. CSLib's own lakefile pins
mathlib via a SHA; that's CSLib's choice and is independent of
how we pin CSLib.

**`lake update` discipline**: only `bump/*` branches run
`lake update` (or accept its output via the auto-bump PR). A
pre-commit warning script reminds about this when
`lake-manifest.json` changes outside a bump branch.

### `lake-manifest.json`

Committed (mathlib convention). Pins the actual mathlib SHA between
`lake update` invocations; gives reproducible builds.

### `.gitignore`

```gitignore
.DS_Store
.cache
.lake
**/__pycache__/    # in case scripts/ ever gains Python helpers
.jj/
.remember/        # remember-plugin local state, all of it
```

`lake-manifest.json` is **not** ignored. The entire `.remember/`
directory is gitignored: it's local plugin state (now.md, recent.md,
archive.md, today-*.md, logs/), not part of the repo. Earlier
draft only ignored `.remember/logs/`; expanded for completeness.

### `.editorconfig`

None. Verified absent in `leanprover-community/mathlib4` master
2026-05-07 (M5); we follow that.

## Lean 4 module system

Every `.lean` file uses Lean 4's module system:

```lean
/-
Copyright …
-/
module

public import Foo.Bar
import Bar.Internal
```

The `module` keyword (after the copyright block) declares the
file as a Lean 4 module. Imports re-exported to downstream users
use `public import`; imports whose contents are used only
internally use plain `import`. This authoring convention is
required for two reasons:

- **Upstream extractability**: both mathlib and CSLib have
  adopted the module system upstream (verified against mathlib
  `Mathlib.Algebra.Group.Basic` and CSLib `Cslib/Init.lean`).
  Files authored in plain-import form would not be extractable
  to either via `scripts/extract-pr.sh`.
- **Minimised-imports enforcement**: `lake shake` operates only
  on module-form files. The pre-push checklist and CI run
  `lake shake --add-public --keep-implied --keep-prefix Geb
  GebTests`; CSLib's CI runs the same `lake shake` command with
  the same flags. The flag set is mirrored verbatim from CSLib;
  `--add-public` only affects how shake's `--fix` would write
  new imports (we do not run `--fix`).

The smoke test `scripts/tests/test-lake-shake.sh` guards both
the flag interface (grep-checking `lake shake --help` for the
flag names) and semantic detection (injecting an unused mathlib
import into a tracked file, rebuilding, asserting that shake
reports it, and restoring) against silent toolchain regressions.
Operational details in `.claude/rules/lean-coding.md` § Lean 4
module system; rationale in `docs/process.md` § Lean 4 module
system.

## VCS workflow

### Prerequisites

Before any `jj` invocation:

- **jj >= 0.41.0** (project pin; `jj --version`). 0.41.0 is the
  current pin; the project tracks jj closely. Behaviour discoveries
  D8–D26 (in the bootstrap discoveries log) reference v0.20–v0.41
  semantics; the spec below assumes 0.41.
- **git >= 2.41.0** (D13: jj v0.38 raised the floor;
  v0.40+ refuses to run with older git). On macOS, this requires
  Apple "Developer Tools" 26 or a Homebrew-installed git; system
  git on older Xcode CLT versions is too old.
- **jj user identity configured** (D6: jj does not auto-inherit
  git's `user.name`/`user.email`):

  ```bash
  jj config get user.name  || jj config set --user user.name  "Your Name"
  jj config get user.email || jj config set --user user.email "you@example.com"
  ```

- **Working tree is NOT inside an existing git worktree**
  (D14: `jj git init --colocate` refuses inside a worktree as
  of v0.38). For the real-repo bring-up, choose a directory
  that is itself the repo root, not a worktree of another repo.

### Known contributor-side constraints (S5)

The `git >= 2.41.0` floor (D13) is a real friction point for
contributors on systems whose vendored git is older. As of
2026-05-07 the affected baselines include RHEL 8 (system git
2.27), Ubuntu 22.04 LTS (2.34), and macOS pre-Xcode-CLT-26
(varying). Contributors on locked-down corporate machines may
not be able to install a newer git system-wide.

The escape hatch: **the maintainer-side jj workflow is not
required for external contributors**. An external contributor
making a one-shot PR can use plain git only (clone, branch,
commit, push, open PR via the GitHub web UI or `gh`). All of
the project's safety properties depend on
**server-side CI** (the `conflict-check.yml` gate, the
required-status-check on `main`, etc.), not on the contributor
running jj locally. The maintainer-side scripts
(`regenerate-integration.sh`, `rebase-topics.sh`, `pre-push.sh`)
and the recommended local jj configuration apply to the
**maintainer's** working tree, not to external contributors'.
This preserves the fork-readiness invariant: a contributor with
git ≥ 2.0 (functionally any modern system git) can still fork,
clone, branch, commit, and submit a PR — only the maintainer
needs jj 0.41+.

### Repository setup (one-time)

```bash
cd $REPO_ROOT          # the dev's geb-mathlib clone
git init --initial-branch=main
jj git init --colocate
```

`.git/` is authoritative storage; `.jj/` is local-only state
(gitignored).

**Note on `git init --initial-branch=main` redundancy** (M1,
verified against jj 0.41.0 on 2026-05-07): when run in a directory
without a pre-existing `.git/`, `jj git init --colocate` itself
initialises the colocated `.git/` with `HEAD` already pointing at
`refs/heads/main` (jj's default). The explicit `git init
--initial-branch=main` step above is therefore redundant in the
default case. We keep it in the canonical sequence for explicitness
and because it is harmless if `.git/` does not yet exist; in
recovery scenarios where a partial `.git/` is present, the
explicit `git init` is the safer of the two orderings.

**Note on `--colocate`** (one-time clarification, applies to
every `jj git init` / `jj git clone` invocation in this spec):
since jj v0.34 (D12) colocation is the default. The `--colocate`
flag is redundant unless `git.colocate = false` has been set;
we keep it explicit throughout the spec for readers' clarity, with
no behaviour change.

### Recommended local jj configuration (per-developer)

Per jj v0.38 (D8), per-repo config is stored *outside* the repo at
`~/.config/jj/repos/<hash>/config.toml` (auto-migrated; the docs
state the move was for security reasons). A committed
`jj-config-repo.toml` template that is `cp`'d into `.jj/repo/` no
longer survives — jj migrates the file out. The project therefore
**recommends** (does not enforce) the following local settings,
documented in `docs/process.md § Setup` for contributors to apply
themselves once after `jj git init --colocate`:

```bash
# Refuse to push commits with conflicts (and their descendants).
# The local hard-fail is a contributor convenience; the
# binding safety check is server-side (see "Local-vs-server safety
# model" below). In jj 0.41 (D23), `jj git push --all`/`--tracked`
# /`-r REVSETS` SKIPS private/conflicted bookmarks rather than
# failing — yet another reason the binding gate is server-side.
jj config set --repo git.private-commits 'conflicts()'

# Auto-track newly-pushed bookmarks on `origin`. Replaces the
# deprecated `git.push-new-bookmarks = true` (D2/D9). Note: since
# jj v0.38 a bare `jj git push -b <name>` already auto-tracks the
# bookmark; this glob covers `--all`/`--tracked` first-pushes too.
jj config set --repo remotes.origin.auto-track-bookmarks 'glob:*'

# Optional: bookmark-advance helper (D10/D11; replaces the removed
# `experimental-advance-branches` config). Lets `jj bookmark
# advance <name>` move a bookmark forward to `@` without an
# explicit `-r @-` argument.
jj config set --repo revsets.bookmark-advance-from 'heads(::to & bookmarks())'
jj config set --repo revsets.bookmark-advance-to   '@'
```

The project does **not** ship a setup script that runs the above
on a contributor's behalf — running config commands silently on
someone's machine is invasive. Contributors who skip these steps
may produce conflicted commits in their fork; the project's
server-side CI rejects PRs that contain such commits, so any
breakage is bounded to the contributor's own clone.

Per-developer signing config (`~/.config/jj/config.toml`
`[signing]` block) and identity (`user.name`/`user.email`) are
genuinely user-owned and live in the user-level config; they
are out of scope for repo-level setup.

### Branch / bookmark naming

| Prefix | Use | Eligible as PR-candidate? |
| --- | --- | --- |
| `main` | **Append-only** stable branch; never force-pushed | No (target of PRs, not a PR source) |
| `integration` | Regenerated fan-in merge view of `main` + active topic branches; force-pushed as topic tips move | No |
| `feat/<topic>` | New mathematical content / new functionality | **Yes** — primary PR-candidate prefix |
| `fix/<topic>` | Correcting a bug in existing code | **Yes** |
| `refactor/<topic>` | Restructuring without behavioural change | **Yes** |
| `migrate/<topic>` | Internal → Mathlib migration | **Yes** (the Mathlib version becomes the PR) |
| `chore/<topic>` | Tooling / CI / scaffolding | No (geb-mathlib-internal only) |
| `docs/<topic>` | Project documentation only | No (geb-mathlib-internal only) |
| `bump/<lean-version>` | Toolchain/mathlib bump | No (geb-mathlib-internal only) |

A "PR-candidate" branch is one whose content lives under
`Geb/Mathlib/*` and is intended for eventual mathlib upstream. The
`feat/`, `fix/`, `refactor/`, and `migrate/` prefixes are the
candidates; `chore/`, `docs/`, `bump/` are repo-internal only.
**Note (S4)**: PR-candidacy controls upstream-eligibility; it
does NOT restrict which branches appear in the regenerated
`integration` snapshot. See "Integration scope vs PR-candidacy"
above.

### `regenerate-integration.sh` revset contract

The script computes `integration`'s parent set as: `main`'s tip
plus the tips of all currently-active topic-branch bookmarks
whose changes are NOT already reachable from `main` (because
once a topic is merged into `main`, including it again in the
`integration` fan-in is redundant). Concretely (jj revset form):

```text
main | (bookmarks(glob:"feat/*")     ~ ::main)
     | (bookmarks(glob:"fix/*")      ~ ::main)
     | (bookmarks(glob:"refactor/*") ~ ::main)
     | (bookmarks(glob:"migrate/*")  ~ ::main)
     | (bookmarks(glob:"chore/*")    ~ ::main)
     | (bookmarks(glob:"docs/*")     ~ ::main)
     | (bookmarks(glob:"bump/*")     ~ ::main)
```

(`A ~ ::B` reads as "A excluding ancestors of B," i.e., topic
branches whose tips aren't yet reachable from `main`.) Parentheses
above are explicit per-clause for reader clarity (M2, round 4) — jj's
revset grammar binds `~` (priority 6) tighter than `|` (priority 7),
so the grouping shown is what the bare form would parse to anyway,
but the explicit parens remove any ambiguity for readers who don't
have the precedence table memorised. The script
runs `jj git fetch` first to refresh lease state, then
`jj new <those revs> -m "integration: ..."`, then
`jj bookmark set integration -r @`, then
`jj git push --remote origin -b integration`. After a topic
branch's content lands on `main` (via normal merge), it drops out
of the fan-in revset on the next regeneration. After a topic
branch is rebased onto a new `main` (e.g., post-bump), the
regeneration picks up the new commit IDs.

### `main` (append-only) and `integration` (regenerated)

**`main`** is **append-only**, immutable history. Topic branches
land on `main` via normal merge commits. Never force-pushed. This
is what GitHub serves as the default branch; what `git clone`
produces; what PRs against our own repo (e.g., the bump-PR cron)
target. Production-ready repos must be fork-friendly; force-pushed
`main` is incompatible with that goal.

**Bookmark anchoring (D3)**: jj bookmarks track *change-ids*,
which persist across `jj describe`/`jj metaedit`/edits. Pinning a
bookmark to a change-id that subsequently accumulates content
moves the bookmark with it — bookmarks do not "stay at an empty
starting commit" by themselves. Anchoring `main` at `root()`
(jj's synthetic null change `zzzzzzzz 00000000`) was considered
and rejected: jj refuses to export a bookmark pointing at the
synthetic root to git (`Warning: Failed to export some bookmarks:
main@git: Ref cannot point to the root commit in Git`), so
`refs/heads/main` is never created and `jj git push -b main`
publishes nothing on the remote — empirically verified against
jj 0.41.0.

`main` is therefore anchored at an **empty placeholder commit**
created at the start of Part 1. Both `main` and `chore/bootstrap`
initially branch off the placeholder; `chore/bootstrap` accumulates
the bootstrap work; `main` stays at the placeholder until the
real-repo bring-up (Task 4.7 of the plan) fast-forwards it to
`chore/bootstrap`'s tip. The placeholder is a real (zero-content)
commit, has a git counterpart, and is exportable / pushable from
day one. Concrete sequence:

```bash
# After `jj git init --colocate`, the working copy is an empty
# change at @. Describe it as the placeholder:
jj describe -m "chore: anchor main at empty placeholder commit"
jj bookmark create main -r @

# Move forward to the chore/bootstrap line of work:
jj new
jj bookmark create chore/bootstrap -r @
```

**Implementation note: working-tree snapshot at init.** `jj git
init --colocate` snapshots the existing working-tree contents
into the initial change `@` at init time. Any pre-existing files
(spec, plan, configs) that live in the working tree before
`jj git init` runs are captured into `@` and consequently into
the placeholder commit after `jj describe` annotates it — which
contradicts the "empty placeholder" intent above. A real
bootstrap necessarily begins with the spec and plan present in
`docs/superpowers/`, so this case is the rule, not the
exception. The plan's Task 1.5 includes an explicit
detect-and-squash step that moves snapshot content out of the
placeholder before the bookmarks are finalised:

```bash
jj squash --from main --into chore/bootstrap --keep-emptied
```

`--keep-emptied` preserves the placeholder commit even after its
file changes are moved out, so `main`'s anchor remains a real
(zero-content) commit exportable to git. After the squash, the
placeholder commit ends up empty by content; the chore/bootstrap
commit carries the bootstrap inputs. Empirically verified on
jj 0.41.0 / 2026-05-08.

Concerns and mitigation:

- The placeholder commit is visible in `git log`: a single empty
  commit with the message `chore: anchor main at empty
  placeholder commit` (S2: imperative form, complies with the
  spec's mathlib-derived commit-message convention). By design —
  the alternative (anchor at `root()`) is unworkable per the
  export refusal above.
- The placeholder commit appears as the *root* of `git log` for
  every contributor and visitor (M6). `docs/process.md` notes
  this so newcomers do not mistake the empty root for a
  mis-initialised repo.
- After `jj git push -b main` at real-repo bring-up (Task 4.7),
  the remote's `main` ref points at the chore/bootstrap tip
  (the placeholder is its first ancestor); this is what
  `git clone` produces and what GitHub serves as the default
  branch.
- Task 2.32's history rewrite of `chore/bootstrap` does NOT
  touch `main` (still at the placeholder). The bookmark-safety
  flags vary by command (verified against `jj <cmd> --help` on
  jj 0.41.0): `jj abandon` takes `--retain-bookmarks` (D16:
  v0.26+ default deletes them); `jj squash` takes `-k` /
  `--keep-emptied` to prevent the empty source from being
  abandoned; `jj rebase` and `jj describe` need no flag because
  bookmarks travel with change-ids by default (D3).

**`integration`** is the **regenerated fan-in merge view** of
`main` plus all currently-active topic branches. Force-pushed as
topic-branch tips move (lease-protected — see jj force-push
section below). Used locally for "view all in-flight work
together"; pushed to GitHub as a snapshot for visibility, but never
the target of PRs and never assumed stable. Anyone curious about
WIP work checks out `integration`; anyone doing routine work
checks out `main`.

**Topic branches** are the source of truth for in-flight work.
They merge into `main` via normal merge commits when complete;
meanwhile they're folded into the regenerated `integration`.

**Integration scope vs PR-candidacy (S4).** The
`regenerate-integration.sh` revset (below) folds *every* topic
branch into `integration` — `feat/*`, `fix/*`, `refactor/*`,
`migrate/*` AND `chore/*`, `docs/*`, `bump/*` — even though the
PR-candidacy column of the branch table marks the latter three
as repo-internal-only. The two policies diverge intentionally:
PR-candidacy answers *which branches eventually upstream to
mathlib*, whereas integration answers *what is the conflict
surface across all in-flight work right now*. A broken
`bump/v4.31.0` mid-flight should appear in `integration`
precisely so the team sees it interact with the `feat/*`
branches that will need to rebase onto the new toolchain;
hiding it would defeat the diagnostic purpose. `integration` is
documented as never-stable (force-pushed; never the target of
PRs); broken intermediate states there are expected, not a
quality regression.

The `update.yml` cron's `open-bump-pr` opens PRs **against
`main`** (which is append-only and stable, so the PR's base
doesn't shift). Once we merge the bump PR (normal merge into
`main`), `integration` is regenerated to incorporate the new
`main` state plus any other active topic branches.

This split is the production-ready / fork-ready answer to the
earlier-draft tension between "force-pushed main" and "GitHub PR
flow." The user's reframing: production-ready means fork-ready,
which means we can't defer fixing the force-push issue. Hence
`main` (stable) and `integration` (volatile) from day 1.

### Verified jj-native primitives

| Primitive | Idiom |
| --- | --- |
| Fan-in merge of N bookmarks | `jj new BOOKMARK1 BOOKMARK2 ...` then `jj bookmark set integration -r @` |
| Mass-rebase descendants | `jj rebase -d new-base -s 'roots(bookmarks(glob:"feat/*") \| ...)'` |
| Pre-push conflict refusal (local recommendation, D2/D9) | `jj config set --repo git.private-commits 'conflicts()'` (per-developer per-checkout; written to `~/.config/jj/repos/<hash>/config.toml` — NOT inside the repo, per the v0.38 migration documented in D8) |
| Pre-push conflict refusal (binding gate) | Server-side CI workflow rejects PRs containing `.jjconflict-base-*`/`.jjconflict-side-*` paths or unresolved conflict markers; see "Local-vs-server safety model" below |
| Bookmark prefix matching | `bookmarks(glob:"feat/*")` revset |
| Bookmark advance after commit (D10) | `jj bookmark advance <name>` (configured via `revsets.bookmark-advance-from`/`-to`); replaces the removed `experimental-advance-branches` (D11) |
| Force-push of `integration` | `jj git push --remote origin -b integration` (lease-semantics by default in jj 0.41; no `--force` flag needed) |

These are **built-in**. Our scripts (`regenerate-integration.sh`,
`rebase-topics.sh`) are thin wrappers (3–5 lines each).

**Force-push mechanism** (verified 2026-05-06 against
`https://docs.jj-vcs.dev/latest/bookmarks/`): jj 0.41 has **no
`--force` or `--allow-non-fast-forward` flag** because every
`jj git push` is lease-semantics by default (equivalent in spirit
to git's `--force-with-lease`). Sideways/backward moves of an
existing bookmark just work, provided the local view of the
remote matches the actual remote.

Paraphrasing the jj docs (run `jj git push --help` on jj 0.41 or
later for the canonical text): if the local bookmark has changed
from the last fetch, the push will update the remote bookmark to
the new position after passing safety checks similar to
`git push --force-with-lease`.

**Silent-skip on private/conflicted bookmarks (D23, jj v0.41
breaking change)**: as of jj v0.41 (2026-05-06),
`jj git push --all` / `--tracked` / `-r REVSETS` no longer fails
when revisions to push are private or have conflicts —
ineligible bookmarks are *skipped* and the command exits 0 with
a notice in stderr. The pre-push gate must therefore parse push
output for "skipped" notices and treat unexpected skips as a
failure. The single-bookmark form (`jj git push -b <name>`)
still fails on private/conflicted commits, so the canonical
sequence below remains a hard-fail when the explicitly-named
bookmark is conflicted; the silent-skip change applies only to
bulk forms.

**Canonical sequence** (used by `scripts/regenerate-integration.sh`):

```sh
jj git fetch --remote origin                                  # refresh lease state
jj new b1 b2 b3 ... bN -m "integration: fan-in @ $(date -I)"   # N-way merge
jj bookmark set integration -r @                              # move bookmark
jj git push --remote origin -b integration                    # lease-protected push
```

For first-time push (creating remote bookmark): since jj v0.38
(D9) a bare `jj git push -b <name>` automatically tracks the
bookmark on first push if it is not already tracking any remote;
no extra config is needed for the canonical single-bookmark
sequence. The deprecated `git.push-new-bookmarks = true` (D2) and
the also-deprecated `--allow-new` flag (D9) are replaced by
`remotes.<name>.auto-track-bookmarks = "glob:*"` per-remote, which
is useful when bulk-pushing many new bookmarks via `--all`. The
project recommends the auto-track-bookmarks config as part of the
"Recommended local jj configuration" section above; for the
typical `-b <name>` flow it is not required.

`main` is **never** force-pushed; the canonical sequence above is
specific to `integration`.

### Pre-push checklist

Conflict-commit refusal is the contributor-side ergonomic from
`git.private-commits` (recommended local config) plus the binding
server-side CI gate (see "Local-vs-server safety model" below).
The remaining checks split into:

**Machine-runnable (executed by `scripts/pre-push.sh`)**:

1. `lake build` succeeds locally.
2. `lake test` succeeds locally.
3. `lake lint` quiet (uses the `lintDriver` from `lakefile.toml`).
4. `scripts/lint-imports.sh` quiet on the to-be-pushed branches.
5. `markdownlint-cli2 '**/*.md'` quiet.
6. `bash scripts/check-axioms.sh Geb/ GebTests/` quiet (no
   non-allowlisted axioms flagged in our own closure).
7. **Push form is single-bookmark `-b <name>` only (S3)**.
   Pre-push.sh issues one `jj git push --remote <r> -b <name>`
   per bookmark to publish. The `-b <name>` form **hard-fails**
   on private or conflicted commits in jj 0.41 (the silent-skip
   semantics from D23 apply only to bulk forms `--all`,
   `--tracked`, `-r REVSETS`), so a separate silent-skip gate
   is unnecessary in this path. The bulk-push surface where the
   silent-skip gate matters is the real-repo bring-up's single
   `jj git push --all` (specified in the real-repo bring-up
   section), not routine pre-push.
8. (If branch is PR-candidate) Pre-push reminder about no-LLM-text
   rule for PR descriptions; affirmative confirmation required.

**Human-driven (user-initiated, prompted by the script)**:
9. **For Lean-content branches**: `lean4:golf` ran on changed proofs
   (polish step), then `lean4:review` ran on the diff.
10. **For PR-candidate branches**: `pr-review-toolkit:review-pr` ran.
11. **User reviewed the diff line-by-line** (always — the "no push
    without review" rule).

### Mathlib bump procedure

Two distinct flows, both ending at "mathlib is bumped, our repo is
healthy."

**Flow X — cron-driven (the common path)**:

1. Daily `update.yml` cron fires
   `leanprover-community/mathlib-update-action`. The action runs
   `lake update`, which fetches a new mathlib SHA into
   `lake-manifest.json` (since our `lakefile.toml` has no `rev`
   for mathlib, the manifest is the only file changed).
2. The action commits the manifest change and opens a PR against
   our default branch (`main`, which is append-only) via its
   internal PR-creation mechanism.
3. The PR appears in our review queue. Locally check it out as a
   `bump/<lean-version>` topic branch.
4. `lake build && lake test` locally to verify our code still
   compiles. Fix any breakage in commits on the topic branch.
5. Update `lean-toolchain` to match the new mathlib master if
   needed.
6. Merge the bump topic branch into `main` via a normal merge
   commit. The bump PR auto-closes.
7. Mass-rebase remaining active topic branches onto the new
   `main`: `scripts/rebase-topics.sh main`.
8. Regenerate `integration`:
   `scripts/regenerate-integration.sh`.

**Flow Y — user-initiated** (toolchain-watch reports drift between
cron runs, or we want an immediate update):

1. Create a `bump/<lean-version>` branch off `main` manually.
2. `lake update` locally — pulls latest mathlib master, updates
   `lake-manifest.json`. (No `lakefile.toml` change because we
   have no `rev` field for mathlib; the manifest carries the
   SHA.)
3. Update `lean-toolchain` to match.
4. `lake build && lake test`; fix breakage on the topic branch.
5. Merge into `main` (append-only).
6. Mass-rebase: `scripts/rebase-topics.sh main`.
7. Regenerate `integration`:
   `scripts/regenerate-integration.sh`.

Flow Y is essentially Flow X starting from step 4 (we did locally
what the cron would have done). In both flows, the merge into
`main` is a normal merge commit (no force-push of `main`). Only
`integration` is force-pushed.

## CI

Four GitHub Actions workflow files (M4): `ci.yml`,
`markdown-lint.yml`, `conflict-check.yml`, `update.yml`.

### `ci.yml`

- Triggers: `push: main`, `push: integration`, `pull_request: main`,
  `workflow_dispatch`. Note that `pull_request: main` is now an
  active trigger (the bump-PR cron targets `main`); it's not just
  future-proofing.
- Concurrency: cancel-in-progress only on PR branches and on
  `integration`; never on `main`.
- Jobs:
  - `style_lint`: forbid bare umbrella imports
    (`import Mathlib`, `import Cslib`) under `Geb/Mathlib/`,
    `Geb/Cslib/`, `GebTests/Mathlib/`, and `GebTests/Cslib/`.
  - `floodgate_imports`: run `scripts/lint-imports.sh` (which
    enforces both the per-subtree import-direction rules and
    the per-subtree no-prefix-leakage rules for `Geb.Mathlib.`
    and `Geb.Cslib.` outside imports).
  - `build`: `leanprover/lean-action@v1` with `build: true`,
    `test: true`, `lint: true`, `mk_all-check: false`. Covers
    `lake build` + `lake test` + `lake lint` + auto-detect
    mathlib for `lake exe cache get` + `.lake` caching.
    Followed in the same job by
    `lake shake --add-public --keep-implied --keep-prefix Geb
    GebTests` (minimised-imports check, enabled by Lean 4
    module-form authoring — see § Lean 4 module system) and
    `scripts/tests/test-lake-shake.sh` (flag-interface smoke
    test). **`mk_all-check` is deliberately disabled**: it
    auto-generates monolithic root index files, which conflicts
    with our narrow-and-deep, hand-curated indexing-file
    convention.
  - `hooks_test`: smoke-test `scripts/hooks/tests/*.sh`.
  - `axiom_check`: run `bash scripts/check-axioms.sh Geb/
    GebTests/`. Fails if any non-allowlisted axiom (anything other
    than `propext`, `Quot.sound`, `quot.sound`) appears in the
    closure of any declared symbol; in particular, `Classical.choice`
    in our own code is flagged for explicit user justification.

**`upstreaming-dashboard-action` — deferred**: we considered
adopting `leanprover-community/upstreaming-dashboard-action` but
found that it requires a Jekyll Pages setup to render the
dashboard from the markdown files it emits. At bootstrap time we
have no upstream content for the dashboard to inspect, and we
don't yet have a Pages setup. Defer adoption until we have
substantive `Geb/Mathlib/*` content, at which point we wire in
the action plus a Pages-published dashboard following FLT's
pattern. Recorded as an Open Question.

**Action pinning policy**: per the production-ready posture, all
third-party actions are SHA-pinned (not just major-version tagged).
Pin specific commits referenced from the action's release tags;
update via Dependabot-style review. This trades a small amount of
maintenance for tight supply-chain security. **Notation note
(S8)**: workflow YAML in this spec uses tag refs
(`leanprover/lean-action@v1`,
`DavidAnson/markdownlint-cli2-action@v19`,
`leanprover-community/mathlib-update-action`) as **shorthand**;
the concrete workflow files written by the bootstrap plan
replace each tag ref with its current commit SHA per the policy
above before the workflow lands on `main`.

### `markdown-lint.yml`

- `DavidAnson/markdownlint-cli2-action@v19` against
  `'**/*.md'` using `.markdownlint-cli2.jsonc`.

### `conflict-check.yml`

- Triggers: `push`, `pull_request`. Required status check on
  `main`.
- Job: scan the changeset (PR diff or pushed commits) for
  jj-conflict artefacts. Implementation specified in the bootstrap
  plan; the contract enumerates exactly what is checked.
- **Hard-fail conditions** (no allowlist):
  - Any path in the changeset matches `.jjconflict-base-*` or
    `.jjconflict-side-*` (these are jj's synthetic-conflict
    directories and never legitimate in committed content).
  - Note on the `(conflict)` annotation (S1, round 6 fix). The
    `(conflict)` token visible in `jj log` output is a *template
    rendering* artefact emitted by jj's templating layer, NOT a
    field of the persisted git commit object. Verified 2026-05-07
    against jj 0.41.0 on a materialised conflict: `git log -1
    --format='%s'` and `git log -1 --format='%B'` show only the
    user-supplied description; `git cat-file -p HEAD` shows the
    standard tree/parent/author/committer/change-id headers and
    the user description, with no `(conflict)` annotation. A CI
    gate that greps git commit messages for `(conflict)` therefore
    never triggers on jj-originated conflicts. The path-based
    hard-fail above is the binding detection mechanism for
    jj-originated conflicts.
- **Marker-substring conditions** (allowlist applies; see
  below). The job greps each changed text file for any of the
  following exact byte sequences appearing at column 0 of any
  line:
  - git's three-way merge markers (the **primary** target of
    this gate, since they CAN appear in committed content if a
    contributor used `git merge` directly outside jj):
    `<<<<<<<`, `=======`, and `>>>>>>>` (each seven characters;
    the first / third optionally followed by a label).
  - jj's working-copy conflict markers (included for
    completeness, though they normally do NOT appear in committed
    content — see the note immediately below): `<<<<<<< conflict`
    (jj prefixes the start marker with the literal word
    `conflict`), `%%%%%%% diff from:`, `\\\\\\\` (seven
    backslashes — jj's "to" marker), `+++++++` followed by a
    space and a change-id, and `>>>>>>> conflict` (verified
    verbatim against jj 0.41.0 by materialising a two-sided
    conflict in a scratch working copy on 2026-05-08).
- **Note on jj-distinctive marker emission (S1, round 4 fix).**
  jj's conflict markers (`%%%%%%% diff from:`, `\\\\\\\`,
  `+++++++ <change-id>`) appear in **working-copy materialisation
  only**, NOT in the committed git tree. When jj exports a
  conflicted commit to git, the in-tree files do not carry these
  markers; instead `.jjconflict-base-*/` and `.jjconflict-side-*/`
  directories appear in the tree, plus a `JJ-CONFLICT-README`
  blob describing the conflict. Therefore the path-based
  hard-fail above (`.jjconflict-base-*` / `.jjconflict-side-*`
  paths) is the **primary** gate for jj-originated conflicts. The
  substring
  grep catches plain-git three-way merge markers — i.e., the case
  where someone ran `git merge` outside jj and committed an
  unresolved result. Both gates run unconditionally; redundancy
  is intentional.
- **Allowlist mechanism**: a file in `docs/` (only) is exempt
  from marker-substring matching if and only if it contains the
  literal sentinel comment line
  `<!-- conflict-check: allow markers in this file -->`
  within its first 30 lines. The sentinel exempts that one
  file from substring matching only; the path-based hard-fail
  conditions above (`.jjconflict-*` paths) have no allowlist.
  Files outside `docs/` cannot use the sentinel — there is no
  legitimate reason for a Lean source, CI workflow, or other
  repo file to contain conflict-marker substrings.
- This workflow is the **binding** safety gate per "Local-vs-
  server safety model"; the local jj `git.private-commits` config
  is a contributor-side ergonomic.

The spec itself does not need the sentinel: it describes the
markers in prose (using fenced code blocks with backticks for
short marker fragments) but does not place any of the canonical
seven-character strings at column 0 of a text-file line. The
documentation that describes the gate (`docs/process.md`) DOES
need the sentinel because it shows the markers as quoted
examples.

### `update.yml`

- Cron: `'0 17 * * *'` daily. (No fixed-rationale time; we pick
  17:00 UTC arbitrarily, similar to FLT. The action's README
  shows `'0 8 */7 * *'` as a default example; either is fine.)
- **Workflow uses
  `leanprover-community/mathlib-update-action`** (the official-
  template default; matches `equational_theories` and the
  LeanProject template). The action watches `lake-manifest.json`
  (default) or `lean-toolchain` for changes; runs `lake update`
  (or `lake -R -Kenv=dev update` in legacy mode); commits the
  resulting changes and opens a PR (PR-creation mechanism is
  internal to the action; we don't need to depend on its specific
  implementation). The PR's base branch defaults to the repo's
  default branch (configured to `main` in our GitHub settings),
  so the PR targets `main` (which is append-only).
  Inputs include `intermediate_releases` (values per the action's
  `action.yml` documentation: `all`, `latest`, `master` — choose
  during scaffolding based on whether we want every release,
  latest only, or master-tracking. Verified at SHA `d2b88048`,
  2025-11-11, via `gh api .../mathlib-update-action/contents/`
  `action.yml`. F8: an earlier draft of this spec listed
  `stable` as a fourth option in error; `stable` is not a
  documented input value).
- **Why not `downstream-reports`** (FLT's choice): the
  `downstream-reports` actions (`bump-to-latest`, `open-bump-pr`,
  `track-incompatibility`, `query-latest`) are LKG/FKB-aware —
  they only propose bumps to mathlib commits *known* to build
  against the project, and skip when the project is broken. More
  intelligent, but require explicit registration in the
  `leanprover-community/downstream-reports` registry (PR adding
  an entry to `ci/inventory/downstreams.json`), and registration
  triggers daily Zulip notifications on `NEW_FAILURE`/`RECOVERED`
  events. **Registration is deliberately deferred** beyond
  bootstrap and beyond the first content commit — the registered
  projects today (FLT, sphere-eversion, infinity-cosmos, several
  Tao-led projects, etc.) are major efforts with substantive
  content. Adding a small / early-stage project to the registry
  would generate noise (Zulip pings) without contributing
  diagnostic value the community is likely to care about. The
  decision to register will be a manual, periodic check by the
  user — "do we have *enough* substantive content that
  registration would be informative for the community?" We start
  with `mathlib-update-action` (no registration required); switch
  to `downstream-reports` only when the user explicitly decides
  registration is warranted. The bootstrap leaves the
  infrastructure ready (`update.yml` is a one-line swap from one
  action to the other) but does NOT register.
- **All workflow actions are SHA-pinned**.

No CI matrix (single Lean version per mathlib pin).

## Mathlib alignment

### LLM contribution policy (verified text)

Per `https://leanprover-community.github.io/contribute/index.html`,
"Use of AI" section (verbatim quotes fetched 2026-05-05; the page
has no "last revised" metadata — the only in-text date reference
is "(As of April 2026)" embedded in the body):

- **"We do not accept pull requests opened by new contributors where
  code is LLM-generated."** Unconditional. Disclosure does NOT unlock
  it.
- **"It is essential that you can vouch for all the code submitted in
  a PR, and understand all the content written by an AI."** At every
  seniority.
- **"If you use artificial intelligence (such as, by using github's
  copilot mode, asking an LLM like ChatGPT or using an agent like
  Codex, Claude, Gemini, or even Lean-dedicated agents like Aristotle),
  please explain this in the PR description. Explain which tool(s)
  you used and how you used it."**
- **"Note that using an LLM when writing comments on github or Zulip
  is not allowed: use your own words."** At every seniority.
- **"More generally the reviewer team may close a PR containing
  low-quality code if it appears to be AI-generated."** Reviewer
  discretion is real.

### The floodgate test

At all times, the repo must be ready to ship dependency-ordered PRs
on short notice with no source-code changes. If mathlib were suddenly
to switch from accepting nothing to accepting anything mathlib-ready,
we should be bounded only by review cadence, not cleanup work. This
is a continuous discipline, not a "we'll clean it up before
submitting" plan.

### Path 1 — directory split for upstream-eligibility

`Geb/Mathlib/*` is upstream-eligible (modules `Geb.Mathlib.*`);
`Geb/Internal/*` is downstream-only. The path is the eligibility flag.
Linter (`scripts/lint-imports.sh`) enforces: files in `Geb/Mathlib/`
import only from `Mathlib.*` or `Geb.Mathlib.*`.

Extraction (`scripts/extract-pr.sh`):

1. Copy `Geb/Mathlib/X/Y.lean` to `<mathlib4-fork>/Mathlib/X/Y.lean`.
2. `sed -i -E 's/\bGeb\.Mathlib\./Mathlib./g'` on each. The `\b`
   word boundary prevents matching `Geb.MathlibFoo` (an identifier
   that happens to start with that prefix). Global within-line
   replacement (not restricted to import lines) so any in-file
   reference to our upstream-eligible namespace is rewritten.
3. Same for `GebTests/Mathlib/X/Y.lean` → mathlib's test directory.
4. Produce a clean PR branch.

**Discipline rule for files in `Geb/Mathlib/*`**: the `Geb.Mathlib.`
prefix appears **only** in `import` lines that reference other
upstream-eligible files in this repo. Do NOT use the prefix in:

- namespace declarations (write `namespace Computability.Primrec`,
  not `namespace Geb.Mathlib.Computability.Primrec`)
- declaration bodies / fully-qualified-name references (use `open` or
  the bare name)
- docstrings or comments

**Enforcement**: the floodgate-CI lint (`scripts/lint-imports.sh`)
checks both:

1. Files under `Geb/Mathlib/*` import only from `Mathlib.*` or
   `Geb.Mathlib.*` (the import-direction rule).
2. Files under `Geb/Mathlib/*` do NOT contain `Geb.Mathlib.` outside
   of `^import` lines (the no-prefix-leakage rule).

The combination of (1) and (2) ensures the extraction `sed` has
nothing to corrupt: every `Geb.Mathlib.` is exactly an import that
should become a `Mathlib.` import.

User reviews the script's *output* (the resulting PR diff), not the
input transformation. Path 1 is the "mechanical rewrite at extract
time" pattern; Paths 2 and 3 (which would have given zero source-byte
change) were prototype-tested and ruled out (Path 2 fails because Lake
treats library namespaces as exclusive; Path 3 fails because Lean
v4.30-rc2's stable surface has no `module` keyword that lets a file
declare a module name distinct from its path).

### Mathematical content fixed; expression open

When porting concepts from prior trees, the **mathematical content of
each declaration is fixed** (the underlying object, the set of provable
theorems, functorial relationships, computability properties). The
**surface expression is open** (Lean syntactic style, encoding,
naming, tactic style, file structure, even the Lean type used). The
invariant is testable: the same theorems must remain provable in the
new representation.

### Two-track development for foundations

When we want a foundation we can build on right away but don't yet
have an upstream-quality version:

1. **Track 1 (Internal, mode c)**: Claude drafts the code into
   `Geb/Internal/Foo.lean`; user reviews line-by-line and accepts.
2. **Track 2 (Mathlib, mode a or b)**: in parallel/sequentially, we
   rewrite into `Geb/Mathlib/Foo.lean` (mode a if credentialing-PR
   candidate; mode b otherwise).
3. **Migration**: when Mathlib version covers what Internal version
   covered, migrate dependents via `jj rebase`. Internal version is
   then removed.

### Authoring modes (directory-driven dispatch)

| Where | Mode | What Claude does | What the user does |
| --- | --- | --- | --- |
| `Geb/Internal/*` | (c) Hands-off draft + commit-time review | Drafts freely | Reviews and accepts/rejects line-by-line |
| `Geb/Mathlib/*` (credentialing-PR candidate) | (a) User-driven | Suggests in natural language only | Writes every line |
| `Geb/Mathlib/*` (other) | (b) Co-authoring | Drafts; user modifies until owned | Reads, modifies, commits when fully understood |

### Credentialing-PR checkpoint

Before starting any work in `Geb/Mathlib/*` whose only dependencies
are mathlib (i.e., a true PR-candidate with no in-flight geb-mathlib
deps), Claude asks: "Is this the credentialing PR?" The user weighs:
(1) confidence to write solo, (2) strength on its own merits,
(3) opportunity cost vs. other candidates. Until the credentialing PR
is identified, every such candidate is a potential choice — preserve
the rotatability.

### Mathlib's commit-message convention (verbatim)

```text
<type>(<optional-scope>): <subject>

<body>

<footers>
```

Types (verbatim from the page; see citation below):
`feat | fix | doc | style | refactor | test | chore | perf | ci`.

**Subject-line rules** (verbatim quotes re-fetched 2026-05-07
from `https://leanprover-community.github.io/contribute/commit.html`,
M1):

- Tense and voice: *"use imperative, present tense: 'change' not
  'changed' nor 'changes'"*.
- Capitalisation: *"do not capitalize the first letter"*.
- Punctuation: *"no dot(.) at the end"*.

**Documented footers** (verbatim from the same page):

- *"All breaking changes have to be mentioned in footer with the
  description of the change, justification and migration notes"*.
- *"Closed bugs should be listed on a separate line in the footer
  prefixed with 'Closes' keyword like this: Closes #123, #456"*.
- *"if this PR depends on others, they should be listed in
  checkbox format, i.e., `- [ ] depends on: #XXXX`"*.

`Moves:` and `Deletions:` are NOT documented on the official
contribute page. They appear informally in some mathlib commit
messages but are not required. We omit them from our committed
convention; if a commit moves or deletes declarations, the body
prose can describe that without a structured footer.

A sample of recent mathlib master commits (verified 2026-05-04 via
`gh api repos/leanprover-community/mathlib4/commits` against the
master HEAD) all use the type-prefix form. Spot-check during the
adversarial-review iteration.

### Mathlib's comment / docstring rules (verified)

- `/-! ... -/` module docstring: **mandatory** after imports. Required
  sections: title, summary, main definitions, main statements,
  notation (if any), implementation notes, references, tags.
- `/-- ... -/` declaration docstring: **mandatory** for every `def`,
  `structure`, `class`, `instance`, major theorem; **mandatory** for
  every `structure`/`class` field.
- Markdown + LaTeX (`$...$`, `$$...$$`) in docstrings.
- **No development-history references** in docstrings.
- **No post-hoc axiom-free celebration** in docstrings.
- **Empty lines in declarations are lint-discouraged**; prefer a brief
  comment as a structural separator.

## CSLib alignment

CSLib (Computer Science Library for Lean 4,
`https://github.com/leanprover/cslib`) is a peer dependency to
mathlib in our `lakefile.toml`. CSLib aims to be "for computer
science what Lean's Mathlib is for mathematics." Its existing
content directly overlaps our likely first work — URM
(unlimited register machines), primitive recursion, λ-calculus,
combinatory logic, Turing machines, LTS, linear logic.

### Search-before-prove extends to CSLib

Whenever we're about to formalise a computer-science concept,
**search CSLib first** in addition to mathlib. The lean-lsp MCP's
`leansearch` and `loogle` cover both libraries; specifically check
the `Cslib.*` namespace (e.g., `Cslib.Computability.URM`) before
re-deriving content. The same applies during porting from prior
trees: if CSLib already has the concept formalised, prefer
importing from `Cslib.*` over re-implementing (with appropriate
mathematical-content-fixed considerations).

### CSLib's style and conventions

Per CSLib's `CONTRIBUTING.md` (verified 2026-05-06): "We generally
follow the [mathlib style for coding and documentation]." So our
mathlib-shaped style automatically satisfies CSLib's expectations
in most respects. CSLib-specific deviations:

- Domain-specific variable names allowed (e.g., `State`, `μ` in
  computability contexts).
- Locally-scoped notation preferred unless typeclass-generalisable.
- Same Conventional-Commits-shaped PR-title prefixes as mathlib.
- **Minimised-imports enforcement** via
  `lake shake --add-public --keep-implied --keep-prefix`. Our
  repo-wide pre-push and CI check (see § Lean 4 module system)
  satisfies this for both upstream targets; no CSLib-specific
  step is needed.

If a future CSLib convention conflicts with mathlib's, the rule
of precedence is **mathlib wins** (mathlib is the more established
standard); we don't expect conflicts because CSLib explicitly
builds on mathlib's foundations.

### CSLib's AI/LLM policy

Materially **more permissive than mathlib's**. Quoted verbatim
from CSLib's `CONTRIBUTING.md` § "The role of AI": "There are two
primary areas where generative AI can help: generating/refining
specifications (at the front-end or Boole level); helping to
prove Lean conjectures. Other creative uses of AI are welcome,
but contributions should remain reviewable and maintainable."

Recent CSLib PRs are openly tagged "Prepared with Claude Code"
and accepted. **Implication**: the new-contributor restriction
that mathlib applies (no LLM-generated code from new contributors)
does NOT apply to CSLib-bound contributions. The credentialing-PR
checkpoint is mathlib-specific; CSLib-bound work proceeds with
ordinary AI-disclosure practice.

The rule "no LLM-drafted user-facing text on mathlib channels"
applies symmetrically to CSLib channels — we still author Zulip
messages and PR descriptions ourselves; the difference is that
LLM-assisted Lean *code* is acceptable to CSLib (with disclosure)
where mathlib forbids it from new contributors.

### CSLib-bound directory structure

`Geb/Cslib/*` is a peer upstream-eligible subtree alongside
`Geb/Mathlib/*`. The floodgate property holds independently for
each upstream: at any moment, every file in either subtree can
be extracted to a PR upstream.

Per-subtree import rules (enforced by `scripts/lint-imports.sh`
and its smoke test `scripts/tests/test-lint-imports.sh`):

| Subtree | Allowed imports | Self-prefix |
| --- | --- | --- |
| `Geb/Mathlib/` (and tests) | `Mathlib.*`, `Geb.Mathlib.*` | `Geb.Mathlib.` |
| `Geb/Cslib/` (and tests) | `Mathlib.*`, `Cslib.*`, `Geb.Cslib.*` | `Geb.Cslib.` |

The cross-subtree boundary follows the upstream dependency
relationship: mathlib does not depend on CSLib (so `Geb/Mathlib/`
files cannot import from `Cslib.*` or `Geb.Cslib.*`), and CSLib
depends on mathlib only through the upstream `Mathlib.*` modules
(so `Geb/Cslib/` files cannot import from `Geb.Mathlib.*` —
unupstreamed mathlib-targeted content is not yet available to a
CSLib PR). `Geb/Internal/*` may import from any of the above.

`scripts/extract-pr.sh` dispatches on source path: it accepts
`Geb/Mathlib/*` / `GebTests/Mathlib/*` for mathlib4 extraction
(rewriting `Geb.Mathlib.` to `Mathlib.`) and
`Geb/Cslib/*` / `GebTests/Cslib/*` for CSLib extraction
(rewriting `Geb.Cslib.` to `Cslib.`).

### CSLib registration with downstream-reports

CSLib is itself registered with `downstream-reports` (it appears
in the registry alongside FLT and other major projects).
**Registration of `geb-mathlib` is deliberately deferred** —
beyond the bootstrap, beyond first content, and decided manually
by the user as a periodic checkpoint. The trigger is "do we have
enough substantive content that registration would be informative
to the community, given that registration generates Zulip
`NEW_FAILURE`/`RECOVERED` notifications?" Bootstrap leaves the
infrastructure ready (`update.yml` can be swapped from
`mathlib-update-action` to `downstream-reports` actions in one
line) but the registration PR itself is a separate, intentional,
user-driven act.

## Process discipline

### Always-on skills per phase

| Phase | Trigger | Always-on skill | Helper |
| --- | --- | --- | --- |
| Brainstorming | New design space | `superpowers:brainstorming` | `sequential-thinking`; **Lean-specific skills as helpers** when testing code snippets, exploring mathlib, or formalising paper-bound results would inform design choices (e.g., `lean4:learn` to explore mathlib API options, `lean-lsp` `leansearch`/`loogle` to verify a relevant lemma exists, `lean4:autoformalize` early-look for paper-bound material) |
| Writing-plan | Approved spec exists | `superpowers:writing-plans` | `sequential-thinking`; **Lean-specific skills as helpers** when planning involves verifying mathematical claims with `lean_run_code` snippets, referencing specific mathlib lemmas already verified to exist, or anticipating proof-strategy choices via `lean4:draft`/`lean4:formalize` previews |
| Executing-plan | Approved plan exists | `superpowers:executing-plans` (or `subagent-driven-development`) | phase-relevant Lean skills (full sub-skill table below) |
| Lean code work | Any `.lean` file | `lean4` umbrella (sub-skills below) | `lean-lsp`, `serena` MCPs |
| Mathlib search | Lemma name unknown | `lean-lsp` (`leansearch`, `loogle`, `local_search`, `hammer_premise`) | — |
| Pre-commit | Before any commit | `superpowers:verification-before-completion` | — |

### `lean4` sub-skills by Lean-work phase

| Phase | Sub-skill | Always-on? |
| --- | --- | --- |
| Introduction (formalising informal math) | `draft`, `formalize`, `autoformalize` | Try `autoformalize` early on paper-bound results |
| Completion (proving stated lemma) | `prove`, `autoprove` | Try `autoprove` when manual stalls |
| Improvement (mathlib-quality polish) | `golf` | **Always-on** as post-process |
| Porting from `geb-lean/` | `refactor` | **Always-on** during porting |
| Self-review pre-commit | `review` | **Always-on** for any Lean commit |
| Exploring mathlib | `learn` | As needed |
| Diagnosis (build/setup issues) | `doctor` | As needed |
| Save progress | `checkpoint` | At natural milestones |

### Adversarial review of specs and plans

After a brainstormed spec or written plan is committed, before
implementation begins:

1. Author commits the spec/plan.
2. Dispatch a **fresh-context** Agent (general-purpose, NEW invocation —
   not SendMessage) with adversarial review instructions: find every
   error, omission, vagueness, infelicity, internal contradiction,
   scope-creep, missing edge case, unstated assumption. Categorise as
   **blocker / serious / minor / cosmetic-taste**. Be willing to say
   "the goal is unachievable" if true.
3. Author responds to **every** finding in writing: fixed / deferred
   with rationale / rejected as cosmetic-taste.
4. Re-dispatch to a fresh Agent. Loop.
5. Termination: all findings cosmetic-taste, OR reviewer concludes
   goal unachievable (escalate to user).

For VCS / repo-layout / pervasive choices, the adversary must
specifically (a) check primary sources for every cited pattern,
(b) search for more standard alternatives the author may have missed,
(c) flag any "we'll write a script for this" decision that could be a
single command in an existing tool.

**Fork hygiene for scratch verifications.** Adversarial-review forks
routinely spin up scratch jj/git repos (typically under
`/tmp/scratch-*`) to verify behaviour claims against the running
tool. Such forks must NOT pollute the user's user-level config files.
Specifically:

- Do not run any `--user`-scoped jj config command — `jj config set
  --user`, `jj config edit --user`, `jj config unset --user` all write
  to `~/.config/jj/config.toml` (and `jj config edit --user` creates
  the file if absent), overwriting the user's real identity.
- Do not run `git config --global <key> <value>` (writes to
  `~/.gitconfig`) or `git config --system <key> <value>` (writes to
  `/etc/gitconfig`; usually requires sudo, but mention for completeness).
- Repo-local writes are fine: `git config user.name "..."` (no
  `--global`) writes to `<repo>/.git/config` and does not pollute
  user-level state.
- Acceptable alternatives for scratch identity / config:
  - Set `JJ_CONFIG=/tmp/scratch-config-$$/config.toml` env var
    before any scratch invocation; jj reads this isolated config.
  - Pass `--config-file <PATH>` or `--config <NAME=VALUE>` global
    options on the jj command line for per-invocation isolation.
  - Use `jj config set --repo <key> <value>` — this writes to
    `~/.config/jj/repos/<hash>/config.toml`, scoped to that one
    scratch repo, harmless to delete.
  - Skip identity setup entirely; jj warns on commit-creation but
    most read commands and even commit-creation work (commit
    attribution will be empty, which is fine for a throwaway
    scratch repo).
- After fork completion, the user-level config files
  (`~/.config/jj/config.toml`, `~/.gitconfig`) must be unchanged.
  Forks should explicitly verify this before reporting completion:
  `jj config get user.name && jj config get user.email` against
  the user's real identity values, OR an mtime/hash check on the
  config file.

The fork directive (the prompt the orchestrator passes to the Agent
tool) should include an explicit "CRITICAL fork hygiene" clause
stating these rules. Forks that violate this are an immediate test
failure: the user has to manually restore their config, and any
spec/plan claim "verified against jj 0.41.0" by such a fork is no
longer trustworthy without re-verification by an uncontaminated
fork.

### Verify agent claims against authoritative sources

Any factual claim by a Claude agent (main or subagent) about an
external system (mathlib, Lean, third-party tools, jj, GitHub
conventions, library APIs) is **provisional** until verified against
authoritative sources. Verification means: fetch the source (official
docs, repo file at a specific commit, official spec) and quote the
relevant text. Claims that land in committed artifacts include the
citation. Adversarial reviewers explicitly check for unverified claims
and flag them as findings. Do not trust your own memory for facts
about external systems — re-verify when re-using.

This rule paid off during bootstrap: an agent claimed mathlib style
required `module Mathlib.X` headers (false; Lean 4 has no such
keyword). Another summary of mathlib's LLM policy was less precise
than the actual text. Both were caught by primary-source verification.

### Process self-update mechanism

The process itself revises through three triggers and two executors:

**Triggers**:

- **(t1) End-of-session review**: at the end of any non-trivial
  session, ask "did we learn anything that should be encoded?"
  Answered via `claude-md-management`'s `/revise-claude-md` command.
- **(t2) Friction-driven**: whenever Claude notices re-deriving
  something it should already know, or repeating a same explanation
  across sessions, raise it; the user decides whether to encode.
- **(t3) User-initiated**: the user notices and says "we should add a
  rule."

Calendar-driven and pre-commit triggers are deliberately skipped
(ritual risk).

**Executors**:

- **(e1) Claude proposes a diff to CLAUDE.md / `.claude/rules/*` /
  `docs/process.md`; user reviews; user commits.** Default for all
  in-session updates.
- **(e2) User writes the update directly.** Available for small
  changes the user prefers to author themselves.
- **(e3) `claude-md-management:revise-claude-md` plugin** for the
  end-of-session form (uses (t1) trigger).

### Four-layer work tracking

| Layer | Role | Lifetime | Where |
| --- | --- | --- | --- |
| 1. Claude tasks (`TaskCreate`/`Update`/`List`) | Per-session bullet progress | Session-only | Internal to harness |
| 2. `TODO.md` at repo root | Hierarchical, topological, in-progress only | Lifetime of project | Repo root |
| 3. Project docs (`docs/index.md` + `Geb.lean` literate index) | Implemented work, topological | Lifetime of project | Repo |
| 4. Per-workstream specs/plans | Workstream history | Retained after completion | `docs/superpowers/specs/` and `plans/` |

Workstream lifecycle: new → entry in TODO + spec + plan; progresses
via Claude tasks + adversarial reviews; completes → entry **removed**
from TODO, content merged into project docs, references updated.

### Constructive-only Lean code

The project is **purely constructive**. Hard rules:

1. **No `noncomputable`** anywhere in our code. Every definition
   computes.
2. **Minimise `Classical`**. Avoid where avoidable. Where mathlib's
   own machinery (e.g., parts of category theory, possibly
   `Category` itself) inevitably pulls `Classical` via transitive
   dependencies, we accept the inevitability — but verify it's
   genuinely inevitable for each invocation, not a convenience.
3. **Axiom checks (in place from bootstrap, not deferred)**:
   `scripts/check-axioms.sh` is a **vendored copy** of the
   `lean4-skills` plugin's `check_axioms_inline.sh` (located at
   `~/.claude/plugins/cache/lean4-skills/<version>/lib/scripts/`),
   with our allowlist customised. The vendored script is
   committed to our repo so it travels with us regardless of
   plugin-version drift. **Provenance note (S4)**: the script
   lives in `scripts/`, not under `Geb/Mathlib/`, so it is
   project tooling and not eligible for upstream extraction;
   its origin and customisation rationale are recorded in
   `docs/process.md`.

   How it works: appends `#print axioms <decl>` lines to each
   `.lean` file (under a marker comment), runs `lake env lean
   FILE`, parses output for axiom dependencies, restores the
   file. Output flags any axiom not in the allowlist as red.

   **Allowlist customisation**: the upstream script's default
   allowlist is `propext|quot.sound|Classical.choice|Quot.sound`.
   Our copy excludes `Classical.choice` from the allowlist (since
   we want it flagged for explicit justification per our
   constructive discipline). Our `STANDARD_AXIOMS` line is
   `propext|Quot.sound|quot.sound`.

   **Workflow when `Classical.choice` flags**: the user inspects
   the flagged declaration. If `Classical.choice` is transitive
   via mathlib (no avoidable use in our own code), the user
   adds the declaration to a per-file allowlist comment (e.g.,
   `-- AXIOM_ALLOW: Classical.choice (transitive via Mathlib.X)`).
   If the dependency is genuinely from our own code, refuse the
   commit and rewrite to avoid `Classical`. (The script does NOT
   yet parse such per-file allowlists — flag-and-review is the
   manual disambiguation step. A smarter implementation is a
   future upgrade.)

   **Limitations of the vendored script** (documented at the
   top of the file): only top-level (column-0) declarations
   are detected; only the first namespace per file is honoured;
   private/protected/local declarations are missed. For our
   narrow-and-deep file structure these limitations are
   acceptable. A future upgrade replaces the shell script with
   a `lake exe checkAxioms` Lean executable using
   `Lean.collectAxioms` for full coverage; tracked as an Open
   Question, executed when the limitations bite or when we have
   substantial enough content for the upgrade to be worthwhile.

   **CI invocation**: `bash scripts/check-axioms.sh Geb/ GebTests/`
   in `ci.yml`. Pre-push checklist runs the same command on
   touched files. The CI step fails if any non-allowlisted axiom
   is flagged.

Why: the user's framing of Geb is computable-function theory; a
`noncomputable` declaration breaks the language's intended
semantics. A gratuitous `Classical` invocation weakens the formal
guarantee that we're staying in the constructive fragment.

When porting from prior trees, audit `Classical` usage and
flag/justify each instance explicitly. Where mathlib offers a
constructive alternative (e.g., a `Decidable` predicate over a
`Classical` instance), prefer it.

### Continuous verifiability discipline

Every new module is immediately verifiable:

- **Index-on-skeleton**: a new `.lean` file is added to its enclosing
  subindex (and transitively the root) the moment it's created, even
  with just a copyright header.
- **Examples accompany new concepts**: every new definition /
  structure / type / significant lemma includes at least one
  small concrete `example`. **Default placement: in
  `GebTests/<path>.lean`**, mirroring the source path. This
  matches mathlib's verified practice (~87% of mathlib's
  `example`s live in `MathlibTest/`, the mirrored test
  directory; CSLib follows the same pattern). **Inline examples
  are reserved for the narrow case mathlib uses them**:
  tactic/metaprogramming/reflection sanity checks and
  definitional-equality witnesses tied to a specific construction
  in the source file (e.g., `example : (foo).bar = baz := rfl`
  proving a new construction matches an old one). For ordinary
  pedagogical "here is what an X looks like" examples, the
  `GebTests/` mirror is the right home.
- **`GebTests/` mirrors `Geb/`**: one-to-one path correspondence.
- **CI runs `lake build` then `lake test`**: a green CI = "compiles,
  tests pass, linters quiet, markdown clean."

### Concept docs in same branch

Any new concept introduced into source code is documented in
`docs/index.md` **in the same feature branch** as the source. Pre-push
checklist includes a docs-coverage check.

### Generic user references

When writing about interactions with the user — anywhere: memory,
repo files, comments, commit messages, docs, PR descriptions — use
"the user" / "they / them" generically. No first names, email
addresses, or autobiographical details. The repo is intended to make
sense for any developer who adopts it as principal developer; project-
instance-specific facts (e.g., the current GitHub owner) live in
project memories, not in repo content.

### No LLM-drafted user-facing text on mathlib channels

PR descriptions, Zulip messages, GitHub issue/PR comments must be in
the user's own words, not Claude-drafted. Claude may produce a
*draft* clearly marked "for you to paraphrase," but the final posted
text is written by the user.

**Enforcement** (multi-layered, given that text-content can't be
mechanically verified):

1. The rule lives in `CLAUDE.md` as a hard rule (always-on).
2. `scripts/pre-push.sh` includes an explicit reminder step that
   surfaces the rule and asks for affirmative confirmation before
   any push that touches `.github/PULL_REQUEST_TEMPLATE/` or
   that's identified as PR-candidate.
3. When (and if) we add a public `.github/PULL_REQUEST_TEMPLATE/`
   for our repo, it includes a checkbox: "I authored this PR
   description in my own words, not via LLM drafting."
4. The user-review-before-push gate is the final defence: any
   user-facing text the user reviews is by definition reviewed.

**Bootstrap-window enforcement gap** (M5): the PR template at
layer 3 is a deferred TODO; until it lands, layer 3 does not
enforce anything. During the bootstrap window the only PR
expected against `rokopt/geb-mathlib` is the chore/bootstrap
merge PR (or whatever bring-up PRs the runbook produces),
authored by the maintainer per the standing rule and reviewed
under layers 1, 2, and 4. The gap is acknowledged here so that
post-bootstrap work prioritises the PR template before opening
the repo to external contributors.

### Markdownlint discipline

**Every Markdown document we author must be markdownlint-clean.**
This includes:

- All committed `.md` files (specs, plans, runbooks, READMEs,
  `CLAUDE.md`, `.claude/rules/*.md`, `docs/*`, etc.).
- **Local-only `.md` files we author**, including those in
  `.remember/` (which are gitignored but still authored from our
  sessions and considered ours). The markdownlint config does
  NOT exclude `.remember/`; warnings there are visible and must
  be cleared.

The cleanliness gate uses both `markdownlint-cli2` (CLI, in CI)
and the VSCode markdownlint extension (live editor warnings) with
a shared `.markdownlint-cli2.jsonc` configuration. Without a
shared config, the two would surface different warnings.

What the config DOES exclude (only content we don't author /
can't control): `.lake/`, `.jj/`, `node_modules/`.

The specific rule set in `.markdownlint-cli2.jsonc` is **deferred
to the bootstrap plan** (this is implementation, not design). A
sensible default — ideally based on mathlib4's config if it has
one, or the markdownlint-cli2 default with our explicit
allowances/denials otherwise — suffices to start. We tighten or
loosen rules in response to encountered false-positive friction.

**Note on auto-generated content in `.remember/`**: the `remember`
plugin emits files with formatting that occasionally trips the
default markdownlint rules (long single-line summaries, bare
fenced code blocks, missing top-level H1). When this happens, we
edit the offending files locally to be clean (knowing the plugin
may regenerate them). **Fixing those warnings is part of
this project's work, not someone else's** — the memories the
plugin scaffolds are ours; the plugin merely automates the
scaffolding. CLAUDE.md carries a one-line reminder to apply
markdownlint cleanups to remember-plugin output as part of
end-of-session housekeeping (D4).

**Filing an upstream issue with the `remember` plugin**, or
relaxing markdownlint rules specifically for `.remember/`, is
**always a manual, user-approved decision** — never something
Claude initiates autonomously. The same general-policy rule
applies to any external-facing communication (per
`feedback_no_llm_user_facing_text`), but it's worth calling out
explicitly here since the local-fix-and-regenerate cycle could
otherwise read as a standing invitation to escalate.

### Doc-generation strategy and CI

Source docstrings: Markdown rendered by doc-gen4 (mathlib's renderer).
Project prose: Markdown for now. Verso adoption deferred until ANY of:
doc-gen4 supports Verso rendering, Verso marks cross-references stable,
mathlib migrates to Verso, or our prose grows substantial.

Doc-CI: doc-gen4 invocation (TBD during scaffolding — the exact
incantation depends on doc-gen4's current version; common forms are
`lake -R -Kenv=dev build Geb:docs` or via `leanprover-community/`
`docgen-action`) succeeds without warnings. A periodic reminder
mechanism (TBD during scaffolding — likely SessionStart hook or
weekly cron) prompts the user to spot-check rendered output.

## CLAUDE.md and rules architecture

### Layered system

- **`CLAUDE.md`** (target under 200 lines, always-on): hard rules + project
  structure + phase mapping + links into deeper layers.
- **`.claude/rules/*.md`** (path-scoped via `paths:` YAML
  frontmatter): conditionally loaded when files matching the glob
  are accessed.
- **`docs/process.md`** (rationale layer, on demand): why each rule
  exists; decision history; deeper context.
- **`docs/references.md`** (reference catalog, on demand): pointers
  into Lean 4 libraries (mathlib, CSLib) and external mathematical
  literature. Not a binding-rules register; the layer above (path-
  scoped rules + CLAUDE.md) is the rule register.
- **Skills** (`.claude/skills/...`, deferred): for accumulated
  project-specific patterns; create via `skill-creator:skill-creator`
  when friction arises.

This is the verified-current Anthropic architecture per
`https://code.claude.com/docs/en/memory`.

### `CLAUDE.md` skeleton

```markdown
# geb-mathlib

## Project status
[~5 lines: what this is, current phase, key paths]

## Hard rules — must not violate
- Mathlib LLM policy …
- No git push without user review …
- No LLM-drafted user-facing text on mathlib channels …
- No raw `git` mutating commands (use jj) — gated by hook (allow-list with permission prompt)
- Generic user references in all repo content
- `.remember/*.md` must be markdownlint-clean; clean up after each
  `remember`-skill invocation (the plugin emits non-clean markdown).
  Rationale and operational details: see § "Markdownlint discipline".

## Phase-driven workflow
- Brainstorming → `superpowers:brainstorming` (+ `sequential-thinking`)
- Writing-plans → `superpowers:writing-plans`
- Executing-plans → `superpowers:executing-plans` or `subagent-driven-development`
- Each phase produces an artifact; specs/plans are adversarially reviewed
- Verify agent claims against authoritative sources

## Repo structure (one-line)
- `Geb/Mathlib/*` upstream-eligible | `Geb/Internal/*` downstream-only
- Narrow, deep dirs with one indexing file per directory
- `main` = append-only stable branch | `integration` = regenerated fan-in view
- topic branches per PR-candidate

## Style guidelines
- Formal, precise, mathematical, dry, unopinionated.
- Match a mathematical-paper register; cite known mathematics
  where applicable; reference standard notation.
- Avoid value-laden adjectives ("key", "important", "crucial",
  "elegant", "beautiful", "neat", "clever", "powerful",
  "interesting", "insight"). Let the reader form their own
  judgment.
- Refer to "the X-Y theorem" rather than "the seminal X-Y theorem."
- This rule binds repo content; conversational chat is unrestricted.

## Constructive-only Lean code
- No `noncomputable` anywhere.
- Minimise `Classical`; flag/justify each invocation in our own code.
- `scripts/check-axioms.sh` is part of the pre-commit / pre-push
  checklist.

## Specs and plans live on the feature branch
- Each feature's spec, plan, and code co-evolve on the same topic
  branch (`feat/<topic>`, `fix/<topic>`, `migrate/<topic>`, …).
- Spec lands in `docs/superpowers/specs/<date>-<topic>-design.md`;
  plan in `docs/superpowers/plans/`.
- Adversarial-review iterations on spec and plan are commits on
  the same branch.
- Merge to `main` brings the spec, plan, and code together.

## Tooling
- VCS: jj (colocated, lease-protected pushes)
- Build: lake (mathlib pin via SHA + `mathlib-update-action` cron)
- CI: GitHub Actions via `leanprover/lean-action@v1`,
  `leanprover-community/mathlib-update-action`
  (`leanprover-community/upstreaming-dashboard-action` is
  deferred — see open questions; not adopted at bootstrap)
- Linters: markdownlint-cli2, scripts/lint-imports.sh
- Skills: `superpowers:*`, `lean4:*`, `claude-md-management:*`,
  `code-review:*`, `pr-review-toolkit:*`, `commit-commands:*`,
  `security-review`, plus (per inventory pass)
  `dispatching-parallel-agents`, `systematic-debugging`,
  `test-driven-development`, `claude-automation-recommender`
  (one-shot), `remember`, `session-report`,
  `fewer-permission-prompts`. The plan reconciles this list
  with the contents of `reference_skill_additions.md` and
  records any subsequent skill additions there (M6).

## When to consider creating a project-specific skill
[3-line note: if recurring patterns accumulate that don't fit
CLAUDE.md or docs/process.md, use skill-creator to generate a
geb-development skill.]

## Key references
- Memory dir: per-developer local; not committed
- Process rationale: docs/process.md
- Path-scoped rules: .claude/rules/
```

### `.claude/rules/lean-coding.md`

YAML frontmatter:

```yaml
paths: ["**/*.lean"]
```

Content: comment/docstring mandatory rules; mathlib style header
template; `lean4` sub-skill mapping; "no development-history
references in docstrings" and "no post-hoc axiom-free celebration."

### `.claude/rules/upstream-eligible.md`

YAML frontmatter (note: `**` matches files inside the directory but
not the index file at the directory's parent level, so we list
both):

```yaml
paths:
  - "Geb/Mathlib.lean"
  - "Geb/Mathlib/**"
  - "GebTests/Mathlib.lean"
  - "GebTests/Mathlib/**"
```

Content: authoring modes (a)/(b); two-track development;
credentialing-PR checkpoint; floodgate-test reminder; "no bare
`import Mathlib`" rule; the no-prefix-leakage rule (`Geb.Mathlib.`
appears only in import lines).

### `.claude/rules/markdown-writing.md`

```yaml
paths: ["**/*.md"]
```

Content: markdownlint expectations; link conventions; prose-style
brevity preferences.

### `.claude/rules/ci-and-workflow.md`

```yaml
paths:
  - ".github/workflows/**"
  - "scripts/**"
```

Content: workflow conventions; commit-message convention; pre-push
checklist; hook-script conventions.

## Hooks

### SessionStart: signing-key warm-up

`scripts/check-signing-key.sh`:

1. Check whether commits will be signed (`git config --get
   commit.gpgsign` returns `true`). If not, exit 0.
2. Dispatch on `git config --get gpg.format`:
   - **`ssh`**: run `ssh-add -l >/dev/null 2>&1 || ssh-add` —
     prompts the user once if no keys are loaded yet.
   - **`openpgp`/`x509`/unset**: query `gpg-connect-agent
     'keyinfo --list' /bye | grep -q ' 1 '`; if not cached, run
     `echo warm | gpg --clearsign >/dev/null` to seed the cache
     via pinentry.
3. Exit 0 either way (don't block session startup if the user
   isn't ready to unlock; they can do it manually).

**jj-specific note**: jj has its own `[signing]` config table
that does NOT inherit git's signing config. Both must be
configured: `~/.config/jj/config.toml` `[signing]` block with
`behavior = "own"`, `backend = "gpg"` or `"ssh"`, and `key =
"..."`. The agents (`gpg-agent`, `ssh-agent`) are shared, so the
warm-up above works equally for jj-driven commit cascades.

**Why a SessionStart hook**: a cascade of `jj squash`/`jj
split`/`jj describe`/`jj new` operations during normal work each
produce signed commits. Without warm-up, each one prompts —
fragmenting attention. Warming the agent at session start
defers the prompt to once at the boundary.

### SessionStart: toolchain-watch

`scripts/toolchain-watch.sh`:

1. `curl --max-time 5 -fsSL` mathlib master's `lean-toolchain`.
2. If the curl fails (offline, rate-limited, mathlib outage), print
   "toolchain-watch: could not reach mathlib master (offline?); skipping"
   and exit 0 silently — never block a session start on a network call.
3. Otherwise, compare to ours and print a one-line status:
   - In sync: `toolchain-watch: in sync (vX.Y.Z-rcN)`
   - Drift: `toolchain-watch: behind — ours=vX.Y, mathlib=vX.Z.
     Run lake update on a bump/* branch.`
4. Exit 0 either way (don't block).

Runs alongside (does not replace) the existing `remember` plugin's
SessionStart hook.

### PreToolUse: block-mutating-git

`scripts/hooks/block-mutating-git.sh` is an **allow-list**: it
enumerates read-only `git` forms and falls through to a permission
prompt for anything else. The path name is historical — earlier
drafts were a deny-list; the current behaviour is allow-with-prompt.

**Design rationale.** Failure-mode asymmetry favours allow-list
over deny-list. A missed read-only command is loud (the user sees
a prompt) and easy to fix (extend the allow-list). A missed
mutating command in a deny-list is silent and produces unintended
state changes. Allow-list is also the principle-of-least-privilege
default. The prompt-rather-than-hard-block stance reflects the
broader project principle that an individual contributor can take
decisions on their fork or clone that the project itself wouldn't
enforce; the project's binding safety net is server-side
(`conflict-check.yml` plus required-status-checks on `main`), not
client-side hooks.

**Behaviour:**

- Reads JSON from stdin per the Claude Code hook contract:
  `{"tool_input": {"command": "..."}}`.
- Short-circuits to allow (exit 0) if `.jj/` is absent in
  `CLAUDE_PROJECT_DIR` — the hook is a no-op outside colocated
  jj+git repositories.
- Strips `jj git X` invocations (allowed; jj's own git interop).
- Matches the residual command against the allow-list described
  below. Allowed forms exit 0 silently.
- Anything not on the allow-list emits the
  `hookSpecificOutput.permissionDecision = "ask"` JSON so the user
  sees an inline approve/deny prompt with an explanatory reason
  string (mapping common git mutations to their jj equivalents and
  noting how to extend the allow-list).

**Allow-list — unconditional read-only subcommands** (allowed
regardless of flags): `status`, `log`, `diff`, `show`, `blame`,
`reflog`, `ls-files`, `ls-tree`, `cat-file`, `rev-parse`,
`rev-list`, `merge-base`, `for-each-ref`, `describe`, `name-rev`,
`shortlog`, `whatchanged`, `grep`, `count-objects`, `fsck` (no
`--write`; see flag-aware section below), `help`, `version`,
`--version`, `--help`, `ls-remote`, `verify-pack`, `verify-tag`,
`verify-commit`, `annotate`, `check-ignore`, `check-ref-format`,
`format-patch`, `request-pull`, `stripspace`, `var`, `diff-tree`,
`diff-index`, `diff-files`. `symbolic-ref` is allowed in its
read-only forms (bare, `--short`, or `<name>` query); the writing
forms (`--delete`/`-d` or supplying a target argument) prompt.

**Global flag handling.** Before verb matching, the hook strips
the following `git` global flags (which can precede the verb):
`-C <path>`, `-c <key=val>`, `--no-pager`, `--git-dir=<path>`,
`--work-tree=<path>`, `--no-replace-objects`, `--literal-pathspecs`.
This lets `git --no-pager log` and `git -C /tmp status` reach the
allow-list without spurious prompts. Mutating forms with global
flags (e.g., `git -c user.email=x commit -m y`) still prompt,
because the verb after stripping is `commit`.

**Compositional rule.** Shell command chains (`;`, `&&`, `&`,
`||`, `|`, `(`, `)`, newline) are split into segments and each
segment is evaluated independently. A command like `git status && git push`
therefore prompts — the read-only first segment is not enough to
authorise the whole input.

**Known false-positive limitations.** The colon-refspec rejection
regex matches any segment containing a colon between non-whitespace
tokens; this includes URL-form remotes (`https://...`). When `git
fetch <https-url>` triggers the prompt, the user authorises via the
permission UI. Subprocess wrappers (`bash -c "..."`, `sh -c "..."`,
`xargs ...`) are opaque to the hook because the outer command is
not `git`; inner mutations bypass the hook. The project's binding
safety property is server-side (`conflict-check.yml` plus
required-status-check on `main`), not local hooks. Tightening the
regex or adding wrapper-detection is feasible but adds parsing
complexity for low-frequency cases; the project accepts these
limitations.

**Allow-list — flag-aware compound subcommands** (allowed only
when the flags match the read-only forms enumerated):

- `git config`: `--get`, `--get-all`, `--get-regexp`, `--list` (or
  `-l`), `--show-origin`, `--show-scope`. Any other form (notably
  `--set`, `--unset`, `--add`, `--unset-all`, `--rename-section`,
  `--remove-section`) prompts.
- `git branch`: bare `git branch`, `-l`, `--list`, `-v`, `-vv`,
  `-a`, `--remotes`, `--show-current`, `--contains`,
  `--no-contains`, `--merged`, `--no-merged`, `--column`. Mutating
  forms (`-d`, `-D`, `-m`, `-c`, `-C`, `-f`, `--set-upstream-to`,
  `--unset-upstream`, `--track`, `--no-track`) prompt.
- `git tag`: bare `git tag`, `-l`, `--list`, `--contains`,
  `--no-contains`, `--merged`, `--no-merged`, `--points-at`,
  `--column`, `-n` (line-count variant). Mutating forms (`-a`,
  `-d`, `-s`, `-u`, `-f`, `--create-reflog`, `--cleanup`) prompt.
- `git remote`: bare `git remote`, `-v`, `-vv`, `get-url`, `show`.
  Mutating forms (`add`, `remove`, `rename`, `set-url`,
  `set-head`, `prune` without `--dry-run`) prompt. Note that
  `git remote add` and `git remote remove` are mutating (they
  edit `.git/config`); the deny-list-era spec listed them as
  illustrative read-only examples — that was wrong. The allow-list
  treats them as prompts.
- `git worktree`: only `list`. `add`, `remove`, `prune` prompt.
- `git stash`: only `list`, `show`. `push`, `pop`, `apply`,
  `drop`, `clear`, `branch`, `create`, `store` prompt.
- `git submodule`: only `status`. `foreach` always prompts
  because the inner command is opaque to the hook.
- `git notes`: only `list`, `show`.
- `git bundle`: only `verify`, `list-heads`.
- `git fetch`: allowed only in forms that do NOT include an
  explicit `<src>:<dst>` refspec. The colon-refspec form (e.g.,
  `git fetch origin main:main` or
  `git fetch origin +refs/heads/*:refs/heads/*`) updates local
  branches directly — a source-of-truth mutation that bypasses
  the project's append-only `main` invariant. Such forms prompt.
  `git fetch`, `git fetch origin`, `git fetch --dry-run`, and
  `git fetch --prune` are allowed: they update only remote-tracking
  refs (`refs/remotes/<remote>/*`), which jj relies on
  implicitly.
- `git fsck`: allowed unless the segment contains the substring
  `--write` (which causes object-database writes). All other
  forms — including diagnostic combinations such as
  `--full --connectivity-only` — are read-only and allowed.

**Prompt UX.** When a command is not on the allow-list, the hook
emits a JSON document of the form:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "ask",
    "permissionDecisionReason": "git command '<command>' is not on the project's read-only allow-list. For state-mutating operations, use jj. If '<command>' is read-only and should be on the allow-list, edit scripts/hooks/block-mutating-git.sh and add it. The project's binding safety net is server-side (conflict-check.yml plus required-status-check on main); local hooks are conveniences, not enforcement."
  }
}
```

The exact JSON shape MUST be verified at execute-time against
the current Claude Code hook reference
(`https://code.claude.com/docs/en/hooks-reference`); the
`permissionDecision: "ask"` field is the documented form as of
spec drafting.

**Extending the allow-list is a routine project edit.** PRs that
add a missed read-only form to the allow-list are welcome and do
not require a full adversarial-review cycle; they should still
extend the smoke test alongside.

**Rationale on `git worktree` being prompt-not-allowed**: jj v0.41
manages working copies via its own change-DAG model (`jj edit`,
`jj new`); `git worktree add`/`remove` would create or delete
parallel working trees that jj wouldn't track in its operation
log, leading to confusion. If a separate working copy is genuinely
needed, jj's `jj workspace` mechanism is the canonical interface.

Smoke test in `scripts/hooks/tests/test-block-mutating-git.sh`
exercises both allow-paths (each enumerated form returns exit 0)
and prompt-paths (a representative set of mutating forms triggers
the prompt JSON). Exercised by CI.

### Local-vs-server safety model

The project enforces "no conflicted commits in our public
history" as a *server-side* property, not a *client-side* one.
Local jj configuration is *recommended* to give contributors a
hard-fail before they push; the binding gate is a CI workflow
that rejects PRs containing jj-conflict artefacts.

The split is deliberate. Running `jj config set --repo …` on a
contributor's behalf via a setup script is invasive (it modifies
the contributor's local tooling state without their explicit
action). The project respects contributor autonomy by *documenting*
the recommended local config in `docs/process.md § Setup` and
*declining* to enforce it. A contributor who skips the setup may
produce a local mess in their fork — that is their business; we
won't accept their PRs until the conflicted commits are cleaned
up.

This split also neatly absorbs jj v0.41's behaviour change (D23):
in v0.41 `jj git push --all`/`--tracked`/`-r REVSETS` *silently
skips* private/conflicted bookmarks rather than failing. Server-
side rejection catches anything that does land, regardless of
whether the contributor's local push refused it or skipped it.

#### Local recommendation (documented; not enforced)

The recommended local jj config (covered in detail in the
"Recommended local jj configuration (per-developer)" section
above) includes:

- `git.private-commits = "conflicts()"` — refuses to push
  conflicted commits (single-bookmark `-b` form fails; bulk
  forms skip per D23).
- `remotes.origin.auto-track-bookmarks = "glob:*"` — replaces
  the deprecated `git.push-new-bookmarks = true` (D2/D9).
- `revsets.bookmark-advance-from`/`-to` — supports
  `jj bookmark advance` (D10/D11).

The `private-commits` semantics: the config refuses to push any
commit matching the revset (and its descendants). `conflicts()`
is jj's documented revset for "commits that have files in a
conflicted state."

**Important clarification** (verified 2026-05-07 against
`jj git push --help` on jj 0.41.0): jj's default
`git.private-commits` is `none()`, which the help text describes
as "all commits are eligible to be pushed" (M1). So this config
setting is genuinely *needed* — not a redundant override of a
stricter default. Without it, a jj-conflict commit can be pushed,
producing the `.jjconflict-base-*/` / `.jjconflict-side-*/`
synthetic directories visible to git collaborators.

Sources:

- `https://docs.jj-vcs.dev/latest/config/`
- `https://docs.jj-vcs.dev/latest/revsets/`
- `https://docs.jj-vcs.dev/latest/cli-reference/` (`jj git push --allow-private`)

#### Server-side enforcement (binding)

A CI workflow runs on every push and pull-request and rejects the
push/PR if the changeset contains any of the path/marker
patterns enumerated in the canonical `conflict-check.yml`
section above (see "conflict-check.yml" — marker enumeration with
verbatim jj 0.41 strings; this subsection deliberately does **not**
re-enumerate the patterns to avoid the fix-drift hazard exposed in
round 5 of adversarial review, where the duplicated enumeration
diverged from the canonical one and embedded a non-existent jj
literal). The gate covers:

- Synthetic conflict-marker directory paths
  (`.jjconflict-base-*/**`, `.jjconflict-side-*/**`).
- Plain-git three-way merge markers in committed content
  (the **primary** substring target).
- jj's working-copy conflict markers (included for completeness;
  do not normally appear in committed content).

The canonical section above documents (S1, round 6 fix) why the
spec does NOT include a "`(conflict)` in commit message" gate:
that token is a `jj log` template rendering artefact, not a
field of the persisted git commit object, and a grep over `git
log` messages would never match on jj-originated conflicts.

Note (M4 round 2 / M2 round 3): a bare `=======` at column 0 is
also a valid Markdown setext-style **H1** underline (setext H1 is
`===` of any length ≥ 3; setext H2 is `---`). Our docs use ATX
`#`/`##` headers throughout, so the gate's bare-`=======` rule
does not produce false positives in current content; should the
project ever adopt setext headers, the gate must require the
marker to be **paired** with `<<<<<<<` and `>>>>>>>` before
failing.

Concrete check: a small script (specified in the implementation
plan) greps the diff in CI; the workflow file's name and exact
script are deferred to the plan, but the workflow *exists* from
the bootstrap.

Why CI rather than a pre-receive Git hook on the GitHub side:
GitHub does not run user-supplied pre-receive hooks for non-
Enterprise accounts; the equivalent gating is a required-status-
check on the default branch. The CI workflow that performs the
conflict-marker scan is wired as a required check on `main`.

A failing workflow does not delete the contributor's branch or
modify their state in any way — it simply blocks the merge. The
contributor cleans up locally and re-pushes; the workflow re-runs.

#### Why this split, recapped

Contributor autonomy + project safety. The project's
"production-ready ⇒ fork-ready" goal includes "external
contributors can clone, follow CLAUDE.md, and contribute
without us imposing tooling state on their machines."
Server-side enforcement is the only mechanism that scales to
contributors we have not met.

## geb-lean distillation pass

During the bootstrap, walk through the prior tree's
`geb-lean/CLAUDE.md` (a sibling-directory historical artifact, ~order
of 600 lines) together with the user. For each
section / rule / convention: keep / adapt / drop. Anything kept is
re-derived in our `CLAUDE.md` or `docs/process.md` with explicit
rationale (not lifted as-is, given that file's chaotic provenance per
`feedback_geb_lean_distillation`).

## What happens after the bootstrap

The bootstrap completes. The next session begins a separate
brainstorming workstream — the first piece of mathematical /
programming-language work — proceeding via the same processes the
bootstrap establishes (skills-by-phase, adversarial review, no push
without review, etc.). That session:

1. Picks the initial mathematical scope (which concept to formalise
   first).
2. Decides whether to start two-track (Internal first) or directly
   in `Geb/Mathlib/`.
3. Identifies whether the first work is a credentialing-PR candidate.
4. Produces its own spec and plan in `docs/superpowers/specs/` and
   `plans/`.

The bootstrap's `TODO.md` has at least one entry for "begin first
mathematical workstream brainstorming" pointing at the next-up
work.

## Test-repo simulation

The bootstrap is not an ordinary scaffolding job — it stands up a
public repository we intend to build on for years. Creating that
repo and discovering process bugs against it for the first time
would mean public history with force-pushes, awkward fix-up commits,
or "we're starting over" events visible to anyone watching. None of
that is acceptable for a project intended to be plausibly
upstreamable to mathlib.

So before the real repo exists, we stand up a **throwaway public
test repo** and exercise every documented process there end-to-end.
We iterate this spec on every discrepancy between expected and
actual behaviour. The test repo's purpose is to discover process
bugs while a do-over is free.

### Test repo identity (numbered iterations)

- **GitHub remotes**: `rokopt/geb-mathlib-test-1`,
  `rokopt/geb-mathlib-test-2`, …, `rokopt/geb-mathlib-test-N`,
  each public, each with a `README.md` whose first line is a
  clear disclaimer ("Throwaway test repository for the
  geb-mathlib bootstrap; iteration N; ignore.").
- **Local clones**: sibling directories of the real repo's
  eventual location, named `geb-mathlib-test-1`,
  `geb-mathlib-test-2`, …
- **No deletion during testing**: each iteration creates a fresh
  numbered repo. **We never run `gh repo delete` during the
  iteration loop.** Earlier-iteration repos remain available for
  diagnostic inspection. After the real repo is healthy, the user
  manually batch-deletes all `rokopt/geb-mathlib-test-*` repos
  in one session. Rationale: `gh repo delete` is unrecoverable;
  numbered repos eliminate the deletion-during-iteration risk
  entirely. Each test repo is small (process scaffolding only,
  no math), so cumulative storage cost is trivial.
- **Extraction-script verification**: the PR-extraction script
  (event H below) is exercised **locally only** during the
  simulation — we run it, inspect its output by `git diff`, but
  **do NOT push extracted branches to `rokopt/mathlib4`** during
  the simulation. Reasons: (a) the test repo's content is
  meaningless when extracted into mathlib's tree (it's bootstrap
  scaffolding, not real math), and (b) pushing test branches to
  the real `rokopt/mathlib4` fork pollutes its branch listing and
  audit history. The extraction-script's *push semantics* are
  exercised once on the real repo against a real PR-candidate, as
  routine work after the bootstrap.

- **Post-real-fork pollution-prevention rule**: once the
  `rokopt/mathlib4` GitHub fork exists (per goal 17), there is no
  intended push to it during the bootstrap. The first push to the
  fork happens with the first real mathlib PR-candidate, which is
  routine post-bootstrap work. The pre-push checklist's "user
  reviewed line-by-line" rule applies to fork pushes; the
  bootstrap discipline forbids pushes to it before that gate has
  fired.

### Why this design rather than alternatives

Standard alternatives we considered and rejected:

- **GitHub `--template` repo + scratch clones**: meant for repos
  that *templatise* a starting point. Doesn't fit; we don't want
  a long-lived template, we want a one-shot dry run.
- **Branch-based testing inside the real repo**: would mean
  creating the real repo first, then testing on a branch — defeats
  the "discover process bugs before they're public" purpose.
- **Organisation sandbox repo**: not relevant for personal-account
  ownership (`rokopt`).
- **Personal staging fork**: that's effectively what
  `rokopt/geb-mathlib-test-N` is; we follow the pattern.

So a throwaway public test repo with explicit lifecycle is the
right shape for our case.

### Simulation event categories (dependency-ordered)

The runbook executes these in order; later events depend on earlier
ones working.

A. **Repo creation and bootstrap branch**

- **Pre-flight checks** (D6, D13, D14):
  - `jj --version` reports 0.41.0 or newer.
  - `git --version` reports 2.41.0 or newer.
  - `jj config get user.name` and `jj config get user.email`
    return values; if either is empty, the contributor sets them
    via `jj config set --user user.name "..."` /
    `user.email "..."` before continuing.
  - The working directory is NOT inside an existing git
    worktree (jj v0.38+ refuses `jj git init --colocate` there).
- (M4 round 6 fix.) Throughout this event, the runbook uses the
  shell variable `${N}` for the current test-repo iteration
  number, matching the iteration-loop snippet later in this
  section. The runbook expects `${N}` to be exported in the
  contributor's shell (e.g., `export N=2` for the second
  iteration) before the steps below run; the iteration-loop
  snippet sets `NEW_N` automatically.
- `gh repo create rokopt/geb-mathlib-test-${N} --public` (this
  creates only the remote — `gh` does NOT create a local checkout
  when `--clone` is omitted).
- `mkdir geb-mathlib-test-${N} && cd geb-mathlib-test-${N}` to
  create and enter the local working directory before any
  `git`/`jj` invocation (the runbook depends on the working
  directory matching the repo name).
- `git init --initial-branch=main` + `jj git init --colocate`
     in the new working directory. Expected output (jj v0.41.0,
     verified 2026-05-08): the single line `Initialized repo in
     "."`. The `Hint: Running git clean -xdf will remove .jj/!`
     line that D26 captured against jj v0.40 is no longer emitted
     in v0.41 (D26 in `jj-040-discoveries.md` was specific to
     v0.40). Earlier text expecting `Initialized repo in <path>`
     (with absolute path) is stale.
- Apply the recommended local jj config (per "Recommended local
     jj configuration" section above) by `jj config set --repo`
     for `git.private-commits`, the `auto-track-bookmarks` glob,
     and the bookmark-advance revsets.
- Anchor `main` at an empty placeholder commit (per "Bookmark
     anchoring (D3)"): `jj describe -m "chore: anchor main at
     empty placeholder commit"`, then `jj bookmark create main
     -r @`.
- Move forward via `jj new`, then create a `chore/bootstrap`
     topic branch at the new working-copy change (`jj bookmark
     create chore/bootstrap -r @`); subsequent bootstrap work
     accumulates on `chore/bootstrap`.
- First commit (`README.md`, `LICENSE`, minimal scaffolding,
     `.markdownlint-cli2.jsonc`, `.gitignore`) on `chore/bootstrap`.
     CSLib availability is confirmed as a configuration check
     (`.lake/packages/cslib/Cslib/Init.lean` exists post-`lake
     update`); no sanity-import `.lean` file is committed, per
     the project's "code is cost" principle. When real content
     uses CSLib, that content is the verification.
- Verify `markdownlint-cli2` runs clean against the repo.
- **User review of the first commit's diff line-by-line** (per the
     "no push without review" rule) before any push.
- First push of `main` and `chore/bootstrap` to the new remote
     (the bare `-b <name>` form auto-tracks per D9; no
     `--allow-new` flag).
- **`main` FF rehearsal (M4 round 5; M3 round 6 wording).**
     Fast-forward `main` on the test repo to the current
     `chore/bootstrap` tip via `jj bookmark set main -r
     chore/bootstrap` followed by `jj git push -b main`. The
     rehearsal *exercises the FF mechanism* (one move + one
     creation produces two reflog entries, so verification item
     22's pairwise-ancestor walk runs on more than one entry on
     the test repo). It is a smoke test, not a deep stress test:
     Task 4.7's real-repo flow walks the FF across ~10–20 commits
     after the history rewrite, whereas this rehearsal walks one
     FF only. Without this step, `git reflog show main` on the
     test repo contains a single creation entry and item 22 passes
     vacuously.
- Open a fresh Claude session in this repo; verify the toolchain-
     watch hook fires (in-sync case) AND the `remember` plugin's
     SessionStart hook is silent (not erroring on `.remember/logs/`).

B. **Hooks active**

- Toolchain-watch hook: in-sync case (silent), drift case
     (manually edit local `lean-toolchain` to an older value),
     offline case (block network temporarily).
- PreToolUse mutating-git hook: type `git checkout` and verify
     the hook emits a permission-ask prompt with the expected
     reason string; type `jj git push` and verify it runs without
     prompting.
- Smoke test in `scripts/hooks/tests/` runs and passes.

C. **Branch operations**

- Create `feat/<topic>`, `chore/<topic>`, `fix/<topic>` topic
     branches; commits on each; push each.

D. **CI activates**

- `ci.yml` fires on push to `main` and on a deliberately-opened
     PR. Job statuses observed.
- `markdown-lint.yml` fires; passes.
- `update.yml` validity check: triggered via `workflow_dispatch`;
     success criterion is the canonical one stated at the top of
     the spec (`update.yml` bootstrap-time success criterion;
     M7) — workflow parses, loads in `gh workflow list`, runs to
     completion. Either bump-PR-opened or no-op outcome is
     acceptable. **Cron race**: the test repo's lifetime may
     straddle a `'0 17 * * *'` cron firing; resulting bump PRs
     against the test repo's `main` are noise we ignore (the
     test repo is throwaway). Note in the runbook.

E. **Integration regeneration**

- Run `scripts/regenerate-integration.sh`; verify
     `integration`'s tip is the fan-in merge of all active topic
     branches.
- Force-push the regenerated `integration`; verify the remote
     accepts (lease check passes) and the regenerated history is
     visible on GitHub.
- **Verify `main` was NOT touched** by the regeneration —
     `main`'s tip should be unchanged. `main` is append-only;
     only `integration` is force-pushed.
- Topic branches that are *complete* (e.g., a finished feature)
     are merged into `main` via normal merge commits in a
     separate event, not via integration regeneration.

F. **Mass-rebase on a simulated bump**

- Create a `bump/<lean-version>` branch.
- `lake update` (which produces a real or simulated mathlib
     advance).
- Update `lean-toolchain`, fix any breakage.
- Run `scripts/rebase-topics.sh main`; verify all topic
     branches are now based on the new `main`.
- Regenerate `integration` again (NOT `main`); verify clean.

G. **Floodgate-CI lint**

- **G1 (test-only)**: add a file to `Geb/Mathlib/` with a
     forbidden import; verify `scripts/lint-imports.sh` rejects
     it.
- **G2 (test-only)**: add a file to `Geb/Mathlib/` with a
     `Geb.Mathlib.X` reference outside an `import` line; verify
     the prefix-leakage rule rejects it.
- **G3 (bootstrap-real)**: add a clean file; verify the lint
     passes.
- **G4 (test-only)**: add a stub declaration that uses
     `Classical.choice` (e.g., a definition that invokes
     `Classical.choice` directly, or whose elaboration emits
     `Classical.choice` in its axiom closure); verify
     `scripts/check-axioms.sh` flags it. This exercises the
     axiom-allowlist policy that excludes `Classical.choice` per
     the constructive-discipline rule.

H. **PR extraction (local-only)**

- Add a clean `Geb/Mathlib/X.lean` file with a tiny example
     (a single trivial declaration, since we have no real math
     content; the point is exercising the script, not validating
     the math).
- Run `scripts/extract-pr.sh` against it; observe the rewritten
     output by `git diff` against a fresh worktree of upstream
     `leanprover-community/mathlib4` (cloned to a temp directory
     just for this purpose; we do NOT need our own
     `rokopt/mathlib4` fork to exist yet, since we're only
     diffing the script's output against mathlib's tree).
- **Do NOT push the extracted branch anywhere.** The test repo's
     extraction is for script-mechanics verification only. The
     full extract-and-push flow gets validated on the real repo's
     first real PR-candidate as routine work, not during the
     simulation.

I. **Conflict-commit refusal (server-side gate)**

- Deliberately create a jj-conflict commit (e.g., merge two
     incompatible feat branches).
- **Local-side check (recommended config)**: with the
     recommended `git.private-commits = "conflicts()"` applied,
     `jj git push -b <name>` refuses (single-bookmark form fails
     hard). Bulk forms (`--all`/`--tracked`/`-r`) silently skip
     in jj v0.41 (D23) — verify the expected-skipped notice
     appears in stderr.
- **Server-side check (binding gate)**: open a PR from a
     deliberately-conflicted bookmark (bypassing local config),
     and verify `conflict-check.yml` fails on the PR, blocking
     merge.

J. **Process self-update**

- Invoke `claude-md-management:revise-claude-md` on a trivial
     change (e.g., add a sentence to `CLAUDE.md`).
- Verify the diff round-trips through user review and the
     updated rule loads in a fresh session.

K. **Doc generation**

- Run the doc-gen4 incantation (TBD-during-simulation).
- Verify it produces output without warnings.
- Open the rendered docs in a browser; visually confirm.

### Runbook format and storage

The runbook lives at
`docs/superpowers/runbooks/2026-XX-XX-bootstrap-runbook.md` —
**in the developer's local geb-mathlib working tree**, NOT in any
test repo. Each iteration uses a fresh `rokopt/geb-mathlib-test-N`
(incrementing N per "Iteration loop and reset discipline" below);
prior test repos are NOT deleted until Part 5 closeout. The runbook
persists across all iterations because it's in the dev's main repo
workspace, not in any test repo. After the real repo is created and
the runbook used to bring it up, the runbook is committed to the
real repo at the same path as historical record.
For each event, the runbook records:

- **Preconditions**: required repo state.
- **Action**: exact command(s) to run.
- **Expected result**: what should happen.
- **Verification**: how to confirm success.
- **Rollback / cleanup**: how to undo if something went wrong.
- **Discoveries**: notes on anything that didn't match the spec,
  with date stamps and links to spec changes that resulted.

The runbook starts as the proposed sequence and ends as "the
sequence that actually worked." Discoveries during the test-repo
phase produce updates to *this* spec, to memory, and to the
runbook itself. The pattern is: try → observe → if surprised,
update spec/memory → continue.

### Iteration loop and reset discipline

Execution of the simulation events is **iterative**. Each event:

1. Read the runbook entry; verify preconditions.
2. Execute the action.
3. Observe the result.
4. If matches expected: mark done, move to next event.
5. If doesn't match: pause, diagnose, update spec / memory /
   runbook to reflect the discovery; **then increment the
   iteration counter N to N+1, create a fresh
   `rokopt/geb-mathlib-test-(N+1)` and a fresh local clone, and
   restart the simulation from event A** in the new repo.

**Increment-N rather than delete-and-recreate** is the user-
mandated reset discipline (per `feedback_test_repos_numbered`).
Reasons:

- `gh repo delete` is unrecoverable; mistakes (typos, wrong repo
  name) could be disastrous. Avoiding the command entirely during
  the iteration loop eliminates that risk.
- Earlier-iteration repos remain available for diagnostic
  inspection if later iterations fail in ways related to earlier
  discoveries.
- Each iteration's repo is small (process scaffolding only); the
  cumulative storage cost is trivial.

```bash
# At iteration N+1:
NEW_N=$((N + 1))
gh repo create rokopt/geb-mathlib-test-${NEW_N} --public
mkdir geb-mathlib-test-${NEW_N}
cd geb-mathlib-test-${NEW_N}
# then proceed with event A
```

**Cleanup is one batch operation at the end**: after the real repo
is healthy and confirmed, the user manually deletes all
`rokopt/geb-mathlib-test-*` repos in one session. Until that
point, no test repo is deleted.

We do not declare the test-repo simulation complete after a
single iteration. We declare it complete when **a clean execution
of all events from start to finish on a fresh
`rokopt/geb-mathlib-test-N` (some N), with no spec changes
during, signed off by the user, has succeeded**. Until then, the
loop continues with new numbered repos.

### Out-of-band discoveries log

Because force-pushes during the simulation destroy intermediate
states, the "Discoveries" notes in the runbook must record context
out-of-band: relevant outputs (commands, error messages,
diagnostic state) are pasted *into* the runbook entry, not just
referenced by jj/git revision. The runbook is the durable record;
the test repo's history is volatile.

### Test-only events vs. bootstrap-real events

Some simulation events are **test-only** — they're done to verify
the process works, but are NOT part of the runbook executed
against the real repo:

- **Toolchain-watch drift case** (B, sub-event): manually editing
  `lean-toolchain` to an older value to test the hook's drift
  warning. The artifact is not part of real-repo content and is
  reverted before moving on.
- **Toolchain-watch offline case** (B, sub-event): blocking
  network temporarily.
- **Forbidden-import file** (G, sub-events): adding files that
  intentionally trip the floodgate-CI lint to verify rejection.
  These are deliberately broken inputs, not part of the real repo.
- **Conflict-commit creation** (I): manufacturing a jj-conflict to
  test push refusal. Not part of real-repo content.

The runbook **clearly marks** each event as either *bootstrap-real*
(re-executed on the real repo verbatim) or *test-only* (run only
on the test repo, skipped on the real repo). The real-repo runbook
is a *strict subset* of the test-repo runbook, omitting the
test-only events.

### Termination criterion

The test-repo simulation terminates when:

1. All bootstrap-real events execute cleanly on a freshly-reset
   test repo, start-to-finish, with no spec changes during.
2. All test-only events have been exercised at least once
   (potentially on a different test-repo iteration if needed) and
   confirmed working.
3. The runbook has no open "discoveries."
4. The user has signed off on the runbook as "this is the
   sequence we will run on the real repo."

### Test-repo cleanup

After the real repo is healthy and confirmed: the user manually
deletes all `rokopt/geb-mathlib-test-*` repos in a single batch
session. Local clones (`geb-mathlib-test-1/`, `-2/`, …) are
deleted at the same time.

The deletion is **explicitly user-driven** — Claude does not run
`gh repo delete` autonomously, even at the end of bootstrap. The
user runs the cleanup commands themselves so any typo or wrong-
repo confusion lands on a human review gate.

## Verification

The bootstrap completes in **two passes** of the same verification
checklist: first against the test repo (with iteration on each
failure), then against the real repo (expected to pass clean since
the spec has been iterated to convergence).

### Verification checklist (mapped to simulation events)

Each item is mapped to the simulation event(s) that exercise it.
The mapping is exact for **simulation-bound items**; the
**out-of-simulation items** (marked explicitly) are gates checked
outside the simulation loop (adversarial reviews, fork existence,
etc.).

**Reading the "Sim. event(s)" column**: the letters (`A`, `B`,
`C`, …) index into the lettered subsections under
[**Simulation event categories (dependency-ordered)**](#simulation-event-categories-dependency-ordered)
in the Test-repo simulation section above (`A. Repo creation and
bootstrap branch`, `B. Hooks active`, etc.). A cell like
"`E (explicit check)`" refers to event E in that list.

| # | Verification item | Sim. event(s) |
| --- | --- | --- |
| 1 | `lake build` succeeds on empty library skeleton | A (after first commit) |
| 2 | `lake test` succeeds on empty test library (to be verified during the first test-repo simulation iteration where event A reaches a clean run; if `lake test` does not exit 0 on the empty `GebTests` library in the running Lake version, the plan must include a fallback test that swaps `testDriver` to a script-style entry per FLT/CSLib precedent and adjusts `lakefile.toml` accordingly; S2 / S5) | A (after first commit) |
| 3 | `lake lint` runs without warnings | A |
| 4 | `ci.yml` passes on push to `main` and `integration` | D |
| 5 | `ci.yml` passes on the bump PR (PR-against-`main`) | D |
| 6 | `markdown-lint.yml` passes | D |
| 7 | `update.yml` syntactically valid; runs to completion on `workflow_dispatch` (`mathlib-update-action` either opens a bump PR or reports no-update; both are acceptable; no registration is required for `mathlib-update-action`) | D |
| 8 | (deferred) `upstreaming-dashboard-action` produces a valid dashboard | (out-of-bootstrap; adopt when there's content to dashboard) |
| 9 | git-blocking hook prompts on raw `git checkout`; allows `jj git push`; allows non-refspec `git fetch` forms; smoke test in `scripts/hooks/tests/` passes | B |
| 10 | Toolchain-watch hook: in-sync silent | B |
| 11 | Toolchain-watch hook: drift case prints sensible message (test-only event) | B |
| 12 | Toolchain-watch hook: offline case degrades gracefully (test-only event) | B |
| 13 | Signing-key warm-up hook unlocks GPG/SSH agent at session start (no mid-cascade prompts) | B |
| 14 | `markdownlint-cli2` quiet on every `.md` (including `.remember/`) | A (and continuously) |
| 15 | `.remember/` is gitignored; remember-plugin SessionStart hook silent | A |
| 16 | Floodgate-CI lint rejects forbidden import (test-only event) | G |
| 17 | Floodgate-CI lint rejects `Geb.Mathlib.` outside imports (test-only event) | G |
| 18 | Floodgate-CI lint passes on a clean file | G |
| 19 | `scripts/check-axioms.sh` (vendored from lean4-skills, with `Classical.choice` excluded from allowlist) runs in CI on `Geb/` and `GebTests/`; passes on the empty/skeleton bootstrap library; the workflow is exercised in a test-only event by intentionally adding a `Classical.choice`-using stub and verifying the script flags it | A (passing-case) and G (test-only failing-case) |
| 20 | `scripts/regenerate-integration.sh` produces fan-in merge with lease-protected push | E |
| 21 | Force-push of regenerated `integration` accepted by remote (lease check passes); `main` is **not** modified by the regeneration | E |
| 22 | `main` is never force-pushed: the pairwise ancestor walk over `git reflog show main --format='%H'` (newest-first, reversed via `tac`) satisfies `git merge-base --is-ancestor <prev-sha> <next-sha>` (exit 0) on every consecutive pair. Any non-zero exit is a non-FF move and breaks the invariant. The reflog message itself does *not* annotate FF vs non-FF in jj-colocated mode — every entry's message is `export from jj` — so the binding check is the pairwise ancestor walk, not the message text (S1, S10). The shell form is given in this spec's "Verification 22" snippet (B1, round 4 — exit-code-propagating form via process substitution). The earlier round-1 example using `jj op log --template 'self.bookmarks()...'` was incorrect (the `Operation` template type has no `bookmarks()` method in jj 0.41; the form errors at parse time); the plan may add a jj-native equivalent later, but the git reflog ancestor-walk is the canonical evidence here. | E (explicit check) at end of test-repo simulation |
| 23 | `scripts/rebase-topics.sh` rebases topic branches | F |
| 24 | `scripts/extract-pr.sh` produces a clean diff (local-only verification) | H |
| 25 | `conflict-check.yml` rejects a deliberately-pushed jj-conflict commit (server-side enforcement is the binding gate; the local `git.private-commits = "conflicts()"` ergonomic is recommended in `docs/process.md` but not project-enforced — D8/D23) (test-only event) | I |
| 26 | `claude-md-management:revise-claude-md` produces a reviewable diff that loads in a fresh session | J |
| 27 | `doc-gen4` produces output without warnings; renders correctly | K |
| 28 | CSLib package is fetched: `.lake/packages/cslib/Cslib/Init.lean` exists post-`lake update` (no committed `.lean` file under `Geb/` is required to verify; per "code is cost") | A |
| 29 | Adversarial review of this spec terminated with no non-cosmetic findings | (out-of-simulation) |
| 30 | Adversarial review of the bootstrap plan terminated | (out-of-simulation) |
| 31 | `CLAUDE.md` round-trips through a fresh session | J |
| 32 | Local `mathlib4` fork clone exists; `rokopt/mathlib4` GitHub fork exists | (out-of-simulation, real-repo only) |
| 33 | jj initialised; first user-reviewed local commit on `chore/bootstrap` exists | A |
| 34 | Real-repo brought up via series-of-reviewed-commits-with-clean-history (per `feedback_initial_push_series`) | (out-of-simulation, real-repo only) |
| 35 | A fresh-session clone of the real repo immediately picks up CLAUDE.md and follows our processes | (out-of-simulation, real-repo only — fork-readiness check) |

### Verification 22 snippet (`main` append-only ancestor walk)

The pairwise ancestor walk implementing item 22 (B1, round 4 — exit
code now propagates correctly via process substitution; the loop runs
in the parent shell, not a pipe-side subshell, so `exit 1` reaches
the script's exit status):

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
```

`git reflog show main --format='%H'` returns the new-sha of each
entry (newest-first); `tac` reverses to oldest-first. Each iteration
compares the previous new-sha to the current one. The script exits 0
iff every transition is a fast-forward (or a merge whose first parent
is the previous tip).

Verified empirically on jj 0.41.0 (2026-05-08) against a colocated
scratch repo: FF-only history exits 0; introducing a backward move
via `jj bookmark set main -r @- --allow-backwards` causes the next
run to exit 1 with `non-FF: <old> -> <new>`. Note that jj 0.41
refuses backward moves by default (`Refusing to move bookmark
backwards or sideways: main / Hint: Use --allow-backwards to allow
it.`), so violating the invariant locally requires either an
explicit `--allow-backwards` flag or bypassing jj entirely (e.g.,
raw git ref manipulation).

### First pass — test repo

The full checklist passes on a fresh `rokopt/geb-mathlib-test-N`.
Iteration continues (incrementing N) until the pass is clean
(no spec changes during).

### Second pass — real repo, via series-of-reviewed-commits

After the test-repo phase signs off:

1. Create `rokopt/geb-mathlib` on GitHub (empty initially);
   `gh repo create rokopt/geb-mathlib --public`.
2. **Re-run the pre-flight checks from event A** (jj/git
   versions, jj user identity, no enclosing git worktree per
   D14) before any local work in the new directory (S9). The
   check list is identical to event A's; do not duplicate it
   here.
3. Locally clone, `jj git init --colocate`, and replay the
   runbook onto this clone. Each event in the runbook produces
   one or more jj commits.
4. **Capture the pre-rewrite bookmark inventory** (S6):
   `jj bookmark list --all > /tmp/bookmarks-pre-rewrite.txt`.
   This file is the reference set the post-rewrite list must
   match.
5. Once the runbook is replayed end-to-end, **rewrite history**
   into a clean topological sequence. Concrete jj commands —
   bookmark-safety flags differ per command (B1 / S1; verified
   against `jj <cmd> --help` on jj 0.41.0; do NOT assume a
   single flag works on every rewrite verb):
   - `jj log` — view the current commit graph (read-only).
   - `jj squash --from <src> --into <dst> --keep-emptied` —
     collapse adjacent commits. The `-k` / `--keep-emptied`
     flag (jj 0.41) prevents the now-empty source from being
     abandoned, keeping any bookmark on it addressable. If
     the source carries no bookmark, `--keep-emptied` may be
     omitted and the source is abandoned cleanly. Note: there
     is no `--retain-bookmarks` flag on `jj squash` in 0.41 —
     the round-1 fix that added it would error at the CLI
     parser before any commit was touched.
   - `jj split -r <rev>` — split a commit into multiple
     (split does not abandon; bookmarks land on the second of
     the resulting changes by jj's default — verify with
     `jj bookmark list` after each split).
   - `jj describe -r <rev> -m "..."` — rewrite commit messages
     (does not abandon; change-id is preserved).
   - `jj rebase -r <rev> -d <new-parent>` — reorder. No
     bookmark flag needed: `jj rebase` preserves change-ids,
     so bookmarks travel with the rebased commit by default
     (D3). `jj rebase` exposes `--keep-divergent` (a
     divergence-handling flag) but NOT `--retain-bookmarks`.
   - `jj abandon <rev> --retain-bookmarks` — drop a change
     without losing its bookmarks (which then move to the
     parent commit). This is the only rewrite verb in jj 0.41
     that exposes `--retain-bookmarks`.
   The target shape is ~10–20 commits in topological order:
   scaffolding → conventions → CI → hooks → test infrastructure
   → first content commit (the bootstrap branch).
6. **Clean up orphan empty commits** (M3): `jj squash
   --keep-emptied` retains an empty hull so any bookmark on the
   source remains addressable, but if a subsequent step moves
   the bookmark off, the hull is now an orphan. Inspect with
   `jj log -r 'empty()'` (the `empty()` revset is supported in
   jj 0.41 — verified). For each empty commit that is no longer
   carrying a bookmark, abandon with `jj abandon -r <rev>
   --retain-bookmarks`. Without this cleanup, `--keep-emptied`
   leaves residue and the "10–20 clean topological commits"
   target is unreachable.
7. **Verify the post-rewrite bookmark inventory matches the
   pre-rewrite list** (S6): `jj bookmark list --all >
   /tmp/bookmarks-post-rewrite.txt`; `diff -u
   /tmp/bookmarks-pre-rewrite.txt
   /tmp/bookmarks-post-rewrite.txt` — the bookmark *names* must
   match exactly (the change-ids will differ because of the
   rewrite). If any bookmark name is missing, a rewrite step
   silently dropped it and must be reapplied with the correct
   per-command flag — `--retain-bookmarks` for `jj abandon`,
   `--keep-emptied` for `jj squash`, or no flag for
   `jj rebase` / `jj describe` (whose default behaviour
   already preserves bookmarks via change-ids).
8. **The user reviews each commit's diff line-by-line** per the
   no-push-without-review rule. For ~10–20 commits, this is
   roughly an hour of focused review; budget accordingly.
9. The user signs off on the entire local history.
10. **Single push** to the real repo:
   `jj git push --remote origin --all`. This is the first push;
   it delivers a coherent public history rather than fixup-noise.
   Apply the **silent-skip gate** (B2 / S3 / D23) here — this
   is the only bulk-push surface in the bootstrap, and jj 0.41's
   `--all` form silently skips private/conflicted bookmarks
   instead of failing. The gate has two parts (verify both).

   The verbatim shape of `jj git push --dry-run` output (captured
   from jj 0.41.0 against a colocated scratch repo, 2026-05-07):

   ```text
   Changes to push to origin:
     bookmark: feat/test [add to f7bbfeacf515]
     bookmark: main [add to f5c4021d37ab]
     bookmark: feat/test [move forward from f7bbfeacf515 to 48d25cf14b6d]
     bookmark: feat/test [move sideways from 48d25cf14b6d to f35f5115e141]
   ```

   Each bookmark-action line begins with two spaces, then the
   literal `bookmark:` followed by a space, the bookmark name,
   and a bracketed action of form `[add to <hash>]`,
   `[move forward from <hash> to <hash>]`, or
   `[move sideways from <hash> to <hash>]`.

   The gate has two parts:

   **Substring grep on stderr** for `Won't push bookmark` and
   `Won't push commit` (the actual jj 0.41 stderr literals
   emitted when a private/conflicted bookmark is silently
   skipped, verified against the running tool — *not*
   `Skipping`, which appears in the changelog prose but never
   on the wire). The shell form is
   `jj git push --remote origin --all --dry-run 2>&1 |
   grep -E "Won't push (bookmark|commit)"`.

   **Structural count check**: count the bookmark-action lines
   in the dry-run output via the regex
   `^  bookmark: .+ \[(add to|move forward from|move sideways from)\s`
   and assert the count equals the size of the to-be-pushed
   bookmark set. A silently-skipped bookmark produces no such
   line, so the count is short and the gate fails. The grep
     pattern is keyed to the verbatim output above; if a future
     jj version changes the format, the gate fails closed (the
     count drops to zero) rather than silently passing.

   Either gate failing is a hard fail — fix locally and retry.
11. Run the verification checklist on the real repo.

The bootstrap is **complete** when:

- The real-repo pass succeeds end-to-end with no surprises.
- The user has confirmed that a fresh-session clone immediately
  picks up `CLAUDE.md` and follows our documented processes (the
  fork-readiness test from `feedback_initial_push_series`).

If a surprise is discovered during the real-repo pass, that's a
serious finding: pause, fix the spec / runbook / scripts, and
optionally run another iteration of the test-repo simulation
to re-validate the affected event. Then resume.

The user has reviewed and approved the initial pushed contents
of `rokopt/geb-mathlib` line-by-line, per the standing "no push
without review" rule.

## Open questions / deferred decisions

- **Initial mathematical scope** (deferred to the first mathematical-
  workstream brainstorming session that follows the bootstrap).
- **Doc-CI reminder mechanism** specifics (SessionStart hook? weekly
  cron? other?). Decide during scaffolding.
- **Whether to migrate Internal-Foo dependencies to Mathlib-Foo
  eagerly or lazily** when the Mathlib version becomes available.
  Project-policy decision; defaulting to eager migration.
- **Whether to create a `geb-development` project-specific skill**
  preemptively or wait for friction. Defaulting to wait.
- **Whether to maintain a curated `notes` or `journal` directory**
  for ad-hoc explorations. Defaulting to no; can add if friction.
- **`upstreaming-dashboard-action` adoption**: deferred until we
  have substantive `Geb/Mathlib/*` content for the dashboard to
  inspect. Adoption requires a Jekyll Pages setup (the action
  emits markdown files; doesn't host). Trigger to revisit: when
  the first PR-candidate is in flight against mathlib.
- **`mathlib-update-action` `intermediate_releases` setting**:
  `all` (every intermediate Lean release; default), `latest`
  (only the newest release, then mathlib `master`), or `master`
  (only mathlib `master`). Verified against `action.yml` at SHA
  `d2b88048`, 2025-11-11; an earlier draft of this spec listed a
  `stable` value in error (per finding F8 in test-2 findings).
  Decide during scaffolding based on observed bump-PR cadence
  preference.
- **`downstream-reports` registration timing**: the bootstrap
  intentionally does NOT register `geb-mathlib` with the
  `leanprover-community/downstream-reports` LKG/FKB pipeline.
  Registration generates daily Zulip `NEW_FAILURE`/`RECOVERED`
  notifications and adds a row maintainers see; we want to spare
  the community that noise until our project has substantive
  content the community would care about. **Decision is manual
  and periodic**: at intervals after content lands, the user
  asks "do we have enough substance for registration to be
  informative now?" and decides yes/no. The infrastructure for
  registration (swap `update.yml`'s action to the
  `downstream-reports` set) is ready from bootstrap; the
  registration PR itself is the user's deliberate act, separate
  from any other workstream.

## References

This spec consolidates 35+ memory entries plus extended brainstorming
across two sessions (2026-05-04 to 2026-05-05). Authoritative sources
cited inline include:

- Mathlib contribute pages (LLM policy, commit messages, style).
- Anthropic memory documentation (CLAUDE.md architecture).
- jj v0.41 documentation (workflow primitives); jj CHANGELOG
  v0.20–v0.41 cross-referenced for behavioural baseline (D8–D26).
- FLT, sphere-eversion, MIL (downstream lakefile and CI patterns).
- Verso and doc-gen4 repositories (docs strategy).
- Lean v4.30-rc2 release.

The Claude memory directory for this project (a per-developer local
state, not part of the repo) contains the full rationale and
provenance for each rule encoded above.

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

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

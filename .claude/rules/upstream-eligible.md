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

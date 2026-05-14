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
7. Install `doctoc` to enable pre-push TOC regeneration of
   committed Markdown:
   `npm install -g doctoc` (or your preferred install path).
   The pre-push checklist skips the TOC check when `doctoc` is
   missing rather than failing, so this step is recommended but
   not blocking.

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

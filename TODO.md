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

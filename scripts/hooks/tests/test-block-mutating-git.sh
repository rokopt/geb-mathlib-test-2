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

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

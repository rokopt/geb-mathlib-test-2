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

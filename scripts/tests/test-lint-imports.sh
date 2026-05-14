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

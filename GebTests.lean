/-
Copyright (c) 2026 The geb-mathlib contributors. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: The geb-mathlib contributors
-/
module -- shake: keep-all, shake: keep-downstream

public import GebTests.Mathlib
public import GebTests.Cslib
public import GebTests.Internal

/-!
# GebTests root module

Test library root. Mirrors `Geb.lean` structure: `GebTests.Mathlib`
tests `Geb.Mathlib`; `GebTests.Cslib` tests `Geb.Cslib`;
`GebTests.Internal` tests `Geb.Internal`.
-/

# Mathematical / library references

Catalog of useful pointers into Lean 4 libraries and external
literature, organised by topic.

## Searchable

- [Loogle](https://loogle.lean-lang.org/)
  - A searchable reference to the Lean standard libraries — use
    this to try to find standard implementations of concepts that
    we don't already know about.
- [Reservoir](https://reservoir.lean-lang.org/)
- The remote-index search tools (Loogle, `lean_leansearch`,
  `lean_leanfinder`, `lean_state_search`, `lean_hammer_premise`)
  index mathlib + Lean core + batteries; **none currently index
  CSLib**. For CSLib content, use the CSLib API docs site
  (<https://api.cslib.io/docs/>) or grep the CSLib source under
  `.lake/packages/cslib/Cslib/`.
- When introducing a new computational construct (register
  machine, Turing machine, automaton, λ-calculus variant,
  programming-language semantics, etc.), search CSLib first, just
  as we search mathlib for general mathematical concepts.

## Lean language

- [The Lean 4 Theorem Prover and Programming Language (conference paper)](https://link.springer.com/content/pdf/10.1007/978-3-030-79876-5_37.pdf?pdf=inline%20link)
- [Functional Programming in Lean: Structures and Inheritance](https://leanprover.github.io/functional_programming_in_lean/functor-applicative-monad/inheritance.html)
- [Lean Language Reference: Type Classes](https://lean-lang.org/doc/reference/latest/Type-Classes/)
- [Theorem Proving in Lean 4](https://leanprover.github.io/theorem_proving_in_lean4/)
- [Theorem Proving in Lean 4: Type Classes](https://lean-lang.org/theorem_proving_in_lean4/Type-Classes/)
- [Functional Programming in Lean: Type Classes and Polymorphism](https://leanprover.github.io/functional_programming_in_lean/type-classes/polymorphism.html)
- [Tabled Typeclass Resolution](https://arxiv.org/pdf/2001.04301)
- [Use and abuse of instance parameters in the Lean mathematical library](https://arxiv.org/pdf/2202.01629.pdf)
- [Lean projects and build process](https://leanprover-community.github.io/install/project.html)
- [A Beginner's Guide to Theorem Proving in Lean 4](https://emallson.net/blog/a-beginners-companion-to-theorem-proving-in-lean/)

## CSLib

- [Homepage](https://www.cslib.io/) and
  [whitepaper (arXiv:2602.04846)](https://arxiv.org/abs/2602.04846)
- [API docs](https://api.cslib.io/docs/)
- [Repository](https://github.com/leanprover/cslib)
- Top-level directory layout under `Cslib/`:
  - `Algorithms/` — algorithm/data-structure formalizations.
  - `Computability/` — `Automata/`, `Languages/`, `Machines/`,
    `URM/` (Unlimited Register Machine; namespace `Cslib.URM`).
  - `Foundations/` — `Combinatorics/`, `Control/`, `Data/`,
    `Lint/`, `Logic/`, `Semantics/` (including `LTS/` and
    `FLTS/`), `Syntax/`.
  - `Languages/` — `Boole/`, `CCS/`, `CombinatoryLogic/`,
    `LambdaCalculus/`.
  - `Logics/` — `HML/`, `LinearLogic/` (plural directory name).
- Constructive discipline: importing CSLib is fine in the same
  sense that importing mathlib is fine, but the project rule that
  bans `Classical`, `noncomputable`, and `axiom` applies to any
  *transitive* axiom dependency too: a Geb term that depends on a
  CSLib (or mathlib) lemma using `Classical.choice` will surface
  that axiom under `#print axioms`. For results that must remain
  constructive, run `#print axioms` and refactor if a non-pure
  axiom appears.
- Reuse discipline: prefer CSLib typeclasses and abstract
  structures (e.g. `LTS`, `HasFresh`) over reaching into concrete
  instances, so internal CSLib changes do not break our code.

## General mathematics

- [Lean's "mathlib" page](https://leanprover-community.github.io/mathlib-overview.html)

## General category theory

- [Lean's "category theory" page](https://leanprover-community.github.io/theories/category_theory.html)

## Opposite categories

- [Mathlib.CategoryTheory.Opposites](https://leanprover-community.github.io/mathlib4_docs/Mathlib/CategoryTheory/Opposites.html)
- [Mathlib.CategoryTheory.Category.Cat.Op](https://leanprover-community.github.io/mathlib4_docs/Mathlib/CategoryTheory/Category/Cat/Op.html)

## Comma / slice (over) / coslice (under) categories

- [Mathlib.CategoryTheory.Comma.Basic](https://leanprover-community.github.io/mathlib4_docs/Mathlib/CategoryTheory/Comma/Basic.html)
- [PLMlab's `Over.lean`](https://plmlab.math.cnrs.fr/nuccio/mathlib4/-/blob/master/Mathlib/CategoryTheory/Over.lean?ref_type=heads)
- [CategoryTheory.Arrow](https://leanprover-community.github.io/mathlib_docs/category_theory/arrow.html)

## Polynomial functors

- [mathlib4's univariate polynomial functors](https://leanprover-community.github.io/mathlib4_docs/Mathlib/Data/PFunctor/Univariate/Basic.html)
- [mathlib4's multivariate polynomial functors](https://leanprover-community.github.io/mathlib4_docs/Mathlib/Data/PFunctor/Multivariate/Basic.html)
- [mathlib4's W-types](https://leanprover-community.github.io/mathlib4_docs/Mathlib/Data/PFunctor/Multivariate/W.html)
- [mathlib4's M-types](https://leanprover-community.github.io/mathlib4_docs/Mathlib/Data/PFunctor/Multivariate/M.html)
- [mathlib4's univariate QPFs (quotients of polynomial functors)](https://leanprover-community.github.io/mathlib4_docs/Mathlib/Data/QPF/Univariate/Basic.html)
- [mathlib4's multivariate QPFs (quotients of polynomial functors)](https://leanprover-community.github.io/mathlib4_docs/Mathlib/Data/QPF/Multivariate/Basic.html)

## Profunctors

- [Mathlib.CategoryTheory.Limits.Shapes.End (ends and coends)](https://leanprover-community.github.io/mathlib4_docs/Mathlib/CategoryTheory/Limits/Shapes/End.html)

## Parametricity and Free Theorems

- Wadler, *Theorems for free!* (1989)
  - Types read as relations; parametricity proposition: (t,t) in
    the relational interpretation of T. Application to rearrangement,
    fold, sort, filter, map. Connection to lax natural
    transformations noted.
- [Reasonably Polymorphic: Review of Theorems for Free](https://reasonablypolymorphic.com/blog/theorems-for-free/)
  - Relations specialized to functions become bifunctors;
    function relation becomes naturality square f' . g = h . f;
    conjecture: all Haskell laws are category laws in different
    categories.

## Computability

- [Mathlib.Computability.Primrec](https://leanprover-community.github.io/mathlib4_docs/Mathlib/Computability/Primrec.html)
- [Mathlib.Computability.TMComputable](https://leanprover-community.github.io/mathlib4_docs/Mathlib/Computability/TMComputable.html)
- [Mathlib.Computability.TuringMachine](https://leanprover-community.github.io/mathlib4_docs/Mathlib/Computability/TuringMachine.html)

## Monad algebra

- [mathlib4's Monad.Algebra](https://leanprover-community.github.io/mathlib4_docs/Mathlib/CategoryTheory/Monad/Algebra.html)

## Kan extensions

- [mathlib4's KanExtension](https://leanprover-community.github.io/mathlib4_docs/Mathlib/CategoryTheory/Functor/KanExtension/Basic.html)
- [mathlib4's CategoryTheory.Bicategory.KanExtension.Adjunction](https://leanprover-community.github.io/mathlib4_docs/Mathlib/CategoryTheory/Bicategory/Kan/Adjunction.html)

## Grothendieck Construction

- [Mathlib.CategoryTheory.Grothendieck](https://leanprover-community.github.io/mathlib4_docs/Mathlib/CategoryTheory/Grothendieck.html)
  - Provides Lean formalization of the Grothendieck construction for functors
    valued in categories (\(C \to Cat\)), including morphisms and universal
    properties.
- [Mathlib.CategoryTheory.Bicategory.Grothendieck](https://leanprover-community.github.io/mathlib4_docs/Mathlib/CategoryTheory/Bicategory/Grothendieck.html)
  - Bicategorical generalization of the Grothendieck construction.

## Simplicial Sets and Nerves

- [Mathlib.AlgebraicTopology.SimplicialSet.Basic](https://leanprover-community.github.io/mathlib4_docs/Mathlib/AlgebraicTopology/SimplicialSet/Basic.html)
- [Mathlib.AlgebraicTopology.SimplicialSet.Nerve](https://leanprover-community.github.io/mathlib4_docs/Mathlib/AlgebraicTopology/SimplicialSet/Nerve.html)
- [Mathlib.AlgebraicTopology.SimplicialSet.NerveAdjunction](https://leanprover-community.github.io/mathlib4_docs/Mathlib/AlgebraicTopology/SimplicialSet/NerveAdjunction.html)

## Quotients

- [Init.Prelude.Quot](https://leanprover-community.github.io/mathlib4_docs/Init/Prelude.html#Quot)
  - Other operations on `Quot` follow
- [Init.Core.Quot.recOn](https://leanprover-community.github.io/mathlib4_docs/Init/Core.html#Quot.recOn)
  - Other operations on `Quot` precede and follow
- [Init.Core.Quotient](https://leanprover-community.github.io/mathlib4_docs/Init/Core.html#Quotient)
- [Mathlib.Data.Fintype.Quotient](https://leanprover-community.github.io/mathlib4_docs/Mathlib/Data/Fintype/Quotient.html)

## Topos Theory

- [Mathlib.CategoryTheory.Topos.Classifier](https://leanprover-community.github.io/mathlib4_docs/Mathlib/CategoryTheory/Topos/Classifier.html)
- [b-mehta/topos: Topos theory in Lean](https://github.com/b-mehta/topos)
  - Independent repository formalizing foundational aspects of topos theory,
    including subobject classifiers, Lawvere-Tierney topologies, and
    categorical theorems.

## Presheaf/Copresheaf Universal Properties

- [Mathlib.CategoryTheory.Limits.Presheaf](https://leanprover-community.github.io/mathlib4_docs/Mathlib/CategoryTheory/Limits/Presheaf.html)
  - Formalizes limits and colimits within presheaf categories, including the
    colimit-of-representables theorem.
- [Mathlib.CategoryTheory.Comma.Presheaf.Colimit](https://leanprover-community.github.io/mathlib4_docs/Mathlib/CategoryTheory/Comma/Presheaf/Colimit.html)
  - Addresses colimit structures in comma categories related to presheaf
    categories.
- [Mathlib.Topology.Sheaves.Sheaf](https://leanprover-community.github.io/mathlib4_docs/Mathlib/Topology/Sheaves/Sheaf.html)
  - Implementation of sheaf theory, with presheaves and categorical structures
    detailed for topological spaces.
- [Mathlib.Topology.Sheaves.Presheaf](https://leanprover-community.github.io/mathlib4_docs/Mathlib/Topology/Sheaves/Presheaf.html)
  - Documents presheaf categories for sheaf-theoretic constructions.

## Subobject Classifiers and Related

- [Mathlib.CategoryTheory.Topos.Classifier](https://leanprover-community.github.io/mathlib4_docs/Mathlib/CategoryTheory/Topos/Classifier.html)
  - Detailed formalization of subobject classifiers in category theory,
    including construction for presheaf categories.
- [Mathlib.CategoryTheory.Subpresheaf.Subobject](https://leanprover-community.github.io/mathlib4_docs/Mathlib/CategoryTheory/Subpresheaf/Subobject.html)
  - Focuses on subobjects and subpresheaf categories, relevant to classifier
    theory and morphism structure.
- [Mathlib/CategoryTheory/Sites/Closed.lean](https://plmlab.math.cnrs.fr/nuccio/octonions/-/blob/add-vector-api-alt/Mathlib/CategoryTheory/Sites/Closed.lean)
  - Code and theory for closed sites, relevant for power objects and
    classifier constructions.

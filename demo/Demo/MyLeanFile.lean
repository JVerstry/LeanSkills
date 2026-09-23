import LeanDoc.Core

/-!
# My Lean Module

This file is LeanDoc's own demo project (`demo/`) — a small, self-contained
Lean project used to develop and test the extractor against real
declarations and docstrings, rather than against LeanDoc's own source
(which, being the tool itself, is a poor stand-in for "someone else's
Lean project"). It doubles as a worked example: once LeanDoc can render
documentation, this file's docstrings are what that rendered output will
be built from — so they're written as genuine, readable documentation,
not throwaway placeholder text.

`import LeanDoc.Core` here (task T19) is what makes `@[leandoc_ignore]`
available below — the same thing a real adopting project needs once it
`require`s LeanDoc to use the attribute in its own code.
-/

namespace MyLeanModule

/-- Doubles a natural number.

For example, `MyLeanFunction 3 = 6`. This is a deliberately simple
example: LeanDoc should be able to extract its name, its type
(`Nat → Nat`), and this docstring without any special-casing. -/
def MyLeanFunction (n : Nat) : Nat :=
  2 * n

/-- `MyLeanFunction` doubles its input.

A minimal example theorem, proved by `rfl` since doubling is definitional
here. LeanDoc should extract this alongside `MyLeanFunction` even though
one is a `def` and the other a `theorem` — both are declarations with a
name, a type, and (optionally) a docstring. -/
theorem MyLeanTheorem (n : Nat) : MyLeanFunction n = n + n := by
  simp [MyLeanFunction, Nat.two_mul]

/-- A pair of natural numbers, used to demonstrate that LeanDoc also sees
structures and their fields, not just `def`/`theorem`. -/
structure MyLeanStructure where
  /-- The first component. -/
  fst : Nat
  /-- The second component. -/
  snd : Nat

-- Deliberately undocumented, to prove the extractor correctly reports
-- "no docstring" rather than skipping the declaration entirely.
def myLeanUndocumentedFunction (n : Nat) : Nat :=
  n + 1

/-- An internal helper, deliberately excluded from generated
documentation (task T19) — proves `@[leandoc_ignore]` actually removes
a declaration from LeanDoc's output rather than just being parsed and
ignored. -/
@[leandoc_ignore]
def myLeanInternalHelper (n : Nat) : Nat :=
  n - 1

/-- A `Prop`-valued structure. Originally added to exercise task
T41/T42's Prop-projection noise exclusion (`isNoise`) — but empirically
this simple, single-field case elaborates its projection
(`MyLeanProp.trivial`) as a genuine `theorem` directly, not the `def`
Batteries' own comment describes, so that exclusion never actually
fires here. Kept anyway as a real `Prop`-structure example; see
`isNoise`'s doc comment in `LeanDoc/Core.lean` for the honest status of
that check. -/
structure MyLeanProp : Prop where
  /-- Always true. -/
  trivial : True

/-- A tiny typeclass, used to demonstrate task T48's instance listing:
LeanDoc should render the anonymous `Nat` instance below under this
class's own page as a registered instance, not just as an unrelated
`def` elsewhere in the module. -/
class MyLeanDefault (α : Type) where
  /-- The default value for `α`. -/
  myLeanDefaultValue : α

/-- `Nat`'s default is `0`. Proves LeanDoc's extractor actually links
this instance back to `MyLeanDefault` (its `instanceOf`), not just that
`MyLeanDefault` itself gets documented. -/
instance : MyLeanDefault Nat where
  myLeanDefaultValue := 0

end MyLeanModule

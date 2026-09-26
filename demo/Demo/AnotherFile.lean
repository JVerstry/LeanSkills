import Demo.MyLeanFile

/-!
# Another Module

A second module in `demo/`'s own package, importing
`Demo.MyLeanFile`. It exists to exercise two things end-to-end:
LeanDoc documenting a project whose own modules import each other
(task T54 — this exact file failed to elaborate before that fix), and
the "Imported by" line (task T50) that `MyLeanFile`'s page should now
show.
-/

/-- Quadruples a natural number by doubling `MyLeanFunction`'s result
— actually uses the import above, so it can't elaborate unless
`Demo.MyLeanFile` genuinely resolves. -/
def MyLeanModule.MyLeanQuadrupled (n : Nat) : Nat :=
  2 * MyLeanModule.MyLeanFunction n

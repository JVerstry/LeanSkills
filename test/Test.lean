import LeanDoc.Core

/-!
# LeanDoc tests (task T24)

Plain IO-based assert harness, not a proper test framework (Lean has
none built in, and adding an external one felt like more than this
project's size warrants). Three tiers:

- **Unit-level**, on pure functions from `LeanDoc.Core`. Where possible
  these build their *expected* value with the same primitives the code
  under test uses (e.g. `System.FilePath`'s `/` operator) rather than a
  hardcoded path string — a hardcoded `"demo/Demo/MyLeanFile.lean"`
  would itself be exactly T9's bug (assumes `/` is the host separator),
  just relocated into the test instead of fixed.
- **Fixture-level**, exercising real file I/O against `demo/` — the
  same project the extractor/renderer have been manually verified
  against throughout this backlog, now pinned as an automated check
  instead of something re-verified by hand after every change.
- **Project hygiene**: required top-level files (`README.md`,
  `InstallationPrompt.txt`) still exist, and `wip/`/`CLAUDE.md` stay
  untracked by git — not code checks, but
  regressions with no other automated guard.

Several checks below exist specifically because a past bug slipped
through without one: `loadConfig`'s trailing-slash trim (T8),
`groupDeclsByModule`'s grouping (T9), the noise filter's declaration
count (T7), and `renderIndexPage`'s forward-slash-only links (T9's
Windows path-separator bug) all have a named test now.
-/

open Lean

structure TestState where
  passed : Nat := 0
  failed : Nat := 0

def TestState.check (s : TestState) (label : String) (ok : Bool) : IO TestState := do
  if ok then
    pure { s with passed := s.passed + 1 }
  else
    IO.eprintln s!"FAIL: {label}"
    pure { s with failed := s.failed + 1 }

def main : IO Unit := do
  -- Needed for the fixture-level tests, which call `extractFile` for
  -- real — same setup `Main.lean`'s `main` does before `runFrontend`.
  Lean.initSearchPath (← Lean.findSysroot)
  unsafe enableInitializersExecution

  let mut s : TestState := {}

  -- ## Unit-level: path/name conversions

  let demoRoot : System.FilePath := "demo"
  let demoModule : Name := `Demo.MyLeanFile
  s ← s.check "moduleToFile builds the expected path"
    (moduleToFile demoRoot demoModule == demoRoot / "Demo" / "MyLeanFile.lean")
  s ← s.check "fileToModuleName round-trips moduleToFile"
    (fileToModuleName demoRoot (moduleToFile demoRoot demoModule) == demoModule)
  s ← s.check "stringToModuleName parses a dotted string"
    (stringToModuleName "Demo.MyLeanFile" == demoModule)
  s ← s.check "moduleToDocPath builds the expected path"
    (moduleToDocPath "Demo.MyLeanFile" ==
      (("." : System.FilePath) / "Demo" / "MyLeanFile").addExtension "md")

  -- ## Regression: T9's Windows path-separator link bug.
  -- `renderIndexPage` must emit forward-slash links unconditionally,
  -- not via `System.FilePath`'s native-separator stringification.
  let indexPage := renderIndexPage #["Demo.MyLeanFile"] true
  s ← s.check "renderIndexPage never emits a backslash"
    (!(indexPage.any (· == '\\')))
  s ← s.check "renderIndexPage links with forward slashes"
    ((indexPage.splitOn "Demo/MyLeanFile.md").length > 1)

  -- ## Unit-level: T22/T28/T31's Jekyll-targeted output, and the
  -- `jekyll := false` opt-out (task T31).
  s ← s.check "renderIndexPage (jekyll) emits front matter"
    (indexPage.startsWith "---\n---\n")
  s ← s.check "renderIndexPage (jekyll) links via {% link %}, reference/-prefixed"
    ((indexPage.splitOn "{% link reference/Demo/MyLeanFile.md %}").length > 1)
  let plainIndexPage := renderIndexPage #["Demo.MyLeanFile"] false
  s ← s.check "renderIndexPage (no jekyll) has no front matter"
    (!plainIndexPage.startsWith "---\n---\n")
  s ← s.check "renderIndexPage (no jekyll) uses a plain relative link"
    ((plainIndexPage.splitOn "(Demo/MyLeanFile.md)").length > 1)
  s ← s.check "renderIndexPage (no jekyll) emits no Liquid syntax"
    (!plainIndexPage.any (· == '%'))

  -- ## Unit-level: rendering content

  let undocumented : DeclMeta :=
    { module := "M", name := "foo", kind := "def", type := "Nat"
      docString := none, range := none }
  s ← s.check "renderDecl shows a not-documented fallback, not silence"
    ((renderDecl undocumented |>.splitOn "not documented").length > 1)
  let documented := { undocumented with docString := some "does a thing" }
  s ← s.check "renderDecl shows the real docstring"
    ((renderDecl documented |>.splitOn "does a thing").length > 1)

  -- ## Unit-level: grouping

  let metas : Array DeclMeta :=
    #[ { module := "A", name := "a1", kind := "def", type := "Nat", docString := none, range := none }
     , { module := "B", name := "b1", kind := "def", type := "Nat", docString := none, range := none }
     , { module := "A", name := "a2", kind := "def", type := "Nat", docString := none, range := none } ]
  let grouped := groupDeclsByModule metas
  s ← s.check "groupDeclsByModule preserves first-seen module order"
    (grouped.map (·.1) == #["A", "B"])
  s ← s.check "groupDeclsByModule keeps every declaration in its group"
    ((grouped.find? (·.1 == "A")).map (·.2.size) == some 2)

  -- ## Unit-level: kindString (the variants that don't need a real
  -- environment lookup — `.induct` needs `Lean.isStructure`, checked
  -- at fixture level below via the demo project's real structure)

  let emptyEnv ← mkEmptyEnvironment
  s ← s.check "kindString: defn" (kindString emptyEnv `x .defn == "def")
  s ← s.check "kindString: thm" (kindString emptyEnv `x .thm == "theorem")
  s ← s.check "kindString: axiom" (kindString emptyEnv `x .axiom == "axiom")
  s ← s.check "kindString: opaque" (kindString emptyEnv `x .opaque == "opaque")
  s ← s.check "kindString: quot" (kindString emptyEnv `x .quot == "quotient")
  s ← s.check "kindString: ctor" (kindString emptyEnv `x .ctor == "constructor")
  s ← s.check "kindString: recursor" (kindString emptyEnv `x .recursor == "recursor")

  -- ## Fixture-level: leandoc.toml parsing (T8's trailing-slash trim)

  let cfg ← loadConfig (demoRoot / "leandoc.toml")
  s ← s.check "loadConfig trims a trailing slash off json_dir"
    (cfg.jsonDir == (".leandoc" : System.FilePath))
  s ← s.check "loadConfig trims a trailing slash off docs_dir"
    (cfg.docsDir == ("docs" : System.FilePath))

  -- ## Fixture-level: whole-package scanning (T21) against demo/'s
  -- real lakefile.toml

  let discovered ← discoverModules demoRoot
  s ← s.check "discoverModules finds demo/'s one module via lean_lib globs"
    (discovered == #["Demo.MyLeanFile"])

  -- ## Fixture-level: the real extractor against demo/ (T7's
  -- noise-filtering count, pinned instead of re-checked by hand)

  let demoMetas ← extractFile (moduleToFile demoRoot demoModule) demoModule
  s ← s.check "extractFile keeps exactly the 7 real declarations, not the 21 raw ones"
    (demoMetas.size == 7)
  s ← s.check "extractFile finds MyLeanFunction with the right kind and type"
    (demoMetas.any fun d =>
      d.name == "MyLeanModule.MyLeanFunction" && d.kind == "def" && d.type == "Nat → Nat")
  s ← s.check "extractFile finds the undocumented declaration as actually undocumented"
    (demoMetas.any fun d =>
      d.name == "MyLeanModule.myLeanUndocumentedFunction" && d.docString.isNone)

  -- ## Project hygiene: required top-level files exist, and the
  -- working-notes tracker / personal Claude Code config stay out of
  -- git.
  --
  -- These don't test *code*, but a missing/accidentally-deleted
  -- top-level doc, or `wip/`/`CLAUDE.md` silently getting tracked
  -- again, are real regressions with no other automated guard — CI's
  -- output-freshness diff (T11) wouldn't catch either. `AGENTS.md` was
  -- removed from this list (task T32/T33, 2026-09-22): judged not
  -- worth maintaining as a committed, AI-agent-facing doc separate
  -- from `README.md` — its useful content moved to a personal,
  -- gitignored `CLAUDE.md` instead, same treatment as `wip/`.

  for file in #["README.md", "InstallationPrompt.txt", "docs/manual.md"] do
    s ← s.check s!"{file} exists" (← System.FilePath.pathExists file)
  -- `QualityAuditPrompt.txt` intentionally left out until T17 actually
  -- ships (2026-09-22): a draft existed briefly but T17 was explicitly
  -- kept open rather than committed, and a permanently-failing check
  -- here would block every future commit via the pre-commit hook.
  -- Restore this check as part of landing T17 for real, not before.

  let wipTracked ← IO.Process.output { cmd := "git", args := #["ls-files", "wip"] }
  s ← s.check "wip/ has no files tracked by git"
    (wipTracked.exitCode == 0 && wipTracked.stdout.trimAscii.isEmpty)

  let claudeTracked ← IO.Process.output { cmd := "git", args := #["ls-files", "CLAUDE.md"] }
  s ← s.check "CLAUDE.md has no files tracked by git"
    (claudeTracked.exitCode == 0 && claudeTracked.stdout.trimAscii.isEmpty)

  IO.println s!"LeanDoc tests: {s.passed} passed, {s.failed} failed"
  if s.failed > 0 then
    IO.Process.exit 1

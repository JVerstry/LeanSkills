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
  `InstallationPrompt.txt`, `docs/manual.md`, `QualityAuditPrompt.txt`)
  still exist, and `wip/`/`CLAUDE.md` stay untracked by git — not code
  checks, but regressions with no other automated guard.

Several checks below exist specifically because a past bug slipped
through without one: `loadConfig`'s trailing-slash trim (T8),
`groupDeclsByModule`'s grouping (T9), the noise filter's declaration
count (T7), and `renderModulesPage`'s forward-slash-only links (T9's
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
  -- `renderModulesPage` must emit forward-slash links unconditionally,
  -- not via `System.FilePath`'s native-separator stringification.
  let modulesPage := renderModulesPage #["Demo.MyLeanFile"] true
  s ← s.check "renderModulesPage never emits a backslash"
    (!(modulesPage.any (· == '\\')))
  s ← s.check "renderModulesPage links with forward slashes"
    ((modulesPage.splitOn "Demo/MyLeanFile.md").length > 1)

  -- ## Unit-level: T22/T28/T31's Jekyll-targeted output, and the
  -- `jekyll := false` opt-out (task T31).
  s ← s.check "renderModulesPage (jekyll) emits front matter with layout: default"
    (modulesPage.startsWith "---\nlayout: default\n---\n")
  s ← s.check "renderModulesPage (jekyll) links via {% link %}, reference/-prefixed"
    ((modulesPage.splitOn "{% link reference/Demo/MyLeanFile.md %}").length > 1)
  let plainModulesPage := renderModulesPage #["Demo.MyLeanFile"] false
  s ← s.check "renderModulesPage (no jekyll) has no front matter"
    (!plainModulesPage.startsWith "---\n")
  s ← s.check "renderModulesPage (no jekyll) uses a plain relative link"
    ((plainModulesPage.splitOn "(Demo/MyLeanFile.md)").length > 1)
  s ← s.check "renderModulesPage (no jekyll) emits no Liquid syntax"
    (!plainModulesPage.any (· == '%'))

  -- ## Unit-level: T18's table of contents (kindBucket, renderToc)

  s ← s.check "kindBucket: def" (kindBucket "def" == "Definitions")
  s ← s.check "kindBucket: opaque" (kindBucket "opaque" == "Definitions")
  s ← s.check "kindBucket: theorem" (kindBucket "theorem" == "Theorems & Axioms")
  s ← s.check "kindBucket: axiom" (kindBucket "axiom" == "Theorems & Axioms")
  s ← s.check "kindBucket: structure" (kindBucket "structure" == "Structures & Inductives")
  s ← s.check "kindBucket: inductive" (kindBucket "inductive" == "Structures & Inductives")
  s ← s.check "kindBucket: constructor" (kindBucket "constructor" == "Structures & Inductives")
  s ← s.check "kindBucket: quotient falls into Other" (kindBucket "quotient" == "Other")
  s ← s.check "kindBucket: recursor falls into Other" (kindBucket "recursor" == "Other")

  let tocMetas : Array DeclMeta :=
    #[ { module := "M", name := "myDef", kind := "def", type := "Nat", docString := none, range := none }
     , { module := "M", name := "myThm", kind := "theorem", type := "Prop", docString := none, range := none } ]
  let toc := renderToc tocMetas true
  s ← s.check "renderToc includes a heading for a present bucket"
    ((toc.splitOn "## Definitions").length > 1)
  s ← s.check "renderToc includes a heading for another present bucket"
    ((toc.splitOn "## Theorems & Axioms").length > 1)
  s ← s.check "renderToc omits a heading for an empty bucket"
    ((toc.splitOn "## Structures & Inductives").length == 1)
  s ← s.check "renderToc links an entry to its module page"
    ((toc.splitOn "{% link reference/M.md %}").length > 2)

  -- ## Fixture-level: T18's root-index nav management (ensureRootIndex)
  -- Uses a scratch directory under `.leandoc/` (already gitignored) —
  -- not a real project, just a throwaway spot for file I/O checks.

  let scratchDir : System.FilePath := ".leandoc" / "test-scratch"
  IO.FS.createDirAll scratchDir
  let scratchIndex := scratchDir / "index.md"

  -- Case 1: no file yet — creates one with the nav block.
  if ← scratchIndex.pathExists then IO.FS.removeFile scratchIndex
  ensureRootIndex scratchDir true
  let created ← IO.FS.readFile scratchIndex
  s ← s.check "ensureRootIndex creates a missing index.md with the nav block"
    ((created.splitOn navMarkerStart).length > 1 && (created.splitOn navMarkerEnd).length > 1)

  -- Case 2: markers already present — only the region between them changes,
  -- hand-written content outside it survives untouched.
  let handWritten := s!"# My Project\n\nSome intro text.\n\n{navMarkerStart}\nstale content\n{navMarkerEnd}\n\nMore text after.\n"
  IO.FS.writeFile scratchIndex handWritten
  ensureRootIndex scratchDir true
  let updated ← IO.FS.readFile scratchIndex
  s ← s.check "ensureRootIndex preserves hand-written content around the markers"
    ((updated.splitOn "Some intro text.").length > 1 && (updated.splitOn "More text after.").length > 1)
  s ← s.check "ensureRootIndex refreshes stale content between the markers"
    ((updated.splitOn "stale content").length == 1)

  -- Case 3: an existing page with no markers at all — left byte-for-byte
  -- untouched, never silently modified.
  let noMarkers := "# Someone else's landing page\n\nNo markers here.\n"
  IO.FS.writeFile scratchIndex noMarkers
  ensureRootIndex scratchDir true
  let untouched ← IO.FS.readFile scratchIndex
  s ← s.check "ensureRootIndex never touches a page with no markers"
    (untouched == noMarkers)

  IO.FS.removeFile scratchIndex

  -- ## Fixture-level: T29's vendored stylesheet/layout assets
  -- (ensureStyleAsset, ensureDefaultLayout) — same scratch directory,
  -- same write-once guarantee as ensureJekyllConfig/ensureRootIndex.

  let scratchStyle := scratchDir / "assets" / "style.css"
  let scratchLayout := scratchDir / "_layouts" / "default.html"
  if ← scratchStyle.pathExists then IO.FS.removeFile scratchStyle
  if ← scratchLayout.pathExists then IO.FS.removeFile scratchLayout

  ensureStyleAsset scratchDir
  ensureDefaultLayout scratchDir
  let styleContent ← IO.FS.readFile scratchStyle
  let layoutContent ← IO.FS.readFile scratchLayout
  s ← s.check "ensureStyleAsset writes the vendored doc-gen4 stylesheet"
    (styleContent == LeanDoc.Assets.styleCss)
  s ← s.check "ensureDefaultLayout writes LeanDoc's own layout"
    (layoutContent == LeanDoc.Assets.defaultLayoutHtml)
  s ← s.check "the vendored stylesheet mentions its doc-gen4 origin"
    ((styleContent.splitOn "doc-gen4").length > 1)
  s ← s.check "the default layout links assets/style.css"
    ((layoutContent.splitOn "/assets/style.css").length > 1)

  -- Write-once: a customized file must survive a second `render` run.
  let customStyle := "/* my custom override */\n"
  IO.FS.writeFile scratchStyle customStyle
  ensureStyleAsset scratchDir
  let styleAfterCustomization ← IO.FS.readFile scratchStyle
  s ← s.check "ensureStyleAsset never overwrites a customized stylesheet"
    (styleAfterCustomization == customStyle)

  IO.FS.removeFile scratchStyle
  IO.FS.removeFile scratchLayout

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
  s ← s.check "loadConfig defaults compliance checking to off"
    (!cfg.complianceEnabled && cfg.complianceAuthor.isEmpty && cfg.complianceLicense.isEmpty)

  -- ## Unit-level: T41's copyright/license header check

  let realHeader := "/- Copyright (c) 2026 Jane Doe. Released under Apache 2.0. Authors: Jane Doe -/\nimport Lean\n"
  s ← s.check "hasCopyrightHeader passes a real header (author + license both configured)"
    (hasCopyrightHeader realHeader "Jane Doe" "Apache 2.0")
  s ← s.check "hasCopyrightHeader fails when the author doesn't match"
    (!hasCopyrightHeader realHeader "John Smith" "Apache 2.0")
  s ← s.check "hasCopyrightHeader fails when the license doesn't match"
    (!hasCopyrightHeader realHeader "Jane Doe" "MIT")
  s ← s.check "hasCopyrightHeader fails when there's no Copyright at all"
    (!hasCopyrightHeader "import Lean\n\ndef foo := 1\n" "Jane Doe" "Apache 2.0")
  s ← s.check "hasCopyrightHeader passes with nothing configured to check, as long as Copyright appears"
    (hasCopyrightHeader realHeader "" "")
  s ← s.check "hasCopyrightHeader still requires Copyright even with nothing else configured"
    (!hasCopyrightHeader "import Lean\n" "" "")

  -- ## Fixture-level: T41's [compliance] leandoc.toml section, and
  -- checkComplianceHeader as a smoke test (its warning goes to stderr,
  -- not something this harness captures — the real logic is already
  -- covered above via hasCopyrightHeader directly).

  let complianceTomlPath := scratchDir / "leandoc.toml"
  IO.FS.writeFile complianceTomlPath
    "[compliance]\nenabled = true\nauthor = \"Jane Doe\"\nlicense = \"Apache 2.0\"\n"
  let complianceCfg ← loadConfig complianceTomlPath
  s ← s.check "loadConfig parses [compliance] enabled"
    complianceCfg.complianceEnabled
  s ← s.check "loadConfig parses [compliance] author"
    (complianceCfg.complianceAuthor == "Jane Doe")
  s ← s.check "loadConfig parses [compliance] license"
    (complianceCfg.complianceLicense == "Apache 2.0")
  IO.FS.removeFile complianceTomlPath

  checkComplianceHeader complianceCfg (demoRoot / "Demo" / "MyLeanFile.lean")
  checkComplianceHeader (cfg : LeanDocConfig) (demoRoot / "Demo" / "MyLeanFile.lean")
  s ← s.check "checkComplianceHeader runs without crashing, enabled or not" true

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

  for file in #["README.md", "InstallationPrompt.txt", "docs/manual.md",
                "QualityAuditPrompt.txt"] do
    s ← s.check s!"{file} exists" (← System.FilePath.pathExists file)

  let wipTracked ← IO.Process.output { cmd := "git", args := #["ls-files", "wip"] }
  s ← s.check "wip/ has no files tracked by git"
    (wipTracked.exitCode == 0 && wipTracked.stdout.trimAscii.isEmpty)

  let claudeTracked ← IO.Process.output { cmd := "git", args := #["ls-files", "CLAUDE.md"] }
  s ← s.check "CLAUDE.md has no files tracked by git"
    (claudeTracked.exitCode == 0 && claudeTracked.stdout.trimAscii.isEmpty)

  IO.println s!"LeanDoc tests: {s.passed} passed, {s.failed} failed"
  if s.failed > 0 then
    IO.Process.exit 1

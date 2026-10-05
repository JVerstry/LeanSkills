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

Each group of checks is its own function taking and returning the
`TestState`, and `main` runs them in order. Keep it that way: one long
`do` block nests one level per statement and, at ~140 checks, exceeded
Lean's default recursion limit. The few values several groups share
(the `demo/` project, its build result and search path, a scratch
directory) travel in `Ctx`.

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

/-- Values shared by several test sections: the `demo/` fixture project, the
result of building it and its search path (set up once in `main`), and a
scratch directory for throwaway file I/O. -/
structure Ctx where
  demoRoot : System.FilePath
  demoModule : Name
  demoBuilt : Bool
  demoSearchPath : System.SearchPath
  scratchDir : System.FilePath

def pathChecks (c : Ctx) (s0 : TestState) : IO TestState := do
  let mut s := s0
  let demoRoot := c.demoRoot
  let demoModule := c.demoModule

  -- ## Unit-level: path/name conversions

  s ← s.check "moduleToFile builds the expected path"
    (moduleToFile demoRoot demoModule == demoRoot / "Demo" / "MyLeanFile.lean")
  s ← s.check "fileToModuleName round-trips moduleToFile"
    (fileToModuleName demoRoot (moduleToFile demoRoot demoModule) == demoModule)
  s ← s.check "stringToModuleName parses a dotted string"
    (stringToModuleName "Demo.MyLeanFile" == demoModule)
  s ← s.check "moduleToDocPath builds the expected path"
    (moduleToDocPath "Demo.MyLeanFile" ==
      (("." : System.FilePath) / "Demo" / "MyLeanFile").addExtension "md")

  pure s

def modulesPageChecks (s0 : TestState) : IO TestState := do
  let mut s := s0

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

  pure s

def moduleTreeChecks (s0 : TestState) : IO TestState := do
  let mut s := s0

  -- ## Unit-level: T49's nested module tree

  let multiModuleTree := buildModuleTree #["Foo.Bar", "Foo.Baz", "Quux"]
  s ← s.check "buildModuleTree groups Foo.Bar and Foo.Baz under a shared Foo namespace node"
    (match multiModuleTree with
      | .node children _ => children.any fun (seg, child) =>
          seg == "Foo" && match child with
            | .node grandchildren _ => grandchildren.size == 2
      )
  s ← s.check "buildModuleTree keeps a top-level module (Quux) as its own leaf"
    (match multiModuleTree with
      | .node children _ => children.any fun (seg, child) =>
          seg == "Quux" && match child with
            | .node _ full => full == some "Quux"
      )
  let treeHtml := renderModuleTree #["Foo.Bar", "Foo.Baz", "Quux"] true
  s ← s.check "renderModuleTree nests Foo's children under one collapsible Foo entry"
    ((treeHtml.splitOn "<summary>Foo</summary>").length == 2)
  s ← s.check "renderModuleTree links each leaf module via {% link %}"
    ((treeHtml.splitOn "{% link reference/Foo/Bar.md %}").length > 1 &&
     (treeHtml.splitOn "{% link reference/Foo/Baz.md %}").length > 1 &&
     (treeHtml.splitOn "{% link reference/Quux.md %}").length > 1)
  s ← s.check "renderModuleTree never emits a backslash"
    (!(treeHtml.any (· == '\\')))
  -- The tree is raw block HTML, which kramdown (GitHub Pages) leaves
  -- unparsed: a Markdown link inside it would render as literal text, so
  -- every link must be a real <a> element.
  s ← s.check "renderModuleTree links with <a> elements, not Markdown links"
    ((treeHtml.splitOn "](").length == 1 &&
     (treeHtml.splitOn "<a href=\"{% link reference/Foo/Bar.md %}\">Bar</a>").length > 1)

  pure s

def tocChecks (s0 : TestState) : IO TestState := do
  let mut s := s0

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

  pure s

def rootIndexChecks (c : Ctx) (s0 : TestState) : IO TestState := do
  let mut s := s0
  let scratchDir := c.scratchDir

  -- ## Fixture-level: T18's root-index nav management (ensureRootIndex)
  -- Uses a scratch directory under `.leandoc/` (already gitignored) —
  -- not a real project, just a throwaway spot for file I/O checks.

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

  pure s

def assetChecks (c : Ctx) (s0 : TestState) : IO TestState := do
  let mut s := s0
  let scratchDir := c.scratchDir

  -- ## Fixture-level: T29's vendored stylesheet/layout assets
  -- (ensureStyleAsset, ensureDefaultLayout) — same scratch directory,
  -- same write-once guarantee as ensureJekyllConfig/ensureRootIndex.

  let scratchStyle := scratchDir / "assets" / "style.css"
  let scratchLayout := scratchDir / "_layouts" / "default.html"
  let scratchColorScheme := scratchDir / "assets" / "color-scheme.js"
  let scratchSearchJs := scratchDir / "assets" / "search.js"
  let scratchMathjaxConfig := scratchDir / "assets" / "mathjax-config.js"
  let scratchFindPage := scratchDir / "find.html"
  let scratchNotFoundPage := scratchDir / "404.html"
  if ← scratchStyle.pathExists then IO.FS.removeFile scratchStyle
  if ← scratchLayout.pathExists then IO.FS.removeFile scratchLayout
  if ← scratchColorScheme.pathExists then IO.FS.removeFile scratchColorScheme
  if ← scratchSearchJs.pathExists then IO.FS.removeFile scratchSearchJs
  if ← scratchMathjaxConfig.pathExists then IO.FS.removeFile scratchMathjaxConfig
  if ← scratchFindPage.pathExists then IO.FS.removeFile scratchFindPage
  if ← scratchNotFoundPage.pathExists then IO.FS.removeFile scratchNotFoundPage

  ensureStyleAsset scratchDir
  ensureDefaultLayout scratchDir
  ensureColorSchemeScript scratchDir
  ensureSearchScript scratchDir
  ensureMathjaxConfig scratchDir
  ensureFindPage scratchDir
  ensureNotFoundPage scratchDir
  let styleContent ← IO.FS.readFile scratchStyle
  let layoutContent ← IO.FS.readFile scratchLayout
  let colorSchemeContent ← IO.FS.readFile scratchColorScheme
  let searchJsContent ← IO.FS.readFile scratchSearchJs
  let mathjaxConfigContent ← IO.FS.readFile scratchMathjaxConfig
  let findPageContent ← IO.FS.readFile scratchFindPage
  let notFoundPageContent ← IO.FS.readFile scratchNotFoundPage
  s ← s.check "ensureStyleAsset writes the vendored doc-gen4 stylesheet"
    (styleContent == LeanDoc.Assets.styleCss)
  s ← s.check "ensureDefaultLayout writes LeanDoc's own layout"
    (layoutContent == LeanDoc.Assets.defaultLayoutHtml)
  s ← s.check "ensureColorSchemeScript writes the theme-switcher script"
    (colorSchemeContent == LeanDoc.Assets.colorSchemeJs)
  s ← s.check "ensureSearchScript writes the search script"
    (searchJsContent == LeanDoc.Assets.searchJs)
  s ← s.check "ensureMathjaxConfig writes the MathJax config"
    (mathjaxConfigContent == LeanDoc.Assets.mathjaxConfigJs)
  s ← s.check "the vendored stylesheet mentions its doc-gen4 origin"
    ((styleContent.splitOn "doc-gen4").length > 1)
  s ← s.check "the default layout links assets/style.css"
    ((layoutContent.splitOn "/assets/style.css").length > 1)
  s ← s.check "the default layout links assets/color-scheme.js"
    ((layoutContent.splitOn "/assets/color-scheme.js").length > 1)
  s ← s.check "the default layout links assets/search.js"
    ((layoutContent.splitOn "/assets/search.js").length > 1)
  s ← s.check "the default layout links assets/mathjax-config.js and MathJax's CDN script"
    ((layoutContent.splitOn "/assets/mathjax-config.js").length > 1 &&
     (layoutContent.splitOn "cdn.jsdelivr.net/npm/mathjax").length > 1)
  s ← s.check "the default layout includes the color-theme-switcher form"
    ((layoutContent.splitOn "color-theme-switcher").length > 1)
  s ← s.check "the default layout includes the search box markup"
    ((layoutContent.splitOn "search-input").length > 1 &&
     (layoutContent.splitOn "search-results").length > 1)
  s ← s.check "color-scheme.js targets the #color-theme-switcher/#settings markup"
    ((colorSchemeContent.splitOn "color-theme-switcher").length > 1 &&
     (colorSchemeContent.splitOn "#settings").length > 1)
  s ← s.check "search.js targets the #search-input/#search-results markup"
    ((searchJsContent.splitOn "search-input").length > 1 &&
     (searchJsContent.splitOn "search-results").length > 1)
  s ← s.check "mathjax-config.js configures $...$ and $$...$$ delimiters"
    ((mathjaxConfigContent.splitOn "inlineMath").length > 1 &&
     (mathjaxConfigContent.splitOn "displayMath").length > 1)
  s ← s.check "ensureFindPage writes the /find.html redirect page"
    (findPageContent == LeanDoc.Assets.findHtml)
  s ← s.check "find.html reads a ?pattern= query parameter and fetches the search index"
    ((findPageContent.splitOn "pattern").length > 1 &&
     (findPageContent.splitOn "assets/search-index.json").length > 1)
  s ← s.check "ensureNotFoundPage writes the 404 page"
    (notFoundPageContent == LeanDoc.Assets.notFoundHtml)
  s ← s.check "404.html fetches the search index and resolves site.baseurl"
    ((notFoundPageContent.splitOn "assets/search-index.json").length > 1 &&
     (notFoundPageContent.splitOn "site.baseurl").length > 1)

  -- Write-once: a customized file must survive a second `render` run.
  let customStyle := "/* my custom override */\n"
  IO.FS.writeFile scratchStyle customStyle
  ensureStyleAsset scratchDir
  let styleAfterCustomization ← IO.FS.readFile scratchStyle
  s ← s.check "ensureStyleAsset never overwrites a customized stylesheet"
    (styleAfterCustomization == customStyle)

  IO.FS.removeFile scratchStyle
  IO.FS.removeFile scratchLayout
  IO.FS.removeFile scratchColorScheme
  IO.FS.removeFile scratchSearchJs
  IO.FS.removeFile scratchMathjaxConfig
  IO.FS.removeFile scratchFindPage
  IO.FS.removeFile scratchNotFoundPage

  pure s

def qualityHookChecks (c : Ctx) (s0 : TestState) : IO TestState := do
  let mut s := s0

  -- ## T43's opt-in quality check: scripts/quality-check.sh. Structure
  -- first (always runs), then behaviour (needs an `sh`).

  let scriptPath := "scripts/quality-check.sh"
  s ← s.check "scripts/quality-check.sh exists" (← System.FilePath.pathExists scriptPath)
  let script ← IO.FS.readFile scriptPath
  s ← s.check "quality-check.sh is a POSIX sh script" (script.startsWith "#!/bin/sh")
  s ← s.check "quality-check.sh takes --message-file, --message and --docs-dir"
    ((script.splitOn "--message-file").length > 1 && (script.splitOn "--message)").length > 1 &&
     (script.splitOn "--docs-dir").length > 1)
  let install ← IO.FS.readFile "InstallationPrompt.txt"
  s ← s.check "InstallationPrompt.txt documents the commit-msg hook, the script and the WIP marker"
    ((install.splitOn "quality-check.sh").length > 1 && (install.splitOn "commit-msg").length > 1 &&
     (install.splitOn "WIP").length > 1)

  let hasSh ← try
      let r ← IO.Process.output { cmd := "sh", args := #["-c", "true"] }
      pure (r.exitCode == 0)
    catch _ => pure false
  unless hasSh do
    IO.println "LeanDoc tests: note: no `sh` on PATH, skipping the quality-check.sh behaviour checks"
    return s

  -- Forward slashes throughout: `sh` treats a backslash as an escape.
  let rootStr := (c.scratchDir.toString.replace "\\" "/") ++ "/quality"
  let docsStr := rootStr ++ "/docs"
  let root : System.FilePath := rootStr
  let docs : System.FilePath := docsStr
  if ← root.pathExists then IO.FS.removeDirAll root
  IO.FS.createDirAll (docs / "_layouts")
  IO.FS.createDirAll (docs / "reference")
  let layoutFile := docs / "_layouts" / "default.html"
  IO.FS.writeFile layoutFile LeanDoc.Assets.defaultLayoutHtml
  IO.FS.writeFile (docs / "toc.md") "# Toc\n"
  IO.FS.writeFile (docs / "reference" / "A.md") "# A\n\n[toc]({% link toc.md %})\n"
  let run (extra : Array String) : IO (UInt32 × String × String) := do
    let r ← IO.Process.output
      { cmd := "sh", args := #[scriptPath, "--docs-dir", docsStr] ++ extra }
    pure (r.exitCode, r.stdout, r.stderr)
  let has (hay needle : String) : Bool := (hay.splitOn needle).length > 1

  let (code, out, _) ← run #[]
  s ← s.check "quality-check: clean docs have no findings and exit 0" (code == 0 && has out "no findings")

  -- A missing link target (the one that fails a whole Jekyll build).
  let broken := docs / "reference" / "B.md"
  IO.FS.writeFile broken "# B\n\n[x]({% link reference/Nope.md %})\n"
  let (code, _, err) ← run #[]
  s ← s.check "quality-check: a missing link target fails (strict)" (code == 1 && has err "link target missing")
  -- ...and the WIP override downgrades it, findings still printed.
  for marker in ["WIP", "WIP: half done", "[WIP] half done", "wip add search"] do
    let (code, _, err) ← run #["--message", marker]
    s ← s.check s!"quality-check: the message '{marker}' downgrades findings to warnings"
      (code == 0 && has err "warning: link target missing" && has err "warnings only")
  for notMarker in ["Wipe the cache", "Implement T43", "WIPE"] do
    let (code, _, _) ← run #["--message", notMarker]
    s ← s.check s!"quality-check: the message '{notMarker}' is not a WIP marker" (code == 1)
  IO.FS.writeFile (root / "msg.txt") "Fix things\n\nWIP in the body only\n"
  let (code, _, _) ← run #["--message-file", rootStr ++ "/msg.txt"]
  s ← s.check "quality-check: a WIP marker counts only on the first line of the message file" (code == 1)
  IO.FS.writeFile (root / "msg.txt") "WIP: stuff\n\nlonger body\n"
  let (code, _, _) ← run #["--message-file", rootStr ++ "/msg.txt"]
  s ← s.check "quality-check: --message-file reads a WIP first line" (code == 0)

  -- An example inside {% raw %} is shown literally, not run by Jekyll.
  IO.FS.writeFile broken "# B\n\n{% raw %}[x]({% link reference/Example.md %}){% endraw %}\n"
  let (code, _, _) ← run #[]
  s ← s.check "quality-check: a link tag inside raw is not checked" (code == 0)
  IO.FS.removeFile broken

  -- An outdated layout, and scaffolding that leaked into the reference.
  IO.FS.writeFile layoutFile "<html></html>"
  let (code, _, err) ← run #[]
  s ← s.check "quality-check: an outdated layout fails" (code == 1 && has err "outdated layout")
  IO.FS.writeFile layoutFile LeanDoc.Assets.defaultLayoutHtml
  let leaky := docs / "reference" / "C.md"
  IO.FS.writeFile leaky "# C\n\n### `Foo.casesOn`\n"
  let (code, _, err) ← run #[]
  s ← s.check "quality-check: leaked scaffolding fails" (code == 1 && has err "scaffolding leaked")
  IO.FS.removeFile leaky

  let r ← IO.Process.output { cmd := "sh", args := #[scriptPath, "--docs-dir", rootStr ++ "/nothing-here"] }
  s ← s.check "quality-check: a docs directory that doesn't exist is an error (exit 2)" (r.exitCode == 2)
  IO.FS.removeDirAll root
  pure s

def namingChecks (c : Ctx) (s0 : TestState) : IO TestState := do
  let mut s := s0
  let scratchDir := c.scratchDir

  -- ## Unit-level: T41's naming-convention check (namingProblem). The
  -- accepted names are real Mathlib/core ones, to keep the heuristic
  -- honest about false positives.

  for (role, name) in [("proof", "Nat.add_comm"), ("proof", "map_natCast"), ("proof", "isOpen_iff"),
                       ("proof", "Nat.succ_le_of_lt'"), ("proof", "rfl"), ("proof", "IsOpen.union"),
                       ("type", "Nat"), ("type", "MonoidHom"), ("type", "LE"), ("type", "Foo.Bar"),
                       ("predicate", "IsOpen"), ("predicate", "le"), ("predicate", "Nat.Prime"),
                       ("data", "List.foldl"), ("data", "toList"), ("data", "String.toNat?"),
                       ("data", "mk"), ("data", "Array.mkEmpty"), ("data", "toLE")] do
    s ← s.check s!"namingProblem accepts {name} as a {role}" (namingProblem role name).isNone
  for (role, name) in [("proof", "Foo.MyTheorem"), ("proof", "add_Comm"), ("proof", "AddComm"),
                       ("type", "myStruct"), ("type", "My_Type"),
                       ("predicate", "is_open"),
                       ("data", "MyFunction"), ("data", "to_list"), ("data", "Foo.Bar.Baz")] do
    s ← s.check s!"namingProblem flags {name} as a {role}" (namingProblem role name).isSome
  s ← s.check "namingProblem judges only the last component (the namespace is someone else's name)"
    ((namingProblem "proof" "My_Namespace.add_comm").isNone &&
     (namingProblem "data" "MyNamespace.toList").isNone)
  s ← s.check "namingProblem skips a name starting with an underscore, or quoted"
    ((namingProblem "data" "_Private").isNone && (namingProblem "data" "«My Name»").isNone)
  s ← s.check "namingProblem ignores an unknown role" (namingProblem "other" "Whatever_x").isNone

  -- ## namingViolations skips instances and declarations with no role

  let base : DeclMeta :=
    { module := "M", name := "Bad_Name", kind := "def", type := "Nat", docString := none, range := none }
  s ← s.check "namingViolations flags a real violation"
    ((namingViolations #[{ base with namingRole := some "data" }]).size == 1)
  s ← s.check "namingViolations skips an instance (its name is generated)"
    ((namingViolations #[{ base with namingRole := some "data", instanceOf := some "Inhabited" }]).isEmpty)
  s ← s.check "namingViolations skips a declaration with no role (older metadata)"
    ((namingViolations #[base]).isEmpty)

  -- ## Fixture-level: the opt-in switch

  s ← s.check "the naming check is off by default" (!(({} : LeanDocConfig).complianceNaming))
  let tomlPath := scratchDir / "naming.toml"
  IO.FS.writeFile tomlPath "[compliance]\nnaming = true\n"
  let namingCfg ← loadConfig tomlPath
  s ← s.check "loadConfig parses [compliance] naming" namingCfg.complianceNaming
  s ← s.check "[compliance] naming is independent of the header check" (!namingCfg.complianceEnabled)
  IO.FS.removeFile tomlPath
  -- Smoke: warns on stderr, never fails, and is silent when off.
  checkNamingConventions namingCfg #[{ base with namingRole := some "data" }]
  checkNamingConventions {} #[{ base with namingRole := some "data" }]
  s ← s.check "checkNamingConventions runs without crashing, on or off" true
  pure s

def layoutVersionChecks (s0 : TestState) : IO TestState := do
  let mut s := s0
  let shipped := LeanDoc.Assets.defaultLayoutHtml

  -- ## Unit-level: T61's layout version stamp

  s ← s.check "layoutStampOf reads the stamp" (layoutStampOf "<!-- leandoc-layout-version: 7\n -->" == some 7)
  s ← s.check "layoutStampOf is none without a stamp" (layoutStampOf "<html></html>" == none)
  s ← s.check "the shipped layout carries a stamp" (layoutStampOf shipped).isSome

  -- If this fails, assets/layouts/default.html changed: bump its
  -- `leandoc-layout-version` stamp (and regenerate Assets.lean), then update
  -- both pinned numbers below. LeanDoc never overwrites a project's layout,
  -- so the stamp is the only way an older copy gets noticed.
  let pinnedStamp : Nat := 1
  let pinnedHash : UInt64 := 9217214827997882634
  let actualHash := hash shipped
  s ← s.check "the layout template and its version stamp changed together"
    ((layoutStampOf shipped) == some pinnedStamp && actualHash == pinnedHash)
  unless (layoutStampOf shipped) == some pinnedStamp && actualHash == pinnedHash do
    IO.eprintln s!"  layout stamp = {layoutStampOf shipped}, template hash = {actualHash}"

  -- ## Unit-level: T61's warning

  s ← s.check "layoutWarning is silent for the layout LeanDoc ships" (layoutWarning "p" shipped shipped).isNone
  s ← s.check "layoutWarning is silent for a newer layout"
    (layoutWarning "p" "<!-- leandoc-layout-version: 99 -->" shipped).isNone
  let oldLayout := "<html><link href=\"/assets/style.css\"></html>"
  s ← s.check "layoutWarning warns about a layout with no stamp"
    (match layoutWarning "docs/_layouts/default.html" oldLayout shipped with
      | some m => (m.splitOn "older").length > 1 && (m.splitOn "no version stamp").length > 1 &&
          (m.splitOn "docs/_layouts/default.html").length > 1
      | none => false)
  s ← s.check "layoutWarning names the features an old layout lacks"
    (match layoutWarning "p" oldLayout shipped with
      | some m => (m.splitOn "the search box").length > 1 && (m.splitOn "LaTeX rendering").length > 1 &&
          (m.splitOn "theme switcher").length > 1
      | none => false)
  s ← s.check "layoutWarning only names what is actually missing"
    (match layoutWarning "p" "<!-- leandoc-layout-version: 0 -->/assets/search.js" shipped with
      | some m => (m.splitOn "version 0").length > 1 && (m.splitOn "the search box").length == 1 &&
          (m.splitOn "LaTeX rendering").length > 1
      | none => false)
  s ← s.check "layoutWarning points at the manual and the template"
    (match layoutWarning "p" oldLayout shipped with
      | some m => (m.splitOn "Upgrading").length > 1 && (m.splitOn "assets/layouts/default.html").length > 1
      | none => false)

  -- ## Fixture-level: checkLayoutVersion never fails and never overwrites

  let dir : System.FilePath := ".leandoc" / "test-scratch" / "layout-version"
  if ← dir.pathExists then IO.FS.removeDirAll dir
  IO.FS.createDirAll (dir / "_layouts")
  IO.FS.writeFile (dir / "_layouts" / "default.html") oldLayout
  checkLayoutVersion dir
  s ← s.check "checkLayoutVersion leaves an outdated layout untouched"
    ((← IO.FS.readFile (dir / "_layouts" / "default.html")) == oldLayout)
  IO.FS.removeDirAll dir
  pure s

def searchIndexChecks (s0 : TestState) : IO TestState := do
  let mut s := s0

  -- ## Unit-level: renderSearchIndex (task T47)

  let searchMetas : Array DeclMeta :=
    #[ { module := "Demo.MyLeanFile", name := "Demo.foo", kind := "def"
         type := "Nat", docString := some "docs", range := none }
     , { module := "Demo.MyLeanFile", name := "Demo.Bar", kind := "structure"
         type := "Type", docString := none, range := none } ]
  let searchIndexJson := renderSearchIndex searchMetas
  let searchIndexParsed := (Json.parse searchIndexJson).toOption
  s ← s.check "renderSearchIndex produces valid JSON" searchIndexParsed.isSome
  let parsedResult : Except String (Array SearchEntry) :=
    fromJson? (searchIndexParsed.getD (Json.arr #[]))
  s ← s.check "renderSearchIndex output matches the SearchEntry schema" parsedResult.toOption.isSome
  let parsedEntries := parsedResult.toOption.getD #[]
  s ← s.check "renderSearchIndex emits one entry per declaration"
    (parsedEntries.size == 2)
  s ← s.check "renderSearchIndex entries carry name/kind/module"
    (parsedEntries.any fun e => e.name == "Demo.foo" && e.kind == "def" && e.module == "Demo.MyLeanFile")
  s ← s.check "renderSearchIndex builds a reference/<path>.html link"
    (parsedEntries.any fun e => e.name == "Demo.foo" && e.link == "reference/Demo/MyLeanFile.html")

  pure s

def declRenderChecks (s0 : TestState) : IO TestState := do
  let mut s := s0

  -- ## Unit-level: rendering content

  let undocumented : DeclMeta :=
    { module := "M", name := "foo", kind := "def", type := "Nat"
      docString := none, range := none }
  let noInstances : Std.HashMap String (Array DeclMeta) := {}
  s ← s.check "renderDecl shows a not-documented fallback, not silence"
    ((renderDecl undocumented none noInstances |>.splitOn "not documented").length > 1)
  let documented := { undocumented with docString := some "does a thing" }
  s ← s.check "renderDecl shows the real docstring"
    ((renderDecl documented none noInstances |>.splitOn "does a thing").length > 1)

  -- ## Unit-level: T46's jump-to-source links

  let withRange : DeclMeta :=
    { module := "Foo.Bar", name := "baz", kind := "def", type := "Nat"
      docString := none
      range := some { startLine := 3, startColumn := 0, endLine := 5, endColumn := 1 } }
  let sourceUrl := "https://github.com/owner/repo/blob/abc123"
  s ← s.check "renderDecl links to source when both a base URL and a range are available"
    ((renderDecl withRange (some sourceUrl) noInstances
      |>.splitOn "https://github.com/owner/repo/blob/abc123/Foo/Bar.lean#L3-L5").length > 1)
  s ← s.check "renderDecl omits the source link when there's no base URL"
    ((renderDecl withRange none noInstances |>.splitOn "[source]").length == 1)
  s ← s.check "renderDecl omits the source link when there's no range, even with a base URL"
    ((renderDecl undocumented (some sourceUrl) noInstances |>.splitOn "[source]").length == 1)

  pure s

def liquidChecks (s0 : TestState) : IO TestState := do
  let mut s := s0

  -- ## Unit-level: T56's Liquid escaping of Lean-sourced text

  s ← s.check "escapeLiquid turns {{ and {% into literal-printing output expressions"
    (escapeLiquid "a {{ x }} b {% link %} c" ==
      "a {{ \"{{\" }} x }} b {{ \"{%\" }} link %} c")
  s ← s.check "escapeLiquid leaves text without Liquid delimiters unchanged"
    (escapeLiquid "Nat → Nat { x // x > 0 }" == "Nat → Nat { x // x > 0 }")
  let liquidDecl : DeclMeta :=
    { module := "M", name := "foo", kind := "def", type := "Nat"
      docString := some "Emits `{% link %}` and `{{ site.baseurl }}`.", range := none }
  let liquidPage := renderModulePage "M" #[liquidDecl] true none {} {}
  s ← s.check "renderModulePage (jekyll) escapes Liquid in a docstring"
    ((liquidPage.splitOn "{% link %}").length == 1 &&
     (liquidPage.splitOn "{{ site.baseurl }}").length == 1 &&
     (liquidPage.splitOn "{{ \"{%\" }} link %}").length > 1)
  let plainLiquidPage := renderModulePage "M" #[liquidDecl] false none {} {}
  s ← s.check "renderModulePage (no jekyll) leaves a docstring's Liquid-like text alone"
    ((plainLiquidPage.splitOn "Emits `{% link %}` and `{{ site.baseurl }}`.").length > 1)
  s ← s.check "renderToc (jekyll) escapes Liquid in a declaration name"
    ((renderToc #[{ liquidDecl with name := "«{{x}}»" }] true |>.splitOn "«{{x}}»").length == 1)

  pure s

def instanceListingChecks (s0 : TestState) : IO TestState := do
  let mut s := s0

  -- ## Unit-level: T48's typeclass instance listings

  let classDecl : DeclMeta :=
    { module := "M", name := "Inhabited", kind := "structure", type := "Type -> Type"
      docString := none, range := none }
  let instanceDecl : DeclMeta :=
    { module := "M", name := "instFooInhabited", kind := "def", type := "Inhabited Foo"
      docString := none, range := none, instanceOf := some "Inhabited" }
  let instancesByClass := groupInstancesByClass #[classDecl, instanceDecl]
  s ← s.check "groupInstancesByClass groups an instance under its class"
    ((instancesByClass.getD "Inhabited" #[]).any (·.name == "instFooInhabited"))
  s ← s.check "renderDecl on a class lists its registered instances"
    ((renderDecl classDecl none instancesByClass |>.splitOn "instFooInhabited").length > 1)
  s ← s.check "renderDecl on a declaration with no instances shows no Instances section"
    ((renderDecl instanceDecl none instancesByClass |>.splitOn "**Instances:**").length == 1)

  pure s

def importedByChecks (c : Ctx) (s0 : TestState) : IO TestState := do
  let mut s := s0
  let demoRoot := c.demoRoot
  let demoModule := c.demoModule

  -- ## Unit-level: T50's "imported by"

  let moduleImportsFixture : Std.HashMap String (Array String) :=
    Std.HashMap.ofList
      [ ("Demo.AnotherFile", #["Demo.MyLeanFile"])
      , ("Demo.MyLeanFile", #[]) ]
  let importedByMap := buildImportedByMap moduleImportsFixture
  s ← s.check "buildImportedByMap records the importer under the imported module"
    ((importedByMap.getD "Demo.MyLeanFile" #[]) == #["Demo.AnotherFile"])
  s ← s.check "buildImportedByMap has no entry for a module nothing imports"
    ((importedByMap.getD "Demo.AnotherFile" #[]).isEmpty)
  s ← s.check "renderImportedBy renders a line for an imported module"
    ((renderImportedBy "Demo.MyLeanFile" true importedByMap).isSome)
  s ← s.check "renderImportedBy omits the line for a module nothing imports"
    ((renderImportedBy "Demo.AnotherFile" true importedByMap).isNone)
  s ← s.check "renderImportedBy links via {% link %} in Jekyll mode"
    (match renderImportedBy "Demo.MyLeanFile" true importedByMap with
      | some line => (line.splitOn "{% link reference/Demo/AnotherFile.md %}").length > 1
      | none => false)

  let externalImportsFixture : Std.HashMap String (Array String) :=
    Std.HashMap.ofList [("Demo.MyLeanFile", #["Init", "Lean"])]
  s ← s.check "buildImportedByMap drops imports of undocumented (external) modules"
    ((buildImportedByMap externalImportsFixture).isEmpty)

  -- Real-file checks against demo/'s actual source, not just synthetic
  -- HashMaps. `Init` also shows up in moduleImports' result (twice,
  -- even) -- Lean's implicit default prelude import, not something the
  -- source text writes. Harmless: buildImportedByMap only keeps imports
  -- of documented modules.
  let realImports ← moduleImports (moduleToFile demoRoot demoModule)
  s ← s.check "moduleImports finds demo/MyLeanFile.lean's real import of LeanDoc.Core"
    (realImports.contains "LeanDoc.Core")
  -- End-to-end on demo/'s two real modules — possible only since task
  -- T54 made a demo module importing another one actually elaborate.
  let anotherImports ← moduleImports (demoRoot / "Demo" / "AnotherFile.lean")
  let realImportedBy := buildImportedByMap (Std.HashMap.ofList
    [ ("Demo.MyLeanFile", realImports), ("Demo.AnotherFile", anotherImports) ])
  s ← s.check "buildImportedByMap on demo/'s real modules: MyLeanFile is imported by AnotherFile"
    ((realImportedBy.getD "Demo.MyLeanFile" #[]) == #["Demo.AnotherFile"])

  pure s

def sourceLinkChecks (c : Ctx) (s0 : TestState) : IO TestState := do
  let mut s := s0
  let demoRoot := c.demoRoot
  let scratchDir := c.scratchDir

  s ← s.check "parseGithubOwnerRepo handles an HTTPS remote with .git"
    (parseGithubOwnerRepo "https://github.com/JVerstry/LeanDoc.git" == some "JVerstry/LeanDoc")
  s ← s.check "parseGithubOwnerRepo handles an HTTPS remote without .git"
    (parseGithubOwnerRepo "https://github.com/JVerstry/LeanDoc" == some "JVerstry/LeanDoc")
  s ← s.check "parseGithubOwnerRepo handles an SSH remote"
    (parseGithubOwnerRepo "git@github.com:JVerstry/LeanDoc.git" == some "JVerstry/LeanDoc")
  s ← s.check "parseGithubOwnerRepo rejects a non-GitHub remote rather than guessing"
    (parseGithubOwnerRepo "https://gitlab.com/JVerstry/LeanDoc.git" == none)

  -- Fixture-level: against LeanDoc's own real repo (which does have a
  -- GitHub `origin` remote) — should produce a real base URL.
  let realBaseUrl ← githubSourceBaseUrl "."
  s ← s.check "githubSourceBaseUrl finds a real base URL for LeanDoc's own repo"
    realBaseUrl.isSome
  -- Task T57: pinned to `blob/HEAD` (the default branch), never a
  -- commit hash — a hash made committed docs differ from what any later
  -- regeneration produces, so freshness checks could never pass.
  s ← s.check "githubSourceBaseUrl links the default branch (blob/HEAD), not a commit hash"
    (realBaseUrl == some "https://github.com/JVerstry/LeanDoc/blob/HEAD")

  -- Regression: `demo/` is a *subdirectory* of LeanDoc's own repo, not
  -- a repo of its own — a real bug caught by generating demo/'s actual
  -- docs and inspecting the output URL, not assumed correct from
  -- reading the code. The base URL for `demo/` must include a `demo/`
  -- path segment, or every link it produces points at the wrong file
  -- in the real repo.
  let demoBaseUrl ← githubSourceBaseUrl demoRoot
  s ← s.check "githubSourceBaseUrl includes demo/'s own path prefix, not just the repo root's"
    (demoBaseUrl == some "https://github.com/JVerstry/LeanDoc/blob/HEAD/demo")

  -- And against a genuinely separate scratch git repo with no `origin`
  -- configured — deliberately *not* a plain non-git subdirectory:
  -- `git` searches upward through parent directories for `.git`, so a
  -- subdirectory with no `.git` of its own (nested inside this repo)
  -- would just resolve to *this* repo's real remote, not test the
  -- "no remote" bail-out path at all. A repo with its own `.git` but
  -- no `origin` is the correct way to exercise that path.
  let noRemoteDir := scratchDir / "no-remote"
  if ← noRemoteDir.pathExists then IO.FS.removeDirAll noRemoteDir
  IO.FS.createDirAll noRemoteDir
  discard <| IO.Process.output { cmd := "git", args := #["init", "-q"], cwd := some noRemoteDir }
  let noRemoteBaseUrl ← githubSourceBaseUrl noRemoteDir
  s ← s.check "githubSourceBaseUrl returns none for a repo with no origin remote"
    noRemoteBaseUrl.isNone
  IO.FS.removeDirAll noRemoteDir

  pure s

def groupingChecks (s0 : TestState) : IO TestState := do
  let mut s := s0

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

  pure s

def configChecks (c : Ctx) (s0 : TestState) : IO TestState := do
  let mut s := s0
  let demoRoot := c.demoRoot
  let scratchDir := c.scratchDir

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

  pure s

def versionChecks (c : Ctx) (s0 : TestState) : IO TestState := do
  let mut s := s0
  let demoRoot := c.demoRoot
  let scratchDir := c.scratchDir

  -- ## Unit-level: T27's version-tag normalization

  s ← s.check "normalizeVersion strips a leading v" (normalizeVersion "v1.0.0" == "1.0.0")
  s ← s.check "normalizeVersion strips a leading V" (normalizeVersion "V1.0.0" == "1.0.0")
  s ← s.check "normalizeVersion leaves a bare version alone" (normalizeVersion "1.0.0" == "1.0.0")

  -- ## Fixture-level: T27's checkVersionTag, against a genuinely
  -- separate scratch git repo (not LeanDoc's own — this creates a real
  -- git tag, which shouldn't happen in LeanDoc's actual repo as a test
  -- side effect). Removed and recreated every run for idempotency —
  -- `git tag` fails on an already-existing tag name.

  let versionScratchDir := scratchDir / "version-test"
  if ← versionScratchDir.pathExists then IO.FS.removeDirAll versionScratchDir
  IO.FS.createDirAll versionScratchDir
  let gitInit ← IO.Process.output { cmd := "git", args := #["init", "-q"], cwd := some versionScratchDir }
  s ← s.check "git init succeeds in the version-test scratch repo" (gitInit.exitCode == 0)
  discard <| IO.Process.output
    { cmd := "git", args := #["config", "user.email", "test@test.com"], cwd := some versionScratchDir }
  discard <| IO.Process.output
    { cmd := "git", args := #["config", "user.name", "test"], cwd := some versionScratchDir }
  IO.FS.writeFile (versionScratchDir / "dummy.txt") "dummy\n"
  discard <| IO.Process.output { cmd := "git", args := #["add", "-A"], cwd := some versionScratchDir }
  discard <| IO.Process.output
    { cmd := "git", args := #["commit", "-q", "-m", "init"], cwd := some versionScratchDir }
  let gitTag ← IO.Process.output { cmd := "git", args := #["tag", "v1.0.0"], cwd := some versionScratchDir }
  s ← s.check "git tag succeeds in the version-test scratch repo" (gitTag.exitCode == 0)

  -- Smoke tests: matching, mismatching, unconfigured, and no-tags-at-all
  -- should all run without crashing — the actual warning goes to
  -- stderr, not something this harness captures.
  checkVersionTag { projectVersion := "1.0.0" : LeanDocConfig } versionScratchDir
  checkVersionTag { projectVersion := "v1.0.0" : LeanDocConfig } versionScratchDir
  checkVersionTag { projectVersion := "2.0.0" : LeanDocConfig } versionScratchDir
  checkVersionTag { projectVersion := "" : LeanDocConfig } versionScratchDir
  checkVersionTag { projectVersion := "1.0.0" : LeanDocConfig } demoRoot
  s ← s.check "checkVersionTag runs without crashing in every case" true

  IO.FS.removeDirAll versionScratchDir

  pure s

def projectBuildChecks (c : Ctx) (s0 : TestState) : IO TestState := do
  let mut s := s0
  let demoRoot := c.demoRoot
  let demoBuilt := c.demoBuilt
  let demoSearchPath := c.demoSearchPath

  -- ## Fixture-level: whole-package scanning (T21) against demo/'s
  -- real lakefile.toml

  let discovered ← discoverModules demoRoot
  s ← s.check "discoverModules finds both of demo/'s modules via lean_lib globs"
    (discovered.qsort (· < ·) == #["Demo.AnotherFile", "Demo.MyLeanFile"])

  -- ## Unit-level + fixture-level: T54's project search path and build
  -- step — what lets one of a project's modules import another.

  let sep := System.SearchPath.separator.toString
  s ← s.check "parseLeanPathFromLakeEnv extracts and splits LEAN_PATH"
    ((parseLeanPathFromLakeEnv s!"LAKE=x\nLEAN_PATH=a{sep}b\r\nOTHER=y\n").map toString
      == ["a", "b"])
  s ← s.check "parseLeanPathFromLakeEnv returns [] when there's no LEAN_PATH line"
    (parseLeanPathFromLakeEnv "LAKE=x\nOTHER=y\n").isEmpty
  s ← s.check "buildProjectModules builds demo/'s modules" demoBuilt
  let demoBuildLib := (demoRoot / ".lake" / "build" / "lib" / "lean").toString
  s ← s.check "projectSearchPath includes demo/'s own build output"
    (demoSearchPath.any fun p => p.toString.endsWith demoBuildLib)
  s ← s.check "projectSearchPath includes demo/'s LeanDoc path dependency's build output"
    (demoSearchPath.any fun p =>
      (p.toString.splitOn "demo").length == 1 && p.toString.endsWith
        (System.FilePath.mk ".lake" / "build" / "lib" / "lean").toString)
  -- The T54 regression itself: before this fix, elaborating this file
  -- failed outright with "unknown module prefix 'Demo'".
  let anotherMetas ← extractFile (demoRoot / "Demo" / "AnotherFile.lean") `Demo.AnotherFile
  s ← s.check "extractFile documents a module that imports a sibling module (T54)"
    (anotherMetas.any fun d => d.name == "MyLeanModule.MyLeanQuadrupled")

  pure s

def extractorChecks (c : Ctx) (s0 : TestState) : IO (TestState × Array DeclMeta) := do
  let mut s := s0
  let demoRoot := c.demoRoot
  let demoModule := c.demoModule

  -- ## Fixture-level: the real extractor against demo/ (T7's
  -- noise-filtering count, pinned instead of re-checked by hand)

  let demoMetas ← extractFile (moduleToFile demoRoot demoModule) demoModule
  s ← s.check "extractFile keeps exactly the 14 real, documentable declarations"
    (demoMetas.size == 14)
  s ← s.check "extractFile finds MyLeanFunction with the right kind and type"
    (demoMetas.any fun d =>
      d.name == "MyLeanModule.MyLeanFunction" && d.kind == "def" && d.type == "Nat → Nat")
  s ← s.check "extractFile finds the undocumented declaration as actually undocumented"
    (demoMetas.any fun d =>
      d.name == "MyLeanModule.myLeanUndocumentedFunction" && d.docString.isNone)

  -- ## Fixture-level: T19's @[leandoc_ignore] attribute, exercised
  -- through the real extractor against demo/'s real fixture (not a
  -- fabricated environment) — proves the attribute actually removes a
  -- declaration from extraction output, not just that it parses.
  s ← s.check "extractFile excludes a @[leandoc_ignore]'d declaration"
    (!(demoMetas.any fun d => d.name == "MyLeanModule.myLeanInternalHelper"))

  -- ## Fixture-level: T41/T42's isNoise refinements, exercised through
  -- the real extractor.
  s ← s.check "extractFile finds MyLeanProp (the Prop structure itself is real content)"
    (demoMetas.any fun d => d.name == "MyLeanModule.MyLeanProp")
  s ← s.check "extractFile finds MyLeanProp.trivial — Lean elaborates it as a real \
               theorem here, so it's not noise-filtered (see isNoise's honest doc comment)"
    (demoMetas.any fun d => d.name == "MyLeanModule.MyLeanProp.trivial" && d.kind == "theorem")

  -- ## Fixture-level: T41's naming roles, computed from real types, and
  -- the check run over demo/'s real declarations. `demoMetas` is
  -- Demo.MyLeanFile, which deliberately contains two misnamed ones (an
  -- upper-case function and an upper-case proof); Demo.AnotherFile has a
  -- third, an upper-case function, seen in a real `lake exe leandoc demo`
  -- run with the check on.
  let roleOf (n : String) : Option String :=
    (demoMetas.find? (·.name == n)).bind (·.namingRole)
  s ← s.check "namingRole: a structure is a type" (roleOf "MyLeanModule.MyLeanStructure" == some "type")
  s ← s.check "namingRole: a Prop structure is a predicate" (roleOf "MyLeanModule.MyLeanProp" == some "predicate")
  s ← s.check "namingRole: a function is data" (roleOf "MyLeanModule.MyLeanFunction" == some "data")
  s ← s.check "namingRole: a constructor is data" (roleOf "MyLeanModule.MyLeanStructure.mk" == some "data")
  s ← s.check "namingRole: a theorem is a proof" (roleOf "MyLeanModule.MyLeanTheorem" == some "proof")
  s ← s.check "namingRole: a Prop field's proof is a proof" (roleOf "MyLeanModule.MyLeanProp.trivial" == some "proof")
  let flagged := (namingViolations demoMetas).map (·.1.name)
  s ← s.check "the naming check flags demo/'s upper-case function and theorem, and nothing else"
    (flagged.qsort (· < ·) == #["MyLeanModule.MyLeanFunction", "MyLeanModule.MyLeanTheorem"])

  pure (s, demoMetas)

def renderChecks (c : Ctx) (demoMetas : Array DeclMeta) (s0 : TestState) : IO TestState := do
  let mut s := s0
  let scratchDir := c.scratchDir

  -- ## Fixture-level: T38's orphan cleanup — `render` must wipe
  -- `reference/` fresh each run, not just write/overwrite, or a
  -- renamed/removed module's old page lingers forever.

  let renderScratchDir := scratchDir / "render-test"
  if ← renderScratchDir.pathExists then IO.FS.removeDirAll renderScratchDir
  IO.FS.createDirAll renderScratchDir
  let renderScratchJson := renderScratchDir / "metadata.json"
  IO.FS.writeFile renderScratchJson (toJson demoMetas).pretty
  let renderScratchDocs := renderScratchDir / "docs"
  let orphanPath := renderScratchDocs / "reference" / "SomeOldModule.md"
  IO.FS.createDirAll (renderScratchDocs / "reference")
  IO.FS.writeFile orphanPath "stale content from a module that no longer exists\n"
  -- Task T55: a hand-written page outside reference/ must survive.
  let customPage := renderScratchDocs / "guides" / "getting-started.md"
  let customContent := "---\nlayout: default\n---\n\n# My own guide\n"
  IO.FS.createDirAll (renderScratchDocs / "guides")
  IO.FS.writeFile customPage customContent
  render renderScratchJson renderScratchDocs true none {}
  s ← s.check "render wipes an orphaned reference/ page that no longer corresponds to any module"
    (!(← orphanPath.pathExists))
  s ← s.check "render still writes the real, current module pages"
    (← (renderScratchDocs / "reference" / "Demo" / "MyLeanFile.md").pathExists)
  s ← s.check "render leaves a hand-written page outside reference/ untouched (T55)"
    ((← IO.FS.readFile customPage) == customContent)
  IO.FS.removeDirAll renderScratchDir

  pure s

def hygieneChecks (s0 : TestState) : IO TestState := do
  let mut s := s0

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

  -- Task T55: the starter template for hand-written pages ships with
  -- the front matter Jekyll needs to style it.
  let templatePath : System.FilePath := "templates" / "page.md"
  s ← s.check "templates/page.md exists" (← templatePath.pathExists)
  if ← templatePath.pathExists then
    s ← s.check "templates/page.md has layout: default front matter"
      ((← IO.FS.readFile templatePath).startsWith "---\nlayout: default\n")

  -- The `/leandoc` audit skill (skill/SKILL.md), the audit prompt it
  -- runs, and the install prompt step that copies both. These are
  -- prompts, not code, so the checks are structural: they catch a file
  -- going missing or the three pieces drifting apart (a renamed
  -- subcommand, a lost version line, a changed folder name).
  let skillPath : System.FilePath := "skill" / "SKILL.md"
  s ← s.check "skill/SKILL.md exists" (← skillPath.pathExists)
  if ← skillPath.pathExists then
    let skill ← IO.FS.readFile skillPath
    let skillLines := skill.splitOn "\n"
    s ← s.check "skill/SKILL.md has front matter naming the skill 'leandoc'"
      (skillLines.take 2 == ["---", "name: leandoc"] &&
       (skillLines.getD 2 "").startsWith "description: " && skillLines.getD 3 "" == "---")
    s ← s.check "skill/SKILL.md states its version"
      ((skill.splitOn "LeanDoc skill version: ").length > 1)
    for sub in #["/leandoc dry", "/leandoc schedule", "/leandoc papercuts", "/leandoc update",
                 "/leandoc mode", "/leandoc uninstall"] do
      s ← s.check s!"skill/SKILL.md documents {sub}" ((skill.splitOn sub).length > 1)
    s ← s.check "skill/SKILL.md saves scheduled reports under .leandoc-audit/"
      ((skill.splitOn ".leandoc-audit/").length > 1)
    s ← s.check "skill/SKILL.md fetches from LeanDoc's own repository"
      ((skill.splitOn "raw.githubusercontent.com/JVerstry/LeanDoc/main/QualityAuditPrompt.txt").length > 1 &&
       (skill.splitOn "raw.githubusercontent.com/JVerstry/LeanDoc/main/skill/SKILL.md").length > 1)
  let audit ← IO.FS.readFile "QualityAuditPrompt.txt"
  let auditFirst := (audit.splitOn "\n").headD ""
  s ← s.check "QualityAuditPrompt.txt starts with 'LeanDoc audit version: <number>'"
    (auditFirst.startsWith "LeanDoc audit version: " &&
     ((auditFirst.drop "LeanDoc audit version: ".length).toString.toNat?).isSome)
  s ← s.check "QualityAuditPrompt.txt defines dry-run rules and finding keys"
    ((audit.splitOn "dry run").length > 1 && (audit.splitOn "FINDING KEYS").length > 1)
  let installPrompt ← IO.FS.readFile "InstallationPrompt.txt"
  s ← s.check "InstallationPrompt.txt copies the skill and the audit from the dependency"
    ((installPrompt.splitOn "skill/SKILL.md").length > 1 &&
     (installPrompt.splitOn ".lake/packages/LeanDoc/").length > 1 &&
     (installPrompt.splitOn "audit.txt").length > 1 && (installPrompt.splitOn "mode.txt").length > 1)

  -- A `{% link %}` tag with no target fails the whole Jekyll build
  -- ("Could not find document ''", checked against Jekyll's own
  -- link.rb), and Liquid runs even inside code spans. So in LeanDoc's
  -- own hand-written pages, every mention of it must be escaped.
  for file in #["docs/index.md", "docs/manual.md"] do
    let content ← IO.FS.readFile file
    let bare := (content.splitOn "{% link %}").length - 1
    let escaped := (content.splitOn "{% raw %}{% link %}{% endraw %}").length - 1
    s ← s.check s!"{file} never has an unescaped, targetless link tag" (bare == escaped)

  -- Task T56: the same check Jekyll's own `link` tag makes, over the
  -- committed generated pages — every `{% link X %}` must name a file
  -- that exists, or the whole site build fails. LeanDoc's own
  -- `Core.lean` docstrings mention `{% link %}` (describing its Jekyll
  -- output), so this catches a regression in escapeLiquid for real.
  for docsRoot in #[("docs" : System.FilePath), "demo" / "docs"] do
    let generated := #[docsRoot / "toc.md"] ++
      ((← (docsRoot / "reference").walkDir).filter (·.extension == some "md"))
    let mut bad : Array String := #[]
    for page in generated do
      for piece in ((← IO.FS.readFile page).splitOn "{% link ").drop 1 do
        let target := (piece.splitOn " %}").headD ""
        unless ← (docsRoot / target).pathExists do
          bad := bad.push s!"{page}: {target}"
    s ← s.check s!"every link tag in {docsRoot}'s generated pages points at an existing file"
      bad.isEmpty
    unless bad.isEmpty do
      IO.eprintln s!"  broken link tags: {bad}"

  let wipTracked ← IO.Process.output { cmd := "git", args := #["ls-files", "wip"] }
  s ← s.check "wip/ has no files tracked by git"
    (wipTracked.exitCode == 0 && wipTracked.stdout.trimAscii.isEmpty)

  let claudeTracked ← IO.Process.output { cmd := "git", args := #["ls-files", "CLAUDE.md"] }
  s ← s.check "CLAUDE.md has no files tracked by git"
    (claudeTracked.exitCode == 0 && claudeTracked.stdout.trimAscii.isEmpty)

  pure s

def main : IO Unit := do
  let demoRoot : System.FilePath := "demo"
  let demoModule : Name := `Demo.MyLeanFile
  -- Needed for the fixture-level tests, which call `extractFile` for
  -- real — same setup `Main.lean`'s `main` does before `runFrontend`,
  -- including task T54's build step and demo/'s own search path, so
  -- `Demo.AnotherFile`'s import of `Demo.MyLeanFile` resolves.
  let demoBuilt ← buildProjectModules demoRoot #["Demo.MyLeanFile", "Demo.AnotherFile"]
  let demoSearchPath ← projectSearchPath demoRoot
  Lean.initSearchPath (← Lean.findSysroot) demoSearchPath
  unsafe enableInitializersExecution

  -- Throwaway spot for file I/O checks, under `.leandoc/` (already
  -- gitignored) — not a real project.
  let scratchDir : System.FilePath := ".leandoc" / "test-scratch"
  IO.FS.createDirAll scratchDir
  let c : Ctx := { demoRoot, demoModule, demoBuilt, demoSearchPath, scratchDir }

  let s : TestState := {}
  let s ← pathChecks c s
  let s ← modulesPageChecks s
  let s ← moduleTreeChecks s
  let s ← tocChecks s
  let s ← rootIndexChecks c s
  let s ← assetChecks c s
  let s ← layoutVersionChecks s
  let s ← searchIndexChecks s
  let s ← declRenderChecks s
  let s ← liquidChecks s
  let s ← instanceListingChecks s
  let s ← importedByChecks c s
  let s ← sourceLinkChecks c s
  let s ← groupingChecks s
  let s ← configChecks c s
  let s ← namingChecks c s
  let s ← versionChecks c s
  let s ← projectBuildChecks c s
  let (s, demoMetas) ← extractorChecks c s
  let s ← renderChecks c demoMetas s
  let s ← qualityHookChecks c s
  let s ← hygieneChecks s

  IO.println s!"LeanDoc tests: {s.passed} passed, {s.failed} failed"
  if s.failed > 0 then
    IO.Process.exit 1

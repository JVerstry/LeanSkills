import LeanDoc.Core

/-!
# LeanDoc CLI entry point

Thin orchestration only — the real logic lives in `LeanDoc.Core` (task
T24: pulled out into a library so `test/` can import and exercise it
directly, rather than only being testable by running this whole
executable end-to-end).

Task T13: the project path is a CLI argument (`lake exe leandoc
[path]`), defaulting to `.` — LeanDoc's own repo — since dogfooding
LeanDoc's own source is the primary case now that the pipeline works;
`demo/` (the test fixture) needs `lake exe leandoc demo` explicitly.
-/

open Lean

def main (args : List String) : IO Unit := do
  -- Needed so `Init`'s (and any other core module's) `.olean`s resolve;
  -- see `Lean.Shell`'s `lean` driver, which does the same before calling
  -- `runFrontend`.
  Lean.initSearchPath (← Lean.findSysroot)
  -- Required before any import that loads environment extensions (which
  -- `runFrontend` does); see `Lake.importModulesUsingCache`, which does
  -- the same before its own `importModules (loadExts := true)`.
  unsafe enableInitializersExecution
  let projectRoot : System.FilePath := args.headD "."
  let config ← loadConfig (projectRoot / "leandoc.toml")
  -- Task T21: an explicit [modules] include list is used as-is; an
  -- empty/missing one falls back to whole-package scanning instead of
  -- immediately giving up.
  let discovered ← if config.includeModules.isEmpty then
      discoverModules projectRoot
    else
      pure config.includeModules
  -- `exclude` applies either way — even to an explicit include list,
  -- since naming something in both isn't a use case worth rejecting.
  let isExcluded (m : String) : Bool :=
    config.exclude.any fun ex => m == ex || m.startsWith (ex ++ ".")
  let effectiveModules := discovered.filter (!isExcluded ·)
  if effectiveModules.isEmpty then
    IO.eprintln "LeanDoc: nothing to document — leandoc.toml has no [modules] include list and whole-package scanning found nothing (or every discovered module was excluded)."
    IO.Process.exit 1
  let mut allMetas : Array DeclMeta := #[]
  let mut moduleCount := 0
  for moduleStr in effectiveModules do
    let moduleName := stringToModuleName moduleStr
    let file := moduleToFile projectRoot moduleName
    allMetas := allMetas ++ (← extractFile file moduleName)
    moduleCount := moduleCount + 1
  let outFile := projectRoot / config.jsonDir / "metadata.json"
  if let some dir := outFile.parent then
    IO.FS.createDirAll dir
  IO.FS.writeFile outFile (toJson allMetas).pretty
  IO.println s!"LeanDoc: wrote {allMetas.size} declarations from {moduleCount} module(s) to {outFile}"
  render outFile (projectRoot / config.docsDir) config.rendererJekyll

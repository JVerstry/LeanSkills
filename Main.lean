import Lean
import Lake.Toml

/-!
# LeanDoc extractor + renderer prototype (tasks T6/T7/T8/T9)

Proof-of-concept for LeanDoc's full pipeline (see `AGENTS.md` /
`docs/conventions.md` for the architecture writeup): the **extractor**
reads a project's `leandoc.toml`, runs Lean's own frontend over each
included module, walks the resulting `Environment` for the declarations
it added, and dumps their metadata to JSON; the **renderer** then reads
that JSON back off disk (a real read, not a reuse of the in-memory
array — this exercises the file-based contract between the two stages,
not just declares it) and writes Markdown pages.

Still narrow: module → file path mapping assumes the plain Lean
convention (`Foo.Bar` ↔ `Foo/Bar.lean`, no custom `srcDir`), and the
renderer only produces Markdown (no HTML, no theming). Both stages live
in one executable for now — a deliberate simplification, since the
architecture's "swappable renderer" promise is about the JSON contract
staying stable, not about the two stages being separate *processes*
from day one.

Task T13: the project path is now a CLI argument (`lake exe leandoc
[path]`), defaulting to `.` — LeanDoc's own repo — since dogfooding
LeanDoc's own source is the primary case now that the pipeline works;
`demo/` (the test fixture) needs `lake exe leandoc demo` explicitly.
-/

open Lean

/-- `leandoc.toml`'s parsed shape (task T8). All fields have defaults so
a project can omit the file entirely, or any section/field within it —
`include` is the only field with no *useful* default (an empty list
just means "document nothing" until T9 adds whole-package scanning). -/
structure LeanDocConfig where
  jsonDir      : System.FilePath := ".leandoc"
  docsDir      : System.FilePath := "docs"
  includeModules : Array String := #[]
  exclude      : Array String := #[]
  /-- Reserved for T9 — no renderer exists yet, so this is parsed but
  unused. -/
  rendererName : String := "markdown"
deriving Inhabited

open Lake.Toml in
/-- Loads `<projectRoot>/leandoc.toml`, falling back to
`LeanDocConfig`'s defaults if the file is missing or fails to parse.
Reuses Lake's own TOML parser/decoder (`Lake.Toml`) — the same one
`lakefile.toml` itself is parsed with — rather than hand-rolling one. -/
def loadConfig (path : System.FilePath) : IO LeanDocConfig := do
  unless (← path.pathExists) do
    return {}
  let input ← IO.FS.readFile path
  let ictx := Parser.mkInputContext input (toString path)
  match (← loadToml ictx |>.toBaseIO) with
  | .error log =>
    IO.eprintln s!"LeanDoc: warning: couldn't parse {path}, using defaults:"
    log.forM fun msg => do IO.eprintln (← msg.toString)
    return {}
  | .ok table =>
    let .ok cfg _errs := EStateM.run (s := #[]) do
      let output ← table.tryDecodeD `output Table.empty
      let modules ← table.tryDecodeD `modules Table.empty
      let renderer ← table.tryDecodeD `renderer Table.empty
      -- Decoded as `String`, not `System.FilePath`, so a trailing `/`
      -- (as written in the schema, e.g. `.leandoc/`) can be trimmed
      -- before use — otherwise joining it with a filename below
      -- produces a doubled separator.
      let jsonDirStr ← output.tryDecodeD `json_dir ".leandoc"
      let docsDirStr ← output.tryDecodeD `docs_dir "docs"
      let jsonDir : System.FilePath := (jsonDirStr.dropEndWhile (· == '/')).toString
      let docsDir : System.FilePath := (docsDirStr.dropEndWhile (· == '/')).toString
      let includeModules ← modules.tryDecodeD `include (#[] : Array String)
      let exclude ← modules.tryDecodeD `exclude (#[] : Array String)
      let rendererName ← renderer.tryDecodeD `name "markdown"
      pure { jsonDir, docsDir, includeModules, exclude, rendererName : LeanDocConfig }
    pure cfg

/-- Maps a module name to its source file, assuming the plain Lean
convention (`Foo.Bar` ↔ `<root>/Foo/Bar.lean`) — no `srcDir` override
support yet. -/
def moduleToFile (root : System.FilePath) (m : Name) : System.FilePath :=
  let path := (m.toString.splitOn ".").foldl (init := root) (· / ·)
  path.addExtension "lean"

/-- Maps a source file back to its dotted module name, the inverse of
`moduleToFile` — used by whole-package scanning (task T21) to name files
it discovers rather than was told about. Built from `FilePath.parent`
(for the namespace prefix) and `FilePath.fileStem` (for the last
component) rather than manual string surgery on the path, so it doesn't
care whether the path uses `/` or `\` — the same class of bug T9 hit
building *links* out of raw `FilePath` strings, avoided here by not
doing that in the first place. -/
def fileToModuleName (root file : System.FilePath) : Name :=
  let dirComponents := (file.parent.getD root).components.drop root.components.length
  let stem := file.fileStem.getD file.toString
  (dirComponents ++ [stem]).foldl Name.mkStr .anonymous

open Lake.Toml in
/-- Whole-package scanning (task T21): when `leandoc.toml` doesn't list
modules explicitly, read the target project's own `lakefile.toml` to
find what it actually builds, instead of requiring every module to be
named by hand. Only understands `lakefile.toml`, not the `lakefile.lean`
DSL — a project using the latter needs an explicit `include` list.

Mirrors Lake's own defaulting rules (see its README): a `lean_exe`'s
`root` defaults to its `name`; a `lean_lib`'s `roots` default to
`[name]`, and its `globs` default to one `Glob.one` (bare module, no
expansion) per root unless the config says otherwise. A glob ending in
`.+` means "submodules only" (the root itself isn't a real module);
`.*` means "the root module and its submodules". Submodule expansion
walks the filesystem (`System.FilePath.walkDir`) rather than trying to
statically enumerate without touching disk, since that's what "which
files actually exist" requires. -/
def discoverModules (projectRoot : System.FilePath) : IO (Array String) := do
  let lakefilePath := projectRoot / "lakefile.toml"
  unless (← lakefilePath.pathExists) do
    IO.eprintln s!"LeanDoc: whole-package scanning needs {lakefilePath} — lakefile.lean projects aren't supported yet, so `leandoc.toml` needs an explicit [modules] include list."
    return #[]
  let input ← IO.FS.readFile lakefilePath
  let ictx := Parser.mkInputContext input (toString lakefilePath)
  match (← loadToml ictx |>.toBaseIO) with
  | .error _ =>
    IO.eprintln s!"LeanDoc: couldn't parse {lakefilePath} for whole-package scanning."
    return #[]
  | .ok table =>
    let .ok (exeRoots, libGlobs) _errs := EStateM.run (s := #[]) do
      let exeTables ← table.tryDecodeD `lean_exe (#[] : Array Table)
      let exeRoots ← exeTables.mapM fun t => do
        let name ← t.tryDecodeD `name "Main"
        t.tryDecodeD `root name
      let libTables ← table.tryDecodeD `lean_lib (#[] : Array Table)
      let libGlobs ← libTables.mapM fun t => do
        let name ← t.tryDecodeD `name "Main"
        let roots ← t.tryDecodeD `roots (#[name] : Array String)
        t.tryDecodeD `globs roots
      pure (exeRoots, libGlobs)
    let mut modules := exeRoots
    for globs in libGlobs do
      for glob in globs do
        if glob.endsWith ".+" || glob.endsWith ".*" then
          let includeRootModule := glob.endsWith ".*"
          let base := (glob.take (glob.length - 2)).toString
          if includeRootModule then
            modules := modules.push base
          let baseDir := (base.splitOn ".").foldl (init := projectRoot) (· / ·)
          if (← baseDir.pathExists) then
            for p in (← System.FilePath.walkDir baseDir) do
              if p.extension == some "lean" then
                modules := modules.push (fileToModuleName projectRoot p).toString
        else
          modules := modules.push glob
    return modules

/-- Builds a hierarchical `Name` (`Foo.Bar`) from its dotted-string form
(`"Foo.Bar"`), as `leandoc.toml`'s `[modules] include` entries are
written. -/
def stringToModuleName (s : String) : Name :=
  (s.splitOn ".").foldl Name.mkStr .anonymous

/-- A declaration's source location. Line is 1-indexed and column is
0-indexed, matching Lean's own `Position` (and LSP, for `charUtf16`-free
consumers) — deliberately not reinvented here. -/
structure DeclRange where
  startLine   : Nat
  startColumn : Nat
  endLine     : Nat
  endColumn   : Nat
deriving ToJson, FromJson

/-- One extracted declaration: the T7 schema, refined by T9. T9 added
`module` — building the renderer immediately exposed that grouping
declarations by module (needed for one page per module) was impossible
without it, so this isn't the per-module-JSON-files split T7 left open;
it's a smaller, real gap that split would've also required.

Known gaps, left for a later pass rather than guessed at now:
- `kind` distinguishes `def`/`theorem`/`structure`/`inductive`/etc., but
  a `structure`'s *fields* only show up as their auto-generated
  projection functions (kind `"def"`) — there's no separate "field of
  which structure" relationship recorded yet.
- No import list yet (T7 also asks for per-module imports).
-/
structure DeclMeta where
  module    : String
  name      : String
  kind      : String
  type      : String
  docString : Option String
  range     : Option DeclRange
deriving ToJson, FromJson

/-- Human-readable declaration kind. `structure` vs `inductive` isn't
distinguishable from `ConstantKind` alone (a structure *is* a
single-constructor inductive under the hood) — `Lean.isStructure` is
Lean's own way of telling them apart. -/
def kindString (env : Environment) (name : Name) : ConstantKind → String
  | .defn => "def"
  | .thm => "theorem"
  | .axiom => "axiom"
  | .opaque => "opaque"
  | .quot => "quotient"
  | .induct => if Lean.isStructure env name then "structure" else "inductive"
  | .ctor => "constructor"
  | .recursor => "recursor"

/-- Extracts one declaration's metadata. Runs in `CoreM` because
`Lean.isAutoDeclOrPrivate_Internal` (the noise filter, see `isNoise`
below) and type pretty-printing both need it. -/
def declMetaOf (env : Environment) (moduleName : Name) (c : AsyncConstantInfo) :
    CoreM DeclMeta := do
  let docString ← findDocString? env c.name
  let type := toString (← (Meta.ppExpr c.toConstantVal.type).run')
  let range := (← findDeclarationRanges? c.name).map fun r =>
    { startLine := r.range.pos.line, startColumn := r.range.pos.column
      endLine := r.range.endPos.line, endColumn := r.range.endPos.column }
  pure { module := moduleName.toString, name := c.name.toString
         kind := kindString env c.name c.kind, type, docString, range }

/-- Whether `c` is Lean-generated scaffolding (recursors, `noConfusion`,
`injEq`, `_sizeOf_*`, equation lemmas, ...) rather than something a human
wrote — see T7 in `wip/todo.md`. Uses Lean's own
`isAutoDeclOrPrivate_Internal` (the same predicate Lean's environment
linter uses to count auto-generated declarations) plus a direct
recursor check, rather than reinventing name-suffix heuristics; verified
against the demo project's `MyLeanStructure` (which exercises all of the
above) that this correctly keeps only the 7 real declarations out of 21
total. -/
def isNoise (c : AsyncConstantInfo) : CoreM Bool :=
  if c.kind == ConstantKind.recursor then pure true else isAutoDeclOrPrivate_Internal c.name

/-- Extracts every non-noise declaration added by elaborating `file` as
module `moduleName`. -/
def extractFile (file : System.FilePath) (moduleName : Name) : IO (Array DeclMeta) := do
  let input ← IO.FS.readFile file
  let env? ← Lean.Elab.runFrontend input {} (toString file) moduleName
  let some env := env?
    | IO.eprintln s!"LeanDoc: elaboration of {file} failed (see errors above)."
      IO.Process.exit 1
  -- Only the declarations *added by this file*, not everything imported
  -- (e.g. all of `Init`) — see `Environment.getLocalConstantInfos`.
  let consts ← env.getLocalConstantInfos
  let coreCtx : Core.Context := { fileName := toString file, fileMap := FileMap.ofString input }
  let coreState : Core.State := { env }
  (do
      let mut acc : Array DeclMeta := #[]
      for c in consts do
        unless (← isNoise c) do
          acc := acc.push (← declMetaOf env moduleName c)
      pure acc
    : CoreM (Array DeclMeta)).toIO' coreCtx coreState

/-! ## Renderer (task T9)

Everything below only touches `DeclMeta`/`Json` — no `Environment`,
`CoreM`, or anything else from the extractor half above. That's the
seam the architecture calls "swappable": a future renderer (a different
Lean module, or a different language entirely) only needs to replicate
this section against the same JSON, not touch the extractor at all. -/

/-- Maps a dotted module name string (as stored in `DeclMeta.module`) to
a relative doc path, e.g. `"Demo.MyLeanFile"` ↦ `Demo/MyLeanFile.md` —
mirrors `moduleToFile`'s convention but for Markdown output. -/
def moduleToDocPath (m : String) : System.FilePath :=
  (m.splitOn ".").foldl (init := ("." : System.FilePath)) (· / ·) |>.addExtension "md"

/-- Renders one declaration as a Markdown section: a heading, the
signature as a code block, and the docstring (or an explicit "not
documented" note — silently omitting undocumented declarations would
hide exactly the coverage gaps T17's audit is meant to catch). -/
def renderDecl (d : DeclMeta) : String :=
  let doc := d.docString.getD "*(not documented)*"
  s!"### `{d.name}`\n\n\
     *{d.kind}*\n\n\
     ```lean\n{d.name} : {d.type}\n```\n\n\
     {doc}\n"

/-- Renders one module's page: a heading plus every declaration's
section, in the order the extractor emitted them (elaboration order —
see `Environment.getLocalConstantInfos`). -/
def renderModulePage (moduleName : String) (decls : Array DeclMeta) : String :=
  let body := String.join ((decls.map renderDecl).toList.intersperse "\n")
  s!"# {moduleName}\n\n{body}"

/-- Renders the API section's index: one line per module, linking to
its page. Deliberately minimal — task T18 covers a real table of
contents/glossary; this is just enough for the module pages to be
reachable at all.

Link targets are built as plain `/`-joined strings, not via
`moduleToDocPath`'s `System.FilePath` — a Markdown/web link needs `/`
regardless of host OS, but `FilePath`'s string rendering uses the native
separator (`\` on Windows), which would silently break these links only
on Windows. -/
def renderIndexPage (moduleNames : Array String) : String :=
  let linkPath (m : String) : String := (m.splitOn ".").foldl (init := "") fun acc part =>
    if acc.isEmpty then part else s!"{acc}/{part}"
  let items := moduleNames.map fun m => s!"- [{m}]({linkPath m}.md)"
  let body := String.join (items.toList.intersperse "\n")
  s!"# API Reference\n\n{body}\n"

/-- Groups declarations by module, preserving first-seen module order
(there's no `Array.groupByKey` in the stdlib to reach for here). -/
def groupDeclsByModule (metas : Array DeclMeta) : Array (String × Array DeclMeta) :=
  Id.run do
    let mut order : Array String := #[]
    let mut byModule : Std.HashMap String (Array DeclMeta) := {}
    for d in metas do
      unless byModule.contains d.module do
        order := order.push d.module
      byModule := byModule.insert d.module ((byModule.getD d.module #[]).push d)
    return order.map fun m => (m, byModule[m]!)

/-- Reads `jsonPath` back off disk (not the extractor's in-memory
result — see the module docstring), groups declarations by module, and
writes one Markdown page per module plus an index, under
`docsDir/api/`. -/
def render (jsonPath docsDir : System.FilePath) : IO Unit := do
  let raw ← IO.FS.readFile jsonPath
  let some json := Json.parse raw |>.toOption
    | IO.eprintln s!"LeanDoc: {jsonPath} is not valid JSON, can't render."
      IO.Process.exit 1
  let some (metas : Array DeclMeta) := (fromJson? json).toOption
    | IO.eprintln s!"LeanDoc: {jsonPath} doesn't match the DeclMeta schema, can't render."
      IO.Process.exit 1
  let apiDir := docsDir / "api"
  IO.FS.createDirAll apiDir
  let mut moduleNames : Array String := #[]
  for (moduleName, decls) in groupDeclsByModule metas do
    moduleNames := moduleNames.push moduleName
    let path := apiDir / moduleToDocPath moduleName
    if let some dir := path.parent then
      IO.FS.createDirAll dir
    IO.FS.writeFile path (renderModulePage moduleName decls)
  IO.FS.writeFile (apiDir / "index.md") (renderIndexPage moduleNames)
  IO.println s!"LeanDoc: rendered {moduleNames.size} module page(s) to {apiDir}"

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
  render outFile (projectRoot / config.docsDir)

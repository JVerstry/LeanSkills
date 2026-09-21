import Lean

/-!
# LeanDoc extractor prototype (tasks T6/T7)

Proof-of-concept for the extractor half of LeanDoc's pipeline (see
`AGENTS.md` / `docs/conventions.md` for the full architecture writeup):
run Lean's own frontend over a file, walk the resulting `Environment` for
the declarations it added, and dump their metadata to JSON.

This prototype is intentionally narrow: it targets one hardcoded file
(`demo/Demo/MyLeanFile.lean`, LeanDoc's own demo/test-fixture project).
Turning this into the real extractor is the rest of the backlog: walking
a whole project rather than one hardcoded file, and reading configuration
from `leandoc.toml` (T8).
-/

open Lean

/-- The demo project's example file this prototype extracts from. -/
def demoFile : System.FilePath :=
  System.FilePath.mk "demo" / "Demo" / "MyLeanFile.lean"

/-- The demo file's module name, used to name private/auxiliary
declarations during elaboration. Not derived from `demoFile`'s path yet
(see T7) — hardcoded since this prototype only ever points at one file. -/
def demoModuleName : Name :=
  `Demo.MyLeanFile

/-- Where the extracted metadata is written. Matches the `.leandoc/`
convention settled in `wip/todo.md`, scoped under `demo/` since that's
whose declarations this prototype extracts. -/
def outFile : System.FilePath :=
  System.FilePath.mk "demo" / ".leandoc" / "metadata.json"

/-- A declaration's source location. Line is 1-indexed and column is
0-indexed, matching Lean's own `Position` (and LSP, for `charUtf16`-free
consumers) — deliberately not reinvented here. -/
structure DeclRange where
  startLine   : Nat
  startColumn : Nat
  endLine     : Nat
  endColumn   : Nat
deriving ToJson

/-- One extracted declaration: the T7 schema, first cut.

Known gaps, left for a later pass rather than guessed at now:
- `kind` distinguishes `def`/`theorem`/`structure`/`inductive`/etc., but
  a `structure`'s *fields* only show up as their auto-generated
  projection functions (kind `"def"`) — there's no separate "field of
  which structure" relationship recorded yet.
- No import list yet (T7 also asks for per-module imports).
-/
structure DeclMeta where
  name      : String
  kind      : String
  type      : String
  docString : Option String
  range     : Option DeclRange
deriving ToJson

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
def declMetaOf (env : Environment) (c : AsyncConstantInfo) : CoreM DeclMeta := do
  let docString ← findDocString? env c.name
  let type := toString (← (Meta.ppExpr c.toConstantVal.type).run')
  let range := (← findDeclarationRanges? c.name).map fun r =>
    { startLine := r.range.pos.line, startColumn := r.range.pos.column
      endLine := r.range.endPos.line, endColumn := r.range.endPos.column }
  pure { name := c.name.toString, kind := kindString env c.name c.kind, type, docString, range }

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

def main : IO Unit := do
  -- Needed so `Init`'s (and any other core module's) `.olean`s resolve;
  -- see `Lean.Shell`'s `lean` driver, which does the same before calling
  -- `runFrontend`.
  Lean.initSearchPath (← Lean.findSysroot)
  -- Required before any import that loads environment extensions (which
  -- `runFrontend` does); see `Lake.importModulesUsingCache`, which does
  -- the same before its own `importModules (loadExts := true)`.
  unsafe enableInitializersExecution
  let input ← IO.FS.readFile demoFile
  let env? ← Lean.Elab.runFrontend input {} (toString demoFile) demoModuleName
  let some env := env?
    | IO.eprintln "LeanDoc: elaboration of the demo file failed (see errors above)."
      IO.Process.exit 1
  -- Only the declarations *added by this file*, not everything imported
  -- (e.g. all of `Init`) — see `Environment.getLocalConstantInfos`.
  let consts ← env.getLocalConstantInfos
  let coreCtx : Core.Context := { fileName := toString demoFile, fileMap := FileMap.ofString input }
  let coreState : Core.State := { env }
  let metas ← (do
      let mut acc : Array DeclMeta := #[]
      for c in consts do
        unless (← isNoise c) do
          acc := acc.push (← declMetaOf env c)
      pure acc
    : CoreM (Array DeclMeta)).toIO' coreCtx coreState
  if let some dir := outFile.parent then
    IO.FS.createDirAll dir
  IO.FS.writeFile outFile (toJson metas).pretty
  let filtered := consts.size - metas.size
  IO.println s!"LeanDoc: wrote {metas.size} declarations to {outFile} ({filtered} filtered as auto-generated)"

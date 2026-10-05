import Lean
import Lake.Toml
import LeanDoc.Assets

/-!
# LeanDoc core (extractor + renderer)

The reusable logic behind `lake exe leandoc` (see `Main.lean`), pulled
into its own library module (task T24) so `test/` can import and
exercise it directly instead of only being testable by running the
whole executable end-to-end. See `README.md`
for the architecture writeup this implements: the **extractor** reads a
project's `leandoc.toml`, runs Lean's own frontend over each included
module, walks the resulting `Environment` for the declarations it
added, and dumps their metadata to JSON; the **renderer** then reads
that JSON back off disk (a real read, not a reuse of the in-memory
array — this exercises the file-based contract between the two stages,
not just declares it) and writes Markdown pages.

Still narrow: module → file path mapping assumes the plain Lean
convention (`Foo.Bar` ↔ `Foo/Bar.lean`, no custom `srcDir`), and the
renderer only produces Markdown (no HTML, no theming). Both stages live
in one module for now — a deliberate simplification, since the
architecture's "swappable renderer" promise is about the JSON contract
staying stable, not about the two stages being separate *processes*
from day one.
-/

open Lean

/-- `leandoc.toml`'s parsed shape (task T8). All fields have defaults so
a project can omit the file entirely, or any section/field within it —
`include` is the only field with no *useful* default on its own (an
empty list falls back to whole-package scanning, task T21). -/
structure LeanDocConfig where
  jsonDir      : System.FilePath := ".leandoc"
  docsDir      : System.FilePath := "docs"
  includeModules : Array String := #[]
  exclude      : Array String := #[]
  /-- Reserved for a future renderer choice — Markdown is the only one
  that exists, so this isn't acted on yet. -/
  rendererName : String := "markdown"
  /-- Whether generated pages target Jekyll (task T31): front matter,
  `{% link %}` internal links, and a written `_config.yml` (task
  T22/T28) vs. plain portable Markdown with plain relative links and no
  `_config.yml`. Defaults to `true` since `docs_dir` is committed to git
  for GitHub Pages by default (T15/T22), and GitHub Pages runs Jekyll by
  default — set to `false` for output meant to be read as plain
  Markdown (an IDE, a non-Jekyll/non-Pages host) instead. -/
  rendererJekyll : Bool := true
  /-- Task T41: the overall opt-in/opt-out toggle for documentation-
  convention/compliance checks derived from Mathlib's own style
  guidelines (currently just the copyright/license header check below
  — naming-conventions and docstring-quality checks are designed but
  not built yet, pending task T42). Off by default: most projects
  aren't Mathlib and shouldn't be held to its conventions unless they
  explicitly ask. -/
  complianceEnabled : Bool := false
  /-- Task T41: the author name(s) `checkComplianceHeader` expects to
  find in each file's copyright header when `complianceEnabled` is
  true. Empty skips the author-specific part of that check even when
  compliance checking is otherwise on (nothing configured to check
  against). -/
  complianceAuthor : String := ""
  /-- Task T41: the license string `checkComplianceHeader` expects to
  find in each file's copyright header. Same empty-skips treatment as
  `complianceAuthor`. -/
  complianceLicense : String := ""
  /-- Task T27: the project's own release version, e.g. `"1.2.0"` —
  manually set, not auto-detected. Empty (the default) means "not
  tracked," and `checkVersionTag` skips its check entirely rather than
  warning about a version nobody configured. Only ever compared against
  the project's latest git tag, never rendered anywhere a reader would
  see it — see `checkVersionTag`'s doc comment for why. -/
  projectVersion : String := ""
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
      let compliance ← table.tryDecodeD `compliance Table.empty
      let project ← table.tryDecodeD `project Table.empty
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
      let rendererJekyll ← renderer.tryDecodeD `jekyll true
      let complianceEnabled ← compliance.tryDecodeD `enabled false
      let complianceAuthor ← compliance.tryDecodeD `author ""
      let complianceLicense ← compliance.tryDecodeD `license ""
      let projectVersion ← project.tryDecodeD `version ""
      pure { jsonDir, docsDir, includeModules, exclude, rendererName, rendererJekyll,
             complianceEnabled, complianceAuthor, complianceLicense, projectVersion
             : LeanDocConfig }
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
  module     : String
  name       : String
  kind       : String
  type       : String
  docString  : Option String
  range      : Option DeclRange
  /-- The class this declaration is a registered instance *of* (task
  T48), e.g. `some "Inhabited"` for an `instance : Inhabited Foo`.
  `none` for anything that isn't a registered instance, or whose
  conclusion's head isn't itself a class (shouldn't happen for a
  well-formed instance, but not asserted). See `instanceClassOf`. -/
  instanceOf : Option String := none
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

/-- The class `declName` is a registered instance *of*, if any (task
T48). `none` for anything `Lean.Meta.isInstance` doesn't recognize as
an instance at all, and also (deliberately not asserted otherwise) for
an instance whose conclusion's head constant isn't itself a class —
telescoping the type down to its conclusion and checking the head via
`Lean.isClass` mirrors how instance resolution itself finds the class
of a `instance : Foo Bar` declaration.

Scoped to this one direction only — "what class is this an instance
of" — not doc-gen4's other direction ("what instances mention this
*type*", e.g. every `Inhabited Foo`-shaped instance on `Foo`'s own
page regardless of which class each belongs to). That second direction
needs walking every argument of the conclusion, not just its head, and
was left for a later pass rather than guessed at now. -/
def instanceClassOf (env : Environment) (declName : Name) (type : Expr) :
    CoreM (Option String) := do
  if ← Meta.isInstance declName then
    let head ← (show MetaM Expr from
      Meta.forallTelescopeReducing type fun _ concl => pure concl.getAppFn).run'
    match head with
    | .const n _ => pure (if isClass env n then some n.toString else none)
    | _ => pure none
  else
    pure none

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
  let instanceOf ← instanceClassOf env c.name c.toConstantVal.type
  pure { module := moduleName.toString, name := c.name.toString
         kind := kindString env c.name c.kind, type, docString, range, instanceOf }

/-- Whether `c` is Lean-generated scaffolding (recursors, `noConfusion`,
`injEq`, `_sizeOf_*`, equation lemmas, ...) rather than something a human
wrote — see T7 in `wip/todo.md`. Uses Lean's own
`isAutoDeclOrPrivate_Internal` (the same predicate Lean's environment
linter uses to count auto-generated declarations) plus a direct
recursor check, rather than reinventing name-suffix heuristics; verified
against the demo project's `MyLeanStructure` (which exercises all of the
above) that this correctly keeps only the 7 real declarations out of 21
total.

Also excludes two categories `isAutoDeclOrPrivate_Internal` doesn't
catch, ported *carefully*, not wholesale, from Batteries' own
`docBlame`/`docBlameThm` linter exemption logic (task T41/T42's
investigation confirmed these are real, checked against
`Batteries/Tactic/Lint/Misc.lean` directly, not guessed): custom-
notation parser/pretty-printer plumbing
(`parenthesizer`/`formatter`/`delaborator`/`quot`-suffixed) and
Prop-projection `def`s (Batteries' own comment cites `leanprover/
lean4#2575`: "Prop projections are generated as defs even when they
should be theorems"). The first is verified — `demo/`'s fixture has no
custom notation to trigger it directly, but the string check itself is
trivial. **The second is ported defensively, not confirmed to ever
fire**: a real single-field `Prop`-structure test case in `demo/`
(`MyLeanProp.trivial`) came through with kind `theorem` directly, not
`def` — Lean's behavior here may have changed since Batteries' comment
was written, or the issue needs a shape this simple case doesn't
trigger. Left in rather than removed, since it's real, checked
upstream logic and harmless if it never matches anything — just not
something to claim as empirically verified working.

**Deliberately not ported**: Batteries' `docBlame` also exempts
instances (and their nested auxiliary declarations) from needing a
docstring — but that's an exemption from *lint nagging*, not a
statement that instances aren't real content. Checked directly against
Mathlib's own generated docs (a real page, not assumed): instances *do*
show up in doc-gen4's rendered output, undocumented ones included —
the exact same distinction already made for `@[nolint docBlame]` in
task T19's design (a lint-suppression tag isn't a
hide-from-documentation signal). Treating instances as noise here would
have been the same mistake, just made a second time in a different
spot — caught and reverted before this shipped.

The Prop-projection check needs `Lean.Meta.isProp`, lifted from
`MetaM` into `CoreM` via `.run'` — the same lifting pattern
`declMetaOf` already uses for `Meta.ppExpr`. -/
def isNoise (c : AsyncConstantInfo) : CoreM Bool := do
  if c.kind == ConstantKind.recursor then return true
  if ← isAutoDeclOrPrivate_Internal c.name then return true
  if let .str _ s := c.name then
    if s == "parenthesizer" || s == "formatter" || s == "delaborator" || s == "quot" then
      return true
  if c.kind == ConstantKind.defn then
    if (← isProjectionFn c.name) && (← (Meta.isProp c.toConstantVal.type).run') then
      return true
  return false

/-- Task T19: `@[leandoc_ignore]` marks a declaration as *deliberately*
undocumented — a real decision by whoever wrote it, not a coverage gap
LeanDoc should report. A `TagAttribute` (Lean's own lightweight
boolean-attribute mechanism, `Lean.registerTagAttribute` — the same
shape `@[inline]` uses), not a custom parametric attribute: there's
nothing to configure, a declaration either has it or doesn't.

Deliberately LeanDoc's *own* attribute, not an attempt to recognize
Mathlib/Batteries' `@[nolint docBlame]`: that tag suppresses a
*lint warning* when running `#lint`, it doesn't affect what doc-gen4
renders at all (doc-gen4 shows every declaration it finds, documented
or not) — treating it as equivalent to "hide from generated docs"
would misrepresent what a project using it actually meant. Recognizing
it for real would also require adding Batteries as a genuine compile-
time dependency of LeanDoc itself (its `nolint` attribute is a
`ParametricAttribute` with no generic, type-erased way to query it
without importing the module that defines it) — a real, recurring
cost (toolchain-compatibility tracking) LeanDoc doesn't currently have
at all, not worth taking on for a tag that wouldn't even mean the
right thing here. -/
initialize leandocIgnoreAttr : TagAttribute ←
  registerTagAttribute `leandoc_ignore
    "Marks a declaration as deliberately excluded from LeanDoc's generated documentation \
     (task T19) — a decision by the author, distinct from `isNoise`'s compiler-generated-\
     scaffolding filter."

/-- Whether `declName` was tagged `@[leandoc_ignore]` (task T19) — see
`leandocIgnoreAttr`. -/
def isDeliberatelyIgnored (env : Environment) (declName : Name) : Bool :=
  leandocIgnoreAttr.hasTag env declName

/-- Extracts every non-noise, non-`@[leandoc_ignore]`'d declaration
added by elaborating `file` as module `moduleName`. -/
def extractFile (file : System.FilePath) (moduleName : Name) : IO (Array DeclMeta) := do
  -- Required before *every* `runFrontend` call, not just the first one
  -- per process: `Lean.withImporting`'s `finally` resets this flag to
  -- `false` once each import completes (see `Lean/ImportingFlag.lean`),
  -- so a caller extracting more than one file per run — which whole-
  -- package scanning (T21) made possible for the first time when it
  -- started finding more than a single module — needs it re-enabled
  -- here, not just once at startup.
  unsafe enableInitializersExecution
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
          unless isDeliberatelyIgnored env c.name do
            acc := acc.push (← declMetaOf env moduleName c)
      pure acc
    : CoreM (Array DeclMeta)).toIO' coreCtx coreState

/-- Whether `source`'s header mentions the expected author/license
(task T41) — checked as plain substring presence within the file's
first 1000 characters (generous enough to cover a real header without
scanning the whole file), not a strict parse of Mathlib's exact
copyright-header grammar (`/- Copyright (c) YEAR Name. ... Authors:
... -/`). A header lives before any declaration, so this is a genuine
gap in what `DeclMeta`-based extraction can see at all — a separate,
purely textual check, not something bolted onto `extractFile`. Empty
`expectedAuthor`/`expectedLicense` skip that part of the check
(nothing configured to check against); always requires the literal
word "Copyright" to appear, regardless. -/
def hasCopyrightHeader (source expectedAuthor expectedLicense : String) : Bool :=
  let header := (source.take (min source.length 1000)).toString
  let mentionsCopyright := (header.splitOn "Copyright").length > 1
  let mentionsAuthor := expectedAuthor.isEmpty || (header.splitOn expectedAuthor).length > 1
  let mentionsLicense := expectedLicense.isEmpty || (header.splitOn expectedLicense).length > 1
  mentionsCopyright && mentionsAuthor && mentionsLicense

/-- Warns (never fails the build) on stderr if `file` is missing its
expected copyright/license header, per `config`'s `[compliance]`
settings (task T41). A no-op unless `complianceEnabled` is true *and*
at least one of `complianceAuthor`/`complianceLicense` is actually
configured — otherwise there's nothing meaningful to check against,
and a bare "missing Copyright" warning on every file would be noise
for a project that never asked for this. -/
def checkComplianceHeader (config : LeanDocConfig) (file : System.FilePath) : IO Unit := do
  if config.complianceEnabled &&
      !(config.complianceAuthor.isEmpty && config.complianceLicense.isEmpty) then
    let source ← IO.FS.readFile file
    unless hasCopyrightHeader source config.complianceAuthor config.complianceLicense do
      IO.eprintln s!"LeanDoc: warning: {file} is missing the expected copyright/license header (see [compliance] in leandoc.toml)."

/-- Strips a single leading `v`/`V` (e.g. `"v1.2.0"` → `"1.2.0"`), so a
git tag written either way compares equal to a plain `[project]
version` value (task T27). -/
def normalizeVersion (v : String) : String :=
  if v.startsWith "v" || v.startsWith "V" then (v.drop 1).toString else v

/-- Warns (never fails the build) on stderr if `[project] version`
doesn't match the project's latest git tag (task T27) — a real,
narrowly-scoped signal that someone forgot to bump the configured
version after tagging a release, not a general "is this repo dirty"
check (deliberately not built: a dirty working tree is completely
normal mid-edit, e.g. generating docs before committing both the
source changes and the regenerated docs together — warning about that
would just be noise on routine use). A no-op if `projectVersion` is
empty (nothing configured to check), `projectRoot` isn't a git repo,
or it has no tags yet — there's nothing to compare against in any of
those cases, not a reason to warn. Deliberately never rendered
anywhere a reader would see it, only ever a build-time developer
warning — see the task's own discussion in `wip/todo.md` for why a
reader-facing stamp was dropped in favor of this instead. -/
def checkVersionTag (config : LeanDocConfig) (projectRoot : System.FilePath) : IO Unit := do
  unless config.projectVersion.isEmpty do
    let result ← IO.Process.output
      { cmd := "git", args := #["describe", "--tags", "--abbrev=0"], cwd := some projectRoot }
    if result.exitCode == 0 then
      let latestTag := result.stdout.trimAscii.toString
      unless latestTag.isEmpty do
        unless normalizeVersion config.projectVersion == normalizeVersion latestTag do
          IO.eprintln s!"LeanDoc: warning: leandoc.toml's [project] version ({config.projectVersion}) doesn't match the latest git tag ({latestTag}) — did you forget to bump it?"

/-- Parses a git remote URL into `"owner/repo"`, if — and only if — it's
recognizably a GitHub URL (task T46). Handles the two common forms:
`git@github.com:owner/repo.git` (SSH) and `https://github.com/owner/
repo[.git]` (HTTPS). Deliberately `none` for anything else, including
other hosts (GitLab, Codeberg, self-hosted Gitea, ...) — those use
different source-line-range URL schemes, and a wrong guess is worse
than no link at all. -/
def parseGithubOwnerRepo (remote : String) : Option String :=
  let stripGitSuffix (s : String) : String :=
    if s.endsWith ".git" then (s.dropEnd 4).toString else s
  if remote.startsWith "git@github.com:" then
    some (stripGitSuffix ((remote.drop "git@github.com:".length).toString))
  else if remote.startsWith "https://github.com/" then
    some (stripGitSuffix ((remote.drop "https://github.com/".length).toString))
  else if remote.startsWith "http://github.com/" then
    some (stripGitSuffix ((remote.drop "http://github.com/".length).toString))
  else
    none

/-- Attempts to build a GitHub "blob" URL prefix for jump-to-source
links (task T46), e.g. `"https://github.com/owner/repo/blob/HEAD"` —
`none` if `projectRoot` isn't a git repo, has no `origin` remote, or
that remote isn't recognizably GitHub (`parseGithubOwnerRepo`).

`HEAD`, not a commit hash (task T57): GitHub resolves `blob/HEAD/…` to
the repository's default branch. A commit hash made generated output
self-referential — docs committed alongside a change are generated
*before* that commit exists, so they could only ever embed the
previous commit's hash, and any freshness check regenerating them
later (CI, the pre-commit template) always saw a diff. The trade-off:
a link shows the default branch's current file, not the exact version
the docs were generated from, so line ranges drift if published docs
lag behind the code — which a freshness check exists to prevent.
Degrades silently, not with a warning: not every project is hosted on
GitHub, and that's a completely normal, unremarkable state, not
something to nag about the way a missing compliance header (T41) or a
version mismatch (T27) is.

Also folds in `git rev-parse --show-prefix` — `projectRoot` need not
*be* the git repo's own root (e.g. `demo/` is a subdirectory of
LeanDoc's own repo, not a repo of its own); without this, a link built
from module-relative paths alone would point at the wrong location in
the real repo (`.../Demo/MyLeanFile.lean` instead of the real
`.../demo/Demo/MyLeanFile.lean`) — caught by generating LeanDoc's own
`demo/` docs for real and checking the actual output URL, not assumed
correct from reading the code alone. -/
def githubSourceBaseUrl (projectRoot : System.FilePath) : IO (Option String) := do
  let remoteResult ← IO.Process.output
    { cmd := "git", args := #["remote", "get-url", "origin"], cwd := some projectRoot }
  if remoteResult.exitCode != 0 then return none
  let remote := remoteResult.stdout.trimAscii.toString
  let some ownerRepo := parseGithubOwnerRepo remote
    | return none
  let subdirResult ← IO.Process.output
    { cmd := "git", args := #["rev-parse", "--show-prefix"], cwd := some projectRoot }
  let rawSubdir := if subdirResult.exitCode == 0 then subdirResult.stdout.trimAscii.toString else ""
  let subdir := if rawSubdir.endsWith "/" then (rawSubdir.dropEnd 1).toString else rawSubdir
  let base := s!"https://github.com/{ownerRepo}/blob/HEAD"
  return some (if subdir.isEmpty then base else s!"{base}/{subdir}")

/-- Extracts `LEAN_PATH`'s value from `lake env`'s output (one
`NAME=value` line per variable), parsed with the platform's own
search-path separator. `[]` if there's no such line. -/
def parseLeanPathFromLakeEnv (output : String) : System.SearchPath :=
  let line? := (output.splitOn "\n").find? (·.startsWith "LEAN_PATH=")
  match line? with
  | some line => System.SearchPath.parse ((line.drop "LEAN_PATH=".length).trimAscii.toString)
  | none => []

/-- The target project's own module search path (task T54), as Lake
itself computes it: its own build output plus every dependency's. Read
from `lake env` (run in `projectRoot`) rather than reconstructed by
hand, so `require`d packages, custom `buildDir`s, etc. all come out
right without LeanDoc re-implementing Lake's resolution logic.

This is what lets one of a project's modules `import` another of its
own: `runFrontend` never writes an `.olean`, so an imported sibling can
only resolve against one already compiled by `lake build` — the same
requirement doc-gen4 has (it runs as a Lake facet that builds the
library first). Uses the `LAKE` environment variable when set — `lake
exe leandoc` sets it to the exact Lake binary running us — so the
toolchain matches, falling back to whatever `lake` is on `PATH`.
Returns `[]`, with a warning, if `lake env` fails. -/
def projectSearchPath (projectRoot : System.FilePath) : IO System.SearchPath := do
  let lake := (← IO.getEnv "LAKE").getD "lake"
  let result ← IO.Process.output { cmd := lake, args := #["env"], cwd := some projectRoot }
  if result.exitCode != 0 then
    IO.eprintln s!"LeanDoc: warning: `lake env` failed in {projectRoot}, so its own modules \
      and dependencies won't be on the search path — imports of them will fail to resolve.\n\
      {result.stderr}"
    return []
  return parseLeanPathFromLakeEnv result.stdout

/-- Builds `modules` in the target project with Lake (`lake build
+Mod …`, run in `projectRoot`) before extraction (task T54), so the
`.olean`s `projectSearchPath` points at exist and aren't stale: a
module `import`ing a sibling resolves against that sibling's compiled
`.olean`, never its source. Builds exactly the documented modules (and,
transitively, whatever they import) rather than the project's default
targets, which needn't cover every documented module. A no-op when
everything's already up to date. Lake's own progress output goes
straight to the terminal — a first build can take a while. Returns
whether the build succeeded; docs can't be generated from code that
doesn't compile, the same requirement doc-gen4 has. -/
def buildProjectModules (projectRoot : System.FilePath) (modules : Array String) :
    IO Bool := do
  let lake := (← IO.getEnv "LAKE").getD "lake"
  let child ← IO.Process.spawn
    { cmd := lake, args := #["build"] ++ modules.map ("+" ++ ·), cwd := some projectRoot }
  return (← child.wait) == 0

/-- A module's own direct imports, read straight off its source file
(task T50) via `Lean.parseImports'` — the same fast header-only parser
Lake itself uses to resolve a module's dependencies, not hand-rolled
text scanning, and considerably cheaper than a full `runFrontend` just
to read `import` lines. Returns dotted module name strings, matching
`DeclMeta.module`'s own convention. -/
def moduleImports (path : System.FilePath) : IO (Array String) := do
  let content ← IO.FS.readFile path
  let header ← Lean.parseImports' content path.toString
  pure (header.imports.map (·.module.toString))

/-- Inverts a module → its-own-imports map into module → modules-that-
import-it (task T50's "imported by"), restricted to modules that are
themselves documented — an import of `Init`/`Lean`/a dependency
outside the project isn't something LeanDoc has a page for, so it's
silently dropped rather than rendered as a dead link. -/
def buildImportedByMap (moduleImports : Std.HashMap String (Array String)) :
    Std.HashMap String (Array String) :=
  Id.run do
    let mut m : Std.HashMap String (Array String) := {}
    for (importer, imports) in moduleImports.toArray do
      for imported in imports do
        if moduleImports.contains imported then
          m := m.insert imported ((m.getD imported #[]).push importer)
    return m

/-! ## Renderer

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

/-- Same mapping as `moduleToDocPath`, but as a plain `/`-joined string
rather than a `System.FilePath` — a Markdown/web link needs `/`
regardless of host OS, but `FilePath`'s string rendering uses the
native separator (`\` on Windows), which would silently break links
only on Windows (T9's original bug). Shared by every link-building
function below rather than each redefining it locally. -/
def linkPath (m : String) : String :=
  (m.splitOn ".").foldl (init := "") fun acc part =>
    if acc.isEmpty then part else s!"{acc}/{part}"

/-- Makes text copied from Lean source safe to put in a Jekyll page
(task T56). Jekyll runs Liquid over the whole page before Markdown,
even inside code spans and code blocks, so a docstring mentioning
`{% link %}` would fail the entire site build ("Could not find
document ''") and one mentioning `{{ site.baseurl }}` would print a
value instead of the text. Each `{{` and `{%` becomes a Liquid output
expression printing it literally (`{{ "{{" }}`, `{{ "{%" }}`).

Not a `raw`/`endraw` wrapper: the text could itself contain an
`endraw` tag. Not `render_with_liquid: false` front matter either:
that's Jekyll 4 only (GitHub Pages runs Jekyll 3), and generated pages
need Liquid for their own `link` tags. The `{{` pass runs first
because its output contains no `{%`, whereas the `{%` pass's output
contains `{{`. Only for Jekyll output: plain Markdown has no Liquid. -/
def escapeLiquid (s : String) : String :=
  (s.replace "{{" "{{ \"{{\" }}").replace "{%" "{{ \"{%\" }}"

/-- Renders one declaration as a Markdown section: a heading, the
signature as a code block, the docstring (or an explicit "not
documented" note — silently omitting undocumented declarations would
hide exactly the coverage gaps T17's audit is meant to catch), and — if
`sourceBaseUrl` is available and `d.range` was captured — a
jump-to-source link (task T46). `DeclMeta.range` (task T7) has always
been captured but never rendered until now; confirmed by direct
comparison with a real Mathlib page that this is genuinely expected,
not just a nice-to-have (every declaration there links to its exact
GitHub line range). `sourceBaseUrl` is `none` whenever
`githubSourceBaseUrl` couldn't build one (no git repo, no `origin`,
non-GitHub remote) — silently omit the link then, not an error. -/
def renderDecl (d : DeclMeta) (sourceBaseUrl : Option String)
    (instancesByClass : Std.HashMap String (Array DeclMeta)) : String :=
  let doc := d.docString.getD "*(not documented)*"
  let sourceLink := match sourceBaseUrl, d.range with
    | some base, some r =>
      let path := linkPath d.module ++ ".lean"
      s!"\n\n[source]({base}/{path}#L{r.startLine}-L{r.endLine})"
    | _, _ => ""
  -- Task T48: `d` is a class with registered instances iff some other
  -- declaration's `instanceOf` names it — render those as a flat list
  -- of `name — module`, not links to a specific in-page anchor (same
  -- reasoning `renderToc` already gives for not guessing at Jekyll's
  -- heading-id slugification without a real local Jekyll to verify
  -- against).
  let instances := instancesByClass.getD d.name #[]
  let instancesSection :=
    if instances.isEmpty then "" else
      let items := String.join ((instances.map fun i =>
        s!"- `{i.name}` — *{i.module}*").toList.intersperse "\n")
      s!"\n\n**Instances:**\n\n{items}\n"
  s!"### `{d.name}`\n\n\
     *{d.kind}*\n\n\
     ```lean\n{d.name} : {d.type}\n```\n\n\
     {doc}{sourceLink}{instancesSection}\n"

/-- Jekyll (task T22/T28) only converts a Markdown file at all — running
Liquid tags, honoring `_config.yml`, everything — if it has *front
matter*: per Jekyll's own docs
(`jekyllrb.com/docs/static-files/`), "a static file is a file that does
not contain any front matter", and static files are copied through
byte-for-byte. An empty front-matter block would technically satisfy
that, but front matter here also carries `layout: default` (task T29):
Jekyll only applies a layout's styling to a page when that page's front
matter names one — confirmed against Jekyll's own docs
(`jekyllrb.com/docs/themes/`) after realizing the previous empty
`---\n---\n` block meant generated pages likely never actually picked
up any theme/stylesheet at all, `_config.yml`'s `theme:` key
notwithstanding. `default` refers to `_layouts/default.html`, written
by `ensureDefaultLayout`. -/
def frontMatter : String := "---\nlayout: default\n---\n\n"

/-- Renders the "Imported by" line for a module's page (task T50):
which other *documented* modules import this one, if any — `none` when
nothing does, so `renderModulePage` can omit the line entirely rather
than print an empty "Imported by:". Links use the same `jekyll`
branching every other renderer here follows. -/
def renderImportedBy (moduleName : String) (jekyll : Bool)
    (importedByMap : Std.HashMap String (Array String)) : Option String :=
  let importers := importedByMap.getD moduleName #[]
  if importers.isEmpty then none else
  let items := importers.qsort (· < ·) |>.map fun m =>
    if jekyll then
      "[" ++ escapeLiquid m ++ "](" ++ "{% link reference/" ++ linkPath m ++ ".md %}" ++ ")"
    else
      s!"[{m}]({linkPath m}.md)"
  some s!"**Imported by:** {String.intercalate ", " items.toList}\n"

/-- Renders one module's page: a heading, an optional "Imported by"
line (task T50), plus every declaration's section, in the order the
extractor emitted them (elaboration order — see
`Environment.getLocalConstantInfos`). `jekyll` (task T31) controls
whether front matter is prepended — `false` produces plain portable
Markdown with no Jekyll-specific content at all. `sourceBaseUrl` (task
T46) is threaded through to `renderDecl` for jump-to-source links. -/
def renderModulePage (moduleName : String) (decls : Array DeclMeta) (jekyll : Bool)
    (sourceBaseUrl : Option String) (instancesByClass : Std.HashMap String (Array DeclMeta))
    (importedByMap : Std.HashMap String (Array String)) : String :=
  let body := String.join
    ((decls.map (renderDecl · sourceBaseUrl instancesByClass)).toList.intersperse "\n")
  -- Task T56: `renderDecl`'s output holds no Liquid of LeanDoc's own
  -- (plain source URLs, no `link` tags), so escaping it whole is safe.
  let body := if jekyll then escapeLiquid body else body
  let heading := if jekyll then escapeLiquid moduleName else moduleName
  let fm := if jekyll then frontMatter else ""
  let importedByLine := match renderImportedBy moduleName jekyll importedByMap with
    | some line => s!"\n{line}"
    | none => ""
  s!"{fm}# {heading}\n{importedByLine}\n{body}"

/-- One node of the module tree (task T49): a namespace segment,
its own module page if one exists exactly at this path (`some m` for
a leaf like `Demo.MyLeanFile`; `none` for a pure namespace prefix like
`Demo` when nothing is documented at `Demo` itself), and its children
keyed by the *next* path segment. Built purely by splitting each
module's dotted name on `.` — no separate hierarchy-tracking needed,
since Lean's own module naming already encodes it. -/
inductive ModuleTree where
  | node (children : Array (String × ModuleTree)) (full : Option String)

def ModuleTree.empty : ModuleTree := .node #[] none

partial def insertModule : ModuleTree → List String → String → ModuleTree
  | .node children _, [], full => .node children (some full)
  | .node children leaf, s :: rest, full =>
    match children.findIdx? (·.1 == s) with
    | some i =>
      match children[i]? with
      | some (_, child) => .node (children.set! i (s, insertModule child rest full)) leaf
      | none => .node children leaf
    | none =>
      .node (children.push (s, insertModule .empty rest full)) leaf

/-- Builds the module tree from the flat list `render` already has —
every module's dotted name, split on `.`. -/
def buildModuleTree (moduleNames : Array String) : ModuleTree :=
  moduleNames.foldl (init := ModuleTree.empty) fun t m => insertModule t (m.splitOn ".") m

/-- Renders one tree node as a nested `<li>`, natively-collapsible via
`<details>`/`<summary>` — no JS needed for the collapse mechanism
itself, mirroring doc-gen4's own choice there. Children are sorted
alphabetically by segment at each level. A leaf module's segment is a
link (Jekyll `{% link %}` or a plain relative link, same `jekyll`
branching every other renderer here already uses); a pure namespace
prefix with no module of its own (e.g. `Demo` when only
`Demo.MyLeanFile` is documented) renders as plain, unlinked text.

In Jekyll mode the link is a real HTML `<a>` element, not a Markdown
link: this whole tree is raw block HTML, and kramdown (the Markdown
converter GitHub Pages runs) leaves the content of a block-level HTML
element unparsed by default, so a Markdown link inside it would show up
as literal `[Core](/reference/...)` text on the published site. -/
partial def renderModuleTreeNode (label : String) (tree : ModuleTree) (jekyll : Bool) : String :=
  match tree with
  | .node children full =>
    let shown := if jekyll then escapeLiquid label else label
    let selfText := match full with
      | some m =>
        if jekyll then
          "<a href=\"" ++ "{% link reference/" ++ linkPath m ++ ".md %}" ++ "\">" ++ shown ++ "</a>"
        else
          s!"[{label}]({linkPath m}.md)"
      | none => shown
    if children.isEmpty then
      s!"<li>{selfText}</li>"
    else
      let sorted := children.qsort (fun a b => a.1 < b.1)
      let childItems := String.join
        ((sorted.map fun (seg, child) => renderModuleTreeNode seg child jekyll).toList)
      s!"<li><details><summary>{selfText}</summary><ul>{childItems}</ul></details></li>"

/-- Renders the whole module tree as a `<ul>` of top-level namespace
segments — the entry point `renderModulesPage` calls.

Scoped deliberately narrower than doc-gen4's own nav tree (task T49's
backlog entry left this open): no shared iframe nav-frame persisting
expand/collapse state across page loads, and no auto-expand-to-the-
current-page's-own-entry — both are meaningful when a *whole
ecosystem's* dependency closure needs one shared, always-visible
sidebar (Mathlib's actual scale), but `reference/modules.md` is a
single, standalone index page here, not something rendered inside
every other page — LeanDoc typically documents one project, not an
entire ecosystem, so there is no "current page's own entry" to expand
to on this page in the first place. -/
def renderModuleTree (moduleNames : Array String) (jekyll : Bool) : String :=
  let tree := buildModuleTree moduleNames
  match tree with
  | .node children _ =>
    let sorted := children.qsort (fun a b => a.1 < b.1)
    let items := String.join
      ((sorted.map fun (seg, child) => renderModuleTreeNode seg child jekyll).toList)
    s!"<ul>{items}</ul>"

/-- Renders the list of documented modules, linking to its page.
Named `modules.md` (task T18 — not `index.md`, to avoid having two
different-purposed `index.md` files in the tree: this one lists
modules, `docs_dir/index.md` is the site's actual root page).

Jekyll output (task T31) renders a nested, collapsible tree (task
T49, see `renderModuleTree`) grouped by namespace rather than a flat
list — links use Jekyll's `{% link %}` tag (task T28), not plain
Markdown links: Jekyll renames a converted page's extension
(`Foo/Bar.md` ↦ `Foo/Bar.html`), so a plain `.md` link would 404 once
Jekyll processing is on. The `link` tag resolves the *source* path to
its converted output URL at build time, and fails the build if the
target doesn't exist (`jekyllrb.com/docs/liquid/tags/`).

Crucially, the path inside the `link` tag is resolved from the
Jekyll *source root* (this page's `docsDir`, e.g. `docs/`), not from the
current page's own directory the way a relative Markdown link would be
— so it needs a `reference/` prefix (task T25 — renamed from `api/`,
since this is a flat dump of every included declaration, not a
curated public API surface) even though this page and the pages it
links to live in the same directory. Getting this wrong would silently
reintroduce the plain-relative-link bug this replaces.

Non-Jekyll output (`jekyll = false`) falls back to a flat, plain
relative `.md` list — portable, readable outside Jekyll, but 404s once
Jekyll *does* process the page (never mix the two within one
`docs_dir`), and raw `<details>` HTML has no obvious "plain Markdown"
equivalent worth inventing here. -/
def renderModulesPage (moduleNames : Array String) (jekyll : Bool) : String :=
  let fm := if jekyll then frontMatter else ""
  if jekyll then
    s!"{fm}# Modules\n\n{renderModuleTree moduleNames jekyll}\n"
  else
    let items := moduleNames.map fun m => s!"- [{m}]({linkPath m}.md)"
    let body := String.join (items.toList.intersperse "\n")
    s!"{fm}# Modules\n\n{body}\n"

/-- Buckets a declaration's `kind` (see `kindString`) into one of the
table of contents' four groups. Every `kindString` output maps to
exactly one bucket — `"quotient"`/`"recursor"` are rare enough to share
"Other" rather than each getting a barely-populated section of their
own. -/
def kindBucket (kind : String) : String :=
  match kind with
  | "def" | "opaque" => "Definitions"
  | "theorem" | "axiom" => "Theorems & Axioms"
  | "structure" | "inductive" | "constructor" => "Structures & Inductives"
  | _ => "Other"

/-- Renders a flat, project-wide table of contents (task T18): every
documented declaration across every module, grouped by `kindBucket`
rather than by module — the point is "show me every theorem," not
"show me what's in this file" (that's what `reference/`'s module pages
are already for).

Links point at the declaration's *module* page, not a per-declaration
anchor within it. Deliberately not deep-linking to an in-page anchor:
Jekyll's `{% link %}` only validates that the *target file* exists at
build time, not a specific `#anchor` inside it, and this project has no
local Jekyll available to empirically verify its Markdown-to-heading-id
slugification matches what's assumed here (the same honesty standard
T28 held itself to) — a wrong guess would silently produce broken
in-page anchors that nothing catches. Revisit once that's verified for
real, not before.

A bucket with zero declarations is omitted entirely, not rendered as an
empty heading. -/
def renderToc (metas : Array DeclMeta) (jekyll : Bool) : String :=
  let bucketOrder := #["Definitions", "Theorems & Axioms", "Structures & Inductives", "Other"]
  let bucketed : Std.HashMap String (Array DeclMeta) := Id.run do
    let mut m : Std.HashMap String (Array DeclMeta) := {}
    for d in metas do
      let b := kindBucket d.kind
      m := m.insert b ((m.getD b #[]).push d)
    return m
  let renderEntry (d : DeclMeta) : String :=
    if jekyll then
      "- [`" ++ escapeLiquid d.name ++ "`](" ++ "{% link reference/" ++ linkPath d.module ++
        ".md %}" ++ ") — *" ++ escapeLiquid d.module ++ "*"
    else
      s!"- [`{d.name}`]({linkPath d.module}.md) — *{d.module}*"
  let sections := bucketOrder.filterMap fun b =>
    let decls := bucketed.getD b #[]
    if decls.isEmpty then none else
    let items := String.join ((decls.map renderEntry).toList.intersperse "\n")
    some s!"## {b}\n\n{items}\n"
  let body := String.join (sections.toList.intersperse "\n")
  let fm := if jekyll then frontMatter else ""
  s!"{fm}# Table of Contents\n\n{body}\n"

/-- One entry in the site-wide search index (task T47) — deliberately
narrower than `DeclMeta`: just enough for `assets/search.js` to filter
by name and render a result (`kind`/`module` as a label, `link` to jump
to it). `link` is site-root-relative, no leading slash (`search.js`
prefixes it with `LEANDOC_BASEURL` itself) — `"reference/" ++ linkPath
module ++ ".html"`, matching Jekyll's default converted-file naming
(`.md` sources become same-path `.html` outputs) the same way
`renderModulesPage`'s `{% link %}` tags already rely on. -/
structure SearchEntry where
  name   : String
  kind   : String
  module : String
  link   : String
deriving ToJson, FromJson

/-- Renders `docs_dir/assets/search-index.json` (task T47): one compact
JSON array, one entry per documented declaration, powering
`assets/search.js`'s client-side search. Only meaningful for Jekyll
output (`search.js`/the layout's `#search` box are only wired up when
`jekyll` is on, same as every other JS asset here) — `render` only
calls this in that branch. Regenerated fresh on every run (unlike the
write-once assets below), since it must reflect the project's current
declarations, not a one-time template. `.compress`, not `.pretty`:
this file is machine-read only, and T47's own backlog entry already
flagged index size as a real scale concern (Mathlib's equivalent is
67.6MB) — no reason to spend extra bytes on human-readable whitespace
nobody reads. -/
def renderSearchIndex (metas : Array DeclMeta) : String :=
  let entries := metas.map fun d =>
    ({ name := d.name, kind := d.kind, module := d.module
       link := s!"reference/{linkPath d.module}.html" } : SearchEntry)
  (toJson entries).compress

/-- Ensures `docsDir/assets/search.js` exists, writing the client-side
search script (task T47 — see `assets/search.js`,
`LeanDoc.Assets.searchJs`) if it's missing. Never overwrites an
existing file, same write-once treatment as `ensureStyleAsset`. -/
def ensureSearchScript (docsDir : System.FilePath) : IO Unit := do
  let path := docsDir / "assets" / "search.js"
  unless (← path.pathExists) do
    if let some dir := path.parent then
      IO.FS.createDirAll dir
    IO.FS.writeFile path LeanDoc.Assets.searchJs

/-- Ensures `docsDir/assets/mathjax-config.js` exists, writing the
MathJax delimiter configuration (task T51 — see
`assets/mathjax-config.js`, `LeanDoc.Assets.mathjaxConfigJs`) if it's
missing. Never overwrites an existing file, same write-once treatment
as `ensureStyleAsset`. MathJax's own renderer script is loaded
directly from its CDN in the layout, not vendored — unlike the other
assets here, it's a large, versioned third-party library, not
something a project would ever want to hand-edit after the fact. -/
def ensureMathjaxConfig (docsDir : System.FilePath) : IO Unit := do
  let path := docsDir / "assets" / "mathjax-config.js"
  unless (← path.pathExists) do
    if let some dir := path.parent then
      IO.FS.createDirAll dir
    IO.FS.writeFile path LeanDoc.Assets.mathjaxConfigJs

/-- Ensures `docsDir/find.html` exists, writing the stable-permalink
redirect page (task T52 — see `assets/find.html`,
`LeanDoc.Assets.findHtml`) if it's missing. Lives at the site root
(not under `assets/`, unlike the other write-once JS/CSS here), since
`/find.html?pattern=<Name>` is meant to be a stable, memorable URL
external links target directly. Never overwrites an existing file,
same write-once treatment as `ensureStyleAsset`. Depends on
`assets/search-index.json` existing to look anything up in, so only
meaningful for Jekyll output — same as `ensureSearchScript`. -/
def ensureFindPage (docsDir : System.FilePath) : IO Unit := do
  let path := docsDir / "find.html"
  unless (← path.pathExists) do
    IO.FS.createDirAll docsDir
    IO.FS.writeFile path LeanDoc.Assets.findHtml

/-- Ensures `docsDir/404.html` exists, writing a friendlier 404 page
(task T53 — see `assets/404.html`, `LeanDoc.Assets.notFoundHtml`) if
it's missing. GitHub Pages serves this file automatically for any
unmatched path, so it needs no wiring beyond existing at this exact
path. Suggests plausible declarations from `assets/search-index.json`
(task T47) based on the broken URL's own last path segment — a simple
substring match, not real fuzzy matching, same scoping decision T47
itself made. Never overwrites an existing file, same write-once
treatment as `ensureStyleAsset`. Only meaningful for Jekyll output,
same as `ensureFindPage`/`ensureSearchScript`. -/
def ensureNotFoundPage (docsDir : System.FilePath) : IO Unit := do
  let path := docsDir / "404.html"
  unless (← path.pathExists) do
    IO.FS.createDirAll docsDir
    IO.FS.writeFile path LeanDoc.Assets.notFoundHtml

/-- The auto-managed navigation region inside `docs_dir/index.md`
(task T18) — delimited by these markers so `ensureRootIndex` can keep
it current as LeanDoc's own generated pages grow (a plain "write once,
never touch again" file, like `_config.yml`, would go stale the moment
a new generated page type ships, even for a user who never customized
anything) without disturbing any hand-written content around it. -/
def navMarkerStart : String := "<!-- leandoc:nav:start -->"
def navMarkerEnd : String := "<!-- leandoc:nav:end -->"

/-- Renders the nav block's current contents, markers included. -/
def renderNavBlock (jekyll : Bool) : String :=
  let refLink := if jekyll then "{% link reference/modules.md %}" else "reference/modules.md"
  let tocLink := if jekyll then "{% link toc.md %}" else "toc.md"
  s!"{navMarkerStart}\n- [Reference]({refLink})\n- [Table of Contents]({tocLink})\n{navMarkerEnd}"

/-- Ensures `docsDir/index.md` — the site's actual root page — exists
and links to the generated `reference/`/`toc.md` pages. Three cases:
- **Missing entirely**: create a minimal page with just the nav block.
- **Exists, contains the nav markers**: replace only what's between
  them with a freshly rendered block, leaving everything outside it
  (a hand-written intro, whatever else) untouched.
- **Exists, no markers** (a hand-written page that predates this
  mechanism): leave it completely alone. Silently injecting content
  into a page someone hand-curated would be worse than an out-of-date
  link — the fix there is adding the markers once, by hand, not having
  LeanDoc decide where to put them. -/
def ensureRootIndex (docsDir : System.FilePath) (jekyll : Bool) : IO Unit := do
  let path := docsDir / "index.md"
  let navBlock := renderNavBlock jekyll
  if ← path.pathExists then
    let content ← IO.FS.readFile path
    let hasStart := (content.splitOn navMarkerStart).length > 1
    let hasEnd := (content.splitOn navMarkerEnd).length > 1
    if hasStart && hasEnd then
      let beforeStart := (content.splitOn navMarkerStart).headD ""
      let afterStart := ((content.splitOn navMarkerStart).drop 1).headD ""
      let afterEnd := ((afterStart.splitOn navMarkerEnd).drop 1).headD ""
      IO.FS.writeFile path (beforeStart ++ navBlock ++ afterEnd)
  else
    let fm := if jekyll then frontMatter else ""
    IO.FS.writeFile path s!"{fm}# Documentation\n\n{navBlock}\n"

/-- Groups instance declarations by the class they're an instance of
(task T48 — see `instanceClassOf`), for `renderDecl`'s "Instances"
section. Project-wide, not per-module: an instance can (and often
does) live in a different module than the class it's an instance of. -/
def groupInstancesByClass (metas : Array DeclMeta) : Std.HashMap String (Array DeclMeta) :=
  Id.run do
    let mut m : Std.HashMap String (Array DeclMeta) := {}
    for d in metas do
      if let some cls := d.instanceOf then
        m := m.insert cls ((m.getD cls #[]).push d)
    return m

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

/-- Minimal `_config.yml` written once. No `theme:`/`remote_theme:` key
(task T29 — dropped `jekyll-theme-minimal`): LeanDoc now ships its own
complete stylesheet and layout (`ensureStyleAsset`/
`ensureDefaultLayout`) rather than pulling in a GitHub Pages theme, so
there's nothing else `_config.yml` needs to say. Only ever written if
the file doesn't already exist — like `InstallationPrompt.txt`'s other
one-time setup steps, this must not clobber a customization on a later
`lake exe leandoc` run. -/
def defaultJekyllConfig : String :=
  ""

/-- Ensures `docsDir/_config.yml` exists, writing the default (see
`defaultJekyllConfig`) if it's missing. Never overwrites an existing
file. -/
def ensureJekyllConfig (docsDir : System.FilePath) : IO Unit := do
  let path := docsDir / "_config.yml"
  unless (← path.pathExists) do
    IO.FS.writeFile path defaultJekyllConfig

/-- Ensures `docsDir/assets/style.css` exists, writing doc-gen4's
vendored stylesheet (task T29 — see `assets/style.css`,
`LeanDoc.Assets.styleCss`) if it's missing. Never overwrites an
existing file, so a project is free to edit it after that first write
— LeanDoc never touches it again. -/
def ensureStyleAsset (docsDir : System.FilePath) : IO Unit := do
  let path := docsDir / "assets" / "style.css"
  unless (← path.pathExists) do
    if let some dir := path.parent then
      IO.FS.createDirAll dir
    IO.FS.writeFile path LeanDoc.Assets.styleCss

/-- Ensures `docsDir/_layouts/default.html` exists, writing LeanDoc's
minimal layout (task T29 — see `assets/layouts/default.html`,
`LeanDoc.Assets.defaultLayoutHtml`) if it's missing. Never overwrites
an existing file, same write-once treatment as `ensureStyleAsset`. -/
def ensureDefaultLayout (docsDir : System.FilePath) : IO Unit := do
  let path := docsDir / "_layouts" / "default.html"
  unless (← path.pathExists) do
    if let some dir := path.parent then
      IO.FS.createDirAll dir
    IO.FS.writeFile path LeanDoc.Assets.defaultLayoutHtml

/-- Ensures `docsDir/assets/color-scheme.js` exists, writing the
light/dark/system theme switcher script (task T45 — see
`assets/color-scheme.js`, `LeanDoc.Assets.colorSchemeJs`) if it's
missing. Never overwrites an existing file, same write-once treatment
as `ensureStyleAsset`. -/
def ensureColorSchemeScript (docsDir : System.FilePath) : IO Unit := do
  let path := docsDir / "assets" / "color-scheme.js"
  unless (← path.pathExists) do
    if let some dir := path.parent then
      IO.FS.createDirAll dir
    IO.FS.writeFile path LeanDoc.Assets.colorSchemeJs

/-- Reads `jsonPath` back off disk (not the extractor's in-memory
result — see the module docstring), groups declarations by module, and
writes one Markdown page per module plus an index, under
`docsDir/reference/` (task T25 — named `reference/`, not `api/`: this
is a flat dump of every included declaration, not a curated public API
surface, and the name shouldn't claim curation the renderer doesn't do).
`jekyll` (task T31, from `LeanDocConfig.rendererJekyll`) controls
whether the output targets Jekyll (front matter, `{% link %}` links, a
written `_config.yml`) or is plain portable Markdown. Also writes
`docs_dir/toc.md` (task T18's table of contents) and ensures
`docs_dir/index.md` links to both (`ensureRootIndex`).

`docs_dir/reference/` is wiped and recreated fresh on every run (task
T38) rather than only ever written/overwritten — otherwise a renamed
or removed module's old page lingers on disk forever, orphaned, never
cleaned up (hit for real landing T18/T25's `reference/index.md` →
`reference/modules.md` rename: the stale file had to be removed by
hand). Safe to do unconditionally because `reference/` is exclusively
generator-owned — nothing under it is ever meant to be hand-edited,
unlike `_config.yml`/`assets/style.css`/`_layouts/default.html`, which
stay write-once-only.

`sourceBaseUrl` (task T46, from `githubSourceBaseUrl`) and
`importedByMap` (task T50, from `buildImportedByMap`) are both threaded
through to every `renderModulePage` call — computed once by the caller
(`Main.lean`, which has `projectRoot` and each module's file path;
`render` itself only ever sees `docsDir` and the already-extracted
JSON), not per-module. Same reasoning as `sourceBaseUrl`: reading a
module's own source file to find its imports is an extractor-side
concern, not something the renderer (which only ever touches
`DeclMeta`/`Json` — see this section's own module docstring) should be
doing.

For Jekyll output, also writes `docs_dir/assets/search-index.json`
(task T47) powering the layout's client-side search box — after
`ensureRootIndex`, not before: ordering doesn't actually matter here
(different files, no dependency between them), but grouping the
"only meaningful for Jekyll" writes together keeps them visually
separate from the always-on Markdown writes above. -/
def render (jsonPath docsDir : System.FilePath) (jekyll : Bool)
    (sourceBaseUrl : Option String) (importedByMap : Std.HashMap String (Array String)) :
    IO Unit := do
  let raw ← IO.FS.readFile jsonPath
  let some json := Json.parse raw |>.toOption
    | IO.eprintln s!"LeanDoc: {jsonPath} is not valid JSON, can't render."
      IO.Process.exit 1
  let some (metas : Array DeclMeta) := (fromJson? json).toOption
    | IO.eprintln s!"LeanDoc: {jsonPath} doesn't match the DeclMeta schema, can't render."
      IO.Process.exit 1
  let referenceDir := docsDir / "reference"
  if ← referenceDir.pathExists then
    IO.FS.removeDirAll referenceDir
  IO.FS.createDirAll referenceDir
  if jekyll then
    ensureJekyllConfig docsDir
    ensureStyleAsset docsDir
    ensureDefaultLayout docsDir
    ensureColorSchemeScript docsDir
    ensureSearchScript docsDir
    ensureMathjaxConfig docsDir
    ensureFindPage docsDir
    ensureNotFoundPage docsDir
  let instancesByClass := groupInstancesByClass metas
  let mut moduleNames : Array String := #[]
  for (moduleName, decls) in groupDeclsByModule metas do
    moduleNames := moduleNames.push moduleName
    let path := referenceDir / moduleToDocPath moduleName
    if let some dir := path.parent then
      IO.FS.createDirAll dir
    IO.FS.writeFile path
      (renderModulePage moduleName decls jekyll sourceBaseUrl instancesByClass importedByMap)
  IO.FS.writeFile (referenceDir / "modules.md") (renderModulesPage moduleNames jekyll)
  IO.FS.writeFile (docsDir / "toc.md") (renderToc metas jekyll)
  ensureRootIndex docsDir jekyll
  if jekyll then
    let indexPath := docsDir / "assets" / "search-index.json"
    if let some dir := indexPath.parent then
      IO.FS.createDirAll dir
    IO.FS.writeFile indexPath (renderSearchIndex metas)
  IO.println s!"LeanDoc: rendered {moduleNames.size} module page(s) to {referenceDir}"

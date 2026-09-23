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

/-- Renders one module's page: a heading plus every declaration's
section, in the order the extractor emitted them (elaboration order —
see `Environment.getLocalConstantInfos`). `jekyll` (task T31) controls
whether front matter is prepended — `false` produces plain portable
Markdown with no Jekyll-specific content at all. -/
def renderModulePage (moduleName : String) (decls : Array DeclMeta) (jekyll : Bool) : String :=
  let body := String.join ((decls.map renderDecl).toList.intersperse "\n")
  let fm := if jekyll then frontMatter else ""
  s!"{fm}# {moduleName}\n\n{body}"

/-- Renders the list of documented modules, one line per module, linking
to its page. Named `modules.md` (task T18 — not `index.md`, to avoid
having two different-purposed `index.md` files in the tree: this one
lists modules, `docs_dir/index.md` is the site's actual root page).

Links use Jekyll's `link` Liquid tag (task T28), not plain Markdown
links: Jekyll renames a converted page's extension (`Foo/Bar.md` ↦
`Foo/Bar.html`), so a plain `.md` link would 404 once Jekyll processing
is on. The `link` tag resolves the *source* path to its converted
output URL at build time, and fails the build if the target doesn't
exist (`jekyllrb.com/docs/liquid/tags/`) — a stronger guarantee than the
plain links this replaces gave us.

Crucially, the path inside the `link` tag is resolved from the
Jekyll *source root* (this page's `docsDir`, e.g. `docs/`), not from the
current page's own directory the way a relative Markdown link would be
— so it needs a `reference/` prefix (task T25 — renamed from `api/`,
since this is a flat dump of every included declaration, not a curated
public API surface) even though this page and the pages it links to
live in the same directory. Getting this wrong would silently
reintroduce the plain-relative-link bug this replaces.

`jekyll` (task T31) controls both the front matter and which link form
is used: `false` falls back to a plain relative `.md` link (portable,
readable outside Jekyll, but 404s once Jekyll *does* process the page —
never mix the two within one `docs_dir`). -/
def renderModulesPage (moduleNames : Array String) (jekyll : Bool) : String :=
  let items := moduleNames.map fun m =>
    if jekyll then
      -- Built with `++`, not `s!"..."`, because the literal Liquid
      -- `{% ... %}` braces would otherwise be parsed as string
      -- interpolation syntax.
      "- [" ++ m ++ "](" ++ "{% link reference/" ++ linkPath m ++ ".md %}" ++ ")"
    else
      s!"- [{m}]({linkPath m}.md)"
  let body := String.join (items.toList.intersperse "\n")
  let fm := if jekyll then frontMatter else ""
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
      "- [`" ++ d.name ++ "`](" ++ "{% link reference/" ++ linkPath d.module ++ ".md %}" ++
        ") — *" ++ d.module ++ "*"
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
stay write-once-only. -/
def render (jsonPath docsDir : System.FilePath) (jekyll : Bool) : IO Unit := do
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
  let mut moduleNames : Array String := #[]
  for (moduleName, decls) in groupDeclsByModule metas do
    moduleNames := moduleNames.push moduleName
    let path := referenceDir / moduleToDocPath moduleName
    if let some dir := path.parent then
      IO.FS.createDirAll dir
    IO.FS.writeFile path (renderModulePage moduleName decls jekyll)
  IO.FS.writeFile (referenceDir / "modules.md") (renderModulesPage moduleNames jekyll)
  IO.FS.writeFile (docsDir / "toc.md") (renderToc metas jekyll)
  ensureRootIndex docsDir jekyll
  IO.println s!"LeanDoc: rendered {moduleNames.size} module page(s) to {referenceDir}"

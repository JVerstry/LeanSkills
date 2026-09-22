# LeanDoc.Core

### `LeanDocConfig`

*structure*

```lean
LeanDocConfig : Type
```

`leandoc.toml`'s parsed shape (task T8). All fields have defaults so
a project can omit the file entirely, or any section/field within it —
`include` is the only field with no *useful* default on its own (an
empty list falls back to whole-package scanning, task T21). 

### `LeanDocConfig.mk`

*constructor*

```lean
LeanDocConfig.mk : System.FilePath → System.FilePath → Array String → Array String → String → LeanDocConfig
```

*(not documented)*

### `LeanDocConfig.jsonDir`

*def*

```lean
LeanDocConfig.jsonDir : LeanDocConfig → System.FilePath
```

*(not documented)*

### `LeanDocConfig.docsDir`

*def*

```lean
LeanDocConfig.docsDir : LeanDocConfig → System.FilePath
```

*(not documented)*

### `LeanDocConfig.includeModules`

*def*

```lean
LeanDocConfig.includeModules : LeanDocConfig → Array String
```

*(not documented)*

### `LeanDocConfig.exclude`

*def*

```lean
LeanDocConfig.exclude : LeanDocConfig → Array String
```

*(not documented)*

### `LeanDocConfig.rendererName`

*def*

```lean
LeanDocConfig.rendererName : LeanDocConfig → String
```

Reserved for a future renderer choice — Markdown is the only one
that exists, so this isn't acted on yet. 

### `instInhabitedLeanDocConfig.default`

*def*

```lean
instInhabitedLeanDocConfig.default : LeanDocConfig
```

*(not documented)*

### `instInhabitedLeanDocConfig`

*def*

```lean
instInhabitedLeanDocConfig : Inhabited LeanDocConfig
```

*(not documented)*

### `loadConfig`

*def*

```lean
loadConfig : System.FilePath → IO LeanDocConfig
```

Loads `<projectRoot>/leandoc.toml`, falling back to
`LeanDocConfig`'s defaults if the file is missing or fails to parse.
Reuses Lake's own TOML parser/decoder (`Lake.Toml`) — the same one
`lakefile.toml` itself is parsed with — rather than hand-rolling one. 

### `moduleToFile`

*def*

```lean
moduleToFile : System.FilePath → Lean.Name → System.FilePath
```

Maps a module name to its source file, assuming the plain Lean
convention (`Foo.Bar` ↔ `<root>/Foo/Bar.lean`) — no `srcDir` override
support yet. 

### `fileToModuleName`

*def*

```lean
fileToModuleName : System.FilePath → System.FilePath → Lean.Name
```

Maps a source file back to its dotted module name, the inverse of
`moduleToFile` — used by whole-package scanning (task T21) to name files
it discovers rather than was told about. Built from `FilePath.parent`
(for the namespace prefix) and `FilePath.fileStem` (for the last
component) rather than manual string surgery on the path, so it doesn't
care whether the path uses `/` or `\` — the same class of bug T9 hit
building *links* out of raw `FilePath` strings, avoided here by not
doing that in the first place. 

### `discoverModules`

*def*

```lean
discoverModules : System.FilePath → IO (Array String)
```

Whole-package scanning (task T21): when `leandoc.toml` doesn't list
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
files actually exist" requires. 

### `stringToModuleName`

*def*

```lean
stringToModuleName : String → Lean.Name
```

Builds a hierarchical `Name` (`Foo.Bar`) from its dotted-string form
(`"Foo.Bar"`), as `leandoc.toml`'s `[modules] include` entries are
written. 

### `DeclRange`

*structure*

```lean
DeclRange : Type
```

A declaration's source location. Line is 1-indexed and column is
0-indexed, matching Lean's own `Position` (and LSP, for `charUtf16`-free
consumers) — deliberately not reinvented here. 

### `DeclRange.mk`

*constructor*

```lean
DeclRange.mk : Nat → Nat → Nat → Nat → DeclRange
```

*(not documented)*

### `DeclRange.startLine`

*def*

```lean
DeclRange.startLine : DeclRange → Nat
```

*(not documented)*

### `DeclRange.startColumn`

*def*

```lean
DeclRange.startColumn : DeclRange → Nat
```

*(not documented)*

### `DeclRange.endLine`

*def*

```lean
DeclRange.endLine : DeclRange → Nat
```

*(not documented)*

### `DeclRange.endColumn`

*def*

```lean
DeclRange.endColumn : DeclRange → Nat
```

*(not documented)*

### `instToJsonDeclRange.toJson`

*def*

```lean
instToJsonDeclRange.toJson : DeclRange → Lean.Json
```

*(not documented)*

### `instToJsonDeclRange`

*def*

```lean
instToJsonDeclRange : Lean.ToJson DeclRange
```

*(not documented)*

### `instFromJsonDeclRange.fromJson`

*def*

```lean
instFromJsonDeclRange.fromJson : Lean.Json → Except String DeclRange
```

*(not documented)*

### `instFromJsonDeclRange`

*def*

```lean
instFromJsonDeclRange : Lean.FromJson DeclRange
```

*(not documented)*

### `DeclMeta`

*structure*

```lean
DeclMeta : Type
```

One extracted declaration: the T7 schema, refined by T9. T9 added
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


### `DeclMeta.mk`

*constructor*

```lean
DeclMeta.mk : String → String → String → String → Option String → Option DeclRange → DeclMeta
```

*(not documented)*

### `DeclMeta.module`

*def*

```lean
DeclMeta.module : DeclMeta → String
```

*(not documented)*

### `DeclMeta.name`

*def*

```lean
DeclMeta.name : DeclMeta → String
```

*(not documented)*

### `DeclMeta.kind`

*def*

```lean
DeclMeta.kind : DeclMeta → String
```

*(not documented)*

### `DeclMeta.type`

*def*

```lean
DeclMeta.type : DeclMeta → String
```

*(not documented)*

### `DeclMeta.docString`

*def*

```lean
DeclMeta.docString : DeclMeta → Option String
```

*(not documented)*

### `DeclMeta.range`

*def*

```lean
DeclMeta.range : DeclMeta → Option DeclRange
```

*(not documented)*

### `instToJsonDeclMeta.toJson`

*def*

```lean
instToJsonDeclMeta.toJson : DeclMeta → Lean.Json
```

*(not documented)*

### `instToJsonDeclMeta`

*def*

```lean
instToJsonDeclMeta : Lean.ToJson DeclMeta
```

*(not documented)*

### `instFromJsonDeclMeta.fromJson`

*def*

```lean
instFromJsonDeclMeta.fromJson : Lean.Json → Except String DeclMeta
```

*(not documented)*

### `instFromJsonDeclMeta`

*def*

```lean
instFromJsonDeclMeta : Lean.FromJson DeclMeta
```

*(not documented)*

### `kindString`

*def*

```lean
kindString : Lean.Environment → Lean.Name → Lean.ConstantKind → String
```

Human-readable declaration kind. `structure` vs `inductive` isn't
distinguishable from `ConstantKind` alone (a structure *is* a
single-constructor inductive under the hood) — `Lean.isStructure` is
Lean's own way of telling them apart. 

### `declMetaOf`

*def*

```lean
declMetaOf : Lean.Environment → Lean.Name → Lean.AsyncConstantInfo → Lean.CoreM DeclMeta
```

Extracts one declaration's metadata. Runs in `CoreM` because
`Lean.isAutoDeclOrPrivate_Internal` (the noise filter, see `isNoise`
below) and type pretty-printing both need it. 

### `isNoise`

*def*

```lean
isNoise : Lean.AsyncConstantInfo → Lean.CoreM Bool
```

Whether `c` is Lean-generated scaffolding (recursors, `noConfusion`,
`injEq`, `_sizeOf_*`, equation lemmas, ...) rather than something a human
wrote — see T7 in `wip/todo.md`. Uses Lean's own
`isAutoDeclOrPrivate_Internal` (the same predicate Lean's environment
linter uses to count auto-generated declarations) plus a direct
recursor check, rather than reinventing name-suffix heuristics; verified
against the demo project's `MyLeanStructure` (which exercises all of the
above) that this correctly keeps only the 7 real declarations out of 21
total. 

### `extractFile`

*def*

```lean
extractFile : System.FilePath → Lean.Name → IO (Array DeclMeta)
```

Extracts every non-noise declaration added by elaborating `file` as
module `moduleName`. 

### `moduleToDocPath`

*def*

```lean
moduleToDocPath : String → System.FilePath
```

Maps a dotted module name string (as stored in `DeclMeta.module`) to
a relative doc path, e.g. `"Demo.MyLeanFile"` ↦ `Demo/MyLeanFile.md` —
mirrors `moduleToFile`'s convention but for Markdown output. 

### `renderDecl`

*def*

```lean
renderDecl : DeclMeta → String
```

Renders one declaration as a Markdown section: a heading, the
signature as a code block, and the docstring (or an explicit "not
documented" note — silently omitting undocumented declarations would
hide exactly the coverage gaps T17's audit is meant to catch). 

### `renderModulePage`

*def*

```lean
renderModulePage : String → Array DeclMeta → String
```

Renders one module's page: a heading plus every declaration's
section, in the order the extractor emitted them (elaboration order —
see `Environment.getLocalConstantInfos`). 

### `renderIndexPage`

*def*

```lean
renderIndexPage : Array String → String
```

Renders the API section's index: one line per module, linking to
its page. Deliberately minimal — task T18 covers a real table of
contents/glossary; this is just enough for the module pages to be
reachable at all.

Link targets are built as plain `/`-joined strings, not via
`moduleToDocPath`'s `System.FilePath` — a Markdown/web link needs `/`
regardless of host OS, but `FilePath`'s string rendering uses the native
separator (`\` on Windows), which would silently break these links only
on Windows. 

### `groupDeclsByModule`

*def*

```lean
groupDeclsByModule : Array DeclMeta → Array (String × Array DeclMeta)
```

Groups declarations by module, preserving first-seen module order
(there's no `Array.groupByKey` in the stdlib to reach for here). 

### `render`

*def*

```lean
render : System.FilePath → System.FilePath → IO Unit
```

Reads `jsonPath` back off disk (not the extractor's in-memory
result — see the module docstring), groups declarations by module, and
writes one Markdown page per module plus an index, under
`docsDir/api/`. 

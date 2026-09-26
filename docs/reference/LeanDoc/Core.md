---
layout: default
---

# LeanDoc.Core

**Imported by:** [Main]({% link reference/Main.md %})

### `LeanDocConfig`

*structure*

```lean
LeanDocConfig : Type
```

`leandoc.toml`'s parsed shape (task T8). All fields have defaults so
a project can omit the file entirely, or any section/field within it —
`include` is the only field with no *useful* default on its own (an
empty list falls back to whole-package scanning, task T21). 

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L31-L76)

### `LeanDocConfig.mk`

*constructor*

```lean
LeanDocConfig.mk : System.FilePath →
  System.FilePath → Array String → Array String → String → Bool → Bool → String → String → String → LeanDocConfig
```

*(not documented)*

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L35-L35)

### `LeanDocConfig.jsonDir`

*def*

```lean
LeanDocConfig.jsonDir : LeanDocConfig → System.FilePath
```

*(not documented)*

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L36-L36)

### `LeanDocConfig.docsDir`

*def*

```lean
LeanDocConfig.docsDir : LeanDocConfig → System.FilePath
```

*(not documented)*

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L37-L37)

### `LeanDocConfig.includeModules`

*def*

```lean
LeanDocConfig.includeModules : LeanDocConfig → Array String
```

*(not documented)*

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L38-L38)

### `LeanDocConfig.exclude`

*def*

```lean
LeanDocConfig.exclude : LeanDocConfig → Array String
```

*(not documented)*

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L39-L39)

### `LeanDocConfig.rendererName`

*def*

```lean
LeanDocConfig.rendererName : LeanDocConfig → String
```

Reserved for a future renderer choice — Markdown is the only one
that exists, so this isn't acted on yet. 

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L42-L42)

### `LeanDocConfig.rendererJekyll`

*def*

```lean
LeanDocConfig.rendererJekyll : LeanDocConfig → Bool
```

Whether generated pages target Jekyll (task T31): front matter,
`{% link %}` internal links, and a written `_config.yml` (task
T22/T28) vs. plain portable Markdown with plain relative links and no
`_config.yml`. Defaults to `true` since `docs_dir` is committed to git
for GitHub Pages by default (T15/T22), and GitHub Pages runs Jekyll by
default — set to `false` for output meant to be read as plain
Markdown (an IDE, a non-Jekyll/non-Pages host) instead. 

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L50-L50)

### `LeanDocConfig.complianceEnabled`

*def*

```lean
LeanDocConfig.complianceEnabled : LeanDocConfig → Bool
```

Task T41: the overall opt-in/opt-out toggle for documentation-
convention/compliance checks derived from Mathlib's own style
guidelines (currently just the copyright/license header check below
— naming-conventions and docstring-quality checks are designed but
not built yet, pending task T42). Off by default: most projects
aren't Mathlib and shouldn't be held to its conventions unless they
explicitly ask. 

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L58-L58)

### `LeanDocConfig.complianceAuthor`

*def*

```lean
LeanDocConfig.complianceAuthor : LeanDocConfig → String
```

Task T41: the author name(s) `checkComplianceHeader` expects to
find in each file's copyright header when `complianceEnabled` is
true. Empty skips the author-specific part of that check even when
compliance checking is otherwise on (nothing configured to check
against). 

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L64-L64)

### `LeanDocConfig.complianceLicense`

*def*

```lean
LeanDocConfig.complianceLicense : LeanDocConfig → String
```

Task T41: the license string `checkComplianceHeader` expects to
find in each file's copyright header. Same empty-skips treatment as
`complianceAuthor`. 

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L68-L68)

### `LeanDocConfig.projectVersion`

*def*

```lean
LeanDocConfig.projectVersion : LeanDocConfig → String
```

Task T27: the project's own release version, e.g. `"1.2.0"` —
manually set, not auto-detected. Empty (the default) means "not
tracked," and `checkVersionTag` skips its check entirely rather than
warning about a version nobody configured. Only ever compared against
the project's latest git tag, never rendered anywhere a reader would
see it — see `checkVersionTag`'s doc comment for why. 

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L75-L75)

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

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L76-L76)

### `loadConfig`

*def*

```lean
loadConfig : System.FilePath → IO LeanDocConfig
```

Loads `<projectRoot>/leandoc.toml`, falling back to
`LeanDocConfig`'s defaults if the file is missing or fails to parse.
Reuses Lake's own TOML parser/decoder (`Lake.Toml`) — the same one
`lakefile.toml` itself is parsed with — rather than hand-rolling one. 

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L79-L119)

### `moduleToFile`

*def*

```lean
moduleToFile : System.FilePath → Lean.Name → System.FilePath
```

Maps a module name to its source file, assuming the plain Lean
convention (`Foo.Bar` ↔ `<root>/Foo/Bar.lean`) — no `srcDir` override
support yet. 

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L121-L126)

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

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L128-L139)

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

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L142-L195)

### `stringToModuleName`

*def*

```lean
stringToModuleName : String → Lean.Name
```

Builds a hierarchical `Name` (`Foo.Bar`) from its dotted-string form
(`"Foo.Bar"`), as `leandoc.toml`'s `[modules] include` entries are
written. 

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L197-L201)

### `DeclRange`

*structure*

```lean
DeclRange : Type
```

A declaration's source location. Line is 1-indexed and column is
0-indexed, matching Lean's own `Position` (and LSP, for `charUtf16`-free
consumers) — deliberately not reinvented here. 

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L203-L211)

### `DeclRange.mk`

*constructor*

```lean
DeclRange.mk : Nat → Nat → Nat → Nat → DeclRange
```

*(not documented)*

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L206-L206)

### `DeclRange.startLine`

*def*

```lean
DeclRange.startLine : DeclRange → Nat
```

*(not documented)*

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L207-L207)

### `DeclRange.startColumn`

*def*

```lean
DeclRange.startColumn : DeclRange → Nat
```

*(not documented)*

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L208-L208)

### `DeclRange.endLine`

*def*

```lean
DeclRange.endLine : DeclRange → Nat
```

*(not documented)*

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L209-L209)

### `DeclRange.endColumn`

*def*

```lean
DeclRange.endColumn : DeclRange → Nat
```

*(not documented)*

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L210-L210)

### `instToJsonDeclRange.toJson`

*def*

```lean
instToJsonDeclRange.toJson : DeclRange → Lean.Json
```

*(not documented)*

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L211-L211)

### `instToJsonDeclRange`

*def*

```lean
instToJsonDeclRange : Lean.ToJson DeclRange
```

*(not documented)*

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L211-L211)

### `instFromJsonDeclRange.fromJson`

*def*

```lean
instFromJsonDeclRange.fromJson : Lean.Json → Except String DeclRange
```

*(not documented)*

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L211-L211)

### `instFromJsonDeclRange`

*def*

```lean
instFromJsonDeclRange : Lean.FromJson DeclRange
```

*(not documented)*

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L211-L211)

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


[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L213-L239)

### `DeclMeta.mk`

*constructor*

```lean
DeclMeta.mk : String → String → String → String → Option String → Option DeclRange → Option String → DeclMeta
```

*(not documented)*

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L226-L226)

### `DeclMeta.module`

*def*

```lean
DeclMeta.module : DeclMeta → String
```

*(not documented)*

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L227-L227)

### `DeclMeta.name`

*def*

```lean
DeclMeta.name : DeclMeta → String
```

*(not documented)*

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L228-L228)

### `DeclMeta.kind`

*def*

```lean
DeclMeta.kind : DeclMeta → String
```

*(not documented)*

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L229-L229)

### `DeclMeta.type`

*def*

```lean
DeclMeta.type : DeclMeta → String
```

*(not documented)*

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L230-L230)

### `DeclMeta.docString`

*def*

```lean
DeclMeta.docString : DeclMeta → Option String
```

*(not documented)*

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L231-L231)

### `DeclMeta.range`

*def*

```lean
DeclMeta.range : DeclMeta → Option DeclRange
```

*(not documented)*

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L232-L232)

### `DeclMeta.instanceOf`

*def*

```lean
DeclMeta.instanceOf : DeclMeta → Option String
```

The class this declaration is a registered instance *of* (task
T48), e.g. `some "Inhabited"` for an `instance : Inhabited Foo`.
`none` for anything that isn't a registered instance, or whose
conclusion's head isn't itself a class (shouldn't happen for a
well-formed instance, but not asserted). See `instanceClassOf`. 

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L238-L238)

### `instToJsonDeclMeta.toJson`

*def*

```lean
instToJsonDeclMeta.toJson : DeclMeta → Lean.Json
```

*(not documented)*

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L239-L239)

### `instToJsonDeclMeta`

*def*

```lean
instToJsonDeclMeta : Lean.ToJson DeclMeta
```

*(not documented)*

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L239-L239)

### `instFromJsonDeclMeta.fromJson`

*def*

```lean
instFromJsonDeclMeta.fromJson : Lean.Json → Except String DeclMeta
```

*(not documented)*

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L239-L239)

### `instFromJsonDeclMeta`

*def*

```lean
instFromJsonDeclMeta : Lean.FromJson DeclMeta
```

*(not documented)*

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L239-L239)

### `kindString`

*def*

```lean
kindString : Lean.Environment → Lean.Name → Lean.ConstantKind → String
```

Human-readable declaration kind. `structure` vs `inductive` isn't
distinguishable from `ConstantKind` alone (a structure *is* a
single-constructor inductive under the hood) — `Lean.isStructure` is
Lean's own way of telling them apart. 

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L241-L253)

### `instanceClassOf`

*def*

```lean
instanceClassOf : Lean.Environment → Lean.Name → Lean.Expr → Lean.CoreM (Option String)
```

The class `declName` is a registered instance *of*, if any (task
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
was left for a later pass rather than guessed at now. 

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L255-L278)

### `declMetaOf`

*def*

```lean
declMetaOf : Lean.Environment → Lean.Name → Lean.AsyncConstantInfo → Lean.CoreM DeclMeta
```

Extracts one declaration's metadata. Runs in `CoreM` because
`Lean.isAutoDeclOrPrivate_Internal` (the noise filter, see `isNoise`
below) and type pretty-printing both need it. 

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L280-L292)

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
`declMetaOf` already uses for `Meta.ppExpr`. 

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L294-L348)

### `leandocIgnoreAttr`

*opaque*

```lean
leandocIgnoreAttr : Lean.TagAttribute
```

Task T19: `@[leandoc_ignore]` marks a declaration as *deliberately*
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
right thing here. 

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L350-L374)

### `isDeliberatelyIgnored`

*def*

```lean
isDeliberatelyIgnored : Lean.Environment → Lean.Name → Bool
```

Whether `declName` was tagged `@[leandoc_ignore]` (task T19) — see
`leandocIgnoreAttr`. 

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L376-L379)

### `extractFile`

*def*

```lean
extractFile : System.FilePath → Lean.Name → IO (Array DeclMeta)
```

Extracts every non-noise, non-`@[leandoc_ignore]`'d declaration
added by elaborating `file` as module `moduleName`. 

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L381-L409)

### `hasCopyrightHeader`

*def*

```lean
hasCopyrightHeader : String → String → String → Bool
```

Whether `source`'s header mentions the expected author/license
(task T41) — checked as plain substring presence within the file's
first 1000 characters (generous enough to cover a real header without
scanning the whole file), not a strict parse of Mathlib's exact
copyright-header grammar (`/- Copyright (c) YEAR Name. ... Authors:
... -/`). A header lives before any declaration, so this is a genuine
gap in what `DeclMeta`-based extraction can see at all — a separate,
purely textual check, not something bolted onto `extractFile`. Empty
`expectedAuthor`/`expectedLicense` skip that part of the check
(nothing configured to check against); always requires the literal
word "Copyright" to appear, regardless. 

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L411-L427)

### `checkComplianceHeader`

*def*

```lean
checkComplianceHeader : LeanDocConfig → System.FilePath → IO Unit
```

Warns (never fails the build) on stderr if `file` is missing its
expected copyright/license header, per `config`'s `[compliance]`
settings (task T41). A no-op unless `complianceEnabled` is true *and*
at least one of `complianceAuthor`/`complianceLicense` is actually
configured — otherwise there's nothing meaningful to check against,
and a bare "missing Copyright" warning on every file would be noise
for a project that never asked for this. 

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L429-L441)

### `normalizeVersion`

*def*

```lean
normalizeVersion : String → String
```

Strips a single leading `v`/`V` (e.g. `"v1.2.0"` → `"1.2.0"`), so a
git tag written either way compares equal to a plain `[project]
version` value (task T27). 

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L443-L447)

### `checkVersionTag`

*def*

```lean
checkVersionTag : LeanDocConfig → System.FilePath → IO Unit
```

Warns (never fails the build) on stderr if `[project] version`
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
reader-facing stamp was dropped in favor of this instead. 

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L449-L471)

### `parseGithubOwnerRepo`

*def*

```lean
parseGithubOwnerRepo : String → Option String
```

Parses a git remote URL into `"owner/repo"`, if — and only if — it's
recognizably a GitHub URL (task T46). Handles the two common forms:
`git@github.com:owner/repo.git` (SSH) and `https://github.com/owner/
repo[.git]` (HTTPS). Deliberately `none` for anything else, including
other hosts (GitLab, Codeberg, self-hosted Gitea, ...) — those use
different source-line-range URL schemes, and a wrong guess is worse
than no link at all. 

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L473-L490)

### `githubSourceBaseUrl`

*def*

```lean
githubSourceBaseUrl : System.FilePath → IO (Option String)
```

Attempts to build a GitHub "blob" URL prefix for jump-to-source
links (task T46), e.g. `"https://github.com/owner/repo/blob/<commit>"`
— `none` if `projectRoot` isn't a git repo, has no `origin` remote, or
that remote isn't recognizably GitHub (`parseGithubOwnerRepo`).
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
correct from reading the code alone. 

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L492-L525)

### `parseLeanPathFromLakeEnv`

*def*

```lean
parseLeanPathFromLakeEnv : String → System.SearchPath
```

Extracts `LEAN_PATH`'s value from `lake env`'s output (one
`NAME=value` line per variable), parsed with the platform's own
search-path separator. `[]` if there's no such line. 

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L527-L534)

### `projectSearchPath`

*def*

```lean
projectSearchPath : System.FilePath → IO System.SearchPath
```

The target project's own module search path (task T54), as Lake
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
Returns `[]`, with a warning, if `lake env` fails. 

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L536-L558)

### `buildProjectModules`

*def*

```lean
buildProjectModules : System.FilePath → Array String → IO Bool
```

Builds `modules` in the target project with Lake (`lake build
+Mod …`, run in `projectRoot`) before extraction (task T54), so the
`.olean`s `projectSearchPath` points at exist and aren't stale: a
module `import`ing a sibling resolves against that sibling's compiled
`.olean`, never its source. Builds exactly the documented modules (and,
transitively, whatever they import) rather than the project's default
targets, which needn't cover every documented module. A no-op when
everything's already up to date. Lake's own progress output goes
straight to the terminal — a first build can take a while. Returns
whether the build succeeded; docs can't be generated from code that
doesn't compile, the same requirement doc-gen4 has. 

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L560-L576)

### `moduleImports`

*def*

```lean
moduleImports : System.FilePath → IO (Array String)
```

A module's own direct imports, read straight off its source file
(task T50) via `Lean.parseImports'` — the same fast header-only parser
Lake itself uses to resolve a module's dependencies, not hand-rolled
text scanning, and considerably cheaper than a full `runFrontend` just
to read `import` lines. Returns dotted module name strings, matching
`DeclMeta.module`'s own convention. 

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L578-L587)

### `buildImportedByMap`

*def*

```lean
buildImportedByMap : Std.HashMap String (Array String) → Std.HashMap String (Array String)
```

Inverts a module → its-own-imports map into module → modules-that-
import-it (task T50's "imported by"), restricted to modules that are
themselves documented — an import of `Init`/`Lean`/a dependency
outside the project isn't something LeanDoc has a page for, so it's
silently dropped rather than rendered as a dead link. 

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L589-L602)

### `moduleToDocPath`

*def*

```lean
moduleToDocPath : String → System.FilePath
```

Maps a dotted module name string (as stored in `DeclMeta.module`) to
a relative doc path, e.g. `"Demo.MyLeanFile"` ↦ `Demo/MyLeanFile.md` —
mirrors `moduleToFile`'s convention but for Markdown output. 

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L612-L616)

### `linkPath`

*def*

```lean
linkPath : String → String
```

Same mapping as `moduleToDocPath`, but as a plain `/`-joined string
rather than a `System.FilePath` — a Markdown/web link needs `/`
regardless of host OS, but `FilePath`'s string rendering uses the
native separator (`\` on Windows), which would silently break links
only on Windows (T9's original bug). Shared by every link-building
function below rather than each redefining it locally. 

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L618-L626)

### `renderDecl`

*def*

```lean
renderDecl : DeclMeta → Option String → Std.HashMap String (Array DeclMeta) → String
```

Renders one declaration as a Markdown section: a heading, the
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
non-GitHub remote) — silently omit the link then, not an error. 

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L628-L663)

### `frontMatter`

*def*

```lean
frontMatter : String
```

Jekyll (task T22/T28) only converts a Markdown file at all — running
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
by `ensureDefaultLayout`. 

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L665-L679)

### `renderImportedBy`

*def*

```lean
renderImportedBy : String → Bool → Std.HashMap String (Array String) → Option String
```

Renders the "Imported by" line for a module's page (task T50):
which other *documented* modules import this one, if any — `none` when
nothing does, so `renderModulePage` can omit the line entirely rather
than print an empty "Imported by:". Links use the same `jekyll`
branching every other renderer here follows. 

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L681-L695)

### `renderModulePage`

*def*

```lean
renderModulePage : String →
  Array DeclMeta →
    Bool → Option String → Std.HashMap String (Array DeclMeta) → Std.HashMap String (Array String) → String
```

Renders one module's page: a heading, an optional "Imported by"
line (task T50), plus every declaration's section, in the order the
extractor emitted them (elaboration order — see
`Environment.getLocalConstantInfos`). `jekyll` (task T31) controls
whether front matter is prepended — `false` produces plain portable
Markdown with no Jekyll-specific content at all. `sourceBaseUrl` (task
T46) is threaded through to `renderDecl` for jump-to-source links. 

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L697-L713)

### `ModuleTree`

*inductive*

```lean
ModuleTree : Type
```

One node of the module tree (task T49): a namespace segment,
its own module page if one exists exactly at this path (`some m` for
a leaf like `Demo.MyLeanFile`; `none` for a pure namespace prefix like
`Demo` when nothing is documented at `Demo` itself), and its children
keyed by the *next* path segment. Built purely by splitting each
module's dotted name on `.` — no separate hierarchy-tracking needed,
since Lean's own module naming already encodes it. 

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L715-L723)

### `ModuleTree.node`

*constructor*

```lean
ModuleTree.node : Array (String × ModuleTree) → Option String → ModuleTree
```

*(not documented)*

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L723-L723)

### `ModuleTree.empty`

*def*

```lean
ModuleTree.empty : ModuleTree
```

*(not documented)*

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L725-L725)

### `insertModule`

*opaque*

```lean
insertModule : ModuleTree → List String → String → ModuleTree
```

*(not documented)*

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L727-L736)

### `buildModuleTree`

*def*

```lean
buildModuleTree : Array String → ModuleTree
```

Builds the module tree from the flat list `render` already has —
every module's dotted name, split on `.`. 

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L738-L741)

### `renderModuleTreeNode`

*opaque*

```lean
renderModuleTreeNode : String → ModuleTree → Bool → String
```

Renders one tree node as a nested `<li>`, natively-collapsible via
`<details>`/`<summary>` — no JS needed for the collapse mechanism
itself, mirroring doc-gen4's own choice there. Children are sorted
alphabetically by segment at each level. A leaf module's segment is a
link (Jekyll `{% link %}` or a plain relative link, same `jekyll`
branching every other renderer here already uses); a pure namespace
prefix with no module of its own (e.g. `Demo` when only
`Demo.MyLeanFile` is documented) renders as plain, unlinked text. 

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L743-L767)

### `renderModuleTree`

*def*

```lean
renderModuleTree : Array String → Bool → String
```

Renders the whole module tree as a `<ul>` of top-level namespace
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
to on this page in the first place. 

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L769-L789)

### `renderModulesPage`

*def*

```lean
renderModulesPage : Array String → Bool → String
```

Renders the list of documented modules, linking to its page.
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
equivalent worth inventing here. 

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L791-L826)

### `kindBucket`

*def*

```lean
kindBucket : String → String
```

Buckets a declaration's `kind` (see `kindString`) into one of the
table of contents' four groups. Every `kindString` output maps to
exactly one bucket — `"quotient"`/`"recursor"` are rare enough to share
"Other" rather than each getting a barely-populated section of their
own. 

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L828-L838)

### `renderToc`

*def*

```lean
renderToc : Array DeclMeta → Bool → String
```

Renders a flat, project-wide table of contents (task T18): every
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
empty heading. 

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L840-L879)

### `SearchEntry`

*structure*

```lean
SearchEntry : Type
```

One entry in the site-wide search index (task T47) — deliberately
narrower than `DeclMeta`: just enough for `assets/search.js` to filter
by name and render a result (`kind`/`module` as a label, `link` to jump
to it). `link` is site-root-relative, no leading slash (`search.js`
prefixes it with `LEANDOC_BASEURL` itself) — `"reference/" ++ linkPath
module ++ ".html"`, matching Jekyll's default converted-file naming
(`.md` sources become same-path `.html` outputs) the same way
`renderModulesPage`'s `{% link %}` tags already rely on. 

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L881-L894)

### `SearchEntry.mk`

*constructor*

```lean
SearchEntry.mk : String → String → String → String → SearchEntry
```

*(not documented)*

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L889-L889)

### `SearchEntry.name`

*def*

```lean
SearchEntry.name : SearchEntry → String
```

*(not documented)*

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L890-L890)

### `SearchEntry.kind`

*def*

```lean
SearchEntry.kind : SearchEntry → String
```

*(not documented)*

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L891-L891)

### `SearchEntry.module`

*def*

```lean
SearchEntry.module : SearchEntry → String
```

*(not documented)*

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L892-L892)

### `SearchEntry.link`

*def*

```lean
SearchEntry.link : SearchEntry → String
```

*(not documented)*

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L893-L893)

### `instToJsonSearchEntry.toJson`

*def*

```lean
instToJsonSearchEntry.toJson : SearchEntry → Lean.Json
```

*(not documented)*

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L894-L894)

### `instToJsonSearchEntry`

*def*

```lean
instToJsonSearchEntry : Lean.ToJson SearchEntry
```

*(not documented)*

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L894-L894)

### `instFromJsonSearchEntry.fromJson`

*def*

```lean
instFromJsonSearchEntry.fromJson : Lean.Json → Except String SearchEntry
```

*(not documented)*

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L894-L894)

### `instFromJsonSearchEntry`

*def*

```lean
instFromJsonSearchEntry : Lean.FromJson SearchEntry
```

*(not documented)*

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L894-L894)

### `renderSearchIndex`

*def*

```lean
renderSearchIndex : Array DeclMeta → String
```

Renders `docs_dir/assets/search-index.json` (task T47): one compact
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
nobody reads. 

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L896-L912)

### `ensureSearchScript`

*def*

```lean
ensureSearchScript : System.FilePath → IO Unit
```

Ensures `docsDir/assets/search.js` exists, writing the client-side
search script (task T47 — see `assets/search.js`,
`LeanDoc.Assets.searchJs`) if it's missing. Never overwrites an
existing file, same write-once treatment as `ensureStyleAsset`. 

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L914-L923)

### `ensureMathjaxConfig`

*def*

```lean
ensureMathjaxConfig : System.FilePath → IO Unit
```

Ensures `docsDir/assets/mathjax-config.js` exists, writing the
MathJax delimiter configuration (task T51 — see
`assets/mathjax-config.js`, `LeanDoc.Assets.mathjaxConfigJs`) if it's
missing. Never overwrites an existing file, same write-once treatment
as `ensureStyleAsset`. MathJax's own renderer script is loaded
directly from its CDN in the layout, not vendored — unlike the other
assets here, it's a large, versioned third-party library, not
something a project would ever want to hand-edit after the fact. 

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L925-L938)

### `ensureFindPage`

*def*

```lean
ensureFindPage : System.FilePath → IO Unit
```

Ensures `docsDir/find.html` exists, writing the stable-permalink
redirect page (task T52 — see `assets/find.html`,
`LeanDoc.Assets.findHtml`) if it's missing. Lives at the site root
(not under `assets/`, unlike the other write-once JS/CSS here), since
`/find.html?pattern=<Name>` is meant to be a stable, memorable URL
external links target directly. Never overwrites an existing file,
same write-once treatment as `ensureStyleAsset`. Depends on
`assets/search-index.json` existing to look anything up in, so only
meaningful for Jekyll output — same as `ensureSearchScript`. 

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L940-L953)

### `ensureNotFoundPage`

*def*

```lean
ensureNotFoundPage : System.FilePath → IO Unit
```

Ensures `docsDir/404.html` exists, writing a friendlier 404 page
(task T53 — see `assets/404.html`, `LeanDoc.Assets.notFoundHtml`) if
it's missing. GitHub Pages serves this file automatically for any
unmatched path, so it needs no wiring beyond existing at this exact
path. Suggests plausible declarations from `assets/search-index.json`
(task T47) based on the broken URL's own last path segment — a simple
substring match, not real fuzzy matching, same scoping decision T47
itself made. Never overwrites an existing file, same write-once
treatment as `ensureStyleAsset`. Only meaningful for Jekyll output,
same as `ensureFindPage`/`ensureSearchScript`. 

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L955-L969)

### `navMarkerStart`

*def*

```lean
navMarkerStart : String
```

The auto-managed navigation region inside `docs_dir/index.md`
(task T18) — delimited by these markers so `ensureRootIndex` can keep
it current as LeanDoc's own generated pages grow (a plain "write once,
never touch again" file, like `_config.yml`, would go stale the moment
a new generated page type ships, even for a user who never customized
anything) without disturbing any hand-written content around it. 

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L971-L977)

### `navMarkerEnd`

*def*

```lean
navMarkerEnd : String
```

*(not documented)*

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L978-L978)

### `renderNavBlock`

*def*

```lean
renderNavBlock : Bool → String
```

Renders the nav block's current contents, markers included. 

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L980-L984)

### `ensureRootIndex`

*def*

```lean
ensureRootIndex : System.FilePath → Bool → IO Unit
```

Ensures `docsDir/index.md` — the site's actual root page — exists
and links to the generated `reference/`/`toc.md` pages. Three cases:
- **Missing entirely**: create a minimal page with just the nav block.
- **Exists, contains the nav markers**: replace only what's between
  them with a freshly rendered block, leaving everything outside it
  (a hand-written intro, whatever else) untouched.
- **Exists, no markers** (a hand-written page that predates this
  mechanism): leave it completely alone. Silently injecting content
  into a page someone hand-curated would be worse than an out-of-date
  link — the fix there is adding the markers once, by hand, not having
  LeanDoc decide where to put them. 

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L986-L1011)

### `groupInstancesByClass`

*def*

```lean
groupInstancesByClass : Array DeclMeta → Std.HashMap String (Array DeclMeta)
```

Groups instance declarations by the class they're an instance of
(task T48 — see `instanceClassOf`), for `renderDecl`'s "Instances"
section. Project-wide, not per-module: an instance can (and often
does) live in a different module than the class it's an instance of. 

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L1013-L1023)

### `groupDeclsByModule`

*def*

```lean
groupDeclsByModule : Array DeclMeta → Array (String × Array DeclMeta)
```

Groups declarations by module, preserving first-seen module order
(there's no `Array.groupByKey` in the stdlib to reach for here). 

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L1025-L1035)

### `defaultJekyllConfig`

*def*

```lean
defaultJekyllConfig : String
```

Minimal `_config.yml` written once. No `theme:`/`remote_theme:` key
(task T29 — dropped `jekyll-theme-minimal`): LeanDoc now ships its own
complete stylesheet and layout (`ensureStyleAsset`/
`ensureDefaultLayout`) rather than pulling in a GitHub Pages theme, so
there's nothing else `_config.yml` needs to say. Only ever written if
the file doesn't already exist — like `InstallationPrompt.txt`'s other
one-time setup steps, this must not clobber a customization on a later
`lake exe leandoc` run. 

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L1037-L1046)

### `ensureJekyllConfig`

*def*

```lean
ensureJekyllConfig : System.FilePath → IO Unit
```

Ensures `docsDir/_config.yml` exists, writing the default (see
`defaultJekyllConfig`) if it's missing. Never overwrites an existing
file. 

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L1048-L1054)

### `ensureStyleAsset`

*def*

```lean
ensureStyleAsset : System.FilePath → IO Unit
```

Ensures `docsDir/assets/style.css` exists, writing doc-gen4's
vendored stylesheet (task T29 — see `assets/style.css`,
`LeanDoc.Assets.styleCss`) if it's missing. Never overwrites an
existing file, so a project is free to edit it after that first write
— LeanDoc never touches it again. 

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L1056-L1066)

### `ensureDefaultLayout`

*def*

```lean
ensureDefaultLayout : System.FilePath → IO Unit
```

Ensures `docsDir/_layouts/default.html` exists, writing LeanDoc's
minimal layout (task T29 — see `assets/layouts/default.html`,
`LeanDoc.Assets.defaultLayoutHtml`) if it's missing. Never overwrites
an existing file, same write-once treatment as `ensureStyleAsset`. 

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L1068-L1077)

### `ensureColorSchemeScript`

*def*

```lean
ensureColorSchemeScript : System.FilePath → IO Unit
```

Ensures `docsDir/assets/color-scheme.js` exists, writing the
light/dark/system theme switcher script (task T45 — see
`assets/color-scheme.js`, `LeanDoc.Assets.colorSchemeJs`) if it's
missing. Never overwrites an existing file, same write-once treatment
as `ensureStyleAsset`. 

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L1079-L1089)

### `render`

*def*

```lean
render : System.FilePath → System.FilePath → Bool → Option String → Std.HashMap String (Array String) → IO Unit
```

Reads `jsonPath` back off disk (not the extractor's in-memory
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
separate from the always-on Markdown writes above. 

[source](https://github.com/JVerstry/LeanDoc/blob/d3f1d0e06c86cfd28a8d1fb37f735ca018d84987/LeanDoc/Core.lean#L1091-L1170)

---
layout: default
---

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
LeanDocConfig.mk : System.FilePath →
  System.FilePath → Array String → Array String → String → Bool → Bool → String → String → String → LeanDocConfig
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

### `LeanDocConfig.complianceLicense`

*def*

```lean
LeanDocConfig.complianceLicense : LeanDocConfig → String
```

Task T41: the license string `checkComplianceHeader` expects to
find in each file's copyright header. Same empty-skips treatment as
`complianceAuthor`. 

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

### `isDeliberatelyIgnored`

*def*

```lean
isDeliberatelyIgnored : Lean.Environment → Lean.Name → Bool
```

Whether `declName` was tagged `@[leandoc_ignore]` (task T19) — see
`leandocIgnoreAttr`. 

### `extractFile`

*def*

```lean
extractFile : System.FilePath → Lean.Name → IO (Array DeclMeta)
```

Extracts every non-noise, non-`@[leandoc_ignore]`'d declaration
added by elaborating `file` as module `moduleName`. 

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

### `normalizeVersion`

*def*

```lean
normalizeVersion : String → String
```

Strips a single leading `v`/`V` (e.g. `"v1.2.0"` → `"1.2.0"`), so a
git tag written either way compares equal to a plain `[project]
version` value (task T27). 

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

### `moduleToDocPath`

*def*

```lean
moduleToDocPath : String → System.FilePath
```

Maps a dotted module name string (as stored in `DeclMeta.module`) to
a relative doc path, e.g. `"Demo.MyLeanFile"` ↦ `Demo/MyLeanFile.md` —
mirrors `moduleToFile`'s convention but for Markdown output. 

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

### `renderDecl`

*def*

```lean
renderDecl : DeclMeta → String
```

Renders one declaration as a Markdown section: a heading, the
signature as a code block, and the docstring (or an explicit "not
documented" note — silently omitting undocumented declarations would
hide exactly the coverage gaps T17's audit is meant to catch). 

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

### `renderModulePage`

*def*

```lean
renderModulePage : String → Array DeclMeta → Bool → String
```

Renders one module's page: a heading plus every declaration's
section, in the order the extractor emitted them (elaboration order —
see `Environment.getLocalConstantInfos`). `jekyll` (task T31) controls
whether front matter is prepended — `false` produces plain portable
Markdown with no Jekyll-specific content at all. 

### `renderModulesPage`

*def*

```lean
renderModulesPage : Array String → Bool → String
```

Renders the list of documented modules, one line per module, linking
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
never mix the two within one `docs_dir`). 

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

### `navMarkerEnd`

*def*

```lean
navMarkerEnd : String
```

*(not documented)*

### `renderNavBlock`

*def*

```lean
renderNavBlock : Bool → String
```

Renders the nav block's current contents, markers included. 

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

### `groupDeclsByModule`

*def*

```lean
groupDeclsByModule : Array DeclMeta → Array (String × Array DeclMeta)
```

Groups declarations by module, preserving first-seen module order
(there's no `Array.groupByKey` in the stdlib to reach for here). 

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

### `ensureJekyllConfig`

*def*

```lean
ensureJekyllConfig : System.FilePath → IO Unit
```

Ensures `docsDir/_config.yml` exists, writing the default (see
`defaultJekyllConfig`) if it's missing. Never overwrites an existing
file. 

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

### `ensureDefaultLayout`

*def*

```lean
ensureDefaultLayout : System.FilePath → IO Unit
```

Ensures `docsDir/_layouts/default.html` exists, writing LeanDoc's
minimal layout (task T29 — see `assets/layouts/default.html`,
`LeanDoc.Assets.defaultLayoutHtml`) if it's missing. Never overwrites
an existing file, same write-once treatment as `ensureStyleAsset`. 

### `render`

*def*

```lean
render : System.FilePath → System.FilePath → Bool → IO Unit
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

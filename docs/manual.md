---
layout: default
---

# Manual

How to actually use LeanDoc, day to day. For the short pitch and
architecture summary, see
[`README.md`](https://github.com/JVerstry/LeanDoc/blob/main/README.md);
for the extractor/renderer pipeline write-up, see
[`index.md`]({% link index.md %}). This page is usage documentation —
what to configure and why, not how LeanDoc is built internally.

## For users

You depend on LeanDoc to document *your own* project.

### Installing

LeanDoc has no packaged installer yet (no tagged release — see the
STATUS NOTE at the top of `InstallationPrompt.txt`). Hand
[`InstallationPrompt.txt`](https://github.com/JVerstry/LeanDoc/blob/main/InstallationPrompt.txt)
to your own AI coding assistant; it walks through adding the
dependency, reviewing configuration choices with you, and running the
first generation.

### Running it

```sh
lake exe leandoc
```

Run from your own project's root (once LeanDoc is a `require`d
dependency, `lake exe` resolves it the same way it resolves your
project's own executables — no separate checkout needed). Writes
intermediate metadata to `json_dir` (gitignored, regenerated every run)
and rendered pages to `docs_dir` (committed by default).

### Configuration (`leandoc.toml`)

Sibling to `lakefile.toml`, at your project's root. Every field has a
default, so an absent file — or an absent section within one — is
fine:

```toml
[output]
json_dir = ".leandoc/"   # intermediate metadata, gitignored
docs_dir = "docs/"       # final rendered output

[modules]
# include = [...]        # see "Inclusion and exclusion" below
# exclude = [...]

[renderer]
name = "markdown"        # the only renderer that exists today
jekyll = true             # see "Jekyll" below

[compliance]
enabled = false           # see "Documentation-compliance checking" below
# author = "..."
# license = "..."
```

### Inclusion and exclusion

This is the part of `leandoc.toml` that decides what actually gets
documented.

- **`include`** — a list of dotted Lean module names (e.g.
  `"Foo.Bar"`). **Leave it empty** unless you want a subset: LeanDoc
  then scans your project's own `lakefile.toml` (its `lean_lib`/
  `lean_exe` targets) and documents everything it finds — whole-package
  scanning, mirroring Lake's own defaulting rules for target roots and
  globs. Only `lakefile.toml` is understood, not the `lakefile.lean`
  DSL; a project using the latter needs an explicit `include` list,
  since there's nothing to scan automatically.
- **`exclude`** — dotted module names to leave out, whether the
  effective module list came from `include` or from whole-package
  scanning. A module is excluded if it matches an entry exactly or sits
  under one as a dotted prefix (excluding `"Foo"` also excludes
  `"Foo.Bar"`).
- **Per-declaration opt-out — not implemented yet.** Today, exclusion
  only works at the module level: an entire file is either documented
  or not, with no way to mark one `def` inside an otherwise-documented
  file as deliberately undocumented (as opposed to a real coverage
  gap). A `.docignore`-style mechanism for this is planned but not
  built — don't write documentation or tooling that assumes it exists.

### Documentation-compliance checking

`[compliance]` (task T41) lets you opt into checks derived from
[Mathlib's own documentation style guidelines](https://leanprover-community.github.io/contribute/doc.html)
— entirely **off by default**, since most projects aren't Mathlib and
shouldn't be held to its conventions unless they explicitly ask.

Today this covers one check: whether each documented file's header
mentions the `author`/`license` you configure. Set `enabled = true`
and at least one of `author`/`license` to turn it on — leaving both
empty, even with `enabled = true`, means there's nothing to check
against, so nothing runs. When it *does* run, a file missing the
expected header gets a **warning on stderr**, never a build failure —
`lake exe leandoc` still completes and writes its output either way.
The check itself is intentionally loose: it looks for the literal word
"Copyright" plus your configured `author`/`license` text appearing
near the top of the file (first ~1000 characters), not a strict parse
of Mathlib's exact header grammar
(`/- Copyright (c) YEAR Name. ... Authors: ... -/`).

**Not built yet**, even though they're part of the same planned
feature area (`wip/todo.md` tasks T41/T42) — don't assume either
exists: a naming-conventions check (Mathlib's `snake_case`/
`UpperCamelCase` scheme) and a docstring-quality check (does a
docstring read as plain-language explanation, not just a restated type
signature). Both are pending an investigation into whether Mathlib's
own linters (`docBlame`, `docBlameThm`, `tacticDocs`) can be reused
rather than reimplemented from scratch.

LeanDoc can be used either way: to generate documentation that
conforms to Mathlib's conventions (`[compliance] enabled = true`,
configured to match your project), or to generate documentation
however you like with no conventions enforced at all (the default).

### Jekyll

`[renderer] jekyll` (default `true`) controls whether generated pages
target Jekyll — front matter (`layout: default`), internal links via
Jekyll's `{% link %}` tag, and written `_config.yml`/`assets/style.css`/
`_layouts/default.html` files (task T29) — or are plain, portable
Markdown instead (ordinary relative links, no Jekyll-specific content,
readable as-is outside Jekyll).

Leave it `true` if `docs_dir` will be published via GitHub Pages —
Pages runs Jekyll by default, and `false` output left there would be
served unprocessed (raw Markdown source, not a rendered page). Set it
to `false` only if you don't want GitHub Pages/Jekyll for these docs at
all (browsing in an IDE, serving from elsewhere, or an existing Jekyll
setup you don't want LeanDoc's output mixed into).

If `docs_dir` already has hand-written Markdown pages of your own
(e.g. a landing page) and `jekyll = true`: LeanDoc's renderer only adds
front matter to the pages *it* generates, never to existing
hand-written ones. Give those pages `---\nlayout: default\n---\n`
yourself, or they'll stay unprocessed "static files" next to your
processed generated ones — a half-broken, inconsistent site.

### Styling and customizing the CSS

`docs_dir/assets/style.css` is doc-gen4's own stylesheet (task T29),
vendored unmodified — this is deliberate: it's what Mathlib's and
cslib's published documentation actually looks like (verified by
diffing the live CSS from both sites — they turned out to be
byte-identical to doc-gen4's own default, and doc-gen4 itself has no
per-project color/theme customization mechanism at all), so LeanDoc's
output matches what Lean-ecosystem readers already expect rather than
inventing its own look. It ships with doc-gen4's own light/dark theme
toggle built in.

Both `docs_dir/assets/style.css` and `docs_dir/_layouts/default.html`
are written **once** and never touched again by LeanDoc on later
`lake exe leandoc` runs — the same write-once guarantee as
`_config.yml`. Edit either file directly to customize your site's
look; nothing will overwrite your changes. There's no `leandoc.toml`
option for "pick a different palette" — if you want something other
than the vendored default, edit the CSS itself after the first
generation.

### Generated output

Rendered pages land under `docs_dir/reference/` — one Markdown page per
documented module (mirroring its dotted name, e.g. `Foo.Bar` →
`reference/Foo/Bar.md`), plus a `reference/modules.md` linking all of
them. Named `reference/`, not `api/`: it's a flat dump of every
included declaration (compiler-generated noise filtered out), not a
curated public API surface — nothing here distinguishes a genuinely
public interface from an internal helper that merely lives in an
included module.

A `docs_dir/toc.md` (task T18) lists every documented declaration
project-wide, grouped by kind — Definitions, Theorems & Axioms,
Structures & Inductives, Other — rather than by module, so "show me
every theorem" doesn't mean reading through every module page by hand.
Each entry links to its declaration's module page (not a specific
in-page anchor — Jekyll's `{% link %}` only validates that the target
*file* exists, not a fragment within it, and there's no way to verify
anchor slugification without a real Jekyll build, so this deliberately
doesn't guess).

`docs_dir/index.md`, the site's actual root page, gets a
`<!-- leandoc:nav:start -->`/`<!-- leandoc:nav:end -->`-delimited
section linking to both `reference/modules.md` and `toc.md`, kept
current automatically on every `lake exe leandoc` run. If the file
doesn't exist yet, LeanDoc creates a minimal one; if it exists without
those markers (e.g. a landing page you wrote by hand), LeanDoc leaves
it completely alone — add the markers yourself once if you want the
navigation section kept in sync automatically.

### Optional: CI and pre-commit freshness checks

Neither is set up automatically. `InstallationPrompt.txt` documents
ready-to-use templates for both — a GitHub Actions workflow that
regenerates docs and fails if `docs_dir/reference` has drifted from
what's committed, and a local pre-commit hook doing the same check
before a commit lands. Both are opt-in only: the CI version isn't
auto-written because the LeanDoc dependency still pins a branch, not a
tagged release, so a generated workflow today would silently pick up
LeanDoc's own breaking changes; the pre-commit version isn't
auto-installed because a full `lake exe leandoc` run before *every*
commit is a real, ongoing per-commit cost on a large project, not a
one-time setup cost.

### What ends up in your repo

Installing LeanDoc as a dependency brings its whole git repository
along — including `demo/`, `test/`, and `.githooks/`, LeanDoc's own
development fixtures and tooling. These end up physically present on
disk under `.lake/packages/LeanDoc/` (unavoidable; Lake has no
mechanism to exclude a subdirectory from a git dependency checkout),
but none of it is ever built or run as part of your project — `lake
build`/`lake exe leandoc` only build LeanDoc's own `leandoc`/
`leandoc-test` targets, never `demo/`'s separate nested Lake package,
and `lake exe leandoc` only ever reads and writes your own project's
files. See `README.md`'s "Users vs. developers of LeanDoc" section for
the fuller writeup (this was verified empirically, not assumed — task
T35).

## For developers

You work on LeanDoc's own source, not a project that merely depends on
it. See `README.md`'s "Users vs. developers of LeanDoc" section for the
full breakdown of what that involves (`test/`, `.githooks/pre-commit`,
`lake exe leandoc-test`) — not repeated here to avoid maintaining the
same content in two places (see `wip/todo.md` task T30 for why a
duplicate page was judged not worth it before).

---
layout: default
---

# Manual

How to actually use LeanDoc, day to day. For the short pitch and
architecture summary, see
[`README.md`](https://github.com/JVerstry/LeanSkills/blob/main/LeanDoc/README.md);
for the extractor/renderer pipeline write-up, see
[`index.md`]({% link index.md %}). This page is usage documentation —
what to configure and why, not how LeanDoc is built internally.

## For users

You depend on LeanDoc to document *your own* project.

### Installing

LeanDoc has no packaged installer yet (no tagged release — see the
STATUS NOTE at the top of `InstallationPrompt.txt`). It is installed by the
LeanSkills installer: hand
[`InstallationPrompt.txt`](https://github.com/JVerstry/LeanSkills/blob/main/InstallationPrompt.txt)
at the root of the LeanSkills repository (raw file:
`https://raw.githubusercontent.com/JVerstry/LeanSkills/main/InstallationPrompt.txt`)
to your own AI coding assistant. It asks which tool you want, LeanDoc,
LeanPerformance or both, asks once about the skills' scope and audit source,
then follows LeanDoc's own installer part
([`InstallationPrompt.txt`](https://github.com/JVerstry/LeanSkills/blob/main/LeanDoc/InstallationPrompt.txt)
in this folder, which also works on its own): it walks through adding the
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

**Your project must compile.** Before extracting anything, LeanDoc runs
`lake build` on exactly the modules it's about to document (task T54).
Lake's progress output is shown as it runs, and the step is a no-op
when everything is already up to date. This is what lets one of your
modules `import` another: LeanDoc reads each module from source, but
imports resolve against compiled `.olean` files, so they must exist
and be current (doc-gen4 has the same requirement). If your project
depends on Mathlib, run `lake exe cache get` first, as you would for
any build, so Mathlib is downloaded rather than compiled from source.
If the build fails, LeanDoc stops with Lake's own errors. Fix them, or
exclude the failing modules via `[modules] exclude` in `leandoc.toml`.

### Auditing the output

`lake exe leandoc` running without error doesn't mean the result is
actually good documentation — it can be technically valid and still
stale, low-quality, or misconfigured. Hand
[`QualityAuditPrompt.txt`](https://github.com/JVerstry/LeanSkills/blob/main/LeanDoc/QualityAuditPrompt.txt)
to your AI coding assistant after generating docs to
sanity-check the result: freshness, docstring coverage and quality,
generated-noise leaks, navigation/structure, Jekyll/GitHub Pages
compatibility (if applicable), and more — it reads your `leandoc.toml`
(including "Documentation-compliance checking," below) rather than
assuming a fixed one-size-fits-all standard. This is a manual, one-off
or periodic check, not a substitute for the CI/pre-commit freshness
checks described in "Optional: CI and pre-commit freshness checks"
below — those two are about *drift*, this is about *quality*.

The prompt works with any assistant that can read your files and run
commands. A report lists each finding with a stable key, its category
(a LeanDoc bug, a gap in your project, or by design), and whether it
was verified against your actual output.

#### The `/leandoc` skill (Claude Code)

If you use Claude Code, the installer can install a small
skill so that you can run the audit with `/leandoc` instead of handing
over the prompt each time (the LeanSkills installer asks whether you want
it; it is step 8 of LeanDoc's own `InstallationPrompt.txt`; to add it to a
project that already uses LeanDoc, hand either file to your assistant and
ask for the skill only). It writes three text files into a skill folder, either
for all your projects (`~/.claude/skills/leandoc/`) or for this one
(`.claude/skills/leandoc/`, which you can commit so collaborators get it
too). Nothing in your Lean project changes.

- `/leandoc` runs the full audit, which regenerates the docs and builds
  your project.
- `/leandoc dry` is the light version: it only reads files, builds and
  regenerates nothing, and marks every finding unverified. Treat its
  findings as leads to confirm with a full run.
- `/leandoc fix` runs the full audit, then offers to fix findings one at a
  time: it shows the exact edit and applies it only after you approve
  that one (no "apply all"). It never edits generated output (it fixes
  the Lean source, `leandoc.toml` or a file you own), never stages,
  commits or pushes, and regenerating the docs is a step you agree to
  separately. Naming findings are reported, never fixed.
- `/leandoc schedule` sets up a recurring dry check (weekly by default)
  using your assistant's own scheduler, saving reports in a
  `.leandoc-audit/` folder, which it adds to your `.gitignore` after you
  confirm. Each run compares itself with the previous report and tells
  you only what is new, gone or changed, or "No change". It writes
  nothing outside `.leandoc-audit/`. `/leandoc schedule off` removes it.
- `/leandoc papercuts <path>` connects a papercuts log (a text file of
  tooling friction, one line per entry). After a full audit the skill
  proposes lines only for verified findings that are general lessons,
  and appends them once you confirm. `/leandoc papercuts off`
  disconnects it.
- `/leandoc update` refreshes the skill and its copy of the audit, shows
  what changed, and asks before overwriting. If LeanDoc's repository
  can't be fetched (for example while it is private), it offers the
  copy inside your pinned LeanDoc dependency instead.
- `/leandoc mode local|remote` chooses where the audit text comes from.
  `local` uses the saved copy (offline, reproducible); `remote` fetches
  the latest from LeanDoc's repository on every run and falls back to
  the copy. The audit describes one LeanDoc version's output, so the
  latest one can describe a newer LeanDoc than your project uses; each
  report says which audit it used and which LeanDoc revision your
  project pins.
- `/leandoc uninstall` removes the skill after confirmation (or delete
  its folder yourself). Neither updating nor removing it touches your
  Lean project.

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

[project]
# version = "..."         # see "Version tracking" below
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
- **`@[leandoc_ignore]`** (task T19) — marks a single declaration as
  *deliberately* undocumented, distinct from a real coverage gap.
  Requires `import LeanDoc.Core` (the same import a `require`d
  dependency already gives you access to):

  ```lean
  @[leandoc_ignore]
  def myInternalHelper (n : Nat) : Nat := n - 1
  ```

  A tagged declaration is fully omitted from generated output — not
  shown with an "ignored" marker, simply absent, the same treatment as
  Lean's own compiler-generated scaffolding (recursors, `noConfusion`,
  equation lemmas, ...) that LeanDoc already filters out by default.
  There's no `.docignore` file, and no plan to add one: it would just
  be a second mechanism doing the same job `[modules] exclude` already
  does for whole modules — a real design call, not an oversight.

  **LeanDoc deliberately does *not* recognize Mathlib/Batteries'
  `@[nolint docBlame]`** as an equivalent, even though it looks
  similar. That tag only suppresses a *lint warning* when running
  Batteries' `#lint` — it has no effect on what doc-gen4 (or any
  documentation generator) actually renders; a `@[nolint docBlame]`'d
  declaration still shows up, undocumented, in Mathlib's own generated
  docs. Treating it as "hide from LeanDoc's output" would silently
  misrepresent what a project using it actually meant. Recognizing it
  for real would also require adding Batteries as a genuine compile-
  time dependency of LeanDoc itself (its `nolint` attribute has no
  generic way to be queried without importing the module that defines
  it) — a real, ongoing cost not worth taking on for a tag that
  wouldn't even mean the right thing here.

### Documentation-compliance checking

`[compliance]` (task T41) lets you opt into checks derived from
[Mathlib's own documentation style guidelines](https://leanprover-community.github.io/contribute/doc.html)
— entirely **off by default**, since most projects aren't Mathlib and
shouldn't be held to its conventions unless they explicitly ask.

Two checks exist, each with its own switch: the copyright/license
header check just below, and the naming-convention check after it.

**Header check.** Whether each documented file's header
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

**Naming check.** Set `naming = true` to get a **warning on stderr**,
never a failure, for each documented declaration whose name breaks
[Mathlib's naming guide](https://leanprover-community.github.io/contribute/naming.html)
for what it is:

- types, structures and classes are `UpperCamelCase`;
- theorems and other proofs are `snake_case`, where a word that is
  itself named in `UpperCamelCase` appears in `lowerCamelCase`
  (`isOpen_iff`);
- functions and other data are `lowerCamelCase`, except that a function
  is named like its return value, so one returning a type is
  `UpperCamelCase`.

```toml
[compliance]
naming = true
```

It's a heuristic and is labelled "convention only" in its output: it
can't see why a name is the way it is. So it's deliberately lenient:
only the last component of a name is judged (the namespace names
something else), a trailing `'`, `?` or `!` is ignored, a name starting
with `_` or quoted with `«»` is skipped, instances are skipped (their
names are generated), and a `Prop`-valued definition is only flagged for
an underscore, because Mathlib itself writes both `IsOpen` and `le`. At
most 25 are listed, then a count of the rest. It's independent of
`enabled`: you can use either, both, or neither.

**Not a LeanDoc check:** whether a docstring reads as plain-language
explanation rather than a restated type signature. That needs judgement,
so it lives in the `QualityAuditPrompt.txt` audit (see "Auditing the
output"), not in LeanDoc. Neither check borrows from Mathlib's or
Batteries' linters: there is no naming-convention linter in either, and
`docBlame`/`docBlameThm` only check that a docstring *exists*.

LeanDoc can be used either way: to generate documentation that
conforms to Mathlib's conventions (`[compliance]`, configured to match
your project), or to generate documentation however you like with no
conventions enforced at all (the default).

### Version tracking

`[project] version` (task T27) is optional and unset by default — your
project's own release version (e.g. `"1.2.0"`), typed in by hand, never
auto-detected. If you set it, LeanDoc warns (never fails the build) at
generation time when it doesn't match your project's latest git tag —
catching "forgot to bump the version after tagging a release," nothing
more. A leading `v`/`V` on either side (`v1.2.0` vs. `1.2.0`) is
normalized away before comparing, so it doesn't matter which
convention your tags use.

This is deliberately narrow, not a general "is this repo stale" check.
Two things it's specifically *not*:
- **Not a reader-facing stamp.** The version, a commit hash, or a
  generation date are never rendered anywhere in the generated docs
  themselves — this is purely a build-time signal for whoever runs
  `lake exe leandoc`, not something a reader browsing the site sees.
- **Not a dirty-working-tree check.** Generating docs with
  uncommitted changes is completely normal — you'd typically regenerate
  docs *before* committing both the source changes and the regenerated
  output together. A warning about that would just be noise on routine
  use, so LeanDoc doesn't do it.

If nothing's configured, or the project isn't a git repo, or it has no
tags yet, the check silently does nothing — there's nothing meaningful
to compare against in any of those cases.

### Jekyll

`[renderer] jekyll` (default `true`) controls whether generated pages
target Jekyll — front matter (`layout: default`), internal links via
Jekyll's `{% raw %}{% link %}{% endraw %}` tag, and written `_config.yml`/`assets/style.css`/
`_layouts/default.html` files (task T29) — or are plain, portable
Markdown instead (ordinary relative links, no Jekyll-specific content,
readable as-is outside Jekyll).

Leave it `true` if `docs_dir` will be published via GitHub Pages —
Pages runs Jekyll by default, and `false` output left there would be
served unprocessed (raw Markdown source, not a rendered page). Set it
to `false` only if you don't want GitHub Pages/Jekyll for these docs at
all (browsing in an IDE, serving from elsewhere, or an existing Jekyll
setup you don't want LeanDoc's output mixed into).

#### Choosing, and what GitHub's Jekyll does to each choice

GitHub Pages builds the folder it publishes with its own Jekyll, whatever
`jekyll` says, so the right setting depends on where the docs are read.
The installer (`InstallationPrompt.txt`, step 2f) asks this first and
recommends from the answer:

| Where the docs are read | Set `jekyll` | What happens |
|---|---|---|
| GitHub Pages, deployed from a branch folder | `true` | Pages' builder (Jekyll 3.10) turns the pages into a styled, searchable site. With `false` it would serve the raw Markdown source. |
| GitHub Pages, deployed by a GitHub Actions workflow | `true` | Same output, but a workflow can use a newer Jekyll, where the `{% raw %}{% link %}{% endraw %}` tag also adds the site's `baseurl`. Check the links after the first deploy. |
| github.com or an IDE only | `false` | With `true`, github.com shows the front matter as a table and the `{% raw %}{% link %}{% endraw %}` links are broken, because its Markdown viewer does not run Jekyll. |
| Another host, or your own Jekyll site | `false`, unless you run Jekyll yourself | `true` writes `_config.yml`, a layout and a stylesheet that may clash with an existing site. |

**Known limitation, project sites.** A project site is served from a
sub-path (`<user>.github.io/<repo>/`). Jekyll's documentation says the
`{% raw %}{% link %}{% endraw %}` tag adds the site's `baseurl` only
from Jekyll 4.0, so with Pages' own builder (3.10) the generated internal
links point at the wrong place on a project site. A user or organisation
site, or a custom domain, is served from the root and is not affected.
This comes from Jekyll's documentation and has not been confirmed on a
real deploy; a fix is planned (task T64). Until then, prefer a root-served
site, or `jekyll = false` and browse the docs on github.com.

Changing the setting later is safe: edit `leandoc.toml`, run
`lake exe leandoc`. The files written only once (`_layouts/`, `assets/`,
`_config.yml`) are kept when you switch to `false`; they are harmless
and can be deleted by hand.

Jekyll processes Liquid template syntax on every page, so text copied
from your Lean source (docstrings, names, types) is escaped: a
docstring that mentions {% raw %}`{{ … }}` or `{% … %}`{% endraw %} is shown as
written, instead of being run or failing the site build (task T56).

If `docs_dir` has hand-written pages of your own, see "Adding your own
pages" below: LeanDoc never touches them, so they need their own front
matter.

### Styling and customizing the CSS

`docs_dir/assets/style.css` is doc-gen4's own stylesheet (task T29),
vendored unmodified — this is deliberate: it's what Mathlib's and
cslib's published documentation actually looks like (verified by
diffing the live CSS from both sites — they turned out to be
byte-identical to doc-gen4's own default, and doc-gen4 itself has no
per-project color/theme customization mechanism at all), so LeanDoc's
output matches what Lean-ecosystem readers already expect rather than
inventing its own look.

A light/dark/system theme switcher (task T45) is included too —
`docs_dir/assets/color-scheme.js`, adapted from doc-gen4's own (not
vendored unmodified like the CSS: doc-gen4's original coordinates with
a separate nav document loaded in an iframe, which LeanDoc's simpler
single-page layout doesn't have, so the logic was simplified to work
directly on the page itself) plus a small switcher form in
`docs_dir/_layouts/default.html`. Your preference is remembered across
visits (`localStorage`), defaults to following your OS/browser
setting.

`docs_dir/assets/style.css`, `docs_dir/_layouts/default.html`,
`docs_dir/assets/color-scheme.js`, and `docs_dir/assets/search.js` (see
"Searching the generated site" below) are all written **once** and
never touched again by LeanDoc on later `lake exe leandoc` runs — the
same write-once guarantee as `_config.yml`. Edit any of them directly
to customize your site's look or behavior; nothing will overwrite your
changes. There's no `leandoc.toml` option for "pick a different
palette" — if you want something other than the vendored default, edit
the CSS itself after the first generation.

### Upgrading LeanDoc

Because those files are written once, upgrading LeanDoc doesn't update
them: a project that installed an older LeanDoc keeps its old
`_layouts/default.html`. New scripts a newer LeanDoc ships are written
if they're missing, but an old layout never loads them, so the site
quietly lacks the search box, the light/dark switcher or LaTeX
rendering.

To make that visible, the layout carries a `leandoc-layout-version`
number in its opening comment, raised whenever LeanDoc changes the
layout. `lake exe leandoc` compares it with your copy's and prints a
**warning** (never an error) when yours is older, or has no number,
naming the features it appears to lack.

LeanDoc will not overwrite the file, because you may have customised
it. The fix is a manual merge:

1. Open LeanDoc's current layout, `assets/layouts/default.html`, in
   LeanDoc's repository, or under `.lake/packages/LeanDoc/LeanDoc/` in your
   project.
2. Compare it with `docs_dir/_layouts/default.html` and copy across what
   yours is missing (the extra `script` lines and the search box),
   keeping your own changes.
3. Keep its `leandoc-layout-version` line, updated to the current
   number. The warning stops.

If you never customised the layout, the simplest route is to delete
`docs_dir/_layouts/default.html` and run `lake exe leandoc`: it writes
the current one. (The other write-once files, such as `style.css`, carry
no number; compare them by hand when you want a newer version.)

The `QualityAuditPrompt.txt` audit checks the same thing.

### Searching the generated site

Jekyll output (see "Jekyll" above) includes a search box at the top of
every page (task T47), backed by `docs_dir/assets/search-index.json` —
a flat, site-wide list of every documented declaration's name, kind,
module, and link. Unlike the assets above, this file is **not**
write-once: it's rewritten on every `lake exe leandoc` run so it always
reflects your project's current declarations.

Matching is a simple case-insensitive substring match against
declaration names (capped at 20 results) — not the fuzzy, ranked search
doc-gen4's own Mathlib-scale index does. LeanDoc's typical project is
nowhere near Mathlib's ~70MB index size, so this keeps things simple
rather than porting that complexity in ahead of an actual need. Plain
Markdown output (`renderer.jekyll = false` in `leandoc.toml`) has no
search box at all — there's no static-site layer to run the script.

### Jumping to source

Each declaration's page links to its exact definition on GitHub (task
T46), when two things are both available: the project is a git repo
with a GitHub `origin` remote (SSH or HTTPS; other hosts and non-git
projects are skipped gracefully, no link rendered rather than a wrong
one), and the declaration's source range was captured during
extraction.

Links point at your repository's default branch (`…/blob/HEAD/…`,
which GitHub resolves to it), not at a specific commit (task T57). A
commit hash can't work for docs committed alongside the code: they're
generated before the commit exists, so a freshness check would always
see a changed hash. As long as your committed docs are regenerated with
every change, which the optional freshness checks below enforce, the
line numbers match the default branch's code.

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
in-page anchor — Jekyll's `{% raw %}{% link %}{% endraw %}` only validates that the target
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

### Typeclass instances

A class's own declaration page (task T48) lists every registered
instance of it project-wide (`instance : MyClass Foo`-shaped
declarations, wherever they're defined), under an **Instances**
heading — e.g. `Inhabited`'s page would list `instInhabitedNat`,
`instInhabitedBool`, and so on. Each entry names the instance and the
module it lives in, without a specific in-page link (same reasoning as
`toc.md`'s entries above — no verified Jekyll anchor slugification to
link to).

This only covers "what instances does this class have," not doc-gen4's
other direction ("what instances mention this *type*, across every
class") — a class with no registered instances (or a declaration that
isn't a class at all) simply gets no Instances section.

### Module navigation

Jekyll output's `reference/modules.md` (task T49) renders the
project's modules as a nested, collapsible tree grouped by namespace
— `Foo.Bar` and `Foo.Baz` both appear under one expandable `Foo` entry
— rather than one flat list, using plain HTML `<details>`/`<summary>`
(no JavaScript needed to expand or collapse a namespace). Non-Jekyll
output keeps the flat list, since raw `<details>` HTML has no obvious
plain-Markdown equivalent.

Deliberately simpler than doc-gen4's own nav tree: no shared sidebar
persisted across every page via an iframe, and no auto-expanding to
the page you're currently on — both matter at Mathlib's scale (one
tree spanning an entire dependency closure, visible on every page at
once), but `reference/modules.md` here is a single, standalone index
page, not something embedded in every other page. LeanDoc typically
documents one project, not an entire ecosystem.

### "Imported by"

Each module's own page (task T50) shows an **Imported by** line
listing every other *documented* module that imports it, if any — read
straight off each module's own source file (a fast header-only parse,
not a full re-elaboration just to see its `import` lines). An import
of something outside the project (the Lean core library, Mathlib, any
other dependency) isn't shown — LeanDoc has no page for it to link to,
so it's silently dropped rather than rendered as a dead link. A module
nothing else imports gets no line at all.

### LaTeX in docstrings

Jekyll output loads [MathJax](https://www.mathjax.org/) (task T51),
rendering `$...$` (inline) and `$$...$$` (display) LaTeX inside
docstrings — matching doc-gen4's own choice of delimiters, so a
docstring written with doc-gen4 in mind renders the same way here.
MathJax itself is loaded from its own CDN, not vendored — unlike
LeanDoc's other JS assets, it's a large, versioned third-party
library, not something a project would ever want to hand-edit.
Non-Jekyll output has no MathJax include; `$...$` in a docstring just
renders as literal text there.

### Stable permalinks

`docs_dir/find.html?pattern=<DeclarationName>` (task T52, Jekyll
output only) redirects straight to that declaration's doc page —
useful for an external link that shouldn't need to know which module
file a declaration currently lives in, since that can change (a module
gets renamed or split) without breaking a link written against this
page. It looks the name up in `assets/search-index.json` (task T47)
client-side and redirects on a match; an unrecognized name shows a
plain "not found" message rather than a broken redirect.

Scoped to exact-name lookup redirecting to the doc page only — doc-gen4's
own `/find` also supports jumping straight to a declaration's *source*
link via a `#src` fragment, which `search-index.json` doesn't carry
data for (only the doc link); the doc page itself already links to
source (task T46) once you're there.

### A friendlier 404 page

Jekyll output includes `docs_dir/404.html` (task T53) — GitHub Pages
serves this file automatically for any unmatched path, no extra
configuration needed. Instead of a bare "not found," it takes a guess
at what you meant from the broken URL's own last path segment and
suggests matching declarations from `assets/search-index.json`
(task T47), the same simple substring match `find.html`/`search.js`
use — real fuzzy/edit-distance matching wasn't judged worth the extra
complexity at LeanDoc's typical project scale. No suggestions are shown
if nothing matches, or if the search index can't be reached at all.

### Adding your own pages

You can add pages that aren't generated from your Lean source, such as
a getting-started guide, a tutorial or a changelog (task T55). LeanDoc
never touches a file it didn't write, so these pages are entirely
yours. This manual is itself an example: it's a hand-written page in
LeanDoc's own `docs/`, sitting next to the generated reference.

**Where to put them.** Anywhere in `docs_dir` except the places
LeanDoc writes:

| Path | What LeanDoc does with it |
|---|---|
| `reference/` | Deleted and regenerated on every run — never put your own files here |
| `toc.md`, `assets/search-index.json` | Overwritten on every run |
| `index.md` | Only the part between the `leandoc:nav` markers is rewritten; the rest is yours |
| `_config.yml`, `_layouts/`, `assets/*.js`, `assets/style.css`, `find.html`, `404.html` | Written once if missing, then left alone |

A subfolder such as `docs_dir/guides/` keeps things tidy.

**Start from the template.** LeanDoc ships a starter page,
`templates/page.md`. Since your project `require`s LeanDoc, Lake has
already downloaded it:

```sh
mkdir -p docs/guides
cp .lake/packages/LeanDoc/LeanDoc/templates/page.md docs/guides/getting-started.md
```

(It's also on
[GitHub](https://github.com/JVerstry/LeanSkills/blob/main/LeanDoc/templates/page.md).)
Then change its `title` and rewrite its content. Keep the front matter
block at the top, and keep `layout: default` in it. Without front
matter, Jekyll serves the file as raw, unstyled Markdown.

**Linking.** Link to generated pages and to your other pages with
Jekyll's `link` tag. The path is relative to `docs_dir` and uses the
`.md` source name, even though the published page ends in `.html`:

{% raw %}
```markdown
[The MyProject.Basic module]({% link reference/MyProject/Basic.md %})
[All modules]({% link reference/modules.md %})
[Back home]({% link index.md %})
```
{% endraw %}

A `link` tag pointing at a page that doesn't exist fails the whole site
build. That catches broken links before they're published, but it also
means a typo stops the site from updating until it's fixed.

**Making the page reachable.** LeanDoc doesn't add your pages to the
navigation list or to the search box: search covers Lean declarations
only. Link each page from `index.md` yourself, *outside* the
`leandoc:nav` markers so LeanDoc leaves the link alone. LeanDoc's own
`index.md` does exactly this for this manual.

**One pitfall: Liquid runs on the whole page.** {% raw %}Jekyll processes
`{{ … }}` and `{% … %}` sequences everywhere in a page, including
inside code blocks and inline code. To show such text literally, for
example when documenting Jekyll itself, wrap it between
`{% raw %}`{% endraw %} and `{{ "{% endraw %}" }}`.

**Without Jekyll** (`[renderer] jekyll = false`): leave out the front
matter and use ordinary Markdown links, relative to the page's own
location, for example `[Basic](../reference/MyProject/Basic.md)` from
a page in `guides/`.

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

### Optional: quality checks on commit or CI

Separate from the freshness checks above (which catch docs that are
*out of date*), LeanDoc ships a small script that catches problems in
the docs *as they are*, for use in a commit hook or in CI. It runs only
the mechanical checks that need no judgement, on the committed docs:

- every Jekyll `link` tag names a file that exists (a missing target
  fails the whole Jekyll build, and nothing else would tell you before
  you publish);
- `_layouts/default.html` isn't older than the one your LeanDoc ships
  (see "Upgrading LeanDoc");
- no Lean-generated scaffolding (`.rec`, `.casesOn`, `.noConfusion`, ...)
  leaked into `docs_dir/reference`.

Judgement checks, such as whether a docstring is any good, stay with the
audit (see "Auditing the output"). The script reads files only: it
regenerates nothing and modifies nothing, so it's fast.

It is **strict**: a finding fails the commit or the CI run. To commit
work in progress anyway, start the commit message with `WIP` (or
`WIP: ...`, or `[WIP] ...`, in any case). The findings are then still
printed in full, but as warnings, and the commit goes through. Unlike
`git commit --no-verify`, this skips nothing else, and the marker stays
visible in your history. Only the first line of the message counts, and
words that merely start with those letters ("Wipe the cache") don't.

The script is `scripts/quality-check.sh` in LeanDoc, so under
`.lake/packages/LeanDoc/LeanDoc/` in your project. You can run it by hand:

```sh
sh .lake/packages/LeanDoc/LeanDoc/scripts/quality-check.sh --docs-dir docs
```

As a hook it needs the `commit-msg` stage, since that's the first moment
the message exists. `InstallationPrompt.txt` has a ready-made
`.githooks/commit-msg` and a CI step (which passes the checked commit's
message to the script, so the same WIP marker applies), both opt-in and
never set up automatically.

Installing LeanDoc as a dependency brings its whole git repository
along — including `demo/`, `test/`, and `.githooks/`, LeanDoc's own
development fixtures and tooling. These end up physically present on
disk under `.lake/packages/LeanDoc/LeanDoc/` (unavoidable; Lake has no
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
`lake exe leandoc-test`) — not repeated here, to avoid maintaining the
same content in two places.

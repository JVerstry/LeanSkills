---
layout: default
---

# LeanDoc

LeanDoc generates documentation for Lean 4 projects, using Lean itself to
parse and understand the code.

> **Status note:** the extractor and a first Markdown renderer exist. Running
> `lake exe leandoc` in this folder documents LeanDoc's own source as a smoke
> test (a much larger input than `demo/`), but the output goes to the
> gitignored `.leandoc/site/` and is not committed. This page and `manual.md`
> are the only hand-written pages in `docs/`.

See [`README.md`](https://github.com/JVerstry/LeanSkills/blob/main/LeanDoc/README.md)
for LeanDoc's documentation elaboration strategy (how the extractor and
renderer stages work), or [`manual.md`]({% link manual.md %}) for how to
actually configure and use it (task T23).

## Documentation

- [Manual]({% link manual.md %}) — how to configure and use LeanDoc.
- The generated reference for LeanDoc's own source is not committed. To see it,
  run `lake exe leandoc` in this folder and open `.leandoc/site/reference/modules.md`.
  The checked-in example of generated output is `demo/docs/`.

## Where things live

| Path | What it is | In git? |
|---|---|---|
| `.leandoc/` | Intermediate metadata JSON, one file per module | No — gitignored, regenerated every run |
| `docs/` | LeanDoc's own hand-written pages (this one and the manual) | Yes |
| `.leandoc/site/` | LeanDoc's own generated docs, from running it on itself | No — gitignored, regenerated on demand |
| `demo/docs/` | Checked-in example of generated output, for the test fixture | Yes — committed, and CI checks it is up to date |
| `leandoc.toml` | Configuration (output paths, included/excluded modules) | Yes |

## GitHub Pages compatibility

The pages LeanDoc generates for a project are meant to be served through
**Jekyll** (task T22/T28) — the default GitHub Pages behavior — rather than
disabling it via `.nojekyll`. Every generated `.md` file carries a front-matter block
with `layout: default` so Jekyll actually converts it to HTML instead
of copying it through unprocessed (Jekyll only treats a file with
front matter as a page at all, and only applies a layout's styling to
a page whose front matter names one — task T29, confirmed against
Jekyll's own docs); internal links use Jekyll's
[`{% raw %}{% link %}{% endraw %}` tag](https://jekyllrb.com/docs/liquid/tags/) rather than
plain Markdown links, since Jekyll renames converted pages `.md` →
`.html` and `{% raw %}{% link %}{% endraw %}` resolves that automatically (and fails the
build if a target doesn't exist). `assets/style.css` (task T29) is
doc-gen4's own stylesheet, vendored unmodified — matching what
Mathlib/cslib actually look like, rather than a GitHub Pages
`theme:`/`remote_theme:` or something LeanDoc invented — paired with
`_layouts/default.html`, LeanDoc's own minimal layout that links it.

To publish a project's docs: point its GitHub Pages setting at the `main` branch,
`/docs` folder. No further CI/build step is required for the committed
output to go live — Jekyll processing happens on GitHub's own Pages
build, not something LeanDoc runs itself.

## Contributing to LeanDoc

See [`README.md`](https://github.com/JVerstry/LeanSkills/blob/main/LeanDoc/README.md)'s
"Users vs. developers of LeanDoc" section for a quick orientation
(task T30, 2026-09-22: folded in from this site's former
`conventions.md`, which was judged an unnecessary extra page for
content that fit fine in the README).

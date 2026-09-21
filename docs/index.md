# LeanDoc

LeanDoc generates documentation for Lean 4 projects, using Lean itself to
parse and understand the code.

> **Status note:** LeanDoc's extractor/renderer are not implemented yet
> (see the project repo's `wip/todo.md`). This page is currently
> hand-maintained and describes the intended architecture. Once the
> renderer exists, this page is expected to become (or be replaced by)
> its generated landing page — see the backlog entry about reconciling
> the two.

## Documentation elaboration strategy

LeanDoc runs in two stages, connected by a JSON contract:

1. **Extractor (Lean 4).** LeanDoc loads your project through Lean's own
   frontend (`Lean.Elab.Frontend`), fully elaborating every file exactly
   as `lake build` would — no regexes, no hand-rolled parsing of Lean's
   syntax. This gives LeanDoc access to Lean's real `Environment`:
   fully-qualified names, resolved types, and docstrings (via
   `findDocString?`), plus each declaration's source location.

   The extractor writes one `metadata.json` per module into a
   `.leandoc/` directory at your project root. **This directory is a
   build artifact** — regenerated on every run — and is gitignored, the
   same way `.lake/` already is. It is never committed and never sits
   next to your `.lean` sources.

2. **Renderer.** A separate stage reads the JSON out of `.leandoc/` and
   produces the documentation you're looking at right now, written into
   `docs/`. Keeping this stage separate from the extractor means the
   output format (HTML, Markdown, a custom theme) can change without
   touching the elaboration logic that has to stay correct against
   Lean's compiler internals.

   (A syntax-only "fast mode" that skips elaboration was considered and
   deliberately dropped from v1 — see `wip/todo.md` for why.)

## Where things live

| Path | What it is | In git? |
|---|---|---|
| `.leandoc/` | Intermediate metadata JSON, one file per module | No — gitignored, regenerated every run |
| `docs/` | Final rendered documentation (this site) | Yes — committed, so GitHub Pages can serve it straight from `main` |
| `leandoc.toml` | Configuration (output paths, included/excluded modules) | Yes |

## GitHub Pages compatibility

This directory ships a [`.nojekyll`](.nojekyll) marker file so GitHub
Pages serves it as-is, without first running it through Jekyll — which
would otherwise ignore or rewrite any file or folder whose name starts
with an underscore (a common convention in static-site output) and apply
its own default theme to Markdown files instead of leaving them, or the
renderer's own HTML, untouched.

To publish: point the repo's GitHub Pages setting at the `main` branch,
`/docs` folder. No further CI/build step is required for the committed
output to go live.

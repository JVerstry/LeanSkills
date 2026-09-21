# LeanDoc

LeanDoc generates documentation for Lean 4 projects, using Lean itself to
parse and understand the code.

> **Status note:** LeanDoc's extractor/renderer are not implemented yet
> (see the project repo's `wip/todo.md`). This page is currently
> hand-maintained and describes the intended architecture. Once the
> renderer exists, this page is expected to become (or be replaced by)
> its generated landing page — see the backlog entry about reconciling
> the two.

See [`conventions.md`](conventions.md) for LeanDoc's documentation
elaboration strategy (how the extractor and renderer stages work).

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

## Contributing to LeanDoc

See [`conventions.md`](conventions.md) for a quick orientation, or
`AGENTS.md` in the repository root for the full set of project
conventions.

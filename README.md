# LeanDoc

A free tool to generate documentation for Lean 4 projects, using Lean
itself.

## Installation

LeanDoc doesn't have a packaged installer. Hand
[`InstallationPrompt.txt`](InstallationPrompt.txt) to your own AI coding
assistant (Claude or otherwise) — it walks through adding LeanDoc as a
Lake dependency, setting up `docs/` and `leandoc.toml`, and running the
initial generation.

## The short version

- **What LeanDoc does:** generates documentation for Lean 4 projects by
  fully elaborating them through Lean's own frontend
  (`Lean.Elab.runFrontend`) — not regexes, not hand-rolled syntax parsing.
  See [`docs/index.md`](docs/index.md) for the full pipeline write-up.
- **Toolchain:** managed by `elan` (`lean`, `lake` on `PATH`), pinned via
  `lean-toolchain`. `lake build` / `lake exe leandoc` builds and runs the
  (currently placeholder) extractor executable.
- **Where things live:** intermediate metadata JSON in `.leandoc/`
  (gitignored, regenerated every run); final rendered docs in `docs/`
  (committed to git); configuration in `leandoc.toml`.
- **Task tracking:** ongoing work is tracked with stable IDs in
  [`wip/todo.md`](wip/todo.md).

For anything beyond this summary — architecture rationale, why certain
approaches were dropped, specific notes — go to
[`AGENTS.md`](AGENTS.md).

# LeanDoc

A free tool to generate documentation for Lean 4 projects, using Lean
itself.

## Installation

LeanDoc doesn't have a packaged installer. Hand
[`InstallationPrompt.txt`](InstallationPrompt.txt) to your own AI coding
assistant (Claude or otherwise) — it walks through adding LeanDoc as a
Lake dependency, setting up `docs/` and `leandoc.toml`, and running the
initial generation.

**Note:** modifying comments (including docstrings) in a Lean file can
trigger a surprising amount of rebuilding even when no code actually
changed. On a large project that isn't organized to limit this, build
times can suffer badly — including, potentially, from routine LeanDoc
usage. If you run into this, consider auditing your project with
[LeanPerformance](https://github.com/JVerstry/LeanPerformance), which
will suggest ways to address it.

## The short version

- **What LeanDoc does:** generates documentation for Lean 4 projects by
  fully elaborating them through Lean's own frontend
  (`Lean.Elab.runFrontend`) — not regexes, not hand-rolled syntax parsing.
  See [`docs/index.md`](docs/index.md) for the full pipeline write-up.
- **Toolchain:** managed by `elan` (`lean`, `lake` on `PATH`), pinned via
  `lean-toolchain`. `lake build` builds; `lake exe leandoc [path]` runs
  the real extractor + Markdown renderer (default path `.` — LeanDoc
  documents itself; see [`docs/api/`](docs/api/index.md)).
- **Where things live:** intermediate metadata JSON in `.leandoc/`
  (gitignored, regenerated every run); final rendered docs in `docs/`
  (committed to git); configuration in `leandoc.toml`.

For anything beyond this summary — architecture rationale, why certain
approaches were dropped, specific notes — go to
[`AGENTS.md`](AGENTS.md).

## Users vs. developers of LeanDoc

These are different audiences with different tooling, and it matters
which one a given piece of documentation or setup step is for:

- **Users** depend on LeanDoc to document *their own* project. This is
  what [`InstallationPrompt.txt`](InstallationPrompt.txt) walks
  through: add the `require` line, write `leandoc.toml`, run `lake exe
  leandoc`. Nothing about LeanDoc's own development tooling is relevant
  here, and `InstallationPrompt.txt` deliberately never sets any of it
  up.
- **Developers** work on LeanDoc's own source (this repository). That
  includes `test/` (the test suite, run via `lake exe test`) and
  `.githooks/pre-commit`, which runs that suite before every commit —
  opt in once with `git config core.hooksPath .githooks` (not
  automatic; `.git/hooks/` itself is never committed, so shipping a
  hook via a tracked file and asking developers to point Git at it is
  the standard way to distribute one at all). This costs real time per
  commit (a full `lake exe test` run) in exchange for catching a
  regression locally instead of only in CI after a push.

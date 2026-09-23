# LeanDoc

A free tool to generate documentation for Lean 4 projects, using Lean
itself. Use it to generate documentation that conforms to Mathlib's
own documentation conventions (task T41's `[compliance]` settings), or
to generate documentation however you like with no conventions
enforced at all — the default.

## Installation

LeanDoc doesn't have a packaged installer. Hand
[`InstallationPrompt.txt`](InstallationPrompt.txt) to your own AI coding
assistant (Claude or otherwise) — it walks through adding LeanDoc as a
Lake dependency, setting up `docs/` and `leandoc.toml`, and running the
initial generation. See [`docs/manual.md`](docs/manual.md) for the full
usage manual (configuration, inclusion/exclusion, Jekyll, auditing the
output with [`QualityAuditPrompt.txt`](QualityAuditPrompt.txt), optional
CI/pre-commit checks) once it's installed.

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
  documents itself; see [`docs/reference/`](docs/reference/modules.md) —
  task T25 named it `reference/`, not `api/`: it's a flat dump of every
  included declaration, not a curated public API surface — and
  [`docs/toc.md`](docs/toc.md), task T18's project-wide table of
  contents grouped by declaration kind).
- **Where things live:** intermediate metadata JSON in `.leandoc/`
  (gitignored, regenerated every run); final rendered docs in `docs/`
  (committed to git); configuration in `leandoc.toml`.
- **What gets left out, and why:** LeanDoc filters out Lean's own
  compiler-generated scaffolding — recursors, `noConfusion`, equation
  lemmas, `_sizeOf_*`, and similar (`isNoise`, using the same predicate
  Lean's own environment linter uses, `isAutoDeclOrPrivate_Internal`) —
  since none of that was written by a human and none of it belongs in
  generated docs. This is separate from `@[leandoc_ignore]` (task T19,
  see [`docs/manual.md`](docs/manual.md)'s "Inclusion and exclusion"):
  `isNoise` answers "did the *compiler* generate this," `@[leandoc_
  ignore]` answers "did the *author* deliberately opt this out" — two
  different reasons, checked independently, for the same mechanical
  outcome (omitted from output entirely, not shown with a marker).

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
  includes `test/` (the test suite, run via `lake exe leandoc-test` —
  named that rather than the generic `test`, task T36, since a plain
  `test` executable target would be exposed to any project that
  requires LeanDoc as a dependency, and an installing user typing
  `lake exe test` for their own unrelated test runner would silently
  invoke LeanDoc's instead, crashing confusingly),
  `.githooks/pre-commit`, which runs that suite before every commit —
  opt in once with `git config core.hooksPath .githooks` (not
  automatic; `.git/hooks/` itself is never committed, so shipping a
  hook via a tracked file and asking developers to point Git at it is
  the standard way to distribute one at all) — and `demo/`, a
  standalone Lake project (its own `lean-toolchain`/`lakefile.toml`/
  `leandoc.toml`) used purely as `test/`'s fixture: real source
  `lake exe leandoc` is run against to verify the extractor/renderer,
  not anything an installing user's own project needs or touches.
  This costs real time per commit (a full `lake exe leandoc-test` run)
  in exchange for catching a regression locally instead of only in CI
  after a push.
  - `demo/`, `test/`, and `.githooks/` do still end up physically on
    disk in an installing user's `.lake/packages/LeanDoc/` — confirmed
    empirically (task T35, 2026-09-22, testing a real `git`-based
    `require` against a local clone): Lake fetches the *whole* LeanDoc
    repo via `git clone`, and there's no Lake mechanism to exclude a
    subdirectory from that. But none of it is ever *built* or *run* as
    part of your project: `lake build`/`lake exe leandoc` only build
    LeanDoc's own top-level targets (`LeanDoc.Core`, `Main`), never
    `demo/`'s separate nested Lake package, and `lake exe leandoc`
    operates on your project's own root (confirmed: it generated docs
    for the calling project's own declarations, not `demo/`'s) — the
    same "inert files present, never executed" situation as any other
    Lean/Lake git dependency that happens to ship its own examples or
    tests in its repo.

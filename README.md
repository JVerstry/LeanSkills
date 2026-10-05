# LeanSkills

A set of practical AI skills for Lean projects. Each tool is a prompt, or a small
skill built from prompts, that you hand to an AI assistant working inside your own
Lean project. There is one installer for all of them.

## The tools

### LeanPerformance

Lean and Lake build times can balloon in ways that aren't obvious from reading the
code: a cosmetic doc-comment edit can trigger a multi-minute rebuild cascade, a proof
split for "parallelism" can end up slower, a default tactic can silently dominate a
file's compile time. LeanPerformance is an audit that measures where your project's
build time goes and reports a prioritized, plain-language list of concrete fixes. It
also checks your code's structure and style against Mathlib or CSLib conventions, and
can apply low-risk recommendations one measured batch at a time. In Claude Code it
installs as the `/leanperf` skill.

Manual: [LeanPerformance/MANUAL.md](LeanPerformance/MANUAL.md)

### LeanDoc

A free tool that generates documentation for Lean 4 projects using Lean itself, by
fully elaborating them through Lean's own frontend. It writes plain Markdown that
GitHub Pages can serve, optionally following Mathlib's documentation conventions. It
is added to your Lake project as a dependency, and comes with an audit prompt, and in
Claude Code an optional `/leandoc` skill, that checks the generated documentation.

Manual: [LeanDoc/docs/manual.md](LeanDoc/docs/manual.md), with a short overview in
[LeanDoc/README.md](LeanDoc/README.md)

## Installation

There is no package to install. Hand [`InstallationPrompt.txt`](InstallationPrompt.txt)
to your AI assistant, running inside your Lean project, for example by giving it this
address:

```
https://raw.githubusercontent.com/JVerstry/LeanSkills/main/InstallationPrompt.txt
```

The installer asks which tool you want, LeanPerformance, LeanDoc or both. It
always adds a third small skill, `/leanskills`, described below. It asks once
for what the two skills share: whether to install them for all your projects or only
the current one, and whether they run from local copies of the audit texts or fetch
the latest on every run. Then it carries out each tool's own steps. LeanDoc's steps
include reviewing its configuration with you. The details of each are in the tool's
manual, in its installation section.

### The `/leanskills` skill

`/leanskills` is the entry point once things are installed. On its own it detects
what you have and explains how to use `/leanperf` and `/leandoc`. Its commands:

| Command | What it does |
|---|---|
| `/leanskills status` | What is installed, where, which versions, and whether newer ones are published |
| `/leanskills update` | Updates both tools and itself after one confirmation |
| `/leanskills install [tool]` | Runs the installer, including the throwaway-clone trial |
| `/leanskills doctor` | Read-only health check: files, versions, Lake project, toolchain compatibility, reachability |
| `/leanskills tour` | A guided first run on your project, one confirmed step at a time |
| `/leanskills mode`, `papercuts` | One local/remote setting and one papercuts log for both skills |
| `/leanskills report` | Prepares the text of a GitHub issue; it never posts it |
| `/leanskills uninstall [tool]` | Removes the skills after one confirmation; your project is left alone |

### Try it on a throwaway clone first

The installation edits your project's files. LeanDoc, for example, adds a
dependency to your `lakefile.toml`, updates `lake-manifest.json`, and writes
`leandoc.toml` and `.gitignore` lines. The installer therefore offers to
rehearse on a copy before it touches anything: it clones your project, in its
committed state and including unpushed commits, to a temporary folder outside it, runs the whole
installation there with project-level skills, and shows you what changed. Your
real project is untouched until you choose to apply the same installation to it.
You can also keep the clone to inspect it, or have it deleted. The first
generation of LeanDoc's documentation builds the whole project, so for a large
project (for example one that depends on Mathlib) the installer recommends
skipping it in the trial. Choose "Try it first on a throwaway clone" when it asks.

Two practical points for a project that depends on Mathlib. The clone has no
`.lake`, so the installer offers to copy your project's `.lake/packages` folder
into it (about 7 GB and 2 minutes for a Mathlib project), which keeps Lake's
build outputs so nothing is downloaded or rebuilt. And on Windows the clone
must be in a short path, such as `C:\Temp\<project>-trial`: Mathlib's build
files are nested so deeply that a clone under a long path breaks the cache
unpacking with "The system cannot find the path specified".

Each tool's part of the installer also works alone:
[LeanPerformance/InstallationPrompt.txt](LeanPerformance/InstallationPrompt.txt) and
[LeanDoc/InstallationPrompt.txt](LeanDoc/InstallationPrompt.txt).

## Contributing

Contributing (submitting changes) is limited to this project's contributors.

Anyone can open or report an issue, though. If you hit a problem with a prompt
or have a suggestion, please file an issue.

By contributing to this project, you agree that your contribution is
automatically licensed under this project's license (see [LICENSE](LICENSE)),
with no separate agreement required.

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

There is no package to install, and no command to run yourself. The installer is a
prompt, [`InstallationPrompt.txt`](InstallationPrompt.txt), that you hand to an AI
assistant working inside your Lean project. With Claude Code, for example, open a
terminal in your project's folder, start it, and give it the address of the prompt:

```
cd path/to/your/lean/project
claude
```

then type:

```
Install LeanSkills: fetch https://raw.githubusercontent.com/JVerstry/LeanSkills/main/InstallationPrompt.txt and follow it.
```

Any assistant that can fetch a web page and edit files will do; with another one, paste
the contents of the file instead. The assistant then asks you the questions below.

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

### Try it first, on a throwaway branch or clone

The installation edits your project's files. LeanDoc, for example, adds a
dependency to your `lakefile.toml`, updates `lake-manifest.json`, and writes
`leandoc.toml` and `.gitignore` lines. The installer therefore offers to rehearse
before it touches anything for good, in one of two ways:

- **A throwaway branch** (recommended when your working tree is clean and nobody
  else is working in the folder). The installation runs on a new branch of your
  own project: nothing to copy, no extra disk, and your compiled files in `.lake`
  are already there. It protects less, because it switches the folder, `lake update`
  writes the LeanDoc package into your `.lake`, and the skill folders and
  `leandoc.toml` are not tracked by git. The installer tells you the branch and
  commit to return to, and discarding the trial lists exactly what it will remove
  and asks first.
- **A throwaway clone**, in a short path such as `C:\Temp\<project>-trial`
  (recommended when your tree has uncommitted changes, or something else is working
  in the folder). The clone has the committed state, including unpushed commits, and
  your project is not touched. For a project that depends on Mathlib the installer
  offers to copy your whole `.lake` folder into it (8.3 GB and about 80 seconds for a
  Mathlib project), packages and your own compiled files included, so nothing is
  downloaded or compiled again. On Windows the short path matters: Mathlib's build
  files are nested so deeply that a clone under a long path breaks the cache
  unpacking with "The system cannot find the path specified".

In either case the skills are installed for the project only, the first generation
of LeanDoc's documentation (which builds the whole project) can be skipped, and for
a trial `/leanperf dry` is the cheap way to try the audit. When the installer asks
whether to install directly or try it first, answer that you want a trial, then pick the
branch or the clone. To try the branch route, check first that `git status` shows nothing
uncommitted and that no other session or editor is working in the project folder.

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

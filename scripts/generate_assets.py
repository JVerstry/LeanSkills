#!/usr/bin/env python3
"""Embeds real static asset files (assets/) into a Lean source file
(LeanDoc/Assets.lean) as string constants, so `leandoc`'s compiled
executable carries them regardless of the working directory it's run
from (task T29) -- it can't just read assets/ at runtime, since when
LeanDoc is installed as a dependency, the executable runs with the
*target* project's directory as its cwd, not LeanDoc's own.

Run by hand whenever a file under assets/ changes; the generated
LeanDoc/Assets.lean is committed to git like any other source file, not
regenerated automatically as part of `lake build`.
"""

import pathlib

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
OUTPUT = REPO_ROOT / "LeanDoc" / "Assets.lean"

# (Lean identifier, source file relative to repo root)
ASSETS = [
    ("styleCss", "assets/style.css"),
    ("defaultLayoutHtml", "assets/layouts/default.html"),
    ("colorSchemeJs", "assets/color-scheme.js"),
    ("searchJs", "assets/search.js"),
]


def lean_string_literal(text: str) -> str:
    # Lean string literals accept literal embedded newlines directly
    # (verified empirically before writing this script) -- only
    # backslashes and double quotes need escaping.
    escaped = text.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def main() -> None:
    parts = [
        "-- GENERATED FILE (task T29) -- do not edit by hand.",
        "-- Regenerate with `python scripts/generate_assets.py` after",
        "-- changing a file under assets/.",
        "",
        "namespace LeanDoc.Assets",
        "",
    ]
    for name, rel_path in ASSETS:
        content = (REPO_ROOT / rel_path).read_text(encoding="utf-8")
        parts.append(f"/-- Embedded from `{rel_path}`. -/")
        parts.append(f"def {name} : String := {lean_string_literal(content)}")
        parts.append("")
    parts.append("end LeanDoc.Assets")
    parts.append("")
    OUTPUT.write_text("\n".join(parts), encoding="utf-8")
    print(f"Wrote {OUTPUT} ({sum(1 for _ in parts)} lines)")


if __name__ == "__main__":
    main()

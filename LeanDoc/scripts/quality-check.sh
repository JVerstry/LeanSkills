#!/bin/sh
# LeanDoc quality check: the mechanical checks from QualityAuditPrompt.txt
# that a script can decide without judgement, for use in an opt-in
# commit-msg hook or CI step (see "Quality checks on commit or CI" in
# LeanDoc's manual). It reads the committed docs; it does not regenerate
# them (the freshness templates do that) and it never modifies anything.
#
# Checks:
#   - every Jekyll `link` tag names a file that exists (a missing target
#     fails the whole Jekyll build);
#   - the project's _layouts/default.html is not older than the layout
#     this LeanDoc ships (its leandoc-layout-version stamp);
#   - no Lean-generated scaffolding (.rec, .casesOn, .noConfusion, ...)
#     leaked into docs/reference.
#
# Strict by default: exit 1 if there is a finding. If the commit message
# starts with a WIP marker (`WIP`, `WIP: ...`, `[WIP] ...`, any case),
# the findings are still printed in full but as warnings, and the exit
# status is 0 ("I know, but this is WIP").
#
# Usage: quality-check.sh [--docs-dir DIR] [--message-file FILE]
#                         [--message TEXT] [--wip]
#   --docs-dir       the project's docs directory (default: docs)
#   --message-file   a commit message file (the commit-msg hook's $1)
#   --message        a commit message (for CI); only its first line counts
#   --wip            behave as if the message had a WIP marker

set -u

docs_dir=docs
mode=strict
message=""
script_dir=$(cd "$(dirname "$0")" && pwd)

while [ $# -gt 0 ]; do
  case "$1" in
    --docs-dir) docs_dir="$2"; shift 2 ;;
    --message-file) message=$(head -n 1 "$2" 2>/dev/null); shift 2 ;;
    --message) message=$(printf '%s\n' "$2" | head -n 1); shift 2 ;;
    --wip) mode=wip; shift ;;
    -h|--help) sed -n '2,/^set -u/p' "$0" | sed '$d'; exit 0 ;;
    *) echo "quality-check: unknown option: $1" >&2; exit 2 ;;
  esac
done

if printf '%s\n' "$message" | grep -Eiq '^\[?wip\]?([^[:alnum:]]|$)'; then
  mode=wip
fi

if [ ! -d "$docs_dir" ]; then
  echo "quality-check: $docs_dir is not a directory (use --docs-dir)." >&2
  exit 2
fi

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

# Drops {% raw %} ... {% endraw %} regions (inline or multi-line): an
# example inside one is shown literally, not run by Jekyll.
strip_raw() {
  sed 's/{% raw %}.*{% endraw %}//g' "$1" |
    awk '/{% raw %}/ { skip = 1 } !skip { print } /{% endraw %}/ { skip = 0 }'
}

# 1. Link targets (Jekyll output only: it has a _layouts directory).
if [ -d "$docs_dir/_layouts" ]; then
  find "$docs_dir" -name '*.md' -not -path '*/_site/*' -print | while IFS= read -r page; do
    strip_raw "$page" | grep -o '{% link [^%]* %}' 2>/dev/null |
      sed 's/^{% link //; s/ %}$//' | while IFS= read -r target; do
        [ -e "$docs_dir/$target" ] ||
          echo "link target missing: $page -> $target" >> "$tmp"
      done
  done
fi

# 2. Outdated layout.
layout="$docs_dir/_layouts/default.html"
shipped_layout="$script_dir/../assets/layouts/default.html"
if [ -f "$layout" ] && [ -f "$shipped_layout" ]; then
  stamp() {
    sed -n 's/.*leandoc-layout-version: *\([0-9][0-9]*\).*/\1/p' "$1" | head -n 1
  }
  have=$(stamp "$layout")
  want=$(stamp "$shipped_layout")
  have=${have:-0}
  if [ -n "$want" ] && [ "$have" -lt "$want" ]; then
    echo "outdated layout: $layout is version $have, current is $want (see \"Upgrading LeanDoc\" in the manual)" >> "$tmp"
  fi
fi

# 3. Scaffolding that leaked into the generated reference.
if [ -d "$docs_dir/reference" ]; then
  grep -rnE '^### `[^`]*(\.(rec|recOn|casesOn|noConfusion|noConfusionType|brecOn|binductionOn|below|ibelow|injEq|sizeOf_spec)|_sizeOf_[0-9]+)`$' \
    "$docs_dir/reference" --include='*.md' 2>/dev/null |
    sed 's/^/scaffolding leaked into the docs: /' >> "$tmp"
fi

count=$(wc -l < "$tmp" | tr -d ' ')
if [ "$count" -eq 0 ]; then
  echo "quality-check: no findings"
  exit 0
fi

if [ "$mode" = wip ]; then
  while IFS= read -r line; do echo "quality-check: warning: $line" >&2; done < "$tmp"
  echo "quality-check: $count finding(s); the commit message has a WIP marker, so they are warnings only." >&2
  exit 0
fi

while IFS= read -r line; do echo "quality-check: $line" >&2; done < "$tmp"
echo "quality-check: $count finding(s). Fix them, or start the commit message with WIP to commit anyway (they stay warnings)." >&2
exit 1

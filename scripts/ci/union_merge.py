#!/usr/bin/env python3
"""Resolve git merge conflicts in docs by keeping both sides (ours, then theirs).

For PLAN.md, PROGRESS.md and OWNER_TODO.md, where two steps each added table rows or History lines. Afterwards look
for a row both sides changed (it now appears twice) and keep the newer one: union_merge.py --dupes <file> lists them.
Never use it on code, data or translations (take one side and re-import instead).

Usage: python3 scripts/ci/union_merge.py <file> [<file> ...]
       python3 scripts/ci/union_merge.py --dupes docs/roadmap/vX.Y.Z/PLAN.md
"""
import re
import sys

CONFLICT = r"<<<<<<< [^\n]*\n(.*?)=======\n(.*?)>>>>>>> [^\n]*\n"


def main() -> None:
    if sys.argv[1:2] == ["--dupes"]:
        for p in sys.argv[2:]:
            seen = {}
            for n, line in enumerate(open(p, encoding="utf-8"), 1):
                m = re.match(r"\| ([A-Z]+[0-9]*[a-z]?|[A-Z]{2,}[0-9]?) \|", line)
                if m:
                    key = m.group(1)
                    if key in seen:
                        print(f"{p}:{n}: row {key} also at line {seen[key]}")
                    seen.setdefault(key, n)
        return
    for p in sys.argv[1:]:
        text = open(p, encoding="utf-8").read()
        text, count = re.subn(CONFLICT, lambda m: m.group(1) + m.group(2), text, flags=re.S)
        open(p, "w", encoding="utf-8").write(text)
        print(f"{p}: {count} conflict(s) kept both sides")


if __name__ == "__main__":
    main()

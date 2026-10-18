#!/usr/bin/env bash
# Printed at the start of every Claude Code session (.claude/settings.json SessionStart hook; owner, 2026-10-18): the
# branch, uncommitted files, and the active version's "Where we are" block, so a new session picks up without the old
# conversation. Read-only: it changes nothing.
cd "$(dirname "${BASH_SOURCE[0]}")/../.." || exit 0
echo "Branch: $(git rev-parse --abbrev-ref HEAD 2>/dev/null) at $(git log --oneline -1 2>/dev/null)"
dirty=$(git status --short 2>/dev/null | grep -v '^??' | wc -l | tr -d ' ')
echo "Uncommitted tracked changes: $dirty"
progress=$(ls -d docs/roadmap/v*/PROGRESS.md 2>/dev/null | sort -V | tail -1)
if [ -n "$progress" ]; then
	echo "Active: $progress"
	awk '/^## Where we are/{on=1} on&&/^## /&&!/^## Where we are/{exit} on' "$progress"
fi
open=$(grep -c '^| *☐' docs/OWNER_TODO.md 2>/dev/null || echo 0)
echo "Open owner items in docs/OWNER_TODO.md: $open"
echo "Lead workflow: docs/process/LEAD_PLAYBOOK.md"
exit 0

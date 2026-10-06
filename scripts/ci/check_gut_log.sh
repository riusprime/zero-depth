#!/usr/bin/env bash
# Fails when a GUT run "passed" without really testing (docs/architecture/TEST_MATRIX.md §3, LESSONS L5).
# Usage: scripts/ci/check_gut_log.sh <gut.log> [min_count_file]
set -euo pipefail
LOG="$1"
MIN_FILE="${2:-tests/MIN_TEST_COUNT}"
# Strip ANSI colour codes before matching.
CLEAN="$(sed -E 's/\x1B\[[0-9;]*[mK]//g' "$LOG")"

fail() { echo "check_gut_log: FAIL: $*" >&2; exit 1; }

echo "$CLEAN" | grep -q "Passing Tests" || fail "no GUT summary (GUT did not run)"
for pattern in "SCRIPT ERROR" "Parse Error" "Failed to load script" "\[GUT ERROR\]"; do
	if echo "$CLEAN" | grep -E -q "$pattern"; then
		echo "$CLEAN" | grep -E "$pattern" | head -5 >&2
		fail "log contains '$pattern'"
	fi
done
PASSING="$(echo "$CLEAN" | grep -E '^Passing Tests' | tail -1 | awk '{print $3}')"
TESTS="$(echo "$CLEAN" | grep -E '^Tests ' | tail -1 | awk '{print $2}')"
[[ "$PASSING" =~ ^[0-9]+$ ]] || fail "could not read the passing count"
[[ "$PASSING" == "$TESTS" ]] || fail "$PASSING of $TESTS tests passed"
MIN="$(tr -d '[:space:]' < "$MIN_FILE")"
(( PASSING >= MIN )) || fail "$PASSING passing tests, below the committed minimum of $MIN"
echo "check_gut_log: ok ($PASSING passing, minimum $MIN)"

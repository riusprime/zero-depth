#!/usr/bin/env bash
# Sums the passing tests of the shard logs (scripts/ci/gut_shard.sh) and holds them to tests/MIN_TEST_COUNT, so a
# sharded run is held to the same floor as one full run (TEST_MATRIX §3, LESSONS L5).
# Usage: bash scripts/ci/check_gut_total.sh <gut_shard log>...
set -euo pipefail
[[ $# -gt 0 ]] || { echo "check_gut_total: no logs" >&2; exit 1; }
TOTAL=0
for log in "$@"; do
	n="$(sed -E 's/\x1B\[[0-9;]*[mK]//g' "$log" | grep -E '^Passing Tests' | tail -1 | awk '{print $3}')"
	[[ "$n" =~ ^[0-9]+$ ]] || { echo "check_gut_total: FAIL: no passing count in $log" >&2; exit 1; }
	echo "check_gut_total: $log $n"
	TOTAL=$((TOTAL + n))
done
MIN="$(tr -d '[:space:]' < tests/MIN_TEST_COUNT)"
(( TOTAL >= MIN )) || { echo "check_gut_total: FAIL: $TOTAL passing tests, below the committed minimum of $MIN" >&2; exit 1; }
echo "check_gut_total: ok ($TOTAL passing, minimum $MIN)"

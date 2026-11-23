#!/usr/bin/env bash
# Fails when a GUT run "passed" without really testing (docs/architecture/TEST_MATRIX.md §3, LESSONS L5).
# Usage: scripts/ci/check_gut_log.sh <gut.log> [min_count_file]
# v0.8.0 (2026-10-18): grep -q reads from a here-string, not a pipe: under pipefail an early-exiting grep -q made
# the echo fail with SIGPIPE on a big log, and a green seams run (469/469) read as "no GUT summary".
set -euo pipefail
LOG="$1"
MIN_FILE="${2:-tests/MIN_TEST_COUNT}"
# Strip ANSI colour codes before matching.
CLEAN="$(sed -E 's/\x1B\[[0-9;]*[mK]//g' "$LOG")"

fail() { echo "check_gut_log: FAIL: $*" >&2; exit 1; }

grep -q "Passing Tests" <<<"$CLEAN" || fail "no GUT summary (GUT did not run)"
for pattern in "SCRIPT ERROR" "Parse Error" "Failed to load script" "\[GUT ERROR\]"; do
	if grep -E -q "$pattern" <<<"$CLEAN"; then
		echo "$CLEAN" | grep -E "$pattern" | head -5 >&2
		fail "log contains '$pattern'"
	fi
done
PASSING="$(echo "$CLEAN" | grep -E '^Passing Tests' | tail -1 | awk '{print $3}')"
TESTS="$(echo "$CLEAN" | grep -E '^Tests ' | tail -1 | awk '{print $2}')"
[[ "$PASSING" =~ ^[0-9]+$ ]] || fail "could not read the passing count"
# A missed bot or balance target is reported, not hidden: its test calls pending("NOT MET, ...") with the numbers, so a
# miss neither turns the suite red nor passes silently (the owner's choice). A test in the run summary counts as
# reported only when it has at least one pending line and every line under it is a pending that starts with "NOT MET";
# a failure, a risky test, a skipped script or any other pending still fails the run.
SUMMARY="$(awk '/^= Run Summary/{s=""; on=1; next} /^Totals/{on=0} on{s=s $0 "\n"} END{printf "%s", s}' <<<"$CLEAN")"
REPORTED="$(awk '
	function close_test() { if (name != "" && ok && seen) n++; name="" }
	/^- / { close_test(); name=$0; ok=1; seen=0; next }
	/^[[:space:]]*\[Pending\]:[[:space:]]+NOT MET/ { if (name != "") seen=1; next }
	/^[[:space:]]*\[(Failed|Pending|Risky)\]/ { ok=0; next }
	/^[[:space:]]*(Did not assert|before_all\/after_all)/ { ok=0; next }
	END { close_test(); print n+0 }
' <<<"$SUMMARY")"
if grep -q "\[Risky\] Script was skipped" <<<"$SUMMARY"; then fail "a test script was skipped"; fi
(( PASSING + REPORTED == TESTS )) || fail "$PASSING of $TESTS tests passed ($REPORTED reported as NOT MET)"
if (( REPORTED > 0 )); then
	echo "check_gut_log: $REPORTED test(s) report a missed target:"
	grep -E '^[[:space:]]*\[Pending\]:[[:space:]]+NOT MET' <<<"$SUMMARY" | sed -E 's/^[[:space:]]*\[Pending\]:[[:space:]]+/  /'
fi
MIN="$(tr -d '[:space:]' < "$MIN_FILE")"
(( PASSING >= MIN )) || fail "$PASSING passing tests, below the committed minimum of $MIN"
echo "check_gut_log: ok ($PASSING passing, $REPORTED NOT MET, minimum $MIN)"

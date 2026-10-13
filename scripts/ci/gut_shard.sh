#!/usr/bin/env bash
# Runs one shard of the GUT suite, so GitHub can run the suite as parallel jobs (owner, 2026-10-13: the full run
# "takes a lot of time"; CLAUDE.md "Testing before a push"). Every test_*.gd under tests/ belongs to exactly one
# shard; `--check` proves it.
# Usage: bash scripts/ci/gut_shard.sh <sim_a|sim_b|sim_c|e2e|presentation|rest>   (writes build/gut_<shard>.log)
#        bash scripts/ci/gut_shard.sh --check                                   (every test file in exactly one shard)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"
SHARDS=(sim_a sim_b sim_c e2e presentation rest)
# The slowest sim files get a shard of their own (the 2026-10-13 run: sim_b took 68 of its 71 minutes; local
# JUnit times: these five 2,074 s, the rest of i-z 2,086 s, a-h 2,122 s). Rebalance from build/gut.xml when one
# shard runs much longer than the others.
HEAVY_SIM=(test_modifier_smoke_mx4.gd test_modifier_smoke.gd test_wand_smoke.gd test_wand_migration.gd
	test_starglow_patches.gd)

_not_heavy() {
	local pat
	pat="$(printf '/%s$|' "${HEAVY_SIM[@]}")"
	grep -Ev "${pat%|}"
}

# The test scripts of one shard, one res:// path per line.
files_of() {
	case "$1" in
	sim_a) find tests/unit/sim -maxdepth 1 -name 'test_[a-h]*.gd' | _not_heavy ;;
	sim_b) find tests/unit/sim -maxdepth 1 -name 'test_*.gd' ! -name 'test_[a-h]*.gd' | _not_heavy ;;
	sim_c) for f in "${HEAVY_SIM[@]}"; do echo "tests/unit/sim/$f"; done ;;
	e2e) find tests/e2e -name 'test_*.gd' ;;
	presentation) find tests/unit/presentation -name 'test_*.gd' ;;
	rest)
		find tests -name 'test_*.gd' ! -path 'tests/unit/sim/*' ! -path 'tests/e2e/*' \
			! -path 'tests/unit/presentation/*'
		;;
	*)
		echo "gut_shard: unknown shard '$1' (${SHARDS[*]})" >&2
		exit 2
		;;
	esac | sort | sed 's|^|res://|'
}

if [[ "${1:-}" == "--check" ]]; then
	all="$(find tests -name 'test_*.gd' | sort | sed 's|^|res://|')"
	listed="$(for s in "${SHARDS[@]}"; do files_of "$s"; done | sort)"
	if [[ "$all" != "$listed" ]]; then
		echo "gut_shard: the shards don't cover every test file exactly once:" >&2
		diff <(echo "$all") <(echo "$listed") >&2 || true
		exit 1
	fi
	echo "gut_shard: ok ($(echo "$all" | wc -l) test files in ${#SHARDS[@]} shards)"
	exit 0
fi

SHARD="${1:?usage: gut_shard.sh <shard>|--check}"
LIST="$(files_of "$SHARD" | paste -sd, -)"
[[ -n "$LIST" ]] || {
	echo "gut_shard: shard '$SHARD' has no test files" >&2
	exit 1
}
mkdir -p build
set +e
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest="$LIST" \
	-gjunit_xml_file="build/gut_$SHARD.xml" -gexit 2>&1 | tee "build/gut_$SHARD.log"
GUT_EXIT=${PIPESTATUS[0]}
set -e
[[ $GUT_EXIT -eq 0 ]] || {
	echo "gut_shard: GUT exited $GUT_EXIT" >&2
	exit "$GUT_EXIT"
}
bash scripts/ci/check_gut_log.sh "build/gut_$SHARD.log" <(echo 1)

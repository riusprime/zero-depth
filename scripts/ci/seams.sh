#!/usr/bin/env bash
# The lead's check after merging agents' branches (CLAUDE.md "Testing before a push"; owner, 2026-10-13): the tests
# where separate changes meet. Every cross-step failure the full runs found in v0.7.0-v0.7.5 is in this set (the dev
# panel's folder list, old saves, orphan nodes across restarts, the every-card soak). It is not the full suite: the PR
# into main runs that once on GitHub.
# Usage: bash scripts/ci/seams.sh            (writes build/seams.log)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"
mkdir -p build

godot --headless --path . --editor --import --quit > build/import.log 2>&1 || true
if sed -E 's/\x1B\[[0-9;]*[mK]//g' build/import.log | grep -E -q "^(ERROR|SCRIPT ERROR)"; then
	sed -E 's/\x1B\[[0-9;]*[mK]//g' build/import.log | grep -E "^(ERROR|SCRIPT ERROR)" | head -10 >&2
	echo "seams: import reported errors" >&2
	exit 1
fi
gdformat --check src scripts tests
gdlint src scripts tests
bash scripts/ci/gut_shard.sh --check

DIRS="res://tests/content,res://tests/arch,res://tests/golden,res://tests/unit/application,res://tests/unit/app"
DIRS="$DIRS,res://tests/unit/debug"
FILES=(
	tests/unit/sim/test_wand.gd
	tests/unit/sim/test_combos.gd
	tests/unit/sim/test_modifier_smoke.gd
	tests/unit/sim/test_readable_cause.gd # v0.7.5 BF2: a boss's new patterns met the readable-cause rule here
	tests/unit/sim/test_world_snapshot.gd # v0.8.0: SR's shop-room tables met the snapshot guard here
	tests/e2e/test_e2e_damage_soak.gd
	tests/e2e/test_e2e_saves.gd
	tests/e2e/test_e2e_old_save.gd
	tests/e2e/test_e2e_run_flow.gd
	tests/e2e/test_e2e_shell.gd
	tests/e2e/test_e2e_pad_menus.gd
	tests/e2e/test_e2e_dev_master_panel.gd
	tests/e2e/test_e2e_bosses_2.gd
	tests/e2e/test_e2e_boss_signatures.gd
	tests/e2e/test_e2e_boss_strikes.gd
	tests/e2e/test_e2e_final_boss.gd
	tests/unit/sim/test_boss_pace.gd # v0.8.0: BP (boss damage by hits) meets RR and loop scaling here
	tests/e2e/test_e2e_attack_order.gd # v0.8.0: AO (card order) met RR (tiers, counts) here
	tests/unit/sim/test_rarity.gd
	tests/unit/sim/test_items.gd # v0.8.0: AO (new cards) and RR (tiers) met the pool count here
	tests/unit/sim/test_nemesis.gd # v0.8.0: RR's tiers changed the Nemesis's pick order here
	tests/unit/sim/test_intensity_director.gd # v0.8.0: N5 (the director) meets spawning, snapshots and old saves here
	tests/unit/sim/test_final_pace.gd # v0.8.0: N2 (the final boss paced to your damage) meets RR/BP/N1 builds here
	tests/e2e/test_e2e_health_bars.gd # v0.8.0: N4 (the bars) meets N2 (the final boss) and every boss here
	tests/unit/presentation/test_attack_visuals_2.gd # v0.8.0: BS2 moves met AV2s every-move check here
	tests/e2e/test_e2e_loading_cover.gd # v0.8.0: N3's loading cover sits in every floor load (start, portal)
	tests/e2e/test_e2e_builds.gd # v0.8.0: N3's cover moved the run start past the pick press; the first shot met it here
	tests/e2e/test_e2e_codex.gd # v0.8.0: AO's new cards reflowed the Codex grid under RR's tier walk here
	tests/e2e/test_e2e_pad_aim.gd # v0.8.0: N9 (pad aim follows the walk) meets the loading cover and the builds here
	tests/e2e/test_e2e_arrival.gd # v0.8.0: N11 (the arrival) meets the loading cover, spawning and the HUD here
	tests/e2e/test_e2e_boss_signatures_2.gd # v0.8.0: N11 (arrival) and N14 (the default floor) met the Foundry meltdown here
	tests/e2e/test_e2e_wand_build.gd # v0.8.0: a Swap given mid-arrival (N11) froze the landing under the hidden HUD here
)
LIST="$(printf 'res://%s\n' "${FILES[@]}" | paste -sd, -)"
set +e
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir="$DIRS" -ginclude_subdirs -gtest="$LIST" \
	-gexit 2>&1 | tee build/seams.log
GUT_EXIT=${PIPESTATUS[0]}
set -e
[[ $GUT_EXIT -eq 0 ]] || { echo "seams: GUT exited $GUT_EXIT" >&2; exit "$GUT_EXIT"; }
bash scripts/ci/check_gut_log.sh build/seams.log <(echo 1)

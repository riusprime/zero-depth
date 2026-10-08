# ABILITIES_2: do v0.4.0 Step AB's three abilities, eight ability combos and the Overrun branch pass the suite and reach the real game?

- **Status:** RUN
- **Build:** `e5e32e7` on the AB worktree branch (cut from `claude/lucid-fermat-9wv2tf` at `c60512d`, EN merged);
  Godot `4.7.2.stable.official.ed1daf0bf`; OS Linux (cloud container), screenshots under Xvfb with Vulkan on llvmpipe.
  The final commit adds only this file, PROGRESS and `tests/MIN_TEST_COUNT` on top of it.
- **Date:** 2026-10-08
- **Who ran it:** agent

## Commands
```
godot --headless --path . --editor --import --quit
gdformat --check src scripts tests && gdlint src scripts tests
bash scripts/verify.sh
python3 scripts/audio/generate_sfx.py --check
xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver vulkan -s scripts/shots/abilities_2.gd
```

## Raw output
Import (`build/evidence/import.log`): exit 0, 0 lines starting `ERROR` or `SCRIPT ERROR`.

Lint:
```
419 files would be left unchanged
Success: no problems found
```

`bash scripts/verify.sh` (tail, `build/evidence/verify.log`):
```
Totals
------
Scripts             136
Tests               845
Passing Tests       845
Asserts           430784
Time              637.204s


---- All tests passed! ----

Results saved to build/gut.xml
check_gut_log: ok (845 passing, minimum 812)
exit 0
```

The Overrun generation property test (`tests/unit/sim/test_overrun.gd`, seeds 1..1000; each floor: the Overrun room is
reachable, not the hall, boss room, its host or the portal room, off the shortest path to the boss, the boss reachable
without entering it, every doorway into it framed):
```
* test_every_floor_has_one_overrun_room_off_the_boss_path
    overrun over 1000 seeds: 0 floors without one, 979 dead ends
```

The e2e through `main.tscn` (input only: keys, the left stick, mouse clicks on the dev panel):
```
res://tests/e2e/test_e2e_abilities_ab.gd
* test_dev_panel_grants_a_pair_and_storm_bombs_evolve
* test_walk_through_the_red_door_into_an_overrun
```

The readable-cause test (`tests/unit/sim/test_readable_cause.gd`, bars unchanged): 4/4 passed, no violation.

Sounds: `generate_sfx.py` rendered 74 files (generator v2); `--check` reported `0 difference(s)`; the five new
files (`arc_field`, `frost_nova`, `flame_trail`, `overrun_enter`, `overrun_clear`) are in the manifest, and no
existing file changed.

Screenshots (`build/evidence/shots.log`):
```
Vulkan 1.4.318 - Forward+ - Using Device #0: Unknown - llvmpipe (LLVM 20.1.2, 256 bits)
abilities_2: renderer=forward_plus
abilities_2: shot …/build/shots/v0.4.0/abilities_2/01_element_abilities_and_combo.png
abilities_2: shot …/build/shots/v0.4.0/abilities_2/02_overrun_room.png
```

## Target bands
| Metric | Target | Source |
|---|---|---|
| Suite | all pass, ≥ the committed minimum | CLAUDE.md "Testing before a push" |
| Overrun room | one per floor where possible, reachable, off the boss path, over 1,000 seeds | lead's step brief |
| Readable cause | 0 violations, bars unchanged | lead's step brief |
| Goldens | unchanged unless on purpose | CLAUDE.md |

## Result
| Metric | Measured | In band? |
|---|---|---|
| Suite | 845 / 845 (was 812) | yes |
| Overrun room | 1,000 / 1,000 floors have one; 979 of them a dead end | yes |
| Readable cause | 0 violations | yes |
| Goldens | none regenerated; the replay golden passes unchanged | yes |

## Interpretation
The three abilities, the eight ability combos and the Overrun branch are in the sim, reachable from the real game and
covered by unit and e2e tests. Nothing here measures balance or feel: every number (the ability table, the combos,
×1.5 / +50 % / 12 kills / 2× shards) is a starting value, and how they play is the owner's call after playing
(OWNER ONLY: feel, fun, balance). Interpretations of PLAN lines are listed in PROGRESS "Open".

## Screenshots
Shot setup (not play): the script adds six Chargers by the hero, grants Bomb Lobber, Frost Nova and Arc Field to L3
directly and later puts the hero just inside the Overrun door; the input paths are the e2e above.
- [`abilities_2_combo.png`](abilities_2_combo.png): the Superconductor combo card (both ability icons), the two combo
  badges (Storm Bombs, Superconductor) bottom right, Frost Nova's ring, bomb blasts and a lightning bolt, frost on
  the Chargers, the ability HUD with level pips.
- [`abilities_2_overrun.png`](abilities_2_overrun.png): the red door frame, the OVERRUN banner with its kill count
  (8 / 12), the minimap's Overrun mark and red doorway.

## After merging the lead branch (BO, CP, SC; `55a895d`), 2026-10-08
Build `99d5dc7` (the merge with conflicts resolved; the final merge commit adds only this section, PROGRESS and
`tests/MIN_TEST_COUNT`). How the two sides compose:
- Bombs: `Abilities.drop_bomb` marks every Bomb Lobber bomb (thrown, or Blink Charge's) as splittable, so Cluster
  Payload splits it; bomblets share the bomb's root and are never splittable. Storm Bombs chains only from a
  splittable bomb's blast and at most once per root, so a Cluster bomb chains once and its bomblets never chain.
- A blink runs both AbilityMods.on_blink (Afterimage) and AbilityCombos.on_blink (Blink Charge).
- Arc Field, Frost Nova and Flame Trail use `Stats.auto_cooldown` (Fast Hands applies; the HUD reads the same).
- Overrun on SC's spawn director: alive cap = `SpawnTable.cap(floor, tier)` x 1.5 and interval = `interval(tier)` / 1.5
  while inside; every pack member that arrives then gets its tier-scaled HP x 1.5 and its tier power
  (`ActorStore.power`, used by every enemy attack, bolt and mine) x 1.5. The Damage-pipeline multiplier AB had is
  gone (it would have doubled with power).

Commands and raw output:
```
godot --headless --path . --editor --import --quit        # exit 0, 0 ERROR lines
gdformat --check src scripts tests && gdlint src scripts tests
438 files would be left unchanged
Success: no problems found

bash scripts/verify.sh
Scripts             145
Tests               924
Passing Tests       924
Asserts           451844
Time              693.678s
---- All tests passed! ----
check_gut_log: ok (924 passing, minimum 891)
exit 0

godot --headless --path . -s scripts/checks/readable_cause.gd     (build/readable_cause.json; summary)
	"deaths_checked": 24,
	"floor_ticks": 3600,
	"runs": 36,
	"seeds": 12,
	"violations": 0

bash scripts/ci/export_smoke.sh      # run from the scratchpad, outside the project folder; exit 0
  ok    600-tick World run hash e5365ddb6dcb matches the project's
  ok    manifest hash 462435cea790 matches the project's
  ok    audio cues: 79
0 miss(es)
```
Goldens: none changed by AB or the merge (the replay golden passes; the export smoke's hash is SC's `e5365ddb…`).


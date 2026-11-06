# O5_LOOPS: reasons to loop (O5a) and loops that remix rules (O5b)

- **Status:** RUN
- **Build:** branch `v0105-o5`: `c40ce826` (O5a), `9f59d7ed` (O5b), merged with `claude/v0100-cleanup` at `38e7d086`;
  the runs below are of `38e7d086` plus the uncommitted fix-ups committed after them (the Q6 loop test's numbers for the
  new HP step, the shot script's settle frames, a design-note line). Godot `4.7.2.stable.official.ed1daf0bf`; OS
  Windows 11 Pro 10.0.26200 (the owner's PC)
- **Date:** 2026-11-02
- **Who ran it:** agent

Design and picks: [`../O5_LOOPS.md`](../O5_LOOPS.md).

## Commands

Each with its own `APPDATA=$(mktemp -d)`, after `godot --headless --path . --editor --import --quit`, run in parallel:

```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/content,res://tests/arch,res://tests/golden -ginclude_subdirs -gexit
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/application/test_loop_rules.gd,res://tests/unit/application/test_loop_records.gd,res://tests/unit/application/test_codex_lore.gd,res://tests/unit/application/test_ascension_saves.gd,res://tests/unit/application/test_old_saves.gd,res://tests/unit/sim/test_ascension.gd,res://tests/unit/application/test_achievements.gd,res://tests/unit/presentation/test_run_recap.gd,res://tests/unit/presentation/test_ascension_views.gd,res://tests/unit/application/test_meta_progress.gd,res://tests/unit/presentation/test_achievements_view.gd,res://tests/unit/sim/test_collectibles.gd -gexit
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/e2e/test_e2e_ascension.gd,res://tests/e2e/test_e2e_codex.gd,res://tests/e2e/test_e2e_rune_fragments.gd,res://tests/e2e/test_e2e_saves.gd,res://tests/e2e/test_e2e_wardrobe.gd,res://tests/e2e/test_e2e_hub.gd -gexit
godot --path . --fixed-fps 60 --resolution 1600x900 --position -10000,-10000 -s scripts/shots/loops_o5.gd -- lang=en
gdformat --check src scripts tests && gdlint src scripts tests
```

## Raw output (the summary lines of each run)

```
== content + arch + golden
Tests               172
Passing Tests       172
Asserts           31177
== unit files
Tests               109
Passing Tests       109
Asserts            4252
== e2e files
Tests                21
Passing Tests        21
Asserts             405
== shots
loops: renderer=forward_plus lang=en
loops: shot C:/Users/extri/Desktop/zerodepth/wt-o5/build/shots/v0.10.5/loops/en_hub_records.png (1600, 900)
loops: rule elite_hunt
loops: shot C:/Users/extri/Desktop/zerodepth/wt-o5/build/shots/v0.10.5/loops/en_loop2_floor_card.png (1600, 900)
loops: card Loop 2 · Floor 1 Ruins New rule: Elite Hunt Elite rooms appear on every floor. Max HP +15
== lint
Success: no problems found
```

## Failures met on the way (fixed before the runs above)

- First run (before the merge): `tests/arch` failed: `run_definition.gd (content) uses LoopRules (sim)` and
  `hud.gd (presentation) uses LoopRules (sim)`. Content now has its own `RunDefinition.LOOP_RULE_IDS` (a test keeps it
  equal to `LoopRules.POOL`); the HUD builds the rule's keys itself.
- `test_e2e_codex`: `[14] expected to equal [9]: nine lines`: the Lore page has the five rule lines now (the test
  reads `CodexStore.LORE_IDS.size()`).
- `test_e2e_ascension`: the rule's Codex line was read 3 frames into loop 2, before the recorder's first tick; it is
  read after the arrival now.
- `tests/unit/sim/test_ascension.gd` `test_loop_scaling_compounds_and_caps` failed on this branch's base (`13215121`)
  before any O5 change (floor 1's EP3 ease missing from the expected value); `claude/v0100-cleanup` had fixed it, so
  the branch merged it. Its Q6 tests then read ×3.5 (was ×6): `[1000, 3500, 12250, 42875, 100000]`.
- `test_shielded_guards_every_normal_enemys_front`: the test indexed the actor by its id (a test bug).

## Goldens

None moved: `tests/golden` passed unchanged (a loop-1 world hashes as before; the loop rules hash only once a loop drew
one).

## Shots (looked at)

- `build/shots/v0.10.5/loops/en_loop2_floor_card.png`: "Loop 2 · Floor 1", Ruins, "Max HP +15", then in the Loop
  device's violet "New rule: Elite Hunt" / "Elite rooms appear on every floor." The rule's two lines sit over the hero
  in the start hall (readable; the card fades as before).
- `build/shots/v0.10.5/loops/en_hub_records.png`: the hub Codex's Achievements page opens on a Records block: "Deepest
  loop: GUN 3 · BLADE 2", "Fastest true ending: GUN 25:40 · BLADE —", then the groups. The weapon names are the build
  keys' capitals (`BUILD_GUN`).

Not shot: Spanish (the strings are in `locale/strings.csv`; `test_locale_coverage` passed), the recap's record lines
(unit-tested in `test_loop_records.gd`).

## Not run

- The full suite (GitHub runs it on the PR). Feel and whether the rules make looping worth it: `OWNER ONLY`.

## Picks for the owner

Each is a starting value, built; keep or change:

1. **Loop robes:** Ouroboros (reach loop 3, teal) and Abyssal (reach loop 5, night blue), earned, not sold.
2. **Codex:** one Lore line per loop rule, unlocked when a loop first draws it.
3. **Records:** deepest loop and fastest true ending per weapon, in the hub's Achievements page and the recap
   ("New record: loop N reached!", "New record: fastest true ending!").
4. **Loop achievements:** Third Turn (loop 3) and Bottomless (loop 5); loop 2 stays `ascend_1`.
5. **Fragments:** × (1 + 0.5 × (loop − 1)), every source; the recap shows "Loop bonus: ×1.5".
6. **Rules pool (one a loop, no repeats, seeded):** Quickened (enemy speed ×1.2), Lean Mending (orbs ×0.5 as often,
   ×2 heal), Elite Hunt (elite rooms every floor at the last floor's rate), Shielded (front 45°: 60 % damage),
   Point Blank (bolts ×1.3, keep distance ×0.6).
7. **HP step:** enemies and bosses ×3.5 a loop (was ×6); damage ×1.2 unchanged.
8. Shown: the floor card on the loop's first floor, the pause menu's "Loop rules:" line, the recap's "Loop rules:" line.

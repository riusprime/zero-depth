# D1: why the wand-build replay was "not exact" with frost_core + ember_core

Machine: the owner's PC (Windows 11), Godot 4.7.2, base `84de12ab`, worktree branch `v0105-d1`.
Verdict: **a test-helper bug, not a sim determinism bug.** The sim replays exactly; `tests/support/save_lab.gd`
builds the replay's base world without `pair_table`.

## Commands and raw results

Temporary copy of `tests/e2e/test_e2e_wand_build.gd` (first test only, cards read from the `D1CARDS` env var;
deleted, not committed). Each run: `APPDATA=$(mktemp -d) godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/e2e/test_tmp_d1.gd -gexit`.

| Cards (the 4 dev-granted) | Result |
|---|---|
| frost_core, blade_orbit, echo_slash, ember_core (old) | FAIL: `the replay is exact` (`42fe171f...` expected `c6b35e98...`) |
| heavy, whirl, flurry + ONE old card (each of the four) | all 4 PASS |
| frost_core, blade_orbit, echo_slash, heavy | PASS |
| blade_orbit, echo_slash, ember_core, heavy | PASS |
| frost_core, blade_orbit, heavy, whirl / echo_slash, ember_core, heavy, whirl | PASS / PASS |
| frost_core, blade_orbit, ember_core, heavy | FAIL |
| frost_core, echo_slash, ember_core, heavy | FAIL |
| frost_core, ember_core, heavy, whirl (either order) | FAIL |
| frost_core, ember_core, flurry, parry_edge | FAIL |
| heavy, whirl, flurry, ember_core | PASS |

No single old card breaks it; the pair **frost_core + ember_core** does (Fire + Frost = pair X1, Thermal Shock,
`ElementPairs`).

Per-tick compare (hash recorded live on each `driver.ticked`, compared after each replayed `step`), cards
frost_core, ember_core, heavy, whirl:

```
SNAP tick 492 mask 1 lv 1 slots [9, 40, 97, 102]
APPLIED tick 492 mask 1 lv 1 slots [9, 40, 97, 102] pt <null>
  r tick 493 mask 0
FIRST DIVERGE tick 493 live mask=1 log=[] lv=1 ; replay mask=0 log=[] lv=0
```

The replay base world has `pair_table == null`. Verification: adding the missing line to `save_lab.gd` (temporary,
reverted) and re-running with the old cards frost_core, blade_orbit, echo_slash, ember_core: `Passing Tests 1`.

## Cause

- `WorldSnapshot` lists `pair_table` as `"loadout"` (`src/sim/core/world_snapshot.gd:48`): not saved, the world
  must be built with it. `FloorPlan` sets it: `src/app/floor_plan.gd:176` (`w.pair_table = WandCompiler.pairs(repo)`,
  added in v0.9.5 EE3, commit 7da137b5).
- `SaveLab.build_floor` (`tests/support/save_lab.gd:90-92`) mirrors Main's loadout ("as Main") and sets
  `wand_table`, `blade_table`, `slot_table`, but never `pair_table`.
- `ElementPairs.mask` returns 0 when `w.pair_table == null` (`src/sim/items/element_pairs.gd:~107`). The snapshot
  restores `pair_mask = 1`, but on the first replayed tick the wand recompiles (`ElementPairs.refresh`,
  `element_pairs.gd:~182`) and zeroes the mask and levels. Thermal Shock (`element_pairs.gd:~229`,
  called at `src/sim/combat/damage.gd:149`) and the pair hash block (`element_pairs.gd:~441`) then differ from the
  live run. With any other pair-free set the null table has no effect, hence the other cards passed.

## Proposed fix

Test-helper only: add `w.pair_table = WandCompiler.pairs(repo)  # v0.9.5 EE3, as Main` after the `slot_table` line
in `SaveLab.build_floor` (`tests/support/save_lab.gd:92`). The fixture can then return to frost_core / ember_core
(or keep the current four and add a separate wand-build replay test with a Fire + Frost pair). Also worth a
guard test comparing the field list `FloorPlan` sets under "loadout" in `world_snapshot.gd` against what
`SaveLab.build_floor` sets, so the next new loadout table cannot drift silently. No game code change is needed.
Other tests that replay from `SaveLab` worlds with two held elements may have been hiding the same drift.

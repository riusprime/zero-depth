# WAND_1: does the wand compile left to right, cut on triggers, grow 4 → 6 → 8, reorder as input and save?

- **Status:** RUN (agent: lint and the tests of the touched folders and their e2e; NOT the full suite, which is the
  lead's one run per wave)
- **Build:** the commits `8e50eb3` … `87af956` on the agent's session branch (cut from `claude/lucid-fermat-9wv2tf` at
  `9986ec5`); Godot `4.7.2.stable.official.ed1daf0bf`; OS Linux 6.18 (cloud container)
- **Date:** 2026-10-12
- **Who ran it:** agent

Design: [`../../../design/WAND.md`](../../../design/WAND.md) (owner-approved). Contracts:
[`SIM_CONTRACTS.md`](../../../architecture/SIM_CONTRACTS.md) §3, §8e;
[`CONTENT_SCHEMA.md`](../../../architecture/CONTENT_SCHEMA.md) §2 "the wand". PLAN rows W3, W6.

## What was built
- **Left-to-right compile** (`src/sim/combat/wand_compile.gd`, `WandCompile`): the fixed stage sort across cards is
  gone; each card rewrites the spell built so far, in slot order (`World.mod_slots`); inside one card its ops keep
  their stage order. A hook's child is compiled by its own card (lineage blocks its own hook) and the cards to its
  right. Readings for what depended on the stage order: SIM_CONTRACTS §8e.
- **Triggers** (a new op `TRIGGER`; `ModifierOpDefinition.Trigger` gains `ON_CRIT`, `ON_FINISHER`): a trigger ends
  the spell on every spec it reaches; the cards to its right build a child spell, a small copy of the basic attack
  (`data/wand/wand.tres`: size 600 ‰, range 600 ‰, damage 500 ‰ of the hit; starting values), cast on its trigger;
  depth ≤ 2 (a third trigger casts nothing). `ON_CRIT` runs from `Attacks._landed` / `on_projectile_hit` when the hit
  was a crit (`World.last_hit_crit`, set by `Damage.hit` as it returns); `ON_FINISHER` compiles into the combo's last
  step's `ON_HIT`. A hook's projectile now carries its proc coefficient on its HIT (`Attacks.projectile_proc`: 50,
  then 25; it was always 100).
- **Four trigger cards as data** (`data/modifiers/trigger_*.tres`, `data/items/trigger_*.tres`, new item kind
  `TRIGGER` and tag `trigger`), placeholder names en + es, a silver placeholder frame. Not offered (`ItemPool` skips
  the kind until WN5); their item indices come after every earlier card.
- **Slots grow** (`Wand.slots`, `WandTable.slots_at`): 4 / 6 / 8 on floors 1 / 2 / 3+ (data). `BuildSlots.full`,
  the migration and the swap answers use it; a lab world without the table keeps six. The HUD pips show the wand's
  count; the Swap panel takes keys 1–8.
- **Reorder as input**: `InputFrame.pick` = 1000 + from × 16 + to (`InputFrame.wand_move`), applied first in
  `World.step` in any state; the rest of the tick sees no pick. `WorldReader.wand()` (cards, levels, cuts,
  triggers), `WorldReader.wand_read_back()` / `Wand.describe()` (keys + args) and `Wand.render()`; 12 `WAND_READ_*`
  strings in en and es.
- **Saves**: `RunSaver.PAYLOAD_VERSION` 4 (reads 2, 3, 4). Version 3's pick order is its wand order; slot count from
  the floor reached; no card dropped from a v0.6 save. `CatchUp.power` reads the wand (`Wand.size`).

## Commands and raw outputs
Lint (on `87af956`):
```
gdformat --check src scripts tests && gdlint src scripts tests
643 files would be left unchanged
Success: no problems found
```

The new wand tests (on the tree of `9336f0b`, code the same as `87af956` but for the trigger cards' frame family and
three test counts):
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/sim/test_wand_smoke.gd,res://tests/unit/sim/test_wand.gd,res://tests/unit/sim/test_wand_order_fight.gd,res://tests/unit/sim/test_wand_compile.gd -gexit
    wand smoke: 960 runs (60 cards × 8 slots × 2 weapons)
Tests                36
Passing Tests        36
Time              116.286s
```

The whole `tests/unit/sim` folder (same tree):
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/sim -ginclude_subdirs -gexit
Tests               814
Passing Tests       810
Failing Tests         4
Time              2565.021s
```
The four failures, pasted (`[Failed]` lines, deduplicated):
```
[0] expected to be > than [0]:  blade: mod:trigger_on_end is offered somewhere      (… the same for the other 3 triggers, both weapons)
[33] expected to equal [32]:  the 31 v0.5 kinds and MODIFIER
[55] expected to equal [51]:  the 14 migrated attack items (MX1), Frost Nova's frost, Razor Orbit (MX2); MX4: the M-list's 29 new, 3 legendary, Cluster Payload, Overclocked Drone, Afterimage
[67] expected to equal [63]:  16 + 8 engine items (G) + 3 heat items (L18) + 4 ability mods (CP) + 32 modifier cards (v0.6.0 MX4)
[81] expected to be between [40] and [80]:  gun: 40-80 cards
[84] expected to be between [40] and [80]:  blade: 40-80 cards
```
All four are counts of the shipped data and the pool survey, which now hold the four trigger cards (not offered by
design). Fixed in `87af956` (`tests/support/card_pool_survey.gd` skips the `TRIGGER` kind; `test_items_j` 67 items
and 33 kinds; `test_modifier_smoke` 55 modifiers) and the three files run again:
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/sim/test_card_pool_reach.gd,res://tests/unit/sim/test_items_j.gd,res://tests/unit/sim/test_modifier_smoke.gd -gexit
Tests                29
Passing Tests        29
Time              141.445s
```
The `tests/unit/sim` folder was not run again as a whole after `87af956`.

For comparison, the same folder on the untouched tree (`9986ec5`, a copy outside the worktree, run alongside):
```
Tests               778
Passing Tests       778
Time              2437.997s
```

Content, arch, the replay golden and the application tests (on `9336f0b`):
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/content,res://tests/arch,res://tests/golden,res://tests/unit/application -ginclude_subdirs -gexit
Tests               139
Passing Tests       139
Time              29.27s
```

Presentation (on `9336f0b`):
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/presentation -ginclude_subdirs -gexit
Tests               388
Passing Tests       387
Failing Tests         1
Time              300.088s
```
The failure (`test_card_frames.gd`): `trigger_on_hit has a family in CardFrames.FAMILY_OF` / `trigger_on_hit: a known
family` (and the same for the other three). Fixed in `16c2026` (`CardFrames.FAMILY_OF` lists the four, family
`time`; the modifiers' family `epic` → `time`), then:
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/presentation/test_card_frames.gd,res://tests/content/test_modifier_validation.gd,res://tests/content/test_card_frame_assets.gd -gexit
Tests                18
Passing Tests        18
```

The e2e tests that reach what changed (main.tscn, real input; on `9336f0b`):
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/e2e/test_e2e_swap.gd,res://tests/e2e/test_e2e_combo.gd,res://tests/e2e/test_e2e_modifiers_mx4.gd,res://tests/e2e/test_e2e_saves.gd,res://tests/e2e/test_e2e_builds.gd,res://tests/e2e/test_e2e_hud_style.gd -gexit
Tests                17
Passing Tests        17
Time              88.902s
exit 0
```
`test_e2e_swap.gd` now fills floor 1's four slots (it filled six) and swaps the fifth.

## Goldens
None changed. `tests/golden/fixtures/modifier_equivalence.json` still matches under the slot-order compile
(`test_modifier_equivalence.gd` 3/3 in the sim folder run above; also run alone: 3/3, 10.492s); the replay golden
`test_replay_ground_plane.gd` passed in the content/arch/golden run. The export smoke was NOT RUN.

## The order-sensitivity proof (what the tests assert)
- `test_wand_compile.gd` (14): Big·Split is a big shot with normal splits, Split·Big makes the splits big, the two
  books' digests differ; Short Fuse·Split vs Split·Short Fuse (shipped cards) differ; Fire·ON_HIT·Shock burns the
  shot and not the child, ON_HIT·Fire·Shock burns only the child, their digests differ; the child is the small copy
  (Gun bolt, Blade slash); each trigger casts on its own trigger (T4: crit on the Gun, the last combo step on the
  Blade); nesting to depth 2, a third trigger casts nothing; a trigger reaches the splits built to its left; moments
  read past a trigger; the compile is deterministic.
- `test_wand_order_fight.gd` (4): the AttackScenario fight with Big·Split vs Split·Big and Ember Core·ON_HIT·Split
  Shot vs ON_HIT·Ember Core·Split Shot gives different event digests, each order replays to the same digest and hash;
  every trigger's child lands in a fight on both weapons (On Crit through the crit stream); a trigger's child hits
  at proc 50.
- `test_wand.gd` (16): slots 4/6/8 (and 6 without the table), Swap at the fifth card on floor 1, order kept into
  floor 2, utility and stat cards outside; the reorder as input (moves, refused moves change no state, a move during
  an open Swap answers nothing), a run with reorders replays exactly and differs from one without; the reader and
  the read-back (keys; rendered "You fire a bolt shaped by Split Shot. Each hit casts a small bolt shaped by Ember
  Core." and its Spanish); a snapshot round trip with equal hashes that plays on the same; a v0.6.0 save's six cards
  kept in pick order on floor 1; a v0.5 carry into the floor's slot count; CatchUp.power unchanged by a reorder.
- `test_wand_smoke.gd` (2): every slot card (the items of rewrites, the four triggers, the six ability modifiers: 60)
  in each of the 8 slots of a full wand (two triggers among the other seven), on the Blade and the Gun, 60 ticks:
  960 runs, launches under the cap, bounded projectiles and queued launches, and the same digest and hash replayed.
  Mechanics only: no bot, no balance (P1).

## Known limits (honest list)
- **The v0.5 riders ignore the order.** A held Ember Edge (or Wildfire / Flame Trail) still burns the Blade's root
  slashes through the burn rider even when Ember Edge sits right of a trigger (the slash loses the ember element and
  the child gets Ember Edge's burn). Same for the bolt's slow rider. Until the old cards migrate (WN5).
- **The reorder has no UI yet** (WN2's Build page and Swap reorder), so no e2e drives it through `main.tscn`; the
  sim action is tested in `test_wand.gd`. The pause menu stops the sim: WN2 must deliver its moves on a tick
  (e.g. the Build page stepping the world as a choice does), or they arrive on the first tick after unpausing.
- **The Swap panel at 8 slots** lays out 9 tiles of 150 px (about 1,430 px with gaps): wider than a 1280 px screen.
  Floors 3+ reach it; WN2 rebuilds that panel.
- The trigger cards are never offered and wear a placeholder frame and names (WN5).
- `ON_FINISHER` on the Blade casts only from the last step's hits; a child slash (depth 1) has no finisher, so a
  second T4 there casts nothing.
- A hook's projectile HIT now reports proc 50 / 25 (was 100). Nothing reads `HIT.proc_pct` for an outcome; the
  equivalence digest leaves it out.
- `tests/MIN_TEST_COUNT` not raised (the lead's, after the full run).
- Export smoke, the full suite, the screenshot tour: NOT RUN.

## Owner only
Feel, the starting values (4/6/8 slots, the child spell at 60 % size and range and 50 % damage), the placeholder
names: `OWNER ONLY`.

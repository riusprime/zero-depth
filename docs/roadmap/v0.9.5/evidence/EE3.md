# Evidence: v0.9.5 Step EE3 (the ten level-3 element pairs)

Base build SHA: `625eb87c` (branch `v095-ee3`, cut from the worktree HEAD, then `claude/v095-feedback` merged; before the EE3
commit). Machine: owner's PC, Windows 11, Godot 4.7.2, `--fixed-fps 60 --language en`. Each run used its own `APPDATA`; up
to five Godot processes ran at once, so wall times are noise.

## What was built
- `data/combos/element_pairs.tres` (`ElementPairsDefinition`, category `element_pairs`; `ContentDef.validate` ranges) ->
  `WandCompiler.pairs` -> `ElementPairTable` (`World.pair_table`, loadout; set in `FloorPlan` and `PlaygroundScenario`;
  null = no pairs). Every number of X1-X10 is in the `.tres`.
- `src/sim/items/element_pairs.gd` (`ElementPairs`). A pair is on while the Gun holds both of its elements at Lv 3 (cards
  held and `CardLevels.level` >= 3). `Modifiers.compile` calls `ElementPairs.refresh`: it sets `World.pair_mask` (bit X per
  pair; more than one only on a Blade run, where the element slots are not limited) and emits `SimEvent.Kind.PAIR_ON`
  (new, appended) for each pair that just turned on. A pair that turns off takes its clouds with it.
- Rules (hooks): X1 `Damage.hit` (reads burning and frozen before the hit's own statuses land, because a landing hit's
  frost or burn would otherwise break both at once through the existing Thermal Break; ends both, bursts x3 the hit in 1.5 m,
  TAG_AREA, effect `pair_burst`, proc 50); X2 `Engines.add_burn` / `ItemEffects.on_melee_hit` (a poisoned enemy lit) lays a
  2 m cloud for 180 ticks, `ElementPairs.tick` (from `Venom.tick`) pulses every 5 ticks and poisons 1 stack, once per enemy
  per 60 ticks (new actor column `gas_cd`); X3/X8/X9 `Attacks._chain` (the jumped-to enemy gets a burn application, 1 poison
  stack, 1 bleed stack); X4 `Engines.tick_statuses` (bleed tick x2 on a burning enemy); X5 `Attacks._chain` (nearest
  frozen enemy in reach first, damage x2 on a frozen one); X6 `ItemProcs.slow_factor` (x0.8 on a poisoned enemy, on top of
  any slow) and `Venom.tick` (`poison_t` held while frozen); X7 `ElementLevelsFsf.shatter` and the kill in `Damage._apply`
  (remaining bleed = `bleed_damage` x stacks x ticks still to come, split evenly over the enemies within 2 m as DoT, effect
  `pair_burst`; the dying or shattered enemy's bleed ends); X10 `Damage.hit` and `Damage.tick_dot` (x1200/1000 for a
  hero hit or tick on an enemy with >= 3 poison and >= 3 bleed stacks).
- Budget (`World.pair_log`, flat [pair, tick] of the last 60 ticks; 4 per pair): X1, X2, X3, X7, X8, X9 (the rules that
  do work: a burst, a cloud, a status on a jump). X4, X5's damage and target choice, X6 and X10 only change a number, cost
  nothing to repeat and are not counted. Clouds: at most 16 live (the budget keeps it near 12).
- State: `pair_mask`, `pair_log`, `pair_clouds` (World; snapshot "added since v0.5", so an older save reads 0) and
  `ActorStore.gas_cd` (padded for an older save). All hashed only while a pair is on (`ElementPairs.hash_into`,
  `ModifierRuntime.hash_into`).
- View: banner = the combo card (`Hud._pair_pending`, `WorldReader.pair_*`): the pair's name and line, the two element
  cards as its icons, caption "Element pair", the combo chime. X1/X7 burst = the existing shatter burst at the pair's
  radius (old look: a ring). X2 cloud = one flat quad per cloud (soft round alpha from a radial `GradientTexture2D`) in
  `ElementVisuals`, pool of 16. Status visuals of burning, frozen, poison and bleed are the existing ones. No new
  particle system.
- Codex: it lists no combos, so no pair entry was added (`tests/content/test_codex_content.gd` passes).
- Finding: Thermal Break (existing) already consumes burn + frost when the second lands; the pair's X1 therefore reads the
  state before the hit's own statuses. Owner call if X1 should also fire when Thermal Break would.
- Finding: X6 "slowed 20 % more" is read as a x0.8 speed factor on every poisoned enemy, in addition to any slow it has.

## Text (content tests cap a description at 60)
| Key | en | es |
|---|---|---|
| PAIR_THERMAL_SHOCK_DESC | 48 | 53 |
| PAIR_TOXIC_FUMES_DESC | 48 | 44 |
| PAIR_IGNITION_ARC_DESC | 32 | 35 |
| PAIR_BOILING_BLOOD_DESC | 43 | 44 |
| PAIR_COLD_CIRCUIT_DESC | 47 | 45 |
| PAIR_BLACK_ICE_DESC | 50 | 52 |
| PAIR_BRITTLE_DESC | 48 | 44 |
| PAIR_NEUROTOXIN_DESC | 33 | 37 |
| PAIR_ARTERIAL_ARC_DESC | 31 | 35 |
| PAIR_SEPSIS_DESC | 49 | 48 |

Names (en / es) as the brief; plus `UI_PAIR_ON` ("Element pair" / "Par elemental").

## Commands and raw totals
```
APPDATA=<own> godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://<file>[,...] -gexit --language en
APPDATA=<own> godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/content -ginclude_subdirs -gexit --language en
```
| Run | Result |
|---|---|
| `tests/unit/sim/test_element_pairs.gd` (new) | 25/25 (218 asserts): each pair on only at Lv 3 + Lv 3 (off at Lv 2 + Lv 2, one at Lv 2, one alone, no table); announced once; text in both languages <= 60; X1 x3 in 1.5 m, not at 4 m, needs both statuses; X1 4/s then room after 60 ticks; X2 cloud, 1 stack per second, 2 m, 3 s, 4/s; X3/X8/X9 jumped-to enemy burns/1 poison/bleeds, none with the pair off, 4/s; X4 double; X5 frozen first and x2; X6 x0.8 and poison held while frozen; X7 shatter and death split evenly, 2 m; X10 +20 % at 3 and 3, not 3 and 2; determinism of all 10; hash gating; snapshot round trip |
| `tests/unit/presentation/test_pair_banner.gd` (new) | 3 tests: the HUD banner names Thermal Shock and shows both element icons; the ten banners fit the plaque in en and es; a cloud is one quad |
| `tests/e2e/test_e2e_element_pairs.gd` (new, main.tscn, real input) | 1/1 (8 asserts): "EE3 e2e: 1 burst hit(s) on the neighbour at 1 m" |
| `test_element_levels_venom_bleed`, `test_element_levels_fsf`, `test_modifier_equivalence`, `test_engines`, `test_damage`, `test_mx4_engine`, `test_world_snapshot`, `test_old_saves` + `test_element_pairs` | 112/112 |
| `test_pair_banner`, `test_plaques`, `test_codex_view`, `test_status_visuals`, `test_combos`, `test_wand_shared`, `test_card_levels_clv` | 58/58 |
| `tests/content/` | 157/157 (30 scripts) |
| `tests/golden/` + `tests/arch/` | 6/6 |
| `tests/e2e/test_e2e_element_levels.gd` + `test_wand_shared.gd` (after the change) | 11/11 |

A first e2e run without `--headless` failed in both `test_e2e_element_pairs` and `test_e2e_element_levels` ("Cannot call
method 'find_child' on a null value": no dev panel in that window run); with `--headless` both pass.

## Existing tests changed
- `tests/unit/presentation/test_plaques.gd::test_item_and_combo_plaques_fit_in_english_and_spanish`: it read every file in
  `data/combos` as a `ComboDefinition`; it now skips `element_pairs.tres` (the pairs' banner fit is in `test_pair_banner`).
  Nothing else was edited.

## Changed digests and goldens
None. `test_modifier_equivalence` and `tests/golden` pass unchanged (a world with no pair on hashes exactly as before: the
new state is hashed only while `pair_mask` != 0). No golden changed.

## Not run
`test_five_floors.gd`, `test_curse_room.gd`, `test_modifier_smoke.gd`, `test_event_rarity.gd` (excluded by the brief); the
full suite (GitHub). No frame-time probe or 20-enemy soak was run (no timing on a busy machine: `NOT YET RUN (owner
hardware)`). Look and feel of the banner, the burst and the gas cloud: OWNER ONLY (no screenshot taken).

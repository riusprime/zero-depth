# FC8: the Wave accepts eight more cards (v0.9.5 Step FC8, FORM_COMBOS.md W1-W8)

- **Status:** RUN (agent). Owner playtest of the look and feel: OWNER ONLY (empty).
- **Build:** the commit that holds this file, on branch `v095-fc8` (cut from `claude/v095-feedback` at b358d62b, which
  holds FC4, FC5 and FC6); the SHA is in the step report. Godot 4.7.2 stable; Windows 11 Pro, owner PC, several Godot
  processes at once (no timings here are evidence).
- **Date:** 2026-10-26

## What was built

- `src/sim/combat/wave_mods.gd` (pure, one handler per card; `WaveMods.DEFAULTS` = the data row, 21 keys). A wave
  ignores the eight cards' generic ops (`WandCompile.run` notes the id in `modifier_ids`); the handlers read them.
  Twin and Backfire are untouched.
  - W1 Ricochet: thrown with 1 wall bounce (the generic wall bounce); the band follows the new heading.
  - W2 Homing: at launch picks the enemy within the wave's reach (speed x life) and inside a 90 degree cone ahead
    (45 degrees a side) with the most enemies within 2 m (the lowest index on a tie), and bends toward it at most
    45 degrees a second (8 units of 1/4096 turn a tick).
  - W3 Echo: a ghost wave 24 ticks later from the same muzzle and angle at 50 % damage; it starts no follow-ups.
  - W4 Big Shot: 5 m wide, x1.6 damage, speed x0.75 (reach 8.1 m). W5 Rapid Fire: 2 m wide, x0.7 damage, period 33
    ticks (`ItemEffects.shot_period_ticks` -> `WaveMods.period`). Both: damage multiplies, width = 5 x 2 / 3 m.
  - W6 Split: when its run ends (life out or a wall; `Attacks.on_projectile_end` -> `WaveMods.on_end`) it queues two
    waves at +-45 degrees that roll 3 m, 50 % of its damage, half its width, no cards of their own, no follow-ups.
  - W7 Mine: 4 m from where it left, the wave stops and churns 90 ticks (its life becomes the hold; its per-shot waits
    are stretched to match), then ends. Hits under the Wave's normal rule: each enemy once per wave.
  - W8 Spiral: a sideways offset of 0.8 m x sin(2 pi t / 60 ticks) from the Kin table, applied as a per-tick position
    shift across the heading (no new trig).
  - Bound: at most `live_max` = 8 live waves per hero (`WaveMods.cull`, the oldest end first and do not split), rows
    capped at 64. Echo's ghosts and Split's children do not spend the shot cap (bounded by the 8).
  - Rows in `ModifierState.wm_*` (the prefix was free), hashed only while set, listed in `WaveMods.SNAPSHOT_FIELDS`
    (one `if` beside RuneMods' in `WorldSnapshot._apply_object`; an older save loads with none).
  - `WaveShots` reads a wave's own width (`WaveMods.band_mm`, `half_of`) and heading (`WaveMods.heading`, so a churning
    Mine still has a band); the existing `WorldReader.wave_shots()` therefore carries the changed width and direction.
- Data: `data/wand/attack_slots.tres` wave row `allowed` += Ricochet, Homing, Echo, Big Shot, Rapid Fire, Split,
  Mine, Spiral; a `params` dictionary (21 keys); `AttackFormRow.WAVE_KEYS`; one line in `_keys_of`. Halo, Ring, Pierce,
  Orbit, Swirl, Threadline stay off.
- Hooks (one or a few lines each): `Attacks._bolts` (damage, speed, bounces, Echo's row), `Attacks.on_projectile_end`,
  `World._apply_spawns` (on_spawn, cull), `ModifierRuntime.advance`, `WandCompile.run`, `ItemEffects.shot_period_ticks`.
- View: the existing wave look, drawn at the sim's width. No new art, no new strings.

## Deviations to flag (readings the spec left open)

- No new `WorldReader` method: the existing `wave_shots()` already returns the per-wave width and heading.
- "90 degree cone" read as 90 degrees in all (45 a side). Reach = speed x remaining life. The count of "enemies within 2 m"
  includes the candidate itself. The target is fixed at launch; if it dies the wave rolls straight.
- Big Shot with Rapid Fire: widths multiply (3.33 m); the spec gives each alone. Big Shot's speed x0.75 with an unchanged
  life shortens the reach to 8.1 m (the spec has no life change).
- Ricochet: the Wave's per-shot "hit each enemy once" rule stays, so after the bounce the wave hits only enemies it has
  not hit yet.
- Split also fires when the wave ends on a wall, and when Mine's churn ends. A Split child flies straight (no Homing,
  Spiral, Mine of its own). An Echo ghost carries the movement cards (it homes, sways, stops) but not Echo or Split.
- A Backfire wave (generic) carries the damage, speed and width of the cards too.
- `test_shot_rate_all_forms.gd` build count: unchanged at 37 (the Wave's builds are Pattern choices; the eight cards
  join each build as Secondaries; the test passes unedited). `test_wave.gd` `WAVE_ON` gained the eight ids.

## Commands and raw results (all `--language en`, own `APPDATA` per process, project.godot untouched)

- `godot --headless --path . --editor --import --quit`: no ERROR lines.
- `gdformat` + `gdlint` on all touched `.gd`: "Success: no problems found".

| Run | Tests | Passing | Asserts |
|---|---|---|---|
| test_wave_mods (new), test_wave, e2e test_e2e_wave_combos (new), final | 35 | 35 | 355 |
| test_wave_mods, test_wave, test_attack_slots, test_shot_rate_all_forms, test_world_snapshot, test_modifier_equivalence, test_wave_view, test_gun_pool_order, test_glaive_mods, test_wisps (before the `WAVE_ON` edit) | 127 | 126 | 7966 of 7974 |
| tests/content + tests/golden + tests/arch | 163 | 163 | 30744 |

- The one failure in the 127 was `test_wave.gd` `WAVE_ON` (the eight cards now on), fixed; the file passes in the
  35-test run. Digests: none moved (test_modifier_equivalence, tests/golden pass). Goldens changed on purpose: none.
- e2e: "FC8 e2e: most waves drawn 3; the dummy lost 144 of 5000" (Wave from the altar; Big Shot and Echo by the dev
  panel's Grant clicks as labelled helpers; the dummy 2.4 m off the aim, reachable only by a 5 m wave).
- Not run: test_five_floors, test_curse_room, the seed-loop tests, `seams.sh`, the full suite.

## DPS check (`godot --headless --path . -s scripts/balance/forms_dps.gd`, crit off, floor 5, from tick 120)

Orbs baseline: single 930, line 335, pack 330. Plain Wave: 930 / 1680 / 1650.

```
wave + (plain)          1.000 | 5.015 | 5.000 |  930 | 1680 | 1650
wave + gun_ricochet     1.000 | 5.015 | 5.000 |  930 | 1680 | 1650
wave + gun_homing       1.000 | 4.925 | 4.000 |  930 | 1650 | 1320
wave + gun_echo         1.500 | 7.478 | 7.500 | 1395 | 2505 | 2475
wave + gun_big_shot     1.600 | 8.024 | 8.000 | 1488 | 2688 | 2640
wave + gun_rapid_fire   1.152 | 5.704 | 3.436 | 1071 | 1911 | 1134
wave + split_shot       1.000 | 5.015 | 5.000 |  930 | 1680 | 1650
wave + gun_mine         1.000 | 2.955 | 5.000 |  930 |  990 | 1650
wave + gun_spiral       1.000 | 5.015 | 5.000 |  930 | 1680 | 1650
```

Against the plain Wave (single / line / pack): Ricochet, Split, Spiral 1.00 / 1.00 / 1.00; Homing 1.00 / 0.98 / 0.80;
Echo 1.50 / 1.49 / 1.50; Big Shot 1.60 / 1.60 / 1.60; Rapid Fire 1.15 / 1.13 / 0.69; Mine 1.00 / 0.59 / 1.00. **No
single exceeds x2.0 and no pack exceeds x6.0 against the plain Wave.** Against the orbs the plain Wave already reads
5.0 pack, so Echo (7.5) and Big Shot (8.0) read above 6.0 on that column; the ratios the step set are against the plain
Wave. The sheet's scene (everything in front on the aim) cannot show Ricochet, Split, Spiral or Homing's bend.

## Not done / OWNER ONLY

- Feel and look of the wide wave, ghost, children, the churning Mine and the sway on the owner's hardware: OWNER ONLY.
- Cards' en/es descriptions still read their generic text; no strings added.

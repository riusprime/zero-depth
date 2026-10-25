# Step DC: danger keeps climbing to minute 10 of a floor and past it

Owner line: "The difficulty scaling on each room never reaches more than the 4th level at the top, so from minute 5 it
never gets harder, we should aim to a 10 minutes max per floor, where difficulty after minute 10 is usually too bad to
continue so you have to go to the boss, fix that one" (PLAN Q19 starting values).

Build: base `d33bc82a` (branch `v095-dc`, the step's commit on top). Machine: owner's PC, Windows 11, Godot 4.7.2,
other agents running Godot at the same time (timings are noise).

## What changed

- `data/curves/floor_1..5.tres`: the overtime schedule, as data (identical on every floor):
  `overtime_seconds = [90,150,240,330,420,510,600]` (tiers 4-10), `overtime_step_seconds = 30`, `overtime_max_tier = 20`,
  `cap_per_tier_permille = 80`, `interval_per_tier_permille = 40`, `interval_min_seconds = 0.8`,
  `pack_cap_bumps = [6,10,15]`. Read from `DifficultyCurveDefinition` (new exports, validated: positive, ascending,
  not before the peak phase, max tier covers the schedule, bumps above tier 3), compiled into `CurveTable` by
  `ContentCompiler.compile_curve`.
- `CurveTable` (sim, integer only): in the last phase `tier_permille_at = max(phase tier, overtime tier x 1000)`;
  `cap_bonus_permille`, `overtime_interval`, `pack_cap_at` apply the per-tier growth. `SpawnTable.cap_now` /
  `interval_now` call them (these are the only sim lines touched; `world.gd` not touched).
- Existing phases unchanged. The clock is `World.run_ticks` (the floor's own tick count, already in the world snapshot).
- Tier tables: `hp_tier_permille`, `damage_tier_permille`, `interval_tier_permille` in `data/spawning/floor_1.tres` already
  have 21 entries (tiers 0-20) and every floor shares that one table, so no extension was needed (HP x6.727, damage
  x2.653, interval x0.122 at tier 20).
- HUD (`DangerMeter`): from tier 4 the tier number is drawn ("×7", locale key `HUD_DANGER_TIER`, `×%d` in en and es),
  in the danger colour, pulsing on a rise like the marks; from tier 10 the marks turn the palette's WARN red. The meter's
  six marks are unchanged (the row is 34 px wider for the number). Bosses and Overrun are untouched.

## Floor 3: by minute (`dc_table.gd`, raw output)

Enemy HP factor = `hp_now(1000, t)` (per mille of base HP; 700 = x0.7); damage factor = `power_now(t)`.

```
minute | tier | cap | interval_s | pack_cap | enemy HP | damage
 0 |  0 |  12 | 4.50 | 2 |  700 |  450
 1 |  3 |  26 | 2.37 | 0 | 1032 |  637
 2 |  4 |  32 | 2.02 | 0 | 1135 |  669
 3 |  5 |  38 | 1.73 | 0 | 1249 |  702
 4 |  6 |  45 | 1.50 | 0 | 1373 |  737
 5 |  6 |  45 | 1.50 | 0 | 1373 |  737
 6 |  7 |  53 | 1.28 | 0 | 1510 |  774
 7 |  8 |  60 | 1.10 | 0 | 1662 |  812
 8 |  8 |  60 | 1.10 | 0 | 1662 |  812
 9 |  9 |  68 | 0.95 | 0 | 1827 |  853
10 | 10 |  78 | 0.80 | 0 | 2010 |  896
11 | 12 |  96 | 0.80 | 0 | 2432 |  988
12 | 14 | 118 | 0.80 | 0 | 2943 | 1089
13 | 16 | 135 | 0.80 | 0 | 3561 | 1201
14 | 18 | 145 | 0.80 | 0 | 4309 | 1324
15 | 20 | 156 | 0.80 | 0 | 5213 | 1459
```

Floor 3's last phase has no pack limit (pack_cap 0), so the bumps do not show there; floor 1 (limit 3) shows them in
the unit test. The 0.8 s floor holds from tier 4 on (`test_the_overtime_grows_the_cap_and_shortens_the_interval` checks every
30 s from 1:30 to 21:00); the table was re-printed after the final clamp. Other raw lines: floor 3 reads tier 3 at
89 s, 4 at 90 s, 4 at 149 s, 5 at 150 s, 6 at 240 s, 10 at 600 s, 11 at 630 s, 20 at 900 s.

## Tests run (`APPDATA=<own folder> godot --headless --fixed-fps 60 ... --language en`)

| Run | Result |
|---|---|
| `tests/unit/sim/test_difficulty_curve.gd` (4 new: tier schedule on floors 1/2/5, cap and interval at tier 10 and the 0.8 s floor, pack bumps 6/10/15, a snapshot at 6:00 resumes tier 7) | 16/16 passed (1526 asserts) |
| `tests/content` (new: overtime validation), whole folder | 157/157 passed |
| `tests/unit/presentation/test_hud_style.gd` (new: number from tier 4, red at 10), `tests/unit/sim/test_spawn_director.gd` | 19/19 passed in the combined run's log (the run did not finish, see below) |
| `tests/e2e/test_e2e_difficulty_curve.gd`, `test_e2e_difficulty.gd`, `test_e2e_hud_style.gd` | 3/3 passed (237 asserts) |
| `tests/golden` + `tests/arch` | 6/6 passed (golden unchanged) |
| lint: `gdformat --check`, `gdlint` on the touched folders | clean |

A combined run of `test_five_floors.gd` and `test_intensity_director.gd` and the old-save tests was started and killed:
`test_five_floors`' 1000-seed map generation (unrelated to the curve) did not finish in 40+ minutes on the busy
machine. Those files: NOT YET RUN to the end here (GitHub's shards cover them).

## Survival lab (`scripts/balance/survival.gd seeds=3 floor_s=600 "only=blade, no defence"`)

Healed bot, 600 s of fighting each floor (the rule's whole point), HP lost on the floor / to the boss, mean of 3 seeds:
F1 2079/177, F2 3411/316, F3 4409/584, F4 5377/997, F5 6237/706; final fight 2630 lost, won 3/3. Every seed reaches
the 100 HP death line on floor 1 under these 600 s floors (reach 0/3 at every damage share down to 10 %). No baseline
(overtime off) was run, per "no baseline copies", so there is no before/after comparison: the numbers are the shipped
rule's. This lab's default is 90 s a floor, where the overtime is only in its first step.

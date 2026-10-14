# LOOP_SCALING: what each Ascension loop multiplies after Q6 (HP ×6, damage ×1.2)

- **Status:** RUN
- **Build:** the working tree of the commit `v0.8.0 Step LS` on `v080-ls` (parent `98698cb`); the code and data
  that ran are the ones committed (the script ran before the commit, so the commit cannot name its own SHA);
  Godot `4.7.2.stable.official.ed1daf0bf`; OS `Linux 6.18.44-fc-v114`
- **Date:** 2026-10-14
- **Who ran it:** agent

## The change
- Owner Q6 (PLAN "Owner decisions", O11): per Ascension loop, normal enemies and bosses alike get HP ×6 and damage
  ×1.2, compounding; the ×100 cap (`loop_scale_cap_permille` 100000) stays.
- `data/run/three_floors.tres` and the `RunDefinition` defaults (`src/content/defs/run_definition.gd`):
  `loop_enemy_hp_permille` 4000 → 6000, `loop_enemy_damage_permille` 2000 → 1200, `loop_boss_hp_permille`
  2000 → 6000, `loop_boss_damage_permille` 1500 → 1200. The math (`RunState.loop_permille`, `scale_enemies`,
  `scale_bosses`) is unchanged; loop 1 has no factor, so floors of loop 1 and the goldens are unchanged.
- The cap applies to each stat's factor on its own: HP reaches ×100 at loop 4 (6³ = 216 → 100); damage stays
  below it (×2.073 at loop 5; 1.2^25 ≈ 95, so ×100 not before loop 27).
- The F10 dev panel lists every exported field of the files under `res://data/run` (`src/debug/dev_fields.gd`), so
  the four fields stay tunable there with no change.

## Command
```
godot --headless --path . -s scripts/checks/loop_scaling.gd
```
(writes `build/loop_scaling.txt`; pasted here by hand)

## Raw output
```
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org

steps (per mille): enemy hp 6000 dmg 1200, boss hp 6000 dmg 1200, cap 100000
floor-1 sample: enemy ENEMY_ARC_CASTER (hp 40, dmg 12), boss BOSS_BROOD_MOTHER (hp 2000, attack 0 dmg 14)
loop | enemy hp pm | enemy dmg pm | boss hp pm | boss dmg pm | enemy | e dmg | boss | b dmg
1 | 1000 | 1000 | 1000 | 1000 | 40 | 12 | 1600 | 11
2 | 6000 | 1200 | 6000 | 1200 | 240 | 14 | 12000 | 16
3 | 36000 | 1440 | 36000 | 1440 | 1440 | 17 | 72000 | 20
4 | 100000 | 1728 | 100000 | 1728 | 4000 | 21 | 200000 | 24
5 | 100000 | 2073 | 100000 | 2073 | 4000 | 25 | 200000 | 29
```
Columns: the loop factors per mille (`loop_permille` of each step), then the first compiled enemy's and the first
compiled boss's HP and damage (the boss's first attack) on that loop's floor 1, after `scale_enemies` /
`scale_bosses`. Loop 1's boss is the floor-1 eased one (×0.8, D9); later loops' floor 1 is not eased.

## Target bands
| Metric | Target | Source |
|---|---|---|
| HP factor per loop (enemy and boss) | ×6, compounding, capped ×100 | PLAN Q6 |
| Damage factor per loop (enemy and boss) | ×1.2, compounding, capped ×100 | PLAN Q6 |
| Loop 2 / loop 3 | ×6 / ×1.2; ×36 / ×1.44 | PLAN Q6 |

## Result
| Metric | Measured | In band? |
|---|---|---|
| HP factor, loops 1-5 | 1000, 6000, 36000, 100000, 100000 ‰ (enemy and boss) | yes |
| Damage factor, loops 1-5 | 1000, 1200, 1440, 1728, 2073 ‰ (enemy and boss; integer division rounds 2073.6 down) | yes |
| Loop 2 / loop 3 | ×6 / ×1.2; ×36 / ×1.44 | yes |

## Tests
Pinned by `tests/unit/sim/test_ascension.gd`: `test_q6_loop_factors_from_the_data` (the data's four steps and the
loop 1-5 factors) and `test_q6_loops_2_and_3_scale_an_enemy_and_a_boss` (an enemy's and a boss's HP and damage on
loop 2 and loop 3). Runs and counts: `PROGRESS.md` History, 2026-10-14 LS.

## Interpretation
- This proves the numbers are the owner's Q6 values and the cap holds HP at ×100 from loop 4. It does not prove the
  loop feels right: whether loop 2 and deeper are hard enough for a strong build (O11's 150K-DPS Gun build) and not
  too long a slog is **OWNER ONLY** (playtest). No bot balance sim was run (not in this step's scope).
- From loop 4 on HP stops growing (cap) while damage keeps growing ×1.2 a loop; if the owner wants deeper loops to
  keep outgrowing the build's damage, the cap is the knob (dev panel, `loop_scale_cap_permille`).

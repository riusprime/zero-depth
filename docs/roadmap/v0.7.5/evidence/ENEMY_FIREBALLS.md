# v0.7.5 Step EF: enemy fireballs (evidence)

Owner N16 (verbatim in [`../PLAN.md`](../PLAN.md) and [`../../../design/BOSS_FIGHTS.md`](../../../design/BOSS_FIGHTS.md)
"Normal enemies", "Approve all", 2026-10-13): "All normal enemies, besides the turrets and snipers should change into
this kind of attacks, not bullets going fast but slower attacks, make them look like fireballs, but different for each
enemy/boss, and the ones that change don't have the trayectory drawn in the ground anymore, only the turrets, the
melee enemies keep the red thingy". The agent's readings are in PLAN "EF". Branch `v075-ef`, from `81a07b5`.

## What was built
| Enemy | Before | Now (starting values, `data/bullet_patterns/`) | Ground |
|---|---|---|---|
| Arc Caster, bolt | one 22 m/s bolt down a drawn line | `arc_caster_plasma_fan`: FAN of 3 over 30 deg, 4 m/s, look `arc_plasma` | nothing |
| Arc Caster, spread | 3 bolts at 16 m/s down 3 drawn lines | `arc_caster_plasma_fan_wide`: FAN of 3 over 56 deg, 3.5 m/s, `arc_plasma` | nothing |
| Arc Caster, rune | a circle that erupts under you | unchanged | its circle |
| Lens Drone | 2 pulses at 10 m/s down drawn lines | `lens_drone_orb_ring`: a ring of 6 orbs (RING 12, 6 one-shot gaps, one at you), 3.5 m/s, `lens_orb` | nothing |
| Bomb Drone | a bomb on a 1.8 m circle filling for 0.8 s | `bomb_drone_fire_x`: a lobbed fireball (0.6 s, drawn in the air) landing where you stood at the commit (hurts within 0.5 m), bursting into an X of 4 cinders at 4 m/s, `bomb_cinder` | nothing |
| Needle, Sniper, Charger, Warden, Splitter, Splitling, Shield Bearer, Swarmer, Hatchling, Mine Layer, Mender | — | unchanged | their lines / red telegraphs |

- **Sim.** `EnemyTable.patterns` (one `BulletPatternTable` per attack, from `pattern_id` through
  `PatternCompiler.compile_enemy_patterns`, called by `ContentCompiler.compile_enemy(def, repo)` /
  `compile_enemies`); `EnemyAi.pattern_of`, `_resolve_pattern` (fires through `BulletPatterns.fire`: its caps, no shot on
  the player or in a wall, shots stop at walls), the ACTIVE time is the pattern's length, a pattern is aimed at its own
  speed, the Bomb Drone's landing tracks your exact position until the commit. Telegraphs `cast` / `lob` with
  `"ground": false` (SIM_CONTRACTS §10e). No new state; no new stream.
- **Damage and scaling.** Each fireball (and the landing) deals the attack's damage (12 / 8 / 16 as before), scaled
  per floor/loop by RunState and powered by the danger tier and the hidden catch-up (`EnemyAi.powered`; test below).
- **Elites.** An elite is its kind's AI: elite Arc Casters, Lens Drones and Bomb Drones fire the same new patterns. No
  other elite changed.
- **Presentation.** `TelegraphViews` skips `ground: false` telegraphs; `FireballViews.LOOKS` gains `arc_plasma`,
  `lens_orb`, `bomb_cinder` (additive) and draws the Bomb Drone's lobbed fireball on its arc (`lob_count()`); the
  Bomb Drone's blast sound plays at the landing spot.
- **Content / strings.** Behaviour schemas (`lens_drone`, `arc_caster`'s bolt and spread, `bomb_drone`) take
  `pattern_id` only; `ENEMY_ARC_CASTER_DESC`, `ENEMY_LENS_DRONE_DESC`, `ENEMY_BOMB_DRONE_DESC`, `CAUSE_LENS_DRONE`,
  `CAUSE_BOMB_DRONE` rewritten in en and es.

## Tests (raw)
Lint, on the final tree:
```
$ gdformat --check src scripts tests && gdlint src scripts tests
784 files would be left unchanged
Success: no problems found
```
New: `tests/unit/sim/test_enemy_fireballs.gd` (the bolt's 3-ball fan at 4 m/s, 15 deg either side; the spread's wide
fan at 3.5 m/s; the rune keeps its circle; the Lens Drone's ring of 6 at 3.5 m/s, evenly round, one at the player;
the Bomb Drone's lob drawn 37 ticks from 0 to landed, the landing hitting a player who stayed (16) with no cinder on
them, and a player who stepped out missing the landing and meeting the X at 45/135/225/315 deg from where it landed;
the Needle, Sniper and seven melee kinds keep ground telegraphs and no pattern; the danger-tier power on the orbs; an
orb that would start in a wall left out; determinism of a mixed fight and every enemy fireball <= 5 m/s, all three
looks flown), `tests/unit/presentation/test_enemy_fireball_views.gd` (each look drawn by FireballViews and never as a
plain shot, TelegraphViews drawing nothing for the three; the lobbed ball drawn while it flies; the Needle's lines
still drawn; the three looks apart from each other and the bosses'), `tests/e2e/test_e2e_enemy_fireballs.gd`
(main.tscn, real input: the dev panel brings in an Arc Caster; it casts a fan of 3 plasma balls at <= 4 m/s, drawn in
`arc_plasma`, and the ground telegraph count stays 0 through its windups), and a content test in
`test_enemy_validation.gd` (the three name existing slow patterns in their looks; Needle, Sniper, Charger, Warden none).

Changed on purpose (the attacks changed): `test_enemy_ai.gd` (the three spells' telegraphs, the bolt is 3 balls at
4 m/s, the bomb drone's 48-tick windup has no circle), `test_enemy_validation.gd` (no bolt speed / bomb radius),
`test_bosses_2.gd` (the Lens Drone winds up with no lanes), `test_new_enemy_avatars.gd` (no bomb circle or bolt line,
the rune's mark kept; 1800 ticks so a rune comes up), `test_e2e_new_enemies.gd` (a cast / lob or the rune circle).

`godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd <-gtest=… / -gdir=…> -gexit`, shared machine.
Code tree of every run: `6b2350f` (the later commits change docs and the screenshot script only).

| Run | Raw totals |
|---|---|
| `-gdir=tests/content,tests/arch,tests/golden,tests/unit/application,tests/unit/debug` | `Scripts 42`, `Tests 219`, `Passing Tests 219`, `Time 55.054s` |
| 16 sim files: `test_combos` (the every-card soak), `test_enemy_fireballs`, `test_enemy_ai`, `test_bullet_patterns`, `test_bosses_2`, `test_bosses`, `test_horde`, `test_horde_enemies`, `test_spawn_director`, `test_difficulty_curve`, `test_world_snapshot`, `test_rewards`, `test_boss_markers`, `test_gamble`, `test_run_flow`, `test_events` (a 17th name, `unit/sim/test_old_saves.gd`, doesn't exist: it is `unit/application`'s, run above) | `Scripts 16`, `Tests 249`, `Passing Tests 249`, `Time 384.198s`; soak `SOAK\| kills=265 events=6696 most_in_a_tick=188 limits=0 (watchdog 0, heal cap 0)` |
| 14 presentation files: audio_director, boss_challenge_parity, boss_fight_views, boss_telegraph_parity, boss_views, bosses_2_views, codex_view, colour_modes, enemy_fireball_views, horde_avatars, new_enemy_avatars, run_recap, telegraph_parity, status_visuals | `Scripts 14`, `Tests 90`, `Passing Tests 90`, `Time 42.683s` |
| 18 e2e files: enemy_fireballs, new_enemies, enemies, horde_enemies, arenas (overrun), arena, bosses_2 (Hive Lens drones, Foundry Bomb Drones), bosses, boss_dodge, difficulty, difficulty_curve, dev_master_panel, dev_live_balance, dev_panel, codex, events, run_flow, damage_soak | `Scripts 18`, `Tests 29`, `Passing Tests 28`, `Failing Tests 1`, `Time 219.089s` |
| `test_e2e_dev_master_panel.gd` alone; then `test_e2e_damage_soak.gd` + it | `Tests 2`, `Passing Tests 2`; `Tests 3`, `Passing Tests 3` |
| `test_e2e_difficulty.gd`, `test_e2e_difficulty_curve.gd`, `test_e2e_dev_master_panel.gd` on this tree, and the same three on the base `81a07b5` | both `Tests 4`, `Passing Tests 3` |

The one failure, pasted:
```
    [Failed]:  [40] expected to equal [97]:  typed into the content
    [Failed]:  [40] expected to not equal [40]:
    [Failed]:  [40] expected to equal [97]:  the rebuilt floor uses it (floor 1 scaling is x1)
```
`test_e2e_dev_master_panel.gd` "test_f10_edit_restart_floor" fails when it runs after `test_e2e_difficulty_curve.gd` in
one process, on the base `81a07b5` too (same output); alone, or after the damage soak, it passes. It is pre-existing
and order-dependent (the typed HP does not reach the field), not from EF; not fixed here (the dev panel isn't this
step's). The GitHub shards run each file set as `scripts/ci/gut_shard.sh` orders them: NOT YET RUN.

`tests/golden` passed unchanged (no golden fixture changed). Not run: the full suite (the lead's, on GitHub), the bot
sims, `scripts/ci/seams.sh` (the lead's after the merge), the bench and hitch probe (NOT YET RUN).

## Screenshots
`VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" godot --path .
--audio-driver Dummy --resolution 1600x900 -s scripts/shots/enemy_fireballs.gd` (xvfb + llvmpipe), copied from
`build/shots/v0.7.5-dev/enemy_fireballs/` (the `_b` Arc Caster shot left out: a pillar hid its fan):
- [`shots/enemy_fireballs/1_arc_caster_plasma_fan.jpg`](shots/enemy_fireballs/1_arc_caster_plasma_fan.jpg)
- [`shots/enemy_fireballs/3_arc_caster_plasma_fan_c.jpg`](shots/enemy_fireballs/3_arc_caster_plasma_fan_c.jpg)
- [`shots/enemy_fireballs/4_lens_drone_orb_ring.jpg`](shots/enemy_fireballs/4_lens_drone_orb_ring.jpg)
- [`shots/enemy_fireballs/5_bomb_drone_fireball_in_the_air.jpg`](shots/enemy_fireballs/5_bomb_drone_fireball_in_the_air.jpg)
- [`shots/enemy_fireballs/6_bomb_drone_x_of_cinders.jpg`](shots/enemy_fireballs/6_bomb_drone_x_of_cinders.jpg)
- [`shots/enemy_fireballs/7_needle_keeps_its_lines.jpg`](shots/enemy_fireballs/7_needle_keeps_its_lines.jpg) (for
  contrast: the turret's lines kept)

The red ring under each enemy in the shots is its own ground ring (the actor marker), not an attack telegraph.

## Not measured / open
- OWNER ONLY: whether the slower enemies feel right, and the numbers (speeds, counts, the 0.5 m landing, damage).
- The difficulty change (slower shots are easier to dodge; the Bomb Drone's area went from a 1.8 m circle to a 0.5 m
  landing plus the X): NOT YET RUN (bot sims are not an agent's run here).
- No shadow under the lobbed fireball (it would be a mark on the ground); the owner may want one.
- The colour-blind modes don't recolour the fireball looks (as BF1's).
- `EnemyAi.bolt_lanes` / `fan_angle` and the Arc Caster's old bolt fields in `EnemyTable` are now unused by the three
  (kept: harmless; a cleanup later).

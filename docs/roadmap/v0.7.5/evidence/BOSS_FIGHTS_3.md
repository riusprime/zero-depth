# v0.7.5 Step BF3: the Siege Engine and the Foundry fight dodge-first (evidence)

Owner N15 (verbatim in [`../../../design/BOSS_FIGHTS.md`](../../../design/BOSS_FIGHTS.md); picks "About 1.5×",
"Track, then lock 0.8 s", "Shielded during big patterns"; "Approve all", 2026-10-13). Built on BF1's engine
([`BOSS_FIGHTS_1.md`](BOSS_FIGHTS_1.md), its "how to add a boss's patterns" guide). Branch `v075-bf3`, from
`81a07b5`. The agent's readings are in PLAN "BF3". The tree each run below was on is named with it.

## What was built

| Boss | Phase 1 (100 %) | Phase 2 (66 %, opens with) | Phase 3 (33 %, opens with) |
|---|---|---|---|
| Siege Engine (HP 1800 → 2250) | **Turret Cross** (4 arms of cannon embers turning 30°/s, 20 waves; shielded), **Mortar Grid** (5 × 5 tracked board, 2 colours in turn), **Barrage** (3 tracked circles, 0.6 s apart), **Rail** (a tracked lane) | Turret Cross fast (−42°/s, 24 waves; shielded), Mortar Grid, Barrage, Rail — opens with the needle **deploy** (kept) | Turret Cross reversing (a 4-arm spiral turning back at 1.6 s; shielded), Mortar Grid ×3 (A, B, A), Barrage fast (0.45 s), Rail ×3 (28° apart), Shockwave (kept) — opens with the reversing cross |
| Foundry (HP 1900 → 2375) | **Slag Fountain** (drops thrown up land in a 6-petal flower round it, 4 waves; shielded, door shut), **Furnace Waves** (4 rings of 20, 2 gaps of 3, alternating, gaps shifting), **Molten Flood** (3 tracked molten rows), Vent Blast (kept), Bomb Drones (kept) | Slag Fountain ×6 waves (shielded), Furnace Waves, Molten Flood ×5 rows, Vent Blast, Bomb Drones ×3 — opens with the fountain | Slag Fountain ×6, Furnace Waves fast (6 rings, shifting the other way), Molten Flood ×5, Vent Blast, Bomb Drones ×3, Firestorm (kept, now tracked) — opens with the fast waves |

Every marker (Mortar Grid, Barrage, Rail, Molten Flood, Firestorm) follows the player's exact position, then locks and
flashes 0.8 s before it strikes. Punish: the Siege Engine's Shockwave (inner 4.4 m, outer 50 m: BF1's values), the
Foundry's Firestorm. Gap-closer: the Siege Engine's Barrage, the Foundry's Molten Flood (the anti-kite tests ask every
boss but the Gatekeeper for one). Dropped from the fights (not in the design table): the Siege Engine's scattered
barrage, rail sweep and fast bolt fan (their moves stay in code, tested on fixtures, `BossLab.siege_v070_def`), the
Foundry's Slag Mortar. N18's radius and rooms (1.8 m / 1.95 m, 4 × 4) and the Vent Blast ring (4.65 m) unchanged.

**Engine (additive; BF1's tests green, below):**
- Move **`grid`** (`BossSchemas`, `BossDodge.grid_discs` / `grid_state` / `grid_telegraph` / `resolve_grid`): a
  `count` × `count` board (odd) of `radius_m` circles `cell_m` apart, centred on the tracked point; `volleys` strikes
  `stagger_seconds` apart alternate its colours; each later colour shows only for its own lock. Validation: odd
  count, `cell_m` >= 2 × radius, a lock.
- Move **`row_flood`** (`BossDodge.row_flood_of`): `count` lanes along x, `gap_m` apart, centred on the tracked point,
  cut by walls; stands and burns like `flood` (the same resolve and telegraph branch, drawn molten). Needs a lock.
- **Raining flower**: `BulletPatternDefinition.rain_seconds` / `rain_m` (FLOWER only, 0 by default, so BF2's flowers
  are unchanged): each wave lands `rain_seconds` after it is thrown, `rain_m` × the petal's share out from the body,
  through `BulletPatterns.fire` (its fairness rules). In the air the drops are a read only: `BossDodge.rain_drops`,
  `WorldReader.boss_rain(i)`; `FireballViews` draws them on an arc (`rain_point`).
- `FireballViews.LOOKS`: `cannon_ember` (core #FFB878, edge #2E1A0E, grey smoke trail with no glow: a new optional
  `smoke` key, size 1.2) and `molten_drop` (core #FFF07A, edge #2A1C06, gold trail). `WorldReader.MOVE_GRID`,
  `MOVE_ROW_FLOOD`; audio cues (`boss_mortar`, `boss_floor_burst`); the Siege and Foundry avatars map the new moves
  to their old poses; the Foundry's shielded pose now shows during the fountain (BM's hook, BF1's read).
- Strings: `CAUSE_SIEGE_CROSS`, `CAUSE_SIEGE_GRID`, `CAUSE_FOUNDRY_FOUNTAIN`, `CAUSE_FOUNDRY_WAVES` (en + es), and
  `BOSS_SIEGE_ENGINE_DESC` / `BOSS_FOUNDRY_DESC` (the Codex and boss text) rewritten for the new fights.
- Docs: CONTENT_SCHEMA §4 / §4b, SIM_CONTRACTS §10d.

## Fairness, as built
- Every pattern keeps a gap the hero fits (`test_the_shipped_patterns_each_leave_a_gap_the_hero_fits` covers the seven
  new pattern files); the Turret Cross's arms are 90° apart; the Furnace Waves' gaps are three shots wide; the
  flower's petals are cut at 30 %.
- The Mortar Grid always leaves the other colour and the corners between circles safe; the test walks the four cases
  (centre, neighbour, out-and-back, corner). The Molten Flood leaves 1.6 m between lanes (1.2 m on the Firestorm,
  widened from 0.6 m, narrower than the hero, by narrowing its lanes 2.0 → 1.4 m).
- No drop lands on the player (the safe radius) and drops in the air hurt nothing.
- One attack at a time, so no pattern starts while a marker locks.

## Tests (raw)
Lint on the final tree:
```
$ gdformat --check src scripts tests && gdlint src scripts tests
783 files would be left unchanged
Success: no problems found
```
New: `tests/unit/sim/test_boss_fights_3.gd` (13: both phase scripts and HP, both shielded signatures, the grid tracks
then locks with one colour drawn, the grid's four stand cases, the Barrage's three circles in turn, the Rail tracks
then locks (stay hit / step out missed), the Molten Flood's rows and gap, the fountain's rain and flower, no drop on
the player, the Furnace Waves alternate and shift, determinism of both fights, the cannon embers slow and in their
look); `tests/unit/presentation/test_boss_fight_views_3.gd` (7: both looks off the hero's colours, the smoke trail,
the rain drawn on its arc then as fireballs, the grid drawn = struck, the flood dull → flash → molten, the Foundry's
shielded pose in the fountain, the avatars' move mapping); `tests/e2e/test_e2e_boss_dodge_3.gd` (main.tscn, real
input: the Siege Engine summoned from the dev panel, a Barrage circle locks on the player, the stick walks out, it
strikes where it locked and misses; its cannon embers drawn).
Changed: `test_bosses_2.gd` (the Foundry's phase 2 opens with its fountain; its flood follows the row),
`test_boss_views.gd` and `test_boss_telegraph_parity.gd` (the Siege Engine's v0.7.0 moves on fixtures, the new moves
added), `tests/support/boss_lab.gd` (`siege_v070_def`, `ensure_attack`).

`godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd <-gtest=… / -gdir=…> -ginclude_subdirs -gexit`
on a shared machine (other agents' runs alongside). The GUT totals as printed:

| Run | Tree | Raw totals |
|---|---|---|
| `tests/unit/presentation` | `e903a88`'s code | `Scripts 77`, `Tests 498`, `Passing Tests 498` |
| boss sim files: `test_bosses`, `test_bosses_2`, `test_boss_fights`, `test_boss_fights_3`, `test_boss_gates`, `test_boss_pressure`, `test_boss_challenge`, `test_bullet_patterns`, `test_boss_markers`, `test_rewards` | `e903a88`'s code | `Scripts 10`, `Tests 135`, `Passing Tests 135` |
| `tests/golden`, `tests/arch`, `tests/content`, `tests/unit/application`, `tests/unit/debug` | `e903a88`'s code | `Scripts 42`, `Tests 218`, `Passing Tests 218` |
| e2e: `test_e2e_boss_dodge_3`, `test_e2e_boss_dodge`, `test_e2e_bosses`, `test_e2e_bosses_2`, `test_e2e_boss_challenge`, `test_e2e_after_boss`, `test_e2e_ascension`, `test_e2e_audio`, `test_e2e_dev_master_panel` | `e903a88`'s code | `Scripts 9`, `Tests 15`, `Passing Tests 15` |
| `tests/unit/sim` (the whole folder) | `e903a88`'s code | `Scripts 95`, `Tests 991`, `Passing Tests 991` (`test_readable_cause.gd` 4/4 among them; the every-card soak: `SOAK\| kills=265 events=6696 most_in_a_tick=188 limits=0 (watchdog 0, heal cap 0)`) |

First runs that failed and were fixed (raw): `test_bosses_2.gd` "the foundry's phase two opens with five molten
lanes" (`[1] expected to equal [5]`: phase 2 opens with the fountain now) and "flood windups track then commit"
(angle-based; the rows run along x); `test_boss_pressure.gd` "foundry / siege_engine has a gap-closer" and
`test_bosses_2.gd` "foundry: a gap-closer" (`[-1] expected to be >= than [0]`: the first data had none; gap-closers
restored); the new view test "a dark edge" (`[0.16280941665173] expected to be < than [0.15]` for the molten edge
#3A2808, changed to #2A1C06).

The fight logs the boss tests print (bot fights, not the bot sims): `BOSSFIGHT| siege_engine MELEE ticks=3510
seconds=58.5 hits=158`, `RANGED_NEAR ticks=5456 seconds=90.9`, `RANGED_FAR ticks=10432 seconds=173.9 punished=26`;
`BOSSFIGHT| foundry MELEE ticks=3753 seconds=62.5 hits=172`, `RANGED_NEAR ticks=4018 seconds=67.0`, `RANGED_FAR
ticks=8883 seconds=148.1 punished=34`; `BO_CAUSE| foundry seed=9102 ticks=3600 hits=29 violations=0`. No v0.7.0
numbers from the same bots are at hand here, so these are not a fight-length ratio.

`tests/golden` passed unchanged (no golden fixture changed).

## Screenshots
`VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" godot --path .
--audio-driver Dummy --resolution 1600x900 -s scripts/shots/boss_fights.gd` (xvfb + llvmpipe, exit 0), copied from
`build/shots/v0.7.5-dev/boss_fights/`:
- [`10_siege_turret_cross_shielded.jpg`](shots/boss_fights/10_siege_turret_cross_shielded.jpg) (the four arms trail
  as spirals; the shell up)
- [`12_siege_mortar_grid_locked.jpg`](shots/boss_fights/12_siege_mortar_grid_locked.jpg) (the first colour flashing,
  the hero on its centre square; cells in walls left out)
- [`13_siege_mortar_grid_second_colour.jpg`](shots/boss_fights/13_siege_mortar_grid_second_colour.jpg)
- [`14_siege_barrage_in_turn.jpg`](shots/boss_fights/14_siege_barrage_in_turn.jpg)
- [`15_siege_rail_locked.jpg`](shots/boss_fights/15_siege_rail_locked.jpg)
- [`16_foundry_slag_fountain_raining.jpg`](shots/boss_fights/16_foundry_slag_fountain_raining.jpg) (the first wave
  in the air over the shut Foundry)
- [`17_foundry_slag_fountain_flower.jpg`](shots/boss_fights/17_foundry_slag_fountain_flower.jpg)
- [`18_foundry_furnace_waves.jpg`](shots/boss_fights/18_foundry_furnace_waves.jpg)
- [`19_foundry_molten_flood_locked.jpg`](shots/boss_fights/19_foundry_molten_flood_locked.jpg) (the rows cut short by
  the stage's pillars and wall)

## Not measured / open
- **Fight length ≈ 1.5×: NOT YET RUN** (the bot sims are not an agent's run here). HP ×1.25 is data; the shielded
  time is the signatures' windup and waves (Turret Cross 0.9 s + 2.7 s; Slag Fountain 1.0 s + 0.7 s + 2.0 s).
  OWNER ONLY: whether it feels 1.5× and whether the dodging is fun.
- Starting values for F10: every speed, count, gap, the lock 0.8 s, HP, damage (fireballs 14).
- A player who stays far keeps drawing the gap-closer (Barrage / Molten Flood) and the punish; BF1 dropped the
  Gatekeeper's gap-closer for that reason. Kept here because the anti-kite rule (and its tests) asks for one; the
  owner may prefer none.
- Drops in the air are drawn from the boss's centre (2.6 m up), not from the Foundry model's chimney anchors (a view
  polish).
- Not run: the full suite (the lead's, on GitHub), the bot sims, `scripts/ci/seams.sh` (the lead's after merging),
  the sim bench and the hitch probe.

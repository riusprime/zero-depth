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
- `FireballViews.LOOKS`: `cannon_ember` (core #D79000 since the merge, was #FFB878; edge #2E1A0E, a grey smoke
  trail with no glow: a new optional
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

### After merging `claude/v0.7.5-new-ground` at `96bb7ea` (BF2, its fix, EF) into `v075-bf3`
The lead's heads-up (2026-10-13): BF2's fix made every non-burst pattern show a `cast` telegraph (`ground: false`)
and added `ProjectileStore.cause`. Conflicts were append-only (both sides added functions, looks, strings, doc
paragraphs); kept both, with BF2's `cast` form of `pattern_telegraph` (BF3 never relied on its old `{}`; a raining
flower shows the cast too). Every BF3 pattern windup is ≥ 0.8 s, over `MIN_TELEGRAPH_TICKS`. Two failures the merged
tree showed, both fixed in the merge commit:
- `tests/unit/application` `test_old_saves.gd` / `test_ascension_saves.gd`: `["World.projectiles.cause: not in the
  snapshot"] expected to equal [""]` (3 tests, with cascades). BF2's fix added the `cause` column without listing it
  among the fields an older snapshot may lack; added to `WorldSnapshot.ADDED_SINCE_V05` (`ProjectileStore`, empty =
  none, as `look`). A shared-engine fix outside BF3's own code: the lead should know (on `96bb7ea` alone this would
  fail the same way; not run there by me).
- `test_boss_fights_2_views.gd`: `[0.05614833906293] expected to be > than [0.15]: ember_stone and cannon_ember read
  apart` (BF2's test that every pair of looks differs). The cannon embers' core #FFB878 → #D79000 (amber orange):
  0.29 from the hero's colours, 0.24+ from every other look.

| Run (merged tree) | Raw totals |
|---|---|
| `tests/golden`, `tests/arch`, `tests/content`, `tests/unit/application`, `tests/unit/debug`, before the snapshot fix | `Tests 241`, `Passing Tests 238`, `Failing Tests 3` (above) |
| `test_old_saves.gd`, `test_ascension_saves.gd` after it | `Scripts 2`, `Tests 8`, `Passing Tests 8` |
| `tests/golden`, `tests/arch`, `tests/content`, `tests/unit/application`, `tests/unit/debug` after it | `Scripts 43`, `Tests 241`, `Passing Tests 241` |
| boss sim files (BF3's list + `test_boss_fights_2`, `test_readable_cause`, `test_enemy_fireballs`) | `Scripts 13`, `Tests 167`, `Passing Tests 167` |
| `tests/unit/presentation`, before the colour change | `Tests 513`, `Passing Tests 512`, `Failing Tests 1` (above) |
| `tests/unit/presentation`, after it | `Scripts 80`, `Tests 513`, `Passing Tests 513` |
| e2e: `test_e2e_boss_dodge_3`, `_2`, `test_e2e_boss_dodge`, `test_e2e_bosses`, `_2`, `test_e2e_boss_challenge`, `test_e2e_after_boss`, `test_e2e_ascension`, `test_e2e_audio` | `Scripts 9`, `Tests 14`, `Passing Tests 14` |

Not re-run on the merged tree: the whole `tests/unit/sim` folder (its pre-merge run is above).

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
`build/shots/v0.7.5-dev/boss_fights/` (re-run on the merged tree after the cannon-ember colour change, below; BF2's
rows come first in the script, so the Siege Engine's and the Foundry's are 20–30; named `bf3_*` as BF2 named its):
- [`bf3_20_siege_turret_cross_shielded.jpg`](shots/boss_fights/bf3_20_siege_turret_cross_shielded.jpg) (the four arms trail
  as spirals; the shell up)
- [`bf3_22_siege_mortar_grid_locked.jpg`](shots/boss_fights/bf3_22_siege_mortar_grid_locked.jpg) (the first colour flashing,
  the hero on its centre square; cells in walls left out)
- [`bf3_23_siege_mortar_grid_second_colour.jpg`](shots/boss_fights/bf3_23_siege_mortar_grid_second_colour.jpg)
- [`bf3_24_siege_barrage_in_turn.jpg`](shots/boss_fights/bf3_24_siege_barrage_in_turn.jpg)
- [`bf3_25_siege_rail_locked.jpg`](shots/boss_fights/bf3_25_siege_rail_locked.jpg)
- [`bf3_26_foundry_slag_fountain_raining.jpg`](shots/boss_fights/bf3_26_foundry_slag_fountain_raining.jpg) (the first wave
  in the air over the shut Foundry)
- [`bf3_27_foundry_slag_fountain_flower.jpg`](shots/boss_fights/bf3_27_foundry_slag_fountain_flower.jpg)
- [`bf3_28_foundry_furnace_waves.jpg`](shots/boss_fights/bf3_28_foundry_furnace_waves.jpg)
- [`bf3_29_foundry_molten_flood_locked.jpg`](shots/boss_fights/bf3_29_foundry_molten_flood_locked.jpg) (the rows cut short by
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

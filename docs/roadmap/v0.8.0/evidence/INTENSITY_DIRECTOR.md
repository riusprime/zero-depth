# v0.8.0 N5 — the intensity director

Owner line **O58** (2026-10-16, Left 4 Dead's AI director): "Every player carries one hidden number, intensity. Take a
hit, it climbs. A zombie dies beside you, it climbs. It drains away, but never while you're under attack. The AI
director … sends more and more until it peaks. Then it pulls everything back. 10 to 20 seconds of quiet. Then it builds
again. So the peaks land somewhere new every run. And it isn't learning. It's a few simple rules. It doesn't change how
hard the game hits. It changes when." Owner answers: pull back = "Stop sending new ones"; warning cue: "for now
nothing, quietness, the enemies are the real indicator".

Build: worktree on `57bbaff` (branch `v080-n5`) with this step's changes, uncommitted when the commands below ran;
the step's commit is the one that adds this file. Godot 4.7.2.stable.official.ed1daf0bf, headless, Linux container.

## The rules (sim: `src/sim/world/intensity.gd`; contract: SIM_CONTRACTS §11)

- Runs inside `SpawnDirector.advance` (tick phase 9), so only on ordinary floor spawning. Sealed arenas, the Overrun,
  boss rooms, waves/encounters and the final arena never run it (it is frozen there; a kill or a hit there counts
  nothing). A spawner without `SpawnTable.intensity` (labs, the kernel, a hand-built `compile_spawning`) is unchanged.
- **Intensity** 0..1000 (held as × 1000 integers, `World.intensity.level`):
  - a **hit**: the hero's HP fell since the tick before → `+ lost × hit_full_hp_gain / max HP` (any HP loss counts);
  - **close**: an alive enemy within `close_radius_m` → `+ close_gain_per_second / 60` every tick;
  - a **kill** within `close_radius_m` (`World._remove_dead` → `Intensity.on_death`) → `+ close_kill_gain`;
  - **drain**: only once `calm_seconds` passed with no hit and no enemy close: `− drain_per_second / 60` a tick.
- **States**:
  - `BUILD_UP`: today's packs at the curve's cap; the interval to the next pack is the curve's × `build_interval_permille`
    (the ramp toward the peak: sooner, never more at once, never stronger). At `peak_intensity` → `PEAK`; one stream
    `ai:intensity:<cycle>` (derived from the floor's seed) draws the peak's length (3–5 s), then the quiet's (10–20 s).
  - `PEAK`: packs at the curve's interval, for the drawn length → `PULL_BACK`.
  - `PULL_BACK`: **no new packs** (the enemies out stay); ends when at most `pull_back_enemies` alive enemies are within
    `pull_back_radius_m`, or after `pull_back_max_seconds` → `QUIET`.
  - `QUIET`: **no new packs**; ends when its drawn length has passed and intensity ≤ `relax_intensity`, or at the latest
    `quiet_seconds_max` after it began (then intensity drops to `relax_intensity`) → `BUILD_UP`, cycle + 1.
- What arrives and how strong is untouched: the cap, the mix, the pack size, the danger tier, the curve's easing, loop
  scaling, curses, Deep and the hidden catch-up all run as before (unit test
  `test_it_never_changes_what_arrives_or_how_strong`).
- No cue for the player. `WorldReader.has_intensity / intensity / intensity_mode / intensity_timer`; F10 → Tools shows
  "intensity 512 PEAK 2.0 s" (`DevPanel.intensity_text`). The values are in `data/spawning/intensity.tres`, so the dev
  panel's Difficulty group (its `data/spawning` folder) lists and tunes them like the other spawn values.
- Saved and hashed: `World.intensity` (`IntensityState`) is snapshotted and hashed only when the spawner has the table;
  an older save (no `intensity` key, `WorldSnapshot.ADDED_SINCE_V05`) starts the floor in `BUILD_UP` at 0.

## The values (`data/spawning/intensity.tres`; starting values, not measurements)

| Field | Value | |
|---|---|---|
| `close_radius_m` | 3.0 | "beside you" |
| `hit_full_hp_gain` | 1000 | a hit of 10 % of max HP adds 100 |
| `close_kill_gain` | 25 | a kill within 3 m |
| `close_gain_per_second` | 30 | while an enemy is within 3 m |
| `drain_per_second` | 60 | after 2 s calm |
| `calm_seconds` | 2.0 | |
| `peak_intensity` | 750 | |
| `peak_seconds_min` / `max` | 3 / 5 | |
| `pull_back_radius_m`, `pull_back_enemies`, `pull_back_max_seconds` | 8.0, 2, 4.0 | |
| `quiet_seconds_min` / `max` | 10 / 20 | |
| `relax_intensity` | 400 | |
| `build_interval_permille` | 400 | build-up packs at 0.4 × the curve's interval |

How they were reached, honestly: the first set (hit gain 2000, relax 300, pull back 8 s, no ramp, and a quiet with no
upper end) got stuck in QUIET for four minutes on seed 11 (leftover ranged enemies kept hitting the hero, so intensity
never drained) and killed 86.6 % fewer enemies a minute. The quiet got its 20 s upper end; then three runs on seeds
11–13 changed `build_interval_permille` 1000 → 500 → 400, `pull_back_max_seconds` 8 → 4, `hit_full_hp_gain` 2000 →
1000 and `relax_intensity` 300 → 400 (kills/min −37.7 %, −24.3 %, −23.7 % against off). Then I stopped tuning and ran the
final five seeds below.

## Proof (scripted sim, not the bot suite)

`scripts/checks/intensity_curve.gd`: floor 1 of each run seed as Main builds it (`SaveLab.floor_world`, Blade), a
scripted fighting hero (`FightBot`'s input, held within 5 m of where it starts so it fights in its room and never walks
into an arena or the boss room), 300 s of floor time, HP topped up to full whenever it falls under 35 % (a poke between
ticks, so it lives the whole time; the same in both runs). Each seed runs with the director (as shipped) and with it
off (`SpawnTable.intensity = null`, today's spawning). Quiet lengths and no-pack gaps are counted in director ticks:
the 1,647–1,833 of the 18,000 ticks where phase 9 didn't run are left out ("director ticks" in the raw lines; a
one-off probe on seed 11 found none of them was an altar choice, an arena or the boss room, which leaves the hit-stop
freeze, where the whole world stands still). Peak starts are in floor ticks.

```
godot --headless --path . -s scripts/checks/intensity_curve.gd -- seeds=11,12,13,14,15 seconds=300 curve=11
```

### Summary lines (raw)

```
SEED 11 | peaks at s [56.9, 96.8, 147.4, 187.3, 230.9, 273.4] | quiet lengths s [20.0, 20.0, 20.0, 20.0, 20.0] | no-pack gaps s [13.3, 26.5, 24.9, 40.5, 24.6, 14.9] | kills/min on 22.0 off 23.8 (-7.6 %)
SEED 11 | on: kills 110, heals 11, director ticks 16271/18000 | off: kills 119, heals 12
SEED 12 | peaks at s [54.9, 92.3, 131.9, 169.4, 210.3, 250.1, 286.9] | quiet lengths s [20.0, 20.0, 20.0, 20.0, 20.0, 20.0] | no-pack gaps s [30.1, 26.2, 24.1, 25.4, 31.6, 15.8] | kills/min on 23.4 off 38.0 (-38.4 %)
SEED 12 | on: kills 117, heals 12, director ticks 16353/18000 | off: kills 190, heals 11
SEED 13 | peaks at s [63.8, 100.2, 136.9, 177.6, 208.0, 247.3, 291.9] | quiet lengths s [20.0, 20.0, 20.0, 20.0, 20.0, 20.0] | no-pack gaps s [10.3, 22.9, 14.0, 32.3, 19.4, 13.4, 34.9, 12.3] | kills/min on 23.0 off 27.8 (-17.3 %)
SEED 13 | on: kills 115, heals 11, director ticks 16202/18000 | off: kills 139, heals 14
SEED 14 | peaks at s [40.0, 79.3, 116.1, 156.2, 196.6, 237.9, 276.6] | quiet lengths s [20.0, 20.0, 20.0, 20.0, 20.0, 20.0] | no-pack gaps s [12.0, 21.5, 10.7, 11.4, 19.6, 28.8, 25.7, 33.2] | kills/min on 24.8 off 30.6 (-19.0 %)
SEED 14 | on: kills 124, heals 11, director ticks 16167/18000 | off: kills 153, heals 13
SEED 15 | peaks at s [67.0, 102.7, 137.8, 172.9, 210.6, 249.3, 288.3] | quiet lengths s [20.0, 20.0, 20.0, 20.0, 20.0, 20.0] | no-pack gaps s [15.9, 12.4, 12.3, 24.6, 22.9, 21.9, 28.1, 33.7, 28.4] | kills/min on 23.4 off 27.8 (-15.8 %)
SEED 15 | on: kills 117, heals 10, director ticks 16325/18000 | off: kills 139, heals 12
MEAN kills/min on 23.3 off 29.6 (-21.2 %)
```

### Findings

- **Peaks**: 6–7 per 5 minutes on every seed (needed: at least two), roughly 35–50 s apart.
- **Peaks land at different times per seed**: the first peak at 56.9 / 54.9 / 63.8 / 40.0 / 67.0 s on seeds 11–15,
  and the later ones drift apart further (e.g. the third: 147.4 / 131.9 / 136.9 / 116.1 / 137.8 s).
- **Quiet**: every QUIET on every seed ran its full 20.0 s (the upper end), never the shorter drawn length. With this
  hero, enemies left over from the peak (several ranged ones it can't reach on its leash) keep hitting it or stay within
  3 m, so intensity never falls below 400 before 20 s. The drawn 10–20 s only shows when the hero clears the leftovers.
  The no-pack gaps (pull back + quiet, plus any build-up time with the cap full or no anchor far enough) ran
  10.3–40.5 s; most are 12–30 s.
- **Kills per floor-minute**: mean **23.3 with the director, 29.6 without: −21.2 %**. That misses the ±20 % target
  by 1.2 points; per seed −7.6 %, −38.4 %, −17.3 %, −19.0 %, −15.8 % (seed 12 far outside). Without the director the
  alive count sits at the cap (18 of 18) for most of the run, so this hero's kill rate is bound by how fast it kills,
  not by how fast packs come; any stretch with no new packs takes kills away unless the cap rises, which the brief
  rules out ("it doesn't change how hard the game hits"). Reported, not retuned further: D46 asks the owner.

### The recorded curve (seed 11, director on, every 5 s; the full once-a-second table is in the raw output)

| s | intensity | state | alive / cap | enemies within 3 m | kills | intensity / 25 |
|---|---|---|---|---|---|---|
| 5 | 0 | BUILD | 1/5 | 0 | 0 | ` ` |
| 10 | 15 | BUILD | 3/5 | 1 | 0 | ` ` |
| 15 | 0 | BUILD | 4/5 | 0 | 1 | ` ` |
| 20 | 50 | BUILD | 5/5 | 0 | 3 | `##` |
| 25 | 53 | BUILD | 5/5 | 0 | 4 | `##` |
| 30 | 124 | BUILD | 5/5 | 0 | 4 | `####` |
| 35 | 114 | BUILD | 6/6 | 0 | 5 | `####` |
| 40 | 206 | BUILD | 6/6 | 0 | 6 | `########` |
| 45 | 167 | BUILD | 8/9 | 1 | 6 | `######` |
| 50 | 423 | BUILD | 9/9 | 1 | 8 | `################` |
| 55 | 703 | BUILD | 9/9 | 0 | 12 | `############################` |
| 60 | 861 | PEAK | 8/9 | 1 | 14 | `##################################` |
| 65 | 1000 | QUIET | 3/12 | 2 | 19 | `########################################` |
| 70 | 1000 | QUIET | 2/13 | 1 | 20 | `########################################` |
| 75 | 961 | QUIET | 1/13 | 0 | 21 | `######################################` |
| 80 | 815 | QUIET | 1/13 | 0 | 21 | `################################` |
| 85 | 305 | BUILD | 10/14 | 0 | 21 | `############` |
| 90 | 256 | BUILD | 17/17 | 0 | 21 | `##########` |
| 95 | 537 | BUILD | 18/18 | 0 | 21 | `#####################` |
| 100 | 1000 | PEAK | 15/18 | 2 | 25 | `########################################` |
| 105 | 1000 | PULL | 13/18 | 2 | 30 | `########################################` |
| 110 | 1000 | QUIET | 8/18 | 0 | 35 | `########################################` |
| 115 | 1000 | QUIET | 7/18 | 0 | 36 | `########################################` |
| 120 | 1000 | QUIET | 6/18 | 0 | 37 | `########################################` |
| 125 | 1000 | QUIET | 4/18 | 1 | 39 | `########################################` |
| 130 | 450 | BUILD | 8/18 | 0 | 39 | `##################` |
| 135 | 528 | BUILD | 18/18 | 0 | 40 | `#####################` |
| 140 | 296 | BUILD | 18/18 | 0 | 40 | `###########` |
| 145 | 597 | BUILD | 18/18 | 2 | 41 | `#######################` |
| 150 | 1000 | PEAK | 18/18 | 4 | 42 | `########################################` |
| 155 | 1000 | PULL | 16/18 | 2 | 45 | `########################################` |
| 160 | 1000 | QUIET | 10/18 | 1 | 51 | `########################################` |
| 165 | 1000 | QUIET | 8/18 | 0 | 53 | `########################################` |
| 170 | 1000 | QUIET | 8/18 | 0 | 53 | `########################################` |
| 175 | 1000 | QUIET | 7/18 | 0 | 54 | `########################################` |
| 180 | 440 | BUILD | 11/18 | 0 | 54 | `#################` |
| 185 | 596 | BUILD | 18/18 | 0 | 55 | `#######################` |
| 190 | 914 | PEAK | 18/18 | 3 | 56 | `####################################` |
| 195 | 1000 | PULL | 16/18 | 1 | 61 | `########################################` |
| 200 | 1000 | QUIET | 13/18 | 1 | 64 | `########################################` |
| 205 | 1000 | QUIET | 9/18 | 0 | 68 | `########################################` |
| 210 | 1000 | QUIET | 8/18 | 0 | 69 | `########################################` |
| 215 | 1000 | QUIET | 6/18 | 4 | 71 | `########################################` |
| 220 | 1000 | QUIET | 5/18 | 0 | 72 | `########################################` |
| 225 | 469 | BUILD | 18/18 | 0 | 72 | `##################` |
| 230 | 704 | BUILD | 18/18 | 1 | 74 | `############################` |
| 235 | 1000 | PEAK | 17/18 | 2 | 78 | `########################################` |
| 240 | 1000 | PULL | 14/18 | 1 | 82 | `########################################` |
| 245 | 1000 | QUIET | 13/18 | 3 | 83 | `########################################` |
| 250 | 1000 | QUIET | 12/18 | 3 | 86 | `########################################` |
| 255 | 1000 | QUIET | 6/18 | 0 | 92 | `########################################` |
| 260 | 1000 | QUIET | 5/18 | 0 | 93 | `########################################` |
| 265 | 400 | BUILD | 9/18 | 0 | 95 | `################` |
| 270 | 611 | BUILD | 18/18 | 2 | 95 | `########################` |
| 275 | 865 | PEAK | 18/18 | 0 | 98 | `##################################` |
| 280 | 1000 | PULL | 17/18 | 1 | 99 | `########################################` |
| 285 | 1000 | QUIET | 17/18 | 4 | 99 | `########################################` |
| 290 | 1000 | QUIET | 7/18 | 0 | 109 | `########################################` |
| 295 | 1000 | QUIET | 6/18 | 0 | 110 | `########################################` |
| 300 | 1000 | QUIET | 6/18 | 0 | 110 | `########################################` |

<details><summary>Raw output (full)</summary>

```
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org

intensity_curve: seeds=[11, 12, 13, 14, 15] seconds=300 build=blade floor=1
CURVE seed 11 on | s | intensity | state | alive/cap | near 3 m | kills | ascii (intensity / 25)
CURVE 11 |   1 |    0 | BUILD |   0/  5 |  0 |    0 | 
CURVE 11 |   2 |    0 | BUILD |   0/  5 |  0 |    0 | 
CURVE 11 |   3 |    0 | BUILD |   0/  5 |  0 |    0 | 
CURVE 11 |   4 |    0 | BUILD |   0/  5 |  0 |    0 | 
CURVE 11 |   5 |    0 | BUILD |   1/  5 |  0 |    0 | 
CURVE 11 |   6 |    0 | BUILD |   1/  5 |  0 |    0 | 
CURVE 11 |   7 |    0 | BUILD |   2/  5 |  0 |    0 | 
CURVE 11 |   8 |    0 | BUILD |   2/  5 |  0 |    0 | 
CURVE 11 |   9 |    0 | BUILD |   3/  5 |  0 |    0 | 
CURVE 11 |  10 |   15 | BUILD |   3/  5 |  1 |    0 | 
CURVE 11 |  11 |   60 | BUILD |   2/  5 |  0 |    1 | ##
CURVE 11 |  12 |   60 | BUILD |   3/  5 |  0 |    1 | ##
CURVE 11 |  13 |   43 | BUILD |   3/  5 |  0 |    1 | #
CURVE 11 |  14 |    0 | BUILD |   4/  5 |  0 |    1 | 
CURVE 11 |  15 |    0 | BUILD |   4/  5 |  0 |    1 | 
CURVE 11 |  16 |    0 | BUILD |   5/  5 |  0 |    1 | 
CURVE 11 |  17 |   40 | BUILD |   4/  5 |  0 |    2 | #
CURVE 11 |  18 |   40 | BUILD |   5/  5 |  0 |    2 | #
CURVE 11 |  19 |   35 | BUILD |   5/  5 |  0 |    2 | #
CURVE 11 |  20 |   50 | BUILD |   5/  5 |  0 |    3 | ##
CURVE 11 |  21 |  135 | BUILD |   5/  5 |  1 |    3 | #####
CURVE 11 |  22 |  162 | BUILD |   5/  5 |  0 |    4 | ######
CURVE 11 |  23 |  162 | BUILD |   5/  5 |  0 |    4 | ######
CURVE 11 |  24 |  113 | BUILD |   5/  5 |  0 |    4 | ####
CURVE 11 |  25 |   53 | BUILD |   5/  5 |  0 |    4 | ##
CURVE 11 |  26 |   61 | BUILD |   5/  5 |  0 |    4 | ##
CURVE 11 |  27 |   81 | BUILD |   5/  5 |  0 |    4 | ###
CURVE 11 |  28 |  101 | BUILD |   5/  5 |  0 |    4 | ####
CURVE 11 |  29 |  102 | BUILD |   5/  5 |  1 |    4 | ####
CURVE 11 |  30 |  124 | BUILD |   5/  5 |  0 |    4 | ####
CURVE 11 |  31 |  124 | BUILD |   6/  6 |  0 |    4 | ####
CURVE 11 |  32 |   78 | BUILD |   6/  6 |  0 |    4 | ###
CURVE 11 |  33 |   51 | BUILD |   6/  6 |  1 |    4 | ##
CURVE 11 |  34 |  114 | BUILD |   6/  6 |  0 |    5 | ####
CURVE 11 |  35 |  114 | BUILD |   6/  6 |  0 |    5 | ####
CURVE 11 |  36 |  134 | BUILD |   6/  6 |  0 |    5 | #####
CURVE 11 |  37 |  134 | BUILD |   6/  6 |  0 |    5 | #####
CURVE 11 |  38 |  144 | BUILD |   6/  6 |  1 |    5 | #####
CURVE 11 |  39 |  186 | BUILD |   6/  6 |  0 |    6 | #######
CURVE 11 |  40 |  206 | BUILD |   6/  6 |  0 |    6 | ########
CURVE 11 |  41 |  206 | BUILD |   6/  6 |  0 |    6 | ########
CURVE 11 |  42 |  205 | BUILD |   6/  6 |  0 |    6 | ########
CURVE 11 |  43 |  145 | BUILD |   6/  6 |  0 |    6 | #####
CURVE 11 |  44 |  139 | BUILD |   6/  6 |  0 |    6 | #####
CURVE 11 |  45 |  167 | BUILD |   8/  9 |  1 |    6 | ######
CURVE 11 |  46 |  219 | BUILD |   7/  9 |  0 |    7 | ########
CURVE 11 |  47 |  243 | BUILD |   9/  9 |  2 |    7 | #########
CURVE 11 |  48 |  369 | BUILD |   8/  9 |  1 |    8 | ##############
CURVE 11 |  49 |  394 | BUILD |   9/  9 |  1 |    8 | ###############
CURVE 11 |  50 |  423 | BUILD |   9/  9 |  1 |    8 | ################
CURVE 11 |  51 |  485 | BUILD |   9/  9 |  1 |    9 | ###################
CURVE 11 |  52 |  600 | BUILD |   8/  9 |  2 |   10 | ########################
CURVE 11 |  53 |  676 | BUILD |   7/  9 |  0 |   12 | ###########################
CURVE 11 |  54 |  677 | BUILD |   9/  9 |  1 |   12 | ###########################
CURVE 11 |  55 |  703 | BUILD |   9/  9 |  0 |   12 | ############################
CURVE 11 |  56 |  709 | BUILD |   9/  9 |  1 |   12 | ############################
CURVE 11 |  57 |  755 | PEAK  |   9/  9 |  0 |   13 | ##############################
CURVE 11 |  58 |  784 | PEAK  |   9/  9 |  1 |   13 | ###############################
CURVE 11 |  59 |  810 | PEAK  |   9/  9 |  1 |   13 | ################################
CURVE 11 |  60 |  861 | PEAK  |   8/  9 |  1 |   14 | ##################################
CURVE 11 |  61 |  908 | QUIET |   8/  9 |  0 |   14 | ####################################
CURVE 11 |  62 |  945 | QUIET |   7/  9 |  3 |   15 | #####################################
CURVE 11 |  63 | 1000 | QUIET |   4/  9 |  0 |   18 | ########################################
CURVE 11 |  64 | 1000 | QUIET |   4/ 12 |  1 |   18 | ########################################
CURVE 11 |  65 | 1000 | QUIET |   3/ 12 |  2 |   19 | ########################################
CURVE 11 |  66 | 1000 | QUIET |   3/ 12 |  0 |   19 | ########################################
CURVE 11 |  67 | 1000 | QUIET |   3/ 13 |  2 |   19 | ########################################
CURVE 11 |  68 | 1000 | QUIET |   3/ 13 |  2 |   19 | ########################################
CURVE 11 |  69 | 1000 | QUIET |   3/ 13 |  2 |   19 | ########################################
CURVE 11 |  70 | 1000 | QUIET |   2/ 13 |  1 |   20 | ########################################
CURVE 11 |  71 | 1000 | QUIET |   2/ 13 |  1 |   20 | ########################################
CURVE 11 |  72 | 1000 | QUIET |   2/ 13 |  1 |   20 | ########################################
CURVE 11 |  73 | 1000 | QUIET |   1/ 13 |  0 |   21 | ########################################
CURVE 11 |  74 | 1000 | QUIET |   1/ 13 |  0 |   21 | ########################################
CURVE 11 |  75 |  961 | QUIET |   1/ 13 |  0 |   21 | ######################################
CURVE 11 |  76 |  901 | QUIET |   1/ 13 |  0 |   21 | ####################################
CURVE 11 |  77 |  841 | QUIET |   1/ 13 |  0 |   21 | #################################
CURVE 11 |  78 |  836 | QUIET |   1/ 13 |  0 |   21 | #################################
CURVE 11 |  79 |  836 | QUIET |   1/ 13 |  0 |   21 | #################################
CURVE 11 |  80 |  815 | QUIET |   1/ 13 |  0 |   21 | ################################
CURVE 11 |  81 |  836 | QUIET |   1/ 13 |  0 |   21 | #################################
CURVE 11 |  82 |  836 | QUIET |   1/ 13 |  0 |   21 | #################################
CURVE 11 |  83 |  381 | BUILD |   4/ 13 |  0 |   21 | ###############
CURVE 11 |  84 |  321 | BUILD |   7/ 14 |  0 |   21 | ############
CURVE 11 |  85 |  305 | BUILD |  10/ 14 |  0 |   21 | ############
CURVE 11 |  86 |  305 | BUILD |  10/ 17 |  0 |   21 | ############
CURVE 11 |  87 |  282 | BUILD |  13/ 17 |  0 |   21 | ###########
CURVE 11 |  88 |  308 | BUILD |  15/ 17 |  0 |   21 | ############
CURVE 11 |  89 |  308 | BUILD |  17/ 17 |  0 |   21 | ############
CURVE 11 |  90 |  256 | BUILD |  17/ 17 |  0 |   21 | ##########
CURVE 11 |  91 |  242 | BUILD |  17/ 17 |  1 |   21 | #########
CURVE 11 |  92 |  250 | BUILD |  17/ 17 |  2 |   21 | ##########
CURVE 11 |  93 |  384 | BUILD |  17/ 17 |  3 |   21 | ###############
CURVE 11 |  94 |  517 | BUILD |  17/ 17 |  3 |   21 | ####################
CURVE 11 |  95 |  537 | BUILD |  18/ 18 |  0 |   21 | #####################
CURVE 11 |  96 |  670 | BUILD |  18/ 18 |  3 |   21 | ##########################
CURVE 11 |  97 |  804 | PEAK  |  18/ 18 |  3 |   21 | ################################
CURVE 11 |  98 |  875 | PEAK  |  17/ 18 |  1 |   23 | ###################################
CURVE 11 |  99 |  933 | PEAK  |  17/ 18 |  2 |   23 | #####################################
CURVE 11 | 100 | 1000 | PEAK  |  15/ 18 |  2 |   25 | ########################################
CURVE 11 | 101 | 1000 | PEAK  |  18/ 18 |  2 |   25 | ########################################
CURVE 11 | 102 | 1000 | PULL  |  18/ 18 |  3 |   25 | ########################################
CURVE 11 | 103 | 1000 | PULL  |  17/ 18 |  3 |   26 | ########################################
CURVE 11 | 104 | 1000 | PULL  |  15/ 18 |  1 |   28 | ########################################
CURVE 11 | 105 | 1000 | PULL  |  13/ 18 |  2 |   30 | ########################################
CURVE 11 | 106 | 1000 | PULL  |  11/ 18 |  3 |   32 | ########################################
CURVE 11 | 107 | 1000 | QUIET |   9/ 18 |  0 |   34 | ########################################
CURVE 11 | 108 | 1000 | QUIET |   9/ 18 |  2 |   34 | ########################################
CURVE 11 | 109 | 1000 | QUIET |   8/ 18 |  1 |   35 | ########################################
CURVE 11 | 110 | 1000 | QUIET |   8/ 18 |  0 |   35 | ########################################
CURVE 11 | 111 | 1000 | QUIET |   8/ 18 |  1 |   35 | ########################################
CURVE 11 | 112 | 1000 | QUIET |   7/ 18 |  0 |   36 | ########################################
CURVE 11 | 113 | 1000 | QUIET |   7/ 18 |  0 |   36 | ########################################
CURVE 11 | 114 | 1000 | QUIET |   7/ 18 |  1 |   36 | ########################################
CURVE 11 | 115 | 1000 | QUIET |   7/ 18 |  0 |   36 | ########################################
CURVE 11 | 116 | 1000 | QUIET |   7/ 18 |  1 |   36 | ########################################
CURVE 11 | 117 | 1000 | QUIET |   6/ 18 |  0 |   37 | ########################################
CURVE 11 | 118 | 1000 | QUIET |   6/ 18 |  0 |   37 | ########################################
CURVE 11 | 119 | 1000 | QUIET |   6/ 18 |  0 |   37 | ########################################
CURVE 11 | 120 | 1000 | QUIET |   6/ 18 |  0 |   37 | ########################################
CURVE 11 | 121 | 1000 | QUIET |   6/ 18 |  0 |   37 | ########################################
CURVE 11 | 122 | 1000 | QUIET |   6/ 18 |  1 |   37 | ########################################
CURVE 11 | 123 | 1000 | QUIET |   5/ 18 |  1 |   38 | ########################################
CURVE 11 | 124 | 1000 | QUIET |   4/ 18 |  0 |   39 | ########################################
CURVE 11 | 125 | 1000 | QUIET |   4/ 18 |  1 |   39 | ########################################
CURVE 11 | 126 | 1000 | QUIET |   4/ 18 |  0 |   39 | ########################################
CURVE 11 | 127 | 1000 | QUIET |   4/ 18 |  0 |   39 | ########################################
CURVE 11 | 128 | 1000 | QUIET |   4/ 18 |  0 |   39 | ########################################
CURVE 11 | 129 |  450 | BUILD |   6/ 18 |  0 |   39 | ##################
CURVE 11 | 130 |  450 | BUILD |   8/ 18 |  0 |   39 | ##################
CURVE 11 | 131 |  450 | BUILD |  11/ 18 |  0 |   39 | ##################
CURVE 11 | 132 |  467 | BUILD |  14/ 18 |  1 |   39 | ##################
CURVE 11 | 133 |  535 | BUILD |  15/ 18 |  0 |   40 | #####################
CURVE 11 | 134 |  535 | BUILD |  18/ 18 |  0 |   40 | #####################
CURVE 11 | 135 |  528 | BUILD |  18/ 18 |  0 |   40 | #####################
CURVE 11 | 136 |  468 | BUILD |  18/ 18 |  0 |   40 | ##################
CURVE 11 | 137 |  408 | BUILD |  18/ 18 |  0 |   40 | ################
CURVE 11 | 138 |  348 | BUILD |  18/ 18 |  0 |   40 | #############
CURVE 11 | 139 |  288 | BUILD |  18/ 18 |  0 |   40 | ###########
CURVE 11 | 140 |  296 | BUILD |  18/ 18 |  0 |   40 | ###########
CURVE 11 | 141 |  296 | BUILD |  18/ 18 |  0 |   40 | ###########
CURVE 11 | 142 |  250 | BUILD |  18/ 18 |  0 |   40 | ##########
CURVE 11 | 143 |  308 | BUILD |  18/ 18 |  0 |   40 | ############
CURVE 11 | 144 |  428 | BUILD |  18/ 18 |  5 |   40 | #################
CURVE 11 | 145 |  597 | BUILD |  18/ 18 |  2 |   41 | #######################
CURVE 11 | 146 |  621 | BUILD |  18/ 18 |  3 |   41 | ########################
CURVE 11 | 147 |  649 | BUILD |  18/ 18 |  5 |   41 | #########################
CURVE 11 | 148 |  815 | PEAK  |  18/ 18 |  4 |   42 | ################################
CURVE 11 | 149 |  959 | PEAK  |  18/ 18 |  5 |   42 | ######################################
CURVE 11 | 150 | 1000 | PEAK  |  18/ 18 |  4 |   42 | ########################################
CURVE 11 | 151 | 1000 | PEAK  |  18/ 18 |  1 |   42 | ########################################
CURVE 11 | 152 | 1000 | PULL  |  18/ 18 |  1 |   43 | ########################################
CURVE 11 | 153 | 1000 | PULL  |  16/ 18 |  4 |   45 | ########################################
CURVE 11 | 154 | 1000 | PULL  |  16/ 18 |  3 |   45 | ########################################
CURVE 11 | 155 | 1000 | PULL  |  16/ 18 |  2 |   45 | ########################################
CURVE 11 | 156 | 1000 | PULL  |  16/ 18 |  5 |   45 | ########################################
CURVE 11 | 157 | 1000 | QUIET |  12/ 18 |  1 |   49 | ########################################
CURVE 11 | 158 | 1000 | QUIET |  12/ 18 |  3 |   49 | ########################################
CURVE 11 | 159 | 1000 | QUIET |  10/ 18 |  0 |   51 | ########################################
CURVE 11 | 160 | 1000 | QUIET |  10/ 18 |  1 |   51 | ########################################
CURVE 11 | 161 | 1000 | QUIET |   9/ 18 |  1 |   52 | ########################################
CURVE 11 | 162 | 1000 | QUIET |   9/ 18 |  1 |   52 | ########################################
CURVE 11 | 163 | 1000 | QUIET |   9/ 18 |  1 |   52 | ########################################
CURVE 11 | 164 | 1000 | QUIET |   8/ 18 |  0 |   53 | ########################################
CURVE 11 | 165 | 1000 | QUIET |   8/ 18 |  0 |   53 | ########################################
CURVE 11 | 166 | 1000 | QUIET |   8/ 18 |  0 |   53 | ########################################
CURVE 11 | 167 | 1000 | QUIET |   8/ 18 |  0 |   53 | ########################################
CURVE 11 | 168 | 1000 | QUIET |   8/ 18 |  0 |   53 | ########################################
CURVE 11 | 169 | 1000 | QUIET |   8/ 18 |  1 |   53 | ########################################
CURVE 11 | 170 | 1000 | QUIET |   8/ 18 |  0 |   53 | ########################################
CURVE 11 | 171 | 1000 | QUIET |   8/ 18 |  0 |   53 | ########################################
CURVE 11 | 172 | 1000 | QUIET |   8/ 18 |  0 |   53 | ########################################
CURVE 11 | 173 |  963 | QUIET |   8/ 18 |  0 |   53 | ######################################
CURVE 11 | 174 | 1000 | QUIET |   8/ 18 |  1 |   53 | ########################################
CURVE 11 | 175 | 1000 | QUIET |   7/ 18 |  0 |   54 | ########################################
CURVE 11 | 176 | 1000 | QUIET |   7/ 18 |  0 |   54 | ########################################
CURVE 11 | 177 | 1000 | QUIET |   7/ 18 |  2 |   54 | ########################################
CURVE 11 | 178 | 1000 | QUIET |   7/ 18 |  0 |   54 | ########################################
CURVE 11 | 179 |  400 | BUILD |   9/ 18 |  0 |   54 | ################
CURVE 11 | 180 |  440 | BUILD |  11/ 18 |  0 |   54 | #################
CURVE 11 | 181 |  490 | BUILD |  12/ 18 |  0 |   54 | ###################
CURVE 11 | 182 |  511 | BUILD |  15/ 18 |  1 |   54 | ####################
CURVE 11 | 183 |  555 | BUILD |  17/ 18 |  1 |   55 | ######################
CURVE 11 | 184 |  596 | BUILD |  18/ 18 |  0 |   55 | #######################
CURVE 11 | 185 |  596 | BUILD |  18/ 18 |  0 |   55 | #######################
CURVE 11 | 186 |  592 | BUILD |  18/ 18 |  1 |   55 | #######################
CURVE 11 | 187 |  643 | BUILD |  18/ 18 |  1 |   56 | #########################
CURVE 11 | 188 |  789 | PEAK  |  18/ 18 |  1 |   56 | ###############################
CURVE 11 | 189 |  853 | PEAK  |  18/ 18 |  1 |   56 | ##################################
CURVE 11 | 190 |  914 | PEAK  |  18/ 18 |  3 |   56 | ####################################
CURVE 11 | 191 | 1000 | PEAK  |  18/ 18 |  2 |   56 | ########################################
CURVE 11 | 192 | 1000 | PEAK  |  18/ 18 |  2 |   56 | ########################################
CURVE 11 | 193 | 1000 | PEAK  |  20/ 18 |  5 |   57 | ########################################
CURVE 11 | 194 | 1000 | PULL  |  20/ 18 |  4 |   57 | ########################################
CURVE 11 | 195 | 1000 | PULL  |  16/ 18 |  1 |   61 | ########################################
CURVE 11 | 196 | 1000 | PULL  |  15/ 18 |  2 |   62 | ########################################
CURVE 11 | 197 | 1000 | PULL  |  13/ 18 |  2 |   64 | ########################################
CURVE 11 | 198 | 1000 | PULL  |  13/ 18 |  1 |   64 | ########################################
CURVE 11 | 199 | 1000 | QUIET |  13/ 18 |  1 |   64 | ########################################
CURVE 11 | 200 | 1000 | QUIET |  13/ 18 |  1 |   64 | ########################################
CURVE 11 | 201 | 1000 | QUIET |  12/ 18 |  1 |   65 | ########################################
CURVE 11 | 202 | 1000 | QUIET |  12/ 18 |  3 |   65 | ########################################
CURVE 11 | 203 | 1000 | QUIET |  10/ 18 |  1 |   67 | ########################################
CURVE 11 | 204 | 1000 | QUIET |  10/ 18 |  1 |   67 | ########################################
CURVE 11 | 205 | 1000 | QUIET |   9/ 18 |  0 |   68 | ########################################
CURVE 11 | 206 | 1000 | QUIET |   9/ 18 |  1 |   68 | ########################################
CURVE 11 | 207 | 1000 | QUIET |   8/ 18 |  0 |   69 | ########################################
CURVE 11 | 208 | 1000 | QUIET |   8/ 18 |  0 |   69 | ########################################
CURVE 11 | 209 | 1000 | QUIET |   8/ 18 |  1 |   69 | ########################################
CURVE 11 | 210 | 1000 | QUIET |   8/ 18 |  0 |   69 | ########################################
CURVE 11 | 211 | 1000 | QUIET |   7/ 18 |  2 |   70 | ########################################
CURVE 11 | 212 | 1000 | QUIET |   6/ 18 |  2 |   71 | ########################################
CURVE 11 | 213 | 1000 | QUIET |   6/ 18 |  0 |   71 | ########################################
CURVE 11 | 214 | 1000 | QUIET |   6/ 18 |  0 |   71 | ########################################
CURVE 11 | 215 | 1000 | QUIET |   6/ 18 |  4 |   71 | ########################################
CURVE 11 | 216 | 1000 | QUIET |   5/ 18 |  0 |   72 | ########################################
CURVE 11 | 217 | 1000 | QUIET |   5/ 18 |  0 |   72 | ########################################
CURVE 11 | 218 | 1000 | QUIET |   5/ 18 |  1 |   72 | ########################################
CURVE 11 | 219 | 1000 | QUIET |   5/ 18 |  0 |   72 | ########################################
CURVE 11 | 220 | 1000 | QUIET |   5/ 18 |  0 |   72 | ########################################
CURVE 11 | 221 |  401 | BUILD |   7/ 18 |  0 |   72 | ################
CURVE 11 | 222 |  401 | BUILD |  10/ 18 |  0 |   72 | ################
CURVE 11 | 223 |  388 | BUILD |  12/ 18 |  0 |   72 | ###############
CURVE 11 | 224 |  409 | BUILD |  15/ 18 |  0 |   72 | ################
CURVE 11 | 225 |  469 | BUILD |  18/ 18 |  0 |   72 | ##################
CURVE 11 | 226 |  515 | BUILD |  18/ 18 |  2 |   72 | ####################
CURVE 11 | 227 |  540 | BUILD |  18/ 18 |  0 |   72 | #####################
CURVE 11 | 228 |  600 | BUILD |  18/ 18 |  0 |   72 | ########################
CURVE 11 | 229 |  694 | BUILD |  17/ 18 |  0 |   74 | ###########################
CURVE 11 | 230 |  704 | BUILD |  18/ 18 |  1 |   74 | ############################
CURVE 11 | 231 |  819 | PEAK  |  18/ 18 |  1 |   74 | ################################
CURVE 11 | 232 |  844 | PEAK  |  18/ 18 |  3 |   74 | #################################
CURVE 11 | 233 |  958 | PEAK  |  17/ 18 |  1 |   76 | ######################################
CURVE 11 | 234 |  999 | PEAK  |  16/ 18 |  1 |   77 | #######################################
CURVE 11 | 235 | 1000 | PEAK  |  17/ 18 |  2 |   78 | ########################################
CURVE 11 | 236 | 1000 | PULL  |  18/ 18 |  2 |   78 | ########################################
CURVE 11 | 237 | 1000 | PULL  |  16/ 18 |  0 |   80 | ########################################
CURVE 11 | 238 | 1000 | PULL  |  15/ 18 |  3 |   81 | ########################################
CURVE 11 | 239 | 1000 | PULL  |  14/ 18 |  0 |   82 | ########################################
CURVE 11 | 240 | 1000 | PULL  |  14/ 18 |  1 |   82 | ########################################
CURVE 11 | 241 | 1000 | QUIET |  13/ 18 |  1 |   83 | ########################################
CURVE 11 | 242 | 1000 | QUIET |  13/ 18 |  1 |   83 | ########################################
CURVE 11 | 243 | 1000 | QUIET |  13/ 18 |  0 |   83 | ########################################
CURVE 11 | 244 | 1000 | QUIET |  13/ 18 |  1 |   83 | ########################################
CURVE 11 | 245 | 1000 | QUIET |  13/ 18 |  3 |   83 | ########################################
CURVE 11 | 246 | 1000 | QUIET |  13/ 18 |  3 |   83 | ########################################
CURVE 11 | 247 | 1000 | QUIET |  14/ 18 |  4 |   84 | ########################################
CURVE 11 | 248 | 1000 | QUIET |  14/ 18 |  3 |   84 | ########################################
CURVE 11 | 249 | 1000 | QUIET |  13/ 18 |  2 |   85 | ########################################
CURVE 11 | 250 | 1000 | QUIET |  12/ 18 |  3 |   86 | ########################################
CURVE 11 | 251 | 1000 | QUIET |  11/ 18 |  0 |   87 | ########################################
CURVE 11 | 252 | 1000 | QUIET |   9/ 18 |  3 |   89 | ########################################
CURVE 11 | 253 | 1000 | QUIET |   7/ 18 |  0 |   91 | ########################################
CURVE 11 | 254 | 1000 | QUIET |   6/ 18 |  0 |   92 | ########################################
CURVE 11 | 255 | 1000 | QUIET |   6/ 18 |  0 |   92 | ########################################
CURVE 11 | 256 | 1000 | QUIET |   6/ 18 |  2 |   92 | ########################################
CURVE 11 | 257 | 1000 | QUIET |   5/ 18 |  0 |   93 | ########################################
CURVE 11 | 258 | 1000 | QUIET |   5/ 18 |  0 |   93 | ########################################
CURVE 11 | 259 | 1000 | QUIET |   5/ 18 |  0 |   93 | ########################################
CURVE 11 | 260 | 1000 | QUIET |   5/ 18 |  0 |   93 | ########################################
CURVE 11 | 261 | 1000 | QUIET |   5/ 18 |  2 |   93 | ########################################
CURVE 11 | 262 | 1000 | QUIET |   4/ 18 |  1 |   94 | ########################################
CURVE 11 | 263 | 1000 | QUIET |   3/ 18 |  1 |   95 | ########################################
CURVE 11 | 264 |  400 | BUILD |   6/ 18 |  0 |   95 | ################
CURVE 11 | 265 |  400 | BUILD |   9/ 18 |  0 |   95 | ################
CURVE 11 | 266 |  435 | BUILD |  11/ 18 |  0 |   95 | #################
CURVE 11 | 267 |  439 | BUILD |  14/ 18 |  0 |   95 | #################
CURVE 11 | 268 |  504 | BUILD |  16/ 18 |  0 |   95 | ####################
CURVE 11 | 269 |  504 | BUILD |  18/ 18 |  0 |   95 | ####################
CURVE 11 | 270 |  611 | BUILD |  18/ 18 |  2 |   95 | ########################
CURVE 11 | 271 |  659 | BUILD |  18/ 18 |  2 |   96 | ##########################
CURVE 11 | 272 |  688 | BUILD |  18/ 18 |  2 |   96 | ###########################
CURVE 11 | 273 |  739 | BUILD |  18/ 18 |  1 |   97 | #############################
CURVE 11 | 274 |  761 | PEAK  |  18/ 18 |  1 |   97 | ##############################
CURVE 11 | 275 |  865 | PEAK  |  18/ 18 |  0 |   98 | ##################################
CURVE 11 | 276 |  895 | PEAK  |  17/ 18 |  0 |   99 | ###################################
CURVE 11 | 277 |  947 | PULL  |  17/ 18 |  0 |   99 | #####################################
CURVE 11 | 278 |  947 | PULL  |  17/ 18 |  0 |   99 | #####################################
CURVE 11 | 279 | 1000 | PULL  |  17/ 18 |  0 |   99 | ########################################
CURVE 11 | 280 | 1000 | PULL  |  17/ 18 |  1 |   99 | ########################################
CURVE 11 | 281 | 1000 | QUIET |  17/ 18 |  2 |   99 | ########################################
CURVE 11 | 282 | 1000 | QUIET |  17/ 18 |  1 |   99 | ########################################
CURVE 11 | 283 | 1000 | QUIET |  17/ 18 |  2 |   99 | ########################################
CURVE 11 | 284 | 1000 | QUIET |  17/ 18 |  4 |   99 | ########################################
CURVE 11 | 285 | 1000 | QUIET |  17/ 18 |  4 |   99 | ########################################
CURVE 11 | 286 | 1000 | QUIET |  15/ 18 |  3 |  101 | ########################################
CURVE 11 | 287 | 1000 | QUIET |  13/ 18 |  4 |  103 | ########################################
CURVE 11 | 288 | 1000 | QUIET |  13/ 18 |  6 |  103 | ########################################
CURVE 11 | 289 | 1000 | QUIET |  10/ 18 |  3 |  106 | ########################################
CURVE 11 | 290 | 1000 | QUIET |   7/ 18 |  0 |  109 | ########################################
CURVE 11 | 291 | 1000 | QUIET |   7/ 18 |  0 |  109 | ########################################
CURVE 11 | 292 | 1000 | QUIET |   7/ 18 |  0 |  109 | ########################################
CURVE 11 | 293 | 1000 | QUIET |   6/ 18 |  0 |  110 | ########################################
CURVE 11 | 294 | 1000 | QUIET |   6/ 18 |  0 |  110 | ########################################
CURVE 11 | 295 | 1000 | QUIET |   6/ 18 |  0 |  110 | ########################################
CURVE 11 | 296 | 1000 | QUIET |   6/ 18 |  0 |  110 | ########################################
CURVE 11 | 297 | 1000 | QUIET |   6/ 18 |  0 |  110 | ########################################
CURVE 11 | 298 | 1000 | QUIET |   6/ 18 |  0 |  110 | ########################################
CURVE 11 | 299 | 1000 | QUIET |   6/ 18 |  0 |  110 | ########################################
CURVE 11 | 300 | 1000 | QUIET |   6/ 18 |  0 |  110 | ########################################
SEED 11 | peaks at s [56.9, 96.8, 147.4, 187.3, 230.9, 273.4] | quiet lengths s [20.0, 20.0, 20.0, 20.0, 20.0] | no-pack gaps s [13.3, 26.5, 24.9, 40.5, 24.6, 14.9] | kills/min on 22.0 off 23.8 (-7.6 %)
SEED 11 | on: kills 110, heals 11, director ticks 16271/18000 | off: kills 119, heals 12
SEED 12 | peaks at s [54.9, 92.3, 131.9, 169.4, 210.3, 250.1, 286.9] | quiet lengths s [20.0, 20.0, 20.0, 20.0, 20.0, 20.0] | no-pack gaps s [30.1, 26.2, 24.1, 25.4, 31.6, 15.8] | kills/min on 23.4 off 38.0 (-38.4 %)
SEED 12 | on: kills 117, heals 12, director ticks 16353/18000 | off: kills 190, heals 11
SEED 13 | peaks at s [63.8, 100.2, 136.9, 177.6, 208.0, 247.3, 291.9] | quiet lengths s [20.0, 20.0, 20.0, 20.0, 20.0, 20.0] | no-pack gaps s [10.3, 22.9, 14.0, 32.3, 19.4, 13.4, 34.9, 12.3] | kills/min on 23.0 off 27.8 (-17.3 %)
SEED 13 | on: kills 115, heals 11, director ticks 16202/18000 | off: kills 139, heals 14
SEED 14 | peaks at s [40.0, 79.3, 116.1, 156.2, 196.6, 237.9, 276.6] | quiet lengths s [20.0, 20.0, 20.0, 20.0, 20.0, 20.0] | no-pack gaps s [12.0, 21.5, 10.7, 11.4, 19.6, 28.8, 25.7, 33.2] | kills/min on 24.8 off 30.6 (-19.0 %)
SEED 14 | on: kills 124, heals 11, director ticks 16167/18000 | off: kills 153, heals 13
SEED 15 | peaks at s [67.0, 102.7, 137.8, 172.9, 210.6, 249.3, 288.3] | quiet lengths s [20.0, 20.0, 20.0, 20.0, 20.0, 20.0] | no-pack gaps s [15.9, 12.4, 12.3, 24.6, 22.9, 21.9, 28.1, 33.7, 28.4] | kills/min on 23.4 off 27.8 (-15.8 %)
SEED 15 | on: kills 117, heals 10, director ticks 16325/18000 | off: kills 139, heals 12
MEAN kills/min on 23.3 off 29.6 (-21.2 %)
```

</details>

## Tests

Run on the same uncommitted worktree (on `57bbaff`). No full suite, no bot tests (owner rule).

```
gdformat --check src scripts tests && gdlint src scripts tests
981 files would be left unchanged
Success: no problems found

bash scripts/ci/gut_shard.sh --check
gut_shard: ok (353 test files in 6 shards)

godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/sim/test_intensity_director.gd -gexit
Tests                20
Passing Tests        20
Asserts             140
```

The folders and e2e this step reaches, in one GUT run (`-gdir=res://tests/content,res://tests/arch,res://tests/golden,
res://tests/unit/application,res://tests/unit/app,res://tests/unit/debug -ginclude_subdirs -gtest=` the files below):
`tests/unit/sim/` `test_intensity_director`, `test_spawn_director`, `test_difficulty_curve`, `test_world_snapshot`,
`test_world_walls`, `test_arenas`, `test_overrun`, `test_catch_up`, `test_horde`, `test_horde_enemies`; `tests/e2e/`
`test_e2e_run_flow`, `test_e2e_saves`, `test_e2e_old_save`, `test_e2e_horde_enemies`, `test_e2e_enemies`,
`test_e2e_difficulty_curve`, `test_e2e_dev_panel`, `test_e2e_dev_master_panel`, `test_e2e_dev_live_balance`,
`test_e2e_damage_soak`.

```
Totals
------
Warnings              1

Scripts              68
Tests               401
Passing Tests       401
Asserts           75909
Time              1091.803s

---- All tests passed! ----

bash scripts/ci/check_gut_log.sh build/n5_tests.log build/n5_min.txt
check_gut_log: ok (401 passing, minimum 1)
```

The one warning is `RunSaveStore`'s own corrupt-file test (`test_a_corrupt_file_is_ignored_and_kept`), as designed.
`tests/golden` (in that run) passed unchanged: no golden fixture changed.

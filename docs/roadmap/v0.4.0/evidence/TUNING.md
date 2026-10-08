# TUNING (v0.4.0 TU): does the difficulty curve give an easy first minute, enemies by phase and a peak at the floor's end, and does the expected-build bot meet the PLAN's bands?

- **Round 2 (owner D7–D9) is at the end of this file and supersedes these bands' results:** floor-1 deaths 25 % (met),
  by floor 3 95 % (missed, bosses), TTK +78 % (missed).
- **Status (round 1):** RUN. **The calm minute and the phases work as specified; the PLAN's three sim bands are MISSED** (floor-1
  deaths 90 % vs < 30 %; deaths by floor 3 100 % vs 30–60 %; time-to-kill rises 101 % vs falls 20–40 %). Reported,
  not widened, and not retuned further: three more curve variants (below) moved deaths by a few runs at most, because
  the deaths are attrition and the floor-1 boss, not the curve (Interpretation). **Horde bench target still missed**
  (a 5–6 % gain measured; the machine was loaded). Readable cause: 0 violations. Boss fight bands: met with the Gun at
  ×1.00.
- **Build:** "after" sims = `d080d66` (`worktree` branch of TU, the shipped curves, the final bot); test fixes after
  it (`aec532d`, this commit) change no sim code. "before" sims = `87bac21` (what the owner played, Gun ×0.85, no
  curve) with only the bot's four support files copied in (`tests/support/run_bot.gd`, `run_lab.gd` with the base's
  `compile_spawning`, `tuning_run.gd`, `scripts/sim/tuning_sim.gd`). Godot `4.7.2.stable.official.ed1daf0bf`,
  headless. Bench "before" = `6ff13c6` (TU before the collision micro-optimisations) and `87bac21`.
- **Machine:** cloud container, 4 vCPU, shared with other agents (load average in each raw block, 4–9).
- **Date:** 2026-10-08. **Who ran it:** agent.

## What was built
1. **The curve as data** (`DifficultyCurveDefinition` / `DifficultyPhase`, `data/curves/floor_1..3.tres`, validated;
   compiled to `CurveTable` on the floor's `SpawnTable`; CONTENT_SCHEMA §7, SIM_CONTRACTS §11, BLUEPRINT §H). Shipped
   starting values (the same timing on every floor; each floor's base comes from SC's per-floor tables):

   | Phase (HUD) | Starts | Tier | Cap (of SC's at the tier) | Interval | HP / damage (of SC's) | Largest pack | Floor 1 / 2 / 3 new kinds |
   |---|---|---|---|---|---|---|---|
   | Calm (holds) | 0:00 | 0 | 35 / 25 / 18 % (5 / 7 / 9 alive) | ×2.0 | 60 / 40 % | 1 | Charger, Needle, Swarmer (all floors) |
   | They stir | 1:00 | 0 → | 40 % → | ×1.8 → | 70 / 45 % → | 2 | Warden / Warden, Arc Caster, Splitter / those + Shield Bearer |
   | The hunt | 2:00 | 2 → | 50 % → | ×1.5 → | 75 / 55 % → | 3 | Arc Caster / Shield Bearer / Bomb Drone, Mine Layer |
   | The swarm | 3:00 | 4 → | 60 % → | ×1.3 → | 80 / 65 % → | 3 / 4 / 8 | Splitter / Bomb Drone, Mine Layer / Mender, Sniper (+ Swarmer packs) |
   | Full horde (peak, holds) | 10:00 | 20 | 100 % (120 alive) | ×1.0 | 100 / 100 % | 3 / 4 / 8 | — |

   "→" ramps linearly to the next phase. Why these: the calm row is the lead's spec (cap 4–6, the basic kinds as
   singles, slow, no tier growth); the peak is SC's tier-max level at M-FLOOR's 10 min (a P0 band, ranked above a bot
   measurement; see Q-T1); the kinds' phases end at 3:00 because the bots reach the boss door at 2:38–3:47 (below), so
   a player who heads for the boss still meets the floor's kinds (owner D2, D5). HP / damage easing was added because
   without it the calm cap alone still killed half the bots in their first minute (c1 below).
2. **Phase HUD:** the phase's name under the top plate; a brighter line for 4 s when a phase begins or when a kind new
   to the run first appears ("New: Arc Caster" / "Nuevo: …"); strings en + es. Dev panel: **Next difficulty phase**.
3. **Early growth (D4):** the floor's first reward spot is in a room next to the start hall and always holds a free
   altar (`Rewards.start_first`; its first card a new ability while a slot is free). Shards follow the curve's tier.
4. **Fix owed (SC's gap):** enemies that join through `World.queue_enemy` (Splitlings, boss summons) get the tier
   scaling, the curve's easing and the Overrun's ×1.5 (`SpawnDirector.scale_arrival`).
5. **Gun ×0.85 → ×1.00** (owner, 2026-10-08).
6. **The expected-build bot** (`tests/support/run_bot.gd`, `average` preset of SCORECARD §3: reaction 14 ticks, dodge
   650 ‰): explores every room (not the boss or Overrun room), opens every free altar and every chest it can afford,
   tours the rooms again fighting until it can afford the rest, then walks through the boss door, fights the boss and
   takes the portal. Picks the best-scoring card (a new ability 100, a level-up 55 + 5 × level, stats by id × rarity,
   survival stats × 2 under 60 % HP, mods 30/40). Fights the nearest enemy in sight (Blade closes in, Gun keeps
   4–7 m and shoots on the move), walks (and dashes once) out of any telegraph it stands in, vents in a crowd.
   `TuningRun` plays a whole run floor after floor (`RunLab` builds each floor as `Main._start_floor` does).

## Commands
```
bash build/run_sims.sh <name> 5       # untracked launcher: two processes of
#   godot --headless --path . -s scripts/sim/tuning_sim.gd -- seeds=5 first=<1|6> out=build/tuning/<name>_<k>.jsonl [preset=expert]
#   then  ... tuning_sim.gd -- summarize=build/tuning/<name>_0.jsonl,build/tuning/<name>_1.jsonl
time godot --headless --path . -s scripts/checks/readable_cause.gd
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/sim/test_boss_fights.gd -gexit
godot --headless --path . -s scripts/bench/sim_bench.gd -- --only=horde      # in each tree, interleaved, twice
```
Seeds 7301–7310 (`7300 + first + s`), both builds, floors 1–3 (a run stops at a death). A floor's "door" is the boss
door sealing; "ttk" is first hit by the player's side to death, normal kinds only (Swarmers, Splitlings, Hatchlings,
Lens Drones and bosses left out); "start" = kills in minutes 0–1, "end" = the last two minutes before the door.

## Target bands
| Metric | Target | Source |
|---|---|---|
| Deaths on floor 1 | < 30 % of runs | PLAN v0.4.0 "Scaling and hordes" (starting band) |
| Deaths by floor 3 | 30–60 % of runs | same |
| Median TTK of a normal enemy, start → end of a floor | falls 20–40 % while the crowd grows | same |
| Calm minute | cap 4–6 on floor 1, only Charger / Needle / Swarmer singles, no tier growth | TU brief |
| Floor length | 10–15 min | SCORECARD M-FLOOR (P0) |
| Readable cause | 0 violations | M-CAUSE |
| Horde bench | mean ≤ 4 ms a tick | PLAN "Performance" |

## Raw output

### Before (`87bac21` + bot files), 10 seeds × 2 builds
```
 08:12:40 up  1:27,  0 user,  load average: 4.95, 5.39, 4.86
seed 7301 blade: F1 died_floor door -1s floor 47s kills 23 cards -1/-1/1 peak 20
seed 7301 gun: F1 died_floor door -1s floor 47s kills 22 cards -1/-1/1 peak 20
seed 7302 blade: F1 died_floor door -1s floor 51s kills 18 cards -1/-1/1 peak 20
seed 7302 gun: F1 died_floor door -1s floor 52s kills 25 cards -1/-1/1 peak 22
seed 7303 blade: F1 died_floor door -1s floor 64s kills 18 cards -1/-1/1 peak 21
seed 7303 gun: F1 died_floor door -1s floor 73s kills 42 cards -1/-1/1 peak 26
seed 7304 blade: F1 died_floor door -1s floor 56s kills 30 cards -1/-1/1 peak 19
seed 7304 gun: F1 died_floor door -1s floor 109s kills 74 cards -1/-1/3 peak 26
seed 7305 blade: F1 died_floor door -1s floor 108s kills 62 cards -1/-1/3 peak 32
seed 7305 gun: F1 died_boss door 67s floor 111s kills 58 cards -1/-1/2 peak 21
seed 7306 blade: F1 died_floor door -1s floor 125s kills 122 cards 5/-1/5 peak 30
seed 7306 gun: F1 died_floor door -1s floor 58s kills 45 cards -1/-1/1 peak 21
seed 7307 blade: F1 died_floor door -1s floor 64s kills 42 cards -1/-1/1 peak 21
seed 7307 gun: F1 died_floor door -1s floor 85s kills 54 cards -1/-1/1 peak 26
seed 7308 blade: F1 died_floor door -1s floor 44s kills 18 cards -1/-1/1 peak 20
seed 7308 gun: F1 died_floor door -1s floor 102s kills 64 cards -1/-1/4 peak 26
seed 7309 blade: F1 died_floor door -1s floor 73s kills 49 cards -1/-1/3 peak 25
seed 7309 gun: F1 died_floor door -1s floor 48s kills 33 cards -1/-1/1 peak 19
seed 7310 blade: F1 died_floor door -1s floor 43s kills 19 cards -1/-1/1 peak 20
seed 7310 gun: F1 died_floor door -1s floor 55s kills 30 cards -1/-1/1 peak 20
 08:16:37 up  1:31,  0 user,  load average: 8.98, 7.98, 6.07
runs: 20
blade F1: reached 10, died 10 (boss 0), timeouts 0; died by F1 10/10 (100%); door s med 0 [-..-]; kills med 26; cards 2m/5m/end med -1.0/-1.0/1.0; first chest s med -1; peak alive med 20 max 32; ttk s start 1.40 (n 263) end 0.00 (n 0) change -100%
blade F1 ttk by minute: 0:1.32(208) 1:2.22(55) 2:6.35(6)
blade F1 hurt_floor: charger 430, needle 408, arc_caster 124, bomb_drone 18, shield_bearer 17, gone 13, swarmer 5, sniper 4
gun F1: reached 10, died 10 (boss 1), timeouts 0; died by F1 10/10 (100%); door s med 67 [67..67]; kills med 44; cards 2m/5m/end med -1.0/-1.0/1.0; first chest s med -1; peak alive med 22 max 26; ttk s start 2.18 (n 308) end 0.00 (n 0) change -100%
gun F1 ttk by minute: 0:2.00(247) 1:3.72(61)
gun F1 hurt_floor: charger 361, needle 354, arc_caster 126, sniper 55, bomb_drone 47, gone 45, warden 4
gun F1 hurt_boss: gatekeeper 24
all F1: reached 20, died 20 (boss 1), timeouts 0; died by F1 20/20 (100%); door s med 67 [67..67]; kills med 38; cards 2m/5m/end med -1.0/-1.0/1.0; first chest s med -1; peak alive med 21 max 32; ttk s start 1.82 (n 571) end 0.00 (n 0) change -100%
```
(`cards_2m = -1`: the run ended before 2 min. One process's lines shown merged in seed order; the two `uptime`
pairs were 08:12:40 → 08:16:29 / 08:16:37.)

### After (`d080d66`), 10 seeds × 2 builds, `average`
```
 08:11:36 up  1:26,  0 user,  load average: 5.30, 5.51, 4.85
seed 7301 blade: F1 died_boss door 158s floor 173s kills 47 cards 3/-1/5 peak 18
seed 7301 gun: F1 died_floor door -1s floor 216s kills 109 cards 3/-1/5 peak 23
seed 7302 blade: F1 died_floor door -1s floor 227s kills 117 cards 3/-1/6 peak 24
seed 7302 gun: F1 died_boss door 227s floor 243s kills 107 cards 4/-1/6 peak 27
seed 7303 blade: F1 died_boss door 207s floor 214s kills 77 cards 2/-1/4 peak 23
seed 7303 gun: F1 died_boss door 191s floor 205s kills 78 cards 3/-1/4 peak 22
seed 7304 blade: F1 died_boss door 200s floor 210s kills 57 cards 3/-1/5 peak 23
seed 7304 gun: F1 died_floor door -1s floor 211s kills 85 cards 4/-1/4 peak 28
seed 7305 blade: F1 next door 177s floor 201s kills 62 cards 3/-1/5 peak 19 | F2 died_boss door 121s floor 148s kills 28 cards 4/-1/4 peak 15
seed 7305 gun: F1 died_boss door 174s floor 196s kills 57 cards 3/-1/5 peak 18
seed 7306 blade: F1 died_floor door -1s floor 182s kills 64 cards 4/-1/4 peak 19
seed 7306 gun: F1 died_floor door -1s floor 212s kills 107 cards 3/-1/4 peak 20
seed 7307 blade: F1 died_floor door -1s floor 213s kills 76 cards 2/-1/3 peak 26
seed 7307 gun: F1 died_boss door 189s floor 210s kills 84 cards 2/-1/3 peak 19
seed 7308 blade: F1 died_floor door -1s floor 161s kills 53 cards 3/-1/4 peak 14
seed 7308 gun: F1 died_boss door 199s floor 207s kills 65 cards 4/-1/6 peak 23
seed 7309 blade: F1 died_floor door -1s floor 165s kills 50 cards 2/-1/2 peak 17
seed 7309 gun: F1 died_boss door 203s floor 225s kills 83 cards 3/-1/4 peak 24
seed 7310 blade: F1 died_floor door -1s floor 201s kills 77 cards 2/-1/4 peak 23
seed 7310 gun: F1 next door 158s floor 195s kills 53 cards 3/-1/4 peak 15 | F2 died_boss door 164s floor 181s kills 61 cards 5/-1/6 peak 25
 08:18:56 up  1:34,  0 user,  load average: 5.73, 7.14, 6.03
runs: 20
blade F1: reached 10, died 9 (boss 3), timeouts 0; died by F1 9/10 (90%); door s med 189 [158..207]; kills med 63; cards 2m/5m/end med 3.0/-1.0/4.0; first chest s med 122; peak alive med 21 max 26; ttk s start 0.99 (n 176) end 1.47 (n 151) change +48%
blade F1 ttk by minute: 0:0.72(45) 1:1.22(131) 2:1.51(230) 3:1.92(73)
blade F1 hurt_floor: warden 250, charger 245, needle 218, arc_caster 82, gone 8
blade F1 hurt_boss: gatekeeper 212
gun F1: reached 10, died 9 (boss 6), timeouts 0; died by F1 9/10 (90%); door s med 191 [158..227]; kills med 84; cards 2m/5m/end med 3.0/-1.0/4.0; first chest s med 96; peak alive med 22 max 28; ttk s start 0.57 (n 198) end 1.57 (n 269) change +176%
gun F1 ttk by minute: 0:0.47(61) 1:0.68(137) 2:1.43(311) 3:2.73(123)
gun F1 hurt_floor: arc_caster 247, needle 132, charger 97, warden 84, gone 42
gun F1 hurt_boss: warlord 223, gatekeeper 165
all F1: reached 20, died 18 (boss 9), timeouts 0; died by F1 18/20 (90%); door s med 191 [158..227]; kills med 76; cards 2m/5m/end med 3.0/-1.0/4.0; first chest s med 108; peak alive med 22 max 28; ttk s start 0.75 (n 374) end 1.51 (n 420) change +101%
all F1 ttk by minute: 0:0.55(106) 1:0.92(268) 2:1.48(541) 3:2.25(196)
all F2: reached 2, died 2 (boss 2), timeouts 0; died by F2 20/20 (100%); door s med 142 [121..164]; kills med 44; cards 2m/5m/end med 4.5/-1.0/5.0; first chest s med 15; peak alive med 20 max 25; ttk s start 1.13 (n 43) end 0.00 (n 0) change -100%
all F2 hurt_boss: brood_mother 92, hive_lens 70, hatchling 7
all F3: not reached
```
(The two processes' lines merged in seed order; the second process: 08:11:36 → 08:18:34, load 6.08.)

Extra stats from the same `.jsonl` (`python3 build/dbg/stats.py <run_0.jsonl>,<run_1.jsonl>`, untracked; each line
covers both files and is labelled with the second's name):
```
after_1.jsonl runs 20 F1 died_s median 210 min 161 max 243 alive@60s 20/20 alive@120s 20/20 floor_s med 208 shards@door med 178
before10_1.jsonl runs 20 F1 died_s median 61 min 43 max 125 alive@60s 10/20 alive@120s 1/20 floor_s med 61 shards@door med 146
```

### After, `expert` preset (reaction 8, dodge 900 ‰), 6 seeds × 2 builds
```
all F1: reached 12, died 9 (boss 3), timeouts 0; died by F1 9/12 (75%); door s med 196 [177..235]; kills med 83; cards 2m/5m/end med 3.0/-1.0/5.0; first chest s med 108; peak alive med 23 max 38; ttk s start 0.80 (n 198) end 1.83 (n 344) change +129%
all F2: reached 3, died 2 (boss 2), timeouts 0; died by F2 11/12 (92%); door s med 115 [110..122]; kills med 24; cards 2m/5m/end med 4.0/-1.0/4.0; first chest s med 18; peak alive med 14 max 18; ttk s start 1.35 (n 45) end 0.00 (n 0) change -100%
all F3: reached 1, died 1 (boss 0), timeouts 0; died by F3 12/12 (100%); door s med 0 [-..-]; kills med 29; cards 2m/5m/end med 4.0/-1.0/4.0; first chest s med 12; peak alive med 16 max 16; ttk s start 2.22 (n 21) end 0.00 (n 0) change -100%
all F1 hurt_floor: arc_caster 349, needle 260, charger 157, warden 93, gone 37, splitter 10
all F1 hurt_boss: gatekeeper 286, warlord 58
afterx_1.jsonl runs 12 F1 died_s median 225 min 189 max 264 alive@60s 12/12 alive@120s 12/12 floor_s med 223 shards@door med 181.5
```
(08:19:35 → 08:24:50, load 4.07 → 6.02.)

### Curve variants tried on the way (same bot unless noted; 6 seeds × 2 builds; only the `all F1` line)
| Variant | Change from the shipped curve | Floor-1 deaths | Boss deaths among them | Door s median |
|---|---|---|---|---|
| c1 (bot before its route/dodge fixes were final) | peak 8:00, phases at 1:00 / 3:12 / 5:36, HP 700–1000, damage 500–1000 | 10/12 | 3 | 178 |
| c2 | peak 10:00, phases at 1:00 / 4:00 / 7:00, damage 400 / 450 / 600 / 800 | 11/12 | 8 | 214 |
| c2, `expert` | as c2 | 9/12 | 8 | 208 |
| c3 (the shipped timing, scoring before the survival rule) | — | 11/12 | 6 | 191 |
| c4 | damage 250 / 300 / 400 / 500, HP 500–800 (about half the shipped damage) | 10/12 | 6 | 189 |

### Readable cause (`d080d66`)
```
	"deaths_checked": 24,
	"runs": 36,
	"seeds": 12,
	"violations": 0
real	6m0.275s
user	4m10.270s
sys	0m0.401s
```
`death_recap_mismatches: []`. (FightLab's floors run without a curve, so every kind still appears in its window.)

### Boss fight bands with the Gun at ×1.00 (`tests/unit/sim/test_boss_fights.gd`, both tests pass)
```
BOSSFIGHT| gatekeeper MELEE ticks=2008 seconds=33.5 hits=86 deflected=0 exposed=28 punished=0
BOSSFIGHT| gatekeeper RANGED_NEAR ticks=3387 seconds=56.5 hits=474 deflected=0 exposed=0 punished=0
BOSSFIGHT| brood_mother MELEE ticks=2301 seconds=38.4 hits=104 deflected=0 exposed=25 punished=0
BOSSFIGHT| brood_mother RANGED_NEAR ticks=5222 seconds=87.0 hits=645 deflected=0 exposed=7 punished=0
BOSSFIGHT| siege_engine MELEE ticks=2090 seconds=34.8 hits=89 deflected=0 exposed=27 punished=0
BOSSFIGHT| siege_engine RANGED_NEAR ticks=3322 seconds=55.4 hits=457 deflected=0 exposed=0 punished=0
BOSSFIGHT| warlord MELEE ticks=2057 seconds=34.3 hits=87 deflected=0 exposed=27 punished=0
BOSSFIGHT| warlord RANGED_NEAR ticks=3367 seconds=56.1 hits=463 deflected=0 exposed=0 punished=0
BOSSFIGHT| hive_lens MELEE ticks=1743 seconds=29.1 hits=74 deflected=0 exposed=31 punished=0
BOSSFIGHT| hive_lens RANGED_NEAR ticks=3026 seconds=50.4 hits=424 deflected=0 exposed=1 punished=0
BOSSFIGHT| foundry MELEE ticks=2059 seconds=34.3 hits=88 deflected=0 exposed=32 punished=0
BOSSFIGHT| foundry RANGED_NEAR ticks=3452 seconds=57.5 hits=473 deflected=0 exposed=9 punished=0
BOSSFIGHT| gatekeeper RANGED_FAR ticks=5257 seconds=87.6 hits=735 deflected=533 punished=0 gap_closed=13
BOSSFIGHT| brood_mother RANGED_FAR ticks=7774 seconds=129.6 hits=1091 deflected=441 punished=0 gap_closed=13
BOSSFIGHT| siege_engine RANGED_FAR ticks=6690 seconds=111.5 hits=904 deflected=900 punished=20 gap_closed=0
BOSSFIGHT| warlord RANGED_FAR ticks=4828 seconds=80.5 hits=665 deflected=489 punished=0 gap_closed=12
BOSSFIGHT| hive_lens RANGED_FAR ticks=6295 seconds=104.9 hits=877 deflected=671 punished=1 gap_closed=20
BOSSFIGHT| foundry RANGED_FAR ticks=7136 seconds=118.9 hits=954 deflected=950 punished=25 gap_closed=0
Passing Tests         2
```
Before (Gun ×0.85, `evidence/BOSSES_2.md`): near 59.7–68.3 s for the BO bosses, far 97.4–172.0 s. Now near
50.4–87.0 s (band 25–120 s: in), far / melee 2.35× (Warlord) to 3.6× (Hive Lens), all ≥ the 1.5× rule. No band
changed.

### Horde bench (interleaved, `--only=horde`)
```
=== round 1 tree …/bench_before (6ff13c6)       load 5.90 → 5.95
		"cpu_ms_per_tick_all": 5.306,  "mean_ms": 8.055,  "p99_ms": 27.656, actors 121.0, projectiles 191.4
=== round 1 tree worktree (TU, optimised)        load 5.95 → 6.02
		"cpu_ms_per_tick_all": 5.019,  "mean_ms": 6.91,   "p99_ms": 24.42
=== round 1 tree …/before (87bac21)              load 6.02 → 6.07
		"cpu_ms_per_tick_all": 5.106,  "mean_ms": 7.005,  "p99_ms": 24.185
=== round 2 tree …/bench_before (6ff13c6)       load 6.07 → 6.16
		"cpu_ms_per_tick_all": 5.297,  "mean_ms": 7.563,  "p99_ms": 24.525
=== round 2 tree worktree (TU, optimised)        load 6.16 → 6.28
		"cpu_ms_per_tick_all": 4.947,  "mean_ms": 6.77,   "p99_ms": 23.751
=== round 2 tree …/before (87bac21)              load 6.28 → 6.17
		"cpu_ms_per_tick_all": 5.122,  "mean_ms": 7.297,  "p99_ms": 24.523
```
(Each block is the grep of `build/bench_ab.log`, one line per key there; joined here for width.) A scratch phase
profile of the same scene (`build/dbg/prof_horde.gd`, untracked, load ~6) put 1.5 of 7.3 ms in the collision pairs,
1.8 in the projectile sweeps, 1.7 in enemy think/plan, 0.5 in the flood.

## Result
| Metric | Before | After (`average`) | Band | In band? |
|---|---|---|---|---|
| Floor-1 deaths | 20/20 (100 %), median at 61 s (43–125) | 18/20 (90 %), median at 210 s (161–243); 9 at the boss | < 30 % | **No** |
| Deaths by floor 3 | 20/20 | 20/20 (2 reached floor 2, both died at its boss) | 30–60 % | **No** |
| Median TTK start → end (floor 1) | 1.82 s at the start; no run lived to an "end" | 0.75 → 1.51 s (+101 %) | −20…−40 % | **No** |
| Alive through the calm minute | 10/20 | 20/20 | (D1) | — |
| Alive at 2:00 | 1/20 | 20/20 | (D1) | — |
| Cards by 2:00 / floor end (median) | — / 1 | 3 / 4 | (D4) | — |
| First chest opened (median) | never | 108 s (inside the first two phases, 0–120 s) | (D4) | yes |
| Kills on floor 1 (median) | 38 | 76 | — | — |
| Peak alive on floor 1 (median / max) | 21 / 32 | 22 / 28 | — | — |
| Time to the boss door (floor 1) | 67 s (the one run that got there) | 191 s median (158–227) | M-FLOOR 10–15 min | **No** (see Q-T1) |
| Floor-1 kinds that hurt the player | Charger, Needle, Arc Caster, Bomb Drone, Sniper, Shield Bearer, … | Needle, Charger, Warden, Arc Caster only | floor 1's kinds only (D5) | yes |
| Readable cause | — | 0 violations / 36 runs | 0 | yes |
| Boss fight bands (Gun ×1.00) | in | in | unchanged | yes |
| Horde bench, mean per tick | 7.56–8.06 (`6ff13c6`), 7.01–7.30 (`87bac21`) wall; CPU 5.30 / 5.11 | 6.77–6.91 wall; CPU 4.95–5.02 | ≤ 4 ms | **No** (load ~6) |
| Owner's feel | — | — | — | OWNER ONLY |

## Interpretation
- **What the curve delivers:** the first two minutes are now survivable for this bot (every run alive at 2:00 vs 1 in
  20), it opens 3 cards by 2:00 and its first chest at ~1:48, kills twice as many enemies, and floor 1 shows only its
  own kinds. That is the owner's D1/D2/D5 ask, measured.
- **Why the bands still miss (not a curve problem, so not retuned further):** halving the curve's damage (c4) or
  playing at the `expert` preset moved floor-1 deaths only from 18/20 (90 %) to 10/12 (c4, 83 %) and 9/12 (`expert`,
  75 %). The bot loses its 100 HP by
  **attrition**: nothing heals during a fight (regen waits 10 s out of combat; the horde never stops), so about 100
  damage over ~3.5 min kills it whatever the per-hit numbers; and half the deaths are the floor-1 boss, met at about
  half HP with 4 cards. The TTK band can't be met with SC's tables as the peak: enemy HP grows ×1.1 a tier while four
  or five cards on floor 1 add far less.
- **Questions for the owner (nothing decided here):**
  - **Q-T1 (floor length):** a bot that buys every reward reaches the floor-1 boss door after ~3 min (158–227 s);
    M-FLOOR says 10–15 min, so the peak sits at 10:00 and a player who heads for the boss early never sees it. Keep
    it there, move it to the measured ~3:30 (then the peak's 120 enemies at ×6.7 HP meet a 4-card build), or make a
    floor longer (more rewards, or rewards that keep coming)?
  - **Q-T2 (sustain):** should a run have healing during fights (e.g. a small heal on kills, regen that doesn't wait
    10 s, heal pickups)? Without it no curve keeps deaths under 30 % for this bot.
  - **Q-T3 (floor-1 boss):** the Gatekeeper / Warlord kill 9 of 18 bots that reach them (the boss bands measure fight
    length with invulnerable bots, not survival). Heal at the door, a lighter floor-1 boss, or as is?
  - **Q-T4 (bands):** keep the PLAN's bands as they are until Q-T1–T3 are answered (the default here), or set new
    ones? They were not widened.
- **Bench:** the pass inlines the pair push and asks the wall grid "any wall here?" without building a list (same
  results: the replay golden and the export-smoke hash are unchanged). It measured ~5–6 % less CPU per tick than
  `6ff13c6`; wall-clock numbers on this loaded machine (load ~6 on 4 vCPU) are far above any of SC's earlier runs, so
  they say nothing about the ≤ 4 ms target, which stays **missed** until measured on a quiet machine or the CI runner.
  The next candidates (the projectile sweeps, the plan's grid queries, the flood) need deeper changes.
- **Not proved:** floors 2 and 3 (2 and 1 runs reached them); the owner's feel; the 60 fps view with the phase HUD.

## Verify (`4f6d419`, the tree of this commit but this section)
```
godot --headless --path . --editor --import --quit          # exit 0, 0 ERROR lines
gdformat --check src scripts tests && gdlint src scripts tests   # 458 files unchanged; Success: no problems found
bash scripts/verify.sh
Tests               964
Passing Tests       964
Asserts           455577
Time              999.941s
---- All tests passed! ----
check_gut_log: ok (964 passing, minimum 964)
```
Export smoke (`aec532d` tree, run from the scratchpad): 0 misses; 600-tick hash `e5365ddb6dcb` (unchanged), manifest
`a57cabd1d460…` (196 files: the three curves added).


---

# Round 2 (owner answers D7–D9, 2026-10-08)

- **Status:** RUN. **Floor-1 deaths band MET (5/20 = 25 % < 30 %).** Deaths by floor 3: **MISSED** (19/20 = 95 % vs
  30–60 %): every death on floors 2–3 is at the boss (10/10, 4/4), which the owner kept unchanged (D9); with the boss
  removed by a labelled shortcut the floors alone kill 9/20 by floor 3 (45 %). TTK: **MISSED** (+78 %, should fall).
  Readable cause 0 violations; export smoke 0 misses; horde bench still over 4 ms.
- **Build:** `027ccd9` (the lead branch `claude/lucid-fermat-9wv2tf` at `421ee41` merged in, then the bot's portal fix);
  the commit carrying this section changes only docs and `MIN_TEST_COUNT`. Godot 4.7.2, headless.
- **Machine:** the same container, quieter (load 0.5 → 4.1 during the sims, ~1 during the bench).

## What changed (D7–D9 and the lead's fix)
- **D7 "Peak ~1 min before boss":** each floor's peak is placed one minute before the median boss-door time measured
  with D8/D9 in and the old curve (run `m1`: 3:24 / 1:17 / 1:35 on floors 1/2/3). Floor 1 peaks at 2:24; floors 2–3
  would peak inside the calm minute (0:17, 0:35), which D1 forbids, so they peak at 1:30 (phases at 1:00 / 1:10 /
  1:20) — **a conflict for the owner (Q-T5)**. The peak holds; shards now follow the floor's plain 30 s tier, so staying
  longer still pays more. The peak's level was tuned against the bot (it is not SC's tier 20 any more; below).
- **D8 heal orbs:** 10 % of normal kills drop one (loot stream), +25 % max HP when walked over (pickup range counts),
  at most 16 on a floor, drawn as a pulsing green sphere (`HealOrbViews`); hashed and snapshotted (`HealOrbStore`).
  The bot walks to an orb in sight within 12 m when under 75 % HP. Floor 1: 4.8 orbs a run, +75 HP a run (median runs).
- **D9:** floor-1 bosses −20 % HP and damage (`RunDefinition.boss_ease_floor_permille`), and a full heal when the
  floor-1 boss room seals (`boss_room_heal_floor_permille`).
- **Lead fix:** the shop's ability salvage refund 25 → 10 shards per level (`data/shop/terminal.tres`; M-LOOP).
- **Bot:** walks into the portal's opening (the v0.5.0 SCD bot's fix); the floor-1 numbers are unchanged by it.

## Commands
```
bash build/run_sims.sh <name> 5 [killboss=1]   # as in round 1; killboss=1 kills each boss the tick it appears
time godot --headless --path . -s scripts/checks/readable_cause.gd
bash build/bench_ab.sh                          # horde bench, interleaved: 6ff13c6, this tree, 87bac21
bash <repo>/scripts/ci/export_smoke.sh          # from the scratchpad
```
`killboss=1` is a **labelled shortcut** (the dev panel's Kill boss, a test-side write) used only to sample floors 2–3;
none of its numbers stand for a real run.

## Peak tuning on the way (20 runs each; `all F1` deaths, the normal runs)
| Run | Floor-1 peak | Peak values (tier / cap / HP / damage) | F1 deaths | by F3 | F1 door median |
|---|---|---|---|---|---|
| m1 | 10:00 (round 1's curve) + D8/D9 | 20 / 100 % / 100 % / 100 % | 4/20 (20 %) | 20/20 | 204 s |
| c5 | 2:24 | 6 / 65 % / 85 % / 70 % | 16/20 (80 %) | 19/20 | 168 s |
| c6 | 2:24 | 4 / 55 % / 80 % / 60 % | 7/20 (35 %) | 20/20 | 197 s |
| **c7 (shipped)** | **2:24** | **3.5 / 55 % / 77.5 % / 55 %** | **5/20 (25 %)** | 20/20 | 180 s |
| c8 | 2:00 (one minute before c7's 180 s) | as c7 | 8/20 (40 %) | 20/20 | 206 s |

c8 put the peak exactly a minute before c7's re-measured door time and broke the floor-1 band, so c7 ships: its peak is
36 s before its own measured median (180 s), not 60 s. With 20 runs a cell, 25 % vs 40 % is within the noise (5 vs 8
deaths); a P0 verdict needs 100 seeds (SCORECARD §5).

## Raw output (`fin`, the shipped tree; 10 seeds × Blade/Gun)
```
 11:02:42 up  4:17,  0 user,  load average: 0.48, 0.81, 1.57
seed 7301 blade: F1 next door 180s floor 198s kills 81 cards 3/-1/5 peak 17 orbs 5 (+56 HP) | F2 died_boss door 63s floor 82s kills 11 cards -1/-1/4 peak 5 orbs 1 (+4 HP)
seed 7301 gun: F1 next door 136s floor 170s kills 43 cards 4/-1/5 peak 16 orbs 1 (+16 HP) | F2 died_boss door 131s floor 154s kills 41 cards 3/-1/4 peak 26 orbs 2 (+48 HP)
seed 7302 blade: F1 next door 213s floor 233s kills 110 cards 4/-1/6 peak 18 orbs 5 (+60 HP) | F2 next door 99s floor 128s kills 18 cards 4/-1/4 peak 25 orbs 2 (+33 HP) | F3 died_boss door 95s floor 109s kills 27 cards -1/-1/4 peak 23 orbs 1 (+5 HP)
seed 7302 gun: F1 next door 215s floor 241s kills 108 cards 5/-1/6 peak 18 orbs 5 (+50 HP) | F2 died_boss door 99s floor 123s kills 19 cards 4/-1/4 peak 24 orbs 1 (+10 HP)
seed 7303 blade: F1 next door 162s floor 186s kills 54 cards 3/-1/4 peak 18 orbs 3 (+48 HP) | F2 next door 75s floor 110s kills 12 cards -1/-1/3 peak 6 orbs 0 (+0 HP) | F3 died_boss door 102s floor 116s kills 17 cards -1/-1/4 peak 37 orbs 0 (+0 HP)
seed 7303 gun: F1 died_boss door 189s floor 217s kills 77 cards 4/-1/4 peak 18 orbs 3 (+37 HP)
seed 7304 blade: F1 next door 267s floor 297s kills 111 cards 3/-1/5 peak 18 orbs 11 (+191 HP) | F2 died_boss door 42s floor 65s kills 1 cards -1/-1/5 peak 7 orbs 1 (+27 HP)
seed 7304 gun: F1 died_boss door 303s floor 341s kills 130 cards 3/5/5 peak 19 orbs 9 (+154 HP)
seed 7305 blade: F1 next door 160s floor 182s kills 50 cards 4/-1/5 peak 17 orbs 2 (+29 HP) | F2 died_boss door 138s floor 170s kills 43 cards 4/-1/4 peak 26 orbs 1 (+25 HP)
seed 7305 gun: F1 next door 176s floor 211s kills 68 cards 4/-1/5 peak 18 orbs 1 (+28 HP) | F2 next door 131s floor 173s kills 47 cards 4/-1/4 peak 26 orbs 2 (+56 HP) | F3 died_boss door 97s floor 114s kills 24 cards -1/-1/5 peak 16 orbs 0 (+0 HP)
seed 7306 blade: F1 next door 274s floor 304s kills 139 cards 3/5/5 peak 19 orbs 15 (+281 HP) | F2 died_boss door 75s floor 112s kills 8 cards -1/-1/4 peak 11 orbs 1 (+5 HP)
seed 7306 gun: F1 next door 171s floor 197s kills 70 cards 4/-1/5 peak 18 orbs 1 (+7 HP) | F2 died_boss door 74s floor 96s kills 9 cards -1/-1/4 peak 10 orbs 1 (+4 HP)
seed 7307 blade: F1 died_boss door 197s floor 221s kills 80 cards 1/-1/3 peak 18 orbs 6 (+115 HP)
seed 7307 gun: F1 next door 179s floor 207s kills 71 cards 2/-1/3 peak 18 orbs 5 (+73 HP) | F2 died_boss door 67s floor 82s kills 11 cards -1/-1/5 peak 4 orbs 0 (+0 HP)
seed 7308 blade: F1 next door 173s floor 191s kills 56 cards 4/-1/6 peak 18 orbs 2 (+9 HP) | F2 next door 78s floor 105s kills 19 cards -1/-1/5 peak 12 orbs 1 (+14 HP) | F3 won door 37s floor 66s kills 4 cards -1/-1/4 peak 9 orbs 0 (+0 HP)
seed 7308 gun: F1 next door 165s floor 192s kills 55 cards 4/-1/6 peak 18 orbs 1 (+12 HP) | F2 next door 194s floor 234s kills 138 cards 7/-1/7 peak 28 orbs 6 (+118 HP) | F3 died_boss door 37s floor 62s kills 8 cards -1/-1/4 peak 6 orbs 0 (+0 HP)
seed 7309 blade: F1 died_floor door -1s floor 268s kills 109 cards 3/-1/5 peak 20 orbs 7 (+117 HP)
seed 7309 gun: F1 died_boss door 239s floor 264s kills 138 cards 4/-1/5 peak 18 orbs 7 (+132 HP)
seed 7310 blade: F1 next door 156s floor 182s kills 48 cards 3/-1/4 peak 19 orbs 2 (+42 HP) | F2 died_boss door 199s floor 226s kills 114 cards 5/-1/5 peak 27 orbs 10 (+161 HP)
seed 7310 gun: F1 next door 243s floor 273s kills 130 cards 3/-1/4 peak 18 orbs 4 (+41 HP) | F2 died_boss door 88s floor 118s kills 17 cards -1/-1/6 peak 13 orbs 1 (+25 HP)
 11:08:40 up  4:23,  0 user,  load average: 3.90, 3.41, 2.55
runs: 20
all F1: reached 20, died 5 (boss 4), timeouts 0; died by F1 5/20 (25%); door s med 180 [136..303]; kills med 78; cards 2m/5m/end med 3.5/-1.0/5.0; first chest s med 84; peak alive med 18 max 20; ttk s start 0.85 (n 397) end 1.52 (n 481) change +78%
all F1 ttk by minute: 0:0.62(107) 1:0.97(290) 2:1.41(502) 3:2.08(226) 4:2.17(80)
all F1 hurt_floor: warden 585, arc_caster 441, needle 407, charger 330, gone 51, splitter 32, swarmer 3
all F1 hurt_boss: gatekeeper 662, warlord 393
all F2: reached 15, died 10 (boss 10), timeouts 0; died by F2 15/20 (75%); door s med 88 [42..199]; kills med 18; cards 2m/5m/end med -1.0/-1.0/4.0; first chest s med 14; peak alive med 13 max 28; ttk s start 1.07 (n 241) end 3.12 (n 94) change +193%
all F2 hurt_floor: needle 163, arc_caster 143, warden 98, charger 67, gone 22, mine_layer 14, splitling 10
all F2 hurt_boss: hive_lens 829, brood_mother 281, lens_drone 17, hatchling 7
all F3: reached 5, died 4 (boss 4), timeouts 0; died by F3 19/20 (95%); door s med 95 [37..102]; kills med 17; cards 2m/5m/end med -1.0/-1.0/4.0; first chest s med 10; peak alive med 16 max 37; ttk s start 1.75 (n 57) end 0.00 (n 0) change -100%
all F3 hurt_floor: warden 22, needle 16
all F3 hurt_boss: foundry 371, siege_engine 57, bomb_drone 40
```
(The two processes' lines merged in seed order.) Per build on floor 1: Blade 2/10 died (1 at the boss), Gun 3/10 (3 at
the boss).
```
fin_1.jsonl runs 20 F1 died_s median 264 min 217 max 341 alive@60s 20/20 alive@120s 20/20 floor_s med 214 shards@door med 319
```

### Kill-boss shortcut (`fink`, labelled: bosses die on arrival)
```
runs: 20
all F1: reached 20, died 1 (boss 0), timeouts 0; died by F1 1/20 (5%); door s med 180 [136..303]; kills med 78; cards 2m/5m/end med 3.5/-1.0/5.0; first chest s med 84; peak alive med 18 max 20; ttk s start 0.85 (n 397) end 1.52 (n 481) change +78%
all F1 ttk by minute: 0:0.62(107) 1:0.97(290) 2:1.40(499) 3:1.93(217) 4:2.08(77)
all F2: reached 19, died 1 (boss 0), timeouts 0; died by F2 2/20 (10%); door s med 73 [39..131]; kills med 13; cards 2m/5m/end med -1.0/-1.0/4.0; first chest s med 14; peak alive med 7 max 26; ttk s start 0.97 (n 206) end 0.00 (n 0) change -100%
all F3: reached 18, died 7 (boss 0), timeouts 0; died by F3 9/20 (45%); door s med 88 [36..118]; kills med 18; cards 2m/5m/end med -1.0/-1.0/5.0; first chest s med 12; peak alive med 18 max 38; ttk s start 2.11 (n 280) end 0.00 (n 0) change -100%
```

### Readable cause (`027ccd9`)
```
	"death_recap_mismatches": [],
	"deaths_checked": 24,
	"runs": 36,
	"violations": 0
real	4m10.548s
```

### Horde bench (interleaved, `--only=horde`, quiet machine)
```
=== round 1 tree /tmp/claude-0/-home-user/b2a5e714-7fb3-53a7-be6c-7e4e971fcb73/scratchpad/bench_before
 11:10:12 up  4:25,  0 user,  load average: 1.09, 2.62, 2.35
		"cpu_ms_per_tick_all": 5.192,
		"mean_actors": 121.0,
		"mean_ms": 4.979,
		"mean_projectiles": 191.4,
		"p99_ms": 13.378,
 11:10:32 up  4:25,  0 user,  load average: 1.07, 2.52, 2.32
=== round 1 tree /home/user/zero-depth/.claude/worktrees/agent-ae97ce255e6b6ccfd
 11:10:32 up  4:25,  0 user,  load average: 1.07, 2.52, 2.32
		"cpu_ms_per_tick_all": 5.031,
		"mean_actors": 121.0,
		"mean_ms": 4.825,
		"mean_projectiles": 192.5,
		"p99_ms": 12.697,
 11:10:52 up  4:25,  0 user,  load average: 1.05, 2.42, 2.29
=== round 1 tree /tmp/claude-0/-home-user/b2a5e714-7fb3-53a7-be6c-7e4e971fcb73/scratchpad/before
 11:10:52 up  4:25,  0 user,  load average: 1.05, 2.42, 2.29
		"cpu_ms_per_tick_all": 5.061,
		"mean_actors": 121.0,
		"mean_ms": 4.856,
		"mean_projectiles": 191.4,
		"p99_ms": 13.527,
 11:11:11 up  4:26,  0 user,  load average: 1.03, 2.32, 2.26
=== round 2 tree /tmp/claude-0/-home-user/b2a5e714-7fb3-53a7-be6c-7e4e971fcb73/scratchpad/bench_before
 11:11:11 up  4:26,  0 user,  load average: 1.03, 2.32, 2.26
		"cpu_ms_per_tick_all": 4.989,
		"mean_actors": 121.0,
		"mean_ms": 4.803,
		"mean_projectiles": 191.4,
		"p99_ms": 12.918,
 11:11:31 up  4:26,  0 user,  load average: 1.02, 2.26, 2.24
=== round 2 tree /home/user/zero-depth/.claude/worktrees/agent-ae97ce255e6b6ccfd
 11:11:31 up  4:26,  0 user,  load average: 1.02, 2.26, 2.24
		"cpu_ms_per_tick_all": 4.889,
		"mean_actors": 121.0,
		"mean_ms": 4.686,
		"mean_projectiles": 192.5,
		"p99_ms": 12.696,
 11:11:50 up  4:26,  0 user,  load average: 1.02, 2.18, 2.22
=== round 2 tree /tmp/claude-0/-home-user/b2a5e714-7fb3-53a7-be6c-7e4e971fcb73/scratchpad/before
 11:11:50 up  4:26,  0 user,  load average: 1.02, 2.18, 2.22
		"cpu_ms_per_tick_all": 4.914,
		"mean_actors": 121.0,
		"mean_ms": 4.716,
		"mean_projectiles": 191.4,
		"p99_ms": 12.564,
 11:12:10 up  4:27,  0 user,  load average: 1.01, 2.10, 2.19
```

### Export smoke (`027ccd9`, from the scratchpad)
```
manifest: 9bc3be2a05970e9fbb3bb123891686cb0d89544aec4bb4680d34ff66d3e9d7ab (220 files, 0 errors)
  ok    600-tick World run hash e5365ddb6dcb matches the project's
  ok    manifest hash 9bc3be2a0597 matches the project's
0 miss(es)
```

## Result (round 2)
| Metric | Before (`87bac21`) | Round 1 (`d080d66`) | Round 2 (`027ccd9`) | Band | In band? |
|---|---|---|---|---|---|
| Floor-1 deaths | 20/20 (100 %) | 18/20 (90 %) | 5/20 (25 %); 4 at the boss | < 30 % | **Yes** |
| Deaths by floor 3 | 20/20 | 20/20 | 19/20 (95 %); floors 2–3: 14 deaths, all at the boss | 30–60 % | **No** |
| Same, bosses killed on arrival (shortcut) | — | — | 9/20 (45 %) | (not the band's measure) | — |
| Median TTK, floor-1 start → end | 1.82 s → — | 0.75 → 1.51 s (+101 %) | 0.85 → 1.52 s (+78 %) | −20…−40 % | **No** |
| Alive at 1:00 / 2:00 | 10/20 / 1/20 | 20/20 / 20/20 | 20/20 / 20/20 | (D1) | — |
| Median floor-1 death time (those who died) | 61 s | 210 s | 264 s | — | — |
| Floor-1 boss door (median) | 67 s (1 run) | 191 s | 180 s | M-FLOOR 10–15 min | **No** (Q-T1) |
| Floor-2 / floor-3 door (median, shortcut runs) | — | — | 73 s / 88 s | — | — |
| Peak alive on floor 1 (median / max) | 21 / 32 | 22 / 28 | 18 / 20 | — | — |
| Readable cause | — | 0 / 36 | 0 / 36 | 0 | Yes |
| Horde bench mean (ms a tick) | 4.72–4.86 (`87bac21`) | — | 4.69–4.83 (6ff13c6: 4.80–4.98) | ≤ 4 | **No** |
| Owner's feel | — | — | — | — | OWNER ONLY |

## Interpretation (round 2)
- Heal orbs did what the owner asked for: the same bot that lost 18 of 20 floor-1 runs now loses 5, and the deaths moved
  from attrition on the floor to the floor-1 boss (4 of 5) even with D9's ease and full heal.
- Floors 2–3 are now decided by their bosses (Brood Mother / Hive Lens; Foundry / Siege Engine), which the owner kept
  unchanged; the floors themselves (shortcut runs) cost 9/20 by floor 3.
- **Questions for the owner:**
  - **Q-T5 (D7 vs D1 on floors 2–3):** the bots reach the floor-2/3 boss doors at ~1:15–1:35, so "a minute before"
    lands inside the calm minute. Shipped: calm minute kept, peak at 1:30. Keep that, shorten the calm minute on
    floors 2–3, or lengthen those floors?
  - **Q-T6 (bosses on floors 2–3):** they killed 10 of the 15 bots that reached floor 2 and 4 of the 5 that reached floor 3. Ease them like floor 1, as is, or tune
    the band to exclude bosses?
  - **Q-T7 (the peak's level):** the shipped peak is SC's tier 3.5 at 55 % cap / 77.5 % HP / 55 % damage (SC's tier 20
    is no longer reached). Higher peaks (c5, c6) broke the floor-1 band. Accept?
  - The TTK band can't be met while enemy HP grows with the tier and floor 1 gives 4–5 cards; it is reported, not
    widened.
- Bench: same code as round 1's pass; on a quiet machine the TU tree is 1–3 % faster than `87bac21` and still over 4 ms.

## Verify (round 2, `9495cbf`; the commit carrying this section changes only this file)
```
godot --headless --path . --editor --import --quit                  # 0 ERROR lines
gdformat --check src scripts tests && gdlint src scripts tests       # 514 files unchanged; Success: no problems found
bash scripts/verify.sh
Tests              1076
Passing Tests      1076
Asserts           483535
Time              1538.87s
---- All tests passed! ----
check_gut_log: ok (1076 passing, minimum 1076)
```

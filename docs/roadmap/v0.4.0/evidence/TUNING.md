# TUNING (v0.4.0 TU): does the difficulty curve give an easy first minute, enemies by phase and a peak at the floor's end, and does the expected-build bot meet the PLAN's bands?

- **Status:** RUN. **The calm minute and the phases work as specified; the PLAN's three sim bands are MISSED** (floor-1
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

# BENCH (v0.3.0 O): the sim with real enemy AI, a boss and engines/combos (ARCHITECTURE §13, risk 1)

- **Status:** RUN. **Stress with real AI: target missed. Kernel stress: target missed (as in v0.0.1).** Reference
  scenes (kernel, real floor 1, floor 2's boss fight): in band on wall clock, with a contended CPU (below).
- **Build:** the working tree of workstream O on `5e24bf7` (bench script extended, `FightBot` added), before it was
  committed. Godot `4.7.2.stable.official.ed1daf0bf`, headless.
- **Machine:** cloud container, 4 vCPU "Intel(R) Xeon(R) Processor @ 2.10GHz", **shared with other agents' runs**:
  load average 11.8–13.2 on 4 vCPUs during the run (`uptime` before and after, in the raw output). Wall-clock
  numbers (`mean_ms`, `p50/p99/max_ms`, `realtime_x`) are inflated by that contention; `cpu_ms_per_tick_all` is this
  process's own CPU time (from `/proc/self/stat`, 10 ms resolution, including the bot and top-ups) and is the
  fairer mean. Not the owner's PC (`OWNER ONLY` row below).
- **Date:** 2026-10-07. **Who ran it:** agent.

## Command
```
godot --headless --path . -s scripts/bench/sim_bench.gd
```
(wrapped in `uptime; time …; uptime` to record the load).

## Scenes
| Scene | What runs | Band |
|---|---|---|
| `stress` | v0.0.1 kernel: 60 dummy movers, ~300 projectiles, 40 walls, ScriptedInput | mean ≤ 2 ms, p99 ≤ 4 ms |
| `reference` | v0.0.1 kernel: 12 movers, ~40 projectiles, 12 walls | ≥ 15× real time |
| `stress_ai` | floor 3's boss room (run seed 20261007): the Siege Engine plus ~60 real enemies kept alive (Charger, Warden, Needle, hatchling in turn), the player holding the 16 items of all 8 named combos, FightBot playing, HP topped up between ticks | mean ≤ 2 ms, p99 ≤ 4 ms |
| `reference_floor` | floor 1 as played (its own spawning), FightBot | ≥ 15× real time |
| `reference_boss` | floor 2's boss room (the Brood Mother and her hatchlings), FightBot | ≥ 15× real time |

Each scene runs 3,600 ticks; only `World.step` is timed (the bot and the top-ups run between timed ticks).

## Raw output
```
 15:02:49 up  1:17,  0 user,  load average: 13.15, 18.00, 20.24
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org

{
	"godot": "4.7.2-stable (official)",
	"reference": {
		"cpu_ms_per_tick_all": 0.569,
		"max_ms": 351.255,
		"mean_actors": 13.0,
		"mean_ms": 0.981,
		"mean_projectiles": 42.5,
		"over_4ms_on_flow_field_ticks": 9,
		"p50_ms": 0.552,
		"p99_ms": 7.81,
		"realtime_x": 17.0,
		"scene": "reference",
		"ticks_over_4ms": 131,
		"walls": 12
	},
	"reference_boss": {
		"cpu_ms_per_tick_all": 0.269,
		"max_ms": 10.047,
		"mean_actors": 2.8,
		"mean_ms": 0.299,
		"mean_projectiles": 0.1,
		"over_4ms_on_flow_field_ticks": 14,
		"p50_ms": 0.126,
		"p99_ms": 3.57,
		"realtime_x": 55.8,
		"scene": "reference_boss",
		"ticks_over_4ms": 32,
		"walls": 157
	},
	"reference_boss_in_band": true,
	"reference_floor": {
		"cpu_ms_per_tick_all": 0.978,
		"max_ms": 23.04,
		"mean_actors": 3.4,
		"mean_ms": 1.06,
		"mean_projectiles": 1.6,
		"over_4ms_on_flow_field_ticks": 207,
		"p50_ms": 0.217,
		"p99_ms": 17.079,
		"realtime_x": 15.7,
		"scene": "reference_floor",
		"ticks_over_4ms": 216,
		"walls": 205
	},
	"reference_floor_in_band": true,
	"reference_in_band": true,
	"stress": {
		"cpu_ms_per_tick_all": 3.806,
		"max_ms": 360.679,
		"mean_actors": 61.0,
		"mean_ms": 6.0,
		"mean_projectiles": 311.7,
		"over_4ms_on_flow_field_ticks": 191,
		"p50_ms": 4.323,
		"p99_ms": 30.68,
		"realtime_x": 2.8,
		"scene": "stress",
		"ticks_over_4ms": 2046,
		"walls": 40
	},
	"stress_ai": {
		"combos_owned": 8,
		"cpu_ms_per_tick_all": 6.767,
		"items_owned": 16,
		"max_ms": 389.095,
		"mean_actors": 61.9,
		"mean_ms": 10.439,
		"mean_projectiles": 13.6,
		"over_4ms_on_flow_field_ticks": 290,
		"p50_ms": 8.933,
		"p99_ms": 56.305,
		"realtime_x": 1.6,
		"scene": "stress_ai",
		"ticks_over_4ms": 2830,
		"walls": 143
	},
	"stress_ai_in_band": false,
	"stress_in_band": false
}

real	1m11.734s
user	0m46.464s
sys	0m0.259s
 15:04:01 up  1:18,  0 user,  load average: 11.79, 16.64, 19.61
```

## Result
| Metric | Measured (wall) | CPU mean | In band? |
|---|---|---|---|
| `stress_ai` mean tick (61.9 actors, 13.6 projectiles, 143 walls, 8 combos) | 10.439 ms | 6.767 ms | **No** |
| `stress_ai` p99 tick | 56.305 ms | — | **No** |
| `stress` (kernel) mean / p99 | 6.0 / 30.68 ms | 3.806 ms | **No** |
| `reference` (kernel) speed | 17.0× | 0.569 ms/tick | Yes |
| `reference_floor` speed (3.4 actors, 205 walls) | 15.7× | 0.978 ms/tick | Yes (narrowly) |
| `reference_boss` speed (2.8 actors, 157 walls) | 55.8× | 0.269 ms/tick | Yes |
| Owner's PC, all scenes | — | — | OWNER ONLY |

## Interpretation (no retuning was done)
- The kernel `stress` scene's CPU mean (3.806 ms) is close to v0.0.1's quiet-machine wall mean (3.457 ms), so the
  CPU column is a usable yardstick here; the wall-clock p99s of this run are not.
- With real AI the stress scene costs about **6.8 ms of CPU per tick**, over three times the 2 ms target, even
  though it has far fewer projectiles than the kernel scene (enemies shoot rarely). The cost moved from
  projectile sweeps to the enemies, the boss and a much larger wall set (143 walls). p99 can't be judged on this
  machine.
- On the real floor, 207 of the 216 ticks over 4 ms fell on flow-field ticks (`World.tick % NavField.PERIOD == 0`,
  every 10 ticks): flooding the flow field over a 205-wall floor is the first spike source to look at. In
  `stress_ai`, 2,830 of 3,600 ticks are over 4 ms and only 290 of them are flow-field ticks, so its cost is the
  steady per-tick load, not the floods.
- Not profiled per phase yet. One candidate seen in the code, unmeasured: `EnemyAi.steer` sweeps every wall of the
  floor for every walking enemy each tick (no grid query).
- Per the rule, the step stops here and the owner decides. Options (the v0.0.1 list still applies): measured
  optimization (per-enemy steer wall sweeps over every wall, the flow-field flood, collide), a lower stress scene
  matching what the game really fields, a GDExtension for the hot loops (an
  EI change), or re-checking on the owner's PC.

# HORDES (v0.4.0 SC): can the sim and the view carry 120 enemies and 200 projectiles?

- **Status:** RUN. **After the BS/EN/BO merge (`b58e737`, below): the horde target is MISSED (4.841 and
  4.893 ms).** On the same machine at the same hour SC's own commit `1330ecd` measured 4.554 ms, so most of the rise
  is the machine (post-restart host, load 4.5–6.2), and the merge adds about 0.3 ms (~7 %). Not retuned. Before the
  merge: **sim horde target (≤ 4 ms mean a tick) met on this machine (3.656 ms).** `stress_ai` (v0.3.0's
  missed target, ≤ 2 ms mean, p99 ≤ 4 ms): met (1.732 / 3.35 ms). The v0.0.1 kernel `stress` scene: still missed on
  the mean (2.216 ms vs ≤ 2 ms; p99 3.85 ms is in band). View frame time: measured only on lavapipe, a CPU
  rasteriser; the owner's 60 fps check is OWNER ONLY.
- **Build:** "after" = the working tree of step SC on `b110985` (`claude/lucid-fermat-9wv2tf`), uncommitted when
  measured; it is the commit that carries this file (no code changed after the runs below except docs and the
  regenerated goldens). "Before" = `b110985` itself: the stress scenes from that checkout; the horde scene from an
  export of `b110985` (`git archive b110985`) with only `scripts/bench/sim_bench.gd` replaced by SC's (the horde
  scene uses no API SC added). Godot `4.7.2.stable.official.ed1daf0bf`, headless for the sim.
- **Machine:** cloud container, 4 vCPU, **shared with other agents' runs**; the load average is in each raw output
  (`uptime` before and after). `cpu_ms_per_tick_all` is this process's CPU time per tick (includes the bot and the
  untimed top-ups), the fairer number when the load is high. Not the owner's PC.
- **Date:** 2026-10-07. **Who ran it:** agent.

## What changed (SC, measured first)
A phase profile of `stress_ai` (a scratch copy of `World.step` with timers, not committed) put 6.1 of its 6.7 ms in
phase 5: each walking enemy swept every wall of the floor for its line of sight (~5.4 ms) and summed its spread push
over every other actor (~1.3 ms). In the horde scene the flow-field flood (every 10 ticks over the whole floor; up to
~11 ms on floor 1), the projectile store rebuilding 15 arrays element by element whenever a shot died, and the event
log freeing 4,096 events in one tick (a ~10 ms hitch) followed. Changes, all in `src/sim` unless named:
- `DenseGrid` replaces `UniformGrid`'s Dictionary of Arrays for the walls and the actors; line-of-sight and charge
  runs walk only the cells along the segment (`World.walls_along`).
- Enemies re-plan every 4 ticks on the phase `id % 4` (walk direction, spread push from the actor grid, flow field
  when blocked; the wall sweep every other plan) and move every tick (SIM_CONTRACTS §10b).
- The flood is bounded (160 steps) and skipped when the player is still in the last flood's cell.
- Cheap box rejects before the circle and sweep calls in collision and projectile hits; walls skipped for bodies with
  none within 0.5 m; stores remove in place; the event log trims 512 at a time; aim and facing computed only when used.
- View (`src/presentation`): projectile nodes pooled per look; enemy HP bars only once hurt; off-screen enemy models
  stop animating; occlusion tests the hero and at most 24 enemies within 10 m, with a quick reject.

## Commands
```
uptime; time godot --headless --path . -s scripts/bench/sim_bench.gd; uptime          # before (b110985) and after
uptime; time godot --headless --path . -s scripts/bench/sim_bench.gd -- --only=horde; uptime   # before, horde only
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
  godot --path . --audio-driver Dummy --resolution 1280x720 -s scripts/bench/view_bench.gd -- --frames=150
```
The view "before" ran SC's sim with `b110985`'s three view files (`actor_views.gd`, `world_view_root.gd`,
`occlusion.gd`) put back for the run.

## Scenes
| Scene | What runs | Band |
|---|---|---|
| `horde` (new) | floor 3 (run seed 20261007), 120 real enemies kept alive in the start hall and its neighbours (Charger, Needle, Warden, Arc Caster, Bomb Drone in turn), the player's bolts topped up to 200 in flight, FightBot playing, HP topped up | mean ≤ 4 ms |
| `stress_ai` | v0.3.0's: floor 3's boss room, ~60 real enemies, the boss, 16 items / 8 combos | mean ≤ 2 ms, p99 ≤ 4 ms |
| `stress` | v0.0.1 kernel: 60 dummy movers, ~300 projectiles, 40 walls | mean ≤ 2 ms, p99 ≤ 4 ms |
| `reference`, `reference_floor`, `reference_boss` | as in v0.3.0's BENCH | ≥ 15× real time |

## Raw output

### Before, all scenes (`b110985`)
```
 21:23:40 up  1:40,  0 user,  load average: 1.76, 1.73, 1.91
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org

{
	"godot": "4.7.2-stable (official)",
	"reference": {
		"cpu_ms_per_tick_all": 0.528,
		"max_ms": 1.564,
		"mean_actors": 13.0,
		"mean_ms": 0.518,
		"mean_projectiles": 42.5,
		"over_4ms_on_flow_field_ticks": 0,
		"p50_ms": 0.501,
		"p99_ms": 0.889,
		"realtime_x": 32.2,
		"scene": "reference",
		"ticks_over_4ms": 0,
		"walls": 12
	},
	"reference_boss": {
		"cpu_ms_per_tick_all": 0.261,
		"max_ms": 1.987,
		"mean_actors": 2.6,
		"mean_ms": 0.237,
		"mean_projectiles": 0.1,
		"over_4ms_on_flow_field_ticks": 0,
		"p50_ms": 0.14,
		"p99_ms": 1.3,
		"realtime_x": 70.2,
		"scene": "reference_boss",
		"ticks_over_4ms": 0,
		"walls": 157
	},
	"reference_boss_in_band": true,
	"reference_floor": {
		"cpu_ms_per_tick_all": 0.569,
		"max_ms": 11.881,
		"mean_actors": 4.1,
		"mean_ms": 0.544,
		"mean_projectiles": 0.8,
		"over_4ms_on_flow_field_ticks": 108,
		"p50_ms": 0.245,
		"p99_ms": 9.956,
		"realtime_x": 30.6,
		"scene": "reference_floor",
		"ticks_over_4ms": 108,
		"walls": 205
	},
	"reference_floor_in_band": true,
	"reference_in_band": true,
	"stress": {
		"cpu_ms_per_tick_all": 3.381,
		"max_ms": 16.792,
		"mean_actors": 61.0,
		"mean_ms": 3.366,
		"mean_projectiles": 311.7,
		"over_4ms_on_flow_field_ticks": 27,
		"p50_ms": 3.285,
		"p99_ms": 4.723,
		"realtime_x": 5.0,
		"scene": "stress",
		"ticks_over_4ms": 228,
		"walls": 40
	},
	"stress_ai": {
		"combos_owned": 8,
		"cpu_ms_per_tick_all": 6.478,
		"items_owned": 16,
		"max_ms": 40.84,
		"mean_actors": 61.9,
		"mean_ms": 6.38,
		"mean_projectiles": 11.3,
		"over_4ms_on_flow_field_ticks": 274,
		"p50_ms": 8.043,
		"p99_ms": 12.338,
		"realtime_x": 2.6,
		"scene": "stress_ai",
		"ticks_over_4ms": 2613,
		"walls": 143
	},
	"stress_ai_in_band": false,
	"stress_in_band": false
}

real	0m42.524s
user	0m42.368s
sys	0m0.094s
 21:24:23 up  1:40,  0 user,  load average: 1.94, 1.78, 1.92
```

### Before, horde (`b110985` + SC bench script)
```
 22:40:19 up  2:56,  0 user,  load average: 6.41, 9.65, 10.23
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org

{
	"godot": "4.7.2-stable (official)",
	"horde": {
		"cpu_ms_per_tick_all": 14.297,
		"max_ms": 35.439,
		"mean_actors": 120.9,
		"mean_ms": 14.134,
		"mean_projectiles": 193.4,
		"over_4ms_on_flow_field_ticks": 278,
		"p50_ms": 17.44,
		"p99_ms": 24.586,
		"realtime_x": 1.2,
		"scene": "horde",
		"ticks_over_4ms": 2808,
		"walls": 142
	},
	"horde_in_band": false
}

real	0m52.412s
user	0m52.347s
sys	0m0.060s
 22:41:11 up  2:57,  0 user,  load average: 3.79, 8.38, 9.76
```

### After, all scenes
```
 22:41:14 up  2:57,  0 user,  load average: 3.79, 8.38, 9.76
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org

{
	"godot": "4.7.2-stable (official)",
	"horde": {
		"cpu_ms_per_tick_all": 3.817,
		"max_ms": 13.833,
		"mean_actors": 121.0,
		"mean_ms": 3.656,
		"mean_projectiles": 189.9,
		"over_4ms_on_flow_field_ticks": 282,
		"p50_ms": 4.09,
		"p99_ms": 8.885,
		"realtime_x": 4.6,
		"scene": "horde",
		"ticks_over_4ms": 1984,
		"walls": 142
	},
	"horde_in_band": true,
	"reference": {
		"cpu_ms_per_tick_all": 0.339,
		"max_ms": 0.84,
		"mean_actors": 13.0,
		"mean_ms": 0.329,
		"mean_projectiles": 42.5,
		"over_4ms_on_flow_field_ticks": 0,
		"p50_ms": 0.329,
		"p99_ms": 0.433,
		"realtime_x": 50.7,
		"scene": "reference",
		"ticks_over_4ms": 0,
		"walls": 12
	},
	"reference_boss": {
		"cpu_ms_per_tick_all": 0.178,
		"max_ms": 1.291,
		"mean_actors": 2.6,
		"mean_ms": 0.158,
		"mean_projectiles": 0.1,
		"over_4ms_on_flow_field_ticks": 0,
		"p50_ms": 0.107,
		"p99_ms": 1.064,
		"realtime_x": 105.4,
		"scene": "reference_boss",
		"ticks_over_4ms": 0,
		"walls": 157
	},
	"reference_boss_in_band": true,
	"reference_floor": {
		"cpu_ms_per_tick_all": 0.586,
		"max_ms": 4.82,
		"mean_actors": 12.0,
		"mean_ms": 0.561,
		"mean_projectiles": 3.9,
		"over_4ms_on_flow_field_ticks": 67,
		"p50_ms": 0.327,
		"p99_ms": 4.115,
		"realtime_x": 29.7,
		"scene": "reference_floor",
		"ticks_over_4ms": 67,
		"walls": 205
	},
	"reference_floor_in_band": true,
	"reference_in_band": true,
	"stress": {
		"cpu_ms_per_tick_all": 2.225,
		"max_ms": 4.752,
		"mean_actors": 61.0,
		"mean_ms": 2.216,
		"mean_projectiles": 311.4,
		"over_4ms_on_flow_field_ticks": 3,
		"p50_ms": 2.179,
		"p99_ms": 3.85,
		"realtime_x": 7.5,
		"scene": "stress",
		"ticks_over_4ms": 24,
		"walls": 40
	},
	"stress_ai": {
		"combos_owned": 8,
		"cpu_ms_per_tick_all": 1.811,
		"items_owned": 16,
		"max_ms": 6.488,
		"mean_actors": 62.0,
		"mean_ms": 1.732,
		"mean_projectiles": 10.8,
		"over_4ms_on_flow_field_ticks": 0,
		"p50_ms": 2.031,
		"p99_ms": 3.35,
		"realtime_x": 9.6,
		"scene": "stress_ai",
		"ticks_over_4ms": 15,
		"walls": 143
	},
	"stress_ai_in_band": true,
	"stress_in_band": false
}

real	0m34.420s
user	0m34.288s
sys	0m0.076s
 22:41:49 up  2:58,  0 user,  load average: 3.00, 7.67, 9.47
```

### View before (`b110985` view files)
```
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org
Vulkan 1.4.318 - Forward+ - Using Device #0: Unknown - llvmpipe (LLVM 20.1.2, 256 bits)

frame 50
frame 100
frame 150
{
	"draw_calls_mean": 7146.0,
	"driver": "Unknown",
	"enemies_target": 120,
	"fps_mean": 0.5,
	"frame_ms": {
		"mean": 2124.91,
		"p50": 2048.12,
		"p95": 2851.86
	},
	"frames": 150,
	"godot": "4.7.2-stable (official)",
	"mean_actors": 121,
	"objects_mean": 7188.0,
	"renderer": "llvmpipe (LLVM 20.1.2, 256 bits)",
	"sim_step_ms": {
		"mean": 5.44,
		"p50": 4.13,
		"p95": 16.33
	},
	"view_sync_ms": {
		"mean": 27.15,
		"p50": 20.28,
		"p95": 69.42
	}
}
```

### View after
```
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org
Vulkan 1.4.318 - Forward+ - Using Device #0: Unknown - llvmpipe (LLVM 20.1.2, 256 bits)

frame 50
frame 100
frame 150
{
	"draw_calls_mean": 6920.0,
	"driver": "Unknown",
	"enemies_target": 120,
	"fps_mean": 1.1,
	"frame_ms": {
		"mean": 899.47,
		"p50": 947.95,
		"p95": 1268.05
	},
	"frames": 150,
	"godot": "4.7.2-stable (official)",
	"mean_actors": 121,
	"objects_mean": 7144.0,
	"renderer": "llvmpipe (LLVM 20.1.2, 256 bits)",
	"sim_step_ms": {
		"mean": 4.64,
		"p50": 4.02,
		"p95": 14.22
	},
	"view_sync_ms": {
		"mean": 11.81,
		"p50": 11.52,
		"p95": 19.95
	}
}
 22:40:12 up  2:56,  0 user,  load average: 6.88, 9.80, 10.28
```

## Result (sim, headless)
| Scene | Before (b110985) mean / p99 / CPU | After mean / p99 / CPU | Band | In band after? |
|---|---|---|---|---|
| `horde` (120.9 / 121.0 actors, 193.4 / 189.9 projectiles) | 14.134 / 24.586 / 14.297 ms | 3.656 / 8.885 / 3.817 ms | mean ≤ 4 ms | **Yes** |
| `stress_ai` | 6.38 / 12.338 / 6.478 ms | 1.732 / 3.35 / 1.811 ms | ≤ 2 / ≤ 4 ms | **Yes** |
| `stress` (kernel) | 3.366 / 4.723 / 3.381 ms | 2.216 / 3.85 / 2.225 ms | ≤ 2 / ≤ 4 ms | **No** (mean) |
| `reference_floor` | see raw | 29.7× | ≥ 15× | Yes |
| `reference_boss` | see raw | 105.4× | ≥ 15× | Yes |
| `reference` | see raw | 50.7× | ≥ 15× | Yes |
| Owner's PC | — | — | — | OWNER ONLY |

Load average: before 1.76–1.94 (stress scenes), 6.41 → 3.79 (horde before); after 3.79 → 3.00.

## Result (view, lavapipe CPU rasteriser, 1280×720, 150 frames, 120 enemies + 200 projectiles)
| Metric | Before (b110985 view) | After (SC view) |
|---|---|---|
| `view_sync_ms` mean / p95 (WorldViewRoot.sync, CPU) | 27.15 / 69.42 | 11.81 / 19.95 |
| frame mean (lavapipe, rasterising on the CPU) | 2124.91 ms | 899.47 ms |
| draw calls a frame | 7146 | 6920 |
| 60 fps on the owner's PC | — | OWNER ONLY |

The frame times are a CPU rasteriser's on a loaded machine (load 12–13 during "before", 9.7 → 6.9 during "after"),
so they say nothing about a GPU. The view's own CPU cost (`view_sync_ms`) more than halved. Draw calls stay ~7,000:
each enemy model is its own node tree (about 60 meshes with X-ray twins and shadows), not a MultiMesh, because each
kind animates its own parts. That is the open risk for 60 fps with 120 enemies.

## Interpretation
- The horde target is met on this machine with about 9 % to spare; on a slower CI runner or a busier machine it may
  not be (the regression test `tests/unit/sim/test_horde.gd` uses a 25 ms bound on purpose, to catch an O(n²)
  return, not a few per cent).
- The kernel `stress` scene (dummy movers, ~300 shots) improved 34 % but stays over its 2 ms mean. Reported, not
  retuned; it has missed since v0.0.1.
- p99 in the horde (8.9 ms) comes mostly from the flood ticks (every 10th tick, ~3–5 ms on floor 3).
- Decisions for the owner: whether the view's draw-call count needs instanced crowds (a model rework) after the
  60 fps check on the owner's PC.

## Readable cause (after)
```
time godot --headless --path . -s scripts/checks/readable_cause.gd
```
```
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org

{
	"boss_fights": 36,
	"boss_ticks": 3600,
	"by_cause": {
		"CAUSE_ARC_CASTER": 19,
		"CAUSE_BOSS_ARENA": 53,
		"CAUSE_BROOD_BROOD": 6,
		"CAUSE_BROOD_BURROW": 53,
		"CAUSE_BROOD_LEAP": 6,
		"CAUSE_CHARGER": 398,
		"CAUSE_GATEKEEPER_CHARGE": 8,
		"CAUSE_GATEKEEPER_LANES": 7,
		"CAUSE_GATEKEEPER_SLAM": 7,
		"CAUSE_GATEKEEPER_SWEEP": 32,
		"CAUSE_HATCHLING": 31,
		"CAUSE_NEEDLE": 409,
		"CAUSE_SIEGE_BARRAGE": 38,
		"CAUSE_SIEGE_BOLTS": 56,
		"CAUSE_SIEGE_DEPLOY": 4,
		"CAUSE_SIEGE_RAIL": 27,
		"CAUSE_WARDEN": 11
	},
	"damage_to_player": 1165,
	"death_recap_mismatches": [],
	"deaths_checked": 24,
	"floor_ticks": 3600,
	"godot": "4.7.2-stable (official)",
	"runs": 36,
	"seeds": 12,
	"violations": 0
}

real	3m15.901s
user	3m15.625s
sys	0m0.292s
```
0 violations over 36 runs (12 seeds, every floor and boss, both utilities). The unit tests
(`tests/unit/sim/test_readable_cause.gd`, `test_enemy_ai.gd`'s readable-cause test) pass unchanged; no hit bar was
lowered.

## After the merge with BS, EN and BO (`a2b6d5b`)
- **Build:** the merge commit `b58e737` (it carries the merge fixes: `MineStore` in-place removal, mine damage by
  the layer's tier power); the commit carrying this section changes only docs and `MIN_TEST_COUNT`. The comparison row is SC's own `1330ecd`, exported with
  `git archive 1330ecd` and benched right after, on the same machine and load.
- **Machine:** the container restarted twice since the numbers above; the load is in the raw output.

### Commands
```
uptime; time godot --headless --path . -s scripts/bench/sim_bench.gd; uptime                       # merged, all scenes
uptime; time godot --headless --path . -s scripts/bench/sim_bench.gd -- --only=horde,stress_ai,stress; uptime   # merged, again; and 1330ecd
time godot --headless --path . -s scripts/checks/readable_cause.gd
bash <repo>/scripts/ci/export_smoke.sh      # run from the scratchpad, outside the project folder
```

### Result
| Scene | `1330ecd` now (mean / p99 / CPU ms) | Merged run 1 | Merged run 2 | Band | In band? |
|---|---|---|---|---|---|
| `horde` | 4.554 / 11.076 / 4.753 | 4.841 / 12.896 / 5.042 | 4.893 / 12.827 / 5.097 | mean ≤ 4 ms | **No** |
| `stress_ai` | 2.172 / 4.429 / 2.267 | 2.029 / 4.567 / 2.131 | 2.092 / 5.036 / 2.2 | ≤ 2 / ≤ 4 ms | **No** |
| `stress` (kernel; no merge code runs in it) | 2.86 / 5.538 / 2.844 | 2.896 / 5.582 / 2.892 | 2.935 / 5.675 / 2.95 | ≤ 2 / ≤ 4 ms | **No** |

The kernel scene runs none of the merged code and still rose from 2.216 to ~2.9 ms between the sessions: the machine
is slower now. Measured against SC's commit under the same conditions, the merge costs ~0.3 ms in the horde (the
horde kinds' AI and BS's abilities hooks in the tick). Against the target it is a miss, reported as such: the owner
(or the lead) decides whether to optimise further (the next candidates are the flood ticks, the projectile phase and
the per-enemy think) or to judge the target on the CI runner / the owner's PC.

### Raw output: merged, all scenes
```
 23:43:01 up 32 min,  0 user,  load average: 5.85, 4.35, 3.07
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org

{
	"godot": "4.7.2-stable (official)",
	"horde": {
		"cpu_ms_per_tick_all": 5.042,
		"max_ms": 31.266,
		"mean_actors": 121.0,
		"mean_ms": 4.841,
		"mean_projectiles": 191.4,
		"over_4ms_on_flow_field_ticks": 285,
		"p50_ms": 5.291,
		"p99_ms": 12.896,
		"realtime_x": 3.4,
		"scene": "horde",
		"ticks_over_4ms": 2759,
		"walls": 140
	},
	"horde_in_band": false,
	"reference": {
		"cpu_ms_per_tick_all": 0.436,
		"max_ms": 1.035,
		"mean_actors": 13.0,
		"mean_ms": 0.424,
		"mean_projectiles": 42.5,
		"over_4ms_on_flow_field_ticks": 0,
		"p50_ms": 0.414,
		"p99_ms": 0.727,
		"realtime_x": 39.3,
		"scene": "reference",
		"ticks_over_4ms": 0,
		"walls": 12
	},
	"reference_boss": {
		"cpu_ms_per_tick_all": 0.267,
		"max_ms": 1.894,
		"mean_actors": 2.7,
		"mean_ms": 0.24,
		"mean_projectiles": 0.6,
		"over_4ms_on_flow_field_ticks": 0,
		"p50_ms": 0.155,
		"p99_ms": 1.245,
		"realtime_x": 69.4,
		"scene": "reference_boss",
		"ticks_over_4ms": 0,
		"walls": 156
	},
	"reference_boss_in_band": true,
	"reference_floor": {
		"cpu_ms_per_tick_all": 0.736,
		"max_ms": 7.045,
		"mean_actors": 12.1,
		"mean_ms": 0.702,
		"mean_projectiles": 3.6,
		"over_4ms_on_flow_field_ticks": 215,
		"p50_ms": 0.396,
		"p99_ms": 5.011,
		"realtime_x": 23.7,
		"scene": "reference_floor",
		"ticks_over_4ms": 215,
		"walls": 186
	},
	"reference_floor_in_band": true,
	"reference_in_band": true,
	"stress": {
		"cpu_ms_per_tick_all": 2.892,
		"max_ms": 9.136,
		"mean_actors": 61.0,
		"mean_ms": 2.896,
		"mean_projectiles": 311.4,
		"over_4ms_on_flow_field_ticks": 19,
		"p50_ms": 2.792,
		"p99_ms": 5.582,
		"realtime_x": 5.8,
		"scene": "stress",
		"ticks_over_4ms": 147,
		"walls": 40
	},
	"stress_ai": {
		"combos_owned": 8,
		"cpu_ms_per_tick_all": 2.131,
		"items_owned": 16,
		"max_ms": 10.55,
		"mean_actors": 62.0,
		"mean_ms": 2.029,
		"mean_projectiles": 26.6,
		"over_4ms_on_flow_field_ticks": 67,
		"p50_ms": 2.227,
		"p99_ms": 4.567,
		"realtime_x": 8.2,
		"scene": "stress_ai",
		"ticks_over_4ms": 103,
		"walls": 141
	},
	"stress_ai_in_band": false,
	"stress_in_band": false
}

real	0m44.694s
user	0m44.318s
sys	0m0.092s
 23:43:45 up 33 min,  0 user,  load average: 4.93, 4.38, 3.14
```

### Raw output: merged, second run
```
 23:43:51 up 33 min,  0 user,  load average: 4.53, 4.31, 3.13
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org

{
	"godot": "4.7.2-stable (official)",
	"horde": {
		"cpu_ms_per_tick_all": 5.097,
		"max_ms": 29.887,
		"mean_actors": 121.0,
		"mean_ms": 4.893,
		"mean_projectiles": 191.4,
		"over_4ms_on_flow_field_ticks": 285,
		"p50_ms": 5.337,
		"p99_ms": 12.827,
		"realtime_x": 3.4,
		"scene": "horde",
		"ticks_over_4ms": 2764,
		"walls": 140
	},
	"horde_in_band": false,
	"stress": {
		"cpu_ms_per_tick_all": 2.95,
		"max_ms": 8.719,
		"mean_actors": 61.0,
		"mean_ms": 2.935,
		"mean_projectiles": 311.4,
		"over_4ms_on_flow_field_ticks": 11,
		"p50_ms": 2.839,
		"p99_ms": 5.675,
		"realtime_x": 5.7,
		"scene": "stress",
		"ticks_over_4ms": 116,
		"walls": 40
	},
	"stress_ai": {
		"combos_owned": 8,
		"cpu_ms_per_tick_all": 2.2,
		"items_owned": 16,
		"max_ms": 9.207,
		"mean_actors": 62.0,
		"mean_ms": 2.092,
		"mean_projectiles": 26.6,
		"over_4ms_on_flow_field_ticks": 92,
		"p50_ms": 2.271,
		"p99_ms": 5.036,
		"realtime_x": 8.0,
		"scene": "stress_ai",
		"ticks_over_4ms": 161,
		"walls": 141
	},
	"stress_ai_in_band": false,
	"stress_in_band": false
}

real	0m38.798s
user	0m38.671s
sys	0m0.092s
 23:44:30 up 34 min,  0 user,  load average: 4.73, 4.36, 3.19
```

### Raw output: `1330ecd` (SC before the merge), same session
```
 23:45:21 up 35 min,  0 user,  load average: 6.15, 4.77, 3.39
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org

{
	"godot": "4.7.2-stable (official)",
	"horde": {
		"cpu_ms_per_tick_all": 4.753,
		"max_ms": 16.726,
		"mean_actors": 121.0,
		"mean_ms": 4.554,
		"mean_projectiles": 189.9,
		"over_4ms_on_flow_field_ticks": 288,
		"p50_ms": 4.996,
		"p99_ms": 11.076,
		"realtime_x": 3.7,
		"scene": "horde",
		"ticks_over_4ms": 2736,
		"walls": 142
	},
	"horde_in_band": false,
	"stress": {
		"cpu_ms_per_tick_all": 2.844,
		"max_ms": 8.615,
		"mean_actors": 61.0,
		"mean_ms": 2.86,
		"mean_projectiles": 311.4,
		"over_4ms_on_flow_field_ticks": 14,
		"p50_ms": 2.759,
		"p99_ms": 5.538,
		"realtime_x": 5.8,
		"scene": "stress",
		"ticks_over_4ms": 117,
		"walls": 40
	},
	"stress_ai": {
		"combos_owned": 8,
		"cpu_ms_per_tick_all": 2.267,
		"items_owned": 16,
		"max_ms": 7.495,
		"mean_actors": 62.0,
		"mean_ms": 2.172,
		"mean_projectiles": 10.8,
		"over_4ms_on_flow_field_ticks": 3,
		"p50_ms": 2.54,
		"p99_ms": 4.429,
		"realtime_x": 7.7,
		"scene": "stress_ai",
		"ticks_over_4ms": 54,
		"walls": 143
	},
	"stress_ai_in_band": false,
	"stress_in_band": false
}

real	0m37.339s
user	0m37.013s
sys	0m0.084s
 23:45:58 up 35 min,  0 user,  load average: 5.78, 4.88, 3.49
```

### Readable cause (merged)
```
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org

{
	"boss_fights": 36,
	"boss_ticks": 3600,
	"by_cause": {
		"CAUSE_ARC_CASTER": 31,
		"CAUSE_BOMB_DRONE": 44,
		"CAUSE_BOSS_ARENA": 72,
		"CAUSE_BROOD_BROOD": 1,
		"CAUSE_BROOD_BURROW": 17,
		"CAUSE_CHARGER": 395,
		"CAUSE_FOUNDRY_FLOOD": 28,
		"CAUSE_FOUNDRY_LAUNCH": 1,
		"CAUSE_FOUNDRY_SLAG": 10,
		"CAUSE_FOUNDRY_VENT": 21,
		"CAUSE_GATEKEEPER_CHARGE": 5,
		"CAUSE_GATEKEEPER_LANES": 3,
		"CAUSE_GATEKEEPER_SWEEP": 17,
		"CAUSE_HATCHLING": 12,
		"CAUSE_HIVE_DIVE": 2,
		"CAUSE_HIVE_GLARE": 35,
		"CAUSE_HIVE_PRISM": 5,
		"CAUSE_HIVE_SPLIT": 1,
		"CAUSE_HIVE_SWEEP": 35,
		"CAUSE_LENS_DRONE": 12,
		"CAUSE_NEEDLE": 387,
		"CAUSE_SIEGE_BARRAGE": 15,
		"CAUSE_SIEGE_BOLTS": 24,
		"CAUSE_SIEGE_DEPLOY": 1,
		"CAUSE_SIEGE_RAIL": 17,
		"CAUSE_SPLITTER": 5,
		"CAUSE_SWARMER": 12,
		"CAUSE_WARDEN": 16,
		"CAUSE_WARLORD_BASH": 15,
		"CAUSE_WARLORD_DASH": 4,
		"CAUSE_WARLORD_SPEARS": 13
	},
	"damage_to_player": 1256,
	"death_recap_mismatches": [],
	"deaths_checked": 24,
	"floor_ticks": 3600,
	"godot": "4.7.2-stable (official)",
	"runs": 36,
	"seeds": 12,
	"violations": 0
}

real	4m5.920s
user	4m5.248s
sys	0m0.348s
```

### Export smoke (merged; from outside the project folder)
```
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org

manifest: f2e51de52154a21808597da3a63a8cc2cd250adee46c23b0fc58a8092573b06e (167 files, 0 errors)
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org

Export smoke check (exported pack)
  ok    running inside the exported pack (run from outside the project folder)
  ok    the main scene ships
  ok    600-tick World run hash e5365ddb6dcb matches the project's
  ok    content player: 1
  ok    content biomes: 3
  ok    content validates inside the pack (0 errors)
  ok    manifest hash f2e51de52154 matches the project's
  ok    Spanish translation is loaded
  ok    UI_PLAY is PLAY / JUGAR
  ok    boss model stone_sentinel loads from the pack
  ok    boss model crawler_queen loads from the pack
  ok    boss model fortress_turret loads from the pack
  ok    audio cues: 74
  ok    every cue's sound loads from the pack (missing: [])
  ok    the test framework is not shipped
  ok    tests are not shipped
0 miss(es)
```
The 600-tick kernel hash in the pack is `e5365ddb…`, the one SC re-recorded; the merge didn't change it.

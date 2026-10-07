# HORDES (v0.4.0 SC): can the sim and the view carry 120 enemies and 200 projectiles?

- **Status:** RUN. **Sim horde target (≤ 4 ms mean a tick): met on this machine (3.656 ms).** `stress_ai` (v0.3.0's
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

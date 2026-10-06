# BENCH: is the GDScript sim fast enough (ARCHITECTURE §13, risk 1)?

- **Status:** RUN. **Stress scene: target missed.** Reference scene: in band.
- **Build:** working tree on `818ac81` + Step 5 changes (bench script, two bench knobs, two grid fixes); Godot `4.7.2.stable.official.ed1daf0bf`
- **Machine:** cloud container, 4 vCPU "Intel(R) Xeon(R) Processor @ 2.10GHz", headless. Not the owner's PC (`OWNER ONLY` rows below).
- **Date:** 2026-10-06
- **Who ran it:** agent

## Command
```
godot --headless --path . -s scripts/bench/sim_bench.gd
```

## Raw output
```
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org

{
	"godot": "4.7.2-stable (official)",
	"reference": {
		"actors": 13,
		"mean_ms": 0.524,
		"mean_projectiles": 40.9,
		"p50_ms": 0.494,
		"p99_ms": 0.888,
		"realtime_x": 31.2,
		"scene": "reference",
		"walls": 12
	},
	"reference_in_band": true,
	"stress": {
		"actors": 61,
		"mean_ms": 3.457,
		"mean_projectiles": 319.4,
		"p50_ms": 3.343,
		"p99_ms": 5.988,
		"realtime_x": 4.8,
		"scene": "stress",
		"walls": 40
	},
	"stress_in_band": false
}
```

## Target bands
| Metric | Target | Source |
|---|---|---|
| Stress: mean tick | ≤ 2 ms | ARCHITECTURE §13; owner decision 2026-10-06 |
| Stress: p99 tick | ≤ 4 ms | same |
| Reference: headless speed | ≥ 15× real time | same (O5: applies to the reference scene) |

## Result
| Metric | Measured | In band? |
|---|---|---|
| Stress: mean tick (61 actors, 319.4 projectiles on average, 40 walls) | 3.457 ms | **No** |
| Stress: p99 tick | 5.988 ms | **No** |
| Reference: headless speed (13 actors, 40.9 projectiles, 12 walls) | 31.2× | Yes |
| Owner's PC, both scenes | — | OWNER ONLY |

## How the scenes were made to carry their load
The first stress run averaged 13.6 projectiles, not ~300: the movers crowded the player and every shot hit within a
few ticks, so the scene wasn't the scene in the target. Two bench-only knobs were added to `World` (off by default,
so the golden hash is unchanged): movers keep 9 m from the player, and shots get up to ±45° aim error. The fire
period was then set so the scenes average 319 and 41 live projectiles.

## What was measured and changed (not tuned blind)
A per-phase profile of the stress scene (3,600 ticks, `build/profile_phases.gd`, not committed):

| Phase | Before (ms/tick) | After (ms/tick) |
|---|---|---|
| input + AI | 0.170 | 0.172 |
| move and collide | 1.225 | 1.435 |
| projectile sweeps | 3.046 | 1.733 |
| spawns | 0.090 | 0.090 |

Two behaviour-identical fixes came from it: the projectile query box no longer grows by an unneeded 1 m, and grid
cells use reference arrays instead of packed arrays copied on every insert. The 10,000-tick replay golden's final
hash is unchanged (`cc9224c8…`), so outcomes did not move. Mean went 4.532 → 3.457 ms, p99 6.970 → 5.988 ms.

## Interpretation
- GDScript runs this kernel's *reference* encounter at about 31× real time, so headless sims are affordable.
- The *stress* scene (60 enemies, ~300 projectiles, 40 walls) costs about 3.5 ms per tick on this 2.1 GHz cloud
  CPU. That is a fifth of a 16.7 ms frame, but over the agreed 2 ms. A desktop CPU may be faster; that is
  unmeasured.
- Per the rule, the step stops here and the owner decides. Options:
  1. measured optimization of collide and sweeps (e.g. fewer actor-pair checks, cheaper queries), then re-bench;
  2. lower the stress scene to what the game will really field;
  3. move the hot loops to a GDExtension (ARCHITECTURE §13 fallback, an EI change);
  4. re-check on the owner's PC before deciding.

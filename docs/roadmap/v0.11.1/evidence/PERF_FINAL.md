# PERF_FINAL: the frame and the tick on the final code of v0.11.1

- **Status:** RUN
- **Build:** `c7a2dfbc` on `lead-merge` (clean worktree `wt-seams`): the native core the only sim (step 54b), steps
  55b, 55c, 58, 60 and the Ring fix (62) in; the library built by `bash scripts/native/build.sh all`; Godot
  `4.7.2.stable.official.ed1daf0bf`
- **Machine:** the owner's PC (i7-10700K, RTX 3060). No other Godot process ran (`tasklist` counted 0 at 13:57, 14:14
  and 14:28) and no agent was running. **The owner was awake and the Claude desktop app was open** (the earlier quiet
  runs were made at night with the owner asleep); the lead did not record what else was running. The back-to-back
  part below is there because of that.
- **Date:** 2026-11-11
- **Who ran it:** agent (the lead), after the owner said the PC was free ("Yes, start it")
- **Before:** [`PERF_W8.md`](PERF_W8.md) (`9bea0088`, at night), and the same build measured again here

## Commands
```
godot --headless --path . -s scripts/checks/horde_phases.gd -- --counts=20,60,120 --ticks=1800        (two rounds)
godot --path . --resolution 1920x1080 --windowed --position -10000,-10000 -s scripts/checks/frame_probe.gd -- --biome=red_canyon [scene] --secs=15 --spans
```
three rounds, the six scenes in turn inside each round: 20 enemies (no scene argument: the probe's default build,
which holds the Ring), `--enemies=60 --heavy --fx`, `--enemies=120 --only=swarmer`, `--cards=none` (the Gun alone, 20
enemies), `--cards=gun_ring` (Gun + Ring, 20 enemies), `--enemies=60 --cards=gun_ring`.

**Back to back** (14:15–14:28, the same worktree switched to `9bea0088` and back, the library rebuilt and the project
imported twice each time): the 20-enemy and the 120-swarmer scenes, three rounds each, `9bea0088` with
`--native=all`, then `c7a2dfbc`.

## Raw output
The tick (`horde_phases`, ms; round 1 / round 2):
```
enemies=20   step mean 0.319 / 0.325  p99 0.829 / 0.836  max 6.019 / 6.119
enemies=60   step mean 0.416 / 0.417  p99 0.981 / 0.977  max 6.301 / 6.133
enemies=120  step mean 0.536 / 0.533  p99 1.390 / 1.410  max 6.533 / 6.393
outcome_hash  20: 8c3d9369b45a8cbd8b76abfb3659ab14350193e6d14a0ddb73ed38ce8b8ba160 (both rounds)
              60: d98fd9bbddd52cd65e4b532297879f6192166a62ca27a6e63ae4dee2b0ecf029 (both rounds)
             120: 1186daed1384272ab810772266449421597d917a2d023ee4968adbe1ca41cbc2 (both rounds)
```
The frame (avg_ms / 1 % low fps; rounds 1, 2, 3):
```
20 enemies (default build)   8.486/44.7   10.014/43.2   8.956/43.4
60 heavy fx                  24.142/19.9  24.513/20.9   24.179/21.8
120 swarmers                 15.370/34.1  15.247/32.7   15.778/32.0
Gun alone, 20                6.920/69.0   7.069/70.2    6.995/71.6
Gun + Ring, 20               7.922/59.1   7.916/55.9    7.915/59.7
Gun + Ring, 60               22.456/24.7  21.046/25.1   20.304/26.7
```
Spans (µs a frame, mean):
```
20 enemies r1    nodes_process=4116   after_process=905   draw=2369  nodes_physics=605   physics_post=78
60 heavy r2      nodes_process=11535  after_process=2740  draw=5747  nodes_physics=3178  physics_post=521
120 swarmers r2  nodes_process=7993   after_process=1410  draw=3359  nodes_physics=1949  physics_post=94
Gun alone r1     nodes_process=3580   after_process=489   draw=1985  nodes_physics=426   physics_post=55
Gun + Ring r1    nodes_process=3949   after_process=790   draw=2205  nodes_physics=494   physics_post=77
```
Back to back (avg_ms / 1 % low fps; rounds 1, 2, 3):
```
20 enemies    9bea0088  9.526/43.1   8.192/44.1   9.046/43.0
              c7a2dfbc  8.525/46.1   8.141/49.6   9.401/42.8
120 swarmers  9bea0088  17.786/26.3  19.285/27.3  17.949/29.7
              c7a2dfbc  15.952/30.7  15.612/33.1  15.602/30.7
```
The first import of the main run ended in a segmentation fault when the editor quit (`import1.log`: the import itself
had finished); the second import was clean, and the four imports of the back-to-back part exited 0. The reports are
under `build/perf_final/` and `build/perf_ab/` in the lead's worktree (not tracked).

## Target bands
| Metric | Target | Source |
|---|---|---|
| Frame | never under 60 fps; up to 144 fps when the scene allows | LOCKED_DECISIONS 2026-11-11 (owner Q1) |
| Horde tick (120 enemies) | mean ≤ 4 ms | v0.4.0 PLAN "Performance" |

## Result
| Scene | `9bea0088` at night (PERF_W8) | `9bea0088` today | `c7a2dfbc` today (mean of three) | Never under 60 fps? |
|---|---|---|---|---|
| 20 enemies | 8.2 ms | 8.9 ms | 9.2 ms in the main run, 8.7 ms back to back; 1 % low 43–50 fps | No (the average is 109–115 fps) |
| 60 enemies, heavy build | 24.9 ms | not measured | 24.3 ms (41 fps); 1 % low 20–22 fps | No |
| 120 swarmers | 18.5 ms | 18.3 ms | 15.5 ms in the main run, 15.7 ms back to back (64 fps); 1 % low 31–34 fps | No |
| Gun alone, 20 enemies | — | — | 7.0 ms (143 fps); 1 % low 69–72 fps | Yes |
| Gun + Ring, 20 enemies | — | — | 7.9 ms (126 fps); 1 % low 56–60 fps | At the line |
| Gun + Ring, 60 enemies | — | — | 21.3 ms (47 fps); 1 % low 25–27 fps | No |

| Tick | Before the flip (PERF_NATIVE, `68b92b18`) | `c7a2dfbc` | In band? |
|---|---|---|---|
| 120 enemies | 0.55–0.58 ms, p99 1.4–1.5 ms, max 6.1 ms | 0.53–0.54 ms, p99 1.4 ms, max 6.4–6.5 ms | Yes |
| 60 / 20 enemies | 0.43–0.46 / 0.33–0.34 ms | 0.42 / 0.32–0.33 ms | — |

## Interpretation
- **The 120-swarmer frame is 2.6 ms shorter than at PERF_W8's build** (18.3 → 15.7 ms back to back, in all three
  rounds): steps 55b, 55c, 58 and 60. Its 1 % lows rose from 26–30 to 31–33 fps.
- **The 20-enemy frame did not change** (8.9 against 8.7 ms back to back, inside the spread of the rounds). The main
  run's 9.2 ms against PERF_W8's 8.2 ms is the machine, not the code: PERF_W8's own build measures 8.9 ms today.
  Today's numbers are about 0.7 ms higher than the night's in this scene.
- **The 60-enemy heavy frame is within 0.6 ms of PERF_W8's** (24.3 against 24.9 ms, measured on different days: not
  separated from the machine's difference).
- **The Ring costs 0.9 ms a frame over the Gun alone at 20 enemies** (7.0 → 7.9 ms). It cost 4.7 ms before step 62
  (12.80 against 8.1 ms, the Ring agent's busy-machine runs).
- **The tick is unchanged by the flip** (0.54 ms at 120 enemies), and each scene's two rounds give the same hash.
- **The probe scenes do not meet "never under 60 fps"**, judged on their 1 % lows, except the Gun alone. These scenes
  keep N enemies alive with fire held for the whole run. What the owner sees in real play ("barely falls under 60
  fps", 2026-11-11, before step 55c) is theirs to report: OWNER ONLY.
- **Where a 120-swarmer frame goes now:** scripts and views 8.0 ms (10.9 at PERF_W8), the draw 3.4 ms, the sim's
  span 1.9 ms, the engine's work after scripts 1.4 ms.
- **What this does not show:** why the editor crashed once on quitting after an import (one time in six imports
  today; not reproduced); the 60-enemy heavy scene back to back.

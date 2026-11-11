# PERF_W8: the frame after the first display-layer steps (55, 57, 59), and what each is worth

- **Status:** RUN (steps 55b and 58 are not in it: they were started after this run)
- **Build:** `9bea0088` on `lead-merge` (clean worktree `wt-seams`): the native core on, steps 55 (enemies batched),
  57 (lightning bolts by shader), 59 (the HUD) merged; the library built; Godot `4.7.2.stable.official.ed1daf0bf`
- **Machine:** the owner's PC (i7-10700K, RTX 3060). No other Godot process ran (`tasklist` counted 0 at 04:36 and at
  05:07); no agent was running; the owner was asleep.
- **Date:** 2026-11-11
- **Who ran it:** agent (the lead)
- **Before:** [`PERF_NATIVE.md`](PERF_NATIVE.md)'s attribution baselines (`68b92b18`, the same machine, 15 s runs,
  `--spans`, native on)

## Commands
```
godot --path . --resolution 1920x1080 --windowed --position -10000,-10000 -s scripts/checks/frame_probe.gd -- --biome=red_canyon [scene] --secs=15 --spans --native=all [--ab=no_still | --ab=no_hud | --ab=no_batch]
```
three rounds, the four variants in turn inside each round. The scenes: 20 enemies (no scene argument),
`--enemies=60 --heavy --fx`, `--enemies=120 --only=swarmer`. `no_still`: the HUD's still-part textures off (its redraw
fixes stay); `no_hud`: the HUD hidden; `no_batch`: the enemy batch off (every enemy a node again).

## Raw output
avg_ms / 1 % low fps, rounds 1, 2, 3:
```
20 enemies    base      7.657/45.7   9.165/41.2   7.803/42.9
              no_still  8.567/48.4   9.284/45.0   8.716/42.2
              no_hud    7.465/46.6   6.951/50.5   7.579/48.4
              no_batch  9.704/46.0   7.624/42.6   7.751/47.0
60 heavy fx   base      24.600/19.8  25.859/18.8  24.282/19.4
              no_still  25.505/21.1  22.401/21.3  24.763/19.9
              no_hud    23.435/22.4  22.756/21.2  24.403/21.2
              no_batch  25.354/21.1  24.057/23.2  25.318/20.6
120 swarmers  base      19.375/25.8  19.221/28.1  17.010/29.1
              no_still  18.311/26.8  19.625/25.2  18.014/29.2
              no_hud    17.922/29.8  17.190/31.5  17.228/28.8
              no_batch  19.913/26.9  17.643/26.0  18.474/24.9
```
Spans of round 1 (µs a frame, mean):
```
120 base      nodes_process=10872  after_process=1573  draw=3634  nodes_physics=2655  physics_post=171  sum=19375
120 no_batch  nodes_process=10724  after_process=1844  draw=3881  nodes_physics=2621  physics_post=346  sum=19913
120 no_hud    nodes_process=10650  after_process=909   draw=3390  nodes_physics=2451  physics_post=164  sum=17922
20  base      nodes_process=3684   after_process=791   draw=2189  nodes_physics=540   physics_post=70   sum=7657
20  no_hud    nodes_process=3773   after_process=592   draw=2181  nodes_physics=548   physics_post=69   sum=7465
```
The reports are under `build/perf_w8/` in the lead's worktree (not tracked).

## Target bands
| Metric | Target | Source |
|---|---|---|
| Frame | every frame under 6.94 ms (144 fps), judged on the 1 % lows | v0.9.5 PF |

## Result
| Scene | `68b92b18` (native on) | `9bea0088` (mean of three) | In band? |
|---|---|---|---|
| 20 enemies | 11.8 ms (mean of 7 baselines) | 8.2 ms (122 fps); 1 % low 41–46 fps | No |
| 60 enemies, heavy build | 27.7 ms (mean of 9) | 24.9 ms (40 fps); 1 % low 19–20 fps | No |
| 120 swarmers | 22.2 ms (mean of 15) | 18.5 ms (54 fps); 1 % low 26–29 fps | No |

| What it is worth now (base against the variant, mean of three) | 20 enemies | 60 heavy | 120 swarmers |
|---|---|---|---|
| The HUD's remaining cost (`no_hud`) | 0.9 ms (it was 2.4) | 1.4 ms (2.2) | 1.1 ms (1.9) |
| The HUD's still textures (`no_still` is without them) | 0.65 ms better with them, in all three rounds | inside the spread | inside the spread |
| The enemy batch (`no_batch` is without it) | inside the spread | inside the spread | 0.15 ms, inside the spread |

## Interpretation
- **The frame is 2.7 to 3.7 ms shorter than before these steps** in every scene; the 20-enemy scene is at 122 fps on
  average. The 1 % lows are still far from the target.
- **The HUD now costs about 1 ms** where it cost about 2. Its still-part textures are kept on: with 20 enemies they
  win in every round, and in the horde scenes the difference is inside the spread (the HUD agent's busy-machine runs
  had suggested they might lose in the heavy scene; this run does not show that).
- **Taking the enemies' nodes out of the tree is worth almost nothing by itself** (0.15 ms at 120 swarmers): the cost
  PERF_NATIVE measured with `detach_actors` is the per-enemy script loop and the bodies' drawing, which step 55 kept.
  Step 55b (posing and writing the batch from the sim's columns in C++) goes after that loop: about 4 ms by step
  55's own breakdown.
- **Where a 120-swarmer frame goes now:** scripts and views 10.9 ms, the draw 3.6 ms, the sim's span 2.7 ms, the
  engine's work after scripts 1.6 ms.
- **What this does not separate:** step 57's share (the lightning bolts) from the HUD's redraw fixes inside the
  2.7–3.7 ms; the scene runs were 15 s here and 20 s in PERF_NATIVE's off-against-on table, so compare with its
  attribution baselines (15 s), as the Result table does.

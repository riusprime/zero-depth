# PERF_NATIVE: the tick and the frame with the native kernels off against on, and where a frame goes

- **Status:** RUN
- **Build:** `68b92b18` on `lead-merge` (clean worktree `wt-seams`; every native kernel merged, off by default); the
  library built by `bash scripts/native/build.sh all`; Godot `4.7.2.stable.official.ed1daf0bf`; Windows 11 Pro
- **Machine:** the owner's PC (i7-10700K, RTX 3060). No other Godot process ran (`tasklist` counted 0 at the start of
  the quiet part, 01:07, and at the end, 02:12); no agent was running; the owner was asleep.
- **Date:** 2026-11-11
- **Who ran it:** agent (the lead)

## Commands
```
godot --headless --path . -s scripts/checks/horde_phases.gd -- --counts=20,60,120 --ticks=1800 --native=0|all      (two rounds each)
godot --path . --resolution 1920x1080 --windowed --position -10000,-10000 -s scripts/checks/frame_probe.gd -- --biome=red_canyon [scene] --secs=20 --spans --native=0|all   (three rounds each, alternating)
NATIVE=all SWITCHES="ab:detach_actors ab:hide_actors ab:no_hud ab:no_fti ab:no_particles ab:no_anim" bash scripts/checks/frame_attribution.sh swarm120 15
NATIVE=all SWITCHES="ab:detach_actors ab:no_hud ab:no_particles" bash scripts/checks/frame_attribution.sh heavy60 15
NATIVE=all SWITCHES="ab:no_hud ab:no_particles" bash scripts/checks/frame_attribution.sh enemies20 15
```
The scenes: 20 enemies (no scene argument), `--enemies=60 --heavy --fx`, `--enemies=120 --only=swarmer`. `--spans` cuts
the frame into consecutive spans that sum to it; these runs are a little slower than PERF_AFTER's plain ones (its
stamp nodes), so compare inside this page only.

## Raw output
The tick (`horde_phases`, ms; round 1 / round 2):
```
                 script (native=0)                          every kernel (native=all)
enemies=20   step mean 0.928 / 0.997  p99 1.848 / 2.334    step mean 0.327 / 0.337  p99 0.891 / 0.939
enemies=60   step mean 1.842 / 1.893  p99 3.135 / 3.345    step mean 0.430 / 0.458  p99 1.081 / 1.177
enemies=120  step mean 3.323 / 3.350  p99 5.319 / 5.311    step mean 0.547 / 0.577  p99 1.425 / 1.535
             max 14.691 / 14.848                            max 6.108 / 6.125
outcome_hash at 120: script 14f2fbce4fb2e51c13976d0e0b6f3b1424a72563957855b01c3c11a4f5abbcad (both rounds)
                     native a769a0c276eb2066315b498e0590acb23553d324722783b5dea9a03eb5ccbd94 (both rounds)
```
The frame (`frame_probe --spans`, avg_ms and 1 % low fps; rounds 1 / 2 / 3):
```
20 enemies     script  12.825 / 12.675 / 13.684   1pct_low 31.3 / 37.0 / 31.4
               native  12.156 / 12.489 / 12.457   1pct_low 37.0 / 31.3 / 36.9
60 heavy fx    script  28.765 / 32.028 / 30.116   1pct_low 18.3 / 16.2 / 17.5
               native  28.664 / 28.862 / 27.055   1pct_low 19.3 / 16.4 / 17.7
120 swarmers   script  25.691 / 25.012 / 24.497   1pct_low 19.9 / 18.8 / 20.1
               native  21.100 / 23.102 / 22.311   1pct_low 22.5 / 21.2 / 22.6
```
The spans of round 1 (µs a frame, mean):
```
120 script  nodes_process=11325  after_process=2728  draw=4499  after_draw=308  nodes_physics=5801  physics_post=799  sum=25691
120 native  nodes_process=10310  after_process=2533  draw=4278  after_draw=308  nodes_physics=2800  physics_post=671  sum=21100
60  script  nodes_process=11898  after_process=3503  draw=6423  after_draw=314  nodes_physics=5352  physics_post=978  sum=28765
60  native  nodes_process=12746  after_process=3606  draw=6815  after_draw=307  nodes_physics=3849  physics_post=1031 sum=28664
20  script  nodes_process=5411   after_process=1868  draw=3369  after_draw=336  nodes_physics=1430  physics_post=291  sum=12825
20  native  nodes_process=5264   after_process=1844  draw=3315  after_draw=325  nodes_physics=1031  physics_post=264  sum=12156
```
`nodes_process` is the scripts and views of the frame (the views' sync is in it); `nodes_physics` holds the sim's
ticks and their listeners; `draw` is the engine's draw with the present; `after_process` is the engine's queued work
after the scripts (redraws, transforms, the delete queue).

The attribution, every kernel on (`summary.txt`, per switch: the mean of its two runs against the mean baseline):
```
swarm120   baseline: 15 runs, mean avg_ms 22.153, spread (max - min) 2.912
  ab_detach_actors   16.124   -6.029   beyond the spread: yes
  ab_hide_actors     19.893   -2.260   no
  ab_no_hud          20.209   -1.944   no
  ab_no_fti          20.887   -1.266   no
  ab_no_particles    23.172   +1.019   no
  ab_no_anim         23.534   +1.380   no
heavy60    baselines 25.949 – 30.421 (9 runs)
  ab_detach_actors   18.779   -8.870   yes
  ab_no_hud          25.442   -2.208   no
  ab_no_particles    28.025   +0.375   no
enemies20  baselines 11.381 – 12.267 (7 runs)
  ab_no_hud           9.370   -2.426   yes
  ab_no_particles    11.803   +0.008   no
```
`detach_actors` takes the actors' nodes out of the tree while the sim still runs them; `hide_actors` only hides them;
`no_hud` hides the HUD layer; `no_fti` turns the physics interpolation off. The full reports are under
`build/perf_native/` and `build/attribution/` in the lead's worktree (not tracked).

## Target bands
| Metric | Target | Source |
|---|---|---|
| Horde tick (120 enemies) | mean ≤ 4 ms | v0.4.0 PLAN "Performance" |
| Frame | every frame under 6.94 ms (144 fps), judged on the 1 % lows | v0.9.5 PF |

## Result
| Metric | Script | Native | In band? |
|---|---|---|---|
| Tick at 120 enemies | 3.32–3.35 ms, p99 5.3 ms, max 14.7 ms | 0.55–0.58 ms, p99 1.4–1.5 ms, max 6.1 ms | Yes |
| Tick at 60 / 20 enemies | 1.84–1.89 / 0.93–1.00 ms | 0.43–0.46 / 0.33–0.34 ms | — |
| Frame, 120 swarmers | 25.1 ms (mean of three) | 22.2 ms | No |
| Frame, 60 enemies, heavy build | 30.3 ms | 28.2 ms | No |
| Frame, 20 enemies | 13.1 ms | 12.4 ms | No |

## Interpretation
- **The tick is 6 times cheaper at 120 enemies** (3.3 → 0.56 ms), and its worst tick fell from 14.7 to 6.1 ms. The
  native run replays itself: both rounds give the same hash.
- **The frame gains 2 to 3 ms in the horde scenes and under 1 ms in the light one.** The sim's span in a horde frame
  fell from 5.8 to 2.8 ms: what is left there is the hero's own systems and the per-tick listeners, which were not
  ported, and more than one tick a frame while the frame is over 16.7 ms.
- **The enemies' nodes are the largest single cost of a frame: 6.0 ms at 120 swarmers and 8.9 ms at 60 with the
  heavy build** (`detach_actors`, well beyond the run-to-run spread). Hiding them saves only 2.3 ms, so most of it is
  updating and processing the nodes, not drawing them. The swarmers' bodies are already crowd instances: the cost is
  the node each enemy still has (its root, disc, ring, bar) and its per-frame update. This is step 55's target.
- **The HUD costs about 2.0–2.4 ms a frame in every scene** (beyond the spread in the 20-enemy scene, where it is a
  fifth of the frame). The plan had dropped the HUD's redraw step because its scripts measure under 0.3 ms: the cost
  is the engine's 2D drawing (389 draw calls, about 14 controls redrawn a frame), which no script bucket shows.
- **Particles, animation players and the physics interpolation show no gain** beyond the spread.
- **What this does not show:** how much of the enemies' 6–9 ms an instanced replacement gives back (it has its own
  cost), and the split of `nodes_process` between the effects layer and the other views.

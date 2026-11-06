# PB_SHADOWS: particles and most torches cast no shadow; a cheaper sun shadow to try

- **Status:** RUN
- **Build:** branch `v0105-pb` cut from `1f309fd5`. Every tool prints `sha=1f309fd5`: the "before" runs ran on that
  tree unchanged, the "after" runs on the same tree with this step's changes uncommitted. The step's commit is the one
  that adds this file. Godot `4.7.2.stable` (`Godot_v4.7.2-stable_win64_console.exe`); Windows 11 Pro 10.0.26200.
- **Machine:** the owner's PC, i7-10700K, RTX 3060 (the tools read `NVIDIA GeForce RTX 3060`, Forward+), 1920 x 1080
  windowed, off screen (`--position -10000,-10000`). **Other agents (PA, PC, PD) ran Godot jobs on this PC at the same
  time**, so the frame times in §3 are noise (one run each, as asked); the draw-call counts are not timing.
- **Date:** 2026-11-02
- **Who ran it:** agent

Why: the owner's answers in PLAN "Perf wave 2" (options 3, 4, 8), from DRAW_CALLS.md: 123 particle draws in the sun's
shadow in a 60-enemy fight, 4 shadowed torches the biggest shadow source on a quiet floor (104 draws), the sun's shadow
pass 98.

## What changed

| # | Owner | Change | Where |
|---|---|---|---|
| 1 | "yes particles should not draw shadows" | Every GPUParticles3D and CPUParticles3D under the floor's view and the hub casts no shadow. **One central place:** a `ParticleShadowOff` node (a `node_added` hook filtered to its parent's subtree, plus a scan of what is already there), added first under `WorldViewRoot` and under `HubView`; no pool or effect file is edited. `RenderSwitches.PARTICLES_NO_SHADOW` (switch 6) turns it off. | `src/presentation/world_view/particle_shadow_off.gd` |
| 2 | "go for it" (fewer torch shadows) | `StageKit.SHADOW_LIGHTS` 4 → **2**: the two torches nearest the view's focus keep their (faded, dual-paraboloid) shadows, the rest light without one. Picked over 0 because the near torch's shadows round the hero and the props are most of the torch look (room 2 shots); over 3 because 2 halves the cost. Every other kit or effect OmniLight already cast none. | `stage_kit.gd` |
| 3 | "let's try before and after" (cheaper sun) | **Not the default.** Switch 8: project setting `game/render/cheap_sun_shadow` (project.godot, `false`), or `-- --cheap-sun` on the command line. | `render_switches.gd`, `stage_view.gd`, `iso_rig.gd` |

The sun, current → proposed (switch 8 on):

| Setting | Current | Proposed |
|---|---|---|
| Mode / splits | `SHADOW_ORTHOGONAL` (1 split) | the same (already the fewest) |
| Shadow max distance | 80 m | 76 m (the ground is 48-72 m from the camera) |
| Iso camera near plane (the orthographic camera's shadow covers near..max distance) | 0.1 m | 30 m |
| Directional shadow atlas | 4096 (project.godot) | 2048 |
| Soft shadow filter | 4, high (project.godot) | 3, medium |

## 1. Commands

```
export APPDATA=$(mktemp -d)    # a fresh one for every run
G="C:/Users/extri/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
# census, quiet floor and the 60-enemy fight; tag before | after12 | cheapsun (cheapsun adds --cheap-sun)
"$G" --path . --position -10000,-10000 --resolution 1920x1080 --windowed --audio-driver Dummy \
  -s scripts/checks/draw_census.gd -- --biome=red_canyon --tag=pb_<tag> --shot [--cheap-sun]
"$G" --path . --position -10000,-10000 --resolution 1920x1080 --windowed --audio-driver Dummy \
  -s scripts/checks/draw_census.gd -- --biome=red_canyon --fight=60 --tag=pb_<tag> --shot [--cheap-sun]
# frame probe, PERF_Q5 base60
"$G" --path . --position -10000,-10000 --resolution 1920x1080 --windowed -s scripts/checks/frame_probe.gd -- \
  --biome=red_canyon --heavy --fx --secs=20 --warm=4 --enemies=60 [--cheap-sun]
```

The two census runs of a configuration ran at the same time; the probes ran one at a time (other agents' jobs aside).
Logs: `build/pb/census_{room,fight}_{before,after12,cheapsun}.log`, `build/pb/probe60_{before,after12,cheapsun}.log`
(untracked).

## 2. Draw calls (`draw_census.gd`)

Quiet floor, mean over the 5 rooms (raw rows):

```
== before (tag=pb_before)
  OmniLight3D: 369 (shown 21, shadow on 4)  shadow-casting geometry shown: 621
all shown (total)                                398    2303    876731 |    110     133 |    161     228 |    127
lights: torch shadows                             68      86    154273 |      0       0 |     68      86 |      0
lights: sun shadow                                93     142    204951 |      0       0 |     93     142 |      0
== after 1+2 (tag=pb_after12)
  OmniLight3D: 369 (shown 21, shadow on 2)  shadow-casting geometry shown: 617
all shown (total)                                373    2283    810168 |    110     133 |    133     193 |    129
lights: torch shadows                             40      50     87669 |      0       0 |     40      50 |      0
lights: sun shadow                                93     142    204951 |      0       0 |     93     142 |      0
== after 1+2 + cheaper sun (tag=pb_cheapsun)
  OmniLight3D: 369 (shown 21, shadow on 2)  shadow-casting geometry shown: 617
all shown (total)                                377    2283    810168 |    112     133 |    136     193 |    129
lights: torch shadows                             40      50     87669 |      0       0 |     40      50 |      0
lights: sun shadow                                95     142    204951 |      0       0 |     95     142 |      0
```

60-enemy fight (one paused frame, median of ~97 readings; the fight is not the same frame from run to run, so its
camera rows move by themselves):

```
== before
  particles: 561 (emitting and shown: 155)
all shown (total)                               2056    2896   5366074 |   1377    1540 |    230     275 |    449
lights: sun shadow                               231     275   2380970 |      1       0 |    230     275 |      0
  view: PackFx                                   518     519   4597676 |    443     444 |     75      75 |      0
== after 1+2
  particles: 588 (emitting and shown: 150)
all shown (total)                               1992    2862   3438826 |   1373    1542 |    166     211 |    453
lights: sun shadow                               167     211    479981 |      1       0 |    166     211 |      0
  view: PackFx                                   461     457   2659702 |    455     451 |      6       6 |      0
== after 1+2 + cheaper sun
  particles: 599 (emitting and shown: 140)
all shown (total)                               1848    2629   3899323 |   1230    1331 |    164     190 |    453
lights: sun shadow                               164     190    475869 |      0       0 |    164     190 |      0
  view: PackFx                                   451     450   3232802 |    442     440 |      9      10 |      0
```

| | Quiet floor draws (shadow) | 60-enemy fight draws (shadow) |
|---|---|---|
| before | 398 (161) | 2,056 (230) |
| after 1+2 | 373 (133): torch shadows 68 → 40 | 1,992 (166): the pack's shadow draws 75 → 6, the sun's pass 230 → 166 |
| after 1+2 + cheaper sun | 377 (136) | 1,848 (164) |

What it says: 1 and 2 cut the shadow passes by 28 draws on a quiet floor and 64 in the fight. The cheaper sun cuts
**no draws** (the sun's pass 93 → 95 quiet, 166 → 164 in the fight: the same casters); its 2048 atlas, medium filter and
tighter fit save GPU fill, not draw calls. The fight's lower camera count with it (1,373 → 1,230) is a different
fight frame, not the sun (nothing is missing in the cheaper-sun fight and room shots looked at; the camera's near plane at 30 m is far above the tallest thing on the floor).

## 3. Frame probe, 60 enemies (PERF_Q5 base60), one run each

```
== before
frame_probe  sha=1f309fd5  biome=red_canyon  ab=none
frames=608  avg_ms=32.946  p50_ms=31.993  p95_ms=47.396  p99_ms=59.155
1pct_low_fps=12.5 (1000 / mean of the slowest 7 frames)  max_ms=131.995  over_6.94ms=608 (100.00 %)  avg_fps=30.4
render_cpu_ms_avg=2.824  render_gpu_ms_avg=9.723  (RenderingServer viewport measured time)
== after 1+2
frame_probe  sha=1f309fd5  biome=red_canyon  ab=none
frames=554  avg_ms=36.107  p50_ms=34.371  p95_ms=53.358  p99_ms=67.255
1pct_low_fps=10.4 (1000 / mean of the slowest 6 frames)  max_ms=139.778  over_6.94ms=554 (100.00 %)  avg_fps=27.7
render_cpu_ms_avg=2.985  render_gpu_ms_avg=10.163  (RenderingServer viewport measured time)
== after 1+2 + cheaper sun
frame_probe  sha=1f309fd5  biome=red_canyon  ab=none
frames=564  avg_ms=35.466  p50_ms=34.224  p95_ms=49.546  p99_ms=69.630
1pct_low_fps=10.9 (1000 / mean of the slowest 6 frames)  max_ms=141.673  over_6.94ms=564 (100.00 %)  avg_fps=28.2
render_cpu_ms_avg=2.863  render_gpu_ms_avg=9.272  (RenderingServer viewport measured time)
```

**Not a measured gain.** The "after" runs were slower on average than "before" (33.0 → 36.1 / 35.5 ms) while three other
agents ran Godot on the same PC; the probe's frame is mostly not the renderer (render GPU ~9-10 ms of ~33-36 ms), and
one run each on a busy machine cannot show a ~60-draw change. A clean timing: `NOT YET RUN (owner hardware, idle)`.

## 4. Shots for the owner (untracked)

`build/shots/v0.10.5/pb/`, the same camera on the hero each time (census spots):

| View | before | after 1+2 | after 1+2 + cheaper sun |
|---|---|---|---|
| A normal room with torches (spot 2) | `room2_before.png` | `room2_after12.png` | `room2_after12_cheapsun.png` |
| The start room (spot 0) | `room0_before.png` | `room0_after12.png` | `room0_after12_cheapsun.png` |
| The 60-enemy fight | `fight60_before.png` | `fight60_after12.png` | `fight60_after12_cheapsun.png` |

The fight shots are different moments of the fight (it runs in real time), so compare the light, not the enemies.
Which sun to keep: `OWNER ONLY`. To turn the cheaper sun on: `render/cheap_sun_shadow=true` under `[game]` in
project.godot.

## 5. Tests

```
"$G" --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/unit/presentation/test_particle_shadow_off.gd,res://tests/unit/presentation/test_stage_kit_lights.gd -gexit
res://tests/unit/presentation/test_particle_shadow_off.gd
    particle systems under the view: 416 (shown: 11)
3/3 passed.
res://tests/unit/presentation/test_stage_kit_lights.gd
6/6 passed.
Tests                 9
Passing Tests         9
Asserts              64

"$G" --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/e2e/test_e2e_horde_enemies.gd -gexit
res://tests/e2e/test_e2e_horde_enemies.gd
2/2 passed.
Tests                 2
Passing Tests         2
Asserts              43
```

`test_stage_kit_lights.gd`'s swap test placed its challenger for a budget of 4 (it failed at 2: the keeper never
handed over); the challenger now sits 4 m past the row, so it holds for any budget. Lint: `gdformat --check` and
`gdlint` clean on every touched file.

# VAT_PILOT: the Swarmer drawn from baked poses (W3-V1)

Owner, 2026-11-06: "Can you start working on that while I play the run and then we check the logs and the increase
from VAT?" (PLAN W3-V1, OWNER_QUESTIONS "Enemy VAT"). Presentation only (EI-07): no sim change, no golden change.
The switch is off by default (the old path) until the owner signs the look off (G2).

- Machine: the owner's PC (i7-10700K, RTX 3060), Godot 4.7.2 stable, Forward+, Windows. The owner had finished their
  run; the lead was analysing a CSV in Python at the same time (one core, light). Each frame_probe ran alone.
- Build: commit `2a352807` (the phase-1 WIP) plus the phase-2 fixes. The bake, the sheet, the motion check and the
  probes ran on that working tree; the reports print `sha=2a352807`. All of it is committed in the step's commit
  (`v0.10.5 W3-V1: …`, the commit that adds this file).
- Raw outputs: `build/vat/2a352807_bake.txt`, `build/vat/motion_check.txt`, `build/vat/tests1.txt`,
  `build/vat/tests2.txt`, `build/shots/v0.10.5/vat/vat_sheet.png` and `vat_diff.txt`, `build/perf/vat_probe_n*_*.log`
  and `build/perf/2a352807_red_canyon_*only-swarmer_vat-*.txt`.

## What was built

- The pilot kind is the **Swarmer**: the only horde kind spawned as a pack (`data/spawning/floor_1.tres`: weight 3,
  pack 8, about 24 bodies per pick weight; the Charger, next, weight 5 x 1). A code body with no death animation.
- `VatBake` builds the real `HordeAvatar` and runs its own `_pose()` (through `pose_at`) over a grid of its inputs.
  It bakes **joint transforms, not vertices**: 9 joints (body, 2 mandible hinges, 6 hips), each relative to its parent
  joint. Two grids in one RGBA32F texture (18 x 453 texels, 127 KiB): the stance, 9 x 9 x 5 over the windup raise x
  the strike x the crouch (trilinear in the shader), and the gait, a 48-sample loop of the legs (linear, wrapped). The
  idle bob and the rise-in are a lift of the whole body, sent per instance (exact). Baked once a session, in code
  (behind the loading cover through ShaderWarmup, or with the first VAT Swarmer), so it cannot go stale.
- `VatLooks`: the shader that poses each vertex from the texture; its shading is EnemyLooks' body and accent code,
  unchanged.
- `VatCrowd`: one MultiMesh per look (biome cast, role glow, palette). Per instance: the transform (the actor's
  interpolated place x its facing and the Void's lean x the avatar's flinch, lean, squash and knock, then the lift), the
  drives (raise, strike, crouch, gait phase), and the hit flash or status tint with the accent glow. Proxy shadows come
  from a second MultiMesh of the same stand-in EnemyShadows builds; "blob" mode keeps the blob node.
- Every Swarmer keeps its actor, facing and avatar nodes (with no pieces), so the sync, flinch, hit-stop, flash, tints,
  culling, bars and rings all run through the same code.
- Attach points: the Swarmer has none (status effects hang off the actor root and the bar height, hit sparks off the
  sim position). A socket would be one more baked joint.
- The switch: `ViewPrefs.enemy_vat`. It is set by the settings key `enemy_vat` ("off" by default), overridden by the
  launch flag `-- --enemy-vat=on|off`, and flipped at runtime by the dev panel's "Enemy VAT (Swarmers)" button, which
  rebuilds the Swarmers on the next sync.

## 1. Pose error (the bake against the live pose)

```
APPDATA=C:/Users/extri/Desktop/zerodepth/appdata-vat2 Godot_v4.7.2-stable_win64_console.exe --headless --path . -s scripts/checks/vat_bake_report.gd
```
```
vat bake report  sha=2a352807  godot=4.7.2-stable (official)
grids: stance (9, 9, 5) (wind x strike x crouch), gait 48 samples a loop
kind 11: 9 joints, 1380 vertices, 464 triangles, pose texture 18x453 RGBAF (127 KiB)
  bake ms (this machine, once a session): poses 10.0, mesh 2.1
  reduced_motion=false samples=4000 vertices/sample=1380  max_error_m=0.000455  mean_error_m=0.0000702
    worst at { "wind": 0.560407102108, "strike": 0.93703556060791, "crouch": 0.39855268597603, "t": 15.0157308578491, "rise": 0.41414001584053, "vertex": 344 }
  reduced_motion=true samples=4000 vertices/sample=1380  max_error_m=0.000455  mean_error_m=0.0000702
    worst at { "wind": 0.560407102108, "strike": 0.93703556060791, "crouch": 0.39855268597603, "t": 15.0157308578491, "rise": 0.41414001584053, "vertex": 344 }
```
**Max 0.455 mm, mean 0.07 mm.** For scale: at the game camera (17 m tall over 1080 px) one pixel is about 15.7 mm, so
the worst vertex is about 0.03 px off. The two runs are identical because the reduced-motion difference (no bob) is an
exact lift, not baked. This is the shader's arithmetic run on the CPU; the GPU path is checked by section 2.

## 2. Side-by-side sheet, old path (left) vs VAT (right): for the owner (G2)

```
APPDATA=C:/Users/extri/Desktop/zerodepth/appdata-vat Godot_v4.7.2-stable_win64_console.exe --path . --resolution 1920x1080 --position -10000,-10000 -s scripts/shots/vat_sheet.gd
```
Sheet: `build/shots/v0.10.5/vat/vat_sheet.png` (the script writes it under `build/shots/v0.9.0/vat/`, because
`GameVersion.label()` still says v0.9.0 on this branch; copied to v0.10.5 by hand). The 14 states are driven by the same
calls on both avatars. Per-pair image difference (220 x 220 px, MSAA 4x), raw:
```
state | max channel diff (0-255) | pixels off by > 8 | share
idle | 11 | 2 | 0.0000
scuttle (t 1.37 s) | 15 | 2 | 0.0000
windup 31 % | 131 | 11 | 0.0002
windup 90 % (flash) | 10 | 1 | 0.0000
strike snap (0.05 s) | 13 | 1 | 0.0000
strike out (0.15 s) | 15 | 1 | 0.0000
strike easing back | 5 | 0 | 0.0000
flinch at its peak | 8 | 0 | 0.0000
Blade knock | 8 | 0 | 0.0000
hit flash | 115 | 1 | 0.0000
status tint (burn) | 18 | 1 | 0.0000
rise-in, half way | 9 | 1 | 0.0000
biome cast + role glow | 10 | 1 | 0.0000
reduced motion + flinch | 8 | 0 | 0.0000
```
At most 11 of 48,400 pixels per state differ by more than 8/255: edge pixels where a sub-millimetre shift lands on the
other side of a silhouette edge. Whether that is "the same look" is the owner's call: `OWNER ONLY`.

## 3. Moving check (is the instance where the engine draws its actor on this frame?)

```
APPDATA=C:/Users/extri/Desktop/zerodepth/appdata-vat Godot_v4.7.2-stable_win64_console.exe --path . --position -10000,-10000 -s scripts/checks/vat_motion_check.gd
```
```
physics interpolation: true  frames compared: 599  fps ~56  fraction buckets seen: 11
instance x vs this frame's interpolated place: max 0.00000 m, mean 0.00000 m
instance x vs the last tick's place: max 0.04996 m, mean 0.02469 m
```
The instance follows the actor's interpolated place on the same frame. There is no one-frame lag; a stale read would
have been off by up to 5 cm at 3 m/s.

## 4. frame_probe: 20 / 60 / 100 Swarmers, VAT off vs on

One run each, one at a time, in this order: 20 off, 20 on, 60 off, 60 on, 100 off, 100 on (11:05–11:11). Command
(n = 20, 60, 100; v = off, on):
```
APPDATA=C:/Users/extri/Desktop/zerodepth/appdata-vat Godot_v4.7.2-stable_win64_console.exe --path . --resolution 1920x1080 --windowed --position -10000,-10000 -s scripts/checks/frame_probe.gd -- --biome=red_canyon --enemies=$n --only=swarmer --enemy-vat=$v
```
Raw lines (Playground room seed 4404, Gun build, warm-up 3 s, measured 30 s, enemy_shadows proxy):
```
n=20  off: frames=3166  avg_ms=9.476  p50_ms=9.146  p95_ms=14.243  p99_ms=20.238  1pct_low_fps=27.0  max_ms=128.634  avg_fps=105.5  render_cpu_ms_avg=1.152 render_gpu_ms_avg=3.269
n=20  on:  frames=3568  avg_ms=8.410  p50_ms=8.434  p95_ms=12.781  p99_ms=15.567  1pct_low_fps=54.4  max_ms=37.048   avg_fps=118.9  render_cpu_ms_avg=1.104 render_gpu_ms_avg=3.237
n=60  off: frames=1317  avg_ms=22.782 p50_ms=20.432 p95_ms=29.716  p99_ms=104.032 1pct_low_fps=6.7  max_ms=205.659  avg_fps=43.9   render_cpu_ms_avg=1.723 render_gpu_ms_avg=6.181
n=60  on:  frames=1711  avg_ms=17.539 p50_ms=16.982 p95_ms=24.052  p99_ms=33.375  1pct_low_fps=26.2 max_ms=55.534   avg_fps=57.0   render_cpu_ms_avg=1.553 render_gpu_ms_avg=5.317
n=100 off: frames=975   avg_ms=30.782 p50_ms=28.383 p95_ms=46.143  p99_ms=171.455 1pct_low_fps=3.6  max_ms=345.752  avg_fps=32.5   render_cpu_ms_avg=1.881 render_gpu_ms_avg=7.867
n=100 on:  frames=1270  avg_ms=23.630 p50_ms=22.912 p95_ms=34.457  p99_ms=50.834  1pct_low_fps=15.6 max_ms=79.368   avg_fps=42.3   render_cpu_ms_avg=1.773 render_gpu_ms_avg=6.759
```
Means of the 30 per-second samples (awk over the logs):
```
n=20 off: draw_calls 762  nodes 3146  primitives 361936
n=20 on:  draw_calls 749  nodes 2762  primitives 368797
n=60 off: draw_calls 1003 nodes 4308  primitives 612194
n=60 on:  draw_calls 995  nodes 3243  primitives 656141
n=100 off: draw_calls 1127 nodes 5026 primitives 751222
n=100 on:  draw_calls 1136 nodes 3618 primitives 842206
```
| Swarmers | avg ms off -> on | avg fps off -> on | 1 % low fps off -> on |
|---|---|---|---|
| 20 | 9.48 -> 8.41 (-11 %) | 105.5 -> 118.9 (+13 %) | 27.0 -> 54.4 |
| 60 | 22.78 -> 17.54 (-23 %) | 43.9 -> 57.0 (+30 %) | 6.7 -> 26.2 |
| 100 | 30.78 -> 23.63 (-23 %) | 32.5 -> 42.3 (+30 %) | 3.6 -> 15.6 |

The lead's estimate was +25–40 % fps in big hordes. Measured: +30 % at 60 and 100, +13 % at 20. Each is one run, so
treat them as single measurements.

**What the gain is (and is not):** draw calls barely change, because the Swarmer's pieces already drew instanced
(v0.8.0 HR shared meshes and materials). The saving is per-enemy nodes (about 1,000 fewer at 60 Swarmers) and the
frame-time pose code (11 node transforms per Swarmer per frame), and therefore fewer ticks per frame (PERF_Q5 §4). GPU
time also fell (6.18 -> 5.32 ms at 60). Primitives rose a little: the VAT shadow MultiMesh draws every Swarmer's proxy
in the shadow pass, and the live counts differ between runs (the hero kills them; the probe tops up once a second).

## 5. Finding on the old path: the Swarmer's proxy shadow sits under the floor

`EnemyShadows` merges the proxy at build time, right after `setup()` has posed the body fully sunk for the rise-in
(`_rise` = 0). The sheet script prints the Swarmer's proxy box:
```
swarmer shadow proxy aabb (avatar space, m): [P: (-0.2, -0.326976, -0.16), S: (0.609287, 0.236976, 0.32)] (top y -0.090; the floor is y 0)
```
The whole stand-in is 9–33 cm under the floor, so Swarmers cast no shadow today. The sheet shows no shadow under
either half, with a sun at 55°. The VAT path reuses the same mesh, so it matches. Other kinds that sink for their
rise-in probably have the same problem; this was not checked. Not fixed (out of scope): the owner decides whether
Swarmers should cast a shadow.

## 6. Tests

```
APPDATA=C:/Users/extri/Desktop/zerodepth/appdata-vat Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gexit -gtest=<14 files>
```
Files: test_enemy_vat, test_horde_avatars, test_melee_strikes, test_windup_tells, test_hit_impact, test_enemy_shadows,
test_rig_merge, test_enemy_palettes, test_shader_warmup, test_first_use_warm, test_colour_modes, test_dev_panel,
arch/test_layering, e2e/test_e2e_horde_enemies.

First run: `Tests 98, Passing 97, Failing 1, Asserts 27003/27004`. The failure was
`test_actor_views_draw_vat_swarmers_through_one_multimesh`: `SHADER ERROR: Expected constant, function, uniform or
varying` at `flat varying float zd_accent;` (the qualifier goes after `varying`). Fixed. Rerun of the two files that
reach the shader (test_enemy_vat, test_shader_warmup): `Tests 9, Passing 9, Asserts 661`. The 6 orphans reported (all
`BarChunks`) come from test_hit_impact, test_shader_warmup and test_first_use_warm; their source, `bar_chunks.gd`, is
untouched here.

Not run: the full suite (GitHub runs it on the PR), and the ink outline pass of the VAT material, because
`ActorLooks.OUTLINES` is false (written, never compiled).

## Owner

- Is the VAT Swarmer the same look as the old one (the sheet)? `OWNER ONLY`
- Keep VAT on (default "on") and extend it to the other horde kinds? `OWNER ONLY`
- Should Swarmers cast a shadow (section 5)? `OWNER ONLY`

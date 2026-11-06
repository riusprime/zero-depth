# PA_SHADOWS: enemies cast one shaped shadow (blob option), interpolation only near the hero

- **Status:** RUN (one run each, as asked; the timings are noise-prone, see Machine)
- **Build:** branch `v0105-pa` cut from `1f309fd5`. Every tool prints `sha=1f309fd5`: the "before" runs ran on the
  untouched tree; the "proxy" and "blob" runs on the same tree with this step's changes uncommitted (the mode picked by
  the new `--enemy-shadows=` flag of both tools). The step's commit is the one that adds this file.
  Godot `4.7.2.stable` (`Godot_v4.7.2-stable_win64_console.exe`); Windows 11 Pro 10.0.26200.
- **Machine:** the owner's PC, i7-10700K, RTX 3060 (the tools read `NVIDIA GeForce RTX 3060`, Forward+), 1920 x 1080
  windowed, off screen (`--position -10000,-10000`). **Other agents (PB, PC, PD) ran Godot jobs on this PC at the same
  time**, so the frame times below are noise, not a verdict; the draw-call counts are not affected by load.
- **Date:** 2026-11-02
- **Who ran it:** agent

## What changed (presentation only, EI-07)

- `EnemyShadows` (`src/presentation/world_view/enemy_shadows.gd`), called by `ActorViews._make_actor` for every
  normal and elite enemy (not bosses, not the hero, which keep their own shadows; bosses keep `ShadowTrim`'s 4):
  - every visible part of the enemy: `cast_shadow = SHADOW_CASTING_SETTING_OFF`;
  - **proxy** (default): one `SHADOWS_ONLY` MeshInstance3D, a child of the avatar (it follows the position, facing,
    lean, rise-in, an elite's vanish and the fall; the limbs don't animate). Its mesh is every part that cast before
    `PA` (the avatar's own settings, before `ShadowTrim`), merged into one ArrayMesh in the rest pose, built once per
    kind and shared;
  - **blob**: a soft dark disc (one shared quad, an unshaded alpha material with a radial gradient) on the actor's
    root, 3.2 x its radius across; nothing of the enemy in any shadow pass. Hidden with the body (an egg, a vanished
    elite) and when the actor dies.
- `ViewPrefs.enemy_shadows` (`"proxy"` | `"blob"`), from the new `GameSettings` key `enemy_shadows` (default
  `"proxy"`). Not in the Options menu: the owner picks from the shots first.
- `ActorViews._animate_if_seen`: the same ScreenCull test that already decides an enemy's animation (the camera's view
  rectangle + 4 m model reach + 6 m margin, + 2 m hysteresis while on) now also decides its physics interpolation: far
  enemies are `PHYSICS_INTERPOLATION_MODE_OFF`, near ones `INHERIT`, with `reset_physics_interpolation()` when one
  comes back. So "near" is everything on screen and ~10-12 m beyond its edges. The hero and the camera are untouched
  (the IsoRig camera already runs with interpolation off and smooths itself).

## Commands

```
export APPDATA=$(mktemp -d)    # a fresh one for every run
G="C:/Users/extri/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
# frame probe, base (no breakdown), one run each; MODE = proxy | blob (no flag on the before tree)
"$G" --path . --position -10000,-10000 --resolution 1920x1080 --windowed -s scripts/checks/frame_probe.gd -- \
  --biome=red_canyon --heavy --fx --secs=20 --warm=4 --enemies=60 [--enemy-shadows=MODE]
# draw census, the probe's fight, with one shot
"$G" --path . --position -10000,-10000 --resolution 1920x1080 --windowed --audio-driver Dummy \
  -s scripts/checks/draw_census.gd -- --biome=red_canyon --fight=60 --tag=pa_before|pa_proxy|pa_blob --shot \
  [--enemy-shadows=MODE]
```

## 1. Frame probe, 60 enemies (raw lines)

```
== before (sha=1f309fd5, flags: none)
frames=413  avg_ms=48.466  p50_ms=35.671  p95_ms=110.723  p99_ms=245.370
1pct_low_fps=3.5 (1000 / mean of the slowest 5 frames)  max_ms=325.852  over_6.94ms=413 (100.00 %)  avg_fps=20.6
render_cpu_ms_avg=6.036  render_gpu_ms_avg=10.742  (RenderingServer viewport measured time)
== proxy (enemy_shadows: proxy)
frames=589  avg_ms=33.994  p50_ms=32.882  p95_ms=51.274  p99_ms=73.222
1pct_low_fps=10.5 (1000 / mean of the slowest 6 frames)  max_ms=141.296  over_6.94ms=589 (100.00 %)  avg_fps=29.4
render_cpu_ms_avg=2.844  render_gpu_ms_avg=10.854  (RenderingServer viewport measured time)
== blob (enemy_shadows: blob)
frames=568  avg_ms=35.265  p50_ms=33.529  p95_ms=53.640  p99_ms=73.385
1pct_low_fps=10.3 (1000 / mean of the slowest 6 frames)  max_ms=153.851  over_6.94ms=568 (100.00 %)  avg_fps=28.4
render_cpu_ms_avg=3.009  render_gpu_ms_avg=10.192  (RenderingServer viewport measured time)
```

The before run's p95/p99 are far worse than both after runs and than PERF_Q5's base60 (p95 82 ms on an idle machine);
with other agents' Godot jobs running at the same time this cannot be read as the change's gain. Re-measure on an
idle machine: **NOT YET RUN (idle owner hardware)**.

## 2. Draw census, the 60-enemy fight (raw rows; draws objects prims | cam_dc cam_obj | shd_dc shd_obj | cv_dc)

```
== before (draw_census sha=1f309fd5 fight=60 tag=pa_before)
  OmniLight3D: 393 (shown 16, shadow on 0)  shadow-casting geometry shown: 534
all shown (total)                               2006    2831   4164669 |   1337    1490 |    220     260 |    449
lights: sun shadow                               220     260   1785802 |      0       0 |    220     260 |      0
hero                                              22      23      5157 |     14      15 |      8       8 |      0
enemies                                          832    1007    434621 |    725     860 |    107     147 |      0
== proxy (enemy_shadows: proxy)
  OmniLight3D: 395 (shown 17, shadow on 0)  shadow-casting geometry shown: 481
all shown (total)                               1976    2787   5386262 |   1361    1497 |    162     182 |    453
lights: sun shadow                               162     182   2445650 |      0       0 |    162     182 |      0
hero                                              23      23      5157 |     15      15 |      8       8 |      0
enemies                                          738     885    484766 |    710     837 |     28      48 |      0
== blob (enemy_shadows: blob)
  OmniLight3D: 389 (shown 15, shadow on 0)  shadow-casting geometry shown: 404
all shown (total)                               1940    2732   6171880 |   1368    1505 |    119     119 |    453
lights: sun shadow                               117     119   2756758 |     -2       0 |    119     119 |      0
hero                                              23      23      5157 |     15      15 |      8       8 |      0
enemies                                          786     914    404922 |    786     914 |      0       0 |      0
```

Reading it:
- The enemies' shadow-pass draws: **107 → 28 (proxy) → 0 (blob)**. The proxy's 28 is under one per enemy because
  every enemy of a kind shares one mesh and the renderer batches them. The blob adds one transparent camera draw per
  enemy (cam_dc 725 → 786), so the blob's total enemy draws (786) are above the proxy's (738).
- The fight is the same scenario (seed, cards, 60 enemies, 300 ticks) but not a bit-identical frame: the effects
  differ run to run (the frame's total primitives move by 2M with the enemies' rows moving by 0.1M), so compare the
  enemy rows, not the totals.
- The enemies' camera pass (~710-786 draws, ~12-13 per enemy) is untouched by this step; it is still the largest
  source.

## 3. Shots (untracked, for the owner)

`build/shots/v0.10.5/pa/fight60_before.png`, `fight60_proxy.png`, `fight60_blob.png` (copied from the census's
`build/shots/v0.10.5/draw/red_canyon_fight60_pa_<tag>_0.png`). Same scenario and camera, not a bit-identical frame.
The owner's verdict on proxy vs blob: **OWNER ONLY**.

## 4. Tests (headless, one run each, a fresh APPDATA per run)

```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=<each file> -gexit
  tests/unit/presentation/: test_enemy_shadows (new, 4), test_shadow_trim, test_rig_merge, test_screen_cull,
  test_charger_avatar, test_elite_views, test_horde_avatars, test_needle_avatar, test_warden_avatar,
  test_new_enemy_avatars, test_player_avatar, test_boss_views, test_contact_shadows, test_vfx_interpolation;
  tests/unit/application/test_settings_profile
    Tests 100  Passing 99  Failing 1  Asserts 3138/3140
godot ... -gdir=res://tests/arch -ginclude_subdirs -gexit           Tests 4  Passing 4  Asserts 19365
godot ... -gtest=res://tests/e2e/test_e2e_horde_enemies.gd -gexit   Tests 2  Passing 2  Asserts 43
```

The one failure is `test_settings_profile.gd::test_settings_round_trip_through_a_profile_file` (line 14:
`InputMap.action_get_events(&"dash")` is empty after `InputRemap.apply`). It fails the same way on the untouched
tree (`git stash`, the file alone: Tests 4, Passing 3, Failing 1), so it is not caused by this step.

# PERF_Q7: the effects layer's remaining costs; the shots stutter on slow frames

- **Status:** RUN, **noisy** (other agents' Godot processes ran during the "after" runs: see "Machine")
- **Build:** branch `v0105-q7` cut from `6f5a087f`. The probe prints `sha=6f5a087f` for both sides: the "before" runs
  on the clean tree (`dirty=0` in each log's first line), the "after" runs on the uncommitted working tree that became
  this step's commit (`dirty=8`: the `src/` files below; this file, the tests and `assets/vfx_zd/lightning/bolt.gd`
  were not counted). Godot `4.7.2.stable` (`Godot_v4.7.2-stable_win64_console.exe`); Windows 11 Pro 10.0.26200.
- **Machine:** the owner's PC, i7-10700K, RTX 3060 (the probe reads `NVIDIA GeForce RTX 3060`, Forward+), 1920 x 1080
  windowed, off screen (`--position -10000,-10000`). **Not idle:** each log's first line counts the `godot` lines in
  `tasklist` just before the run: `other_godot_lines=2` for the "before" runs, `4` for the "after" runs (other agents'
  tests). The frame-level numbers are inside the noise; the per-drawer buckets are the evidence.
- **Date:** 2026-11-05
- **Who ran it:** agent

The PERF_Q5/Q6 scenario: `scripts/checks/frame_probe.gd`, red_canyon, the Playground room (seed 4404), the Gun, the 11
cards (`--heavy`), fire held, 60 enemies; 4 s warm-up, 20 s measured, real time.

## Commands

```
G="C:/Users/extri/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
export APPDATA=C:/Users/extri/Desktop/zerodepth/appdata-q7/<side>_<run>    # its own folder per run
"$G" --path . --position -10000,-10000 --resolution 1920x1080 --windowed -s scripts/checks/frame_probe.gd -- \
  --biome=red_canyon --heavy --fx --secs=20 --warm=4 --enemies=60 [--breakdown | --process]
```

One run each, before and after: bdo60 (`--breakdown`), bd60 (`--process`). Logs (untracked): `build/q7/before_*.log`,
`build/q7/after_*.log`; the diagnosis run `build/q7/diag2_bdo60.log` (temporary marks, removed again).

## Raw lines

```
== before_bdo60 other_godot_lines=2 tree=6f5a087f dirty=0 date=2026-11-05T11:05:56+01:00
frames=641  avg_ms=31.223  p50_ms=31.243  p95_ms=45.190  p99_ms=56.538
  frame_total                      31341     56648     31341       641
  frame.scene_process              16655     29966     16681       640
  sync_all                          6153     15493      6153       641
  vfx.status_visuals._draw_vfx       992      3161       992       641
  view.fireballs                     495      2526       495       641
  vfx.hero.impact_fx.draw            199       794       199       641
  vfx.finish_rest                    168       371       168       641
  vfx.fireball_views.draw_lights         5        11         5       641
== after_bdo60 other_godot_lines=4 tree=6f5a087f dirty=8 date=2026-11-05T11:29:51+01:00
frames=593  avg_ms=33.762  p50_ms=31.792  p95_ms=49.604  p99_ms=72.769
  frame_total                      33883     72872     33883       593
  frame.scene_process              17322     37065     17351       592
  sync_all                          6187     20033      6187       593
  vfx.status_visuals._draw_vfx       844      3026       844       593
  vfx.fireball_views.draw_lights       440      2854       440       593
  vfx.finish_rest                    198       504       198       593
  view.fireballs                     173       338       173       593
  vfx.hero.impact_fx.draw            203       709       203       593
== before_bd60 other_godot_lines=2 tree=6f5a087f dirty=0 date=2026-11-05T11:06:55+01:00
frames=484  avg_ms=41.380  p50_ms=40.119  p95_ms=53.794  p99_ms=69.239
  frame_total                      51761     83092     51761       484
  sync_all                          6567     19126      6567       484
  script.attack_form_view.gd        2133      5261      2133       484
  vfx.status_visuals._draw_vfx      1080      3301      1080       484
  view.fireballs                     481      2943       481       484
  script.fireball_views.gd           266       573       266       484
  vfx.fireball_views.draw_lights         5        12         5       484
== after_bd60 other_godot_lines=4 tree=6f5a087f dirty=8 date=2026-11-05T11:30:50+01:00
frames=474  avg_ms=42.197  p50_ms=39.750  p95_ms=59.829  p99_ms=75.893
  frame_total                      52715     90213     52715       474
  sync_all                          6295     20936      6295       474
  script.attack_form_view.gd        2451      7185      2451       474
  vfx.status_visuals._draw_vfx       920      3729       920       474
  vfx.fireball_views.draw_lights       501      3421       501       474
  view.fireballs                     177       328       177       474
  script.fireball_views.gd             2         4         2       474
== diag2_bdo60 (temporary marks round each payoff's draw, by kind and on/off screen with an 8 m reach)
frames=568  avg_ms=35.214  p50_ms=33.750  p95_ms=48.183  p99_ms=58.397
  vfx.status_visuals._draw_vfx      1079      3418      1079       568
  diag.on.strike                     489      2659       870       319
  diag.on.wildfire                   265       571       265       568
```

(Rows trimmed to the ones this step touches; the logs hold all of them.)

## Before / after (us per frame, one run each, noisy)

| Bucket | Before | After | Change |
|---|---|---|---|
| frame avg ms: bdo60 / bd60 | 31.22 / 41.38 | 33.76 / 42.20 | within the noise (busier machine after) |
| `vfx.status_visuals._draw_vfx` (bdo60 / bd60) | 992 / 1080 | 844 / 920 | -15 % |
| the fireballs, all of it (bd60): `view.fireballs` + `script.fireball_views.gd` + `draw_lights` | 481 + 266 + 5 = 752 | 177 + 2 + 501 = 680 | -10 % |
| `script.attack_form_view.gd` `_process` (bd60) | 2133 | 2451 | +15 %: the fireballs' one draw now runs inside it (`draw_lights` 501); without it 1950 (-9 %) |

**What the diagnosis found.** In this scenario every payoff in flight is on screen (`diag.off.*` never appeared), so the
cull saves nothing here; it saves the whole payoff's cost in play whenever the fights run past the screen's edge. The
cost was the Overcharge strikes (`strike`, 0.87 ms in the frames that had one) and the Wildfire bursts (0.27 ms): a
strike's 3-5 bolts grow every frame, and each regrown bolt (`ZdBolt._rebuild`) re-summed its line up to every point
through a new Array (quadratic), worked every point's side twice (once a layer), and each bolt touched made a new
colour Dictionary and a new closure; a Wildfire laid out ten sparks every frame of its last 55 %, all of them wholly
clear (alpha 0).

## What changed (`src/presentation` and `assets/vfx_zd/lightning/bolt.gd`; nothing in `src/sim`)

- `StatusVisuals`: a payoff wholly off screen (past its reach + `ScreenCull.MARGIN_M`: a burst's widest light,
  `r * 3 + 2.5` m, a line's length + 4 m) draws nothing but the floor mark it would leave (`VfxLayer.burst_mark` /
  `line_mark`: the same key, texture, size and colour), so the mark is there when the camera arrives; the payoffs are
  kept in place (no new Array a frame). `shots_drawn` / `shots_culled` count them.
- `ZdBolt._rebuild`: each point's side, width factors and v worked out once for both layers, its length along the line
  kept as it goes; the same sums in the same order, so the same mesh.
- `StormPack`: its colours made once; the hit spark on a bolt's first touch through `PackHold.spawned`, not a closure
  per bolt a frame. `PackHold.touch`: no new empty Dictionary a call.
- `VfxLayer._explosion_rest`: no sparks are laid out once they are wholly clear.
- `FireballViews` (draw_on_sync off under WorldViewRoot): one draw a frame, at the frame's fraction, by `draw_lights`
  inside `VfxLayer.finish` (so the lights are this frame's, no lag) or `_process`; no draw at fraction 1.0 in the sync.

What the player sees is the same, except where a budget was full: a payoff skipped off screen no longer takes a burst
slot, a light or pool pieces from the ones on screen.

## The owner's playtest bug: the bolt "appears at some spots and flickers", "lags or sticks"

**Cause (v0.10.5 Q5, `ee19605f`, not W3-Q6):** the shot views (`HeroPulseViews`, the Gun's bolt; `FireballViews`)
draw a shot at `lerp(_before, _now, fraction)`, `_before` being its place at the views' last sync. Since Q5 the views
sync once a rendered frame, so on a frame that ran two ticks or more `_before` is two or more ticks old: the shot is
drawn a tick or more behind where it is, and the next one-tick frame jumps it forward. Under 60 fps (the owner's heavy
builds run 24-40) that happens on every other frame or so: the bolt judders and seems to stick. `hero_pulse_views.gd`,
`fireball_views.gd`, `sim_driver.gd` and `latched_reader.gd`'s tick notes are the same at `84c60816` (before Q6) and
`6f5a087f` (`git diff --stat 84c60816 6f5a087f -- src/` lists none of them but `latched_reader.gd`'s telegraph cache),
so it shows on both; not run at `84c60816`.

A scratch check (`build/q7/lag_check.gd`, untracked: each frame at `frame_pre_draw`, each shot's drawn place against
`lerp(tick - 1, tick, fraction)` from the sim's per-tick places, by how many ticks the frame ran), the plain Gun, 60
enemies, 8 s:

```
"$G" --path . --position -10000,-10000 --resolution 1920x1080 --windowed -s res://build/q7/lag_check.gd -- \
  --biome=red_canyon --secs=8 --warm=2 --enemies=60 --plain
== build/q7/lc_q6_plain60.log (6f5a087f, clean)
  fireball/1   n=  9296 mean=0.000 max=0.000
  fireball/2   n=  2638 mean=0.050 max=0.066
  hero/1       n=  1021 mean=0.000 max=0.000
  hero/2       n=   105 mean=0.269 max=1.581
== build/q7/lc_fix_plain60.log (this step's tree)
  fireball/0   n=     9 mean=0.000 max=0.000
  fireball/1   n=  9893 mean=0.000 max=0.000
  fireball/2   n=  2570 mean=0.000 max=0.000
  fireball/3   n=    49 mean=0.000 max=0.000
  hero/0       n=     4 mean=0.000 max=0.000
  hero/1       n=   991 mean=0.000 max=0.000
```

(The fixed run happened to have no hero shot in a two-tick frame; the unit test below covers the hero view.) A second
scratch check (`build/q7/bolt_check.gd`: a held pack effect far from its shot, shown without one, shared by two shots,
or live and held by nobody) found none at `6f5a087f` (`frames_checked=331 counts={  }`, the probe's build, 20 enemies):
W3-Q6's PackHold, PackFx and VfxCore changes are not the cause.

**Fix:** `LatchedReader.note()` keeps each tick's shot places; on a sync whose frame ran two ticks or more,
`projectile_pos_before(id)` gives a shot's place at the tick before the latest, and both views draw from there.
Test: `test_view_sync_once_a_frame.gd::test_a_shot_is_drawn_between_the_last_two_ticks_when_a_frame_ran_several`
(fails without the view change: `[VECTOR2(1.41, 0.0)] expected to equal [VECTOR2(1.68, 0.0)]`).

**Not fixed:** the actors (the hero, the enemies) move by Godot's physics interpolation, written once a frame since Q5;
Q5's own check (Q5_FIX.md §4) found the same "from last frame's tick" on multi-tick frames. They move slower than a
bolt, so it shows less; it is left for the lead.

Owner-only: whether the bolt now reads smooth on the owner's game (`OWNER ONLY`); a clean timing on an idle PC is
`NOT YET RUN`.

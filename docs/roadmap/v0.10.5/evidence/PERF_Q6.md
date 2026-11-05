# PERF_Q6: the views skip work when nothing changed

- **Status:** RUN, **noisy** (other agents ran Godot on the same PC during every run: see "Machine")
- **Build:** branch `v0105-q6` cut from `84c60816`. The probe prints `sha=84c60816` for both sides: the "before" runs ran
  on the clean tree (`dirty=0` in each log's first line), the "after" runs on the uncommitted working tree that became
  this step's commit (`dirty=10`: the ten `src/` files below; this file was written after the runs). Godot
  `4.7.2.stable` (`Godot_v4.7.2-stable_win64_console.exe`); Windows 11 Pro 10.0.26200.
- **Machine:** the owner's PC, i7-10700K, RTX 3060 (the probe reads `NVIDIA GeForce RTX 3060`, Forward+), 1920 x 1080
  windowed, off screen (`--position -10000,-10000`). **Not idle:** each log's first line counts the `godot` lines in
  `tasklist` just before the run (`other_godot_lines=4` to `6`: two or three other Godot processes, other agents'
  tests). The frame-level numbers are inside the noise; the per-view buckets are the evidence.
- **Date:** 2026-11-05
- **Who ran it:** agent

The PERF_Q5 scenario: `scripts/checks/frame_probe.gd`, red_canyon, the Playground room (seed 4404), the Gun, the 11
cards, fire held, 60 enemies; 4 s warm-up, 20 s measured, real time. Since Q5 the views sync once a rendered frame
(item 1), so the `view.*` rows are per frame, not per tick.

## Commands

```
G="C:/Users/extri/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
export APPDATA=C:/Users/extri/Desktop/zerodepth/appdata-q6/<run>    # its own folder per run
"$G" --path . --position -10000,-10000 --resolution 1920x1080 --windowed -s scripts/checks/frame_probe.gd -- \
  --biome=red_canyon --heavy --fx --secs=20 --warm=4 --enemies=60 [--breakdown | --process]
```

One run each, before and after: base60 (no flags), bdo60 (`--breakdown`), bd60 (`--process`). Logs (untracked):
`build/q6/before_*.log`, `build/q6/after_*.log`; the diagnosis runs `build/q6/diag*_bdo60.log`.

## Raw lines

```
== before_base60   (other_godot_lines=4 tree=84c60816 dirty=0)
frames=536  avg_ms=37.328  p50_ms=34.479  p95_ms=54.014  p99_ms=75.663
1pct_low_fps=10.4 (1000 / mean of the slowest 6 frames)  max_ms=148.064  over_6.94ms=536 (100.00 %)  avg_fps=26.8
render_cpu_ms_avg=2.847  render_gpu_ms_avg=9.390  (RenderingServer viewport measured time)
== after_base60    (other_godot_lines=6 tree=84c60816 dirty=10)
frames=538  avg_ms=37.179  p50_ms=35.906  p95_ms=56.253  p99_ms=68.390
1pct_low_fps=10.8 (1000 / mean of the slowest 6 frames)  max_ms=147.988  over_6.94ms=538 (100.00 %)  avg_fps=26.9
render_cpu_ms_avg=2.936  render_gpu_ms_avg=10.153  (RenderingServer viewport measured time)
== before_bdo60    (other_godot_lines=6 dirty=0)
frames=531  avg_ms=37.671  p50_ms=36.162  p95_ms=53.238  p99_ms=69.862
  frame_total                      37786     69967     37786       531
  frame.scene_process              19519     39656     19556       530
  sync_all                          7412     25134      7412       531
  view.actors                       2488     18764      2488       531
  actors.update                     1330      2253      1330       531
  view.status_fx                     620      1212       657       501
  view.fireballs                     558      3113       558       531
  actors.enemy_sync                  544      1033       544       531
  view.telegraphs                    405      1271       405       531
  view.attack_forms                  290       902       290       531
  view.shards                        241      1803       241       531
  view.hit_feel                      240      1726       240       531
  view.elite_fx                      201       545       201       531
  view.horde_fx                      161       599       161       531
== after_bdo60     (other_godot_lines=6 dirty=10)
frames=572  avg_ms=34.978  p50_ms=31.228  p95_ms=60.513  p99_ms=80.916
  frame_total                      35104     81090     35104       572
  frame.scene_process              18318     47219     18350       571
  sync_all                          6594     28475      6594       572
  view.actors                       2073     23002      2073       572
  vfx.status_visuals._draw_vfx      1096      4221      1096       572
  actors.update                     1053      2005      1053       572
  view.fireballs                     509      2789       509       572
  view.status_fx                     462      1335       524       504
  view.telegraphs                    413      1240       413       572
  actors.enemy_sync                  323       642       323       572
  view.attack_forms                  304      1249       304       572
  view.hit_feel                      229      1595       229       572
  view.shards                        221      1787       221       572
  view.horde_fx                      150       525       150       572
  view.elite_fx                      125       427       125       572
== before_bd60     (other_godot_lines=6 dirty=0)
frames=425  avg_ms=47.112  p50_ms=45.178  p95_ms=68.139  p99_ms=82.910
  script.attack_form_view.gd        2587      7406      2587       425
  script.elite_avatar.gd             423       756       423       425
  script.horde_avatar.gd             390       737       390       425
  script.fireball_views.gd           313       682       313       425
== after_bd60      (other_godot_lines=6 dirty=10)
frames=447  avg_ms=44.798  p50_ms=43.443  p95_ms=62.476  p99_ms=93.972
  script.attack_form_view.gd        2319      5974      2319       447
  vfx.status_visuals._draw_vfx      1172      3796      1172       447
  script.elite_avatar.gd             436       914       436       447
  script.horde_avatar.gd             403       703       403       447
  script.fireball_views.gd           306       639       306       447
```

(Rows trimmed to the ones this step touches; the logs hold all of them. The `vfx.*` rows are new in this step, so
they have no "before" row. `diag1_bdo60`, run with this step's first changes but before the PackFx and PackHold ones,
reads `vfx.status_visuals._draw_vfx 1330`.)

## Before / after (us per frame, one run each, noisy)

| Bucket | Before | After | Change |
|---|---|---|---|
| frame avg ms: base60 / bdo60 / bd60 | 37.33 / 37.67 / 47.11 | 37.18 / 34.98 / 44.80 | within the noise (Q5's spread ~4 ms) |
| `sync_all` (every view's sync, bdo60) | 7412 | 6594 | -11 % |
| `view.actors` | 2488 | 2073 | -17 % |
| `actors.update` | 1330 | 1053 | -21 % |
| `actors.enemy_sync` | 544 | 323 | -41 % |
| `view.status_fx` | 620 | 462 | -25 % |
| `view.elite_fx` | 201 | 125 | -38 % |
| `view.fireballs` | 558 | 509 | -9 % (noise level) |
| `view.telegraphs` | 405 | 413 | none |
| `script.attack_form_view.gd` `_process` (bd60) | 2587 | 2319 | -10 % |
| of it `vfx.status_visuals._draw_vfx` | — (1330 in diag1) | 1096 / 1172 | |

**The `attack_form_view.gd` `_process` target (half) is missed: -10 %.** Its time is not the forms: it calls
`VfxLayer.finish()`, which runs every effects drawer. Diagnosis runs with temporary marks (removed again; `diag1`, `diag4`)
split it: `status_visuals._draw_vfx` 1.33 ms (diag4: of its 1.39, 0.95 ms the item payoffs' bursts and lines in
flight, `_shots`, and 0.24 ms the burn flames), the hit impacts 0.24, the forms' own effects 0.25, the layer's own
finish 0.2 (diag1). The payoff bursts are real drawing (each frame lays out
its sprites, lines and pack bursts); halving them needs a change to what they draw, or culling the off-screen ones,
which this step does not do.

## What changed (`src/presentation` only; nothing in `src/sim`)

- `ActorViews.sync`: the key walks over the nodes, the bars and five per-id tables run only when an actor died (the
  node count differs from the live count); the same for the projectiles.
- `HordeAvatar.sync`, `EliteAvatar.sync`: the values go straight to `_apply`, no Dictionary per enemy per sync
  (`apply_state(Dictionary)` stays for the tests).
- `LatchedReader.telegraph(i)`: worked out once per tick and actor, shared by the telegraphs, the enemy models'
  windups, the elites, the lobs and the bosses' cues (cleared on every tick, note and settle).
- `StatusBadges.update`: the same row (statuses, counts, camera right) writes nothing; `StatusVisuals._update_plus`
  builds no key string.
- `BarChunks.feed`: a bar at rest is not rescaled every sync.
- `PackFx.is_live` / `live_count(family)`: a lookup instead of a walk over every live effect (every held effect asked it
  every frame).
- `PackHold._move`: an effect touched where it already stands is not placed again.
- `VfxCore.finish`: a pool's count and a light's settings are written only when they change; each drawer is timed into
  the frame probe's `--breakdown` (`vfx.<script>.<method>`, `vfx.hero.*`, `vfx.finish_rest`; one bool check when off).

What each view shows is the same: every skip is of a write whose value is already there, or of a walk that finds
nothing to remove.

Owner-only: none (no feel judgement); a clean timing on an idle PC is `NOT YET RUN`.

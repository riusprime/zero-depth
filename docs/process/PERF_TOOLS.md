# Performance tools: how to measure, and how not to

Every tool that measures the sim or the frame, what its numbers mean, the protocol that makes a number evidence, and
the misreadings that cost this project time. Logging a game the owner plays is a separate tool:
[`PERF_LOG.md`](PERF_LOG.md). Evidence pages follow [`TEMPLATES.md`](TEMPLATES.md) §3; tools write only under
`build/`, and a number goes into evidence by hand (CLAUDE.md "Evidence honesty").

## 1. The target

The owner, 2026-11-11 (LOCKED_DECISIONS, OWNER_QUESTIONS Q1): **never under 60 fps, with 144 fps as the ceiling when
the scene allows.** "Every frame under 6.94 ms" is retired as the objective. The probe's reports still print
`over_6.94ms` and the evidence pages before that date judge against it; read them against the new target.

The sim's own budgets stand: the horde tick (120 enemies, 200 projectiles) mean ≤ 4 ms; the stress tick mean ≤ 2 ms,
p99 ≤ 4 ms ([`../architecture/ARCHITECTURE.md`](../architecture/ARCHITECTURE.md) §13).

## 2. The quiet-machine protocol

A timing is evidence only when it was taken like this. Anything else is an indication, and its evidence says so.

1. **No other Godot process.** Count them before and after (`tasklist | grep -i godot` on Windows) and write both
   counts in the evidence. No agent runs tests or shots meanwhile. On a cloud machine, timing is never evidence
   (CLAUDE.md "Keep steps fast").
2. **The owner is not playing** and nothing else heavy runs. Write in the evidence what else ran, even a few seconds
   of a Python job.
3. **Measure the baseline's spread first:** run the unchanged build at least three times. Its spread (max − min of the
   average frame) is the noise floor. In the horde scenes it was about ±1.5 ms of average frame
   ([`PERF_AFTER.md`](../roadmap/v0.11.1/evidence/PERF_AFTER.md)).
4. **Alternate A and B** (base, variant, base, variant …), never all A then all B: the machine drifts.
5. **A difference inside the spread means nothing.** Report it as "inside the spread", not as a gain or a loss.
6. **Name the build.** Measure a clean worktree at a known SHA with the library built for that SHA
   (`bash scripts/native/build.sh all`). Check that the build contains the thing in question (§4.5).
7. **Run the renderer off screen,** never `--headless` for a frame: `--position -10000,-10000 --resolution 1920x1080
   --windowed`, with a temp `APPDATA` so the owner's settings are untouched.

## 3. The tools

Headless tools build a `World` directly. Tools that need a renderer boot `main.tscn` or the Playground.
**Which sim a tool runs:** since step 54b there is one: every tool, headless or not, runs the native core, and the
`--native` options (`horde_phases`, `shot_phases`, the frame probe, `frame_attribution.sh`'s `NATIVE`) and
`ZD_NATIVE_*` are gone, as is `native_compare` (it compared the GDScript and native paths). A headless tool that checks
stops with the one error and exit code 1 without the library (`horde_phases`, `shot_phases`, the benches,
`native_fixtures`); `scripts/checks/native_fixtures.gd` checks the loaded library against the recorded fixtures, and
`scripts/native/check_release.sh` does it with the release build. The crowd writer keeps its own switch
(`--ab=no_native_crowd`).

### 3.1 The frame probe: `scripts/checks/frame_probe.gd` (with `frame_spans.gd`)

```
APPDATA=$TEMP/zd-frame godot --path . --resolution 1920x1080 --windowed --position -10000,-10000 \
  -s scripts/checks/frame_probe.gd -- --biome=red_canyon [scene] --secs=20 [options]
```
It boots the game, opens the Playground with the Gun and a fixed build (`BUILD_KEYS` at level 3), keeps the enemies
topped up round the hero (who cannot die), strafes and sweeps the aim, and times every rendered frame (vsync off, no
fps cap). The report goes to `build/perf/<sha>_<biome>[_ab-<flags>].txt` and to stdout.

**The three scenes** every evidence page uses: 20 enemies (no scene argument); `--enemies=60 --heavy --fx` (the
heavy build: `HEAVY_KEYS` at level 5 on top of the base build); `--enemies=120 --only=swarmer`.

**The report line:** `frames avg_ms p50_ms p95_ms p99_ms 1pct_low_fps max_ms over_6.94ms`, then `gpu` and `cpu`
(the renderer's own times). The per-second samples: `draw_calls`, `live_objects` (every Object alive in memory, not
what is drawn), `primitives`, `video_mem_MB`, `nodes`, `resources`, `orphans`, `particle_nodes`, `emitting`,
`drawn_objects` (what the renderer drew, all passes).

| Option | What it does |
|---|---|
| `--biome=<id[,id]>`, `--secs=N`, `--warm=N` | the biomes (default `frozen_shore,red_canyon`), seconds measured (30), warm-up (3) |
| `--enemies=N`, `--heavy`, `--only=<kind>`, `--boss=<index>` | the scene: N enemies, the heavy build, one kind only, one boss instead |
| `--spans` | cuts every frame into consecutive spans that add up to it: `probe_script`, `nodes_process` (scripts and views, the views' sync), `after_process` (redraws, layout, transforms, the delete queue), `draw` (the engine's draw and present), `after_draw`, and per physics step `physics_pre`, `nodes_physics` (the sim's ticks and their listeners), `physics_post`. The stamps cost a few µs a frame; runs are a little slower than plain ones, so compare inside one page |
| `--breakdown` | per-bucket script time: every view's sync, every tick listener, the sim's phases, `PerfMarks` |
| `--process` | `--breakdown` plus every script node's `_process` timed from the probe. It adds 5–7 ms a frame of its own: proportions only (§4.3) |
| `--fx` | the hero's effect instances and the hostile threats on screen per frame |
| `--census` | every visible geometry instance grouped by owner script, mesh and material |
| `--redraws` | counts `CanvasItem` redraws a frame; with `--spans` also the root viewport's 2D draw calls (`count.canvas_dc`) |
| `--orphans` | lists the nodes outside the tree by class and script |
| `--hud-hide=<part[,part]>` | hides the HUD and UI children whose class, script or name contains a part |
| `--size=WxH`, `--vsync=off\|on\|mailbox\|adaptive` | the window and root viewport size; the vsync mode |
| `--shot=<png>` | the viewport 0.5 s before the end |
| `--shot-at=N:<png>` | the viewport at the scenario's Nth frame, the scripted strafe on frame time: with `--fixed-fps 60`, the same frame twice (a before/after pair) |
| `--twin` | draws the scene a second time with a node per enemy and compares every batched enemy with its node every frame (`batch_twin.gd`; [`../architecture/PRESENTATION_CONTRACTS.md`](../architecture/PRESENTATION_CONTRACTS.md) §11.5). It doubles the drawing: never time a `--twin` run |
| `--enemy-vat=on\|off`, `--enemy-shadows=proxy\|blob` | the VAT crowd and the enemy shadow mode |
| `--ab=<flag[,flag]>` | turns one suspected cost off, no code edit (below) |

The `--ab` flags. In `frame_probe.gd`: `wildfire`, `no_pack_fx`, `no_interp`, `shadows_low`, `no_ssil`, `fx_half`,
`fx_low`, `no_rig_merge`, `no_burn_fx`, `no_anim`, `low_hp` (`planar_floor` is listed and not available). In
`frame_spans.gd`:

| Flag | Takes out |
|---|---|
| `no_fti` | the physics interpolation |
| `hide_actors` | the actors' view, hidden (still updated) |
| `detach_actors` | the actors' view out of the tree (the sim still runs them): what the enemies' nodes cost in all |
| `detach_furniture` | each enemy's disc, rings and bar nodes out of the tree |
| `no_batch` | the enemy batch: every enemy a node again (`ActorViews.batch_enemies` off) |
| `no_native_crowd` | the batch's native writer: the GDScript pass (`EnemyBatch.native` off) |
| `no_particles`, `no_sun_shadow`, `no_omni` | particle nodes; the directional light; omni and spot lights |
| `no_hud`, `no_still` | the HUD layer; the HUD's still-part textures (`HudStill` off) |
| `no_3d`, `no_viewport` | the root viewport's 3D; the root viewport's drawing |

There is no `--cards` option.

### 3.2 `scripts/checks/frame_attribution.sh`

```
NATIVE=all [SWITCHES="ab:no_hud ab:detach_actors"] bash scripts/checks/frame_attribution.sh swarm120|heavy60|enemies20 [secs]
```
Runs the frame probe with `--spans` on one scene: the baseline three times, then each switch twice, each followed by
another baseline. The summary (`build/attribution/<scene>/<sha>/summary.txt`) gives the baseline's mean and spread,
then per switch its mean, its difference and `beyond_spread` yes or no. `ab:<flag>` is `--ab=<flag>`; `size:<WxH>`
renders a small window (the GPU's share). `GODOT` names the binary; `NATIVE` the kernels for every run. This is the
tool for "what does X cost the frame".

### 3.3 The sim

| Tool | Command | What it gives |
|---|---|---|
| `scripts/checks/horde_phases.gd` | `godot --headless --path . -s scripts/checks/horde_phases.gd -- --counts=20,60,120 --ticks=1800` | floor 3, N real enemies kept alive, FightBot playing: ms mean / p99 / max a tick for `step` and every phase (`nav_flood`, `ai`, `move`, `resolve`, `proj`, …), and an `outcome_hash` chain. The tool for a kernel's off-against-on |
| `scripts/checks/attack_phases.gd` | `… -s scripts/checks/attack_phases.gd -- [--enemies=60] [--ticks=1800] [--calls=1]` | the frame probe's heavy scene without the renderer, fire held: every attack phase and sub-phase a tick, an outcome hash; `--calls=1` times the helpers a landed hit calls |
| `scripts/checks/shot_phases.gd` | `… -s scripts/checks/shot_phases.gd -- [--scenes=horde,stress] [--ticks=1800]` | the projectile phase and its parts in the two scenes with the most projectiles, the live projectile count, a hash chain |
| `scripts/bench/sim_bench.gd` | `godot --headless --path . -s scripts/bench/sim_bench.gd [-- --only=horde,stress_ai]` | the budget scenes (`horde`, `reference`, `reference_boss`, `reference_floor`, `stress`, `stress_ai`): mean, p50, p99, max a tick, `*_in_band`; writes `build/bench.json` |
| `scripts/bench/native_columns_bench.gd` | `… -- [--rows=121,500] [--reps=2000]` | the cost of a column crossing by name, read and write |
| `scripts/bench/native_pairs_bench.gd` | `… -- [--counts=120,500] [--reps=2000]` | the pair pass, GDScript against native, inside and with the call |

The outcome hashes are the "same result" proof of a speed-up that must not change the game: equal before and after.

### 3.4 The draw and the views

| Tool | Command | What it gives |
|---|---|---|
| `scripts/checks/draw_census.gd` | `godot --path . --position -10000,-10000 --resolution 1920x1080 --windowed -s scripts/checks/draw_census.gd -- --biome=red_canyon [--spots=5] [--tag=before] [--shot] [--enemy-shadows=proxy\|blob] [--fight=N]` | counts, not timings: draw calls and objects drawn, everything shown and then each source hidden in turn, per pass (camera, shadows, 2D); `--fight=N` on the probe's fight |
| `scripts/checks/view_dump.gd` | `godot --path . --fixed-fps 60 --resolution 640x360 --windowed --position -10000,-10000 -s scripts/checks/view_dump.gd -- --out=build/view_dump.txt [--frames=900]` | a frame-by-frame dump of the bulk-reading views' nodes and state over one seeded fight: diff two trees' dumps line by line |
| `scripts/checks/hud_still_diff.gd` | `godot --path . --position -10000,-10000 -s scripts/checks/hud_still_diff.gd -- --scene=fight\|run [--size=1600x900] [--ui=110]` | pixels that differ, HUD drawn from textures against drawn directly, with the noise floor (two captures of the same mode) |
| `scripts/bench/view_bench.gd` | see its header | the view's CPU side over the horde scene (lavapipe in a container: scaling only) |

## 4. Reading the numbers: mistakes already made

Each of these happened, cost a wrong conclusion, and is why a rule above exists.

1. **"Objects" was not what is drawn.** The probe's old objects column was `Performance.OBJECT_COUNT`, every Object
   alive in memory; the baseline reported "20,000 objects drawn a frame". The renderer drew 1,704–3,139. The columns
   are now `live_objects` and `drawn_objects` ([`PERF_BASELINE.md`](../roadmap/v0.11.1/evidence/PERF_BASELINE.md)
   "Correction"). Rule: know what a monitor counts before you quote it.
2. **`engine.process` and `engine.physics_process` are per-second maxima**, not per-frame means (`Performance`'s
   `TIME_PROCESS`, `TIME_PHYSICS_PROCESS`). `PERF_AFTER.md`'s breakdown rows carry that error: read them for
   proportions among script buckets only.
3. **`--process` adds 5–7 ms a frame of its own.** A `--breakdown --process` frame is longer than a plain one; its
   buckets are proportions, never totals.
4. **Scaling one run's buckets onto another run's frame invents time.** A table of a horde frame built from
   `--process` buckets set against a plain run's frame showed an "unnamed 9 ms" that does not exist; `--spans` then
   showed the spans cover the whole frame (PROGRESS History, 2026-11-10). Rule: take every number of a table from one
   run mode.
5. **Measure a build that contains the thing.** To judge the owner's report about the Ring form's lights, the lead
   first turned the omni lights off in a probe scene and saw no change; PROGRESS records that the scene measured was
   the heavy build's Rune Explosion, not Ring, so the run said nothing about Ring. The probe prints the cards it
   granted (its build line); read it before quoting a result about one card.
6. **Estimates are not costs.** The code audit's cost estimates were wrong several times: T1 (the boot and hub walk
   under 2 s, not 20 s a test), T5 (frame limits read as waits), U3 (the content load under 100 ms), V1 (the enemies'
   own `_process` 3 µs each, not 40 µs) ([`E2E_FIXED_COST.md`](../roadmap/v0.11.1/evidence/E2E_FIXED_COST.md),
   [`PERF_BASELINE.md`](../roadmap/v0.11.1/evidence/PERF_BASELINE.md)). Each was read from the code, not measured.
   Measure the bucket before building the fix.
7. **Removing nodes is not removing their cost.** Taking nine enemy kinds' nodes out of the tree gained 0.15 ms; the
   6 ms `detach_actors` showed was the per-enemy script loop and the bodies' drawing, which stayed
   ([`PERF_W8.md`](../roadmap/v0.11.1/evidence/PERF_W8.md)). A switch that removes a whole subtree measures
   everything under it; split it before you build.
8. **Script buckets miss engine work.** The HUD's scripts measured under 0.3 ms, so its step was dropped; hiding the
   HUD saved 2.0–2.4 ms of the engine's 2D drawing ([`PERF_NATIVE.md`](../roadmap/v0.11.1/evidence/PERF_NATIVE.md)).
   Use an `--ab` switch for the true cost of a part.
9. **Busy-machine numbers are indications.** A step measured beside other Godot processes reports proportions; its
   gain is confirmed by the next quiet run.

## 5. The evidence index

All under [`../roadmap/v0.11.1/evidence/`](../roadmap/v0.11.1/evidence/), in order. Each page has its commands, raw
output, build and machine.

| Page | What was measured | Headline |
|---|---|---|
| [`SEAMS_TIMING.md`](../roadmap/v0.11.1/evidence/SEAMS_TIMING.md) | the seams run, file by file, before and after the test-speed wave | 3,442 s → 1,606 s wall; 3,185 s → 1,396 s of tests; one test was 48.7 % of the run |
| [`E2E_FIXED_COST.md`](../roadmap/v0.11.1/evidence/E2E_FIXED_COST.md) | what an e2e test pays before its own work | a boot 0.2 s; a warm run start about 6 s (world build 2.5 s, view build 2.2 s); the first run start in a process 27–33 s |
| [`PERF_BASELINE.md`](../roadmap/v0.11.1/evidence/PERF_BASELINE.md) | the sim bench, the tick by phase, three frame scenes, before any speed-up | horde tick 5.315 ms; frames 14.8 / 36.7 / 29.6 ms; bound by script, not the GPU |
| [`PERF_AFTER.md`](../roadmap/v0.11.1/evidence/PERF_AFTER.md) | the GDScript speed-ups, the thread trial | frames 20–31 % shorter; 1 % lows in hordes 10 → 20 fps; tick at 120 4.26 → 3.09 ms; the thread trial 4–15 % |
| [`PERF_NATIVE.md`](../roadmap/v0.11.1/evidence/PERF_NATIVE.md) | the native kernels off against on; the frame attribution | tick at 120 enemies 3.3 → 0.56 ms; horde frames 2–3 ms shorter; the enemies' nodes 6.0–8.9 ms, the HUD 2.0–2.4 ms |
| [`PERF_W8.md`](../roadmap/v0.11.1/evidence/PERF_W8.md) | the frame after the first display steps | 20 enemies 8.2 ms (122 fps), 60 heavy 24.9 ms, 120 swarmers 18.5 ms; the HUD about 1 ms; the batch alone 0.15 ms |
| [`PERF_FINAL.md`](../roadmap/v0.11.1/evidence/PERF_FINAL.md) | the final code of v0.11.1 (the native core the only sim), with PERF_W8's build measured again back to back | 20 enemies 8.7–9.2 ms, 60 heavy 24.3 ms, 120 swarmers 15.5 ms; the tick at 120 enemies 0.54 ms; the Ring 0.9 ms over the Gun alone; a daytime run reads about 0.7 ms higher than a night one |

The quiet run after the batched avatars, the bulk reads and the shard drops is **NOT YET RUN** (PROGRESS "Where we
are").

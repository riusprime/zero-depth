# PF1: the X-ray pass is gone, and the frame-time profiler exists

Step PF1 of v0.9.5 (the first half of PF). Base: `claude/v095-feedback` at `1a7307b7`. The owner-PC measurement and
the cuts it points to are PF2 and are NOT YET RUN.

## Part A: the X-ray silhouette pass removed

Owner (L21): "No enemy is drawn behind walls or floors". PLAN PF: the X-ray pass goes.

Removed outright (no dead paths left):
- `ActorViews.technique` defaults to `&"outline"` (rim only); `_ghost_material` and the per-body-piece "ghost" box
  (a second `MeshInstance3D` in `STENCIL_MODE_XRAY`) are deleted. `main.gd`'s gallery setup passes `&"outline"`.
- `EnemyLooks`: the `xray()` shader pass (`_XRAY` shader, `XRAY_ALPHA`, `XRAY_SHRINK`), `chain_xray()`, `xray_of()`
  and the `xray_pass` parameter of `body()`, `accent()` and `_outline_pass()` (their cache keys lose it too).
- `AvatarBase`: the `xray_twin()` helper, the `xray_pass` parameter of `shared_body()`, the `chain_xray` call in
  `_outlined()`.
- `EliteAvatar`, `HordeAvatar`: `_xray`, `XRAY_GROW`, and the code that built the pass. `ChargerAvatar`: the pass on
  its merged plates (and the now unused `team` / `technique` arguments of `_piece` and `_build_leg`).
- `BossAvatar` (the skinned `XrayTwin` node), `BossParts.piece` (the twin box), `LensDroneAvatar` (the twin per part).
- Kept on purpose: the stencil outline (the rim) and `AvatarBase.write_stencil` (faces / visors still mark the
  stencil like the body pieces do; harmless without the pass). The `technique` argument stays on the avatars'
  `setup()` (underscore-named where unused) so the many callers and tests did not need a signature change.
- Scripts: `scripts/checks/horde_draws.gd` and `scripts/shots/galleries.gd` pass `&"outline"` instead of `&"xray"`
  (the gallery's `occlusion_xray` row names are historical; they now draw the rim).

Tests changed (other coverage kept): the 5 boss view files, the horde, needle, player, warden, charger and
colour-blind palette tests used to assert that the X-ray pass existed; they now assert there is none (no `XrayTwin`
node, no `STENCIL_MODE_XRAY` material, same body pieces). 20 other test files only swapped the `&"xray"` argument.

Checks run (headless, this machine, `--language en`, `APPDATA=$TEMP/zd-pf1*`):
- gdformat + gdlint on every touched file: clean. `src/app/main.gd` still 1000 lines (the cap).
- `tests/unit/presentation` (whole folder, 161 scripts): 1090 / 1091 on the first run; the one failure (`test_boss_models`, an old "mesh and its X-ray twin = 2" assert) was fixed and that file re-run: 6 / 6. So 1091 / 1091 after the fix.
- `tests/arch`: 4 / 4 passed (2 scripts, 18203 asserts).
- e2e `test_e2e_run_flow`, `test_e2e_horde_enemies`, `test_e2e_playground`: 6 / 6 passed (3 scripts, 155 asserts).
- Not run: the seams, the full suite (GitHub runs it).

## Part B: the profiler `scripts/checks/frame_probe.gd`

Boots the real `main.tscn`, opens the Playground (seed 4404, the real room, views and sim) with the Gun, grants
Glaive + Ring + Split Shot + Ember Core (fire) + Storm Core (lightning) at level 3, keeps 20 live enemies round the
hero (7-12 m out, topped up each second; the hero cannot die), holds fire (right mouse), sweeps the aim round a
circle and strafes left / up / right / down in 2 s legs. 1920x1080 windowed, vsync off, no fps cap (restored on exit;
the profile is in-memory and `APPDATA` is a temp folder, so the owner's settings are never touched). Warm-up 3 s,
measured 30 s (defaults). Writes `build/perf/<sha>_<biome>[_ab-<flags>].txt` (git-ignored) and prints it; never writes
into `docs/`.

Per biome it reports: frames, average, p50, p95, p99, max (ms), the 1 % low fps (1000 / mean of the slowest 1 % of
frame times), the count over 6.94 ms, the RenderingServer CPU and GPU render time averages, and per second the draw
calls, objects, primitives, video memory, node count and particle-node counts (total / emitting).

Command lines (Git Bash, from the repo root; Godot must render, so no `--headless`):

```bash
G="/c/Users/extri/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
# both biomes (Frozen Shore, Red Canyon), the target run:
APPDATA=$TEMP/zd-frame "$G" --language en --path . --resolution 1920x1080 --windowed -s scripts/checks/frame_probe.gd
# one biome:
APPDATA=$TEMP/zd-frame "$G" --language en --path . --resolution 1920x1080 --windowed -s scripts/checks/frame_probe.gd -- --biome=frozen_shore
# A/B (one cost off at a time; repeat per flag, compare with the run above):
APPDATA=$TEMP/zd-frame "$G" --language en --path . --resolution 1920x1080 --windowed -s scripts/checks/frame_probe.gd -- --biome=frozen_shore --ab=shadows_low
#   flags: shadows_low | no_ssil | fx_half | fx_low | planar_floor  (comma-separated to combine)
#   other options: --secs=30 --warm=3
```

`--ab` flags (only those that map to an existing knob):
- `shadows_low`: directional shadow atlas 2048 and soft-shadow filter quality 1 (project: 4096, quality 4).
- `no_ssil`: the stage's SSIL off.
- `fx_half`: the Options "Effects density" at Medium (the existing knob; there is no exact "half" setting). `fx_low`:
  Low.
- `planar_floor`: NOT AVAILABLE. The kit ground (`StageView._ground_material`) is world-triplanar for every biome
  (`uv1_triplanar` and `uv1_world_triplanar` true) and no planar path exists to switch to. The report prints the
  triplanar state.
- Not available either: any per-hit VFX thinning finer than the density setting, and status-effect particle caps
  (no knob exists).

### Smoke output: SMOKE ONLY, MACHINE BUSY, NOT EVIDENCE

Run on the owner's PC (RTX 3060) while another agent's Godot and my own test runs were using it, with shortened
runs (10 s measured, 2 s warm-up), at `1a7307b7` plus the uncommitted PF1 tree. These numbers prove the tool works
and say nothing about the game's frame time. (The `floor:` line in the first two blocks is from before I fixed the
triplanar detection: it printed 0 materials; the third block shows the fixed line.)

Command: `... -s scripts/checks/frame_probe.gd -- --secs=10 --warm=2`

```
frame_probe  sha=1a7307b7  biome=frozen_shore  ab=none
scenario: Playground room seed 4404, Gun, 20 live enemies, warm-up 2.0 s, measured 10.0 s
flags: none
frames=735  avg_ms=13.615  p50_ms=14.464  p95_ms=19.101  p99_ms=28.739
1pct_low_fps=27.2 (1000 / mean of the slowest 8 frames)  max_ms=45.394  over_6.94ms=586 (79.73 %)  avg_fps=73.4
render_cpu_ms_avg=1.396  render_gpu_ms_avg=3.459  (RenderingServer viewport measured time)
  draw_calls 980-1283, objects 9518-10206, primitives 212121-337624, video mem 1861 MB, particle nodes 4 (1-2 emitting)

frame_probe  sha=1a7307b7  biome=red_canyon  ab=none
scenario: Playground room seed 4404, Gun, 20 live enemies, warm-up 2.0 s, measured 10.0 s
flags: none
frames=651  avg_ms=15.387  p50_ms=15.027  p95_ms=28.616  p99_ms=37.958
1pct_low_fps=21.1 (1000 / mean of the slowest 7 frames)  max_ms=56.642  over_6.94ms=542 (83.26 %)  avg_fps=65.0
render_cpu_ms_avg=1.483  render_gpu_ms_avg=3.770
  draw_calls 976-1173, objects 9847-10361, primitives 344415-418927, video mem 1867 MB, particle nodes 4
```

Command: `... -- --biome=frozen_shore --secs=4 --warm=1 --ab=no_ssil,shadows_low,fx_half,planar_floor` (flags check)

```
frame_probe  sha=1a7307b7  biome=frozen_shore  ab=no_ssil,shadows_low,fx_half,planar_floor
floor: kit ground uv1_triplanar=true uv1_world_triplanar=true (no planar path exists: planar_floor NOT AVAILABLE)
flags: no_ssil=on, shadows_low=on, fx_half=on, planar_floor=NOT AVAILABLE
frames=181  avg_ms=22.115  p50_ms=17.471  p95_ms=51.694  p99_ms=74.414
1pct_low_fps=12.4 (1000 / mean of the slowest 2 frames)  max_ms=86.923  over_6.94ms=178 (98.34 %)
render_cpu_ms_avg=1.714  render_gpu_ms_avg=4.096
```

The one reading worth passing on, still "smoke": the RenderingServer's own render CPU (about 1.4 ms) and GPU
(about 3.5 ms) times were far below the frame time, which suggests the frame is bound by the main thread (sim and
views) or by the busy machine, not the GPU. Only an idle-machine run can tell; that is the lead's.

## Owner-PC measurement: baseline (lead, 2026-10-26)

- Machine: the owner's PC (i7-10700K, RTX 3060, Windows 11), Godot 4.7.2 console build, 1920x1080 windowed, vsync off,
  no cap. Idle: no other Godot process (`tasklist` count 0 before the run), no agent running.
- Build: `b9ff8110` (claude/v095-feedback with RS1 and PF1 merged).
- Command: `APPDATA=$TEMP/zd-frame "$G" --language en --path . --resolution 1920x1080 --windowed -s scripts/checks/frame_probe.gd`
- Raw report heads (the per-second samples are in `build/perf/`; draw calls 1060–1470, objects 9.6k→12.4k rising over
  the 30 s, nodes ~2.6–2.8k, particle nodes 4):

```
frame_probe  sha=b9ff8110  biome=frozen_shore  ab=none
machine: renderer=forward_plus adapter=NVIDIA GeForce RTX 3060 window=(1920, 1080)  (the report does not know whether other processes were busy: name the machine and check the CPU was idle before quoting it as evidence)
scenario: Playground room seed 4404, Gun, 20 live enemies, warm-up 3.0 s, measured 30.0 s
build: ITEM_GUN_GLAIVE, ITEM_GUN_RING, ITEM_SPLIT_SHOT, ITEM_EMBER_CORE, ITEM_STORM_CORE at level 3 (Glaive, Ring, Split, fire core, lightning core)
floor: kit ground uv1_triplanar=true uv1_world_triplanar=true (no planar path exists: planar_floor NOT AVAILABLE)
flags: none
frames=2000  avg_ms=15.002  p50_ms=15.158  p95_ms=25.536  p99_ms=38.631
1pct_low_fps=18.6 (1000 / mean of the slowest 20 frames)  max_ms=135.738  over_6.94ms=1690 (84.50 %)  avg_fps=66.7
render_cpu_ms_avg=1.549  render_gpu_ms_avg=3.881  (RenderingServer viewport measured time)
```

```
frame_probe  sha=b9ff8110  biome=red_canyon  ab=none
machine: renderer=forward_plus adapter=NVIDIA GeForce RTX 3060 window=(1920, 1080)  (the report does not know whether other processes were busy: name the machine and check the CPU was idle before quoting it as evidence)
scenario: Playground room seed 4404, Gun, 20 live enemies, warm-up 3.0 s, measured 30.0 s
build: ITEM_GUN_GLAIVE, ITEM_GUN_RING, ITEM_SPLIT_SHOT, ITEM_EMBER_CORE, ITEM_STORM_CORE at level 3 (Glaive, Ring, Split, fire core, lightning core)
floor: kit ground uv1_triplanar=true uv1_world_triplanar=true (no planar path exists: planar_floor NOT AVAILABLE)
flags: none
frames=2062  avg_ms=14.551  p50_ms=15.177  p95_ms=21.246  p99_ms=38.817
1pct_low_fps=21.6 (1000 / mean of the slowest 21 frames)  max_ms=64.227  over_6.94ms=1707 (82.78 %)  avg_fps=68.7
render_cpu_ms_avg=1.583  render_gpu_ms_avg=3.791  (RenderingServer viewport measured time)
```

**Reading:** the target (every frame under 6.94 ms) is missed by far: about 67–69 fps average, 1 % lows 18.6–21.6 fps,
83–85 % of frames over 6.94 ms. The renderer's own times are small (CPU 1.5 ms, GPU 3.8–3.9 ms), so the frame is
bound by the main thread's script work (sim step and view sync), not by the GPU: shadows, SSIL and the floor are not
the first cut. The rising object count is worth a look. Next: PF2 profiles the main thread and cuts there.

## Owner-PC measurement after the cuts: NOT YET RUN

To be filled by the lead from a run on an idle machine: the exact command, the raw `build/perf/<sha>_<biome>.txt`
output and the build SHA ([`TEMPLATES.md`](../../../process/TEMPLATES.md) section 3), for Frozen Shore and Red
Canyon, then the A/B runs per flag. Target: every frame under 6.94 ms, judged on the 1 % lows.

## PF2: main-thread cuts

Step PF2 of v0.9.5. Base: `claude/v095-feedback` at `2427d296`. Machine: the owner's PC (RTX 3060) while other Godot
windows and test runs of other agents were using it, so every absolute number below is **machine possibly busy, not
evidence**. Only back-to-back ratios are quoted; the lead takes the owner-PC numbers. `fight_bench.gd` was NOT written:
the sim's phases are already measured in the renderer run through `World.phase_probe`, so the real scene needed no
second harness.

### The tool (`frame_probe.gd --breakdown`, `--process`)

`--breakdown` adds per frame (mean, p99, mean over the frames the bucket ran, frames it ran in; microseconds) the
buckets: `step_once` (the physics tick: input, `sim_step`, `ticked_all`), `sim_step` (`World.step`) with its phases
(`World.phase_probe`), `ticked_all` split per `SimDriver.ticked` listener (`tick.<script>.<method>`), `sync_all` and
`view.<name>` (each view's sync, via `WorldViewRoot.profile_sync`), `sync.occlusion`, and the frame's three engine
slices `frame.scene_process` (probe `_process` to `frame_pre_draw`), `frame.draw_pre_to_post`, `frame.rest_after_draw`.
`PerfMarks` (`src/presentation/perf_marks.gd`) is the static helper: one bool check when off. `--process` takes every
node's `_process` off the engine and times it from the probe, per script. `--ab=no_interp` turns physics interpolation
off. The per-second samples gained `resources` and `orphan_nodes`.

### Where a frame goes (Red Canyon, 15 s, one run, before any cut, busy machine)

```
frames=999 avg_ms=15.0 (66 fps)
step_once            6200 us/frame  (ran in 838 of 999 frames: ~60 Hz ticks in ~67 fps frames)
  sim_step           1596   (ai 319, move 296, proj 289 [sweep 234], nav_flood 269 [1054 on its 255 ticks], dash_abilities 153)
  ticked_all         4557
    view sync        3385   (actors 906, fireballs 207, attack_forms 154, status_fx 145, telegraphs 144, spikes 105, signatures 100, ~55 more views at 30-90 each)
    HUD (Playground) 1068   (build_hud 666 alone)
frame.scene_process  2907   (script _process of all nodes is under ~1000 of it; physics interpolation off: no change)
frame.draw_pre_to_post 3022
frame.rest_after_draw  2885
```

Reading: the 60 Hz tick (sim + view sync + HUD) is about 6.2 ms of a 15 ms frame; the engine's scene process, the draw and
the present are about 9 ms and are not script work I can cut (render CPU 1.5 ms, GPU 3.9 ms from the same run). The
view sync is a long tail: about 60 views at 30-200 us each, each looping every actor through `WorldReader` calls
(about 1 us a call in GDScript), even when its feature is idle (a boss view in a room with no boss). The 144 fps target
is NOT reachable by these cuts.

### Cuts

1. `src/presentation/hud/build_hud.gd` (+ `WorldReader.pips_key()`, `has_abilities()`): the build pips were rewritten
   every tick (`reader.build()`, `wand()`, `abilities()` allocate and parse every card; each pip write redraws a stone
   box; `_place()` re-lays the row). Now a cheap key (cards, levels, wand size, weapon form, abilities held, locale)
   gates all of it; the plate is re-placed only when the key or the anchor moved. `build_hud` 666 -> 24 us/tick; the
   Playground HUD tick (`_on_playground_tick`) 1068 -> 384 us (same session, two runs).
2. `src/presentation/world_view/fireball_views.gd`: `_draw` skips a look that has nothing in the air and drew nothing
   last time (3 MultiMesh writes per idle look per tick). `view.fireballs` about 245 -> 146-202 us.
3. `src/presentation/world_view/status_visuals.gd` (+ `WorldReader.any_status(i)`): one call replaces six per statusless
   enemy. `view.status_fx` about 200 -> 156-170 us.

Back-to-back A/B of cuts 2 and 3 (and 1) in alternating runs (before1/after1 ... before3/after3; after1 overlapped a
second probe window and is discarded): frame avg 17.6 / 17.9 / 16.8 ms before vs 15.1 / 13.6 ms after (after1 discarded).
Per-view numbers move with the machine load (`sim_step`, unchanged code, ranged 1.4-2.2 ms between runs), so read them as
direction only. Not done (checked, left): memoising `reader.telegraph(i)` (all 10 callers together cost about 220 us and
a memo could go stale inside a tick in tests), a per-kind actor index for the boss views, the hero avatar's 22-key state
dictionary (about 100 us), `ActorViews._update_actor`'s property writes. These are the next candidates.

### Object count (9.6k -> 12.4k)

Not a leak. In the 30 s samples `resources` stays 1175, `nodes` 2.5k-2.8k, `orphan_nodes` 0. A 100 s run: objects 9.6k
-> about 14k by ~50 s, then flat at 13.7-14.5k. The climb is `World._events`, the sim's bounded event log of `SimEvent`
RefCounted objects (`EVENT_LOG_CAP` 4096 + `EVENT_LOG_TRIM` 512), filling up in a fight. No per-hit material, mesh or
decal is created without being freed.

### Tests (headless, `--language en`)

- gdformat/gdlint on every touched file: clean.
- `tests/golden` 2 / 2, `tests/arch` 4 / 4 (18255 asserts), `tests/content` 158 / 158 (30 scripts).
- 18 scripts, 128 / 128 passing (27427 asserts): `test_modifier_equivalence`, `test_world_snapshot`, presentation
  `card_level_views`, `ember_stone`, `reward_cards`, `ui_polish`, `wand_views`, `status_visuals`, `enemy_fireball_views`,
  `vfx_layer`, `attack_visuals`, `boss_fight_views`; e2e `run_flow`, `playground`, `wand_build`, `swap`, `card_levels`,
  `enemy_fireballs`. Goldens and equivalence digests did not move (no sim state changed; the reader gained read-only
  functions).
- Not run: seed-loop tests, the seams, the full suite (GitHub).

## PF3: draw calls and view sync

Step PF3 of v0.9.5. Base: `claude/v095-feedback` at `975f6b79`. Machine: the owner's PC (RTX 3060) with other Godot
windows / test runs of other agents possibly active, so every absolute number is **machine possibly busy, not
evidence**. Only same-session ratios are read, and `sim_step` (code unchanged) is the load check. At most one probe
window ran at a time (5 windows: `before1`, `census0`, `after1`, `after2`, `after3`; the raw reports are in `build/pf3/`,
untracked). No baseline checkout was made (CLAUDE.md "no baseline copies"), so "before" is the first run on the
unchanged code (`before1`), not a back-to-back pair.

### The tool: `frame_probe.gd --census`

Walks the scene at the end of the measured window and counts every `is_visible_in_tree()` `GeometryInstance3D` by
owning script, mesh and material (distinct pairs, how many share a pair, shadow casters). Command (Red Canyon,
20-enemy fight, 1920x1080): `APPDATA=... godot --language en --path . --resolution 1920x1080 --windowed -s
scripts/checks/frame_probe.gd -- --biome=red_canyon --secs=15 --breakdown --census`.

### 1. Draw calls: the census says there is no static level geometry worth batching (nothing changed)

`census0` (6 s) and `before1` (15 s), Red Canyon:

```
census: visible GeometryInstance3D=535 (MultiMesh 84, shadow off 301); distinct mesh+material pairs=415;
        instances sharing a pair with another=134; distinct materials=358      (census0)
census: visible GeometryInstance3D=538 (MultiMesh 84, shadow off 374); distinct mesh+material pairs=333;
        instances sharing a pair with another=245; distinct materials=254      (before1)
by owner (census0): needle_avatar 102, actor_views 54, bomb_drone_avatar 52, stage_kit 40, damage_numbers 40,
  arc_caster_avatar 36, warden_avatar 32, shard_views 20, elite_avatar 19, hit_feel 19, vfx_layer 18, elite_bar 15, ...
```

Reading: the level (`stage_kit.gd`: 40 instances, 13 distinct meshes, 9 shadow casters; `stage_view`, `biome_backdrop`,
`kit_view` 2 each) is under 10 % of the visible instances and is already few, large pieces. The rest is the 20 enemies'
articulated rigs (Needle 102 instances for legs, barrel and eyes with IK; Bomb Drone 52; Arc Caster 36; Warden 32;
Elite 19), each piece its own mesh (96 distinct meshes among the Needles' 102 instances) with an outline `next_pass`
(each piece draws twice), plus the hit-feel / damage-number / shard pools. Merging the level's pieces would save a few
tens of draws at most; merging the rigs is not possible (their parts move every frame) without changing how they are
built. So **no geometry was batched and no shot pair was taken** (no geometry changed). Draw calls before -> after:
unchanged (`draw_calls` 923-1398 over `before1`; the PF3 cuts below do not touch the scene).

Owner questions (each would change the look, so not done; they are where the ~1000 draws come from):
1. 160-230 rig pieces cast shadows (`census0`: Needle 93 casters, Bomb Drone 44, Warden 28, Arc Caster 21, Elite 19);
   each is drawn again for every shadow cascade. Turning the shadow off on the small pieces (feet, eyes, collars) would
   cut the shadow pass; it needs a before/after shot the owner judges.
2. The outline `next_pass` on every rig piece doubles its draws; a cheaper outline (one hull per enemy, or a
   screen-space one) changes the look.
3. 64 Decals and 34 OmniLights are in the tree (`node classes` line); their cost was not separated here.

### 2. View sync: cuts (presentation, plus read-only reader functions; no sim state)

`WorldReader` gained read-only summaries (`src/sim/world/world_reader.gd`): `any_boss()`, `any_elite()` (a kind mask built
once from the sim's own `is_boss_kind` / `is_elite_kind`: one lookup per actor), `any_kind(kind)`, `any_egg()`,
`any_telegraph()` (native `has` scans), `heat_tier()` (= `heat_state()["tier"]` without building the 21-key
dictionary), `swing_step()`. `telegraph(i)` now returns `{}` at once unless the actor is winding up, active or a Mine
Layer (every sim `telegraph` branch needs one of those); `boss_index()` early-outs on `any_boss()`.

| File | What | Measured (view us/tick, `before1` -> `after1` / `after3`; noisy) |
|---|---|---|
| `stone_spike_views.gd` | actor loop only with a boss in the room | spikes 102 -> 10 / 11 |
| `boss_shield_view.gd`, `boss_challenge_view.gd`, `boss_strike_views.gd` | same | boss_shields 28 -> 5, challenge 39 -> 18, strikes 50 -> 25 |
| `boss_signature_views.gd` | egg loop only with an egg | signatures 98 -> 44 / 48 |
| `elite_views.gd`, `event_pedestal_views.gd` | loops only with an elite | elite_fx 62 -> 41 / 51 |
| `telegraph_views.gd` | loop only when some actor can have a telegraph | telegraphs 153 -> 89 / 110 |
| `fireball_views.gd` | the lob loop only with a Bomb Drone | fireballs 208 -> 163 / 181 |
| `horde_visuals.gd` | the loop only with a Mender or Sniper | 52 -> 58 / 55: no change (this scenario's mix has them) |
| `actor_views.gd`, `attack_form_view.gd`, `kit_view.gd`, `skill_visuals.gd` | `heat_tier()` instead of `HeatLooks.tier_of(reader.heat_state())` (4 dictionaries a tick) | inside actors / attack_forms / kit (kit 43 -> 40 / 32) |
| `player_avatar.gd` (+ `swing_step()`) | the hero's state reads one swing step, not four rebuilds | `actors.hero_sync` 158 (`after2`, busier) -> 101 (`after3`) |
| `actor_views.gd` | `facing` / `bar` / `dazed` `visible` written only when changed; `PerfMarks` buckets `actors.update / enemy_sync / hero_sync / animate` | part of `actors.update` |
| `elite_bar.gd` | `set_fraction` re-lays the bar only when the fraction or the chunk changed (the layout is a function of those two) | elites only |

Totals (same scenario, Red Canyon, 15 s; `sim_step` is unchanged code, used as the load check):

```
                    before1   after1   after3
sim_step (us)          1585     1426     1521
sync_all (us)          3453     2758     2993      (sync_all / sim_step: 2.18 -> 1.93 -> 1.97)
step_once (us)         5603     4681     5031
view.actors (us)        959      793      906
frames avg_ms         13.98    12.83    13.44      1pct_low_fps 16.9 / - / 20.1
```

So the view sync is about 10 % cheaper by the load-normalised ratio, mostly from views that are idle with no boss /
elite (a boss fight will not get those savings). `view.heat_fx` read 50 -> 85 -> 107 us with no change to its file (its
p99 is 1.2-1.5 ms): unexplained, probably the hero's heat tier in that run; not investigated.

Not done (checked, left): the projectile-form views (glaives, seekers, voids, pulses, blade_forms) each loop every
projectile and call `Attacks.projectile_spec` per player shot; a cheap guard needs a per-projectile form index the World
does not keep (next candidate: classify each projectile once per tick in the reader); `status_fx` per-actor calls (about
6 us each); the hero avatar's 22-key dictionary (its reads cost, not the dictionary); `actors` self time (about 550 us
of 900: per-actor reader calls, `get_meta`, dictionary bookkeeping).

### 3. The tick spike: what is left

`after3` (74 fps average, so a tick in 829 of 1116 frames; at 144 fps about 42 % of frames run one):

```
step_once: 5031 us/frame mean, 6772 us in the frames that tick, p99 19.5 ms
  sim_step 1521 (ran 2047), sync_all 2993 (ran 4030), HUD _on_playground_tick 368
frame.scene_process 3316   frame.draw_pre_to_post 3211   frame.rest_after_draw 1877   (every frame, about 8.4 ms)
```

A frame that ticks costs about 6.8 ms of script on top of about 8.4 ms of engine slices (about 15 ms against the 6.94 ms
target); a frame without a tick is the 8.4 ms alone, already over the target. **The target cannot be met by script cuts**:
even a free tick leaves the engine slices (scene process 3.3 ms, draw 3.2 ms, present 1.9 ms) over 6.94 ms. Those slices
follow node and draw counts (about 2.6k nodes, 466-540 visible instances, 1000+ draw calls, 64 Decals, 34 OmniLights),
so the next levers are the owner questions above, and an engine-level look at what `scene_process` does (transform
updates of ~1500 MeshInstance3D, Label3D, Decal), which this tool cannot see.

Proposal for the tick spike (not implemented: it changes the order every view relies on): sync the non-critical effect
views (about 40 views of 3-60 us that draw particles and marks) every other tick, in two staggered halves, and let their
`_process` interpolate. It would take about 1 ms off tick frames but delays those views by up to 16 ms, so it is the
owner's call. It does not change the 8.4 ms floor.

### Tests (headless, `--language en`)

- gdformat / gdlint on every touched file: clean (18 files).
- `tests/golden` + `tests/arch` + `tests/content`: 33 scripts, 164 / 164, 31508 asserts.
- 81 scripts that reference the changed views, `WorldViewRoot`, `test_modifier_equivalence` and `test_world_snapshot`:
  613 / 613, 313282 asserts (`test_curse_room` excluded: seed-loop).
- e2e `run_flow`, `playground`, `achievements`, `arenas`, `ascension`: 9 / 9, 284 asserts.
- Goldens and `modifier_equivalence` digests did not move (no sim state changed; the reader gained read-only
  functions, and `telegraph(i)` returns the same `{}` it returned before for the states it now skips).
- Not run: seed-loop tests, the seams, the full suite (GitHub). Screenshots: none (no geometry or look changed).

## PF4: outlines off, simpler shadows, effects at 30 Hz

Step PF4 of v0.9.5. Base: `claude/v095-feedback` at `10d2751b`. Machine: the owner's PC (RTX 3060), other agents' Godot
runs possibly active, so every absolute number is **machine possibly busy, not evidence**. The runs are one probe window
at a time, in this order: `on` (baseline, outlines on), `cut1` (outlines off), `cut2` (+ shadow trim), `cut3` (+ 30 Hz).
`on` ran while the machine was clearly busier (a 1.9 s hitch, 24.6 ms average): do not compare it with the others.
`cut1`..`cut3` are not back-to-back A/Bs either (the 20 enemies are topped up from a time-driven strafe, so their mix
differs per run); read the census columns, which are counts, and treat the frame times as direction only.
Command (each run): `APPDATA=... godot --language en --path . --resolution 1920x1080 --windowed -s
scripts/checks/frame_probe.gd -- --biome=red_canyon --secs=15 --breakdown --census --shot=<png>` (raw reports in
`%TEMP%/zd-pf4/run_*.txt`, not tracked).

### The three cuts

1. **Outlines off** (`src/presentation/world_view/actor_looks.gd`, new): `ActorLooks.OUTLINES := false` is the one switch
   (`true` = the pre-PF4 look). With it off no outline material is created anywhere: `AvatarBase.outline_material`
   (the code-built bodies of the Needle, Warden, Arc Caster, Bomb Drone, hero, epic robe), `EnemyLooks.body` (the horde,
   Charger and elite shared materials: no `next_pass`, and the shader's `stencil_mode write` line is dropped),
   `BossParts` (bosses' code pieces, Lens Drone), `ActorViews._body_material` (the grey-cube fallback), the owner's boss
   model materials (`BossAvatar._dress`, `LensDroneAvatar`), and `AvatarBase.write_stencil` (faces, visors, eyes no
   longer write the stencil). All go through `ActorLooks.outline(mat, colour, thickness)`; shard rock outlines
   (`ShardMesh.outline_material`, scenery, not actors) are untouched. Readability that leaned on the outline: I found
   none. The hit flash and status tints are the body material's emission (`EnemyLooks.HIT` / `flashable()`), the team
   colour is the body albedo and the red ground ring under each enemy is its own mesh, so all of them still work
   with the outline off (the shots show them). Tests that asserted the outline now assert it follows
   `ActorLooks.OUTLINES` (`ActorLooks.outline_mode()`), keeping their other coverage.
2. **Simpler enemy shadows** (`shadow_trim.gd`, new; called from `ActorViews._make_actor`): after an enemy's model is
   built, every shadow-casting `MeshInstance3D` under its facing node except the largest 2 by mesh-AABB volume (times
   the pieces' scale in the avatar) gets `SHADOW_CASTING_SETTING_OFF`; bosses keep the largest 4; the hero is skipped.
   `ShadowTrim.ENABLED` turns it off in one line.
3. **Effects every other tick** (`view_schedule.gd`, new; `WorldViewRoot._sync_view`): `ViewSchedule.HALF_RATE` lists the
   30 Hz views and their parity; a listed view syncs only on its parity's ticks (its very first sync always runs);
   `WorldViewRoot.half_rate_enabled := false` turns it off. On 30 Hz:
   - `status_fx` (even ticks): burn / frost / poison particles, rings and pips riding an enemy. Safe: the effect nodes are
     children of the enemy's own node, which still moves every tick; the sim state (the status itself) is not read late
     for anything but the picture; a status shows or clears up to 1 tick (16 ms) later; the animation clock now counts
     ticks (`_frame += ticks since the last sync`), so the speed is unchanged. Found by the run: the view kept a freed
     enemy node for the extra tick and errored (16 `SCRIPT ERROR`s), fixed by checking validity before the typed read.
   - `modifier_marks` (odd ticks): the hero's own shell / charge / phase auras and the poison-drop / queued marks. Safe:
     the player's own cards, nothing an enemy does and nothing to dodge; the aura follows the hero up to 1 tick late
     (about 0.1 m at full speed).
   Looked at and left at 60 Hz because they show something the player reacts to or keep per-tick state: `telegraphs`,
   `fireballs`, `elite_fx`, `boss_*`, `strikes`, `spikes`, `cores`, `heat_fx` (emits on `tick % N`; half the ticks would
   skip every emit), `item_fx` (per-tick afterimages), `element_fx` (fire patches are hit areas), `stress_marks` (the
   weak sides are gameplay), `remnants`, `damage_numbers`, `hit_feel`. So only two views qualify as
   safe; "half on even, half on odd" is one each. More could move with owner say-so.

### Census and probe, Red Canyon, 20 enemies (this machine, busy-ness unknown)

| run | draw calls (15 s mean) | visible instances | shadow off | shadow casters | frame avg / p99 ms | 1 % low fps | render CPU / GPU ms |
|---|---|---|---|---|---|---|---|
| `on` (outlines on; busy machine) | 1250 | 518 | 272 | 246 | 24.57 / 64.89 | 2.5 | 4.81 / 3.58 |
| `cut1` outlines off | 943 | 502 | 252 | 250 | 9.88 / 17.30 | 19.0 | 1.22 / 3.10 |
| `cut2` + shadow trim | 814 | 565 | 498 | 67 | 10.21 / 18.53 | 17.5 | 1.19 / 3.06 |
| `cut3` + 30 Hz views | 835 | 517 | 454 | 63 | 11.79 / 18.78 | 16.2 | 1.29 / 3.35 |

Shadow casters before -> after the trim: 250 -> 67 (the cut's own pair, `cut1` -> `cut2`; 246 on the busy-machine
baseline). The 1 % lows are dominated by one 0.5 s hitch at the start of each run (`max_ms` ~ 500 in all three), not by
the steady frames; the p99 is the steadier figure. Per-view means (us per tick, `status_fx` / `modifier_marks`):
`cut2` 95 / 23 -> `cut3` 68 / 13 (ran in 436 of 870 frames each). **144 fps (6.94 ms) is NOT reached by this step**: the
average is 9.9-11.8 ms here, with the engine slices still the bulk.

### Shots (1920x1080, `build/shots/v0.9.5/pf4/`, untracked)

`outlines_on_fight.png`, `outlines_off_fight.png` (a 20-enemy Red Canyon fight; the two moments are the same scenario
at the same probe time but the fight is not tick-identical), `outlines_on_boss.png`, `outlines_off_boss.png` (the
Gatekeeper, 8 s in). The boss pair looks identical: the bosses' models already drew no outline (owner, v0.7.5), so the cut
changes the code-built enemies only. Also `shadows_trimmed_fight.png` and `effects30_fight.png`. I looked at both pairs: the enemies stay readable against the red floor without the edge line, and the flash, the burn tint and the ground ring still show; how it feels is the owner's call.

### Tests (headless, `--language en`)

- gdformat / gdlint on every touched file: clean.
- `tests/golden` + `tests/arch` + `tests/content`: 33 scripts, 164 / 164, 31535 asserts.
- `tests/unit/presentation` (whole folder, includes the new `test_shadow_trim.gd`): 163 scripts, 1101 / 1101, 1967790 asserts.
- e2e `test_e2e_run_flow`, `test_e2e_playground`: 4 / 4, 112 asserts.
- `tests/unit/sim/test_modifier_equivalence.gd`: 3 / 3, 68 asserts.
- Goldens and equivalence digests did not move (presentation only; no sim file changed).
- Not run: seed-loop tests, the seams, the full suite (GitHub).

### Probe tool

`frame_probe.gd` gained `--shot=<png>` (saves the viewport 0.5 s before the end) and `--boss=<table index>` (one boss
5 m from a standing hero instead of the 20 enemies; it prints the boss's screen position at the shot).

### OWNER ONLY

- Whether the look without outlines is acceptable (flip `ActorLooks.OUTLINES` to `true` to get it back).
- Whether the enemies' shadows with only their 2 largest pieces look right in motion.
- Frame times on the owner's hardware with nothing else running.

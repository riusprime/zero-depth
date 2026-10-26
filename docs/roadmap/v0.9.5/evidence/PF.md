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

## Owner-PC measurement: NOT YET RUN

To be filled by the lead from a run on an idle machine: the exact command, the raw `build/perf/<sha>_<biome>.txt`
output and the build SHA ([`TEMPLATES.md`](../../../process/TEMPLATES.md) section 3), for Frozen Shore and Red
Canyon, then the A/B runs per flag. Target: every frame under 6.94 ms, judged on the 1 % lows.

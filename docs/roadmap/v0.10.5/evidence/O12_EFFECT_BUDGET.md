# O12_EFFECT_BUDGET: does the hero's effect budget hold its caps, keep hostile cues untouched, and what does it do to frame time?

- **Status:** RUN
- **Build:** worktree `wt-o12`, branch `v0105-o12` cut from `05ca91be`. "Before" ran on `05ca91be` with only the probe's
  new options added (no `src/` change); "after" on the same tree with this step's changes, uncommitted when it ran (the
  probe prints the HEAD it found: `05ca91be`); the step's commit is the one that adds this file.
  Godot `4.7.2.stable.official.ed1daf0bf`; Windows 11 Pro 10.0.26200.
- **Machine:** the owner's PC, i7-10700K, RTX 3060 (the probe reads `NVIDIA GeForce RTX 3060`, Forward+), 1920 x 1080
  windowed, vsync off, no fps cap. The window was placed off screen (`--position -10000,-10000`). Nothing else heavy ran
  during the three timed runs (the test runs started after them).
- **Date:** 2026-11-02
- **Who ran it:** agent

Owner line **P9** (2026-11-01, theory audit): "yes cap it it will also help fps". Overnight mode ("Pick and build"):
every value below is the agent's starting value.

## What was built

`src/presentation/world_view/vfx/hero_fx_budget.gd` (`HeroFxBudget`), handed by the forms' canvas to the effects layer
each frame:

| Category | Cap a frame, High / Medium / Low (Effects density) | Past the cap |
|---|---|---|
| Hero sprites in VfxCore (the forms' canvas + `VfxCore.hero_drawers`: laser, bombs, lances, voids, scatter, runes, glaives, seekers, waves, wisps, the hits' impacts) | `SPRITES` 160 / 110 / 60 | past 75 % (`SOFT`) the oldest draw at 55 % alpha (`OVER_ALPHA`) and 80 % size (`OVER_SCALE`); past the cap they are skipped |
| The forms' meshes and particles (the existing caps: 1024 / 640 / 384 meshes, 1200 x 1 / 0.55 / 0.25 particles) | unchanged | the last quarter of each cap draws at 55 % alpha |
| Live bolts with an element rim and trail | `LIVE_BOLTS` 96 / 64 / 32 (was 96 at every density) | the rest fly as their plain dart |
| Pack effects (PackFx) | unchanged: the per-family caps (`PackFx.CAPS`, scaled by density) | the family's oldest is reused (as before) |

The dimming rule: each enemy telegraph on screen is one threat (`TelegraphViews.threats`: every windup, drawn on the
ground or told by its avatar), and every 4 enemy shots on screen (`SHOTS_PER_THREAT`) one more. Above `DIM_FROM` 4
threats the hero's effects head toward 60 % opacity (`DIM_ALPHA`), reached at `DIM_FULL` 12, moving 1.5 a second
(`DIM_PER_S`, once a sim tick), and come back the same way.

Never in the budget: enemy telegraphs (`TelegraphViews`), hostile shots (`FireballViews`, PackFx `enemy_shot`), boss
strikes, spikes and signatures (`VfxCore.drawers`, their own views), enemy statuses, props. The hero's drawers now run
before the others in `VfxCore.finish()` and are capped at 160 of the layer's 2,000 sprites, so the enemies' drawers
always keep at least 1,840 (before, the hero's canvas drew first with no cap of its own and could take the whole 2,000).

The Options "Effects density" (Low / Medium / High) already existed (v0.6.0 MX3); "Reduced" is its Medium and Low,
which now also lower the hero sprite cap and the live-bolt cap. No new setting, no new strings.

## Command

The probe: `scripts/checks/frame_probe.gd` with three new options (`--enemies=N`, `--heavy`: six more cards at level
5 on top of the probe's five, `--fx`: the per-frame effect counts). It boots `main.tscn`, opens the Playground, fires
and strafes on a script. Real time: the two runs do not see the same frames.

```
export APPDATA=$(mktemp -d)
godot --path . --position -10000,-10000 --resolution 1920x1080 --windowed -s scripts/checks/frame_probe.gd -- \
  --biome=red_canyon --enemies=60 --heavy --fx --secs=20 --warm=4 --shot=build/o12/before_red_canyon.png
# after: the same, --shot=build/o12/after_red_canyon.png
```

## Raw output: before (`05ca91be`, no `src/` change)

```
frame_probe  sha=05ca91be  biome=red_canyon  ab=none
machine: renderer=forward_plus adapter=NVIDIA GeForce RTX 3060 window=(1920, 1080)  (the report does not know whether other processes were busy: name the machine and check the CPU was idle before quoting it as evidence)
scenario: Playground room seed 4404, Gun, 60 live enemies, warm-up 4.0 s, measured 20.0 s
build: ITEM_GUN_GLAIVE, ITEM_GUN_RING, ITEM_SPLIT_SHOT, ITEM_EMBER_CORE, ITEM_STORM_CORE, ITEM_GUN_TWIN, ITEM_HALO_SHOT, ITEM_GUN_RAPID_FIRE, ITEM_WILDFIRE, ITEM_CHAIN_BLAST, ITEM_GUN_RUNE_EXPLOSION at level 3 (Glaive, Ring, Split, fire core, lightning core) + the --heavy cards at level 5
floor: kit ground uv1_triplanar=true uv1_world_triplanar=true (no planar path exists: planar_floor NOT AVAILABLE)
flags: none
frames=353  avg_ms=57.113  p50_ms=54.326  p95_ms=91.357  p99_ms=119.357
1pct_low_fps=3.8 (1000 / mean of the slowest 4 frames)  max_ms=594.419  over_6.94ms=353 (100.00 %)  avg_fps=17.5
render_cpu_ms_avg=2.818  render_gpu_ms_avg=10.918  (RenderingServer viewport measured time)
[… 22 lines trimmed: pack_fx totals and the per-second draw-call samples …]
fx counts per measured frame (avg / p50 / p95 / max):
  forms_meshes: 0.2 / 0 / 2 / 5
  forms_particles: 1.4 / 0 / 12 / 30
  layer_sprites_all: 85.7 / 57 / 198 / 251
  pack_hero_live: 49.9 / 44 / 84 / 93
  pack_enemy_shot_live: 22.2 / 19 / 40 / 43
  telegraphs_drawn: 2.5 / 3 / 6 / 7
```

An earlier "before" run on the same tree (its fx counters were broken: a packed array stored by value, fixed before
the run above) timed `frames=339 avg_ms=59.301 p50_ms=58.495 p95_ms=87.638 p99_ms=119.137`: the run-to-run spread here.

## Raw output: after (this step's changes)

```
frame_probe  sha=05ca91be  biome=red_canyon  ab=none
machine: renderer=forward_plus adapter=NVIDIA GeForce RTX 3060 window=(1920, 1080)  (the report does not know whether other processes were busy: name the machine and check the CPU was idle before quoting it as evidence)
scenario: Playground room seed 4404, Gun, 60 live enemies, warm-up 4.0 s, measured 20.0 s
build: ITEM_GUN_GLAIVE, ITEM_GUN_RING, ITEM_SPLIT_SHOT, ITEM_EMBER_CORE, ITEM_STORM_CORE, ITEM_GUN_TWIN, ITEM_HALO_SHOT, ITEM_GUN_RAPID_FIRE, ITEM_WILDFIRE, ITEM_CHAIN_BLAST, ITEM_GUN_RUNE_EXPLOSION at level 3 (Glaive, Ring, Split, fire core, lightning core) + the --heavy cards at level 5
floor: kit ground uv1_triplanar=true uv1_world_triplanar=true (no planar path exists: planar_floor NOT AVAILABLE)
flags: none
frames=319  avg_ms=63.326  p50_ms=62.661  p95_ms=89.704  p99_ms=113.415
1pct_low_fps=3.8 (1000 / mean of the slowest 4 frames)  max_ms=638.187  over_6.94ms=319 (100.00 %)  avg_fps=15.8
render_cpu_ms_avg=2.967  render_gpu_ms_avg=10.571  (RenderingServer viewport measured time)
[… 22 lines trimmed: pack_fx totals and the per-second draw-call samples …]
fx counts per measured frame (avg / p50 / p95 / max):
  forms_meshes: 0.2 / 0 / 1 / 4
  forms_particles: 1.3 / 0 / 6 / 24
  layer_sprites_all: 94.7 / 87 / 183 / 245
  hero_sprites_drawn: 42.6 / 38 / 111 / 160
  hero_sprites_dimmed: 0.6 / 0 / 0 / 40
  hero_sprites_skipped: 0.0 / 0 / 0 / 11
  hero_alpha_x100: 69.2 / 62 / 95 / 100
  hostile_threats: 10.3 / 12 / 12 / 17
  pack_hero_live: 53.8 / 57 / 78 / 85
  pack_hit: 16.7 / 21 / 24 / 24
  pack_impact: 0.4 / 0 / 2 / 3
  pack_explosion: 4.6 / 4 / 8 / 9
  pack_area: 6.4 / 7 / 12 / 14
  pack_beam: 1.7 / 2 / 3 / 4
  pack_projectile: 0.0 / 0 / 0 / 0
  pack_status: 18.4 / 19 / 27 / 29
  pack_bolt: 5.6 / 6 / 15 / 20
  pack_trail: 0.0 / 0 / 0 / 0
  pack_mark: 0.0 / 0 / 0 / 0
  pack_enemy_shot_live: 26.0 / 28 / 38 / 46
  telegraphs_drawn: 2.3 / 2 / 5 / 6
```

An intermediate run (the budget wired with a 900-sprite cap that never bit, and every enemy shot one threat) timed
`frames=344 avg_ms=58.192 p50_ms=61.450 p95_ms=88.435`; it measured the hero's sprites at 41.9 / 30 / 115 / 166
(avg / p50 / p95 / max), which set `SPRITES` High to 160, and the threats pinned at 12 by the enemy shots alone, which
set `SHOTS_PER_THREAT` to 4.

## Result

| Metric | Before | After | Note |
|---|---|---|---|
| Frame time p50 (ms) | 54.3 (58.5 in the earlier run) | 62.7 | within the run-to-run spread; no gain shown |
| Frame time p95 (ms) | 91.4 (87.6) | 89.7 | the same |
| Render CPU / GPU avg (ms) | 2.8 / 10.9 | 3.0 / 10.6 | the GPU's share is ~11 of ~60 ms |
| All effects-layer sprites p95 / max | 198 / 251 | 183 / 245 | |
| Hero sprites p95 / max | (not split before) | 111 / 160 | the cap held: max = 160 |
| Hero sprites dimmed / skipped, max a frame | — | 40 / 11 | it bites only at the heaviest moments |
| Hero effects' opacity avg / p50 (%) | 100 | 69 / 62 | 60 enemies kept it near 60 % most of the run |
| Pack hero instances p95 / max | 84 / 93 | 78 / 85 | unchanged rule (per-family caps) |

## Interpretation

- **The caps hold and the hostile cues are untouched** (also unit-tested below). The hero's sprites never passed 160;
  enemy shots, telegraphs and boss drawers are outside the budget.
- **No fps gain measured.** This heavy scene runs at ~16-18 fps on this PC before and after; the render thread's
  measured time is ~14 ms of a ~60 ms frame, so the cost is the main thread (the sim and the views of 60 enemies and an
  eleven-card build), not the effects drawn. The hero's sprites were ~40 a frame on average: capping them cannot buy
  much. The owner's "it will also help fps" is not shown by this probe.
- **The dimming is the bigger visible change.** With 60 enemies (each a few shots, a few windups) the hero's effects sat
  near 60 % opacity most of the run. Whether that reads better or just looks dimmer is the owner's call.
- **The shots are not a matched pair.** Real-time scenario: the two shots catch different moments of the fight. In
  both, the loudest layer is the burning enemies' flames (enemy statuses, kept outside the budget on purpose: they say
  which enemy burns).

Shots (not tracked, under `build/`): `build/o12/before_red_canyon.png`, `build/o12/after_red_canyon.png`.

## Tests

```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/presentation/test_hero_fx_budget.gd -gexit
Tests                10
Passing Tests        10
Asserts              44
```
(it runs again in the folder run below)

```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/e2e/test_e2e_attack_order.gd,res://tests/e2e/test_e2e_blade_feel.gd,res://tests/e2e/test_e2e_boss_strikes.gd,res://tests/e2e/test_e2e_bosses_2.gd,res://tests/e2e/test_e2e_stone_spikes.gd,res://tests/e2e/test_e2e_wand_blade.gd,res://tests/content/test_vfx_manifest.gd,res://tests/content/test_locale_coverage.gd,res://tests/arch/test_layering.gd,res://tests/arch/test_sim_purity.gd,res://tests/unit/sim/test_readable_cause.gd -gexit
Scripts              11
Tests                27
Passing Tests        27
Asserts           25228
```

```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/presentation -ginclude_subdirs -gexit
Scripts             177
Tests              1276
Passing Tests      1271
Failing Tests         5
Asserts           1964912/1964921
```

The 5 failures, checked against the base `05ca91be` in a temporary worktree (same command with `-gtest=` on the files):
- `test_blade_feel.gd` `test_a_blade_hit_holds_the_hero_s_swing_and_the_struck_enemy_for_2_4_frames` (2 asserts),
  `test_item_visuals.gd` `test_bolts_change_with_items` and `test_ember_edge_turns_the_blade_orange`,
  `test_seekers_view.gd` `test_a_volley_shows_three_needles_whose_trails_grow_then_go`: **fail on the base too**
  (pre-existing: S1's hit-stop is back to 2 frames while the test expects 2.4; O9 replaced the stat cards the item test
  reads; the Seekers' darts outlive the test's 60 ticks). Not O12's.
- `test_item_cards.gd` `test_the_pick_panel_shows_the_offer_with_rarity_frames`: failed in the folder run, **passes**
  when its file runs alone on this tree (11 tests, the only failure the Seekers' one above) and on the base; order
  dependent, not touched by O12.

Lint: `gdformat --check src scripts tests` clean (1553 files); `gdlint src scripts tests` reports one problem,
`tests/e2e/test_e2e_wand_build.gd:84` max-line-length, a file this step does not touch (pre-existing).

## Picks for the owner

1. **The caps** (starting values): hero sprites 160 / 110 / 60 a frame, live rimmed bolts 96 / 64 / 32, the oldest
   quarter at 55 % alpha and 80 % size. Keep, or raise / lower?
2. **The dimming:** 60 % at 12+ threats, from 4, 1.5 a second; every 4 enemy shots count as one telegraph. In a
   60-enemy horde it sits near 60 % most of the time. Keep it, count telegraphs only (not shots), or a softer floor
   (70-80 %)?
3. **Enemy statuses** (burning flames on enemies, the loudest layer in both shots) are outside the budget: they tell
   which enemy burns. Put them in the hero's budget (dimmed and capped with the rest)?
4. **The pack's instances** keep their per-family caps only. A total cap on the hero's pack instances needs each spawn
   tagged hero or hostile (bosses share families such as `explosion`), so it was not built. Want it?
5. **FPS:** the budget did not move frame time in this scene; the main thread is the cost. A `--breakdown` run of the
   same probe would name the hot spots, if the owner wants a performance step.

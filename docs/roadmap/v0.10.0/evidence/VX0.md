# v0.10.0 Step VX0: the VFX pack is in; the fire explosion uses it

Machine for every timing below: the owner's PC (i7-10700K, RTX 3060, Windows 11, Godot 4.7.2 console build, Vulkan
Forward+). Other programs were open (the build ran next to Claude Code), so the frame times rank the two runs and do
not replace the owner's own run. Branch `v0100-vx0`, cut from `v095-ep-int` (`bbf5e61f`). Build SHA of the probes:
`bbf5e61f` plus this step's uncommitted tree.

**Owner to judge (OWNER ONLY):** whether the pack's fire explosion looks right, and whether its cost is acceptable
before VX1-VX8 convert the rest. Nothing here is a playtest.

## 1. What went in

- **Installed:** the ten attack packs into `assets/BinbunVFX/` (871 files besides `.import` and `.uid`, 11 MB on disk)
  and `addons/magic_circles/` (without `demo/`, with `LICENSE.txt`, 69 KB). `newVFX/` is not in git.
- **Demo scenes skipped:** `fire_effects/demo.tscn`, `beam_vfx_scene`, `ice_effects_scene`, `magic_orbs_scene`,
  `magic_orb_flash_vfx_03_demo`, `magic_projectiles_scene`, `main.tscn` (Impact), `magic_areas_scene`,
  `poison_effects_scene`, `smoke_effects_scene`.
- **`PackFx`** (`src/presentation/world_view/vfx/pack_fx.gd`), its table `data/vfx/pack_fx.tres`
  (`PackFxDefinition`, `src/content/defs/pack_fx_definition.gd`: ids, scenes, families, scales, three colours) with
  four rows: `explosion_fire_a/b/c` (`vfx_explosion_01/03/04`) and `smoke_after` (`smoke_vfx_02`, family `cloud`).
- **VfxLayer** (`vfx_layer.gd`): `_explosion` is now `_pack_explosion` (or, with `PACK_EXPLOSION := false` or no
  PackFx, the old sprite body `_explosion_sprites`) plus `_explosion_rest` (sparks, VfxCore's merged light, the scorch
  mark: unchanged).
- **WorldViewRoot** makes the PackFx next to the VfxLayer and queues the warm-up.
- **Credits (I10):** `scripts/content/build_credits.gd` now lists the Binbun folder through
  `assets/BinbunVFX/manifest.json` (licence line + `files_total`) and names the addon "Magic Circles 3D Free"
  (its `LICENSE.txt`, which begins with the CC BY credit line, is the body); `data/credits/licences.tres` was rebuilt
  with the builder, not by hand. `test_credits_licences.gd` expects the CC BY text for that addon (the MIT phrase stays
  required for the others).

### The fire-explosion callers (everything that reaches `_explosion`)

`burst(kind)` falls through to `_explosion` for kind `&"fire"` or `&""`:

| Caller | When |
|---|---|
| `AttackFormCanvas._landing_at` (`attack_form_canvas.gd:796`) | a LOB form's landing, any no-element or fire shot |
| `AttackFormCanvas._draw_burst` (`:830`) | a BURST form: Explosive's blasts, Chain Blast and the other burst cards (fire or no element) |
| `StatusVisuals` `wildfire` payoff (`status_visuals.gd:536`) | a burning kill spreading Wildfire |
| `BossStrikeFx` `shell` strikes (`boss_strike_fx.gd:40`) | a boss shell landing |
| `BombView.draw_fx` (`bomb_view.gd:333`) | the retired Bomb form's blasts (kept in code; the Bomb was removed in BR, a held Bomb becomes Void) |

### The `shared/` collisions and the other load problems

Nine of the ten packs ship their own copy of `assets/BinbunVFX/shared/`; the zips were copied in the brief's order
(later wins). The copies differ in **76** files (noise/gradient `.tres` and two shader files). Resolved so that every
effect scene (260) loads with zero engine warnings or errors, in headless and with a GPU:

1. **Duplicate UID:** `smoke_effects/src/shader/util/dithering.gdshaderinc` and `shared/shader/util/` shipped the same
   uid. The smoke copy is still included by its own `alpha.gdshaderinc`, so it was kept with its `.uid` removed (Godot
   wrote it a new one).
2. **`#include` in shaders:** Godot's headless dummy renderer does not run the shader preprocessor, so the five pack
   shaders that `#include` (`shared/shader/{transparent,opaque,particle,glow_fresnel}`, `smoke_effects/.../smoke`)
   logged `Tokenizer: Unknown character #35` and failed every test that loaded them. They are inlined by
   `scripts/assets/inline_pack_shader_includes.py` (the draw is the same: an include is textual; the `.gdshaderinc`
   files stay, unused). **Not needed for the four VX0 rows except `smoke_after`.**
3. **VRAM-compressed textures:** 28 vendor `.import` files were `compress/mode=2` with an `s3tc.ctex` that only a GPU
   import writes (`Unable to open file ... .s3tc.ctex` in headless), plus 5 with `detect_3d/compress_to=1`. Rewritten to
   lossless mode 0 with the uid kept, by `scripts/assets/fix_pack_imports.py`. **Cost:** those textures (flares, flashes,
   spirals) are lossless, not VRAM-compressed (more video memory; none is used by the VX0 rows).
4. **Cache path inside three materials** (`load_path = res://.godot/imported/...s3tc.ctex` in
   `basic_area_06_flare_01/02.tres`, `magic_orb_small_06_flare.tres`): turned into normal references to the texture's
   source file (same script).
5. **Uid mismatches:** 5 `.tres` referenced `spirals_02/04/05.png` by a uid the later zip's `.import` no longer carried;
   corrected to the installed uid (same script).
6. **`fire_area.gd`** (vendor script) read `get_node("WaveMesh")` in two property setters before the scene has children
   (`Node not found` on instantiate). Both now use `get_node_or_null` and skip when it is absent.

Re-installing a pack means running the two scripts again (`python scripts/assets/fix_pack_imports.py`, then
`python scripts/assets/inline_pack_shader_includes.py`), then the import.

## 2. PackFx behaviour (as built)

- **Pools** per id; an instance is hidden and reused. A spawn sets the controller's `autoplay` false before it enters
  the tree (otherwise the controller loops the effect by itself), restarts its GPUParticles3D and plays the
  `main` animation from 0. It returns to its pool when `main` finishes or after its own life (the animation, or twice
  the particle lifetime for an effect without an AnimationPlayer such as the smoke) plus 0.1 s.
- **Caps (I5):** hit 24, impact 12, explosion 12, area 16, beam 8, cloud 4, projectile 96, status 32 at Effects density
  High; the family's oldest live instance is reused past the cap. **Density (I9):** x0.25 / x0.55 / x1, rounded up,
  at least 1.
- **Lights (I3):** `light_enable = false` on the controller and every `Light3D` under the instance hidden.
- **Colours (I6):** the caller's `{primary, secondary, tertiary}`, else the table's (alpha 0 = the scene's own, which is
  restored on every reuse).
- **Pause (I8):** `VfxLayer.begin(now)` calls `PackFx.follow(now)`: no new sim tick for 0.1 s of real time is a pause, and
  every live instance's `speed_scale` is 0 (and its life timer holds) until a tick moves again. The views have no pause
  flag to read (the driver pauses by not ticking), so the held state is read from the sim clock.
- **Warm-up (I2):** `WorldViewRoot` queues one ViewBuildQueue job per id (`pack_fx_warmup_<id>`, added from the
  `pack_fx_warmup` job), each spawning its effect once at the camera's ground focus (2 m toward the camera) with the
  loading cover up; it goes back to its pool 2 frames later. **Deviation from the brief:** the brief said one job
  calling `warm_all()`. As one job the load's longest frame was 1.1 s (below); per id it is 0.5 s. `warm_all()` still
  exists (all at once) and the tests use it.

## 3. Tests

Commands (Git Bash, repo root, `APPDATA` pointed at a folder under `build/`; `G` = the console Godot):

```
G --headless --path . --editor --import --quit
G --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=<files> -gexit
gdformat --check src scripts tests ; gdlint src scripts tests
```

| Run | Result (raw) |
|---|---|
| New and touched: `tests/unit/presentation/test_pack_fx.gd`, `test_pack_explosion.gd`, `tests/content/test_pack_fx_scenes.gd`, `test_credits_licences.gd`, `test_assets.gd` | `Scripts 5 / Tests 29 / Passing Tests 29 / Asserts 136` |
| `tests/content`, `tests/arch`, `tests/golden` (whole folders; before the warm-up was split per id) | `Scripts 34 / Tests 168 / Passing Tests 168 / Asserts 31617 / All tests passed!` |
| The VfxLayer / VfxCore / attack-form presentation tests (`test_attack_forms`, `test_attack_visuals`, `test_attack_visuals_2`, `test_blade_feel`, `test_hit_impact`, `test_screen_cull`, `test_vfx_budget`, `test_vfx_interpolation`, `test_vfx_layer`, `test_vfx_pressure`, `test_vx_looks`, `test_wand_cast_view`, `test_view_build_queue`, `test_altar_stage`, `test_shard_altar`) and the e2e `loading_cover`, `old_save`, `saves`, `lance_scatter`, `rune_combos`, `wand_build`, `breakables_solid` | `Scripts 22 / Tests 178 / Passing Tests 178 / Asserts 26063 / Time 397.239s` (2 GUT "Float/Int comparison" warnings, unrelated) |
| After the per-id warm-up change: `test_pack_fx`, `test_pack_explosion`, `test_view_build_queue`, `e2e/test_e2e_loading_cover` | `Scripts 4 / Tests 25 / Passing Tests 25 / Asserts 1333` |
| `gdlint src scripts tests` | `Success: no problems found` |
| `gdformat --check src scripts tests` | `1 file would be reformatted` (`tests/unit/presentation/test_form_card_text.gd`, not touched by this step); every file this step wrote is clean |

Not run (the brief: no full suite): the seed-loop tests, the other e2e. The goldens are in the `tests/golden` run above
(presentation only: none changed). `tests/MIN_TEST_COUNT` is not raised (the lead raises it from the green `verify`).
New tests: `test_pack_fx.gd` 13, `test_pack_explosion.gd` 6, `test_pack_fx_scenes.gd` 4 (every one of the 260 effect
scenes instantiates; the table validates).

## 4. Shots (R18, before and after)

Script `scripts/shots/vx0_explosion.gd` (new; a real `WorldViewRoot`, the Gun's stage, the effects layer, a fixed
frame time). A green ring marks the burst radius `r = 2.5 m`; each sheet is 2x2: left the sprite explosion (before),
right the pack's (after); top 0.3 s after the burst starts, bottom 0.9 s (smoke).

```
G --path . --fixed-fps 60 --audio-driver Dummy --resolution 1280x720 -s scripts/shots/vx0_explosion.gd
vx0_explosion: res://build/shots/v0.10.0/vx0/ruins.png
vx0_explosion: res://build/shots/v0.10.0/vx0/frozen_shore.png
```

- `build/shots/v0.10.0/vx0/ruins.png` (the Ruins stage)
- `build/shots/v0.10.0/vx0/frozen_shore.png` (the Frozen Shore)

(`build/` is not tracked; the images are on the owner's PC at those paths.)

**What I see, not a verdict:** at the scale `r / 1.5` the pack's fireball body is about as wide as the ring (5 m across
for r = 2.5), so the factor stands; its streaks and sparks reach about a metre past the ring. It reads darker and more
brown-orange than the sprite fireball and with much more detail. The smoke is a dark plume that rises up-left of the
burst and outlasts the fireball. A Decal under the pack's explosion adds a cracked-ground mark on top of our scorch.
Whether it fits the game's look is the owner's call (OWNER ONLY).

## 5. Cost

**The 20-enemy fight (`scripts/checks/frame_probe.gd`):** the Playground room, the Gun with Glaive, Ring, Split Shot,
Ember Core and Storm Core (fire + lightning) at level 3, 20 live enemies, 1920x1080 windowed, vsync off, 3 s warm-up and
30 s measured, Frozen Shore. Two flags were added to the probe for this step: `wildfire` (also grants Wildfire, so a
burning kill spreads fire and bursts: that is what makes fire explosions in this build) and `no_pack_fx` (the sprite
explosion: the "before"). Both runs have Wildfire; they differ only in `no_pack_fx`.

```
G --language en --path . --resolution 1920x1080 --windowed -s scripts/checks/frame_probe.gd -- --biome=frozen_shore --ab=wildfire,no_pack_fx
G --language en --path . --resolution 1920x1080 --windowed -s scripts/checks/frame_probe.gd -- --biome=frozen_shore --ab=wildfire
```

| | before (sprites) | after (pack) |
|---|---|---|
| `frames` | 2675 | 2397 |
| `avg_ms` / `p50` / `p95` / `p99` | 11.215 / 12.112 / 16.881 / 22.882 | 12.516 / 13.385 / 17.803 / 24.941 |
| `1pct_low_fps` / `max_ms` | 31.3 / 130.902 | 34.0 / 40.295 |
| `over_6.94ms` | 1947 (72.79 %) | 1986 (82.85 %) |
| `avg_fps` | 89.2 | 79.9 |
| `render_cpu_ms_avg` / `render_gpu_ms_avg` | 1.359 / 3.365 | 1.511 / 5.196 |
| draw calls per second sampled (first three) | 883, 839, 780 | 982, 888, 823 |
| primitives (first three) | 258343, 270395, 208944 | 772161, 624979, 684678 |
| `pack_fx` | spawned 4 (warm-up only) | spawned 176, reused 82 |

Raw lines are in `build/perf/bbf5e61f_frozen_shore_ab-wildfire-no_pack_fx.txt` and
`build/perf/bbf5e61f_frozen_shore_ab-wildfire.txt`. **Reading:** with the pack the average frame is **+1.3 ms** and the
GPU render time **+1.8 ms** (3.4 to 5.2); the primitives per second roughly triple. The 144 fps target (6.94 ms) is
missed in both runs: this scenario is already at 11 ms before the pack (the PF step's own finding). Spawned 176 minus
the 4 warm-up spawns is 172 pack effects, about 86 explosions each with its smoke; 82 were the cap reusing the oldest
instance (explosion 12, cloud 4). The two runs are one 30 s sample each on a shared machine, not repeated.

## 6. Warm-up and load

`scripts/checks/load_probe.gd` on the GPU (`--menu-only`: a new run, Continue, Restart), the real `main.tscn`:

```
G --path . --fixed-fps 60 --audio-driver Dummy --resolution 1280x720 -s scripts/checks/load_probe.gd -- --menu-only
```

Warm-up time behind the cover, from `CoverLoads.phases` (ms; the compile of each pack effect's pipelines lands in the
frame after its job, so the load's longest frame is the number to watch):

| Load | `pack_fx_warmup_explosion_fire_a` | `_b` | `_c` | `_smoke_after` |
|---|---|---|---|---|
| new_run | 144.7 | 59.3 | 10.3 | 36.7 |
| continue | 128.5 | 60.0 | 10.5 | 28.8 |

| Longest frame while covered | new_run | continue | restart |
|---|---|---|---|
| no pack warm-up (job disabled for this one run) | 310.7 ms | 265.0 ms | 257.4 ms |
| one warm-up job for all four ids (as the brief said) | 1177.0 ms | 1132.2 ms | 1122.2 ms |
| **one job per id (as committed)** | **506.1 ms** | **488.3 ms** | 498.7 ms |

So the warm-up adds about 0.2 s to the longest frame of a load, behind the cover. That is the
price of not paying the same compile as a first-fight hitch; the corner mark still moved on every frame
(`still mark frames 0`). The pipelines of the explosions are the largest part (fire_a: 145 ms of job plus its compile
in the next frame). Spreading further (one effect per frame, with a frame between) would lower the longest frame
again; not done here.

**Hitch probe** (`scripts/checks/hitch_probe.gd`, headless), raw:

```
hitch_probe: ticks after a 250 ms stall = 4 (limit 4, max seen 4), dash starts = 1 -> ok
```

That probe is a sim-time rule (a stall followed by at most 4 ticks); it builds no view and draws nothing, so it cannot see
a first-use shader stall. The first-use stall is covered by the load probe above (the warm-up) and is **NOT YET RUN**
as "first explosion of a fight with no warm-up" (not measured here; the cost page reported 50-420 ms for most pack
effects and 1.6-1.7 s for ice and smoke).

## 7. Not done, and open

- No Windows export / `export_smoke.sh` run: the pack adds 11 MB and the export filter keeps `addons/magic_circles`
  (it excludes `*.md` and `*.uid` as before). **NOT YET RUN.**
- The explosion's Decal (cracks) under the pack explosion is left as the scene has it; no scorch change.
- The lossless textures (section 1.3) are used by effects VX1-VX8 will bring in; if video memory matters then, they
  can be VRAM-compressed again by an import done on a GPU machine.
- Pack scenes keep one `AnimationPlayer` `main` clip; effects with other clip names (a `oneshot`) are not handled by
  PackFx yet.

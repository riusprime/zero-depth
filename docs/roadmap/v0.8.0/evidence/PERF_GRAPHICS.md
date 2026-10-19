# v0.8.0 perf and graphics (O86) — evidence

Branch `claude/perf-graphics-v080` (owner O86, 2026-10-19). Steps FS, FV (performance) and GX (graphics). No fps or
timing is measured in the cloud (CLAUDE.md "No timing on a busy machine"): every frame target is
`NOT YET RUN (owner hardware)`.

## GX

Owner lines: O86 (the graphics feedback `feedback/2026-10-19_graphics_upgrade.md` §1, §3, §4, §5); O88 (2026-10-19):
"the image of reference for lighting is this one, improving graphics should be from there, the fog, better lighting or
particles and improvements, never going out of that" — the reference is
[`mi_shots/ruins_room.jpg`](mi_shots/ruins_room.jpg).

Build: branch `v080-gx` from `d2ae864`. Code at the WIP commit `3e57166a`, plus this commit's data changes (height haze
`fog_height` 0.4 → 0.0 in Ruins, Night Rocks and Red Canyon; Night Rocks `volumetric_light_energy` 1.5 → 1.0), which
were made before the final shots and the tests below. Machine: cloud container, 4 CPUs, lavapipe (llvmpipe) Vulkan.

### What was built (all on the "high" lighting tier; "low" is unchanged)

- **Volumetric fog (§1).** `StageAtmosphere` (`src/presentation/world_view/stage_atmosphere.gd`) holds a FogVolume box
  that follows the view's focus, from 1 m under the floor up to the mood's `volumetric_height`. The Environment's own
  volumetric density is 0: an even density over the 48-72 m between the iso camera and the floor would black out the
  frame. The void never takes the fog (`volumetric_fog_sky_affect` 0). The fire props light it
  (`volumetric_light_energy`), the sun or moon barely (`volumetric_sun_energy`, 0 except Frozen Shore's 0.05).
  **Volumetric fog does render under the orthographic camera** (the shots below), so §6 (fake cones) was not needed.
- **Height haze (§4).** `fog_height` / `fog_height_density` mood fields. Godot has one fog colour, so the haze tints
  toward `fog_color`; it can't darken. To keep O88's look it is set only under the floor's level (`fog_height` 0): it
  touches Frozen Shore's sea (0.35) and nothing on the first three biomes' floors; Starfall 0 (its stars stay clear,
  ART_DIRECTION "no fog").
- **Embers and dust (§3).** One GPUParticles3D per kit light prop (28 warm additive soft dots, parented to the light,
  so it hides and stops emitting when StageKit fades the light out of the view's reach), one cool dust emitter
  (90 motes) over the view. Reduced motion freezes them.
- **Crystal glint (§5).** On this branch crystal roughness was already 0.12-0.24; metallic 0.2
  (`ShardMesh.CRYSTAL_METALLIC`) added to the room shards (ShardMesh, ShardCluster), CodeProps star crystal and ice,
  Starfall's drifting void crystals and the curse room's glow crystals; the owner's `star_crystal` and `ice_shard`
  .glb materials are glossed at load (`KitModels.GLOSS`, the files untouched). Stone stays matte.
- Mood values per biome in `data/biomes/*.tres`; ranges in `BiomeMood.problems()`; CONTENT_SCHEMA updated.

### Shots (one per biome, the reference's tool and room)

Command (per biome; `S` the agent's scratchpad):

```
XDG_DATA_HOME=$S/xdg VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
  godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/room_layouts.gd -- \
  biome=<id> only=room_2x2_1 out=gx
```

Every log line read `renderer=forward_plus device=llvmpipe (LLVM 20.1.2, 256 bits) window=(1600, 900)`, target
`[&"room_2x2_1", 20261031, 2]`, `missing=[]`. Side by side (before = `mi_shots/<biome>_room.jpg`, after = this build):
[`gx_shots/`](gx_shots/). The befores are earlier builds' shots of the same room, so props differ a little and the
numbers compare the frames' overall brightness, not GX alone. Luma per frame (each scaled to 720 px high; mean, standard
deviation, share of pixels under 20 of 255), from the agent's side-by-side script:

| Biome | Before | After |
|---|---|---|
| Ruins | mean=38.4 stddev=21.8 share<20=0.232 | mean=37.8 stddev=21.7 share<20=0.211 |
| Night Rocks (first shot, light energy 1.5) | mean=16.9 stddev=16.2 share<20=0.673 | mean=18.1 stddev=18.2 share<20=0.678 |
| Night Rocks (light energy 1.0, kept) | mean=16.9 stddev=16.2 share<20=0.673 | mean=16.8 stddev=17.0 share<20=0.716 |
| Red Canyon | mean=26.1 stddev=18.9 share<20=0.362 | mean=26.4 stddev=20.1 share<20=0.371 |
| Frozen Shore | mean=98.8 stddev=36.8 share<20=0.002 | mean=95.1 stddev=36.4 share<20=0.007 |
| Starfall | mean=50.1 stddev=30.0 share<20=0.218 | mean=49.2 stddev=29.7 share<20=0.215 |

Night Rocks' first shot read brighter (the torch fog spread a warm wash), so its torch fog energy was lowered and that
biome alone re-shot. The look against the reference: OWNER ONLY.

### Tests

```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gexit -ginclude_subdirs -gtest=res://tests/unit/presentation/test_stage_atmosphere.gd,res://tests/unit/presentation/test_stage_mood.gd,res://tests/unit/presentation/test_stage_kit_lights.gd,res://tests/unit/presentation/test_kit_models.gd,res://tests/unit/presentation/test_deep_look.gd,res://tests/unit/presentation/test_frozen_shore.gd,res://tests/unit/presentation/test_starfall.gd,res://tests/unit/presentation/test_curse_room_view.gd
Scripts               8
Tests                49
Passing Tests        49
Asserts           225066
Time              157.094s
---- All tests passed! ----

godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gexit -ginclude_subdirs -gdir=res://tests/content
Scripts              26
Tests               134
Passing Tests       134
Asserts            9679
Time              29.732s
---- All tests passed! ----

godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gexit -ginclude_subdirs -gdir=res://tests/arch
Scripts               2
Tests                 4
Passing Tests         4
Asserts           12233
Time              1.371s
---- All tests passed! ----

godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gexit -ginclude_subdirs -gtest=res://tests/e2e/test_e2e_lighting.gd
Scripts               1
Tests                 1
Passing Tests         1
Asserts              15
Time              15.123s
---- All tests passed! ----
```

Lint: `gdformat --check src scripts tests` flags only `src/presentation/world_view/boss_door_view.gd`, already so at
`d2ae864` (not touched here); `gdlint src scripts tests`: `Success: no problems found`.

### Cost

fps High vs Low with the new atmosphere: `NOT YET RUN (owner hardware)`. The owner compares Options > Display >
Lighting quality High and Low on the same room.

# BIOME_PERF_AND_LIGHT: biomes against Star, lights that fade, less glow, cheaper view code, loop 2 + Purple Portal (v0.8.0 P3)

Owner lines (verbatim in [`../PLAN.md`](../PLAN.md)): O29 "The Star biome runs smoothly, but the Red, Blue, and
Original biomes experience lag … possibly related to lighting. Compare the affected biomes against the Star biome";
O30 "Lighting sometimes changes abruptly as the player moves through rooms, appearing to switch on and off"; O31
"Glow intensity is still excessive across all biomes, particularly on barrels, torches, and the main character. Keep
the atmospheric illumination but reduce the glow so it doesn't obstruct visibility"; O32 "Look for ways to make the
game more efficient, not changing graphic or animations itself but making less calculations improving the code";
O35 "… Reduce the difficulty of this specific combination (second loop + Purple Portal) by approximately 10%".

- **Status:** RUN (agent). The owner's fps on their PC, and how the lights and glow look in play: **OWNER ONLY**.
- **Build:** before = the base commit `6da58e4` (branch `claude/lucid-fermat-9wv2tf`) for every file the step
  changes; after = the working tree of the commit `v0.8.0 Step P3` on `v080-p3` (the runs were made on that tree
  before it was committed, so the commit cannot name its own SHA). The A/B runs swapped only the changed
  presentation files and biome data between the two (`git show 6da58e4:<file>`), back to back in the same session.
  Godot `4.7.2.stable.official.ed1daf0bf`; OS Linux 6.18.44 (cloud container, 4 cores, no GPU: Vulkan through
  **llvmpipe**, a software rasteriser). Other agents' runs shared the 4 cores (load average 4-11 during the runs),
  so wall-clock numbers drift between runs; each before/after pair ran back to back, and `cpu_ms` (the process's own
  CPU time) is the steadier number where it exists.
- **Date:** 2026-10-16
- **Who ran it:** agent

## Which biomes the owner meant
"Star" is **Starfall**. "Red", "Blue" and "Original" are the three first biomes, the ones with the hand-written look
(`BiomeDefinition.look` null): **Red Canyon** (red ground), **Night Rocks** (blue ground, `ground` `(0.28, 0.40,
0.59)`) and **Ruins** (the original first biome). Frozen Shore and Starfall are the two v0.7.5 biomes with a
`BiomeLook`. Frozen Shore's ground is near white, so it isn't "Blue"; it was measured too and behaves like Starfall.

## The probe
`scripts/checks/biome_probe.gd` (new): one real generated floor (`SaveLab.floor_world(20261008, 1)`, the same run
seed and floor index every time) drawn by the game's own `WorldViewRoot` in one biome (its mood, look, kit, shards,
surface and edge), the camera stopped at the start room and the next rooms (the game's view size 17), vsync off, no
fps cap; per measured frame: wall time, the process's CPU time (`/proc/self/stat`), RenderingServer's render CPU/GPU
time, draw calls, objects, primitives, and omni lights (all, shadow-casting, visible). Options: `light_spot=1` (a
spot on the fire prop nearest the hero, for the shots), `shot=1` (saves frames), `off=…` (diagnosis toggles),
`cpu=1` (times the views' tick work, headless too). It writes only under `build/perf/`; the numbers below were pasted
by hand from its printout.

## O29: what makes the first three biomes slower
Same floor, same spots, before the fix (`6da58e4`), back-to-back A/B (`ab.sh` below), 3 spots × 6 frames, 640×360:

| biome | frame_ms avg | cpu_ms avg | omni lights visible |
|---|---|---|---|
| Starfall | 6155.6 | — (not measured: the CPU reading was broken in this run) | 80 |
| Ruins | 20285.4 | — (same) | 80 |
| Night Rocks | 16225.5 | 16069.4 | 80 |
| Red Canyon | 11785.8 | 15511.1 | 80 |
| Frozen Shore | 2386.8 | 4153.3 | 80 |

(Seconds a frame: llvmpipe draws every pixel on the CPU. On a GPU the absolute numbers are nothing like these; the
ratios between biomes are the finding.) The first three are 3-4× Starfall and Frozen Shore. The lights are the
same on every biome (the same floor: 104 omni lights, 62 of them fire props, 4 casting shadows). Fog is not it:
at the start room alone (`spots=1 frames=4 settle=4`), Ruins with its fog turned off (`off=fog`) took 11600.6 ms a
frame, and Frozen Shore with its fog on (the thickest, 0.006) 3345.4 ms (base commit, `xvfb-run -a godot --path .
--audio-driver Dummy --resolution 640x360 -s scripts/checks/biome_probe.gd -- biome=<b> tag=<t> spots=1 frames=4
settle=4 [off=fog]`; the lines that matter):
```
off: fog
biome_probe: biome=ruins seed=20261008 floor=1 spots=1 frames=4 lighting=high renderer=forward_plus device=llvmpipe (LLVM 20.1.2, 256 bits)
env: fog=false fog_density=0.0050 glow=true glow_intensity=0.70 glow_bloom=0.00 ssao=true ssil=true
frame_ms       11600.596  12003.053  12003.053
render_gpu     11689.121  12443.773  12443.773
biome_probe: biome=frozen_shore seed=20261008 floor=1 spots=1 frames=4 lighting=high renderer=forward_plus device=llvmpipe (LLVM 20.1.2, 256 bits)
env: fog=true fog_density=0.0060 glow=true glow_intensity=1.20 glow_bloom=0.04 ssao=true ssil=true
frame_ms       3345.395  3939.169  3939.169
render_gpu     3127.011  3315.715  3315.715
```
The difference is the **scattered decoration**:

```
godot --headless --path . -s res://build/decor_count.gd
```
(an untracked one-off: it builds the same floor's view per biome and multiplies each MultiMesh's instance count by its
mesh's triangles; its source is below)
```
starfall: multimesh tris=542415 (instances 23940) meshinstance tris=26057194 decor={ &"Decor_star_crystal": "1280 x 54", &"Decor_meteorite": "603 x 40" }
ruins: multimesh tris=20737357 (instances 17398) meshinstance tris=26047458 decor={ &"Decor_grass_tuft": "1271 x 10419", &"Decor_rubble_small": "392 x 12835", &"Decor_debris_low": "211 x 9816" }
night_rocks: multimesh tris=20346192 (instances 17376) meshinstance tris=26335708 decor={ &"Decor_grass_tuft": "1238 x 10419", &"Decor_rubble_small": "386 x 12835", &"Decor_debris_low": "214 x 9816" }
red_canyon: multimesh tris=20737357 (instances 17398) meshinstance tris=26047538 decor={ &"Decor_grass_tuft": "1271 x 10419", &"Decor_rubble_small": "392 x 12835", &"Decor_debris_low": "211 x 9816" }
frozen_shore: multimesh tris=456878 (instances 18477) meshinstance tris=26292460 decor={ &"Decor_snow_drift": "1494 x 21", &"Decor_ice_shard": "389 x 36" }
```
The first three biomes scatter the owner's kit grass, rubble and debris (9.8-12.8k triangles each, ~1,900 pieces a
floor: **~20.7 million triangles**); Starfall and Frozen Shore swap them for code-made pieces of 21-54 triangles
(~0.5 million). Each kind was one MultiMesh over the whole floor, so its bounds were always on screen and inside
every shadow pass (the sun's and the 4 shadowed fire lights'): all of it was drawn every frame, several times. The
walls and cover (MeshInstances, ~26 million triangles a floor) are the same in every biome and are culled per piece.

`build/decor_count.gd`:
```gdscript
extends SceneTree


func _initialize() -> void:
	var repo := ContentRepository.load_all()
	for bid in [&"starfall", &"ruins", &"night_rocks", &"red_canyon", &"frozen_shore"]:
		var biome: BiomeDefinition = repo.get_def(&"biomes", bid)
		var w := SaveLab.floor_world(20261008, 1)
		IcePatches.place(w, BiomeCompiler.compile_surface(biome))
		var reader := WorldReader.new(w)
		var view := WorldViewRoot.new()
		view.stage.mood = biome.mood
		view.stage.prop_style = biome.id
		view.stage.look = biome.look
		root.add_child(view)
		view.setup(reader, biome.palette, 60.0)
		var mm_tris := 0
		var mm_inst := 0
		var mi_tris := 0
		var per := {}
		for n in view.find_children("*", "MultiMeshInstance3D", true, false):
			var mm := (n as MultiMeshInstance3D).multimesh
			if mm == null or mm.mesh == null:
				continue
			var t := _tris(mm.mesh) * mm.instance_count
			mm_tris += t
			mm_inst += mm.instance_count
			if String(n.name).begins_with("Decor"):
				per[n.name] = "%d x %d" % [mm.instance_count, _tris(mm.mesh)]
		for n in view.find_children("*", "MeshInstance3D", true, false):
			var m := (n as MeshInstance3D).mesh
			if m != null and (n as MeshInstance3D).visible:
				mi_tris += _tris(m)
		print("%s: multimesh tris=%d (instances %d) meshinstance tris=%d decor=%s" % [bid, mm_tris, mm_inst, mi_tris, per])
		view.free()
	quit(0)


static func _tris(m: Mesh) -> int:
	var tris := 0
	for s in m.get_surface_count():
		var a := m.surface_get_arrays(s)
		var idx = a[Mesh.ARRAY_INDEX]
		if idx != null and idx.size() > 0:
			tris += idx.size() / 3
		else:
			tris += (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return tris
```

### The fix (look kept)
- `StageKit`: decoration is one MultiMesh per piece kind **per 16 m square** of the floor (still under one
  `Decor_<piece>` node), so a chunk off screen or out of a light's reach is culled.
- `KitModels.decor_mesh`: a scattered piece over 1,000 triangles is drawn from its **coarsest generated level of
  detail** (the same vertices, UVs and material; the engine's generator keeps UV seams, so the kit's pieces stop at
  grass 4,689 / rubble 3,207 / debris 3,376 triangles, from 10,419 / 12,835 / 9,816). The pieces are 0.2-0.4 m, a
  few dozen pixels on screen; the shots below show the same floor.
- Not changed: fog, the lights' count, SSAO / SSIL, the walls.

### After: the same A/B
```
bash ab.sh 6 3 ruins starfall night_rocks red_canyon frozen_shore
```
(`ab.sh`, in the session's scratchpad: for each biome, copies the `6da58e4` versions of the changed presentation
files and biome data in, runs the probe, copies this branch's back, runs it again:
`xvfb-run -a godot --path . --audio-driver Dummy --resolution 640x360 -s scripts/checks/biome_probe.gd -- biome=<b>
frames=6 settle=6 spots=3 tag=ab_<side>`.) Raw output, every line the probe printed for the metrics:

```
== ruins before
biome_probe: biome=ruins seed=20261008 floor=1 spots=3 frames=6 lighting=high renderer=forward_plus device=llvmpipe (LLVM 20.1.2, 256 bits)
env: fog=true fog_density=0.0050 glow=true glow_intensity=0.70 glow_bloom=0.00 ssao=true ssil=true
scene: nodes=5887 omni_lights=104 (kit fire lights 62) spot_lights=0 particles=2
metric          avg       p95       max
frame_ms       20285.386  25152.815  25152.815
cpu_ms           -1.000    -1.000    -1.000
render_cpu        2.390     3.282     3.282
render_gpu     20529.932  25370.686  25370.686
draws           584.000   617.000   617.000
objects         952.333  1090.000  1090.000
prims          2626817.000  3303036.000  3303036.000
omni_all        106.000   106.000   106.000
omni_shadow       4.000     4.000     4.000
omni_visible     80.000    80.000    80.000
== ruins after
biome_probe: biome=ruins seed=20261008 floor=1 spots=3 frames=6 lighting=high renderer=forward_plus device=llvmpipe (LLVM 20.1.2, 256 bits)
env: fog=true fog_density=0.0050 glow=true glow_intensity=0.45 glow_bloom=0.00 ssao=true ssil=true
scene: nodes=6088 omni_lights=104 (kit fire lights 62) spot_lights=0 particles=2
metric          avg       p95       max
frame_ms       7533.297  11718.841  11718.841
cpu_ms           -1.000    -1.000    -1.000
render_cpu        2.446     4.239     4.239
render_gpu     7274.281  11693.831  11693.831
draws           548.889   820.000   820.000
objects         915.944  1331.000  1331.000
prims          7052851.889  11676288.000  11676288.000
omni_all        106.000   106.000   106.000
omni_shadow       3.556     4.000     4.000
omni_visible     29.000    35.000    35.000
== starfall before
biome_probe: biome=starfall seed=20261008 floor=1 spots=3 frames=6 lighting=high renderer=forward_plus device=llvmpipe (LLVM 20.1.2, 256 bits)
env: fog=false fog_density=0.0000 glow=true glow_intensity=1.30 glow_bloom=0.05 ssao=true ssil=true
scene: nodes=5920 omni_lights=104 (kit fire lights 62) spot_lights=0 particles=2
metric          avg       p95       max
frame_ms       6155.623  8580.641  8580.641
cpu_ms           -1.000    -1.000    -1.000
render_cpu        3.903     7.949     7.949
render_gpu     6078.201  8318.668  8318.668
draws           700.000   790.000   790.000
objects        1093.333  1300.000  1300.000
prims          4525315.000  5350084.000  5350084.000
omni_all        106.000   106.000   106.000
omni_shadow       4.000     4.000     4.000
omni_visible     80.000    80.000    80.000
== starfall after
biome_probe: biome=starfall seed=20261008 floor=1 spots=3 frames=6 lighting=high renderer=forward_plus device=llvmpipe (LLVM 20.1.2, 256 bits)
env: fog=false fog_density=0.0000 glow=true glow_intensity=0.75 glow_bloom=0.00 ssao=true ssil=true
scene: nodes=6063 omni_lights=104 (kit fire lights 62) spot_lights=0 particles=2
metric          avg       p95       max
frame_ms       5402.235  7539.042  7539.042
cpu_ms         3948.333  5380.000  5380.000
render_cpu        3.529    19.337    19.337
render_gpu     5338.577  7448.268  7448.268
draws           607.111   885.000   885.000
objects         973.222  1395.000  1395.000
prims          2310741.389  3429444.000  3429444.000
omni_all        106.000   106.000   106.000
omni_shadow       3.556     4.000     4.000
omni_visible     31.778    39.000    39.000
== night_rocks before
biome_probe: biome=night_rocks seed=20261008 floor=1 spots=3 frames=6 lighting=high renderer=forward_plus device=llvmpipe (LLVM 20.1.2, 256 bits)
env: fog=true fog_density=0.0030 glow=true glow_intensity=0.70 glow_bloom=0.00 ssao=true ssil=true
scene: nodes=5886 omni_lights=104 (kit fire lights 62) spot_lights=0 particles=2
metric          avg       p95       max
frame_ms       16225.544  20040.672  20040.672
cpu_ms         16069.444  20490.000  20490.000
render_cpu        2.579     5.257     5.257
render_gpu     16290.968  19467.061  19467.061
draws           625.667   740.000   740.000
objects         995.333  1217.000  1217.000
prims          2586267.000  3469895.000  3469895.000
omni_all        106.000   106.000   106.000
omni_shadow       4.000     4.000     4.000
omni_visible     80.000    80.000    80.000
== night_rocks after
biome_probe: biome=night_rocks seed=20261008 floor=1 spots=3 frames=6 lighting=high renderer=forward_plus device=llvmpipe (LLVM 20.1.2, 256 bits)
env: fog=true fog_density=0.0030 glow=true glow_intensity=0.45 glow_bloom=0.00 ssao=true ssil=true
scene: nodes=6088 omni_lights=104 (kit fire lights 62) spot_lights=0 particles=2
metric          avg       p95       max
frame_ms       3016.761  4404.112  4404.112
cpu_ms         5240.556  7350.000  7350.000
render_cpu        2.238     5.804     5.804
render_gpu     2940.300  4372.713  4372.713
draws           560.667   821.000   821.000
objects         928.222  1329.000  1329.000
prims          7130390.722  12736961.000  12736961.000
omni_all        106.000   106.000   106.000
omni_shadow       3.556     4.000     4.000
omni_visible     28.722    35.000    35.000
== red_canyon before
biome_probe: biome=red_canyon seed=20261008 floor=1 spots=3 frames=6 lighting=high renderer=forward_plus device=llvmpipe (LLVM 20.1.2, 256 bits)
env: fog=true fog_density=0.0025 glow=true glow_intensity=0.70 glow_bloom=0.00 ssao=true ssil=true
scene: nodes=5890 omni_lights=104 (kit fire lights 62) spot_lights=0 particles=2
metric          avg       p95       max
frame_ms       11785.780  13843.045  13843.045
cpu_ms         15511.111  17950.000  17950.000
render_cpu        2.381     3.485     3.485
render_gpu     11891.447  16055.439  16055.439
draws           614.667   654.000   654.000
objects        1103.667  1322.000  1322.000
prims          3099416.000  4053534.000  4053534.000
omni_all        106.000   106.000   106.000
omni_shadow       4.000     4.000     4.000
omni_visible     80.000    80.000    80.000
== red_canyon after
biome_probe: biome=red_canyon seed=20261008 floor=1 spots=3 frames=6 lighting=high renderer=forward_plus device=llvmpipe (LLVM 20.1.2, 256 bits)
env: fog=true fog_density=0.0025 glow=true glow_intensity=0.45 glow_bloom=0.00 ssao=true ssil=true
scene: nodes=6091 omni_lights=104 (kit fire lights 62) spot_lights=0 particles=2
metric          avg       p95       max
frame_ms       3076.599  4478.630  4478.630
cpu_ms         5348.333  7460.000  7460.000
render_cpu        2.097     3.406     3.406
render_gpu     2990.726  4453.075  4453.075
draws           591.222   881.000   881.000
objects         1078.944  1567.000  1567.000
prims          7788111.222  12804577.000  12804577.000
omni_all        106.000   106.000   106.000
omni_shadow       3.556     4.000     4.000
omni_visible     29.000    35.000    35.000
== frozen_shore before
biome_probe: biome=frozen_shore seed=20261008 floor=1 spots=3 frames=6 lighting=high renderer=forward_plus device=llvmpipe (LLVM 20.1.2, 256 bits)
env: fog=true fog_density=0.0060 glow=true glow_intensity=1.20 glow_bloom=0.04 ssao=true ssil=true
scene: nodes=5896 omni_lights=104 (kit fire lights 62) spot_lights=0 particles=2
metric          avg       p95       max
frame_ms       2386.786  3303.257  3303.257
cpu_ms         4153.333  5770.000  5770.000
render_cpu        2.638     3.836     3.836
render_gpu     2356.022  3281.648  3281.648
draws           708.667   794.000   794.000
objects        1113.333  1307.000  1307.000
prims          3621523.000  4403167.000  4403167.000
omni_all        106.000   106.000   106.000
omni_shadow       4.000     4.000     4.000
omni_visible     80.000    80.000    80.000
== frozen_shore after
biome_probe: biome=frozen_shore seed=20261008 floor=1 spots=3 frames=6 lighting=high renderer=forward_plus device=llvmpipe (LLVM 20.1.2, 256 bits)
env: fog=true fog_density=0.0060 glow=true glow_intensity=0.70 glow_bloom=0.00 ssao=true ssil=true
scene: nodes=6038 omni_lights=104 (kit fire lights 62) spot_lights=0 particles=2
metric          avg       p95       max
frame_ms       2090.647  3134.175  3134.175
cpu_ms         3876.111  5350.000  5350.000
render_cpu        2.911     6.641     6.641
render_gpu     2067.561  3102.474  3102.474
draws           619.000   880.000   880.000
objects         997.000  1393.000  1393.000
prims          2362507.611  3469895.000  3469895.000
omni_all        106.000   106.000   106.000
omni_shadow       3.556     4.000     4.000
omni_visible     31.444    39.000    39.000
```
(`cpu_ms` reads -1 for the first two biomes: the probe read `/proc/self/stat` with `get_as_text`, which returns
nothing for a file that reports no length; fixed to `get_line` while the run went on, so the later biomes have it.)

| biome | frame_ms before → after | cpu_ms before → after |
|---|---|---|
| Ruins ("Original") | 20285 → 7533 (−63 %) | — |
| Night Rocks ("Blue") | 16226 → 3017 (−81 %) | 16069 → 5241 (−67 %) |
| Red Canyon ("Red") | 11786 → 3077 (−74 %) | 15511 → 5348 (−66 %) |
| Starfall ("Star") | 6156 → 5402 (−12 %) | — → 3948 |
| Frozen Shore | 2387 → 2091 (−12 %) | 4153 → 3876 (−7 %) |

**Against Star, reported:** the first three now take about 5.2-5.3 s of CPU a frame on this software renderer against
Starfall's and Frozen Shore's 3.9 s (**~1.35×**, from ~4×): the gap is mostly closed, not gone. What is left is the
kit decoration's coarsest level (3.2-4.7k triangles a piece against Starfall's 40-54); going lower needs simpler
meshes for those three pieces (an art change: a low-poly grass tuft, rubble and debris, or code-made ones like
Starfall's), which this step doesn't make. `prims` reads *higher* after: the engine counts a chunk's instances, and
before it apparently did not count the floor-wide MultiMeshes the same way; the frame and CPU times are what moved.
`omni_visible` drops from 80 to ~30: the far fire lights now fade out (O30 below).

## O30: lights that fade instead of switching
What switched: `StageKit` turned shadows on for the 4 fire lights nearest the camera's focus and off for the rest,
re-picked every 15 frames, so as you walked a light's shadow (and the light it blocked) snapped on or off. Now:
- a light joining or leaving the 4 **fades its shadow** (`shadow_opacity`, smoothstep) over 0.45 s; the joining one
  waits for the leaving one's slot, so never more than 4 cast at once (a swap costs no extra shadow pass);
- a light keeps its shadow until another is nearer the focus by 1.5 m (no back-and-forth on a border);
- a fire light whose reach can't touch the view (farther from the focus than 1.3 × the camera size plus its range)
  **fades out** over 0.4 s and hides, and fades back in on the way in (it lit nothing on screen; hidden ones skip
  the flicker's work and their flames' sprites);
- presentation only, frame time (no sim read or write); `tests/unit/presentation/test_stage_kit_lights.gd`.
Not changed: VfxCore's 10 pooled effect lights (flashes of bursts and fires) still go to the brightest requests each
frame; they are short effect flashes, not the rooms' lighting.

## O31: less glow
| what | before | after |
|---|---|---|
| Starfall glow intensity / threshold / bloom | 1.3 / 0.8 / 0.05 | 0.75 / 1.0 / 0 |
| Frozen Shore | 1.2 / 0.8 / 0.04 | 0.7 / 1.0 / 0 |
| Ruins, Night Rocks, Red Canyon | 0.7 / 1.0 / 0 | 0.45 / 1.0 / 0 |
| fire prop flame (barrels, braziers): HDR colour × / emission | 1.6 / 2.0 | 1.2 / 1.1 |
| fire prop flame sprites (VfxLayer) | (2.2, 1.8, 1.4) | (1.6, 1.32, 1.04) |
| hero visor emission (rest) | 2.4 | 1.4 |

Kept: ambient colour and energy, the sun, fog, the fire lights' colour, energy and range, the hero's carried light,
the grade, the glow's spread. Shots, before and after, same floor and spots, 960×540 (`shots.sh`: `xvfb-run -a godot
--path . --audio-driver Dummy --resolution 960x540 -s scripts/checks/biome_probe.gd -- biome=<b> tag=<side> spots=1
light_spot=1 frames=1 settle=8 shot=1`, the PNGs converted to JPEG by hand into
[`p3_shots/`](p3_shots/)): `<biome>_0_<before|after>.jpg` the start room with the hero, `<biome>_1_<before|after>.jpg`
the fire props nearest the start (barrels by the wall). In Starfall the barrels' blown-out halo is gone and the
flames read as flames; in the first three biomes the change is small in a still frame (their glow was already
0.7). How it looks in play: **OWNER ONLY**.

## O32: less work per tick and per frame
- `Occlusion.build_index` / `select_in`: the floor's walls (549 on this floor) indexed once by 8 m cell; each tick
  tests only the walls near the focus instead of all of them (same result: `test_occlusion_select.gd`
  `test_the_index_selects_the_same_walls`, 40 trials against `select`).
- `StageKit`: hidden (far) lights skip the flicker; the shadow pick computes each distance once (it sorted with a
  distance computed in the comparator).
- `WorldViewRoot._draw_prop_fires`: no flame sprites for hidden fire lights.
- (O29's decoration chunks and levels of detail are the big saving, on the GPU side.)

```
bash views_ab.sh
```
(scratchpad, as `ab.sh`: three rounds of `godot --headless --path . -s scripts/checks/biome_probe.gd -- biome=ruins
frames=120 settle=30 spots=5 cpu=1 tag=cpu_<side>` before then after, then the PF probe once each:
`godot --headless --fixed-fps 60 --path . -s scripts/checks/perf_probe.gd -- --seconds=10 --tag=p3_<side>`)
```
== views round 1 before
sync_ms           2.191     3.128     4.528
kit_ms            0.074     0.243     0.468
sprites         310.000   310.000   310.000
== views round 1 after
sync_ms           1.538     2.282     5.738
kit_ms            0.052     0.115     0.506
sprites          63.558    95.000   310.000
== views round 2 before
sync_ms           1.969     2.872     7.677
kit_ms            0.060     0.220     0.564
sprites         310.000   310.000   310.000
== views round 2 after
sync_ms           1.750     2.541     4.207
kit_ms            0.054     0.114     0.222
sprites          63.400    95.000   310.000
== views round 3 before
sync_ms           2.213     3.128     4.330
kit_ms            0.074     0.224     2.225
sprites         310.000   310.000   310.000
== views round 3 after
sync_ms           1.917     2.778     6.946
kit_ms            0.066     0.127     0.990
sprites          63.433    95.000   310.000
== PF before
sync_ms           4.039     8.734    15.127
total_ms          9.712    20.181    29.142
verdict: avg 9.71 ms per tick+frame against 12.0 ms -> within
== PF after
sync_ms           3.303     6.375     9.113
total_ms          7.944    14.674    23.026
verdict: avg 7.94 ms per tick+frame against 12.0 ms -> within
```
(each `metric avg p95 max`; the omni lines and headers are left out here, they match the A/B above.) On a real floor
the views' tick work (`sync_ms`) is 10-30 % lower and the fire flames' sprites 80 % fewer; StageKit's own frame work
is unchanged on average (0.05-0.07 ms) with a lower p95. **The PF probe (its one Playground room) does not show it
reliably:** an earlier pair, run before the occlusion index existed, gave 8.88 → 8.95 and 8.82 → 9.68 ms (no
change within the container's ±15 %); the pair above gave 9.71 → 7.94 ms. Earlier PF pair, for the record:
```
== PF round 1 before
total_ms          8.883    16.815    25.898
verdict: avg 8.88 ms per tick+frame against 12.0 ms -> within
== PF round 1 after
total_ms          8.952    16.115    26.691
verdict: avg 8.95 ms per tick+frame against 12.0 ms -> within
== PF round 2 before
total_ms          8.817    16.726    26.769
verdict: avg 8.82 ms per tick+frame against 12.0 ms -> within
== PF round 2 after
total_ms          9.682    17.671    54.822
verdict: avg 9.68 ms per tick+frame against 12.0 ms -> within
```
The hitch probe, before and after (`godot --headless --path . -s scripts/checks/hitch_probe.gd`):
```
== hitch before
hitch_probe: ticks after a 250 ms stall = 4 (limit 4, max seen 4), dash starts = 1 -> ok
== hitch after
hitch_probe: ticks after a 250 ms stall = 4 (limit 4, max seen 4), dash starts = 1 -> ok
```
Not touched (another agent's step): `src/sim/ai` chase and steering.

## O35: loop 2 + the Purple Portal about 10 % easier
The Purple Portal is the **Deep gate** (violet, `PortalGate.DEEP_VIOLET`; `Routes.Route.DEEP`). New data field
`RunDefinition.loop_deep_ease_permille` (`data/run/three_floors.tres`: **900**; 1000 = none): on a Deep floor past
loop 1, `RunState.scale_enemies` and `scale_bosses` multiply HP and damage by it, after the floor, Deep and loop
factors (one more integer step). Loop 1's Deep floors and loop 2's normal floors keep their numbers exactly
(`tests/unit/sim/test_loop_deep_ease.gd`). It applies on every loop past the first (loop 3's Deep floors too): the
owner named loop 2; the lead or owner can say otherwise.

```
godot --headless --path . -s scripts/checks/loop_scaling.gd
```
(extended for P3 with the floor-2 rows; writes `build/loop_scaling.txt`.) Before, run with the base commit's
`data/run/three_floors.tres` (no field: 1000):
```
loop_deep_ease_permille 1000
floor 2: loop | route | enemy | e dmg | boss | b dmg
1 | normal | 76 | 17 | 2800 | 16
1 | deep | 95 | 21 | 3500 | 21
2 | normal | 456 | 20 | 16800 | 20
2 | deep | 570 | 25 | 21000 | 25
3 | normal | 2736 | 24 | 100800 | 24
3 | deep | 3420 | 30 | 126000 | 30
```
After:
```
steps (per mille): enemy hp 6000 dmg 1200, boss hp 6000 dmg 1200, cap 100000
floor-1 sample: enemy ENEMY_ARC_CASTER (hp 40, dmg 12), boss BOSS_BROOD_MOTHER (hp 2000, attack 0 dmg 14)
loop | enemy hp pm | enemy dmg pm | boss hp pm | boss dmg pm | enemy | e dmg | boss | b dmg
1 | 1000 | 1000 | 1000 | 1000 | 40 | 12 | 1600 | 11
2 | 6000 | 1200 | 6000 | 1200 | 240 | 14 | 12000 | 16
3 | 36000 | 1440 | 36000 | 1440 | 1440 | 17 | 72000 | 20
4 | 100000 | 1728 | 100000 | 1728 | 4000 | 21 | 200000 | 24
5 | 100000 | 2073 | 100000 | 2073 | 4000 | 25 | 200000 | 29
loop_deep_ease_permille 900
floor 2: loop | route | enemy | e dmg | boss | b dmg
1 | normal | 76 | 17 | 2800 | 16
1 | deep | 95 | 21 | 3500 | 21
2 | normal | 456 | 20 | 16800 | 20
2 | deep | 513 | 23 | 18900 | 22
3 | normal | 2736 | 24 | 100800 | 24
3 | deep | 3078 | 27 | 113400 | 27
```
Loop 2's Deep floor 2: the sample enemy 570 → 513 HP (−10 %), 25 → 23 damage (−8 %, whole points), the boss 21000 →
18900 HP (−10 %), 25 → 22 attack damage (−12 %, whole points); every other row unchanged. Whether it feels about
right: **OWNER ONLY**.

## Tests (this tree, 2026-10-16; the summary lines GUT printed)
```
gdformat --check src scripts tests && gdlint src scripts tests
942 files would be left unchanged
Success: no problems found

godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/sim/test_loop_deep_ease.gd,res://tests/unit/sim/test_ascension.gd,res://tests/unit/sim/test_routes.gd,res://tests/unit/application/test_run_saves.gd -gexit
Tests                41
Passing Tests        41

godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/content,res://tests/golden,res://tests/arch -ginclude_subdirs -gexit
Tests               132
Passing Tests       132

godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/presentation -ginclude_subdirs -gexit
Tests               690
Passing Tests       690

godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/debug -ginclude_subdirs -gexit
Tests                15
Passing Tests        15

godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/e2e/test_e2e_starfall.gd,res://tests/e2e/test_e2e_frozen_shore.gd,res://tests/e2e/test_e2e_designed_rooms.gd,res://tests/e2e/test_e2e_lighting.gd,res://tests/e2e/test_e2e_routes.gd,res://tests/e2e/test_e2e_ascension.gd,res://tests/e2e/test_e2e_damage_soak.gd,res://tests/e2e/test_e2e_dev_live_balance.gd -gexit
Tests                12
Passing Tests        12
```
(The content, golden and arch run and the sim run were made before the occlusion index and the shadow-slot rule
were added; those touch presentation only, covered by the presentation and e2e runs after them.) No full suite
locally (owner rule); no bot tests.

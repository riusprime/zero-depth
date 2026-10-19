# Zero Depth — graphics upgrade proposal

Written 2026-10-19 from a read-only clone of `riusprime/zero-depth` (main @ a20850f).
Nothing was pushed; the repo is untouched. This doc lives in the goal workspace, not the repo.

## Where the game already stands

Honestly assessed from `stage_view.gd`, `biome_mood.gd`, `stage_kit.gd` and
`data/biomes/ruins.tres`: the lighting system is already strong. The BiomeMood
resource (sun, ambient, AGX tonemap, SSAO + contact shadows + SSIL, fog, glow
with spread control, teal-orange split grade, contrast/saturation, vignette,
warm prop lights, hero light) is good architecture — per-biome, presentation-only,
validated ranges. The Ruins mood is already tuned hard toward the reference:
deep-blue ambient at 0.15, near-black void, glow threshold 0.8 with 0.7 spread,
grade strength 0.7, vignette 0.55. Flames already run emission energy 3.0, so
the HDR bloom insight from the lighting recipe is in. Shadow-casting is capped
at the 4 omnis nearest the camera focus and torches flicker. Don't touch any
of this.

The remaining gap vs the reference is not lighting balance anymore — it's
**atmosphere and material richness**. Ranked below by impact per effort.

## 1. Volumetric fog for torch light shafts (biggest remaining lever)

The reference has light *pooling in the air* around flames, not just on the
floor. Nothing in the current pipeline does this — fog is exponential
distance haze only, and no volumetric pass exists.

- `Environment.volumetric_fog_enabled = true`, density low (~0.02–0.05 to
  start), warm albedo tint so torch light visibly hangs in the air.
- Gate it behind the existing "high" lighting quality setting (the one that
  already toggles SSAO/SSIL) — add e.g. `volumetric_enabled` to BiomeMood,
  default off, so low-end GPUs never pay for it.
- Cost is real but bounded: a handful of omnis in a small arena is the kind
  scene volumetric fog likes. Test on the target min-spec GPU before shipping.

## 2. Directional shadow 8192 → 2048 (free performance)

`project.godot` sets `directional_shadow/size = 8192` with soft-shadow filter
quality 4. The sun is a 0.45-energy cool fill light — an 8K shadow map for it
is pure waste. Drop to 2048 (or 1024): visually identical at this energy,
meaningfully less VRAM and bandwidth. One-line change, zero risk.

## 3. Ember and dust particles in torch light (cheap atmosphere)

Only `portal_transit_view.gd` uses particles today; rooms have none. The
reference feels alive because the air has texture.

- One `GPUParticles3D` per light prop (or a shared system repositioned):
  ~20–40 slow drifting motes, small warm-tinted billboards, additive blend,
  lifetime a few seconds, emission box matched to the torch's light range.
- They'll catch the warm omni light and the glow pass, selling the air
  without any new lighting cost. A second, cooler, sparser emitter for
  ambient dust in shadowed areas adds depth contrast.
- Same gating as volumetric: high quality setting only.

## 4. Height fog for layered depth (cheap)

Current fog is pure exponential distance haze (density 0.003 in Ruins).
Godot 4's Environment fog also has height falloff — sinking the floor edges
and the void below a height curve darkens the frame bottom the way the
reference does and layers the depth. Two properties on the existing fog,
no new systems.

## 5. Material roughness variation (art pass, no code)

Everything ground/kit-side is `roughness = 1.0`, fully matte. Matte is
correct for the low-poly look, but *uniform* matte flattens the specular
story — the reference's crystals glint.

- Crystals: roughness ~0.2–0.3, slight metallic (0.1–0.3). Under a 7.0-energy
  warm torch they'll throw the sharp highlights the current look lacks.
- Optional: a "wet stone" variant at ~0.4 for patches near water/dark areas.
- Keep the blocks matte — the contrast between matte stone and glinting
  crystal is the whole trick.

## 6. Fake light shafts (fallback if volumetric is too heavy)

If volumetric fog doesn't fit the perf budget: additive-blended cone meshes
hanging under/around torch flames, warm gradient alpha, no depth write.
Classic cheap trick, looks convincing in isometric view where the camera
never orbits inside the cone. Decide after profiling #1.

## When 4.8 goes stable (already discussed 2026-10-19, not for now)

- Multi-bounce ambient occlusion: occluded corners pick up subtle warm bleed
  from nearby torches instead of going dead blue-black. Directly serves the
  art direction.
- Screen-space contact shadows: cheap real-time grounding for blocks and
  props, no lightmap rebake.
- Stay on 4.7.x until then; the 4.8 beta's breaking changes (no inheriting
  inner classes in GDScript, debugger failing in release exports) are not
  worth it mid-project. Verified: the wand-resolver files use plain
  `extends Resource`/`RefCounted`, so the GDScript break doesn't hit them —
  but the rest of the beta risk stands.

## What not to do

- Don't chase PBR texture realism — it fights the flat low-poly identity.
- Don't add reflection probes — matte surfaces gain nothing from them.
- Don't restructure the BiomeMood system — it's the right architecture;
  new levers (volumetric, height fog density) should become mood fields.
- Don't raise MSAA above 2x or touch the sun shadow beyond shrinking it —
  the perf budget is better spent on atmosphere.

## Suggested order

1. #2 (one line, free perf headroom for everything below)
2. #3 (particles — biggest feel win per hour of work)
3. #5 (material pass — art-only, no code risk)
4. #1 (volumetric — the headline upgrade; profile first)
5. #4 (height fog — two properties once #1 lands)
6. #6 only if #1 fails profiling

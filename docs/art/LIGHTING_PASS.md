# Lighting pass and fire fix (after the v0.6.1 playtest build)

**Owner, 2026-10-12** (with a target image, the dark iso scene with the lit chest and the fire barrel):
"with fire things go crazy the attack leaves fire everywhere and it goes buggy all around, that's too much fire we
are producing, and secondly we need to work a bit more into the lighting of the game". The owner's notes on the
look: "the shadows go deep blue and nearly black, while the warm lights pool hard around torches and the chest …
Darken the ambient, let a couple of warm point lights with shadows do the heavy lifting, turn on glow in the
WorldEnvironment so emissives actually bloom, and push a teal-orange grade over it."

## 1. Fire (a fix, `4f4e644`)

- **The bug ("buggy all around"):** a live fire patch took its seed from its index in the sim's list. When an
  older patch went out, every later patch got a new seed: its flames jumped, a new scorch was laid, the lights
  reshuffled. Patches are now seeded by place (`AttackFormView._sync_mx2_forms`).
- **Too much fire:** Flame Trail lays a 0.9 m patch every 0.8 m of a dash, and each one drew a full set of flames,
  smoke, embers and its own light. Now:
  - flames from different patches keep 0.8 m apart (`VfxLayer.FLAME_SPACING`), so overlapping patches draw about
    one layer;
  - a patch draws fewer, shorter flames;
  - fire lights within 2.5 m merge into one;
  - one smoke per 1.6 m;
  - overlapping floor marks of a kind keep one decal.
- **Tests:** `test_a_fire_patch_keeps_its_seed_when_an_older_one_goes_out` (test_attack_forms_live.gd),
  `test_overlapping_fire_patches_thin_out` (test_vfx_layer.gd: six overlapping patches draw fewer than four
  patches' flames, at most 2 lights, at most 3 scorches).

## 2. Lighting (a proposal, G2 pending)

New BiomeMood fields (CONTENT_SCHEMA §6), off by default:
- `glow_threshold`, `glow_bloom`: what starts to bloom, and how much;
- `grade_shadows`, `grade_highlights`, `grade_strength`: a split-tone colour grade (per-channel 1D curve on the
  environment);
- `contrast`, `saturation`.

Proposed values (all three biomes keep their own sun colour):

| | Before (v0.5.9 pick B) | Proposed |
|---|---|---|
| Moon / sun energy | 0.8–0.9 | 0.45 (Ruins), 0.5 (Night Rocks), 0.65 (Red Canyon) |
| Ambient energy | 0.5–0.6 | 0.22–0.3, cooler |
| Fire props' light | 5.0, range 10 | 7.0, range 9 |
| Hero light | 1.2, range 4.5 | 1.8, range 5 |
| Exposure | 1.0 | 1.1 |
| Glow | 0.7–0.8, threshold 1.0 | 1.0, threshold 0.85, bloom 0.04 |
| Grade | none | teal shadows, orange highlights, strength 0.7 (Red Canyon 0.55); contrast 1.1, saturation 1.06–1.08 |
| Vignette | 0.35–0.45 | 0.45–0.5 |

The 4 fire props nearest the camera already cast shadows on High (StageKit.SHADOW_LIGHTS).

- **Test:** `test_the_grade_tints_shadows_and_highlights` (test_stage_mood.gd).
- **Mockup:** `mock_look.gd -- variants=B` (and `focus=light`), before at `4f4e644` and after.

**Owner, 2026-10-12, on the first proposal:** "the last 10–15%: the reference pushes it further in two places. One,
the light sources themselves bloom — the torch flames and glowing objects halo a bit, yours pool light on the
ground but the sources stay flat. Two, the corners go properly black; yours still holds detail everywhere, which
flattens the depth. A touch more glow in the WorldEnvironment and dropping the ambient a hair would get you there."

Second proposal:
- **Sources bloom:**
  - each fire prop now carries real flames from the effects layer (`VfxLayer.prop_fire`, HDR so they bloom);
  - the prop's core is HDR;
  - a new `glow_spread` (0.7) turns on Godot's wider glow levels, so bright sources halo;
  - glow 1.2, threshold 0.8.
- **Corners black:** ambient 0.15 (Ruins), 0.17 (Night Rocks), 0.2 (Red Canyon); contrast 1.18 (Red Canyon 1.15);
  vignette 0.55 (Red Canyon 0.5).

| Gate | Asked | Answer | Date |
|---|---|---|---|
| G2 Lighting pass (before / after, mock_look.gd) | 2026-10-12 | direction kept; "the last 10–15%": sources bloom, corners black | 2026-10-12 |
| G2 Lighting pass, second proposal | 2026-10-12 | OWNER ONLY | — |

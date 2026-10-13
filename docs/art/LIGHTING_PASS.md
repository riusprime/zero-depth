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
| G2 Lighting pass, second proposal | 2026-10-12 | "the light source on the actual game glows too much, and it is not that close" (§3) | 2026-10-13 |
| G2 Look pass v3, lighting (§3) | 2026-10-13 | OWNER ONLY | — |

## 3. Look pass v3: lighting (2026-10-13)

**Owner, 2026-10-13** (the same target image beside a Ruins screenshot): "the light source on the actual game glows
to much, and it is not that close, we could add more elements maybe, the pool of models is not to big so we could
make those, I could generate textures for you". On the findings list: "Plan is right … just go for the lighting
for now, we'll work the rest after".

Findings, reference vs. Ruins (biggest gap first). Only F1–F3 and F10 are in this pass; the rest wait for the owner.

| # | Gap | Reference | Before | This pass |
|---|---|---|---|---|
| F1 | Palette temperature | one warm family; warm brown shadows, no blue | blue moon, cool ambient, teal shadow grade 0.7 | Ruins: dim warm dusk sun (0.95,0.82,0.72) at 0.3, warm ambient (0.38,0.3,0.27), brown shadow grade 0.35, saturation 0.85, exposure 1.0 |
| F2 | Glow | sources barely halo; light pools on the floor | glow 1.2, threshold 0.8, spread 0.7, bloom 0.04; fire light 7.0 / 9 m | all biomes: glow 0.7, threshold 1.0, spread 0.25, bloom 0; fire light 4.5 / 7.5 m; flame core ×1.6, emission 2.0 |
| F3 | Darks | dark but readable, low contrast | ambient 0.15, SSAO 6.0, contrast 1.18, vignette 0.55 | Ruins: ambient 0.22, SSAO 3.5, contrast 1.06, vignette 0.4 |
| F10 | Haze | warm dust haze | fog 0.003 neutral | Ruins: fog 0.005, warm brown |
| F4 | Texture style | chunky low-res texels, big ground squares | smooth 1024 px dirt | later: owner textures (128 px, nearest filter) |
| F5 | Wall shape | few tall standalone blocks | long low cobble runs | later |
| F6 | Teal crystals | none; only warm accents | teal clusters on 20% of wall bases | later |
| F7 | Camera | closer (view about 13–14 m) | 17 m | later (gameplay reach: owner decides) |
| F8 | Ink outlines | none drawn | ink strength 0.8 | later |
| F9 | Set dressing | car, barrels, facade with ladder, poles, clutter | 17 kit pieces, sparse mid-size clutter | later: owner models |

Night Rocks and Red Canyon keep their own colours; they only take the F2 glow and fire-light change.

- **Mockup:** `mock_look.gd -- variants=B biomes=ruins` (and `focus=light`), before (base `7eb460a`) and after;
  shots in `build/shots/`, not tracked. A first try (sun 0.55, ambient 0.3, saturation 1.0) came out bright orange,
  not dusk; the values above are the second.
- **Tuning live:** the dev panel's lighting page changes every value here while playing.

# v0.5.9 evidence: the look (lighting, contact shadow, kit)

Renders come from lavapipe (Mesa's software Vulkan) under `xvfb-run`, in a cloud container. They show what the game
draws, not how fast it draws it. **Frame times and the look on the owner's GPU: OWNER ONLY.**

## 1. Godot's SSAO under the orthographic iso camera

**Question.** Does Environment SSAO give the contact shadow the owner asked for (L3: "the occlusion ambience")?

**Method.** `scripts/shots/mock_look.gd`, Ruins, the run's first floor, 1920×1080:
1. Variant B at lighting `high` (SSAO and SSIL on) and at `low` (both off), with nothing else different.
2. The two PNGs compared pixel by pixel: the mean of the summed absolute RGB difference, and the share of pixels
   that differ by more than 20.

**State.** The working tree before `9f4866c`. The Ruins mood was `ssao_radius 1.5`, `ssao_intensity 4.0`,
`ssao_light_affect 0.5`. The "maximum" run used `ssao_radius 6.0`, `ssao_intensity 16.0`, `ssao_light_affect 1.0`
in `data/biomes/ruins.tres`, restored afterwards.

**Commands:**
```
xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --audio-driver Dummy --resolution 1920x1080 \
  -s scripts/shots/mock_look.gd -- biomes=ruins lighting=high
xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --audio-driver Dummy --resolution 1920x1080 \
  -s scripts/shots/mock_look.gd -- biomes=ruins lighting=low
python3 (PIL + numpy): d = |B_ruins_high - B_ruins_low| summed over RGB; print d.mean(), (d > 20).mean()
```

**Raw output:**
```
mean diff high vs low 1.91 pixels >20: 0.003
max-ssao diff 8.38 0.144
```

**Reading.** At the mood's values, SSAO changes 0.3% of the pixels. At its maximum it changes 14.4%, but only as
a faint, blurry darkening near the cast shadows; there is no contact line where a wall meets the floor (the
screenshot crops show it).

**Decision.** The contact shadow is drawn from the geometry instead: `ContactShadows`, one mesh with a soft
falloff around every wall and slab footprint, in one draw call. It is drawn on Low too. That is the custom shader
ARCHITECTURE §11 allows once a scene proves the need; this section is that proof. SSAO stays on High at
moderate values (`ssao_radius 3.0`, `ssao_intensity 6.0`) for the soft tone it adds.

## 2. The owner's kit uploads

The script `scripts/assets/kit_prep.py` writes into `assets/`. The models and textures are assets, not evidence,
and the manifest holds their sha256.

| Upload | As uploaded | After `kit_prep.py` |
|---|---|---|
| 16 `.glb` models | 7–14k triangles; textures 4096 px (13) and 2048 px (3); texture mean about 0.3 (sRGB) | Same meshes; textures 1024 px JPEG q90, brightened to a mean of 0.55, because they read black under the night moods |
| `ground-a.png` (1254 px) | Grout-line centres at 313, 626.5 and 940 px; edge seam (sum RGB diff) 37.9 left-right and 20.2 top-bottom, against 3.6 inside the image | Cropped grout centre to grout centre (313–940), so 2×2 tiles that repeat exactly; 1024 px; channel means set to 0.82 so the biome ground colour tints it |
| `ground-b.png` (1254 px) | Edge seam 8.5 left-right and 9.0 top-bottom, against 5.2 / 5.5 inside the image | Offset-and-blend made seamless; 1024 px; neutralised as above |

The table's figures come from an inspection script in the session scratchpad (`glbinfo.py` and a seam check). It
is not in the repository. Re-checking them needs a fresh run of `kit_prep.py`'s inputs through the same reads.

## 3. Test runs (full suite, clean worktree of the commit)

| Commit | Command | Result |
|---|---|---|
| `23f2237` (merged base, before any v0.5.9 code) | `godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` | `Scripts 169, Tests 1076, Passing Tests 1076, Time 1755.531s, ---- All tests passed! ----` |
| `9f4866c` (Step 1) | same | `Scripts 172, Tests 1083, Passing Tests 1083, Time 1771.714s, ---- All tests passed! ----` |
| `fbedd6d` (Steps 3–4) | same | `Scripts 174, Tests 1092, Passing Tests 1092, Time 1707.753s, ---- All tests passed! ----` |
| `9e5f9be` (Step 5, LODs, variant C) | same | `Scripts 175, Tests 1094, Passing Tests 1094, Time 1608.567s, ---- All tests passed! ----` |

## 4. Not covered yet

- **On-screen contrast of hero, enemies and telegraphs against the lit ground** (`look_contrast.gd`, Step 1):
  NOT YET RUN.
- **Frame time with the dressed, lit floor** (`view_bench`, Step 6): NOT YET RUN. Every piece is a full-detail
  owner mesh (7–14k triangles) with no LOD yet. That is the main performance risk.
- **The pixel filter** (variant C) is only a post-processing approximation for the G2 pick. See the header of
  `mock_look.gd`.

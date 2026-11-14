# v0.11.0 VL: the VFX lab and the pack recipe (spec, lead 2026-11-08)

**Owner (2026-11-08):** "I want you to analyze one of the VFX on the pack, for example, the fire pools on the ground, or
… the fireballs, and tell me what would you need to be able to create assets like those on your end", then "I want you
to start the VFX lab and do everything of this, but in a different session … from a very detailed spec that you write
from these findings."

**Why:** PD-13 (owner, 2026-11-07: "You create very simple VFX for new thing we introduce … VFX have to match the style
of the premade assets") says new effects use or modify the packs' effects. To also build NEW effects that match them, we
need (1) the packs' recipe written down, (2) a way to see effects MOVE next to a pack reference, from the game camera,
(3) the owner's eye on the result. This step builds those tools and proves them on a pilot. It changes nothing a player
sees until the owner picks (OWNER_GATES G2).

## 1. What the lead found (the analysis this spec rests on)

The Binbun packs (`assets/BinbunVFX/`, 260 effect scenes; ours in their style under `assets/vfx_zd/`) are built almost
entirely from text resources, not painted textures:

| Count in the packs | What |
|---|---|
| 539 | `MeshInstance3D` (quads, spheres, cylinders, tubes) with custom `.gdshader`s |
| 333 | `GPUParticles3D` (point sparks with `TubeTrailMesh` trails, billboard quads) |
| 162 | `OmniLight3D` (flash lights) |
| 14 | `Decal` (ground marks) |
| 188 of the effect files | Godot `NoiseTexture2D` + `FastNoiseLite` (procedural noise, no image) |
| a few dozen PNGs | only `shared/texture/` (flare, flash, flash_front/long/side, spirals); `spirals.ptex` is a Material Maker source, so even those were generated |

**The fire pool, `fire_effects/effects/Fire/fire_area_01.tscn`:**
- A `QuadMesh` 1.5 m, subdivided 16×16, lying flat (`orientation = 1`), with `src/shader/fire/fire_area_01.gdshader`:
  - a radial mask from the centre (`distance(0.5, scaled UV)`, `mask_scale` 0.5);
  - a **vertex wave**: `VERTEX.y = wave(mask) * 0.1`, a sine of the mask minus time, so the pool ripples outward;
  - the same noise sampled **twice**, scrolled at different speeds and scales (`UV*1.5 - t*(0.1, 0.05)` and
    `UV + t*0.1`), **multiplied** (×1.5): the crawling flame pattern;
  - a **hard toon edge**: `smoothstep(0.05, 0.2, wave * noise)`;
  - colour: `main_color` (1, 0.235, 0) → `edge_color` (1, 0.447, 0) by the noise, then → `glow_color` (1, 1, 0.68) by
    `pow(1 - mask, 4)` (a hot centre);
  - `ALPHA` = the edged noise; **`EMISSION = ALBEDO * 2.0`** (above 1, so it blooms);
  - `blend_mix`, unshaded look through emission.
- Its noise texture `src/texture/flame/flame_01.tres` is a `NoiseTexture2D`: `FastNoiseLite` seed 5, `fractal_type` 2
  (ping-pong), 3 octaves, lacunarity 2.605, weighted strength 0.64, ping-pong strength 10.445, `cellular_return_type` 5,
  **domain warp** on (frequency 0.009, 2 octaves), `seamless = true`. The radial mask `src/texture/radial.tres` is a
  two-stop `GradientTexture2D` (white centre → black, radial fill).
- **Sparks** (`src/prefs/fire/sparks.tscn`): `GPUParticles3D`, 2 particles, lifetime 0.5, `trail_lifetime` 0.1, two draw
  passes (`PointMesh` + `TubeTrailMesh`); its process material emits from a 0.4×0.1×0.4 box, up at 1–3 m/s, tangential
  accel ±5, damping 1–10, no gravity, a scale curve that pops in and fades out (0 → 1 at 0.49 → 0).
- Driven by `src/script/fire/fire_area.gd` / `vfx_fire_controller.gd` (`play()`, `stop()`, `one_shot`).

**The fireball, `fire_ball_01.tscn`:** four layers.
- `Flame_Core`: a quad with `flame_core.gdshader`, **billboarded in the vertex shader** (it rebuilds `MODELVIEW_MATRIX`
  from `INV_VIEW_MATRIX` keeping the model's scale); two noises (one only warps), `COLOR.r` as a per-instance UV offset,
  a radial `smoothstep` mask, `ALBEDO = (1, pow(noise, 0.8), 0)`: orange to yellow by the noise.
- `Tip`: a `SphereMesh` with `fire_ball_01.gdshader`: vertex ripple along the normal
  (`sin((UV.y + t*0.4) * 40) * 0.01`), noise scrolled along UV.y, `smoothstep(0.15, 0.2, …)` edge, white-hot
  `vec3(1, 0.9, 0.8)` at the leading tip.
- `GPUParticles3D` embers: `flame_01.gdshader` quads, colour ramp red → white, initial-colour ramp red → black,
  1–3 m/s from a 0.1 m sphere, a scale curve.
- The same `sparks`.

**So the house style is:** 3–4 layers per effect; alpha cut by two scrolling noise layers; hard edges by `smoothstep` with
a narrow band (≈0.05–0.2); a 2–3 colour ramp with a hot (pale yellow / white) centre or tip; emission at ~1–2× albedo
for bloom; short-lived sparks with trails; small vertex motion (ripple, wobble); flash lights for impacts; billboards
done in the shader. **Why the lead's earlier effects looked "simple":** single meshes, flat colours, no noise-cut alpha,
no layering, not a missing tool.

## 2. Deliverables (each a step, one commit each: `v0.11.0 Step VL<n>: <outcome>`)

### VL1. The recipe: `docs/art/VFX_RECIPE.md`
- Survey **at least ten representative effects across the packs**, reading their `.tscn`, shaders and `.tres`: fire
  area + fire ball (above), one each from `ice_effects`, `impact_explosions` (explosion and hit), `magic_areas`,
  `magic_orbs`, `magic_projectiles`, `smoke_effects`, `poison_effects`, `muzzle_flash`, `beam_vfx`.
- For each: its layers (node type, mesh, material/shader), the shader techniques it uses, and the **numbers**: noise
  settings, scroll speeds, `smoothstep` bands, emission multipliers, colour ramps, particle amount/lifetime/velocity/curve,
  light energy/range/fade, durations.
- Distil it into: **the layer patterns** (ground pool, projectile, impact/burst, area/aura, beam, trail, flash), **the
  shader building blocks** (radial mask, dual-noise crawl, smoothstep edge, hot-centre ramp, vertex ripple, shader
  billboard, fresnel rim if found, UV scroll along a tube), **value ranges** (a table), **colour ramps per element**
  (fire, ice, poison, lightning/storm, arcane, earth/stone) and **timing** (pop-in, hold, fade).
- How it meets the game: the iso camera (35° down, far: effects are ~60–200 px), biome lighting and tints (bright Ruins
  vs dark Night Rocks), the project's glow/bloom settings (read them from `project.godot` / the environments in code),
  PD-13, `PackFx` rows (`data/vfx/*.tres`) and how the game colours and scales pack effects already.
- A "check before you show the owner" list (reads at game size, matches a named pack reference, layered, no flat
  colours, emission blooms but doesn't white out, reduced motion respected, cost: particle counts and draw calls).
- Link it from `docs/art/ART_DIRECTION.md` (the §4.x packs section) and from the PD-13 row's notes in
  `docs/architecture/LOCKED_DECISIONS.md` (a pointer only; don't change the decision).

### VL2. The lab: see an effect move, next to a pack reference, from the game camera
- `scripts/shots/vfx_lab.gd` (renderer, run off screen: `--position -10000,-10000`): takes a **lab sheet** (a small
  `.tres` or a dictionary file under `scripts/shots/vfx_lab/`) listing rows: `{label, scene or builder, reference scene,
  duration, play mode (loop | one-shot), scale, colour}`.
- For each row it places **the reference pack effect and the candidate side by side** in a real game view (reuse
  `EffectStage` / `EffectsCatalog`'s stage, `src/app/galleries/effect_stage.gd`, so camera, light, outline and bloom
  are the game's), in **two lightings** (Ruins and Night Rocks), and captures N frames over the effect's life.
- Outputs under `build/vfx_lab/<sheet>/` (never into tracked docs):
  - `<row>_strip.png`: reference row over candidate row, ~8 frames across, labelled with the time;
  - `<row>.webp` (or `.gif`): an **animated** side-by-side for the owner's phone, assembled from the frames with Pillow
    (`scripts/art/vfx_lab_anim.py`). The owner reviews motion, not stills.
- The **Effects gallery** (`EffectsCatalog`, debug builds) gets a `lab` group listing every candidate under
  `assets/vfx_zd/lab/`, so the owner can watch them live in the game (string keys en + es in `locale/strings.csv`).
- Tests: a unit test that the lab sheet loads and every row's scenes instantiate; a gallery test that the `lab` group
  finds a candidate; the existing gallery tests stay green. Lint clean.

### VL3. Sprites in the pack's style, when the pack lacks one
- `scripts/art/vfx_sprites.py` (numpy + Pillow; offline tool, writes into `assets/vfx_zd/textures/` only when asked):
  radial glow, star flare (n rays, soft core, like `shared/texture/flash/flash_02.png`), long flash, spiral, ring,
  crack mask; seamless noise tiles only if `NoiseTexture2D` can't do it.
- Prove it: render a generated star flare next to `flash_02.png` in the lab and in a strip; report honestly how close it
  is.
- Every generated texture goes into `assets/vfx_zd/manifest.json` (or the existing one) with its generator command;
  credits rebuilt if the content test needs it (`scripts/content/build_credits.gd`).

### VL4. The pilot: prove the recipe makes pack-quality effects
- **Calibration (blind):** rebuild a fire ground pool **from the recipe alone, without copying** `fire_area_01`'s
  files, as `assets/vfx_zd/lab/fire_pool_recipe.tscn`, and put it beside `fire_area_01` in the lab. This shows whether
  the recipe captures the style. Write down what differed and fix the recipe, not just the effect.
- **One effect the game lacks:** the Kiln Beetle's **heat haze over its vents** (its agent found no pack effect for it,
  O17e). Make 2–3 variants (e.g. a refraction shimmer quad using `SCREEN_TEXTURE`/`hint_screen_texture` with scrolling
  noise distortion; rising faint ember motes; a soft heat glow). Show them in the lab beside the closest pack effects.
  **Don't wire it into the Beetle**; the owner picks first (G2), then the lead wires it.
- Report to the owner: the strips and animated side-by-sides (send them with SendUserFile), and one short paragraph per
  candidate on what it is.

## 3. Constraints
- **Read `CLAUDE.md` first** (hard rules, evidence honesty, testing table). Presentation and tools only: **nothing under
  `src/sim/`**, nothing decides an outcome (EI-02/03/07). Every visible string `tr()` with en + es.
- **Don't touch the files the lead session is working in** (the O17 enemy models): `src/presentation/world_view/*_avatar.gd`,
  `actor_views.gd`, `solo_vat.gd`, `vat_*.gd`, `horde_vat.gd`, `ruins_rocks_views.gd`, `canyon_shore_bodies.gd`,
  `enemy_models.gd`, `assets/models/`, `docs/roadmap/v0.11.0/PROGRESS.md`. New files go under `scripts/shots/vfx_lab*`,
  `scripts/art/`, `assets/vfx_zd/lab/`, `assets/vfx_zd/textures/`, `docs/art/VFX_RECIPE.md`, plus the gallery's
  `lab` group and its strings.
- **Your own branch** (your worktree's), cut from local `claude/v0110`. Commit each step there. Don't push to
  `claude/v0110` or `main`, don't merge; pushing your own branch to origin is fine. The lead merges and runs seams.
- **Owner's PC (Windows):**
  - Godot: `C:/Users/extri/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe`. The console
    exe can't be copied or renamed; for `godot` on PATH use a bash wrapper script in `build/bin/godot` that `exec`s it.
  - Python: `C:/Users/extri/AppData/Local/Python/pythoncore-3.14-64/python.exe` (numpy, Pillow installed in the user
    site). If you override `APPDATA` for Godot, don't override it for Python (or set
    `PYTHONUSERBASE=C:/Users/extri/AppData/Roaming/Python`), or numpy disappears.
  - Lint: `C:/Users/extri/AppData/Local/Python/pythoncore-3.14-64/Scripts/gdformat` and `gdlint`. gdformat may write
    CRLF; keep files LF.
  - Use your own `APPDATA=C:/Users/extri/Desktop/zerodepth/appdata-vfxlab` for every Godot run, so saves don't collide
    with the lead's.
  - First run an import in your worktree (`godot --headless --path . --editor --import --quit`), and again after a new
    `class_name` or asset.
  - Tests always `--headless`; shots off screen. GUT exits 0 on parse errors: read "Passing Tests" and the errors. The
    PC's locale is Spanish: tests comparing English text call `TranslationServer.set_locale("en")`.
  - Never stage `.uid`/`.import` files you didn't cause; the untracked `scripts/shots/*.uid` and `newVFX/` in the main
    checkout aren't yours. Don't stage `project.godot` editor rewrites.
- **Keep it moving:** report after each step (a short line to the owner with the shot), don't wait for permission
  between VL1–VL3; VL4's choice is the owner's.
- **Evidence honesty:** paste real commands and raw output; `NOT YET RUN` is legal; never describe a look you didn't
  render and look at.

## 4. Done when
- `docs/art/VFX_RECIPE.md` exists with the survey table, the patterns, building blocks, ranges and ramps, and is linked.
- `vfx_lab.gd` renders strips and animated side-by-sides from a lab sheet, in two lightings; the gallery shows a `lab`
  group live.
- `vfx_sprites.py` makes the listed sprite kinds; a generated flare is shown beside the pack's.
- The calibration pool and the heat-haze variants are in the lab, sent to the owner, waiting on the owner's pick.
- Tests and lint green on what you touched; one commit per step on your branch; a short hand-over for the lead
  (branch, SHAs, what to merge, the owner's pending pick).

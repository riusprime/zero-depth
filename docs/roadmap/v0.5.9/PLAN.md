# v0.5.9 — Embers: lit, occluded, kit-built floors (plan, DRAFT)

Recorded so these decisions never depend on chat context. Progress: [`PROGRESS.md`](PROGRESS.md).

## Context
- **When:** this version starts **after the v0.5.0 session ends**. It runs on its own branch, cut from `origin/main` once
  v0.5.0 has merged, and merges only after the owner has verified the build. The version number `v0.5.9` is a proposal
  (an art-only version between v0.5.0 and v0.6.0); the owner may rename it at Step 0.
- **What the owner sent (2026-10-08):** a target image ([`../../art/look_reference.webp`](../../art/look_reference.webp)).
  It shows a dark iso scene where fire barrels and a glowing chest throw warm pools of light. Every block sits in soft
  contact shadow, and the props are chunky, chipped and weathered. The owner: "the lighting and occlusion ambience is
  the thing I'd like to achieve".
- **What is drawn today:**
  - one bright `DirectionalLight3D`;
  - linear tonemap, with no SSAO, SSIL or fog;
  - flat-shaded, untextured `BoxMesh` walls and a checkerboard ground (`src/presentation/world_view/stage_view.gd`);
  - code-built rubble, grass, boulders and mesas.
- **Owner rule:** anything that isn't a direct fix is decided before it's built.
- **Gates:**
  - **G2 "Look"** (Step 2) decides the direction.
  - It blocks Steps 3–6 from shipping as the default look. They may be built behind the fallback.
- **Conflicts this version must resolve with the owner, never quietly:**
  - **PD-11:** "Primitives-first, low-poly, flat-shaded 3D … the target look".
  - **ART_DIRECTION §4:** one light, no textures, glow only for core and shots.
  - **v0.2.0 L2:** clean, non-stair-stepped shadows. The pixel option (Q1) would break it.
  - The G2 pick supersedes these in the LOCKED_DECISIONS change log, on the same day.

## Every owner line → where it lands
| # | Owner line (verbatim or close) | Decision | Step |
|---|---|---|---|
| L1 | "is this doable in godot? … I just need to know if we can achieve this graphics" | Yes: SSAO/SSIL, warm omni lights, AgX tonemap, fog, a modular kit, and an optional low-res pixel filter | 1–5 |
| L2 | "I can create 10-20 renders and we use those procedurally with some rules to generate all of this" | 3D `.glb` kit pieces placed by seeded dressing rules over the sim's floor layout | 3, 4 |
| L3 | "the lighting and occlusion ambience is the thing I'd like to achieve" | Lighting comes first (Step 1) and needs no new art | 1 |
| L4 | Pieces made with an AI 3D generator (Tripo or similar) | Specs give target sizes; the import step rescales and snaps each piece | 3 |
| L5 | All 3 biomes, one shared kit | Kit retinted by the biome palette, plus 2 biome props each and one lighting mood per biome | 3, 5 |
| L6 | Pixel look: decide at the mockup | Q1 → G2 variant C | 2 |
| L7 | "different version, worked from a new branch and we'll merge and verify when ready" | Its own version and branch; merged after the owner verifies | 0, R |

## Design questions
- **Q1. Pixel look.** (a) Full resolution, with the mood coming only from light, AO and textures. (b) A low-res render
  with nearest upscale, as in the image. **Owner: decide at G2 (variant B vs C).**
- **Q2. Wall heights.** Today structural walls are 1.0 m and slabs 1.8 m.
  - (a) Keep them. ← recommended: it keeps occlusion low.
  - (b) Taller walls, closer to the image (1.6 m / 2.2 m), which hide more of the player and enemies.
- **Q3. Hero light.**
  - (a) A small warm light carried by the player, so the hero's area is always readable in dark rooms. ← recommended
  - (b) None.

## Steps
### 0. Setup
- Branch from `origin/main` after v0.5.0 merges. Update this PLAN with the SHA and commit it first.
- Add a ROADMAP §4 row and ART_DIRECTION §6 rows.
- The art list is [`../../art/KIT_REQUESTS.md`](../../art/KIT_REQUESTS.md). The owner can start making pieces now.

### 1. Lighting lab: dark scenes with warm light and contact shadow (presentation only)
- **Files:**
  - `stage_view.gd` (`_build_environment`, `_build_light`);
  - new `src/content/defs/biome_mood.gd`;
  - `data/biomes/*_mood.tres`;
  - `BiomeDefinition` gets a `mood` field;
  - `project.godot` (positional shadow atlas);
  - the options menu;
  - `locale/strings.csv`.
- **Rule / design:**
  - **`BiomeMood`** is typed `.tres`, validated and discovered through `ContentScanner` (EI-08), with a schema row in
    CONTENT_SCHEMA §6. Fields:
    - sun colour, energy and angle;
    - ambient colour and energy;
    - tonemap and exposure;
    - SSAO radius and intensity;
    - SSIL on or off;
    - fog density and colour;
    - glow;
    - warm-light colour and range.
  - **Environment:**
    - AgX tonemap.
    - **SSAO** for contact darkening, the core of L3.
    - **SSIL** for warm bounce light near fires.
    - Light depth fog.
    - Vignette via a CanvasLayer `ColorRect`.
    - SDFGI is tried in the lab only and ships only if the owner's GPU numbers allow.
  - **Lights:**
    - The sun becomes a dim, cool moon (night) or a low dusk sun.
    - Warm `OmniLight3D`s sit on light props (Step 4) and on the existing chest, portal and shrine lights.
    - At most N shadowed omni lights near the camera (starting value N = 4); the rest are unshadowed.
    - Enemies still carry no light (PRESENTATION_CONTRACTS §7).
  - **Readability:**
    - Telegraphs and pickups stay unshaded and above shadows, and INK stays the outline.
    - New `scripts/shots/look_contrast.gd` measures on-screen luminance contrast of hero, enemy and telegraph against
      the lit ground and writes to `build/`. The bar is 3:1 (PRESENTATION_CONTRACTS §3).
  - **Options:** Lighting quality Low (no SSAO/SSIL, unshadowed omni lights) / High, with `tr()` en and es.
- **Tests:** `BiomeMood` validation; every biome has a mood. The e2e test toggles lighting quality on `main.tscn`
  through `Input.parse_input_event`.
- **Reachable from the real game?** Yes: every floor uses its biome's mood, and the option sits in Options. Proved by
  the e2e test.
- **Done when:** the three biomes render with their moods, contrast evidence is pasted, and the tests pass.

### 2. G2 "Look": the owner picks the direction (presentation only)
- **Files:** `scripts/shots/mock_look.gd`, plus a pixel-filter prototype (`SubViewport` at 1/3–1/4 resolution, nearest
  upscale, camera snapped to the texel grid, HUD and InkPass at full resolution).
- **Rule / design:** fixed seed, the same room in all 3 biomes, 1920×1080, en and es. Variants:
  - **A:** today;
  - **B:** Step 1 at full resolution;
  - **C:** B plus the pixel filter.

  Kit pieces that have arrived are used; missing ones fall back to their primitive.
- **Done when:** the owner has picked. The same day:
  - LOCKED_DECISIONS change log: PD-11 superseded, and v0.2.0 L2 too if C is picked;
  - ART_DIRECTION §4 rewritten.

### 3. Kit pipeline: generated pieces load, scale and tint (presentation + asset tests)
- **Files:**
  - `assets/models/kit/<id>.glb`;
  - `assets/models/manifest.json`;
  - `src/presentation/world_view/boss_models.gd` → shared `ModelLibrary` (`BossModels` becomes a client);
  - new `kit_specs.gd`;
  - `tests/content/test_model_manifest.gd`.
- **Rule / design:**
  - Each spec gives a target footprint W×D×H (m), a bottom-centre pivot, a yaw fix and a tint mode.
  - On load, measure the AABB, scale to the footprint and drop the bottom to y = 0, with LOD for the poly budget.
  - Albedo × the biome palette token, so one kit serves all three biomes.
  - Repeated decoration draws through `MultiMeshInstance3D` (HORDES.md: draw calls are the 60 fps risk).
  - A missing piece draws its primitive (L15).
- **Tests:** the manifest test covers the kit, every `KitSpecs` id resolves, and normalisation puts the AABB within
  tolerance of the spec.
- **Done when:** the pieces delivered so far load in the mockup room at the right size.

### 4. Dressing rules: floors built from the kit, the same per seed (presentation only)
- **Files:**
  - new `src/presentation/world_view/stage_dresser.gd` (a pure function);
  - `stage_view.gd`.
- **Rule / design:**
  - Input is what `WorldReader` already exposes: `wall(i)` Obb plus `wall_class(i)`, `floor_ground()`, rooms, doors,
    reward positions and portal.
  - Output is `{piece, transform, tint}`. Draws come from the `cosmetic` stream, seeded from the floor seed (EI-05).
  - Starting values:
    1. **Looks solid = is solid.**
       - Anything taller than 0.4 m sits inside a sim wall or cover footprint.
       - The silhouette stays within ±0.1 m of the sim box.
       - Walkable ground gets only decoration of 0.4 m or less.
    2. **Structural walls:** tiled with `wall_2m` / `wall_1m`, with about 20% `wall_broken`, and `wall_pillar` at
       corners and ends. Height jitter is ±10%.
    3. **Cover slabs** (class 1), by footprint fit:
       - `car_wreck` (long);
       - `crate_stack` / `slab_concrete` / `slab_wide`;
       - `rock_large` in Night Rocks.
    4. **Light props:** 0–2 per room, inside wall footprints or flush against wall faces, never in a doorway. The
       start hall always gets 1.
       - `fire_barrel` gets a warm omni light and flame particles (within the §7 particle budget).
       - `brazier_pole` is wall-mounted.
    5. **Decoration:** `grass_tuft` along wall bases, `rubble_small` / `debris_low` on open floor. Keep 1.5 m clear
       of doorways, spawns, rewards and the portal.
    6. **Ground:** `ground_a` / `ground_b` textures replace the checker, plus stain and crack decals (within the
       64-decal budget).
    7. **Occlusion:** a sim wall fades all of its pieces. The fade becomes `TRANSPARENCY_ALPHA_HASH` (dithered, as
       PRESENTATION_CONTRACTS §5 asks) instead of plain alpha 0.3.
- **Tests:**
  - same seed gives the same placements;
  - no tall piece sits outside a sim footprint;
  - clearances hold;
  - every wall is covered;
  - the occlusion fade reaches every piece of a wall.
- **Reachable from the real game?** Yes: every floor. Proved by the existing run e2e test plus the tour screenshots.
- **Done when:** a 1,000-seed property test passes and the tour shows dressed floors in the three biomes.

### 5. Set pieces and biome identity (presentation only)
- The `chest` model (with its lid as a part) replaces the reward chest primitive in `reward_views.gd` and keeps its
  glow light.
- Biome extras are placed by biome. Moods:
  - Ruins: warm night;
  - Night Rocks: cold moon plus a few fires;
  - Red Canyon: dusk.

### 6. Performance (presentation only)
- `scripts/bench/view_bench.gd` gains a dressed, lit floor at both quality levels. Evidence goes in
  `evidence/LOOK.md` (command, raw output, SHA).
- Lavapipe numbers are labelled as lavapipe. Numbers on the owner's GPU are **OWNER ONLY**.

### R. Release
- ROADMAP §0.4 checklist: version bump, patch notes en + es, tour en + es, README row, PROGRESS final.
- `PLAYTEST.md` with look questions; owner answers are verbatim.
- Merge after the owner verifies the build.

## Open items (what they block)
- Q1 (G2), Q2 and Q3: these block Steps 2 and 4 from shipping as the default.
- Kit pieces from the owner: they block nothing, since each missing piece draws its primitive (L15).

## Verification
- Unit and property tests per step, through `bash scripts/verify.sh` from a clean worktree.
- The e2e test for the lighting option.
- Mockup and tour screenshots (`xvfb-run` plus lavapipe) and contrast numbers into `build/`, pasted by hand into
  evidence.
- `view_bench` at both quality levels.
- The sim is untouched, so **no golden may change**: a moved replay hash would mean presentation randomness leaked.
- Feel and results on the owner's GPU are OWNER ONLY.

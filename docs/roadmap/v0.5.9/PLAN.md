# v0.5.9 — Embers: lit, occluded, kit-built floors (plan, DRAFT)

Recorded so these decisions never depend on chat context. Progress: [`PROGRESS.md`](PROGRESS.md).

## Context
- **When:** the owner moved the start forward (2026-10-08): "can we start developing on what the other agent is building,
  he's just running balancing tweaks, so we can build over that code". This version runs on `claude/keen-volta-ht74pz`,
  built over the v0.4.0/v0.5.0 branch `claude/lucid-fermat-9wv2tf` (merged at `5e5b3f9`), not `origin/main`. That
  branch is merged in again often, because it still touches presentation files this version changes
  (`reward_views.gd`, `world_view_root.gd`). This version merges only after the owner has verified the build. The version number `v0.5.9` is a proposal
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
| G2 | "B, keep wall heights, yes to the hero light" (2026-10-08) | Variant B; PD-11 superseded (LOCKED_DECISIONS); C dropped; Q2 keep; Q3 yes | 1, 2 |
| L8 | "rework of how rooms generate … distinct objects and combinations … logical and structured … not the 9x9 diagonal wall design … like the image reference … saving the spacing we have now" (2026-10-08) | Proposal: themed rooms built from vignettes (below); waits on the owner's answers | 7 (proposed) |

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
- Branch `claude/keen-volta-ht74pz`, built over `claude/lucid-fermat-9wv2tf` at `5e5b3f9` (owner, 2026-10-08).
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

## L8 proposal: themed rooms built from vignettes (step 7, not built until answered)

**Today.** `RoomInterior` gives each room a geometric template (PILLARS, CROSS, LINES, BUNKERS, COLONNADE,
DIAGONALS…) made of identical slabs. `FloorGenerator` then keeps a group only if it keeps the gaps
(`EDGE` 2.6 m from walls, `slab_gap` 2.2 m between groups), leaves the doorways, start and gate clear, and leaves
the room in one piece. The patterns read as geometry, not as places, and the dresser has to guess what each slab
is from its shape.

**Proposal.** Keep the second half (the validation is what guarantees the mobility) and replace what gets
proposed.

1. **Vignettes** (new typed content, `data/vignettes/*.tres`, EI-08). A vignette is a small, authored, recognisable
   cluster:
   - a footprint;
   - its blocking boxes, which are the sim's collision;
   - its decoration, which is presentation only;
   - an anchor: `corner`, `wall`, `centre` or `free`.

   Each blocking box names the kit piece that draws it, so the dresser stops guessing. Starting set, from the
   reference:

   | Vignette | What it is |
   |---|---|
   | Wreck | A car wreck, a crate stack beside it, an oil drum |
   | Supply pile | 2–3 crate stacks in an L, with rubble |
   | Collapsed wall | A broken wall run with a pillar and fallen blocks |
   | Shrine / pillar pair | Two slabs framing a gap |
   | Barricade | A short low wall with crates behind it |
   | Burn barrel | A fire barrel inside a ring of low debris; a light source |
   | Rock outcrop (Night Rocks) | A large rock and a dead tree |
   | Mesa stack (Red Canyon) | Layered stone blocks |
   | Shed corner | Two short walls in an L hugging a room corner, with a ladder frame |

2. **Room themes.** Each room draws a theme by its size and role (hall, side room, portal room). The theme says
   which vignettes may appear, how many, and how they're laid out:
   - **Scrapyard:** wrecks and supply piles against the walls.
   - **Ruined hall:** collapsed walls and pillar pairs.
   - **Camp:** a burn barrel in the centre and barricades.
   - **Overgrown:** outcrops and grass.
   - **Open arena:** almost empty; for the boss approach and big fights.

3. **Structured placement on anchors.** This is what makes rooms look like your image: objects hug corners and
   walls, and the middle stays open lanes. The order is:
   1. corner vignettes first;
   2. then wall vignettes along the walls (never in front of a doorway);
   3. then at most one centrepiece in a big room.

   Every placement goes through today's checks: gaps, doorways clear, one region. A room also has a **blocked-area
   band** (starting value 8–15 % of its floor, measured against today's templates), so open space and mobility stay
   where they are now.

4. **Decoration** (grass at bases, rubble, drums) comes from each vignette's own list plus the dresser's existing
   rules. It stays presentation only and seeded.

**What it touches.** This is sim and content (`room_interior.gd`, `floor_generator.gd`, a new
`VignetteDefinition`, `FloorLayout` keeping each box's piece tag), plus the dresser. Every floor layout changes, so:
- the floor property tests (1,000 seeds) and the scorecard sims must be re-run;
- any balance numbers measured on today's layouts move;
- the replay goldens on generated floors change on purpose.

**Owner answers (2026-10-08):** "we are still adding this to the same version we worked on this session, which
will come after the v0.5.0 feedback, balancing is done from the other agent is done and I did not send the
feedback yet, but I'll send it after we work the visual rework, yes send mockups and I chose the rooms, if we need
more renders I could generate them after".
- **Q4:** (b). The room rework is part of v0.5.9, a one-time exception to "patch versions are presentation and
  art" (LOCKED_DECISIONS).
- **Q5:** the balancing pass is done and merged to `main` (PR #1); this branch merged `main` at `37d008d`. The
  scorecard sims are re-run after the rework.
- **Q6:** yes. Room mockups first (`scripts/shots/mock_rooms.gd`); the owner picks the rooms; the owner can make
  more pieces if a vignette needs them.

**Questions for the owner (answered above):**
- **Q4. Where it lives.** ROADMAP §0.3/§2 keep patch versions to presentation and art, and this is sim.
  - (a) Its own minor version after the v0.5.0 playtest, folded into this look work before the merge. ← recommended
  - (b) In v0.5.9 now, as a one-time waiver.
- **Q5. Timing with the balancing agent.** Its tuning is measured on today's layouts.
  - (a) Build this after its pass merges, then re-run the sims. ← recommended
  - (b) Build now; it re-measures afterwards.
- **Q6. Mockup first (G2).** Three room themes, rendered with the kit before the generator changes. ← recommended

### 7. Themed rooms (sim + tests + sims) — owner G2 Rooms, 2026-10-08

- **Owner:** "Density is about right … Just don't use as many cars scrapeyard, max 2 per room of the sized you show,
  if it's bigger it should increase proporcionally go ahead and implement these variants". On room sizes: unchanged.
  The generator still draws 1×1 to 3×3-cell rooms; the themes only fill them.
- **Files:**
  - new `src/sim/map/room_themes.gd` (the vignettes, the four themes, counts and the car cap);
  - `room_interior.gd` (the weights: ordinary rooms draw only themes, or now and then an open room; the geometric
    templates stay for boss arenas);
  - `floor_generator.gd` (`_furnish_themed`, `_vignette_fits`);
  - `floor_layout.gd` (`Template` gains SCRAPYARD, RUINED_HALL, CAMP, OVERGROWN; `piece_tags`);
  - `world_reader.gd` (`wall_piece`);
  - `stage_view.gd` (passes the piece to the dresser).
- **Rules:**
  - Vignettes per room = area / 44 m², clamped to 2..18.
  - Corners first, then the centre (Camp, rooms ≥ 200 m², never the start hall), then walls, then free floor.
  - Car wrecks ≤ max(1, ⌊2 × area / 352 m²⌋).
  - Spacing: a vignette's footprint touches a wall lining the room exactly (within 5 mm) or keeps the slab gap
    (2.2 m) from it, and keeps the slab gap from every other vignette. No overlaps. Plus every existing group check:
    doorways, the start and the gate clear, and the room stays one region.
- **Tests:** `tests/unit/sim/test_room_themes.gd` (200 floors: kit-piece tags, the car cap, no slits, bigger rooms
  hold more, deterministic tags). `test_floor_generator.gd`'s template assertion changes on purpose: the four
  themes show up, and no geometric template in ordinary rooms.
- **Done when:** the full suite passes (`a8f6958`: 1107/1107); the floor property tests pass; the owner sees generated
  rooms. The owner dropped the scorecard as a measure of difficulty (2026-10-08): "bot runs don't matter anymore, i
  cleared every single time I played v0.5 really easy". The one before-and-after run made stays in
  evidence/LOOK.md §4 for the record.

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

# VFX requests: textures for fire, explosions and electric effects

**Owner, 2026-10-09:** "let's start with the fire and main abilities, sword animation stays as is for now I like
it, but for example fire, bombs, electrical, there is a lot of combinations now and none of them work visually,
they look like test like … a lot of effects make a circle on the ground and I don't want that I want them to feel
real within the game and art direction, not a circle with bad made particles on top, fire should be fire, even if
minimalistic, that matches the style of the game". The owner generates the textures.

## How they're used

- **One look per element, not per combo.** The v0.6.0 modifier engine builds every attack from elements (fire,
  storm, frost, venom) on forms (projectile, burst, ring, lob, chain, trail). Each element gets one look that works on
  every form, so every combination, including future ones, looks right.
- **Real 3D.** The textures sit on 3D particles and meshes in the lit scene:
  - flames rise and flicker;
  - explosions bloom with debris and smoke;
  - lightning arcs through the air;
  - each one flashes real light on the floor and walls;
  - scorch marks stay behind.
- **No ground circles as the effect.** A flat, bright marker stays only where the player must read a danger zone
  (an enemy telegraph). Those are gameplay, not decoration.
- **Single images, animated in the engine.** Image generators can't keep an animation consistent frame to frame, so
  these are still shapes and seamless noise. Shaders animate them (scroll, distort, dissolve).

## Rules for every texture

- **Pure black background** (#000000). The engine uses brightness as transparency, so black means invisible.
- **Square PNG,** 1024 × 1024 unless the row says 512.
- **Sheets of 4** (2 × 2) where the row says so: four separate variants, each centred in its quarter, with nothing
  crossing the middle lines or touching the edges.
- **Style:** chunky, stylized, low-detail to match the low-poly kit. Cel-shaded with 2–3 flat tone bands and crisp
  shapes, no photo realism, no fine wisps. Think the stylized flame in the look reference.
- **No text, no frame, no ground, no scene.**
- **Name the file by its id** (`fx_flame_shapes.png`) and upload it to `unprocessed_images/vfx/`.

**Prompt prefix** (paste before each prompt):

> stylized game VFX texture, chunky low-poly game art style, cel shaded with 2-3 flat tone bands, crisp simple
> shapes, no photo realism, centered, isolated on a pure black background, no text, no frame, no ground,

## The list

| # | id | element | size | prompt (after the prefix) | status |
|---|---|---|---|---|---|
| 1 | `fx_flame_shapes` | fire | 1024, 2 × 2 | four different single flame tongues, each a tall stylized teardrop flame with a bright pale-yellow core, an orange middle band and a red-orange outer band, slightly different shapes and lean, each centred in its own quarter of the image | prepared (`281e4f1`) |
| 2 | `fx_fire_noise` | fire | 512 | seamless tileable texture, wispy upward-stretched flame noise in white and grey on black, vertical streaks, even coverage, no focal point | prepared (`281e4f1`) |
| 3 | `fx_smoke_puffs` | fire, bombs | 1024, 2 × 2 | four different chunky stylized smoke puffs, rounded cauliflower clusters in white and light grey with 2-3 flat grey bands, each centred in its own quarter | prepared (`281e4f1`) |
| 4 | `fx_explosion_burst` | bombs | 1024, 2 × 2 | four different stylized explosion fireballs seen from the side, chunky rounded fire clouds with a white-yellow core, orange middle and dark red edge, each centred in its own quarter | prepared (`281e4f1`) |
| 5 | `fx_debris_chunks` | bombs | 1024, 2 × 2 | four small groups of chunky rock and metal debris fragments, flat-shaded grey and rust colours, each group centred in its own quarter | prepared (`281e4f1`) |
| 6 | `fx_scorch_mark` | fire, bombs | 1024 | top-down view of an irregular charred scorch mark on the ground, dark black-brown burnt blotch with jagged cracks and soot spikes radiating outward, NOT a circle, uneven ragged outline, shown light grey on black (the engine darkens it) | prepared (`281e4f1`) |
| 7 | `fx_lightning_bolts` | electric | 1024, 2 × 2 | four different jagged horizontal lightning bolts running left to right across their quarter, a thin bright white core with a pale cyan-blue glow, a few small side forks, each centred in its own quarter | prepared (`281e4f1`; delivered as 4 rows, used as a 1 × 4 sheet) |
| 8 | `fx_electric_noise` | electric | 512 | seamless tileable texture, crackling electric web of thin bright branching lines in white and pale blue on black, even coverage, no focal point | prepared (`281e4f1`) |
| 9 | `fx_spark_shapes` | all | 512, 2 × 2 | four tiny bright spark shapes: a four-point star, a thin streak, a small diamond and a small cross, white with a soft glow, each centred in its own quarter | prepared (`281e4f1`) |

**Later (frost, venom, others):** requested once fire, explosions and electric are in and picked.

## After upload

1. Textures are prepared into `assets/textures/vfx/` (cropped into variants, brightness to alpha) and listed in the
   manifest.
2. Effects are built for fire (burning hits, fire bursts, Flame Trail, Ember Trail), bombs (Bomb Lobber, Bomb
   Rounds, Aftershock blasts) and electric (Storm Core chains, Arc Field, Shock Circles).
3. A before/after mockup goes to the owner to pick, then the rollout.

## Built (first pass, 2026-10-09)

`src/presentation/world_view/vfx/vfx_layer.gd` (VfxLayer). WorldViewRoot creates it when the new look is on
(the biome has a mood) and the textures are installed. AttackFormCanvas then sends these to it instead of drawing
flat shapes; without it, the canvas draws as before.

| Element on a form | Before (v0.6.0) | Now |
|---|---|---|
| Fire (ember) patch | a flat disc and rim on the ground, box particles | upright flames that breathe and swap shape, rising embers, a little smoke, warm light on floor and walls, a scorch decal |
| Bomb in flight | the bomb over a ground circle that fills | the bomb and its lit fuse only |
| Bomb landing | a flat flash disc and front (12 ticks) | a fireball that blooms and burns away, debris thrown out, a smoke cloud, a light flash, a scorch (70 ticks) |
| Electric (storm) patch | a flat disc and rim | lightning strikes inside the patch, sparks, a cold flicker of light |
| Electric ring | a flat ring growing | lightning running round the ring's edge, no fill |
| Electric beam or chain | a flat core and edge quad | a jagged bolt that re-strikes every few ticks, sparks at its end, light |

- **Kept as they were:** the sword; enemy telegraphs (gameplay readability); frost, venom, void and bleed (later
  pass); attacks that mix fire and electric take the fire look.
- **Budget:** fixed sprite pools per texture, 8 pooled lights (the brightest win), 48 scorch decals that fade after 7 s.
  Presentation only: it reads the canvas's effects and decides nothing (EI-07).
- **Tests:** `tests/unit/presentation/test_vfx_layer.gd`.
- **Mockup:** `scripts/shots/mock_vfx.gd` (before/after in a lit Ruins room: fire, bomb landing, bomb smoke,
  electric, all together) → `build/shots/<version>/vfx/`.

| Gate | Asked | Answer | Date |
|---|---|---|---|
| G2 Effects (before / after, mock_vfx.gd) | 2026-10-09 | OWNER ONLY | — |

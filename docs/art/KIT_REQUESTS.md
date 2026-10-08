# Kit requests: the pieces for v0.5.9 "Embers"

The owner makes these with an AI 3D generator (Tripo or similar). Seeded rules place them over each floor
([`../roadmap/v0.5.9/PLAN.md`](../roadmap/v0.5.9/PLAN.md) Step 4). Style reference:
[`look_reference.webp`](look_reference.webp).

Nothing here blocks a step. A missing piece draws its current primitive (L15).

## Rules for every piece

- **One object**, centred, with no ground plane, base or backdrop. The bottom is flat.
- **Low-poly, chunky and blocky** with chipped edges, like the reference. Aim for under about 3,000 triangles.
- **Neutral, desaturated colours** (greys, browns). The game tints each piece per biome.
- **No baked lighting, shadows or ambient occlusion in the texture.** The engine adds them; a baked shadow fights the
  real one.
- **Export `.glb`** with one texture of at most 1024 px.
- **Name it by its id** (`wall_1m.glb`) and drop it in `unprocessed_images/kit/` or send it in chat.
- **Sizes are targets, not exact.** The import step rescales each piece to its footprint, but the proportions should
  match: a 2×1×1 wall should look twice as long as it is tall.

**Prompt prefix** (paste it before each prompt):

> low-poly isometric game asset, chunky blocky shapes, chipped worn edges, muted desaturated colours, simple flat
> texture, no baked shadows, no lighting, single object, no ground, white background,

## Core kit (16)

| # | id | role | target W×D×H (m) | prompt (after the prefix) | status |
|---|---|---|---|---|---|
| 1 | `wall_1m` | wall | 1 × 1 × 1 | a cube-shaped block of rough grey stone or concrete, chipped top edges, small cracks | requested |
| 2 | `wall_2m` | wall | 2 × 1 × 1 | a long rectangular block of rough grey stone or concrete, twice as long as tall, a crack across the middle | requested |
| 3 | `wall_broken` | wall | 1 × 1 × 0.7 | a broken low concrete block with a jagged, crumbled top, a few bits of rusty rebar sticking out | requested |
| 4 | `wall_pillar` | wall corner | 1 × 1 × 1.3 | a thick square stone pillar, slightly taller than wide, chipped corners, flat top | requested |
| 5 | `slab_concrete` | cover | 1 × 1 × 1.8 | a tall weathered concrete slab standing upright, cracked, chunks missing from the top corner | requested |
| 6 | `slab_wide` | cover | 2 × 1 × 1.8 | two tall weathered concrete slabs standing side by side, touching, different heights | requested |
| 7 | `crate_stack` | cover | 1 × 1 × 1.2 | a stack of two or three old wooden and metal crates, slightly offset, worn planks | requested |
| 8 | `car_wreck` | cover | 2 × 4 × 1.4 | an abandoned rusty boxy car wreck, flat tyres, broken windows, dented panels | requested |
| 9 | `rock_large` | cover | 1.5 × 1.5 × 1.2 | a large faceted boulder with sharp flat faces, angular low-poly rock | requested |
| 10 | `fire_barrel` | light source | 0.6 × 0.6 × 0.9 | a rusty open-top oil drum, dented, burn marks near the rim, empty inside (no fire) | requested |
| 11 | `brazier_pole` | light source | 0.3 × 0.3 × 2.0 | a tall thin metal pole with a small iron fire basket on top, empty basket (no fire) | requested |
| 12 | `chest` | reward | 0.9 × 0.6 × 0.6 | a sturdy wooden treasure chest with dark metal bands, closed, a clear horizontal seam between lid and body. **Closed only.** A separate lid part is nice but not needed: a single mesh is cut at the seam in code (as BossRig does for bosses) | requested |
| 13 | `rubble_small` | decoration | 0.6 × 0.6 × 0.25 | a small flat cluster of 3 to 5 broken stone chunks | requested |
| 14 | `grass_tuft` | decoration | 0.5 × 0.5 × 0.4 | a clump of dry spiky grass blades, low-poly | requested |
| 15 | `debris_low` | decoration | 0.8 × 0.4 × 0.2 | a flat pile of scrap: a broken plank, a short rusty pipe and a metal plate lying on the ground | requested |
| 16 | `ground_a`, `ground_b` | ground | **2D tileable texture**, 512 × 512 px | full prompts in [Ground textures](#ground-textures) below (they replace the prefix) | requested |

**Fire and glow** (flames, sparks, the chest's inner light) are made in the engine, not in the models.

## Ground textures

These don't use the prefix above. Each one is a 2D image, 1024 × 1024 px, square.

**ground_a (worn stone tiles):**

> seamless tileable texture, perfectly repeating pattern, orthographic top-down view looking straight down, flat even
> lighting, no shadows, no vignette, no border, no frame. A floor of a regular grid of exactly 4 by 4 square worn stone
> paving tiles, equal size, the grid lines aligned to the image edges so that every tile is complete and the image
> edge cuts through the middle of a grout line. Muted desaturated grey-brown stone, thin dark grout, small chips,
> faint hairline cracks and light dust spread evenly across the whole image. No large unique features, no object, no
> plants, no text. Low-detail stylised game texture, low contrast.

**ground_b (packed dirt and gravel):**

> seamless tileable texture, perfectly repeating pattern, orthographic top-down view looking straight down, flat even
> lighting, no shadows, no vignette, no border, no frame. Packed dusty dirt ground with small scattered gravel and
> tiny pebbles, a few faint cracks, spread evenly across the whole image with no focal point. Muted desaturated
> grey-brown, low contrast. No large rocks, no object, no plants, no text, no tiles. Low-detail stylised game
> texture.

**Negative prompt** (if the tool has one):

> border, frame, vignette, edge decoration, perspective, horizon, shadows, lighting gradient, centred object, large
> rock, text, watermark, high contrast, saturated colours

**Tips:**

- If the generator has a **tile / seamless / tiling option**, turn it on. It matters more than the prompt. Midjourney
  uses `--tile`; Stable Diffusion UIs have a "Tiling" checkbox.
- Edges that don't loop are fine to send anyway. Claude makes them seamless in code: offset by half, then blend the
  seam. The texture must have no single big feature for that to work.

## Biome extras (6, second batch)

| id | biome | role | target W×D×H (m) | prompt (after the prefix) | status |
|---|---|---|---|---|---|
| `column_broken` | Ruins | cover | 1 × 1 × 1.6 | a broken ancient stone column, snapped top, fallen chunk at its base | requested |
| `ladder_frame` | Ruins | cover | 1 × 0.4 × 2.0 | a rusty metal scaffold frame with a ladder, flat-backed so it stands against a wall | requested |
| `boulder_small` | Night Rocks | decoration | 0.5 × 0.5 × 0.35 | a small angular faceted rock, flat underside | requested |
| `dead_tree` | Night Rocks | cover | 1 × 1 × 2.2 | a leafless dead tree with a thick twisted trunk and a few bare angular branches | requested |
| `mesa_chunk` | Red Canyon | cover | 1.5 × 1.5 × 1.4 | a layered sandstone rock block with horizontal strata, flat top | requested |
| `dry_shrub` | Red Canyon | decoration | 0.5 × 0.5 × 0.4 | a small dry thorny desert shrub, low-poly | requested |

## Delivery

When a piece arrives:

1. Commit it to `assets/models/kit/<id>.glb` (the ground textures go to `assets/textures/kit/`).
2. Add it to `assets/models/manifest.json` with its sha256.
3. Move its row here to `delivered`, with the commit SHA.

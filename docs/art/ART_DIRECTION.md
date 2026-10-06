# Art direction

**Low-poly, flat-shaded, primitives-first 3D, seen through a fixed orthographic isometric camera.** This look is
the target, not a placeholder (PD-11). Deathventory waited for art batches that arrived late and in lumps
([`../LESSONS.md`](../LESSONS.md) L15). Here every visual works from code first, and supplied art only replaces it.

The rules that make the look **readable** (outlines, team rings, occlusion, telegraph layering, colour-blind
modes) are contracts in [`../architecture/PRESENTATION_CONTRACTS.md`](../architecture/PRESENTATION_CONTRACTS.md).
This file holds the look itself.

## 1. The reference image

The owner's reference is a 2×2 grid of the same scene in four biomes. It belongs at
`docs/art/reference/biomes_reference.png` (owner action O2 in the v0.0.1 PLAN). What it shows:

- **Every panel has:**
  - **Player:** a white cube with glowing **cyan** inset panels on its sides (the "core"). A short white health
    bar floats above it.
  - **Enemies:** plain **red** cubes about the player's size, each with a short red bar above.
  - **Hostile shots:** **yellow** arrow-like streaks with dashed motion trails, flying from the enemies toward
    the player.
  - **Hazard prop:** at least one **red cylinder**, a barrel. Its red is close to the enemies' red (§2 rule).
  - **Ground detail:** small dark cubes scattered as rubble, and dry grass tufts.
  - **Floor:** large square tiles in two close tones, aligned to the world grid, so they read as diamonds on
    screen.
  - **Shadows:** hard, long, from one light at the upper right, falling toward the lower left.
- **Ruins (top left):** sand ground. Tall, thin **grey slabs** as walls and cover, some in L-shapes and broken
  ends. A wooden crate. Dry orange grass.
- **Night Rocks (top right):** blue ground on a raised plateau over a dark **void**. Big faceted blue boulders. A
  wooden fence along one edge. A bare dead tree.
- **Red Canyon (bottom left):** red-orange ground. Chunky dark-red **mesa blocks** and cliff edges. Dry grass.
- **Frozen Shore (bottom right):** white snow. Dark slate blocks. Bare dead trees. The shoreline meets dark blue
  **water** with white **ice floes**.

## 2. Palette tokens

Every `BiomeDefinition.palette` defines these tokens ([`../architecture/CONTENT_SCHEMA.md`](../architecture/CONTENT_SCHEMA.md)
§6). Values are **approximate eyedrops** from the reference. The owner confirms or adjusts them at the v0.1.0 G2
gate, and the confirmed values replace these.

| Token | Ruins | Night Rocks | Red Canyon | Frozen Shore (later) |
|---|---|---|---|---|
| `ground` | sand `#D9C4A0` | `#4A649A` | `#C9553F` | snow `#DCE6F0` |
| `ground_alt` (tile tone) | `#D2BC96` | `#46609A` | `#C24F3A` | `#D4DFEA` |
| `cover` | grey slab `#8C8C90` | `#33477A` | `#8E3A2B` | `#3D4F75` |
| `accent` (grass, props) | dry grass `#B07A3A` | fence wood `#3C3A44` | dry grass `#A0502E` | dead wood `#4A5468` |
| `void` / `water` | — | void `#1F2842` | dark `#5E241B` | water `#3C6E96` |
| `ambient` (light tint) | warm `#FFF1DC` | cool `#B8C8F0` | warm red `#FFD2C0` | cool `#E8F0FF` |

**Fixed actor colours** (the same in every biome; remapped only by colour-blind modes):

| Token | Value | Use |
|---|---|---|
| `player_body` | white `#F2F2F2` | Player cube |
| `player_core` | cyan `#33D6FF` (emissive) | Core panels, the player's ring, player projectiles |
| `player_bar` | white `#F2F2F2` | Player health bar |
| `enemy_body` | red `#D63A2F` | Enemy cubes |
| `enemy_bar` | red `#D63A2F` | Enemy health bars |
| `proj_hostile` | yellow `#FFC93C` (emissive) | **Hostile projectiles only** |
| `telegraph_hostile` | **proposal:** orange-red outline `#FF6A3D`, fill at 30% | Enemy attack areas |
| `hazard` | **proposal:** orange `#E0892B` with a dark band | Barrels and other hazard props, kept off `enemy_body` |
| `outline_dark` | `#1A1A22` | Actor outlines and contact rings |

Rules:
- `proj_hostile` and `player_core` are reserved for their uses (enforced by the palette test).
- The reference's red barrels are too close to `enemy_body`. Barrels use `hazard`, whose value is decided at
  G2.
- Each biome's `ground` must stay at least 3:1 in luminance contrast against `outline_dark`, so outlines read
  everywhere.

## 3. Shapes

| Thing | Shape | Notes |
|---|---|---|
| Player | Cube, about 0.7 m, with an inset emissive core on each side | Must read as "the player" in greyscale, through the core panels |
| Enemies | Cubes and boxy variants, about the player's size; bosses larger | One distinct silhouette per behaviour: a wedge for a charger, a shield plate for a guard, a long box for a shooter, and so on. Decided per enemy at its G2 |
| Walls and cover | Thin tall slabs (Ruins), faceted boulders (Night Rocks), mesa blocks (Red Canyon), slate blocks (Frozen Shore) | Generated from boxes plus seeded faceting |
| Props | Small cubes (rubble), grass tufts, crates, fences, dead trees, barrels, ice floes | Seeded procedural meshes; never block movement unless they are cover |
| Projectiles | Streaks: a thin emissive box plus a dashed trail | Hostile yellow, player cyan or white |

## 4. Lighting and rendering

- **One `DirectionalLight3D`** with hard shadows, coming from the upper right in screen terms as in the
  reference. Its angle is fixed per biome only if the owner asks.
- **Ambient:** a `WorldEnvironment` tinted with the biome's `ambient` token. **Glow** is on, for `player_core` and
  `proj_hostile` only.
- **Materials:** `StandardMaterial3D`, flat-shaded (low-poly normals), no textures except an optional subtle noise
  on the ground. Telegraph and pickup decals are unshaded and drawn above shadows.
- **Renderer:** Forward+ unless the v0.0.1 gallery shows Compatibility is needed
  ([`../architecture/ARCHITECTURE.md`](../architecture/ARCHITECTURE.md) §11).

## 5. Pipeline

1. **Primitives first.** Godot primitive meshes (`BoxMesh`, `CylinderMesh`) plus a seeded procedural generator
   for faceted rocks, mesas and dead trees (`src/presentation/world_view/procgen_mesh.gd`, `cosmetic` stream). This
   is enough to ship.
2. **Owner-supplied models later.** `.glb` files go in `assets/models/<kind>/`. A manifest
   (`assets/models/manifest.json`, with `id`, `path` and `sha256` per model) is checked by an asset test. A model
   replaces its primitive by id; if it's missing, the primitive draws.
3. **2D art** (item icons, key art, the app icon): agents write prompts, the owner generates the images, and the
   lead installs them. This is Deathventory's `ART_PROMPTS.json` flow. Prompts live in
   `docs/art/ART_PROMPTS.json` with `id`, `kind`, `size`, `prompt`, `style_ref` and `status`. Delivered images go
   through `unprocessed_images/` (with a `.gdignore`) into `assets/`.
4. **Fallbacks.** Every icon has a generated fallback: a coloured shape plus the item's first letter. Missing art
   never blocks a step.

## 6. Art requests per version

Each version's PLAN lists its art needs in a short table and adds the prompts to `ART_PROMPTS.json`:

| id | kind | needed by step | fallback in use | status |
|---|---|---|---|---|
| `icon_bleed_edge` | item icon 128×128 | v0.2.0 Step 5 | generated letter icon | requested |

A delivery moves the row to `delivered` with the commit SHA.

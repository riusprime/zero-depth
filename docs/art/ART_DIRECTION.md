# Art direction

**Low-poly, flat-shaded, primitives-first 3D, seen through a fixed orthographic isometric camera.** This look is
the target, not a placeholder (PD-11). Deathventory waited for art batches that arrived late and in lumps
([`../LESSONS.md`](../LESSONS.md) L15). Here every visual works from code first, and supplied art only replaces it.

The rules that make the look **readable** (outlines, team rings, occlusion, telegraph layering, colour-blind
modes) are contracts in [`../architecture/PRESENTATION_CONTRACTS.md`](../architecture/PRESENTATION_CONTRACTS.md).
This file holds the look itself.

## 1. The reference image

[`biomes_reference.png`](biomes_reference.png) (1536×1024) is the owner's reference. It is a 2×2 grid of the same
scene in four biomes:

- **Every panel has:**
  - **Player:** a white cube with glowing **cyan** inset panels on its sides (the "core"). A short white health
    bar floats above it.
  - **Enemies:** plain **red** cubes about the player's size, each with a short red bar above.
  - **Hostile shots:** **yellow** arrow-like streaks with dashed motion trails, flying from the enemies toward
    the player.
  - **Hazard prop:** at least one **red cylinder**, a barrel. Its red is close to the enemies' red (§2).
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

**What the reference shows about readability.** These figures are WCAG contrast ratios computed from colours
sampled out of the PNG (§2):
- Enemy red against Red Canyon ground is **1.21:1**. A colour mask for "enemy red" also selects most of the
  canyon floor.
- The white player against Frozen Shore snow is **1.16:1**.
- The barrels' red matches the enemies' red in all four panels.

Each of these became a rule in [`../architecture/PRESENTATION_CONTRACTS.md`](../architecture/PRESENTATION_CONTRACTS.md)
§3.

## 2. Palette tokens

**Biome tokens.** Every `BiomeDefinition.palette` must define exactly these seven keys
([`../architecture/CONTENT_SCHEMA.md`](../architecture/CONTENT_SCHEMA.md) §6):
`ground`, `ground_alt`, `cover`, `accent`, `edge`, `ambient`, `outline`.

Values marked *sampled* are medians of the reference PNG's pixels (lit faces where it matters). Values marked
*proposal* aren't visible in the image. The owner confirms or changes all of them at the v0.1.0 G2 gate.

| Token | Ruins | Night Rocks | Red Canyon | Frozen Shore (later) |
|---|---|---|---|---|
| `ground` | `#CBAD91` sampled | `#486796` sampled | `#C55946` sampled | `#D1DAE4` sampled |
| `ground_alt` (tile tone) | `#D0B396` sampled | `#50709F` sampled | `#D0614B` sampled | `#C7D3E1` sampled |
| `cover` | `#8C8C90` eyedrop (lit slab) | `#395077` sampled | `#7A3D36` sampled | `#303C52` sampled |
| `accent` (grass, props) | `#9D6B4C` sampled (grass) | `#3C3A44` proposal (fence) | `#9D6B4C` proposal (grass) | `#455B77` sampled |
| `edge` (void, cliff, water) | `#A08A74` proposal (no edge in image) | `#253043` sampled (void) | `#4C3032` sampled (cliff) | `#436C8E` sampled (water) |
| `ambient` (light tint) | `#FFF1DC` proposal | `#B8C8F0` proposal | `#FFD2C0` proposal | `#E8F0FF` proposal |
| `outline` (actor rim + contact ring) | `#1A1A22` (8.2:1) | `#EEF2F8` light (5.1:1) | `#1A1A22` (4.0:1) | `#1A1A22` (12.2:1) |

**Why `outline` changes per biome.** A dark outline on Night Rocks' blue reaches only 3.0:1, right at the limit,
so that biome uses a light rim. The ratio after each value is its contrast against that biome's `ground`. The
palette test requires at least 3:1.

**Fixed tokens.** These live in `ThemePalette`, not in biomes. They are the same everywhere, and only
colour-blind modes remap them.

| Token | Value | Use |
|---|---|---|
| `player_body` | `#F2F2F2` (lit in the image: `#EEE8E0` sampled) | Player cube |
| `player_core` | `#2BC4E2` sampled; emissive | Core panels, the player's ring, player projectiles |
| `player_bar` | `#F2F2F2` | Player health bar |
| `enemy_body` | `#E25A4C` sampled (lit faces) | Enemy cubes |
| `enemy_bar` | `#DF3731` sampled | Enemy health bars |
| `proj_hostile` | `#FBD07A` sampled; emissive | **Hostile projectiles only** |
| `telegraph_hostile` | `#FF6A3D` proposal: outline, with fill at 30% | Enemy attack areas |
| `hazard` | `#E0892B` proposal: orange with a dark band | Barrels and other hazard props |

Rules:
- `proj_hostile` and `player_core` are reserved for their uses (enforced by the palette test).
- Barrels sample at `#C3503E`–`#E25E4F`, the same as `enemy_body`. So barrels use `hazard`, and its final value is
  decided at G2.
- `enemy_body` against Red Canyon `ground` is 1.21:1. Team rings and outlines carry identity there, not hue
  ([`../architecture/PRESENTATION_CONTRACTS.md`](../architecture/PRESENTATION_CONTRACTS.md) §3).

## 3. Shapes

| Thing | Shape | Notes |
|---|---|---|
| Player | Cube, about 0.7 m, with an inset emissive core on each side | Must read as "the player" in greyscale, through the core panels |
| Enemies | Cubes and boxy variants, about the player's size; bosses larger | One distinct silhouette per behaviour: a wedge for a charger, a shield plate for a guard, a long box for a shooter, and so on. Decided per enemy at its G2 |
| Walls and cover | Thin tall slabs (Ruins), faceted boulders (Night Rocks), mesa blocks (Red Canyon), slate blocks (Frozen Shore) | Generated from boxes plus seeded faceting |
| Props | Small cubes (rubble), grass tufts, crates, fences, dead trees, barrels, ice floes | Seeded procedural meshes; never block movement unless they are cover |
| Projectiles | Streaks: a thin emissive box plus a dashed trail | Hostile yellow, player cyan or white |

## 4. Lighting and rendering

- **One `DirectionalLight3D`** with crisp, long shadows, coming from the upper right in screen terms as in the
  reference. Its angle is fixed per biome only if the owner asks. Shadow edges are straight and clean, never
  stair-stepped (owner, v0.2.0 L2): 8192 directional atlas, high soft-shadow filtering, blur 0.5, iso camera
  `far` kept short ([`../roadmap/v0.2.0/evidence/SHADOWS.md`](../roadmap/v0.2.0/evidence/SHADOWS.md)).
- **Ambient:** a `WorldEnvironment` tinted with the biome's `ambient` token. **Glow** is on, for `player_core` and
  `proj_hostile` only.
- **Materials:** `StandardMaterial3D`, flat-shaded (low-poly normals), no textures except an optional subtle noise
  on the ground. Telegraph and pickup decals are unshaded and drawn above shadows.
- **Renderer:** Forward+ unless the v0.0.1 gallery shows Compatibility is needed
  ([`../architecture/ARCHITECTURE.md`](../architecture/ARCHITECTURE.md) §11).

**Ink stroke (owner, 2026-10-07; picked INK).** The owner wanted the look "closer to a hand draw sketch … just
the feeling": a light, thin black stroke on the borders of things. `InkPass` draws it as a screen-space pass over
depth and normals. After playing the v0.1.0 build the owner said "the outline I like the most is INK set it as
default" (v0.2.0 PLAN L4), so the rule is: **the default outline is INK** (clean, one-pixel lines). Options still
offer off / ink / sketch / sketch + paper, and an unknown saved value falls back to ink
([`../roadmap/v0.1.0/evidence/OUTLINES.md`](../roadmap/v0.1.0/evidence/OUTLINES.md) shows the four styles).

**Main character (owner, 2026-10-07).** The reference is
[`main_character_visual_reference.png`](main_character_visual_reference.png): a small hooded wanderer, off-white
faceted hood with a dark face and a glowing cyan visor, a wide faceted cloak, short dark legs; shown in the game
scene and as a five-view turnaround. The player avatar must match it (PLAN v0.2.0 L10).
The detailed character sheet [`main-character-sheet.png`](main-character-sheet.png) (owner, 2026-10-07: front,
right-front, right, back-right) is the **primary** reference; where the two images differ, the sheet wins:
a forward-tipped, tapered box hood with a black shield-shaped face (pointed at the bottom) and a centred cyan
rectangle visor; a diamond poncho (corners front/back/left/right, a V-neck under the face, the front corner
lowest, ~2× the hood's width); two chunky, separated charcoal legs with lighter boot blocks, ~¼ of the height.

**Enemies (owner, 2026-10-07).** The reference is [`enemies_visual_reference.png`](enemies_visual_reference.png) (front, right-front and right views of each), to be matched as close to 1:1 as possible (PLAN v0.2.0 L17). Low-poly faceted, red and grey: **Charger** — a red hooded body with a glowing red visor, carried on four grey segmented claw legs with bone talons; **Needle** — a red cube body with red slit eyes on four mechanical legs, a grey cannon barrel forward; **Warden** — a hulking grey rock golem with huge stone fists, a faceted red cap/shell and a red visor slot.

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

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

**New enemies (v0.3.5 AI, owner F5/F6; code-built in the same style, no sheet yet).** **Arc Caster** — a tall faceted
red robe (an octagonal frustum) under grey pauldrons, a dark hood with a red slit visor and a red cowl, a grey staff
held out with a hostile-yellow arc crystal at its tip, three red rune shards orbiting the hood; the staff rises and
the crystal brightens through a windup. **Bomb Drone** — a faceted red quad-rotor hull with a red slit eye and a grey
cap, four grey arms with dark spinning rotors, a dark bomb slung under its belly with a glowing fuse; drawn 1.8 m up
with a soft bob, over a soft dark shadow and its contact ring on the ground, where the sim has it (melee and shots
hit it there). Telegraphs: the bolt's line carries a bright core, the rune an inner ring with turning spokes, the
bomb's circle a cross-hair and the bomb itself arcing down to it as the circle fills. Flash materials come from
`ActorViews.flashable` (emission on at energy 0; nothing toggles `emission_enabled` at runtime).

**Horde enemies (v0.4.0 EN; code-built in the same style, no sheet yet; `HordeAvatar`, `HordeVisuals`).** **Swarmer**
— a tiny red beetle on six grey legs with a grey head, a red slit eye and bone mandibles that open through its
windup. **Splitter** — two red half-bodies (a light and a dark red hexagonal frustum, grey caps) pressed over a
glowing hostile-orange seam that gapes as it winds up, grey claws with bone tips; a **Splitling** is the same at 0.62
scale. **Shield Bearer** — a squat grey body under a red helm with a red visor, dark legs, and a tall light-grey tower
shield (red rim and stripe) on its front; the shield draws back through the windup and slams forward on the bash; a
blocked hit sparks pale blue (the guard's block spark). **Mender** — a floating red robe and grey hood holding up a
heal crystal, with a spinning cross over it (the priority mark), both **pale green `#7CF29A`** (the heal colour: not
a reserved role); its heal beam is the same green, pulsing, from the crystal to its patient. **Mine Layer** — a low
red crawler on dark treads with a grey dome, a red eye and a rear hopper holding a dark mine; a mine on the floor is
a dark disc with a blinking red light inside a faint hostile ring (its circle), and an armed mine's circle fills as a
telegraph with a turning spiked star. **Sniper** — a red box body on a grey tripod with a long light-grey barrel and
a red scope that glows hotter through the windup; its line carries the bolt's bright core and its shot leaves a
hostile-yellow tracer. The Shield Bearer's bash lane carries two chevrons pointing down it.

**Bosses (owner, 2026-10-07).** The reference is [`first-three-bosses-concept.png`](first-three-bosses-concept.png): **Stone Sentinel** (colossal grey boulder golem, huge stacked stone fists, a spiky faceted red crown and back shell with a red visor slot and glowing red cracks on the back), **Crawler Queen** (a red faceted hood carapace with a red hex visor, a huge red egg sac of glowing spheres with spikes, many grey legs with long bone talons), **Fortress Turret** (a red armoured box hull with red slit eyes, a long grey main cannon with a vented muzzle, two back mortar tubes with red glow, four heavy grey mechanical legs). Matched as close to 1:1 as possible (PLAN v0.3.0 L10).

**Second bosses (v0.4.0 BO; code-built in the same style until the owner's sheet; prompts in
[`BOSSES_2.md`](BOSSES_2.md)).** **Warlord** — a grey faceted armoured knight on short armoured legs, red tabard and
pauldrons, a closed grey helm with a glowing red T visor under a crest of red crystal blades, a tall red tower shield
with a grey rim and a glowing emblem on its left arm, a long grey spear with a red head; the shield lifts up and aside
while its weak point (a gold core on the chest) is open. **Hive Lens** — a faceted grey armoured sphere hovering
1.75 m up over a soft ground shadow, one great red iris with a dark pupil ringed by red crystal lashes, three red
drone pods docked on its rim (they drift off and vanish when it splits), three grey cable tails with glowing red
tips. **Lens Drone** — a small red pod with a grey cap, a red eye slit and a turning grey ring, hovering 1.3 m up.
**Foundry** — a squat grey furnace block with a red hood, a glowing grate behind a dark door frame in front (the door
swings open on the weak point), two chimneys glowing inside, glowing side vents, a red launcher tube on its back and
four short heavy legs. Their flood telegraphs stand drawn while active: the Warlord's as a row of spear heads down
each lane, the Foundry's as a hot orange core with cross bars. Every body piece is outlined and flashable
(`ActorViews.flashable`); glows change energy only. A model file `assets/models/bosses/<warlord|hive_lens|foundry>.glb`
replaces a code body (whole-body motion until rigged). v0.5.5 LK (A6): the model request in the new style, with an image
prompt and a 3D model prompt per boss, is [`requests/v0.5.5_bosses_2_models.md`](requests/v0.5.5_bosses_2_models.md).

**Heat-coloured attacks (owner, v0.5.5 A2).** The hero's attacks (the blade and its trail, the bolts, the Lunge
Cleave and the Scatter Blast) wear the Overclock meter's tier colour (`HeatLooks.attack_color`): their own colour
below Hot, the meter's Hot orange `#FFA63A` at Hot, its Overclock red `#FF4A1A` at Overclock and while overheated.
One table (`HeatLooks`) feeds the meter and the attacks.

**VFX audit (v0.5.5 A3).** Every effect against the owner's new art and light:
[`../roadmap/v0.5.5/evidence/VFX_AUDIT.md`](../roadmap/v0.5.5/evidence/VFX_AUDIT.md). Rule taken from it: a flash
of light (a vent's disc, a skill's flash) is additive; debris and vapour (death shards, steam) are lit by the scene;
telegraphs stay unshaded (PRESENTATION §4).

## 5. Pipeline

1. **Primitives first.** Godot primitive meshes (`BoxMesh`, `CylinderMesh`) plus a seeded procedural generator
   for faceted rocks, mesas and dead trees (`src/presentation/world_view/procgen_mesh.gd`, `cosmetic` stream). This
   is enough to ship.
2. **Owner-supplied models later.** `.glb` files go in `assets/models/<kind>/`. A manifest
   (`assets/models/manifest.json`, with `id`, `path` and `sha256` per model) is checked by an asset test. A model
   replaces its primitive by id; if it's missing, the primitive draws.
   **Owner-supplied UI art (v0.5.5 A4).** The pick cards' 12 crystal frames are the owner's own art, cropped from
   [`../roadmap/v0.5.5/refs/card_templates_empty.webp`](../roadmap/v0.5.5/refs/card_templates_empty.webp) by
   `scripts/art/crop_card_frames.py` into `assets/ui/cards/frame_<colour>.png` (251 × 505, RGBA). The manifest
   (`assets/ui/cards/manifest.json`: source and its sha256, licence, and per frame `id`, `path`, `sha256`, `size`
   and the dark `panel` box) is checked by `tests/content/test_card_frame_assets.gd`; `--check` re-crops in memory
   and fails if a file differs. The card layout follows
   [`../roadmap/v0.5.5/refs/card_style_reference.webp`](../roadmap/v0.5.5/refs/card_style_reference.webp): the
   frame's crystals on top, then inside its dark panel the title in coloured capitals, the sentence, the rarity line
   between the card's icon and a rarity gem; a glow behind the frame for rare, epic and ability cards. The frame
   colour is the card's family, one table in `src/presentation/hud/card_frames.gd` (red damage, blue projectiles
   and frost, amber economy and stats, purple dash and void, green healing, silver time and slow, pink crit, cyan
   area, orange fire, violet curses, gold epic, indigo trinkets; the owner may remap).
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

**v0.5.9 "Embers" kit:** the modular `.glb` pieces and ground textures are requested in
[`KIT_REQUESTS.md`](KIT_REQUESTS.md) (target image [`look_reference.webp`](look_reference.webp)). Until the v0.5.9 G2
look pick, §4 and PD-11 still stand.

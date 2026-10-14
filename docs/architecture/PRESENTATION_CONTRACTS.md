# Presentation contracts

How the game looks, reads and responds on screen. Presentation is everything under `src/presentation/`. It reads
the sim and never writes it (EI-07). Palette values live in [`../art/ART_DIRECTION.md`](../art/ART_DIRECTION.md);
this file holds the rules they must satisfy.

Numbers marked **starting value** are defaults to tune, usually at a G2 gate or an owner playtest.

## 1. Camera

- **Projection:** a `Camera3D` in `PROJECTION_ORTHOGONAL` with a fixed **45° yaw** and **no rotation** (PD-02).
- **Pitch:** picked by the owner from the v0.0.1 camera gallery. The candidates are 30°, 35.26° (true isometric)
  and 45°. Record the pick in [`LOCKED_DECISIONS.md`](LOCKED_DECISIONS.md) as a PD.
- **Framing:** the ortho `size` shows a whole room's width plus a margin. Rooms are 1–1.5 screens
  ([`../design/GAME_BLUEPRINT.md`](../design/GAME_BLUEPRINT.md) §G).
- **Follow:** the camera follows the player with a dead zone and a small look-ahead toward the aim point
  (**starting values**: dead zone 1.5 m, look-ahead 15% of aim distance, capped at 3 m). It is smoothed in
  `_process` and never affects the sim. Because it moves in `_process`, the camera node sets
  `physics_interpolation_mode = PHYSICS_INTERPOLATION_MODE_OFF`, so physics interpolation doesn't fight it.
- **Shake** is presentation only. It uses the `cosmetic` RNG stream, has an Options toggle and intensity slider,
  and is off under reduced motion.

## 2. Frame and interpolation

- `SimDriver` steps the sim in `_physics_process` at 60 Hz. Views then write each actor's `Node3D` transform from
  the sim state.
- Godot's 3D physics interpolation (`physics/common/physics_interpolation = true`, 4.4+) smooths those
  transforms between ticks. A view calls `reset_physics_interpolation()` when an actor spawns or teleports, so it
  doesn't streak across the room.
- The **aim reticle** is drawn in `_process` from the live cursor or stick position, not from the last tick. Aim
  must feel instant even though the sim reads it at 60 Hz.
- **Frame budget** (**target**): 60 fps at 1080p on the owner's lowest-spec GPU, with the presentation stress
  scene at p99 ≤ 16.6 ms per frame. The bench lives in `scripts/bench/view_bench.gd` from v0.1.0.

## 3. Readability rules

The reference image ([`../art/ART_DIRECTION.md`](../art/ART_DIRECTION.md) §1) already shows where readability
breaks. The contrast figures below were computed from colours sampled out of the PNG. Each problem became a rule:

| Problem seen in the image | Rule |
|---|---|
| The white player against Frozen Shore snow is **1.16:1** | Every actor has a **contact ring** under it and a **rim outline** (the stencil outline mode in `BaseMaterial3D`, to be proved in the v0.0.1 occlusion gallery), both drawn in the biome's `outline` token. Each biome's `outline` must reach at least **3:1** against its `ground`. |
| The red enemies against Red Canyon ground are **1.21:1** | A **team ring decal** sits under every actor: cyan for the player, red for enemies. Team identity never relies on body hue alone. |
| The red barrels share the enemies' red in all four biomes | Hazard props never use the enemy colour token. They get their own `hazard` token and a distinct silhouette (a cylinder with a band). |
| Tall slabs hide actors from the iso view | **Occlusion cutaway** (§5). |
| Hard, long shadows fall across the floor | Telegraphs and pickups render **unshaded and above shadows**. A shadow can never hide a warning. |

- **Reserved colours.** Hostile-projectile yellow is used for hostile projectiles **only**. Player cyan is used
  for the player, their projectiles and their ring only. The palette test enforces both.
- **Shape language.** The player is a cube with a glowing core. Enemies are cubes and boxy variants, each with a
  distinct silhouette per behaviour. Cover is a slab or a rock. A hazard is a cylinder or a marked field. A
  behaviour must be identifiable in greyscale.
- **Health bars** float above actors (white for the player, red for enemies), as in the image, and also show in
  the HUD for the player. Bars never overlap the actor's body.

**Sealed arenas (v0.5.5 AR).** While an arena is sealed the rest of the floor goes dark (owner X1: "Others go dark
when sealed") as a separate layer (`ArenaViews`: an unshaded dark veil box over every other room, faded in and out);
the biome's lighting mood (sun, ambient, fog, SSAO, the kit's lights) is never written, so v0.5.9's look comes back
unchanged at the clear. The minimap keeps showing the whole layout and marks each arena (amber) once discovered.

## 4. Telegraphs

- Every enemy attack shows its area on the ground for its full windup. The windup is at least
  `MIN_TELEGRAPH_TICKS` (validated in content, [`CONTENT_SCHEMA.md`](CONTENT_SCHEMA.md) §3).
- A telegraph is an unshaded decal or mesh drawn after shadows. It has an outline at full opacity and a fill that
  grows from 0 to 100% across the windup, so the player can read *when* as well as *where*.
- The shape comes from the same sim function that resolves the hit (EI-07). The test
  `tests/unit/presentation/test_telegraph_parity.gd` checks that the drawn area equals the hit area for every
  attack shape.
- **No damage without a readable cause.** Every `DAMAGE` event against the player maps to a telegraph, a visible
  projectile, a visible field or a status icon. v0.1.0's exit gate tests this from the event log.
- **Body cues instead of ground marks** (owner, v0.7.5 N16 and v0.8.0 O4 / Q3, 2026-10-14: "only things landing at
  range"). Among normal enemies only the Arc Caster's rune and the Mine Layer's armed mines are drawn on the ground.
  Every other normal enemy's telegraph (the fireball casters' `cast` / `lob`; since v0.8.0 TG the Charger / Hatchling
  / Swarmer lanes, the Splitter / Splitling disc, the Shield Bearer's bash, the Warden's slam, the Sniper's line and
  the Needle's lanes) carries `"ground": false`: it keeps its shape and timing for the forecasts, the parity tests and
  the readable-cause check, and its avatar tells the windup (AvatarBase `tell_crouch` / `tell_glow`: a crouch that
  deepens with the progress, an accent glow that climbs and flashes over the last fifth, steady under reduced
  motion; the body faces the locked attack). Elites follow their kind; the bosses' markers are unchanged.
  `tests/unit/sim/test_enemy_ground_marks.gd` lists the ground marks per kind.
- **Boss ground attacks in 3D** (v0.8.0 AV, owner O7). The Gatekeeper's shock lanes (a `row_lanes` marks telegraph,
  `TelegraphViews.is_cracked`) are drawn as cracked ground on the exact lane quads (a procedural crack shader, still
  unshaded and over shadows): faint glowing cracks under the dull outline while they track, charred ground with wide
  hot cracks that pulse under the bright edge once locked (steady with reduced motion). On the strike tick (the lanes
  marker shows locked at progress 1000, `BossDodge.mark_state` 2) `StoneSpikeViews` raises stone spikes along the same
  lanes; they sink back within 0.6 s. Drawn, never decided: the hit is the sim's, the spikes only follow it.

- **The player's attacks are drawn from their final specs** (v0.6.0 MX1; design
  [`../design/MODIFIER_ENGINE.md`](../design/MODIFIER_ENGINE.md) §4): `AttackView` reads `WorldReader.attack_spec`
  and composes the look by layer (form → what draws it, size → the blade's arc and reach and the dart's length,
  elements → the core colour, behaviour → trail and brightness, heat → the edge via `HeatLooks.attack_color`). No
  view asks which cards are held for an attack's look. MX1 keeps the v0.5 looks exactly
  (`tests/unit/presentation/test_attack_view.gd`); the 8-form / 5-element art layers are MX stage 3.
- **MX3: the form and element layers** (`src/presentation/world_view/attack_forms/`). `AttackFormLooks.compose(spec,
  heat tier)` turns a spec into a look: the form picks the pools, size / reach / count / spread / directions the
  meshes' scale, number and layout (a halo of 12 shots is 12 darts evenly round); the first element sets the core
  colour and particles (storm white-blue crackle, ember orange sparks, frost pale shards, venom green drip, void violet
  smear, bleed MX1's tint), a second element the rim; the heat edge is `HeatLooks.attack_color` over the rim (values
  untouched); behaviour cues (pierce a streak, bounce a flash, home a curved trail, return a tether); a damage
  multiplier (`damage_mul_permille`) thickens and brightens, a crit adds a white-hot flash. `AttackFormView` draws
  them in MultiMesh pools per form layer and per particle kind, additive light (lit matter for the lob's bomb), timed
  by sim ticks. **Ground marks never take a hostile hue:** a zone's patch, a lob's landing circle and the flat fill of
  a ring or burst pass through `AttackFormLooks.ground_safe`, which leans a colour in the telegraphs' red-orange /
  red / magenta band toward the player's cool core; only light that rises off the floor carries the heat edge.
  Plain attacks (no element, cue or weight) add nothing over the v0.5 blade and dart.
- **The ability modifiers' attacks** (v0.6.0 MX2) draw through the existing ability views from sim numbers: bombs and
  their ground circles (`AbilityVisuals`), the drones and orbit blades, the patches by kind (`ElementVisuals`: fire
  orange, Napalm red, Arc Field's shock field pale blue, a hook's zone pale white) and each growing ring (the RING
  form) as a frost torus at its radius now. Their per-form art is MX stage 3.
- **MX3 takes over the spec forms of MX2's runners** in the game (`WorldViewRoot` sets `forms_drawn` on
  `ElementVisuals` and `AbilityVisuals`): `AttackFormView` reads each live ring (`WorldReader.rings_live`: drawn at the
  runner's radius now, so the drawn front is the hit front), each patch that names a spec (`fire_spec_keys`), each bomb
  (`bomb_spec_keys`: the shell on its arc over its blast circle, then its landing), the orbit blades' ORBITER spec
  (an element glow and trail over the steel blades, which `AbilityVisuals` keeps) and every player projectile in its
  own spec's look (`projectile_spec_key`, `attack_spec_at`). What names no spec (Napalm Drone's patches, the drones)
  stays with the older views.

## 5. Occlusion cutaway

- A wall whose box lies between the camera and a focus point (the player, enemies within a radius, active
  telegraphs) **fades** with a dithered alpha (**starting value**: 25% opacity) while it blocks.
- An actor that is still hidden draws a flat **silhouette** in its team colour through the wall. The first
  technique to try is the `BaseMaterial3D` X-ray stencil mode (4.5+). The occlusion gallery scene proves the
  technique before it's adopted.
- Picking which walls fade is a pure function, `Occlusion.select(cam_dir, focus_points, walls) ->
  PackedInt32Array`. It is unit tested in `tests/unit/presentation/test_occlusion_select.gd`, separately from the
  rendering.
- **Crowds (v0.4.0 SC):** the focus points are the player and at most `WorldViewRoot.OCCLUSION_FOCUS_MAX` (24)
  enemies within `OCCLUSION_RADIUS_M` (10 m) of it; `select` rejects far point-wall pairs with a cheap distance test
  before the exact one (it picks the same walls). Testing every wall against every enemy each frame had become the
  view's largest CPU cost with a horde; the X-ray silhouettes still show the enemies farther off.

## 6. Hit feel

- **Hit-stop** is sim state (`freeze_ticks`, [`SIM_CONTRACTS.md`](SIM_CONTRACTS.md) §2). The view shows it; it
  never creates it.
- **Flash:** a struck actor flashes white for a few frames (**starting value** 3 frames). Reduced motion keeps
  the flash but lowers its intensity.
- **Shake:** see §1.
- **Damage numbers:** optional (an Options toggle), placed from the event's `pos` and stacked so they don't
  overlap.
- **Armour sparks:** read from `HIT` tags only. A guarded hit throws a pale spark, a hit on a Warden's armoured
  front (`ARMOURED`) a dull grey one, a hit on its weak spot behind (`WEAK_SPOT`) a bright one, so flanking reads.
- **Death:** a short pop of low-poly shards from the `cosmetic` stream. A dead enemy's ring disappears on the
  `KILL` tick, so it never reads as alive.

## 7. VFX and cue budget

- **Crowds (v0.4.0 SC):** projectile nodes are pooled per look (hidden and reused, at most
  `ActorViews.PROJECTILE_POOL_MAX` idle) and share one mesh and one kept material per look; an enemy's floating HP
  bar shows only once it is hurt (the hero's always); enemy models beyond `ActorViews.ANIMATE_RADIUS_M` (24 m, off
  screen) stop their frame-time animation; no enemy carries a light (a boss has its weak-point light only). The
  damage-lag rule stands: materials are built flashable (`ActorViews.flashable`), and nothing toggles
  `emission_enabled` or another feature flag at runtime. Enemy models are not MultiMesh instances: each kind's model
  animates its own parts, so a crowd stays one node tree per enemy (measured in `docs/roadmap/v0.4.0/evidence/
  HORDES.md`).
- **Attack forms (v0.6.0 MX3):** at most `AttackFormView.MAX_ATTACK_MESHES` (1,024) form meshes and
  `MAX_PARTICLES` (1,200, inside the 2,000 below) attack particles a frame, the live attacks first, then the newest
  effects; every pool has a fixed size (384 per layer, 600 per particle kind) and at most 256 effects live. Options >
  Display > **Effects density** (low / medium / high, `ViewPrefs.effects_density`; default high) scales the particles
  (× 0.25 / 0.55 / 1) and the mesh cap (384 / 640 / 1,024); a pattern's own copies are never thinned below the cap.
- **Hostile fireballs and stone spikes (v0.8.0 AV):** each fireball look is three MultiMeshes (core, edge, trail; one
  draw each) whatever the count; Low density draws every other trail, shorter and narrower (the balls stay). Lights
  come only from VfxCore's pool (`LIGHTS`, the brightest requests win): one per lobbed fireball or raining drop, at
  most `FireballViews.SIGNATURE_LIGHTS` for a boss's signature shots, one flash per spike strike. The spikes are one
  MultiMesh of at most `StoneSpikeViews.MAX_SPIKES` (512), at most `MAX_STRIKES` (8) strikes alive; their debris and
  dust come out of VfxCore's sprite pools (inside the 2,000) and scale with the density, their crack marks out of its
  64 decals.

- **Starting values**, confirmed by the stress scene in v0.1.0:
  - at most 2,000 live GPU particles in total;
  - at most 24 concurrent hit-spark emitters;
  - at most 64 decals.
- Cues play in event order within the frame they arrive. If the budget is exceeded, cosmetic cues drop first, by
  priority. Telegraphs, player-damage feedback and pickup highlights never drop.
- The `CueBuffer` never blocks the sim (see [`ARCHITECTURE.md`](ARCHITECTURE.md) §12 on Deathventory's
  `PresentationGate`).

## 8. Accessibility

| Setting | Version | Contract |
|---|---|---|
| Remapping (KB+M and pad) | v0.1.0 | Every action is rebindable. Prompts follow the last-used device. |
| Screen shake on/off and intensity | v0.1.0 | Off means none at all. |
| Reduced motion | v0.1.0 | No shake. Fewer particles. No full-screen flashes. Camera smoothing is kept. |
| Colour-blind modes | v0.1.0 | Normal, red-green safe and blue-yellow safe. Each mode remaps the team, hostile-projectile, telegraph and hazard tokens. |
| Captions for sounds | v0.1.0 | Every gameplay SFX has a caption key ([`../audio/SFX_NEEDS.md`](../audio/SFX_NEEDS.md)). |
| Text size floor | v0.0.1 | Body text is at least 18 px at 1080p (**starting value**). |
| Flash safety | v0.1.0 | No full-screen flash more than 3 times per second. |
| Interface size | v0.7.5 SM | Options → Accessibility "Interface size" 90 / 100 / 110 % (`ui_scale`): the window's content scale, so every menu, the HUD and their text grow or shrink together; the 3D view is not scaled. 110 % is the most the 1080-built pick panel takes at 1280×720. |
| First-run hints | v0.7.5 SM | Options → Accessibility "Show hints" (on by default) and "Reset hints". A hint never blocks: no mouse, no focus, no pause; the keys it names follow the last-used device and the live bindings. |

**Palette test** (`tests/unit/presentation/test_palette_contrast.gd`). For each colour-blind mode, it simulates
the mode's colour vision on the tokens and asserts:
- the player, enemy, hostile-projectile and telegraph tokens stay pairwise distinguishable (a minimum
  colour-difference threshold, **starting value** ΔE ≥ 20);
- every biome's `outline` keeps a contrast of at least 3:1 against that biome's `ground`.

## 9. UI

- **The build and the Swap** (v0.6.0 MX2): `BuildHud` (its own node) shows the weapon, the utility pick and six
  modifier slot pips in the card family's frame colour (`CardFrames`) with the level on an ability modifier;
  `SwapPanel` (its own node, over the pick panel and the shop) shows the incoming card and the six held modifiers
  while `WorldReader.swapping()`; its answer goes out as input (`InputFrame.PICK_SWAP_BASE + n`, `PICK_SWAP_SKIP`):
  keyboard 1–6 / arrows and Enter, Esc to skip; a mouse click; pad d-pad, A, B.
- **Theme tokens** come from `ThemePalette` (adapted from Deathventory): colours, font sizes, a spacing scale and
  corner radii. No view hard-codes a colour or size.
- **Layout:** the UI sits on a `CanvasLayer`. The base resolution is 1920×1080 with `canvas_items` stretch and
  `expand` aspect (**starting values**). It is tested at 1280×720, 1920×1080, 2560×1440 and 3440×1440.
- **Font:** one dynamic TTF with full Latin coverage, including Spanish (á é í ó ú ü ñ ¿ ¡), set in the project
  theme. There are no bitmap fonts ([`../LESSONS.md`](../LESSONS.md) L13).
- **Strings:** every visible string is `tr("KEY")` (EI-10). Layouts must fit Spanish, which runs about 25%
  longer. The screenshot tour runs in both languages.
- **Button prompts** show glyphs for the active device.
- **HUD and card look** (v0.3.5 F15, F16; G2 picks pending, defaults ship): the HUD is calm, plain type, thin
  bars, one hairline per group, no glow, echo or glitch (`HudStyle`, one constant: `DEFAULT`); every card (pick,
  item, combo, gamble) is a flat square dark panel with a thin outline, no rounded corners, shadow or coloured side
  bar, with rarity as a small faceted mark (`CardStyle`, one constant: `DEFAULT`). Since v0.5.5 A4 the **pick
  cards** (altar, chest, shop stock) wear the owner's crystal frames instead (`CrystalCard`, `CardFrames`: the
  frame colour is the card's family, epic and cursed offers override it; rarity reads as the rarity line, the gem
  and a glow; text steps down in size so it never overflows the panel, checked in en and es by
  `test_card_frames.gd`); the item, combo, gamble and event cards keep `CardStyle` until the A5 pick. Overclock heat is a thin straight
  bar whose ticks come from the sim's heat table (F2). The minimap is oriented like the screen: up, left and right on
  the map are up, left and right through the iso camera (`MinimapView.turn`, checked against `IsoRig`'s projection
  in `test_minimap_orientation.gd`, F14).
- **v0.5.5 A5 restyle (owner pick, 2026-10-08):** the in-game HUD is **B "Ember stone"** (`HudStyle.DEFAULT =
  EMBER`): chipped dark stone slabs (`HudStyle.draw_plate`), a warm ember line and glow under the HP, top, heat and
  boss slabs, warm type, a red HUD HP bar, danger marks drawn as ember teeth. The heat meter keeps its straight bar,
  ticks and `HeatLooks` colours, set in a slab. The **corner minimap has no background** (owner: "we should remove
  the black background"): it floats over the game, every line over a dark halo, every room over a faint dark wash,
  four ember corner ticks mark its window (`MinimapStyle.CORNER_PANEL = false`); the held full map keeps its panel.
  Every full-screen menu (main menu, pause, Options, credits, the run recap and death screen, the build picker's Back)
  is **C "Cold glass"** (`MenuStyle`, one Theme set on each menu root): the game blurred and dimmed behind
  (`MenuBackdrop`, a screen-texture shader), a left-aligned title and list, plain type, the focused row lit by a
  thin cold-glass wash and hairline with a glass diamond beside it, small notes and key hints under the list; **no
  build cards beside the menu** (owner: not needed). The pick cards keep `CrystalCard`.
- **v0.8.0 MU restyle (owner O14 "we're just throwing away the shard cards"; G2 pick "menu style B", 2026-10-14;
  [`../roadmap/v0.8.0/evidence/MENU_G2.md`](../roadmap/v0.8.0/evidence/MENU_G2.md)):** the cards and the menus are
  **"Ember stone"**, drawn in code. One style box, `StoneBox` (`src/presentation/theme/`, tokens in `EmberStone`):
  a dark carved slab with chipped edges, the ember glow under it (`under`, `focus`), a grain, cracks, a warm lower
  bevel, and optional inlays (a glowing groove line, a ring round a socket, a gold rim). Every **pick card** (altar,
  chest, shop stock, the Swap's card, the Codex's card) is a `StoneCard` (replaces `CrystalCard`): the icon in an
  `InlaySocket` ringed in the element's colour, the title in the family's colour (`CardFrames`, now a colour table
  only) over a groove, the sentence, the carved rarity gem (`CardMark`) over the rarity words, a gold rim when epic or
  legendary, the level badge top right; text steps down (`TextFit`) and a sentence too long at the smallest size
  reflows the card (a smaller socket), so it never runs into the gem (`test_card_frames.gd`, en and es, every scale).
  The **plaques** (`PlaqueBox`: item, combo, gamble, event, ascension, shop, banner) are stone slabs with a groove in
  their colour; the **wand tiles** (`WandRow`), **pips** (`BuildHud`), **Codex tiles**, **achievement rows** and
  **toast**, the **Swap** tiles and the **build picker** (stone tablets with the weapon's symbol in a socket, a stone
  title plaque) share it. **Every menu** (`MenuStyle`; main menu, pause, Options, credits, Codex, Build page, run
  recap, build picker) puts its list on a slab, the focused or pressed row an ember-lit slab with a groove and an
  ember diamond beside it (`EmberMarker`; a hovered row half lit), warm type; behind it `MenuBackdrop`: the game
  blurred into a warm dark with a low ember glow, or with nothing behind (the main menu, `own_scene`) its own
  ember-lit stone floor; sparks drift up from below; **reduced motion stops its clock** (no sparks moving, no
  flicker). The ember `#EBAE72` is kept apart from the Hot heat colour by saturation (`test_ember_stone.gd`). The
  owner's crystal frames, plaques and build-picker art are retired (assets, manifests, crop scripts removed).
- **The Codex** (v0.7.5 CX, owner N6; Ember stone since v0.8.0 MU): `CodexView`, a full-screen menu from the main menu (a row after
  Credits) and the pause menu (a row after Options). Four pages (Cards by pool, Enemies, Bosses, Biomes) of
  `CodexTile`s, and the focused entry beside them: a card as its stone tablet (`StoneCard`, its family's colour) or
  an emblem (`CodexGlyphs`: an enemy by its behaviour, a boss by its id, a biome as a landscape in its palette), the
  game's own name and sentence keys, and the profile's counts. An entry not met is a dark silhouette named "???".
  Keyboard arrows / Q E / Esc, pad d-pad / LB RB / B, mouse hover, tab click and Back. It reads `CodexCatalog` and
  `CodexStore` only; it fits the 1920×1080 base in en and es (`test_codex_view.gd`). It was built straight in the
  owner's Cold glass look without a G2 round (v0.7.5: the owner asked for no interventions); the owner corrects it
  at the playtest.
- **The achievements** (v0.7.5 AC, owner N7): a fifth Codex page, **Achievements** (`AchievementsPage` in
  `CodexView`, after Biomes; Q E / LB RB, the tab by mouse), the achievements in their groups, two
  `AchievementRow`s a line: a code-drawn glyph (`AchievementGlyphs`), the name, the sentence and the state. An
  unlocked one is lit in gold with "Unlocked"; a **locked one is dimmed but keeps its name, its sentence and its
  progress** ("2 / 5"), so the page says what to aim for; a **hidden** one (today the two Ascension ones) is "???"
  with the hidden line until it unlocks. The unlock **toast** (`AchievementToast`) is a small Ember-stone slab under
  the corner minimap (top 404, right 28 at the 1920×1080 base): "ACHIEVEMENT UNLOCKED", the glyph, the name and the
  sentence, 4 s with a short slide and fade, more unlocks queued; it ignores the mouse and the focus (never
  blocks), lives on the UI layer outside the HUD so it outlives a floor change, and reads its clock from the frame
  (a look, never an outcome). Both fit the 1920×1080 base in en and es for every achievement
  (`test_achievements_view.gd`). Built straight in the owner's looks without a G2 round (v0.7.5: no
  interventions); the owner corrects it at the playtest.
- **Card levels** (v0.7.5 SM, owner N8): a card that levels (a wand card, 1–5, and an ability card) wears a small
  badge (v0.8.0 MU: top right on the stone tablet) on every pick card (`StoneCard` via `PickPanel.card_face`, so the altar
  and chest pick, the shop's stock, the event panel and the Swap): "Lv 1" when not held, "Lv N → N+1" when taking it
  levels a held card, and on the boss's legendary altar "Lv N → 5" (its level-5 version; "Lv 5" when not held). The
  rarity line is unchanged. The HUD's wand pips (`BuildHud`) and the Build page's tiles (`WandRow`) show a wand
  card's level as they show an ability modifier's. The badge fits on the card at the pick's and the shop's scales
  in en and es (`test_card_level_views.gd`).
- **First-run hints** (v0.7.5 SM, owner N8): `OnboardingHints`, one small Ember-stone slab with a cold top line at
  the top centre (top 150 at the 1920×1080 base, 720 wide, "TIP" and one line); while a centre panel is open (a pick, the
  Swap, the shop, an event) it sits low instead (its bottom 82 px above the screen's, between the panel's key line and
  the heat meter), so it never covers the panel's title or cards. Each hint shows once
  (`HintStore`, the profile's `hints` section): move and aim, attack, dash at a first run's start (each closes when
  you do it); vent when the heat first reads Hot; the first card pick (the wand reads left to right); the Build page
  (pause → Build) after the first card joins the wand; the first trigger card; the first shop; the first open
  portal; the Codex (pause → Codex) at the second floor's start. A hint about a moment (pick, shop, portal, vent)
  comes before a waiting first-run step; a hint stays at least 2 s and at most 9 s, fades in and out (no slide), and
  waits under the pause menu, Options, the Build page, the Codex and the run recap. Its clock is the frame's (a look,
  never an outcome); it reads `WorldReader` only. Built straight in the HUD's look without a G2 round (v0.7.5: no
  interventions); the owner corrects it at the playtest.
- **New screens go through gate G2** (2–3 mockups, the owner picks; see
  [`../process/OWNER_GATES.md`](../process/OWNER_GATES.md) §3).
  - **Exemption:** v0.0.1's functional stubs (main menu, pause, options stub, credits, dev panel) use the default
    theme and skip G2.
  - Each stub goes through G2 when it is designed for real: Options in v0.1.0, the HUD and menus in v0.3.0.

## 10. Screenshot tour

- `scripts/shots/tour.gd` is committed. It boots the game with a fixed seed, walks through every screen and a
  scripted combat moment, and saves PNGs to `build/shots/<version>/<lang>/` (gitignored).
- **It needs a real renderer:** `--headless` uses a dummy renderer that draws nothing. Run it like this:
  - **In CI** (ubuntu), under `xvfb-run` with Mesa's software Vulkan (lavapipe) for Forward+, or llvmpipe OpenGL for
    Compatibility. v0.0.1 Step 7 proves which works and records it. The PNGs are uploaded as a CI artifact.
  - **Locally,** on any machine with a GPU: `godot --path . -s scripts/shots/tour.gd`.
- **PNGs the owner decides on** (gallery picks, G2 mockups) are committed under the version's `evidence/shots/`,
  because they are decision records. Full tours stay as CI artifacts.
- G2 mockups use the same harness (`scripts/shots/mock_<screen>.gd`).
- Deathventory's `.shots/` scripts were never committed, so every UI pass rebuilt them from scratch
  ([`../LESSONS.md`](../LESSONS.md) L12).
- Each release's evidence links the tour output it was checked against.

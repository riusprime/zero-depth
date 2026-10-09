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

**Palette test** (`tests/unit/presentation/test_palette_contrast.gd`). For each colour-blind mode, it simulates
the mode's colour vision on the tokens and asserts:
- the player, enemy, hostile-projectile and telegraph tokens stay pairwise distinguishable (a minimum
  colour-difference threshold, **starting value** ΔE ≥ 20);
- every biome's `outline` keeps a contrast of at least 3:1 against that biome's `ground`.

## 9. UI

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

# v0.6.1 SW: shard-look audit of the world pieces (R3, gate G1)

Owner line R3 (2026-10-09): "we'd have to also modify some renders in game to match the more shard like style like
altars or other elements". This is the G1 list: every world piece the player interacts with or that marks a place,
how it is drawn now, whether it fits the shard style, and the change proposed. The owner approves, edits or cuts each
row. Rows marked **applied** were built in step SW (the altars, named by the owner, and three small code-built
pieces); every other row was **awaiting owner**.

**Owner answer (2026-10-09, PLAN A1):** "the shop terminal is fine, the portals could have some of them around
matching the color of the portal". So W10/W11 got shard clusters in the portal's own colour (step SW2, evidence
[`SHARD_WORLD_2.md`](SHARD_WORLD_2.md)); the shop terminal (W8) and every other awaiting row stay as they are
(**kept, owner A1**). A2 ("no"): the epic altar stays violet.

## The style the pieces are judged against

The owner's own crystal art: [`../../v0.6.0/refs/card_templates_empty.webp`](../../v0.6.0/refs/card_templates_empty.webp),
[`../../v0.6.0/refs/card_style_reference.webp`](../../v0.6.0/refs/card_style_reference.webp) and
[`../refs/plaque_templates_empty.webp`](../refs/plaque_templates_empty.webp). What they share:
- **faceted crystal shards**, long pointed hexagonal/pentagonal prisms, clustered with one tall shard and smaller
  ones leaning out;
- a **dark outline** round every shard (near-black, thick for the art's size);
- **cel facets**: a bright facet next to a darker one on every shard, a bright highlight at the tip;
- an **inner glow** in the shard's colour (and a soft halo behind the brightest frames);
- small **floating fragments** (diamond chips) beside the clusters;
- one **family colour** per piece (the 12 card-frame colours, `CardFrames.TINT`);
- dark stone or a dark panel under/behind the crystals.

The game's look (v0.5.9 "Embers": the owner's kit, lighting moods, contact shadows) stays as it is. The VFX audit's
rule applies ([`../../v0.6.0/evidence/VFX_AUDIT.md`](../../v0.6.0/evidence/VFX_AUDIT.md), ART_DIRECTION §4): solid
pieces are **lit by the scene**; only light (a glow, a flash) is additive; no flat unshaded fills.

## The shard builder (applied)

`src/presentation/world_view/shard_mesh.gd` (`ShardMesh`), one file so every piece and step SD's dressing share it:
- `crystal()`: a jagged faceted shard (base narrower than the shoulder, a pointed tip, radii and apex jittered from a
  salt; deterministic), flat-shaded, each facet painted a tone through its vertex colour (bright / dark bands, the
  tip brightest);
- `crystal_material()`: the colour **lit by the scene** (StandardMaterial3D, per-pixel), facet tones as albedo, a tight
  highlight (`roughness 0.24`), a rim, and a small emission of its own (on from creation; only energies change);
- `outlined()`: the shard plus an inverted-hull shell (the same mesh 14 % larger, back faces only, `#130F1A`
  unshaded): the art's dark outline, thicker than the screen-space INK line (which still draws on top);
- `glow()`: a soft additive radial sprite (billboard) for the inner glow;
- `cluster()`, `fragment()`, `rock()`: a tall shard with smaller ones leaning out (tips kept inside a radius), a
  floating chip, a rough stone base.

## Every world piece

Status: **applied** (built in SW or SW2), **keep** (no change proposed), **kept (owner A1)** (was awaiting owner; the owner kept it as it is).

| # | Piece | File | Drawn now | Fits the shard style? | Proposed change | Status |
|---|---|---|---|---|---|---|
| W1 | Altar (plain) | `world_view/reward_views.gd` (`make_altar`) | Was: flat-colour hex stone plinth, one bipyramid "rune" spinning over it, three orbiting chips, cold light | Partly (a crystal, but a single gem on a pedestal, no outline, flat stone) | Code-built shard altar: two-step stone base on the same 0.62 m footprint, a cluster of 8 outlined faceted shards in the **blue** frame colour `#4FA8F0`, soft additive glow, 4 fragments floating and bobbing; lit by the mood; brighter (emission, glow, light) in reach | **applied** |
| W2 | Altar (epic; the Deep floor's) | same | Was: W1 in violet `#B47CFF` | as W1 | W1 in the **purple** frame colour `#B36BFF` (the Deep gate's violet, PickSlot.EPIC). Note: the card frames give an *epic card* the gold frame; the altar keeps violet so it still matches the Deep gate. Owner may switch it to gold | **applied** (owner A2: stays violet) |
| W3 | Altar (legendary, the boss's) | same | Was: W1 in gold `#FFD84A` | as W1 | W1 in the **gold** frame colour `#F0D85A`, the tall shard a little taller (0.95 m vs 0.85 m) | **applied** |
| W4 | Arena seal on a locked reward | `reward_views.gd` (`_add_seal`) | Amber torus round the foot + two crossed bars, unshaded-emissive | Yes as a warning cue (a ring of light) | Keep (its ring, 0.72–0.8 m, still circles the new base) | keep |
| W5 | Chest | `reward_views.gd` (`_kit_chest`) | **The owner's model** (v0.5.9), red lock glow, lid opens with a flare | It is the owner's art (not shards) | Keep the model. Optional accent: one small outlined red shard (`ShardMesh.fragment`) as the lock instead of the plain bipyramid | kept (owner A1) |
| W6 | Chest price tag gem | `reward_views.gd` (`_finish_chest`), `ShardViews.shared_material` | Unshaded violet bipyramid next to the number | UI-like (floats with the label) | Keep unshaded (it reads as an icon) | keep |
| W7 | Reward pedestals (item pickups) | `world_view/pickup_views.gd` | 8-sided grey cylinder, a **cube** gem in the item colour turning over it, a light | **No** (a cube on a cylinder; the plainest piece left) | Code-built: `ShardMesh.rock` base + one outlined shard in the item colour floating and turning, 2 fragments, glow. Small, same pattern as W1 | kept (owner A1) |
| W8 | Shop terminal | `world_view/shop_terminal_view.gd` | Code-built vending console (metal boxes, violet screen, gem) | **No** (a machine; the screen was the brightest object, V46) | Model request (it carries a screen and a slot: better as art). Prompt P1 below. Until then keep | kept (owner A1: "the shop terminal is fine") |
| W9 | Event pedestals | `world_view/event_pedestal_views.gd` | Stepped stone base, slanted lectern, violet glyph bipyramid + 2 chips, light | Partly (a crystal over a lectern) | Code-built: keep base and lectern, glyph → outlined shard cluster (`ShardMesh.cluster`, 3 shards) in its state colour (ready violet / fight red / guard cyan / spent dark) | kept (owner A1) |
| W10 | Portal (normal) | `world_view/portal_gate.gd` | Stacked-stone pillars and lintel round a visor-blue swirl | Partly (the stone is flat colour, V43) | Code-built: crystal shards growing from the pillars' feet and the lintel in the swirl's blue (2 clusters + fragments). Or a model: prompt P2 | **applied in SW2** (owner A1: code-built clusters at both pillars' feet and on the lintel's ends + 4 fragments, in the portal's own colour) |
| W11 | Portal (Deep) | same (`set_deep`) | W10 in violet with red frame strips | as W10 | As W10 in violet shards with red tips | **applied in SW2** (owner A1: "matching the color of the portal": violet `DEEP_VIOLET` shards, no red tips) |
| W12 | Boss-room door / seal | `world_view/boss_door_view.gd` | Stone slab between jambs, red disc seal and studs on both faces; sinks into the floor | Partly (seal is a disc) | Code-built: the red seal disc → a ring of outlined red shards round a central shard on each face; jambs keep stone. Or a model: prompt P3 | kept (owner A1) |
| W13 | Arena doorway frames | `world_view/arena_views.gd` (`_frame`) | Amber emissive box frames (jambs + lintel) | No (flat boxes) | Code-built: a small amber shard cluster at each jamb's foot; the lintel stays a bar of light | kept (owner A1) |
| W14 | Arena door barriers | `arena_views.gd` (`_build_barriers`) | Amber / red emissive box filling the doorway while sealed | It is a wall of light (a warning) | Keep the sim-sized box (it shows the real barrier); optional: additive with vertical crystal streaks | kept (owner A1) |
| W15 | Heal orbs | `world_view/heal_orb_views.gd` | Was: unshaded green sphere, pulsing | No (a ball) | Outlined faceted green shard, lit + emission 1.4, turning slowly in a soft additive green glow; same colour, height (0.45 m) and pulse | **applied** |
| W16 | Shard pickups (gems flying to the hero) | `world_view/shard_views.gd` | Was: unshaded violet bipyramids | Partly (crystals without outline, unshaded) | Outlined faceted violet shards, lit + emission 1.6; same burst and flight | **applied** |
| W17 | Core crystals over elites/bosses (Core theft) | `world_view/core_views.gd` (`_make_gem`) | Emissive bipyramid in the card's family colour, light, flares when staggered | Partly (no outline) | Code-built: `ShardMesh.outlined` shard + 2 fragments, same colour and flare. Small; left for the owner's pick because the core sits over enemy models (readability) | kept (owner A1) |
| W18 | Dropped core (a stolen core / Marked's card) | `reward_views.gd` (`make_drop`) | Was: emissive bipyramid floating over a ring | Partly | Outlined faceted shard in the card colour (lit, emission 1.1) with 2 bobbing chips and a soft glow; the floor ring kept. Floats at 1.0 m (it used to be built at 0.9 and lifted to 1.25 by the shared bob) | **applied** |
| W19 | Gamble shrine | `world_view/gamble_shrine_view.gd` | **The owner's model** (v0.6.0 SR), magenta crystal light, orbiting shards | The owner's art | Keep | keep |
| W20 | Overrun doorways | `world_view/overrun_door_views.gd` | Red emissive jambs, lintel and floor strip | No (flat boxes), but a warning | As W13 in red | kept (owner A1) |

## Model requests (prompts in the shared style)

For the rows where a model is better than code (the owner's kit flow: image → AI 3D generator → `.glb` in
`unprocessed_images/kit/`, prepared by `scripts/assets/kit_prep.py`). Shared style block for every prompt:

> Style: low-poly stylised game asset, faceted crystal shards with thick dark outlines and cel-shaded facets (one
> bright facet beside a dark one, a bright highlight at each tip), a soft inner glow in the crystal colour, a few
> small diamond fragments floating beside the clusters, set on dark weathered stone/concrete with soot and rust like
> a ruined city. Matches a dark isometric action roguelike lit by fire. Single object, centred, neutral background,
> no text, no characters. 3/4 isometric view from above.

- **P1 — Shop terminal** (W8; ~1.6 × 0.9 × 1.8 m, front = the screen): "An old vending console of dark weathered
  metal and concrete, a slanted cracked screen glowing soft violet (#B48CFF), a coin slot strip, two side posts each
  topped with a small violet crystal shard, and a cluster of violet crystal shards breaking out of its top and one
  side." + the style block.
- **P2 — Portal gate** (W10/W11; opening 2.4 × 3.2 m, pillars ~0.8 m wide): "A ruined stone doorway: two pillars of
  stacked broken stone blocks under a heavy lintel, clusters of light-blue (#2BC4E2) crystal shards growing from the
  pillars' feet and along the lintel; the opening left empty (the swirl is drawn by the game)." Deep variant: "the
  same doorway with violet (#8B3DFF) shards tipped red (#FF2A3D)". + the style block.
- **P3 — Boss door** (W12; gap width per floor, slab ~0.4 m thick, jambs ~3 m tall): "A heavy stone slab door
  between two dark stone jambs under a lintel; on its face a seal made of a ring of red (#E2321F) crystal shards round
  one central shard, glowing." Separate pieces: the slab (it sinks into the floor in game), the jambs and lintel. +
  the style block.

## Screenshots

`scripts/shots/shard_world.gd` (committed) boots the real game and walks to the nearest altar. Its runs and results
are in [`SHARD_WORLD.md`](SHARD_WORLD.md).

## Open questions for the owner (G1)

Answered 2026-10-09 (PLAN "Owner answers" A1, A2): questions 1 and 3 by A1 (portals: code-built clusters in their
colour; the shop terminal and the other rows kept), question 2 by A2 (the epic altar stays violet). The original
questions, for the record:

1. Approve, edit or cut each **awaiting owner** row (W5, W7–W14, W17, W20), and the **applied** ones (W1–W3, W15,
   W16, W18).
2. The epic altar (W2): keep the Deep gate's violet, or the epic cards' gold (then the legendary altar would need
   another colour or more brightness)?
3. Code-built or a model for W8 (shop), W10/W11 (portals), W12 (boss door)? The prompts above are ready.

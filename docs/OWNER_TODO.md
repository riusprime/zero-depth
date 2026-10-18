# What the lead needs from Rius (the owner's to-do list)

Only what is **still open**: tests, decisions and art. Anything you answered or delivered is gone from here; your
answers live in [`roadmap/v0.8.0/PLAN.md`](roadmap/v0.8.0/PLAN.md) (owner lines O39–O50 and "Owner decisions"). Last
rewritten 2026-10-16 from your annotated copy, v0.8.0 (branch `claude/lucid-fermat-9wv2tf`).

**How to deliver art:** drop the `.glb` (with its textures) or `.png` into `unprocessed_images/` (or the repo root),
named by the **id** below, and say so in chat. The lead installs, sizes, lists and tests it. Every item has a
code-made stand-in until yours arrives, so nothing blocks the game.

Priority: **P1** changes the game most · **P2** worth doing soon · **P3** nice to have.

---

## 1. Playtest: what you haven't tried yet

Get it: `git fetch origin && git switch claude/lucid-fermat-9wv2tf && git pull`, open in Godot 4.7.2, Play.
Shortcut to every fight: Main menu → **F10** → **Playground** (top bar) → **F1**. Every number: **F10**.

- [ ] **Void's black holes:** do they feel good, is the pull strong enough? (decides D20)
- [ ] **Loop 2 and later:** hard without one-shotting you? Is loop 2 through the Purple Portal about 10 % easier?
  (decides D22)
- [ ] **Enemies chasing:** do they now follow you round walls and through doors? Does the Warden's red circle and
  overhead slam read?
- [ ] **Faster bosses:** are the Warlord's javelins, the leaps and the slams dashable after the warning? Is the
  pause after big attacks long enough to hit back with the Blade?
- [ ] **Rarity:** do the tier colours read on cards, the shop and the boss reward? (D31)
- [ ] **Your textures and VFX,** once installed (the next push): does each look right where it is used? Anything to
  redo?
- [ ] **Windows export,** on the next builds (you confirmed this one works).
- [ ] After the next build (Ring as a travelling shot, the longer final boss, loading screens): the same checks again.

**What I hope to get back:** the same as before: per boss too easy / right / too hard and how long it took; fps
with your biggest builds; bugs (what you did, saw, expected; a screenshot); anything you'd cut.

---

## 2. Decisions still open

| # | Question | Today (the lead's default) | Where |
|---|---|---|---|
| D13 | Add the map sub-streams `map:ice`, `map:starglow`, `map:overrun`, the shrine's `map:shrine` and `loot:shrine:<use>` (N14), the curse room's `map:curse_room` (N17) (and Ring/Swirl's stream, if it stays after the Ring change) to the engineering rule's locked list? A bookkeeping call: nothing in play changes | kept, unlisted | LOCKED_DECISIONS EI-05 |
| D20 | Void's black holes: 8 % a shot +3 % a level (20 % at 5), 2 s, at most 3, pull 3.5 m, every 0.2 s 30 % of the shot's damage. OK? (after you try it) | as built | VOID_AND_PORTALS.md |
| D22 | The Purple Portal 10 % ease on loop 2 **and every later loop**, or loop 2 only? (after you try it) | loop 2 and later | BIOME_PERF_AND_LIGHT.md |
| D23 | **Utility cards:** 22 mechanic cards; mark each row Yes / No / Change. Nothing on that list is built until you do | — | [`UTILITY_CARDS.md`](roadmap/v0.8.0/UTILITY_CARDS.md) |
| D28 | Which other cards should care about order (like Ring, Spread, Halo, Swirl)? Twin, Boomerang, Orbit, Spiral, Homing are order-free today | as built | ATTACK_ORDER.md |
| D31 | Rare cards are **blue** (were amber, too close to Legendary gold); every card says its tier in words. OK? | blue | RARITY.md |
| D32 | A boss's stolen **core** gives only legendary stat cards (no ×2 triggers), so every Legendary card goes through the odds. OK, or let cores give Legendary cards too? | stats only | RARITY.md |
| D33 | Split, Twin, Blade Storm and Riposte Chain are **Epic** (rarer than common). Other picks? | as built | RARITY.md |
| D34 | Chain Blast's blasts never merge (the old rule), so a Chain Blast + Split + Spread build may lag like before the performance fix (not measured yet; the lead measures it next) | as built | RARITY.md |
| D35 | How fast loops pile up Legendaries: each loop +5 % chance at a boss altar and one more pick, up to 4 | as built | RARITY.md |
| D38 | **(Later, you said: noted for the future)** **Bosses get easy if you farm a floor** (O40). Pick how the boss keeps up: **(a)** it scales with your power when you reach it (your damage per second and HP, read when the fight starts), **(b)** it scales with the time you spent on the floor, **(c)** the floor pushes you on (enemies get harder the longer you stay). The lead recommends **(a)**: the fight stays hard however you got strong, and it's the same rule that gives the final boss its 1–2 minute phases (O41) | (a), once you pick | PLAN O40, O41 |
| D43 | **Three calls from N1** (after you try it): **(1)** the Blade's hit-stop is ~20 % longer as you asked, but the sim's freeze stops the whole world, so the Blade now kills about 14 % slower in seconds (enemies freeze too, so a fight is no harder): keep it, or give the Blade back some damage? **(2)** Enemy role colours now glow a little of their own colour (0.45): red, orange and yellow measure well apart in every biome, but in Frozen Shore the Warden's bronze and the Splitling's orange are still the closest pair, and in Starfall the orange and yellow came a bit closer than before (still apart): enough, or stronger? **(3)** A Legendary card that has an element (Inferno Core, Tempest Core, Chain Blast) shows the star burst, not its element's glyph (its ring keeps the element's colour): OK, or the element first? | keep (1); 0.45 (2); star first (3) | [`N1_FIXES.md`](roadmap/v0.8.0/evidence/N1_FIXES.md) |
| D41 | Textures (TX2): the Warden's slam dust ring is now your `fx_dust_ring` (beige dust and stones); on the pale Playground sand it reads fainter than the old near-white band. Keep yours, go back to the white band, or a whiter dust ring render? | yours | TEXTURES_2.md; `tx_shots/tx2_warden_slam_dust.jpg` |
| D45 | **Three calls from N3** (after you try it): **(1)** the Ring is now the shot (a flying ring) and retuned: alone it is ~1.9× the plain shot on a crowd and ~1.1× on one target, but Ring · Spread and Swirl · Ring · Spread are ~1.5× the other two-card builds on a tight crowd (about equal on one target): OK, or lower them further? **(2)** The storm (Ring · Spread · Swirl) and Ring · Halo fire all round you, so they are the weakest orders on a crowd in front of you: OK as the horde orders, or should the storm's rings bend toward enemies? **(3)** Swirl's random stream `wand:swirl` stays (the storm and a swirled bolt); list it under D13? | as built (1, 2); yes (3) | [`N3_RING_AND_LOADING.md`](roadmap/v0.8.0/evidence/N3_RING_AND_LOADING.md) |
| D46 | **The intensity director (N5), after you try it:** **(1)** quiet stops new enemies, so a hero who kills as fast as they come (the alive count sits at the cap today) kills fewer: on 5 seeds × 5 min a scripted Blade killed **21 % fewer a minute** (target was within 20 %), even with the build-up sending packs 2.5× as often. Accept the dip (the quiet is the point), or let the peak bring more at once (that raises the cap, so it changes "how hard", not only "when")? **(2)** With that hero every quiet ran its full 20 s: enemies left over from the peak keep hitting you, so intensity never falls; quiet only ends sooner when you clear them. OK, or should quiet end on time alone (10–20 s drawn), whatever is left? | accept (1); as built (2) | [`INTENSITY_DIRECTOR.md`](roadmap/v0.8.0/evidence/INTENSITY_DIRECTOR.md) |
| D44 | **The final boss's pace and The Fallen (N2, O41/O42/O52), after you try it:** each body lasts 120 s × √(30 / your dps), never under 60 s nor over 180 s, and can't take more than a minute's share of its HP a second. The Fallen copies you in a 7 s window every 20 s (first at 12 s, warned 1.5 s ahead) and, in it, pulls your damage on it to the base hero's level (at least 10 %) and your move speed to the base; its hits 22 / 30 / 34 / 50 % of your HP. Against our scripted absurd builds The Fallen took 86–110 s (the windows slow strong builds most; the Colossus and the Prism about 61–76 s). OK, or shorter/longer windows, a softer pull, a different 60 s floor? | as built | [FINAL_BOSS_N2.md](roadmap/v0.8.0/evidence/FINAL_BOSS_N2.md) |
| D47 | **Health bars (N4, O56/O57/O59), after you try them:** **(1)** no boss has a shield you break with hits, and the game keeps no shield count, so "shields left" counts what the bar can honestly read: the phase gates still to come (each an invulnerable transition; on the final boss only the current body's own gates, so nothing gives away the bodies to come). Keep that, or should a real breakable shield (N hits / N pillars to break) be designed? **(2)** the bar goes blue and says "Invulnerable" whenever no hit can land: shielded patterns, phase gates, the final shatter, but also the boss's rise and brief leaps / burrows / The Fallen's dashes; the final boss's rate cap (hits landing for 0 once its bucket empties) is **not** shown. OK? **(3)** floor bosses still say "Phase 2 / 3" under the bar (O59 covered only the final boss): keep, or hide too? **(4)** timings: hold 0.5 s, drain 0.4 s, refill 0.8 s, a hit of 8 % of the bar or more lights the chunk brighter. | as built (gates as shields; blue on every invulnerable tick; floor bosses keep "Phase 2 / 3") | [HEALTH_BARS.md](roadmap/v0.8.0/evidence/HEALTH_BARS.md) |
| D49 | **Chests that deal one card (N7, O61/D48), two calls:** **(1)** a **cursed chest** used to put a trade-off curse among its three cards; with one card it would force the curse on you, and threat must rise only by your choice. Built: a cursed chest still asks, **its curse card or its one card** (the only chest that asks). Keep that, or move the cursed offer to altars, or let a cursed chest force its curse? **(2)** One card per chest lowers the broken-build odds (RR's band, 7–10 % of runs by the end of loop 1): **Blade 6.1 → 4.4 %, Gun 9.4 → 5.5 %** ([RARITY N7](roadmap/v0.8.0/evidence/RARITY.md#v080-n7-a-chest-deals-one-card-re-run-2026-10-17)). Not retuned: raise the boss's Legendary chance (now 12.5 % on loop 1), the chests' Epic/Legendary weights, or accept the lower odds? |

| D52 | **The arrival (N11, O69), after you try it:** **(1)** lengths: floor 1 of a run 1.6 s, later floors 0.8 s, reduced motion 0.3 s (data: `data/tuning/sim.tres`); the arrival now starts only once the loading cover or the portal's iris has opened, so from the portal to control is the iris (0.55 s) plus 0.8 s; **(2)** the receiver has no body in the sim: you walk over it (its four arms are short and at the rim); **(3)** reduced motion: the receiver's light flares and fades and the hero appears in it (no true see-through fade of the model); **(4)** the final arena keeps the old light column (no receiver there). OK? | as built | [`ARRIVAL.md`](roadmap/v0.8.0/evidence/ARRIVAL.md) |
| D51 | **Loads (N12, O70), after you try them:** the cover's mark and the portal's iris now keep moving while a floor builds (the floor is built in the background; the longest frame of a load on the test machine went from 1.9-10.6 s to 33-61 ms). One stop may be left: the first frame that draws the new floor, still under the cover, compiles its materials' shaders (1.7-2.2 s on the test machine's CPU renderer; a real GPU is much faster, unmeasured). **(1)** On your PC, does the cover still stop for a moment before it opens (on the first run more than later)? If yes, a shader warm-up behind the first black cover is the next step (it would make the first load a little longer). **(2)** The first load of a session reads the models and takes ~11 s behind the black cover here (later loads 2-4 s): OK, or should the game read them at boot, behind the menu? | as built | [LOADS_NO_FREEZE.md](roadmap/v0.8.0/evidence/LOADS_NO_FREEZE.md) |
| D54 | **The rarer shrine (N14, O72), after you try it:** **(1)** starting values: a shrine on 40 % of floors, at most 3 stats a shrine, 30 % of paid uses fail (all in `data/gamble/shrine.tres`); the price steps up after every paid try, a miss too. OK? **(2)** It stands in a combat room away from the start hall (never the boss room, the shop's, the Overrun room or a sealed arena), so you may have to fight your way to it, and it isn't shown until you find its room. OK, or should the minimap show it from the start? **(3)** Each try's success is fixed by the floor (reloading a save gives the same result). OK? **(4)** A run saved before this change keeps its floor's shrine in the start hall, its earlier wins counted toward the 3. | as built | [PROGRESS](roadmap/v0.8.0/PROGRESS.md) N14 |
| D56 | **Calmer walls (N15, O73), after you look:** Night Rocks and Starfall (and, lighter, Frozen Shore) now draw their wall textures softer and flatter (fine detail and contrast toned down, bigger tiles), with bigger top stones, fewer missing or recessed blocks, a bigger, flatter rubble fill and steadier shading; the walls' shape and pillars are the same. Measured at the game's camera: 33-41 % less busy; Ruins and Red Canyon unchanged. **(1)** Calm enough, too flat, or still busy (per biome)? Every value is in the biome's data and on the dev panel's lighting page (`wall_detail`, `wall_face_contrast`, `wall_top_contrast`, `wall_stone_scale`, `wall_breakage`, …). **(2)** Should Ruins get a lighter pass too (it measures between Frozen Shore and Red Canyon)? The old/B wall toggle is gone (D53) | as built | [CALMER_WALLS.md](roadmap/v0.8.0/evidence/CALMER_WALLS.md); `n15_shots/` |
| D58 | **Your v0.8.0 models (MI, O77-O81), after you look:** **(1)** caps a floor, so a landmark never repeats: the observatory 1 (yours), the stone arch 2, the wagon and the boat wreck 3 each, the building corner 4: OK, or other numbers (or caps on more pieces)? **(2)** Your `ice_floe.glb` is a frozen boat half sunk in snow, so it went in as `boat_wreck` (Frozen Shore's wreck and landmark); the floes on the sea stay code-made: OK, or send the floe? **(3)** Starfall's pools are now cracks your texture shows through, but the speed is still the sim's rectangle: the cracks reach its four sides and a faint wash covers the rest, so the edge of the fast area reads only roughly. OK, a stronger wash, or should the sim's pool take the crack's shape (a sim change)? **(4)** The light props are unchanged: the rusty oil drum and the iron brazier light every biome, and the drum reads as a city prop outside Ruins: give each biome its own light prop (a model for each)? **(5)** Your enemies: no drawn outline (as on your bosses); the Mender's violet plates take its green, the Lens Drone's red ones the palette's violet; the Splitter's arms span 1.7 m (its body in the sim is smaller): OK? **(6)** Shared on purpose: the plain boulder (`rock_large`) in all five biomes, the dead tree in Night Rocks and Frozen Shore: OK? **(7)** The Ascension portal's beam is light violet as you asked: its edge colour is close to the Deep gate's violet (both portals never stand on one floor): OK? | as built | [MODELS_INSTALL.md](roadmap/v0.8.0/evidence/MODELS_INSTALL.md); `mi_shots/` |
| D59 | **The curse room as its own room (N19, O80), after you look:** **(1)** the crystals are code-made (dark violet faceted clusters, some glowing violet or deep red), one look for every biome; your `star_crystal`/ice pieces belong to their biomes' looks, so they aren't used here. OK, or a crystal model of your own? **(2)** The altar is solid now (you walk up to it, not through it) and the crystals are solid too. **(3)** On a Deep floor the altar always holds Whispering Deep, so Unstable Core and Echo Mirror appear only on normal floors. OK? **(4)** Echo Mirror is decided when the floor is built: raising your first stat on a floor makes it possible from the next floor on. **(5)** Which room: rooms holding no altar or chest first, the small (one-cell) ones first among them; only when every allowed room holds one may a chest or altar stand beside the curse altar. OK? | as built | [CURSE_ROOM_2.md](roadmap/v0.8.0/evidence/CURSE_ROOM_2.md); `n19_shots/` |

---

## 3. 3D art: specs and prompts

**Shared rules (every model):** the look of your kit and `docs/art/look_reference.webp`: chunky, chipped, weathered
low-poly; worn metal, concrete and stone; no baked lighting or shadows; no text, letters or logos; one object, no
ground plane; readable from an isometric camera about 35° down. Rigged is always a bonus, never needed: without a rig
the lead animates parts in code.

**Kit prefix** (props, room pieces, devices):
> Low-poly faceted 3D game prop, stylised, chunky and slightly weathered, flat-shaded facets with crisp edges, a
> single object centred on a plain white background, three-quarter view from above, soft even studio light, no
> text, no letters, no numbers, no logo, no ground plane, same style as a modular kit of ruined-city props (concrete
> walls, crate stacks, a car wreck, fire barrels) for a dark isometric action roguelike.

**Character prefix** (enemies, vendors, the hero's weapons when shown on their own):
> Stylised low-poly faceted game character for a dark isometric action roguelike, reference sheet with a 3/4 front
> view and a side view on a plain neutral grey background, chunky readable silhouette, worn scratched charcoal steel
> and stone plates with [COLOUR] faceted armour, a few small glowing accents in the same colour, no baked shadows,
> soft even studio light, no text, no logo, no watermark,

**3D step** (with the image as input):
> Game-ready stylised low-poly 3D model, hard-surface faceted shapes, worn scratched charcoal steel with [COLOUR]
> parts, small emissive accents, clear silhouette from above, baked colour texture with no lighting or shadows baked
> in, single object, no base, no background,

**Negative prompt** (if the tool has one):
> text, letters, logo, watermark, background scenery, ground, base, pedestal, baked shadows, strong rim light,
> smooth organic skin, realistic photo, clean plastic look, many tiny details

### 3.0 Delivered 2026-10-18 (installed in v0.8.0 MI)
Your 34 models and the ground_star texture: each prepared offline (sized, simplified to a triangle budget, re-textured)
by `scripts/assets/mi_prep.py`, listed in `assets/models/manifest.json`, and placed only in the biome it fits (your
O78). The numbers and the shots: [`roadmap/v0.8.0/evidence/MODELS_INSTALL.md`](roadmap/v0.8.0/evidence/MODELS_INSTALL.md).

| ✓ | id | Where it went |
|---|---|---|
| ☑ 2026-10-18 | `building_corner` | Ruins: a designed room's landmark and its big blocks (at most 4 a floor) |
| ☑ 2026-10-18 | `ladder_frame` | Ruins: stands against a wall, in a niche of the wall |
| ☑ 2026-10-18 | `column_broken` | Ruins: square cover and posts |
| ☑ 2026-10-18 | `pipe_bundle` | Ruins: long cover |
| ☑ 2026-10-18 | `barricade` | Ruins: long cover and thin walls |
| ☑ 2026-10-18 | `tire_stack` | Ruins: square cover |
| ☑ 2026-10-18 | `boulder_small` | Night Rocks: floor decoration |
| ☑ 2026-10-18 | `rock_spire` | Night Rocks: square cover and posts |
| ☑ 2026-10-18 | `stone_arch` | Night Rocks: landmark and deep cover (at most 2 a floor) |
| ☑ 2026-10-18 | `mushroom_cluster` | Night Rocks: floor decoration |
| ☑ 2026-10-18 | `bone_pile` | Night Rocks: floor decoration |
| ☑ 2026-10-18 | `floating_island_moss` | Night Rocks: islands drifting in the void past the floor's edge (your O78) |
| ☑ 2026-10-18 | `mesa_chunk` | Red Canyon: square cover, blocks, long cover and walls |
| ☑ 2026-10-18 | `dry_shrub` | Red Canyon: floor decoration |
| ☑ 2026-10-18 | `cactus` | Red Canyon: square cover and posts |
| ☑ 2026-10-18 | `wagon_wreck` | Red Canyon: the wreck slot (the car's) and landmark (at most 3 a floor) |
| ☑ 2026-10-18 | `cattle_skull_post` | Red Canyon: posts, and against a wall in a niche |
| ☑ 2026-10-18 | `snow_drift` | Frozen Shore: floor decoration (replaces the code-made drift) |
| ☑ 2026-10-18 | `ice_shard` | Frozen Shore: floor decoration (replaces the code-made shard) |
| ☑ 2026-10-18 | `ice_rock` | Frozen Shore: square cover, blocks, long cover and walls |
| ☑ 2026-10-18 | `ice_floe` (file) | Your `ice_floe.glb` holds a frozen boat half sunk in snow, so it is installed as **`boat_wreck`**: Frozen Shore's wreck slot and landmark (at most 3 a floor). The floes on the sea stay code-made (see D58) |
| ☑ 2026-10-18 | `fish_rack` | Frozen Shore: against a wall, in a niche (it is 1.6 m tall: rule 1 keeps tall pieces off open floor) |
| ☑ 2026-10-18 | `star_crystal` | Starfall: floor decoration (replaces the code-made crystal) |
| ☑ 2026-10-18 | `meteorite` | Starfall: floor decoration (replaces the code-made one) |
| ☑ 2026-10-18 | `star_monolith` | Starfall: square cover, long cover, walls, posts |
| ☑ 2026-10-18 | `floating_island_starfall` | Starfall: the islands drifting in the starry void |
| ☑ 2026-10-18 | `void_spike` | Starfall: the spikes hanging from the floor's rim |
| ☑ 2026-10-18 | `ruined_observatory` | Starfall: a designed room's landmark and big blocks, **at most 1 a floor** (your O79) |
| ☑ 2026-10-18 | `ground_star` (texture) | Starfall: the starglow pools are now crack shapes your texture shows through |
| ☑ 2026-10-18 | `loop_device` | The Loop device's pad (its green ring, arrows and light stay on top) |
| ☑ 2026-10-18 | `mender` | The Mender (animated in code: float, sway, cross, crystals raised while healing, death) |
| ☑ 2026-10-18 | `shield_bearer` | The Shield Bearer (legs walk, shield raised and held, bash, death) |
| ☑ 2026-10-18 | `splitter` | The Splitter and, smaller, the Splitling (legs, claws raised and held then chop, halves part on death) |
| ☑ 2026-10-18 | `lens_drone` | The Hive Lens's drones (hover, ring of feet spins, eye flares) |
| ☑ 2026-10-18 | `ascension_portal` | The Ascension portal (your dais, pillars and crystals; the violet beam in code, after your reference image) |

### 3.0b Delivered 2026-10-18 (installed in v0.8.0 BD)
Your five boss doors and the door's two sounds (O82, O83). Each door is cut into its frame and its slab by
`scripts/assets/bd_prep.py`, about 18 % bigger than the old code-made door, and shown on its biome's boss room. The
door now opens when you press interact (E / pad X) next to it. Numbers and shots:
[`roadmap/v0.8.0/evidence/BOSS_DOORS.md`](roadmap/v0.8.0/evidence/BOSS_DOORS.md).

| ✓ | id | What |
|---|---|---|
| ☑ 2026-10-18 | `boss_door_ruins` | Ruins: concrete, riveted iron and rebar, a scrap-metal horned crest |
| ☑ 2026-10-18 | `boss_door_night_rocks` | Night Rocks: blue-grey rock, moss, bones and a pale beast skull |
| ☑ 2026-10-18 | `boss_door_red_canyon` | Red Canyon: sandstone strata, rope-bound beams, a cattle skull, the sun on the slab |
| ☑ 2026-10-18 | `boss_door_frozen_shore` | Frozen Shore: ice and snow, icicles, an ice-glazed skull |
| ☑ 2026-10-18 | `boss_door_starfall` | Starfall: violet stone, star specks, crystal clusters |
| ☑ 2026-10-18 | `door_opening` (sound) | Plays at the door when you press to open it (the opening lasts as long as the sound, 2.7 s) |
| ☑ 2026-10-18 | `door_impact` (sound) | Plays when the slab lands. Cut to 2.95 s with a 0.9 s fade (the game's sound effects stop at 3 s; yours rings for about 5.5 s). Tell the lead if you want the whole tail |

- [ ] **Your key:** you wrote "F on keyboard", but F is already Vent, so the door uses the existing interact key, E
  (pad X is the same as you asked). Say if you want something else.

### 3.1 New from your playtest notes (P1)

| ✓ | id | What it is, how it should look | Size (W×D×H m) | Prompt (after the prefix) |
|---|---|---|---|---|
| ☑ | `ascension_portal` | **Delivered 2026-10-18, installed in MI** (7,992 triangles, map 1024; the beam is code: soft violet shafts, a glowing ring, floating crystals, as in your reference image). The way to the final boss (walk in) | 2.4 × 1.0 × 3.6 | — |
| ☐ | `floor_receiver` | Where the hero arrives on every floor (N11). Must read as "you arrive here", clearly not the exit portal: low, round, a ring of standing stones or metal arms around a glowing landing circle, no opening to walk into | 2.2 × 2.2 × 1.2 | [kit prefix] a low round arrival platform, a worn stone disc with a glowing pale-cyan landing circle in its centre, four short curved metal arms rising from its rim and bending inward like a cage opened, cables and runes along the arms, no arch, no doorway |
| ☑ | `curse_altar` | **Delivered 2026-10-18, installed by N17** (decimated to 1,822 triangles, maps 1024). The curse device in its dark curse room (N17). Low, square, heavy and ominous: it should read as "a pact you make here", not a shop or a shrine. Only the stone: the game floats its own cracked violet crystal above it and draws the glowing glyphs around the room | 1.4 × 1.4 × 1.0 | [kit prefix] a squat ancient altar of dark cracked basalt, a square plinth with a sunken basin on top, two short curved horn-like stones rising at its sides, faint violet runes carved into its faces, chains and broken shackles hanging from the corners, black wax drips, no crystal on top, no light source |
| ☐ | `hero_gun` | The hero's Gun, professional-looking (your note: they "need to look professional"). It fires the blue pulse, so blue accents; seen in the hero's hand, small | 0.7 long | [character prefix, steel blue] a chunky sci-fi energy pistol held in one hand, a short thick barrel with a glowing blue core visible through vents, a faceted charcoal steel body, a blue crystal power cell at the back, a worn grip; shown on its own, side view |
| ☐ | `hero_blade` | The hero's Blade, professional-looking. Its slash leaves a blue-white edge, so the edge glows | 1.1 long | [character prefix, steel blue] a single-edged laser sword, a long straight faceted blade of pale blue-white light with a hard bright edge, a chunky charcoal steel hilt with a blue crystal in the guard, a wrapped grip; shown on its own, side view |
| ☐ | `menu_chest` | For the future main-menu scene (the hero opening a chest). A treasure chest that opens: a separate lid (or a rig with an `open` clip) | 1.0 × 0.6 × 0.7 | [kit prefix] a heavy iron-banded treasure chest of dark weathered wood, faceted metal corners, a red crystal lock, glowing red light leaking through the gap under the lid, the lid as a separate object |
| ☐ | (rig) the hero | For the same scene: if your hero model can be rigged with an `open_chest` clip (kneel, lift the lid, look in), the lead builds the menu around it. Otherwise the lead animates the existing hero in code | — | — |

### 3.2 Enemy models (P1)
Three kinds still have the lead's code-made body. Each takes its **role colour** where the prompts say
[COLOUR] (the game fine-tunes the shade). Greys stay neutral, because each biome tints them.

| ✓ | id | Role colour | In-game size | Prompt (after the character prefix, then the 3D step) |
|---|---|---|---|---|
| ☐ | `swarmer` | melee red-orange `#D8562A` | 0.5 m long | a small fast armoured beetle, a low wedge-shaped faceted shell with a ridge down its back, a charcoal head with one glowing slit eye, two pale bone mandibles that open wide, six thin segmented charcoal legs splayed low; about 3k triangles |
| ☐ | `mine_layer` | bomber yellow `#D8A824` | 0.9 m long | a low armoured crawler on two short charcoal tank treads, a faceted hull with chevron plates, a charcoal dome with one glowing eye, an open hopper at the back holding a dark round spiked mine with a small blinking light (the mine as a separate object is a bonus); about 5k triangles |
| ☐ | `sniper` | ranged blue-violet `#5A62D8` | 1.1 m tall | a lean walking gun platform on a tripod of three long thin charcoal legs, a narrow faceted body, a very long charcoal rifle barrel pointing forward, a big round glowing scope lens on top, cooling fins along the barrel; about 5k triangles |

### 3.3 The final boss (P1–P2)

| ✓ | What | Spec | Prompt / note |
|---|---|---|---|
| ☐ | **Re-export your final-boss file with one shared, smaller texture** (P1) | 2048² or 4096², one texture used by all three bodies | Each of the three models now carries its own copy of the same 8192² texture: +56 MB in the repo |
| ☐ | Animated Colossus, Prism and The Fallen (P2) | clips named `idle`, `walk` and the attack names in FINAL_BOSS_1..3.md, in an AnimationPlayer inside the `.glb` | Yours replace the code clips by name |
| ☐ | `arena_wall_segment` (P2) | 8 × 3 × 4; 8 make the ring | [kit prefix] + "cosmic, star-lit, dark violet stone with red crystal veins": a curved section of a tall arena wall, tiered dark stone seating rising in steps, broken in places, red crystal veins, star-lit edges |
| ☐ | `arena_gate` (P2) | 6 × 2 × 6 | [same] a huge arched gate in the same stone, closed by a crystal portcullis |
| ☐ | `arena_pillar` (P2) | 1.2 × 1.2 × 5 | [same] a tall broken column topped by a floating crystal shard |
| ☐ | `arena_brazier` (P2) | 1 × 1 × 1.4 | [same] a stone brazier holding a violet star-fire |
| ☐ | `ground_arena` (P2) | tileable 1024² PNG | worn circular stone paving seen from above, a faint star pattern, dark violet, seamless tile, no text |

### 3.4 The shop (P2: you're not sure yet)

| ✓ | id | Spec | Prompt (after the character prefix, "standing idle, arms at its sides, facing forward") |
|---|---|---|---|
| ☐ | `shop_vendor_ruins` | 1.6 m tall, its face toward glTF +Z, **a separate model from the stall** (so it can move) | a hunched scavenger in a hooded patched coat and goggles, a big backpack of junk and wires |
| ☐ | `shop_vendor_night_rocks` | 1.7 m | a lantern-carrying hermit in a moss-grey cloak, a staff hung with charms |
| ☐ | `shop_vendor_red_canyon` | 1.7 m | a desert trader in wrapped scarves and a wide-brimmed hat, a bandolier of pouches |
| ☐ | `shop_vendor_frozen_shore` | 1.7 m | a fur-wrapped fisher-trader with a hood rimmed in frost, a hook on a pole |
| ☐ | `shop_vendor_starfall` | 1.8 m, floating, no floor base | a floating cloaked astral merchant, a star-map cape, small orbiting crystals |
| ☐ | `shop_wares` | 1.0 × 0.6 × 0.6, +Z toward the player | (kit prefix) a pile of goods for a counter: bottles, a scroll case, glowing crystal shards in a crate, a small chest |
| ☐ | stalls for the other 4 biomes (P3) | must fit 4.0 × 3.4 m, 2.55 m tall; say which way its front faces | (kit prefix) your desert stall's shape, re-dressed: Night Rocks (moss-grey cloth, a hanging lantern on a staff), Red Canyon (sun-bleached cloth, cattle skull), Frozen Shore (furs, nets, frost), Starfall (star-map cloth, floating crystals) |

### 3.5 Boss attack pieces (P2)

| ✓ | id | Size | Prompt (after the kit prefix) |
|---|---|---|---|
| ☐ | `stone_spike` | 0.6 × 0.6 × 1.4 (tall), 3 variants in one file | a sharp faceted stone spike bursting out of cracked ground, grey with a red-hot glowing crack, in three heights (short, mid, tall) side by side |
| ☐ | `javelin` | 2.0 long | the Warlord's leaf-headed crystal javelin, a red faceted crystal tip, a grey worn steel shaft |
| ☐ | `brood_egg` | 0.6 tall | the Brood Mother's leathery green-grey egg with glowing veins, slightly cracked at the top |

### 3.6 Room pieces (P2–P3)
Still to come (the rest of the list arrived 2026-10-18, §3.0). All after the kit prefix.

| Biome | id | Size (W×D×H m) | Prompt |
|---|---|---|---|
| Ruins | `metal_post` | 0.2 × 0.2 × 1.8 | a bent rusty metal post with a snapped bracket at the top |
| Ruins | `dumpster` | 1.8 × 1.0 × 1.2 | a dented rusty dumpster with its lid half open, junk spilling over |
| Ruins | `cable_spool` | 0.9 × 0.9 × 0.7 | a big wooden cable spool lying on its side |
| Ruins | `sign_frame` | 1.2 × 0.2 × 1.6 | a blank fallen billboard frame on two posts, no text |
| Frozen Shore | `ice_floe` | 2 × 1.6 × 0.12 | a flat cracked slab of floating sea ice, seen from above (the file you sent under this name is a frozen boat; it went in as `boat_wreck`) |
| Frozen Shore | `ground_snow` | tileable 1024² PNG | packed snow ground with footprints of wind, seen from above, seamless tile |

### 3.7 Boss animation clips (P3: you're not sure yet)
Any boss: clips named like the code ones (`idle`, `walk`, `marks`, `pattern`, `lanes`, `leap`, `death`…, listed per
boss in [`roadmap/v0.8.0/evidence/BOSS_ANIMATIONS.md`](roadmap/v0.8.0/evidence/BOSS_ANIMATIONS.md)) in an
AnimationPlayer inside the `.glb`; yours replace the code ones.

---

## 4. 2D art and audio still owed

| ✓ | id | What | Prompt |
|---|---|---|---|
| ☐ | `fx_rail_streak` (P2) | The Siege Engine's rail shot (the only texture missing from the zips) | in [`art/requests/v0.8.0_textures.md`](art/requests/v0.8.0_textures.md) |
| ☐ | final-boss music (P3) | A track for the final arena; today it uses the boss sounds | — |

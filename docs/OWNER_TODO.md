# What the lead needs from Rius (the owner's to-do list)

Only what is **still open**: tests, decisions and art. Anything you answered or delivered is gone from here; your
answers live in [`roadmap/v0.8.0/PLAN.md`](roadmap/v0.8.0/PLAN.md) (owner lines O39–O50 and "Owner decisions"). Last
rewritten 2026-10-16 from your annotated copy, v0.8.0 (branch `claude/lucid-fermat-9wv2tf`).

- [ ] **v0.11.0 questions (2026-11-07):** Q1–Q27 in
  [`roadmap/v0.11.0/OWNER_QUESTIONS.md`](roadmap/v0.11.0/OWNER_QUESTIONS.md) (scope, Laser, bosses, hordes, spells,
  enemies, rooms), and the Laser sketch.
- [ ] **The v0.10.5 playtest (2026-11-06):** the build, what to try and the questions are in
  [`roadmap/v0.10.5/PLAYTEST.md`](roadmap/v0.10.5/PLAYTEST.md) (branch `claude/v0100-cleanup`, then its PR into `main`).

**How to deliver art:** drop the `.glb` (with its textures) or `.png` into `unprocessed_images/` (or the repo root),
named by the **id** below, and say so in chat. The lead installs, sizes, lists and tests it. Every item has a
code-made stand-in until yours arrives, so nothing blocks the game.

Priority: **P1** changes the game most · **P2** worth doing soon · **P3** nice to have.

---

## 1. Playtest: what you haven't tried yet

- [ ] **The v0.9.0 playtest (2026-10-24):** the build, what to try and the questions are in
  [`roadmap/v0.9.0/PLAYTEST.md`](roadmap/v0.9.0/PLAYTEST.md) (branch `claude/world-combat-v090`, then its PR into
  `main`). The v0.8.0 items below are older.

Get it: `git fetch origin && git switch claude/lucid-fermat-9wv2tf && git pull`, open in Godot 4.7.2, Play.
Shortcut to every fight: Main menu → **F10** → **Playground** (top bar) → **F1**. Every number: **F10**.

- [ ] **Enemies chasing:** do they now follow you round walls and through doors? Does the Warden's red circle and
  overhead slam read?
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
| D23 | **Utility cards (moved to v0.9.0, O92):** 22 mechanic cards; mark each row Yes / No / Change. Nothing on that list is built until you do | being re-reviewed (v0.10.5 O9) | [`UTILITY_CARDS.md`](roadmap/v0.8.0/UTILITY_CARDS.md) |
| D28 | Which other cards should care about order (like Ring, Spread, Halo, Swirl)? Twin, Boomerang, Orbit, Spiral, Homing are order-free today | as built | ATTACK_ORDER.md |
| D34 | Chain Blast's blasts never merge (the old rule), so a Chain Blast + Split + Spread build may lag like before the performance fix (not measured yet; the lead measures it next) | as built | RARITY.md |
| D44 | **The final boss's pace and The Fallen (N2, O41/O42/O52), after you try it:** each body lasts 120 s × √(30 / your dps), never under 60 s nor over 180 s, and can't take more than a minute's share of its HP a second. The Fallen copies you in a 7 s window every 20 s (first at 12 s, warned 1.5 s ahead) and, in it, pulls your damage on it to the base hero's level (at least 10 %) and your move speed to the base; its hits 22 / 30 / 34 / 50 % of your HP. Against our scripted absurd builds The Fallen took 86–110 s (the windows slow strong builds most; the Colossus and the Prism about 61–76 s). OK, or shorter/longer windows, a softer pull, a different 60 s floor? | as built | [FINAL_BOSS_N2.md](roadmap/v0.8.0/evidence/FINAL_BOSS_N2.md) |
| D61 | **Wand damage rounds down at every card (O86 feedback, Part 1):** each ×‰ card truncates an integer damage, so order and small numbers compound: base 4 with [Big Shot, Rapid Fire] hits 4, with [Rapid Fire, Big Shot] hits 3 (real product 4.48), while the bolt *looks* 1.12× heavier. Keep it (deterministic, order matters on purpose), or round to nearest / keep damage in fixed-point until the hit? Nothing changed until you say | as built | [feedback](roadmap/v0.8.0/feedback/2026-10-19_perf_and_wand_math.md) |
| D64 | **Balance pass (O91), stats: the other compounding stats.** You asked for damage and attack speed to add instead of compound; max HP, area, move speed, shard gain and pickup range still compound (five +15 % max HP cards = ×2.01). Make them add too (simpler cards: each shows its real gain), or keep them compounding? | unchanged until you say | [BALANCE_PASS](roadmap/v0.8.0/BALANCE_PASS.md) SG |
| D68 | **Balance pass, new cards:** **(1)** Dodge Imprint stays a Blade card (it reworks the Blade's Afterimage), or shared? **(2)** Thermal Break (burning + chilled/frozen): one hit of 6 + 4 per burn stack, both statuses consumed. **(3)** Mutations (Double Exposure, Grand Finale) are a category of their own: exceptionally rare on floor 1 (weight ×0.02, or a Jackpot), ×0.1 / ×0.3 / ×0.6 on floor 2 / floor 3 / Deep and loops. OK? The other proposed cards wait until this batch is validated | as built | [BALANCE_PASS](roadmap/v0.8.0/BALANCE_PASS.md) RM |
| D70 | **The balance pass measured (BV), three targets missed, nothing retuned:** in 100 seeded runs per weapon (scripted picks, [BALANCE_BV](roadmap/v0.8.0/evidence/BALANCE_BV.md)), exceptional builds (≥2.5× the median damage, heavy reference pack) at floor 3: **Blade 11 %, Gun 15 %** (inside your 10–20 %). But **(1)** they come early: 16 of the 26 were already exceptional on floor 1 or 2 (Gun 27 % on floors 1 and 2); **(2)** jackpots taken: 17 on floor 1, 8 on floor 2, 18 on floor 3 (not "much rarer" early); **(3)** a mutation is taken on floor 1 in about 9 % of runs (not "exceptionally rare"). The lead suggests: floor-1 jackpot 15 → 3 ‰ and no mutation through a floor-1 jackpot; Spread/Twin's floor-1 weight down (they make the early Gun spikes). Retune that way, or play first? Also: Gun Twin · Spread · Halo at level 1 hits *less* than the plain Gun against spread-out dummies (Halo's half range), to check in the Playground | numbers only | [BALANCE_BV](roadmap/v0.8.0/evidence/BALANCE_BV.md) |

---

## 3. 3D art: specs and prompts

**Shared rules (every model):** the look of your kit and `docs/art/look_reference.webp`: chunky, chipped, weathered
low-poly; worn metal, concrete and stone; no baked lighting or shadows; no text, letters or logos; one object, no
ground plane; readable from an isometric camera about 35° down. Rigged is always a bonus, never needed: without a rig
the lead animates parts in code.

**v0.9.5 (2026-10-25): the refreshed list of models still drawn by code** (10 enemies, 11 props, 6 shop pieces, 2 boss
attack pieces, the wardrobe robe, optional collectibles) is [`art/requests/v0.9.5_MODEL_LIST.md`](art/requests/v0.9.5_MODEL_LIST.md).

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

### v0.9.0: the new list (2026-10-22)
Everything v0.9.0 needs (the arrival altar, the final approach's pylons, the three elites, the puzzle and secret props,
lockdown bars and hazards, shrines, the hub's landmarks, sounds and optional effect textures), with prompts and sizes:
[`art/requests/v0.9.0_ART_LIST.md`](art/requests/v0.9.0_ART_LIST.md). The four new bosses and the 16 collectibles get
their prompts there after their G1 lists.

### 3.0 Still owed from the earlier lists

**Still not sent from the v0.9.0 list** ([`art/requests/v0.9.0_ART_LIST.md`](art/requests/v0.9.0_ART_LIST.md)):
`approach_pylon`; the containers `container_crate`, `container_urn`, `container_barrel`; `explosive_barrel`;
`timed_door` (a stone door; your bar gate became `lockdown_seal`); the hazards `hazard_cable`, `hazard_rock`, `hazard_vent`, `hazard_ice`, `hazard_star`; the four
floor 4-5 bosses and the 16 collectibles (after their G1 lists); all the sounds and the optional effect textures; and
the eight enemy models in §3.2.

- [ ] **Your key:** you wrote "F on keyboard", but F is already Vent, so the door uses the existing interact key, E
  (pad X is the same as you asked). Say if you want something else.

### 3.1 New from your playtest notes (P1)

| ✓ | id | What it is, how it should look | Size (W×D×H m) | Prompt (after the prefix) |
|---|---|---|---|---|
| ☐ | `hero_gun` | The hero's Gun, professional-looking (your note: they "need to look professional"). It fires the blue pulse, so blue accents; seen in the hero's hand, small | 0.7 long | [character prefix, steel blue] a chunky sci-fi energy pistol held in one hand, a short thick barrel with a glowing blue core visible through vents, a faceted charcoal steel body, a blue crystal power cell at the back, a worn grip; shown on its own, side view |
| ☐ | `hero_blade` | The hero's Blade, professional-looking. Its slash leaves a blue-white edge, so the edge glows | 1.1 long | [character prefix, steel blue] a single-edged laser sword, a long straight faceted blade of pale blue-white light with a hard bright edge, a chunky charcoal steel hilt with a blue crystal in the guard, a wrapped grip; shown on its own, side view |
| ☐ | `menu_chest` | For the future main-menu scene (the hero opening a chest). A treasure chest that opens: a separate lid (or a rig with an `open` clip) | 1.0 × 0.6 × 0.7 | [kit prefix] a heavy iron-banded treasure chest of dark weathered wood, faceted metal corners, a red crystal lock, glowing red light leaking through the gap under the lid, the lid as a separate object |
| ☐ | (rig) the hero | For the same scene: if your hero model can be rigged with an `open_chest` clip (kneel, lift the lid, look in), the lead builds the menu around it. Otherwise the lead animates the existing hero in code | — | — |

### 3.2 Enemy models (P1)
Your answer Q21 (2026-11-07): the eight kinds the lead still draws in code get your `.glb` models, in the Charger's
style but not red, each in its role colour. The game animates them through VAT, so a rig is a bonus and never needed;
legs and limbs as separate parts help. Each takes its **role colour** where the prompts say [COLOUR] (the game
fine-tunes the shade). Greys stay neutral, because each biome tints them.

**The style every prompt starts from:** the Charger's family. A faceted, ridged shell or hood on top, a dark
shield-shaped face under it with one glowing gem visor in the role colour, a charcoal body, and grey segmented limbs
with bone-coloured tips. Only the body plan changes, to fit what the enemy does.

| ✓ | id | Role colour | In-game size | Prompt (after the character prefix, then the 3D step) |
|---|---|---|---|---|
| ☐ | `hatchling` | melee red-orange `#C93A1E` | radius 0.28 m | a small young crawler, the Charger's family at two thirds of its size: a short faceted ridged hood in [COLOUR] over a dark shield-shaped face with one glowing [COLOUR] gem visor, a small back flap, a charcoal body, four stubby grey segmented legs with small bone talons, the front pair a little bigger; about 3k triangles |
| ☐ | `needle` | ranged blue `#3A6BD4` | radius 0.35 m | a walking turret: a faceted ridged cube-shaped shell in [COLOUR], a dark shield-shaped face on its front with one glowing [COLOUR] gem visor, a charcoal body, two grey octagonal pods on its flanks, a square grey cannon barrel pointing forward, four grey segmented legs with bone-coloured feet splayed to the corners; about 5k triangles |
| ☐ | `warden` | tank bronze `#9A6232` | radius 0.55 m | a hulking armoured tank: a long faceted ridged shell in [COLOUR] over its head and back (cracks across the back of the shell), a dark shield-shaped face with one glowing [COLOUR] gem visor, a heavy charcoal chest, big grey boulder shoulders with heavy segmented forearms and fists hanging to the ground, two short stumpy grey legs with bone-coloured toes; about 5k triangles |
| ☐ | `arc_caster` | ranged violet `#8A50D8` | radius 0.38 m | a tall caster: a faceted ridged hood and long robe-like shell in [COLOUR], a dark shield-shaped face with one glowing [COLOUR] gem visor, a charcoal body under it, grey segmented arms holding a grey staff with a bright arc crystal at its tip, three small floating [COLOUR] rune shards around the hood, no legs showing, a hem of grey segmented spikes with bone tips; about 5k triangles |
| ☐ | `bomb_drone` | bomber yellow `#E8C22E` | radius 0.40 m; hovers about 1.8 m up | a hovering quad-copter: a faceted ridged shell in [COLOUR], a dark shield-shaped face at the front with one glowing [COLOUR] gem visor, a charcoal body, four grey segmented arms with bone-coloured tips that carry flat rotor blades (blades as separate parts), a dark round bomb slung under its belly with a glowing fuse (the bomb as a separate object is a bonus); about 5k triangles |
| ☐ | `swarmer` | melee crimson `#B82A48` | radius 0.24 m (about 0.5 m long) | a small fast armoured beetle: a low wedge-shaped faceted ridged shell in [COLOUR], a dark shield-shaped face with one glowing [COLOUR] gem visor, a charcoal body, two pale bone mandibles that open wide, six thin grey segmented legs with bone tips splayed low; about 3k triangles |
| ☐ | `mine_layer` | bomber dark yellow `#C29A14` | radius 0.42 m (about 0.9 m long) | a low armoured crawler: a faceted ridged hull in [COLOUR] with chevron plates, a dark shield-shaped face with one glowing [COLOUR] gem visor, a charcoal body, carried on grey segmented legs with bone tips (two short tank treads in grey are also fine), an open hopper at the back holding a dark round spiked mine with a small blinking light (the mine as a separate object is a bonus); about 5k triangles |
| ☐ | `sniper` | ranged blue `#3A55C0` | radius 0.35 m (about 1.1 m tall) | a lean walking gun platform: a narrow faceted ridged shell in [COLOUR], a dark shield-shaped face with one glowing [COLOUR] gem visor shaped like a big round scope lens, a charcoal body, a very long grey rifle barrel pointing forward with cooling fins, three long thin grey segmented legs in a tripod with bone-coloured feet; about 5k triangles |

Still to come here: the 5 horde critters (one per biome, Q14) and the 10 new enemies (Q22), after ENEMIES.md is approved.

### 3.3 The final boss (P1–P2)

| ✓ | What | Spec | Prompt / note |
|---|---|---|---|
| ☐ | **Re-export your final-boss file with one shared, smaller texture** (P1) | 2048² or 4096², one texture used by all three bodies | Each of the three models now carries its own copy of the same 8192² texture: +56 MB in the repo |
| ☐ | Animated Colossus, Prism and The Fallen (P2) | clips named `idle`, `walk` and the attack names in FINAL_BOSS_1..3.md, in an AnimationPlayer inside the `.glb` | Yours replace the code clips by name |

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

# What the lead needs from Rius (the owner's to-do list)

Only what is **still open**: tests, decisions and art. Anything you answered or delivered is gone from here; your
answers live in [`roadmap/v0.8.0/PLAN.md`](roadmap/v0.8.0/PLAN.md) (owner lines O39–O50 and "Owner decisions"). Last
rewritten 2026-10-16 from your annotated copy, v0.8.0 (branch `claude/lucid-fermat-9wv2tf`).

- [ ] **v0.11.1, the 144 fps target (2026-11-10):** measured on your PC, the stress scenes run at 67 fps (20 enemies)
  and 27–34 fps (60–120 enemies), with 1 % lows of 10–28 fps
  ([`roadmap/v0.11.1/evidence/PERF_BASELINE.md`](roadmap/v0.11.1/evidence/PERF_BASELINE.md)). The GPU alone takes
  4.8 ms of the 6.9 ms a 144 fps frame allows. Wave 3 goes after the script cost; say whether 144 fps stays the
  target, or what you want held instead (for example: never under 60 in a horde).
- [ ] **v0.11.1, where the CPU time can still come from (2026-11-10).** The frame is limited by script on one core.
  Wave 3's cuts took a few ms off a 30–37 ms horde frame. The levers left, each measured before it is built; say
  which you want tried:
  1. **Enemies think less often, staggered** (the genre's usual first trick). It changes outcomes slightly (an enemy
     reacts a few ticks later), so it needs your OK; it would ride with the approved golden reset.
  2. **The sim on its own thread,** stepping while the main thread draws. Results stay identical. Proposed as a
     measured trial on a branch after step 32.
  3. **Every enemy on the crowd renderer** (step 39): also cuts the 8–9 draws each enemy costs today.
  4. **Native code (C# or C++) for enemy AI and movement:** only if the three above fall short; it changes the
     toolchain.
- [ ] **v0.11.1, look at the lighter effects (step 47, 2026-11-10):** a before/after sheet of every pack effect whose
  mesh was simplified will be sent; you approve the look (`OWNER ONLY`).
- [ ] **v0.11.1, the HUD's draw calls (2026-11-10):** the HUD is a flat 389 draw calls a frame (43 % of all draws
  with 20 enemies) because its icons are drawn in code. Turning them into textures would cut that and slightly
  change their edges. Not planned unless you ask.
- [ ] **v0.11.1, small:** the hub station stand-in panel can no longer be opened in the game (only a test builds it):
  delete it?
- [ ] **v0.11.1, feel the aim assist (step 33, built 2026-11-10; `OWNER ONLY`):** the aim turns 10 % of the way toward
  the enemy nearest your aim, if one is within 12° of it and within 12 m. Mouse and gamepad, on by default; Options →
  Controls → "Aim assist" turns it off. To tune it while playing: F10 → Sim → `aim_assist` (`strength_percent`,
  `cone_degrees`, `range_m`). Known choices to judge: it does not check walls (it can bend toward an enemy behind
  one); the mouse cursor stays where you point (the hero and the shot show the bent aim); a just-spawned enemy does
  not pull until its 0.6 s rise-in ends.
- [ ] **v0.11.1 "Clean and fast" (2026-11-10), one answer:** aim assist on mouse and gamepad, or gamepad only
  (default being planned: both, on, with an Options switch; [`roadmap/v0.11.1/PLAN.md`](roadmap/v0.11.1/PLAN.md)
  "Open items"). The golden reset is answered (yes, once). Later, yours to feel: aim assist once built, and each batch of enemies moved to the crowd.
- [ ] **v0.11.0, still yours (2026-11-08):** the **boss brief** (the bosses besides the Gatekeeper, Lantern Shade and
  Twins, and the "remembered" Hollow Crown behind the hidden room), the **Laser sketch**, and the overnight questions
  **N1–N9** in [`roadmap/v0.11.0/OWNER_QUESTIONS.md`](roadmap/v0.11.0/OWNER_QUESTIONS.md) §J (each has a default
  being built). Q1–Q30 and every G1/G2 are answered.
- [x] **The v0.10.5 playtest (2026-11-06):** closed per your Q27 ("treat as unmentioned"): every
  [`roadmap/v0.10.5/PLAYTEST.md`](roadmap/v0.10.5/PLAYTEST.md) row the v0.11 brief didn't mention (hub gaps,
  see-through fade, pools, Lance charge, Foundry and Hive Lens fixes, loops, Astral UI, performance, enemy shadows)
  counts as OK; the rows the brief did raise became v0.11.0 steps. Confirm or reopen in §J N8.

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

**Horde critters (one per biome, Q14).** Many are on screen at once, so each is small, one simple silhouette, about
1.5k triangles. They keep the family features (faceted shell, one glowing gem eye) scaled down. All are melee, so they
take the Swarmer's crimson.

| ✓ | id | Role colour | In-game size | Prompt (after the character prefix, then the 3D step) |
|---|---|---|---|---|
| ☐ | `dust_mite` | melee crimson `#B82A48` | about 0.3 m | a fist-sized stone tick: a low round faceted ridged shell in [COLOUR], a tiny dark shield-shaped face with one glowing [COLOUR] gem eye, a charcoal underside, six thin grey segmented legs with bone tips splayed low; about 1.5k triangles |
| ☐ | `cave_bat` | melee crimson `#B82A48` | about 0.4 m across the wings | a small flying bat: a compact faceted ridged shell in [COLOUR] on the back, a tiny dark shield-shaped face with one glowing [COLOUR] gem eye, a charcoal body, two broad grey stone wings spread wide with bone-coloured tips (wings as separate parts), two tiny grey feet tucked under; about 1.5k triangles |
| ☐ | `ember_flea` | melee crimson `#B82A48` | about 0.3 m | a small hopping flea: a tall curved faceted ridged shell in [COLOUR], a tiny dark shield-shaped face with one glowing [COLOUR] gem eye, a charcoal body, two big grey segmented back legs folded like springs with bone tips, four short front legs, a few small glowing [COLOUR] cracks on the shell; about 1.5k triangles |
| ☐ | `ice_crab` | melee crimson `#B82A48` | about 0.4 m wide | a flat sliding crab: a wide flat faceted ridged shell in [COLOUR] with pale ice-blue facets at the edges, a tiny dark shield-shaped face on the front with one glowing [COLOUR] gem eye, a charcoal underside, two small grey segmented claws with bone tips, six short flat grey legs held out sideways; about 1.5k triangles |
| ☐ | `star_mote` | melee crimson `#B82A48` | about 0.3 m | a tiny floating star with a tail: a five-pointed faceted ridged body in [COLOUR], a small dark shield-shaped face in the middle with one glowing [COLOUR] gem eye, a charcoal core, a short tapering grey tail of three segments with a bone tip, no legs; about 1.5k triangles |

**New enemies (Q22).** Same family, about 5k triangles each, plus the one thing that makes each readable in play.
**Use the detailed, ready-to-paste prompts in [`art/requests/v0.11.0_enemy_models.md`](art/requests/v0.11.0_enemy_models.md)**
(owner 2026-11-08: "these need to be detailed prompts"; sizes, separate parts and a check for each). The rows below are
the short summary.

| ✓ | id | Role colour | In-game size | Prompt (after the character prefix, then the 3D step) |
|---|---|---|---|---|
| ☐ | `wire_weaver` | bomber yellow `#E8C22E` | — | a spindly cable-laying walker: a faceted ridged shell in [COLOUR], a dark shield-shaped face with one glowing [COLOUR] gem visor, a charcoal body, four long grey segmented arms with bone tips holding two short grey cable posts with sparking tops (the two posts as separate objects), a coil of cable on its back, four thin grey segmented legs; about 5k triangles |
| ✓ | `scrap_hound` | melee red-orange `#C93A1E` | — | a lean fast four-legged hound: a low faceted ridged shell in [COLOUR] along the back, a dark shield-shaped face on a long snout with one glowing [COLOUR] gem visor, a charcoal body, four long thin grey segmented legs with bone-coloured claws, a short grey segmented tail, a few scrap plates bolted on its flanks; about 5k triangles |
| ✓ | `rock_lurker` | melee red-orange `#C93A1E` | — | a crouched creature disguised as a boulder: a round rough faceted ridged grey rock shell covering its whole back, thin glowing [COLOUR] cracks across the rock, a dark shield-shaped face half hidden under the rock edge with one glowing [COLOUR] gem visor, a charcoal body, four thick short grey segmented legs with bone-coloured claws tucked in; about 5k triangles |
| ✓ | `stone_thrower` | tank bronze `#9A6232` | — | a hunched brute with huge arms: a faceted ridged shell in [COLOUR] on its back, a small dark shield-shaped face with one glowing [COLOUR] gem visor, a heavy charcoal chest, two huge grey segmented arms with big bone-tipped hands raised overhead holding a rough grey rock (the rock as a separate object), two short stumpy grey legs; about 5k triangles |
| ✓ | `kiln_beetle` | bomber yellow `#E8C22E` | — | a slow, heavy armoured beetle: a round faceted ridged shell in [COLOUR] with vent slits, a dark shield-shaped face with one glowing [COLOUR] gem visor, a charcoal body, a big glowing [COLOUR] kiln belly showing through a gap under the shell, six thick grey segmented legs with bone tips; about 5k triangles |
| ✓ | `cinder_priest` | ranged violet `#8A50D8` | — | a robed priest: a faceted ridged hood and long robe-like shell in [COLOUR], a dark shield-shaped face with one glowing [COLOUR] gem visor, a charcoal body under it, grey segmented arms holding a tall grey staff topped with a glowing [COLOUR] ember crystal, a hem of grey segmented spikes with bone tips, no legs showing; about 5k triangles |
| ☐ | `frost_spitter` | ranged blue `#3A6BD4` | — | a lean four-legged spitter: a faceted ridged shell in [COLOUR], a dark shield-shaped face on a short wide mouth with one glowing [COLOUR] gem visor, a charcoal body, a big pale ice-blue sac swelling on its throat, four grey segmented legs with bone tips; about 5k triangles |
| ☐ | `glacier_turtle` | tank bronze `#9A6232` | — | a squat turtle: a charcoal body, a dark shield-shaped face with one glowing [COLOUR] gem visor on a short grey neck, four thick grey segmented legs with bone tips, a big domed ice shell of pale blue faceted slabs held in front (the shell as a separate object), a small faceted ridged cap in [COLOUR] on its back; about 5k triangles |
| ☐ | `star_warper` | ranged violet `#8A50D8` | — | a slim floating caster: a five-pointed star-shaped faceted ridged head in [COLOUR], a dark shield-shaped face in the middle of the star with one glowing [COLOUR] gem visor, a narrow charcoal body, two thin grey segmented arms with bone tips, a tapering grey tail instead of legs, a few small [COLOUR] star shards around it; about 5k triangles |
| ☐ | `gravity_node` | bomber yellow `#E8C22E` | — | a floating orb, no legs: a round faceted ridged shell in [COLOUR] split in two halves around a charcoal core, a dark shield-shaped face plate on the front with one glowing [COLOUR] gem visor, two or three thin grey rings circling it at different tilts (the rings as separate parts), small bone-coloured studs on the rings; about 5k triangles |

Role colours for kinds that don't match the eight above one to one: the Weaver, Kiln Beetle and Gravity Node
(area control, bomber) take the bomber yellow; the Scrap Hound and Rock Lurker (flanker, ambush) take the melee
red-orange; the Stone Thrower (brute) and Glacier Turtle (tank) take the tank bronze; the Cinder Priest (support) and
Star Warper (teleporter) take the Arc Caster's violet; the Frost Spitter (ranged) takes the Needle's blue.

The biome variants (Rubble Warden, Dim Needle, Ember Charger, Frost Charger, Split Sniper) reuse their base models with biome effects drawn by the game.

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

**v0.11.0 purpose rooms (owner, 2026-11-07: "Add to my list"; G2_ROOMS.md).** The camp, collapsed hall and quarry
rooms use stand-ins until these arrive. All after the kit prefix; sizes are targets, not measurements.

| ✓ | Room | id | Size (W×D×H m) | Prompt |
|---|---|---|---|---|
| ☐ | Camp | `camp_tent` | 2.4 × 2.0 × 1.8 | a patched canvas lean-to tent on bent metal poles, one side open, a rolled blanket inside |
| ☐ | Camp | `log_seat` | 1.4 × 0.4 × 0.4 | a short log split lengthwise as a bench, worn smooth on top |
| ☐ | Camp | `cook_pot` | 0.7 × 0.7 × 0.9 | a dented iron cooking pot hanging from a tripod of three metal rods over cold ashes |
| ☐ | Hall | `statue_whole` | 1.2 × 1.2 × 3.2 | a weathered stone statue of a hooded figure holding a staff, on a square plinth |
| ☐ | Hall | `statue_broken` | 1.4 × 1.2 × 1.8 | the same hooded statue broken at the waist, its upper half lying beside the plinth |
| ☐ | Hall | `column_round` | 0.8 × 0.8 × 3.6 | a tall round fluted stone column with a simple capital, chipped |
| ☐ | Hall | `column_drum` | 0.8 × 1.6 × 0.8 | a fallen round column drum lying on its side, cracked |
| ☐ | Quarry | `quarry_crane` | 2.0 × 1.6 × 4.0 | a wooden quarry hoist: a timber frame with a jib arm, a pulley, a rope and a hanging stone block |
| ☐ | Quarry | `mine_cart` | 1.4 × 0.9 × 1.0 | a small rusty mine cart full of rubble on a short length of rail |
| ☐ | Quarry | `stone_block` | 1.2 × 1.2 × 0.8 | a roughly cut rectangular stone block with chisel marks (tinted per biome by the game) |
| ☐ | Quarry | `tool_rack` | 1.4 × 0.4 × 1.6 | a wooden rack with pickaxes, a sledgehammer and shovels leaning in it |
| ☐ | All | bigger focal pieces | — | larger versions of the biome focal pieces (the Ruins arch, the Starfall observatory and monoliths) so they read across a 3x3 room; or say if the game may scale the existing ones |

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

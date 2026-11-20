# Assets still pending (2026-11-20)

Everything the game still draws with a code stand-in or plays with a borrowed sound, after the 2026-11-19 delivery (the
16 room pieces, the Wire Weaver, Frost Spitter, Glacier Turtle, Gravity Node, the javelin, War Banner, hour clock and
ammo cart are in). Each row was checked against `assets/`: none of these has a file there yet. The prompts, sizes and
colours are where the "Prompt" column points; this page is only the list.

Priorities are the ones the owner set in `docs/OWNER_TODO.md` §3 (P1 first). Same rules as before: one object per file,
or several laid out apart in one file (the lead cuts them out); parts that move as separate pieces help; no rig needed.

## 1. Enemies (P1): 14 models

Drawn in code today. Each will be cut into parts, animated and put on VAT like the 2026-11-19 four.

| id | What | Role colour | Prompt |
|---|---|---|---|
| `hatchling` | the Brood Mother's spawn, a small Charger | melee red-orange `#C93A1E` | OWNER_TODO §3.2 |
| `needle` | a walking turret | ranged blue `#3A6BD4` | OWNER_TODO §3.2 |
| `warden` | a hulking shielded tank | tank bronze `#9A6232` | OWNER_TODO §3.2 |
| `arc_caster` | a tall robed lightning caster | ranged violet `#8A50D8` | OWNER_TODO §3.2 |
| `bomb_drone` | a hovering quad-copter | bomber yellow `#E8C22E` | OWNER_TODO §3.2 |
| `swarmer` | a small fast beetle (comes in packs) | melee crimson `#B82A48` | OWNER_TODO §3.2 |
| `mine_layer` | a low crawler with a mine hopper | bomber dark yellow `#C29A14` | OWNER_TODO §3.2 |
| `sniper` | a tripod gun platform | ranged blue `#3A55C0` | OWNER_TODO §3.2 |
| `star_warper` | a floating star-headed caster (Starfall) | ranged violet `#8A50D8` | `v0.11.0_enemy_models.md` §9 |
| `dust_mite` | horde critter, a stone tick (about 1.5k tris) | melee crimson | OWNER_TODO §3.2 |
| `cave_bat` | horde critter, a small bat | melee crimson | OWNER_TODO §3.2 |
| `ember_flea` | horde critter, a hopping flea | melee crimson | OWNER_TODO §3.2 |
| `ice_crab` | horde critter, a flat sliding crab | melee crimson | OWNER_TODO §3.2 |
| `star_mote` | horde critter, a tiny floating star | melee crimson | OWNER_TODO §3.2 |

## 2. The hero and the final boss (P1–P2)

| What | Priority | Note |
|---|---|---|
| `hero_gun` | P1 | the hero's pistol, "professional-looking" (OWNER_TODO §3.1) |
| `hero_blade` | P1 | the hero's laser sword (OWNER_TODO §3.1) |
| Final-boss file re-exported with one shared, smaller texture | P1 | each of the three bodies carries its own 8192² copy today (+56 MB) |
| Animated Colossus, Prism and The Fallen | P2 | clips `idle`, `walk` and the attack names (OWNER_TODO §3.3) |
| The Fallen's four emblems of the bosses it remembers | P3 | Judge, Tidecaller, Gatekeeper, Twin Wardens (OWNER_TODO §3.3) |
| The amber Warden's shade | P3 | a translucent amber Warden standing and charging (OWNER_TODO §3.3) |

## 3. Boss attack pieces (P2): 6 models

| id | Boss | Size | Prompt |
|---|---|---|---|
| `stopped_gear` | Clockwork Judge's gear walls | 5.4 across, 0.8 thick | OWNER_TODO §3.5 |
| `siege_boulder` | Siege Engine's crater wall | 3 × 3, 1.1 tall | OWNER_TODO §3.5 |
| `foundry_slab` | Foundry's cooled lava slab | 4.0 across, 0.15 tall | OWNER_TODO §3.5 |
| `foundry_plate` | Foundry's Forged Plate armour | fits the Foundry | OWNER_TODO §3.5 |
| `lens_glass` | Hive Lens's burnt glass strip | 8 × 1, flat | OWNER_TODO §3.5 |
| `brood_egg` | Brood Mother's egg | 0.6 tall | OWNER_TODO §3.5 |

## 4. Props and devices (P2): 11 models

From the v0.9.0/v0.9.5 lists, never sent.

| id | What | Size | Prompt |
|---|---|---|---|
| `timed_door` | the secret room's stone door slab | 2.6 × 3.0 × 0.4 | `v0.9.0_ART_LIST.md` |
| `container_crate` | breakable crate | 0.8 cube | `v0.9.0_ART_LIST.md` |
| `container_urn` | breakable urn | 0.6 × 0.9 | `v0.9.0_ART_LIST.md` |
| `container_barrel` | breakable barrel | 0.6 × 0.9 | `v0.9.0_ART_LIST.md` |
| `explosive_barrel` | bursts when hit (red marks) | 0.6 × 0.9 | `v0.9.0_ART_LIST.md` |
| `approach_pylon` | the two pylons on the final plateau | 1.0 × 1.0 × 3.0 | `v0.9.0_ART_LIST.md` |
| `hazard_cable` | lockdown hazard, Night Rocks | flat, 2 m | `v0.9.0_ART_LIST.md` |
| `hazard_rock` | lockdown hazard, Ruins / Red Canyon | 1.2 m | `v0.9.0_ART_LIST.md` |
| `hazard_vent` | lockdown hazard, Red Canyon | flat, 1.3 m | `v0.9.0_ART_LIST.md` |
| `hazard_ice` | lockdown hazard, Frozen Shore | flat, 1.3 m | `v0.9.0_ART_LIST.md` |
| `hazard_star` | lockdown hazard, Starfall | flat, 1.3 m | `v0.9.0_ART_LIST.md` |

## 5. The shop (P2: you weren't sure yet)

| What | Prompt |
|---|---|
| Five vendors, one per biome (`shop_vendor_ruins`, `_night_rocks`, `_red_canyon`, `_frozen_shore`, `_starfall`), separate from the stall so they can move | OWNER_TODO §3.4 |
| `shop_wares`: a pile of goods for the counter | OWNER_TODO §3.4 |
| Stalls for the other four biomes (P3) | OWNER_TODO §3.4 |

## 6. Rooms (P3)

| What | Note |
|---|---|
| Bigger focal pieces | larger Ruins arch, Starfall observatory and monoliths that read across a 3 × 3 room; or say the game may scale the existing ones |

## 7. Main-menu scene (when you get to it)

| What | Note |
|---|---|
| `menu_chest` | a treasure chest with a separate lid (OWNER_TODO §3.1) |
| The hero rigged with an `open_chest` clip | optional; otherwise the lead animates the hero in code |

## 8. Boss animation clips (P3: you weren't sure yet)

In the boss's own `.glb`, named exactly so; each replaces a stand-in clip (OWNER_TODO §3.7).

| Boss | Clips |
|---|---|
| Twin Wardens | `sword_combo`, `sweep`, `dash`, `rift_dive` (Amber); `mirror_ward`, `shadow_swords`, `stunned` (Violet) |
| Warlord | `banner_plant`, `duel_call`, `duel_stance`, `enraged` |

## 9. 2D and audio

| What | Priority | Note |
|---|---|---|
| `fx_rail_streak` | P2 | the Siege Engine's rail shot texture (`v0.8.0_textures.md`) |
| Final-boss music | P3 | the final arena uses the boss sounds today |
| Boss mechanic sounds | — | the Clockwork Judge, Twin Wardens, Tidecaller, Siege Engine, The Fallen, Foundry, Warlord and Hive Lens each borrow re-pitched existing sounds (the list per boss: OWNER_TODO §4) |

## 10. From older lists: say if still wanted

These were on the v0.9.5 model list and never came back to the owner's list; the game draws them in code.

| What | Note |
|---|---|
| Splitling | what a Splitter splits into (a small Splitter) |
| The Wardrobe's display robe | a cloth on its stand in the hub; a code shape today |
| The 16 collectibles | small (≤ 0.4 m) pieces shown on the hub's pedestals; code-drawn today (`collectible_looks.gd`) |

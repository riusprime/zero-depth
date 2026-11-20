# Assets still pending (updated 2026-11-20)

Everything the game still draws with a code stand-in or plays with a borrowed sound, after the 2026-11-19 delivery (the
16 room pieces, the Wire Weaver, Frost Spitter, Glacier Turtle, Gravity Node, the javelin, War Banner, hour clock and
ammo cart are in). Each row was checked against `assets/`: none of these has a file there yet.

**Status words:** **Owner making** (prompts ready to paste in [`v0.12.0_models.md`](v0.12.0_models.md)), **Paused**
(kept on the list, not being made now), **Lead** (the lead does it, no art needed), **Dropped**.

The owner's answers of 2026-11-20 are quoted where they set a row.

## 1. Enemies: Owner making (14 models)

Owner: "I'll work the 8 regular pending enemies, the star warper, and the 5 small horde critters as well". Each will be
cut into parts, animated and put on VAT like the 2026-11-19 four. Prompts: `v0.12.0_models.md` §1–14.

| id | What | Role colour |
|---|---|---|
| `hatchling` | the Brood Mother's young, a small Charger | melee red-orange `#C93A1E` |
| `needle` | a walking turret | ranged blue `#3A6BD4` |
| `warden` | a hulking rock golem | tank bronze `#9A6232` |
| `arc_caster` | a tall robed lightning caster | ranged violet `#8A50D8` |
| `bomb_drone` | a hovering four-rotor drone | bomber yellow `#E8C22E` |
| `swarmer` | a small fast beetle (packs of eight) | melee crimson `#B82A48` |
| `mine_layer` | a low crawler with a mine hopper | bomber dark yellow `#C29A14` |
| `sniper` | a tripod gun platform | ranged blue `#3A55C0` |
| `star_warper` | a floating star-headed caster (Starfall) | ranged violet `#8A50D8` |
| `dust_mite`, `cave_bat`, `ember_flea`, `ice_crab`, `star_mote` | the five horde critters, one per biome | melee crimson `#B82A48` |

## 2. Props: Owner making (11 models)

Owner: "I'll also work the props". Prompts: `v0.12.0_models.md` §15–25.

`timed_door`, `container_crate`, `container_urn`, `container_barrel`, `explosive_barrel`, `approach_pylon`,
`hazard_cable` (Ruins), `hazard_rock` (Night Rocks), `hazard_vent` (Red Canyon), `hazard_ice` (Frozen Shore),
`hazard_star` (Starfall).

## 3. The hero and the final boss

| What | Status | Note |
|---|---|---|
| `hero_gun` | **Dropped** | Owner: "the hero being the one who shoots like "energy" / magic rune power feels better for me than giving him a gun". The hero keeps shooting from his own rune power, with no gun in his hand |
| `hero_blade` | **Owner has the model** | Owner: "the blade I have the model the thing is how are we implementing it visually so it fits". The lead's proposal is in §9 below; waiting on the owner's choice |
| Final-boss file re-exported with one shared, smaller texture | Open (P1) | each of the three bodies carries its own 8192² copy today (+56 MB) |
| Animated Colossus, Prism and The Fallen | Open (P2) | clips `idle`, `walk` and the attack names (OWNER_TODO §3.3). The lead can rig and animate these in Blender, as it did for the Twin Wardens and the Warlord |
| The Fallen's four emblems | Open (P3) | Judge, Tidecaller, Gatekeeper, Twin Wardens (OWNER_TODO §3.3) |
| The amber Warden's shade | Open (P3) | (OWNER_TODO §3.3) |

## 4. Boss attack pieces: Paused (6 models)

Owner: "I think they look good enough actually, leave them as paused but do not delete them from the list just in
case". The code-built pieces stay. Prompts: OWNER_TODO §3.5.

`stopped_gear` (Clockwork Judge), `siege_boulder` (Siege Engine), `foundry_slab` and `foundry_plate` (Foundry),
`lens_glass` (Hive Lens), `brood_egg` (Brood Mother).

## 5. The shop: Paused

Owner: "The shop paused as the boss pieces, the same one is enough, but if I want that extra I will generate them".
The one stall stays in every biome. Prompts: OWNER_TODO §3.4.

Five vendors (one per biome), `shop_wares`, stalls for the other four biomes.

## 6. Rooms: bigger focal pieces (optional, Owner)

Owner: "there is nothing specified in the doc, what kind of pieces do you want, we can work a couple but otherwise make
others bigger". The lead's proposal (`v0.12.0_models.md` Part 4): two new pieces, a `grand_arch` (6 m wide, the hall's
centrepiece in the Ruins, Night Rocks and Red Canyon) and a `great_monolith` (6 m tall, Starfall's hall). The game
scales the rest up by about 1.5 times (the observatory, the camp's fire pit, the quarry's rock face).

## 7. Boss animation clips: Lead

Owner: "what are we exactly missing and why couldn't you animate those, we worked this on another session". Right:
these need no art. In v0.11.1 the lead rigged the Twin Wardens and the Warlord in Blender and animated their first
clips (`scripts/assets/boss_anim/`). Their new moves came later in v0.12.0, after those files were made, so each borrows
an old clip today. The lead makes the eleven clips with the same rigs (a step of its own):

| Boss | Clip | Plays today |
|---|---|---|
| Twin Wardens (amber) | `sword_combo` | the file's `swipe`, once per cut |
| | `sweep` (overhead) | the file's `swipe` |
| | `dash` | nothing: he slides in his walk or idle |
| | `rift_dive` | nothing: he sinks into the floor |
| Twin Wardens (violet) | `mirror_ward`, `shadow_swords` | the file's `cast` (fits) |
| | `stunned` | the code `stagger` sway |
| Warlord | `banner_plant`, `duel_call` | the file's `idle` |
| | `duel_stance` | the file's `idle` |
| | `enraged` | the file's `idle` |

## 8. 2D and audio

| What | Status | Note |
|---|---|---|
| `fx_rail_streak` | **Owner making** | the Siege Engine's rail shot; prompt in `v0.12.0_models.md` §26 |
| Final-boss music | Paused | Owner: "Audio - still pending not gonna work on it now" |
| Boss mechanic sounds (Judge, Twin Wardens, Tidecaller, Siege Engine, The Fallen, Foundry, Warlord, Hive Lens) | Paused | each borrows re-pitched existing sounds today (OWNER_TODO §4) |

## 9. The Blade: how it would show (the lead's proposal, owner to choose)

Today the hero holds nothing: the code hero is a hooded figure in a poncho with no arms showing, and a swing is drawn
as your slash atlas sweeping round him. Your Gun answer points the same way for the Blade: the hero's power is runes,
not carried steel. So the proposal is a **rune-summoned blade**:

- It is not carried. On each swing it forms in a flash of blue runes at the poncho's edge on the swing's side, already
  at the start of the arc.
- It sweeps the arc in one motion with no hand, with your slash atlas trailing it as now, so the hit still reads exactly
  where the sim puts it.
- At the end of the recovery it breaks into blue motes and is gone. Between swings nothing shows.
- The finisher spin and the Lunge Cleave keep it out for their whole move.
- It is your model, kept matte steel with only its edge glowing pale blue-white, lit like the walls (this version's
  rule), at about 1.1 m.

The other options, if you prefer: (b) the hero carries it on his back between swings and draws it; (c) it floats
beside the hero all the time. (b) needs arms to draw it and (c) adds a moving thing next to the hero the whole run, so
the lead suggests the summoned blade. Say which, and send the model.

## 10. From older lists: what they are

These were on the v0.9.5 model list (2026-10-25) and dropped out of the owner's list since. The game draws them in
code today and none is missing anything in play. Say if you want any of them.

| What | What it is in the game | Today |
|---|---|---|
| Splitling | When you kill a Splitter, it breaks into small Splitlings that keep coming at you | drawn as a small code body in the batched crowd |
| The Wardrobe's display robe | In the hub, the Wardrobe station shows the robe your hero wears on a stand | your `hub_wardrobe` model is installed; the robe on it is a code cloth shape |
| The 16 collectibles | The secret pickups you find in runs, shown on the hub's pedestals once found | each a code-made glowing faceted gem in its own colour |

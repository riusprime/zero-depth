# v0.5.5 LK: VFX audit (A3, gate G1)

Owner line A3: "Some VFX need to match the new style of the game, I worked a full art rework and some don't match
neither style nor lighting". This is the G1 list: every effect in the game, what it looks like now, whether it
matches the new art, and the change proposed. The owner approves, edits or cuts each row. Only the rows marked
**applied** were changed in this step (low-risk: shading mode, blend mode, alpha). Every other row is **awaiting
owner**.

## The look the effects are judged against

- **The owner's visual rework is in the game** (v0.5.9 "Embers", merged into this branch at `e27e543`, merged here
  in `5bba4ba`): floors built from the owner's `.glb` kit (`assets/models/kit/`) over the worn stone ground textures,
  a lighting mood per biome (`data/biomes/*`: AgX tonemap, SSAO, SSIL, fog, a dimmer sun, warm omni lights at the
  fire props), soft contact shadows, themed rooms, and the hero's small warm light. Target image:
  [`../../../art/look_reference.webp`](../../../art/look_reference.webp) (owner: "the lighting and occlusion ambience
  is the thing I'd like to achieve").
- **Read from the art:** a dark, desaturated ruined city; weathered concrete (kit texture means `#373439`–`#504E4F`),
  rust and soot (`#4C3E37`, `#543528`), worn stone floor (`#7E6750`); bosses in saturated red and charcoal; light comes
  from fire and the hero.
- **How it was shot:** `scripts/shots/vfx_audit.gd` (committed) boots the real game (`main.tscn`), starts a run with a
  fixed profile, spawns a ring of Chargers round the hero and drives the attacks with real input events, one shot per
  effect. Two passes per build: **before** (the merged branch `e27e543` with this step's presentation files reverted)
  and **after** (this step). Renderer: `xvfb-run` + Mesa lavapipe (llvmpipe, Vulkan, Forward+), 1280 × 720; the
  raw output is in [`LOOK.md`](LOOK.md). Contact sheets (crops round the hero) in [`shots/`](shots/):
  `vfx_audit_blade_before.jpg` / `_after.jpg`, `vfx_audit_gun_before.jpg` / `_after.jpg`. Tiles, left to right, top
  to bottom: attack cool, attack Hot, attack Overclock, vent blast, skill start, skill hit, enemy telegraphs, element
  abilities (Bomb Lobber, Frost Nova, Arc Field), hits and deaths. A "Floor 1" banner covers the top of the first
  tiles (the shots start right after the floor intro).
- An earlier draft of this audit, made before the rework reached this branch, compared the effects against the kit
  laid over the old floors under an approximated light. Those shots are not committed; this version replaces them.

## The main finding

The effects were tuned for bright, pale biomes under a strong ambient light. Under the Embers light they split in
two:
- **Light-like effects read well**: the emissive blade core, bolts, hostile shots, embers, the visor, gems and orbs,
  the telegraph outlines. They glow against the dark like the fire does, and the heat colours (A2) read clearly.
- **Flat unshaded fills don't**: the skill flashes, the Bomb Lobber's landing disc, the fire patches, the Frost Nova
  disc, and before this step the vent's disc. Drawn as mixed, unshaded, pale translucent sheets, they ignore the scene
  light and read as **flat paper laid on the floor** (after sheet, tiles 5–6: the cleave's pale cyan fans; tiles 8–9:
  the Bomb Lobber's solid orange disc).
- **Debris and vapour drawn unshaded** (death shards, steam) glow at full brightness next to the lit bodies they come
  from, so the death pop's red chunks look like stickers rather than broken pieces of the enemy.

A first try with additive discs at their old alphas made them brighter sheets, not softer ones (seen in a render of
the earlier draft, not committed); the applied values are the lower alphas in the table.

Rule proposed for every effect (written into ART_DIRECTION §4 for the applied rows): **a flash of light is additive;
debris and vapour are lit by the scene; telegraphs stay unshaded** (PRESENTATION §4: no shadow may hide a warning).
Nothing here changes the v0.5.9 look: no light, environment, mood, kit, ground or hero-light value was touched; the
applied rows change only the materials of transient effects.

## Every VFX

The shots cover the hero's attacks and skills, heat, the Chargers' telegraphs, the three element abilities, sparks
and deaths. The other rows (dash, blink, statuses, boss arena, pickups, portals) are judged from their code and say
so where the judgement matters.

Status: **applied** (changed in this step), **done (A1/A2)** (built in this step for another row), **awaiting
owner** (proposal only), **keep** (matches; no change proposed).

### The hero's attacks and skills
| # | VFX | File | Now | Matches style / light? | Proposed change | Status |
|---|---|---|---|---|---|---|
| V1 | Blade (core, glow, slash trail, thrust streak, spin trail) | `world_view/kit_view.gd` | Emissive core capsule (energy 3), additive unshaded glow, mixed unshaded vertex-colour ribbon; player cyan, items tint it | Yes: reads as a light blade on dark and pale ground | A2: the tier colour (cyan below Hot, `#FFA63A` at Hot, `#FF4A1A` at Overclock); the core whitens less when hot so the colour reads | done (A2) |
| V2 | Player bolts | `world_view/actor_views.gd` (`_make_projectile`, `bolt_color`) | Unshaded emissive dart (energy 2.5), cyan or the item look | Yes | A2: a bolt takes the tier colour when fired and keeps it in flight | done (A2) |
| V3 | Lunge Cleave forecast fan | `world_view/skill_visuals.gd` | Mixed unshaded fan, alpha 0.12–0.37, rides with the lunge | Partly: flat, but it is a readable forecast | A2 tier colour. Keep mixed (it must read on pale ground) | done (A2) |
| V4 | Lunge Cleave sweep (new) | `world_view/skill_visuals.gd` | New in A1: a ribbon across the real 180° fan led by a bright blade edge, landing on the hit tick | Built in the blade's trail look (mixed, bright at the edge) | — | done (A1) |
| V5 | Lunge Cleave hit flash | `world_view/skill_visuals.gd` (`_fan`) | Was a mixed unshaded pale fan at alpha 0.75: a flat cyan sheet on the dark floor | **No** | Additive (glow template), alpha 0.75 → 0.3, tier colour 35 % toward white | **applied** |
| V6 | Lunge streak | `world_view/skill_visuals.gd` (`_streak`) | A flat mixed box (0.5 m wide plank) from the lunge's start | No: reads as a plank, not motion | A tapered ribbon like the dash trail's, additive, fading from the start | awaiting owner |
| V7 | Scatter Blast cone flash | `world_view/skill_visuals.gd` (`_blast`) | Was a mixed pale fan at alpha 0.3 | **No** (flat sheet) | Additive, alpha 0.3 → 0.22, tier colour | **applied** |
| V8 | Scatter Blast tracers and muzzle flash | `world_view/skill_visuals.gd` | Unshaded thin boxes to each pellet's end; A1 adds a muzzle flash disc | Yes | Tier colour (A2) | done (A1/A2) |
| V9 | Hero skill poses | `world_view/player_avatar.gd` | A1: lunge pose and cleave whip; braced blast with recoil | Same code-built model and frame-time smoothing as the combo poses | — | done (A1) |

### Heat
| # | VFX | File | Now | Matches? | Proposed change | Status |
|---|---|---|---|---|---|---|
| V10 | Vent blast disc | `world_view/heat_visuals.gd` (`_blast`) | Was a mixed unshaded disc, heat colour lerped 30 % to white-hot, alpha 0.2–0.45 | **No**: the clearest mismatch (a pale salmon sheet in the earlier draft's dark shots; before sheet tile 4) | Additive (glow template), the pure heat colour, alpha 0.2–0.45 → 0.1–0.25; the ring keeps the edge readable on pale ground. Under the v0.5.9 light the before and after sheets look nearly the same (tile 4): still a disc of even colour: a radial falloff (bright core, clear edge) is proposed next | **applied** (falloff: awaiting owner) |
| V11 | Vent blast ring | `world_view/heat_visuals.gd` | Unshaded torus growing to the sim radius | Yes (a bright edge) | — | keep |
| V12 | Overclock embers (hits, trail, vent) | `world_view/heat_visuals.gd` | Unshaded small boxes, orange to white-hot, gravity | Yes (sparks of light) | — | keep |
| V13 | Overheat steam | `world_view/heat_visuals.gd` (`_steam`) | Was unshaded pale spheres at 0.55: bright white blobs, brightest in the dark | **No** (vapour drawn as light) | Shaded by the scene light (roughness 1), same colour and alpha | **applied** |
| V14 | Visor heat tint | `world_view/player_avatar.gd` (`set_heat`) | Visor leans cyan → orange → white-hot | Yes | — | keep |
| V15 | Heat meter | `hud/heat_meter.gd` | Thin bar; Hot / Overclock ticks in the same colours as the attacks now | UI: A5 mockups decide | — | keep (A5) |

### Movement
| # | VFX | File | Now | Matches? | Proposed change | Status |
|---|---|---|---|---|---|---|
| V16 | Dash trail and afterimages | `world_view/dash_trail.gd` | White ribbon at `Color(1.5,1.5,1.5)` (over 1.0 for glow) plus white silhouettes | Partly (judged from the code, not shot): owner asked for white (v0.2.0 L12); an over-bright white ribbon is likely to be the brightest thing on the dark art | Keep white but drop the over-bright value to ~1.1 and alpha ~0.7 on dark floors, or tint it toward the visor cyan | awaiting owner |
| V17 | Blink flash | `world_view/blink_flash.gd` | Blue `#2F6BFF` column, ground pool, sparks, a real OmniLight | Yes (it lights the scene) | — | keep |
| V18 | Kinetic Dash afterimages, Twin Arc echo, Overcharge ring | `world_view/item_visuals.gd` | Unshaded cyan pieces | Yes (light) | — | keep |
| V19 | Portal way in / arrival (motes, column, flash) | `world_view/portal_transit_view.gd` | Additive visor-blue column and motes | Yes | — | keep |

### Hit feel
| # | VFX | File | Now | Matches? | Proposed change | Status |
|---|---|---|---|---|---|---|
| V20 | Hit flash | `world_view/actor_views.gd` (`_set_flash`) | White emission 1.6 for 3 frames | Yes | — | keep |
| V21 | Sparks: guard, weak spot, exposed, finisher | `world_view/hit_feel.gd` | Unshaded small boxes, pale / gold | Yes (light) | — | keep |
| V22 | Dull sparks: Warden armour, boss deflect | `world_view/hit_feel.gd` | Unshaded grey boxes | Partly: grey "sparks" are chips of stone, drawn as light | Shaded like the death pop (one line, same `lit` flag) | awaiting owner |
| V23 | Death pop | `world_view/hit_feel.gd` (`_burst` on KILL) | Was 7 unshaded enemy-red boxes | **No**: the chunks glowed brighter than the lit body they broke from | Shaded by the scene light (`lit`), same colour, size and motion | **applied** |
| V24 | Damage numbers | `world_view/damage_numbers.gd` | White / crit-yellow Label3D, outlined | UI | Follows the A5 UI style pick | awaiting owner (A5) |

### Enemies and bosses
| # | VFX | File | Now | Matches? | Proposed change | Status |
|---|---|---|---|---|---|---|
| V25 | Attack telegraphs (all shapes; Arc Caster core and rune, bomb cross-hair, snipe core, bash chevrons, mine star, spear heads, molten core) | `world_view/telegraph_views.gd` | Unshaded hostile-orange outline at full opacity, fill growing 0 → 100 % | Contract: unshaded by rule (PRESENTATION §4). On the dark art they read clearly; the fill is flat | Keep unshaded. Optional: a faint additive inner glow on the outline so it reads as light, not paint | awaiting owner |
| V26 | Hostile projectiles | `world_view/actor_views.gd` | Unshaded emissive yellow streaks | Yes | — | keep |
| V27 | Sniper tracer, Mender heal beam, mines' red light | `world_view/horde_visuals.gd` | Unshaded lines and a blinking light | Yes | — | keep |
| V28 | Enemy and boss glows (visors, cracks, weak points, muzzles) | avatars, `boss_parts.gd` | Emissive 1.0–2.4 | Yes; the owner's boss models carry the same red | — | keep |
| V29 | Boss arena band, pull vortex, dissolve motes | `world_view/boss_challenge_view.gd` | Solid unshaded `#FF5A2A` strip; cyan motes | Partly: the solid strip is flat paint | Additive band or a molten texture; keep the warning outline unshaded | awaiting owner |
| V30 | Elite crowns | `world_view/event_pedestal_views.gd` | Unshaded gold ring under every elite | Yes | — | keep |

### Statuses
| # | VFX | File | Now | Matches? | Proposed change | Status |
|---|---|---|---|---|---|---|
| V31 | Burn embers, shock pips and sparks, discharge lines, bleed drips and ring, frost crystals, ice shell, Bulwark orbs, combo rings (Plasma Arc, Shatter Dash, Wildfire, Blood Harvest, Frozen Bastion, Resonance) | `world_view/status_visuals.gd` | Unshaded small meshes per status | Mostly (light-like). Bleed drips and frost crystals are matter drawn as light | Bleed drips and frost crystals shaded; the rest keep | awaiting owner (not shot) |
| V32 | Burning / frozen body tint | `world_view/item_visuals.gd` (`set_tint`) | Orange / icy emission on the body | Yes | — | keep |

### Abilities
| # | VFX | File | Now | Matches? | Proposed change | Status |
|---|---|---|---|---|---|---|
| V33 | Bomb Lobber: arc, landing circle, landing flash disc | `world_view/ability_visuals.gd` | Dark bomb, ring + growing fill, orange mixed flash disc | The flash disc has V10's flat-sheet problem (shot 08) | Additive flash (the V10 change) | awaiting owner |
| V34 | Drone Buddy, its muzzle flash and chain line | `world_view/ability_visuals.gd` | Lit white shell, cyan emissive | Yes | — | keep |
| V35 | Orbit Blades (steel / ice) | `world_view/ability_visuals.gd` | Flat steel blades | Yes | — | keep |
| V36 | Blink shock, Combo Sword finisher wave | `world_view/ability_visuals.gd` | Ring flashing out to the radius | Yes | — | keep |
| V37 | Arc Field bolts, Storm Bombs chains | `world_view/element_visuals.gd` | Unshaded jagged lines, pale blue / violet | Yes (light) | — | keep |
| V38 | Frost Nova disc, fire patches (Flame Trail, Napalm Drone) | `world_view/element_visuals.gd` | Unshaded mixed discs (pale blue; flat orange) | **No**: flat sheets on the dark floor (shot 08) | Frost: additive; fire: additive core with a few rising embers (as V12) | awaiting owner |
| V39 | Ember Ward ring, Blink Charge flash, Wingman flash | `world_view/element_visuals.gd` | Unshaded rings / flashes | Mostly | Additive for the flashes | awaiting owner |

### Pickups and the world
| # | VFX | File | Now | Matches? | Proposed change | Status |
|---|---|---|---|---|---|---|
| V40 | Shard gems | `world_view/shard_views.gd` | Violet emissive 2.4 | Yes | — | keep |
| V41 | Heal orbs | `world_view/heal_orb_views.gd` | Green emissive 2.2, pulsing | Yes | — | keep |
| V42 | Item pedestals, altars, chests | `pickup_views.gd`, `reward_views.gd` | Chests: the owner's model since v0.5.9 (red lock glow, warm flare on opening). Pedestals and altars: flat-colour code stone (`#6F6A66`–`#8B847D`) with a glowing crystal and a light | Glows yes; the pedestal and altar stone is flat colour next to the textured kit (judged from code) | Kit-textured plinths (an art request like KIT_REQUESTS) | awaiting owner (models) |
| V43 | Portal gate (swirl, floor glow, Deep variant) | `world_view/portal_gate.gd` | Visor-blue / violet swirl and light; code-built stone pillars | Glow yes; stone as V42 | As V42 for the stone | awaiting owner (models) |
| V44 | Boss door seal, Overrun door frames | `boss_door_view.gd`, `overrun_door_views.gd` | Red emissive seal and frames | Yes | — | keep |
| V45 | Event pedestals, Wandering Drone ring | `world_view/event_pedestal_views.gd` | Violet glyph crystal and light | Yes | — | keep |
| V46 | Gamble shrine, shop terminal | `gamble_shrine_view.gd`, `shop_terminal_view.gd` | Teal core / violet screen, emissive | Partly (judged from the earlier draft's dark shots): the shop screen was the brightest object on screen | Lower the screen's energy on dark floors | awaiting owner |
| V47 | Team and contact rings, HP bars | `world_view/actor_views.gd` | Unshaded, biome `outline` token | Contract (PRESENTATION §3) | Check each biome's `outline` token against the textured ground under the mood light (the palette test checks the flat `ground` token) | awaiting owner |
| V48 | Ink outline pass | `world_view/ink_pass.gd` | Screen-space one-pixel ink (owner's pick) | Yes on the models | — | keep |

## Open questions for the owner (Q-A3)
1. Approve, edit or cut the rows marked **awaiting owner**. The largest group is the flat fills (V6, V10 falloff,
   V29, V33, V38, V39): one shared change (additive light with a radial falloff) would fix them together.
2. Telegraph fills (V25): keep the flat orange (most readable), or add a light-like inner glow?
3. The dash trail (V16): keep pure white, or dim / tint it for the darker floors?

# Card icon prompts (v0.10.5 W3-A1)

`ZD_CARD_ICONS.xlsx` is the workbook for the owner's n8n image workflow, in the shape of the owner's `ART_PROMPTS.xlsx`:
sheet **Prompts** (one row per image sheet, columns `image_name` … `file`, then group / purpose / reference / notes) and
sheet **API setup** (how the workflow calls the API). Look target: the card icons in
`docs/roadmap/v0.10.5/ui_refs/02_carved_eclipse.webp` (painterly, luminous silver and moon-blue, lit from the top-left,
on a transparent background).

Every prompt is self-contained: the full shared style block is repeated word for word in every row, then the
numbered subject of each cell. Every row asks for a PNG with a fully transparent background (`background=transparent`,
`output_format=png`, in the columns and in `request_json`, and said in the prompt). Only the five element cards
(Fire, Frost, Lightning, Venom, Bleed) add an accent hue, from `ElementLooks` (`src/presentation/world_view/attack_forms/element_looks.gd`);
the ornament gems use the card rarity colours of `pick_slot.gd`.

## How to run

1. **n8n:** for each row, `POST` the row's `request_json` to `endpoint` (auth header from an n8n credential), decode
   `data[0].b64_json` and save it as `art_raw/sheets/<image_name>` (`art_raw/` is git-ignored). Run row 1 first and
   approve its look before the others.
2. **Split:** `python -I scripts/art/split_sheets.py` (needs `pip install pillow`; `--only <asset_id>` for one row,
   `--dry-run` to list the files). It cuts each sheet by `grid` in reading order into the names in `cells`, resized to
   `cell_final_size`: card icons to `assets/ui/card_icons/icon_<card id>.png` (256x256), ornaments to
   `assets/ui/card_ornaments/` (128x128).
3. **Import:** `godot --headless --path . --editor --import --quit`. Wiring the icons into the cards is a separate step.

## Sheets

| Row | Sheet | Grid / size | Cells |
|---|---|---|---|
| 1 | card_icons_1_gun_forms | 4x4, 1920x1920 | 16 gun forms and patterns |
| 2 | card_icons_2_blade_forms | 4x4, 1920x1920 | 16 blade forms and patterns |
| 3 | card_icons_3_mods_abilities | 4x4, 1920x1920 | 8 gun shot mods, 4 blade dash/guard mods, 4 abilities |
| 4 | card_icons_4_elements_passives | 4x4, 1920x1920 | 5 element cards, 11 passives |
| 5 | card_icons_5_stats | 4x4, 1920x1920 | 16 stat cards |
| 6 | card_icons_6_heat_curses | 4x3, 1920x1440 | 3 Heat passives, Vent Mend, 7 trade-off curses, the fallback `icon_unknown` |
| 7 | card_ornaments | 4x4, 1920x1920 | shard, heal, reroll, divider, 5 rarity gems x normal/focused, buys-left pip on/off |

The cards are every card a run can offer: the 63 items (`data/items`), the abilities Aegis, Blink and Combo Sword
(level-ups) plus the Pulse Gun (never offered, but its weapon shows in the HUD), the 17 stat cards with a non-zero
weight (`data/stat_cards`), and the 7 trade-off curses a cursed chest offers (`data/curses`). The 8 stat cards with
weight 0 (area, armour, cooldowns, crit_damage, move_speed, pickup_range, regen, shard_gain) are never offered and
have no icon.

## The cards and their icons

| Sheet | Cell | Id | Name | Kind | What it does | Icon subject |
|---|---|---|---|---|---|---|
| card_icons_1_gun_forms | 1 | `gun_glaive` | Glaive | item | A spinning disc that flies out and back. | a four-bladed spinning disc glaive with curved crescent blades, two faint arcs showing it flying out and curving back. |
| card_icons_1_gun_forms | 2 | `gun_laser` | Laser | item | Hold to burn a beam. | a straight, thick beam of white light shooting diagonally from the lower left to the upper right, a bright emitter flare at its base and a small burning splash where it ends. |
| card_icons_1_gun_forms | 3 | `gun_wisps` | Wisps | item | Three wisps circle you and fire at the nearest foe. | three small teardrop-shaped wisps of moonlight orbiting an empty centre on a thin tilted elliptical path, each with a short curling tail. |
| card_icons_1_gun_forms | 4 | `gun_ring` | Ring | item | Your shot becomes a lightning ring. | a crackling ring of thorny lightning, jagged spikes of electricity bristling on its rim, the centre of the ring empty. |
| card_icons_1_gun_forms | 5 | `gun_pierce` | Pierce | item | Your shots pass through enemies. | a slim needle-like bolt passing straight through three thin translucent crystal plates in a row, each plate with a clean round hole where it went through. |
| card_icons_1_gun_forms | 6 | `gun_void` | Void | item | Throw black holes that tug at foes. | a small perfectly black sphere (a black hole) wrapped in a thin bright silver event-horizon ring, streaks of light curving inward toward it as they are pulled in. |
| card_icons_1_gun_forms | 7 | `gun_twin` | Twin | item | Fire twice, side by side. | two identical parallel bolts flying side by side, close together, the same length and brightness, pointing to the upper right. |
| card_icons_1_gun_forms | 8 | `gun_seekers` | Seekers | item | Darts that curve to the nearest foes. | three slim dart-shaped bolts curving along different arcs toward one shared point at the upper right, each trailing a thin curved light line. |
| card_icons_1_gun_forms | 9 | `gun_spiral` | Spiral | item | Your shots corkscrew. | a tight spiralling vortex of light curling inward to a bright centre, its arms sweeping clockwise like a small galaxy. |
| card_icons_1_gun_forms | 10 | `gun_lance` | Lance | item | Hold to charge, release a piercing energy ball. | a long tapering spear of light ending in a dense bright energy ball at its tip, three charging rings gathered around its shaft. |
| card_icons_1_gun_forms | 11 | `gun_backfire` | Backfire | item | Also fire behind you. | two bolts flying in exactly opposite directions out of one central muzzle flash, one toward the upper right and one toward the lower left. |
| card_icons_1_gun_forms | 12 | `gun_wave` | Wave | item | A wide slow wave that rolls through everything. | one broad, low wall of light rolling forward like a cresting ocean wave seen from the side, wide and slow. |
| card_icons_1_gun_forms | 13 | `halo_shot` | Halo | item | Fire in a full ring. | a full ring of eight short bolts pointing outward from a bright centre, evenly spaced like the rays of a compass. |
| card_icons_1_gun_forms | 14 | `gun_ricochet` | Ricochet | item | Your shots bounce off walls. | a bolt zig-zagging between two angled stone wall slabs, its light trail bending at sharp angles, a small spark at each bounce. |
| card_icons_1_gun_forms | 15 | `gun_rune_explosion` | Rune Explosion | item | A violet rune shield bursts out of you. | a faceted hexagonal rune-shield bubble bursting outward from a bright central point, shards of its crystal shell flying away. |
| card_icons_1_gun_forms | 16 | `gun_homing` | Homing | item | Your shots curve toward enemies. | a bolt flying along a smooth curve that bends sharply toward a small faceted diamond crystal, the curve clearly hooking to meet it. |
| card_icons_2_blade_forms | 1 | `whirl` | Whirl | item | Every slash becomes a full spin. | a complete circular spin-slash, a full 360-degree crescent of light around an empty centre with a small sword hilt at one point of the circle. |
| card_icons_2_blade_forms | 2 | `thrust` | Thrust | item | Stab farther and harder, but narrower. | a long, narrow rapier blade stabbing diagonally up to the right, a thin cone-shaped shock of air at its point. |
| card_icons_2_blade_forms | 3 | `fissure` | Fissure | item | Your slashes crack the ground and it erupts. | a jagged crack split open in a slab of rock, sharp shards of rock and light erupting upward out of the crack. |
| card_icons_2_blade_forms | 4 | `blade_orbit` | Orbit Blades | item | Your slashes throw blades that circle you. | three small curved sickle blades circling an empty centre on one round orbit path, evenly spaced. |
| card_icons_2_blade_forms | 5 | `heavy` | Heavy | item | Slower swings that hit much harder. | a massive broad greatsword pointing straight down, thick and heavy, a dense round impact shockwave at its tip. |
| card_icons_2_blade_forms | 6 | `echo_slash` | Wave | item | Your slashes fly as crescents. | a single thin, sharp crescent of light flying away from a sword's tip, detached from the blade like a thrown crescent moon. |
| card_icons_2_blade_forms | 7 | `parry_edge` | Parry Edge | item | Your slashes destroy enemy shots. | a sword edge slicing a small round glowing bullet-orb cleanly in half, the two halves flying apart with sparks. |
| card_icons_2_blade_forms | 8 | `flurry` | Flurry | item | After a pause, a burst of fast, lighter swings. | a fan of five quick, thin, overlapping slash streaks, all from one point, like a burst of rapid cuts. |
| card_icons_2_blade_forms | 9 | `double_slash` | Double Slash | item | Every slash repeats, mirrored. | two mirrored crescent slash arcs crossing each other in a sharp X. |
| card_icons_2_blade_forms | 10 | `finisher_plus` | Fracture Bank | item | Combo hits lodge fragments; your finisher rips them out. | a cracked crystal sphere with three sharp shard fragments being ripped out of it and flying outward. |
| card_icons_2_blade_forms | 11 | `lunge_step` | Lunge Step | item | Each slash steps you forward. | a sword pointing to the right with three stepping chevron-shaped afterimages behind it, showing it lunging forward step by step. |
| card_icons_2_blade_forms | 12 | `split_wave` | Split Wave | item | Flying slashes split; without them, hits throw crescents. | one crescent slash breaking apart into three smaller crescents that fan outward. |
| card_icons_2_blade_forms | 13 | `chain_cut` | Chain Cut | item | Your slash hits jump to the next enemy. | a slash arc whose end leaps as a jagged zig-zag spark chain to a second, smaller slash mark. |
| card_icons_2_blade_forms | 14 | `wide_arc` | Wide Arc | item | Your slashes sweep wider and farther. | a very wide, flat sweeping crescent slash, almost a half moon, broad and long. |
| card_icons_2_blade_forms | 15 | `blade_storm` | Blade Storm | item | Your slashes throw blades that come back. | two curved blades flying out along a long boomerang-shaped loop and coming back, the loop drawn as a bright trail. |
| card_icons_2_blade_forms | 16 | `riposte_chain` | Riposte Chain | item | A slash kill strikes the next enemy. | a sword blade crossing a shattered crystal orb, a long hooked arc of light springing from the orb toward the upper right. |
| card_icons_3_mods_abilities | 1 | `aegis` | Aegis | ability | Hold to guard against enemies. Next attack deals more damage based on your blocks. | a round, domed buckler shield made of faceted hexagonal energy plates, small sparks glancing off its front. |
| card_icons_3_mods_abilities | 2 | `gun_rapid_fire` | Rapid Fire | item | Smaller, weaker shots that fire faster the longer you hold. | a straight stream of five small bolts in a line, packed closer and closer together toward the front. |
| card_icons_3_mods_abilities | 3 | `counter` | Counter | item | Slash right after a dash to hit hard. | a curved dash swoosh that hooks sharply back into a bright X-shaped impact spark. |
| card_icons_3_mods_abilities | 4 | `gun_mine` | Mine | item | Your shots stop and wait as mines. | a small spiked crystal sphere hovering perfectly still, two thin concentric warning rings pulsing around it. |
| card_icons_3_mods_abilities | 5 | `gun_threadline` | Threadline | item | Shots fired close together are linked by a cutting thread. | two bolts flying side by side joined by one taut, glowing thread between them, the thread sharp like a cutting wire. |
| card_icons_3_mods_abilities | 6 | `blink` | Blink | ability | Teleport forward. | two tall, thin blade-like crystal spires of light rising out of concentric rippled rings, as if appearing through a portal. |
| card_icons_3_mods_abilities | 7 | `gun_big_shot` | Big Shot | item | Bigger, stronger, slower shots. | one large, heavy, oversized round orb bolt with a thick dense core and a short heavy trail. |
| card_icons_3_mods_abilities | 8 | `long_shadow` | Dodge Imprint | item | After a dash, your next attack comes from where it began. | a faint translucent ghost of a faceless hooded cloaked figure left behind, a bright slash arc coming out of the ghost. |
| card_icons_3_mods_abilities | 9 | `bulwark` | Bulwark | item | Blocking powers up your next swing. | a tall silver kite shield with a simple four-pointed star glyph glowing at its centre and a charged spark gathering above its top edge. |
| card_icons_3_mods_abilities | 10 | `orbit_rounds` | Orbit | item | Your shots circle you before flying out. | a small bolt travelling around a bright point on a thin circular orbit path, then breaking away along a straight tangent line. |
| card_icons_3_mods_abilities | 11 | `combo_sword` | Combo Sword | ability | Increase damage of your combo and Lunge Cleave. | an elegant straight longsword pointing up, three stacked crescent combo-slash marks curving around its blade. |
| card_icons_3_mods_abilities | 12 | `gun_echo` | Echo | item | Fire again a moment later. | one bolt followed a short distance behind by a fainter, ghostly copy of itself on the same path. |
| card_icons_3_mods_abilities | 13 | `split_shot` | Split | item | Your shots split on hit. | a bolt hitting a small crystal and splitting into three smaller bolts fanning out beyond it. |
| card_icons_3_mods_abilities | 14 | `momentum` | Momentum | item | Attack right after a dash to hit harder. | a sword blade riding on a big forward-pointing chevron arrow made of speed lines, the blade's edge glowing brighter at the front. |
| card_icons_3_mods_abilities | 15 | `gun_swirl` | Swirl | item | Your shots swirl at random. | a bolt trailing a loose, wandering path of random loops and squiggles behind it. |
| card_icons_3_mods_abilities | 16 | `pulse_gun` | Pulse Gun | ability | Increase the damage of your weapon and Scatter Blast. | a slim silver arcane rod-gun with a glowing crystal at its muzzle releasing a single round pulse ring forward. |
| card_icons_4_elements_passives | 1 | `ember_core` | Fire | item | Burns. Lv2: wider fire. Lv3: burning foes take more. | a faceted moon-silver crystal core with tongues of flame licking upward from it. **FIRE accent.** |
| card_icons_4_elements_passives | 2 | `swift_feet` | Swift Feet | item | Run faster and dash more often. | a silver boot with small feathered wings at its heel and speed lines trailing behind it. |
| card_icons_4_elements_passives | 3 | `shared_stress_mark` | Stress Mark | item | Nearby enemies show a weak side. Hit it for double damage. | a curved crystal armour plate with one glowing cracked weak spot marked by a small bright diamond target. |
| card_icons_4_elements_passives | 4 | `frost_core` | Frost | item | Freezes. Lv2: frozen take more. Lv3: shatters. | a large six-armed snowflake crystal with sharp ice spikes, frost rime on its arms. **FROST accent.** |
| card_icons_4_elements_passives | 5 | `executioner` | Executioner | item | Deal more damage to weak enemies. | a heavy crescent headsman's axe blade poised above a cracked, half-broken crystal heart. |
| card_icons_4_elements_passives | 6 | `storm_core` | Lightning | item | Chains. Lv2: +1 jump. Lv3: every 6th hit, a strike. | a crystal orb with a forked lightning bolt splitting out of it toward the lower right, small arcs crawling on the orb. **LIGHTNING accent.** |
| card_icons_4_elements_passives | 7 | `thorn_mantle` | Thorn Mantle | item | Getting hit fires bolts all around you. | a spiked shoulder pauldron bristling with long thorns, three small bolts shooting off the thorns in different directions. |
| card_icons_4_elements_passives | 8 | `chain_blast` | Chain Blast | item | Your attack and its splits all explode. | a chain of three starburst explosions in a diagonal row, each a little smaller than the one before, linked by sparks. |
| card_icons_4_elements_passives | 9 | `venom_core` | Venom | item | Poison. Lv2: it spreads. Lv3: it stacks. | a single large falling venom drop with a curved fang above it, a few small droplets splashing below. **VENOM accent.** |
| card_icons_4_elements_passives | 10 | `kinetic_dash` | Kinetic Dash | item | Dash through enemies to hurt them. | a sharp arrow-shaped dash streak piercing straight through a small crystal orb that shatters into fragments. |
| card_icons_4_elements_passives | 11 | `shared_faultline` | Faultline | item | Hits leave cracks; attacking across one makes it erupt. | a thin glowing zig-zag crack running across the cell, a slash arc crossing it and a small eruption flash where they cross. |
| card_icons_4_elements_passives | 12 | `vampiric_core` | Vampiric Core | item | Kills heal you. | a faceted crystal heart drawing a thin stream of light up into itself from a broken shard below it. |
| card_icons_4_elements_passives | 13 | `cold_snap` | Cold Snap | item | Dashing chills enemies. Frozen ones take more. | a curved dash swoosh leaving a trail of small ice crystals and frost shards behind it. |
| card_icons_4_elements_passives | 14 | `shared_bleed` | Bleed | item | Bleed. Lv2: hurts more on the move. Lv3: bursts. | a curved thorn-hook blade with three drops of blood falling from its point. **BLEED accent.** |
| card_icons_4_elements_passives | 15 | `wildfire` | Wildfire | item | Kills spread the fire. | a cold moon-blue flame leaping in an arc from one small cracked crystal to two others, which catch fire too. |
| card_icons_4_elements_passives | 16 | `phase_strike` | Phase Strike | item | Blinking or blocking hurts enemies around you. | an expanding dome-shaped shockwave with a crackling rim, a small diamond spark at its centre. |
| card_icons_5_stats | 1 | `glass_cannon` | Glass Cannon | stat | +X% damage, -X% max HP | a cluster of sharp crystal spikes bursting upward from one point, the tallest spike with a thin crack running up it. |
| card_icons_5_stats | 2 | `hoarder` | Hoarder | stat | +X% damage per 100 shards, +X% shards | a small heap of faceted diamond-shaped shard gems with a short sword standing upright in the top of the heap. |
| card_icons_5_stats | 3 | `attack_speed` | Haste | stat | +X% attack speed | an hourglass tilted forward, wrapped in speed streaks, its sand pouring fast. |
| card_icons_5_stats | 4 | `max_hp` | Vitality | stat | +X% max HP | a large, whole, bright faceted crystal heart. |
| card_icons_5_stats | 5 | `crit_chance` | Precision | stat | +X% crit chance | four crystal shards pointing inward at one bright centre dot, like a precise aiming mark. |
| card_icons_5_stats | 6 | `onrush` | Onrush | stat | +X% damage while moving | a comet: a bright head with a long tail streaking forward to the upper right. |
| card_icons_5_stats | 7 | `lifesprout` | Lifesprout | stat | Kills may drop a heal orb: X% (+X% per extra card) | a small sprouting seedling of light with two leaves, a glowing round orb at its bud. |
| card_icons_5_stats | 8 | `damage` | Power | stat | +X% damage | a clenched armoured gauntlet fist, glowing with power. |
| card_icons_5_stats | 9 | `overkill` | Overkill | stat | Kills splash X% of extra damage nearby | a chalice overflowing, light spilling over its rim and splashing outward. |
| card_icons_5_stats | 10 | `heat_shield` | Heat Shield | stat | -X% damage taken while HOT | a round shield with wavy heat lines rising off its rim, its centre cool and frosted. |
| card_icons_5_stats | 11 | `third_strike` | Third Strike | stat | Every third attack in a row (1 s apart at most) deals +X% | three slash marks side by side, the third one larger and blazing much brighter than the first two. |
| card_icons_5_stats | 12 | `scavenger` | Scavenger | stat | Critical kills pay +X% shards | a curved scavenger's claw-hook gripping a faceted shard gem, a four-pointed critical sparkle on the gem. |
| card_icons_5_stats | 13 | `fast_hands` | Fast Hands | stat | -X% ability cooldowns | an open armoured hand, palm up, with three small rune stones flicking off its fingertips. |
| card_icons_5_stats | 14 | `close_quarters` | Close Quarters | stat | +X% damage to enemies within 2 m | a short dagger pointing out of a small tight ring of light that hugs it closely. |
| card_icons_5_stats | 15 | `reflex` | Reflex | stat | A kill while your dash recharges cuts X% of its cooldown | a round dial with one hand, a curved dash arrow sweeping around the dial and pushing the hand forward. |
| card_icons_5_stats | 16 | `adrenaline` | Adrenaline | stat | A kill within 3 m: +X% move speed for 1.5 s | a jagged heartbeat line spiking sharply upward across the cell, ending in an upward chevron. |
| card_icons_6_heat_curses | 1 | `heat_sink` | Heat Sink | item | Your vents hit harder and farther. | a ribbed block of radiator fins venting a long, powerful cone of steam out to the right. |
| card_icons_6_heat_curses | 2 | `brittle` | Brittle | curse | Getting hit stuns you / Move faster | a thin crystal pane shattering with spiderweb cracks, three small stun stars circling above it (a curse: darker, more ink and slate, cracked). |
| card_icons_6_heat_curses | 3 | `vent_mend` | Vent Mend | stat | A Vent that hits an enemy heals X% max HP | a plume of steam bursting up from a cracked grate, a small plus-shaped healing spark inside the plume. |
| card_icons_6_heat_curses | 4 | `rooted` | Rooted | curse | You can't dash / Sometimes dodge a hit | a boot bound tight by twisting roots wrapping around it from below (a curse: darker, more ink and slate, cracked). |
| card_icons_6_heat_curses | 5 | `glass_heart` | Glass Heart | curse | Less max HP / More crit chance | a small hollow heart of thin glass hanging from a fine chain, a crack running down its middle (a curse: darker, more ink and slate). |
| card_icons_6_heat_curses | 6 | `meltdown` | Meltdown | item | Overheating explodes instead of stalling you. | a cracked overheating core sphere bursting open in a single big starburst explosion. |
| card_icons_6_heat_curses | 7 | `tunnel_vision` | Tunnel Vision | curse | No minimap / More shards | an open eye whose sight is narrowed by two closing dark stone blinders, only a thin slit of light left between them (a curse: darker, more ink and slate). |
| card_icons_6_heat_curses | 8 | `thermal_edge` | Thermal Edge | item | You run Hot sooner. | a tall glass vial etched with plain rings, its glowing fill rising fast to the very top. |
| card_icons_6_heat_curses | 9 | `blood_price` | Blood Price | curse | Skills and Blink cost HP / Skills and abilities hit harder | a slender sacrificial dagger, drops falling from its point and turning into sparks as they fall (a curse: darker, more ink and slate; the drops stay silver, not red). |
| card_icons_6_heat_curses | 10 | `unknown` | — | fallback | A card with no icon yet. | a smooth, sealed, blank oval rune stone with light leaking from one thin seam around it. |
| card_icons_6_heat_curses | 11 | `heavy_hands` | Heavy Hands | curse | You attack slower / Every 4th hit hits harder | an armoured gauntlet chained to a heavy round iron weight (a curse: darker, more ink and slate). |
| card_icons_6_heat_curses | 12 | `fevered` | Fevered | curse | Heat fades slower / Overclock hits harder | a lantern holding a trapped, churning heat haze that cannot escape, wisps curling inside its glass (a curse: darker, more ink and slate). |

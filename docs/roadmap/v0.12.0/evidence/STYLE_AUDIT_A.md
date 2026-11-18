# Boss style audit, part A: the Clockwork Judge, the Siege Engine, the Foundry, the Warlord, the Hive Lens

The owner, 2026-11-18, before their playtest: "let's throw that full analysis of all of them and then pick which ones
could be reworked to actually fit the style". They named the Siege Engine's "hazard looking textures" and the Clockwork
Judge's gears. This is a read-only audit: no game file changed. Part B (the other bosses) is a separate file.

**The bar** is Amber's charge-end slam after step 25b (the owner: it "matches a lot more the style, the little debris
the colors, looks completely in place"): faceted stone chunks and grit in the floor's own colour, flat-shaded, dark ink
outlines, the biome's muted palette, lit softly by the hero light; no glowing fire, no saturated neon, no particle soup,
no realistic textures. Also ART_DIRECTION §3-§4: flat-shaded materials, "no textures except an optional subtle noise on
the ground", one directional light, ink outline, glow for the player core and hostile shots only.

**How the stills were made** (build `8fbf0d10`, the owner's PC, Godot 4.7.2, Forward+, 1600 x 900, off screen):

```
godot --path . --position -10000,-10000 --audio-driver Dummy --resolution 1600x900 \
  -s scripts/shots/style_audit.gd -- boss=<id> biome=<biome> out=<main checkout>/build/style_audit/<id>
godot --path . --position -10000,-10000 --audio-driver Dummy --resolution 1600x900 -s scripts/shots/<judge_time|siege_fight|forge_fight|warlord_fight|lens_fight>.gd
godot --path . --position -10000,-10000 --audio-driver Dummy --resolution 1600x900 -s scripts/shots/enemy_looks.gd -- biome=<biome> look=now
```

- `scripts/shots/style_audit.gd` (new, this commit): one still per ordinary attack at its most visible moment, in the
  real game view (WorldViewRoot + HUD, JudgeLab's walled 24 m room) at the **game's own camera size (17 m)**, the boss
  hushed and still (SHOT HELPER) and each attack started by hand on a fresh world, a tick a frame so the pack effects
  play in their own time. Biomes: the Judge on Starfall, the Siege Engine on Night Rocks, the Foundry on Red Canyon, the
  Warlord on Ruins, the Hive Lens on Frozen Shore (biomes are shuffled per run, so any boss can meet any of them).
- The reworked mechanics (`2x` stills) come from the fight scripts as they are; they frame wider than the game (the
  Judge 21 m, the others 26 m), so those effects read a little smaller than in play. They draw the Siege Engine on
  Night Rocks and the Foundry, Warlord and Lens on Red Canyon.
- Baseline for "the game's look": each boss room's walls and floor in the stills, and `enemy_looks.gd look=now` per
  biome (worktree `build/shots/v0.10.5/enemy_looks/`).
- Stills: `C:/Users/extri/Desktop/zerodepth/zero-depth-v090/build/style_audit/<boss_id>/` (gitignored). "—" in the
  Still column: that moment was not captured (named per row).

## Shared across all five (fix once, every boss gains)

| # | Mechanic / attack | What draws it (file, pack row / scene) | Still | Verdict | What is off | A slight change that would fit | Size |
|---|---|---|---|---|---|---|---|
| X1 | Every boss's windup glow | `BossAvatar` `glow_overlay` (a red material overlay over the whole body, alpha by windup) | `clockwork_judge/02`, `04`; `warlord/02`-`05` | out of place | The whole model turns a glossy dark red for every windup. The Judge loses its black-and-gold, the Warlord becomes a red silhouette, the Siege Engine a red blob. It reads like plastic or a debug highlight, not like a flat-shaded figure. | Limit the glow to a rim or a small emissive part (the clock face, the visor, the mortar tubes), or tint toward the boss's own accent colour at low alpha. Keep the body's flat colours. | S |
| X2 | Signature-pattern shield (Turret Cross, Shield Wall, Prism Spiral, Slag Fountain) | `boss_shield_view.gd` (a code-made faceted shell in the boss's colour) | `siege_engine/01`, `warlord/01`, `hive_lens/01`, `foundry/01` | slightly off | At game zoom it reads as a flat translucent octagon pasted over the boss (orange, pink, beige), hiding the model. It has no ink edge and no facet shading. | Draw it as a few separate faceted crystal plates with the ink outline, or as a thin rim only, at lower alpha so the model shows. | M |
| X3 | Weak-point core (open after a pattern) | `BossAvatar` weak point (a glowing core on the chest) | `clockwork_judge/07`, `foundry/06`, `07`, `hive_lens/07`, `22` | slightly off | A cream disc with a crack, like a 2D icon or eye stuck on the chest. It does not sit in the model's light. | A small faceted gem or a glowing seam in the model's own accent colour, with the ink outline. | S |
| X4 | Ground textures of the attack markers (`BossStrikeLooks.PATTERN_TEX`) | `tex_mark_hazard` (Siege), `tex_mark_light` (Judge, Lens), `tex_mark_steel` (Warlord), `tex_lava_crust` (Foundry) on `MARK_SHADER`, with a white edge | see each boss | mixed | Painted photographic textures over the flat tiled floor. The hazard stripes are the worst (Siege rows). Steel scratches and light cracks are subtle and pass. The lava crust is busy but on theme. | See the Siege rows. For the others: lower `tex_body` so the floor's own colour shows under the hot part. | S |

## The Clockwork Judge (Starfall)

| # | Mechanic / attack | What draws it (file, pack row / scene) | Still | Verdict | What is off | A slight change that would fit | Size |
|---|---|---|---|---|---|---|---|
| J0 | The model, idle | `clockwork_judge_avatar.gd`, `boss_clockwork_judge.glb` | `00_model` | fits | Black and gold automaton, ink-outlined. It fits Starfall. (In every other still it is red: X1.) | — | — |
| J1 | **Stopped gears** (phase 2+) | `judge_time_views.gd` (a code-made brass cog per wall, rising out of the floor) | `21_gears_field_copy_bell` | **out of place** | Flat mustard-yellow extruded half-cogs with blocky teeth. They look like cardboard cut-outs or debug geometry, much brighter and more saturated than the Judge's dark brass. Each one is a single flat colour with no bevel, hub or spokes, about the size of a wall, so it dominates the room. | Use the Judge's own palette: dark iron with a gold rim (`boss_clockwork_judge.glb` has a waist gear: reuse that mesh, scaled, or model one gear with a hub, spokes and chamfered teeth). Flat-shaded, ink outline. Sink it half into a crack in the floor, with floor-coloured debris as it rises (the amber slam's chunks) and as it sinks. | L (new mesh) / M (reuse the model's gear) |
| J2 | Gear Spiral (bullets) | Bullet pattern `gear_spiral*`, hostile orb look | `02_gear_spiral`, `03_gear_spiral_3` | fits | Yellow hostile orbs with dark edges and short trails, as ART_DIRECTION §3 wants. | — | — |
| J3 | The Echo (path markers, ghosts) | `judge_views.gd` (`ECHO_MARKER_SHADER` gear markers, a gold ribbon, golden ghosts, pack pulse) | `01_the_echo` | slightly off | Stacked white-gold rings and a white column, bloom-blown to white at game zoom. The clock-gear detail is lost in the glow. | Lower the emission so the gold reads as gold, not white. Thinner rings, the ghost at lower alpha. | S |
| J4 | Verdict, telegraph (pendulum + square) | `judge_views.gd` pendulum (a code-made rod and weight); square `cj_verdict` = LIGHT pattern (`tex_mark_light`) | `04_verdict_telegraph` | slightly off | The square is fine (gold cracks, white edge). The pendulum is a thin glowing pale-yellow rod and a flat glowing block: unshaded and glowing, so it reads as a UI line, not brass. | Give the pendulum the Judge's dark-iron-and-gold material, flat-shaded with ink. Keep only a hot seam on the weight. | S |
| J5 | Verdict, strike | `cj_verdict` strike `beam` (pack beam held as a column) | `05_verdict_strike` | out of place | A big white swirl of smoke or wisp over the square, bloom-blown. It looks like a realistic smoke column and hides the hero. | The pendulum's slam with the amber slam's ground crack and floor-coloured stone chunks thrown up from the square, plus a short gold flash. No smoke column. | M |
| J6 | Gavel Slam (telegraph and hit) | `cj_gavel` LIGHT pattern ring; strike `light_ring` = pack `bx_pulse_light` | `06_gavel_slam_telegraph`, `07_gavel_slam_hit` | slightly off | The telegraph (gold cracks in a ring) is fine. The hit is a bright gold pulse ring with sparkles: glowy, but short and in the Judge's colour. | Tone the pulse down. Add a ring of small floor-coloured chips kicked out (the amber slam's grit). | S |
| J7 | Time Wave cast | `judge_time_views.gd` dial (code) + `cj_cast` = `lift_area_vfx_04` | `08_time_wave_cast` | slightly off | A white-hot dial with tick marks under the Judge, bloom-blown, and the pack's lift area washing the model gold and transparent. | Draw the dial in dull gold on the floor (no emission, ink lines), and keep the rising area off the model. | S |
| J8 | Time Wave ring | `judge_time_views.gd` ring + `cj_pulse` = `pulse_area_vfx_04` | `20_time_wave_ring_orbs` | slightly off | A room-sized soft white-gold glow band with a starburst of rays. It is the brightest thing on screen and glows like a lens flare. | A thinner gold ring at lower emission, no rays, maybe a faint dust skirt in the floor's colour. | S |
| J9 | Hour orbs | `cj_orb` = `basic_area_vfx_04` over a code dial, a small clock above | `20_time_wave_ring_orbs`, `21_gears_field_copy_bell` | slightly off | The small clock over each orb is 3D, but at game zoom it reads as a flat white icon, like HUD. The dial under it glows. | Make the clock a small faceted 3D clock (a brass case with ink), or drop it and keep the dial. | M |
| J10 | Slow fields | `cj_field` = `ripple_area_vfx_05` in blue | `21_gears_field_copy_bell` | slightly off | A saturated blue swirl disc, close to the hero's cyan and brighter than the floor. | A cooler and darker blue at lower alpha, or a ring of faceted ice-glass shards at the edge. | S |
| J11 | Rewind (pale copy, the Bell's ring, the line) | `judge_rewind_views.gd`, `cj_pulse` | `21_gears_field_copy_bell` | fits | A pale translucent copy, a white ring and a thin line. Quiet and readable. | — | — |
| J12 | Rewind throw flash, the Judge's return, the Bell's Verdict squares | `judge_rewind_views.gd`, `cj_pulse`; squares as J4/J5 | — (not captured) | — | Not seen in a still. The squares use the J4/J5 look, so J5's change applies to them. | — | — |
| J13 | HUD: slowed-attacks clock and pips | `Hud.attack_slow` | `22_hud_slowed` | fits | A small clock icon and pips in the HUD's own line style. | — | — |

## The Siege Engine (Night Rocks)

| # | Mechanic / attack | What draws it (file, pack row / scene) | Still | Verdict | What is off | A slight change that would fit | Size |
|---|---|---|---|---|---|---|---|
| S0 | The model | `siege_engine_avatar.gd` (the owner's model) | `00_model` | fits | Dark legs, a red hull, a long cannon, ink. In the attack stills it is an all-red blob (X1). | — | — |
| S1 | **Mortar Grid, telegraph and the rocks it leaves** | `se_mortar` = HAZARD pattern, texture `assets/textures/kit/tex_mark_hazard.png` (photographic yellow-and-black warning stripes, peeling paint, grime) | `02_mortar_grid_telegraph`, `03_mortar_grid_rocks` | **out of place** | This is the owner's "hazard looking textures". About 20 overlapping discs of road-marking stripes cover a third of the room. It is a photo texture (peeling paint, grime), saturated industrial yellow, nothing like the flat faceted floor or the night palette. Nothing else in the game uses stripes. | Replace the HAZARD texture with the STONE look the Gatekeeper uses (`fx_ground_cracks`: dark ground, glowing cracks), tinted to the Engine's red-orange `SiegeLooks.DANGER`. Or a plain dark scorch with a hot rim. Either way the floor's own colour shows through. One line in `PATTERN_TEX` / `LOOKS`. | S |
| S2 | Barrage, telegraph | same HAZARD pattern | `04_barrage_telegraph` | out of place | The same stripes on each circle. | As S1 | S |
| S3 | Rail, telegraph | `se_rail` = HAZARD pattern on a lane | `06_rail_telegraph` | out of place | A striped road-marking strip from the Engine to the hero. | As S1 (cracks along the lane, like the Gatekeeper's shock lanes) | S |
| S4 | Shockwave, telegraph (room-wide in phase 3) | `se_shock` = HAZARD pattern, over the whole room outside the Engine's circle | `11_shockwave_telegraph`, `21_cover_shadow_shockwave` | **out of place (the worst)** | For 2 s the whole room is yellow-and-black stripes, walls included. It is the loudest thing in the five fights, and with the teal cover shadows (S11) the room stops looking like the game. | As S1, plus: a room-wide warning should be quieter than a local one: a dark floor wash with the cracks glowing only near the Engine and a moving edge. | S |
| S5 | Turret Cross (bullets + shield) | pattern `siege_turret_cross`; shield X2 | `01_turret_cross` | slightly off | The bullets are fine (yellow-orange orbs). The orange shield octagon (X2) hides the model. | X2 | — |
| S6 | Mortar / barrage shell impacts | strike `shell` → `fx.burst(&"fire")` (pack fire burst; the Mortar Grid hides its Smoke) | `05_barrage_impact` | out of place | A white-orange fireball dome with spark lines, bloom-blown. | The amber slam: floor-coloured stone chunks and grit, a ground crack, a short dull orange flash, no fireball. | M |
| S7 | Rail, fire | strike `rail` (pack beam, held) | `07_rail_fire` | slightly off | A glowing gold-white beam with a smoky gold core, glowy but short. It reads as a cannon beam. | Lower the emission, a dull orange core, and a line of chips kicked up along the lane. | S |
| S8 | Deploy (turrets spawn) | strike `shell` for the spawns | `08_deploy` | slightly off | A white puff dome and an orange flash where each turret drops. | A dust ring in the floor's colour and a few chips as each turret lands. | S |
| S9 | **Target Lock shell landing** | `siege_field_views.gd`: `se_shell` = `mprojectile_javelin_vfx_01` streak, then `se_blast` = `vfx_explosion_02` | `09_lock_shell_lands` | out of place | A huge bloom-white dome over the hero's circle: the explosion's core at full white. | As S6: the amber slam's debris (it is literally a shell into rock, and a rock rises there). | M |
| S10 | Boulder rising | `siege_field_views.gd` (the kit's `rock_large` stretched to 3 x 1.1 m) under `se_blast`'s smoke | `10_lock_boulder_risen`, `20_target_lock` | **out of place** while the blast plays; the rock itself **fits** | One second after landing, a big orange-brown "cookie" of realistic billowing smoke and fire hides the rock. Once it clears, the boulder (the kit rock, ink, night blue) fits well. | Hide the explosion's Smoke and Core (as step 25 did for the amber slam) and let the rock rise out of a crack with floor-coloured chunks. | S |
| S11 | Cover shadow and the hero's ring | `siege_looks.gd` `SHADOW_SHADER`, `HALO_SHADER` (teal `#5CE6E0`) | `21_cover_shadow_shockwave` | slightly off | Flat bright-teal wedges with hard bright edges. They read as 2D overlay polygons. Teal is close to the hero's cyan. | A darker, desaturated cool wash (a real shadow tone, like the boulder's own cast shadow) with a faint rim. Keep the readable shape. | S |
| S12 | Target Lock reticle | `siege_looks.gd` `RETICLE_SHADER` (`DANGER` red-orange) | `20_target_lock` | fits / slightly off | A clean red reticle with ticks, a bit neon but small and readable, the clearest lock in the game. | Optional: a touch less saturated. | S |
| S13 | Ammo cart, its rail and the blast circle; the Doom countdown ring | `siege_cart_views.gd`, `SiegeLooks` code-made wagon; `se_cast` = `lift_area_vfx_02`, `se_doom` = `pillar_area_vfx_02` | `22_ammo_cart_doom_ring` | out of place | The cart is a code stand-in: a dark box with three glowing red stripes, like debug geometry. Its rail is a thin neon pink laser line. The blast circle has pale dashed stripes. The Engine's countdown ring is a saturated red neon ring. | A small faceted wagon model (kit crate + wheels, wood/iron, ink). The rail as dark ruts in the floor. The blast circle as a plain dull ring. The countdown ring at lower emission. | L (cart model) / S (rest) |
| S14 | Doom Shell landing, cart blast, boulder crumble and shatter | `se_doom` pillar, `se_blast` explosion_02, `siege_field_views.gd` crumble | — (not captured) | — | Not seen in a still. They use the same `se_blast` explosion as S9/S10, so the same change applies. | As S9 | — |
| S15 | Stripped armour (vulnerable read) | `boss_vulnerable_views.gd`, the bar's gold shimmer | `23_stripped_vulnerable_read` (shown on the Gatekeeper) | fits | A gold ring of light round the feet and a small halo ring. Quiet. | — | — |
| S16 | Shockwave hit | strike `shock_ring` = `bx_pulse_shock` | `12_shockwave_hit` | slightly off | Concentric pale smoke rings across the room, soft and wispy, more realistic than the floor. | Fewer rings and a dust colour taken from the floor. | S |

## The Foundry (Red Canyon)

| # | Mechanic / attack | What draws it (file, pack row / scene) | Still | Verdict | What is off | A slight change that would fit | Size |
|---|---|---|---|---|---|---|---|
| F0 | The model | `foundry_avatar.gd` | `00_model` | fits | A dark forge body with a glowing grate. On Red Canyon it nearly disappears into the red floor (a readability note, not style). | — | — |
| F1 | Slag Fountain (fireballs + shield) | fireballs (one orange-red look); shield X2 | `01_slag_fountain` | slightly off | Each shot is a fireball sprite with flame wisps and a sprite trail, busier than the clean yellow hostile orbs elsewhere. The beige shield octagon (X2) hides the model. | Keep the fireball core, drop the wisp sprites; X2. | S |
| F2 | Furnace Waves | pattern `foundry_furnace_waves` | `02_furnace_waves` | fits | Rows of small orange orbs with dark edges. | — | — |
| F3 | Molten Flood (telegraph, active lanes) | `fd_molten` = MOLTEN pattern (`tex_lava_crust`, flowing), strike `molten` | `03_molten_flood_telegraph`, `04_molten_flood_active` | slightly off | Busy painted lava-crust texture in strips with a white edge. On theme, but it is a texture, brighter than the canyon's flat tiles. | Lower `tex_body` so the floor's colour shows. Fewer, larger crust plates. A dull edge in place of the white. | S |
| F4 | Vent Blast (telegraph, hit) | `fd_vent` MOLTEN ring; strike `steam_ring` = `bx_pulse_steam` + `bx_smoke_thin` | `05_vent_blast_telegraph`, `06_vent_blast_hit` | out of place (the hit) | The telegraph is fine. The hit is a ring of realistic white smoke puffs and orange flame shreds: particle soup. | A ring of floor-coloured stone chunks and grit thrown out (the amber slam's), one short orange flash, a thin steam wisp at most. | M |
| F5 | Bomb Launch (drones spawn) | `fd_bombs` strike `shell` (`fx.burst(&"fire")`) at each drone | `07_bomb_launch` | out of place | Each spawn is a sprite-burst of white and orange specks, noisy and photographic. | A small dust ring in the floor's colour as each drone drops. | S |
| F6 | Firestorm (lanes) | `fd_firestorm` MOLTEN pattern, strike `fire_lanes` | `08_firestorm_telegraph`, `09_firestorm_active` | slightly off | Seven crust-textured strips with white edges and a hot glow wash, as F3. | As F3 | S |
| F7 | **Meltdown** (the molten floor beyond the safe circle) | `boss_signature_views.gd` meltdown (lava shader with an owner texture slot, `WorldReader.boss_melts`) | `10_meltdown_telegraph`, `11_meltdown_active` | **out of place** | Everything beyond the circle is a flat, unshaded, opaque peach fill: no pattern, no light, no edge detail. It reads as a debug fill, and it hides the floor tiles and the walls' feet. (The shader has a texture slot; if the texture only failed to bind in this shot script, play may look different: check it in the playtest.) | Use the MOLTEN crust pattern (as the floods) at reduced brightness, or the Overpressure floor once that is fixed (F9). A dark crust edge with a hot rim at the safe line. | S |
| F8 | Forge plate, bomb ring | `forge_plate_views.gd`; `fo_forge` = `lift_area_vfx_03`, `fo_reach` = `rim_area_vfx_04`, `fo_bomb` = `magic_orb_flare_vfx_04` | `20_plate_bomb_ring` | fits / slightly off | The plate shell is faint and the ring is quiet. The bomb's flare is a small glowing orb. | — | — |
| F9 | **Overpressure (room-wide burning floor)** | `forge_slag_views.gd` / Overpressure floor glow | `21_overpressure_slabs` | **out of place** | The open floor is covered by large blotchy orange "clouds" noise, like a Photoshop clouds filter, saturated and soft-edged. It replaces the tiled floor and reads as a different game. | Keep the floor's tiles visible: a hot rim of light along each tile seam, or the MOLTEN crust cracks at low alpha, with a slow pulse; the heat-haze edge glow on the screen already says "burning". | M |
| F10 | Slabs | `forge_slag_views.gd` (a basalt disc with a cool blue rim); `fo_safe` = `rim_area_vfx_03` | `21_overpressure_slabs` | slightly off | Flat grey discs with a bright pale-blue neon rim. They read as UI target circles, not basalt. | A low faceted basalt plinth (the kit's rock or a hex prism, dark, ink outline) with a faint cool rim. | M |
| F11 | Scald gauge (HUD) | `Hud` thermometer | `22_scald_gauge_hud` | fits | A small dark thermometer in the HUD's line style. | — | — |
| F12 | Plate burst, slag drop, slab crumble, hero embers and flames | `fo_shards`, `fo_drop` (`fire_ball_05`), `fo_ember`, `forge_hero_views.gd` | — (not captured) | — | Not seen in a still. The slag drop is a pack fire ball; check it against F1 when the owner plays. | — | — |

## The Warlord (Ruins)

| # | Mechanic / attack | What draws it (file, pack row / scene) | Still | Verdict | What is off | A slight change that would fit | Size |
|---|---|---|---|---|---|---|---|
| W0 | The model | `warlord_avatar.gd` | `00_model` | fits | Dark armour, a red shield and spear, ink. Red during every windup (X1). | — | — |
| W1 | Shield Wall / Javelin Fan (bullets + shield) | patterns; shield X2 | `01_shield_wall`, `02_javelin_fan` | fits (bullets) | Small dark-edged javelin darts. The pink shield octagon is X2. | X2 | — |
| W2 | Great Javelin, telegraph | `TelegraphViews` lane (no look) | `03_great_javelin_telegraph` | slightly off | A flat translucent pink-red strip from the Warlord to the hero: plain geometry, the only untextured lane here. | Give it the BLADE look (`wl_spears`: steel scratches), as the spear lines have. | S |
| W3 | **Great Javelin landing** | `great_javelin_views.gd`: the pack's rock impact and dust once, a crack mark | `04_great_javelin_thrown` | **out of place** | Meant as a rock impact, it renders as a white-orange fireball with smoke, bigger than the hero. A thrown spear should not look like it explodes in flame. | The amber slam: the javelin sticks with a ground crack and floor-coloured chips and grit thrown up. | M |
| W4 | Shield Bash | `wl_bash` BLADE, strike `steel_arc` (pack slash) | `05_shield_bash` | slightly off | A pale white smear arc, soft-edged, like a 2D swoosh sprite. | A short dust arc in the floor's colour (as `gk_sweep`'s dust_arc) with a few chips. | S |
| W5 | Spear Lines / Spear Wall | `wl_spears` BLADE pattern; strike `spears` (faceted spears rising) | `06_spear_lines_telegraph`, `07_spear_lines_active` | fits | Faint steel scratches in the lanes, then rows of faceted ink-outlined spearheads out of the floor: the closest to the bar of all of the Warlord's. | — | — |
| W6 | Lunge (wind-up lane, end circle, burst) | `wl_lunge` BLADE + charge burst view (`charge_burst_views.gd`, explosion like the amber's before 25b) | `08_lunge_dash_windup`, `09_lunge_dash_burst`, `20_charge_lane_end` | slightly off | The lane (scratches) is fine. The end circle is a saturated red disc with hard stripes and a white glow edge. The burst is fire-and-debris along the lane. | Apply the step-25 amber slam (debris, crack, no fireball) to the Warlord's burst too: the same move, now drawn two ways. A duller end circle. | S |
| W7 | War Banner (cast, standing ring) | `warlord_looks.gd` code-made banner (a steel pole, red cloth, gold hem); `wl_banner_cast` = `lift_area_vfx_02`, `wl_banner_rim` = `rim_area_vfx_03` | `21_war_banner` | slightly off | The banner (pole + cloth) fits, small and flat-shaded. The 6 m circle is a big soft orange glow disc with a bright gold rim, the brightest thing on the floor. | A thin dull-gold rim and a faint ground tint. Drop most of the inner glow. | S |
| W8 | Javelin cage (fence, rim, the centre's warning) | `warlord_looks.gd` javelins (code-made shafts); `wl_fence` = `vfx_hit_07`, `wl_recall` = `vfx_impact_01` | `22_javelin_cage` | slightly off | The 28 javelins are thin black sticks (no head detail, no ink at that size). The rim is a saturated red neon ring with a concentric red glow in the centre. | Reuse the faceted spearheads of the spear lines (W5) for the cage's javelins. A duller rim. | M |
| W9 | Banner burn and snap, the cage's recall flight and impact, the fence spark | `wl_snap`, `wl_recall`, `wl_fence`, `wl_rage`, `wl_hand` | — (not captured) | — | Not seen in a still. | — | — |

## The Hive Lens (Frozen Shore; the fight script on Red Canyon)

| # | Mechanic / attack | What draws it (file, pack row / scene) | Still | Verdict | What is off | A slight change that would fit | Size |
|---|---|---|---|---|---|---|---|
| L0 | The model and its drones | `hive_lens_avatar.gd`, `lens_drone_avatar.gd` | `00_model` | fits | Violet stone body, ink, flat-shaded. Its Frozen Shore stills are the closest to the bar of the five bosses. | — | — |
| L1 | Prism Spiral / Petal Bloom (bullets + shield) | patterns (pink orbs); shield X2 | `01_prism_spiral`, `02_petal_bloom` | fits (bullets) | Pink dark-edged orbs. The pink shield octagon is X2. | X2 | — |
| L2 | **Gaze (the sweeping beam)** | the Gaze beam (pack beam) | `03_gaze_windup`, `04_gaze_sweep` | **out of place** | A saturated neon pink-white laser with a bloom-white blob where it hits the wall and a brown scorch strip along the wall top. The most "neon" effect of the five. | A thinner, rose-violet beam at lower emission (the Lens's own colour), and on the wall a small burst of floor- or wall-coloured chips instead of the white blob. | S |
| L3 | Focus Beam (telegraph, fire) | `hl_beam` = LIGHT pattern; strike `beam` (pack beam, held) | `05_focus_beam_telegraph`, `06_focus_beam_fire` | out of place (fire) | The telegraph (a gold-crack strip) is fine. The fire is a column of realistic white smoke or wisps with a bloom wash. | A rose-gold beam core with a line of glass-like faceted shards along the lane (it leaves burnt glass in phase 3). No smoke. | M |
| L4 | Lens Flare | `hl_flare`, strike `light_ring` = `bx_pulse_light` | `07_lens_flare` | slightly off | A gold pulse ring, glowy, as J6. | As J6 | S |
| L5 | Dive | `hl_dive` LIGHT pattern; strike `light_burst` = `bx_pillar_light` | `08_dive` | fits | Gold cracks on the landing circle, quiet. | — | — |
| L6 | Split (drones) | `hl_split`, strike `light_burst` | `09_split` | fits | A pink glow round the Lens and the drones landing. | — | — |
| L7 | Feeding threads, shield rings, the bar's pips | `lens_feed_views.gd`; `hl_thread` = `beam_vfx_05`, `hl_layer` = `rim_area_vfx_03`, `hl_glow` = `magic_orb_flare_vfx_04` | `20_drones_feed_beam` | slightly off | The threads are fine (thin and dim). The Lens's feeding glow is a soft magenta bloom aura. | Lower the aura's emission. Keep the rings. | S |
| L8 | Lattice strands | `lens_lattice_views.gd`; `hl_strand` = `beam_vfx_05` (pink), `hl_orbit` = `m_projectile_basic_vfx_05` | `21_lattice` | slightly off | Thick bright pink-white neon beams, white-cored, as L2. | The same lower-emission rose as L2. Keep the width (it is the hit area). | S |
| L9 | **Burnt glass** (phase 3) | `lens_lattice_views.gd` / glass strips; `hl_sizzle` = `smoke_thin_vfx_01` | `22_burnt_glass` | out of place | Hot-pink glittery strips (a sparkly noise texture) with tall realistic white smoke plumes. | Faceted dark glass shards lying along the strip (flat-shaded, ink, a rose glint on the facets). A faint heat shimmer at most, no smoke plumes. | M |
| L10 | Strand touch spark, beam cut burst, drone death flash | `hl_spark`, `hl_cut`, `hl_flash` | — (not captured) | — | Not seen in a still. | — | — |

## Ranked: the most out of place first (all five bosses)

1. **Siege Engine: the hazard-stripe telegraphs** (S1-S4; the room-wide Shockwave S4 is the worst). A photographic
   road-marking texture (`tex_mark_hazard.png`) on every Siege marker. Swap the HAZARD look for the STONE crack look
   tinted to the Engine's red-orange. **S**, one table row in `BossStrikeLooks`.
2. **Clockwork Judge: the stopped gears** (J1). Flat mustard cardboard cogs the size of a wall. Rebuild them from the
   Judge's own gear (dark iron and gold, ink, hub and spokes) and rise them out of a crack with floor-coloured debris.
   **M** (reuse the model's gear) or **L** (new mesh).
3. **Every boss's red windup glow** (X1). The whole model turns glossy red for every attack, so every boss loses its
   colours in the moments the player looks at it most. **S**.
4. **Foundry: Overpressure's clouds floor and Meltdown's flat peach fill** (F9, F7). Both replace the tiled floor with
   something from another game: blotchy noise, or a flat debug fill. **S** (Meltdown) / **M** (Overpressure).
5. **Fireball explosions where stone should break**: the Siege shells and the Target Lock landing (S6, S9, S10), the
   Warlord's Great Javelin (W3), the Foundry's Vent Blast (F4), the Verdict's smoke column (J5). Each is the place the
   amber slam's debris (step 25b: pack `vfx_explosion_07` with Core, Smoke and Dust hidden, chunks in the floor's
   colour) fits directly. **M** each, the same recipe.
6. **Hive Lens's neon pink beams and burnt glass** (L2, L8, L3, L9): saturated laser beams with bloom-white impacts,
   smoke plumes on the glass. Lower the emission to the Lens's rose; glass as faceted shards. **S/M**.
7. **The Siege cart** (S13): a code-made box with glowing stripes on a neon pink rail. A small faceted wagon model.
   **L** (the model) / **S** (the rail, the rings).
8. **The signature-pattern shield octagon** (X2): a flat translucent polygon hiding every boss during its pattern.
   **M**, shared.
9. Smaller glow trims (S each): the Judge's echo, cast dial and Time Wave ring (J3, J7, J8), the cover's teal wedges
   (S11), the Banner's glow disc (W7), the cage's black sticks (W8), the slabs' neon rims (F10), the floating clock
   icons (J9), the weak-point disc (X3).

**What already fits** (keep as they are): the hostile bullets of all five; the Warlord's spear lines; the Siege boulder
itself and its Target Lock reticle; the Lens's model, drones, Dive and Split; the Judge's Rewind copy; the Gear Spiral;
the HUD pieces (the slowed-attacks clock, the scald gauge). Nobody has watched any of this move: these are stills;
the owner's playtest is the judge of motion.

# Boss style audit, part B (read + stills only)

The owner, 2026-11-18: find what in each boss's mechanics and animations "doesnt really look like the games looks"
and could be reworked to fit. Part B covers the Gatekeeper, the Brood Mother, the Lantern Shade, the Tidecaller, the
Twin Wardens and the final bosses (the Colossus, the Prism, The Fallen in the Hollow arena). No game file changed.

**The model of what fits:** the amber Warden's charge-end slam (`GroundSlamViews`, step 25b): faceted, flat-shaded
stone chunks and grit in the floor's own colours, dark ink outlines, lit by the stage's light; no fire, no glow, no
light of its own, a short low dust kick, cracks that fade within a second. Judged against it and against the
biomes' normal rooms (`build/enemy_looks_v2/*_game_new.png`: muted floors, hard shadows, ink lines, glow kept for
the hero's core and hostile shots).

## How the stills were made

- Base `169669cf` (`lead-v0120`), worktree `wt-sb`, branch `v0120-style-b`, owner's PC (RTX 3060), Godot 4.7.2.
- New tool `scripts/shots/style_audit_b.gd`: every attack of each boss run alone in the real game view
  (`WorldViewRoot` with the biome's mood, look and palette, the HUD, the 17 m game camera unless noted), the world
  stepped one tick per frame at `--fixed-fps 60` so pack effects play at their own speed; the boss's own picks hushed,
  the boss standing still. Each file is two frames side by side: left, three quarters into the windup (the marker);
  right, just after the strike (the effect), unless the row says other ticks.
  ```
  godot --path . --position -10000,-10000 --audio-driver Dummy --fixed-fps 60 -s scripts/shots/style_audit_b.gd \
    -- out=C:/Users/extri/Desktop/zerodepth/zero-depth-v090/build/style_audit
  ```
  Exit 0, 51 files. Re-runs with `only=` for seven cells whose first timing missed the strike (exit 0).
- Rooms: regular bosses stand in `JudgeLab`'s walled 24 m room, so the HUD top line reads "Wave 1 / 0, Enemies
  left" (a lab artifact, not what the boss room shows). Biome looks used (the run shuffles biomes; one each):
  Gatekeeper Ruins, Brood Mother Night Rocks, Lantern Shade Starfall, Tidecaller and Twin Wardens Frozen Shore.
  Final bodies: `FinalLab`/`NemesisLab` in the Hollow arena (The Fallen on a Gun run holding four wand cards). The
  Tidecaller's Crossing Waves start only with its streams (a started `crossing_wave` attack errors in a view), so
  that cell runs the streams instead (`03_streams_and_waves.png`).
- Set pieces from the existing scripts, run from `wt-sb` (`--position -10000,-10000 --audio-driver Dummy
  --resolution 1600x900`, each under `timeout 300`), copied into the still folder: `warden_fight.gd`,
  `fallen_remembered.gd`, `fallen_theft.gd`, `nb_lantern_shade.gd`, `boss_signatures.gd`, each exit 0.
- **`scripts/shots/tide_dance.gd` is broken since the
  Tidecaller's turn-taking (step 4c):** its first shot saves, then it loops `Invalid access to property or key
  'centre'` at line 150 forever (the High Tide never comes as it expects). High Tide and Maelstrom stills: NOT YET RUN.
- Still folder: `C:/Users/extri/Desktop/zerodepth/zero-depth-v090/build/style_audit/<boss>/` (gitignored).

## Shared effects (judged once here, referenced below)

| Id | Effect | What draws it | Bosses it touches | Verdict | What is off | A slight change that would fit | Size |
|---|---|---|---|---|---|---|---|
| S1 | **Stone marker: glowing lava cracks** | `BossStrikeLooks.PATTERN_TEX[STONE]` = `fx_ground_cracks.png` (bright orange lava veins) on every STONE marker; `BossStrikeFx.crack_mark()` leaves the same texture as the floor mark after craters, eruptions, javelins | Gatekeeper (fist slam, sweep, shock lanes), Colossus (fists, leap, boulders, spike chase/burst), Twin Wardens (overhead, charge/rift lane, bash, ground slam), Warlord and Siege craters (part A) | **out of place** | Saturated molten veins on every biome, also on snow and on the Hollow's violet stone; reads as a lava texture pasted on the floor, not as the floor cracking. The slam it should match has dark ink cracks, no glow | Keep the marker's dull/bright lock edge (the dodge cue) but swap the fill to the slam's own dark crack lines (`GroundSlamViews` CRACK colour) over a faint darkening of the floor colour; heat only in the last few ticks before the strike if at all | S (texture/colour) to M |
| S2 | **Crater / eruption burst** | `BossStrikeFx` crater, crack_impact, eruption: pack `bx_impact_a`/`bx_impact_b` tinted warm (`_warm(glow)`) + `bx_smoke_big` + light | Gatekeeper fist slam, Colossus leap/boulders/spike chase, Brood Mother leap and burrow, Tidecaller undertow, Twin Wardens ground slam | **out of place** | An orange fireball-and-smoke explosion with a warm light; on the Tidecaller it is tan rock on snow, on the Brood Mother orange sparks on green acid. The exact thing step 25b replaced for Amber | Route these discs through `GroundSlamViews` (chunks + plates + grit in the floor colour, cracks); per boss only the tint changes (acid splash for the Brood Mother, spray for the Tidecaller, see their rows) | M |
| S3 | **Tall dust column** | `bx_smoke_big` (dithered grey smoke, DUST_LIFE_S 1.1 s) in craters and arcs | Colossus fists, spike chase, boulders; Gatekeeper sweep | slightly off | A head-high dithered grey column, realistic smoke | The slam's low flat dust kick (0.35 s) instead | S |
| S4 | **White dust puffs on spike rows** | `StoneSpikeViews` lane strike dust (pack puffs) | Gatekeeper shock lanes, Colossus spike chase/burst, quake shatter | slightly off | Round white cotton puffs along each row, brighter than the floor | The slam's grit in the floor colour, smaller and lower | S |
| S5 | **Boss shield shell** | `BossShieldView` (translucent faceted dome in the boss colour while a signature pattern fires) | Gatekeeper (beige), Brood Mother (green), Tidecaller (teal), Twin Wardens (violet dome on the resting Warden), Prism (red) | slightly off; **out of place on the Prism** | A large flat translucent hull; on the Prism it is a solid pink-red block that hides her model most of the fight | Thinner: rim-lit facet edges with the inside nearly clear, alpha down; Prism's at half the opacity | S |
| S6 | **Void marker (violet lightning squiggles)** | `BossStrikeLooks` Pattern.VOID code rifts | Lantern Shade snuff/sweep, Twin Wardens rune ring/blink/shadow swords, The Fallen slash/cast lanes | slightly off | Neon electric squiggles; read as lightning, not shadow | Dark violet smoke-stain or cracked dark stone, same lock edge | S |
| S7 | **Light pillar / light pulse** | `bx_pillar_light`, `bx_pulse_light` tinted | Lantern Shade snuff (pillar) and sweep (pulse), Twin Wardens blink (pillar) and rune ring (pulse), Prism kneel (pillar) | slightly off | Holographic glowing cylinder / neon rings with gold sparkle; bloom-heavy | Shorter, dimmer, less additive; the ring as a floor wave of darker violet with a thin bright edge | S |
| S8 | **Ember-rock shots** | `FireballViews` look `ember_stone` (glowing rock core, flame trail) | Gatekeeper rock rings, Colossus boulder shards and the leap's ring | slightly off | A field of little fireballs with smoke trails; glow on hostile shots is the rule, the fire trail is not | Keep the bright core, drop the flame/smoke trail for a short dark streak; dark faceted rock skin wider | S |

## Gatekeeper (Ruins)

Mechanics (`data/bosses/gatekeeper.tres`): Rock Rings (+4-ring variant), Fist Slam (1-3 marks), Shock Lanes (+follow,
+2), Sweep; phase 2-3 quake pillars with pulsing rings, shattered by its own Shock Lanes; shield while ringing.

| # | Mechanic / attack | What draws it | Still | Verdict | What is off | A slight change that would fit | Size |
|---|---|---|---|---|---|---|---|
| 1 | Rock Rings | `FireballViews` `ember_stone` (S8); `BossShieldView` beige dome (S5) | `gatekeeper/01_rock_rings.png` | slightly off | Glowing fireball rocks with flame trails; dome hides the model | S8, S5 | S |
| 2 | Fist Slam | `TelegraphViews` + STONE pattern (S1); strike `BossStrikeFx` crater (S2) | `gatekeeper/02_fist_slam.png` | **out of place** | Lava-crack disc, then an orange explosion with smoke on sand | The slam: `GroundSlamViews` at the mark's radius in Ruins sand | M |
| 3 | Shock Lanes | lanes: STONE pattern (S1); spikes: `StoneSpikeViews` (`stone_spike.glb` MultiMesh, red-hot veins `HOT`, hot light flash) + dust puffs (S4) | `gatekeeper/03_shock_lanes.png` (ticks 100, 140) | slightly off | The spike model itself fits (faceted, ink, dark); the lanes are lava strips, the spikes glow red-hot, white puffs along the row | Lanes as S1; spike veins dark-red to no glow (the model in the floor stone colour, like the slam's chunks); S4 | S |
| 4 | Sweep | STONE arc (S1); `dust_arc` strike | `gatekeeper/04_sweep.png` | slightly off | Marker lava; the strike's translucent dust fan is mild and close to the slam's look | S1 only | S |
| 5 | Quake pillars (phase 2-3) + their shatter | `StoneSpikeViews` quake pillars; rings: pack `ring_fire` (`rim_area_vfx_04`) + `bx_pulse_shock`, `RING_COLOR` orange; shatter `bx_impact_a` hot (`_quake_shot`) | `gatekeeper/05_quake_pillars_shock_lanes.png` (22 m view; phase 2 entry, then the lanes aimed through a pillar) | **out of place** (rings), slightly off (pillars) | Concentric glowing fire rings round every pillar, the busiest orange in the Ruins; the shatter is the same warm explosion as S2; the pillars themselves (spike cluster) fit | Rings as a dark floor ripple with a thin bright edge only at the pulse; shatter through `GroundSlamViews` (exactly a rock pillar breaking) | M |
| — | Phase 2 entry (rock rings ×4 from the gate) | same as 1 | visible in 05 left | slightly off | the room fills with ember shots | S8 | S |

The model (`gatekeeper_avatar.gd`, stone golem in Ruins red-brown) fits.

## Brood Mother (Night Rocks)

Mechanics: Egg Storm (+5), Web Spiral, Leap (+chain), Burrow (+2), Brood (+4), Pounce Chain (phase 3); eggs on the
floor that hatch (signature); shield while a pattern fires.

| # | Mechanic / attack | What draws it | Still | Verdict | What is off | A slight change that would fit | Size |
|---|---|---|---|---|---|---|---|
| 1 | Egg Storm | ACID marker `tex_mark_acid`; landing `acid_splat` = `VfxLayer.burst(&"venom")`; dome (S5) | `brood_mother/01_egg_storm.png` (ticks 40, 120) | **out of place** | Neon lime cartoon splatter on the deep-blue Night Rocks floor; the brightest thing on screen | Darker olive-green acid pool, flat, with a few faceted egg-shell shards (the slam's chunk mesh tinted shell-white) | M |
| 2 | Web Spiral | `FireballViews` `acid_glob` | `brood_mother/02_web_spiral.png` | fits / slightly off | Glowing lime globs; readable hostile shots, a little neon | Glob core toward olive, trail drips shorter | S |
| 3 | Leap | ACID marker (photographic slime camouflage `tex_mark_acid`); landing `crack_impact` (S2, `bx_impact_b` warm) | `brood_mother/03_leap.png` | **out of place** | The marker texture reads like a photo of slime; the landing throws orange sparks | Marker: flat dark-green fill with the lock edge; landing: `GroundSlamViews` in the Night Rocks stone colour | M |
| 4 | Burrow | ACID marker; eruption (S2) + acid bits | `brood_mother/04_burrow.png` (ticks 120, 215) | slightly off | The eruption's glowing lime bits and warm light | Floor chunks (slam) heaved up as she breaks out; acid only as a thin wet sheen | M |
| 5 | Brood | ACID marker (small); `acid_splat` venom burst | `brood_mother/05_brood.png` (ticks 30, 90) | slightly off | Same neon splats where hatchlings come out | as row 1 | S |
| 6 | Pounce Chain | ACID marker; landing (S2) | `brood_mother/06_pounce_chain.png` | **out of place** | as row 3 | as row 3 | M |
| 7 | Eggs on the floor (signature), their burst | `BossSignatureViews` eggs (speckled egg, glowing veins, HP pips); burst = `acid_splat` | `brood_mother/07_eggs_sitting.jpg`, `08_eggs_burst.jpg` (`boss_signatures.gd`, which draws the old plain grey stage without a biome look) | fits (eggs) / slightly off (splat) | The pale green faceted eggs fit; the neon splat under them is row 1's | as row 1 | S |

The model (crimson spider) fits.

## Lantern Shade (Starfall)

Mechanics: Lights Out (+3), Wisp Bloom (+2, +3), Snuff (+3), Lantern Sweep; the dark, four edge lanterns to relight.

| # | Mechanic / attack | What draws it | Still | Verdict | What is off | A slight change that would fit | Size |
|---|---|---|---|---|---|---|---|
| 1 | Lights Out (the dark) | `ShadeViews` (full-screen dark pass, fog, the hero's light ring, lantern pools, dashed rings on out lanterns) | `lantern_shade/01_lights_out.png` (ticks 120, 260) | fits | The dark, the cool light ring and the dashed rings read cleanly | — | — |
| 2 | Wisp Bloom | `FireballViews` `shade_wisp` (MultiMesh, white star-shaped puffs) | `lantern_shade/02_wisp_bloom.png` | slightly off | White fluffy popcorn shapes, a 2D-sprite feel; brighter than the room | Small faceted pale-violet crystals (or dim orbs) with the dark edge every hostile shot has | S |
| 3 | Snuff | VOID marker (S6); `light_burst` = `bx_pillar_light` violet (S7) | `lantern_shade/03_snuff.png` | slightly off | Neon squiggles, then a holographic violet cylinder | S6, S7 | S |
| 4 | Lantern Sweep | VOID marker (S6); `light_ring` = `bx_pulse_light` (S7) | `lantern_shade/04_lantern_sweep.png` | slightly off | Lightning squiggles over the disc, a gold-lavender neon shockwave | S6, S7 | S |
| — | The held lantern under Lights Out | `LanternShadeAvatar` lantern glow | in 01 right | fits | a bright flare, intended (it is what you hunt) | — | — |
| 5 | The dark with lanterns lit, wisps near the hero | `ShadeViews` lanterns, warm pools, burn rings; wisp outlines | `lantern_shade/05_dark_lanterns.jpg` (`nb_lantern_shade.gd`) | fits | Warm lantern pools and the hero's cool ring read well in the room's ink style; up close the wisps are faceted pale flakes with ink, less off than at the game camera | — | — |

Model (dark red tendrils) fits.

## Tidecaller (Frozen Shore)

Mechanics: The Pull (+3), streams (Ring Stream, +3) with Crossing Waves, Undertow (+2), Shell Slam; the dance:
Riptide, High Tide, Maelstrom (turn-taking).

| # | Mechanic / attack | What draws it | Still | Verdict | What is off | A slight change that would fit | Size |
|---|---|---|---|---|---|---|---|
| 1 | The Pull | `TideViews` (pack ripple `vx7_tide_disc`, swell, bubbles); dome (S5) | `tidecaller/01_the_pull.png` | fits / slightly off | Soft painterly blue swirl rings over the whole room, a little smeary; palette right | Fewer, crisper ripple rings | S |
| 2 | Ring Stream | `FireballViews` `tide_bubble` | `tidecaller/02_ring_stream.png` | fits | — | — | — |
| 3 | Streams and Crossing Waves (run on their own) | `TideWaveViews` | `tidecaller/03_streams_and_waves.png` (24 m view, ticks 240, 420) | fits / slightly off | The wave is a thin cyan glowing streak, close to the hero's cyan and small | Lower, foam-white curl in the floor's blue-grey, no glow | S |
| 4 | Undertow | WATER marker (code caustics: neon sea-green cell net); `eruption` (S2: tan rock burst) | `tidecaller/04_undertow.png` | **out of place** | Glowing green net on snow, then a warm dirt-and-rock explosion | Marker: pale blue-grey ice cracks (the snow's own colour); eruption: the slam's chunks in ice/snow white with a short spray (pack `tc_splash`) | M |
| 5 | Shell Slam | WATER marker (S above); `steam_ring` (`bx_pulse_steam` + thin smoke) | `tidecaller/05_shell_slam.png` | slightly off | Marker the neon green net; the steam ring is soft and fits | Marker as row 4 | S |
| 6 | Riptide | `TideDanceViews` (water strips, pack `tc_rip_water`, wave walls) | `tidecaller/06_riptide.png` (from `tide_dance.gd`, warning stage) | fits | Pale water strips in the biome's blues, the dry strip bare | — | — |
| 7 | High Tide, Maelstrom | `TideDanceViews`, `MaelstromViews` | NOT YET RUN (`tide_dance.gd` broken, see top) | — | — | — | — |

Model fits.

## Twin Wardens (Frozen Shore)

Amber: Sword Combo, Sword Lane (chain sweep, +fast), Charge (+long), Rift Charge, Overhead, Ground Slam/Bash.
Violet: Crossfire (+3), Orb Volley, Rune Ring, Blink, Warden Bolt, Mirror Ward, Whole Ward, Shadow Swords. Domes on
the resting Warden.

| # | Mechanic / attack | What draws it | Still | Verdict | What is off | A slight change that would fit | Size |
|---|---|---|---|---|---|---|---|
| 1 | Sword Combo | BLADE marker `tex_mark_steel`; `steel_arc` | `twin_wardens/01_sword_combo.png` | fits | Faint scratched-steel fill and a pale arc | — | — |
| 2 | Sword Lane | BLADE lane; `TwinViews` white-hot slash | `twin_wardens/02_chain_sweep.png` | slightly off | The cut is a bloom-blown white lightning bolt | A thinner amber-white slash, less additive, with the slam's grit kicked up along it | S |
| 3 | Charge (end slam) | `ChargeBurstViews` → `GroundSlamViews` | `twin_wardens/03_warden_charge.png` (the run, not the slam); the slam is the reference | fits (reference) | The windup white-hot body flash is strong but intended | — | — |
| 4 | Overhead | STONE arc (S1); `dust_arc` + a few chunks | `twin_wardens/04_overhead.png` | slightly off | Lava cracks on snow; the strike is close to the reference | S1 | S |
| 5 | Rift Charge | STONE lane (S1) + red-orange danger circle with lava cracks (`ChargeBurstViews` circle, pack rim) | `twin_wardens/05_rift_charge.png` | **out of place** | A big glowing lava disc and lane on snow | S1; the end circle as a plain red ring with the slam's dark crack fill | S |
| 6 | Crossfire | `TwinViews` gold chevron lane and safe ring; `warden_violet_ember` shots | `twin_wardens/06_crossfire.png` | slightly off | The ring of shots is a carpet of flat lavender discs (2D-sprite feel); the gold lane fits | Smaller orbs with the dark edge, fewer drawn per ring | S |
| 7 | Orb Volley | violet orbs | `twin_wardens/07_orb_volley.png` | fits / slightly off | flat lavender discs, as 6 | as 6 | S |
| 8 | Rune Ring | VOID marker (S6); `light_ring` (S7) | `twin_wardens/08_rune_ring.png` | slightly off | S6, S7 | S6, S7 | S |
| 9 | Blink | VOID marker (S6); `light_burst` pillar (S7) | `twin_wardens/09_blink.png` | slightly off | S6, S7 | S6, S7 | S |
| 10 | Warden Bolt | `warden_violet_ember` (rendered orange-red here) | `twin_wardens/10_warden_bolt.png` | slightly off | An orange ember from the violet Warden | Tint it the violet body's colour | S |
| 11 | Shadow Swords | `WardenBladeViews` (dark blades, pack violet flare) + `tw_swords` VOID lines and a beam strike | `twin_wardens/11_shadow_swords.png` | **out of place** | The cut is a bloom-blown white-violet laser with four-point star sparkles | A dark violet blade slash (the blade itself flying the line), no beam; a dim edge | M |
| 12 | Resting Warden's dome | `WardenWardViews` (pack forcefield) | in every still; `twin_wardens/14_charge_windup_dome.png` | fits / slightly off | A clear amber/violet bubble; reads, a little glassy | S5's thinner rim | S |
| 13 | Mirror Ward | `WardenWardViews` (a curved wall toward the hero, pack `vx2_zone_ripple`) | `twin_wardens/12_mirror_ward_and_swords.png` (`warden_fight.gd`, 26 m view) | slightly off | A translucent sci-fi grid panel (hex-grid hologram) | A curved wall of faceted violet glass slabs, no grid | M |
| 14 | Whole ward + long charge (phase 3) | `WardenWardViews`, `ChargeBurstViews` circle | `twin_wardens/13_whole_ward_long_charge.png` | fits | Plain red rings and a thin lane; clean | — | — |
| 15 | Through the Rift (portals) | `WardenBladeViews` rifts (pack ripple, light pillar) | NOT YET RUN (the rift opens at 50 % HP, hushed in the tool) | — | — | — | — |

Models fit.

## Final bosses (the Hollow arena)

The arena's own look (dark violet stone, lit pylons) fits. In `style_audit_b.gd`'s final stills the weapon name runs
under "HP 1048576 / 1048576": the tool's held-up hero has a seven-digit HP; at real HP (`fallen_remembered.gd`'s
stills, "HP 160 / 160") the HUD lays out cleanly. Not a finding.

### Colossus

Mechanics: Fist Combo (+3), Leap Slam (+2, +3), Spike Chase (+2, +3), Spike Burst, Boulder Throw (+3).

| # | Mechanic / attack | What draws it | Still | Verdict | What is off | A slight change that would fit | Size |
|---|---|---|---|---|---|---|---|
| 1 | Fist Combo | STONE arc (S1); `dust_arc` + `bx_smoke_big` (S3) | `colossus/01_fist_combo.png` | **out of place** | Lava cracks on violet stone; a tall dithered smoke column | S1, S3 | S |
| 2 | Leap Slam | STONE disc (S1); crater (S2) + a ring of `ember_stone` shots (S8) | `colossus/02_leap_slam.png` | **out of place** | A ring of twenty fireballs plus an orange explosion: the busiest frame of part B | Landing via `GroundSlamViews` (scaled up), the ring shots as dark rocks (S8) | M |
| 3 | Spike Chase | small STONE discs (S1); `crack_impact` (S2, S3) | `colossus/03_spike_chase.png` | slightly off | Lava discs, smoke column | S1-S3 | S |
| 4 | Spike Burst | STONE discs (S1); `StoneSpikeViews` disc clusters (glowing crimson) + puffs (S4) + red light | `colossus/04_spike_burst.png` | **out of place** | Rows of glowing red spikes with white puffs and a red wash of light on violet stone | Spikes unlit dark stone of the arena, S4 | S |
| 5 | Boulder Throw | `BossShieldView` boulder (code-made sphere); STONE disc (S1); crater (S2, S3) | `colossus/05_boulder_throw.png` | **out of place** | In flight the boulder reads as a flat bright-red ball (debug geometry); the landing is a smoke column | A faceted dark rock (the slam's chunk mesh, big) with a thin red rim; land via the slam | M |

Model (crimson and white crystal) fits.

### Prism

Mechanics: the Cross (ring/spiral/flower variants: spin-up, rotating beams, shard volleys, the window), Crown
(ring/spiral/flower orb fans), Prism Bolt, Facet Lances, Shattered Kneel.

| # | Mechanic / attack | What draws it | Still | Verdict | What is off | A slight change that would fit | Size |
|---|---|---|---|---|---|---|---|
| 1 | The Cross (all three variants) | `PrismViews` (aim lines, beam cylinders + scrolling shader, floor burn, wall flare); shell (S5) | `prism/01_cross_ring.png` (ticks 150, 380), `02_cross_spiral.png`, `03_cross_flower.png` (150, 250) | **out of place** | Four huge bloom-blown pink-white beams wash the whole screen out; the window's gold ring is fine | Narrower beams, a solid core with a thin glow, no screen-wide bloom; her red crystal colour, not white | S-M |
| 2 | Crown orb fans | `FireballViews` `crown_orb` (`fx_orb_cores_final`, Flare hidden) | `prism/04_crown_ring.png` | slightly off | Flat glowing rune-discs, a 2D-sprite feel | Faceted gem orbs (the `prism_orb` look already does this) | S |
| 3 | Prism Bolt | aim strip (flat salmon strip, `TelegraphViews`); `crown_bolt` | `prism/05_prism_bolt.png` (ticks 24, 38: the bolt is gone by 38) | slightly off | The aim is a wide flat salmon band; a cyan ring at her feet (cyan is the hero's colour) | Thin aim line like the Cross's; ring in her red/gold | S |
| 4 | Facet Lances | `PrismLastViews` (facet glows, aim lines, lance beams) | `prism/06_facet_lances.png` | **out of place** | The facets are flat violet ovals floating in the air (debug-like 2D shapes) | Small faceted crystal shards (the Prism's own crystal mesh) | M |
| 5 | Shattered Kneel | `PrismLastViews` (gold ring, core flare, `bx_pillar_light`, `bx_shatter`, `bx_pulse_shock`) | `prism/07_prism_kneel.png` | slightly off | A bright yellow light column (S7) | S7 | S |
| — | Her shell | S5 | every Prism still | **out of place** | solid pink-red block over her | S5 | S |

### The Fallen (`nemesis`)

Mechanics: Combo, Crescents, Volley, Point Blank (mimic shots of the hero's weapon), card casts 1-3, Storm, Rush;
mimic windows; remembered mechanics (Time, Riptide, Quake, Ward) at its gates; the card theft (mark on its back).

| # | Mechanic / attack | What draws it | Still | Verdict | What is off | A slight change that would fit | Size |
|---|---|---|---|---|---|---|---|
| 1 | Combo / Rush | VOID arc (S6); `steel_arc` in void colours | `nemesis/01_combo.png` (ticks 30, 46), `08_fallen_rush.png` | slightly off | S6 squiggles; the arc fits | S6 | S |
| 2 | Crescents / Volley / Storm (Gun run) | lanes: flat salmon telegraph strips; shots `nemesis_crescent` | `nemesis/02_crescents.png`, `03_volley.png`, `07_fallen_storm.png` (the three look the same on a Gun run) | slightly off | The eight lanes are flat salmon bands (plain telegraph); the violet crescents fit | Thin lines or the void pattern at low alpha | S |
| 3 | Point Blank | same | `nemesis/04_point_blank.png` | slightly off | as 2 | as 2 | S |
| 4 | Card casts | `NemesisViews` (the card's name floating over its head, a red-orange sigil at its feet); lanes VOID; strike `light_burst` (S7) | `nemesis/05_card_1.png`, `06_card_2.png` | slightly off | **A text label** ("Split", "Fire") floats over its head through each cast: against the owner's no-text rule; the sigil is a bright red-orange glow disc | Drop the label (the sigil already tells); sigil in violet, dimmer | S |
| 5 | Mimic window | `NemesisViews` ring at its feet and the hero's | in 01, 08 left (a cyan-looking ring at its feet) | slightly off | Reads cyan, the hero's colour | Violet as the doc says | S |
| 6 | Remembered: Time (Judge's ghost) | `FallenRememberedViews` ghost + `bx_pillar_light` gold | `nemesis/09_remembered_time.png` (`fallen_remembered.gd`, 30 m view) | slightly off | A gold light column, the brightest thing in the dark arena (S7) | S7 | S |
| 7 | Remembered: Riptide | `TideDanceViews` strips in the round floor | `nemesis/10_remembered_riptide.png` | **out of place** | Frozen Shore's bright sky-blue water laid on the Hollow's dark violet stone: the whole floor turns light blue | Water in the arena's palette: dark teal-violet, the foam edges kept for the read | S |
| 8 | Remembered: Quake | `StoneSpikeViews` pillars (crimson glow) + the dash line white-hot | `nemesis/11_remembered_quake.png` | slightly off | Glowing red spikes, a white-hot streak | Spike glow as Gatekeeper row 3 | S |
| 9 | Remembered: Ward + Amber's shade | `WardenWardViews` dome, `ChargeBurstViews` circle, lane | `nemesis/12_remembered_ward.png` | slightly off | White-hot chevron lane, a saturated filled red disc and a bright dome together | Lane thinner, disc as the plain ring of row 14 above | S |
| 10 | Card theft | `FallenMarkView` (violet glow on its back, pips), HUD dark pip | `nemesis/13_card_theft.png` (`fallen_theft.gd`) | fits | Subtle violet mark; the taken card's pip dims on the HUD; no text | — | — |

**Lead not confirmed:** "The Fallen's meteor landing (`spell_fx.gd` ~557, `p10l_meteor_land`)": that is the hero's
Meteor spell (`SpellZones.METEOR_MARK` → `Spells.FX_STRIKE`); `boss_nemesis.gd`, `fallen_theft.gd` and
`nemesis_build.gd` cast no spell, so The Fallen never plays it. Not judged here.

## Top items across part B (most out of place first)

1. **Lava-crack markers and floor marks (S1)**: on every stone boss and every biome, including snow and the Hollow.
   One texture swap fixes Gatekeeper, Colossus, Twin Wardens (and part A's Warlord/Siege craters). S.
2. **Warm crater/eruption explosions (S2)** on Gatekeeper slam, Colossus leap/boulders, Brood Mother leap/burrow/
   pounce, Tidecaller undertow, quake-pillar shatter: route through `GroundSlamViews` with a per-boss tint. M.
3. **Prism's Cross beams and shell**: screen-washing bloom beams and an opaque red hull. S-M.
4. **Colossus Leap Slam and Boulder**: a ring of fireballs + explosion; a flat red ball as the boulder. M.
5. **Brood Mother acid**: neon lime splats and the photographic slime marker on Night Rocks. M.
6. **Gatekeeper quake rings**: concentric glowing fire rings round every pillar. M.
7. **Twin Wardens' Shadow Swords cut**: white-violet laser with star sparkles. M.
8. **Prism Facet Lances**: flat floating ovals. M.
9. **Spike glow and puffs (S4, spike veins)**: Gatekeeper lanes, Colossus spike burst. S.
10. **The Fallen's card-name label**: text over a boss mechanic (owner rule). S.
11. **Void squiggles and light pillars/pulses (S6, S7)**: Lantern Shade, violet Warden, The Fallen. S.
12. **Undertow / Shell Slam neon-green net marker** on Frozen Shore. S.
13. **The Fallen's remembered Riptide**: Frozen Shore's light-blue water flooding the dark Hollow floor. S.
14. **Mirror Ward**: a hex-grid hologram wall. M.

Fine as they are: Lights Out's dark and lanterns, the Riptide strips, the Ring Stream, the Sword Combo, the charge slam,
the whole ward, the card theft mark, the eggs, every boss model, the Hollow arena.

## A note for the lead

PD-13 (ART_DIRECTION §4.x: new effects start from a premade pack effect) and the reference the owner now likes
(`GroundSlamViews`: code-made faceted stone, no pack) pull different ways. Most fixes above mean using the slam
rather than a pack burst. That is an owner decision to write down before building them.

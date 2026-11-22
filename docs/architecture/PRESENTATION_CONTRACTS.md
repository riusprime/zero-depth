# Presentation contracts

How the game looks, reads and responds on screen. Presentation is everything under `src/presentation/`. It reads
the sim and never writes it (EI-07). Palette values live in [`../art/ART_DIRECTION.md`](../art/ART_DIRECTION.md);
this file holds the rules they must satisfy.

Numbers marked **starting value** are defaults to tune, usually at a G2 gate or an owner playtest.

## 1. Camera

- **Projection:** a `Camera3D` in `PROJECTION_ORTHOGONAL` with a fixed **45° yaw** and **no rotation** (PD-02).
- **Pitch:** picked by the owner from the v0.0.1 camera gallery. The candidates are 30°, 35.26° (true isometric)
  and 45°. Record the pick in [`LOCKED_DECISIONS.md`](LOCKED_DECISIONS.md) as a PD.
- **Framing:** the ortho `size` shows a whole room's width plus a margin. Rooms are 1–1.5 screens
  ([`../design/GAME_BLUEPRINT.md`](../design/GAME_BLUEPRINT.md) §G).
- **Follow:** the camera follows the player with a dead zone and a small look-ahead toward the aim point
  (**starting values**: dead zone 1.5 m, look-ahead 15% of aim distance, capped at 3 m). It is smoothed in
  `_process` and never affects the sim. Because it moves in `_process`, the camera node sets
  `physics_interpolation_mode = PHYSICS_INTERPOLATION_MODE_OFF`, so physics interpolation doesn't fight it.
- **Shake** is presentation only. It uses the `cosmetic` RNG stream, has an Options toggle and intensity slider,
  and is off under reduced motion.

## 2. Frame and interpolation

- `SimDriver` steps the sim in `_physics_process` at 60 Hz. Views then write each actor's `Node3D` transform from
  the sim state.
- Godot's 3D physics interpolation (`physics/common/physics_interpolation = true`, 4.4+) smooths those
  transforms between ticks. A view calls `reset_physics_interpolation()` when an actor spawns or teleports, so it
  doesn't streak across the room.
- A view that lays its pieces out on frame time (ticks plus the interpolation fraction, in `_process`), above all a
  pool whose slots change hands between frames (MultiMesh instances, pooled lights, decals), sets
  `physics_interpolation_mode = OFF`: interpolated, a re-used slot is drawn between two unrelated places for a frame
  (v0.8.0 N1: the fire sprites flashing across the screen, `evidence/N1_FIXES.md`).
- The **aim reticle** is drawn in `_process` from the live cursor or stick position, not from the last tick. Aim
  must feel instant even though the sim reads it at 60 Hz.
- **Frame budget** (**target**): 60 fps at 1080p on the owner's lowest-spec GPU, with the presentation stress
  scene at p99 ≤ 16.6 ms per frame. The bench lives in `scripts/bench/view_bench.gd` from v0.1.0.

## 3. Readability rules

The reference image ([`../art/ART_DIRECTION.md`](../art/ART_DIRECTION.md) §1) already shows where readability
breaks. The contrast figures below were computed from colours sampled out of the PNG. Each problem became a rule:

| Problem seen in the image | Rule |
|---|---|
| The white player against Frozen Shore snow is **1.16:1** | Every actor has a **contact ring** under it and a **rim outline** (the stencil outline mode in `BaseMaterial3D`, to be proved in the v0.0.1 occlusion gallery), both drawn in the biome's `outline` token. Each biome's `outline` must reach at least **3:1** against its `ground`. |
| The red enemies against Red Canyon ground are **1.21:1** | A **team ring decal** sits under every actor: cyan for the player, red for enemies. Team identity never relies on body hue alone. |
| The red barrels share the enemies' red in all four biomes | Hazard props never use the enemy colour token. They get their own `hazard` token and a distinct silhouette (a cylinder with a band). |
| Tall slabs hide actors from the iso view | **Occlusion cutaway** (§5). |
| Hard, long shadows fall across the floor | Telegraphs and pickups render **unshaded and above shadows**. A shadow can never hide a warning. |

- **Reserved colours.** Hostile-projectile yellow is used for hostile projectiles **only**. Player cyan is used
  for the player, their projectiles and their ring only. The palette test enforces both.
- **Shape language.** The player is a cube with a glowing core. Enemies are cubes and boxy variants, each with a
  distinct silhouette per behaviour. Cover is a slab or a rock. A hazard is a cylinder or a marked field. A
  behaviour must be identifiable in greyscale.
- **Health bars** float above actors (white for the player, red for enemies), as in the image, and also show in
  the HUD for the player. Bars never overlap the actor's body.

**Sealed arenas (v0.5.5 AR).** While an arena is sealed the rest of the floor goes dark (owner X1: "Others go dark
when sealed") as a separate layer (`ArenaViews`: an unshaded dark veil box over every other room, faded in and out);
the biome's lighting mood (sun, ambient, fog, SSAO, the kit's lights) is never written, so v0.5.9's look comes back
unchanged at the clear. The minimap keeps showing the whole layout and marks each arena (amber) once discovered.

## 4. Telegraphs

- Every enemy attack shows its area on the ground for its full windup. The windup is at least
  `MIN_TELEGRAPH_TICKS` (validated in content, [`CONTENT_SCHEMA.md`](CONTENT_SCHEMA.md) §3).
- A telegraph is an unshaded decal or mesh drawn after shadows. It has an outline at full opacity and a fill that
  grows from 0 to 100% across the windup, so the player can read *when* as well as *where*.
- The shape comes from the same sim function that resolves the hit (EI-07). The test
  `tests/unit/presentation/test_telegraph_parity.gd` checks that the drawn area equals the hit area for every
  attack shape.
- **No damage without a readable cause.** Every `DAMAGE` event against the player maps to a telegraph, a visible
  projectile, a visible field or a status icon. v0.1.0's exit gate tests this from the event log.
- **Body cues instead of ground marks** (owner, v0.7.5 N16 and v0.8.0 O4 / Q3, 2026-10-14: "only things landing at
  range"). Among normal enemies only the Arc Caster's rune and the Mine Layer's armed mines are drawn on the ground.
  Every other normal enemy's telegraph (the fireball casters' `cast` / `lob`; since v0.8.0 TG the Charger / Hatchling
  / Swarmer lanes, the Splitter / Splitling disc, the Shield Bearer's bash, the Warden's slam, the Sniper's line and
  the Needle's lanes) carries `"ground": false`: it keeps its shape and timing for the forecasts, the parity tests and
  the readable-cause check, and its avatar tells the windup (AvatarBase `tell_crouch` / `tell_glow`: a crouch that
  deepens with the progress, an accent glow that climbs and flashes over the last fifth, steady under reduced
  motion; the body faces the locked attack). Elites follow their kind; the bosses' markers are unchanged.
  `tests/unit/sim/test_enemy_ground_marks.gd` lists the ground marks per kind.
- **A boss attack whose tell is the body** (owner: no aiming line for the amber Warden's phase-1 charge). Its windup telegraph is `{"shape": &"signature", "ground": false, "run": Obb}` while `BossWardenAmber.flashing`: nothing is drawn on the ground, `WorldReader.boss_twin(i)["flash"]` (0..1000) is the tell (the body's white-hot flash), and `"run"` is the lane it will run, read only so `BossStrikeViews` draws the run on the sim's strike tick and the end circle's burst still shows. The ground-marker tests accept such an attack only if the body flashes.
- **Boss ground attacks in 3D** (v0.8.0 AV, owner O7). The Gatekeeper's shock lanes (a `row_lanes` marks telegraph,
  `TelegraphViews.is_cracked`) are drawn as cracked ground on the exact lane quads (a procedural crack shader, still
  unshaded and over shadows): faint glowing cracks under the dull outline while they track, charred ground with wide
  hot cracks that pulse under the bright edge once locked (steady with reduced motion). On the strike tick (the lanes
  marker shows locked at progress 1000, `BossDodge.mark_state` 2) `StoneSpikeViews` raises stone spikes along the same
  lanes; they sink back within 0.6 s. Drawn, never decided: the hit is the sim's, the spikes only follow it.
- **The other bosses' ground attacks in 3D** (v0.8.0 AV part 2, owner O7). Every boss ground attack has a look
  (`BossStrikeLooks`, per boss kind and move; a test derives the move list from `data/bosses`). Its marker keeps the
  dull outline and no fill while it tracks and the bright edge once locked (the lock flash stays the dodge cue), but
  its fill is a ground pattern in the look's colours instead of flat red (stone cracks, steel scratches, bubbling acid,
  shimmering light, hazard stripes, molten seams), burning hot and pulsing once locked (steady with reduced motion);
  an untracked windup's fill warms as it fills. `BossStrikeViews` draws the strike on the tick the sim strikes, read
  from WorldReader only: a marker or grid circle locked at progress 1000, a windup turning active (the hit resolves on
  that tick), a leap at `boss_leap` 1.0, a burrow when `boss_hidden` turns false; the geometry is the telegraph's.
  Sustained strikes (spears, beams, molten and burning lanes, a charge's skid) last while the boss stays active in
  that move. The Gatekeeper's shock lanes stay `StoneSpikeViews`'.
- **The Clockwork Judge's time mechanics** (v0.12.0; the sim: [`SIM_CONTRACTS.md`](SIM_CONTRACTS.md) §10n, §10o). Read
  from `WorldReader.boss_time`, `boss_pickups`, `boss_shot_fields` and `boss_attack_slow` only. `JudgeTimeViews`: the
  cast (a dial under the Judge whose hand goes round once, a closing ring, the pack's `cj_cast`), the wave's gold ring
  from the `time_wave` event, each hour orb (the pack's `cj_orb`, Basic Area 04, over a dial of the exact radius the
  hero must touch, a small clock above it; a running orb's hand and effect run down with `left`), each stopped gear (a
  cog over a strip of the wall's exact `centre` / `half` / `angle`, rising with `age` and sinking with `left`), each
  slow field (a cool disc of its radius under the pack's `cj_field`). `JudgeRewindViews`: the pale copy at `copy`
  (drawn through anything in front of it), the Bell's ring closing on it and the line from the hero while `bell` runs,
  a flash at both ends on `judge_rewind` and `judge_return`; what follows the copy hangs under `copy_parts`.
  `AttackSlowHud`: the share lost and a pip per orb's share won back, over the HP plate, while the cut is above 0.
  Hint arrows: `ObjectiveMarkers.JUDGE_ORB`, drawn as the pillars' arrow, no text. Every slot is built hidden at the
  view's start (the shader warm-up draws it); the pack rows are `data/vfx/pack_fx_cj.tres`. A hero shot inside a
  field needs nothing here: its views draw between its last two tick positions, which the sim already slows.
- **The Tidecaller's dance** (v0.12.0; the sim: [`SIM_CONTRACTS.md`](SIM_CONTRACTS.md) §10p). Read from
  `WorldReader.boss_dance`, `boss_hazards` and `objectives` only. `TideDanceViews`: each Riptide strip a floor quad
  of the reader's exact `strips` rectangle while a cast runs; the three `struck` fill with water rising with `warn`
  (the pack's `tc_rip_water` on each), the safe one stays clear inside a bright pulsing border; on the wave a wall of
  water (the crossing waves' band, `TideWaveViews.wave_mesh`, three times as tall) stands on `front` down each
  struck strip, the strip behind it flooded; `riptide_hit` bursts `tc_splash` on the hero. High Tide: a room-sized
  water plane rising through `cast` and full through `flood`, with a hole of the exact `radius` at `centre` (drained
  on `high_tide_end`); the dry circle a warm disc of that radius with a rim, the pack's `tc_dry`, and a ring that
  fills through the cast and shrinks with the flood's time left; a hero outside it in the flood is splashed each
  0.5 s step and the HUD shows the low-HP edge glow's look (`Hud.tide_flood`, `TideDanceViews.flooding`). The
  pack's `tc_cast` rises under the Tidecaller through a Riptide warning or a High Tide cast, and its avatar plays
  its ring stream's clip (bell_toll) or its Pull's (bell_raise) while no attack runs (`BossAvatar._side_clip`).
  `MaelstromViews`: four log-spiral arms on the floor round `centre`, wound at the sim's `inward` / `around` and
  turning the `spin` way, brighter toward the eye, with dashes pointing inward; the eye a dark core of radius `eye`
  with a bright rim (dim through `grace`) under the pack's `tc_eye`; `maelstrom_throw` a splash and a spray streak.
  Reduced motion stills the arms (the dashes and rings stay). The floor layers draw under every telegraph
  (`render_priority` -2). Hint arrows: `ObjectiveMarkers.TIDE_DRY`, drawn as the pillars' arrow, no text. The tide
  pools (data look `venom`) draw as water while the Tidecaller fights (`HazardViews`: the frost ring, then the
  pack's `tc_pool`). Sounds: `TideDanceCues`. The pack rows are `data/vfx/pack_fx_tc.tres`.
- **The Twin Wardens fight apart** (v0.12.0; the sim: [`SIM_CONTRACTS.md`](SIM_CONTRACTS.md) §10q). Read from
  `WorldReader.boss_wardens`, `boss_charge_bursts`, `boss_twin`, `telegraph`, `boss_hazards` and the `STATUS_APPLY`
  events only. Nothing is drawn between the two bodies (`TwinViews` keeps Crossfire's gap lanes and safe spot and the
  Sword Lane's slash). `ChargeBurstViews` (any boss whose charge bursts): a red-orange circle of the telegraph's
  `burst` radius at its `center`, dull while the aim tracks and flashing once `locked`, the pack's `tw_burst_rim` on
  it; an armed burst's circle stays put and fills with `progress`; when it goes the pack's `tw_burst`, sized to the
  radius. `WardenWardViews`: the resting Warden's dome (the pack's forcefield in its colour, `tw_dome_amber` /
  `tw_dome_violet`, each wearing its own material copy); the Mirror Ward a curved wall on the reader's `centre` /
  `half_arc` round the violet Warden (a sheet of violet light) with the pack's ripple at its foot, rising through the cast toward the hero and
  sinking over its last 0.3 s; `warden_reflect` the pack's hit where it struck, `warden_block` its pulse on the hero;
  the whole ward a larger brighter dome (`tw_dome_full`) and a floor rim; the charge's lane glowing under it,
  white-hot while `breaks`; on `warden_ward_break` the pack's shatter and stun flash, stars while `stun_left`, a
  ring filling to `return_in` and the pack's rising light for its last 2 s. `WardenBladeViews`: a dark blade over
  each sword's `from`, pointing down its line, flying it on `cut` with a slash and the pack's hit; the side dash an
  amber streak while `dash` runs; the rifts the pack's violet ripple at each `centre`, the exit's light pillar only
  while the reader marks it `exit`, its `lane` on the floor, a flash on `warden_rift_enter` / `warden_rift_exit` (the
  amber Warden sinks while `boss_hidden`). The swords' rifts (data look `venom`) draw violet while the Wardens fight
  (`HazardViews`: the pack's rim, then `tw_rift`). The bar's fill shimmers gold (`BossBarTones.VULNERABLE`) while the violet Warden is
  stunned. Hint arrow: `ObjectiveMarkers.TWINS_WARD`, drawn as the pillars' arrow, no text. Clips: the sword combo
  and the overhead play the files' swipe, the Mirror Ward and the Shadow Swords their cast (`OWNER_PLAYS`). Sounds:
  `WardenCues`. The pack rows are `data/vfx/pack_fx_tw.tres`.
- **The Siege Engine's cover and Doom Shell** (v0.12.0; the sim: [`SIM_CONTRACTS.md`](SIM_CONTRACTS.md) §10r). Read
  from `WorldReader.boss_siege`, `telegraph`, `objectives` and the `STATUS_APPLY` events only; shared looks in
  `SiegeLooks`. `SiegeFieldViews`: the Target Lock a red-orange reticle of `lock.radius` on `lock.centre` (ring,
  four turning ticks, a cross, a countdown arc to `left`) with the pack's `se_lock_rim`, still and white-hot once
  `locked`; the shell the pack's javelin (`se_shell`) falling into it over its last 24 ticks, `siege_shell` the
  pack's `se_blast`. Each boulder the kit's `rock_large` stretched to `size` × 1.1 m × `size` on `centre` (its own
  material copy), rising in the pack's rock dust (`vx1_impact_other`) on `siege_boulder`, its cracks glowing over its
  last 5 s, shaking and sinking while `crumbling`, dust on a `siege_boulder_down` that is not `END_EXPIRED`. The
  cover only while a blast that needs cover comes (`doom` ≥ 0, the cart's last 120 ticks, or `cover_rule` with the
  Engine's ring telegraph up): a teal shadow behind each boulder away from the Engine's centre, clipped to `room`
  (`SiegeLooks.shadow_of`), and a ring on the hero drawn over the rocks (no depth test): teal with the pack's
  `se_cover` while `covered`, red and pulsing otherwise. The Shockwave's ring telegraph reads `inner` 0 under the cover
  rule, so its fill covers the whole room and suggests no safe ring round the Engine. `SiegeCartViews`: the cart a
  code-made wagon (`SiegeLooks.cart`) on `cart.position`, facing `to - from`, wheels rolling with the distance, its
  own billboard HP bar from full (`ActorViews` hides the sim's warden body: the actor whose id is `cart.id`); a rail
  from `from` to `to`, dim ahead and lit behind; a faint red circle of the blast's radius (the reader's
  `cart_blast`) stronger as its HP falls and gold while the Engine stands in it; a countdown ring under
  the Engine filling with `progress`, flashing once `doom` ≥ 0 with the pack's `se_cast` and `se_doom` on it;
  `siege_doom_shell` the pack's `se_blast` on the Engine (and on the hero when `amount_applied` is -1),
  `siege_cart_destroyed` one of the blast's size. `BossVulnerableViews` (any boss): the pack's gold `se_strip` pulse
  round the body and the stun stars (`o13d_star_ring`) over it while `boss_stunned` or the siege's `stripped` runs.
  Hint arrows: `ObjectiveMarkers.SIEGE_BOULDER` (`MechanicHints.SIEGE_BOULDER`). Sounds: `SiegeCues`. The pack rows
  are `data/vfx/pack_fx_se.tres`.
- **The Fallen remembers the run** (v0.12.0; the sim: [`SIM_CONTRACTS.md`](SIM_CONTRACTS.md) §10t). Each remembered
  mechanic is drawn by its source boss's own views, which read the same readers: the Time Wave by `JudgeTimeViews`
  (the `time_wave` ring from The Fallen, the orbs and their clocks from `boss_pickups`), `AttackSlowHud` and the
  `JUDGE_ORB` arrows; the Riptide by `TideDanceViews` (`boss_dance`), its strips and walls drawn only inside the
  circle round `boss_fallen().room` (the final floor is round; the square's corners lie past it); the pillars by
  `StoneSpikeViews` (`boss_quake_pillars`: rings, pulses, the shatter when one goes) and the stun by
  `BossVulnerableViews` (`boss_stunned`: The Fallen's table carries a quake table); the ward by `WardenWardViews`
  (the whole dome and rim on The Fallen while `ward.up`, the shade's `lane` under it, white-hot when the lane touches
  The Fallen (the reader's `shade.breaks`), the shatter and stun flash on
  `fallen_ward_break`) and `ChargeBurstViews` (the end circle at `shade.end`, then `burst` armed and going off).
  `FallenRememberedViews` adds what has no source view: through the cast (`cast` ≥ 0) a ghost of the remembered boss
  (`FallenLooks.ghost`: its own model from `BossModels`, unshaded light in its colours, the Twins as a pair) rising
  over The Fallen and fading out, with the pack's `tw_portal_exit` in those colours at its feet; while it runs
  (`stage` 2) the pack's `tw_ward_rim` in those colours at its feet (not under the ward's dome); while
  `pillar_dash` shows, a strip along it in the Gatekeeper's colour, and from where it enters a pillar (grown by the
  body's radius) to the pillar's middle a white-hot strip when `through`; the shade a ghost of the amber Warden's
  model at `shade.position`, facing its lane, brightening through its wind-up. Colours (`FallenLooks.COLOURS`): the
  Judge gold, the Tidecaller sea blue, the Gatekeeper stone amber, the Twins amber over violet. No text. Sounds:
  `FallenCues` (the cast plays the remembered boss's own telegraph cue; the ward and the shade borrow the Wardens').
  No hint arrow to The Fallen during the ward: the sim sets no marker for it.
  **The theft** (§10t "The theft"), no word and no tooltip change: `FallenTheftHud` (HUD, over the build row's still)
  draws the pip of each card in `boss_fallen().taken` dark under a breathing violet glow (drawn rings, as the HUD's
  other glows; the 3D packs are not HUD art) and flies the card's icon (`CardFly`) from its pip to The Fallen's
  screen point as it is taken and back as it returns; the Build page's `WandRow` darkens the tile of a card whose
  `wand()` entry says `taken` (`TAKEN_TINT`) under a violet rim. `FallenMarkView` (owned and synced by
  `FallenRememberedViews`) puts the pack's orb flare (`hl_glow`, recoloured violet) on The Fallen's back at
  `mark.dir`, one small `hl_glow` per hit still needed in a ring round it (8 down to 0), an `hl_flash` and a swell on
  each `fallen_mark_hit`, and grows the glow through the theft's cast (`theft_cast`). Reduced motion stills the
  breathing and the swell; nothing flies.
- **The Foundry's forge** (v0.12.0; the sim: [`SIM_CONTRACTS.md`](SIM_CONTRACTS.md) §10s). Read from
  `WorldReader.boss_forge`, `telegraph` (the bomb drones' `lob`), `boss_hazards`, `objectives` and the `STATUS_APPLY`
  events only; shared looks in `ForgeLooks`; no word anywhere. `ForgePlateViews`: through the forging cast the pack's
  hot lift (`fo_forge`) round the Foundry's feet and hammer sparks (`fo_spark`) on its body, faster as `forging`
  fills; while `on`, each drone's bomb in the air carries the pack's ember flare (`fo_bomb`) on FireballViews' arc,
  and a faint ring (`fo_reach`) of the Foundry's radius plus the reader's `plate.blast` lies round it, gold (`fo_reach_on`) while a bomb is aimed inside;
  none while no bomb flies; `plate_blown` bursts steel shards (`fo_shards`) where it landed and on the Foundry.
  `FoundryAvatar` wears a steel shell while plated (a lit metallic pass grown 3.5 cm off the owner's model, the glow
  overlay's `next_pass`; it builds glowing orange through the cast and drops at once when blown; none on the
  code-built body); the hero's hits on the plate keep HitFeel's dull grey ARMOURED spark. `exposed_left` > 0 is
  `BossVulnerableViews`' gold pulse and stars and `BossBarTones.VULNERABLE`; plated is `BossBarTones.PLATED` (dull
  iron, still). `ForgeSlagViews`: a cooling pool (`slab` false) a crust disc of its `centre` and `radius` whose dark
  patches grow with `cooling` over HazardViews' lava; a slab a basalt disc of its `centre` and `radius` with a cool
  blue rim, cracks spreading as `left` runs out (against the most `left` seen), fading over its last 45 ticks, dust
  (`vx1_impact_other`, dark) on `slab_crumbled` and `slab_shattered`, not drawn once `shattered`; a `slag_drop` a
  molten blob (`fo_drop`) falling into its pool's warning ring with `warn`, landing in `vx1_impact_ember`; the
  Overpressure a room plane (`HEAT_SHADER`, under the bodies and telegraphs, at most half opaque) rising to 0.75 with
  `cast`, full and flickering once `burn` ≥ 0, fading 0.5 s after, with every whole slab cut out and ringed cool, the
  `safe` ones also carrying the pack's cool rim (`fo_safe`). `ForgeHeroViews`: `scald` share ≥ 0.15 an ember lift
  (`fo_ember`) growing on the hero, `burning` the burning status's flames (`status_burn_a`), `draining` turning on a
  white steam puff (`bx_smoke_thin`). HUD: `ScaldHud` over the HP plate's right end, a dark thermometer whose fill is
  `gauge / max` (orange to white-hot), its rim and bulb pulsing red while `burning`, a blue down tick and a blue top
  edge while `draining`, hidden while `scald` is {}; it is not `HeatMeter` (the Overclock heat: another class, place,
  shape and colour family). `ForgeBurnEdge` (a `LowHpVignette` in fire orange) while `burn` ≥ 0 and not `on_slab`.
  Hint arrows: `ObjectiveMarkers.FOUNDRY_SLAB` (`MechanicHints.FOUNDRY_SLAB`). Sounds: `ForgeCues` (no `heat_*` cue).
  The pack rows are `data/vfx/pack_fx_fo.tres`.
- **The Warlord's charge, War Banner and Duel** (v0.12.0; the sim: [`SIM_CONTRACTS.md`](SIM_CONTRACTS.md) §10u). Read
  from `WorldReader.boss_warlord`, the charge's telegraph (`"burst"`), `boss_charge_bursts` and the `STATUS_APPLY`
  and `DAMAGE` events only; shared looks in `WarlordLooks`; no word anywhere. The charge: `ChargeBurstViews` draws its
  end circle and burst (any boss whose lane telegraph carries `"burst"`; nothing in it is the Twins'); the lane, the
  lock flash and the owner's `lunge` clip follow the sim's wind-up, which BossAnimator maps onto the clip's own strike
  time (its 0.93 s couch plays in the 0.6 s wind-up). `WarBannerViews`: through `cast` the code-made banner (a
  stand-in, `WarlordLooks.banner`) is raised from lying to upright in the pack's warm lift (`wl_banner_cast`), its
  circle fading in; standing, a quiet ring of `radius` on `centre` (`RING_SHADER`: a thin band, a 7 % warm wash) and
  the pack's warm rim (`wl_banner_rim`, flattened to stay low); `boss_inside` lays the pack's red embers
  (`wl_rage`) at the Warlord's feet and `WarlordAvatar` glows hot (the glow overlay's `_extra_glow`); `hero_inside`
  holds a warm flare (`wl_hand`) at the hero's casting hand (HeroCastFx's hand point) and each of the hero's hits on
  the Warlord then also bursts in the pack's warm hit (`wl_hit`). The cloth begins to burn over the last 90 ticks of
  `left`; `warlord_banner_fallen` with `FELL_TIME` burns it away in the pack's flames (`status_burn_b`) as it sinks,
  with `FELL_CHARGE` bursts the pack's shards (`wl_snap`) at the pole while its top and cloth fly off; `FELL_CLEARED`
  just goes. `DuelCageViews`: `DuelCageViews.SHAFTS` (28) of the Warlord's javelins (`BossSignatureViews.javelin_mesh`
  and its shader, one MultiMesh) at fixed angles; through the cast they rain in one after another onto the circle the
  cage would close on now, a third landing in the pack's dust (`bx_smoke_dust`); through the cage they stand on the
  fence's exact `radius` round `centre`, leaning outward, and slide in as it closes, dust kicked up at one shaft every
  0.3 s; a faint breathing danger rim (`RING_SHADER`) under them and no glow inside (a pack rim there drowned the
  recall's circle in the shots);
  `warlord_fence_touch` sparks at the hero (`wl_fence`). Through the recall's warning the shafts glow hotter with
  `warn` and the centre's `zone` is the charge burst's floor circle (`WardenLooks`, with `tw_burst_rim`) filling to
  `warn`, flashing locked from 70 %; `warlord_recall` flies every shaft inward through the centre (0.32 s, frame
  time, after the cage is gone) and bursts the pack's impact (`wl_recall`) there. `WarlordAvatar` lowers its shield to
  its side while `shield_down` (a layer over the owner's animations; the sim then tags a front hit as a plain one, so
  HitFeel shows no block spark). The boss bar keeps its plain tone through the duel. Sounds: `WarlordCues`. The pack
  rows are `data/vfx/pack_fx_wl.tres`.
- **The Hive Lens's drones, Lattice and burnt glass** (v0.12.0; the sim: [`SIM_CONTRACTS.md`](SIM_CONTRACTS.md) §10v). Read from
  `WorldReader.boss_lens`, `boss_move` and `telegraph` (a Focus Beam's `lanes`) and the `STATUS_APPLY` events only; shared looks in
  `LensLooks`; no word anywhere. `LensFeedViews`: each feeding drone's thread, the pack's beam (`hl_thread`, the strand's scene in a dim
  rose, 0.06 m drawn radius) from the drone's body into the Lens's; one floating ring (`hl_layer`) per feeding drone round the
  Lens, the outermost gone with a flash (`hl_flash`) as the count drops; a drone a drawn Focus Beam lane touches wears a gold
  glow (`hl_glow`); `lens_drone_cut` bursts in the beam's gold (`hl_cut`, `hl_flash`) and its thread snaps back into the Lens
  over 0.25 s; the threads hide while the web stands. The hero's hits keep HitFeel's ARMOURED spark (the sim tags them).
  `BossBarTones.FED` (a muted rose, still) with a pink pip per feeding drone. `LensLatticeViews`: through the cast the pack's
  big orb (`hl_charge`) grows on the Lens and each drone brightens (`hl_glow`); each listed strand a pack beam (`hl_strand`) from
  its `from` to its `to` at 0.8 m, its drawn radius the reader's `half_width`, keyed by its two actor ids, so a strand the reader
  drops is gone the same frame; each web drone trails a world-space ember (`hl_orbit`); `lattice_strand_hit` sparks on the hero
  (`hl_spark`). Each glass row a floor strip (`GLASS_SHADER`) on its exact rectangle (`from`, `to`, `half_width`), its heat going
  from 1 to 0.35 with `progress`, a smoke (`hl_sizzle`) on `lens_glass_laid`. A beam the pack refuses is a plain glowing rod; a refused key tries again the next frame
  (`LensPackHold`).
  Reduced motion: the glass's shimmer holds still; nothing pulses. Sounds: `LensCues`. The pack rows are
  `data/vfx/pack_fx_hl.tres`.
- **Boss mechanics carry no words** (owner, 2026-11-15: "too much text … we need to make it subtle so the player
  discovers it while playing, with arrows or glows"). `ObjectiveHints` draws arrows only (a small arrow over the
  target on screen, an edge arrow off it) for every reason, never a line of text. The boss bar keeps the boss's
  name and its phase line ("Phase 2 / 3"; the final boss's body names) and shows every state as a tone of its fill
  (`BossBarTones`): the phase gate breathes pale, a boss taking more damage (a quake stun, the violet Warden's broken
  ward, the Engine's stripped armour) shimmers gold, an invulnerable boss is steel blue with a pip per shield left, the Hive Lens fed by its drones a muted rose with a pip per drone,
  the Lantern Shade's bar dims in the dark and turns lantern gold in a lit pool, The Fallen's window breathes and then
  shimmers violet. `AttackSlowHud` shows its clock and pips only. Names, the death recap, sound captions, the Codex
  and Options keep their words.

- **The player's attacks are drawn from their final specs** (v0.6.0 MX1; design
  [`../design/MODIFIER_ENGINE.md`](../design/MODIFIER_ENGINE.md) §4): `AttackView` reads `WorldReader.attack_spec`
  and composes the look by layer (form → what draws it, size → the blade's arc and reach and the dart's length,
  elements → the core colour, behaviour → trail and brightness, heat → the edge via `HeatLooks.attack_color`). No
  view asks which cards are held for an attack's look. MX1 keeps the v0.5 looks exactly
  (`tests/unit/presentation/test_attack_view.gd`); the 8-form / 5-element art layers are MX stage 3.
- **MX3: the form and element layers** (`src/presentation/world_view/attack_forms/`). `AttackFormLooks.compose(spec,
  heat tier)` turns a spec into a look: the form picks the pools, size / reach / count / spread / directions the
  meshes' scale, number and layout (a halo of 12 shots is 12 darts evenly round); the first element sets the core
  colour and particles (storm white-blue crackle, ember orange sparks, frost pale shards, venom green drip, void violet
  smear, bleed MX1's tint), a second element the rim; the heat edge is `HeatLooks.attack_color` over the rim (values
  untouched); behaviour cues (pierce a streak, bounce a flash, home a curved trail, return a tether); a damage
  multiplier (`damage_mul_permille`) thickens and brightens, a crit adds a white-hot flash. `AttackFormView` draws
  them in MultiMesh pools per form layer and per particle kind, additive light (lit matter for the lob's bomb), timed
  by sim ticks. **Ground marks never take a hostile hue:** a zone's patch, a lob's landing circle and the flat fill of
  a ring or burst pass through `AttackFormLooks.ground_safe`, which leans a colour in the telegraphs' red-orange /
  red / magenta band toward the player's cool core; only light that rises off the floor carries the heat edge.
  Plain attacks (no element, cue or weight) add nothing over the v0.5 blade and the hero's shot (since v0.8.0 GF1 a
  blue pulse, HeroPulseViews, in place of the dart).
- **The ability modifiers' attacks** (v0.6.0 MX2) draw through the existing ability views from sim numbers: bombs and
  their ground circles (`AbilityVisuals`), the drones and orbit blades, the patches by kind (`ElementVisuals`: fire
  orange, Napalm red, Arc Field's shock field pale blue, a hook's zone pale white) and each growing ring (the RING
  form) as a frost torus at its radius now. Their per-form art is MX stage 3.
- **MX3 takes over the spec forms of MX2's runners** in the game (`WorldViewRoot` sets `forms_drawn` on
  `ElementVisuals` and `AbilityVisuals`): `AttackFormView` reads each live ring (`WorldReader.rings_live`: drawn at the
  runner's radius now, so the drawn front is the hit front), each patch that names a spec (`fire_spec_keys`), each bomb
  (`bomb_spec_keys`: the shell on its arc over its blast circle, then its landing), the orbit blades' ORBITER spec
  (an element glow and trail over the steel blades, which `AbilityVisuals` keeps) and every player projectile in its
  own spec's look (`projectile_spec_key`, `attack_spec_at`). What names no spec (Napalm Drone's patches, the drones)
  stays with the older views.

## 5. Occlusion cutaway

- A wall whose box lies between the camera and a focus point (the player, enemies within a radius, active
  telegraphs) **fades** with a dithered alpha (**starting value**: 25% opacity) while it blocks.
- An actor that is still hidden draws a flat **silhouette** in its team colour through the wall. The first
  technique to try is the `BaseMaterial3D` X-ray stencil mode (4.5+). The occlusion gallery scene proves the
  technique before it's adopted.
- Picking which walls fade is a pure function, `Occlusion.select(cam_dir, focus_points, walls) ->
  PackedInt32Array`. It is unit tested in `tests/unit/presentation/test_occlusion_select.gd`, separately from the
  rendering.
- **Crowds (v0.4.0 SC):** the focus points are the player and at most `WorldViewRoot.OCCLUSION_FOCUS_MAX` (24)
  enemies within `OCCLUSION_RADIUS_M` (10 m) of it; `select` rejects far point-wall pairs with a cheap distance test
  before the exact one (it picks the same walls). Testing every wall against every enemy each frame had become the
  view's largest CPU cost with a horde; the X-ray silhouettes still show the enemies farther off.

## 6. Hit feel

- **Hit-stop** is sim state (`freeze_ticks`, [`SIM_CONTRACTS.md`](SIM_CONTRACTS.md) §2). The view shows it; it
  never creates it.
- **Flash:** a struck actor flashes white for a few frames (**starting value** 3 frames). Reduced motion keeps
  the flash but lowers its intensity.
- **Shake:** see §1.
- **Damage numbers:** optional (an Options toggle), placed from the event's `pos` and stacked so they don't
  overlap.
- **Armour sparks:** read from `HIT` tags only. A guarded hit throws a pale spark, a hit on a Warden's armoured
  front (`ARMOURED`) a dull grey one, a hit on its weak spot behind (`WEAK_SPOT`) a bright one, so flanking reads.
- **Death:** a short pop of low-poly shards from the `cosmetic` stream. A dead enemy's ring disappears on the
  `KILL` tick, so it never reads as alive.

## 7. VFX and cue budget

- **Crowds (v0.4.0 SC):** projectile nodes are pooled per look (hidden and reused, at most
  `ActorViews.PROJECTILE_POOL_MAX` idle) and share one mesh and one kept material per look; an enemy's floating HP
  bar shows only once it is hurt (the hero's always); enemy models beyond `ActorViews.ANIMATE_RADIUS_M` (24 m, off
  screen) stop their frame-time animation; no enemy carries a light (a boss has its weak-point light only; one
  stage-wide `BossKeyLight`, cull-masked to the bosses' bodies, lights them from the camera's side so a boss never
  reads as a black silhouette against a low sun). The damage-lag rule stands: materials are built flashable (`ActorViews.flashable`), and nothing toggles
  `emission_enabled` or another feature flag at runtime. Enemy models are not MultiMesh instances: each kind's model
  animates its own parts, so a crowd stays one node tree per enemy (measured in `docs/roadmap/v0.4.0/evidence/
  HORDES.md`).
- **Attack forms (v0.6.0 MX3):** at most `AttackFormView.MAX_ATTACK_MESHES` (1,024) form meshes and
  `MAX_PARTICLES` (1,200, inside the 2,000 below) attack particles a frame, the live attacks first, then the newest
  effects; every pool has a fixed size (384 per layer, 600 per particle kind) and at most 256 effects live. Options >
  Display > **Effects density** (low / medium / high, `ViewPrefs.effects_density`; default high) scales the particles
  (× 0.25 / 0.55 / 1) and the mesh cap (384 / 640 / 1,024); a pattern's own copies are never thinned below the cap.
- **Hostile fireballs and stone spikes (v0.8.0 AV):** each fireball look is three MultiMeshes (core, edge, trail; one
  draw each) whatever the count; Low density draws every other trail, shorter and narrower (the balls stay). Lights
  come only from VfxCore's pool (`LIGHTS`, the brightest requests win): one per lobbed fireball or raining drop, at
  most `FireballViews.SIGNATURE_LIGHTS` for a boss's signature shots, one flash per spike strike. The spikes are one
  MultiMesh of at most `StoneSpikeViews.MAX_SPIKES` (512), at most `MAX_STRIKES` (8) strikes alive; their debris and
  dust come out of VfxCore's sprite pools (inside the 2,000) and scale with the density, their crack marks out of its
  64 decals.
- **Boss strikes (v0.8.0 AV part 2):** `BossStrikeViews` is six MultiMeshes with fixed caps (rocks 384, blades 384,
  glowing bands 64, dust bands 48, beams 32, ground quads 160; one draw each) and two rebuilt arc meshes, at most
  `MAX_STRIKES` (24) strikes alive. Its sprites come out of VfxCore's pools, its lights out of the 10-light pool
  (merged per strike), its marks out of the 64 decals, its explosions and acid splats through `VfxLayer.burst` (the
  frame's burst budget) and `BurstBudget.admit` for the live ones. Effects density thins the rocks and the sprites (not
  the blades or the ground marks, which show where it hit); reduced motion stills the tumbling, the overshoot and the
  shaders' flow. It adds no camera shake.
- **Blade forms (v0.8.0 PF2, owner O9):** `BladeFormView`'s crescents and ghost slashes are MultiMesh instances of baked
  shapes (`BakedMeshPools`: one mesh per shape, the same 14-segment band, colours and height the ImmediateMesh drew; a
  ghost's shape is its age in ticks too), at most 256 instances of a shape and 96 shapes (then all are rebuilt), one
  draw each. The cracks, eruptions, sparks, rings and orbiting blades stay in the one ImmediateMesh.
- **The hero's effect budget (v0.10.5 O12, owner P9: "yes cap it"):** `HeroFxBudget` (starting values). The hero's
  own sprites in VfxCore (the forms' canvas and `VfxCore.hero_drawers`: the forms' accents, the hits' impacts) keep to
  `SPRITES` a frame (160 / 110 / 60 by Effects density); past 75 % of it the oldest draw at 55 % alpha and 80 % size,
  past it they are skipped. The forms' meshes and particles dim the same way in the last quarter of their caps; the
  live bolts with a rim keep to `LIVE_BOLTS` (96 / 64 / 32). When more than `DIM_FROM` (4) hostile threats are on
  screen (each telegraph one, every 4 enemy shots one), all of it drops gently (1.5 a second) toward 60 % opacity,
  reached at `DIM_FULL` (12). Enemy telegraphs, hostile shots and boss attacks (`VfxCore.drawers`, their own views,
  PackFx's `enemy_shot`) are never in it. The pack's instances keep their per-family caps (PackFx.CAPS).

- **Starting values**, confirmed by the stress scene in v0.1.0:
  - at most 2,000 live GPU particles in total;
  - at most 24 concurrent hit-spark emitters;
  - at most 64 decals.
- Cues play in event order within the frame they arrive. If the budget is exceeded, cosmetic cues drop first, by
  priority. Telegraphs, player-damage feedback and pickup highlights never drop.
- The `CueBuffer` never blocks the sim (see [`ARCHITECTURE.md`](ARCHITECTURE.md) §12 on Deathventory's
  `PresentationGate`).

## 8. Accessibility

| Setting | Version | Contract |
|---|---|---|
| Remapping (KB+M and pad) | v0.1.0 | Every action is rebindable. Prompts follow the last-used device. |
| Screen shake on/off and intensity | v0.1.0 | Off means none at all. |
| Reduced motion | v0.1.0 | No shake. Fewer particles. No full-screen flashes. Camera smoothing is kept. |
| Colour-blind modes | v0.1.0 | Normal, red-green safe and blue-yellow safe. Each mode remaps the team, hostile-projectile, telegraph and hazard tokens. |
| Captions for sounds | v0.1.0 | Every gameplay SFX has a caption key ([`../audio/SFX_NEEDS.md`](../audio/SFX_NEEDS.md)). |
| Text size floor | v0.0.1 | Body text is at least 18 px at 1080p (**starting value**). |
| Flash safety | v0.1.0 | No full-screen flash more than 3 times per second. |
| Interface size | v0.7.5 SM | Options → Accessibility "Interface size" 90 / 100 / 110 % (`ui_scale`): the window's content scale, so every menu, the HUD and their text grow or shrink together; the 3D view is not scaled. 110 % is the most the 1080-built pick panel takes at 1280×720. |
| First-run hints | v0.7.5 SM | Options → Accessibility "Show hints" (on by default) and "Reset hints". A hint never blocks: no mouse, no focus, no pause; the keys it names follow the last-used device and the live bindings. |

**Palette test** (`tests/unit/presentation/test_palette_contrast.gd`). For each colour-blind mode, it simulates
the mode's colour vision on the tokens and asserts:
- the player, enemy, hostile-projectile and telegraph tokens stay pairwise distinguishable (a minimum
  colour-difference threshold, **starting value** ΔE ≥ 20);
- every biome's `outline` keeps a contrast of at least 3:1 against that biome's `ground`.

## 9. UI

- **The build and the Swap** (v0.6.0 MX2): `BuildHud` (its own node) shows the weapon, the utility pick and six
  modifier slot pips in the card family's frame colour (`CardFrames`) with the level on an ability modifier;
  `SwapPanel` (its own node, over the pick panel and the shop) shows the incoming card and the six held modifiers
  while `WorldReader.swapping()`; its answer goes out as input (`InputFrame.PICK_SWAP_BASE + n`, `PICK_SWAP_SKIP`):
  keyboard 1–6 / arrows and Enter, Esc to skip; a mouse click; pad d-pad, A, B.
- **Theme tokens** come from `ThemePalette` (adapted from Deathventory): colours, font sizes, a spacing scale and
  corner radii. No view hard-codes a colour or size.
- **Layout:** the UI sits on a `CanvasLayer`. The base resolution is 1920×1080 with `canvas_items` stretch and
  `expand` aspect (**starting values**). It is tested at 1280×720, 1920×1080, 2560×1440 and 3440×1440.
- **Font:** one dynamic TTF with full Latin coverage, including Spanish (á é í ó ú ü ñ ¿ ¡), set in the project
  theme. There are no bitmap fonts ([`../LESSONS.md`](../LESSONS.md) L13).
- **Strings:** every visible string is `tr("KEY")` (EI-10). Layouts must fit Spanish, which runs about 25%
  longer. The screenshot tour runs in both languages.
- **Button prompts** show glyphs for the active device.
- **HUD and card look** (v0.3.5 F15, F16; G2 picks pending, defaults ship): the HUD is calm, plain type, thin
  bars, one hairline per group, no glow, echo or glitch (`HudStyle`, one constant: `DEFAULT`); every card (pick,
  item, combo, gamble) is a flat square dark panel with a thin outline, no rounded corners, shadow or coloured side
  bar, with rarity as a small faceted mark (`CardStyle`, one constant: `DEFAULT`). Since v0.5.5 A4 the **pick
  cards** (altar, chest, shop stock) wear the owner's crystal frames instead (`CrystalCard`, `CardFrames`: the
  frame colour is the card's family, epic and cursed offers override it; rarity reads as the rarity line, the gem
  and a glow; text steps down in size so it never overflows the panel, checked in en and es by
  `test_card_frames.gd`); the item, combo, gamble and event cards keep `CardStyle` until the A5 pick. Overclock heat is a thin straight
  bar whose ticks come from the sim's heat table (F2). The minimap is oriented like the screen: up, left and right on
  the map are up, left and right through the iso camera (`MinimapView.turn`, checked against `IsoRig`'s projection
  in `test_minimap_orientation.gd`, F14).
- **v0.5.5 A5 restyle (owner pick, 2026-10-08):** the in-game HUD is **B "Ember stone"** (`HudStyle.DEFAULT =
  EMBER`): chipped dark stone slabs (`HudStyle.draw_plate`), a warm ember line and glow under the HP, top, heat and
  boss slabs, warm type, a red HUD HP bar, danger marks drawn as ember teeth. The heat meter keeps its straight bar,
  ticks and `HeatLooks` colours, set in a slab. The **corner minimap has no background** (owner: "we should remove
  the black background"): it floats over the game, every line over a dark halo, every room over a faint dark wash,
  four ember corner ticks mark its window (`MinimapStyle.CORNER_PANEL = false`); the held full map keeps its panel.
  Every full-screen menu (main menu, pause, Options, credits, the run recap and death screen, the build picker's Back)
  is **C "Cold glass"** (`MenuStyle`, one Theme set on each menu root): the game blurred and dimmed behind
  (`MenuBackdrop`, a screen-texture shader), a left-aligned title and list, plain type, the focused row lit by a
  thin cold-glass wash and hairline with a glass diamond beside it, small notes and key hints under the list; **no
  build cards beside the menu** (owner: not needed). The pick cards keep `CrystalCard`.
- **v0.8.0 MU restyle (owner O14 "we're just throwing away the shard cards"; G2 pick "menu style B", 2026-10-14;
  [`../roadmap/v0.8.0/evidence/MENU_G2.md`](../roadmap/v0.8.0/evidence/MENU_G2.md)):** the cards and the menus are
  **"Ember stone"**, drawn in code. One style box, `StoneBox` (`src/presentation/theme/`, tokens in `EmberStone`):
  a dark carved slab with chipped edges, the ember glow under it (`under`, `focus`), a grain, cracks, a warm lower
  bevel, and optional inlays (a glowing groove line, a ring round a socket, a gold rim). Every **pick card** (altar,
  chest, shop stock, the Swap's card, the Codex's card) is a `StoneCard` (replaces `CrystalCard`): the icon in an
  `InlaySocket` ringed in the element's colour, the title in the family's colour (`CardFrames`, now a colour table
  only) over a groove, the sentence, the carved rarity gem (`CardMark`) over the rarity words, a gold rim when epic or
  legendary, the level badge top right; text steps down (`TextFit`) and a sentence too long at the smallest size
  reflows the card (a smaller socket), so it never runs into the gem (`test_card_frames.gd`, en and es, every scale).
  The **plaques** (`PlaqueBox`: item, combo, gamble, event, ascension, shop, banner) are stone slabs with a groove in
  their colour; the **wand tiles** (`WandRow`), **pips** (`BuildHud`), **Codex tiles**, **achievement rows** and
  **toast**, the **Swap** tiles and the **build picker** (stone tablets with the weapon's symbol in a socket, a stone
  title plaque) share it. **Every menu** (`MenuStyle`; main menu, pause, Options, credits, Codex, Build page, run
  recap, build picker) puts its list on a slab, the focused or pressed row an ember-lit slab with a groove and an
  ember diamond beside it (`EmberMarker`; a hovered row half lit), warm type; behind it `MenuBackdrop`: the game
  blurred into a warm dark with a low ember glow, or with nothing behind (the main menu, `own_scene`) its own
  ember-lit stone floor; sparks drift up from below; **reduced motion stops its clock** (no sparks moving, no
  flicker). The ember `#EBAE72` is kept apart from the Hot heat colour by saturation (`test_ember_stone.gd`). The
  owner's crystal frames, plaques and build-picker art are retired (assets, manifests, crop scripts removed).
- **The Codex** (v0.7.5 CX, owner N6; Ember stone since v0.8.0 MU): `CodexView`, a full-screen menu from the main menu (a row after
  Credits) and the pause menu (a row after Options). Four pages (Cards by pool, Enemies, Bosses, Biomes) of
  `CodexTile`s, and the focused entry beside them: a card as its stone tablet (`StoneCard`, its family's colour) or
  an emblem (`CodexGlyphs`: an enemy by its behaviour, a boss by its id, a biome as a landscape in its palette), the
  game's own name and sentence keys, and the profile's counts. An entry not met is a dark silhouette named "???".
  Keyboard arrows / Q E / Esc, pad d-pad / LB RB / B, mouse hover, tab click and Back. It reads `CodexCatalog` and
  `CodexStore` only; it fits the 1920×1080 base in en and es (`test_codex_view.gd`). It was built straight in the
  owner's Cold glass look without a G2 round (v0.7.5: the owner asked for no interventions); the owner corrects it
  at the playtest.
- **The achievements** (v0.7.5 AC, owner N7): a fifth Codex page, **Achievements** (`AchievementsPage` in
  `CodexView`, after Biomes; Q E / LB RB, the tab by mouse), the achievements in their groups, two
  `AchievementRow`s a line: a code-drawn glyph (`AchievementGlyphs`), the name, the sentence and the state. An
  unlocked one is lit in gold with "Unlocked"; a **locked one is dimmed but keeps its name, its sentence and its
  progress** ("2 / 5"), so the page says what to aim for; a **hidden** one (today the two Ascension ones) is "???"
  with the hidden line until it unlocks. The unlock **toast** (`AchievementToast`) is a small Ember-stone slab under
  the corner minimap (top 404, right 28 at the 1920×1080 base): "ACHIEVEMENT UNLOCKED", the glyph, the name and the
  sentence, 4 s with a short slide and fade, more unlocks queued; it ignores the mouse and the focus (never
  blocks), lives on the UI layer outside the HUD so it outlives a floor change, and reads its clock from the frame
  (a look, never an outcome). Both fit the 1920×1080 base in en and es for every achievement
  (`test_achievements_view.gd`). Built straight in the owner's looks without a G2 round (v0.7.5: no
  interventions); the owner corrects it at the playtest.
- **Card levels** (v0.7.5 SM, owner N8): a card that levels (a wand card, 1–5, and an ability card) wears a small
  badge (v0.8.0 MU: top right on the stone tablet) on every pick card (`StoneCard` via `PickPanel.card_face`, so the altar
  and chest pick, the shop's stock, the event panel and the Swap): "Lv 1" when not held, "Lv N → N+1" when taking it
  levels a held card, and on the boss's legendary altar "Lv N → 5" (its level-5 version; "Lv 5" when not held). The
  rarity line is unchanged. The HUD's wand pips (`BuildHud`) and the Build page's tiles (`WandRow`) show a wand
  card's level as they show an ability modifier's. The badge fits on the card at the pick's and the shop's scales
  in en and es (`test_card_level_views.gd`).
- **The reward cards** (v0.8.0 N8, owner O62, D48; [`../roadmap/v0.8.0/evidence/REWARD_CARDS.md`](../roadmap/v0.8.0/evidence/REWARD_CARDS.md)):
  every pick card (`StoneCard`: the altars, the boss's altar, the epic altar, a chest's one card, the shop's stock,
  the Swap, the Codex) reads top to bottom: the **name**, the **big icon** (its element or star glyph badge kept), the
  **gain line** (old → new: `CardGain`, its numbers the sim's own `WorldReader.card_forecast` → `CardForecast`, the
  steps the take runs: a stat's value, max HP, an ability's or a wand card's level), the sentence, the gem and the
  **rarity's word**. The **whole card is painted in its rarity's colour** (`CardPaint`: the stone face and back tinted
  dark toward it, its frame line and glow in it; the text keeps ≥ 4.5:1 contrast). The pick panel **deals** them
  (`CardDeal`, read each frame, deciding nothing): face down from below the screen into a fan, flipped one by one
  (the width to 0, the face swapped halfway); an **Epic or Legendary** card is dealt last: its back glows, the
  background darkens, and it flips with a punch, a flash and light rays rising behind it (`CardFx`; the rays on one
  layer under every card); a **Legendary** card keeps a looping holographic shine. The focused card **tilts** toward
  the cursor (a fixed tilt when focused by key or pad) and **sinks** a little, its gain counting up from the old value.
  On a pick its icon **flies** to the HUD slot it landed in (`CardFlights`/`CardFly`: an ability's slot, a wand pip,
  the carried row, else the HP plate) and the cards not picked **burn** (a dissolve shader with an ember edge); a
  cancel just closes. A press during the deal ends it at once and still counts (no input lost or held back).
  **Reduced motion:** no deal, flip, tilt or flight; the cards fade in face up, the shine holds still, the panel fades
  out on a pick. The shop's cards wear the same face, paint and gain line, without the deal.
- **First-run hints** (v0.7.5 SM, owner N8): `OnboardingHints`, one small Ember-stone slab with a cold top line at
  the top centre (top 150 at the 1920×1080 base, 720 wide, "TIP" and one line); while a centre panel is open (a pick, the
  Swap, the shop, an event) it sits low instead (its bottom 82 px above the screen's, between the panel's key line and
  the heat meter), so it never covers the panel's title or cards. Each hint shows once
  (`HintStore`, the profile's `hints` section): move and aim, attack, dash at a first run's start (each closes when
  you do it); vent when the heat first reads Hot; the Build page (pause → Build) after the first card joins the wand;
  the Codex (pause → Codex) at the second floor's start (v0.8.0 N18, owner O76: the hints that explained a thing, the
  first pick, the first trigger card, the first shop and the first open portal, are gone; the hints name controls
  only). A hint about a moment (vent) comes before a waiting first-run step; a hint stays at least 2 s and at most 9 s, fades in and out (no slide), and
  waits under the pause menu, Options, the Build page, the Codex and the run recap. Its clock is the frame's (a look,
  never an outcome); it reads `WorldReader` only. Built straight in the HUD's look without a G2 round (v0.7.5: no
  interventions); the owner corrects it at the playtest.
- **New screens go through gate G2** (2–3 mockups, the owner picks; see
  [`../process/OWNER_GATES.md`](../process/OWNER_GATES.md) §3).
  - **Exemption:** v0.0.1's functional stubs (main menu, pause, options stub, credits, dev panel) use the default
    theme and skip G2.
  - Each stub goes through G2 when it is designed for real: Options in v0.1.0, the HUD and menus in v0.3.0.

## 10. Screenshot tour

- `scripts/shots/tour.gd` is committed. It boots the game with a fixed seed, walks through every screen and a
  scripted combat moment, and saves PNGs to `build/shots/<version>/<lang>/` (gitignored).
- **It needs a real renderer:** `--headless` uses a dummy renderer that draws nothing. Run it like this:
  - **In CI** (ubuntu), under `xvfb-run` with Mesa's software Vulkan (lavapipe) for Forward+, or llvmpipe OpenGL for
    Compatibility. v0.0.1 Step 7 proves which works and records it. The PNGs are uploaded as a CI artifact.
  - **Locally,** on any machine with a GPU: `godot --path . -s scripts/shots/tour.gd`.
- **PNGs the owner decides on** (gallery picks, G2 mockups) are committed under the version's `evidence/shots/`,
  because they are decision records. Full tours stay as CI artifacts.
- G2 mockups use the same harness (`scripts/shots/mock_<screen>.gd`).
- Deathventory's `.shots/` scripts were never committed, so every UI pass rebuilt them from scratch
  ([`../LESSONS.md`](../LESSONS.md) L12).
- Each release's evidence links the tour output it was checked against.

## 11. Batched display

A node per drawn thing is moved, notified, processed and drawn by the engine every frame, and the views that fed
them visited every object every frame. In a horde that was the largest part of the frame (taking the enemies' nodes
out of the tree gave back 6.0 ms at 120 swarmers and 8.9 ms at 60 enemies with the heavy build:
[`PERF_NATIVE.md`](../roadmap/v0.11.1/evidence/PERF_NATIVE.md)). So the things a crowd has many of are drawn as
instances of a few MultiMeshes, written in one pass a frame, and the rule for every one of them is the same: **the
look does not change**, and a probe or a test proves it.

### 11.1 What is drawn as instances, and by what

| What | Drawn by | How |
|---|---|---|
| Enemies of the batched kinds (`EnemyBatch.KINDS`: Swarmer, Splitter, Splitling, Shield Bearer, Mender, Mine Layer, Charger, Hatchling, Stone Thrower, Needle, Rock Lurker, Warden, Rubble Warden, Sniper, Arc Caster, Scrap Hound) | `EnemyBatch` (`src/presentation/world_view/enemy_batch.gd`) | No node in the tree. Each keeps its root, facing and avatar as plain objects outside it. The **furniture** (contact disc, team ring, dazed ring, health bar, blob) is one MultiMesh per mesh, written in one pass a frame. A Warden's slam dust ring and a Rubble Warden's crust stay nodes, hung in the tree from the batch's anchor for it through a copy of its facing and its avatar's transform (`BatchWarden`), so the engine draws and interpolates them as it did the node Warden's |
| Their avatars' state (clocks, strike, tell, flinch, hold, pose drives) | `BatchAvatars` (`batch_avatars.gd`) | One row of `STRIDE` (124) packed doubles a slot (the Stone Thrower's pose drives, clocks and rock, the Needle's clocks, drives and legs' rest joints in it too: `BatchNeedleRow`; the Rock Lurker's, `BatchLurker`; the Warden's clocks, drives, pivots and dust ring's clock, `BatchWarden`; the Sniper's clocks, drives and legs' rest joints, `BatchSniperRow`; the Arc Caster's, `BatchArcCaster`; the Scrap Hound's, `BatchScrapHound`). A Rock Lurker waiting as a boulder has its disc and ring taken out of their sets (`EnemyBatch.show_rings`), as its nodes were hidden. While `on`, `ZdCrowd` applies each sync, steps each frame and writes the bodies from the rows: one call each, none per enemy. An event on an avatar (a flinch, a hold, a death) copies its row into the object, runs the avatar's own GDScript, and copies it back before the next native call |
| Every VAT enemy body and its proxy shadow | `VatCrowd` (`vat_crowd.gd`) | One MultiMesh per kind and look (bodies) and per kind (shadows). A batched enemy's body is drawn at `EnemyBatch.body_at` |
| Horde critters | `CritterCrowd` (`critter_crowd.gd`) | No node each; reads the `WorldReader` columns once a sync |
| A dead enemy's cubes | `ShardPool` (`shard_pool.gd`) | One MultiMesh per look, `CAPACITY` 1,024 pieces; a piece lives `LIFE` 0.5 s of real time, so the pop lasts as long at any frame rate |
| Flying shard gems | `ShardViews` (`shard_views.gd`) | Two MultiMeshes (crystals and outline shells), a slot a gem |
| Shard drops on the floor | `ShardViews` | Each drop an instance of one of 48 cluster shapes (`DROP_SHAPES` 16 × `DROP_SIZES` 3), built once a session behind the loading cover (`warm_shapes`); the glow sprites one more batch. No node and no mesh bake in a fight |
| Lightning bolts | `ZdBolt` (`assets/vfx_zd/lightning/bolt.gd`) | One shared strip mesh (`_strip`) for every bolt; the shader draws the jagged line from a few numbers a bolt instead of a mesh rebuilt on every move and flicker. The core always sorts in front of its shell (`CORE_SORT`) |
| The HUD's still parts | `HudStill` (`src/presentation/hud/hud_still.gd`) | A part that has been still for a frame is rendered once into its own SubViewport and drawn from that texture; any change (a redraw, a move, a resize, a show or hide, the screen transform) draws it directly again the same frame. Layout, input and every read of the nodes are unchanged |

### 11.2 Who writes the instances

- **`ZdCrowd`** (the native library, `native/src/zd_crowd.h`) writes the batched enemies' furniture
  (`write_furniture`), applies the avatars' syncs (`apply_sync`), steps them (`step_avatars`) and writes their body
  and shadow instances (`write_bodies`). It reads only the columns the view gives it, never the sim, and holds nothing
  between calls. Its arithmetic is the GDScript's, in the same order and width: doubles where GDScript reckons in
  doubles, floats where it stores into a `PackedFloat32Array`, and the engine's own `sin`, `cos`, `exp`, `asin`
  ([`NATIVE_CORE.md`](NATIVE_CORE.md) §4).
- **The GDScript writer stays** as the reference the tests compare against and as the fallback: without the library,
  with `EnemyBatch.native` off (the frame probe's `--ab=no_native_crowd`, the equality tests), or with
  any batched avatar no native class covers, each enemy's GDScript runs as before. `ActorViews.batch_enemies` off
  (`--ab=no_batch`) puts every enemy back on its own node tree.

Since step 54b the dev panel has no native core switch (`NativeSwitch` is deleted: the sim is native only);
`EnemyBatch.native` is on by default and only the frame probe and the tests turn it off. The GDScript writer stays as
the test reference and the fallback without the library.

### 11.3 What still has a node, and why

| What | Why |
|---|---|
| The other solo VAT kinds: Bomb Drone, Lens Drone, Kiln Beetle, Cinder Priest and the other biomes' owner's models | Their bodies are `VatCrowd` instances, but their avatars read the tree in their frame step or their death (global transforms, timers) (`EnemyBatch.KINDS`' comment) |
| A biome's variant of a batched kind (the Dim Needle, the Split Sniper) | Drawn by its own nodes, never by the VAT crowd (`VatCrowd.supports` takes the base kinds only), so the batch, which draws through the VAT crowd, cannot take it. The Rubble Warden is the exception: its avatar is the Warden's and the VAT crowd draws it as one, so it is batched (`ActorViews._batches` asks of the body kind) |
| Bosses and elites | Their own rigs, models and views |
| The hero | One, with its own rig and effects |
| A batched enemy's status marks | An anchor node made only for an enemy that shows one (`EnemyBatch.anchor`) |

### 11.4 How views read the sim

- **In bulk.** A view that draws a few kinds or a few states walks only those rows, through `WorldReader`'s read-only
  bulk getters: `telegraph_indices`, `indices_in_state`, `status_indices`, `burn_or_frozen_indices`,
  `indices_of_kinds`, `core_indices`, the copies `actor_ids`, `actor_xs`, `actor_ys`, `projectile_ids`,
  `projectile_xs`, `projectile_ys`, and the whole columns (`actor_ids_column`, `actor_pos_x_column`, …). None of them
  enters the state hash or the snapshot. `LatchedReader` notes each tick by copying columns whole.
- **Quiet when empty.** A view with nothing to show hides its pieces and does no work until content comes; a test
  wakes each one (`tests/unit/presentation/test_view_wake.gd`).

### 11.5 Keeping the look identical, and how it is proven

| Proof | What it compares | Tolerance |
|---|---|---|
| The twin probe (`frame_probe.gd -- --twin`, `scripts/checks/batch_twin.gd`): a tool, not a test | A second `ActorViews` drawing the same scene with a node per enemy, synced on the same reader and frames; every batched enemy's body instance, furniture and bar chunks against its twin node, every frame before the draw | `EPS_POS`, `EPS_BASIS`, `EPS_COLOR` 0.0005 (the rounding between two ways of reckoning a transform); the first run matched over 47,000 instances, position within 0.000002, bar fill 0 (the enemy batch's PROGRESS row) |
| `tests/unit/native/test_native_crowd.gd` | The native writer's buffers against the GDScript writer's for a seeded crowd over 300 frames with hits, flinches, holds, a dazed Charger, kills and spawns: places, bar fills, body places, every set's instances | none: bit for bit |
| `scripts/checks/view_dump.gd` | A 900-frame dump of the bulk-reading views' nodes and state, before and after a change | byte-identical |
| Pixel diffs (`scripts/shots/shard_burst.gd`; `scripts/checks/hud_still_diff.gd`) | Shots of the same frame before and after | shard drops and bursts: 0 pixels; the HUD: at most 2/255 a channel, judged against the noise floor of two captures of the same mode (the on / on-again pair) |

### 11.6 Kept on purpose

These reproduce what the engine did with the nodes, so the batch matches the twin; changing them is a visible change
and goes to the owner:
- **A body on a tick frame is drawn at the place of the sync before last** (`EnemyBatch.body_at`): resetting a node's
  interpolation in the same frame as its sync left the engine drawing it there. On a frame with no tick it is drawn at
  the interpolated place; far off screen, at the latest place. The furniture is drawn at the interpolated place.
- **A health bar's first shown frame starts its fill at the current value**, not interpolated from an older one
  (`EnemyBatch`'s furniture pass).

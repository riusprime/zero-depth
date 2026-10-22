# v0.9.0 VX: VFX audit (G1)

**Status:** waiting for the owner. **Nothing in this list is built until you approve it.**

**How to answer:** one word per row, in any order: "V3 approve", "V11 change: …", "V16 drop". A row you skip stays
unbuilt. Rows marked **Decide** offer two options; pick one. Rows marked **Texture** work without your art (a code
fallback ships), and get better if you make the PNG later.

## The request

- C79 (feedback §10): "Several recently added items and attack modifiers are still missing proper VFX. Audit the full
  list".
- C80: "implement a consistent set of effects for: launch and travel; impact; elemental application; laser, bomb, and
  void; Twin, Ring, Spiral, and Swirl; new modifiers that already exist in code".
- C72: "Elements should modify the chosen attack form … Shock + Orbs … Do not assume every effect must work
  identically on every attack".
- The rules VX keeps (PLAN C81–C84): low-poly, faceted, readable silhouettes, bold element colours, no muddy glows or
  realistic particle soup; shaders, meshes and textures where they look better than primitives; every texture through
  an id with a code fallback; judged from the game camera.

## How it works today (short)

- **The Orbs** are drawn by three layers. `HeroPulseViews` draws each shot as a lit blue pulse with a short trail
  (`src/presentation/world_view/hero_pulse_views.gd:1-20`). `AttackFormView` adds the element trail and rim over it
  (`attack_forms/attack_form_view.gd:128-169`, `attack_forms/live_bolt_look.gd:72-110`). `ImpactFx` throws a flash,
  sparks, a spray and chunks at every hit, tinted by the first element (`impact_fx.gd:1-12`, `:187-198`).
- **The seven v0.9.0 forms** each have their own view in `src/presentation/world_view/attack_forms/`
  (`laser_view.gd`, `bomb_view.gd`, `void_view.gd`, `lance_view.gd`, `scatter_view.gd`, `glaive_view.gd`,
  `seekers_view.gd`). All but the Void take their element colours from `BeamLooks` (`beam_looks.gd:18-58`). Only the
  Laser, the Bomb and the Lance also draw on the effects layer (`VfxLayer`, `vfx/vfx_layer.gd:45-140`: flames, arcs,
  frost, drips, explosions).
- **Element colours live in two tables:** `AttackFormLooks.ELEMENT_CORE` (`attack_form_looks.gd:47-62`: the Orbs, the
  Lance's ball in flight, the impacts) and `BeamLooks.STYLE` (`beam_looks.gd:37-44`: the other forms).
- **Effects density** ("low" / "medium" / "high") scales the canvas's particles and caps
  (`attack_form_canvas.gd:7-9`) and thins the pulses' trails (`hero_pulse_views.gd:17`).
- The elements are Fire (`ember`), Lightning (`storm`), Frost, Venom and Bleed (Q11). **Void is a form, not one of the
  five elements.** The `void` element tag survives only on `phase_dash` (and the retired `gravity_well`), and
  `VfxLayer` keeps a void look for it.

**Shots:** today's looks, from the game camera, are already in the evidence folders. They're referenced per row.
- Laser, every element: `evidence/lzbm_shots/1_laser_default.jpg` … `6_laser_bleed.jpg`.
- Bomb: `evidence/lzbm_shots/7_bomb_flight.jpg`, `8_bomb_blast.jpg`, `9_bomb_blast_fire.jpg`.
- Void: `evidence/vp_shots/1_void_flight.jpg`, `2_void_close.jpg`, `3_void_twin_fire.jpg`.
- Lance: `evidence/af1b_shots/1_lance_charged.jpg`, `2_lance_ball.jpg`.
- Scatter: `evidence/af1_shots/3_scatter_cone.jpg`.
- Glaive and Seekers: `evidence/af2_shots/1_glaive_coming_back.jpg`, `2_seekers_curve.jpg`.

No new shots were taken for this audit. The existing scripts cover the forms only, and shots of the Orbs and the
patterns would need a new shot script, which is code. V52 proposes it for the build.

---

## 1. Gun forms

### 1.0 Shared by every form

| # | What | Today (file:line) | Proposal | Cost | Approve? |
|---|---|---|---|---|---|
| V1 | One element palette | Two tables disagree. Fire is `#FFAA33` on an Orb (`attack_form_looks.gd:49`) but `#FF6A1A` edge on the other forms (`beam_looks.gd:39`). Bleed on an Orb is the hero's cyan pulled 70 % toward Serrated Edge's colour (`attack_form_looks.gd:147-150`); on the other forms it's dark red `#8E0A1C` (`beam_looks.gd:43`) | One `ElementLooks` table (core, edge, accent kind, impact kind per element) read by `AttackFormLooks`, `BeamLooks` and `ImpactFx`. **Decide** Bleed: (a) dark red everywhere ← recommended, it reads as blood; (b) keep the Orbs' tinted cyan | M | ☐ |
| V2 | Two elements on one attack | The Orbs show the first element's core and the second's rim (`attack_form_looks.gd:127-137`, ART_DIRECTION §4). The BeamLooks forms pick one element by a fixed order, Fire > Lightning > Frost > Venom > Bleed, and drop the second (`beam_looks.gd:20-26`, `:54-58`) | The BeamLooks forms follow ART_DIRECTION too: the first element's core and the second's edge. Each form's accent (V6, V15, V22, V25, V29) uses the first element | S | ☐ |
| V3 | A launch cue for shots | No form-agnostic muzzle cue. An Orb pulse simply appears; only a crit adds a white flash (`attack_form_canvas.gd:246-248`) | A small muzzle spark: 2 spark sprites in the element's edge colour, no light, 6 ticks, one per volley (never one per copy), from `VfxCore`'s spark pool. Used by the Orbs, Seekers and Backfire (V27, V35). Off at Low | S | ☐ |
| V4 | Element impacts | `ImpactFx` gives every hit the same shape (flash, sparks, spray, chunks, a puff), only tinted (`impact_fx.gd:187-198`, `:234-281`) | One small extra per element on bolt-like hits, from the pools that already exist: Fire 2 embers and a wisp of smoke; Lightning a short fork (`bolt` pool); Frost 3 ice glints; Venom a small splash (`splash` pool); Bleed a splatter mark (`fx_splatter_mark`). Inside `ImpactFx`'s merge and budget (`MAX_LIVE`, `MERGE_M`); none at Low | M | ☐ |

### 1.1 Orbs (F1, the default)

| # | What | Today (file:line) | Proposal | Cost | Approve? |
|---|---|---|---|---|---|
| V5 | Travel | A lit blue pulse with a soft glow and a short trail (`hero_pulse_views.gd:1-20`), plus the element's trail segments and rim dart (`live_bolt_look.gd:72-104`) | Keep | — | ☐ |
| V6 | Element in flight | **The element's particles never draw on a live Orb.** With the effects layer on (it is in the game: `world_view_root.gd:308`), `LiveBoltLook.draw` skips the particles because "the VfxLayer draws this element's" (`live_bolt_look.gd:108-110`, `attack_form_canvas.gd:415-423`), but nothing calls the layer for live bolts. A Fire Orb is an orange-trailed pulse with no embers. Read from the code; not checked in a shot | Each live Orb gets its element accent from the layer's sprite pools, 1–2 pieces a bolt a frame: Fire embers falling behind; Lightning a tiny crackle arc every few ticks; Frost a glint; Venom and Bleed a drip. Capped by `LIVE_BOLTS_MAX` (`attack_form_canvas.gd:16`); none at Low (the pulse and trail stay). The Lance's ball in flight gets it too (V18) | M | ☐ |
| — | Launch | Nothing (see V3) | V3 | — | — |
| — | Impact | `ImpactFx` (see V4) | V4 | — | — |

### 1.2 Laser (F2)

| # | What | Today (file:line) | Proposal | Cost | Approve? |
|---|---|---|---|---|---|
| V7 | Launch and travel | A muzzle glow at the hero (`laser_view.gd:103-134`); a camera-facing ribbon with a scrolling strip per element (`beam_looks.gd:37-44`, a code strip or the `beam_core_<look>` PNG: `:84`); the element's accent along it from the layer (Fire flames, Lightning arcs, Frost motes, Venom and Bleed drips: `laser_view.gd:195-207`). Shots `lzbm_shots/1-6` | Keep | — | ☐ |
| V8 | Impact | A flickering star in the look's colours, 3 sparks and a light (`laser_view.gd:208-218`); the same star shape for every element apart from its spikes and flicker (`beam_looks.gd:36-44`) | Add V4's element extra at the beam's end, at most twice a second per beam (not on every damage tick) | S | ☐ |

### 1.3 Bomb (F3)

| # | What | Today (file:line) | Proposal | Cost | Approve? |
|---|---|---|---|---|---|
| V9 | Launch and travel | No launch cue. A faceted iron bomb tumbles in flight with a fuse spark in the element's colour (`bomb_view.gd:1-8`). Shot `lzbm_shots/7_bomb_flight.jpg` | Keep (the bomb is lit matter and reads on its own) | — | ☐ |
| V10 | Impact: the blast ring | A ring sweeps out to the blast radius, **flat on the floor** (y 0.08: `bomb_view.gd:239-246`), in BeamLooks' core and edge. **Fire's edge `#FF6A1A` and Bleed's `#8E0A1C` sit in the telegraphs' hostile hue band** (300°–34°, `attack_form_looks.gd:81-85`; the telegraph is `#FF6A3D`). Every other player ground mark goes through `ground_safe()` (`attack_form_looks.gd:261-268`); this ring doesn't | Pass the ring's colours through `ground_safe()` (Fire leans toward amber, Bleed toward a cool crimson), and add a unit test that no form's ground mark is a hostile hue (V49) | S | ☐ |
| V11 | Impact: no-element blast | A bomb with no element draws the layer's **fire** explosion (`bomb_view.gd:256-258`) | **Decide:** (a) keep the fire explosion ← recommended (explosions only come from the Bomb now, Q11, and fire reads as "explosion"); (b) a blue energy pop in the Gun's colours | S | ☐ |
| — | Element | The layer's burst for the element: Lightning, Frost, Venom, Bleed each have their own (`vfx_layer.gd:121-137`). Shot `lzbm_shots/9_bomb_blast_fire.jpg` | Keep | — | — |

### 1.4 Void (F4)

| # | What | Today (file:line) | Proposal | Cost | Approve? |
|---|---|---|---|---|---|
| V12 | Launch | None: the sphere appears at full size | The lens grows from a point to full size over its first 6 ticks (a shader uniform, no new node) | S | ☐ |
| V13 | Travel | A travelling lensing sphere: a dark core, a lens that bends the picture behind it with a violet bent-light rim (the `void_lens` PNG when installed: `void_view.gd:114`), swirling dust arms, 3 dust puffs behind, a faint ground ring at its aura's reach (`void_view.gd:1-26`). Shots `vp_shots/1-2` | Keep | — | ☐ |
| V14 | End | A shot that ends just disappears (VoidView draws only shots in flight: `void_view.gd:163`) | The collapse: the lens shrinks to a point with a small violet flash, 8 ticks (a short-lived entry in the view's pool) | S | ☐ |
| V15 | Element | **The Void ignores elements.** Every colour is the `VIOLET` constant (`void_view.gd:22`, `:121`, `:148`); it never reads BeamLooks. Shot `vp_shots/3_void_twin_fire.jpg`: a Fire Void is plain violet | Keep the violet body and dark core (the form's identity). The element tints the bent-light rim and the dust trail, and adds its accent to the trail at Medium and High (Fire embers, Lightning crackle, Frost glints, Venom and Bleed drips) | S | ☐ |

### 1.5 Lance (F5, the charged ball)

| # | What | Today (file:line) | Proposal | Cost | Approve? |
|---|---|---|---|---|---|
| V16 | Charge | A swirling energy circle in front of the hero: arcs turning both ways, motes spiralling in, in the element's colours; it grows, brightens, spins faster and pulses once full (`lance_view.gd:1-7`). Shot `af1b_shots/1_lance_charged.jpg` | Keep | — | ☐ |
| V17 | Release | A burst at the muzzle (a ring thrown outward and a hot flash), sparks and a light (`lance_view.gd:8-10`, `:202-217`), **and a camera kick** back along the aim (`lance_view.gd:176`, `KICK_M` 0.12 m at full charge; none with shake off). Q17 lists the camera moves that stay: the door landing, getting hit, the Blade finisher, the Blade hit kick. The Lance's kick came later (AF1b) and isn't in that list | **Decide:** (a) drop the camera kick ← recommended; the hero's own step back (AF1b) carries the recoil; (b) keep it and add it to Q17's list | S | ☐ |
| V18 | Travel | The ball is the Orb's own look, scaled by its radius (`lance_view.gd:12`, `attack_form_view.gd:172-176`) | Inherits V6's element accent. A full charge also gets the long streak trail (9 segments instead of 4, `attack_form_canvas.gd:27-28`), so a charged ball reads as heavier | S | ☐ |
| V19 | Impact | It pierces everything; each hit goes through `ImpactFx`. Nothing marks where a wall stops it | Where a wall stops it: a flash plus V4's element extra | S | ☐ |

### 1.6 Scatter (F6)

| # | What | Today (file:line) | Proposal | Cost | Approve? |
|---|---|---|---|---|---|
| V20 | Launch | A muzzle cone as wide as the spread that flares and fades in 9 ticks (`scatter_view.gd:1-6`, `CONE_TICKS`). Shot `af1_shots/3_scatter_cone.jpg` | Keep | — | ☐ |
| V21 | Travel | Short hot slugs stretched along their flight, in the element's colours (`scatter_view.gd:1-4`) | Keep | — | ☐ |
| V22 | Element | Colour only; no accent on the layer | The accent goes on the cone, not the 6 pellets: Fire an ember spray, Lightning a crackle across the fan, Frost motes, Venom and Bleed droplets (4–6 sprites a volley). None at Low | S | ☐ |
| — | Impact | `ImpactFx`; 6 pellets on one enemy merge into one impact (`impact_fx.gd` `MERGE_M`) | V4 | — | — |

### 1.7 Glaive (F7)

| # | What | Today (file:line) | Proposal | Cost | Approve? |
|---|---|---|---|---|---|
| V23 | Launch | None | Keep (the 1 m disc reads by itself) | — | ☐ |
| V24 | Travel | A flat spinning disc: a bright rim, three curved blades round a hot hub, two fading afterimages; on its way back it spins the other way and burns brighter (`glaive_view.gd:1-8`). Shot `af2_shots/1_glaive_coming_back.jpg` | Keep | — | ☐ |
| V25 | Element | Colour only (`glaive_view.gd:111-117`) | The rim sheds its accent, 1–2 sprites a disc a frame: Fire embers, Lightning an arc between two blades, Frost glints, Venom and Bleed drips | S | ☐ |
| V26 | Catch | The disc disappears when it gets back (GlaiveView draws only discs in flight: `glaive_view.gd:90-108`) | A small catch flash at the hero's hand, 4 ticks | S | ☐ |

### 1.8 Seekers (F8)

| # | What | Today (file:line) | Proposal | Cost | Approve? |
|---|---|---|---|---|---|
| V27 | Launch | None | V3's muzzle spark, fanned three ways (one per dart) | S | ☐ |
| V28 | Travel | A thin needle of light per dart with 5 fading motes behind it, so the curve reads (`seekers_view.gd:1-12`). Shot `af2_shots/2_seekers_curve.jpg` | Keep | — | ☐ |
| V29 | Element | Colour only (`seekers_view.gd:115-116`) | With the effects layer on, the trail motes become the element's own sprite (an ember, a crackle, a shard, a drip) instead of a round mote. Same count, so the cost stays the same | S | ☐ |

### 1.9 Wave and Wisps (F9, F10: planned, being built in AF3)

From [`ATTACK_FORMS.md`](ATTACK_FORMS.md) rows F9 and F10 only; their code isn't merged and wasn't read. These rows ask AF3 to build the look this way. If AF3 lands first, VX checks it against them.

| # | What | Today (file:line) | Proposal | Cost | Approve? |
|---|---|---|---|---|---|
| V30 | Wave (F9): "a wide slow wave that rolls forward through everything", 3 m wide, 6 m/s, pierces, every 0.9 s | Planned (`ATTACK_FORMS.md:36`) | A low curved band as wide as the hit (3 m: what you see is what hits, O18), in the shared element palette (V1). A skim of dust or the element's accent at its foot. It fades over its last metre. Launch: the band unrolls from the hero over 4 ticks | (AF3) | ☐ |
| V31 | Wisps (F10): "orbs circle you and fire on their own", 3 wisps, a 40 % orb every 0.6 s | Planned (`ATTACK_FORMS.md:37`) | Three small pulses (the Orb's lit look at about 0.7×) circling the hero in the element's colours. Each one flashes as it fires, and its shot is a plain Orb (V5, V6). No orbit ring | (AF3) | ☐ |

## 2. Patterns and motion cards

| # | What | Today (file:line) | Proposal | Cost | Approve? |
|---|---|---|---|---|---|
| V32 | Twin (merged with Spread, Q8) | The copies fly side by side, or fan 15° at three; the Laser draws 2–3 beams. `AttackFormLooks` composes a `twin` cue (`attack_form_looks.gd:196-198`) but **nothing in `src/presentation` draws it** | Keep: the copies are the cue. Delete the unused `twin` cue | S | ☐ |
| V33 | Halo | `count` copies evenly round the hero (`attack_form_looks.gd:247-250`); no cue of its own | A quick ground ring at the hero as a Halo volley leaves (0.8 m, 8 ticks, `ground_safe` colour), so the circle reads as one cast. None at Low | S | ☐ |
| V34 | Ring | The RING form: an expanding circle with a ground-safe fill and a raised front (`attack_form_canvas.gd:578-616`). Ring adds the Lightning element, so the layer draws its storm ring (`:601`), and rings launched together are joined by shock arcs (`attack_form_view.gd:276-316`) | Keep | — | ☐ |
| V35 | Backfire | Each shot's mirror flies behind (`attack_form_looks.gd:254-256`); no cue | V3's muzzle spark at the back too, so the rear shot has a visible source | S | ☐ |
| V36 | Spiral (motion) | A corkscrew path. `AttackFormLooks` composes a `helix` cue (`attack_form_looks.gd:196`) but nothing draws it. The live trail is only 4 segments (`attack_form_canvas.gd:27`), too short to show the corkscrew | A Spiral bolt uses the long trail (9 segments, as Pierce's streak does), so the corkscrew reads | S | ☐ |
| V37 | Swirl (motion) | On rings: a storm strike from the hero to where each thrown ring lands, 6 ticks (`attack_form_view.gd:285-291`). On bolts: each leaves at a random angle up to 60° (`src/sim/combat/wand_rings.gd:41`, `:127`), with no cue | Keep the ring strike. **Decide** bolts: (a) no cue ← recommended, the random angles are the cue; (b) a small curl in each bolt's first 6 ticks of trail | S | ☐ |
| V38 | The other secondaries | Pierce has its streak, Ricochet a flash at each bounce, Homing a curved trail, a returning shot its tether, a mine its ground ring (`attack_form_looks.gd:188-199`, `live_bolt_look.gd:96-108`). Echo, Big Shot and Rapid Fire show only as more, bigger or faster pulses (C79) | Keep. Size already equals the hit size (O18), and more cues on top would be noise | — | ☐ |

## 3. The Blade

| # | What | Today (file:line) | Proposal | Cost | Approve? |
|---|---|---|---|---|---|
| V39 | Blade looks | No PLAN VX row (C49, C56, C72, C79–C84) names the Blade. Q6 keeps forms Gun-only, and AS says the Blade rework is pending, not part of this version | No Blade change in VX. If V1 is approved, the Blade's element colours come from the shared table, as they do today through `AttackFormLooks` | — | ☐ |

## 4. Textures

What's in `assets/textures/vfx/` today: 36 PNGs. Through `VfxCore`'s pools (`vfx/vfx_core.gd:11-41`), the attack
forms already use `fx_flame_shapes`, `fx_explosion_burst`, `fx_smoke_puffs`, `fx_debris_chunks`, `fx_spark_shapes`,
`fx_lightning_bolts`, `fx_liquid_splash`, `fx_bubbles`, `fx_void_tendrils`, `fx_void_rift` and the floor marks
(`fx_scorch_mark`, `fx_frost_mark`, `fx_frost_burst`, `fx_splatter_mark`). The rest serve bosses, enemies, props and
menus. `fx_electric_noise` is used nowhere (no match in `src/`). The art list's effect textures are
`docs/art/requests/v0.9.0_ART_LIST.md` **§7** (the brief said §6; §6 is sounds). None of the four is delivered.

| # | What | Today (file:line) | Proposal | Cost | Approve? |
|---|---|---|---|---|---|
| V40 | `beam_core_<look>` × 6 (default, fire, lightning, frost, venom, bleed), 1024 × 128 | Not delivered. The Laser looks for it (`beam_looks.gd:84`) and falls back to the code strip (`beam_looks.gd:88+`) | Keep the code strip. **Texture** (optional): your strips replace it with no code change | — | ☐ |
| V41 | `blast_ring`, 512 × 512, white on transparent | Not delivered. The Bomb looks for it (`bomb_view.gd:104`) and falls back to a code band | Keep the code band. **Texture** (optional) | — | ☐ |
| V42 | `void_lens`, 512 × 512 | Not delivered. The Void looks for it (`void_view.gd:114`) and falls back to the code rim | Keep the code rim. **Texture** (optional) | — | ☐ |
| V43 | `fire_patch` (Fire's burning ground, XP) | Not delivered, and **no code looks it up** (no match in `src/`). The patch draws as the layer's fire field (`attack_form_view.gd:218-240`, `attack_form_canvas.gd:676`) | Hook the id up: a flat decal under the flames when installed; the flames alone stay as the fallback. **Texture** (optional) | S | ☐ |
| V44 | Element accents and impacts (V4, V6, V15, V22, V25, V29) | — | **No new textures needed:** they use the pools above (`spark`, `flame`, `bolt`, `splash`, splatter marks). Lightning crackle may use the unused `fx_electric_noise` as its scroll | — | ☐ |
| V45 | One list of VFX ids (C83) | Ids are bare file names checked with `ResourceLoader.exists` in two places (`fx_textures.gd:76-78`, `vfx/vfx_core.gd:297-307`); there's no list the way `assets/models/manifest.json` lists models | `assets/textures/vfx/manifest.json`: each id with its use, tint mode and code fallback. An asset test checks that every id the code asks for is listed, and that each listed id has its file or is marked "fallback". Covers V40–V43 | S | ☐ |

## 5. Readability and performance rules

| # | What | Today (file:line) | Proposal | Cost | Approve? |
|---|---|---|---|---|---|
| V46 | Hostile fireballs never use the hero's attack colours (BOSS_FIGHTS "Readable") | The test only compares the hostile cores with the hero's cyan and the heat colours (`tests/unit/presentation/test_boss_fight_views.gd:47-56`), not the element colours. With the test's own distance (RGB, bar 0.2) on the colours in the code: Arc Caster's `arc_plasma` core `#C8DCFF` vs Frost's core `#B5F2FF` is **0.114**; `spear_ember` `#FF7A6B` vs the Bleed beam core `#FF7080` is **0.091**; `crown_orb` `#FF729E` vs that Bleed core is **0.118** (`fireball_views.gd:52`, `:70`, `:156`; `attack_form_looks.gd:50`; `beam_looks.gd:43`). Every hostile look keeps its dark edge, and the hero's shots never have one | Extend the test to every element core and BeamLooks core. **Decide** the three pairs: (a) move the hero's side, Frost a little greener and the Bleed core darker (follows V1's dark red) ← recommended, the boss looks stay as approved; (b) move the hostile looks | S | ☐ |
| V47 | Effects density Low keeps the core shapes | The canvas and the pulses follow it (`attack_form_canvas.gd:7-9`, `hero_pulse_views.gd:17`), and the layer accents thin with `VfxCore.density`. **None of the seven v0.9.0 views reads `ViewPrefs.effects_density` or reduced motion** (no match in `laser`, `bomb`, `void`, `lance`, `scatter`, `glaive`, `seekers_view.gd`) | At Low: the Void keeps its core, lens and ring and drops the dust disc and trail puffs; the Glaive drops its afterimages; the Seekers keep 2 motes; the Lance's motes halve; the Laser ribbon, impact star, Scatter cone and bomb ring stay. Reduced motion stills the swirls (the Void dust, the Lance circle), as the pulses do. A unit test per view | S | ☐ |
| V48 | No per-frame allocations, pooled meshes | The nodes are pooled (fixed arrays built once, e.g. `glaive_view.gd:62-71`). Each sync (once per tick) still allocates: a new Dictionary and Array in Scatter (`scatter_view.gd:136`, `:154`); a new Dictionary and array slices per disc or dart in the Glaive (`glaive_view.gd:95-108`) and the Seekers (`seekers_view.gd:97-111`); and every view rebuilds a `PackedStringArray` from the attack spec (e.g. `scatter_view.gd:131-133`) | Reuse member buffers; cache the look per attack digest, as `ImpactFx` does (`impact_fx.gd:180-184`). Every new VX piece goes through `VfxCore`'s pools and frame caps or a view's fixed pool, never a node per effect | S | ☐ |
| V49 | Player ground marks stay out of the hostile hues | `ground_safe()` covers the canvas's marks (`attack_form_looks.gd:17-20`); the bomb ring is the exception (V10) | Rule for every VX ground mark (V10, V33, the Void ring, V43), checked by one unit test over every form and element | S | ☐ |
| V50 | Hostile shots keep their dark edge; the hero's never get one | Hero pulses: no dark edge (`hero_pulse_views.gd:5-7`, tested by `test_gun_pulse.gd:131`). The new forms' shaders draw additive light (no dark edge seen in the code) | Keep. The V46 test also asserts that no BeamLooks edge is darker than luminance 0.15 | S | ☐ |
| V51 | Flashes stay additive light, debris stays lit matter (ART_DIRECTION §4, the v0.5.5 A3 rule) | Followed by the pools (`vfx_core.gd:11-26`: the blend flag per pool) | Keep. Every V-row above uses the pool whose blend matches (sparks and flashes additive, drips and splashes lit) | — | ☐ |
| V52 | Judged from the game camera (C84) | Shots exist per form (above); no shot script covers the Orbs' elements or the patterns | VX adds one shot script with one contact sheet per form (the 6 element looks tiled) plus one sheet of the patterns (Twin, Halo, Ring, Backfire, Spiral, Swirl on the Orbs): 9 shots at 1280 × 720 from the game camera, at Medium density. Owner looks at those | S | ☐ |

## Rows per section

| Section | Rows |
|---|---|
| 1. Gun forms (1.0 shared + 1.1–1.9) | V1–V31 (31) |
| 2. Patterns and motion cards | V32–V38 (7) |
| 3. The Blade | V39 (1) |
| 4. Textures | V40–V45 (6) |
| 5. Readability and performance | V46–V52 (7) |

## Decisions (owner, date)

| Row | Answer | Built in |
|---|---|---|
| | | |

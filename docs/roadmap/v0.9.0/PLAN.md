# v0.9.0 — World and weapons: the owner's v0.8.0 feedback (plan, owner answers 2026-10-22; Steps await the owner's go)

Recorded so these decisions never depend on chat context. Progress: [`PROGRESS.md`](PROGRESS.md).

**DRAFT:** written in Phase 0, before any code. **Q1–Q30 answered 2026-10-22** (see "Owner decisions"; they win over
the decision column where the two differ). The Steps below are rewritten from the answers. The owner-lines table is complete, but much of the
decision column reads **Decide: Qn**. Nothing except the direct fixes is built until the owner answers the design questions below
(owner, 2026-10-22: "Ask me the design questions and gates before building anything that isn't a direct fix … the
idea is that we go through all new feedback together before the full plan"). The Steps section is the lead's draft
order. It is rewritten once the answers are in, and then the PLAN is marked owner-approved.

The owner, 2026-10-22, verbatim:

> "v0.9.0 starts now. v0.8.0 is released: PR riusprime/zero-depth#7 is merged, so main is at aeef604a, version 0.8.0,
> and I've played it. … Attached are my two feedback documents for v0.9.0. … Every line of my feedback gets a row.
> Also carry over from v0.8.0: UC, the utility cards. The G1 list is docs/roadmap/v0.8.0/UTILITY_CARDS.md (D23) and I
> haven't answered it yet. The rest of EM, the enemy models. … Ask me the design questions and gates before building
> anything that isn't a direct fix. We should go over the new features and you can make questions that you think it'd
> be the best for new features we are implementing … This runs on my PC, so you can run several Godot test jobs at
> once, each with its own APPDATA folder."

The two documents are kept as sent:
- **C:** [`feedback/2026-10-22_combat_visual_overhaul.md`](feedback/2026-10-22_combat_visual_overhaul.md),
  "Gameplay, Combat & Visual Overhaul" (portals, the spawn altar, the final boss approach, the door sound, the
  attack-form / pattern / element restructure, the legendary nerf, VFX, text).
- **W:** [`feedback/2026-10-22_world_elites_progression.md`](feedback/2026-10-22_world_elites_progression.md),
  "ZeroDepth 2.0: World Interaction, Elite Enemies & Progression Expansion" (timed doors, lockdowns, puzzles,
  interactions, shrines, collectibles, the hub, meta currency, robes and affinities, the elite redesign, pacing).

## Context
- **`main`** is v0.8.0 at `aeef604a` (PR riusprime/zero-depth#7, merged; v0.7.5 is inside it). The green `verify`
  total on PR #7 is 2676 (run 39746843277, job 119737208104: e2e 159, presentation 838, rest 269, sim_a 764,
  sim_b 612, sim_c 34). `tests/MIN_TEST_COUNT` is raised 1904 → 2676 in this branch's first commit (`78271656`).
- **Branch:** `claude/world-combat-v090`, cut from `origin/main` at `aeef604a`. It runs on the owner's PC
  (CLAUDE.md "The owner's PC"), so several Godot jobs can run at once, each with its own `APPDATA`.
- **The playtest rule (ROADMAP §0.3) is met.** The owner played v0.8.0 (O92 in [`../v0.8.0/PLAN.md`](../v0.8.0/PLAN.md),
  2026-10-22), and these two documents are that playtest's feedback.
- **Owner rule:** anything that isn't a direct fix is decided before it's built. The direct fixes here are DS (the
  door sound) and VP's removal of the floor black hole once VP's design is agreed. Everything else waits on its
  question or gate.
- **Live code audited 2026-10-22** by four read-only investigations: combat; portals, altar, door and camera; elites,
  rooms and persistence; EM and UC. The facts, with `file:line`, are in "Audit" below.
- **Carried over from v0.8.0:** UC (the utility cards; the G1 list was never answered, D23) and the rest of EM (enemy
  models: Swarmer, Mine Layer and Sniper still have no owner model).
- **Conflicts with higher-ranked sources.** The owner's documents disagree with five earlier rules (CLAUDE.md:
  "never resolve a conflict quietly"). Each is a question below:
  - **X1** "one primary pattern" vs v0.8.0's ordered chains (O37, D45's Ring · Spread · Swirl storm) and O91's
    "Preserve … ordered modifiers … slots growing 4→6→8" (Q2, Q3);
  - **X2** C §11's "clear explanation … correct numerical descriptions" vs O74's "remove all the explaining texts
    … not explain anything", applied in v0.8.0 N16 and N18 (Q14);
  - **X3** W §2's 12–18 s timed door vs PD-05's "no global clock and no enrage timer" (Q20);
  - **X4** W §10.5's "final two floors" vs PD-03's three-floor run, and today's Deep floor, which puts an elite in
    every combat room (Q24);
  - **X5** W §10's distinct elite archetypes vs today's elite: a ×2 HP copy of a normal enemy carrying a stealable
    core (Q25).

## Every owner line → where it lands

Rows **C1–C52** are the combat and visual document and **W1–W70** the world document, in document order. **E1–E2** are
the carry-overs. The "Step" codes are defined in Steps.

### C: Gameplay, Combat & Visual Overhaul

| # | Owner line (verbatim or close) | Decision | Step |
|---|---|---|---|
| C1 | §1 "Replace the existing squar portals that appear after defeating a floor boss" | **Change.** Today both gates (the blue gate and the violet Deep gate) are built when the floor loads and stand sealed all floor; the boss's death only unseals them (`world_view_root.gd:302-322`, `boss_flow.gd:296-302`). New portals replace `PortalGate`'s square stone frame (`portal_gate.gd:22-23`, 2.4 × 3.2 m). Q15 | PT |
| C2 | "Two separate, narrow portals with vertically stretched, elongated shapes, kinda like rick and morty shape" | **Change.** Two tall, narrow, elongated portals: the normal gate and the Deep gate (the Purple Portal), at least 4.8 m apart as today (`routes.gd:22`). The loop's last floor keeps its Ascension portal and Loop device (they are not square gates). Q15: a code-made frame or an owner model | PT |
| C3 | "Retain the existing animated swirling interior rather than recreating the effect" | **Kept.** The swirl shader (`portal_gate.gd:79-157`: fbm noise, two counter-rotating layers, 3 arms, rim) is reused on the new elongated surface; only its mask changes to the new outline | PT |
| C4 | "They should materialize through a proper spawning animation after the boss dies, rather than appearing instantly" | **Change.** Nothing stands before the boss dies. At its death each portal materializes (a seam of light opens, stretches into the tall shape and the swirl fades in), over a starting value of 1.5 s. Today the seal lifts instantly with a 1.2 s flare (`portal_gate.gd:261-293`). Walking in works only once it has formed | PT |
| C5 | "The new portals should remain visually readable from ZeroDepth's isometric camera" | **Rule** for PT: checked in the real game camera (one shot per biome), not in an isolated preview | PT |
| C6 | §2 "Replace the current starting portal/platform with a substantially larger, fully modeled 3D altar" | **Change.** The code-made `FloorReceiver` (`floor_receiver.gd`, 2.2 m across; its model id is not in the manifest) is replaced by a modelled altar. Q16: which floors use it | SA |
| C7 | "Circular stone platform, approximately 3 times larger than the current structure" | **Change.** About 6.6 m across (3 × 2.2 m). The start hall (3 × 3 cells) fits it. Starting value | SA |
| C8 | "Three or four stone steps leading to the central platform" | **Change.** In the model (prompt in [`../../art/requests/v0.9.0_altars_portals.md`](../../art/requests/v0.9.0_altars_portals.md)). The sim has no height (ROADMAP §6), so the steps are visual and the altar is walkable floor | SA |
| C9 | "Ancient stone, consistent with the game's existing low-poly, faceted art direction" | **Rule** for the prompt (the kit prefix) | SA |
| C10 | "Floating or carved arcane runes arranged around the altar" | **Change.** Carved rune slots in the model; the floating runes are separate code objects so they can light up and orbit (Q16) | SA |
| C11 | "Glowing blue symbols, with optional small crystals or jewels around the sides" | **Change.** Blue in the hero's `player_core` family (`theme_palette.gd`); the jewels are separate pieces so each can light up in sequence | SA |
| C12 | "The symbols do not need a real language or meaning; their primary purpose is visual" | **Noted.** Glyph sheet made by the lead (the existing `fx_cast_sigils` style) or by the owner's generator | SA |
| C13 | "We need a new prompt for this model" | **Done in this commit:** [`../../art/requests/v0.9.0_altars_portals.md`](../../art/requests/v0.9.0_altars_portals.md) (the altar, its purple twin for the final approach, and an optional portal frame) | SA |
| C14 | Sequence 1 "Idle: The player initially sees an empty stone altar" | **Change.** The arrival opens on the empty altar, as N11 does today (no hero, nothing spawns, `boss_flow.gd:52-57`) | SA |
| C15 | 2 "Activation: Blue runes and jewels begin illuminating, possibly in sequence" | **Change.** Runes and jewels light one after another around the ring | SA |
| C16 | 3 "Rotation: The glowing symbols begin orbiting the altar, gradually increasing speed" | **Change.** The floating runes orbit and speed up | SA |
| C17 | 4 "Energy buildup: Blue particles, glow, magical noise, and swirling energy intensify around the center" | **Change.** Particles, a centre swirl and a rising hum. Today the arrival has **no sound** (no arrival cue in `audio_events.gd`); a buildup sound is needed (Q16: the lead makes a placeholder, the owner's file replaces it) | SA |
| C18 | 5 "Spawn: The existing player-spawn effect plays, synchronized with the main audio cue" | **Change.** The existing pop (`portal_transit_view.gd:282-315`: puff, burst ring, flash, scale overshoot) is kept and lands on the cue's peak | SA |
| C19 | 6 "Release: The runes slow down, energy dissipates, and control returns to the player" | **Change.** Wind-down, then control returns. The whole sequence needs more time than today's 96 ticks (`data/tuning/sim.tres:9`); Q16 sets the length (a sim tuning value, so goldens that cover arrival move) | SA |
| C20 | Camera: "The current camera shake moves diagonally and feels too directional" | **Agreed with the cause found.** The shake is a single amount drawn along a golden-angle path (`iso_rig.gd:73-76`) plus a directional `kick` at the pop (`portal_transit_view.gd`, `rig.kick(0.5 m)`). The kick is what pulls the camera across the screen | CV |
| C21 | "Replace it with a short, subtle vibration that conveys magical energy or a heavy impact without visibly pulling the camera across the screen" | **Change.** A small high-frequency vibration (noise on both axes, tiny amplitude) replaces the arrival's travelling shake, and the arrival drops its kick. Q17: the arrival only, or every shake in the game | CV |
| C22 | "The shaking should increase slightly during the buildup and peak at the spawn, then fade out naturally" | **Change.** The vibration follows the SA timeline: it ramps through the buildup, peaks at the pop and eases out | CV, SA |
| C23 | "Technical direction: Prefer a reusable altar scene with configurable colors, rune objects, animation timing, sound, and activation triggers" | **Change.** One altar scene (`AltarStage` or similar) with colour, rune set, timeline, sound and trigger as inputs. The blue arrival altar and the purple final altar are two configurations of it | SA, FA |
| C24 | "The runes can use custom textures, emissive materials, or independently animated 3D objects" | **Noted.** Runes are independent emissive objects on the existing sigil material (`fx_textures.gd:110-121`) until the owner's art exists | SA |
| C25 | §3 "The player should no longer teleport directly into the final boss arena" | **Change.** Today the Ascension portal loads `FinalArenaScenario` straight into FIGHT (`floor_plan.gd:91-107`, `final_arena_scenario.gd`). A new approach stage comes first. Q18 | FA |
| C26 | Sequence 1–2 "enters the final boss transition … arrives on a separate, quieter environment" | **Change.** A quiet approach floor with no enemies (Q18). It is not a run floor: no shards, chests or danger tiers | FA |
| C27 | 3 "stairs and a clear path leading toward a large altar (new platform where the boss will appear)" | **Change.** A causeway with stairs (visual steps, as in C8) up to the purple altar. Q18: whether the boss fight happens on that platform or the stage leads into today's ring arena | FA |
| C28 | 4 "The altar resembles the starting altar but has a more ominous purple appearance" | **Change.** The SA altar scene, purple configuration | FA |
| C29 | 5 "activate a small number of mechanisms, approximately two, around the altar" | **Change.** Two mechanisms, each worked with the existing `interact` action (E / pad X, `input_frame.gd:8`). They are the first users of the shared interactable (IX). Q18: press or hold | FA, IX |
| C30 | 6 "Once activated, the purple runes illuminate and begin spinning" | **Change.** Each mechanism lights its share of the runes; the second one sets them spinning | FA |
| C31 | 7 "A buildup animation begins, using a modified version of the starting altar sequence" | **Change.** SA's timeline in purple, longer and darker | FA |
| C32 | 8 "The final boss encounter is initiated" | **Change.** The Colossus rises from the altar at the end of the buildup (`final_boss.gd:141-160` spawn), followed by today's three-body fight | FA |
| C33 | Requirements: "Reuse the starting altar's models, animations, and scripts … Purple replaces blue … Activation mechanisms must provide obvious visual feedback … only trigger once the required activations are complete … without adding a long or tedious gameplay section" | **Rules** for FA: one altar scene, a purple palette, a lit and audible state per mechanism, the fight gated in the sim on both mechanisms, and a target of under 30 s from arrival to the boss at a walk | FA |
| C34 | "The exact stairs, layout, and mechanism design can be decided during implementation" | **Q18** proposes a layout and the owner picks | FA |
| C35 | §4 "The large impact or boom effect currently associated with the regular boss door opening is slightly late … just move it a bit earlier like 0.5s aprox" | **Direct fix, with a measurement to settle (Q19).** The impact cue fires at press + 162 ticks, the frame the slab bottoms out (`boss_flow.gd:170-178`, `audio_events.gd:192-193`). The lateness is inside the file: `boss_door_impact.wav` is near-silent for 0.15 s and peaks around 0.3 s. So the boom is heard about 18 ticks after the slab lands. Moving the trigger 0.5 s earlier would put the peak about 0.2 s before touchdown; 0.3 s earlier makes them meet. Only the cue moves; the slab's animation is untouched | DS |
| C36 | §5 "The current modifier system makes it possible to stack powerful upgrades until the player's basic attack becomes excessively strong, particularly with attack speed, multiple projectiles, and overlapping attack modifiers" | **Agreed, audited.** Nothing caps projectiles per attack: Twin, Spread and Halo multiply freely up to the 256 alive player shots (`attacks.gd:32`, `_shot_room` :356-370). Shares multiply (`attacks.gd:80-92`) | AS, BR |
| C37 | "Split the attack system into three independent categories": Attack Form / Attack Pattern / Elemental Effects | **Change.** A category on every attack card, held in data, with per-category slot limits. Today `loot_category` (form / element / advanced / mutation / trigger) only paces loot (`item_pool.gd:43-60`), and "form" means something else (Homing, Pierce, Mine are labelled form). Q2 | AS |
| C38 | "These categories should interact, but should not all be freely stackable" | **Change.** The slot limits and a compatibility table (C47) | AS |
| C39 | "Attack Form — one active … Equipping another replaces it" | **Change.** One form slot; a new form replaces the old one. Q5: how the replacement is shown and what happens to the old card | AS |
| C40 | "Attack Pattern — one primary pattern active … Twin, spread, ring, spiral, and similar modifiers should compete for the primary pattern position" | **Change, conflicts with X1.** Today Twin (`gun_twin`, "advanced") stacks with Spread, Halo, Ring, Spiral and Swirl, and v0.8.0 built order-dependent chains on purpose (O37; D45's storm is Ring · Spread · Swirl). Q2, Q3 | AS |
| C41 | "approximately two or three attack-shaping upgrade slots, but only one mutually exclusive primary pattern … Remaining slots … compatible secondary behavior upgrades" | **Q4**: the secondary slot count and which cards count as secondary (Pierce, Ricochet, Homing, Echo, Big Shot, Rapid Fire, Split, Mine, Charge, Orbit, Boomerang, Threadline today) | AS |
| C42 | "Elemental Effects — independent. Retain the existing elemental modifier system" | **Kept.** Elements stay cards. Today's element ids are ember, storm, frost, venom, void and bleed (`modifier_op_definition.gd:147`), plus Explosive in the element loot category | AS |
| C43 | "approximately six existing effect types … Confirm their exact names and behavior" | **Confirmed** (Audit A3): Fire (`ember_core`: burn 2 / 0.5 s, 3 s, 5 stacks, a kill blast), Frost (`frost_core`: slow, then freeze), Lightning (`storm_core`: a chain on hit), Venom (`venom_core`: poison that spreads), Bleed (`shared_bleed`), Void (`gravity_well`: the floor black hole). Explosive (`shared_explosive`) is also in the element category. With Void leaving (C70), five remain. Q11 | AS |
| C44 | "The final number of available element slots must be established after reviewing the current implementation" | **Q4** | AS |
| C45 | "Important: The exact slot counts are not finalized. Build the system so these limits can be adjusted through data/configuration" | **Rule.** Slot limits per category in `data/wand/wand.tres` (validated), editable in the F10 panel like other tuning | AS |
| C46 | §6.1 "Keep the existing normal ranged attack as the default … the baseline" | **Kept.** The Gun's blue pulse orb (v0.8.0 GF1; `runner.tres:63-67`) is the default form, Orbs | AS |
| C47 | "we should have around 8-10 total attack replacements. so there are multiple builds possible with the modifiers like twin or swirl" | **G1** [`ATTACK_FORMS.md`](ATTACK_FORMS.md): 10 candidate forms (Orbs, Laser and Bomb as named, Void as named in §6.4, plus 6 of the lead's) with a compatibility row each; approved row by row. Q6: Gun only, or the Blade too | AF |
| C48 | §6.2 Continuous laser: "Holding the attack button continuously fires a laser … frequent ticks … substantially less damage than an orb hit … competitive, potentially higher single-target damage … follows the player's aim" | **Change.** A held beam form (hold-to-fire exists: `player_kit.gd:118-121`). The BEAM form exists only as chains and Scatter Blast's rays (`attacks.gd:10`). Q8 | LZ |
| C49 | Laser element looks: "Default: Original energy color … Fire: A layered beam … Venom: Green or toxic … Electricity: Blue-white or electrical arcs … Other existing elements should receive equivalent treatment … The color change alone is not sufficient: ideally the impact effect and beam texture also reflect the element" | **Change.** One beam look per element: core colour, texture scroll, impact particles and an element accent (arcs, drips, embers, frost, bleed). Built on `vfx_layer.gd:45-100`'s element looks | LZ, VX |
| C50 | Laser balance: "Consider range, tick frequency, sustained aiming, target penetration, and exposure time … Avoid giving the beam the entire benefit of projectile count or attack-speed bonuses … mechanically distinct from simply firing orbs extremely quickly" | **Q8** starting values: range, ticks a second, pierce rule, how attack speed and patterns apply | LZ |
| C51 | §6.3 Bomb launcher: "launches bombs toward the aiming direction … approximately one bomb per second … explode on impact or according to a consistent, short detonation rule … damage enemies within a defined area … Elemental effects apply to the explosion" | **Change.** A bomb form. The LOB form exists (`attacks.gd:105, 535-569`), and the old Bomb Lobber ability and Bomb Rounds card are retired (`migration.tres`). Q9: a lob to the aim point or a straight throw | BM |
| C52 | Bomb compatibility: "Allowed: Bomb + Twin … Bomb + elemental effects. Not allowed: Bomb + Ring. Bomb + another primary attack form such as Laser. Spread … requires an explicit compatibility decision" | **Change** as written; **Q9** decides Spread | BM, AS |
| C53 | Bomb balance: "larger damage per individual attack, with lower frequency … Account for AoE damage, multiple enemies hit, explosion overlap, and interactions with attack speed … Twin bombs should be effective but not automatically double overall damage efficiency" | **Q9** starting values (damage, radius, how attack speed applies, Twin's share). Overlaps merge under the existing 8-per-tick blast budget (`attacks.gd:747-753`) | BM |
| C54 | §6.4 "Remove the previously planned effect that randomly creates a gravity point on the floor and attracts enemies … deleted from the item pool and associated attack behavior" | **Change (the owner's direct instruction).** Void (`gravity_well`, the v0.8.0 O24 floor black hole) is retired through `migration.tres` (old saves keep loading), and `black_holes.gd`, `black_hole_views.gd` and the `hole_*` tuning are deleted. It lands with VP so the pool never loses Void without its replacement | VP |
| C55 | "The player fires miniature black-hole projectiles … travel in the aiming direction … nearby enemies experience a weak gravitational pull toward its trajectory … damage in a small area around itself … subtle … Enemies can still pursue and attack normally" | **Change.** A Void form: a slow projectile with a damage aura and a weak pull towards its path | VP |
| C56 | "The visual should communicate a moving gravitational anomaly, not a stationary vortex" | **Change.** A travelling lensing sphere with a dark core, swirling dust and a bent-light rim; enemies in range lean into it | VP, VX |
| C57 | Void balance: "Limit the pull strength and radius … Avoid infinitely dragging enemies … reduced effectiveness against bosses or large enemies … Avoid multiple void projectiles creating extreme enemy displacement or performance issues" | **Q10** starting values; the pull on one enemy is capped per tick however many voids overlap (no stacking) | VP |
| C58 | "This form may work with certain projectile patterns, but compatibility should be tested before enabling combinations" | **Q10**: which patterns are on at first | VP, AS |
| C59 | §7 Patterns table (Twin, Spread, Ring, Spiral, Swirl) "Review the game's existing patterns first. Do not create duplicates" | **Reviewed** (Audit A2): Twin, Spread, Halo (a full circle, so a duplicate of "ring" in the owner's sense), Ring (a travelling ring since O47), Spiral, Swirl and Backfire already exist. No new pattern is proposed | AS |
| C60 | "Create a centralized compatibility system instead of special-casing every item separately" | **Change.** One table in data: form × card → allowed / allowed with a rule / not allowed. Every check (offers, equip, compile) reads it | AS |
| C61 | Compatibility table (Orbs: all yes; Laser: Twin/Spread tailored, Ring/Spiral no; Bomb: Twin yes, Spread to decide, Ring no, Spiral no; Void: test) | **Starting table** as written; each "to decide" or "test" cell is a row in ATTACK_FORMS.md or Q8–Q10 | AS |
| C62 | "'No by default' and 'test and balance' are proposed initial restrictions … Do not silently introduce unapproved interactions" | **Rule.** Every cell starts **off** unless the owner marks it on | AS |
| C63 | "Core rule: Different attack forms cannot coexist as simultaneous primary weapons" | **Change.** Today a second SET_FORM adds a layered extra attack (`wand_compile.gd:153-160, 293`); that layering is removed for forms | AS |
| C64 | Examples "Laser + Bomb: Not allowed … Bomb + Twin: Allowed … Bomb + Ring: Not allowed … Orb + Twin: Allowed … Twin + Ring: Not simultaneously active" | **Rules**, written as e2e cases | AS |
| C65 | "Each attack form should define its supported patterns and supported effects" | **Change.** Each form's `.tres` lists them, read through the C60 table | AS |
| C66 | "The card/loot selection system must respect these rules. An incompatible modifier should not be offered" | **Change.** `ItemPool.usable` (`item_pool.gd:87-99`) drops cards the current form can't use | AS |
| C67 | "If replacing an equipped form or pattern is supported, the UI must make the replacement obvious" | **Change.** The card says what it replaces; **Q5** decides the details. G2 for the card and Build page change | AS |
| C68 | §8 "Preserve the elemental identities … rather than inventing a separate element system" | **Kept** | AS |
| C69 | "Known examples include: Fire, Venom, Electricity / Shock" | **Confirmed** (C43) | — |
| C70 | "Void … becomes a new attack modifier where you throw the black holes as a gun, lower frequency … a subtle pull … they should never move really fast 10 enemies at the same point … the elemental effect of void is replaced by the other one" | **Change.** Void stops being an element and becomes the VP form (C54–C58). The pull never stacks enemies into one point: a speed cap and a separation push keep them apart | VP |
| C71 | "Confirm the remaining existing effects from the game's current definitions" | **Confirmed** (C43); **Q11** decides whether Explosive counts as an element | AS |
| C72 | "Elements should modify the chosen attack form … Fire + Laser … Venom + Bomb … Shock + Orbs … Do not assume every effect must work identically on every attack" | **Change.** Each element defines how it applies per form (on tick, on blast, on hit); listed per row in ATTACK_FORMS.md | AF, VX |
| C73 | §9 "Two legendary cards currently grant approximately +40% bonuses associated with damage and attack speed. These need a moderate nerf" | **Found** (Audit A4): they are the Legendary rolls of the Power and Haste stat cards, epic × 1.6 (`data/legendary/boss.tres`): Power 25 % → **+40 %**, Haste 18 % → **+28.8 %** before the attack-rate curve (`attack_rate.gd:26-41`). Q12 | LG |
| C74 | "Review their current exact values and formulas, then reduce them slightly without making them undesirable … selected through playtesting" | **Q12** starting values; the owner tunes them in the F10 panel | LG |
| C75 | Broader review: "Attack-speed stacking with Twin, Spread … High projectile counts … Whether attack speed scales lasers … bombs … Multiple elemental effects scaling damage multiplicatively … special patterns can bypass normal attack limitations" | **Change.** A balance review once AS is built: per-form DPS sheets from the Playground's DPS meter (bot sims stay retired, ROADMAP §3); a per-attack projectile cap (Q13) | BR |
| C76 | "The previous problem of builds producing dozens of projectiles per second should be treated as a regression to prevent" | **Change.** A regression test: the worst legal build fires at most N projectiles a second (N from Q13) | BR |
| C77 | Balance targets 1–5 (gradual power; forms with strengths and weaknesses; rare strong combos need investment; meaningful legendaries; future-proof) | **Rules** for BR and ATTACK_FORMS.md | BR |
| C78 | "Review loot weights and progression only where necessary to support the new slot and compatibility system" | **Rule.** Only weights the slot rules require change (`item_pool.gd:44-64`) | AS |
| C79 | §10 "Several recently added items and attack modifiers are still missing proper VFX. Audit the full list" | **G1** `VFX_AUDIT.md` (after AS settles which cards survive): today Spread, Halo, Echo, Rapid Fire, Backfire, Big Shot, Swirl, Split and Orbit have no cue of their own beyond more or bigger bolts (`attack_form_looks.gd:177-215`) | VX |
| C80 | "implement a consistent set of effects for: launch and travel; impact; elemental application; laser, bomb, and void; Twin, Ring, Spiral, and Swirl; new modifiers that already exist in code" | **Change**, from the approved VFX_AUDIT rows | VX |
| C81 | Visual direction: "low-poly/faceted … readable silhouettes … Bold elemental colors … Cel-shaded … Avoid excessive realistic particles, muddy glows" | **Rules** for VX (and O88's "never brighter or flatter" from v0.8.0) | VX |
| C82 | "use Godot's native capabilities … but not feel restricted to weak-looking native primitives when shaders, meshes, custom textures, or sprite sheets would look better" | **Rule** for VX | VX |
| C83 | Asset workflow: "custom textures, elemental sprites, glyphs … created externally and supplied later … modular … replace initial placeholders without major code changes" | **Rule.** Every VFX texture goes through a manifest id with a code-made fallback (as models do today) | VX |
| C84 | "Prioritize visual quality and gameplay readability from the actual isometric game camera" | **Rule.** Shots from the game camera only | VX |
| C85 | §11 "Review and rewrite all item, modifier, upgrade, and attack descriptions … professional, consistent" | **Change, conflicts with X2** (O74: short, no numbers, no explaining). Q14 | TX |
| C86 | Requirements: "Consistent naming … Clear explanation … Consistent terminology … Correct numerical descriptions matching actual implemented values … No placeholder copy … No claims about stacking or compatibility that contradict the mechanics" | **Q14.** Today only 4 of 116 wand-card descriptions have numbers, baked in; stat cards fill `%s` from data | TX |
| C87 | "if an attack modifier replaces another rather than stacking with it, the player should understand that before selecting it" | **Change** whatever Q14 says: the card names its slot and what it replaces | TX, AS |
| C88 | "Preserve both English and Spanish localization" | **Rule** (EI-10). Spanish written on its own, not translated (O74) | TX |
| C89 | "Separate gameplay values from hardcoded description strings wherever possible" | **Change.** Numbers come from data through `%s` placeholders (as `STAT_*_DESC` already do), checked by a test that every placeholder resolves | TX |
| C90 | §14 Decisions to finalize: "1 slot counts … 2 secondary slots or stricter … 3 Laser and Void with advanced patterns … 4 Final six-element list … 5 tick, cadence, coefficients, attraction … 6 legendary values … 7 final boss approach floor" | **Q4, Q3, Q8/Q10, Q11, Q8–Q10, Q12, Q18** in that order | — |

### W: World Interaction, Elite Enemies & Progression Expansion

| # | Owner line (verbatim or close) | Decision | Step |
|---|---|---|---|
| W1 | §1 "Expand ZeroDepth beyond its current combat-focused roguelike loop with interactive environments, short puzzles, secret discoveries, special enemy encounters, a persistent hub, and progression between runs" | **Scope, Q1.** The whole document is several versions' work (its own §14 lists 5 phases). Recommended: Phases 1–2 in v0.9.0, Phases 3–5 in the next version after a playtest | — |
| W2 | "The game should alternate between intense combat, exploration, discovery, and smaller environmental challenges" | **Rule** for RG's pacing (W63) | RG |
| W3 | Principle 1 "Combat remains the priority … Puzzles and interactions should be short, intuitive, and usually understandable within a few seconds" | **Rule** for every puzzle row: understood in under 5 s, solved in under 30 s | all W steps |
| W4 | "Timed doors, rune switches, breakable walls, and surprise encounters are more appropriate than elaborate puzzles" | **Rule**, and the Phase 1 order (W27) | — |
| W5 | Principle 2 "The hub should be a mystery worth exploring … gradually change as players progress" | **Q27** (scope) and a G2 when built | HB |
| W6 | "Previously dark runes might illuminate, new corridors might become accessible, and unusual structures could react to discoveries" | **Change** (HB's evolving states, W45) | HB |
| W7 | "Players should have reasons to explore the hub and notice changes beyond simply purchasing upgrades" | **Rule** for HB | HB |
| W8 | Principle 3 "Permanent progression should unlock variety, not raw power … Avoid permanent upgrades that continuously increase damage, attack speed, or maximum health" | **Kept**: this is PD-06 ("Meta-progression is sideways … no permanent stat increases", `LOCKED_DECISIONS.md:50`) | MP |
| W9 | "Progression should primarily unlock new ways to play, cosmetic options, secrets, additional content, and limited utility" | **Rule** for UNLOCKS.md (G1, with MP) | MP |
| W10 | "The player's skill, choices, and builds within each run should remain the main determinants of success" | **Rule** | — |
| W11 | §2 Timed secret doors: "optional rooms containing a closed door controlled by two separate interactive mechanisms" | **Change, conflicts with X3** (PD-05's "no global clock"). Q20. A side room's door, opened by two switches (IX) | TD |
| W12 | Sequence 1–3 "discovers the closed door … Two … switches … Activating both opens the door, playing the existing broken-door opening sound" | **Change.** "Broken-door opening sound": read as `boss_door_opening.wav` (the existing opening sound); Q20 confirms | TD |
| W13 | 4–5 "A rhythmic beeping sound starts … progressively accelerates" | **Change.** A beep whose interval shrinks with the time left (placeholder tone; the owner's file replaces it) | TD |
| W14 | 6–7 "The player must reach the entrance before the timer expires … If the player fails, the door closes and the mechanisms reset" | **Change.** The timer counts from the second switch to the player crossing the doorway; on expiry the door shuts and both switches reset | TD |
| W15 | Presentation: "Slow beeps at first … Increasing frequency … Very fast beeping immediately before closure … A heavy impact when the door shuts" | **Change** (the door impact sound reused for the shut) | TD |
| W16 | "Include visual feedback, such as flashing runes, for accessibility" | **Change.** The switches' runes and the door's frame flash with the beep; the beeps are captioned (captions exist since v0.1.0) | TD |
| W17 | Technical: "Suggested starting timer: 12–18 seconds … Ensure completion is possible at normal movement speed" | **Change.** Starting value 15 s, and a generator check that the path from the second switch to the door is at most 60 % of the timer at base move speed | TD, RG |
| W18 | "No permanent penalty for failure. Reset safely without trapping the player" | **Change.** The door never shuts with the player inside its frame; if the player is inside the secret room when time runs out, the door stays open from the inside | TD |
| W19 | "Allow variations in switch placement and layout. Make rewards or secret areas optional" | **Change.** Switch spots in the layout data; the secret room is always a dead end off the main path | TD, RG |
| W20 | §3 Combat lockdown rooms: "rooms that close their doors when the player enters … defeat a contained encounter before leaving … differ from the existing overrun mechanic" | **Change, overlaps today's Arenas.** Arenas already seal on entry and run 2–3 waves, 11 % of combat rooms (`arena_rooms.gd:1-40`, `arenas.gd:4-9`). Q21: Arenas become the Normal Lockdown, or Lockdowns are a new type beside them | LK |
| W21 | Sequence 1–6 "Doors close with a noticeable audio and visual effect … Enemies spawn in a controlled arrangement … Defeating them reopens the exits … receives the appropriate reward" | **Change.** Today the barriers are collision only, with no look or sound of their own (`arenas.gd:4-9`). New: bars or a rune seal drop with a sound; packs spawn on authored formations; the exits reopen with a sound; a reward on clear (Q21) | LK |
| W22 | Variations: Normal Lockdown (familiar enemies) | **Change** (Q21) | LK |
| W23 | Elite Lockdown: "rarer … a stronger, unique enemy, respecting the elite spawn restrictions" | **Change.** One elite archetype (EL) plus a small escort, under EL's budget | LK, EL |
| W24 | Hazard Lockdown: "a short fight with environmental dangers" | **Q21**: which hazards (biome vents, falling rocks, frost patches; W60) | LK |
| W25 | "Lockdowns should create a change of pace … Target approximately 20–40 seconds" | **Change.** Waves sized for 20–40 s at the floor's expected DPS (Playground meter); starting values | LK |
| W26 | "Ensure exits reopen reliably even if an enemy fails to spawn, gets stuck, or otherwise becomes inaccessible" | **Change.** Today the only guard is "enemies outside the room don't count" (`arenas.gd:20-23, 81-95`); no timeout. New: an enemy unreachable on the flow field for 3 s is pulled back to a spawn point; a hard cap (starting value 90 s) ends the lockdown and opens the exits; a test drives a stuck enemy | LK |
| W27 | §4 Puzzles A–F, and "Do not implement every puzzle immediately. Start with: Timed doors. Rune alignment. Destructible secrets. Evaluate their effect on the game's pacing before adding the other systems" | **Kept.** v0.9.0 builds TD, RA and DX only. Energy Relay (B), Pressure Plates (D), Unstable Rune Portal (E) and Hidden Sequence (F) wait for the owner's verdict on the first three | TD, RA, DX |
| W28 | Puzzle A Rune Alignment: "Several rune pillars can be rotated … aligns symbols according to a visual clue to unlock a reward" | **Change.** Q22 proposes 3 pillars with 4 faces each and a wall carving as the clue | RA |
| W29 | Puzzle B Energy Relay | **Later** (W27) | later |
| W30 | Puzzle C Destructible Secrets: "walls, statues, or props contain subtle visual clues … Breaking them reveals hidden spaces, resources, or collectibles" | **Change.** Nothing is destructible today (`fire_barrel` is a static kit piece; no prop has HP). Q23 | DX |
| W31 | Puzzle D Pressure Plates "Keep the interaction simple. Avoid complex physics puzzles" | **Later** (W27). The sim has no physics (EI-02), so a pushable object would be a sim actor | later |
| W32 | Puzzle E Unstable Rune Portal | **Later** (W27) | later |
| W33 | Puzzle F Hidden Sequence | **Later** (W27) | later |
| W34 | "Build reusable Godot components so the same interaction logic can support different visual models and room layouts" | **Change.** IX: a shared sim interactable (today each system has its own `interact`, reach and state, dispatched in a fixed order at `world.gd:607-616`) and a shared prompt view. Existing systems move onto it only if that's cheap; new ones start on it | IX |
| W35 | §5 Interactions table: destructible containers, ancient shrines, healing fountains, cursed altars, explosive objects, hidden rune markings, interactive statues | **Q1 scope.** In v0.9.0: destructible containers and explosive objects (both share DX's prop HP) and rune markings (clues for RA and DX). Later: shrines, fountains and statues. Cursed altars exist (the curse room, v0.8.0 N19) | DX, later |
| W36 | Risk/reward shrines: Blood (health for a reward), Chaos (a challenge for an extra upgrade), Fortune (a resource for a random reward) | **Later** (Q1). Today's gamble shrine is close to Fortune (shards for a stat, 30 % fail, 3 wins; `gamble.gd:3-14`). A Chaos Shrine is also an elite exception (W56) | later |
| W37 | "Shrines should communicate their costs clearly before activation. Avoid introducing unnecessary new currencies or complicated interaction menus" | **Rule** (shrines pay in HP or shards) | later |
| W38 | §6 Secret types: collectibles, hidden rooms, environmental Easter eggs, lore fragments, special discoveries | **Q29 / Q1 scope.** Hidden rooms land with TD and DX in v0.9.0 | CL |
| W39 | Archive: "permanently recorded. Store: Unique identifier. Name and description. Associated biome or discovery condition. Collected/uncollected status. Optional visual preview" | **Change.** A `collectibles` section in `user://profile.json` (today version 1: settings, bindings, unlocks (never written), hints, codex, achievements; `profile_store.gd:6-12`), migrated to version 2 with nothing lost; definitions as typed `.tres` | CL |
| W40 | "Suggested initial scope: 12–20 distinctive collectibles … should feel like discoveries rather than a repetitive checklist" | **G1** `COLLECTIBLES.md` (names, where, how found), when CL is in scope | CL |
| W41 | §7 Hub: "a more detailed, explorable hub that players visit between runs … ancient rune aesthetic, stone structures, magical machinery" | **Change**, **Q27**. Today there is no hub; the menu goes Play → BuildPicker → run (`main.gd:181-192`) | HB |
| W42 | Central Portal Machine: "initiate a run … connects to the previously planned first-floor spawn altar … The hub portal sends the player into the run; the blue altar is their arrival point" | **Change.** The hub's machine starts the run and the SA altar receives the hero | HB, SA |
| W43 | Rune Archive (inspect artifacts, lore, secrets) | **Change.** The Codex's view (v0.7.5) gains the collectibles | HB, CL |
| W44 | Wardrobe (robe colours), Progression Station (variety and utility), Trophy Area (accomplishments, bosses, challenges, discoveries) | **Change.** The trophies read today's 32 achievements and the Codex's boss kills | HB, RB, MP |
| W45 | Evolving hub (Mandatory): runes glowing, a sealed corridor opening, a machine becoming interactive, symbols after bosses, secret rooms, artifacts on pedestals, small details changing | **Change.** Each change is a hub state keyed on a profile flag, in data | HB |
| W46 | "Not every change needs an explicit notification … subtle enough that attentive players notice them naturally" | **Rule** (no toast for those) | HB |
| W47 | "The hub should contain its own mysteries and optional discoveries" | **Change** (hub collectibles in COLLECTIBLES.md) | HB, CL |
| W48 | Returning: "After death or completion, the player returns to the hub. Display a short run summary … Restarting another run must remain fast and convenient" | **Change.** Today EndPanel (`main.gd:522-546`) offers Restart (one press, new seed) or Main menu. Q27 keeps a one-press restart | HB |
| W49 | §8 "one main currency earned throughout runs. Working name: Rune Fragments" | **Change** when MP is in scope (Q1, Q28). Run shards stay run-only | MP |
| W50 | Sources: floor completion, bosses, optional challenges, hidden rooms, run completion, milestones; "gradual, without making early unlocks excessively grindy" | **Q28** starting rates | MP |
| W51 | Unlock categories: cosmetics; gameplay variety (attack forms, modifiers, starting choices, challenges); utility (limited convenience, exploration abilities) | **G1** `UNLOCKS.md` with MP. Unlocking attack forms ties into ATTACK_FORMS.md (Q28) | MP |
| W52 | Balance requirement: "Do not implement permanent, repeatedly purchasable increases to damage, attack speed, or health" | **Kept** (PD-06) | MP |
| W53 | §9 Robes: "unlockable robe colors … appearance should not determine power … Separate Robe Appearance from Rune Affinity" | **Change** when in scope. Today the hero's colours are hard-coded (`player_avatar.gd:100-107`); the cloak becomes a palette choice | RB |
| W54 | Affinities: Ember, Storm, Venom, Astral, Guardian; "sidegrades, not compulsory upgrades … No individual affinity should become the universally strongest choice" | **G1** with RB, when in scope (Q28) | RB |
| W55 | §10 "The current concept of elites as ordinary enemies with increased health should be replaced … distinct enemy archetypes with unique 3D models, dedicated abilities, and a miniboss-like presentation" | **Change, X5.** Today `Curses.make_elite` (`curses.gd:229-235`) doubles max HP (`elite_hp_bonus 100`, `data/event_rules/floor.tres`) and changes nothing else; it carries a stealable core (`core_theft.gd`). Q25 | EL |
| W56 | Purpose: "a controlled spike in intensity toward the end of a run, particularly as the player approaches the final floors or prepares to enter the purple portal … threatening and memorable without becoming excessively punishing" | **Rule** for EL | EL |
| W57 | §10.1 Visual identity: a unique model or silhouette, larger, armour/accents, unique attack animations, clear anticipation; "Reusing normal enemy models with different colors or larger health values is not sufficient … low-poly, faceted" | **Change.** Model prompts for each approved archetype in `docs/art/requests/v0.9.0_elites.md` (after Q26); code-made stand-ins until the files arrive, posed in code like the bosses (`BossRig`, BA) | EL |
| W58 | §10.2 Elite health bar: larger, above the elite, distinct colour or frame, readable from the iso camera, scales with distance and size, doesn't hide combat information; "Consider adding a small elite name" | **G2** (3 mockups). Today an elite has the normal 0.55 m bar (`actor_views.gd:12, 607`) plus a gold crown ring. The N4 damage chunk (`health_bar_trail.gd`) carries over | EL |
| W59 | §10.3 Combat: more HP (not a long fight), slightly more damage, one special ability like a simplified boss mechanic, clear telegraphs, recognizable behaviour; "Avoid simply stacking multiple special attacks, extremely high movement speed, and large damage bonuses" | **Rules**, with numbers in `ELITES.md` (G1, Q26) | EL |
| W60 | §10.4 Breaker (armoured, slow ground slam with a warning area, recovery window) | **G1 row** in ELITES.md. Check against the Warden's slam and the Colossus | EL |
| W61 | Rift Hunter (angular, short dash or teleport, signals its landing, forces movement) | **G1 row**. Check against the Charger's dash and The Fallen | EL |
| W62 | Conduit (rune-covered, charges a beam or line, telegraphs, vulnerable in recovery) | **G1 row**. Check against the Sniper's line and the Prism's Cross | EL |
| W63 | "evaluated against the enemy roster to avoid duplicating existing bosses or abilities … Begin with a small number of high-quality elites" | **Rule.** ELITES.md has a "closest existing" column; Q26 proposes 3 | EL |
| W64 | §10.5 Spawn rules 1–6: mainly the final two floors; not earlier in normal generation; special events may spawn earlier, framed as unusual; frequency rises toward the end; no unfair stacks | **Change, X4.** A run is 3 floors (PD-03; `three_floors.tres floors = 3`), and loops repeat them. Today elites come from the Marked curse (1.2 % a spawn), the Deep floor (one in every combat room's first pack, `spawn_director.gd:169-185`) and Ambush Cache (3 elites, from floor 1). Q24 | EL |
| W65 | Special event exceptions: rare special room, shrine challenge, optional event, secret encounter, other designed events; "intentional rather than random" | **Change.** Ambush Cache, the Marked curse and the Elite Lockdown are the designed exceptions; each shows an "unusual encounter" cue | EL |
| W66 | §10.6 Purple portal: "noticeable increase in intensity … Elites can contribute … not so sharply that a previously viable build immediately becomes ineffective … Avoid combining excessive elite health scaling, increased enemy density, high damage, and additional special abilities … Consider a controlled increase in elite frequency" | **Change.** The Deep floor's ×1.25 (`deep_scale`) and v0.8.0 O35's loop-2 ease stay; its "elite in every combat room" becomes a raised elite budget (Q24) | EL |
| W67 | §10.7 Presentation: a short spawn effect, the bar appears, distinctive ability audio and visuals; "Avoid lengthy cinematic introductions … not because the game repeatedly stops to announce them" | **Change.** A 0.5–1 s arrival (a burst and a ground sigil), no pause and no banner | EL |
| W68 | §10.8 Rewards: a better upgrade chance, extra run resources, a small chance of rare rewards; "Do not automatically guarantee legendary items" | **Q25**: keep the core theft (a card for a kill in the stagger window) as the elite's reward, plus extra shards | EL |
| W69 | §10.9 Balancing: "Review the existing enemy and boss scaling before deciding numerical values … More HP than a regular enemy, but substantially less than a boss … Limited simultaneous elite encounters … No extreme movement speed or unavoidable attacks … second-loop scaling and purple portal difficulty … a controlled miniboss encounter, not an unavoidable difficulty wall" | **Rule.** ELITES.md sets HP as a multiple of the floor tier's enemy HP and a share of the floor boss's, including on loop 2 (×6 HP, ×1.2 damage a loop, `ascension.gd`) and Deep (×1.25) | EL |
| W70 | §10.10 "Use an elite encounter budget or spacing rule … Avoid stacking several miniboss-like encounters in consecutive rooms … especially … after entering the purple portal" | **Change.** At most 1 elite alive at once (2 in an Elite Lockdown's designed case), and at least 2 rooms between elite rooms; data values (Q24) | EL |
| W71 | §11 Biomes: Ruins (machinery, destructible walls, pressure plates), Night Rocks (hidden paths, glowing switches, statues), Red Canyon (heat vents, unstable structures, explosives), Frozen Shore (frozen mechanisms, ice runes), Starfall (cosmic relays, floating runes, unstable portals); "share scripts … different models, sounds, and visual effects" | **Change.** Each v0.9.0 interaction (TD switches, RA pillars, DX walls and props, LK hazards) gets a per-biome look in `BiomeLook` (data); the mechanics are shared | BV |
| W72 | §12 Pacing: 70–80 % normal; 10–15 % special combat incl. lockdowns; 10–15 % optional puzzles and secrets; "starting estimates, not mandatory generation probabilities … Elite frequency … controlled separately" | **Change.** Today: arenas 11 % of combat rooms, one Overrun, 1–2 event rooms, a shop, a curse room on 40 % of floors, a shrine on 40 % (Audit B3). RG measures the mix over 1,000 seeds and reports it next to these bands | RG |
| W73 | Generation requirements: each special room defines category, eligible biomes, floors, interactions, enemy and elite eligibility, entry and exit configuration, rewards, difficulty, optional | **Change.** One `SpecialRoomDefinition` `.tres` schema (validated by `ContentScanner`) for the new rooms; today each special room is its own code plus table (`overrun_rooms.gd`, `arena_rooms.gd`, `shop_placement.gd`, …) | RG |
| W74 | "Not every floor needs every interaction … should feel surprising" | **Rule** (per-floor chances and caps in the schema) | RG |
| W75 | §13 Components: Interactable, Puzzle, Timed Door, Room Encounter, Elite Framework, Secret and Collectible Manager, Hub, Persistent Progress; "architectural responsibilities rather than mandatory script names … Reuse current systems … work with procedural room generation and existing save data" | **Rule.** Mapped to IX, RA/TD, TD, LK, EL, CL, HB, MP. Every new sim state goes into the run save (`run_save_store.gd`, `SAVE_VERSION 1`) with a migration; the old-saves seam test covers it | all |
| W76 | §14 Roadmap Phases 1–5 | **Q1** maps them to versions | — |
| W77 | §15 Acceptance criteria (core, elites, hub and progression, technical) | **Verification** below, item by item | — |
| W78 | "For the developer: Inspect the existing project before implementation. Preserve working systems, distinguish confirmed requirements from proposed mechanics … Do not introduce unrelated features or treat suggested numbers as finalized values" | **Rule.** Every number here is a starting value | — |

### E: carried over from v0.8.0

| # | Owner line | Decision | Step |
|---|---|---|---|
| E1 | O36 / O38 (v0.8.0) utility cards; "UC, the utility cards. The G1 list is docs/roadmap/v0.8.0/UTILITY_CARDS.md (D23) and I haven't answered it yet" | **G1**, re-checked against live code: [`UTILITY_CARDS.md`](UTILITY_CARDS.md) adds a "Live code" column (which rows already exist, which need a new hook) and flags the six rows the AS slot rules would touch. Nothing is built before the answers | UC |
| E2 | O3 / Q2 (v0.8.0) enemy models; "The rest of EM, the enemy models" | **Waits on the owner's files.** Swarmer, Mine Layer and Sniper are the only kinds with prompts and no model (`docs/art/requests/v0.8.0_enemy_models.md:15-20`; `OWNER_TODO.md` §3.2). Nothing undelivered sits in `unprocessed_images/`. Wiring per model: `EnemyModels.SPECS` (`enemy_models.gd:16-21`), `HordeAvatar.model_id` (`horde_avatar.gd:135-143`), part posing (`horde_avatar.gd:446-470`) | EM |

## Design questions (asked 2026-10-22)

The format is from OWNER_GATES §4: options, then a recommendation (←). Answers go into "Owner decisions" the same
day.

### Scope
**Q1. What goes into v0.9.0?** (W1, W76)
- (a) Everything in both documents.
- (b) The whole combat document, plus W Phases 1–2 (interactions, timed doors, lockdowns, rune alignment,
  destructibles, elites) and UC and EM. W Phases 3–5 (hub, Rune Fragments, robes and affinities, collectibles,
  shrines, more puzzles) go into the next version, after a playtest. ← recommended: the attack restructure alone
  changes every build. L10 says long builds without a playtest hide problems. The hub also depends on the altar and
  portals landing first.
- (c) The combat document only.

### Attack system (C §5–§9)
**Q2. What happens to the wand?** (C37–C41, conflict X1)
- (a) **Keep the wand** (4 → 6 → 8 slots, read left to right, triggers cast child spells) and add **category
  limits** inside it: 1 Form (a new one replaces it), 1 Pattern (a new one replaces it), N Secondary, M Elements;
  trigger, mutation and stat cards stay free. Order still matters for triggers and secondaries. ← recommended:
  keeps O91's "preserve ordered modifiers … slots growing 4→6→8" and the triggers, and meets every rule in C §5.
- (b) **Replace the wand** with fixed slots: Form 1, Pattern 1, Secondary 1–2, Elements N. Order and triggers go.
  Simpler to read, but v0.7.0's design goes.
- (c) Something else.

**Q3. Which cards are Patterns, the one-at-a-time slot?** (C40, C59)
- (a) Twin, Spread, Halo, Ring, Spiral, Swirl and Backfire are all Patterns. The storm (Ring · Spread · Swirl, D45)
  goes.
- (b) Twin, Spread, Halo, Ring and Backfire are Patterns. Spiral and Swirl become **motion** secondaries that ride
  on a pattern, so Ring + Swirl (a storm with one ring) is still possible, but Ring + Spread is not. ←
  recommended: keeps a version of the storm you liked (O37) and still stops pattern multiplication.
- (c) Something else.

**Q4. Starting slot counts?** (C41, C44, C45; all of them data values)
- (a) Form 1, Pattern 1, Secondary 2, Elements 2. ← recommended
- (b) Form 1, Pattern 1, Secondary 1, Elements 1 (strict).
- (c) Form 1, Pattern 1, Secondary 3, Elements 3 (loose).

**Q5. Taking a Form or Pattern card when that slot is full** (C39, C67, C87)
- (a) The card is marked "Replaces Twin" (its slot icon and the old card's name). Picking it puts it in the slot,
  and the old card burns (v0.8.0 N8's burn). ← recommended
- (b) Picking it opens the Swap panel so you choose which to drop.
- (c) The old card goes into a reserve you can swap back to on the Build page.

**Q6. Does the Form system apply to the Blade?** (C47)
- (a) Gun only in v0.9.0. Forms replace the Gun's orb. The Blade keeps its own pool and gets only the
  one-pattern rule for its shaping cards (Wide Arc, Double Slash, Whirl, Thrust …). ← recommended: the document is
  written about ranged attacks, and Blade forms are a bigger design of their own.
- (b) The Blade becomes one of the forms, and the Blade/Gun choice at the start goes.
- (c) The Blade gets its own 4–6 forms too, in this version.

**Q7. The attack forms: answer [`ATTACK_FORMS.md`](ATTACK_FORMS.md) row by row** (C47: "around 8-10 total").
The list has your four (Orbs, Laser, Bomb, Void) and six of the lead's. Yes / No / Change on each, plus its
compatibility cells.

**Q8. Laser starting values** (C48–C50)
- Damage ticks 10 times a second; each tick is 18 % of an orb hit, so a held beam does about 1.2 × an orb's
  single-target DPS. Range 9 m. The beam stops at the first enemy unless you have Pierce. While the beam fires, you
  move at 75 % speed (the exposure cost).
- Attack speed raises the tick rate at **half** its value.
- Twin: two parallel beams, each 60 %. Spread: three thinner beams in a 20° fan, each 40 %. Ring, Spiral and Swirl:
  off. ← recommended
- Or give your own values or rules.

**Q9. Bomb: how it flies, and Spread** (C51–C53)
- Flight: (a) straight throw: it bursts on the first enemy or wall, or at 8 m. Works the same with the pad. ←
  recommended. (b) Lobbed arc to the aim point (capped at 8 m), flying over enemies. Better with a mouse, but the pad
  has no aim distance.
- Values: 1 bomb a second, a 2.2 m blast at 4.5 × an orb hit. Attack speed counts at half value. Twin: two bombs,
  each 65 %.
- Spread: (a) off for now. ← recommended, to keep the bomb's identity. (b) Three bombs in a fan, each 45 %.

**Q10. Void projectile starting values** (C55–C58, C70)
- 1 shot every 0.6 s at 0.6 × orb speed. A 1.0 m aura deals damage 5 times a second. The pull reaches 3 m and moves
  an enemy at most 1.0 m/s toward the shot's path (no stacking across voids), with a separation push so enemies never
  bunch into one point. Heavies get half the pull.
- Bosses and elites: (a) no pull. ← recommended (b) Half the pull.
- Patterns: Twin on; Spread, Spiral and Swirl off until tested; Ring off.

**Q11. Elements after Void leaves** (C43, C71, C90 4)
- (a) Five elements: Fire, Lightning, Frost, Venom, Bleed. Explosive becomes a Secondary (it's a blast when the shot
  ends), and is off for Bomb. ← recommended
- (b) Six elements, with Explosive as the sixth.
- (c) Five, plus a new sixth element (name and behaviour from you).

**Q12. The legendary nerf** (C73, C74)
- (a) For Power and Haste only, the legendary multiplier goes 1.6 → 1.3: Power +40 % → +32.5 %, Haste +28.8 % →
  +23.4 %. Other legendary stat cards stay at 1.6. ← recommended ("moderate", "slightly")
- (b) 1.6 → 1.4 for every legendary stat card.
- (c) Your numbers.

**Q13. A projectile cap per attack** (C75, C76)
- (a) At most 12 projectiles per attack (pattern × Twin × Split children). Beyond that, extra copies merge into
  bigger shots that keep the damage. A test fails if the worst legal build launches more than 40 projectiles a
  second. Data values. ← recommended
- (b) No cap: the slot rules alone.
- (c) Your numbers.

### Text (C §11, conflict X2)
**Q14. Which text rule wins on cards?**
- (a) Both. Keep O74's style: a short line, no tutorials, no explaining texts. Add one compact effect line built
  from data, plus a slot tag: e.g. "Fire in a fan." / "3 shots · 30°" / "Pattern · replaces Twin". ← recommended:
  numbers and replacements are honest and always match the data, and nothing explains the world.
- (b) O74 stays as it is. Only the slot and replace tag are added.
- (c) The document's fuller descriptions everywhere.

### Portals, altar, camera, final approach, door (C §1–§4)
**Q15. The new portals** (C1–C5)
- Frame: (a) code-made: a tall, narrow, organic oval of stone and light around the swirl. ← recommended: it can
  ship now. Your model can replace it later, and the prompt is in the art request. (b) Wait for your model.
- Materialize: a seam of light opens and stretches to full height over 1.5 s. (a) Yes. ← recommended (b) Your idea.

**Q16. The spawn altar** (C6–C24)
- Which floors: (a) every floor's first room. Floor 1 of a run plays the full six-stage sequence (about 3.0 s);
  later floors play a short version (about 1.2 s, runes flare and the hero steps out). ← recommended: one arrival
  point everywhere, which the hub's portal (W42) also needs. (b) Floor 1 only; later floors keep today's receiver.
- Length of the floor-1 sequence: (a) 3.0 s. ← recommended (b) 2.0 s. (c) 4.0 s. Today it is 1.6 s.
- Model: your model (prompt in the art request), with the floating runes and jewels as separate code objects so they
  can light and orbit. Until your file arrives, a code-made stand-in. OK?
- Sound: the lead makes a placeholder buildup-and-pop cue. OK, or will you send one?

**Q17. The new vibration** (C20–C22)
- (a) Every camera shake in the game becomes the new vibration (arrival, boss door, explosions, big hits). The
  directional kicks go from the arrival but stay on the player's own hits. ← recommended
- (b) The arrival only.

**Q18. The final approach floor** (C25–C34)
- Layout: (a) the arrival altar at the foot of a broad stair causeway (about 25 m) up to a plateau. The purple altar
  stands in the middle, with the two mechanisms (rune pylons) at the plateau's sides. No enemies. ← recommended
- Where the fight happens: (a) **right there:** the plateau is the boss arena, and walls of light rise around it when
  the buildup ends. No second load. ← recommended (b) The buildup ends in a portal cover into today's ring arena.
- Mechanism: (a) press interact once; the pylon locks in with a sound and lights its runes. ← recommended
  (b) Hold for 1 s.

**Q19. The door boom** (C35)
- (a) Fire the impact 0.3 s earlier (18 ticks), so the file's loudest moment lands exactly as the slab touches down.
  The camera shake stays on the touchdown. ← recommended: measured from the file
- (b) 0.5 s earlier, as written. The peak then comes about 0.2 s before touchdown.

### World (W)
**Q20. Timed doors and PD-05** (W11–W19, conflict X3)
- (a) Approve a LOCKED_DECISIONS clarification: "Optional, local challenge timers (timed doors, short room
  challenges) are allowed. There is still no run-wide clock and no enrage timer." Timer 15 s. The opening sound is
  the boss door's opening sound. The reward room holds an epic altar or a chest (a collectible later). ←
  recommended
- (b) No timer: the door just opens once both switches are on.

**Q21. Lockdowns vs today's Arenas** (W20–W26)
- (a) Today's Arenas **become** the Normal Lockdown: closing bars with a sound, formation spawns, 20–40 s, the
  stuck-enemy safety, an altar on clear. Elite and Hazard variants are added, the share stays 11 %, and the Overrun
  stays as it is. ← recommended: no new room type to tell apart from Arenas.
- (b) Lockdowns are a new room type next to Arenas.
- Hazards: (a) one per biome, using W71's biome rows: Ruins sparking cables, Night Rocks falling rocks, Red Canyon
  heat vents, Frozen Shore cracking ice, Starfall falling stars. ← recommended (b) The same hazards everywhere.

**Q22. Rune Alignment** (W28)
- (a) 3 pillars with 4 faces each. Interact turns one a quarter. A carving on the wall shows the 3 symbols to match.
  Solved: a chest or a hidden room opens. ← recommended (b) 4 pillars. (c) Your idea.

**Q23. Destructibles** (W30, W35)
- Cracked walls: (a) any attack breaks them, in 3 hits. ← recommended (b) Only explosions (Explosive, the bomb
  form).
- Containers (crates, urns, barrels): 1 hit, and a small chance of shards or a heal. Explosive barrels: a short
  fuse, then they hurt enemies **and** you. OK?

**Q24. When elites appear** (W64–W70, conflict X4)
- (a) Normal elites on floors 2 and 3 of every loop. Starting values: 15 % of floor 2's combat rooms, 25 % of floor
  3's, +10 points on a Deep floor (replacing "an elite in every combat room"), at most 1 elite alive, at least 2
  rooms between elite rooms. Designed exceptions (Ambush Cache, the Marked curse, the Elite Lockdown) may appear
  earlier, each with an "unusual" cue. ← recommended
- (b) Only floor 3 of each loop, plus Deep floors.
- (c) Your rule.

**Q25. Today's elites** (W55, W68, conflict X5)
- (a) The ×2 HP elite goes entirely: every elite is an archetype. The core theft (stagger it, kill it in the
  window, take its card) becomes every archetype's reward, plus extra shards. ← recommended
- (b) Archetypes are added, and the ×2 HP elites stay for the curse and events.

**Q26. The first elites** (W57–W63)
- (a) The three you proposed (Breaker, Rift Hunter, Conduit), each checked against the bosses and enemies in
  `ELITES.md` (a G1 written after Q24–Q25). Model prompts for each; code stand-ins until your models arrive. ←
  recommended
- (b) Two first. (c) A different set.
- The elite bar gets a G2: 3 mockups, with the name or without it.

**Q27–Q29 apply only if Q1 puts the hub and progression in v0.9.0:**

**Q27. The hub and the menu** (W41–W48)
- (a) The main menu keeps Options, Codex, Credits and Quit. Play and Continue enter the walkable hub, where the
  portal machine starts a run. Death or a win shows the summary, then **Restart** (straight into a new run, one
  press) or **Hub**. ← recommended: restarting stays as fast as today.
- (b) The hub replaces the main menu.

**Q28. Rune Fragments and unlocks** (W49–W54)
- A G1 `UNLOCKS.md` lists every unlock, its price and its category (cosmetic / variety / utility). Should some attack
  forms be unlocks rather than in the pool from the start? (a) Orbs, Laser and Bomb from the start, the rest
  unlocked. (b) All from the start; unlocks are cosmetics and utility only. ← recommended for the first version,
  so the forms are tested before they're gated.

**Q29. Collectibles and lore** (W38–W40)
- (a) The lead drafts 16 collectibles (names, where, how found) and their lore lines in COLLECTIBLES.md, and you
  edit them. ← recommended (b) You write the lore.

### Carried over
**Q30. UC:** answer [`UTILITY_CARDS.md`](UTILITY_CARDS.md) row by row (Yes / No / Change). The new "Live code" column
marks duplicates (12 Magnet = the live pickup-range stat card; 13 Rebound for the Blade = Riposte Chain; 16 Ghost Step =
the retired Phase Dash) and the six rows the AS slot rules would touch (6, 9, 13, 14, 19, 22).

**EM:** no question. Swarmer, Mine Layer and Sniper wait on your files (prompts in
`docs/art/requests/v0.8.0_enemy_models.md`). The elite prompts follow Q26.

## Gates in this version
| Gate | File | Blocks |
|---|---|---|
| Q1–Q30 | this PLAN | answered 2026-10-22 |
| G1 attack forms | [`ATTACK_FORMS.md`](ATTACK_FORMS.md) | answered 2026-10-22 (F1–F10) |
| G1 utility cards | [`UTILITY_CARDS.md`](UTILITY_CARDS.md) | answered 2026-10-22 (Q30) |
| G1 VFX audit | `VFX_AUDIT.md` (after AS) | VX |
| G1 new bosses | `BOSSES_4_5.md` | NB |
| G1 elites | `ELITES.md` | EL |
| G1 unlocks, affinities, collectibles | `UNLOCKS.md`, `AFFINITIES.md`, `COLLECTIBLES.md` | MP, RB, CL |
| G2 portals and altar | shots in the game camera | PT, SA (shown after building; the shape is decided) |
| G2 card slots and replace | mockups of the card and Build page | AS |
| G2 elite bar | 3 mockups | EL |
| G2 hub | mockups | HB |

## Owner decisions
| Q | Answer (the owner's pick, verbatim) | What it means | Date |
|---|---|---|---|
| Q1 | "Everything" | Both documents in full go into v0.9.0, the hub and meta progression (W Phases 3–5) included. Q27–Q29 now apply. The Steps' "Later" block moves into this version | 2026-10-22 |
| Q2 | "Keep it, add limits (Recommended)" | The wand stays (4 → 6 → 8 slots, left to right, triggers). Inside it: 1 Form and 1 Pattern (a new one replaces the old), N Secondary, M Elements; trigger, mutation and stat cards stay free. Order still matters for triggers and secondaries | 2026-10-22 |
| Q3 | "Spiral/Swirl ride along (Recommended)" | Patterns (one at a time): Twin (merged with Spread, see Q8), Halo, Ring, Backfire. Spiral and Swirl are motion secondaries that ride on any pattern, so Ring + Swirl is allowed; D45's Ring · Spread · Swirl storm goes | 2026-10-22 |
| Q4 | "1 / 1 / 2 sec / 2 elem (Recommended)" | Starting limits: Form 1, Pattern 1, Secondary 2, Elements 2 (data, `wand.tres`) | 2026-10-22 |
| Q5 | "Marked, old one burns (Recommended)" | A Form or Pattern card for a full slot reads "Replaces <card>" with its slot icon; picking it burns the old card | 2026-10-22 |
| Q6 | "Gun only for now (Recommended)" | Forms are Gun forms. The Blade keeps its pool and gets only the one-pattern rule for its shaping cards | 2026-10-22 |
| Q7 | "F5 Lance, F6 Scatter, F7 Glaive"; "F8 Seekers, F9 Wave, F10 Wisps" | All ten forms in [`ATTACK_FORMS.md`](ATTACK_FORMS.md) are approved with the compatibility cells as proposed (Twin and Spread now one column, Q8). Lance replaces the Charge card and Glaive the Boomerang card (both retired through `migration.tres`) | 2026-10-22 |
| Q8 | "as proposed, but we should also rework twin and spread, merge them into 1, the amount of double attacks should depend on that rarity of it level 5 its maximun for example 3 beams is level 5 and 2 beams is level from 1 - 3 and we add a bit of damage increase betwen levels that dont get"; then "Every form (Recommended)", "Side by side, fan at 3 (Recommended)", "+10 % per level (Recommended)" | **Laser** as proposed: 10 ticks/s at 18 % of an orb hit, 9 m, stops at the first enemy unless Pierce, 75 % move speed while firing, attack speed at half value on the tick rate; Ring, Spiral, Swirl off. **Twin and Spread merge into one Pattern card for every form** (working name Twin; `gun_spread` retired): 2 copies at Lv 1–3, 2 at Lv 4, 3 at Lv 5; damage per copy 60 / 70 / 80 / 90 %, then 70 % each at Lv 5 (the third copy comes in). Two copies fly side by side; at three, the middle one goes straight and the outer two fan about 15°. This replaces the per-form Twin and Spread values proposed in Q8–Q10 | 2026-10-22 |
| Q9 | "Straight, no Spread (Recommended)" | Bomb: thrown straight, bursts on the first enemy or wall or at 8 m; 1 a second; 2.2 m blast at 4.5 × an orb hit; attack speed at half value. With Spread merged into Twin (Q8, every form), the bomb takes the merged card: 2 bombs at Lv 1–4, 3 at Lv 5 | 2026-10-22 |
| Q10 | "No pull on them (Recommended)" | Void: 1 shot every 0.6 s at 0.6 × orb speed; 1.0 m aura, 5 damage ticks a second; pull 3 m, at most 1.0 m/s toward the path, no stacking, a separation push; heavies half; **bosses and elites none**. The merged Twin on; Spiral and Swirl off until tested; Ring off | 2026-10-22 |
| Q11 | "I don't want to have the enemies exploding after they die that's broken lets swap for something different and delete it"; then "Both", "Burning ground on kill" | **Fire's kill blast is deleted** (`ember_core` ON_KILL, 1.5 m at 60 %): a burning enemy that dies leaves a burning patch instead (starting values 1.2 m, 2 s), and no burst. **The Explosive card is deleted** (`shared_explosive`, retired through `migration.tres`). Elements: Fire, Lightning, Frost, Venom, Bleed (five). Explosions come only from the Bomb form | 2026-10-22 |
| Q12 | "Power/Haste ×1.3 (Recommended)" | Legendary Power +40 % → +32.5 %, Haste +28.8 % → +23.4 % (multiplier 1.6 → 1.3 for those two only); other legendary stat cards stay × 1.6 | 2026-10-22 |
| Q13 | "12 per attack (Recommended)" | At most 12 projectiles per attack (pattern × Twin × Split children); extra copies merge into bigger shots that keep the damage; a regression test fails above 40 projectiles a second for the worst legal build. Data values | 2026-10-22 |
| Q14 | "Short line + slot tag" | O74's style stays: short lines, no numbers or mechanics on wand cards. Each Form, Pattern, Secondary and Element card adds only its slot tag and, when the slot is full, "replaces <card>". C86's "numerical descriptions" and C89 apply where numbers already show (stat cards' `%s`) | 2026-10-22 |
| Q15 | "we already have the animation you built in code and those look pretty good, we would just have to shape it into a vertical oval shaped portal like rick and morty with a bit of random swirl at edges to not make the border completly flat and add some particles of the color portal, a simple tweak"; then "it should appear from a point and grow out of it in a circle that grows into the full oval so from a specific point a transition that gets bigger and the edges should have an effect while they grow from that point like the cards burning but reversed, same way to dissapear, it collapses into a specific point" | **No stone frame.** Today's swirl shader is reshaped into a tall vertical oval with an irregular, swirling edge (not a flat border) and particles in the portal's colour (blue gate, violet Deep gate). It appears only after the boss dies: from a single point it grows as a circle into the full oval, its edge burning inward-out as it grows (v0.8.0 N8's card burn, reversed); you can walk in once it's formed. It disappears the same way, collapsing into a point. The optional portal-frame model is no longer needed | 2026-10-22 |
| Q16 | "only floor 1 the rest of the floor spawn the same portal that you take at the end of the floor, character comes out of it and then it vanishes"; "4.0 s"; "Your model, my sound (Recommended)" | **The altar is on floor 1 only**, with the full six-stage sequence over **4.0 s** (`arrival_first_seconds` 1.6 → 4.0). **Later floors:** the same oval portal you took (blue or violet) grows in the first room, the hero steps out of it, and it collapses into a point. The owner's altar model (prompt in the art request), with the floating runes and jewels as separate code objects; a code stand-in until the file arrives. The lead makes a placeholder buildup-and-pop sound | 2026-10-22 |
| Q17 | "not every explosion should have a shake, just arrival, boss floor and the last boss travel animations, taking the portal and arriving to the new final boss platform, nowhere else"; then, asked which of today's camera moves stay: "Boss door landing, Getting hit, Blade finisher, Blade hit kick" | **The new vibration** (small, fast, no pull across the screen) is used only for the floor-1 arrival, the boss door landing, and the final-boss travel (taking the Ascension portal and arriving on the approach platform). No explosion shakes (none exist today, and none are added). Kept as they are: the shake when you're hit, the Blade finisher's shake and the Blade hit kick. The arrival's directional kick goes | 2026-10-22 |
| Q18 | "On the altar plateau (Recommended)"; "Stair causeway (Recommended)"; "Press once (Recommended)" | You arrive at the foot of a broad stair causeway (about 25 m) up to a plateau, with no enemies. The purple altar stands in the middle and the two rune pylons at the plateau's sides; each switches on with one interact press (it locks in with a sound and lights its runes; the second sets them spinning). The plateau is the arena: when the buildup ends, walls of light rise around it and the Colossus rises from the altar. No second load | 2026-10-22 |
| Q19 | "0.3 s earlier (Recommended)" | The door's impact sound fires 18 ticks (0.3 s) before the slab touches down, so its peak lands on the touchdown; the shake stays on the touchdown | 2026-10-22 |
| Q20 | "Allow local timers (Recommended)" | PD-05 clarified (LOCKED_DECISIONS): optional, local challenge timers are allowed; still no run-wide clock or enrage timer. Timed door: 15 s from the second switch; the boss door's opening sound, accelerating beeps, the door's impact on the shut; the room holds an epic altar or a chest (or a collectible) | 2026-10-22 |
| Q21 | "A new room type"; "One per biome (Recommended)"; then "1–2 a floor, short (Recommended)" | **Lockdowns are a new room type**; today's Arenas stay as the longer wave fights (11 %). 1–2 Lockdowns a floor: one short contained encounter (20–40 s) in set formations, a visible seal with a sound, the stuck-enemy safety (an enemy unreachable for 3 s is pulled back; exits forced open at 90 s), a reward on clear. Normal from floor 1; Elite (floors 4–5 only, the elite rules) and Hazard rarer. Hazards per biome: Ruins sparking cables, Night Rocks falling rocks, Red Canyon heat vents, Frozen Shore cracking ice, Starfall falling stars, each with a ground warning | 2026-10-22 |
| Q22 | "when approaching puzzles the enemy spawn should ease a bit so the player has a chill moment to solve the puzzle, not stop completly"; "A quarter of the rate"; "3 pillars, 4 faces (Recommended)" | **Puzzle calm (every puzzle):** in a puzzle's room (timed-door switches, rune pillars, later puzzles), new packs come at a quarter of the rate; enemies already there keep fighting; normal spawning resumes when it's solved or you leave. Rune Alignment: 3 pillars of 4 faces, interact turns one a quarter, a wall carving shows the 3 symbols, solved opens a chest or a hidden room | 2026-10-22 |
| Q23 | "L1 attack, but don't show it, players will have to guess it, but hidden room should not appear or be visible until you open it"; then "sorry I meant L2, the secondary attack"; then "The Skill (Q / pad Y)" | **Cracked walls break only to the Skill** (Q / pad Y; e.g. the Gun's Scatter Blast). Nothing tells the player (only the wall's subtle cracks, W30). The hidden room behind it is not drawn, lit or shown on the minimap until the wall breaks. Containers (1 hit, a small chance of shards or a heal) and explosive barrels (a short fuse, hurt enemies and you) as proposed (no objection) | 2026-10-22 |
| Q24 | "we are gonna be making the game 5 floors, so 4-5, we need to adjust difficulty scaling and loot to 5 floors"; "Stretch today's curve (Recommended)"; "first floors are smaller and later floors are longer for example 10, 13, 15, 17 , 19"; "4, 5, 6, 7, 8 (Recommended)"; "New bosses for 4–5"; "4: two per floor (Recommended)"; "Scale with floor size (Recommended)"; "All 5, random order (Recommended)"; "15 % / 25 %" | **A run is 5 floors** (PD-03 changed). Floors grow: about 10, 13, 15, 17 and 19 rooms plus the boss room. Difficulty is today's curve stretched so floor 5 ends where floor 3 ends now (enemy HP ‰ 1000 / 1380 / 1900 / 2620 / 3610, damage 1000 / 1180 / 1400 / 1660 / 1960; boss +20 % HP and +10 % damage of floor 1's a floor (`RunState.scale_bosses` is linear: today +40 % / +20 %), so floor 5 lands exactly on today's floor 3, ×1.8 HP and ×1.4 damage; the lead's first draft said +25 % / +12 %, then a compounding +18.3 % / +9.5 %, both wrong readings of the code; FV measured and set 200 ‰ / 100 ‰); loops scale from there as today. Wand slots 4, 5, 6, 7, 8. Every run visits all five biomes once, in random order. Altars and chests scale with the floor's rooms (about 1–2 each on floor 1 up to 3 on floor 5); the shop on floors 1, 3, 5. Floors 1–3 keep today's boss pools; **4 new bosses**, 2 per pool for floors 4 and 5 (a G1 list and model prompts). **Normal elites only on floors 4–5:** 15 % of floor 4's combat rooms, 25 % of floor 5's, at most 1 alive, at least 2 rooms apart | 2026-10-22 |
| Q25 | "you have a 30% chance of dropping the core"; then "The current normal enemies as elite dissapear and we will only get the new elites, those all, have the 30%, there is a card that makes elites appear and drop dozens of cards, we remove that one it is too broken, this feature is replace by elites appearing in later floors and giving a chance of obtaining free cards"; "Remove it" (Ambush Cache) | The ×2 HP elite goes; every elite is an archetype. **Killing one has a 30 % chance to drop its core card** (no stagger window; the core-theft window goes). **The Marked curse is deleted** ("Elites hunt you, and there are more of them" / "Slain elites drop a free rare card"). **The Ambush Cache event is deleted.** Elites now come only from floors 4–5 and Elite Lockdowns | 2026-10-22 |
| Q26 | "Your three (Recommended)"; "Small name above (Recommended)" | Breaker, Rift Hunter and Conduit, checked in `ELITES.md` (G1) against today's bosses and enemies, with model prompts and code stand-ins. The bar: a small name above a wider framed bar; G2 with 3 mockups | 2026-10-22 |
| Q26b | (Purple Portal) "the purple portal should be linked to one of the new puzzles or events, not be there as default"; "one of the event rooms, in a big room, has activation purple runes, that make the screen shake so you know something happened, but then when you kill the boss the purple portal appears"; "it shouldn't be in all floorrs, never in floor 1, 50% of appearing in floor 2 if does not appear, then warrantee on the next floor" | **The Purple Portal is earned.** It no longer opens after every boss. A purple-rune event room (in a big room) holds activation runes; activating them plays the new vibration (added to Q17's list) and a sound, and that floor's boss then leaves the Purple Portal beside the normal one. Never on floor 1; 50 % on floor 2; if it didn't appear there, it's certain on floor 3. **Lead's reading:** one purple room per run (per loop), none on floors 4–5. Deep floors keep their rewards and ×1.25; their "elite in every combat room" goes (elites follow Q24) | 2026-10-22 |
| Q27 | "You will have a small menu, with options, continue and play, and the rest of the thing go into the hub" | The main menu is Play, Continue and Options (and Quit, the lead's addition: the game needs a way out). The Codex, Credits, achievements and the rest move into the hub: the Portal Machine starts a run; the Rune Archive holds the Codex and collectibles; the Wardrobe; the Progression Station; the Trophy Area. Death or a win shows the summary, then Restart (one press) or the hub | 2026-10-22 |
| Q28 | "the most broken could be unlocked, maybe 2 of them" | Eight forms are in the pool from the start; the **2 strongest forms** (picked from BR's measurements, confirmed by the owner) are unlocked with Rune Fragments. The other unlocks are cosmetics and limited utility (G1 `UNLOCKS.md`) | 2026-10-22 |
| Q29 | "I draft 16, you edit (Recommended)" | The lead drafts 16 collectibles and their lore lines in the owner's short style (G1 `COLLECTIBLES.md`); the owner edits | 2026-10-22 |
| Q29b | (other puzzles) "Later wave, after you play (Recommended)"; (shrines) "Gamble shrine = Fortune (Recommended)"; (interactions) "Healing fountains, Hidden rune markings"; (robes) "Robes + 5 affinities (Recommended)" | Puzzles B, D, E, F are built in a later v0.9.0 wave, only after the owner has played TD, RA and DX. Today's gamble shrine becomes the Fortune Shrine; Blood and Chaos shrines are added (at most one shrine a floor, costs shown first; the Chaos challenge may bring an elite, a designed exception). Healing fountains (rare, one use) and hidden rune markings near secrets go in; interactive statues don't. Robe colours are cosmetic; one of five affinities (Ember, Storm, Venom, Astral, Guardian) or none is picked at the Wardrobe (G1 sets each so none is always best) | 2026-10-22 |
| Q30 | UC rows: "1 Close Quarters, 2 Second Wind, 3 Deep Cuts, 4 Heavy L1"; "6 Afterburn, 7 Adrenaline, 8 Perfect Dodge"; "9 Fifth Strike, 10 Wind Up, 11 Last Stand"; "15 Hunter's Mark, 16 Ghost Step"; "17 Backstab, 18 Crowd Control"; "22 Time Shard"; Heavy L1: "Phase Strike's level-up (Recommended)" | **Yes:** 1, 2, 3, 6, 7, 8, 9, 10, 11, 15, 16, 17, 18, 22, and 4 as Phase Strike's higher levels (no new card). **No:** 5, 12, 13, 14, 19, 20, 21. Fifth Strike (9) and Afterburn (6) sit under the new slot rules (Secondary / fire outside the element slot) | 2026-10-22 |
| AS | (on step AS's report and its G2 mockups `evidence/as_mockups/`) "B: ribbon + pips"; "Yes, enforce 40/s (Recommended)"; "Let me choose"; "Yes those four, for now blade rework is pending not treated here, but now that you are touching cards and UI can you make the edges of things straight and not the zigzags it has?" | **G2 AS = B:** a "Replaces <card>" ribbon across the card, the slot tag in the rarity line, pips per slot over the wand. **40 projectiles a second is enforced in play** on Gun runs (the hero's own shot always fires; extras past the budget merge into fewer, bigger shots carrying the damage; a data value), on top of 12 per attack. **A full Secondary or Element slot opens the Swap panel** so you choose which card of that slot goes (Form and Pattern still replace and burn). **Blade:** only Wide Arc, Double Slash, Whirl and Thrust are Patterns for now; a Blade rework is pending, not part of this version. **New (UE):** the UI's frames get straight edges instead of the chipped zigzag ones (cards, panels, plaques, the Build page) | 2026-10-22 |
| LZ | (on step LZ's report: Q8's "10 ticks at 18 % of an orb hit" gives 0.27 × the orbs, not the "≈ 1.2 ×" it promised) "Keep 1.2× the orbs (Recommended)" | The laser does 10 ticks a second at 80 % of an orb hit each (`beam_permille` 800), about 1.2 × the orbs on one target (measured 1.21 ×); the 18 % in Q8 was the lead's arithmetic error | 2026-10-22 |
| FV, MI2 | (on test_final_pace failing by 1.1 s on five floors: strong Blade's Fallen 148.8 s vs base 146.7 s, margin +1.0 s) "Leave it red for now"; (on the delivered `timed_door`, an iron-bar gate with no frame) "Use it for Lockdowns (Recommended)" | test_final_pace stays failing, as a reminder until the owner has played five floors (CI's full suite shows it red). The owner's bar gate becomes `lockdown_seal` (LK's doorway bars); the timed door goes back to the code stone slab until the owner makes a stone door | 2026-10-22 |
| FV, RA, DX | (on five floors leaving floor 1 with no free dead end: as Main builds floors, no rune puzzle in 160 seeds and one cracked wall; floors 2, 3, 5 hold a puzzle in 7, 2, 7 of 60 seeds) "Leave it: secrets start on floor 2." | No change to generation or the secrets' chances: floor 1 rarely or never holds a rune puzzle, cracked wall or timed door, and that is intended. The rune e2e continues a floor-2 save; the timed-door-and-runes tests build floor 3 | 2026-10-22 |
| AF1 | (on the Lance at ATTACK_FORMS F5's ×1 → ×5 measuring 0.46× the orbs on one target at full charge, 2.24× on five in a line) "Tune the Lance so a full charge matches the orbs on one target (about 1.0x); it stays far stronger on a line." | The Lance's full-charge multiplier is raised until a full charge measures about 1.0× the orbs on one target (the same harness as test_lance); a tap stays ×1, the charge still linear, so charging stays the strongest use. F5's "×1 → ×5" is superseded | 2026-10-22 |
| AF1b | "could the charge attack be the same as the original ball but it creates a circle in front of the player that circles like a charging energy and then shoots a bit, moves the player back like a cadence weapon, the feel should be like a lowkey haduoken from street fighter"; then "Pierces all (Recommended)"; "A small step (Recommended)"; "Grows with charge (Recommended)" | **The Lance becomes a charged energy ball** (replaces the instant line). Holding Shoot gathers a swirling energy circle in front of the hero (up to 1.2 s); releasing fires one ball like the orb, flying the orb's range, piercing every enemy and stopped only by walls. It grows with the charge (orb-sized on a tap, about 2× wider at full, the hit as wide). The release pushes the hero back a small step (about 0.5 m over a few ticks at full, less for a weaker charge; walls stop it). A full charge still measures about 1.0× the orbs on one target (the AF1 row) | 2026-10-23 |
| NB, EL, HB, CL, BR, MP | (on OWNER_QUESTIONS 1, ELITES.md, 6, 7, 3/5/11) "1. ok go for those"; "2. ok go for those"; "3. option A"; "4. collectibles are fine"; "6. no tune up. void unlocked when traveling through a purple portal, lance is unlocked by default" | **NB:** the four bosses as drafted in BOSSES_4_5.md (Tidecaller and Twin Wardens on floor 4, Clockwork Judge and Lantern Shade on floor 5). **EL:** the three elites as drafted in ELITES.md (Breaker, Rift Hunter, Conduit). **HB:** hub option A, the Rune Ring (one plaza). **CL:** the 16 collectibles as drafted. **No tune-up:** every form stays as built (Glaive, Seekers, Scatter, Bomb, Wave, Wisps; the Lance stays at about 1.0×). **Unlocks (Q28):** the Void is unlocked by travelling through a Purple Portal; the Lance is in the pool from the start. The affinities (AFFINITIES.md) and the VFX audit are still to be gone through | 2026-10-23 |
| VX | (the VFX_AUDIT.md G1, gone through with the owner) V1 "Dark red (Recommended)"; V11 "Keep fire blast (Recommended)"; V17 "Drop it (Recommended)"; V37 "No cue (Recommended)"; V46 "Move the hero's side (Recommended)"; element looks "Build all, but very important, no cheap 2d flat arts with just plane colours, the idea is that every VFX has a high quality layered effect, (like explosions or frost) if you can't generate you can ask for the needed textures and I will generate them"; small cues "Void grow and collapse, Glaive catch flash, Halo cast ring, Backfire spark, Spiral trail"; housekeeping "Build all (Recommended)" | Approved: V1 (one palette, Bleed dark red), V2–V4, V6, V8, V10, V11 (fire blast kept), V12, V14, V15, V17 (the Lance's camera kick dropped), V18, V19, V22, V25–V27, V29, V33, V35, V36, V37 (no Swirl cue), V43, V45, V46 (the hero's Frost greener, Bleed darker), V47–V49, V52; the "keep" rows stay. **Quality bar (owner):** every effect is layered and high quality (glow core, texture, particles, light, motion), never flat single-colour 2D shapes; textures the lead can't make are requested from the owner in an art list | 2026-10-23 |
| RB | (AFFINITIES.md G1, gone through with the owner) A1 Ember, A2 Storm, A3 Venom, A4 Astral, A5 Guardian: "Approve (Recommended)" each; access "Free, swap between runs (Recommended)"; display "The rune could be under the feet matching the color of the element being used" and "Rune on the robe's back"; robes "Approve (Recommended)" | The five affinities and None as drafted (A0–A5, starting values). Free from the start, changed at the Wardrobe between runs, locked when a run starts. Shown as a small rune on the robe's back **and a rune circle under the hero's feet**, both in the affinity's colour (ember, storm, venom, astral violet, guardian gold; none for None); no run-summary line (not picked). Robes R1–R6 as drafted: Cream and Ash free, Night, Canyon, Frost, Moss for Rune Fragments; the blue core stays; no enemy red or hostile yellow. The balance checks K1–K3 run as proposed: numbers reported, nothing retuned blind | 2026-10-23 |
| CF | "one small note, for closed fights arenas overrun, etc, lets never make it a 1x1 it is too small and so many enemies appear, the enemies that spawn at the same time should be proportional to the room size, where smaller rooms are a challenge but not impossible crazy" | **Closed fights** (Arenas, the Overrun room, Lockdowns, the Chaos shrine's wave) **never use a 1×1-cell room**. The enemies that spawn at once in a closed fight scale with the room's floor area: a small room is a challenge, never a crush; a big room keeps today's numbers. The waves' totals may stay; only how many come at once follows the room | 2026-10-23 |
| CF2 | (banning 1×1 rooms cut Lockdowns from 4,000 of 5,000 floors to 2,618, Elite Lockdowns 639 → 437, arenas 4,973 → 4,604) "Lockdowns get rooms first (Recommended)" | Lockdowns (Elite Lockdowns included) pick their 2+-cell rooms before shrines, fountains, events and secrets, so most floors get 1–2 again; those kinds take the rooms left. Arenas keep their place in the order. A new floor-rules value; older floors rebuild as saved | 2026-10-23 |
| NB4 | (the Lantern Shade's "dark 4 s after the signature starts", built as dark for the rest of the fight) "Dark comes and goes (Recommended)" | Each Lights Out darkens the room for a stretch (starting value 8 s), then the light comes back until the next one (every 12 s): the dark is the signature, not the whole fight. Hittable only in light while it's dark | 2026-10-24 |
| MP2 | (the fragment sources and the robe prices, OWNER_QUESTIONS 14–15) "Robes should cost multiples runs, ascending cost starting from 75 and 25 more each one, then 250 the epic robe that appears with a ??? and it rsembles the hollow crown one, we might have to change the model a bit and not only color, then another 250 that is like the hollow drown but divine with a halo on the head" | Fragment sources stay as built (boss 3, floor 2, secret 2, Purple Portal 3, final boss 10, collectible 1). **The four robes cost 75, 100, 125, 150** (each one bought costs 25 more than the last), so each takes several runs. **Two epic robes at 250 each:** the first shows as "???" until bought and makes the hero resemble the Hollow Crown (the final boss) — a shape change, not only a colour (e.g. a crown and the Crown's dark regalia); the second is a divine Hollow Crown with a halo over the head. Both are sideways (cosmetic, PD-06) | 2026-10-24 |
| NB | (the delivered Lantern Shade has an empty hood and one held lantern) "Keep the empty hood"; (the Clockwork Judge's skeleton is broken) "can you ignore the skeleton?" | The Lantern Shade keeps its empty hood: no head lanterns, the room's edge lanterns and the one in its hand carry its fight (N4). The Judge's skeleton is ignored: it moves as cut parts (Body, ArmL, ArmR, Gears, HandHour, HandMinute), as NB1 prepared it | 2026-10-23 |
| EL | (contact damage on the Breaker and Rift Hunter has no telegraph) "Drop contact damage (Recommended)"; (the Chaos shrine's elite vs Q25) "Floors 4–5 only (Recommended)" | Elites hurt only through their telegraphed attacks: no contact damage. The Chaos shrine brings an elite (25 % of challenges) only on floors 4–5; on floors 1–3 a Chaos challenge is normal enemies only. The elite bar (built without a mockup) is for the owner to judge in play | 2026-10-23 |
| HB | (Continue with a saved run) "Resume the run directly (Recommended)"; (the in-run pause menu's exit) "To the hub (Recommended)" | Continue drops straight back into the saved floor (as built). Leaving a run from its pause menu returns to the Rune Ring, the run saved to Continue (was: the main menu) | 2026-10-23 |
| EL, SV | "Dont put the yellow strokes on elites, it looks ugly, show the model as is"; "i've encountered a problem with adding 5 floors, enemies almost oneshot you because the scaling per floor, but you hp or resistance doeasnt stack, we should not make the player rely on picking dmg reduction cards this hard, just a bit to be safer but not a must … I am not able to get to the finall boss due to dying way too fast"; then "Hero grows each floor (Recommended)"; "A bit safer, never a must (Recommended)" | Elites draw their models as delivered: no gold glow material over the bright parts. **SV (survival):** each floor cleared gives the hero +15 max HP (100 → 160 on floor 5; the loops keep growing it the same way unless capped), and the heal between floors rises from 40 % to 60 %. The enemy curves stay. Defence cards stay as they are: a bit safer, never a must; checked with the bot that a build with no defence card still reaches the final boss | 2026-10-23 |
| HB2 | "also there is no animation when taking the portal, you should click, choose weapon and then the character walks upstairs towards the portal and crosses it" | At the Portal Machine: interact, pick the weapon, then a short scripted walk: the hero climbs the machine's steps to the portal and crosses it (the portal flares, the floor's arrival follows). Input is ignored during the walk; presentation only (the run starts as today once the hero is through) | 2026-10-23 |
| HB3 | "for the hub let's make it a bit bigger and separate the runes a bit from the portal so we can see the one on the top, now the portal hides them and then lets use the top part of the hub to place all the interactive things, looking into the middle, not all loking down, also, we need decoration, floor, some other models to decorate, a different walls we don't re use what we have, lets make a list … do not make me generate 20 assets, maybe with 5 or 6" | **The Rune Ring grows** (plaza radius about 12.5 → 16 m) and the 16 floor runes move out from the machine (ring 5.4 → about 8 m) so the machine never hides the top ones. **The stations stand along the top (north) half of the ring, each turned to face the plaza's middle**, not all facing down; the spawn and the open floor take the bottom half. **Dressing:** a new floor, a new wall (not the run's kit walls), pillars with braziers, the floor runes, the sealed gate and a props set: eight assets in the art list §4b (three floors: paving, centre medallion, paths), code stand-ins until they arrive | 2026-10-23 |

## Steps (rewritten from the owner's answers, 2026-10-22)

Every step is one commit, `v0.9.0 Step <code>: <player-facing outcome>`, tested as CLAUDE.md "Testing before a push"
says. On this PC, test shards and shots run in parallel, each with its own `APPDATA`. Steps that touch the same files
run one after another; the waves below are the order, and steps inside a wave can run side by side. A step marked
**G1** or **G2** starts with that gate and builds only after the owner's answer.

### 0. Setup (done)
- Branch `claude/world-combat-v090` from `origin/main` at `aeef604a`; `MIN_TEST_COUNT` 2676 (`78271656`); the PLAN,
  PROGRESS, feedback, G1s and the art request (`54f40318`); the owner's answers (`74fca543`, `1ae81240`, this commit).

### Wave 1: the door, the camera, the portals, the arrival, the final approach
- **DS: the door boom lands with the slab** (presentation only). The impact cue fires 18 ticks before touchdown,
  from the view on `boss_door_progress()` (sim and goldens unchanged). Tests: the cue tick; `test_e2e_boss_door`.
- **CV: a vibration, not a shove** (presentation only). `IsoRig.vibrate(level)` (noise on both axes, small, with ramp,
  peak and ease), used only by the floor-1 arrival, the boss door landing, the final-boss travel (Ascension portal and
  the approach arrival) and the purple runes (DP). The arrival's kick goes; hit, finisher and Blade-kick shakes stay.
  Shake off and reduced motion stop it. Tests: amplitude bounds, mean offset ~0.
- **PT: oval portals that grow and collapse** (presentation, plus a sim flag so you can walk in only once formed).
  `portal_gate.gd`'s swirl reshaped into a frameless vertical oval with a swirling edge and particles in its colour; it
  grows from a point into a circle and then the oval with a reverse-burn edge (N8's burn) after the boss dies, and
  collapses into a point. Later floors' arrival: the same portal grows in the first room, the hero steps out, it
  collapses (replaces `FloorReceiver` there). Tests: view units; the portal e2e. One shot per biome.
- **SA: the floor-1 altar** (sim tuning + presentation). `AltarStage` (colour, runes, jewels, timeline, sound,
  trigger); floor 1 only; the six-stage sequence over 4.0 s (`arrival_first_seconds` 1.6 → 4.0); the owner's model when
  it arrives, a code stand-in first; a placeholder sound. Goldens that cover an arrival move on purpose. Tests: the
  arrival e2e. One shot per biome.
- **FA: the final approach** (sim + presentation). After the Ascension portal: a stair causeway (~25 m) to a plateau,
  no enemies; two pylons (one interact press each, on IX's first version), the purple `AltarStage`, walls of light,
  the Colossus rises from the altar; the plateau is the arena (replaces the ring arena's entry). Tests: the gate unit;
  an e2e from the Ascension portal to the Colossus's rise through real input.

### Wave 2: the attack system (Gun forms)
- **AS: slots, categories and compatibility** (sim + tests + presentation). Categories and limits in data (Form 1,
  Pattern 1, Secondary 2, Elements 2); patterns Twin (merged), Halo, Ring, Backfire; Spiral and Swirl as motion
  secondaries; one compatibility table; no layering of forms; offers filtered (`item_pool.gd:87-99`); "replaces X" and
  the burn (G2 for the card and Build page); 12 projectiles per attack with merging; the slot tag on every card (en,
  es); runs saved in v0.8.0 still load (how an over-full wand is trimmed is proposed to the owner in this step). Tests:
  compile, offers, old saves; e2e `test_e2e_attack_slots`.
- **TW: Twin and Spread become one card** (data + sim). 2 copies at Lv 1–4 (60/70/80/90 %), 3 at Lv 5 (70 %); side by
  side, a 15° fan at three. `gun_spread` retired through `migration.tres`.
- **XP: no more death explosions** (sim + data). Fire's kill blast becomes a burning patch (1.2 m, 2 s); the Explosive
  card is retired; Fire's text updated (en, es).
- **VP: Void becomes a projectile.** `gravity_well` retired; `black_holes.gd`, its views and `hole_*` deleted; the
  Void form (Q10).
- **LZ: the laser**, **BM: the bomb** (sim + tests + presentation each, Q8, Q9).
- **AF1–AF3: Lance + Scatter, Glaive + Seekers, Wave + Wisps** (Charge and Boomerang retired).
- **LG: the legendary nerf** (data: Power and Haste × 1.3).
- **BR: the balance review.** The projectiles-a-second regression test (≤ 40); per-form DPS sheets from the
  Playground's meter (`evidence/FORMS_DPS.md`); the two strongest forms named for Q28.
- **VX: VFX** (**G1** `VFX_AUDIT.md` first): launch, travel, impact and element looks per form; Twin, Ring, Spiral,
  Swirl cues; modular textures with code fallbacks.

### Wave 3: five floors
- **FV: a run is five floors** (sim + data; PD-03 changed). Floors of about 10, 13, 15, 17, 19 rooms; the stretched
  curves (`data/curves/`, `three_floors.tres` → five); wand slots 4–8; all five biomes once each; loot scaled to room
  count; shop on 1, 3, 5; enemy kinds keep their floor 1–3 introductions, floors 4–5 draw from all; the run save
  migrates (a v0.8.0 run in progress resumes in its 3-floor shape). Generation property tests over 1,000 seeds; goldens
  change on purpose.
- **NB: four new bosses** (**G1** `BOSSES_4_5.md`: one signature mechanic each, checked against the six; then model
  prompts; code stand-ins, one step per boss).
- **DP: the Purple Portal is earned** (sim + presentation). The purple-rune event room (a big room; never floor 1,
  50 % on floor 2, else certain on floor 3, one per run); activation plays the vibration; that floor's boss then opens
  the Purple Portal. Deep floors lose "an elite in every combat room".

### Wave 4: the world
- **IX: a shared interactable** (sim + presentation; FA's pylons move onto it).
- **PC: puzzle calm**: spawns at a quarter of the rate in a puzzle's room.
- **TD: timed doors** (15 s, beeps, PD-05's clarification). **RA: rune alignment** (3 × 4). **DX: destructibles**
  (cracked walls to the Skill only, hidden rooms unseen until open; containers; explosive barrels; hidden rune
  markings). **HF: healing fountains.**
- **LK: lockdowns** (a new room type, 1–2 a floor; Normal, Elite, Hazard per biome; the stuck-enemy safety and the 90 s
  cap, tested with a stuck enemy).
- **RG: the special-room schema** (`SpecialRoomDefinition`) and the pacing report over 1,000 seeds, plus the
  no-softlock property tests (timed doors completable at base speed, lockdowns always open).
- **EL: elites** (**G1** `ELITES.md`; **G2** the bar). The ×2 HP elite, the Marked curse and the Ambush Cache event
  deleted; archetype framework; floors 4–5 at 15 % / 25 %, at most 1 alive, 2 rooms apart; 30 % core drop; the bar with
  its name; one step per archetype (Breaker, Rift Hunter, Conduit).
- **SH: shrines**: the gamble shrine becomes Fortune; Blood and Chaos added.
- **BV: biome looks** for every Wave 4 interaction.

### Wave 5: the hub and progression
- **HB: the hub** (**G2** first). The small menu (Play, Continue, Options, Quit); the hub with the Portal Machine, the
  Rune Archive (Codex, collectibles), the Wardrobe, the Progression Station, the Trophy Area and the Credits; the
  evolving states keyed on profile flags; the run summary, Restart (one press) or the hub.
- **MP: Rune Fragments** (**G1** `UNLOCKS.md`: sources, rates, prices; the two strongest forms from BR; no stat
  upgrades, PD-06); the profile migrates to version 2.
- **RB: robes and affinities** (**G1** `AFFINITIES.md`).
- **CL: collectibles** (**G1** `COLLECTIBLES.md`, 16 drafted by the lead).

### Wave 6: after the owner plays
- **PZ: puzzles B, D, E, F**, once the owner has judged TD, RA and DX.
- **UC: the utility cards** approved in Q30 (1, 2, 3, 6, 7, 8, 9, 10, 11, 15, 16, 17, 18, 22; 4 as Phase Strike's
  higher levels), in batches. They can move earlier if a wave has room.
- **EM:** Swarmer, Mine Layer and Sniper when the owner's files arrive (any time).

### R. Release
- Version 0.9.0 in `project.godot`, patch notes en + es, What's New, the ROADMAP row and History, the README status
  line, CLAUDE.md re-checked, PROGRESS final, PLAYTEST.md, the full suite on the PR into `main`.

## Audit (live code, 2026-10-22)

The four read-only investigations, condensed. Paths are from the repo root.

**A. Attack system**
1. The wand: `data/wand/wand.tres` `slots_per_floor (4, 6, 8)`, `MAX_SLOTS 8` (`wand_definition.gd:12`); compile in
   `WandCompile.run` (`wand_compile.gd:124-147`), stage order FORM, PATTERN, BEHAVIOUR, PAYLOAD, HOOK, SCALE
   (`modifier_table.gd:8`); triggers cut the chain (`:312`, `MAX_DEPTH 2`); v0.8.0's `OrderKind {FREE, SHAPE, COUNT,
   MOTION}` (`modifier_table.gd:10`); Blade/Gun from `data/builds/*.tres` (`content_compiler.gd:375-387`). There is a
   `Form` enum (ARC, BOLT, RING, BEAM, ZONE, ORBITER, LOB, BURST, WEAPON; `attack_spec.gd:11`), but forms are not
   exclusive: a second SET_FORM layers an extra attack (`wand_compile.gd:153-160, 293`).
2. Patterns that exist (Gun): Twin (Epic, +1 lane, 60 % share), Spread (+2 shots, 30°), Halo (×3, full circle),
   Ring (travelling ring, `wand_rings.gd`), Spiral, Swirl, Backfire. Secondaries: Split, Echo, Pierce, Ricochet,
   Homing, Big Shot, Rapid Fire, Mine, Charge, Threadline, Orbit, Boomerang. Shared: Explosive, Faultline, Gravity
   Stitch, Stress Mark; triggers (On Hit / Kill / End / Finisher and ×2); mutations. 43 old cards are retired
   (`migration.tres`, `item_pool.gd:90`).
3. Elements: `ember, storm, frost, venom, void, bleed` (`modifier_op_definition.gd:147`); statuses `burn, shock,
   bleed, frost, slow, poison` (`attacks.gd:41`). Void's floor black hole: `data/items/gravity_well.tres`,
   `data/modifiers/gravity_well.tres` (8 % + 3 %/level), `wand.tres hole_*`, `src/sim/combat/black_holes.gd`,
   `attacks.gd:277-278, 876-877`, `modifier_runtime.gd:142`, `world_snapshot.gd:286`, `black_hole_views.gd`, strings
   `ITEM_GRAVITY_WELL(_DESC)` (`strings.csv:713-714`).
4. Legendary stat cards: epic × 1.6 (`data/legendary/boss.tres`; `content_compiler.gd:890, 911-912`); Power 8/15/25 →
   40 % (`data/stat_cards/damage.tres`), Haste 6/12/18 → 28.8 % (`attack_speed.tres`, cap 2.5); damage is one additive
   bucket (`stats.gd:153-160, 257`); attack rate goes through `AttackRate.curve` (`attack_rate.gd:26-41`: full to
   +50 %, half to +150 %, a quarter beyond).
5. Caps: 256 player shots alive (`attacks.gd:32`), 256 launches a tick, hook depth 2, rings 48 / 5 pulses / 64
   children (`wand_rings.gd:52-57`), blasts merge past 8 a tick (`attacks.gd:747-753`). **No cap per attack.**
6. Offers: `Offers.roll` (`offers.gd:79-90`); weights `ItemPool.card_weight` (`item_pool.gd:44-64`; own weapon ×1.5);
   filters `ItemPool.usable` (`:87-99`) and `LootPacing.compatible` (`loot_pacing.gd:80-98`).
7. Text: 116 `ITEM_*_DESC` keys, 4 with baked digits, none with `%s`; 18 `STAT_*_DESC` keys fill `%s` from data;
   wand cards show only their level before → after (`card_forecast.gd`).
8. VFX: `attack_form_looks.gd` composes looks from the compiled spec (cues `:177-215`); element looks
   `vfx_layer.gd:45-100`; no own cue for Spread, Halo, Echo, Rapid Fire, Backfire, Big Shot, Swirl, Split, Orbit.
9. No player laser or bomb today; the LOB and BEAM forms exist; hold-to-fire exists (`player_kit.gd:118-121`).

**B. Portals, altar, door, camera, final boss**
1. Gates: `floor_generator.gd:361-392`, `boss_room_builder.gd:458-460`, `routes.gd:51-63` (Deep), `boss_flow.gd:296-319`;
   views `portal_gate.gd` (2.4 × 3.2 m, shader `:79-157`, unseal `:261-293`), `world_view_root.gd:302-322, 440-449`.
   Ascension `ascension_portal.gd`, Loop `loop_device.gd`, `ascension.gd:34-47`.
2. Arrival: `floor_receiver.gd` (2.2 m disc, stand-in), `data/tuning/sim.tres:9-11` (1.6 s / 0.8 s / 0.3 s),
   `boss_flow.gd:52-57, 212`, sequence `portal_transit_view.gd:282-337`; **no arrival sound**.
3. Camera: `iso_rig.gd` (amount decays 2.5/s `:69`; golden-angle path `:73-76`; `shake` `:107`, `shake_to` `:114`,
   `kick` `:84-103`, flourish `:120`); toggles `game_settings.gd:36, 40`.
4. Door: press `boss_flow.gd:149-161`; open at +162 ticks `:170-178`; cues `audio_events.gd:190-193`; view
   `boss_door_view.gd:240-281` (linear, lands at progress 1.0, shake `world_view_root.gd:431-432`,
   `DOOR_LAND_SHAKE 0.3`); `boss_door_impact.wav` 2.95 s, near-silent for 0.15 s, peak around 0.3 s.
5. Final boss: `run_state.gd:282-283`, `floor_plan.gd:91-107, 145`, `final_arena_scenario.gd`, `final_arena.gd` (ring
   of 32 walls, r 15 m), `final_arena_stage.gd`, `final_boss.gd:37, 141-160`; no intro beyond the 60-tick rise.
6. Interact: `InputFrame.INTERACT` (`input_frame.gd:8`); dispatch order `world.gd:607-616` (rewards, events, shop,
   gamble, boss door); prompts per HUD (`hud.gd:497`, `event_hud.gd:57`, `shop_hud.gd:43`, `gamble_hud.gd:116`,
   `boss_door_hud.gd:36`). No shared abstraction.
7. Sigils and orbiters: `fx_textures.gd:110-121`, `curse_room_view.gd:24-46`, `ascension_portal.gd:56-59, 495`.

**C. Elites, rooms, persistence**
1. Elite: `curses.gd:229-235` (HP × 2, nothing else), sources Marked (`marked_hunt.tres`, 1.2 %/spawn), Deep
   (`spawn_director.gd:169, 177-185`), Ambush Cache (`ambush_cache.tres`, 3 elites); core theft `core_theft.gd`
   (stagger at 30 % HP, 2 s window, `:161-185`); look: gold ring (`event_pedestal_views.gd:19, 65, 292`), core crystal
   (`core_views.gd:4`), the normal bar (`actor_views.gd:12, 607`).
2. Run: 3 floors (`three_floors.tres`); loops ×6 HP / ×1.2 damage, cap 100× (`ascension.gd`); Deep ×1.25, O35's ×0.9 on
   loop ≥ 2 (`run_state.gd:168-206`); T (`curses.gd:83-88`); tiers every 30 s (`data/spawning/floor_1.tres:81-91`).
3. Rooms: `floor_generator.gd:3-15` (15–19 rooms), layouts `room_layouts.gd` (24), Overrun `overrun_rooms.gd:3-11`,
   Arenas `arena_rooms.gd:1-40` (share 0.11), shop, events (1–2), curse room (40 %), shrine (40 %), altars and chests
   (`rewards.gd:7-12`). Arenas seal with collision-only barriers (`arenas.gd:4-9`); clear = waves done and nobody alive
   inside (`:73-95`); no timeout.
4. Intensity director: `intensity.gd:1-50`; skipped in arenas, the Overrun and boss rooms (`world.gd:688-694`).
5. Destructibles, fountains, prop drops: none.
6. Persistence: `profile_store.gd` (`PROFILE_VERSION 1`; `unlocks` never written), run save `run_save_store.gd`
   (`SAVE_VERSION 1`), 32 achievements, Codex (`codex_store.gd`); no meta currency.
7. Flow: menu `main.gd:158-175`, Play `:181-192`, EndPanel `:508-555`; no hub. Hero colours hard-coded
   (`player_avatar.gd:100-107`).
8. Locked: PD-03 (`LOCKED_DECISIONS.md:47`), PD-05 (`:49`), PD-06 (`:50`), PD-12 (`:56`); ROADMAP §6.

**D. EM and UC:** see E1–E2 and [`UTILITY_CARDS.md`](UTILITY_CARDS.md).

## Open items (what they block)
- The owner's go on the rewritten Steps: Wave 1 starts then.
- The G1s and G2s named in the steps: each blocks only its own step.
- The owner's models: the altar (SA uses a stand-in), the elites and the four new bosses (stand-ins), Swarmer, Mine
  Layer and Sniper (EM). The owner's arrival sound is not needed (Q16: the lead's placeholder).

## Verification
- Per step: the tests named in it, plus the e2e that reaches it through `main.tscn` and real input.
- Goldens change only on purpose (SA's arrival length, AS's compile, VP's removal), each named in PROGRESS.
- W §15 acceptance, item by item: no softlock (RG's 1,000-seed property tests for timed doors, lockdowns and
  destructible paths), elite deaths and lockdown completion (unit + e2e), old saves load (the seams' old-saves test,
  plus a v0.8.0 save fixture), special rooms respect their floor rules (RG), readability (shots from the game camera),
  performance (the horde probe from v0.8.0 FV, on this PC; real timing on the owner's machine).
- C §9's regression (BR's projectiles-a-second test).
- The lead runs `scripts/ci/seams.sh` after merges; the full suite once on the PR into `main`; then the owner's
  Windows playtest.

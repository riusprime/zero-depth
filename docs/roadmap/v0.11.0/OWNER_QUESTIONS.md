# v0.11.0 — questions for the owner (brainstorm, 2026-11-07)

From the brief ([`feedback/`](feedback/ZeroDepth_v0.11_Feedback_and_Design_Brief.md)) and the Phase 0 audits
([`PLAN.md`](PLAN.md)). Each question has options and the lead's recommendation (**rec**). Answer by number
("Q3 b, Q9 rec, Q14 change: …"). Nothing in Waves 2–4 is built before the answer. Answers are recorded at the bottom
the same day.

## A. Scope

**Q1. What goes in v0.11.0, and what waits?** The brief is large: 3 bugs, the Laser, about 10 boss reworks, hordes,
15 spells, enemy models, new enemies with biome rosters, room messages, room structure.
- (a) **rec:** v0.11.0 = the bugs, the Laser, the bosses the brief names (Gatekeeper, Lantern Shade, Twin Wardens) plus
  the two worst-immunity ones (Tidecaller, Prism), the spells, and the horde kind. v0.11.5 or v0.12 = the other
  bosses, new enemies and biome rosters, enemy models, rooms, lore.
- (b) Everything in v0.11.0 (a long version, playtested at the end).
- (c) Your own split.

## B. Bugs

**Q2. The Lantern Shade's dark: what should it hide?** Since v0.9.0 the dark has hidden the wisps (the Shade's shots)
but deliberately kept ground telegraphs visible. The wisps stopped hiding in v0.10.0 (the VFX pack change).
- (a) **rec:** Wisps hidden again outside the light (the 4 m outline stays as the warning); telegraphs stay visible.
- (b) Hide the telegraphs too, outside any light (harder; the lanterns matter more).

**Q3. The Siege Engine's second volley.** Today it shows only 0.6 s before it strikes, 1.0 s after the first.
- (a) **rec:** Show volley 2's board from the start (dimmer, "next") and give it the full 1.6 s like volley 1; the gap
  stays 1.0 s. Phase 3's third volley the same way.
- (b) Keep it hidden until volley 1 lands, but lengthen its telegraph to 1.2 s.
- (c) Only remove the smoke; keep the timing.

## C. The Laser (the sketch is still to come)

**Q4. Damage = 3 s of beam in one shot.** At Lv 1 that is ≈ 30 × the shot's damage. Does the 3 s cooldown also
shrink with attack speed (as the beam's rate does today at half value)?
- (a) **rec:** Yes, at half value, like today; the damage per shot stays fixed, so DPS matches the beam.
- (b) No, a fixed 3 s; attack speed adds damage instead.

**Q5. Statuses and procs.** Today 3 s of beam applies about 20 status hits (burn, frost, venom, bleed stacks,
lightning jumps). One shot would apply 1.
- (a) **rec:** One shot applies the stacks of ~6 hits (a big burst of status on everything it touches), and Lightning
  jumps from every enemy on the path. Crit rolls once per enemy hit.
- (b) Apply all 20 hits' worth (very strong on elements).
- (c) Only 1 (elements become weak on the Laser).

**Q6. Rapid Fire, Echo, Mine, Big Shot on the Laser** all assume a held beam today.
- (a) **rec:** Rapid Fire: −30 % cooldown, −20 % damage a shot. Echo: the shot re-strikes its path after 0.4 s at
  50 %. Mine: one mine at the path's end each shot. Big Shot: a wider lance, ×1.6 damage, no aim lag.
- (b) You list each.

**Q7. Is it instant, or does it travel?**
- (a) **rec:** Instant hit along the whole path, with the line drawn quickly from your hand to its end (~0.15 s) and a
  glow that fades over ~0.5 s: "charged lance".
- (b) A fast travelling lance that steers through targets (like the Fireball's homing ball, but a line).

**Q8. The curve.** With Homing + Pierce the shot picks up to `pierce + 1` targets (max 5) nearest first and bends
through them as one smooth curve; after the last it goes straight to full range. Without Homing it is straight. OK,
or should the curve also bend without Homing (just Pierce)? (Your sketch decides the look.)

## D. Bosses (the G1 BOSS_AUDIT will hold the final rows)

Today every boss has shielded windows. The longest: **Tidecaller** (shielded ≈6 s of every 8 s), **Lantern Shade**
(≈9 s of 12 unhittable unless lit), **Prism** (shielded most of the fight), **Fallen** (two 15 s untargetable
interphases), **Brood Mother** (burrows 2.4 s). The Warlord has none, which may be why it feels good.

**Q9. The Gatekeeper's quake pillars.**
- (a) **rec:** At the start of phase 2 it raises 3 pillars (phase 3: they come back). Each pulses every 3 s, a small
  ring of damage (≈3 % of your HP). Shock Lanes' cross that passes through a pillar shatters it, and the Gatekeeper is
  stunned 2 s and takes +50 % damage while stunned (a reward for luring it). A hint arrow points at a pillar the first
  time.
- (b) As (a), but no stun: breaking the pillars only stops their damage (your brief's wording).
- (c) The pillars also shield the boss while any stands (a must-do, more WoW-like).

**Q10. The Lantern Shade: light and dark.**
- (a) **rec:** No more immunity. In the dark it takes 40 % damage; inside a lit lantern's pool, 150 %. Stepping on a
  lantern lights it for 6 s; Snuff puts lanterns out. The dark and the light alternate (dark 9 s, then 4 s full light).
- (b) Your numbers.

**Q11. The Twin Wardens.**
- (a) **rec:** Yellow (physical): Shield Bash, Chain Sweep, a charge, a ground slam. Purple (magic): Crossfire, an
  orb volley, a rune ring, a blink. Phase 1 (100–66 %): yellow leads; purple stands back, shielded, casting one simple
  bolt every 4 s. Phase 2 (66–33 %): they swap. Phase 3: both active; their big attacks alternate, never overlap;
  every 10 s one twin "exposes" (glows, takes ×1.5) and the other takes ×0.5, so you switch targets.
- (b) Change any part.

**Q12. The hint.** A small arrow or ping at the object that matters (a pillar, a lantern, the exposed twin).
- (a) **rec:** Shown the first 2 times you meet each mechanic, tracked in the Codex; an option turns it off.
- (b) Always shown.
- (c) Never: learn by play.

**Q13. The other bosses: the lead's starting ideas** (approve, change or defer each; the Warlord row is for your
"room for upgrades").
- **Tidecaller:** The Pull loses its shield; instead it drags you **and** the floating ice chunks in. A chunk that hits
  the Tidecaller stuns it. (Risk: close range during the pull is the damage window.)
- **Brood Mother:** no immunity while burrowed. She surfaces at the nearest egg; an egg you break first makes her
  surface stunned.
- **Hive Lens:** the lens drones reflect its Focus Beam; a beam bounced back into the Lens breaks its Spiral shield.
- **Foundry:** quench valves on the walls: hit one to cool a lava lane for 6 s and open a path to it.
- **Clockwork Judge:** the Echo replays your last 3 s; an echo strike that lands on the Judge's own gears damages it,
  so where you walked matters.
- **Warlord:** (optional) the javelins it recalls can hit it if you stand so it pulls them through itself.
- **Prism (final):** fewer shields; the Cross window comes more often; the facets you break stay broken.
- **Fallen (final):** the 15 s untargetable interphases become 8 s, and you can hit its copies inside them.
- **Colossus (final):** no change (it has no immunity beyond its 1.5 s shatter).

## E. Horde enemies

**Q14. What are they?** Contact damage, ~6–10 HP, packs of 15–30, fast but dumb.
- (a) **rec:** One horde critter per biome, with its own look: Ruins dust mites, Night Rocks bats, Red Canyon ember
  fleas, Frozen Shore ice crabs, Starfall star motes. Same rules, different bodies.
- (b) One horde critter for every biome (cheaper; one model).
- (c) Something else you have in mind.

**Q15. When do they appear?**
- (a) **rec:** As "surges": once or twice a floor the spawner sends a burst of 30–60 over 10 s, announced by a sound.
  Also in Overrun rooms and Lockdowns.
- (b) Mixed into normal spawns all the time.

**Q16. Performance gate.** Many more bodies on screen. OK to measure a 120-enemy surge on your PC (the RTX 3060) before
it ships, and cap the surge if it drops under 144 fps? (**rec:** yes.)

## F. Elemental spells

**Q17. How does an element "unlock" its spells?**
- (a) **rec:** Holding an element card (Fire, Frost …) in your wand adds that element's 3 spells to the card pool for
  this run. You can mix: 3 Frost + 1 Fire needs both cards at some point.
- (b) Unlocked once in the hub (meta progression), then offered in every run.
- (c) Spells are offered from the start, no unlock.

**Q18. Upgrades.** (a) **rec:** Taking a held spell again levels it (Lv 1–3, Lv 4–5 from loop 2), each level a
visible change (bigger radius, longer, more hits), like the element levels. (b) Separate "spell upgrade" cards
(radius / duration / damage) that apply to one spell.

**Q19. The HUD.** (a) **rec:** 4 small squares above the ability bar with each spell's cooldown sweep; a spell flashes
when it fires. (b) Spells on the existing ability squares.

**Q20. The roster** (G1 SPELLS.md gets the full rows). The lead's proposal, your 6 in bold:
| Element | 1 | 2 | 3 |
|---|---|---|---|
| Frost | **Blizzard** (ice rain, slows) | **Frost Nova** (1 s freeze around you) | Ice Lances (3 shards at the nearest foes) |
| Fire | **Fireball** (big, automatic) | **Burning Ground** (a fire area) | Meteor (a slow, huge strike) |
| Lightning | **Sky Strike** (hits a foe, area) | Ball Lightning (a slow orb that zaps nearby) | Static Field (a ring around you that shocks) |
| Venom | **Venom Orb** (a pool of stacks) | Toxic Cloud (drifts with you) | Spitter Vine (a plant that spits at foes) |
| Bleed | Blood Thorns (spikes around you, bleed) | Hemorrhage (a mark that bursts bleed) | Leech (heals you from bleeding foes) |

Does Bleed get spells (it is an element card today), and keep, change or replace any proposal?

## G. Enemies

**Q21. Which enemies get new models?** Nine are the lead's code-made bodies: Charger, Hatchling, Needle, Warden, Arc
Caster, Bomb Drone, Swarmer, Mine Layer, Sniper. Four are yours (`.glb`): Lens Drone, Mender, Shield Bearer,
Splitter. All but the Lens Drone already animate through VAT. "Charger-style but not red" — do you mean
(a) **rec:** your `.glb` models made in the Charger's style (faceted, spider-like rigs), for the code-made eight
besides the Charger, in each one's role colour; (b) only Swarmer, Mine Layer, Sniper (already in OWNER_TODO §3.2);
(c) a list you give.

**Q22. How many new regular enemies in this version?** (a) **rec:** 2 per biome (10), designed in a G1 list first;
(b) 5 shared; (c) later version.

**Q23. Biome rosters.** (a) **rec:** each biome keeps a shared core of 4 (Charger, Needle, Swarmer, Warden), plus
its 2 signature enemies, plus a biome variant of one existing enemy (for example a Frozen Shore Charger that leaves
ice); floor depth still unlocks the later kinds. (b) Fully separate rosters per biome.

## H. Room messages and rooms

**Q24. What are the "room messages" you saw?** No room message exists in the code. What did you see on screen? (a)
The TIP hints (move / attack / dash); (b) the collectible lore lines in the Archive; (c) event descriptions; (d)
text on the floor or walls of a room (a shot would help); (e) something else.

**Q25. The Runic Stone's Easter egg (after Q24).** Today the stone learns 10 lines, each from a hidden feat (r1 a
purple-rune room, r2 10 deaths, r3 7 presses in a row, r4 a boss with no hit, r5 60 s still in the hub, r6 8
collectibles, r7 the Hollow Crown beaten, r8 three loops, r9 cracked walls on 5 runs, r10 switching language). The
reward is the Runic robe. The lines read as riddles but point nowhere. Starting ideas:
- (a) **rec:** each line becomes a **clue** to its own feat or to a place in a run ("THE WALLS HIDE WHAT THEY FEAR" →
  a cracked wall), and the ten together tell one short story (the city the Depths were; the Codex Lore's world). The
  last line opens something real: a hidden room on the final floor, or a secret final-boss variant.
- (b) The runes also **appear in runs**: a rune carved in a room matches a stone line, and reading it there teaches
  the line (a world-to-hub link).
- (c) A mix: some lines learned in the hub as today, others found carved in rooms, and a full stone opens a reward.

**Q26. Rooms with a purpose.** Large rooms (3x3 and up) get one purpose each, a focal piece plus dressing that fits it,
like the shop: a camp, a collapsed hall, a shrine, a quarry, a supply yard (per biome). The lead makes G2 shots of
(a) **rec:** purpose rooms from authored templates (like shops) with seeded variation; (b) rules that grow dressing
around one focal piece; (c) a mix. OK to make those shots?

## C2. Pierce (from your Q5 answer)

**Q28. The Laser's built-in pierce, and where the Pierce card is offered.** Gun forms today: the plain Pulse bolt,
Glaive, Lance, Laser, Rune Explosion, Seekers, Void, Wave, Wisps.
- (a) **rec:** the Laser pierces 2 enemies from the start (3 hit in a line); the Pierce card on the Laser adds +1 per
  level and lets Homing chain through more. The Pierce card is offered only with the plain bolt, Seekers, Glaive and
  the Laser; never with Lance, Void, Wave, Wisps or Rune Explosion.
- (b) The Laser pierces everything in its line from the start; the Pierce card isn't offered with the Laser at all.
- (c) Your own form list.

## I. The v0.10.5 checklist

**Q27.** The brief doesn't answer the v0.10.5 PLAYTEST rows (hub gaps, see-through fade, pools, Lance charge, Foundry
and Hive Lens fixes, loops, Astral UI, performance, enemy shadows). (a) **rec:** treat the ones you didn't mention as
OK; (b) you'll go through them.

## J. Overnight (2026-11-08, while you slept)

The owner: "keep working on the plan don't stop if you have questions write them down and I will answer them tomorrow".
Each row says what the lead does meanwhile (**default**). Answer by number ("N3 no", "N5 smaller") or "defaults OK".

| # | Question | Default (what is built until you answer) |
|---|---|---|
| N1 | **The hidden room's reward** (Runic Stone, "Both"): the room under the Hollow Crown's throne holds "one unique card or relic found only there". What is it? The lead's idea: **The City's Heart**, a relic: once a run, the first killing blow on you instead leaves you at 1 HP and pulses a 4 m shock ring (the city catching you; r2's "TEN TIMES YOU FELL"). | The room, its rune scene and a pedestal are built; the pedestal holds the lead's relic as a **placeholder** until you approve or replace it |
| N2 | **The "remembered" Hollow Crown fight** behind the room: its moves are yours (Q13, your boss brief). | The door is built and **sealed** ("THE CROWN IS NOT YET REMEMBERED" in runes) until your brief |
| N3 | **Biome pieces outside their biome** (rule O78): the Ruins hall uses the Night Rocks `stone_arch`; both quarries use the Ruins `ladder_frame` for scaffolds (as in the mockups you approved). OK, or swap? | As built |
| N4 | **Two purposes the lead added**: Red Canyon also gets the camp, Night Rocks also gets the stone-ring hall (so every biome has at least one purpose and most have two). Keep? | Kept |
| N5 | **Boss idle sway under reduced motion** stays full (shrinking it pulls held poses, like the Warlord's weapon, toward rest). Smaller? | Full |
| N6 | **Surge cap 120** holds 161 fps on average but its slowest 1 % of frames run ≈ 121 fps; at 90 they run ≈ 136 fps. Keep 120, or 90? | 120 |
| N7 | **The Glacier Turtle** is hard to see behind its pale shell. | The lead makes its body darker and a little bigger (a Sonnet step) |
| N8 | **The v0.10.5 checklist (S5, your Q27 "treat as unmentioned")**: the lead closes every v0.10.5 PLAYTEST row you didn't mention in the brief (hub gaps, see-through fade, pools, Lance charge, Foundry and Hive Lens fixes, loops, Astral UI, performance, enemy shadows) as OK. Confirm? | Closed as OK in OWNER_TODO, noted "per Q27" |
| N9 | Small looks to judge when you play: Meteor's mark (a pale swirl and a falling rock) vs a boss telegraph; the Spitter Vine drawn as a poison bubble (no plant in the packs); the Swarmer's crimson role colour; the Gatekeeper's phase-3 pillars rising in new spots; right after the tenth rune line the stone shows the eleventh first; critters no longer flinch when hit. | As built |

## Answers (owner)

| # | Answer | Date | Recorded in |
|---|---|---|---|
| Q1 | "Everything in v0.11.0" | 2026-11-07 | PLAN Context (scope) |
| Q3 | "Longer hidden telegraph but remove the smoke, leave just the 'explosion' effect that we currently have" → (b): volley 2 stays hidden until volley 1 lands, then shows for 1.2 s; the pack Smoke goes, the explosion stays | 2026-11-07 | PLAN S3 |
| Q17 | "Hold the element card, if you chose that element as a rune in the wardrobe these cards also have a higher chance of appearing" → (a) plus: the element worn as the Wardrobe's rune affinity raises its spell cards' offer weight | 2026-11-07 | PLAN E1, O10 |
| Q2 | "wisps are now visible in darkness due to new VFX so you can see all of them that's what I meant, we need to hide them again, some of the attack patterns have the wisps too close to each other and leave almost no space to dodge" → (a), plus: the Shade's denser wisp patterns get wider gaps | 2026-11-07 | PLAN B2, S2, S2b |
| Q5 | "3 hits worth, the laser should have piercing from the beginning I think, and then piercing would not appear for all the attacks that don't need it like lance, void, wave, etc, it would only appear as an option if you have a compatible attack form" → one shot applies 3 hits' worth of status; the Laser pierces by default; the Pierce card is offered only with a form it changes | 2026-11-07 | PLAN L1, L3b, O1, S6 |
| Q7 | (a) Instant, drawn fast (~0.15 s), glow fading ~0.5 s | 2026-11-07 | PLAN L1, O1 |
| Q25 | (a) The lines become clues; together one short story; the full stone opens something real | 2026-11-07 | PLAN R1, O14 |
| Q28 | (b) "Pierce everything, no card": the Laser goes through every enemy on its path; the Pierce card is never offered with the Laser (with Homing it still bends through up to 5 chosen targets, then runs straight to full range) | 2026-11-07 | PLAN L3b, O1, S6 |
| Q4 | (a) Attack speed shortens the 3 s cooldown at half value; damage per shot fixed | 2026-11-07 | PLAN L1, O1 |
| Q9 | "boss takes more damage during the stun, this should happen at most 2 times per phase" → (a): a pillar broken by Shock Lanes stuns the Gatekeeper 2 s at +50 % damage taken; at most 2 stuns per phase (a later break still removes the pillar) | 2026-11-07 | PLAN L5, O3 |
| Q10 | (a) 40 % damage in the dark, 150 % inside a lit pool; a lantern stays lit 6 s; dark 9 s / light 4 s | 2026-11-07 | PLAN L6, O4 |
| Q11 | "The boss has 3 phases of full hp P1 should be yellow p2 purple p3 both at the same time, we need to animate these bosses a bit better, right now the animation feels too stiff" → P1 yellow, P2 purple, P3 both. "3 phases of full hp" read as: each phase is a full health bar (to confirm, Q29). Plus: the Twins' animation gets a pass (less stiff) | 2026-11-07 | PLAN L7, L7b, O5 |
| Q12 | (a) The hint shows the first 2 meetings of each mechanic (Codex-tracked); an option turns it off | 2026-11-07 | PLAN L4, O2 |
| Q6 | "mine is disabled for laser, the rest as you mentioned, more attacks 20% less dmg, and echo re-strikes at 50%. big shot bigger beam more damage": Mine not offered with the Laser; Rapid Fire −30 % cooldown at −20 % damage a shot; Echo re-strikes the path after 0.4 s at 50 %; Big Shot a wider lance at ×1.6, no aim lag | 2026-11-07 | PLAN L1, O1, S6 |
| Q14 | (a) One horde critter per biome, same rules, its own body | 2026-11-07 | PLAN H1, O9 |
| Q29 | A full bar per phase: P1 yellow (full bar), P2 purple (new full bar), P3 both (new full shared bar); total paced to 1–2 min | 2026-11-07 | PLAN L7, O5 |
| Q30 | (a) The animation pass covers all bosses, the Twins first | 2026-11-07 | PLAN L7b, O16 |
| Q15 | "Surges but not during an overrun or lockdown": once or twice a floor, 30–60 over 10 s with a sound; never inside an Overrun room or a Lockdown | 2026-11-07 | PLAN H1, O9 |
| Q18 | (a) Taking a held spell again levels it (Lv 1–3, 4–5 from loop 2), each level a visible change | 2026-11-07 | PLAN E3, O11 |
| Q20 | (a) All 15 spells, Bleed included, as a G1 (SPELLS.md) approved row by row | 2026-11-07 | PLAN E4, O10 |
| Q19 | (a) 4 new HUD squares above the ability bar, cooldown sweep, flash on cast | 2026-11-07 | PLAN E2, O10 |
| Q21 | (a) New `.glb` models in the Charger's style for the 8 code-made kinds besides the Charger (Hatchling, Needle, Warden, Arc Caster, Bomb Drone, Swarmer, Mine Layer, Sniper), role colours, VAT | 2026-11-07 | PLAN M1, art list |
| Q22 | (a) 2 new regular enemies per biome (10), G1 ENEMIES.md first, plus the 5 horde critters | 2026-11-07 | PLAN M2, O13 |
| Q23 | (a) Each biome: a shared core of 4 (Charger, Needle, Swarmer, Warden) + its 2 signature enemies + a biome variant of one existing enemy; floor depth still unlocks the later kinds | 2026-11-07 | PLAN M3, O13 |
| Q26 | (a) G2 shots of purpose rooms from authored templates (like shops) with seeded variation | 2026-11-07 | PLAN P1, O15 |
| Q16 | (a) Measure a 120-enemy surge on the owner's PC; cap the surge if it drops under 144 fps | 2026-11-07 | PLAN H1, O9 |
| Q27 | "treat as unmentioned": read as (a), the v0.10.5 rows not mentioned in the brief are OK and close in OWNER_TODO (the lead confirms with the owner when closing) | 2026-11-07 | PLAN S5 |
| Q24 | "I think I meant the rune that is at the hub": the **Runic Stone** (v0.9.5 RS1/RS2). Clarified in chat; see Q25 | 2026-11-07 | PLAN R1 |
| Q8 | Straight without Homing (rec): only Homing bends the lance (through up to 5 targets, then straight to full range); a plain Laser is a straight lance through everything in its line | 2026-11-07 | PLAN L2, O1 |
| Q13 | Asked row by row first (Tidecaller approve; Brood Mother "Not every boss has to have a stun feature", then no hatchling wave after a broken egg; Hive Lens, Clockwork Judge, Prism, Fallen defer; Foundry approve; Warlord, Colossus no change). Then: **"These boss design mechanics are way too average I will design them myself and give you the brief for the new fights"** → the lead's Q13 ideas are dropped; the owner writes the brief for the other bosses' fights. Asked whether that replaces Q9–Q11: **"Q9–Q11 stand"** (Gatekeeper pillars, Lantern light/dark, Twin phases go ahead as answered) | 2026-11-07 | PLAN L9, L10, O6–O8; BOSS_AUDIT |
| G1 SPELLS | Spell budget, auto-aim, all 15 rows approved | 2026-11-07 | SPELLS.md answers |
| G1 ENEMIES | All 5 critters, 10 new enemies and 5 variants approved | 2026-11-07 | ENEMIES.md answers |
| G1 PIERCE | List approved; P2 (flag a held Pierce the form doesn't use) | 2026-11-07 | PIERCE.md answers |
| G1 WISP_GAPS | "Wider still": lane ≥ hero + 0.7 m at 4 m; Bloom 2 and 3 to about 24 shots a wave | 2026-11-07 | WISP_GAPS.md answers |
| L-a | After O1 (one target −3.6 % vs the beam; a line 4.5×, Homing on a pack 5×): **"Falloff per enemy"**: each enemy after the first on a lance's path takes 15 % less than the one before, floor 40 % (starting values; lines ≈ 2.5×) | 2026-11-07 | PLAN L1, O1c |
| L-b | Hero speed while the Laser is held: **"Full speed"** (the beam's 75 % slow goes) | 2026-11-07 | PLAN L1, O1c |
| L-c | Homing's straight tail after the last target: **"Longer"**: it runs on to the first wall, not 9 m | 2026-11-07 | PLAN L2, O1c |
| L-d | After O1c the line is 3.3× the old beam (1662 vs 500), not the 2.5× the lead estimated: **"Keep 15 %"** | 2026-11-07 | PLAN O1c |
| Q10-b | O4 also removed the Lights Out telegraph shield (v0.10.5 O2a): **"Bring it back"** (O4b); all else in O4 stays | 2026-11-07 | PLAN L6, O4 |
| Q11-b | O5 removed Crossfire's shield: **"Keep removed"**. The resting twin (P1/P2) takes 0 with a "not now" spark: **approved**. Twins HP 2500 → 3000 (bots 79 s melee, 90 s ranged): **approved** | 2026-11-07 | PLAN L7, O5 |
| Q16-b | The surge probe missed 144 fps (120 critters ≈ 50 fps, 1 % low ≈ 32; under 144 from 60–80 alive; two other Godot test runs were going): **"Optimise, then cap"**: a performance step, re-measure on an idle PC, then cap at what holds 144. The critters' team ring: **"No ring on critters"** | 2026-11-07 | PLAN H1, O9b |
| Q16-c | After O9b (idle PC: 50 alive 157.1 / 155.4 fps; 120 alive 71.3 fps; cap set to 50): **"Batch now"**: build the batched critter path (no node per critter, reworked critter loops) in v0.11.0 and raise the cap to what holds 144 | 2026-11-07 | PLAN H1, O9c |
| G1 RUNIC_CLUES | Chain (each line hints the next feat); reward "Both" (the hidden room under the throne leads to a "remembered" Hollow Crown fight; its moves wait for the owner's boss brief); all 10 lines approved | 2026-11-07 | RUNIC_CLUES.md, PLAN O14 |
| E5-b | O12 missed (4-spell builds +33.2 / +36.3 / +37.1 %, one +56.8 %; band +40…+80 %): **"Count wand only"**: measure against the wand without its element card's damage, add moving and dying enemies, re-check the same bands before any tuning (O12b). Leech: **"Keep the rule"** (drains bleeding enemies only) | 2026-11-07 | PLAN E5, O12b |
| E5-c | O12b (wand alone, moving + dying scenes): the four 4-spell builds +60.2 / +56.3 / +54.7 / +66.7 % (in band); misses: Frost Nova 22.1, Burning Ground 22.7, Static Field 21.8, Blood Thorns 22.7 % (band 10–20); Lv 5/Lv 1 Venom Orb 3.22, Toxic Cloud 3.70, Ice Lances 1.9994 (band 2.0–3.0): **"Accept as is"**. Laser/Glaive builds +27…36 %, Blade +52…101 %: **"Leave it"** | 2026-11-07 | PLAN E5, O12 |
| G2 ROOMS | Purposes: **Camp, Collapsed hall, Quarry** (all three); method **authored templates with seeded variation** approved; the missing pieces **added to the art list** (OWNER_TODO §3.6) | 2026-11-07 | G2_ROOMS.md, PLAN O15 |
| G2 ROOMS-b | Collapsed hall: "The hall ruins have the pillars way too organized, can we shape them kinda in a way as Stonehenge, not exactly like that but the vibe": a loose ring/horseshoe of standing stones around the focal ruin, irregular gaps, leans, some lintels, some fallen, a few outliers (seeded); passed to O15 | 2026-11-07 | G2_ROOMS.md, O15 |
| MX-1 | Matchups with 34 enemy kinds (`test_the_matrix_is_intransitive` failing since O9/O13a: Wave the weakness of 10 kinds, Void nobody's): **"Spread them out"**: re-pick the new kinds' weak/resist so every Gun form is the weakness of a similar number (≈ 3–6) and none dominates; the test's bounds scaled to 34 kinds | 2026-11-08 | PLAN M2, O13 |

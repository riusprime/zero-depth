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

## I. The v0.10.5 checklist

**Q27.** The brief doesn't answer the v0.10.5 PLAYTEST rows (hub gaps, see-through fade, pools, Lance charge, Foundry
and Hive Lens fixes, loops, Astral UI, performance, enemy shadows). (a) **rec:** treat the ones you didn't mention as
OK; (b) you'll go through them.

## Answers (owner)

| # | Answer | Date | Recorded in |
|---|---|---|---|
| Q1 | "Everything in v0.11.0" | 2026-11-07 | PLAN Context (scope) |
| Q3 | "Longer hidden telegraph but remove the smoke, leave just the 'explosion' effect that we currently have" → (b): volley 2 stays hidden until volley 1 lands, then shows for 1.2 s; the pack Smoke goes, the explosion stays | 2026-11-07 | PLAN S3 |
| Q17 | "Hold the element card, if you chose that element as a rune in the wardrobe these cards also have a higher chance of appearing" → (a) plus: the element worn as the Wardrobe's rune affinity raises its spell cards' offer weight | 2026-11-07 | PLAN E1, O10 |
| Q24 | "I think I meant the rune that is at the hub": the **Runic Stone** (v0.9.5 RS1/RS2). Clarified in chat; see Q25 | 2026-11-07 | PLAN R1 |

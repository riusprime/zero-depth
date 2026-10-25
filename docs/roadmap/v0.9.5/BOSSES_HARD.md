# v0.9.5 G1: harder bosses, the Tidecaller and the Hollow Crown (BOSSES_HARD)

**Owner (2026-10-25, line 2):** "Bosses should not have stagger they should be hard, we should apply in some kind the
scaling of HP with the power before they spawn, so this scaling will be calculated when the boss door opens … we have
to modify 1 spell for each that will be hard to dodge, bosses should feel like a challeng not just a step you go
through … its a capped scaling so not every boss feels exactly the same HP. tidescaller tides shouuld be stronger and
keep the ball patter all times, we should add spawning waves crossing the room, small like 2-4 meters that the player
has to dodge during all fight"

**Owner (line 3, the Hollow Crown):**
- Phase 1: "speeding up a bit some of the attacks."
- Phase 2: "the small balls pattern feels great but we need just a little bit more spacing … only dodgeable from the
  edge of the room, and we should open just a bit the hitting window, when lasers it is still unhittable."
- Phase 3: "interphases … he dissapears and then he makes different kind of patterns, with rays, balls, and thing that
  come out of the ground that make you dodge for about 15 seconds, this should feel like a 6/10 difficulty … I liked
  the darkness ability of the newer boss so we could also reuse that … the fight should be more dynamic and fun."

**How to answer:** row by row. Rows H0–H2 are rules for every boss. Rows B1–B10 are one hard spell per boss. T and
HC are the two fights the owner named. Numbers are starting values, checked in the dodge labs
(`test_e2e_boss_dodge*.gd`) and by the owner's play.

## Rules for every boss
| ID | Today | Proposal |
|---|---|---|
| H0 | **Stagger:** direct damage fills a meter (`boss_ai.gd:703-728`); when full, the boss stops for 2.5 s and its attack is cancelled. The meter doesn't grow with HP, so strong builds stagger-lock bosses | **No stagger for any boss**, finals included. The meter, the STAGGERED state and the stagger bar go. The weak point (Warlord, …) still drops armour; it just no longer adds stagger |
| H1 | **The core steal** (`core_theft.gd:130-140`): a boss's core can be stolen only while it is staggered | The steal window opens for 3 s at each phase change instead: the boss kneels for 1.0 s as the phase turns, and that kneel is the only pause left in a fight (Q3) |
| H2 | **HP from your power:** `CatchUp.on_boss` reads the build's power P when the boss *spawns* (`world.gd:1086`). HP × m, with m = √(P / expected), held between ×1 and a cap of ×2 / ×3 / ×4 (floors 1, 2, 3+), plus 0.25 per Threat and 0.5 per loop | **Read at the door:** P is read when the boss door starts to open, and held. **Cap by floor:** ×2.5 / ×3.0 / ×3.5 / ×4.0 / ×4.5 for floors 1–5. **A spread:** each boss draws ±8 % from the floor's seed, so two runs never meet the same HP. A strong build still kills faster than a weak one (the √ curve), and the cap keeps a very strong build from turning the fight into a wall (Q2) |

## One hard spell per boss
"Hard" here means it takes a read and a well-timed dash, not that it does more damage.
- **Telegraph:** at least 0.55 s.
- **Damage:** unchanged.
- **Position:** every spell keeps one safe answer that isn't the room's edge.

| ID | Boss | Spell | Change |
|---|---|---|---|
| B1 | Gatekeeper | Shock Lanes | Telegraph 0.8 → 0.55 s; in phases 2–3 a second set of lanes fires 0.4 s later, offset half a lane, so the safe lane moves |
| B2 | Warlord | Javelin Fan | Aimed where you are going (it leads your velocity by 0.35 s), then a second fan 0.3 s later at where you are |
| B3 | Brood Mother | Leap Chain | 3 leaps, the last aimed ahead of your movement; landing ring +20 % radius |
| B4 | Hive Lens | Focus Beam | The beam tracks you at 40 °/s while it burns (today it is fixed), so you circle it instead of stepping aside |
| B5 | Siege Engine | Mortar Grid | Only 2 safe cells, and they swap once halfway through the volley (the swap telegraphed 0.6 s) |
| B6 | Foundry | Furnace Waves | Waves come from two walls at right angles, so the crossing point is the trap |
| B7 | Tidecaller | (rebuilt, see T) | |
| B8 | Twin Wardens | Crossfire | The two bodies aim so their lines cross on you; the crossing point follows you for 1.2 s, then fires |
| B9 | Clockwork Judge | Gear Spiral | From phase 2, two spirals turn in opposite directions (today one) |
| B10 | Lantern Shade | Lights Out | Lanterns burn 6 → 4 s; darkness lasts 8 → 9 s; Snuff puts out the 2 nearest lanterns |

## T: the Tidecaller (stronger tides, balls all fight, crossing waves)
| ID | Today | Proposal |
|---|---|---|
| T1 | **The Pull** every 9 s: pull 1.2 m/s for 3 s, then push 1.0 m/s for 2 s (phase 3: 1.5 / 1.2); drift capped at 1.5 m/s | Pull 1.2 → 1.7 m/s, push 1.0 → 1.4 m/s (phase 3: 2.0 / 1.7); drift cap 1.5 → 2.2 m/s; every 8 s |
| T2 | **Tide Rings** are an attack in the rotation (3 rings of 16, 3.2 m/s, two gaps) | **Rings all fight:** a ring of bubbles leaves the Tidecaller every 2.2 s for the whole fight (16 per ring, 2 gaps of 3, 3.0 m/s, turning 20° a ring), on top of its other attacks. Phase 2: every 1.9 s; phase 3: every 1.6 s, alternating gaps |
| T3 | — | **Crossing waves, all fight:** every 3.5 s a short water wave (3 m long; 2 m, 3 m or 4 m, drawn per wave) forms at one wall, telegraphed 0.7 s as a foam line, then crosses the room at 4.5 m/s (15 damage and a 1.5 m shove). From phase 2 two waves at once, from opposite or adjacent walls. They never form on the hero's side within 3 m |
| T4 | Undertow and Shell Slam | Unchanged |

## HC: the Hollow Crown (the final fight)
| ID | Phase | Today | Proposal |
|---|---|---|---|
| HC1 | 1 Colossus | Fist Combo at 5.5 m/s; Leap Slam (24-stone ring at 6.5 m/s); Boulder Throw (8 lobbed at 4.2 m/s) | Fist Combo 5.5 → 6.5 m/s; Leap Slam telegraph −25 % and ring 6.5 → 7.5 m/s; Boulder Throw 4.2 → 5.2 m/s. Spike Chase unchanged |
| HC2 | 2 Prism, balls | Crown Ring 32 per ring with 4 gaps of width 2; Flower 64 per wave; Spiral 10 arms | Crown Ring 32 → 28 and gaps 2 → 3 wide; Flower 64 → 52; Spiral 10 → 8 arms. Dodgeable from the middle third of the room. The dodge lab asserts a safe path exists that never goes within 3 m of the wall |
| HC3 | 2 Prism, hit window | She can be hurt only in the last 2.5 s of each Cross (laser) cast | Window 2.5 → 3.5 s, and she can also be hurt for 2.0 s after each ball pattern ends. Still unhittable while the lasers spin |
| HC4 | 3 The Fallen | It mimics your build in timed windows | **Two interphases**, at 66 % and 33 % of phase 3's HP (HC5) |
| HC5 | 3, interphase | — | He vanishes in a burst of violet runes and can't be targeted. For **15 s** the arena runs one pattern set, drawn without repeats: **(a) Rays:** 3 slow rotating beams from the centre, plus ground eruptions under you every 2 s (0.8 s telegraph, 1.4 m). **(b) Rain:** ball rings from 4 points on the edge, alternating, plus lines of ground spikes walking across the arena. **(c) Lights Out:** the Lantern Shade's darkness with 4 lanterns, slow drifting balls you can only see near light, and eruptions that only glow when lit. Then he slams back down in the centre (1.0 s telegraph) and the fight goes on. **Difficulty 6/10:** 15 damage per hit, every telegraph ≥ 0.8 s, always one gap ≥ 1.6 m, no instant-death stacking |
| HC6 | 3, between | He mimics, then waits | More movement: he dashes to a new spot between every two moves (0.4 s telegraph), and the mimic windows are 20 % shorter |
| HC7 | All | The final fight is paced by your DPS (time 120 s × √(30 / dps), held to 60–180 s) | Unchanged here. The loop ease is Q11 |

## How it is built (once approved)
- **Steps:**
  1. **H0–H2** (sim + tests): stagger removed, the core window moved, HP read at the door.
  2. **B1–B10**, two bosses per step.
  3. **T1–T3**, the Tidecaller.
  4. **HC1–HC3.**
  5. **HC4–HC6**, the interphase, with its own e2e.
- **Tests:** the boss tests and the dodge labs per boss; `test_final_pace.gd` (already red by the owner's
  acceptance) is re-measured, not widened.
- **Goldens:** no golden holds boss HP (audit), so none should move.

## Decisions (owner, date)
| ID | Answer | Built in |
|---|---|---|
| | | |

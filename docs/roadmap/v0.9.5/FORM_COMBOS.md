# v0.9.5 G1: what every card does on every attack form (FORM_COMBOS)

**Owner (2026-10-25, G1):** "we have almost all combinations disbled for new attack forms, we should have more fun
interactions … not every modifier works with every form so some will not be compatible but for example homing + laser
would make the laser follow the neares enemy making a smooth curve, and with pierce it would make a smooth curve trying
to hit the closest 5 enemies … help me go with questions through all of them."
**Owner (G2):** "The shotgun form, the scatter has to go, we are gonna be replacing it with rune explosion, a violet
explosion that comes out of the player as an energy kind like shield that grown, just like a mage from world of
warcraft."

**How to answer:** row by row, e.g. "L1 yes, L4 yes, B5 no, R3 with change …". Nothing here is built before the
answers. "All yes" for a form is fine too.

## Today (live code)
- The table is `forms` in `data/wand/attack_slots.tres` (`AttackFormRow.allowed`; anything not listed is off).
- **Orbs** (the Pulse Gun's plain shot) allow all 16 pattern and secondary cards. The other 9 forms allow only Twin
  (and Backfire on Scatter and Wave, Swirl on Glaive, Pierce on Laser). That is **10 of 144 cells on**.
- Every form allows all five elements. Elements are a separate G1: [`ELEMENTS.md`](ELEMENTS.md).
- Threadline (marked †) stays: Q16 found "double trail" was Double Exposure. It is off on every form but the Orbs, as
  proposed.

The 16 cards, as they read today:
- Twin: fire twice side by side.
- Halo: fire in a full ring.
- Ring: the shot becomes a lightning ring.
- Backfire: also fire behind.
- Pierce: pass through enemies.
- Ricochet: bounce off walls.
- Homing: curve toward enemies.
- Echo: fire again a moment later.
- Big Shot: bigger and slower, more damage.
- Rapid Fire: smaller and faster.
- Split: split on hit.
- Mine: stop and wait as a mine.
- Orbit: circle you before flying out.
- Threadline†: shots fired close together are linked by a cutting thread.
- Spiral: corkscrew.
- Swirl: swirl at random.

**Proposal rule:** a card is on for a form when it changes how that form *moves or lands* in a way you can see. It is
off when it would be invisible, or the same as another card on that form. Every number below is a starting value.

---

## Rune Explosion (replaces Scatter; G2)
**R0. The form.** A violet rune shield bursts out of the hero and grows from 0 to 3.5 m in 0.35 s. Each enemy is hit
once as the edge passes it. Damage ×3.0 orb. Every 1.1 s. A 0.4 m shove outward. No heat (Q12).
- It feels like the WoW mage's Arcane Explosion: the hero stands in it, and enemies around them pop.
- Single-target damage is about 0.55× the orbs; a pack takes about 3× (Scatter's place on the DPS sheet, between
  Bomb and Void).
- Scatter Blast, the Gun's **Skill**, is a different thing and stays (Q9).
- Scatter is retired through `migration.tres`, so an old save holding Scatter gets Rune Explosion.

| ID | Card | Proposal on Rune Explosion |
|---|---|---|
| R1 | Twin | A second, smaller shield (70 %) 0.2 s after the first |
| — | Halo | Off (it is already a circle) |
| R2 | Ring | The edge leaves a lightning ring that holds at full size for 0.8 s, hitting once more |
| — | Backfire | Off (no front or back) |
| — | Pierce | Off (it already hits everything) |
| R3 | Ricochet | The shield rebounds off walls: when it reaches full size it shrinks back in, hitting again at 50 % |
| R4 | Homing | The burst is cast on the nearest enemy within 6 m instead of on you (on you if none) |
| R5 | Echo | A rune glyph stays on the floor where it burst and bursts again 0.6 s later at 60 % |
| R6 | Big Shot | 5 m radius, +60 % damage, every 1.5 s |
| R7 | Rapid Fire | 2.5 m radius, −30 % damage, every 0.7 s |
| R8 | Split | Each enemy hit throws 2 small rune shards outward (25 %, 4 m) |
| R9 | Mine | Leaves a rune trap where it burst; the next enemy to step on it within 4 s sets off a 2 m burst |
| — | Orbit, Spiral, Swirl, Threadline† | Off |

## Laser (hold to burn a beam, 9 m)
| ID | Card | Proposal on Laser |
|---|---|---|
| ✔ | Twin | (on today) Two beams side by side |
| L1 | Halo | A prism tip: where the beam ends, it fans 3 short beams (3 m, ±30°) at 40 % |
| L2 | Ring | A 1.4 m lightning ring rides the beam's tip and pulses every tick |
| L3 | Backfire | A half-length beam behind you |
| ✔ | Pierce | (on today) The beam goes through enemies |
| L4 | Homing | **The owner's combo.** The beam bends in a smooth curve to the nearest enemy within reach (it turns at 120°/s, so it lags and sweeps). **With Pierce:** the curve threads up to the 5 closest enemies, nearest first, as one smooth spline |
| L5 | Ricochet | The beam reflects off walls once and continues to its full reach |
| L6 | Echo | Where the beam swept glows and strikes again 0.4 s later at 50 % |
| L7 | Big Shot | Twice as wide, +60 % damage, turns 30 % slower |
| L8 | Rapid Fire | The tick quickens from 0.1 s to 0.05 s over 2 s of holding; thinner beam |
| L9 | Split | At the first enemy hit, the beam forks into 2 beams at ±25° (4 m) |
| L10 | Mine | Every 1.0 s the tip drops a mine (1.5 m burst when an enemy steps on it; at most 4) |
| L11 | Spiral | The beam wiggles side to side (±12°, 2 times a second), covering a band |
| — | Orbit, Swirl, Threadline† | Off |

## Bomb (lobbed, 2.2 m blast, every 1.0 s)
| ID | Card | Proposal on Bomb |
|---|---|---|
| ✔ | Twin | (on today) Two bombs |
| B1 | Halo | Four bombs land in a cross 3 m around you |
| B2 | Ring | The blast leaves a lightning ring growing to 3.5 m |
| B3 | Backfire | A second bomb drops at your feet with a 0.5 s fuse |
| — | Pierce | Off (it never touches enemies in flight) |
| B4 | Ricochet | The bomb skips once off the floor or a wall and bursts further on |
| B5 | Homing | The bomb lands on the nearest enemy within 3 m of the aim point |
| B6 | Echo | The blast goes off again 0.5 s later at 50 % |
| B7 | Big Shot | 3.3 m blast, +60 % damage, slower throw |
| B8 | Rapid Fire | 1.6 m blasts every 0.6 s |
| B9 | Split | A cluster bomb: the blast throws 3 bomblets 2 m out (40 % each) |
| B10 | Mine | The bomb sits as a proximity mine until an enemy comes within 1.5 m (at most 5 waiting) |
| — | Orbit, Spiral, Swirl, Threadline† | Off |

## Void (a slow black hole that pulls and ticks)
| ID | Card | Proposal on Void |
|---|---|---|
| ✔ | Twin | (on today) Two voids |
| — | Halo | Off (a ring of black holes is too strong; Orbit covers "around you") |
| V1 | Ring | When the void ends, it collapses in a 3 m lightning ring |
| V2 | Backfire | A second void behind you |
| — | Pierce | Off (it already passes through) |
| V3 | Ricochet | Bounces off walls and keeps drifting (life unchanged) |
| V4 | Homing | Drifts toward the densest group within 6 m |
| V5 | Echo | A second, smaller void opens where the first ended (60 %, half the life) |
| V6 | Big Shot | 1.6 m aura, pulls from 4.5 m, slower |
| V7 | Rapid Fire | Smaller, faster voids, half the life, every 0.4 s |
| V8 | Split | When it ends, it splits into 3 mini voids (1.0 s each) |
| V9 | Mine | The void stops at the aim point and holds there for 3 s (a trap) |
| V10 | Orbit | The void circles you once (2.5 m) before flying out |
| — | Spiral, Swirl, Threadline† | Off |

## Lance (hold to charge, pierces all)
| ID | Card | Proposal on Lance |
|---|---|---|
| ✔ | Twin | (on today) Two lances |
| N1 | Halo | A full charge fires 6 lances around you at 50 % each (a tap fires one) |
| N2 | Ring | A lightning ring bursts where the lance ends (2 m) |
| N3 | Backfire | Also fires a lance behind you at 50 % |
| — | Pierce | Off (it already pierces everything) |
| N4 | Ricochet | A full charge bounces off one wall and keeps going |
| N5 | Homing | The lance bends gently toward the nearest enemy ahead (60°/s) |
| N6 | Echo | A ghost lance repeats the same line 0.4 s later at 50 % |
| N7 | Big Shot | Twice as wide, +60 % damage, +0.3 s to charge |
| N8 | Rapid Fire | Charges 40 % faster, −30 % damage |
| N9 | Split | Every enemy it pierces spits 2 shards sideways (25 %, 3 m) |
| — | Mine, Orbit, Spiral, Swirl, Threadline† | Off |

## Glaive (a disc that flies out and back)
| ID | Card | Proposal on Glaive |
|---|---|---|
| ✔ | Twin | (on today) Two discs |
| G1 | Halo | Four discs fly out in a cross and come back |
| G2 | Ring | The disc carries a 1 m lightning ring around itself |
| G3 | Backfire | A second disc thrown behind you |
| — | Pierce | Off (it already cuts through) |
| G4 | Ricochet | It bounces off walls (2 bounces) before it turns home |
| G5 | Homing | It curves to an enemy on the way out and to another on the way back |
| G6 | Echo | A second disc follows the same path 0.3 s later at 50 % |
| G7 | Big Shot | A bigger, slower disc, +60 % damage |
| G8 | Rapid Fire | A smaller, faster disc every 0.45 s |
| G9 | Split | On its first hit it sheds 2 small discs that fly on (30 %) |
| G10 | Mine | At its far point it stops and spins in place for 1.2 s before coming back |
| G11 | Orbit | It circles you once (2.5 m) before flying out |
| ✔ | Swirl | (on today) |
| — | Spiral, Threadline† | Off |

## Seekers (3 darts that curve to the nearest foes)
| ID | Card | Proposal on Seekers |
|---|---|---|
| S1 | Twin | 6 darts at 60 % each |
| S2 | Halo | The darts leave in all directions first, then turn to their targets |
| S3 | Ring | Each dart's hit makes a small lightning ring (1 m) |
| — | Backfire | Off (they seek anyway) |
| S4 | Pierce | A dart goes through its target and seeks the next one (up to 2 more) |
| S5 | Ricochet | Darts bounce off walls and keep seeking |
| — | Homing | Off (they already home) |
| S6 | Echo | A second volley 0.3 s later at 50 % |
| S7 | Big Shot | 2 big darts, +100 % damage each |
| S8 | Rapid Fire | 5 small darts, −35 % damage each |
| S9 | Split | On a hit, a dart splits into 2 that seek other enemies (35 %) |
| S10 | Mine | Darts hang in the air for 0.6 s, then dive at their targets together |
| S11 | Orbit | Darts circle you once before launching |
| — | Spiral, Swirl, Threadline† | Off |

## Wave (a wide slow wave that rolls through everything)
| ID | Card | Proposal on Wave |
|---|---|---|
| ✔ | Twin | (on today) Two waves |
| — | Halo | Off (a ring wave is Rune Explosion's job) |
| — | Ring | Off |
| ✔ | Backfire | (on today) |
| — | Pierce | Off (it already rolls through) |
| W1 | Ricochet | The wave reflects off one wall and rolls back |
| W2 | Homing | The wave bends toward the biggest group in front |
| W3 | Echo | A second wave 0.4 s later at 50 % |
| W4 | Big Shot | 5 m wide, +60 % damage, slower |
| W5 | Rapid Fire | 2 m wide, every 0.55 s |
| W6 | Split | At the end of its run it splits into 2 waves at ±45° (3 m further) |
| W7 | Mine | The wave stops 4 m out and churns in place for 1.5 s |
| W8 | Spiral | The wave snakes left and right as it rolls |
| — | Orbit, Swirl, Threadline† | Off |

## Wisps (three wisps circle you and fire at the nearest foe)
The wisps' shots are small projectiles, so most projectile cards act **on the wisps' shots**, exactly as on the Orbs.
(The wisps' damage is Q13.)

| ID | Card | Proposal on Wisps |
|---|---|---|
| P1 | Twin | A fourth wisp |
| P2 | Halo | 6 wisps at 60 % damage each |
| P3 | Ring | The wisps' shots become small lightning rings |
| — | Backfire | Off |
| P4 | Pierce, Ricochet, Homing, Echo, Big Shot, Rapid Fire, Split, Spiral | Act on the wisps' shots, as on the Orbs (one row: yes or no for all eight) |
| P5 | Mine | Each wisp drops a mine every 2 s instead of every third shot |
| P6 | Orbit | The wisps circle wider (3.5 m) and also hurt enemies they touch (50 %) |
| — | Swirl, Threadline† | Off |

## Orbs (the plain shot)
Every card stays on, as today. No change proposed.

---

## How it is built (once approved)
- **Data:** each new cell is a row in `attack_slots.tres`, plus a small per-form handler in the form's sim file
  (`laser.gd`, `bomb.gd`, …). There is one handler per (form, card) pair approved here.
- **Order:** one step per form, so each one is testable on its own. Laser first, as the owner's example.
- **Tests per step:**
  - a unit test per cell (the behaviour and its numbers);
  - the 40-shots-a-second cap;
  - the form's e2e test with two approved cards.
- **VFX:** existing looks are reused, tinted by the form (the ring, mines, shards). Rune Explosion gets its own
  shader: a violet rune disc with a bright edge.

## Decisions (owner, date)
| ID | Answer | Built in |
|---|---|---|
| R0–R9, L1–L11, B1–B10, V1–V10, N1–N9, G1–G11, S1–S11, W1–W8, P1–P6 | Approved as written (owner, 2026-10-25, in chat) | |

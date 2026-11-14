# Boss brief: fights with mechanics you learn (owner, 2026-11-14)

**Status: DRAFT for the owner. Nothing here is built.** This is the boss brief v0.11.0 was waiting for
([`PLAN.md`](PLAN.md) O6–O8, [`OWNER_QUESTIONS.md`](OWNER_QUESTIONS.md) Q13: "I will design them myself and give you
the brief for the new fights"). The owner spoke it as a feedback session; the words are kept in
[`feedback/ZeroDepth_Boss_Brief_2026-11-14.md`](feedback/ZeroDepth_Boss_Brief_2026-11-14.md).

How to answer: each proposal row has an ID (`CJ2`, `TW5` …). Say "CJ2 yes, TW5 no, TC3 with this change …", and
answer the questions in §6 (`BQ1` …). Rows marked **Owner** are the owner's own design, written down; rows marked
**Lead** are the lead's proposals for the parts the owner asked for help with. Every number is a starting value.

## 1. The style (the owner's rules for every boss)

| # | Owner line | What it means for the work |
|---|---|---|
| B1 | "since each boss has 3 health bars and 3 faces, to have more like a World of Warcraft kind of fight with the different mechanics that involved doing something in exchange of something, or doing something so you don't receive damage, as we did with the pillars and the earthquake with the rock boss" | Each phase of each boss teaches one mechanic of the form "do X to get Y" or "do X or be hurt". The Gatekeeper's quake pillars are the model |
| B2 | "I want all bosses to have things that restrict the area where you could walk through … things falling, venom pool, pulse area, or whatever thing the boss summons" | Every reworked boss denies floor. **This changes an earlier answer** (RQ3, 2026-11-09: no hazards on the Tidecaller, Judge, Twins or Hollow Crown): see BQ2 |
| B3 | "The idea is not to make them very difficult … have the player die sometime at them … you would have to die maybe once … not like Hades 2 … you don't have to try 40 tries" | The target: a first meeting is usually lost or close; the fight is won once the mechanics are known. A mechanic you ignore hurts steadily, it does not kill at once (the owner's soak: "not the idea to kill you instantly") |
| B4 | "They don't need to repeat mechanics and be based on what I said. These are just a fighting reference style" | The lead's proposals for the other bosses use different mechanics from the three the owner designed |
| B5 | "I need you to help me rework the other ones too" | §4 and §5 |
| B6 | "The rock boss is okay. The broad mother is also okay for now, and … the hive boss that has laser and stuff is kind of okay, but we have to go a little bit over it" | Gatekeeper: no change. Brood Mother: no change. Hive Lens: a light pass (§4) |
| B7 | "Phase 1 and 2 of the Hollow Crown are already pretty neat … we have to rethink how phase 3 works" | Colossus and Prism: no change. The Fallen (the third body): §5 |

The Lantern Shade was not mentioned. It was reworked in v0.11.0 (light and dark). Read as: no change (BQ1).

## 2. How the bosses fight today (live code, 2026-11-14, `e53b3e15`)

Shared rules (`src/sim/ai/boss_ai.gd`, `boss_gates.gd`, `boss_challenge.gd`): three bars at 100 / 66 / 33 % of one
HP pool; at each gate the boss kneels 1 s and 2–4 adds spawn; shots from far away do less (100 % up to 5 m, 40 % at
12 m); staying beyond 9 m for 4 s draws a punish attack. Every boss room is 4×4 cells, the largest size.

| Boss | Floor | The fight today | Named in this brief |
|---|---|---|---|
| Gatekeeper | 1 | Stone melee; from phase 2, three quake pillars you shatter with its own Shock Lanes to stun it (`gatekeeper.tres:291`, `boss_quake.gd`) | No change |
| Warlord | 1 | A front shield that blocks everything; javelins that fly back; a great javelin that embeds and quakes; a 20 m/s charge after a 1.0 s wind-up, nothing happens where it ends (`warlord.tres:195`) | Its charge is the owner's example of "too predictable and too slow" |
| Brood Mother | 1, 2 | Leaps, burrows, eggs, hatchlings, venom pools | No change |
| Hive Lens | 2 | Bullet spirals; a turning 12 s gaze beam; focus beams; three drones from phase 2 | Light pass |
| Siege Engine | 3 | Artillery that stops moving in phase 2; mortar grid with safe cells; turrets; falling rocks that leave slow zones; a room-wide shockwave you avoid by hugging it | Lead proposal |
| Foundry | 3 | Molten lanes that leave lava; pools; bomb drones; a phase-3 meltdown that shrinks the room | Lead proposal |
| Tidecaller | 4 | The Pull every 8 s: 3 s in at 1.7 m/s, 2 s out at 1.4 m/s (`tidecaller.tres:7`, `boss_tide.gd:121`); a stream of bubble rings; waves that cross the room | **Owner's design** |
| Twin Wardens | 4 | Two bodies, one HP pool. Amber (physical) leads phase 1 while violet rests, immune, firing one bolt every 4 s; they swap in phase 2; both in phase 3. A burning chain joins them (`boss_twin.gd:551`); Crossfire's safe spot and Chain Sweep's length are computed from it | **Owner's design** |
| Clockwork Judge | 5 | The Echo strikes the path you walked in the last 3 s; a Verdict square; gear spirals; a gavel ring. The simplest boss (4 things to read) | **Owner's design** |
| Lantern Shade | 5 | Dark and light; relight lanterns to deal 150 % | No change (BQ1) |
| Hollow Crown | final | Three bodies: Colossus, Prism, The Fallen. The Fallen copies your weapon and cards in 5.6 s windows every 20 s, and at 66 % and 33 % vanishes for 15 s while the room attacks you (`boss_nemesis.gd`, `boss_interphase.gd`) | Third body: lead proposal |

What the sim has and lacks for this brief:

| Piece | Today |
|---|---|
| Disc hazards with a cap, lava lanes, a shrinking ring | Yes (`boss_hazard.gd`, `boss_lava.gd`) |
| Walls raised and removed mid-fight | Yes (`World.add_barrier`, the Gatekeeper's pillars). They stop the player, ground bosses and both sides' shots |
| Pull, push, shove | Yes (`BossTide.shift`) |
| Hint arrows | Yes (`ObjectiveMarkers`) |
| A debuff on the player's attack speed that a pickup removes | **No.** Only the run-long curse. New |
| Things on the floor you walk over to collect | **No** (the Shade's lanterns are the nearest thing). New |
| Zones that slow the player's shots | **No.** Possible in the script step that steers shots before the C++ sweep (`native_shots.gd:30`), so no C++ change is expected. A shot lives a fixed time, so a slowed shot also falls short (BQ6) |
| A shield that sends the player's shots back | **No.** New, and it touches the shot sweep: read `NATIVE_CORE.md` first |
| One boss body hurting the other | **No.** New (the Twins' phase 3) |
| "Stand here or be hurt" | **No** general check. New (the Tidecaller's strips and soak; reusable) |
| The pack effect "Basic Area VFX 04" | In the project (`assets/BinbunVFX/magic_areas/effects/basic_area/basic_area_vfx_04.tscn`), not registered in `data/vfx` yet |

## 3. The owner's three bosses

### 3.1 Clockwork Judge: time (floor 5)

Owner: "things related with time: echoes, rewind, time stop, speed up, time travel, projectile slowdown".

| ID | Owner line | Proposal | By |
|---|---|---|---|
| CJ1 | "He does an animation of a cast, and then a wave, golden wave that comes out of him, hits you undodgeable, and it slows down your attack speed by 75%" | **Time Wave.** A 1.5 s cast, then a golden ring crosses the whole room. It cannot be dodged or dashed through and deals no damage. Your attack speed drops by 75 % until you recover it | Owner |
| CJ2 | "there are 3 orbs that appear in the map in the room, and you have to pick them up to regain your attack speed, and each one gives you back 20% … the VFX … Basic Area VFX 04 … a little clock on top of it" | **Three hour orbs** appear with the wave, spread apart. Walking through one returns part of the lost speed. Each is Basic Area VFX 04 with a small clock above it, and a hint arrow the first two meetings. 3 × 20 % returns 60 of the 75 points: see **BQ4** | Owner |
| CJ3 | "we need a mechanic that makes it a little difficult for you to get to the attack speed zones sometimes … things that block the path, right? So you have to walk around" | **Stopped gears.** Before the orbs appear the Judge drops 3–4 gear walls (solid, about 5 m long, 12 s) between you and the orbs, so the straight line is closed. Lead's addition: the **Echo already punishes the path you just walked**, so running out for an orb and coming back the same way is the mistake. That keeps the Echo as the Judge's identity | Owner + Lead |
| CJ4 | "he would also spawn some areas where your attacks slow down, and he can actually dodge it … you shoot an attack, it goes through that zone, gets like frozen, not frozen, but moving really slow in time … he spawns these areas between the player and the boss" | **Slow fields.** From phase 2: discs about 3.5 m wide placed on the line between you and the Judge, 8 s each, at most 3. A player shot inside one moves at 20 % speed; the Judge steps aside from shots it can see crawling. You answer by moving until the line is clear, or by going in close. The Blade is not affected by the fields, so for a Blade build the gear walls and the orbs are the fight (BQ5) | Owner |
| CJ5 | "we play with the concept of time for this boss" | **Phases.** P1: Echo, Verdict, Gavel + Time Wave with 3 orbs in the open. P2: + slow fields, + stopped gears on the way to the orbs. P3 (Lead): the orbs **run down like a clock** (each lasts 10 s; one you miss is gone until the next wave), and the Judge **rewinds once**: at 15 % of the bar it returns to where it stood 5 s ago and recovers a small part of that bar (5 %) unless you are within 4 m of it, so the phase ends in close | Owner + Lead |

### 3.2 Twin Wardens: two separate fighters (floor 4)

| ID | Owner line | Proposal | By |
|---|---|---|---|
| TW1 | "we already have them connected in a way with line. I don't want that. I want them to be 2 separate entities" | **The chain is removed**: no line, no burn, no pulling each other along. Crossfire's safe gap and Chain Sweep, which are computed from the chain today, get their own rules (the gap faces away from the other twin; the sweep becomes a sword lane of fixed length). One HP pool or two: **BQ7** | Owner |
| TW2 | "the golden one, Ember … in phase 1, he will have an aggressive sword combo, charges, dashes, charged, attacks, and they will be fast" | **Amber, phase 1.** A 3-hit sword combo that steps forward on each hit; a short side dash between attacks; a charged overhead (long wind-up, large arc); the charge (TW3). Wind-ups shorter than today's 0.7–1.6 s. Needs the new clips | Owner |
| TW3 | "We have some charges right now … too predictable and too slow, so the player just has to walk. So for this attack, he should charge faster and exploding when reaching the end, so you should not be near the end of that charge" | **The charge.** Wind-up 1.0 → 0.6 s, the aim locks for only the last 0.3 s (today 0.8 s), speed 18 → 26 m/s. Where it ends, a 3.5 m burst after 0.25 s. The lane and the end circle are both drawn during the wind-up | Owner |
| TW4 | "the other one stays like charging, casting … with the immune shield, and he cannot take damage, and he will be shooting some purple attacks, not too much, not want to overcrowd" | **Violet, phase 1.** As today: immune under a visible shield, one bolt every 4 s. No change besides the shield's look | Owner |
| TW5 | "when you kill that first HP, we go into phase 2, and they swap … an ability that summons a shield that throw and bounce your projectiles back at you, and after the bounce they can hit you and deal damage" | **Violet, phase 2: Mirror Ward.** A 1.0 s cast, then 4 s in which a ward stands on the side facing you (a 160° arc). Your shots that hit it come back at you at their own speed, for a part of their damage (BQ8). Walk around it or hold fire. What a Blade swing does against it: BQ8 | Owner |
| TW6 | "He could do some shadowy swords, as he has a sword and magic sword attacks, and spawn things that you have to dodge like we have in other bosses" | **Violet, phase 2.** Shadow Swords: 5 blades appear in a fan around you, each shows its line for 0.8 s, then they cut inward one after another. Rune Ring and Blink stay. Lead's addition for B2: each sword that lands leaves a violet rift (a 1.5 m disc, 8 s, at most 5) | Owner + Lead |
| TW7 | "at the phase 3 … they both fight at the same time … the shielding goes all around the boss, and you have to aim the charge of the physical one into the boss to break it. And it should be an long enough charge so you can have time to aim it, but sometimes miss it because you don't get there in time" | **Phase 3: break the ward with the charge.** Violet stands under a full ward and takes nothing. Amber's charge in this phase is long (wind-up 1.4 s, aim locks for the last 0.5 s) and aims at you: stand so that Violet is on the line. A charge that hits Violet breaks the ward, stuns Violet 5 s (it takes 150 %) and staggers Amber 2 s. The ward returns 12 s later. Hint arrow on Violet while Amber winds up. This replaces today's "exposed twin swaps every 10 s" | Owner |
| TW8 | "we have the TAS and the blink, so those timings will have to be adjusted after playstyle" | The lock time and wind-up of TW3 and TW7 are tuned after the owner plays them. `OWNER ONLY` | Owner |

### 3.3 Tidecaller: the dance (floor 4)

| ID | Owner line | Proposal | By |
|---|---|---|---|
| TC1 | "pulls you and pushes you, and it's great, but it is really weak. It doesn't really move you. You can just walk around it … should be stronger" | **A pull you feel.** Today it adds 1.7 m/s in and 1.4 m/s out, capped at 2.2 m/s. Proposal: the pull is set as a share of your own run speed: 75 % in phases 1–2, 85 % in phase 3 (walking straight out barely gains ground; a dash still escapes it). The push throws you 6 m in the first 0.5 s rather than drifting you for 2 s. Shown before/after in the Playground for the owner to feel (`OWNER ONLY`) | Owner |
| TC2 | "these balls that go all around and try to hit you, and the waves moving" | The ring stream and the crossing waves stay | Owner |
| TC3 | "in phase 2 … the room is divided in 4 parallel strips, and he does like a cast where he does this 3 or 4 times, that 3 of them have a wave that's coming at you and hits you very hard, and you have to be in the zone of the room that doesn't have the wave" | **Riptide, phase 2.** The floor shows 4 strips along the room. Three fill with a warning for 2.0 s, then a wave runs down each: 35 % of your max HP. The dry strip is safe. 4 casts in a row, every 20 s | Owner |
| TC4 | "it does some easy ones, and last one that's far, for example, it goes the free space is 2, 3, then 1, and then the 4 strips. So they're the most separate, and you have to run all the way" | **The order is written, not random:** the first two safe strips are neighbours, the third is one strip away, the last is the far side of the room (2, 3, 1, 4 or its mirror). The last warning is 0.5 s longer because the run is the longest. The Pull does not run during Riptide in phase 2 | Owner |
| TC5 | "soaking style areas in phase 3 where the boss fills the room, starts casting, and you have a couple of seconds to get to a specific zone. If you are not inside that zone, you will take damage per second until you reach it. It's not the idea to kill you instantly" | **High Tide, phase 3.** A 2.5 s cast while the water rises; one dry circle (4 m) appears, at least 12 m from you. For 6 s, anyone outside it takes 6 % of max HP a second. Hint arrow to the circle. Lead's addition: the Pull is active during the cast, dragging you **away** from the circle in the last High Tide of the phase | Owner + Lead |
| TC6 | B2 (area denial on every boss) | Lead: each crossing wave leaves a **tide pool** where it breaks on the far wall (a 2 m slow disc, 10 s, at most 5). Only if BQ2 says the Tidecaller gets one | Lead |

## 4. The lead's proposals for the other bosses

On 2026-11-07 the owner called the lead's first ideas for these bosses "way too average". These are new, each built
on something the boss already does, each different from the three fights above. Approve, change or throw out row by
row.

| ID | Boss | Proposal | The trade it asks of you |
|---|---|---|---|
| WL1 | Warlord | **The faster charge** (TW3's numbers: 0.6 s wind-up, 26 m/s, a burst where it ends). The owner named this charge as too slow | Don't stand at the end of the lane |
| WL2 | Warlord | **War Banner, phase 2.** It plants a banner (a 6 m circle). Inside it the Warlord attacks 30 % faster **and you deal 40 % more**. The banner falls if its charge passes through it | Fight inside for a shorter, more dangerous fight, or pull the charge through it to end it |
| WL3 | Warlord | **Javelin Cage, phase 3.** A ring of javelins lands around you both (a 9 m circle; the shafts are solid, touching them hurts). 12 s of a duel with nowhere to back away, then the recall pulls every javelin through the centre | Stay near the edge for the recall, near the centre for the duel |
| SE1 | Siege Engine | **Target Lock, phase 2.** A painted circle follows you for 4 s, then a heavy shell lands. It leaves a crater wall (a solid boulder, 3 m, 30 s, at most 4). A shell that lands on a turret destroys it | You choose where the shell falls: on a turret, and where your cover will stand |
| SE2 | Siege Engine | **The Shockwave needs cover, phase 3.** Today you avoid it by hugging the boss. Proposal: it hits everything in sight of the Engine; stand behind a boulder. Each blast breaks the boulder that saved you | The boulders you placed in phase 2 are your lives in phase 3 |
| FO1 | Foundry | **Forged Plate, phase 2.** Every 20 s it forges a plate: 60 % less damage taken. Its own bomb drones chase you; a drone that explodes against the Foundry blows the plate off and leaves it exposed 5 s (125 %) | Don't kill the bombs: lead them back to the Foundry |
| FO2 | Foundry | **Cooling slag, phase 3.** A lava pool that has lasted 12 s cools into a dark slab for 8 s. During the meltdown's Overpressure cast (3 s) the open floor burns for 6 % max HP a second; a slab is safe | The pools you dodged become the places you stand on |
| HL1 | Hive Lens | **Drones feed it, phase 2.** While a drone lives a beam of light joins it to the Lens and the Lens takes 15 % less per drone. Drones can be shot, or **cut by the Lens's own Focus Beam** if you stand so a drone is on the line | Kill them slowly, or with its own beam |
| HL2 | Hive Lens | **Burnt glass, phase 3.** Where a Focus Beam ends it leaves a scorched strip (1 m wide, 6 s, at most 3) | The room is cut into pieces for a few seconds |
| — | Gatekeeper, Brood Mother, Lantern Shade | No change | — |

## 5. The Hollow Crown's third body (The Fallen)

Today: it copies your weapon and your three strongest cards in 5.6 s windows every 20 s (and lowers your damage
and speed to the base hero's in them), and at 66 % and 33 % it vanishes for 15 s while the room attacks you. The
owner has not yet said what is wrong with it (BQ9). Three directions; the lead recommends HC-A.

| ID | Direction | What the fight becomes |
|---|---|---|
| HC-A | **The Crown remembers your run** ← recommended | The two 15 s "boss is gone" breaks are replaced. At 66 % and 33 %, and every 25 s in between, the Fallen stays in the room and casts **one mechanic from a boss you killed this run**, in that boss's colours: the Judge's Time Wave and orbs, the Tidecaller's Riptide strips, the Gatekeeper's pillars, the Twins' ward (break it with the Fallen's own dash). The final boss is then the exam on what the run taught, and each run's exam is different. The copy windows stay |
| HC-B | **Take the crown back** | The crown breaks into 3 shards on the floor. While a shard lies there the Fallen is stronger (one of your cards, copied, per shard). Standing in a shard's circle for 4 s takes it back: you gain a short burst (+30 % damage, 10 s) and the Fallen loses that card. It defends the circles. No vanishing |
| HC-C | **Smallest change** | The fight as it is; the breaks 15 s → 8 s, and its copies can be hit during them (the lead's old Q13 row, deferred by the owner then) |

## 6. Questions

**BQ1. The Lantern Shade.** Not mentioned in the brief.
- (a) No change. ← recommended (reworked in v0.11.0)
- (b) It gets a pass too.

**BQ2. Area denial on every boss (B2) against your 2026-11-09 answer** ("none on the Gatekeeper, Hive Lens,
Tidecaller, Judge, Lantern Shade, Twins or Hollow Crown").
- (a) The new line wins for the bosses reworked here: Judge (gear walls, slow fields), Twins (rifts, TW6),
  Tidecaller (tide pools, TC6), Hive Lens (HL2). Gatekeeper and Lantern Shade stay without. ← recommended
- (b) Only where your own design asks for it (the Judge). The others stay without.

**BQ3. Where does this work go?**
- (a) It is v0.11.0's steps O6–O8, built on this branch after the v0.11.1 PR merges. ← recommended (it is the brief
  those steps waited for)
- (b) A new version, v0.12.0, after the v0.11 playtest.

**BQ4. The Time Wave's arithmetic.** −75 % and three orbs of +20 % leaves you 15 points short.
- (a) Each orb returns 25: all three bring you back to full. ← recommended (the clearest rule)
- (b) 20 each; the last 15 return by themselves 10 s after the wave.
- (c) 20 each; you stay 15 % slower until the next wave (which resets it to −75 %).

**BQ5. Time Wave and the Blade.** −75 % attack speed applies to the Blade's swings too, and to spells' cooldowns?
- (a) Weapon only (Gun shots, Blade swings, Laser). Auto-spells keep their pace. ← recommended
- (b) Everything, spells included.

**BQ6. A shot inside a slow field.** A shot lives a fixed time, so a slowed one may die inside the field.
- (a) The clock of a shot also slows inside the field: it crawls through and carries on at full speed. The Judge
  has that time to step aside. ← recommended (your "moving really slow in time")
- (b) The shot's life keeps running: most shots die inside the field. The field is a wall for shots unless you fire
  from close.

**BQ7. The Twins' health.**
- (a) One pool, three bars, as today: bar 1 is fought against Amber, bar 2 against Violet, bar 3 against both.
  "Two separate entities" means no chain and separate behaviour. ← recommended (it matches "when you kill that first
  HP, we go into phase 2")
- (b) Each twin has its own HP in phase 3; when one dies the other enrages.

**BQ8. The Mirror Ward.**
- Returned shots deal: (a) 50 % of their damage to you ← recommended (b) 100 % (c) a fixed 20.
- A Blade swing on the ward: (a) is blocked and pushes you back 2 m ← recommended (b) passes through (the ward only
  matters to shots) (c) hurts you.
- The Laser on the ward: (a) is blocked ← recommended (b) reflects along its own line.

**BQ9. What is wrong with The Fallen today?** One line is enough (too easy, too long, the vanishing, the copy
windows, nothing to learn …). Then HC-A, HC-B or HC-C, or your own.

**BQ10. Phase 1 on the first bosses.** The Warlord, Gatekeeper and Brood Mother are met on floor 1.
- (a) Floor-1 bosses keep a plain phase 1 and get their mechanic from phase 2. ← recommended (the first boss of a
  run stays readable)
- (b) A mechanic in every phase of every boss.

**BQ11. Order of building.** Each boss is one step, played by you before the next.
- (a) Clockwork Judge → Tidecaller → Twin Wardens → the Fallen → Warlord → Siege Engine → Foundry → Hive Lens.
  ← recommended (your three first; the Twins third because they need the new animations and the most new sim)
- (b) Your order.

## 7. How it would be built (after the answers)

1. **Shared pieces first, one step** (*sim + tests*): a player attack-speed debuff with a source and a remove rule;
   floor pickups; a "safe area or hurt" check (strips and circles); slow fields for player shots; a charge that
   bursts where it ends; one boss body hitting another. Each is data-driven so the next boss reuses it.
2. **One boss per step** (*sim + tests + sims*, then *presentation*): the fight, its hint arrows, its pack effects
   (PD-13), strings in en and es, the boss's e2e, one shot.
3. **Per boss, the same proof as v0.11.0:** two scripted bots, one that plays the mechanic and one that ignores it.
   The one that ignores it must lose clearly more HP, and must still not die at once (B3). Goldens that pin boss
   fights change on purpose and are named in PROGRESS.
4. **B3 ("die maybe once") is `OWNER ONLY`:** bots can show that a mechanic matters, not that the fight feels fair.
   Each boss step ends with the owner playing that boss from the dev panel.

Needed from the owner besides answers: the Twins' new animations (named in TW2), and a clock icon or model for the
hour orbs if the pack has none.

## Decisions (owner)

| ID | Answer | Date | Built in |
|---|---|---|---|
| — | — | — | — |

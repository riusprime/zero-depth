# v0.5.5 — Feedback pass: the owner's notes on the v0.4.0 + v0.5.0 build (plan, owner-directed 2026-10-08)

Recorded so no line of the owner's feedback depends on chat context. The owner's message is pasted verbatim in
[`../v0.5.0/PLAYTEST.md`](../v0.5.0/PLAYTEST.md) "Owner answers". Progress: [`PROGRESS.md`](PROGRESS.md).

## Context
- **Played:** the `main` build `8ce3de4` (v0.3.5 + v0.4.0 + v0.5.0, PR riusprime/zero-depth#1). This closes v0.4.0
  and v0.5.0 as played (ROADMAP §0.3 is met for v0.6.0 once this pass ships and is played).
- ROADMAP §4: "A `.5` pass takes priority whenever owner feedback arrives."
- **Headline:** the build is far too easy once it grows ("I was literally god after 1 run"). The owner wants a
  difficulty that follows the player's growth up to a cap, so only lucky, broken builds trivialise a floor (RoR2),
  plus a build space made of modifiers that merge attacks (Isaac).
- **Owner process rules (2026-10-08):**
  - "Spawn 3 agents parallel at max at the same time" (replaces the 4 of 2026-10-07).
  - "From now on not run bot tests, because they do not represent reality" (P1 below).
- Every number below is a **starting value** the owner tunes after playing.

## Every line of the feedback (2026-10-08)
Status: **Decided** (build it), **Proposed** (the lead's design, waiting for the owner's yes), **Discuss** (owner
asked to talk it through), **Kept** (no change wanted).

### Process
| # | Owner line (verbatim) | Decision | Status | Where |
|---|---|---|---|---|
| P1 | "From now on not run bot tests, because they do not represent reality" | Bot balance sims are no longer run or used as evidence: `scripts/sims/scorecard.gd`, the score-bot suite, and every test whose assertion is a balance band measured by bots (death rates, TTK, fight lengths, sim bands) leave the suite. Tests that drive a scripted input only to prove a mechanic works (a boss can be hit and dies, a curse applies) stay. Balance is judged by the owner's play. Exit gates that say **sims** become **owner** (ROADMAP §3 row) | Decided | Step EC |
| P2 | "Spawn 3 agents parallel at max at the same time" | Waves of at most 3 agents | Decided | process |
| P3 | "plan and make a document with everysingle thing I said so we don't lose any of the feedback" | This file, plus the verbatim paste in v0.5.0 PLAYTEST.md | Done | this file |

### Difficulty and growth
| # | Owner line (verbatim) | Decision | Status | Where |
|---|---|---|---|---|
| D1 | "Very calm, that fits the first 30 seconds of the first floor then it should ramp a bit faster" | The calm phase lasts 30 s, and only on floor 1; after it the ramp to the peak is steeper (floors 2–3 start at their warm-up level, no calm) | Decided | Step EC |
| D2 | "we should add closing door to some rooms so you have to stay there until you kill X enemies before continuing" | Locked arena rooms: doors close on entry, waves spawn inside, the doors and the room's reward open on the clear. How many rooms, and what the other rooms are, depends on the direction (X1) | **Decided 2026-10-08** | Step AR |
| D3 | "and also find a way of enemies also matching what you can do in terms of not super mega outgrowing them" | The growth-matching scaling below (D4) | **Decided 2026-10-08** | Step DS |
| D4 | "I think a cool mechanic would be to recalculate difficulty for next floor based on your damage, but that'd make it same difficulty everytime even if your build is broken so not exactly scaling with you but maybe regular scaling + multiplier based on how much you grew" | **Regular scaling × a catch-up multiplier, capped.** At each floor entry the sim computes the player's power `P` from the loadout (weapon damage × damage, crit, attack-speed and ability multipliers; a pure function of the build, not of how well you play) and compares it with the expected power `E(floor)` of a normal build. Catch-up `m = clamp(sqrt(P / E), 1, cap(floor, T))`; `cap` = 1.5 / 2.0 / 2.5 on floors 1/2/3, +0.25 per threat T. Enemy HP × m, damage × sqrt(m). `m` is fixed for the floor (no mid-floor rubber band) and **hidden from the player** (owner: "Yes, but hidden"). A build twice as strong as expected meets enemies ×1.41: still easier. A build ten times stronger hits the cap and deletes the floor: the lucky run. | **Decided 2026-10-08** ("Yes, but hidden") | Step DS |
| D5 | "I cleared so easy, and highly outgrew the difficulty of each floor" | D4, plus the economy cuts (D9, S1–S4) that made the growth too fast | **Decided 2026-10-08** | Steps EC, DS |
| D6 | "Really easy, but maybe because I got there clearly outscaling the difficulty" (floor-2/3 bosses) | Bosses use D4 with their own cap and get harder fights (D7) | **Decided 2026-10-08** | Step DS |
| D7 | "bosses felt just like an elite, we have to make bosses harder not only matching in some way the HP to our damage, but not fixed because it would be always hard even if I had the luckiest so that matching in difficulty should have a cap based on the floor and how far you took it, you know how in RoR2 sometimes you delete bosses but other runs the difficulty is hard but not impossible, we have to design a system that only super lucky broken builds allow you to kill with easy" | Bosses: HP × m with the boss cap (2 / 3 / 4 on floors 1/2/3, + threat); **plus mechanics that HP can't skip**: phase gates (a phase change at 66 % and 33 % with a short invulnerable transition and new attacks), adds that spawn per phase, arena hazards; so a strong build still has to play the fight, and only a build past the cap melts it | **Decided 2026-10-08** | Step DS |
| D8 | "The difficulty balancing does not have to be about making the game extremely difficult, its to be a good balance between the difficulty curve and the growing path" | The design principle for D4 and D7: the target is "a normal build feels strong but challenged; a lucky build feels like a god". Written into GAME_BLUEPRINT | Decided | Step DS (docs) |
| D9 | "Too common, we should add them as a card, so it is not perma enables only if you get it" (heal orbs) | Heal orbs drop only with the new stat card **Lifesprout** (kills have 10 % to drop an orb that heals 25 %; stacks raise the chance). Without the card no orbs drop. The D9 boss-room heal of floor 1 stays | Decided | Step EC |
| D10 | "I was literally god after 1 run, unkillable and outscaled the difficulty" | D4, D7 and the economy cuts | **Decided 2026-10-08** | Steps EC, DS |
| D11 | "Framerate was right" | The 4 ms bench miss is accepted by the owner's frame rate; the bench stays reported, it no longer blocks | Kept | — |

### Rewards and economy
| # | Owner line (verbatim) | Decision | Status | Where |
|---|---|---|---|---|
| S1 | "I think too many and that's what made me so strong, we could add max 2 per floor and the rest should be chests" (altars) | At most 2 altars per floor (abilities come from altars); the other reward spots become chests (stat cards) | Decided | Step EC |
| S2 | "The shop is too broken, once you buy a slot refreshing it should now spawn again 4, the bought slots should stay bought" | A reroll redraws only the unsold slots; a bought slot stays empty ("SOLD") for the floor | Decided | Step EC |
| S3 | "and not be able to buy 16 upgrades at a time only 4 max per floor if gold gets it" | At most 4 card purchases per floor per shop (the heal and rerolls don't count) | Decided | Step EC |
| S4 | "I felt like I had enough shards to buy whatever I wanted and passing them onto the next floor also made next floor pretty easy, explored full of shards, bought everything and by the time the enemies started appearing I was super strong" | Shard drops −30 % and shop prices ×1.5 on floors 2–3 (starting values); half the unspent shards (rounded down) carry to the next floor (owner Q-S4: "Keep half") | Decided | Step EC |
| S5 | "Used deep portals but I felt like nothing changed tho, maybe because I was too strong" | Deep floors must feel different: a distinct look (violet fog and light), an elite in every combat room, +1 T, a guaranteed epic chest at the end, a Deep-only event. With D4 the extra threat raises the cap, so it bites even a strong build | **Decided 2026-10-08** ("yes to all three") | Step DS |
| S6 | "curse was fun, but also gave me the god feeling too fast" | Cursed offers stop giving an epic stat card; a cursed offer is a trade-off card (S7) whose upside is rare-level | Decided | Step CU |
| S7 | "curses are fun, we can add more variables into it, you lose dash but have a dodge % or attack speed lower but 4th hit increased X% on damage" | New trade-off curses (list C1–C8 below, G1: the owner approves rows) | **Decided 2026-10-08** | Step CU |
| S8 | "Overrun: should close the door and have between 3-5 waves of 4, 8 or 12 enemies spawning in them, not just killing what spawns outside" | Overrun rooms seal on entry; 3–5 waves (drawn per room) of 4, 8 or 12 enemies (by floor 1/2/3) spawn **inside**; the next wave starts when the last enemy dies; the doors and the reward open after the last wave | Decided | Step AR |
| S9 | "Yeah I did, to go back to store or to the shrine" (exploring after the boss) | Kept as is | Kept | — |
| S10 | "Yes" (Continue after a save) | Kept as is | Kept | — |

### Builds: modifiers and merged attacks
| # | Owner line (verbatim) | Decision | Status | Where |
|---|---|---|---|---|
| B1 | "Blade i tried to took it a bit further, but extremely OP too, i was insta deleting everything, bosses, hordes, whatever was in front of me, I liked the playstyle but that's where the balancing I talked about previously comes in" | The Blade keeps its play; D4/D7 do the balancing (no flat nerf) | **Decided 2026-10-08** ("yes to all three") | Step DS |
| B2 | "I think a good way to distinct this game would be adding modifiers and merging attacks for example lighting, modifies the way bullets fo out, or grabbing something that shoots makes your sword shoot an echo of the slide whenever you attack" | The **attack-modifier engine** (below) and the first modifier set | **Decided 2026-10-08** | Step MX |
| B3 | "and all abilities have a combination between them so you can play a lot of different builds, some are stronger than others but players will have to discover those on their own" | Every attack (weapon, skill, the eight abilities) goes through the engine, so every modifier combines with every attack without a hand-made pair. The named combos stay as showcase extras | **Decided 2026-10-08** | Step MX |
| B4 | "and then adding trinkets and stuff like binding of isaac that also modify how you interact, shorter shots but in a cicle, or weapon shots now are shock circles" | **Trinkets**: rare modifiers that change an attack's form, from the same engine (list below) | **Decided 2026-10-08** | Step MX |
| B5 | "there is infinite possibilities so I cant list them all but you have to help me come up with a list for this" | The candidate list M1–M30 below | **Decided 2026-10-08** | Step MX |
| B7 | "we are no longer having 4 abilities weapons, every build turns around the main weapon, and the rest are modifiers, so it makes sense to be able to swap modifiers, if you don't like one you have a swap button for the next you get and you can decide which one to swap so you can have a build and modify it on the run," | The build is the weapon + up to **6 modifier slots** (owner pick) with a **Swap** choice when full; the six old abilities become weapon modifiers; the utility button (Blink, Aegis) stays outside the slots; stat cards are unlimited and visible. Replaces v0.4.0's four ability slots (F8) | **Decided 2026-10-08** | Step MX, [`../../design/MODIFIER_ENGINE.md`](../../design/MODIFIER_ENGINE.md) |
| B8 | "The base should be sword or shooting, and modifiers apply to that, we said for example shooting sword, adding the third modifier would be for example fire, shooting a sword that applies fire, and the forth one could be a shooting fire sword that divides when you hit an enemy, you get the point?" | Modifiers layer onto the weapon in pick order; each adds, none replaces | **Decided 2026-10-08** | Step MX |
| B9 | "Help me with the modifiers engine the idea is that based on what you have what you do also changes visually not only damage wise as I describe with the shooting swords, that was just an example, but we need all of them to be a modifier that adds to your build" | The view draws every attack from its final spec, so every card shows; stat cards show as weight, size and speed (owner picks: element core + heat edge; visible numbers, no slot) | **Decided 2026-10-08** | Step MX |
| B6 | "Is it possible to create some kind of engine that makes creating this easier so when adding a new modifier you don't have to create every single interaction, or is it better to create each interaction individually?" | **An engine**: the full design is [`../../design/MODIFIER_ENGINE.md`](../../design/MODIFIER_ENGINE.md) | Decided (build model) / G1 (the list) | Step MX |

### Look, feel and art
| # | Owner line (verbatim) | Decision | Status | Where |
|---|---|---|---|---|
| A1 | "The ability for gun and blade should match the animation" | Lunge Cleave and Scatter Blast get their own hero animation (lunge pose and wide cleave; a braced two-handed blast with recoil) timed to the sim's ticks; the drawn shape matches the hit shape | Decided | Step LK |
| A2 | "and the color of the swrod/bullets the current hit color as well, once reached the first threshold they turn orangem second one red" | The blade trail and the bullets take the heat colour: base colour below Hot, **orange** at Hot, **red** at Overclock (one palette shared with the heat bar) | Decided | Step LK |
| A3 | "Some VFX need to match the new style of the game, I worked a full art rework and some don't match neither style nor lighting" | A VFX audit against the owner's new art (G1: a table of every VFX, its screenshot and the change), then the restyle of the rows the owner approves | Decided (audit) | Step LK |
| A4 | "I attached two image for the new card select templates, one is the visual reference and the secord one is the empty templates you'll have to crop to use them as real cards" | The 12 empty frames are cropped from `refs/card_templates_empty.webp` (white background removed, alpha edges kept) into `assets/ui/cards/`; pick cards draw the frame with the title, text and two icons laid out as in `refs/card_style_reference.webp`; the frame colour follows the card's family (mapping below) | Decided | Step CD |
| A5 | "The UI should also match this new style, we can work with some mockups"; pick: "Menu from C (we don't need to have those crystal those there, or what is the purpose? but ingame UI, heat, health and minimap  from B(we should remove the black background tho)" | Mockups done (Step CD). **Picked 2026-10-08:** menus (pause and the other menus) in C "Cold glass" style without the build cards beside them; the in-game HUD (heat bar, health, minimap) in B "Ember stone" style, with the minimap's black background removed (the map floats over the game) | **Decided 2026-10-08** | Step UI |
| A6 | "Yes, new bosses might need a render tho" (the Charger dodge) | The Charger dodge is kept. The three new bosses (Warlord, Hive Lens, Foundry) are code-built; an art request (ART_DIRECTION template) for their models goes to the owner | Kept / art request | Step LK |

### Direction and open questions
| # | Owner line (verbatim) | Decision | Status | Where |
|---|---|---|---|---|
| X1 | "I am between two options help me choose and justify why can we make other rooms not visible from the one you are in so you focus in the one that you are fighting, about 60% of the rooms should close the doors and unlock their rewards after clearing them, more like Isaac, or leaving it as is where it is closer to RoR2 or to megabonk, but those have "open world" and it is different, I think the kinda openworld thingy matches better with the incremental part of the game, but then the world generation feels a bit off with the rooms, I need to decide on how to guide the game, you could maybe help me asking some questions and then we decide the direction of the gameplay" | The lead's recommendation and the questions are below ("Direction: open or sealed rooms") | **Decided 2026-10-08: the hybrid** (answers below) | Step AR |
| X1b | "Yes to the arenas, we are also missing a big reward from killing the boss" | Killing a boss offers a pick of 3 from a boss-only **legendary** tier (modifiers and trinkets stronger than chest cards) | **Decided 2026-10-08** ("Pick a legendary card") | Step AR |
| X2 | "Let's discuss" (Echoes, Core theft, Depth descent) | Proposals below ("Signature systems") | **Decided 2026-10-08** ("yes to all three") | — |
| X3 | "Let's discuss" (EI-05 sub-streams `map:event`, `loot:event`, `ai:elite`) | Approved: EI-05 lists `map:event`, `loot:event`, `ai:elite` | **Decided 2026-10-08** ("Approve") | LOCKED_DECISIONS |

## Direction: open or sealed rooms (X1)
**Recommendation: a hybrid, "open floor, sealed arenas".** The floor stays connected and open (you roam, hordes
grow with time, you walk back to the shop and the shrine, which you did), but about a third of the rooms are arenas
that seal, fight in waves and hold the floor's rewards; while sealed, the other rooms go dark.

Why not pure Isaac (60 % sealed, rooms hidden): Isaac has no clock. Its pressure is the room in front of you. This
game's growth is time-based (hordes grow over the floor, the peak sits before the boss), and that clock only works
when you can move through space and choose where to fight. With 60 % sealed rooms, the clock and the hordes fight
the room locks.

Why not stay as is: you outgrew the floor because nothing gated the rewards, and you could explore the whole floor
before the enemies arrived. Sealed arenas gate the rewards behind fights at the floor's current level.

Why the generation "feels off": the rooms are boxes with no job in an open game. In the hybrid each room has a job
(arena, shop, event, shrine, corridor of hordes), so the rooms read as places.

The questions that decide it, with the owner's answers (2026-10-08):
1. Is time the enemy (the longer you take, the harder), or is each room its own fight? **"Time"**
2. Where should enemies come from: they stream in from anywhere, or they wait in rooms? **"Mostly stream in"**
   (sealed arenas spawn their own waves inside)
3. May the player skip fights and sneak to the boss? **"Yes to the arenas, we are also missing a big reward from
   killing the boss"** (you may skip; the good rewards sit in sealed arenas; X1b)
4. Should you see the next room while fighting? **"Others go dark when sealed"**

**Decided: open floor, sealed arenas.** The clock and the streaming hordes stay; about a third of the rooms
(starting value) are arenas that seal on entry, fight in waves and hold the floor's chests and altars; the rest of
the floor darkens while you're sealed in. The Overrun room is the hardest arena (S8).

## The modifier engine (B2–B9)
The full design (build model, spec, rules, visuals, tests): [`../../design/MODIFIER_ENGINE.md`](../../design/MODIFIER_ENGINE.md).
The summary below predates the owner's build-model answers; the design doc wins.

**Answer: build an engine, with a few hand-made interactions on top.** Writing every pair by hand grows as
modifiers × attacks (30 modifiers × 10 attacks = 300 pieces of code) and new content would keep breaking old
combinations. Isaac's tear effects and Noita's wands are engines.

How it works here (deterministic sim, data in `.tres`):
- Every attack (Blade steps, Gun shots, Skill, the eight abilities) is described as an **attack spec**: a
  *delivery* (arc, projectile, ring, beam, zone), a *pattern* (count, spread, direction), a *payload* (damage,
  element, statuses) and *on-hit / on-end hooks*.
- A **modifier** is a small typed rule that rewrites the spec at one fixed stage, in a fixed order:
  1. form (projectile → ring, arc → projectile);
  2. pattern (×2 count, circle, behind);
  3. payload (element, status);
  4. hooks (on-hit chain, on-end explode, echo).
- Each modifier is written once and applies to every attack, so "lightning" changes bullets, slashes, the drone
  and the bombs alike, and new attacks inherit every modifier.
- The existing proc coefficient and ancestry guard keep chains from looping; the caps stay.
- Hand-made code only for named showcase combos and for an outlier that breaks the game.

### Modifiers and trinkets (G1 approved 2026-10-08, owner: "keep all M1–M30")
| # | Name | Effect (applies to every attack) | Kind |
|---|---|---|---|
| M1 | Storm Core | Hits chain lightning to 2 more enemies (50 % damage) | element |
| M2 | Ember Core | Hits burn; kills explode in a small fire burst | element |
| M3 | Frost Core | Hits slow; the 3rd hit on a slowed enemy freezes it for 1 s | element |
| M4 | Venom Core | Hits stack poison that spreads on death | element |
| M5 | Echo Slash | Melee attacks also fire a projectile copy of the arc (the "sword that shoots") | merge |
| M6 | Edge Rounds | Projectiles that hit pass through once and leave a short slash at the point of hit | merge |
| M7 | Shock Circles | Projectiles become expanding shock rings at half range | form (trinket) |
| M8 | Halo Shot | Projectiles fire in a full circle, ×3 count, ×0.5 range | form (trinket) |
| M9 | Boomerang | Projectiles return to you, hitting again | form (trinket) |
| M10 | Orbit Rounds | Projectiles orbit you once before launching | form (trinket) |
| M11 | Split Shot | Projectiles split in 3 on the first hit | pattern |
| M12 | Twin Cast | Every attack repeats once 0.2 s later at 50 % | pattern |
| M13 | Rearguard | Every attack also fires backwards at 60 % | pattern |
| M14 | Wide Arc | Arcs +40° wider, projectiles +30 % size | pattern |
| M15 | Gravity Well | Hits pull nearby enemies toward the point of hit | hook |
| M16 | Shatter | Kills burst into 4 shards that hit nearby enemies | hook |
| M17 | Aftershock | The end of every arc or projectile leaves a small blast | hook |
| M18 | Seeker | Projectiles home in; arcs snap toward the nearest enemy | form |
| M19 | Long Shadow | Dash leaves an afterimage that repeats your last attack | hook (dash) |
| M20 | Phase Dash | Dash is intangible and ends in a shard burst | hook (dash) |
| M21 | Ember Trail | Moving leaves burning crystals on the ground | hook (move) |
| M22 | Aether Shell | Out of combat for 3 s: a barrier that absorbs one hit | defence |
| M23 | Ascension | After 3 s without attacking, the next attack is ×3 | payload |
| M24 | Resonance | Each element on an enemy adds +15 % damage taken (rewards mixing elements) | payload |
| M25 | Heat Sink Rounds | At Overclock, attacks fire one extra projectile | heat |
| M26 | Meltdown Edge | Venting fires your weapon's attack in a full circle | heat |
| M27 | Mirror Drone | The drone copies your weapon's attack form with its modifiers | ability merge |
| M28 | Bomb Rounds | Every 5th projectile is a bomb from Bomb Lobber (needs Bomb Lobber) | ability merge |
| M29 | Blade Orbit | Orbit Blades take your weapon's element and hooks | ability merge |
| M30 | Short Fuse | All ranges ×0.6, all damage ×1.4 | trade-off trinket |

(Several names come from the owner's card reference image: Echo Shard, Soul Fracture, Tide Crystal, Resonance
Core, Lifebloom, Stasis Vein, Gravity Well, Shatter Aura, Ember Trail, Ascension Shard, Aether Shell, Phase
Fragment. Lifesprout (D9) is the Lifebloom slot.)

## Trade-off curses (S7, G1 approved 2026-10-08, owner: "curses look good too")
| # | Name | Down | Up |
|---|---|---|---|
| C1 | Rooted | No dash | 25 % dodge chance |
| C2 | Heavy Hands | Attack speed −20 % | The 4th hit of every combo +60 % damage |
| C3 | Glass Heart | Max HP −30 % | Crit chance +15 % |
| C4 | Blood Price | Abilities cost 2 % HP | Abilities +35 % damage |
| C5 | Fevered | Heat decays 50 % slower | Overclock +40 % damage |
| C6 | Tunnel Vision | The minimap is off | +25 % shards |
| C7 | Brittle | Taking a hit stuns you for 0.2 s | +20 % move speed |
| C8 | Marked | Elites hunt you | Elites drop a rare card |

## Signature systems (X2, decided 2026-10-08: "yes to all three, go ahead")
These three were named in v0.3.0 (L18) and never designed. Approved in the new direction:
- **Echoes:** becomes the modifier family M5, M12, M19 (attacks that repeat as echoes). No separate system.
- **Core theft:** elites and bosses carry a visible **core** (a modifier from the list). Kill them during a short
  window after a stagger to steal it as a free pick. That makes elites a target and gives the engine a source.
- **Depth descent:** becomes the Deep route (S5): each Deep floor taken raises the cap of D4 and the rewards. It
  turns "how far you took it" (D7) into a choice.

## EI-05 (X3)
The game draws its randomness from named streams so a seed replays identically. v0.5.0 added three child streams:
`map:event` (which rooms are events), `loot:event` (event and cursed-chest rolls) and `ai:elite` (which enemy is
elite). They exist so a new event does not shift every later map or loot roll, which keeps old seeds and saves
stable. The locked rule lists the streams by name, so the owner must approve the three names. The lead recommends
yes; the alternative is folding them into `map`, `loot` and `ai` (simpler list, but every new event reshuffles
later rolls).

## Steps
Wave 1 (three agents) starts now with the Decided rows that don't depend on the open questions. Wave 2 waits for
the owner's answers on X1, D4/D7, G1 (M, C) and the mockups.

| Step | Scope | Rows | Wave |
|---|---|---|---|
| EC | Economy and pacing: remove bot sims and band tests (P1), floor-1 calm 30 s then a steeper ramp (D1), heal orbs only with Lifesprout (D9), max 2 altars per floor and the rest chests (S1), shop rerolls keep sold slots and max 4 buys per floor (S2, S3), shards −30 % and floor 2–3 prices ×1.5 (S4) | P1, D1, D9, S1–S4 | 1 |
| CD | Cards and UI style: crop the 12 frames, new pick cards matching the reference (A4); 2–3 UI mockups (A5) | A4, A5 | 1 |
| LK | Look: heat-coloured blade and bullets (A2), skill animations (A1), the VFX audit (A3), the boss art request (A6) | A1–A3, A6 | 1 |
| AR | Sealed arenas: the Overrun waves inside a sealed room (S8); about a third of the combat rooms are arenas (D2, X1); the boss's legendary pick (X1b). **Built** (`bb0aa38`, [`evidence/ARENAS.md`](evidence/ARENAS.md)) | S8, D2, X1, X1b | 2 |
| DS | Difficulty scaling with a cap (D4), boss caps and phase mechanics (D6, D7), Deep that bites (S5), principle in the blueprint (D8) | D3–D8, D10, S5, B1 | 2 |
| UI | The UI restyle from the A5 pick: menus in C, HUD/heat/health/minimap in B, no minimap black background | A5 | 2 |
| MX | The attack-modifier engine and the approved modifiers (B2–B6) | B2–B6 | 2 |
| CU | Trade-off curses (S6, S7) | S6, S7 | 2 |

Each step: tests (unit + an e2e through `main.tscn` with real input where it's player-facing), an evidence file in
`evidence/`, docs touched, strings en + es, full suite green before the merge. No bot balance sims (P1).

## Card frame colours (A4)
The reference ties a colour to a theme. Starting mapping: red = damage, blue = projectiles / frost, amber = economy
and stats, purple = dash and void, green = healing, silver = time and slow, pink = crit, cyan = area, orange =
fire, violet = curses, gold = epic, indigo = trinkets. The owner may remap.

## Open items (what they block)
- X1: decided (open floor, sealed arenas).
- D4 / D7: decided (hidden); the numbers are starting values the owner tunes by play.

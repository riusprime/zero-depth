# v0.3.0 — Three Floors: a full run of three floors with bosses, an economy, item choices and combos (plan, owner-directed 2026-10-07)

Recorded so these decisions never depend on chat context. Progress: [`PROGRESS.md`](PROGRESS.md).

## Context
- **On the branch:** v0.2.0 "First Floor" is built and playtested twice
  ([`../v0.2.0/PLAYTEST_FLOOR.md`](../v0.2.0/PLAYTEST_FLOOR.md),
  [`../v0.2.0/PLAYTEST_FLOOR_2.md`](../v0.2.0/PLAYTEST_FLOOR_2.md)); the owner closed it: "we have something very
  cool now … this is just a demo". `main` still doesn't exist (O3).
- **The owner's direction (2026-10-07, verbatim in `PLAYTEST_FLOOR_2.md` and below):** walls get a thickness so
  blink can't cross every wall, more generation randomness, and "the next actual playable version that has
  features": item combos, floors, working portals, bosses, an economy and rewards.
- This merges the old roadmap's v0.3.0 (boss 1, reward schedule, pause, recap) and v0.4.0 (floors 2–3, biomes,
  bosses 2–3, run end) scopes (LOCKED_DECISIONS, 2026-10-07). Saves, the slot cap, threat branches, the bench and
  the sims stay later.
- **Owner rule** still holds: anything not directed here is decided with the owner. Every number below is a
  **starting value** the owner tunes after playing.

## Owner answers to the design questions (2026-10-07, verbatim)
- Run and portal: "3 floors boss opens portal, but he should have his boss room, that matches the mechanics we are
  gonna be fighting, bigger rooms or smaller depending on what the boss does, based on what we have now help me
  with 3 prompts that describe each boss, 1 per floor, we'd work a pool of them that get randomly generated, and
  then we need to add an economy and reward system that rewards you for staying more time on a floor due to its
  difficulty increase, so reward would come in two ways, a couple of chests that are open with this economy and a
  couple of them that are like the ones we have now, every floor should have 2-3 "free" ones and 2-3 chests"
- Combos: "Both" (engines plus named combos).
- Getting items: "Pick 1 of 3 (Recommended)".
- Blink walls: "By thickness vs range".

## Every owner line → where it lands
| # | Owner line (2026-10-07) | Decision | Step |
|---|---|---|---|
| L1 | "to the generation we need to add the wall thickness factor so you can't just blink every single wall" + (Q4) "By thickness vs range" | Every wall has a thickness. A blink crosses a wall only if its landing point beyond the wall is within blink range (the far face is closer than the range, and the landing spot is free); otherwise it stops before the wall. Blinks may end in another room | A |
| L2 | "and we add more randomness to it" | More variation per floor: wall thicknesses, door widths and positions, cell size per floor, more interior templates and their parameters, prop density | A |
| L3 | "the items combos floors, portals working etc we have to move onto the next actual playable version" | v0.3.0 is a full run: 3 floors, each ending in a boss room; the portal works | B, C |
| L4 | (Q1) "3 floors boss opens portal, but he should have his boss room, that matches the mechanics we are gonna be fighting, bigger rooms or smaller depending on what the boss does" | Each floor has a sealed boss room behind the farthest room; its size and layout come from the boss's data. Entering seals it and stops normal spawns; killing the boss opens the portal in the boss room; the portal takes you to the next floor; floor 3's boss wins the run | B, C |
| L5 | "help me with 3 prompts that describe each boss, 1 per floor, we'd work a pool of them that get randomly generated" | Three boss designs (below) with image prompts for the owner's reference sheets. Each floor draws its boss from that floor's pool (one boss per pool for now; the pool grows later) | C |
| L6 | "an economy and reward system that rewards you for staying more time on a floor due to its difficulty increase" | **Shards**, dropped by every kill; the amount per kill grows with the danger tier, so staying longer on a floor (harder, more enemies) earns more | E |
| L7 | "reward would come in two ways, a couple of chests that are open with this economy and a couple of them that are like the ones we have now, every floor should have 2-3 'free' ones and 2-3 chests" | Per floor: 2–3 free item altars and 2–3 chests that cost shards. Both offer a choice (L9) | E |
| L8 | (Q2) combos: "Both" | Engines (statuses that stack and scale: burn, shock, bleed, frost, guard charges) **and** named combos: owning a specific pair of items unlocks a combo with its own effect, card and look | G |
| L9 | (Q3) "Pick 1 of 3" | An altar or chest opens a 3-card choice (pause-free in the world, the sim waits for the pick); you take one | E |
| L10 | (2026-10-07) "aded to docs/art at github the bosses image" (`docs/art/first-three-bosses-concept.png`: Stone Sentinel, Crawler Queen, Fortress Turret, each with an in-game shot and FRONT / RIGHT-FRONT / RIGHT views) | The three bosses' models match that sheet as close to 1:1 as possible (floor 1 = the sentinel golem, floor 2 = the crawler queen, floor 3 = the fortress turret) | C |
| L11 | "sword should be a 4 moment combo, composed of 4 different kind of slashes the 4th being stronger" | The melee combo becomes 4 distinct slashes, each with its own shape, timing and blade motion: (1) a horizontal slash, (2) a backhand slash the other way, (3) a forward thrust (narrow, longer reach), (4) a heavy spinning finisher (360°, more damage and hit-stop, a longer recovery). Starting damage 10 / 10 / 12 / 24 | N |
| L12 | (2026-10-07, asked: from point-blank a 5 m blink crosses every 0.6–3 m wall) "Thicker room walls" | Keep the 5 m blink; room walls range 0.6–5.0 m, so the thickest stop a blink even from point-blank and thin ones still let it through. The sealed boss room can't be blinked into or out of | A, B |
| L13 | (2026-10-07) "I also added the boss models to assets folder to replace the current ones" (`assets/boss_gatekeeper.glb`, `assets/brood_mother.glb`, `assets/boss_siege_engine_compare.glb`: one textured mesh each, ~10–12k triangles, no parts or animations) | The owner's models replace the code-built boss bodies (installed under `assets/models/bosses/` with a manifest and an asset test; the code model stays as the fallback). With one mesh each, bosses animate as a whole body (bob, lean, lunge, squash, turn, glow on wind-up), not limb by limb | C2 |
| L14 | "oh so no animation for these? you cant work on that by your end?" | Rig each owner model in code at load time: a skeleton and per-vertex bone weights built from the mesh's regions (fists, legs, cannon, egg sac…), then limb-by-limb procedural animation from the boss state; any part that can't be separated cleanly falls back to whole-body motion, reported honestly | C3 |
| L15 | (full-run playtest, 2026-10-07, verbatim in `PLAYTEST_RUN.md`) "melee and ranged should be separate runs … you start from one build or the other" + (Q) "pick at start, have a two card screen with a cool animation of appearing that shows both" | Two starting builds: **Blade** (melee only) and **Gun** (shooting only), chosen before each run on a two-card screen that animates in. The other weapon does not appear in that run (lead's reading of "separate runs"; reversible). Items that only feed the other weapon are not offered | P |
| L16 | "melee should do just a bit more damage, because shooter is OP" | Blade damage +15 %, Gun damage −15 % (starting values), re-checked against the boss fight-length band | P |
| L17 | "in bosses you just stay away and shoot them to death, they should have a mechanic where that is punished … come closer and have a dynamic fight" + (Q) all four: "Ranged armour, Pull / punish move, Closing arena, Weak point up close" | Bosses: hits from beyond 5 m deal less (ranged armour falls off with distance); a punish move when you stay far too long (a pull, a gap-closing charge or a room-wide wave that spares the area near the boss); hazards that creep in from the walls during the fight; a weak point that opens after certain attacks and takes big damage only up close | BX |
| L18 | "combos feel alright, but nothing different from a poor mobile game, i'd like to have more original mechanics … still missing something cool" + (Q) "Echoes, Overclock heat, Core theft, Depth descent" and "overclock heat should show a combo meter that shows you the overheat point" | All four become the game's signature systems, in this order: **Overclock heat** in v0.3.0 (attacks build heat shown on a meter with the overheat point marked; thresholds transform attacks; overheating stalls you; venting with dash/blink blasts); **Echoes**, **Core theft** and **Depth descent** designed with the owner (`docs/design/SIGNATURE.md`) and built in v0.4.0 | H, design doc |
| L19 | "overstaying the first level gave me a ton of money that I did not have how to spend, so a gamble feature where you spend money on incrementing steps and have a random stat increase" | A **gamble shrine** per floor: each use costs more (escalating steps) and grants a random stat increase from a pool (max HP, damage, speed, dash cooldown, regen, heat capacity…) | EG |
| L20 | "the enemies should disappear from the level when the boss is summoned" | Summoning the boss removes every normal enemy on the floor (with a dissolve effect) | BX |
| L21 | "the letter at the top that say floor numbers and danger … something that fits this game, a bit more futuristic/robotic/echoey" | A new HUD style (G2: 2–3 mockups to the owner, a default ships): techno/robotic type and framing with an echo/glitch treatment | UI |
| L22 | "boss health appeared like a loading bar filling as he spawns, it should take the same amount of time" | The boss bar fills from empty to full over exactly the boss's rise (read from the sim's intro ticks) | BX |
| L23 | "the dangermeter should be something visual instead of numbers" | The danger level becomes a visual meter (segments that fill toward the next tier), no numbers | UI |
| L24 | "when my hp goes below 30% it should blink with red color" | Below 30 % HP the HP bar (and a screen-edge vignette, subtle) pulses red | UI |
| L25 | "an out of combat HP regen feature, when after 10s after no combat you start to regen a bit of health that can later be increased" | After 10 s without dealing or taking damage, regenerate 1 % max HP per second (starting value); items/gamble can raise it | P |
| L26 | "bosses felt just a bit easy so incrementing their AI to be a bit harder" | Harder boss AI: shorter recoveries, attack chaining, better targeting/leading, more aggressive phase 2 (starting values, re-checked against the fight-length band) | BX |
| L27 | "how far can you take the sounds on your own?" + (Q) "I synthesise SFX now" | Procedurally synthesised SFX for every event (robotic/synth/echo style) and an ambient drone per biome, with captions; any file can be replaced by dropping one with the same name | AU |
| L28 | "Sometimes when taking a hit game crashes" | Reproduce and root-cause the crash on hit (it survived v0.2.0 H's lag fix); a regression test; ask the owner for the Windows log if it isn't reproducible here | X |
| L29 | "Sword should be used towards where the character is looking, shooting towards the aimed with the other joystick" | Melee swings toward the character's facing (the move direction, or last facing when still); shooting stays on the aim (right stick / mouse) | P |

## Design (starting values)
**Walls (A).** Outer and partition walls: thickness drawn per wall from 0.6–5.0 m (L12; was 0.6–3.0 m) (map stream); cover slabs and
pillars stay thin (0.5 m). Blink range stays 5.0 m (the v0.1.0 data value; this line first said 4.5 m by mistake): a blink toward a wall crosses it when the free landing spot on
the far side is within range, else it lands short of the wall. The view draws walls at their real thickness.
Doors: width 2.2–3.4 m, position anywhere along the shared wall (not only centred). Cell size per floor drawn from
11–14 × 9–11 m. Templates gain parameters (counts, spacing, rotation) and 2 new ones.

**Run (B).** 3 floors. Biomes in random order per run from Ruins, Night Rocks and Red Canyon (palettes + props;
PD-04: the biome never changes difficulty). Floor index scaling: enemy HP × (1 + 0.4 (f−1)), enemy damage ×
(1 + 0.2 (f−1)); the danger tier restarts at 0 on each floor. Between floors you keep items, combos and shards,
and heal 40 % of max HP. HUD: floor number and biome name. Death or victory opens a **run recap**: floor reached,
time, kills, shards, items and combos, the killing cause. **Pause** (Esc / Start) with Resume, Restart and Main
menu.

**Boss room and portal (B, C).** The generator adds a boss room off the farthest room through a sealed boss door
(it opens when you walk up; a card warns "Boss ahead"). Room size and interior come from `BossDefinition.arena`
(cells and template). Entering closes the door behind you, stops normal spawns and starts the boss bar. Killing
the boss opens the portal in the boss room (the stone gate, now active and brighter); walking in loads the next
floor.

**Bosses (C).** Each boss has a stagger meter (hits fill it; full → staggered for 2.5 s, meter resets), phases at
HP thresholds, and telegraphs ≥ 24 ticks like every enemy (BLUEPRINT §F). Floor tier pools, one each for now:
1. **The Gatekeeper** (floor 1 pool) — a giant stone sentinel, the Warden's big brother. Arena: large and open
   (3×3 cells) with four breakable pillars. Moves: **Fist Slam** (a ring of rock spikes, radius 4 m), **Shock
   Lanes** (slams the floor and sends 3 straight shockwaves along the ground; step between them or blink a pillar),
   **Sweep** (a 180° arm sweep at melee range). Phase 2 (50 %): the lanes become 5 and it charges across the room.
   Armour like the Warden: −20 % from the front, +10 % from behind. Recovery after each slam = the punish window.
2. **The Brood Mother** (floor 2 pool) — a huge crawler queen, the Charger's mother. Arena: round and medium
   (2×2 cells) with burrow holes. Moves: **Leap** (jumps to your marked position), **Burrow** (vanishes, a moving
   ripple tracks you, erupts under you), **Brood** (spits 3–4 Charger hatchlings). Phase 2 (50 %): leaps chain
   twice and hatchlings come faster. Tests area damage, crowd control and mobility.
3. **The Siege Engine** (floor 3 pool) — a walking fortress turret, the Needle grown huge. Arena: a long hall (3×1
   cells) with low cover lines it can destroy. Moves: **Barrage** (mortar shells with ground circles), **Rail
   Sweep** (a charging laser beam that sweeps an arc), **Bolt Fan** (fans of bolts to dodge through). Phase 2
   (50 %): it plants, deploys two small turrets and fires faster. Tests blink, dash and ranged play.

Visuals: built from these descriptions in the enemy style (low-poly, red and grey, faceted) and refined 1:1 to the
owner's reference sheets once they exist (same process as the enemy sheet).

**Economy and rewards (E).** Shards per kill: Charger 3, Needle 4, Warden 6, hatchlings 1, × (1 + 0.25 × danger
tier); a boss drops 60 × floor. Shards fly to the player (presentation) and a counter sits in the HUD. Per floor:
2–3 **free altars** (in rooms; replaces v0.2.0's pedestals) and 2–3 **chests** (in other rooms) costing 40, 60
and 80 shards on floor 1 (× 1.5 on floor 2, × 2 on floor 3). An altar or chest offers 3 different items from the
pool (chests roll more rares). The pick UI is the compact item card × 3; G2 mockups go to the owner, the default
ships meanwhile. Item rarity: common or rare (data). Taking one consumes the altar/chest; the other two go back to
the pool.

**Items, engines and combos (G).** Items get **tags** (fire, shock, frost, bleed, blade, bolt, dash, guard). The
pool grows from 16 to 24 so each engine has 3–4 members:
- **Engines** (statuses in the sim, each stacks and is renewable): **burn** (exists; stacks), **shock** (new: at 5
  stacks it discharges a chain), **bleed** (new: stacking damage over time, bursts on dash hits), **frost** (exists
  as slow; at 4 stacks freezes for 1 s), **guard charges** (blocks build charges spent by the next swing).
- **Named combos**: 8 pairs to start (e.g. Ember Edge + Static Chain = **Plasma Arc**: burning enemies chain
  lightning; Frost Core + Kinetic Dash = **Shatter Dash**: dashing through frozen enemies shatters them), each with
  a card, a HUD badge and a look. The full table goes in `docs/design/INTERACTIONS.md` (BLUEPRINT §D).
- The ancestry guard and per-root-chain limits apply to every combo (SIM_CONTRACTS §7–§8).

## Steps (parallel workstreams; each merges with its tests)
- **A. Walls and randomness:** wall thickness + blink-through-by-range (sim + tests + goldens), variation (map).
- **B. Run flow:** 3 floors, biomes, scaling, boss room in the layout, sealed boss door, active portal → next
  floor, floor HUD, pause, run recap (sim + app + presentation; e2e through `main.tscn`).
- **C. Bosses:** BossDefinition + validation, the boss AI framework (stagger, phases), the three bosses
  (mechanics, telegraphs, models, boss bar) (sim + content + presentation).
- **E. Economy and rewards:** shards, altars, chests, the 3-card pick (sim + content + HUD; e2e).
- **G. Engines and combos:** tags, statuses, 8 more items, 8 named combos, INTERACTIONS.md (sim + content +
  presentation; goldens).
- **N. Four-slash combo:** melee becomes 4 distinct slashes with their own shapes and blade animation; items that read the combo (Overcharge, Twin Arc, Long Edge) follow (sim + presentation + tests + goldens).
- **F. Integration:** merges, goldens, a full-run e2e (enter floor 1, beat a boss with the dev panel's help, reach
  floor 2), the tour, a Windows build and a playtest sheet.
- **Finishing v0.3.0 (owner, full-run playtest; parallel workstreams):**
  - **P. Player builds:** the Blade/Gun two-card start screen, split kits, damage rebalance, out-of-combat regen.
  - **BX. Boss challenge:** anti-kiting (ranged armour, punish move, closing arena, weak point), harder AI, clear
    enemies on summon, the boss bar filling during the rise.
  - **UI. HUD style:** techno/echo HUD (G2 mockups), visual danger meter, low-HP blink.
  - **EG. Gamble shrine:** escalating shard cost, random stat increase.
  - **H. Overclock heat:** the heat meter with its overheat point, thresholds, overheat, vent blasts.
  - **AU. Audio:** synthesised SFX and ambience, captions, the audio options.
  - **O. Options and checks:** the Options screen (G2), the readable-cause test, the bench with real AI.
- **Later in v0.3.0 (from v0.1.0/v0.2.0):** Options screen (G2), SFX hooks with captions, the bench with real AI,
  the readable-cause test.

## Open items
- O3 `main`; O4 credit line.
- The owner's boss reference sheets (from the prompts in L5); until then the bosses use descriptions only.
- G2 mockups for the 3-card pick screen and the recap.

## Verification
- Tests per workstream, the full suite before every push, goldens changed only on purpose (named in PROGRESS),
  renders of each boss and arena, the floor transition and the pick screen, then the owner's Windows playtest.

# v0.11.0 G1 — new enemies and biome rosters (approve row by row)

From the brief §4 and §6, PLAN H1, M1–M4 and the owner's answers Q14, Q15, Q21–Q23 (2026-11-07). Answer each row
**approve**, **change: …** or **cut**. Nothing here is built before the rows are answered (O9, O13).

## What is already decided
- **Rosters (Q23):** every biome = a shared core of 4 (Charger, Needle, Swarmer, Warden) + its 2 signature enemies + a
  biome variant of one existing enemy. Floor depth still unlocks the later kinds (Arc Caster, Bomb Drone, Splitter,
  Shield Bearer, Mender, Mine Layer, Sniper), as today.
- **New regular enemies (Q22):** 2 per biome, 10 in all (below).
- **Horde critters (Q14, Q15):** one per biome, same rules (contact damage, low HP, big packs, cheap to draw), each with
  its own body. They come in surges once or twice a floor (30–60 over 10 s, with a sound), never in an Overrun room or a
  Lockdown. A 120-enemy surge is measured on your PC first (Q16).
- **Models (Q21):** every new kind gets a prompt in OWNER_TODO §3.2 in the Charger's style, once its row is approved.

## The design rule for the new kinds
Each one asks the player to do something the current 14 don't: move a certain way, pick a target first, or use the
room. Each has one clear tell (a pose or a mark, never a hidden timer) and one clear answer. HP is given against the
Charger (45) and the Swarmer (8); all numbers are starting values.

## The horde critters (one per biome)

| # | Biome | Critter | Body | Notes |
|---|---|---|---|---|
| H1 | Ruins | Dust Mite | a fist-sized stone tick on six legs | the base critter |
| H2 | Night Rocks | Cave Bat | a small bat with stone wings; flies low, so it ignores floor hazards | same rules, flies |
| H3 | Red Canyon | Ember Flea | a glowing flea that hops in short arcs | a dead flea leaves a spark for 0.5 s (no damage, just a look) |
| H4 | Frozen Shore | Ice Crab | a flat crab with an ice shell; slides a little when it stops | same rules |
| H5 | Starfall | Star Mote | a tiny floating star with a tail | same rules, floats |

All five: ~8 HP, contact damage only, packs of 15–30 inside a surge. The bodies differ; the rules don't (Q14).

## The new regular enemies

| # | Biome | Enemy | Role | What it does | Tell → answer | HP |
|---|---|---|---|---|---|---|
| R1 | Ruins | **Wire Weaver** | area control | Plants two posts up to 6 m apart and strings a live cable between them (the Ruins' cable hazard). The cable hurts on touch and cuts the room in two. It keeps making new cables while alive | The posts spark as they go in → break a post (low HP) to drop its cable, or kill the Weaver | 40, posts 10 |
| R2 | Ruins | **Scrap Hound** | flanker | Fast; circles you at 5 m and only darts in from behind, when you're attacking something else | Its eyes flash as it turns in → turn and hit it; it stops and yelps on a hit | 30 |
| R3 | Night Rocks | **Rock Lurker** | ambush | Waits disguised as a boulder (it is cover for both sides). Bursts out with a slam when you come within 2 m | A faint glow in its cracks and a rumble → shoot boulders that glow before you walk past | 70 |
| R4 | Night Rocks | **Stone Thrower** | brute, ranged | Rips a rock out of the floor and throws it in an arc at where you stand. The rock stays as new cover (lasts 15 s) | It lifts the rock overhead for 0.8 s, a ring marks the landing → move out; use its rocks as cover from the others | 90 |
| R5 | Red Canyon | **Kiln Beetle** | bomber, melee | A slow armoured beetle full of fire. When it dies it bursts 2.5 m after 1 s. Killed on a lava vent, the vent erupts too | It glows brighter as its HP drops → kill it away from you, or near other enemies | 60 |
| R6 | Red Canyon | **Cinder Priest** | support | Stands by a lava vent and makes it erupt on a 3 s rhythm (a 2 m fire column). Never fights itself | The vent pulses in time with its staff → kill the priest first, or time your path between eruptions | 35 |
| R7 | Frozen Shore | **Frost Spitter** | ranged, area | Lobs ice blobs that leave a 2 m slick patch for 6 s. On a patch you slide (you keep your speed and turn slowly); enemies don't | A blue arc marks where the blob lands → keep off the patches, or dash across them | 40 |
| R8 | Frozen Shore | **Glacier Turtle** | tank | An ice shell that blocks shots from the front; it slowly turns to face you. Broken (its shell has its own HP), the shell bursts into 3 sliding ice chunks that hurt enemies too | It is a shield you go around → circle it or break the shell to send the chunks into a pack | 80, shell 60 |
| R9 | Starfall | **Star Warper** | teleporter | Marks a star on the floor beside you, then 1 s later blinks onto it and strikes | The star mark → step off it; standing on the mark yourself cancels the blink and stuns it 1 s | 45 |
| R10 | Starfall | **Gravity Node** | area control, stationary | A floating orb that pulls every projectile within 5 m toward itself: yours and the enemies'. Your shots bend; theirs too | A visible swirl around it → kill it first to straighten your shots, or stand so it bends enemy shots away from you | 50 |

## The biome variants (one existing enemy per biome)

| # | Biome | Variant | Change |
|---|---|---|---|
| V1 | Ruins | Rubble Warden | the Warden wears a rubble crust (extra 30 HP) that falls off as pieces at half HP; the pieces stay as small cover |
| V2 | Night Rocks | Dim Needle | the Needle's shots stay dark until 4 m from you, then light up (the Night Rocks' darkness; they never hide inside 4 m) |
| V3 | Red Canyon | Ember Charger | the Charger leaves a fire trail for 2 s where it charges |
| V4 | Frozen Shore | Frost Charger | the Charger leaves an ice slick where it charges (your example) |
| V5 | Starfall | Split Sniper | the Sniper's shot splits into 3 at half range |

## How this reaches the game (O9, O13)
- `data/biomes/*.tres` gains a roster (core + signatures + variant + critter); `SpawnDirector` reads floor × biome.
- Generation property tests over 1,000 seeds: every biome spawns only its roster, every new kind can appear, no new kind
  before its floor.
- Each new kind: a codex entry, strings in `en` and `es`, a code-made stand-in body until your model arrives, then VAT.
- R6 and R10 change other enemies' attacks (eruptions, bent shots), so their forecasts call the same sim code (EI-07).

## Owner answers (2026-11-07, asked one row at a time)
- **Horde critters H1–H5:** approved, with their small movement extras (bats fly, fleas hop, crabs slide, motes float).
- **New enemies R1–R10:** all approved as written.
- **Variants V1–V5:** all approved as written.

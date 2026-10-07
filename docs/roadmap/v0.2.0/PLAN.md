# v0.2.0 — First Floor: one full procedural floor with continuous spawning, items and a portal gate (plan, owner-directed 2026-10-07)

Recorded so these decisions never depend on chat context. Progress: [`PROGRESS.md`](PROGRESS.md).

## Context
- **On the branch:** v0.1.0 work through Step 7e (`4756202`) on `claude/lucid-fermat-9wv2tf`; `main` still doesn't
  exist (O3).
- **The owner's direction (2026-10-07, verbatim in [`../v0.1.0/PLAYTEST_FIGHT_2.md`](../v0.1.0/PLAYTEST_FIGHT_2.md)):**
  the movement is right; now build a full first floor: procedural, continuous spawning that ramps every 30 s,
  items that change attacks and looks, an (unusable) portal gate; a laser blade; smooth shadows; pad A/X in menus;
  INK by default; "spawn subagents that develop simultaneously".
- This reorders ROADMAP §4 (LOCKED_DECISIONS, 2026-10-07): the floor (old v0.3.0 scope) and a first item set (old
  v0.2.0 scope) come now. The full effect queue, the bleed/guard engine sims and boss 1 stay later.
- **Owner rule** still holds: anything not directed here is decided with the owner. The numbers below are
  **starting values** the owner tunes after playing.

## Every owner line → where it lands
| # | Owner line | Decision | Step |
|---|---|---|---|
| L1 | "add a sword element … the laser part from a laser sword … a dash trail that follows it … replace the cone completely" | A glowing blade (a capsule of light, no hilt) swings through the arc; a ribbon trail follows its tip; the ground cone is removed | A |
| L2 | "fix … the saw effect, shadows should be a straight line to be smooth" | Higher shadow resolution, soft PCF filtering, tuned bias and split distances for the ortho camera | A |
| L3 | "the menu doesn't really work … for controller you can't press A or X" | Pad A (Xbox) / Cross (PS) presses the focused button in every menu; the d-pad and left stick move focus; e2e proves it | A |
| L4 | "the outline I like the most is INK set it as default" | Default `outline = ink`; the other styles stay in Options | A |
| L5 | "develop 1 full floor … procedural generation" | A seeded floor generator: a grid of rooms joined by doorways, interior cover, a start room and a portal room | B |
| L6 | "not waves but continuous controlled spawn … increasing every 30 seconds a bit" | A spawn director: alive cap, spawn interval, enemy mix and HP scale step up every 30 s (a tier) | C |
| L7 | "create some items … modification on how the character attack and its own visuals" | 8 items on pedestals (one per room, from the loot stream); each changes an attack and the look | E |
| L8 | "add the gateway to other levels even if it is not usable … a stone gate with the portal light inside with the rectangle shape" | A stone gate in the portal room with a swirling green rectangular portal; walking into it says it's sealed | D |
| L9 | v0.1.0 Steps 8–12 (owner moved them here) | Bench with real AI, readable-cause test, Options (G2), SFX hooks, release | later steps |

## Design (starting values)
**Floor.** A 3 × 3 grid of rooms (each about 14 × 12 m), connected by a random spanning tree plus one or two extra
doorways (seeded `map` stream). Each room gets 0–3 interior slabs. The start room is a corner; the portal room is
the room farthest from it by doorways. Every room is reachable (tested).

**Spawning (PD-05 flipped).** Tier n starts at n × 30 s. Alive cap 3 + 2n (max 14); a spawn every
max(0.8, 3.0 − 0.25n) s; HP × (1 + 0.08n); the mix starts Charger/Needle and adds Wardens from tier 1. Enemies
appear at least 8 m away, in the player's room or a neighbour, with the existing 0.6 s spawn-in marker. No end:
the floor lasts until you die. The HUD shows time, tier and kills.

**Items** (one pedestal per room except the start; walk over to take; the HUD lists them):
| Item | Changes the attack | Changes the look |
|---|---|---|
| Long Edge | blade reach +35% | longer blade |
| Twin Arc | each swing echoes once 0.1 s later at 50% damage | a second, fainter blade trail |
| Ember Edge | melee hits burn: 2 damage per 0.5 s for 3 s, stacking to 5 | the blade turns orange-red; burning enemies smoulder |
| Splinter Shot | each shot fires 3 bolts in a 12° fan at 60% damage | bolts split into three |
| Rapid Coil | fire rate +40% | bolts get longer trails |
| Ricochet Core | bolts bounce off walls once | bolts glow brighter |
| Kinetic Dash | dashing through an enemy hits it for 12 | the dash leaves a cyan streak |
| Overcharge | every 4th swing deals double damage and a small shockwave | the core panels pulse; the 4th swing flashes |
Items stack across a run (no duplicates on one floor). They are plain modifiers today; the full
Trigger → Condition → Payoff effect queue (SIM_CONTRACTS §8) arrives with the engine work.

**Portal gate.** Two stone pillars and a lintel around a 2.4 × 3.2 m rectangle of swirling green light (a shader,
like a cartoon portal in a door shape). Sealed for now: walking into it shows "The gate is sealed. The way on
isn't open yet."

## Steps (parallel workstreams; each merges with its tests)
- **A. Look and feel:** laser blade + trail (replaces the cone), smooth shadows, pad A/X in menus, INK default.
- **B. Floor generator:** `src/sim/map/` (pure sim), tests for determinism, reachability, spawn spots.
- **C. Spawn director:** continuous tiers, content data, tests.
- **D. Portal gate:** presentation (stone gate + portal shader), the sealed message.
- **E. Items:** content, pickups, effects in the sim, visuals, HUD (after A–C merge).
- **F. Integration:** `FloorScenario` replaces the arena; HUD time/tier/kills; tour; a build for the owner.
- **Later in v0.2.0:** v0.1.0's Steps 8–12.

## Open items
- O3 `main`; O4 credit line. Floor size, tier pace and item numbers are owner-tuned after playing.

## Verification
- Tests per workstream, the full suite before every push, goldens changed only on purpose (named in PROGRESS),
  screenshots of the floor and the gate, then the owner's Windows playtest.

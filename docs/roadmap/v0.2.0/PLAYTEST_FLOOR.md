# v0.2.0 "First Floor": floor build (owner)

The first full floor, from your direction of 2026-10-07 ([`PLAN.md`](PLAN.md)). Answers below are **OWNER ONLY**:
written by the owner or pasted verbatim from the owner's message.

## Get the build
1. Open the **Windows** workflow runs on `claude/lucid-fermat-9wv2tf`:
   <https://github.com/riusprime/zero-depth/actions/workflows/windows.yml>, and pick the newest green run.
2. Download `game_windows_x86_64`, unzip the `game_windows_x86_64.zip` inside it, and run `game.exe`.

## What's in it
- **A generated floor:** 3 × 3 rooms joined by doorways, with cover slabs. A new seed each Restart.
- **Continuous spawning:** enemies arrive in your room or the next one, never closer than 8 m. Every 30 s the
  danger level rises: more enemies at once, faster arrivals, tougher HP, Wardens from danger 2. The floor lasts
  until you die. The HUD shows the time, the danger level and your kills.
- **8 items on pedestals** (one per room except the start; walk over one to take it). Each changes an attack and
  the look: Long Edge (longer blade), Twin Arc (each swing echoes), Ember Edge (melee burns, orange blade), Splinter
  Shot (3-bolt fan), Rapid Coil (faster fire, longer bolts), Ricochet Core (bolts bounce once), Kinetic Dash (the
  dash hits, afterimages), Overcharge (every 4th swing double damage + shockwave). The HUD lists what you carry.
- **The portal gate** in the farthest room: a stone gate with a swirling green portal, sealed. Walk up to it.
- **The laser blade** replaces the cone: a light blade with a motion trail.
- **The hooded wanderer** replaces the cube: hood with a cyan visor, a cloak with a little spring physics,
  walk / dash / swing / guard / death animation (from your reference image).
- **Smooth shadows**, **INK outlines by default**, **A / Cross works in every menu**.

## Questions
1. Is the floor fun to explore and fight through? Too big, too small, too empty?
2. The 30 s danger ramp: too slow, too fast, about right? How long did you last?
3. Items: did you feel the change in your attacks and in the look? Which felt best, which weakest?
4. The laser blade and its trail: does it read like a sword swing now?
5. The character: does it match your reference? The 3/4 views are close; face-on it still looks a bit boxy, and
   the dash flares the cloak a lot. What should change?
6. The portal gate and the floor look (lower room walls, smooth shadows, INK): anything to change?
7. Controller menus: do A / Cross and the d-pad work everywhere now?
8. Frame rate on your PC, anything broken, anything wrong in Spanish.

## Owner answers (2026-10-07)
Pasted verbatim from the owner's message:

> Some feedback of the game, feels good, but when receiving dmg the game sometime lags and even crash
> Dash and blink should have an animation, like white trail movement for dash and blue blink teleport feel like a blue light at the beggining and end points of the teleport and the portal should be blue, not green, then the way objects display what they do should be more concise, appear in a smaller card and one small sentence should help you understand what it does, maybe we can add to the card a symbol that lets the player know which each item does, the map generation is not what we are looking for, it should be bigger, the first 3x3 should be a room and then have connecting rooms, having in total 10-12, and not always be divided in 1x1 squares but generating different kind maps across the rooms, the 1x1 division will make this feel repetitive, we have to add more variables to the generation, then one randomly selected outer wall of the 3x3 should have a connection to the new room, some rooms could be 3x1, 3x2 and 3x3 for the bigger ones, items should be 1-2 items per room, smaller rooms only have 1, and let's add more items from the plan to the next version, let's work this parallel to the character rework

## Free notes
OWNER ONLY

# v0.3.0 "Three Floors": first full-run build (owner)

The first build with a whole run (PLAN L1–L12). Your boss models (L13–L14) are still being installed and rigged;
this build shows the code-built bosses. Answers below are **OWNER ONLY**: written by the owner or pasted verbatim
from the owner's message.

## Get the build
1. Open the **Windows** workflow runs on `claude/lucid-fermat-9wv2tf`:
   <https://github.com/riusprime/zero-depth/actions/workflows/windows.yml>, and pick the newest green run.
2. Download `game_windows_x86_64`, unzip the `game_windows_x86_64.zip` inside it, and run `game.exe`.

## What's in it
- **A run of three floors** in random biome order (Ruins, Night Rocks, Red Canyon), each harder. Enemies keep
  arriving and get harder every 30 s, and the longer you stay, the more shards each kill pays.
- **Boss rooms:** off the farthest room. Walk through the boss door: it seals behind you, spawns stop and the boss
  bar appears. Stone Sentinel (floor 1 pool), Crawler Queen (floor 2), Fortress Turret (floor 3). Each has a stagger
  meter (fill it to stun the boss for 2.5 s) and a second phase at half HP. Killing it opens the portal; walk in
  to go down. Floor 3's boss wins the run. You keep items, combos and shards, and heal 40 %.
- **Rewards:** 2–3 free altars and 2–3 chests (40/60/80 shards, more on later floors) per floor. Press **E** (pad
  **X / Square**) to open; pick 1 of 3 (mouse, arrows / 1-2-3 + Enter, or d-pad + A); Esc / B leaves it for later.
- **Engines and combos:** burn, shock, bleed, frost and guard charges stack on enemies; 24 items; 8 named combos
  (owning both items unlocks one, with its own card).
- **Four-slash blade:** slash, backhand, thrust, spinning finisher (10 / 10 / 12 / 24).
- **Walls 0.6–5 m thick:** blink crosses a wall only if the far side is within range; you can't blink into or
  out of a sealed boss room.
- **Pause** (Esc / Start) and a **run recap** on death or victory.
- **Dev panel** (dev builds): God mode, Kill boss, Spawn boss — handy to see every floor quickly.

## Questions
1. Does the run feel like a real game now? What's missing first?
2. Bosses: which was most fun, which unfair or boring? Fight length?
3. Economy: did staying longer to earn shards feel worth it? Chest prices?
4. Pick 1 of 3 and the combos: did you build toward something? Which combo felt best?
5. The four-slash combo: does the finisher feel heavy or sluggish?
6. Thick walls and blink: better? Any spot where blink felt wrong?
7. Pick-screen layout (G2): the shipped centred row, or one from `evidence/pick_mockups.png`?
8. Frame rate on your PC, crashes, anything wrong in Spanish.

## Owner answers (2026-10-07)
Pasted verbatim from the owner's message:

> lets go for finish v3, melee and ranged should be separate runs, or being able to unlock further in the game, you start from one build or the other, melee should do just a bit more damage, because shooter is OP, for example in bosses you just stay away and shoot them to death, they should have a mechanic where that is punished and you have to move, come closer and have a dynamic fight, combos feel alright, but nothing different from a poor mobile game, i'd like to have more original mechanics, something that differenciates this game from others, we can discuss which ones but we are still missing something cool. the rest of the gameplay is fine, economy is not bad, in the first run, overstaying the first level gave me a ton of money that I did not have how to spend, so a gamble feature where you spend money on incrementing steps and have a random stat increase could fix that, the enemies should disappear from the level when the boss is summoned and we still have to work on some UI aspects, for example the letter at the top that say floor numbers and danger, we could work on something that fits this game, a bit more futuristic/robotic/echoey I don't really know how to describe the style of the game, and it'd be cool if the boss health appeared like a loading bar filling as he spawns, it should take the same amount of time for him to spawn that the bar to appear, and the dangermeter should be something visual instead of numbers, when my hp goes below 30% it should blink with red color to show the player it is low, and we should add an out of combat HP regen feature, when after 10s after no combat you start to regen a bit of health that can later be increased, bosses felt just a bit easy so incrementing their AI to be a bit harder would be necessary as well, also, how far can you take the sounds on your own? or do I need to add them by myself?

Additional feedback (2026-10-07, verbatim):

> * Sometimes when taking a hit game crashes
> * Sword should be used towards where the character is looking, shooting towards the aimed with the other joystick

> Also should add a minimap that does not make you go in circles for a long time, that is discovered as you walk into new rooms

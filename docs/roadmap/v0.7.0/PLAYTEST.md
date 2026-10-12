# v0.7.0: playtest build (owner)

The wand (your v0.6.1 feedback: "almost everything that you take modifies how your basic attack looks and interacts
and shoots"), the Siege Engine's bigger room, and `claude/keen-volta-ht74pz` (the F10 dev panel and the lighting
pass). Answers below are **OWNER ONLY**.

## Get the build
1. When the PR into `main` is merged, the **Windows** workflow runs on `main`:
   <https://github.com/riusprime/zero-depth/actions/workflows/windows.yml>. Pick the newest green run on `main`.
2. Download `game_windows_x86_64`, unzip `game_windows_x86_64.zip`, run `game.exe`.
3. Old saves load: each v0.6 card becomes its new wand card in pick order (two that map to the same card level it
   up); a card with no new row (the Drone, for example) is refunded in shards. The table is in
   [`../../design/WAND.md`](../../design/WAND.md).

## What's new
- **The wand.** Your basic attack is the spell; every card changes it, read left to right.
  - Split then Big gives three big shots; Big then Split gives one big shot that splits into three normal ones.
  - **Triggers** (On Hit, On Kill, On End, On Finisher with the Blade / On Crit with the Gun) cut the wand: the cards
    to their right cast a small spell where the trigger fires (a pale-gold flash, then the spell).
  - **4 slots on floor 1, 6 after the first boss, 8 after the second.** A card you hold again levels up (1–5) and
    uses no slot.
- **Rearrange it:** pause → **Build** (keyboard, mouse drag or click-click, pad), and on the Swap panel (replace,
  insert with I / X, move with R / Y). Both read the wand back in plain words.
- **Three pools:**
  - **Gun:** Big Shot, Rapid Fire, Twin, Spread, Split, Pierce, Ricochet, Homing, Boomerang, Orbit, Spiral, Mine,
    Charge (hold to grow it; it fires on release or at full charge), Echo, Backfire, Halo.
  - **Blade, the slash as a spell:** Wide Arc, Wave, Split Wave, Whirl, Double Slash, Thrust, Heavy, Flurry, Fissure,
    Chain Cut, Parry Edge, Afterimage, Lunge Step, Finisher+, Orbit Blades, Counter.
  - **Shared:** Fire, Lightning, Frost, Venom, Bleed, Void, Explosive.
- **The boss altar** offers wand cards at level 5 and three legendary triggers that cast twice (On Hit ×2, On Kill ×2,
  On End ×2).
- **The old v0.6 cards** left the offers (43 of them, mapped or refunded). Two old names changed: the Blink card is
  now "Blink Echo", the old ability "Orbiting Copies".
- **The Siege Engine** (the cannon boss) fights in a 3×3 room.
- **From keen-volta:** the F10 dev panel (every balance file, lighting live, Restart floor, Copy changes; a tweaked
  run shows DEV and isn't saved), the darker lighting pass with blooming fire, fire patches that keep their look.
  The wand's own numbers are in F10 → Build pieces.

## Known, measured here (not felt)
- **No screenshots of the wand** were made: the software renderer timed out under load. Nobody has seen the Build
  page, the charge orb, the mine ring, the Blade's crescents or the trigger casts on a real renderer.
- **Pools:** 61 cards offered per Blade run, 59 per Gun run (your call: keep them).
- **A card's level isn't shown yet** on the pick card or the wand pips; the Build page shows "Lv N".
- **The every-card stress test** (all 96 cards at once) peaks at 188 events in one tick, under the game's limit of
  512. The time that tick takes on your PC is not known.
- **Every number is a starting value:** card sizes, levels, the refund, the trigger casts' size.
- The Blade's cast slash starts on the enemy that was hit and sweeps it too.

## Questions
1. Does the wand feel like Isaac / Magicraft now: do your picks change how the attack looks and plays?
2. Order: did you rearrange? Did the read-back help you understand what the wand does?
3. Which combinations surprised you? Which cards are dull or broken (Gun, Blade, shared)?
4. Triggers: can you see where the small spell is cast? On Finisher vs On Crit?
5. Slots 4 → 6 → 8, levels 1–5, the Swap panel's insert and move.
6. The boss altar's level-5 cards and the ×2 triggers.
7. The Siege Engine's 3×3 room.
8. The dev panel and the lighting pass in play; frame rate in the biggest fights.
9. Charge firing on its own at full charge: right?

## Owner answers
OWNER ONLY

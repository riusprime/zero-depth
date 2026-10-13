# v0.7.5: playtest build (owner)

Your 2026-10-12 message (verbatim in [`PLAN.md`](PLAN.md)): two new biomes, the Ascension portal and its endless
loop, the Codex, local achievements, the small things, bigger floors, and fewer curses, shops and challenge rooms.
You asked for no interventions, so the lead's readings are written in PLAN for you to correct. Answers below are
**OWNER ONLY**.

## Get the build
1. When the PR into `main` is merged, the **Windows** workflow runs on `main`:
   <https://github.com/riusprime/zero-depth/actions/workflows/windows.yml>. Pick the newest green run on `main`.
2. Download `game_windows_x86_64`, unzip `game_windows_x86_64.zip`, run `game.exe`.
3. Saves from v0.7.0 load. A saved floor is rebuilt with v0.7.0's floor rules; the next floor uses the new ones.

## What's new
- **Frozen Shore (biome 4):** a cold moonlit shore with snow, slate, ice shards and a frozen sea past the edge.
  **Ice patches** make the hero slide: slower to speed up and to stop. They never hurt.
- **Starfall (biome 5, a working name):** a floating island over a starry void, with nebula light, drifting rock
  islands, magenta crystals and violet fire. **Starglow pools** make you walk 25 % faster, with a short drift.
- **Runs draw their 3 floors from all 5 biomes.**
- **The Ascension portal:** on the run's last floor the boss gate becomes a golden column of light. Walk in and choose:
  - **End the run:** a win, then the recap.
  - **Ascend:** floor 1 of the next loop with your whole build, new biomes, and harder enemies. It never ends.
  - **Not yet:** keep exploring.

  From loop 2 the HUD and the recap show "Loop N".
- **Bigger floors:** 16–20 rooms (was 11–13), with new 4×3, 3×4 and 4×4 rooms.
- **Fewer interruptions:**
  - **Shop:** on floors 1, 3, 5 …
  - **Cursed chests:** at most one, and only on floors 1, 3, 5 …
  - **Challenge rooms:** about 25 % fewer.
- **The Codex:** main menu or pause → Codex. Every card, enemy, boss and biome. An entry unlocks the first time you
  meet it and shows your counts.
- **37 achievements:** a toast under the minimap when one unlocks, and a page in the Codex. Two are hidden until you
  Ascend.
- **The small things:**
  - **Card levels:** shown on pick cards ("Lv 2 → 3"), the wand pips and the Build page.
  - **First-run hints:** ten, each shown once. Options → Accessibility has "Show hints" and "Reset hints".
  - **Interface size:** 90 / 100 / 110 %.
  - **Credits:** the full licence list and the app icon.
  - **Reduced motion and colour-blind modes** now reach the new screens.
  - **F10:** stays on in this build. A release build can lock it with one setting.

## Known, measured here (not felt)
- **Every number is a starting value:**
  - per-loop difficulty: enemy HP ×4 and damage ×2, boss HP ×2 and damage ×1.5, threat +2;
  - ice and starglow speeds;
  - room counts.

  You can tune all of them in F10.
- **Loading a floor** takes about 0.36 s instead of 0.2 s, measured on a busy cloud machine. How it feels on your PC
  isn't known.
- **Screenshots** came from software rendering in a cloud container.
- **Two visual quirks in Starfall:** some small stars show as dark dots (the outline pass), and the zoomed-out wide
  view cuts off the far side.
- **Interface size 110 %:** the skill plate overlaps card 1's key hint, a showing achievement toast covers card 3's
  title, and the Codex detail panel reaches the right edge. Sizes above 110 % were left out.
- **Art placeholders:** biome props, enemy and boss emblems, and achievement icons are made in code. Art requests
  are in `docs/art/requests/` (v0.7.5 Frozen Shore and Starfall).
- **Text written for you to check:** the Codex lines for enemies, bosses and biomes, the achievement names, and the
  hints, in English and Spanish.
- **Still for you:** your own credit line (`CREDITS_OWNER` is "…"), and whether the AI 3D generator's terms allow
  shipping the kit models.

## Questions
1. Frozen Shore and Starfall: the look, the ice and the starglow pools. The name "Starfall"?
2. The Ascension portal: is the choice clear? Is loop 2 fair and fun? Should it be harder or easier per loop?
3. Bigger floors: is 16–20 rooms right? Are the big rooms fun or empty?
4. Shops and curses every two floors, and fewer challenge rooms: is that the right amount?
5. The Codex: does what unlocks an entry, and what it counts, make sense?
6. Achievements: the list, the names and the toast.
7. Hints: too many, too few, the wording?
8. Card levels on the pick cards and the wand.
9. Anything that feels unfinished for a release.

## Owner answers
OWNER ONLY

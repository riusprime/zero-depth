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

## Owner answers (2026-10-14)
Pasted verbatim from the owner's message; it opens v0.8.0 ([`../v0.8.0/PLAN.md`](../v0.8.0/PLAN.md), O1–O11).

> "Okay, so I'm just going to throw a lot of feedback from the game that I've been holding and experimenting while
> playing. So this is going to be V0.8, and I'm just throwing information. So I need you. What I need you to do is to
> organize it and write it down so we don't lose. Anything that I say, and then we start applying it like we always
> do, three, four agents max, if the four, if the tasks are not too big, three agents, and, first of all, the enemies
> are all red. I know I haven't provided models for all of them, but we could work in something that differentiates
> the different enemies, not only by what they do, but also color. And we could add some different models that add,
> you know, a bit more spice to the to the enemy mix and for most of them unless the things that are thrown from a
> distance we are gonna be deleting the red tray that they show when they aim like we already did with some of them
> before And for the new bosses, I do like the fights. That's like the direction, the right direction. But I tried all
> of them, and the fight seem, feels pretty similar. We just do the orbs in spirals and the ones crossing in line, and,
> and that's fine. But we should have something different, right? Something that actually stands out for each boss.
> Um, the animations they do are a shit, actually. So we have to work on animations from there, like we did with the
> actual attacks of the player. There are some... If we need to generate textures for that, so the the attacks look
> real. So, for example, when they do long distance stonekeeper, it should be like spikes coming out of the ground
> that actually look like spikes and not like. Just a red thingy that doesn't look good at all. And also the orbs that
> they throw, they're 2D shit looking. We could look up for some textures online and use them to create actual 3D
> objects in the game that look and feel like the game's art. Um, the combinations for gun are way better than the
> combinations for blade. Blade is way more difficult to get a good, you know, combination of items. And the, I
> haven't tried them yet, but... Feels like sometimes you're not getting that that many modifiers in the blade as you
> get in the gun, and with enough modifiers in the in the gun, for example, it happened multiple times. But this is
> the example I remember right now. You have a split and the other power that makes the attack divide when you hit an
> enemy. And they explode after it, and that causes hell of a lag. Like it goes, the game goes two, FPS. find a way of
> balancing with these animations so the game doesn't have lag a lot. And I feel like the the visuals are great with
> these images, but maybe we can stop applying some effects so it doesn't cause some lag. And with this kind of build,
> I tested the DPS on the new playground. And the DPS is above 50K of damage per second per enemy. So I spawned three
> enemies and I was doing over 150K of DPS. And ultra omega deleting bosses. So we have to find a way of balancing
> this. when you loop the game and you get to that point so it doesn't become boring and it keeps being difficult and
> not only like doing shit the stronger enemies deal more damage because that would one shot the the player so it
> needs to be a lot more HP growing than health because the player doesn't grow in health that much. We don't have
> those items yet. And that's it for now."

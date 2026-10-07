# v0.3.0 "Three Floors": finishing build (owner)

Everything from your full-run feedback (PLAN L15–L30). Answers below are **OWNER ONLY**: written by the owner or
pasted verbatim from the owner's message.

## Get the build
1. Open the **Windows** workflow runs on `claude/lucid-fermat-9wv2tf`:
   <https://github.com/riusprime/zero-depth/actions/workflows/windows.yml>, and pick the newest green run.
2. Download `game_windows_x86_64`, unzip the `game_windows_x86_64.zip` inside it, and run `game.exe`.
3. If it crashes: send `%APPDATA%\Godot\app_userdata\{{TITLE}}\logs\godot.log` (or the newest dated log before you
   restarted).

## What's new
- **Crash on hit fixed** (a swing pressed on the same tick as a hit crashed release builds).
- **Blade or Gun** on a two-card start screen; Blade hits +15 %, Gun −15 %; items, combos and shrine stats follow
  your weapon. Melee swings where you face; shots go where you aim.
- **Bosses fight back:** shots from far deal less, a punish move if you stay far, hazards closing in, a weak point up
  close (×2), smarter and faster attacks; normal enemies vanish when the boss appears; the boss bar fills as it rises.
- **Overclock heat:** attacks build heat (meter, bottom centre: HOT, OVERCLOCK, the overheat point). Hot and
  Overclock make attacks stronger; at max you overheat; dash/blink while hot vents a blast. 3 heat items.
- **Gamble shrine** in each start hall: spend shards (price rises per use) for a random stat boost.
- **Out-of-combat regen** after 10 s; the HP bar glows green while healing and pulses red under 30 %.
- **New HUD style** ("holo-echo"), a visual danger meter, **a minimap** that reveals rooms (hold Tab / Select for
  the full map), **sounds** (all synthesised), **Options** (audio, display, remapping, accessibility, language).

## Questions
1. Any crash or lag on hit now?
2. Blade vs Gun: does each feel like its own run? Is Gun still too strong, or now too weak?
3. Bosses: are you forced to move and fight close now? Fair or frustrating? Too hard / too easy?
4. Overclock heat: does it change how you fight? Is the meter readable? (Note: lone floor-1 enemies rarely push you
   past Hot; it shines in crowds.)
5. Gamble shrine: does it soak up your spare shards? Prices?
6. HUD (pick A terminal / B holo-echo / C industrial from `evidence/hud_mockups.png`), Options layout
   (`evidence/options_mockups.png`), pick-screen layout (`evidence/pick_mockups.png`).
7. Minimap: no more going in circles? Turned to the camera, or north-up?
8. Sounds: which feel right, which to redo? (Nobody here could listen to them.)
9. Frame rate on your PC in big fights (our worst-case stress scene missed its CPU target; your numbers matter).

## Owner answers
Owner, 2026-10-07 (verbatim):

> make a list of all the feedback and also continue onto v0.4.0 if not done then v0.50, do this spawning 4 agents max at the time, then continue after they are done with the assigned tasks:dashing or blinking while hot vents a blast - this should be an different action button, the overclock heat should be an straight bar, way more minimalistic, the bosses should have better AI and faster movements, some times is impossible to get hit by them and the fight are extremely easy, same for regular enemies, way too predictable and avoidable by dashing or blinking, we should add new ones that have faster very hard to dodge spells, some kind of floating enemy that throws bombs (hittable from the ground level tho, and the circle appears (in some way I kinda orient this into an incremental feeling that you can kill a lot of enemies as you grow on so each build showld focus on 4 items that have combo sword maybe auto throuwing bombos, a robot that follows you, like actual abilities than make damage and the rest of the upgrades and cards you get should be oriented into +%hp dmg crit and that kind of stats you you grow exponentially - this makes the enemies must have an scaling system on damage and health that usually goes just a bit below of what you are growing, and spawning more enemies each floor and time, so it becomes this crazy hard huge battle but you feel like you are a "god" feeling), blinking should be a later on spell you get and dashing should have a higher cooldown, we need more objects or upgrades and combos to add variety, the map is bugged and is not oriented the same way as the actual map it is inverted, the HUD is fine but no so cyberpunk let's make it a bit more minimalistic, the card select from chests and altars are way too AI slop, we should not have the rounded card with the color shadow at the left, change it to match the style of the game, sounds from sword are too overwhelming, we need to add a second ability to guns and blades, so you have variety of attacking movements and it is not just spamming the same attack all the time, there should be an animation of the character entering a portal (make it lighter blue matching his eye color) and an animation getting to one  of the new rooms, let's do this and also go ahead with the feedback and after keep developing the roadmap,

Numbered list and where each line lands: [`../v0.3.5/PLAN.md`](../v0.3.5/PLAN.md) (F1–F22). Questions 1, 2, 5, 9 not
answered (no crash reported).

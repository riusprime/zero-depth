# v0.1.0 "Combat Lab": fight build check (owner)

The mid-version check from PLAN Step 7 (owner Q4: "playable fight first"). Options, remapping, colour-blind modes,
sounds and the release come after this. Answers below are **OWNER ONLY**: written by the owner or pasted verbatim
from the owner's message.

## Get the build
1. Open the **Windows** workflow runs on the `claude/lucid-fermat-9wv2tf` branch:
   <https://github.com/riusprime/zero-depth/actions/workflows/windows.yml>, and pick the newest green run.
2. Download the `game_windows_x86_64` artifact. It holds `game_windows_x86_64.zip`: unzip it and run `game.exe`.

## What's in it (one minute)
**Play → choose Guard or Blink → the arena.** Three waves: (Charger, Needle) → (Charger, Warden, Needle) →
(2 Chargers, Warden, 2 Needles). Clear them all to win; die and the game tells you what killed you. Restart gives
a new seed with the same utility.

| Do | Keyboard + mouse | Gamepad |
|---|---|---|
| Move | WASD | left stick |
| Aim | mouse | right stick |
| Swing (3-hit combo) | click left | tap right trigger |
| Charged bolt | hold left, release | hold right trigger, release |
| Guard (hold) / Blink (press) | right mouse | left trigger |
| Dash (invulnerable) | Space | right bumper |
| Pause | Esc | Start |

**Reading the enemies.** Every attack shows its area on the ground in orange before it lands; the fill shows how
soon.
- **Charger**: a lane toward you, then it charges down it. Afterwards it's dazed for 1 s (a yellow ring): hit it.
- **Warden**: its shield blocks everything from the front. A circle around it means a slam is coming. Once it
  starts the slam it can't turn, so step out and hit it from behind.
- **Needle**: keeps its distance; a thin line shows where its 3 bolts will fly.

All numbers are **starting values** for you to tune: player 100 HP, swing 10/10/18, bolt 12–36, enemy HP 45 / 100 /
30, hits 20 / 25 / 8. One change from the plan: the Warden commits to its slam (PROGRESS explains why).

## Questions
1. With no items at all, is this fight fun? What would make it more fun?
2. Did you always know why you took damage? Was any hit unfair or unreadable?
3. Swing vs charged bolt: which did you use, and does the "press to swing, keep holding to charge" input feel
   right?
4. Guard vs Blink: which did you pick, and was the other worth trying?
5. Which enemy felt best and which worst? Too easy, too hard, too slow?
6. How did movement and the dash feel now that there's something to dodge? Any numbers to change?
7. Camera, outlines, X-ray through walls, readability on this biome: anything to change? (The v0.0.1 gates for
   renderer, pitch and occlusion are still open.)
8. Frame rate on your PC, and anything that broke or read wrong in Spanish.

## Owner answers (2026-10-07)
Pasted verbatim from the owner's message:

> okay some feedback, for a first version the movement feels okay, but we could improve it still on how it feels, for spells, dash worked toward I was moving and that's the right choice, and same should happen with blink, that now currently moves where the front face of the character is so is harder to control, we should have both moving following my movement, I played mouse and controller, with the controller the movement felt a bit different than with keys, can we go over that just to check it is meant to be this way or can it be fixed, also attacks, we have 2, the front blade and the ranged attack, in keys I could easily get to shoot, not in the controller, so I had do kill with the blades all of them, both attacks should have different keys, in controller the triggers should be attacks and the R1 L1 should be the blink and dash, we change the shooting, instead of charging one stronger attack we ling press for continuous shooting that deals less damage each bullet
>
> For the visuals could we ahh a light and thin black stroke to borders of things, i'd like to see how that is seen in game, i like the art but it is not exact exact thing I want, i want it to be closer to a hand draw sketch but not so much that just the feeling that's where the black stroke comes from, like the image attached, but that's too much, just for the feeling
>
> [image attached: a screenshot of a third-party game with a heavy hand-drawn ink-sketch look (pencil-hatched white geometry, black ink outlines); not committed to the repo]

## Free notes
OWNER ONLY

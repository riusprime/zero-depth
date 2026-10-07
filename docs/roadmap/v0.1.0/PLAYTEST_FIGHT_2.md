# v0.1.0 "Combat Lab": second fight build (owner)

Built from your fight-build feedback ([`PLAYTEST_FIGHT.md`](PLAYTEST_FIGHT.md), PLAN L7–L12). Answers below are
**OWNER ONLY**: written by the owner or pasted verbatim from the owner's message.

## Get the build
1. Open the **Windows** workflow runs on `claude/lucid-fermat-9wv2tf`:
   <https://github.com/riusprime/zero-depth/actions/workflows/windows.yml>, and pick the newest green run.
2. Download `game_windows_x86_64`, unzip the `game_windows_x86_64.zip` inside it, and run `game.exe`.

## What changed
| You said | What changed |
|---|---|
| Blink should follow my movement, like the dash | Blink now goes the way you're moving (toward the aim only when standing still), always its full 5 m unless a wall is closer |
| The controller movement felt different from the keys | It was a bug: the stick went through two dead zones, so about a third of its travel did nothing and half tilt gave about a third of the speed. Now a light tilt walks and a pushed stick moves exactly like the keys |
| Both attacks should have their own buttons; triggers attack, bumpers blink and dash | See the table below |
| Long press for continuous shooting, less damage per bullet | Hold to shoot: 4 damage per bolt, about 8 bolts a second. The charged bolt is gone. The swing still does 10 / 10 / 18 |
| A light, thin black stroke, closer to a hand-drawn sketch, just the feeling | **Options → Outline style**: off / ink / sketch (default) / sketch + paper. Try them in a fight. Shots: [`evidence/OUTLINES.md`](evidence/OUTLINES.md) |

| Do | Keyboard + mouse | Gamepad |
|---|---|---|
| Move | WASD | left stick |
| Aim | mouse | right stick |
| Melee (3-hit combo) | left click | left trigger |
| Shoot (hold) | right click | right trigger |
| Dash | Space | right bumper (R1) |
| Guard (hold) / Blink (press) | Shift | left bumper (L1) |
| Pause | Esc | Start |

Lead's picks you may want to change: Shift for the utility on the keyboard, and which bumper does which (R1 dash,
L1 blink). Full remapping arrives with the Options step.

## Questions
1. Do the new buttons feel right on the pad and on the keyboard? Would you swap any?
2. Hold-to-shoot vs the swing: is the balance right (shooting is safer but weaker)? Faster or slower fire?
3. Blink following your movement: better? Is 5 m the right length?
4. Does the pad now move like the keys? Anything still off about movement in general? (You said it "could
   improve still on how it feels": what would you change: speed, acceleration, the dash?)
5. Outline style: which one (off / ink / sketch / sketch + paper)? Thicker or thinner, more or less hand-drawn?
6. Anything else: fun, readability, frame rate, Spanish.

## Owner answers (2026-10-07)
Pasted verbatim from the owner's message:

> Okay great! a couple of small things, blink is just like a faster dash but it should be a teleport, allowing you to go through walls, the hitbox of the shots should e just a bit bigger so it is easier to hit the enemies, but just a bit bigger than its actual size, I like the sketch, but it could be a bit thinner, like more precise, look like draw but not sooo much hand drown like taking the hand part of the drawing a 20% down, then the blade should have a sliding animation of a component to be more visual, not just the cone in the ground but more like a sword swinging but not an actual sword render, the acceleration curve should be a bit faster at both ends so you get to top speed fast and you stop fast but not like a hard stop like a fast smooth curve

## Free notes
OWNER ONLY

## Owner answers, third build (2026-10-07)
Pasted verbatim from the owner's message:

> okay we need to add a sword element, not like areal sword but the laser part from a laser sword, and it has a dash tray that follows it that shows as movement, and we replace the cone thingy completely for this new sword, we also need to fix for the shadowing the saw effect, shadows should be a straight line to be smooth, one more thing the menu doesnt really work well for controller you cant press A or X (xbox or ps) and select the buttons from the menu, apart from that we got the main movements right so you should keep working on next steps to develop 1 full floor, if the procedural generation is not ready it'd be one point of working for it, the waves thing was great for the test but as we worked on the "harder as it goes" we should not have waves but continuous controlled spawn of enemies, increasing every 30 seconds a bit, so it gets harder, for this first level let's create some items, it might not be in the plan but as we gather more items there should be modification on how the character attack and its own visuals so it feels like we gathered stuff, now go for that first level full development, we should add the gateway to other levels even if it is not usable now, but it should be a light portal, closer to what a rick and morty portal looks like but in a door shape, like a stone gate with the portal light inside with the rectangle shape, go for it and spawn subagents that develop simultaneously at the same time what is possible so we save time, the outline I like the most is INK set it as default but we can leave the rest as option, go ahead

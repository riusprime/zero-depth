# v0.0.1 "Ground Plane": owner playtest (Windows check)

This is the exit gate's owner half (ROADMAP §4, v0.0.1). The answers below are **OWNER ONLY**: written by the owner,
or pasted verbatim from the owner's message. The lead never fills them in.

## Get the build
1. Open the latest **Windows** workflow run on the `claude/lucid-fermat-9wv2tf` branch (later: `main`):
   <https://github.com/riusprime/zero-depth/actions/workflows/windows.yml>.
2. Download the `game_windows_x86_64` artifact. It holds `game_windows_x86_64.zip` (and its `SHA256SUMS.txt`):
   unzip that anywhere and run `game.exe`.
3. Plug in a gamepad if you have one (Xbox layout).

## What's new (30 seconds)
The game boots to a menu. **Play** opens one test stage: you're the white cube; the red cubes only stand and
shoot, so the camera, outlines and see-through-walls view can be judged. Move with WASD or the left stick, aim with
the mouse or the right stick, dash with Space or the right bumper. Esc or Start pauses.
Options has language, volumes, VSync and a frame cap. Credits has the licences. Patch notes:
[`../../patch-notes/v0.0.1.md`](../../patch-notes/v0.0.1.md).

## Starting values in use (tune or accept)
From [`../../design/GAME_BLUEPRINT.md`](../../design/GAME_BLUEPRINT.md) §C. These are defaults, not measurements.

## Questions
1. Move, aim and dash with **mouse+keyboard**, then with a **gamepad**. Which felt off, and how (too slow, too
   floaty, the dash too short, aim drifting)?
2. Do you accept the player-kit starting values, or what should change?
3. Can you always find the cube on the stage at a glance, including when it's behind a wall?
4. Gates from Step 7, if not picked yet (shots in [`evidence/GALLERIES.md`](evidence/GALLERIES.md)): renderer
   (Forward+ / Compatibility), camera pitch (30° / 35.26° / 45°), occlusion technique (fade / X-ray / both).
5. What frame rate did you see (dev panel: backtick, in debug builds; otherwise your overlay), on which GPU?
6. Did anything break, crash or read wrong in Spanish?

## Owner answers (2026-10-06)
Pasted verbatim from the owner's message:

> the windows version I played was the bare minimun, just the box moving no enemies or no attacking so I could not really try it

Lead's note (not the owner's words): this matches the build. The v0.0.1 stage holds two idle target cubes
(`src/app/stage_scenario.gd`: `dummy_speed = 0`, `dummy_fire_period = 0`) and the player has no attack; both are
v0.1.0 scope. The questions above weren't answered, so the Step 7 gates and the starting values stay pending.

## Free notes
OWNER ONLY

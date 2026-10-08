# v0.5.9 "Embers": playtest build (owner)

The art rework on top of the v0.5.0 build (PR #1): lighting, your kit, the chest, the hero light and themed rooms.
Gameplay tuning is not in this build; the v0.5.0 feedback belongs to the other agent. Answers below are
**OWNER ONLY**: written by the owner or pasted verbatim from the owner's message.

## Get the build
1. When the PR into `main` is merged, the **Windows** workflow runs on `main`:
   <https://github.com/riusprime/zero-depth/actions/workflows/windows.yml>. Pick the newest green run on `main`.
2. Download `game_windows_x86_64` (kept 14 days), unzip `game_windows_x86_64.zip`, run `game.exe`.
3. If it crashes: send `%APPDATA%\Godot\app_userdata\{{TITLE}}\logs\godot.log`.

## What's new
- **Lighting (your pick B):**
  - each biome has a mood: Ruins a cool moon, Night Rocks a cold blue night, Red Canyon a low dusk sun;
  - soft contact shadow at the base of every wall and block;
  - a light haze and a vignette.
- **Your kit builds the floors:**
  - walls tiled from your wall pieces;
  - cover from your slabs, crates, rocks, wrecks and dead trees;
  - your stone and dirt ground textures;
  - grass and rubble at the bases of walls and blocks.
- **Fire:** fire barrels and braziers set into walls throw warm, flickering light. Only the 4 nearest cast shadows.
- **Your chest:** its lock glows red; the lid swings open with a warm flare when you take the reward.
- **Hero light:** you carry a small warm light, so you stay readable in dark rooms.
- **Themed rooms:** every ordinary room is a Scrapyard, Ruined hall, Camp or Overgrown room.
  - Clusters hug the corners and walls, and free-floor pieces stand in rows.
  - Spacing is the same as before: everything touches a wall or leaves a 2.2 m gap.
  - Car wrecks: at most 2 in a room of the mockups' size.
  - Boss arenas are unchanged.
- **Options > Display > Lighting quality:** High (default) or Low. Low turns off the screen-space shadow and the
  bounce light and drops fire shadows, for a slower GPU.

## Known, measured here (not felt)
- Every screenshot so far came from software rendering in a cloud container. **How it looks and how fast it runs
  on your PC are not known.** Your frame rate on High, and in big fights, matters most.
- Each kit piece is 7–14k triangles; lower-detail versions are generated when a floor loads. Whether the Windows
  export keeps those versions is not checked.
- Floors hold more objects than before (about 124 against 47). A floor takes about 0.1–0.2 s longer to build.
- Not checked yet: on-screen contrast of enemies, attacks and the hero against the darker ground.

## Questions
1. The look overall: closer to your reference image? Too dark, too bright, right?
2. Each biome's mood (Ruins, Night Rocks, Red Canyon): which works, which doesn't?
3. Can you always read enemies, their attack telegraphs, bullets and yourself against the darker floors?
4. Fires and their light: enough of them, too many, bright enough?
5. The hero light: helpful, too strong, too weak?
6. Themed rooms: do the rooms feel distinct and structured? Is any theme too crowded or too empty?
7. Movement: does anything in the new rooms block you or feel like a tight squeeze?
8. Your chest opening: does it read?
9. Frame rate on High and on Low on your PC, quiet and in big fights.
10. Anything in your kit that looks wrong in the game (scale, colour, orientation)?

## Owner answers
OWNER ONLY

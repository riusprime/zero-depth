# v0.2.0 "First Floor": second floor build (owner)

Everything from your floor-build feedback and the enemy sheet (PLAN L11–L18). Answers below are **OWNER ONLY**:
written by the owner or pasted verbatim from the owner's message.

## Get the build
1. Open the **Windows** workflow runs on `claude/lucid-fermat-9wv2tf`:
   <https://github.com/riusprime/zero-depth/actions/workflows/windows.yml>, and pick the newest green run.
2. Download `game_windows_x86_64`, unzip the `game_windows_x86_64.zip` inside it, and run `game.exe`.

## What changed since the last build
- **Damage lag (L11):** every hit flash rebuilt a shader mid-frame; flashes now change brightness only. The crash
  was never reproduced on our side: please tell us if it still happens.
- **Bigger floor (L14–L15):** a 3×3 start hall with one exit on a random wall, then 9–11 rooms of 1×1 up to 3×3
  cells, 1–2 extra loop doors, 7 interior layouts. 1 item in small rooms, 1–2 in bigger ones, none in the hall.
  The space between rooms is now empty (no fake floor).
- **16 items (L16)** with **compact cards (L13):** walk near a pedestal for a small card (symbol, name, one
  sentence); it shows again when you pick it up. What you carry is a row of symbols, bottom right.
- **Dash and blink (L12):** a white trail with afterimages on every dash; a blue light column at both ends of a
  blink. **The portal is blue.**
- **Enemies from your sheet (L17):** the Charger is the red hooded crawler, the Needle the legged turret, the
  Warden the rock golem; each has a wind-up, an attack, a dazed recovery and a rise when it spawns.
- **Warden armour (L18):** no more blocking. Hits from its front deal 80 %, from behind 110 %, from the sides
  100 %. A grey spark means armour, a bright one the weak spot (the glowing cracks on its back).

## Questions
1. Any lag or crash when you take damage now? (Please note your GPU if it still happens.)
2. The bigger floor: size, room variety, the start hall. Too big, too small, too empty?
3. Item cards and symbols: readable at a glance? Any symbol unclear?
4. Dash trail, blink lights, blue portal: right feel? (The portal's floor glow can look a bit lavender on sand.)
5. The three enemies against your sheet: what still differs most?
6. The Warden without the block: does flanking still feel worth it? Are 80 % / 110 % right?
7. Frame rate on your PC, anything broken, anything wrong in Spanish.

## Owner answers (2026-10-07)
Pasted verbatim from the owner's message:

> great great he have something very cool now,  I like the idea of this floor, but now to the generation we need to add the wall thickness factor so you can't just blink every single wall, and we add more randomness to it, lets now keep going for the game development plan, the items combos floors, portals working etc we have to move onto the next actual playable version that has features this is just a demo

Questions 1 and 3–7 were not answered individually.

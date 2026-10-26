# v0.9.5 Step MC: the in-game mouse cursor (owner L16)

Base SHA before the commit: d6c4f421 (branch `v095-mc`, from `claude/v095-feedback`).

## What changed

- `src/presentation/ui/game_cursor.gd` (`GameCursor`): draws two 32x32 `ImageTexture`s once, in code, with 4x4 coverage
  samples per pixel (smooth edges): a **reticle** (a 2 px ring of radius 11 in the UI light `#E8EAEE` at 85 %, a 1 px dark
  `#1A1A22` outline, four ticks at N/E/S/W outside the ring, a violet `#9B6BFF` 3-4 px diamond at the centre; hotspot
  the centre) and an **arrow** (classic pointer, dark outline, light fill, a violet diamond near the tip; hotspot the
  tip, 1 px in). At a window of 1440 px or more the size is x1.5 (48x48); the textures are rebuilt only when that
  height class changes.
- They are set with `Input.set_custom_mouse_cursor(tex, CURSOR_ARROW, hotspot)` only when the context changes: the
  reticle in a run (a driver that is not paused and no end panel), the arrow in the menus, hub, pause (the pause
  pauses the driver) and death screen. The node only compares one bool per frame.
- Pad: the game had no mouse-hiding logic (no `mouse_mode` use in `src/`), so `GameCursor` adds it: a pad button or a
  stick past 0.3 as the last device hides the mouse cursor during a run (`MOUSE_MODE_HIDDEN`); mouse motion/click
  shows it again. Same device test as `AbilitySquares`.
- Replaceable: `res://assets/ui/cursor_reticle.png` / `cursor_arrow.png` are used instead when `ResourceLoader.exists`
  (reticle hotspot = image centre, arrow = 0,0). No error when absent. Two rows added to `docs/OWNER_TODO.md` section 4.
- `src/app/main.gd`: one line, `add_child(GameCursor.new())`. `GameCursor` asks its parent (Main) for `driver`,
  `driver.paused` and `_end` by `get()` (duck-typed) because main.gd is at the 1000-line lint cap; I also removed one
  blank line there to stay at the cap.
- No options toggle. No project.godot change (the import did not touch it).

## Tests

All headless, `--language en`, `APPDATA` set to a temp folder.

| Command | Result (raw) |
|---|---|
| `gdformat --check` + `gdlint` on the three touched .gd files | `3 files would be left unchanged` / `Success: no problems found` |
| `-gtest=res://tests/unit/presentation/test_game_cursor.gd` | `Scripts 1, Tests 5, Passing 5, Asserts 14` |
| `-gdir=res://tests/arch -ginclude_subdirs` | `Scripts 2, Tests 4, Passing 4, Asserts 18171` |
| `-gtest=res://tests/e2e/test_e2e_hub.gd,res://tests/e2e/test_e2e_after_boss.gd` | `Scripts 2, Tests 10, Passing 10, Asserts 110` |

The unit test covers: same texture instances across repeated context changes; 32x32 at 1080 and 48x48 at 1440; the
reticle's pixel (16,16) is violet and opaque, (27,16) on the ring is opaque, (23,16) between ring and dot is
transparent; the arrow's pixel (1,1) is opaque and (30,2) transparent; an image at `reticle_path` replaces the drawn
reticle (an existing imported PNG stands in for the owner's file). Not run: the seed-loop tests, `seams.sh`, the
full suite. No e2e drives the cursor itself (a hardware cursor is not in the scene); the e2e above only prove the
menu to hub to run flow still boots and plays with the node present.

## Shots (1920x1080, GPU renderer, `build/shots/v0.9.5/mc/`, not tracked)

Script outside the repo (a SceneTree script that boots `main.tscn`, calls `start_stage()`, saves the viewport).
`menu_arrow.png` (frame 15, main menu), `run_reticle.png` (frame 120, in a run; the node's context read back as run),
`cursor_reticle.png` and `cursor_arrow.png` (the two textures themselves).

**The OS cursor is not part of a viewport capture**, so `menu_arrow.png` and `run_reticle.png` show the screens without
a cursor. The two cursor PNGs are the textures as the game sets them. I opened both at native size; they look as
described above, but I did not see them as a live hardware cursor over the game.

## Deviations

- Pad hiding was added (the game had none), as asked for that case.
- The context probe is duck-typed on the parent (see above) instead of a typed wire from Main.

## OWNER ONLY

How the reticle and the arrow look and feel on your screen over each biome's floor; whether the ring reads on bright
floors (Ruins) and the violet dot reads on the Starfall floor; the size at 1440p; a pad's hide/show behaviour with a
real pad.

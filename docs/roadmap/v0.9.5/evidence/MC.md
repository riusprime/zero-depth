# v0.9.5 Step MC2: the owner's cursor design (supersedes MC below)

Owner (2026-10-26): "the cursor you made is not valid, use this image as reference" (`docs/art/reference/v0.9.5_cursor_sheet.png`).
Branch `v095-mc2`, from `claude/v095-feedback` (78c4144e). The MC section further down describes the code-drawn cursors
that MC2 replaced; it is kept for history.

## What changed

- **Cut tool:** `scripts/art/cut_cursor_sheet.py`. Command (Python with PIL, numpy, scipy):
  `python -I scripts/art/cut_cursor_sheet.py` (writes `assets/ui/cursors/` and the contact sheet `build/shots/v0.9.5/mc2/sheet.png`,
  not tracked). It keys the sheet's background (estimated from the empty band between the two rows) to alpha from the colour
  distance (solid regions fully opaque, soft glow pixels partly, noise floor 9), un-premultiplies the colour so the red glow
  fades to transparent, crops each of the 7 used icons (MOVE TARGET skipped, captions excluded), resamples premultiplied with
  Lanczos to 32/48/64 px: `assets/ui/cursors/<state>_<size>.png`, states default, hover, click, disabled, aim, interact, invalid.
- **Hotspots** (`assets/ui/cursors/hotspots.json`, fractions of the size; `GameCursor.HOTSPOTS` holds the same numbers and a test
  compares them): the six arrows share one window anchored on the arrow's tip, so the tip is at (0.1753, 0.0779) in all of them
  (48 px: pixel (8, 4)); aim at (0.5, 0.5).
- **`GameCursor`** (`src/presentation/ui/game_cursor.gd`): the seven states; textures loaded once per size class (32 px below 900 px
  of window height, 48 px, 64 px from 1440); `Input.set_custom_mouse_cursor` only when the state or the size class changes (one
  `gui_get_hovered_control()` per frame, no texture work). Pad hiding unchanged. Injectable `cursor_setter`, `hover_probe`,
  `prompt_probe`, `in_run`.
- **State rules:** run: AIM (hotspot centre). Outside a run: INVALID over a control (or a parent up to 6 levels) with meta
  `cursor_invalid == true`; DISABLED over a disabled `BaseButton`; HOVER over an enabled `BaseButton`, a control with
  `mouse_default_cursor_shape == CURSOR_POINTING_HAND` or meta `cursor_hover`; INTERACT while an `InteractPrompt` shows text
  (they join group `interact_prompt`); else DEFAULT. CLICK for 0.12 s after a left press in a menu (cosmetic only).
- **Where `cursor_invalid` is set:** the padlocked Blade card in the build picker (`build_picker.gd`, SL), the shop's cards you can't
  buy (`shop_panel.gd`: sold, can't use, can't afford, limit) and the shop's tiles (`shop_tile.gd`, whenever the tile is disabled).
  Not covered: the progression panel (its rows have no too-poor state of their own that I found; they are buttons, so they
  show HOVER/DISABLED).
- **Removed:** the owner-image override (`assets/ui/cursor_reticle.png` / `cursor_arrow.png`), the code-drawn reticle and arrow, and
  their row in `docs/OWNER_TODO.md` section 4.

## Look check

I read the 4x contact sheet (every state on a dark and a light background, hotspot marked green) and fixed the first cut's
faint rectangle on the light background (the background estimate was off by 13/255; now taken from the empty band). The
hover/click glows fade to transparent without a dark fringe on light.

## Tests

All headless, `--language en`, `APPDATA` in a temp folder.

| Command | Result (raw) |
|---|---|
| `gdformat` + `gdlint` on the 7 touched .gd files | `7 files left unchanged` / `Success: no problems found` (after shortening one comment) |
| `-gtest=res://tests/unit/presentation/test_game_cursor.gd` | `Scripts 1, Tests 8, Passing 8, Asserts 131` |
| `-gdir=res://tests/arch -ginclude_subdirs` | `Scripts 2, Tests 4, Passing 4, Asserts 18261` |
| `-gdir=res://tests/content -ginclude_subdirs` | `Scripts 30, Tests 158, Passing 158, Asserts 13211` |
| `-gtest=res://tests/e2e/test_e2e_hub.gd,res://tests/e2e/test_e2e_sword_unbound.gd` | `Tests 10, Passing 10, Asserts 103` |

The unit test covers: every state's texture at 32/48/64 for each height class; hotspots equal `hotspots.json` and the arrow tip is
the same in the arrow states; picks (enabled button, disabled button, invalid meta on the control and on a parent, pointing
hand, prompt, run); the click lasts 0.12 s; the hardware setter is not called again while the state holds. No test in the repo
checks `assets/ui/` (no manifest for it). Not run: seed-loop tests, `seams.sh`, the full suite.

## OWNER ONLY

How the cursor looks and feels live on your screen (the arrow's size at each resolution, the glow over each biome's floor and over
the menus, the CLICK burst, INTERACT in the hub, INVALID over the padlocked Blade and an unaffordable shop card); whether the
hotspot (the arrow's tip) feels exact; a pad's hide/show behaviour with a real pad. A hardware cursor is not in a viewport
capture, so I have no live shot.

---


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

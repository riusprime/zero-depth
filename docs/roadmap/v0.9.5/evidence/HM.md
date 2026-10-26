# v0.9.5 Step HM (G2): three mockups of the ability squares and the bigger HP plate

Tool script only (`scripts/shots/mock_hud.gd`); no game code changed. The owner picks one (PROGRESS "Gates"); nothing
here is built yet.

- **Build SHA:** de8f1ee5 (the parent of the HM commit; the script is the commit's only code).
- **Machine:** the owner's PC (RTX 3060, Vulkan Forward+, Godot 4.7.2).
- **Command:** `APPDATA=<temp>/zd-hm Godot_v4.7.2-stable_win64.exe --path . --resolution 1920x1080 -s scripts/shots/mock_hud.gd`
- **Raw output:** `hm: renderer=forward_plus`, six lines `hm: res://build/shots/v0.9.5/hm/<a|b|c>_<en|es>.png (1920, 1080)`, `hm: done`, exit code 0.
- **Lint:** `gdformat --check` and `gdlint` on the script: no problems. `tests/arch`: 4 tests, 4 passing, 17496 asserts.
- **Backdrop:** a real frame: Gun run, World seed 11, the data's runner + Gun build, Overclock heat 55, four Chargers,
  Ruins palette, drawn by `WorldViewRoot` and the real `Hud`. The old blue pips, the old ability row and the Skill pip
  are hidden; the HP plate is scaled 1.15 (bar 345 x 11.5 on screen). The squares are drawn by the script.
- **States shown at once:** Attack ready; Skill 3.2 s of 6; Dash 7.4 s of 10; Blink ready with 2 charges; an inset to
  the left shows a "just became ready" flash (a Dash).
- **Icons:** Attack and Blink use the game's own (`ItemIcons` pulse_gun, blink); Skill (a fan of three pellets) and
  Dash (a double chevron) are drawn in the script. Mockup strings are in the script (en + es, through `tr()`).

## Files written (build/, untracked)

`build/shots/v0.9.5/hm/a_en.png`, `a_es.png`, `b_en.png`, `b_es.png`, `c_en.png`, `c_es.png`, and
`sheet_en.jpg` (1800 x 200: the bottom-right 600 x 200 of A, B and C side by side, at native scale; the full-width
bottom 360 px would have shrunk the squares to about 25 px).

## The mockups

- **A, Risk of Rain row** (76 px squares): a dark cover shrinks downward as the cooldown runs, with big seconds (30 px)
  in the middle; ready squares have a lit border. Most readable at a glance; the cover hides the icon while cooling.
- **B, Radial** (72 px): a clockwise sweep plus a border ring in the ability's accent that fills as it recharges, with
  small seconds (18 px) under the icon. Shows the progress twice (sweep and ring); the seconds sit close to the pad pill.
- **C, Tinted fill with heat** (68 px): a per-ability accent fill rises from the bottom with the icon greyed, seconds
  at the top; the heat meter becomes a thin bar over the squares and Vent a fifth 48 px square. Most colour and the
  tightest HUD, but it changes the heat meter's place and the squares are the smallest.

## Not done / caveats

- The "just became ready" flash is a static inset, not an animation.
- The final run used the script before a format-only pass (no logic change); the lint above is on the committed file.
- The Vent pad glyph (B) follows the default binding (`input_defaults.gd`).

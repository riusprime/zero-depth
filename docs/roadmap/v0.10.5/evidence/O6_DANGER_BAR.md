# v0.10.5 O6 — a danger bar replaces the triangles, and the depths' answer is shown

Owner, theory audit **P4** (2026-11-01): "let's try to show it, also modify the triangles at the top to be a line
filling up as a danger hazard texture, small kinda shaped like hp but green to red blinking when full"; asked what the
line shows: "Danger, plus a separate tag". Overnight mode ("Pick and build"): the G2 pick below is the agent's, built as
a starting value; the owner reviews.

Build: worktree `wt-o6`, branch `v0105-o6` cut from `fa8a4463`; the step's commit is the one that adds this file.
Godot 4.7.2 (`Godot_v4.7.2-stable_win64_console.exe`), the owner's PC (Windows 11, RTX 3060).

## G2: three mockups (en + es, 1920 × 1080)

```
godot --path . --resolution 1920x1080 --position -10000,-10000 --audio-driver Dummy -s scripts/shots/mock_danger_bar.gd
```

The frame is the real game (main.tscn, a run started from code, floor 1 "Night Rocks"), posed at 5:00 of floor time and
with the floor's catch-up read as a build twice the expected power (P 2000 / E 1000 → m = `CatchUp.multiplier` =
×1.41, the blueprint's §H example). The real HUD draws the bar and the tag; for A and B the script moves them. An inset
on the left shows the bar's states at 2× (15 %, 50 %, 80 %, full bright, full dim). Raw output:

```
mock_danger_bar: renderer=forward_plus
mock_danger_bar: res://build/shots/v0.10.5/o6/c_en.png (1920, 1080) tier=6 progress=0.666 fill=0.667 m=1414
mock_danger_bar: res://build/shots/v0.10.5/o6/c_es.png (1920, 1080) tier=6 progress=0.666 fill=0.667 m=1414
mock_danger_bar: res://build/shots/v0.10.5/o6/a_en.png (1920, 1080) tier=6 progress=0.666 fill=0.667 m=1414
mock_danger_bar: res://build/shots/v0.10.5/o6/a_es.png (1920, 1080) tier=6 progress=0.666 fill=0.667 m=1414
mock_danger_bar: res://build/shots/v0.10.5/o6/b_en.png (1920, 1080) tier=6 progress=0.666 fill=0.667 m=1414
mock_danger_bar: res://build/shots/v0.10.5/o6/b_es.png (1920, 1080) tier=6 progress=0.666 fill=0.667 m=1414
mock_danger_bar: done
```

| Variant | Shots (`build/shots/v0.10.5/o6/`, not tracked) | What | Trade-off |
|---|---|---|---|
| A — inline | `a_en.png`, `a_es.png` | 150 × 8 bar between time and kills; the tag is the number alone ("▼ ×1.41") in the row | Smallest, but "×1.41" sits next to the tier's "×6" and reads as the same kind of number; the row reflows when the tag appears |
| B — wide | `b_en.png`, `b_es.png` | 500 × 6 bar across the plate under the row; the tag in words under it, inside the plate | Most legible bar, but the top plate grows a line (and two when tagged): more screen covered |
| **C — HP twin (pick)** | `c_en.png`, `c_es.png` | 190 × 9 bar where the teeth were, HP bar look (dark track, lit top edge, stone rim), tier number kept; the tag in words hangs under the plate's right end | The plate keeps its size and the row never reflows; the tag reads as a separate thing (as asked), at the cost of a line outside the plate |

**Pick: C.** It is the owner's words most literally ("small kinda shaped like hp"; "a separate tag"), it changes
nothing else on the plate, and the tag's full sentence names what it is without a legend. Built as the shipped HUD; the
`c_*` shots are the shipped code (the inset is the script's overlay).

## What was built

- `src/presentation/hud/danger_meter.gd`: the ember teeth are gone. A 190 × 9 bar fills to (tier + progress) / 10
  (`FULL_TIER` 10, the overtime's 600 s start), striped with a 10 px diagonal hazard tile generated in code
  (`DangerMeter.stripes()`, no asset), green `#4CD964` → yellow `#F5D020` → red (`HudStyle.WARN`). Full, it blinks
  slowly (0.7 Hz, brightness 1 → 0.3); reduced motion: steady red. The tier-rise pulse and the "×N" tier number from
  tier 4 (v0.9.5 DC) stay. The phase line under the plate (PhaseHud) is untouched.
- `CurveTable.shown_permille_at` + `WorldReader.tier_progress`: in the overtime the progress now runs between the
  overtime's starts (it was 0 there, so the bar would have moved in steps). Read only; `tier()` and the sim are
  unchanged.
- `WorldReader.catch_up_permille()` (new, read only): the floor's enemy m (1000 without the table).
- `src/presentation/hud/depths_tag.gd` (new): "The depths answer ×1.41" / "Las profundidades responden ×1.41"
  (`HUD_DEPTHS_ANSWER`), an ember chevron before it, shown only when m > ×1, under the top plate's right end.
- Pause menu: one sentence under the run line when m > ×1 (`UI_PAUSE_DEPTHS`): "The depths answer ×1.41: your build is
  strong, so this floor's enemies have more HP and hit harder." / "Las profundidades responden ×1.41: tu construcción
  es fuerte, así que los enemigos de este piso tienen más vida y pegan más fuerte." (Main calls `show_recap`.) The
  HUD takes no mouse input, so a tooltip could never show; the pause line is the explanation.
- D4 flipped: `docs/design/GAME_BLUEPRINT.md` §H (where D4 is recorded), with the owner's quote, marked v0.10.5 O6.
- Not tagged: the boss. Since O2b its HP is paced, not × m, so "×m" would not describe it.

## Tests

Lint: `gdformat --check src scripts tests && gdlint src scripts tests` → `0 files reformatted, 1532 files left
unchanged.` / `Success: no problems found`.

```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/presentation/test_hud_style.gd,res://tests/unit/presentation/test_depths_tag.gd,res://tests/content/test_locale_coverage.gd,res://tests/unit/presentation/test_ascension_views.gd,res://tests/unit/presentation/test_ui_polish.gd -gdir=res://tests/arch -gexit
```

First run: `Tests 51 / Passing 48 / Failing 3 / Asserts 25588/25593`. Two failures were the new colour asserts
(`assert_eq` on colours made by `lerp`, equal to the printed digits but not bit-equal); fixed to `is_equal_approx`
and `test_hud_style.gd` re-run alone: `Tests 17 / Passing 17 / Asserts 470`. The third,
`test_ascension_views.gd::test_the_recap_marks_a_looped_run` (`["Bucles ×3"] expected to equal ["Looped ×3"]`, line
139), also fails run alone and touches nothing of this step (the recap's loop line; this PC's locale leaks into it):
**not fixed here, reported**.

```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/e2e/test_e2e_hud_style.gd -gexit
```

First run: `Tests 2 / Passing 1 / Failing 1 / Asserts 24/25` (the same colour assert); after the fix:
`Tests 2 / Passing 2 / Asserts 25`. The new e2e drives main.tscn from the menu, poses m = ×1.41 and 601 s of floor
time, checks the tag under the top plate, the full red blinking bar, and opens the pause menu with Esc (its depths
line).

New: `tests/unit/presentation/test_depths_tag.gd` (the multiplier's wording, the tag's ×1 rule, en/es, the pause line,
the reader's read-only getter, the curve's smooth overtime fill). Changed: `test_hud_style.gd` (the teeth's tests
become the bar's fill / colour / blink / reduced-motion / stripe tests), `test_e2e_hud_style.gd`.

## Picks for the owner

1. **Variant C** (bar in the row, tag under the plate's right end) over A (inline number) and B (wide bar).
2. **Full at tier 10** (the 10-minute mark of the overtime): earlier floors' bars run green → yellow over the first
   five minutes.
3. **The tier number "×N" stays** beside the bar from tier 4 (v0.9.5 DC); drop it if the bar alone is enough.
4. **Wording**: "The depths answer ×1.41" / "Las profundidades responden ×1.41", and the pause sentence above.
5. **Blink**: 0.7 Hz, down to 30 % brightness; steady red with reduced motion.
6. **Enemy m only**; the boss gets no tag (its HP is paced since O2b).

# v0.10.5 O13 — the wand forecast reads your spell left to right

Owner, theory audit **P10** (2026-11-01): "ok" (Koster/Adams: let players see the relationships instead of memorising
them). Overnight mode ("Pick and build"): the G2 pick below is the agent's, built as a starting value; the owner reviews.

Build: worktree `wt-o13`, branch `v0105-o13` cut from `90c806a2`; the step's commit is the one that adds this file.
Godot 4.7.2 (`Godot_v4.7.2-stable_win64_console.exe`), the owner's PC (Windows 11, RTX 3060).

## G2: three mockups (en + es, 1920 × 1080)

```
godot --path . --resolution 1920x1080 --position -10000,-10000 --audio-driver Dummy -s scripts/shots/mock_wand_forecast.gd
```

Real data: a Gun run (`CardPoolSurvey.world`, seed 5), floor 1, holding Big Shot · Split · Fire (Ember Core) · Twin under
the shipped slot rules; the Swap shot has Homing incoming (a Secondary: it replaces Big Shot or Split). Every forecast is
the game's own (`WorldReader.wand_forecast`). Raw output (the `| …` tail trimmed after the first two lines):

```
o13: renderer=forward_plus
o13: wand [&"gun_big_shot", &"split_shot", &"ember_core", &"gun_twin"]
o13: res://build/shots/v0.10.5/o13/a_build_en.png (1920, 1080) | Bolt ×2 → big → burns → on hit: Bolt ×4, small, burns, on a kill: Zone, big, burns → on a kill: Zone, big, burns | Shots per attack 2 · Damage each 6 · Damage per second 80.0 · Radius 0.44 m
o13: res://build/shots/v0.10.5/o13/a_build_es.png (1920, 1080) | Proyectil ×2 → tamaño grande → quema → al impactar: Proyectil ×4, tamaño pequeño, quema, al matar: Zona, tamaño grande, quema → al matar: Zona, tamaño grande, quema | Disparos por ataque 2 · Daño de cada uno 6 · Daño por segundo 80.0 · Radio 0.44 m
o13: res://build/shots/v0.10.5/o13/b_build_en.png (1920, 1080)
o13: res://build/shots/v0.10.5/o13/b_build_es.png (1920, 1080)
o13: res://build/shots/v0.10.5/o13/c_build_en.png (1920, 1080)
o13: res://build/shots/v0.10.5/o13/c_build_es.png (1920, 1080)
o13: swapping=true
o13: swap forecast | Bolt ×2 → burns → homes in → on hit: Bolt ×4, small, burns, on a kill: Zone, big, burns → on a kill: Zone, big, burns
o13: res://build/shots/v0.10.5/o13/a_swap_en.png (1920, 1080)
o13: swapping=true
o13: swap forecast | Proyectil ×2 → quema → persigue → al impactar: Proyectil ×4, tamaño pequeño, quema, al matar: Zona, tamaño grande, quema → al matar: Zona, tamaño grande, quema
o13: res://build/shots/v0.10.5/o13/a_swap_es.png (1920, 1080)
o13: done
```

| Variant | Shots (`build/shots/v0.10.5/o13/`, not tracked) | What | Trade-off |
|---|---|---|---|
| **A — text block (pick)** | `a_build_*`, `a_swap_*` | "FORECAST" (Swap: "AFTER THE SWAP") under the wand; the spell left to right in ember; the four numbers in one line under it | Cheapest to read and to translate; a long wand wraps to two lines |
| B — stat chips | `b_build_*` | The spell line, and the numbers as four big chips (number over caption) | The numbers pop, but the block doubles in height and the Swap panel at 8 slots has no room for it |
| C — A + diagram | `c_build_*` | A's block plus a small drawing of the volley (shot size, the casts each hit makes) | Shows the shape, but a static drawing can't show statuses or chains, and an animated one is a second renderer of the spec to keep in step |

**Pick: A.** It is the owner's example literally (a one-line reading plus the key numbers), it fits both the Build page
and the Swap at 8 slots (the e2e checks the Swap still fits the screen), and every word comes from one compiled spec.
The diagram (C) is listed for the owner below.

Looked at: `a_build_en.png` (the shipped Build page with the forecast block between the wand and the read-back,
readable over the stone), `c_build_en.png`, `a_swap_es.png` (Spanish, "TRAS EL CAMBIO", fits under the 4 tiles).

## What was built

- `src/sim/abilities/wand_forecast.gd` (new, `WandForecast`): compiles a wand's card codes with
  `Modifiers.compile_for(w, Modifiers.build_modifiers_of(w, codes))` — the same functions the sim runs on the held wand
  (`build_modifiers` is now `build_modifiers_of(w, w.mod_slots)`) — into its own `AttackBook` (World.attack_book is
  never touched), and reads the root spec: the spell line (noun ×count, size, statuses, pierce/bounces/chains/homing/
  returns/repeat, then each hook's cast "on hit: …", recursively) as translation keys, and the numbers. Numbers through
  the sim's own functions, split out where they were inline: `ItemEffects.shot_period_of` (the Gun's period),
  `PlayerBuild.bolt_permille` / `melee_permille` (the weapon factor, without the residue write), `Attacks.share_of`
  (the share), `Attacks.merged_damage` (the shot cap), `BladeForms.step_of` (the swing's ticks), `Attacks.arc_reach_m`.
  Damage is per shot before per-hit changes (crits, Gamble, curses, armour).
- `WorldReader.wand_forecast(wand_read)` and `wand_forecast_text` (render en/es through `Wand.render`).
- `src/presentation/menus/wand_forecast_view.gd` (new): the block. Build page: under the wand, follows every move live
  (`BuildPage.open(..., reader)`; Main and the Training Room pass `driver.reader`). Swap panel: the forecast of the
  outcome the focus previews (`wand_swapped`), titled "AFTER THE SWAP"; on Skip, the held wand's.
- 49 `UI_FORECAST_*` strings in `locale/strings.csv`, en + es.

## Tests

```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/sim/test_wand_forecast.gd,res://tests/unit/sim/test_wand_compile.gd,res://tests/unit/sim/test_attack_order.gd,res://tests/unit/presentation/test_wand_views.gd,res://tests/unit/presentation/test_attack_slot_views.gd,res://tests/unit/presentation/test_ui_polish.gd,res://tests/unit/presentation/test_ember_stone.gd,res://tests/unit/app/test_training_room.gd,res://tests/e2e/test_e2e_wand_build.gd,res://tests/e2e/test_e2e_training_room.gd,res://tests/e2e/test_e2e_attack_order.gd -gexit
```
```
Scripts              11
Tests                76
Passing Tests        76
Asserts            3301
---- All tests passed! ----
```
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/arch,res://tests/golden -ginclude_subdirs -gexit
```
```
Scripts               3
Tests                 6
Passing Tests         6
Asserts           19188
---- All tests passed! ----
```

`tests/unit/sim/test_wand_forecast.gd` (new): six wands (plain Gun; Big·Split; Split·Big; Twin·Ember·Rapid·Echo;
Halo·Pierce·Ricochet·Frost; Blade Heavy·Whirl·Frost·Echo Slash) forecast from an order the world doesn't hold, then held
through `Wand.move`: the forecast's shots, damage, period and radius/reach equal the world's (`Modifiers.bolt`,
`ItemEffects.shot_period_ticks`, `BladeForms.step`); the order pairs Big·Split / Split·Big and Ember·Split /
Split·Ember read differently; the forecast leaves the state hash, the wand and the cached book unchanged; every phrase
key has en and es with the same `%s` count. Its printed lines:

```
gun []: Bolt | Shots per attack 1 · Damage each 5 · Damage per second 33.3 · Radius 0.20 m
gun [&"gun_big_shot", &"split_shot"]: Bolt → big → on hit: Bolt ×2, small | …9 damage each · 60.0 per second · 0.44 m
gun [&"split_shot", &"gun_big_shot"]: Bolt → big → on hit: Bolt ×2 | …
gun [&"gun_twin", &"ember_core", &"gun_rapid_fire", &"gun_echo"]: Bolt ×2 → small → burns → repeats once → on a kill: Zone, big, burns | Shots per attack 2 · Damage each 3 · Damage per second 77.1 · Radius 0.14 m
gun [&"halo_shot", &"gun_pierce", &"gun_ricochet", &"frost_core"]: Bolt ×4 → chills → pierces 4 → bounces 3× | Shots per attack 4 · Damage each 2 · Damage per second 53.3 · Radius 0.20 m
blade [&"heavy", &"whirl", &"frost_core", &"echo_slash"]: Slash → chills → as it fires: Bolt ×4, small | Hits per swing 1 · Damage per hit 26 · Damage per second 60.5 · Reach 1.60 m
```

`tests/e2e/test_e2e_wand_build.gd` (extended, real input only): the Build page's forecast at open is the held wand's;
after the keyboard move it changes (the casts gain "chills"); after resume the sim's forecast equals the page's last
preview (numbers and spell line). The Swap's forecast (pad insert, leave) equals the outcome's after the answer.

Lint (whole tree): `gdformat --check src scripts tests` → `1566 files would be left unchanged`;
`gdlint src scripts tests` → `Success: no problems found`. (A first gdlint run found 3 problems in this step's files:
a public var after private ones in `swap_panel.gd`, two long comment lines; fixed, then
`test_e2e_wand_build.gd` re-run: `Tests 3 · Passing Tests 3 · All tests passed`.)

## Picks for the owner

- **A, B or C?** A is built. B (chips) and C (a diagram, possibly animated) are drawn in the mock only.
- **Long wands read long.** Ember Core's "on a kill: Zone" shows on the shot and again inside each cast (both are true:
  every cast carries it). Keep it, or fold a hook every cast shares into one "everything: on a kill …" part?
- **Nouns:** the Gun's shot reads "Bolt" (as the read-back's "You fire a bolt"), though the slot pips call the form
  "Orbs". Rename to "Orb"?
- **Damage per second** is the attack's steady rate (period, shots, share, the shot cap, Echo's repeat), before crits,
  statuses, Gamble and curses, and ignores Rapid Fire's ramp beyond its current state. Fine as a forecast, or show a range?
- Spanish numbers use a point ("60.0"), as the rest of the HUD.

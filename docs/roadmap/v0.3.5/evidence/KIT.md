# KIT: do the Vent button, the 1.4 s dash and the Skill button (Lunge Cleave, Scatter Blast) work in the game?

- **Status:** RUN (agent checks); the feel of the new kit is OWNER ONLY
- **Build:** the working tree of the commit `v0.3.5 Step K: Vent and Skill buttons, slower dash` (parent
  `66124b6`), branch `worktree-agent-a5dc0bdd26575f866`; Godot `4.7.2.stable.official.ed1daf0bf`; OS Linux
  (cloud container)
- **Date:** 2026-10-07
- **Who ran it:** agent

Owner lines: F1 (Vent on its own button), F12 (dash cooldown 0.8 s → 1.4 s), F18 (a second ability per build).

## What was built
- `InputFrame.VENT = 32`, `InputFrame.SKILL = 64` (appended); actions `vent` (F / pad B) and `skill` (Q / pad Y),
  remappable in Options; `World.kit` (`KitState`) hashed only once pressed; `PlayerSkill` runs both.
- Vent: Hot or Overclock → the existing vent blast and heat 0 (`VENT` event); under Hot or overheated → a cold
  click (`VENT_COLD`, sound `vent_cold`). Dash and blink no longer vent.
- Dash cooldown 1.4 s in `data/player/runner.tres` and `PlayerTable.starting_values()`; the kernel scenario pins
  the v0.0.1 0.8 s (`KernelScenario.KERNEL_DASH_COOLDOWN_TICKS`), so **no golden changed**.
- Skills (`SkillDefinition` in `data/builds/blade.tres` and `gun.tres`, validated): Lunge Cleave and Scatter Blast
  with the PLAN's starting values; `SKILL_USED` event and `TAG_SKILL` (bit 21); heat once per landed use; HUD pip
  beside the HP bar and vent hint beside the heat meter (`KitHud`); forecast fan, streak, flash and pellet tracers
  (`SkillVisuals`); sounds `skill_lunge_cleave`, `skill_scatter_blast`.
- Lead's readings (reversible): "stagger like the finisher" = the finisher's 7-tick hit-stop when the cleave lands
  (bosses also fill their stagger meter from the damage, as every hit does); the Gun's pellets take the Gun's
  damage factor (×0.85) as the Blade's cleave takes ×1.15; bosses are not knocked back; the skill cooldown counts
  from the press.

## Command 1: the full suite (import, all tests, CI log guards)
```
bash scripts/verify.sh > build/verify1.log 2>&1; echo "verify exit=$?" >> build/verify1.log
```

## Raw output 1
```
[… import and 686 tests trimmed …]
Totals
------
Scripts             117
Tests               686
Passing Tests       686
Asserts           415032
Time              449.389s


---- All tests passed! ----

Results saved to build/gut.xml
check_gut_log: ok (686 passing, minimum 664)
verify exit=0
```
After the run `tests/MIN_TEST_COUNT` was raised to 686 and the guard re-run on the same log:
```
bash scripts/ci/check_gut_log.sh build/gut.log
check_gut_log: ok (686 passing, minimum 686)
```

## Command 2: the step's own tests (unit, views, e2e through main.tscn)
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/presentation/test_kit_views.gd,res://tests/unit/sim/test_player_skill.gd,res://tests/unit/presentation/test_heat_views.gd,res://tests/e2e/test_e2e_kit.gd,res://tests/e2e/test_e2e_heat.gd,res://tests/unit/application/test_input_rebind.gd,res://tests/content/test_locale_coverage.gd,res://tests/content/test_audio_assets.gd,res://tests/unit/presentation/test_audio_director.gd -gexit > build/t3.log 2>&1
```

## Raw output 2 (grep of build/t3.log)
```
    lunged 3.50 m
* test_gun_pad_y_fires_the_scatter_blast_and_the_dash_waits_1_4_s
2/2 passed.
--
    vented 52 heat, 2 blast hit(s)
1/1 passed.
--
Passing Tests        58
Asserts            2408
Time              35.778s
```
(`test_vent_button.gd` was split out of `test_heat.gd` afterwards for the 20-method lint limit; both ran in
Command 1.)

## Command 3: lint and the sound generator
```
gdformat --check src scripts tests && gdlint src scripts tests
python3 scripts/audio/generate_sfx.py --check
```

## Raw output 3
```
364 files would be left unchanged
Success: no problems found
[… 50 "same" lines trimmed …]
  same  assets/audio/sfx/skill_lunge_cleave.wav
  same  assets/audio/sfx/skill_scatter_blast.wav
  same  assets/audio/sfx/vent_cold.wav
0 difference(s)
```
Regenerating wrote the three new files and the manifest; every existing file came out byte-identical.

## Command 4: shots (renderer under Xvfb)
```
xvfb-run -a godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/kit.gd -- build=blade
xvfb-run -a godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/kit.gd -- build=gun
```

## Raw output 4
```
kit: res://build/shots/v0.3.5/kit/kit_blade_0.png skill=0
kit: res://build/shots/v0.3.5/kit/kit_blade_1.png skill=6
kit: res://build/shots/v0.3.5/kit/kit_blade_2.png skill=0
kit: res://build/shots/v0.3.5/kit/kit_gun_0.png skill=0
kit: res://build/shots/v0.3.5/kit/kit_gun_1.png skill=1
```
The PNGs are under `build/` (not tracked). Looked at by the agent: mid-lunge the cleave fan rides ahead of the
hero; the blast draws 7 tracers ending on the enemies' bodies and the cone; "[Q] LUNGE CLEAVE" / "[Q] SCATTER
BLAST" sits right of the HP bar and "[F] VENT" right of the heat meter.

## Target bands
| Metric | Target | Source |
|---|---|---|
| Dash cooldown | 1.4 s = 84 ticks | PLAN v0.3.5 F12 |
| Lunge Cleave | 3.5 m lunge, 180°, 2.2 m, 28 dmg, 4 s | PLAN v0.3.5 "Second abilities" |
| Scatter Blast | 7 pellets, 60°, 4 m, 6 dmg, knockback 1.5 m, step back 0.8 m, 3.5 s | same |
| Goldens | unchanged unless named | CLAUDE.md |

## Result
| Metric | Measured | In band? |
|---|---|---|
| Dash cooldown | 84 ticks (`test_the_dash_waits_1_4_seconds`, e2e `dash_cooldown_total() == 84`) | yes |
| Lunge | 3.50 m in the open (e2e "lunged 3.50 m"); stops flush at a wall (unit) | yes |
| Cleave | 32 per enemy (28 × 1.15), front half only, 7-tick hit-stop (unit) | yes |
| Blast | 7 pellet ends; knockback 1.5 m ± 0.02; step back 0.8 m ± 0.02; cooldown 210 ticks (unit) | yes |
| Goldens | replay and export-smoke fixtures pass unchanged (Command 1) | yes |

## Interpretation
The kit works end to end through real input. Whether the 1.4 s dash, the skills' numbers and the vent on its own
button feel right is OWNER ONLY. Not done here: the build picker's cards don't list the skill yet (the HUD pip
names it in play).

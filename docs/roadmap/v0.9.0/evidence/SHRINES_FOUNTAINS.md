# v0.9.0 Steps SH and HF: shrines and healing fountains: evidence

Owner lines (PLAN "Owner decisions" Q29b; W35, W36, W56): "Today's gamble shrine becomes the Fortune Shrine; Blood and
Chaos shrines are added (at most one shrine a floor, costs shown first; the Chaos challenge may bring an elite, a
designed exception). Healing fountains (rare, one use) …". W36: Blood (health for a reward), Chaos (a challenge for
an extra upgrade), Fortune (a resource for a random reward).

Build: branch `v090-shhf`, cut from `52cac58c`. The code under test is the working tree of the step commit (its
SHA is in the commit itself; the runs below were made on that tree before committing). Machine: the owner's PC
(i7-10700K, RTX 3060), Godot 4.7.2, Windows, its own `APPDATA`. The machine's locale is Spanish, so the shots show the
`es` strings.

## What was built

- **Fortune**: today's gamble shrine (`Gamble`), its rules unchanged (shards for a stat, 30 % fail, 3 wins), shown to
  the player as the Fortune Shrine (strings `UI_GAMBLE_CARD`, `UI_GAMBLE_USE`, `UI_GAMBLE_STATS*`,
  `MAP_LEGEND_SHRINE`) and drawn with the owner's `shrine_fortune` model (GambleShrineView, the new look; the v0.6.0
  model and the code obelisk stay as fallbacks). Code names (`Gamble`, `gamble_*`) are kept, so saves and other code
  are untouched.
- **One shrine a floor**: the gamble shrine's site draw is unchanged (its chance, 400 per mille, its room and spot).
  From floor rules 14, its kind is then drawn from `map:shrine_kind` by data weights (Fortune 400, Blood 300, Chaos
  300). A Blood or Chaos shrine stands on that site instead (Gamble.present is false then).
- **Blood**: price = 30 % of current HP, rounded up, never more than HP − 1 (never lethal); below 25 % of max HP it
  refuses (prompt: "too weak (needs N HP)"). Paid: one free altar (a card offer) rises beside it; one use.
- **Chaos**: the press spawns the floor's challenge at once on the room's spawn points: 5, 6, 6, 7, 7 enemies on
  floors 1-5 (kinds as the spawn director's now, scaled on arrival). When none is left alive, one free altar rises.
  EL's elite hook: `chaos_elite_permille = 0` (the validator keeps it 0 until EL).
- **Healing fountain**: 250 per mille of floors from floor 2, at most one, in a free spot of a combat room
  (Gamble.room_spot), never the shrine's, an event's or the curse room; the secrets, the purple room and the Lockdowns
  placed after keep out of its room. Its footprint is a wall. One press heals 40 % of max HP (to full at most), then it
  is dry; at full HP it refuses and stays.
- Costs are shown before the press in the shared interact prompt (Interactables.prompt_key / prompt_args). Results:
  ShrineHud. Sounds: `shrine_blood`, `shrine_chaos`, `fountain_heal` (placeholders from `generate_sfx.py`, captioned).
- Floor rules 13 → 14 (`FLOOR_RULES_V090_LK := 13`). A floor saved under 1-13 is rebuilt as saved: the gamble shrine
  (Fortune), no Blood/Chaos shrine, no fountain. New state `ShrineState` (World.shrine) is in STATE_CLASSES, hashed
  when present; `ShrineTable` is loadout.
- Data: `data/shrines/shrines.tres` (ShrineDefinition, all numbers starting values), added to the dev panel's folders.

## Commands and raw output

Lint (`gdformat src scripts tests` then `gdlint src scripts tests`):

```
0 files reformatted, 1194 files left unchanged.
Success: no problems found
```

New sim tests: `godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/sim/test_shrines.gd,res://tests/unit/sim/test_gamble.gd,res://tests/unit/presentation/test_gamble_views.gd,res://tests/unit/application/test_old_saves.gd,res://tests/unit/sim/test_world_snapshot.gd,res://tests/unit/sim/test_state_hasher.gd,res://tests/unit/sim/test_lockdowns.gd,res://tests/unit/sim/test_arenas.gd,res://tests/unit/sim/test_interactables.gd,res://tests/unit/sim/test_purple_runes.gd,res://tests/unit/sim/test_purple_rooms.gd,res://tests/unit/presentation/test_purple_rune_view.gd,res://tests/unit/presentation/test_lockdown_view.gd -gexit`

```
    SH_PLACEMENT| floor=1 seeds=40 shrines=13 fortune=5 blood=4 chaos=4 fountains=0 with_both=0
    SH_PLACEMENT| floor=2 seeds=40 shrines=22 fortune=8 blood=6 chaos=8 fountains=10 with_both=5
    SH_PLACEMENT| floor=3 seeds=40 shrines=18 fortune=7 blood=5 chaos=6 fountains=10 with_both=4
    SH_PLACEMENT| floor=4 seeds=40 shrines=20 fortune=11 blood=3 chaos=6 fountains=9 with_both=4
    SH_PLACEMENT| floor=5 seeds=40 shrines=23 fortune=8 blood=4 chaos=11 fountains=12 with_both=7
    SH_KINDS| shrines=96 fortune=39 blood=22 chaos=35
Tests               111
Passing Tests       111
Asserts           37570
Time              1867.817s
```

An earlier run of `test_shrines.gd` (60 seeds) failed the placement rule: the gamble shrine's site could be the
purple-rune room (seeds 4 and 34 on floors 2 and 3; it can on today's floors too: PurpleRooms got no taken rooms).
Fixed for floor rules 14: PurpleRunes.setup now takes the shrine's and the fountain's rooms (`Shrines.site_rooms`);
rules 1-13 pass none, as before. The same run also flagged a shrine or fountain in a secret's *host* room; a host is an
ordinary room the secret opens from (not in the owner's list), so the test no longer counts hosts.

Content, arch, golden, debug: `... -gdir=res://tests/content,res://tests/arch,res://tests/golden,res://tests/unit/debug -ginclude_subdirs -gexit`

```
[Failed]:  data/lockdowns is in the panel
Tests               162
Passing Tests       161
Failing Tests         1
Asserts           24908/24909
Time              52.551s
```

The one failure is `data/lockdowns` missing from the dev panel's folder list, from step LK (on `52cac58c` before this
step); the lead fixes it on the session branch. `data/shrines` is in the list. No golden changed.

Views, the new e2e and the kit shrine: `... -gtest=res://tests/unit/presentation/test_shrines_view.gd,res://tests/e2e/test_e2e_shrines.gd,res://tests/unit/presentation/test_kit_shrine.gd -gexit`

```
    SHRINES_E2E| blood seed=5 cost=30 hp=100->70
    SHRINES_E2E| fountain seed=1 heal=40 hp=17->57
Tests                12
Passing Tests        12
Asserts              89
Time              33.954s
```

The floor e2e: `... -gtest=res://tests/e2e/test_e2e_run_flow.gd,res://tests/e2e/test_e2e_old_save.gd,res://tests/e2e/test_e2e_purple_portal.gd,res://tests/e2e/test_e2e_lockdown.gd,res://tests/e2e/test_e2e_gamble.gd -gexit`

```
[Failed]:  Expected [<null>] to be anything but NULL:  the shrine is drawn
SCRIPT ERROR: Invalid access to property or key 'root' on a base object of type 'Nil'.
Tests                 7
Passing Tests         6
Failing Tests         1
Asserts           162/164
Time              111.399s
```

`test_e2e_gamble` used run seed 2, whose floor-1 shrine is now drawn as another kind. It moved to seed 385, the first
whose floor-1 shrine is Fortune with the same five rolls (fails at uses 1 and 2). Re-run with the views that read the
shrine: `... -gtest=res://tests/e2e/test_e2e_gamble.gd,res://tests/unit/presentation/test_floor_receiver.gd,res://tests/unit/presentation/test_shard_dressing.gd,res://tests/unit/presentation/test_ui_polish.gd -gexit`

```
Tests                39
Passing Tests        39
Asserts           34733
Time              380.089s
```

Not run here: the full suite (GitHub runs it), `test_curse_room` (slow seed loop; not changed).

## Shots

`godot --path . --audio-driver Dummy --resolution 1280x720 -s scripts/shots/shrines_shhf.gd` (GPU, forward_plus):

```
shrines_shhf: shrine_fortune seed=2493802916 at=(13.51, 18.93) prompt= args=[]
shrines_shhf: shrine_blood seed=2035616380 at=(-6.98, -41.465) prompt=SHRINE_BLOOD_PROMPT args=[30]
shrines_shhf: shrine_chaos seed=498365248 at=(60.37, -0.695002) prompt=SHRINE_CHAOS_PROMPT args=[6]
shrines_shhf: healing_fountain seed=3937390046 at=(-40.505, -22.175) prompt=FOUNTAIN_PROMPT args=[40]
```

`shhf_shots/shrine_fortune.png`, `shrine_blood.png`, `shrine_chaos.png`, `healing_fountain.png` (the Fortune prompt is
the gamble HUD's own, so `prompt=` is empty for it).

## Owner only

- Do the shrines and the fountain feel worth stopping for? Are the costs (30 % HP, 5-7 enemies) right? `OWNER ONLY`
- The models' sizes: Blood is drawn 1.5 m tall (its basin is wide), Chaos 1.8 m. `OWNER ONLY`

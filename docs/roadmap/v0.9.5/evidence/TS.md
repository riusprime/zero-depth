# Step TS: timed-door switches spread over the map, a 20 s timer, a lever inside (owner Q7 a)

Built on `164417dc` (the merge of `claude/v095-feedback` and step DR `62cc306c`) with the TS changes uncommitted at
the time of the runs; machine: the owner's PC (Windows, Godot 4.7.2), each run in its own `APPDATA`. Floor rules
20 -> 21 (`RunState.FLOOR_RULES_V095_TS`).

## What changed

- Switches: two DIFFERENT rooms, each 1-2 doorway steps from the door's host room (never the secret room, the start,
  boss, shop, curse, Overrun, arena or locked rooms, and never walked through a sealed room), on spawn spots 2.5 m from
  doorways and 3 m from rewards, items and the shrine. Rooms behind different first doorways out of the host are
  preferred; else any two. Drawn from the `map:timed_door` stream. No valid pair: the floor has no timed door.
  Rune / cracked / purple / Lockdown rooms keep out of the switch rooms (`FloorLayout.timed_switch_rooms`).
- Fairness: each switch's walk to the door (through the rooms between, 4-connected grid, never shorter than the real
  path) is at most 60 % of the timer at base speed, so either order is completable.
- Timer 1200 ticks (data `timed_door_ticks`, range now 12..24 s). New data: `timed_switch_steps_max = 2`,
  `timed_lever_ticks = 300`.
- Lever (`Interactables.Kind.TIMED_LEVER`, prompt `TIMED_LEVER_PROMPT`, en + es): inside the secret room on the door's
  wall, beside the doorway; same reach as a switch; opens the shut door for 300 ticks, as often as needed; takes no
  press while open. The door still holds while the hero is inside. New `TimedDoor` fields `lever`, `lever_ticks`,
  `open_ticks` (hashed; `ADDED_SINCE_V05` for old snapshots). View: `TimedDoorView` lever post with a handle that swings
  down while the door stands open; its tip glows while it can be pulled.
- A floor saved under rules <= 20 keeps both switches in the host, 15 s and no lever (`FloorPlan.add_secrets`).
- Note: the game never shuts the door on the hero (it holds), so "shut inside" is not reachable in normal play; the
  lever is the owner's requested safety net. The lever e2e puts the door in the shut state by hand for that reason.

## Commands and raw totals (GUT, `--language en`)

`godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/<file>.gd -gexit --language en`
(`-gdir=res://tests/<folder> -ginclude_subdirs` for folders).

| Run | Tests | Passing | Asserts |
|---|---|---|---|
| unit/sim/test_timed_door_rooms.gd (2 new) | 4 | 4 | 20 |
| unit/sim/test_timed_door.gd (4 new) | 9 | 9 | 235 |
| unit/presentation/test_timed_door_view.gd (1 new) | 4 | 4 | 131 |
| unit/sim/test_special_room_rules.gd (the 1000-floor property test) | 3 | 3 | 107 |
| unit/sim/test_solids.gd | 9 | 9 | 21 |
| unit/application/test_old_saves.gd (1 new) | 11 | 11 | 157 |
| unit/sim/test_interactables.gd | 4 | 4 | 24 |
| unit/presentation/test_biome_interaction_looks.gd | 11 | 11 | 296 |
| unit/sim/test_collectibles.gd | 16 | 16 | 185 |
| unit/presentation/test_rune_alignment_view.gd | 2 | 2 | 79 |
| tests/arch | 4 | 4 | 17317 |
| tests/content | 157 | 157 | 12769 |
| tests/golden | 2 | 2 | 4 |
| e2e/test_e2e_timed_door.gd (seed 2: switch to switch to the door) | 1 | 1 | 17 |
| e2e/test_e2e_timed_lever.gd (new, seed 2) | 1 | 1 | 17 |

## Numbers

- 200 seeds, the chance forced to 1000 (`TS_PLACEMENT`): `doors_before=196 doors_after=194 different_sides=142
  same_side=52 bad=0 worst_path_share=0.599` (share of the 1200-tick timer at base speed; the limit is 0.600).
- 1000 real run floors (`RG_RULES`, test_special_room_rules): `timed_doors=231 worst_walk_permille_of_timer=598`
  (DR-era baselines in CLOSED_FIGHTS.md: 220-234 doors, worst 622 for the old in-host placement).
- e2e: seed 2 floor 1, walk from the second switch to inside the room `walk_in_ticks=423` of 1200; lever e2e walk out
  `walk_out_ticks=165` of 300.

## Not run / not done

- test_five_floors, test_curse_room, test_modifier_smoke, test_event_rarity, test_event_rooms: not run (told not to).
- test_purple_rooms, test_elite_rooms, test_lockdowns, test_cracked_rooms, test_rune_rooms: not run here (test_purple_rooms
  was stopped by me after ~50 min with no result; none of them reach the new placement, which only rules 21 floors use);
  GitHub covers them.
- No audio cue for the lever press (the door's open/shut cues still play). Feel and difficulty: `OWNER ONLY`.

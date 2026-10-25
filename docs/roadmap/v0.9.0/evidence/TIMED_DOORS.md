# v0.9.0 Steps IX and TD: the shared interactable and the timed doors (evidence)

Build: branch `v090-ixtd`, cut from `1214f0bf`. The Step IX commit is `8c77e190`. The Step TD commit is the one that
adds this file. Tests ran on top of IX with TD's changes in the working tree.
Machine: the owner's PC (Windows 11), Godot 4.7.2, Git Bash. No timings are claimed.

## What changed

- **IX.** `Interactables` (`src/sim/world/interactables.gd`, `World.interactables`) is a plain-data registry. Each
  entry has an id, a kind, a position, a reach, an enabled flag, a state, a ref and a press tick.
  - The interact press goes to the nearest enabled entry in reach. A tie goes to the lowest id.
  - The registry takes the last slot in `World.step`'s press order, after Rewards, Events, Shop, Gamble and the boss
    door. Those five were not moved: they keep their own reach and order.
  - The FA rune pylons are registry entries (`FinalApproach.register`/`press`/`sync_registry`).
  - `WorldReader.interact_prompt_key()` gives the one shared prompt (`InteractPromptHud`, FA's `FinalApproachHud`
    generalised; `Hud.interact`).
  - Saving: `Interactables` is in `WorldSnapshot.STATE_CLASSES` and `interactables` is in `ADDED_SINCE_V05`. A save
    from before IX re-syncs the pylons from its lit ones.
  - The registry is hashed only when it holds an entry.
- **TD, generation** (`TimedDoorRooms.mark`, `src/sim/map/timed_door_rooms.gd`, run from `TimedDoor.setup`):
  - It runs on `timed_door_permille` = 350 of floors (`data/map/floor.tres`; the draw comes from `map:timed_door`).
  - Only floors built under floor rules 10 get one (`RunState.FLOOR_RULES` 9 → 10). A floor saved under 1-9 is
    rebuilt without one.
  - The secret room is a dead-end room with one doorway. It is never the start hall, the boss room or its host, the
    portal room, the Overrun room, the shop, the curse room or an arena. It is also never a room that holds a reward,
    an event or the shrine.
  - The two switches are spawn spots in the room before it, at least 4 m apart.
  - The walk from either switch to the door (4-connected reach cells at 0.5 m clearance) is at most 60 % of
    900 ticks × base speed, which is 54 m.
  - The floor's walls and the `map` stream are unchanged.
- **TD, sim** (`TimedDoor`, `src/sim/world/timed_door.gd`, `World.timed`):
  - SHUT: the slab is a barrier from the floor's first tick.
  - Two switch presses, in either order, change SHUT to OPEN, with a 900-tick timer from the second press.
  - When the timer runs out, the door goes back to SHUT and both switches reset. If the hero is in the doorway or in
    the room at that moment, the door goes to HELD instead, and shuts once the hero is out.
  - The reward inside is an epic altar or a chest, 50/50 from `loot:timed_door`. The epic altar uses
    `Offers.roll_epic`.
  - The secret room has no spawn spots.
  - Puzzle calm: the switches' room is a calm room until the door first opens. While the hero is in it, the spawn
    clock runs one tick in four (`SpawnDirector`, `Interactables.spawn_clock_step`).
- **TD, presentation:**
  - `TimedDoorView` is a code stand-in slab and frame with a seal and rune notches, plus two rune switches.
    `ShopModels.SPECS` has `timed_door` (0.8×3×3 m) and `rune_switch` (0.7×1.3×0.7 m), so the owner's models drop in
    through the model manifest.
  - Beeps follow `beep_ticks(900)`: 62 beeps, the first gap 60 ticks, the last 6. Each beep flashes the switches'
    runes, the seal and the notches.
  - Sounds: `boss_door_opening` on opening, `timer_beep` on each beep (captioned `CAPTION_TIMER_BEEP`), and
    `boss_door_impact` plus the camera thud on the shut. A switch press plays `pylon_lock`.
  - The hidden room (`HiddenRoom`, `StageView.hidden_nodes`/`reveal_hidden`): its ground and its own walls are hidden
    and its decor and lights are stripped. Its reward is hidden and the minimap leaves it out (no fill, no door, no
    stub, not counted in the full map's fit) until the door first opens. Then a warm light comes on inside.
- **Strings:** `TIMED_SWITCH_PROMPT` "[E / X] Activate" / "[E / X] Activar", and `CAPTION_TIMER_BEEP`.
- **Hash fix:**
  - Step FA had moved `floor_index`, `floor_count` and the loop fields out of the boss flow's hash block. Normal
    floors stopped hashing them.
  - TD puts them back where they were before FA.

## Commands and raw summary lines

Command: `APPDATA=<own folder> godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gexit -gtest=<files>`
(or `-gdir=`).

IX, before its commit: test_interactables, test_final_approach, test_world_snapshot, test_state_hasher,
test_modifier_equivalence, test_replay_ground_plane, test_final_approach_view, test_layering, test_sim_purity:
```
Tests                42
Passing Tests        42
Asserts           21069
```
IX, the e2e and saves: test_e2e_final_approach, test_e2e_old_save, test_e2e_saves, test_old_saves:
```
Tests                12
Passing Tests        12
Asserts             211
```
TD: test_timed_door_rooms (the 1,000-seed property test), test_timed_door, test_timed_door_view:
```
    TIMED_DOORS| seeds=1000 placed_when_tried=988 natural_35pct=358 bad=0 worst_walk_m=54.0 budget_m=54.0
    TIMED_BEEPS| count=62 first_gap=60 last_gap=6
Tests                10
Passing Tests        10
Asserts             472
```
TD, the content, arch, golden, application and app folders, plus the touched sim and presentation files (this run
predates the hash fix; the re-run below covers the goldens and the hashed tests after it):
```
Tests               376
Passing Tests       376
Asserts           502171
```
TD after the hash fix: test_ascension, test_timed_door, test_timed_door_view, test_state_hasher,
test_replay_ground_plane, test_modifier_equivalence, test_world_snapshot, test_final_approach, test_interactables,
test_floor_plan, test_old_saves, test_boss_door_press:
```
Tests                71
Passing Tests        71
Asserts           10655
```
TD e2e: test_e2e_old_save, test_e2e_saves, test_e2e_run_flow, test_e2e_final_approach, test_e2e_minimap,
test_e2e_curse_room, test_e2e_timed_door. The list also named test_e2e_boss_door, but no file has that name, so
nothing ran for it:
```
    TIMED_E2E| seed=3 walk_in_ticks=206 timer=900
Tests                10
Passing Tests        10
Asserts             503
```
Lint: `gdformat --check src scripts tests` printed "1101 files would be left unchanged". `gdlint src scripts tests`
printed "Success: no problems found".

## Goldens

- `replay_ground_plane.json`, `modifier_equivalence.json` and `export_smoke_hash.txt` are kernel or attack worlds with
  no floor, so they are unchanged.
- No floor or generation golden exists in the repo, so none moved.
- Run seeds 20261006-20261010 and 20261022 have no timed door on floor 1 (a floor-plan scan). The e2e's STAGE_SEED
  floors are unchanged.

## Not done / notes

- The shot is NOT YET RUN.
- `timer_beep.wav` was rendered by a pure-Python copy of `generate_sfx.py`'s pipeline because numpy is not installed
  on this machine. `generate_sfx.py` holds the recipe (`s_timer_beep`). A later numpy run may rewrite the file with
  tiny sample differences.

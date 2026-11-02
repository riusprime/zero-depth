# v0.10.5 O17 evidence: the Training Room (P17)

- **Owner line (2026-11-01, theory audit P17):** "let's add a new room at the hub that serves this purpose, at the
  bottom that is empty, make it a bit smaller". Overnight mode: **"Pick and build"**; every call below is a starting
  value for the owner to keep or change.
- **Build:** branch `v0105-o17`, measured on the working tree over `56eebce6` with the O17 changes uncommitted; the
  step's commit follows this file.
- **Machine:** the owner's PC (i7-10700K, RTX 3060), Godot 4.7.2. Tests headless; the shot on the GPU, off screen.
  No timing is claimed.

## G2: the layout (options and the pick)

| Option | What | For | Against |
|---|---|---|---|
| **A (picked)** | A door in the hub's south rim (the empty bottom, below the spawn) with a short lane; walking down it loads a separate, smaller room (2 x 2 cells, about 27 x 23 m against the plaza's 32 m) behind the loading cover, lit as the hub (Ruins light); its exit pad at the room's top corner walks back to the hub's spawn | The room runs the real combat World (enemies, cards, heat, the dummy) the Playground already proved; the hub's World stays combat-free; the room can be as busy as needed | A short cover fade each way; the room is the Ruins floor and walls, not the plaza's paving |
| B | A training corner inside the plaza's empty south half (the hub's World gains combat) | No load; truly "in" the hub | The hub's World and HubView have no enemies, shots or damage numbers: a large change to the hub; fights next to the stations; not "a room" |
| C | A station at the south rim whose panel opens the Playground | Least code | Not a room, no walk; the Playground is a dev tool |

**Pick: A.** It is the only one that is both a room reached by walking from the hub and the real combat sim, and it
keeps the hub's World the calm plaza it is.

## What was built

- **The hub:** the south wall segment gives way to a door (`HubDefinition.training_door_half_m` 1.4 m, a 2.6 m lane;
  `rune_ring.tres`): low stone fillers and two posts in the slot, the lane walled low with a blue glow at its end, and
  "Training Room" over the hero near it. Walking to the lane's end (`HubLayout.in_training_door`) opens the room
  (`HubSession.training_requested` -> `TrainingFlow.enter`, behind the cover). From the spawn: 0.92 s straight down (test_hub).
- **The room** (`TrainingScenario`, `TrainingRoom`): the Playground's World in 2 x 2 cells, no ice, the hub hero's
  weapon (`Wardrobe.build_of`), the hero's HP floored at 1 (`World.player_hp_floor`, used only here: a killing blow
  leaves 1 HP; the Playground's revive stays as a backstop), the endless dummy in the middle (takes every hit, its HP
  comes back before each tick, never dies), the run's HUD and the DPS meter (the last 5 s, the average, the sources).
- **The terminal** (a stone lectern with a lit screen by the top-right wall, solid; E / pad X at it opens the
  `TrainingPanel`, the room waits while it is open):
  - Enemy (the kinds the Codex has met) and Count (1 / 3 / 8), Spawn: on a ring round the dummy, on the far side from
    the door (8: a full ring);
  - Clear enemies (the dummy stays);
  - Weapon (Blade / Gun; a locked Blade isn't offered): the room is built again with it;
  - Wand card (the wand cards the Codex has seen, the weapon's own and the shared ones) and Level (1-5; a card whose
    cap is lower is held at its cap), Add card; Remove last card;
  - Wand order: the Build page (as from the pause menu) to put the cards in any order;
  - Reset room (the room built again: no cards, no enemies, full HP, the DPS meter at 0); Back.
  Every choice is an `OptionCycler` (left / right or press), so keyboard, mouse and pad work through the focus.
- **The way back:** a blue pad between two posts at the room's top corner; standing on it returns to the hub
  (behind the cover). The pause menu's last row (To the Rune Ring) also returns; its Restart resets the room.
- **Nothing counts:** the room never attaches the run's recorders (`CodexRecorder`, `AchievementTracker`,
  `MetaHooks`, `RunSaver`), as the dev Playground. Proved by `test_nothing_counts` (the profile, its Codex,
  achievements, records, unlocks and fragments byte-equal after a session that kills eight Chargers and takes a card).
- **Strings:** 24 `UI_TRAINING_*` keys, en and es.

## Commands and raw output

Import first, then the touched tests and the e2e that reach them (one run):

```
APPDATA=$(mktemp -d) godot --headless --path . --editor --import --quit
APPDATA=$(mktemp -d) godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/app/test_training_room.gd,res://tests/e2e/test_e2e_training_room.gd,res://tests/unit/application/test_hub.gd,res://tests/unit/presentation/test_hub_view.gd,res://tests/e2e/test_e2e_hub.gd,res://tests/unit/application/test_playground.gd,res://tests/e2e/test_e2e_playground.gd,res://tests/content/test_locale_coverage.gd,res://tests/content/test_content_valid.gd -gexit
```

Raw output (the per-file lines and the totals; GUT prints each test name):

```
res://tests/unit/app/test_training_room.gd
* test_the_room_is_a_bit_smaller_than_the_plaza
    O17: the Training Room is 27.2 x 22.8 m; the plaza 32.0 m across
* test_the_hero_cannot_die_there
* test_a_run_world_has_no_hp_floor
* test_the_dummy_takes_hits_counts_dps_and_never_dies
* test_the_terminal_offers_only_what_the_codex_met
* test_spawn_points_stand_in_the_room_away_from_the_door
* test_the_terminal_spawns_clears_grants_and_removes
* test_nothing_counts
8/8 passed.
res://tests/e2e/test_e2e_training_room.gd
* test_walk_in_spawn_a_charger_take_a_card_and_walk_out
* test_the_pad_opens_the_terminal_and_spawns_three
2/2 passed.
res://tests/unit/application/test_hub.gd
* test_the_rune_ring_is_valid_content
* test_a_broken_hub_is_caught
* test_flag_grammar
* test_the_plan_turns_onto_the_screen
* test_stations_are_found_where_the_hero_stands
* test_the_gate_is_a_wall_until_it_opens
* test_flags_read_the_profile_and_never_write_it
* test_the_hub_world_walks_the_hero_and_holds_it_in
* test_the_south_door_leads_down_its_lane_to_the_training_room
    O17: the spawn to the Training Room's door: 0.92 s
* test_walking_times_from_the_spawn_stay_short
10/10 passed.
res://tests/unit/presentation/test_hub_view.gd
* test_every_station_and_the_machine_are_drawn
* test_the_glows_are_layered
* test_focus_brightens_the_station
* test_the_runic_stone_is_dark_locked_and_violet_awake
* test_the_states_and_hooks_change_the_hub
* test_the_shelf_lights_each_find_and_the_keystone_waits
* test_the_owners_models_are_drawn
* test_the_owners_hub_pieces_dress_the_ring
* test_the_walk_into_the_portal
* test_the_small_menu_and_the_end_panel_rows
10/10 passed.
res://tests/e2e/test_e2e_hub.gd
* test_the_small_menu
* test_play_walks_to_the_portal_machine_and_starts_a_run
* test_the_pick_walks_the_hero_up_into_the_portal
* test_a_press_skips_the_walk
* test_each_station_opens_its_panel
* test_the_hub_pause_goes_to_the_main_menu
* test_after_a_run_restart_in_one_press_or_the_hub
* test_the_hub_in_spanish
* test_the_hub_never_touches_the_run_save
9/9 passed.
res://tests/unit/application/test_playground.gd
* test_one_room_is_a_single_walled_room_of_four_by_four_cells
* test_one_room_is_the_same_for_a_seed
* test_the_room_spawns_nothing_and_keeps_the_player_inside
* test_the_wand_has_every_slot
* test_a_biome_with_a_surface_lays_it_in_the_room
* test_an_endless_dummy_gets_its_hp_back_before_the_next_tick
* test_a_dummy_with_a_set_hp_dies
* test_nothing_is_placed_in_a_wall_or_outside_the_room
* test_queued_commands_land_at_apply_pending
* test_any_enemy_and_any_boss_spawn_at_a_point
* test_delete_removes_what_is_under_the_point_never_the_player
* test_deleting_a_boss_takes_it_out_of_the_boss_store
* test_clear_keeps_the_dummies_unless_asked
* test_a_wand_card_goes_in_at_its_level_and_comes_out
* test_a_full_wand_takes_no_new_card
* test_an_ability_goes_in_at_a_level_and_down_again
* test_the_weapon_stays
* test_a_stat_card_goes_in_and_out
* test_god_mode_keeps_the_player_unhurt
* test_the_catalog_lists_every_group_and_marks_what_is_held
* test_the_starting_weapon_is_not_in_the_catalog
* test_the_player_comes_back_after_a_death
22/22 passed.
res://tests/e2e/test_e2e_playground.gd
* test_the_playground_from_the_menu
1/1 passed.
res://tests/content/test_locale_coverage.gd
* test_every_row_has_en_and_es
* test_every_key_literal_in_src_exists
* test_generated_option_keys_exist
* test_content_name_keys_exist
* test_tscn_text_properties_are_keys
* test_form_card_lines_exist
6/6 passed.
res://tests/content/test_content_valid.gd
* test_all_data_validates
* test_manifest_hash_is_stable_across_loads
* test_player_compiles_to_ticks
* test_compiled_player_matches_the_kernel_starting_values
* test_the_combo_compiles_to_the_four_slashes
* test_the_run_validates_and_catches_bad_values
* test_the_schemas_and_the_compiler_name_the_same_ids
7/7 passed.
Tests                75
Passing Tests        75
Asserts            6190
---- All tests passed! ----
```

The goldens and the arch lint (the sim changed: `World.player_hp_floor`, `Damage._apply`, `Solids.Kind.TERMINAL`):

```
APPDATA=$(mktemp -d) godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/golden,res://tests/arch -ginclude_subdirs -gexit
res://tests/golden/test_replay_ground_plane.gd
* test_replay_matches_every_checkpoint
* test_two_runs_in_one_process_agree
2/2 passed.
res://tests/arch/test_layering.gd
* test_no_reference_crosses_a_layer_the_wrong_way
* test_rules
2/2 passed.
res://tests/arch/test_sim_purity.gd
* test_sim_sources_are_pure
* test_the_lint_catches_planted_tokens
2/2 passed.
Tests                 6
Passing Tests         6
Asserts           19025
---- All tests passed! ----
```

Lint (whole tree):

```
gdformat --check src scripts tests && gdlint src scripts tests
1558 files would be left unchanged
tests\e2e\test_e2e_wand_build.gd:84: Error: Max allowed line length (120) exceeded (max-line-length)
Failure: 1 problem found
```

The one lint error is not this step's: it is in `60334911` (D1), already on the base. Not fixed here (another step's file).

## Shot

Command (a tool, not a test: it starts the room and places the hero directly):

```
APPDATA=$(mktemp -d) godot --path . --audio-driver Dummy --resolution 1920x1080 --position -10000,-10000   -s scripts/shots/training_room.gd
training_room: C:/Users/extri/Desktop/zerodepth/wt-o17/build/shots/v0.10.5/o17/en_1_hub_south_door.png
training_room: C:/Users/extri/Desktop/zerodepth/wt-o17/build/shots/v0.10.5/o17/en_2_training_room_panel.png
```

Looked at both: the room (`en_2_training_room_panel.png`) shows the terminal's panel open on the left over the room
(Enemy Charger, Count 1, Spawn, Clear enemies, Weapon, Wand card, Level, Add card, Remove last card, Wand order, Reset
room, Back), the lectern lit blue by the top-right wall, the exit pad's glow at the top corner, the dummy in the middle
with three Chargers spawned round it, the hero's HUD and the DPS meter. The hub (`en_1_hub_south_door.png`) shows the
south door's posts in the low rim and "Training Room" over the hero by it. The shots are in `build/` (not tracked).
Feel and look: OWNER ONLY.

## Picks for the owner

1. Layout A (a separate room behind a south door, a cover fade each way), not a corner of the plaza.
2. Size 2 x 2 cells (27.2 x 22.8 m on this seed) against the plaza's 32 m.
3. The room's look: the Ruins floor and walls in the hub's light, the terminal and the exit in the hub's stone and
   blue (stand-in pieces: no owner model; the door's posts and fillers in the south rim are stand-ins too).
4. The hero can't die: HP floors at 1 (no refill); Reset room refills.
5. Counts 1 / 3 / 8; spawns on a 4.5 m ring round the dummy, away from the door.
6. Cards offered: wand cards only (no abilities, passives or stat cards), only those the Codex has seen; levels 1-5.
7. Enemies offered: only kinds the Codex has met; no bosses.
8. Changing the weapon rebuilds the room (cards and enemies are cleared).
9. The DPS meter shows always in the room (the Playground's: last 5 s, average, total, sources).
10. The room starts with the hub hero's weapon (the last one picked at the Portal Machine).

# v0.9.5 Step AQ: event altars show up on about a third of floors, at most twice a run, never the same one twice

Base build: 72becf24 (branch `v095-aq`, cut from the worktree HEAD, then `claude/v095-feedback` merged) plus this step's commit. Machine: owner PC (i7-10700K, RTX 3060), Godot 4.7.2 headless.

## Changes
- `data/event_rules/floor.tres`: rooms_min/rooms_max 0/1; new `event_floor_chance_permille = 300`, `events_max_per_run = 2` (EventRulesDefinition, EventRules, EventCompiler; validated 0..1000 and >= 0). `data/special_rooms/event.tres` count_min/count_max follow (0/1; the source check requires it).
- `Events.pick_rooms(..., done)`: when `events_max_per_run > 0`: none once the run has `done` event rooms; else one room on 30 % of floors (the first draw of `map:event`). Deep floors use the same 30 %. `events_max_per_run = 0` keeps the old 1-2 draw.
- `World.events_seen` (event indices placed in common event rooms this run): carried (RunCarry.FIELDS), so it spans floors, the run save and Ascension loops; excluded from the event draw (never the same event twice); listed in WorldSnapshot ADDED_SINCE_V05 (an old save loads with none). Not hashed.
- RunState.FLOOR_RULES 18 (new const FLOOR_RULES_V090_CF2 = 17): a floor saved under rules 1-17 is rebuilt with its old 1-2 event rooms (FloorScenario.rare_events_of, EventCompiler.setup `rare_events`). Curse room, card altars, chests, shrines, fountains and event content: unchanged.
- Tests: new `tests/unit/sim/test_event_rarity.gd` (7); `test_event_rooms.gd` keeps testing the old draw (its rules set back to 1-2, chance 1000, no cap); `test_event_validation.gd` expects 0/1, 300, 2; `test_old_saves.gd` +1 test. Helpers: `EventLab.world(..., rare := false, extra_carry := {})` (default: the old 1-2 rooms so the event tests keep a pedestal); run_lab, save_lab and shrine_lab pass `rare_events_of(run)`.
- Goldens: no digest or hash changed.

## Commands and results
- `gdformat --check` / `gdlint` on every touched file: clean.
- `... -gtest=res://tests/unit/sim/test_event_rarity.gd`: Tests 7, Passing 7, Asserts 501 (1332 s with other jobs running). Measured:
  - event-room rate over 2000 floors: 587 (29.3 %), never more than 1 on a floor;
  - most event rooms in a 5-floor run over 200 runs: 2;
  - common event rooms over 40 runs x 5 floors (real worlds): 51, no repeat, no run above 2.
- `... -gdir=res://tests/content,res://tests/arch,res://tests/golden -ginclude_subdirs`: Tests 163, Passing 163, Asserts 29198 (a first run failed 7 on the special_rooms/event.tres counts; fixed above).
- `... -gtest=test_events, test_event_rooms, test_event_log, test_arenas, test_plaques, test_old_saves, test_e2e_events, test_e2e_saves`: Tests 61, Passing 59, Failing 2, Asserts 4655/4663. Both failures are in test_old_saves.gd (`test_a_v0_6_1_blade_save_maps_each_card_in_pick_order`, `test_a_v0_6_1_gun_save_from_its_carry_maps_and_levels_up_duplicates`) with `World.heat.fill_rem: not in the snapshot`: the HT step's new HeatState field, not in ADDED_SINCE_V05; not touched by this step. Everything else, the new old-save test and both e2e files included, passed.
- Not run: test_five_floors, test_curse_room, test_modifier_smoke (CI).

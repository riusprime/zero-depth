# v0.9.0 Step DP: the Purple Portal is earned (evidence)

Build: branch `v090-dp`, cut from `897725f7` (the FV head). The Step DP commit is the one that adds this file. Tests
ran with DP's changes in the working tree.
Machine: the owner's PC (Windows 11, Spanish OS locale), Godot 4.7.2, Git Bash. No timings are claimed.

## What changed

- **Generation** (`PurpleRooms.mark`, `src/sim/map/purple_rooms.gd`, run from `PurpleRunes.setup` last in
  `FloorPlan.add_secrets`, after the timed door, the rune puzzle and the destructibles):
  - The chance is `SecretsDefinition.purple_floor_permille` = `[0, 500, 1000, 0, 0]` (`data/secrets/secrets.tres`),
    floor 1 first, within a loop, while the loop has had none (`PurpleRunes.chance`; `RunState.purple_floors` records
    the run floors that held one, saved by `RunSaver` as `run.purple_floors`). So: never floor 1, 50 % on floor 2
    (the `map:purple_runes` sub-stream of the floor seed), certain on floor 3 when floor 2 had none, never both,
    never floors 4-5 (the lead's reading, a data value), the same again on each loop. 0 on a floor that offers no
    Deep gate.
  - The room: never the start hall, the boss room, the portal room, the Overrun room, the shop's room, the curse room,
    an arena, a secret room (timed door, rune puzzle, cracked wall) or a secret's host, and never a room the main path
    needs to cross (the boss room stays reachable from the start hall without it). Rooms of 2 x 2 cells or more
    first (`MIN_CELLS` 4), drawn from the sub-stream; when no big room fits, the biggest that fit.
  - The dais: the room's centre, else its spawn spot nearest the centre, 1.2 m clear of every wall, 3.0 m from
    rewards, events, the shrine, the puzzles' pieces, the shop and the containers, 2.0 m from the doorway approaches,
    on the open floor reached from the doorways. Not solid. The floor's walls and the `map` stream are unchanged.
  - `RunState.FLOOR_RULES` 11 → 12 (`FLOOR_RULES_V090_RA` = 11). A floor saved under rules 1-11 keeps the old
    behaviour (`PurpleRunes.legacy_deep_gate`): the Deep gate on every floor before the last, no purple room.
- **Sim** (`PurpleRunes`, `src/sim/world/purple_runes.gd`, `World.purple`):
  - The dais is one shared interactable (`Interactables.Kind.PURPLE_DAIS`, reach 1.8 m). Its prompt reuses FA's
    pylon string `APPROACH_PYLON_PROMPT` ("[E / X] Awaken" / "[E / X] Despertar"); no new string.
  - One press awakens it for good (the entry is disabled, `lit`, `lit_tick`) and earns the Purple Portal
    (`PurpleRunes.earn`): `BossFlow.routes` is set and the Deep gate's footprint (its spot placed at build by
    `Routes.place_deep_gate`, as before) is added as a barrier. The boss's death then opens both gates
    (`PORTAL_OPENED` amount 1); taking the Deep gate works as before (a Deep floor next). Awakened after the boss
    died, the Deep gate opens at once. Unawakened: no Deep gate at all on that floor.
  - `FloorScenario.build` places the Deep gate's spot as before but adds its footprint and sets `routes` only on a
    legacy floor.
  - Saving: `PurpleRunes` is in `WorldSnapshot.STATE_CLASSES` and `_make`, `purple` in `ADDED_SINCE_V05`; the Deep
    gate's footprint is one of `Secrets.slabs` / `slabs_up` for the save's wall check. Hashed only when present.
  - Deep floors: `SpawnDirector.deep_elite` is gone (no elite in each room's first pack). The ×1.25, the epic altar,
    the extra chest, the Deep-only event, the threat and the violet look stay. `World.deep_elite_rooms` stays for the
    saves that hold it.
- **Presentation:**
  - `PurpleRuneView` (`src/presentation/world_view/purple_rune_view.gd`): the dais through `ShopModels` as
    `purple_rune_dais` (`SPECS`: 1.7 x 0.55 x 1.7 m) when the manifest lists it, else a code stand-in (a two-tier
    octagonal plinth under a floating faceted violet crystal); a ring of 6 purple ritual sigils (`fx_cast_sigils`
    through `FxTextures.sigil_material`, as the curse room; violet diamonds without the sheet), dim (0.12).
  - Awakened: the runes light one every 0.15 s; the view holds the rig's vibration (`IsoRig.vibrate_to`) rising to
    0.55 over the 0.9 s sequence, then one `IsoRig.thud(0.6)` as the last one lights; the crystal and a violet light
    swell. A floor resumed awake shows them lit, with no vibration.
  - `WorldViewRoot` builds the Deep gate's view where it may still be earned (`WorldReader.deep_portal_site`); it stays
    sealed (unseen) until it opens. The stage keeps decor and crystals off the dais.
  - Sound: `purple_runes` (new placeholder, `s_purple_runes` in `scripts/audio/generate_sfx.py`: six rising FM chimes
    over a swelling drone, then a deep thump with an echo; 2.0 s), rendered with numpy by the real recipe (only this
    file written, its manifest row added by hand); `data/audio/cues/purple_runes.tres`; credits rebuilt (103 files).
    The Purple Portal's own look is unchanged.

## Commands and raw summary lines

Command: `APPDATA=<own folder> godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gexit -gtest=<files>`.

Sim: test_purple_runes, test_purple_rooms (the 1,000-seed property test, floors 2 and 3 alternating, chance forced):
```
    PURPLE_CHANCE| floor2 seeds=2000 drawn=977
    PURPLE_RUNS| runs=16 on_floor2=9 on_floor3=7
    PURPLE_ROOMS| seeds=1000 placed=998 big=698 big_possible=698 bad=0
Tests                11
Passing Tests        11
Asserts             177
```
View and e2e (after the last edits): test_e2e_purple_portal, test_routes_view, test_portal_oval:
```
    PURPLE_E2E| seed=1 room=6 cells=12 vibration_peak=0.96
Tests                17
Passing Tests        17
Asserts             493
```
test_e2e_purple_portal, test_e2e_routes, test_e2e_difficulty (the first run, before a print was added):
```
Tests                 3
Passing Tests         3
Asserts             294
```
Updated sim tests: test_routes, test_world_snapshot, test_deep_bite:
```
Tests                32
Passing Tests        31
Failing Tests         1
Asserts           54477/54478
```
The one: test_deep_bite's `test_the_deep_event_offers_its_two_choices` ("Abismo susurrante" expected "Whispering
Deep"), the Spanish OS locale (as in RA/DX).

Sim and application seams (first run; test_routes and test_world_snapshot were then updated, above): test_routes,
test_after_boss, test_deep_bite, test_catch_up, test_portal_clearance, test_loop_deep_ease, test_ascension,
test_world_snapshot, test_interactables, test_old_saves, test_run_saves, test_ascension_saves:
```
Tests               103
Passing Tests        99
Failing Tests         4
Asserts           58515/58540
```
The four: test_routes x2 and test_world_snapshot x1 (they assumed a Deep gate on floor 1; fixed, 31/32 above) and
test_deep_bite's locale line. test_old_saves, test_run_saves, test_ascension_saves, test_after_boss passed.

Presentation, content, arch, goldens, dev panel: test_purple_rune_view, test_routes_view, test_floor_receiver,
test_portal_oval, test_deep_look, test_shard_dressing, test_ascension_views, test_audio_director, test_audio_assets,
test_content_valid, test_credits_licences, test_locale_coverage, test_model_manifest, test_layering, test_sim_purity,
test_dev_master_panel, test_replay_ground_plane, test_state_hasher, test_modifier_equivalence:
```
Tests               109
Passing Tests       103
Failing Tests         6
Asserts           53859/53867
```
The six: test_routes_view x2 and test_portal_oval x3 (floor 1's Deep gate; fixed, 17/17 above) and test_deep_look's
"CAMBIO DE FASE" (the Spanish OS locale).

e2e: test_e2e_run_flow, saves, old_save, portal, after_boss, ascension, rune_alignment, timed_door, cracked_wall,
wand_build:
```
    TIMED_E2E| seed=2 walk_in_ticks=153 timer=900
Tests                16
Passing Tests        13
Failing Tests         3
Asserts           510/513
```
The three: test_e2e_run_flow ("floor 1 opens both portals"; updated, then `Tests 3, Passing Tests 3, Asserts 64`),
and test_e2e_rune_alignment ("this floor has a rune puzzle", run seed 6) and test_e2e_cracked_wall ("this floor has
a cracked wall"). Those two are not DP's: their fixed seeds' floor 1 holds neither secret under the old rules either
(a floor-plan scan of seeds 2, 3, 6 at floor rules 11 and 12 gave the same timed, rune and crack rooms, -1 for rune
and crack); FV's floor sizes moved them. Not fixed here.

Floors built with the save lab (they now hold purple rooms on floors 2-3): test_arenas, test_arrival, test_boss_gates,
test_curse_totals, test_gamble, test_intensity_director, test_shop_placement, test_shop_rooms, test_five_floors,
test_rune_alignment, test_timed_door, test_shop_stall_view, test_view_build_queue, test_procedural_wall,
test_rune_alignment_view, test_camera_vibration, test_floor_receiver:
```
Tests               152
Passing Tests       149
Failing Tests         2
Asserts           92781/92786
```
The two, not DP's: test_arrival's `test_a_swap_opened_mid_arrival_waits_for_the_landing` ("the slots are full": the
wand's slots, nothing DP touches) and test_rune_alignment's `test_beside_a_timed_door_when_both_fit` ("a floor with
both": `RuneLab` searches run floors 1 for both secrets, decided by the layout alone, which DP does not change).
test_curse_room (the slow seed loop) was not run.

Lint: `gdformat` and `gdlint` on every touched .gd: "Success: no problems found".

## Goldens

- `replay_ground_plane.json`, `modifier_equivalence.json` and the hasher's fixtures are worlds with no floor: they
  pass unchanged. No golden moved.

## Decided by me (simplest readings)

- The Deep gate's spot is still placed at build on every floor before the last (so the floors' walls are as before);
  its footprint becomes a wall only once earned, while the hero is in the purple room (never the boss room).
- "Not required to cross" read as: the boss room stays reachable from the start hall without the room. Big rooms are
  mostly on the main path, so 30 % of floors get the biggest small room that fits (`big=698` of 998, and every floor
  that had a big candidate got one).
- A room holding an event pedestal may hold the dais (3 m apart); with them excluded too, about half the rooms were
  small.
- Awakened after the boss died: the Deep gate opens at once (no "form" growth from the boss's death: it pops in).
- The Deep floor's elite is removed on every floor, including a Deep floor resumed from a pre-DP save.
- `test_e2e_routes` now proves floor 1 opens the gate alone; the Deep route's floor checks moved to
  `test_e2e_purple_portal` (floor 3 Deep). `test_e2e_difficulty` walks into the normal gate (floor 2's catch-up);
  the Deep floor's T + 1 and haze are in `test_e2e_purple_portal`. `test_routes`, `test_routes_view` and
  `test_portal_oval` earn the Deep gate with `PurpleRunes.earn` (labelled TEST HELPER).
- The model id `purple_rune_dais` is added to `ShopModels.SPECS` (MI2 may touch the same table: a likely merge point).

## Not done

- The shot is NOT YET RUN. The minimap shows no icon for the purple room (the Deep gate's icon appears once earned).

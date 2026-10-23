# v0.9.0 Step MP: Rune Fragments and unlocks (evidence)

Build: branch `v090-mp`, cut from `0595c566` (the local `claude/world-combat-v090` head). The Step MP commit is the one
that adds this file. Tests ran with MP's changes in the working tree.
Machine: the owner's PC (Windows 11), Godot 4.7.2, Git Bash, own `APPDATA`. No timings are claimed.

Owner lines: Q28 "the most broken could be unlocked, maybe 2 of them"; then (PLAN "Owner decisions", row
`NB, EL, HB, CL, BR, MP`) "void unlocked when traveling through a purple portal, lance is unlocked by default"; RB:
robes Night, Canyon, Frost, Moss bought with Rune Fragments, Cream and Ash free. PD-06: sideways only.

## What changed

- **Content:** `data/meta/rune_fragments.tres` (`RuneFragmentsDefinition`, category `rune_fragments`; in the dev
  panel's Economy group): the sources and `portal_unlocks = [gun_void]`. `RobeDefinition.price` (25 on Night, Canyon,
  Frost, Moss; a robe that isn't free must have a price > 0, validated). All starting values (OWNER_QUESTIONS 14-16).
- **Sim:** `FragmentTable`, `RuneFragments` (pure; reads the floor's own state, no new world state):
  boss beaten (BossFlow state OPEN or later) 3, floor cleared (portal taken) 2, each secret found (timed door opened,
  rune puzzle solved, cracked wall broken, purple runes awakened) 2, the Purple Portal taken (route DEEP) 3, the final
  boss 10, a collectible 1 (`RuneFragments.add_collectibles`, CL's hook). `RunState.fragments_done` (finished floors,
  added in `finish_floor`), `RunState.fragment_table` (null: earns none, as goldens and sims), `RunState.locked_cards`.
  `World.locked_items` (indices; `ItemPool.usable` refuses them, so every draw does: altars, chests, shop, events,
  cores, the boss's tier). Hashed only when non-empty; in `WorldSnapshot.WORLD_KEPT` (loadout: FloorPlan rebuilds it).
- **Saves:** `RunSaver` writes `run.fragments` and `run.locked` only when non-zero / non-empty; an older payload reads
  as 0 and nothing locked (an old run in progress keeps the Void in its pool). No payload version change.
- **Profile:** `ProfileStore.PROFILE_VERSION` 1 -> 2, a `progress` section (`fragments`, `earned`, `portal`);
  `_migrate`: a version-1 profile loads with 0 and the portal not travelled (the Void locked).
- **App:** `FloorPlan.of_profile` locks `portal_unlocks` for a new run while the profile hasn't travelled;
  `FloorPlan.build` sets the run's `fragment_table` (new run and Continue) and resolves `World.locked_items`.
  `MetaHooks` (main.gd unchanged in length, two lines edited): `finish_floor` -> when the gate taken was the Purple
  Portal, the profile records it, the run's locks are emptied (the Void is in the offers from the next floor) and a
  toast "FORM UNLOCKED / The Void" shows once; `recap` -> the end panel's recap banks the run's fragments into the
  profile and adds the balance. A tweaked run (dev-panel balance edits) banks and unlocks nothing.
- **Presentation:** run summary line "Rune Fragments: +N (now M)"; `ProgressionPanel` at the hub's Progression
  Station (the stand-in is gone): the balance, a line saying robes are a colour only, one row per robe (swatch, name,
  price or "owned"), the Void's unlock line, a status line (bought / not enough / already yours), Back. Buying calls
  `MetaProgress.buy_robe` -> `Wardrobe.unlock_robe`, saved at once; the Wardrobe then offers the robe. The toast takes an
  optional header key. 13 strings, en + es.
- Nothing sold is a stat (PD-06); the station lists only the four robes (the PLAN approves no other unlock yet).

## Commands and raw summary lines

Command: `APPDATA=<own folder> godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gexit -gtest=<files>`
(or `-gdir=... -ginclude_subdirs`). Import first: `godot --headless --path . --editor --import --quit` (exit 0, no
errors). Lint: `gdformat --check` + `gdlint` on every changed or new .gd: "Success: no problems found".

New tests (test_meta_progress, test_rune_fragments, test_progression_panel):
```
Tests                16
Passing Tests        16
Asserts              93
```

Regression batch (test_items, test_gun_pool_order, test_card_pool_reach, test_void, test_shot_rate_all_forms,
test_attack_slots, test_old_saves, test_run_saves, test_world_snapshot, test_state_hasher, test_layering,
test_sim_purity, test_wardrobe, test_hub, test_hub_view, test_codex, test_achievements and the three new files):
```
Tests               180
Passing Tests       180
Asserts           25415
```

`-gdir=res://tests/content,res://tests/unit/debug -ginclude_subdirs`:
```
Tests               171
Passing Tests       171
Asserts           12499
```

e2e (test_e2e_rune_fragments, test_e2e_hub, test_e2e_wardrobe, test_e2e_purple_portal, test_e2e_run_flow,
test_e2e_old_save, test_e2e_void):
```
Tests                18
Passing Tests        18
Asserts             333
    MP_E2E| fragments=14
```
(`fragments=14`: the save's 4 from floor 1, plus floor 2's purple runes 2, its boss 3, the floor 2 and the Purple
Portal 3.)

Not run locally: the full suite (GitHub, per CLAUDE.md), the seams (the lead's).

## The e2e (main.tscn, real input only)

- `test_a_run_banks_fragments_and_the_station_sells_a_robe`: a floor-2 save holding 4 fragments, continued (Enter);
  the hero stands still and dies; the summary shows "+N (now M)" and the profile holds M; Down + Enter to the hub;
  E at the Progression Station; Enter buys Night (price spent, row "owned", status line); Down + Enter on Canyon:
  "not enough"; Esc; E at the Wardrobe, Right x2: Night, unlocked, worn by the hub's hero.
- `test_the_purple_portal_unlocks_the_void`: seed 1's floor-2 save on a profile that never travelled (the run holds
  `gun_void` locked; floor 2's `locked_items` has it); the stick walks to the dais, E; the boss door, Kill boss (dev
  panel); the stick walks into the Purple Portal; floor 3: the profile records it, the run's lock is gone, floor 3
  locks nothing, the toast `unlock_void` is up or queued.
- test_e2e_hub now opens the Progression Station's own panel and closes it with Esc.

## Shots (GPU, 1920x1080; `godot --path . --audio-driver Dummy --resolution 1920x1080 -s scripts/shots/mp_shots.gd`)

`mp_shots/en_1_run_summary.png`, `mp_shots/es_1_run_summary.png` (a floor-2 death, +9, balance 47);
`mp_shots/en_2_progression_station.png`, `mp_shots/es_2_progression_station.png` (Canyon owned, Night just bought,
22 left). Whether they read well: OWNER ONLY.

## Goldens

None changed: `World.locked_items` is hashed only when non-empty, and only a run started from a profile locks
anything (`FloorPlan.new_run`, which goldens and sims use, locks nothing; tested).

## Open (OWNER_QUESTIONS 14-16)

The fragment amounts, the robe prices, old profiles locked (vs grandfathered), and the Wave left in the pool from the
start. In Spanish the run's shards are already "Fragmentos" ("Fragmentos: 0" on the summary) next to "Fragmentos de
Runa": worth a look in the playtest.

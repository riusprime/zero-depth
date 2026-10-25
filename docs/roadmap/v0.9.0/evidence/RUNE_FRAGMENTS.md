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

---

# v0.9.0 Step MP2: robe prices and the two epic robes (evidence)

Owner (PLAN "Owner decisions" MP2, two rows, 2026-10-24), and through the lead the same day (verbatim): "tel the agent
that the hollow crown robe if it has the red eyes it should not have the blue square"; "that's only for the black one
the white epic one keeps the square"; "and the black one should also modify the attack color to a purle violet kind
of attack". Machine: the owner's PC (i7-10700K, RTX 3060), Godot 4.7.2, Windows, own `APPDATA`. Base: `66de1082`
(the tests below ran on the working tree that became the MP2 commit).

## What changed

- **Prices (data):** Night, Canyon, Frost, Moss: `price = 75`, `price_step = 25` (`RobeDefinition.price_step`). The
  price now is `MetaProgress.price_of(repo, profile, robe)`: the first price plus one step per ladder robe owned, so
  the four cost 75, 100, 125, 150 in the order bought, whichever comes first; every unbought robe shows the next
  price. `MetaProgress.buy_robe(repo, profile, robe)` pays that. Fragment sources unchanged.
- **Two epic robes (data, 250 each, `epic`, sideways PD-06):** `robe_fallen.tres` (`hidden`: "???" until bought,
  `style = &"fallen"`, near-black) and `robe_divine.tres` (`style = &"divine"`, white). `Wardrobe.look` carries the
  `style`; `Wardrobe.shown_name` is "???" (`ROBE_HIDDEN`) for a hidden robe not owned.
- **The station:** each row "name · price" (the price now), epic rows tagged "epic"; the hidden robe is "???" with a
  hooded silhouette for its swatch (epic swatches framed in violet / gold); buying it shows "Revealed: The Fallen's
  Regalia". The Wardrobe lists "???" (locked) until bought, then picks the epic robes like the others.
- **The look (`EpicRobeView`, `EpicRobeParts`, in code):** the poncho keeps simulating but a robe is drawn in its
  place: its waist ring rides the poncho's own hem springs (pulled in to an A-line), its hem is a second ring of damped
  springs (the poncho's equations, heavier: k 62, c 5.2, inertia 0.5, swing up to 0.3 m), a longer hem (to 0.31 m
  below the waist at the back), a shoulder mantle, a dark collar. Layers: flat-shaded vertex-colour bands, a velvet
  rim, a fresnel sheen shell (also over the hood and the crown), a glowing trim on every edge.
  - **The Fallen's Regalia:** black; the hem torn into jagged points and slits, the mantle in pointed lappets, a faint
    violet ember trim; a dark spiked crown (a flared band, nine forged spikes, the front tallest, a red-violet gem);
    red-violet eyes (`#D040A8`) with a glow in the hood, **the blue visor hidden** while it is worn (owner), back with
    any other robe; dark smoke wisps from the hem while moving; **the plain shots violet** (below).
  - **Divine Hollow Crown:** white and gold, scalloped hem and mantle with gold trim, a soft warm self-light; a gold
    crown of twelve rays with white-hot gems; a halo over the head (a gold torus band, a bright core ring above it,
    eight beads that show its slow turn, a ring glow, ten motes circling, a warm light); gold motes trailing from the
    hem. **Keeps the blue visor** and today's shot colour.
  - The affinity rune stays: the circle under the feet, the back glyph placed on the robe's back below the mantle.
  - Effects: the trail is one fixed MultiMesh pool per robe (40 puffs at High, 20 at Medium, none at Low; one draw);
    Low keeps every shape (robe, crown, eyes, halo rings and glow) and drops the trail, motes and lights; reduced motion
    stills the halo's turn and bob, the motes and the eye flicker, and the puffs stop drifting.
- **Violet attacks (presentation only, EI-07):** `ElementLooks.set_energy` (set by `PlayerAvatar._set_epic`): with
  The Fallen's robe the plain energy (no element) is hot `#FFF0FF`, core `#B526C8`, deep `#5A1680` (FormLook, beams,
  the bolt/pulse colour, the cast flourish); elements keep their colours. RGB distance from the hostile looks (bar
  0.2): core vs the violet fireball `#E9B8FF` core / `#9A4AE0` trail, the Chaos shrine `#A15CFF`, The Fallen's edge
  `#C23CFF`, enemy red, hostile yellow: all over 0.2 (`test_the_violet_is_apart_from_the_hostile_looks`). The views'
  look caches key on the energy too. The sim and hashes are untouched.
- **Profiles:** no migration: `unlocks.robes` only grows; an old profile keeps what it owns (tested: two owned, the
  third costs 125).

## Commands and raw summary lines

```
godot --headless --path . --editor --import --quit                      -> exit=0 (no errors)
gdformat --check src scripts tests && gdlint src scripts tests          -> 1348 files would be left unchanged / Success: no problems found
gut -gtest=test_meta_progress,test_wardrobe,test_progression_panel,test_affinity_runes,test_epic_robes,test_layering
  Tests 47 / Passing Tests 47 / Asserts 16295 / Time 72.789s
gut -gdir=res://tests/content -ginclude_subdirs
  Tests 156 / Passing Tests 156 / Asserts 12424 / Time 48.233s
gut -gtest=test_e2e_wardrobe,test_e2e_rune_fragments,test_e2e_hub
  Tests 13 / Passing Tests 13 / Asserts 200 / Time 141.811s
gut -gtest=test_hub_view,test_vx_looks,test_attack_form_looks,test_attack_forms,test_attack_forms_live,test_gun_pulse,
  test_laser_view,test_item_visuals,test_hit_impact,test_epic_robes,test_affinity_runes,test_progression_panel,test_layering
  Tests 125 / Passing Tests 125 / Asserts 19011 / Time 63.61s
  (then at exit: "ERROR: Pages in use exist at exit in PagedAllocator: N20RasterizerSceneDummy21GeometryInstanceDummyE",
  "ERROR: 1 resources still in use at exit"; also printed by test_hit_impact + test_item_visuals alone, not by
  test_epic_robes alone; not compared with the base)
```

The run of test_meta_progress … test_layering came before the violet-attack and cache-key changes; the 125-test run
after them includes test_epic_robes, test_affinity_runes, test_progression_panel and test_layering again. The content
run came before the cache-key change (item_visuals, form_look, attack_form_view, laser_view, impact_fx sigs) and was
not re-run; the e2e were run again after it, on the final tree:

```
gut -gtest=test_e2e_wardrobe,test_e2e_rune_fragments,test_e2e_hub
  Tests 13 / Passing Tests 13 / Asserts 200 / Time 138.781s
```

## The e2e (main.tscn, real input only)

- `test_buy_the_hidden_robe_and_run_in_it` (test_e2e_wardrobe): 260 fragments banked before the boot (a test
  helper) -> Play -> E at the station: row 5 is "???", "epic", 250 -> Down x4, Enter: bought, 10 left, revealed, the
  status line -> Esc -> E at the Wardrobe, Right x6: The Fallen's Regalia worn, the hub's hero builds crown and eyes,
  the visor hidden -> Esc, the profile keeps it -> the Portal Machine, Enter: the run's hero wears it, visor hidden,
  the plain bolt violet.
- test_e2e_rune_fragments: six rows now; after Night, Canyon's row shows 100.

## Shots (GPU, 1920x1080; `scripts/shots/mp2_shots.gd`, `scripts/shots/mp2_violet.gd`; JPEG copies in `mp2_shots/`)

`en_1_station_hidden` / `es_1_station_hidden` ("???" with its silhouette, 600 fragments), `en_2_station_revealed` /
`es_2_station_revealed`; the hero close up (zoom 3): `en_3_hero_fallen_front`, `_back`, `_moving`, `_low`,
`en_3_hero_divine_front`, `_back`, `_moving`, `_low`, today's `en_3_hero_cream_front` / `_back` to compare; in the hub
(zoom 1.5) `en_3_hero_fallen_hub`, `en_3_hero_divine_hub`; attacks (Ruins stage, Gun, Shoot held):
`en_4_attack_fallen_violet`, `en_4_attack_cream_blue`, `en_4_attack_fallen_cinder` (Cinder Shot keeps its fire
colour). Whether they look great: OWNER ONLY.

## Goldens

None changed (presentation and profile only; no sim file touched).

# ROUTES: do floors 1 and 2 end in a choice of two portals, and is a Deep floor harder and richer as R5 says?

- **Status:** RUN (agent checks). How the choice reads and feels in play, and whether ×1.25 is worth the extra
  chest and the epic altar: OWNER ONLY.
- **Build:** `c46a13c` on the RT worktree branch (base `55a895d` on `claude/lucid-fermat-9wv2tf`); the step commit
  `v0.5.0 Step RT: Deep portal routes` adds only this file and `routes.png`. Godot `4.7.2.stable.official.ed1daf0bf`;
  OS Linux 6.18 (cloud container). Timings are the container's.
- **Date:** 2026-10-08
- **Who ran it:** agent

Owner line R5 (PLAN): "After floors 1 and 2 the portal room offers **two portals**: the normal next floor or a
**Deep** variant (×1.25 scaling, one extra chest, a curse-free epic altar); the choice shows on the floor card and
the minimap".

## What was built
- **Sim.** `Routes` (`src/sim/run/routes.gd`). On a run's floor before the last, `Routes.place_deep_gate` puts the
  Deep gate in the boss room: on the back wall beside the gate (≥ 4.8 m centre to centre, nearest first), else on a
  side wall; a spot fits when the gate and its front square are in the room, its zone is clear of the gate's zone,
  the boss door, the boss's spawn (2.6 m) and the interior pieces, and its front is reached from the door. A pure
  function of the layout (no stream drawn). If no spot is clear, a second pass takes the first spot that fits once
  the interior pieces in its zone are removed (seen on one long LINES room in 300 probe seeds). Its footprint is a
  wall. `BossFlow`: both gates open on the boss's death (`PORTAL_OPENED.amount` 1 when the Deep gate opened too);
  walking into one sets `route_taken` once and starts `ENTERING` (`FLOOR_EXIT.amount` = the route); the other gate
  is closed (`gate_open`). `RunState.routes` keeps each floor's route; `finish_floor` appends the one taken.
- **Deep floors.** `RunState.scale_enemies` / `scale_bosses` multiply the floor factor by `deep_scale` (1.25, data:
  `RunDefinition.deep_scale`) before the single scale, so nothing applies twice; the danger tier's HP and `power`
  still come on top per enemy. `Routes.place_deep_rewards`: one free **epic altar** (`BossFlow.epic_altar_id`) and
  `deep_extra_chests` (1) more chests on item spots the floor's rewards left free (else open spawn spots outside
  the start hall and the boss room), 2 m from any reward and the shrine. `Offers.roll_epic`: epic stat cards and
  level-ups of owned abilities only (loot stream), never a mod or a curse.
- **Hooks for others.** `Routes.is_deep(w)`, `RunState.is_deep(f)` / `routes`. Threat T: not on this base; a
  `TODO(v0.5.0 EV)` line in `routes.gd`, left for the lead.
- **After merging `b010603` (AB, SV, SH).** Saves: `RunSaver.payload_of` / `run_from` carry `run.routes`;
  `PAYLOAD_VERSION` 1 → 2 (an older save is set aside, as for any version change). The route fields live on
  `BossFlow`, already a `WorldSnapshot` state class, so the snapshot guard needed nothing new; `SaveLab.run_state`
  takes a route so the save lab builds Deep floors like Main. The Deep extras never go in the Overrun room or the
  room `ShopPlacement.pick` gives the shop (a pure function of the layout, read before `FloorScenario.add_shop`).
- **View.** The Deep gate (`PortalGate.set_deep`): violet swirl, light and floor glow, a red rim in the swirl and
  three red-lit strips framing the opening (darker and a different hue from the visor-blue gate). Each gate
  closes when the other is taken; the way in draws the hero to the gate taken and flares it. Minimap: a violet
  icon in a red ring (legend "Deep portal"). HUD: "Two portals are open: blue goes on, violet goes Deep (harder,
  richer)."; floor card "Floor 2 · Deep"; floor label "Floor 2 · Deep · <biome>" in light violet. Epic altar:
  violet rune and light, "Open the epic altar", "Epic altar · choose one". Recap: "Route: Normal → Deep → …".
  Strings en + es.
- **Sound.** `deep_portal_open` (`scripts/audio/generate_sfx.py`, `s_deep_portal_open`: a low detuned FM drone, a
  crushed falling growl and a rumble; 2.5 s) plays with `portal_open` when the Deep gate opens; caption
  "[A deeper portal rumbles open]". Cue `data/audio/cues/deep_portal_open.tres`; manifest updated by the script.

## Golden changes
None. No golden fixture builds a run floor (the kernel scenario has no boss flow); both golden tests pass
unchanged and `git status tests/golden` is clean. `BossFlow.hash_into` now also streams
`routes, route_taken, deep, epic_altar_id`, so state hashes of generated floors change (no fixture holds one).
A run's floors 1 and 2 gain the Deep gate's collider (and, on one probe seed of 300, lose a few cover pieces), so
their wall hashes change too.

## Changed test
`tests/e2e/test_e2e_run_flow.gd` asserted floor 1's HUD note "The portal is open…"; floor 1 now opens two portals,
so it asserts `HUD_PORTALS_OPEN` (an intended change of this step, not a widened target).

## Command (sound reproducibility)
```
python3 scripts/audio/generate_sfx.py --check
```
```
[… 75 lines trimmed …]
  same  assets/audio/manifest.json
0 difference(s)
```

## Command (full suite)
```
godot --headless --path . --editor --import --quit
gdformat --check src scripts tests && gdlint src scripts tests
bash scripts/verify.sh
```

## Raw output (full suite)
```
429 files would be left unchanged
Success: no problems found
[… verify.sh output trimmed …]
res://tests/unit/sim/test_routes.gd
* test_the_run_data_has_the_deep_numbers
* test_two_gates_only_after_the_bosses_of_floors_one_and_two
* test_the_deep_gate_takes_the_deep_route_once_and_closes_the_gate
* test_the_gate_takes_the_normal_route_and_closes_the_deep_gate
* test_deep_scaling_composes_with_the_floor_once
* test_the_danger_tier_still_scales_deep_enemies_on_top
* test_deep_floors_have_an_extra_chest_and_an_epic_altar_property
* test_the_epic_altar_offers_only_epic_stats_or_level_ups
* test_the_epic_altar_is_reached_and_picked_through_interact
* test_the_deep_gate_fits_every_boss_room_property
    deep gate: 200 seeds, 14 on a side wall
* test_routes_are_deterministic
11/11 passed.
[…]
res://tests/e2e/test_e2e_routes.gd
* test_into_the_deep_portal_and_floor_two_is_deep
1/1 passed.
[…]
res://tests/unit/presentation/test_routes_view.gd
* test_the_deep_gate_reads_apart_from_the_gate
* test_the_view_builds_both_gates_and_closes_the_one_not_taken
* test_the_last_floor_has_one_gate
* test_the_floor_card_and_label_name_a_deep_floor
* test_the_english_and_spanish_say_deep
* test_the_recap_lists_the_route_per_floor
* test_the_epic_altar_glows_violet
* test_the_deep_gate_opening_has_its_sound
8/8 passed.
[…]
Scripts             145
Tests               911
Passing Tests       911
Asserts           458912
Time              609.362s

---- All tests passed! ----

Results saved to build/gut.xml
check_gut_log: ok (911 passing, minimum 911)
```
`tests/MIN_TEST_COUNT` 891 → 911.

The generation properties: the Deep gate fits 200 seeds (round-robin over every boss arena; 14 on a side wall);
25 seeds of floor 2 built normal and Deep from the same seed: the Deep floor has exactly two more rewards (one
chest, one free epic altar), the floor's own rewards in the same places, none in the start hall or boss room.

## Command (readable cause)
Run on the working tree whose `src/` equals `c46a13c` (the commit after it only touched tests).
```
godot --headless --path . -s scripts/checks/readable_cause.gd -- seeds=4 floor_ticks=1800 boss_ticks=1800
```
```
[… by_cause rows trimmed …]
	"damage_to_player": 160,
	"death_recap_mismatches": [],
	"deaths_checked": 12,
	"floor_ticks": 1800,
	"godot": "4.7.2-stable (official)",
	"runs": 12,
	"seeds": 4,
	"violations": 0
}
```

## Screenshot strip
```
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1600x900x24" \
  godot --path . --fixed-fps 60 --audio-driver Dummy --resolution 1600x900 -s scripts/shots/routes.gd
```
```
routes: renderer=forward_plus device=llvmpipe (LLVM 20.1.2, 256 bits)
routes: res://build/shots/v0.5.0/routes/1_two_portals.png tick=120
routes: res://build/shots/v0.5.0/routes/2_deep_taken.png tick=138
routes: res://build/shots/v0.5.0/routes/3_floor_2_deep.png tick=30
routes: res://build/shots/v0.5.0/routes/routes_sheet.png 2400x450 ["1_two_portals", "2_deep_taken", "3_floor_2_deep"]
ERROR: 2 resources still in use at exit (run with --verbose for details).
```
[`routes.png`](routes.png) is a copy of `routes_sheet.png`. Read by eye:
1. Floor 1 (Ruins), the boss dead: the violet Deep gate (red strip on its frame) beside the light-blue gate on the
   back wall; the HUD note "Two portals are open: blue goes on, violet goes Deep (harder, richer)."; the minimap
   shows both icons.
2. The hero in the Deep gate's mouth, being drawn in; the light-blue gate is dimmed under its veil (closed). The
   HUD note still reads "Two portals are open…" during the ~1 s way in (a gap: it could say which was taken).
3. Floor 2 (this seed: Red Canyon): the card "Floor 2 · Deep / Red Canyon", the label "Floor 2 · Deep · Red Canyon"
   in violet, the arrival column.

## After the merge (`b010603` merged at `a119b35`; follow-ups at `781228d`)
```
$ bash scripts/verify.sh
[… trimmed …]
Scripts             155
Tests               996
Passing Tests       996
Asserts           478735
Time              1151.404s

---- All tests passed! ----

Results saved to build/gut.xml
check_gut_log: ok (996 passing, minimum 974)
$ cd <scratchpad outside the project> && bash <worktree>/scripts/ci/export_smoke.sh
Export smoke check (exported pack)
  ok    running inside the exported pack (run from outside the project folder)
  ok    the main scene ships
  ok    600-tick World run hash e5365ddb6dcb matches the project's
  ok    content player: 1
  ok    content biomes: 3
  ok    content validates inside the pack (0 errors)
  ok    manifest hash ceaa7a8c5910 matches the project's
  ok    Spanish translation is loaded
  ok    UI_PLAY is PLAY / JUGAR
  ok    boss model stone_sentinel loads from the pack
  ok    boss model crawler_queen loads from the pack
  ok    boss model fortress_turret loads from the pack
  ok    audio cues: 83
  ok    every cue's sound loads from the pack (missing: [])
  ok    the test framework is not shipped
  ok    tests are not shipped
0 miss(es)
```
`tests/MIN_TEST_COUNT` 974 (the merged base) → 996.

## Not run
- The scorecard/pacing effect of Deep floors (TU5 / SCD): not measured here.

## Interpretation
Floors 1 and 2 end in a two-portal choice, the choice is taken once and recorded per floor, and a Deep floor is
×1.25 on top of the floor's scaling with an extra chest and an epic altar. Whether the Deep trade is worth taking,
and whether the violet-and-red gate reads apart on the owner's screen and in colour-blind mode, is the owner's call
(OWNER ONLY). Threat T for Deep and saving `routes` wait for EV and SV.

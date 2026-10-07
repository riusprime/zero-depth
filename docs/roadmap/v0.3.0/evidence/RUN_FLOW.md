# v0.3.0 Step B — run flow evidence

Workstream B (owner lines L3–L4): a run of three floors, a sealed boss room off the farthest room, the portal
that opens when the boss dies and takes you down, the floor HUD and title card, pause with Restart run, and the
run recap. This file covers the B commits on the session branch up to `v0.3.0 Step B3` (after merging A, N, G, C
and E at `3161ae3`); the numbers below come from the working tree of that commit, Godot 4.7.2.stable.official,
Linux cloud container, headless (timings are the container's, not the owner's hardware).

Owner-only fields (feel, fun, whether the boss room reads as a boss room on their hardware): **OWNER ONLY**.

## What B does now

- **Run** (`src/sim/run/`): 3 floors (`data/run/three_floors.tres`); biome order shuffled per run (`biomes`
  stream); floor 1 uses the run seed, floors 2–3 a seed derived from it; enemies and the floor's boss scaled
  HP × (1 + 0.4 (f − 1)), damage × (1 + 0.2 (f − 1)) (bosses: every attack's damage; a boss's hatchlings and
  turrets use the floor-scaled enemy tables); the danger tier restarts per floor.
- **Carry** (`RunCarry.FIELDS`): `items_owned` (restored through `World.set_items_owned`: modifiers and combos, no
  unlock events), `combos_owned`, `guard_charges`, `shards`; HP + 40 % of max, capped.
- **Bosses (C's):** each floor draws its boss from its pool (`RunState.pick_boss`, a `boss_<f>` stream of the run
  seed); the boss room takes the boss's arena (cells and template: Gatekeeper 3×3 pillars, Brood Mother 2×2
  scatter, Siege Engine 3×1 lines). B's boss stub is deleted.
- **Rewards (E's):** `FloorScenario.build(..., rewards, floor_index, arena, run, combos)`; altars and chests are
  placed after the carry; the boss room has no item spots, so no reward stands in it; `World.floor_index` is set
  per floor.
- **Boss room** (`BossRoomBuilder`) follows A's wall-thickness model (see `WALLS.md`, "B2").
- **Blink and the boss room:** `World.blink_may_land` — a blink may cross the boss room's boundary only through
  the open doorway (a straight path that touches no wall), never while the door is sealed.

## Full suite

```
$ bash scripts/verify.sh
...
Tests               466
Passing Tests       466
Asserts           402538
Time              294.131s
---- All tests passed! ----
check_gut_log: ok (466 passing, minimum 436)
```

From the same log:

```
    soak: 2 deaths, 11 hits, 5799 frames; nodes 372 -> 383
    boss rooms: 200 seeds, 174.0 ms per floor (generate + attach + checks), 8 hosted off another room
```

"8 hosted off another room": on 8 of 200 seeds the farthest room had no side with free cells for a 3 × 3 room
whose door fits, so the next farthest room hosts it. `tests/MIN_TEST_COUNT` 436 → 466.

## Lint

```
$ gdformat --check src scripts tests && gdlint src scripts tests
265 files would be left unchanged
Success: no problems found
```

## Export smoke and hitch probe

```
$ bash scripts/ci/export_smoke.sh
Export smoke check (exported pack)
  ok    running inside the exported pack (run from outside the project folder)
  ok    the main scene ships
  ok    600-tick World run hash 9c324d3dbf34 matches the project's
  ok    content player: 1
  ok    content biomes: 3
  ok    content validates inside the pack (0 errors)
  ok    manifest hash de8d3c967621 matches the project's
  ok    Spanish translation is loaded
  ok    UI_PLAY is PLAY / JUGAR
  ok    the test framework is not shipped
  ok    tests are not shipped
0 miss(es)
$ godot --headless --path . -s scripts/checks/hitch_probe.gd
hitch_probe: ticks after a 250 ms stall = 4 (limit 4, max seen 4), dash starts = 1 -> ok
```

## Goldens

Unchanged by B. Both come from `KernelScenario`, which has no boss flow (B's state is hashed only when a world has
one):

```
$ godot --headless --path . -s tests/golden/generate_export_smoke_hash.gd
GOLD| export_smoke_hash=9c324d3dbf34a7004e7649382382c67d592309bb2722342cf461afbc81fa17f2
```

Identical to `tests/golden/fixtures/export_smoke_hash.txt` (`git status tests/golden` clean); the replay fixture
(final `5171fdad…`) was not regenerated and its test passes.

## Shots

```
$ VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1920x1080x24" \
    godot --path . --audio-driver Dummy --resolution 1600x900 -s scripts/shots/run_flow.gd
run_flow: res://build/shots/v0.3.0/run_flow/1_boss_door_outside.png
run_flow: res://build/shots/v0.3.0/run_flow/2_boss_door_sealed.png
run_flow: res://build/shots/v0.3.0/run_flow/3_portal_active.png
run_flow: res://build/shots/v0.3.0/run_flow/4_floor_2_title.png
run_flow: res://build/shots/v0.3.0/run_flow/5_pause.png
run_flow: res://build/shots/v0.3.0/run_flow/6_run_recap.png
run_flow: res://build/shots/v0.3.0/run_flow/run_flow_sheet.png 2400x900 ["1_boss_door_outside", "2_boss_door_sealed", "3_portal_active", "4_floor_2_title", "5_pause", "6_run_recap"]
```

[`run_flow.png`](run_flow.png) is a copy of `run_flow_sheet.png` (581 KB). Read by eye:
1. Floor 1, Ruins: the boss door from the host side — a stone slab with a red seal in a thick wall.
2. Inside, the door shut behind you, the Gatekeeper's bar up ("The Gatekeeper"), the pillars arena. The boss's
   body is not in this frame (it was rising or off-camera when the shot fired).
3. The boss dead (60 shards paid, E): the gate's portal lit; the HUD note "The portal is open. Walk in to go down."
4. Floor 2 (this seed: Red Canyon): the "FLOOR 2 / Red Canyon" card, "Floor 2 · Red Canyon", the 60 shards carried.
5. The pause menu: Resume, Restart run, Main menu.
6. The recap after a death on floor 2: "You died", cause, floor reached 2 / 3, time, kills, shards 60, items.
   (The script kills the player with a sourceless hit, so the cause reads "Something got you.")

The script poses the run directly (it is a tool, not a test).

## Open

- **The shared wall can be thicker than 2 × the host's half.** If another neighbour's outer wall reaches deeper
  into the boss room's cells along the shared line, the boss room's half on that side is raised to clear it, so
  the wall is the host's half plus that deeper half. The test checks it is at least the host's half on that side.
- **8 of 200 seeds** put the boss room off a room other than the farthest. That happens when the farthest room
  has no free side wide enough for the door.
- No Night Rocks shot here (this seed's floor 2 drew Red Canyon); the Night Rocks props are unchecked by eye.
- The run-flow e2e uses the dev panel's God mode for the walk and Kill boss for the fight; beating a boss by
  play is C's e2e (`test_e2e_bosses.gd`).

# v0.3.0 Step B — run flow evidence

Workstream B (owner lines L3–L4): a run of three floors, a sealed boss room off the farthest room, the portal
that opens when the boss dies and takes you down, the floor HUD and title card, pause with Restart run, and the
run recap. Built on the session branch from parent `0c44b40`; the commit that adds this file holds the code. The
boss is C's: B codes against `World.spawn_boss` / `World.boss_alive` / `SimEvent.Kind.BOSS_DEFEATED`, with a
stand-in (`src/sim/world/boss_stub.gd`, a Warden with ×12 HP) until C merges.

Owner-only fields (feel, fun, whether the boss room reads as a boss room on their hardware): **OWNER ONLY**.

## Full suite

```
$ bash scripts/verify.sh
...
Totals
------
Scripts              67
Tests               302
Passing Tests       302
Asserts           217576
Time              127.436s

---- All tests passed! ----

Results saved to build/gut.xml
check_gut_log: ok (302 passing, minimum 279)
```

From the same log, the boss-room builder over 200 seeds:

```
    boss rooms: 200 seeds, 164.9 ms per floor (generate + attach + checks), 5 hosted off another room
```

"5 hosted off another room": on 5 of 200 seeds no side of the farthest room had free cells for a 3 × 3 room, so
the next farthest room hosts it (`BossRoomBuilder._hosts`).

`tests/MIN_TEST_COUNT` raised from 279 to 302 after this run.

## Lint

```
$ gdformat --check src scripts tests && gdlint src scripts tests
211 files would be left unchanged
Success: no problems found
```

## Export smoke

```
$ bash scripts/ci/export_smoke.sh
Export smoke check (exported pack)
  ok    running inside the exported pack (run from outside the project folder)
  ok    the main scene ships
  ok    600-tick World run hash 921997d9e01c matches the project's
  ok    content player: 1
  ok    content biomes: 3
  ok    content validates inside the pack (0 errors)
  ok    manifest hash b1a4ed8e89e8 matches the project's
  ok    Spanish translation is loaded
  ok    UI_PLAY is PLAY / JUGAR
  ok    the test framework is not shipped
  ok    tests are not shipped
0 miss(es)
```

## Goldens

Unchanged. `tests/golden/fixtures/replay_ground_plane.json` and `export_smoke_hash.txt` both come from
`KernelScenario`, which has no boss flow; the boss flow's state (and the floor number) is hashed only when a
world has one, so the kernel hash did not move (the replay golden test passes, and the smoke hash above is still
`921997d9e01c…`).

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

The sheet is [`run_flow.png`](run_flow.png) (a copy of `run_flow_sheet.png`, 566 KB). The shots were rendered
before two later edits (gdformat's line wrapping, and `Main` taking a finished floor's nodes out of the tree at
once so the next floor's HUD keeps the name `UI/Hud`); neither changes what is drawn.

What the shots show (read by eye):
1. Floor 1, Ruins: the boss door from 7.5 m outside — a stone slab between dark jambs under a lintel, red seal.
2. Inside, the door shut behind you (seal lit), the stand-in boss (a Warden) up in the room.
3. The boss dead: the gate's portal bright blue and swirling; the HUD note "The portal is open. Walk in to go down."
4. Floor 2 (this seed: Red Canyon): the "FLOOR 2 / Red Canyon" card over the floor, the HUD line
   "Floor 2 · Red Canyon".
5. The pause menu: Resume, Restart run, Main menu.
6. The recap after a death on floor 2: "You died", the cause, "Floor reached: 2 / 3", time, kills, items. (The
   script kills the player with a sourceless hit, so the cause reads "Something got you.")

## Open

- The boss is a stand-in until C merges (see `boss_stub.gd` for what C replaces).
- Walls: the builder walls the boss room at the generator's current `wall_half` (0.4 m) and cuts the door out of
  whatever wall lies on the shared line (keeping its thickness); A's per-wall thickness needs a check at
  integration.
- No night-rocks shot in this sheet (the seed's floor 2 drew Red Canyon); the Night Rocks props are untested by eye.

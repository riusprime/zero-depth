# AFTER_BOSS: once the boss is dead, can you walk back out, explore the floor, fight new spawns and still take the portal (owner D10)?

- **Status:** RUN (agent checks). Whether exploring after the boss is worth it and how it feels: OWNER ONLY.
- **Build:** the PB worktree branch, cut from `5e5b3f9` (lead-merge2). The suite, lint and export smoke ran on the
  tree at `34c117c` (code and tests as committed in `v0.5.0 Step PB: explore the floor after the boss`, whose own
  SHA is in `git log`; only this file and PROGRESS were added after the runs). The readable-cause check ran at
  `6d7f6a0`, whose `src/`, `scripts/` and `data/` equal `34c117c`'s (`git diff --stat 6d7f6a0 34c117c -- src scripts
  data` is empty). Godot `4.7.2.stable.official.ed1daf0bf`; OS Linux 6.18 (cloud container).
- **Date:** 2026-10-08
- **Who ran it:** agent

Owner line D10 ([`../../v0.4.0/PLAN.md`](../../v0.4.0/PLAN.md)): "You can go as soon as you want to the boss and then
explore back, so if you want to rush the boss no problem, you get the boss reward and then explore".

## What was built
- **Sim.** `BossFlow`: on the boss's death (`FIGHT` → `OPEN`, `PORTAL_OPENED` as before) the door's collider leaves
  the walls (`World.remove_wall_now`: matched by shape, the wall grid rebuilt, the flow field from before the seal
  swapped back in, so no rebuild). `door_sealed()` is now true only during the fight, so `blink_may_land` lets a
  blink cross the open doorway; `boss_reached()` is new (true from the seal on). `spawns_open(w)`: before the boss
  room is entered, and after the boss while the player is outside the boss room (a doorway counts as outside); in
  between the floor clock keeps counting (`count_time`), so arrivals are at the curve's level for the floor time
  (D7: staying longer still pays more). `SpawnDirector` already never anchors in the boss room. The seal only
  happens from `WAITING`, so `BOSS_ROOM_SEALED` and the floor-1 heal (D9) are once a floor. No event kind and no
  hashed field were added (the walls are not hashed), so worlds that never kill a boss hash as before.
- **Saves.** `WorldSnapshot`: `World._nav_open` is in `WORLD_KEPT` (rebuilt: `apply` re-seals a sealed door with
  `add_wall_now`, which sets it). A save after the boss holds the floor's own walls (no door), so it restores an
  open door and open portals. No format or payload version change.
- **Shown.** HUD: in the boss room after the boss the portal note gets a second line, `HUD_EXPLORE_AFTER_BOSS`
  ("The boss door is open: explore the rest of the floor, the portal waits for you." / "La puerta del jefe está
  abierta: explora el resto del piso, el portal te espera."); outside the boss room the note is empty. Minimap: the
  boss door is drawn in a dimmed red once open (`MinimapStyle.BOSS_OPEN`); its legend now reads "Boss door (dim:
  open after the boss)" / "Puerta del jefe (tenue: abierta tras el jefe)". The door view needed no change (not
  sealed → its slab sinks as you walk up; its seal already went dark with the portal).
- **Scorecard.** M-FLOOR is reported, no longer a band (SCORECARD §2, dated note; `score_cells.gd` reports "no band
  (D10)" instead of met / missed).
- **Tests changed on purpose.** `test_run_flow.gd` "the door stays shut after the boss" → the door holds during the
  fight and opens after it; `test_routes.gd` "only the door's seal joined the walls" → no wall left behind;
  `test_e2e_run_flow.gd` and `test_e2e_routes.gd` check the HUD note begins with the portal line (it now has a
  second line).

## Tests
- `tests/unit/sim/test_after_boss.gd` (9): the door reopens both ways (walls back to the floor's, walk out and back
  in, no second seal); the D9 heal once; a blink out through the open doorway; no spawns in the boss room after the
  boss (1,200 ticks, the clock running), spawns resume outside (never in the boss room) and stop again inside;
  post-boss arrivals have the curve's HP for the floor time; both gates open after 30 s away; same seed same hash
  after exploring; snapshot round trips after the boss (in the boss room, and exploring after 900 bot ticks: hash,
  walls, door and portals, then 600 more twin-bot ticks equal); a save taken in the fight, restored, then the boss
  killed in both worlds: the door opens the same way (equal hashes 900 ticks later).
- `tests/e2e/test_e2e_after_boss.gd` (1), through `main.tscn` with `Input.parse_input_event` only: dev panel God,
  the stick walks through the boss door (sealed, a wall), Kill boss; the door is open and its collider gone, the HUD
  says keep exploring, nothing arrives in 240 frames in the boss room; the stick walks out through the doorway into
  the host room (door view open, no HUD note); a normal enemy arrives; the stick walks back into the portal and
  floor 2 loads; no engine error.

```
$ godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/e2e -gselect=test_e2e_after_boss -gexit
res://tests/e2e/test_e2e_after_boss.gd
* test_out_through_the_boss_door_and_back_to_the_portal
    first post-boss arrival after 210 frames out, floor time 1797 ticks
1/1 passed.
[…]
Tests                 1
Passing Tests         1
Asserts              19
```

## Command (full suite)
First run (started on the tree at `6d7f6a0`; `tests/support/score_cells.gd` and docs were edited while it ran): 1086 tests, 1085 passing; the failure was `test_routes.gd`
`test_two_gates_only_after_the_bosses_of_floors_one_and_two`, which asserted the door's seal stays in the walls
after the boss (`[137] expected to equal [138]: only the door's seal joined the walls`, on floors 1–3): the old
rule, changed on purpose (above). Second run, at `34c117c`:
```
$ bash scripts/verify.sh
VERIFY_TAIL
```
`tests/MIN_TEST_COUNT` 1076 → 1086.

## Command (lint)
```
$ gdformat --check src scripts tests && gdlint src scripts tests
516 files would be left unchanged
Success: no problems found
```

## Command (readable cause)
```
$ godot --headless --path . -s scripts/checks/readable_cause.gd -- seeds=4 floor_ticks=1800 boss_ticks=1800
[… by_cause rows trimmed …]
	"damage_to_player": 162,
	"death_recap_mismatches": [],
	"deaths_checked": 8,
	"floor_ticks": 1800,
	"godot": "4.7.2-stable (official)",
	"runs": 12,
	"seeds": 4,
	"violations": 0
}
```

## Command (export smoke, from outside the project folder)
```
EXPORT_TAIL
```

## Goldens
None changed. The replay golden test passes in the suite and the export smoke's world hash matches its fixture
(above), unchanged.

## Gaps
- No screenshot strip for this step (the HUD note and the dimmed minimap door are checked by the e2e and by
  reading the code, not by eye).
- Enemies already out of the boss room may follow you into it; only new arrivals are kept out (a safe spot for
  spawns, not a sanctuary). Owner may want more.
- M-RUN's band (35–45 median, 30–60) is unchanged; with D10 a run's length is partly the player's choice too:
  OWNER ONLY to decide whether it stays a band.
- The scorecard bots still head for the portal as soon as it opens (they don't explore after the boss), so M-FLOOR
  measures the rush; not re-run for this step.

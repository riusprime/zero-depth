# SAVES (v0.4.0 SV): save at each room entry and on close, Continue at that room's entry

- **Status:** RUN. Round trip (snapshot → restore → equal hash, then 600 more ticks equal) passes on every world
  tested; the e2e quit-mid-room → Continue lands on the entry tick with the same hash. The on-frame cost of an entry
  save is 0.64–0.72 ms mean, 0.97 ms max (the encode and write run on a worker thread).
- **Build:** measured on `7ebb3e5`, a WIP checkpoint later squashed into the step commit `v0.4.0 Step SV` (cut from
  `55a895d`). `git diff --stat 7ebb3e5` against the step commit lists only docs and `tests/MIN_TEST_COUNT`; no code
  differs. The full suite ran with the doc edits (ARCHITECTURE, SIM_CONTRACTS, TEST_MATRIX, PROGRESS) uncommitted.
- **Machine:** cloud container, shared with other agents' runs (load average 2.3–3.6 during the runs). Godot
  `4.7.2.stable.official.ed1daf0bf`, headless. Not the owner's PC.
- **Date:** 2026-10-08. **Who ran it:** agent. Owner check of Continue in a real run: OWNER ONLY.

## Design
- `WorldSnapshot` (sim, pure; SIM_CONTRACTS §10a) copies every script variable of `World` and its state objects; the
  loadout tables, the event log, the wall grid and the flow field's static part are kept from (or rebuilt in) a base
  world built from the save's inputs. Walls go as packed columns (a dictionary per wall cost ~1.4 ms).
- `RunSaver` (application) saves at the floor's start and at each first room entry (after that tick), keeps the rooms
  entered (the minimap gets them back), flushes on close, deletes on a death or a win.
- `RunSaveStore` (application): `user://saves/run.save`, magic + `save_version` + size + SHA-256 + zstd body, atomic
  `.tmp` + rename, worker-thread writes, a bad save moved to `run.bad.<time>.save` with a warning.

## Commands
```
godot --headless --path . --editor --import --quit
gdformat --check src scripts tests && gdlint src scripts tests
bash scripts/verify.sh
godot --headless --path . -s scripts/checks/hitch_probe.gd
uptime; godot --headless --path . -s scripts/bench/save_bench.gd; uptime
```

## Raw output
`bash scripts/verify.sh` (tail of `build/gut.log`):
```
Tests               914
Passing Tests       914
Time              597.39s
check_gut_log: ok (914 passing, minimum 891)
```
The new tests in that run (`test_round_trip_in_a_crowd` printed `crowd: 104 actors, 33 projectiles at tick 1920`):
```
res://tests/unit/sim/test_world_snapshot.gd          12 tests
res://tests/unit/application/test_run_saves.gd        9 tests
res://tests/e2e/test_e2e_saves.gd                     2 tests
```
Lint: `431 files would be left unchanged` / `Success: no problems found`.

Hitch probe:
```
hitch_probe: ticks after a 250 ms stall = 4 (limit 4, max seen 4), dash starts = 1 -> ok
```
(The probe steps a bare kernel world; it does not save. The save's frame cost is the bench's `on_frame_snapshot`.)

`scripts/bench/save_bench.gd` (20 repetitions each, 5 for restore; `build/save_bench.json`), times in ms as mean / max:

| World | Tick | Actors | Shots | Walls | Raw bytes | File bytes | On-frame snapshot | Worker encode | Encode + write (sync) | Read + decode | Restore (Continue) | `state_hash` (scale) | Restored hash equal |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| floor_start | 0 | 1 | 0 | 189 | 265544 | 7166 | 0.673 / 0.77 | 0.587 / 1.12 | 1.068 / 1.495 | 0.701 / 0.848 | 3.065 / 3.415 | 0.99 | True |
| floor_2_mid_run | 1500 | 8 | 1 | 141 | 273308 | 7776 | 0.724 / 0.966 | 0.688 / 1.281 | 1.304 / 1.723 | 0.768 / 1.015 | 2.749 / 3.083 | 0.98 | True |
| floor_3_crowd | 1860 | 126 | 9 | 168 | 319180 | 16285 | 0.689 / 0.809 | 0.815 / 1.38 | 1.292 / 1.698 | 0.815 / 1.074 | 2.994 / 3.537 | 3.412 | True |
| floor_3_boss_fight | 400 | 2 | 2 | 180 | 292512 | 8698 | 0.64 / 0.835 | 0.627 / 0.744 | 1.111 / 1.444 | 0.705 / 0.856 | 11.943 / 16.044 | 1.029 | True |

Uptime before / after the bench: load average 2.45 / 2.32.

## Notes
- The first snapshot after boot costs ~2.5 ms (each class's field list is read once and cached); it is the floor-start
  save, taken while the floor fades in.
- The snapshot holds no hash (a crowd's `state_hash` is ~3.4 ms on the frame); the load check is the floor's walls.
- Restore with a sealed boss door re-adds it through its prepared flow field (12 ms); a full field rebuild would be
  ~145 ms (measured before that change).
- Raw sizes are dominated by the actor grid and the flow field's distances; zstd brings them to 7–16 KB.

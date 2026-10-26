# Step BK (v0.9.5): crates, urns and barrels are solid until you break them

Owner line (Q17 a): "Breakables solid until broken; kept 1.5 m from doorways".

Build: branch `v095-bk` = claude/v095-feedback + the BK commit (SHA in the step report). Machine: owner PC, Windows,
Godot 4.7.2, `--headless --fixed-fps 60 --language en`, one APPDATA folder per run.

## What was built

- `Solids.Kind.BREAKABLE` (ref = the prop's index). `Breakables.make_solid`: crate 0.4 m half-side, urn, barrel and
  explosive barrel 0.3 m. Registered at setup, so they stand from the floor's first tick and become blockers once the
  hero is 0.5 m clear (SB's rule). Removed in `Breakables.hit` (container breaks) and `_blast` (explosive barrel).
  Not walls: shots, hit detection and sight are unchanged. Enemy steering reads `Solids.blocks`, unchanged.
- Placement: a prop within `DOOR_CLEAR_M` (1.5 m) of a doorway centre is dropped (never moved), after all the draws
  are made, so the other props and the loot streams are as before. The 1.5 m prop gap, 2.0 m from approaches and
  2.5 m from rewards already existed, so no further spacing rule was added (no wall rule: spots are room spawn spots).
- `RunState.FLOOR_RULES` 21 -> 22 (`FLOOR_RULES_V095_BK`). Solid props and the door rule apply only on rules 22
  (`Breakables.setup(..., bk)`, from `FloorPlan.add_secrets`); floors saved on 21 or less are as they were.
  `tests/support/crack_lab.gd` passes `bk = true`.

## Generation drops, 100 seeds (floor 1, blade)

`BK| seeds=100 before=941 kept=941 dropped=0`. The existing 2.0 m approach gap already keeps every prop at least 1.5 m
from a doorway centre, so the new rule dropped nothing; the property test asserts it.

## Tests (raw)

- test_breakables + test_solids + test_world_walls + test_collision: 29/29 passing (11003 asserts).
- tests/golden + tests/arch + tests/content + tests/unit/application (incl. test_old_saves): 302/302 passing.
- e2e `test_e2e_breakables_solid.gd` (new: walks into a prop, stops, hits it with the mouse, walks through),
  `test_e2e_cracked_wall.gd`, `test_e2e_saves.gd`: 5/5 passing.
- New unit tests: unbroken crate, urn, barrel and explosive barrel stop the hero and break nothing; broken, the
  footprint is gone and the hero walks through; a player projectile still hits and breaks a solid prop; no prop within
  1.5 m of a doorway over 100 seeded floors.
- NOT YET RUN: the wider sim/e2e folders (CI shards), test_five_floors, test_curse_room, test_modifier_smoke,
  test_event_rarity, test_event_rooms, test_purple_rooms (excluded by the brief).
- Note: a Gun-build fire-input version of the bolt test did not fire in this headless setup (0 projectiles); the test
  adds a player projectile directly instead. The Gun input path was not investigated.

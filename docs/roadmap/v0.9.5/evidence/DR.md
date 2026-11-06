# Step DR: locked rooms and Overrun, bars on every seal (owner Q6)

Built on `8ace98be` (the merge of `claude/v095-feedback`) with the DR changes uncommitted at the time of the runs;
machine: the owner's PC (Windows, Godot 4.7.2), each run in its own `APPDATA`. Floor rules 19 -> 20.

## What changed

- Locked room = the Lockdown with one burst: 2 formations (the floor's wave size each: 10, 10, 10, 12, 12 enemies), the
  second 1.0 s after the first whoever is left; kinds, the 90 s cap, the stuck-enemy safety and the free altar stay.
  Data: `data/lockdowns/lockdown.tres` `burst_waves = 2`, `burst_gap_seconds = 1.0`.
- Arena rooms are locked rooms on rules 20 (same rooms, same count: `LockdownTable.takes_arenas`; Normal kind); on rules
  1-19 the wave Arena stays (`RunSaver.lockdown_table` zeroes `burst_gap_ticks` and `takes_arenas` for them).
- Overrun: waves, x1.5, x2 shards, altar unchanged. Its seal is drawn with the Lockdowns' falling bars (`LockdownView`);
  the translucent barrier box and the permanent glowing frame and floor strip are gone. A small red rune
  (`OverrunDoorViews`, 0.9 m, additive, fog off, edges masked, pulsing around 0.6) lies outside each doorway and goes
  dark on the clear.

## Commands and raw totals (GUT, `--language en`)

`godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/<file>.gd -gexit --language en`
(`-gdir=res://tests/<folder> -ginclude_subdirs` for folders).

| Run | Tests | Passing | Asserts |
|---|---|---|---|
| unit/sim/test_locked_rooms.gd (new) | 3 | 3 | 33 |
| unit/sim/test_lockdowns.gd | 8 | 8 | 249 |
| unit/sim/test_lockdowns_first.gd | 3 | 3 | 220 |
| unit/sim/test_closed_fights.gd | 8 | 8 | 64 |
| unit/sim/test_overrun.gd | 7 | 7 | 7054 |
| unit/sim/test_arenas.gd | 16 | 16 | 2088 |
| unit/sim/test_special_room_rules.gd | 3 | 3 | 107 |
| unit/sim/test_solids.gd | 9 | 9 | 21 |
| unit/presentation/test_lockdown_view.gd | 2 | 2 | 34 |
| unit/presentation/test_dr_views.gd (new) | 2 | 2 | 24 |
| unit/application/test_old_saves.gd | 10 | 10 | 142 |
| content/ | 157 | 157 | 12701 |
| golden/ | 2 | 2 | 4 |
| arch/ | 4 | 4 | 17195 |
| e2e/test_e2e_lockdown.gd | 1 | 1 | 19 |
| e2e/test_e2e_arenas.gd (second run, after the bars wait) | 2 | 2 | 52 |
| e2e/test_e2e_arena.gd | 3 | 3 | 19 |
| e2e/test_e2e_abilities_ab.gd (the Overrun e2e) | 2 | 2 | 25 |
| e2e/test_e2e_saves.gd | 3 | 3 | 49 |

First runs failed where tests assumed the old behaviour (Arena tests on rules-20 floors, a hazard test whose room
closed after 2 formations, `LockLab.world` picking an arena-only floor, an e2e that read the bars 3 frames after the
seal); each was fixed in the tests and re-run. `test_five_floors`, `test_curse_room`, `test_modifier_smoke`,
`test_event_rarity`, `test_event_rooms` were not run (told to skip); GitHub runs the full suite.

## Shots

`build/shots/v0.9.5/dr/` (untracked; scratchpad script `dr_shots.gd`, forward_plus renderer, Ruins palette on floor 2):
- `overrun_rune_before.png`: the hero 3 m outside the Overrun's doorway; the small red rune lies on the floor just
  outside it, faint but readable, no glowing frame.
- `overrun_sealed_bars.png`: the hero inside the sealed Overrun beside its doorway; the owner's iron bars stand in the
  doorway, no translucent box, the rune dark-ish beyond.

## Not done / notes

- The minimap no longer marks arena rooms on rules 20 (they are listed as locked rooms, which the minimap never drew);
  the arena-clear achievement counter reads `arenas().cleared`, so a locked room clear no longer counts there.
- Wave 2 of a burst respects the room's at-once cap (CF): in a small room part of it waits and comes in as earlier
  ones die.

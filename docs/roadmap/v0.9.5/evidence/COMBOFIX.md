# COMBOFIX: tests/e2e/test_e2e_combo.gd

Build: branch v095-combofix cut from v095-ep-int (bbf5e61f). Machine: owner's PC (Windows, Godot 4.7.2).

## Cause
`_open(e, id)` failed for rewards 2 and 3 because the hero stood next to them but X did nothing: `Rewards.nearest`
skips a reward when `Arenas.locked(w, i)` is true. Diagnostic print (temporary, removed) at the failure:

    DBG id=2 near=-1 locked=true kind=0 rolled=0 offer=[] reach=1.6
    DBG id=3 near=-1 locked=true kind=1 rolled=0 offer=[] reach=1.6

Since v0.9.5 DR (62cc306c) `LockdownTable.takes_arenas` is true by default, so an arena room is a locked room and
`Arenas.locked` answers `not Lockdowns.is_open(w, room)` (`w.lockdown.cleared`). The test's TEST HELPER only
marked `w.arenas.cleared`, which the locked-room branch no longer reads. The game is right by design (a locked
room's reward waits for its lockdown); the test was out of date. No player-facing bug.

Breaking commit: not bisected. DR is an ancestor of both 1717e42b and 66c2d729, so DR alone does not explain
"green on 1717e42b"; a later change to the floor layout or seed probably put rewards into arena rooms. NOT YET RUN
(bisect).

## Fix
A labelled TEST HELPER in tests/e2e/test_e2e_combo.gd also opens the arena rooms in `w.lockdown.cleared` when
`Lockdowns.takes_arenas(w)`. The test's purpose (a combo pair picked through real input) is unchanged.

## Commands and raw results
    godot --headless --path . --editor --import --quit
    godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/e2e/test_e2e_combo.gd -gexit
    (before) Asserts 6/9, 3 failures
    (after)  Passing Tests 1, Asserts 22, "All tests passed!", "combo slipstream from 3 rewards"
    ... -gtest=res://tests/e2e/test_e2e_combo.gd,res://tests/e2e/test_e2e_rewards.gd -gexit
             Scripts 2, Tests 4, Passing Tests 4, Asserts 70, "All tests passed!"
    gdformat --check / gdlint on the test: "1 file would be left unchanged", "Success: no problems found"

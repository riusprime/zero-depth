# CRASH_ON_HIT: why does the game sometimes crash when the wanderer takes a hit? (PLAN v0.3.0 L28)

- **Status:** RUN. Reproduced here as a crash (SIGSEGV) in the **release** export template on Linux, root-caused,
  fixed, and the same release soak re-run clean. The owner's Windows build: **OWNER ONLY** (the next playtest says
  whether the crash is gone).
- **Build:** before = `75fbfc2` (`claude/lucid-fermat-9wv2tf`); after = the working tree of the `v0.3.0 Step X`
  commit on branch `worktree-agent-a721c4a9e526ce95a` (measured before committing; the code under test is the
  commit's). Godot `4.7.2.stable.official.ed1daf0bf` (editor) and the official 4.7.2 export templates
  `linux_release.x86_64` / `linux_debug.x86_64`; OS `Linux 6.18.44-fc-v77 x86_64`, shared with other agents' jobs.
  Rendered runs: Vulkan on **llvmpipe/lavapipe** (software) under Xvfb.
- **Date:** 2026-10-07
- **Who ran it:** agent

## Owner's report
"Sometimes when taking a hit game crashes" (Windows build of the full run, PLAN L28). The v0.2.0 lag-on-hit fix
(`../../v0.2.0/evidence/DAMAGE_LAG.md`, shader recompiles) didn't touch it.

## Root cause
**The laser blade's trail read the last element of an empty array when a hit froze the sim on a swing's first
tick.** `KitView.sync` (src/presentation/world_view/kit_view.gd) cleared the trail whenever the swing tick read 1,
and added a sample only when the tick had moved since the last sync. A hit on the wanderer adds the hurt hit-stop
(`hurt_freeze_ticks` = 4): the world still ticks and the view still syncs, but the swing tick is held. So when the
wanderer is hit on the very tick a swing starts (pressing attack as an enemy connects: common, and "sometimes"),
the next syncs see tick 1 again: the trail is cleared, nothing is added, and `_head()` reads
`_history[_history.size() - 1]` = `_history[-1]` of an empty Array.

- In a **debug** build (the editor, the test suite, every run here before) that is a `SCRIPT ERROR: Out of bounds
  get index '-1'`; the function stops and the game carries on. Nobody saw a crash.
- In a **release** build (what the owner plays; `scripts/export_windows.ps1` exports release) GDScript skips that
  bounds check: the read leaves a typed `Array` local holding garbage, and the next index into it dereferences a
  null array: **segmentation fault**, the process dies.

The hit-stop is the "on hit" part; the release-only VM check is why it only ever crashed on the owner's build.

## The fix
- `kit_view.gd`: a new swing starts the trail over only when the tick went backwards or the blade was off (`t <
  _last_t or not was`), not on "tick 1"; a sample is added whenever the trail is empty; `_head()` returns `[]` on an
  empty trail (and `_build_trail` already draws nothing with fewer than 2 samples).
- Hardening found by review (no crash attributed to it): `ActorViews` now drops a removed actor's hit-flash and
  glow entries (`_flash`, `_tint` were never pruned, so they grew with every enemy id seen on a floor).
- Crash reports: file logging and flush-on-print are explicit in `project.godot` (see "If it crashes again").

## Reproduction and measurements

### 1. Regression test, before and after (headless, debug)
`tests/unit/presentation/test_kit_view.gd::test_a_hit_freeze_on_the_swings_first_tick_keeps_the_trail_head`: a swing
starts, `Damage.hit` lands on the wanderer that tick (the real hurt hit-stop), three frozen ticks with a sync each.
```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/presentation -gselect=test_kit_view -gunit_test_name=test_a_hit_freeze -gexit
```
Before the fix (trimmed: the backtraces after each SCRIPT ERROR):
```
* test_a_hit_freeze_on_the_swings_first_tick_keeps_the_trail_head
SCRIPT ERROR: Out of bounds get index '-1' (on base: 'Array')
          at: KitView._head (res://src/presentation/world_view/kit_view.gd:243)
[… backtrace trimmed …]
    [Failed]:  [0] expected to be > than [0]:  frozen sync 0: the trail keeps the blade's sample
          at line 88
    [Failed]:  [0] expected to be > than [0]:  frozen sync 1: the trail keeps the blade's sample
          at line 88
    [Failed]:  [0] expected to be > than [0]:  frozen sync 2: the trail keeps the blade's sample
          at line 88
    [Failed]:  [3] expected to equal [0]:  no out-of-bounds read of the trail
          at line 90
    [Failed]:  Unexpected Errors:
          at line 91
Totals
Tests                 1
Passing Tests      none
Failing Tests         1
Asserts            6/11
```
After (the whole `test_kit_view` script):
```
Scripts               1
Tests                 4
Passing Tests         4
Asserts              25
---- All tests passed! ----
```

### 2. The same sequence in the release template (crash) vs the debug template (error only)
A scratch copy of the project (not committed) whose main scene is a probe node doing exactly the test's steps
(`World.step` a swing press, `KitView.sync`, `Damage.hit` on the wanderer, then `World.step` + `KitView.sync` each
frame), exported with `godot --headless --path . --export-pack "Windows Desktop" <pck>` and run by the official
templates (release templates refuse `--main-pack`, so the pack sits next to a copy of the binary with the same
name). Before the fix, release:
```
./game_before.x86_64 --headless
Segmentation fault      timeout 60 ./game_before.x86_64 --headless > rel_before.log 2>&1
exit=139
probe: debug_build=false
probe: swing tick 1, trail 1
probe: hit, freeze 4
probe: frozen sync 1 (swing tick 1)
```
Before the fix, debug template, same pack (the error, no crash):
```
probe: debug_build=true
probe: swing tick 1, trail 1
probe: hit, freeze 4
probe: frozen sync 1 (swing tick 1)
SCRIPT ERROR: Out of bounds get index '-1' (on base: 'Array')
          at: KitView._head (res://src/presentation/world_view/kit_view.gd:243)
[… 2 more identical errors trimmed …]
probe: after sync 3, trail 0
probe: survived
exit=0
```
After the fix, release:
```
probe: debug_build=false
probe: swing tick 1, trail 1
probe: hit, freeze 4
probe: frozen sync 1 (swing tick 1)
probe: after sync 1, trail 1
probe: frozen sync 2 (swing tick 1)
probe: after sync 2, trail 1
probe: frozen sync 3 (swing tick 1)
probe: after sync 3, trail 1
probe: survived
exit=0
```

### 3. The real game in the release template: the soak, before and after
`scripts/checks/hit_soak.gd` (committed): boots `main.tscn` and plays it with a pad bot through
`Input.parse_input_event` (stick walks a flow field to the nearest enemy or the boss, triggers swing and shoot,
bumpers dash and guard; Enter on the end panel restarts; Esc → Restart run from the pause menu). Lives cycle
through brawls (every enemy kind queued near the player), all-items brawls (statuses, engines, combos), the three
bosses in turn, and a run leg (altar pick with the panel open while hit, boss door sealing, the real boss, Kill boss,
the portal to floor 2, a fight there, pause-menu restart). It pokes World between ticks for items, boss spawns, the
run leg's HP top-up and the boss kill (so it is a harness, not an e2e test); God mode is never on. For the release
template the same script runs as a Node main scene of the scratch copy (`extends Node`, `_ready`, a stderr line
every 300 frames so a crash shows how far it got).

Before the fix (the real game; the bot is swinging when an enemy connects):
```
XDG_DATA_HOME=<scratch>/xdg timeout 600 ./soak_before.x86_64 --headless --fixed-fps 60 -- frames=30000
alive frame 300 hits 1
alive frame 600 hits 2
Segmentation fault      XDG_DATA_HOME=<scratch>/xdg timeout 600 ./soak_before.x86_64 --headless --fixed-fps 60 -- frames=30000 > rel_soak_before2.log 2>&1
exit=139
```
(A first run of the same binary, without `XDG_DATA_HOME`, also died: `alive frame 600 hits 2`, then
`Segmentation fault`, exit 139, after 10.7 s.) The file log the release build wrote for that run
(`<scratch>/xdg/godot/app_userdata/{{TITLE}}/logs/godot.log`) ends just as abruptly, with no crash message:
```
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org

hit_soak: frames=30000 plans=["brawl", "brawl_items", "boss", "run"]
alive frame 300 hits 1
alive frame 600 hits 2
```
After the fix (final code; release template; 30 000 frames):
```
XDG_DATA_HOME=<scratch>/xdg2 timeout 3000 ./soak_after.x86_64 --headless --fixed-fps 60 -- frames=30000
exit=0
frame 1200 life 1 plan brawl stage fight floor 1 | deaths 0 floors 0 restarts 0 hits 5 picks 0 seals 0 | nodes 2515 orphans 0 objects 7339 | errors 0
frame 6000 life 2 plan boss stage fight floor 1 | deaths 1 floors 0 restarts 0 hits 20 picks 0 seals 0 | nodes 2787 orphans 0 objects 9555 | errors 0
frame 12000 life 4 plan boss stage fight floor 1 | deaths 3 floors 0 restarts 0 hits 41 picks 0 seals 0 | nodes 2295 orphans 0 objects 8255 | errors 0
[… report lines trimmed …]
frame 30000 life 11 plan run stage altar floor 1 | deaths 9 floors 1 restarts 1 hits 98 picks 1 seals 1 | nodes 2374 orphans 0 objects 6679 | errors 0
hits on the wanderer by attacker: { "WARDEN": 25, "NEEDLE": 24, "CHARGER": 39, "none": 1, "GATEKEEPER": 5, "SIEGE_ENGINE": 2, "BROOD_MOTHER": 2 }
boss hits by kind:move: { "GATEKEEPER:2": 3, "GATEKEEPER:3": 1, "GATEKEEPER:1": 1, "SIEGE_ENGINE:8": 1, "SIEGE_ENGINE:9": 1, "BROOD_MOTHER:5": 2 }
lives 11 deaths 9 floor transitions 1 pause restarts 1 picks 1 door seals 1
nodes first fight 2320 max 3365 | max orphans 0 | max ActorViews _tint 3 _flash 3
errors 0
```
A release build skips GDScript's runtime checks, so its "errors 0" says little; the debug runs below are the
error check.

### 4. Debug soaks (the editor binary): errors, growth, orphans
Before the fix, headless, an earlier version of the same bot (no boss lives yet), 12 000 frames:
```
godot --headless --fixed-fps 60 --path . -s scripts/checks/hit_soak.gd -- frames=12000
hits on the wanderer by attacker: { "WARDEN": 5, "NEEDLE": 9, "CHARGER": 11 }
lives 2 deaths 1 floor transitions 0 pause restarts 0 picks 0 door seals 0
nodes first fight 2319 max 2898 | max orphans 0 | max ActorViews _tint 2 _flash 1
errors 4
  res://src/presentation/world_view/kit_view.gd:243 KitView._head: Out of bounds get index '-1' (on base: 'Array') 
  res://src/presentation/world_view/kit_view.gd:243 KitView._head: Out of bounds get index '-1' (on base: 'Array') 
  res://src/presentation/world_view/kit_view.gd:243 KitView._head: Out of bounds get index '-1' (on base: 'Array') 
  res://src/presentation/world_view/kit_view.gd:243 KitView._head: Out of bounds get index '-1' (on base: 'Array') 
exit=1
```
After the kit_view fix, headless, 60 000 frames (this run predates the `ActorViews` pruning, so its `_tint`/`_flash`
maxima are without it):
```
godot --headless --fixed-fps 60 --path . -s scripts/checks/hit_soak.gd -- frames=60000
[… report lines trimmed …]
frame 57600 life 17 plan run stage fight2 floor 2 | deaths 13 floors 3 restarts 3 hits 170 picks 3 seals 3 | nodes 1856 orphans 0 objects 5913 | errors 0
frame 60000 life 18 plan boss stage fight floor 1 | deaths 13 floors 3 restarts 4 hits 177 picks 3 seals 3 | nodes 2495 orphans 0 objects 8198 | errors 0
hits on the wanderer by attacker: { "WARDEN": 36, "NEEDLE": 59, "CHARGER": 62, "none": 2, "GATEKEEPER": 8, "SIEGE_ENGINE": 7, "BROOD_MOTHER": 3 }
boss hits by kind:move: { "GATEKEEPER:2": 5, "GATEKEEPER:3": 1, "GATEKEEPER:1": 2, "SIEGE_ENGINE:8": 2, "SIEGE_ENGINE:9": 3, "BROOD_MOTHER:5": 3, "SIEGE_ENGINE:7": 2 }
lives 18 deaths 13 floor transitions 3 pause restarts 4 picks 3 door seals 3
nodes first fight 2319 max 4872 | max orphans 0 | max ActorViews _tint 4 _flash 2
errors 0
real	15m42.381s
exit=0
```
After (final code), rendered (Xvfb + lavapipe, `--verbose`), 6 000 frames:
```
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json timeout 3500 xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --audio-driver Dummy --resolution 960x540 --verbose -s scripts/checks/hit_soak.gd -- frames=6000
frame 1200 life 1 plan brawl stage fight floor 1 | deaths 0 floors 0 restarts 0 hits 5 picks 0 seals 0 | nodes 2517 orphans 0 objects 7458 | errors 0
[… 3 report lines trimmed …]
frame 6000 life 2 plan boss stage fight floor 1 | deaths 1 floors 0 restarts 0 hits 20 picks 0 seals 0 | nodes 2770 orphans 0 objects 9624 | errors 0
hits on the wanderer by attacker: { "WARDEN": 7, "NEEDLE": 8, "CHARGER": 5 }
boss hits by kind:move: {  }
lives 2 deaths 1 floor transitions 0 pause restarts 0 picks 0 door seals 0
nodes first fight 2319 max 2745 | max orphans 0 | max ActorViews _tint 2 _flash 2
errors 0
exit=0
```
The only engine messages in that rendered log (`grep -E "^(WARNING|ERROR|SCRIPT ERROR)" | sort | uniq -c`):
```
      4 WARNING: Image format RGB8 not supported by hardware, converting to RGBA8.
```
(the boss models' JPEG textures on lavapipe; not an error). A first rendered attempt at 1600x900 was killed by the
container's memory limit (`Memory cgroup out of memory: Killed process ... (godot)`, exit 137) while several other
agents' rendered jobs were running; it had printed no report line yet, so it says nothing about the game.

### 5. Suite and export smoke (final code)
```
bash scripts/verify.sh
Scripts              87
Tests               483
Passing Tests       483
---- All tests passed! ----
check_gut_log: ok (483 passing, minimum 483)

bash scripts/ci/export_smoke.sh
[… check lines trimmed …]
  ok    tests are not shipped
0 miss(es)
```
No golden changed (nothing in `src/sim/` moved).

## Result
| Check | Measured | OK? |
|---|---|---|
| Crash reproduced in the release template, real game | SIGSEGV (exit 139) at ~600–900 frames, twice | reproduced |
| Same soak after the fix, release template | 30 000 frames, 98 hits, 9 deaths, 1 floor transition, exit 0 | yes |
| Script/engine errors, debug, after (60 000 headless + 6 000 rendered) | 0 and 0 (4 before the fix in 12 000) | yes |
| Orphan nodes (debug soaks) | max 0 | yes |
| Node count (60 000 headless) | 2319 at the first fight; 1840–4060 over the 50 report lines, 2495 at the end, after 18 lives; peak 4872 (sampled every 60 frames) during lives where the harness keeps queueing enemies. No upward trend across lives | yes |
| Rendered: skinned mesh / Skeleton3D / physics interpolation messages | none | yes |
| Siege Engine, Gatekeeper, Brood Mother attacks that hit (boss move ids) | 7, 8, 9 / 1, 2, 3 / 5 | partial: the soak bot didn't get hit by every move id |

## If it crashes again: the log
File logging is on (it was already Godot's default on PC; `project.godot` now says so explicitly:
`debug/file_logging/enable_file_logging.pc=true`, `max_log_files=10`) and `application/run/flush_stdout_on_print=
true`, so every line reaches the file before a crash. The project name is `{{TITLE}}` and there's no custom user
dir, so on Windows the log is:
```
%APPDATA%\Godot\app_userdata\{{TITLE}}\logs\godot.log
```
(paste `%APPDATA%\Godot\app_userdata` into the Explorer address bar). `godot.log` is the latest run; older runs
are kept beside it as `godot<date>T<time>.log`. After a crash, send the newest one before restarting the game.
What it can't show: a release build doesn't print GDScript errors (the check that would have named
`kit_view.gd:243` is skipped), and here the release template wrote no crash message either; the log just stops.
Its value is the last lines (floor, what happened just before). A debug export of the same build would print the
error and keep running instead of crashing; whether to ship one for playtests is the owner's call.

## Interpretation
The crash the soak reproduced in a release build is a crash on hit: a hit that freezes the sim on a swing's first
tick. It is now fixed and has a test. Whether it is **the** crash the owner saw on Windows is likely but not proven
here: same mechanism, release-only, triggered by being hit while attacking. That's OWNER ONLY, from the next
playtest. If it still crashes, `godot.log` (path above) is the next step.

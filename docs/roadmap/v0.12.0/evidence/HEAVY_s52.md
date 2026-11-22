# HEAVY_s52: the smaller named costs of a heavy fight, in script (Step 52)

Machine: the owner's PC (i7-10700K, RTX 3060). Worktree `wt-s52`, base `e1c0a233`; the after tree is that base with
this step's diff. One other agent ran Godot meanwhile (the process counts below, from `tasklist | grep -ci godot`, count
two per Godot run: the console wrapper and the engine), so every timing is an indication. Base runs: the step's `src`
and `tests` checked out from `e1c0a233` (`git diff > build/s52/after.patch; git checkout e1c0a233 -- src tests`), the
after runs with the patch applied back. No `git stash`.

## What was cut, and why nothing changes

| Cost | The cut | Why it plays, shows and feels the same |
|---|---|---|
| `AudioDirector.sync` → `AudioEvents._scan_actors` (225 µs of the 434 µs collect a tick, split with temporary marks) | The actor scan reads the ids and kinds as whole columns (`actor_ids_column`, `actor_kinds_column`) instead of a call per field; each stored kind's body and boss test is worked out once (`_kind_info`: `BossAi.is_boss_kind` built an array per call); a non-boss's phase (always 0) is no longer read and stored | The same values in the same order: the columns are what `actor_id` / `actor_kind` read; a kind's body (`EnemyAi.VARIANT_BASE`) and boss test are constants; `_phases` is only read for a boss. Every sound request comes out in the same order, so the pitch jitter stream draws the same numbers |
| `AudioEvents._arrival` (29 µs a tick) | The altar cue's start (`AltarStage.arrival()`, a new `Look` each call) is worked out only while an arrival plays (progress 0 or more) | The cue needs `progress >= start >= 0`, so a negative progress never plays it |
| `script.dps_meter.gd` (the Playground's meter) | `DpsTally.dps_recent` keeps the 5 s window's sum and moves it by the ticks that entered and left, instead of reading all 300 slots a frame; the source lines are built again only when a hit is added, the tally resets, the names or the language change | Integer sums, so the same float and the same text; a window before tick 300, a jump of a window or more, or a clock going back reads every slot as before. A test checks 4,000 random adds, clock moves and resets against the full read |
| `hud.kit`: the Vent line (`kit_hud.gd`) | The line is built whole and written once, when it differs, instead of written and then appended to (two shapings a sync while the vent cools) | The same final text each sync |
| `hud.kit`: the binding glyphs (`ability_squares.gd`) | Each action's glyph is kept with what it was read from (pad flag, language, pad name, the action's bound events) and worked out again only when one changes | A rebind replaces the action's events with new objects (`InputRemap`, `InputDefaults`, `InputRebind`), so the comparison sees it; a test rebinds the Skill, restores the defaults and switches the language |

`scripts/checks/audio_dump.gd` (new): every voice the director starts over one seeded fight (floor 3, 42 enemies of
the Night Rocks kinds kept alive, FightBot, 3,600 ticks), one line per voice: tick, stream file, volume, pitch, bus and
3D place; the director's clock moved 1/60 s a tick (its `_process` off), and its sync's µs a tick. `--marks=1` prints
the PerfMarks buckets entered meanwhile (used with temporary marks, not committed, for the splits above).

## Commands

```
# APPDATA=C:/Users/extri/Desktop/zerodepth/appdata-s52; one Godot process of this step at a time
godot --headless --path . -s scripts/checks/audio_dump.gd -- --out=build/s52/audio_<tag>.txt
godot --path . --fixed-fps 60 --resolution 1920x1080 --windowed --position -10000,-10000 -s scripts/checks/frame_probe.gd -- \
  --biome=night_rocks --enemies=42 --kinds=charger,needle,swarmer,warden,rock_lurker,stone_thrower,dim_needle --secs=12 \
  --shot-at=<420|600>:build/s52/shot_<tag>_<N>.png
godot --path . --windowed --position -10000,-10000 -s scripts/checks/frame_probe.gd -- --biome=night_rocks --enemies=42 \
  --secs=30 --warm=5 --size=2560x1440 --kinds=charger,needle,swarmer,warden,rock_lurker,stone_thrower,dim_needle --process --breakdown
cmp build/s52/audio_base.txt build/s52/audio_after.txt
python <scratch>/pixdiff.py <a.png> <b.png> <regions>   # share of pixels differing, whole frame and HUD regions
```

## Raw output

The sound, base against after (two pairs):
```
[after audio] godot before: 0
[after audio] exit 0 ; godot after: 2
audio_dump: ticks=3600 enemies=42 spawned=79 actors_stored=43 voices=760 logged=256 build/s52/audio_after.txt
audio_dump: sync us a tick mean=210.5 p50=182 p99=485 max=806
[base audio] godot before: 2
[base audio] exit 0 ; godot after: 2
audio_dump: ticks=3600 enemies=42 spawned=79 actors_stored=43 voices=760 logged=256 build/s52/audio_base.txt
audio_dump: sync us a tick mean=315.3 p50=281 p99=667 max=1089
[base2 audio] godot before: 0
[base2 audio] exit 0 ; godot after: 0
audio_dump: ticks=3600 enemies=42 spawned=79 actors_stored=43 voices=760 logged=256 build/s52/audio_base2.txt
audio_dump: sync us a tick mean=398.6 p50=350 p99=895 max=2008
[after2 audio] godot before: 2
[after2 audio] exit 0 ; godot after: 0
audio_dump: ticks=3600 enemies=42 spawned=79 actors_stored=43 voices=760 logged=256 build/s52/audio_after2.txt
audio_dump: sync us a tick mean=212.7 p50=187 p99=470 max=724
$ cmp build/s52/audio_base.txt build/s52/audio_after.txt && echo AUDIO_IDENTICAL
AUDIO_IDENTICAL
$ cmp build/s52/audio_base2.txt build/s52/audio_after2.txt && echo AUDIO2_IDENTICAL
AUDIO2_IDENTICAL
```
The split of the base sync (temporary PerfMarks round each `collect` part, `--marks=1`, base code, one run; the marks
cost a little themselves): `dir.collect` 433.8, `ev._scan_actors` 225.5, `ev._overrun_edges` 38.0, `ev._arrival` 28.9,
`dir.play` 22.4, `ev._scan_projectiles` 16.0, `ev._player` 14.6, `ev._events` 13.1, every other part under 9 µs a tick.
After the actor scan's first cut the same split gave `ev._scan_actors` 118.0.

The frame probe, alternated (`--process --breakdown`: proportions only, PERF_TOOLS §4.3), µs a frame:
```
[base1 probe] godot before: 2      exit 0 ; godot after: 0
frames=1137  avg_ms=26.401  p50_ms=25.420  p95_ms=37.260  p99_ms=44.489
  frame.main.gd._on_playground_tick       707      1264       707      1137
  view.telegraphs                    246       822       246      1137
  hud.kit                            171       335       171      1137
  hud.minimap                        113       215       113      1137
  script.dps_meter.gd                 94       168        94      1137
  hud.top                             90       175        90      1137
  script.minimap.gd                   67       133        67      1137
  script.game_cursor.gd               10        22        10      1137
[after1 probe] godot before: 0     exit 0 ; godot after: 0
frames=1164  avg_ms=25.780  p50_ms=24.835  p95_ms=34.979  p99_ms=46.867
  frame.main.gd._on_playground_tick       678      1244       678      1164
  view.telegraphs                    253       753       253      1164
  hud.kit                            149       294       149      1164
  hud.minimap                        106       208       106      1164
  hud.top                             91       192        91      1164
  script.minimap.gd                   67       131        67      1164
  script.dps_meter.gd                 53       143        53      1164
  script.game_cursor.gd               10        22        10      1164
[base2 probe] godot before: 0      exit 0 ; godot after: 2
frames=1205  avg_ms=24.904  p50_ms=23.902  p95_ms=34.691  p99_ms=42.334
  frame.main.gd._on_playground_tick       702      1171       702      1205
  view.telegraphs                    272       900       272      1205
  hud.kit                            168       309       168      1205
  hud.minimap                        113       217       113      1205
  script.dps_meter.gd                 94       167        94      1205
  hud.top                             90       165        90      1205
  script.minimap.gd                   67       134        67      1205
  script.game_cursor.gd               10        23        10      1205
[after2 probe] godot before: 2     exit 0 ; godot after: 2
frames=1030  avg_ms=29.154  p50_ms=28.282  p95_ms=39.405  p99_ms=50.887
  frame.main.gd._on_playground_tick       690      1178       690      1030
  view.telegraphs                    280       911       280      1030
  hud.kit                            153       296       153      1030
  hud.minimap                        108       194       108      1030
  hud.top                             92       166        92      1030
  script.minimap.gd                   68       128        68      1030
  script.dps_meter.gd                 61       140        61      1030
  script.game_cursor.gd               10        22        10      1030
```
(The after1/after2 runs above still held a minimap change that was then dropped, see below; `hud.minimap` is the base
code in the committed tree.)

Still frames, frame 420 and 600 of the fight (`--fixed-fps 60`), base against after, and base against a second base
(the noise floor). Regions: DPS meter `1565,420,1905,662`, ability squares `1655,980,1900,1075`, heat and Vent line
`760,1012,1400,1055`, minimap `1595,85,1895,385`, HP plate `0,940,470,1075`:
```
== 420 base vs after
whole 1920x1080         5.856 % differ (121433 of 2073600 px), max channel diff 255
region 1565,420,1905,662  0.024 % differ (20 of 82280 px), max channel diff 9
region 1655,980,1900,1075  0.000 % differ (0 of 23275 px), max channel diff 0
region 760,1012,1400,1055  0.149 % differ (41 of 27520 px), max channel diff 41
region 1595,85,1895,385  0.000 % differ (0 of 90000 px), max channel diff 0
region 0,940,470,1075   0.091 % differ (58 of 63450 px), max channel diff 41
== 420 base vs base2
whole 1920x1080         6.923 % differ (143561 of 2073600 px), max channel diff 255
region 1565,420,1905,662  0.022 % differ (18 of 82280 px), max channel diff 6
region 1655,980,1900,1075  0.034 % differ (8 of 23275 px), max channel diff 21
region 760,1012,1400,1055  0.476 % differ (131 of 27520 px), max channel diff 2
region 1595,85,1895,385  0.008 % differ (7 of 90000 px), max channel diff 31
region 0,940,470,1075   0.102 % differ (65 of 63450 px), max channel diff 37
== 600 base vs after
whole 1920x1080         5.152 % differ (106832 of 2073600 px), max channel diff 255
region 1565,420,1905,662  0.085 % differ (70 of 82280 px), max channel diff 38
region 1655,980,1900,1075  0.000 % differ (0 of 23275 px), max channel diff 0
region 760,1012,1400,1055  0.091 % differ (25 of 27520 px), max channel diff 23
region 1595,85,1895,385  0.187 % differ (168 of 90000 px), max channel diff 34
region 0,940,470,1075   0.000 % differ (0 of 63450 px), max channel diff 0
== 600 base vs base2
whole 1920x1080         6.066 % differ (125779 of 2073600 px), max channel diff 255
region 1565,420,1905,662  0.080 % differ (66 of 82280 px), max channel diff 25
region 1655,980,1900,1075  0.000 % differ (0 of 23275 px), max channel diff 0
region 760,1012,1400,1055  0.051 % differ (14 of 27520 px), max channel diff 8
region 1595,85,1895,385  0.221 % differ (199 of 90000 px), max channel diff 76
region 0,940,470,1075   0.000 % differ (0 of 63450 px), max channel diff 0
```
Every shot run exited 0, with 2 Godot processes before and after (the after shot 600: 0 after).

## Result

| Metric | Measured | In band? |
|---|---|---|
| Every voice started over the seeded fight (760), base against after, two pairs | byte-identical | yes |
| The audio director's sync a tick, headless, 42 enemies | 315 / 399 µs base → 211 / 213 µs after | indication (busy machine) |
| `script.dps_meter.gd` | 94 / 94 → 53 / 61 µs a frame | indication |
| `hud.kit` | 171 / 168 → 149 / 153 µs a frame | indication |
| Still frames, HUD regions and whole | inside the same-build noise floor | yes |
| The average frame | NOT YET RUN (busy machine; the lead's quiet run) | — |

## Not made, and why

| Item | Measured | Why not |
|---|---|---|
| `hud.minimap`: the rewards key as a row of numbers instead of a string | 113 / 113 → 106 / 108 µs a frame | Under 20 µs; dropped. Its cost is the reader's dictionaries (`arenas()`, `overrun()`), which a key cannot avoid |
| `view.telegraphs` | 246-280 µs a frame; a temporary pre-pass showed about 206 of it is the sim's `telegraph()` worked out for every winding-up enemy | `LatchedReader` keeps each tick's telegraph for every view, and the avatars read the same ones for their windups: skipping it here moves the work, it does not remove it. The view's own share (about 100 µs) is its walk and two dictionaries a sync; no clean cut over 20 µs found. Its `_process` writes the flash and crack materials every frame even with nothing shown; skipping those writes could leave a stale pulse on the first frame a telegraph appears, so it was not made |
| `script.game_cursor.gd` | 10 µs a frame here (not the 61 µs quoted) | Under 20 µs |
| `hud.top` | 90 µs; of it the heat meter 51 (its `heat_state()` 21) | The reader's heat dictionary is read by the heat meter, the Vent line and the audio each tick; sharing it would change three callers' interfaces for about 20 µs; not made |
| `AudioEvents._overrun_edges` | 38 µs a tick | The reader's `overrun()` and `arenas()` dictionaries; no edge can be known without reading them |
| `script.minimap.gd` | 67 µs a frame | Its `_process` refreshes for the held map key between ticks; whether the frame's second refresh can be skipped depends on input timing, not proven |

## Tests

```
gdformat --check src scripts tests  -> exit 0;  gdlint src scripts tests -> Success: no problems found
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=<22 presentation unit files reaching the
  audio, DPS, kit, ability squares and minimap, and tests/unit/app/test_training_room.gd> -gexit
  exit=0  Scripts 23  Tests 143  Passing Tests 143  Asserts 16546   (with the minimap change, since dropped)
godot ... -gtest=tests/e2e/test_e2e_playground.gd,test_e2e_heat.gd,test_e2e_minimap.gd,
  tests/unit/presentation/test_ability_squares.gd,test_dps_tally.gd,test_audio_director.gd -gexit
  exit=0  Scripts 6  Tests 38  Passing Tests 38  Asserts 4562   (the committed tree)
godot ... -gdir=res://tests/arch,res://tests/golden -ginclude_subdirs -gexit
  exit=0  Scripts 5  Tests 13  Passing Tests 13  Asserts 27167
```
Godot processes: 2 before and after each run (the other agent's).

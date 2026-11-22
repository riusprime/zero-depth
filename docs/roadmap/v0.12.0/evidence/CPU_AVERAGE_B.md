# CPU_AVERAGE_B: idle views and HUD panels, the same frame for less work (Step 49)

- **Status:** RUN (indications on a shared machine; the quiet measure of the merged tree is the lead's: NOT YET RUN)
- **Build:** base `0f298c3d` (branch `lead-v0120`), after = the Step 49 commit on `v0120-s49`; Godot
  `4.7.2.stable.official.ed1daf0bf`; Windows 11 Pro, i7-10700K, RTX 3060 (the owner's PC)
- **Date:** 2026-11-22
- **Who ran it:** agent

## What was cut, and why nothing on screen changes

| View / panel | The cut | Why the picture is the same |
|---|---|---|
| `view.laser` (`laser_view.gd`) | A sync that reads no beam, Echo ghost or mine, after a sync that already read none, only moves the clock (`_tick`, `_since`, `width_now`) and returns | The full sync with nothing to show hides the same ribbons, impacts, muzzle and tubes again; the first sync with a beam runs whole (the look's digest first), so a beam appears on the same frame |
| `view.remnants` (`remnant_views.gd`) | The 112 bar/ring/gem slots: only the ones shown now or at the last sync get their visibility written; a flash slot hidden on an earlier sync is skipped | The slots past both counts were already hidden by an earlier write; nothing else writes them |
| `view.scatter` (`scatter_view.gd`) | The 24 slugs: only the slots shown now or at the last sync (all of them on a new look, which also writes their colours) | Same rule as the remnants |
| `view.kit`, `view.skill_fx`, `view.spikes`, `view.challenge`, `view.strikes` | An `ImmediateMesh` with no surface is not cleared again (`get_surface_count() > 0` first) | Clearing an empty mesh draws nothing different; it only had the renderer re-update every instance of the mesh (the blade's trail and edge with the Gun, every sync; the skill sweep; the boss-only rings, band and vortices, every sync or frame) |
| `view.lances` (`lance_view.gd`) | The circle's `motes_n` and `motion` shader parameters are written when they change, not every sync | The same values; a written parameter re-uploads the material |
| `view.strikes` (`boss_strike_views.gd`) | The glow materials' `motion` written when Reduced motion changes, not every draw | The same values; all glow materials are made in `_init`, before the first write |
| `view.actors` (`actor_views.gd`) | `_animate_if_seen` takes the enemy avatar from the parts already read once (`parts[5]`), not `get_meta` per enemy per sync | The same object (`parts[5]` is read from the same meta when the node is made) |
| `hud.kit` (`ability_squares.gd`) | The last sync's row is kept by reference and the new row built in a new array, instead of a deep copy of every slot dictionary each sync | The slot dictionaries are never changed after they are built; the redraw still happens exactly when the row differs |

Tried and dropped: keeping `any_boss()` and `boss_index()` once per tick in `LatchedReader` (keyed on the tick and the
actors' columns' hashes). The boss views' buckets did not move (`view.charge_bursts` 5.3/5.2 base against 5.4/5.7
after, `view.boss_vulnerable` 1.5/1.4 against 1.8/1.9): the key cost what the walk did. Not committed.

## Command

```
# one Godot process at a time; APPDATA=C:/Users/extri/Desktop/zerodepth/appdata-s49; base = `git stash push -- src`
godot --path . --fixed-fps 60 --resolution 640x360 --windowed --position -10000,-10000 \
  -s scripts/checks/view_dump.gd -- --out=build/s49/view_dump_<tag>.txt --frames=900
godot --path . --fixed-fps 60 --resolution 1920x1080 --windowed --position -10000,-10000 \
  -s scripts/checks/frame_probe.gd -- --biome=red_canyon --secs=12 --shot-at=<420|600>:build/s49/shot_<tag>_<N>.png
godot --path . --resolution 1920x1080 --windowed --position -10000,-10000 \
  -s scripts/checks/floor_fight_probe.gd -- --biome=<red_canyon|night_rocks> --secs=60 --perf-log
python <scratch>/buckets.py <perf csv>     # mean µs a run frame per bucket (frames with a breakdown, scene "run")
python <scratch>/pixdiff.py <a.png> <b.png>
```
`view_dump.gd` now also dumps the views this step changed (the blade, the Laser, the Lance, the remnants, the hero's
skill, the boss strikes, spikes and challenge: resting through its fight), and reads an `ImmediateMesh`'s surfaces by
their vertex arrays (it called `surface_get_array_len`, an `ArrayMesh`-only method, and errored on them).

## Raw output

The sequence (Godot process counts from `tasklist | grep -ci godot`, before and after each run; the other two
steps' agents ran Godot meanwhile):
```
[after shot 420] godot before: 2
[after shot 420] exit 0 ; shot-at: frame 420 -> build/s49/shot_after_420.png ; godot after: 2
[after shot 600] godot before: 2
[after shot 600] exit 0 ; shot-at: frame 600 -> build/s49/shot_after_600.png ; godot after: 2
(stashed src: base)
[base dump] godot before: 2
[base dump] exit 0 ; view_dump: 900 frames, 14400 lines, build/s49/view_dump_base.txt ; godot after: 2
[base shot 420] godot before: 2
[base shot 420] exit 0 ; shot-at: frame 420 -> build/s49/shot_base_420.png ; godot after: 2
[base shot 600] godot before: 2
[base shot 600] exit 0 ; shot-at: frame 600 -> build/s49/shot_base_600.png ; godot after: 2
[base2 shot 420] godot before: 2
[base2 shot 420] exit 0 ; shot-at: frame 420 -> build/s49/shot_base2_420.png ; godot after: 2
[base2 shot 600] godot before: 2
[base2 shot 600] exit 0 ; shot-at: frame 600 -> build/s49/shot_base2_600.png ; godot after: 2
[base1 floor red_canyon] godot before: 2
[base1 floor red_canyon] exit 0 ; perf-log: 7749 frames, 0 marks in .../perf_20261122_134154.csv ; godot after: 2
(src restored)
[after1 floor red_canyon] godot before: 2
[after1 floor red_canyon] exit 0 ; perf-log: 8147 frames, 0 marks in .../perf_20261122_134400.csv ; godot after: 2
(stashed src: base)
[base2 floor red_canyon] godot before: 2
[base2 floor red_canyon] exit 0 ; perf-log: 8100 frames, 0 marks in .../perf_20261122_134606.csv ; godot after: 2
(src restored)
[after2 floor red_canyon] godot before: 2
[after2 floor red_canyon] exit 0 ; perf-log: 7739 frames, 0 marks in .../perf_20261122_134812.csv ; godot after: 2
(stashed src: base)
[base1 floor night_rocks] godot before: 0
[base1 floor night_rocks] exit 0 ; perf-log: 9215 frames, 0 marks in .../perf_20261122_135019.csv ; godot after: 2
(src restored)
[after1 floor night_rocks] godot before: 2
[after1 floor night_rocks] exit 0 ; perf-log: 8626 frames, 0 marks in .../perf_20261122_135223.csv ; godot after: 2
```
The after-tree dump was taken earlier (`[after dump] exit 0 ; view_dump: 900 frames, 14400 lines`). The timed and
pictured "after" tree still held the `LatchedReader` memo that was then dropped (above); what was committed is a subset
of what was dumped and pictured.

View dump:
```
$ cmp view_dump_base.txt view_dump_after.txt && echo DUMP IDENTICAL
DUMP IDENTICAL
c780916260476075046520bcbe6d512e *view_dump_base.txt
c780916260476075046520bcbe6d512e *view_dump_after.txt
```

Still frames (the same-build repeat first, as the noise floor):
```
shot_base_420.png vs shot_base2_420.png: 1920x1080, differ>0 58028 (2.798%), differ>8 11787 (0.568%), max 251
shot_base_420.png vs shot_after_420.png: 1920x1080, differ>0 59978 (2.892%), differ>8 10721 (0.517%), max 253
shot_base2_420.png vs shot_after_420.png: 1920x1080, differ>0 69089 (3.332%), differ>8 10928 (0.527%), max 254
shot_base_600.png vs shot_base2_600.png: 1920x1080, differ>0 43637 (2.104%), differ>8 19522 (0.941%), max 254
shot_base_600.png vs shot_after_600.png: 1920x1080, differ>0 39487 (1.904%), differ>8 17679 (0.853%), max 254
shot_base2_600.png vs shot_after_600.png: 1920x1080, differ>0 43192 (2.083%), differ>8 19310 (0.931%), max 252
```

Buckets, µs a run frame (Red Canyon floor 3 twice each, alternated; Night Rocks floor 3 once each). The floor probe's
fight is not frame-for-frame the same between runs (the frame-time clock), so a bucket that depends on how many enemies
wind up (`view.telegraphs`, `view.actors` on Night Rocks) differs by the fight, not the code:
```
bucket                     base1_rc     after1_rc     base2_rc     after2_rc     base1_nr     after1_nr
frames / avg frame ms   6754/13.376   6997/12.747   6963/12.881   6719/13.428   8076/11.030   7495/11.916
sync_all                     1495.1        1413.9        1439.6        1451.4        1140.0        1285.4
frame.main.gd._on_frame       471.1         443.7         448.2         455.5         376.4         398.4
view.actors                   253.1         244.7         248.6         241.5         172.5         222.8
actors.animate                 13.8          12.5          13.7          11.6           8.0          12.0
hud.kit                        89.1          80.6          84.7          82.7          71.2          73.0
view.laser                     16.6           7.5          15.8           7.7          13.6           7.0
view.lances                    20.3          17.9          19.4          18.8          16.3          16.3
view.remnants                  26.1           7.7          25.1           8.2          21.0           7.1
view.kit                       48.2          44.8          46.9          45.6          38.6          40.4
view.skill_fx                  19.6          18.0          18.5          18.5          15.5          16.4
view.spikes                    14.3          13.8          13.6          14.1          11.5          12.2
view.strikes                   22.7          19.7          21.8          20.0          18.7          17.7
view.challenge                 10.2           9.3           9.5           9.6           8.1           8.2
view.scatter                   10.8           7.1          10.2           7.6           8.7           6.5
view.telegraphs                29.1          24.0          25.0          34.3          13.4          28.6
```
Sum of the touched buckets (laser, remnants, scatter, strikes, hud.kit, kit, skill_fx, spikes, challenge, lances,
actors.animate), Red Canyon: base 291.7 / 279.2, after 238.9 / 244.4.

## Result

| Metric | Measured | In band? |
|---|---|---|
| View dump, base against after (900 frames, 16 views) | byte-identical | yes |
| Still frames 420 and 600, base against after | 1.9–3.3 % of pixels differ, the same as base against base (2.1–2.8 %) | inside the noise floor |
| The touched script buckets, Red Canyon | about −35 to −50 µs a run frame (291.7 / 279.2 → 238.9 / 244.4); clearest: `view.remnants` −18, `view.laser` −9, `view.scatter` −3, `view.strikes` −2 to −3 | indication (busy machine) |
| The whole views' sync and the HUD | inside the runs' spread (`sync_all` 1495 / 1440 base, 1414 / 1451 after) | no gain shown |
| The engine work the empty-mesh guards and the parameter writes save | not timed (it is not in the script buckets) | NOT YET RUN |
| The average frame | NOT YET RUN (busy machine; the lead's quiet run) | — |

## Interpretation

The step measured what the brief asked and cut what could be cut without a visible change, but the gain is small:
about 40 µs a frame of script time, against the 2.25 ms of views and 0.57 ms of HUD in the owner's log. Measuring
per view showed why: the idle views each cost 2–25 µs, and most of that is their reads of the sim (`WorldReader`,
in `src/sim/`, not this step's) and their event cursors (`events_since`, which a skipped sync would lose), not work
on nodes. The largest buckets have something to show in a typical fight (`view.actors`, `view.attack_forms` (step
48's), `view.kit` with the Blade, `view.glaives`, `view.fireballs`, `view.telegraphs`, `view.heat_fx` with the Gun),
and `sync.occlusion` belongs to step 50.

Owner only: whether anything looks or feels different in play (OWNER ONLY).

# The Stone Thrower into the enemy batch, then native (step 51)

Machine: the owner's PC (i7-10700K, RTX 3060). Base `e1c0a233` (`lead-v0120`), worktree `wt-s51`, branch `v0120-s51`.
Another agent's Godot ran beside some runs: each run's Godot process count before and after is in its row (it counts
`tasklist | grep -ci godot`; one Godot run shows as 2 lines, so 2 is one other process). Timings are indications;
the lead measures the merged tree on a quiet machine. Raw logs: `C:/Users/extri/Desktop/zerodepth/appdata-s51/runs/`
(not tracked).

The fight (every run):
```
godot --path . --windowed --position -10000,-10000 -s scripts/checks/frame_probe.gd -- --biome=night_rocks \
  --enemies=42 --secs=30 --warm=5 --size=2560x1440 --kinds=stone_thrower <mode>
```
`--ab=no_batch` puts every batched kind back on its node (with only Stone Throwers it is the base's drawing);
`--ab=no_native_crowd` keeps the batch and runs its avatars in GDScript (half 1's drawing).

## What changed

- Half 1: `EnemyBatch.KINDS` takes `KIND_STONE_THROWER`. Its avatar already read nothing of the tree on the VAT path
  (no global transform, no timer: its pose comes from its own clocks and the sim's state, its death timer is the
  batch's, and `RuinsRocksViews` flies the thrown rock from the sim's place and facing), so no avatar code had to
  change for it. Its root, facing and avatar leave the tree; its disc, ring and bar become the batch's instances.
- Half 2: `ZdCrowd` runs the Stone Thrower's sync, frame step and pose (`native/src/zd_avatar_thrower.cpp`: its
  `apply_state`, `advance`, `_pose`, `_pose_rock`, `grip_points` and `StoneThrowerPoses`' clips, line by line, doubles
  for the GDScript's floats and dictionaries, floats for its `_vd`, its `Vector3`s and its transforms, the engine's
  sin/cos). The batch row grew from 80 to 113 doubles (`BatchAvatars.STRIDE`, `zd_avatar.h`); `apply_sync` takes six
  more inputs a slot (`in_more`: ticks into the state, the facing, the sim's three attack lengths). The GDScript stays
  the reference and the fallback; the avatar's reads `_peek()` and its events `_touch()` like the Charger's.

## Half 1 (GDScript batch)

| Run | Mode | Godot before / after | avg ms | nodes_process µs | actor view nodes |
|---|---|---|---:|---:|---:|
| base1 | clean `e1c0a233` | 0 / 2 | 22.028 | 12282 | 429 |
| after1 | KINDS change | 2 / 0 | 22.053 | 12175 | 114 |
| base2 | `--ab=no_batch` | 0 / 2 | 22.874 | 12345 | 469 |
| after2 | KINDS change | 2 / 0 | 25.372 | 13076 | 110 |

Raw span lines:
```
base1  frames=1363  avg_ms=22.028  p50_ms=20.369  p95_ms=35.170  p99_ms=47.431
base1  spans (us a frame, mean): probe_script=177  nodes_process=12282  after_process=1748  draw=3977  after_draw=487  physics_pre=54  nodes_physics=3030  physics_post=275  sum=22028
after1 frames=1361  avg_ms=22.053  p50_ms=21.134  p95_ms=32.759  p99_ms=42.053
after1 spans (us a frame, mean): probe_script=155  nodes_process=12175  after_process=1799  draw=4004  after_draw=797  physics_pre=52  nodes_physics=2921  physics_post=150  sum=22053
base2  frames=1312  avg_ms=22.874  p50_ms=22.235  p95_ms=33.636  p99_ms=41.646
base2  spans (us a frame, mean): probe_script=165  nodes_process=12345  after_process=2132  draw=4119  after_draw=889  physics_pre=52  nodes_physics=2913  physics_post=258  sum=22874
after2 frames=1183  avg_ms=25.372  p50_ms=23.813  p95_ms=40.195  p99_ms=48.089
after2 spans (us a frame, mean): probe_script=169  nodes_process=13076  after_process=2052  draw=5556  after_draw=941  physics_pre=61  nodes_physics=3342  physics_post=174  sum=25372
```
`--process --breakdown` (µs a frame; proportions only, PERF_TOOLS §4.3):
```
base2_proc (no_batch, 0 / 0)  script.stone_thrower_avatar.gd 3377  script.vat_crowd.gd 708  actors.update 1355  actors.enemy_sync 454
after2_proc (batch, 0 / 2)    batch.avatars 3239  script.vat_crowd.gd 724  actors.update 1307  actors.enemy_sync 531  batch.write 59
```
Reading: half 1 alone gains nothing measurable. The avatars' frame step costs the same in the batch's loop (3.2-3.4 ms
in `--process` mode) as in the tree; only the nodes go (429-469 to 110-114 under the actors' view), as PERF_TOOLS §4.7
says to expect. The spread between runs (22.0 to 25.4 ms) is the other agent's load.

## Half 2 (native)

| Run | Mode | Godot before / after | avg ms | nodes_process µs | p99 ms |
|---|---|---|---:|---:|---:|
| native a | native | 0 / 0 | 14.309 | 6327 | 28.665 |
| base a | `--ab=no_batch` | 0 / 0 | 18.737 | 10867 | 39.367 |
| GDScript a | `--ab=no_native_crowd` | 0 / 2 | 18.516 | 10922 | 36.020 |
| native b | native | 2 / 0 | 13.923 | 6018 | 25.889 |
| base b | `--ab=no_batch` | 0 / 0 | 17.639 | 10185 | 33.212 |

Raw span lines:
```
native_a frames=2097  avg_ms=14.309  p50_ms=13.745  p95_ms=21.907  p99_ms=28.665
native_a spans (us a frame, mean): probe_script=125  nodes_process=6327  after_process=1255  draw=4310  after_draw=340  physics_pre=30  nodes_physics=1842  physics_post=80  sum=14309
base_a   frames=1602  avg_ms=18.737  p50_ms=17.954  p95_ms=31.259  p99_ms=39.367
base_a   spans (us a frame, mean): probe_script=146  nodes_process=10867  after_process=1439  draw=3355  after_draw=355  physics_pre=38  nodes_physics=2340  physics_post=197  sum=18737
gd_a     frames=1621  avg_ms=18.516  p50_ms=18.325  p95_ms=28.183  p99_ms=36.020
gd_a     spans (us a frame, mean): probe_script=136  nodes_process=10922  after_process=1374  draw=3321  after_draw=334  physics_pre=38  nodes_physics=2286  physics_post=105  sum=18516
native_b frames=2156  avg_ms=13.923  p50_ms=13.639  p95_ms=20.257  p99_ms=25.889
native_b spans (us a frame, mean): probe_script=119  nodes_process=6018  after_process=1174  draw=4475  after_draw=317  physics_pre=29  nodes_physics=1717  physics_post=72  sum=13923
base_b   frames=1701  avg_ms=17.639  p50_ms=17.190  p95_ms=26.529  p99_ms=33.212
base_b   spans (us a frame, mean): probe_script=135  nodes_process=10185  after_process=1367  draw=3337  after_draw=327  physics_pre=33  nodes_physics=2072  physics_post=184  sum=17639
```
`--process --breakdown` (both 0 / 0 Godot processes):
```
native_proc  batch.avatars 107  script.vat_crowd.gd 92  batch.write 42  actors.update 1001  actors.enemy_sync 345  (frame_total 25315)
base_proc    script.stone_thrower_avatar.gd 3113  script.vat_crowd.gd 710  actors.update 1368  actors.enemy_sync 458  (frame_total 33511)
```
Reading: 42 Stone Throwers cost 13.9-14.3 ms a frame native against 17.6-18.7 ms on their nodes, about 4 ms a frame
(the process step 10.2-10.9 ms to 6.0-6.3 ms). The avatars' step goes from about 3.1 ms to 0.11 ms and VatCrowd's
writing from 0.71 to 0.09 ms (`--process` proportions). The draw span rises (3.3 to 4.3-4.5 ms): with the CPU work gone
the frame waits more on the GPU there (the frame rate is higher).

A mixed Night Rocks roster (`--kinds=charger,needle,swarmer,warden,rock_lurker,stone_thrower,dim_needle --process
--breakdown`, 0 / 0) keeps the whole batch native with the Stone Throwers in it (`batch.avatars 42` µs; without half 2
a Stone Thrower in the batch would put every batched avatar on the GDScript path, `BatchAvatars.all_native`).
Its rows for the other model kinds: `script.needle_avatar.gd 625  script.warden_avatar.gd 596
script.rock_lurker_avatar.gd 266`.

## The look

- Bit for bit: `tests/unit/native/test_native_crowd.gd`
  `test_the_native_stone_throwers_draw_the_script_ones_bodies`: 14 Stone Throwers (two far out, the catch-up), 300
  frames of 0, 1, 1, 2 ticks, a reduced-motion stretch, hits with flashes, flinches, knocks, holds and tints, two
  spawns, a kill every 40 frames (one with the rock in its hands: it falls), the furniture and every VAT set's instance
  and drive buffers native against GDScript, equal every frame. Proved able to fail: a change of 1e-7 in the GDScript
  flinch's lean (`0.14` to `0.1400001`) failed it at frame 2 (`field 3 at 198: 0.56373537 vs 0.5637354`), then put back.
- The twin probe (`--twin --secs=20`):
```
batched, GDScript (h1_twin, 2 / 2):  twin: 673 frames compared, 26717 body instances, 67944 furniture instances
  bar_basis 0 over 0, bar_pos 0.000001 over 0, body_basis 0, body_color 0, body_pos 0, disc_pos 0.000002, ring_pos 0.000002, bodies_drawn 0, chunks_drawn 0
  body_drives max 0.695296 over 69, bar_new_basis max 0.128896 over 59, bar_new_pos max 0.096804 over 30
batched, native (h2_twin, 0 / 0):    twin: 803 frames compared, 32013 body instances, 81089 furniture instances
  bar_basis 0 over 0, bar_pos 0.000001 over 0, body_basis 0, body_color 0, body_pos 0, disc_pos 0.000001, ring_pos 0.000001, bodies_drawn 0, chunks_drawn 0
  body_drives max 0.695296 over 76, bar_new_basis max 0.255606 over 68, bar_new_pos max 0.048231 over 36
nodes against nodes (--ab=no_batch, h1_twin_nobatch, 2 / 2): twin: 803 frames compared, 29790 body instances
  body_drives max 0.695296 over 72, every other row 0
```
  The `body_drives` row is the harness's own spread for this kind: two node views of Stone Throwers differ by the same
  0.695296 on about as many frames, with no batch (an attack's pose a frame apart between two views built at
  different moments). `bar_new` is a bar's first two frames shown, kept apart by the twin on purpose
  (`batch_twin.gd`). Every other row is 0 or under the 0.0005 tolerance.
- Still frames (`--fixed-fps 60 --shot-at=900:<png>`, 1920x1080, `--secs=30`): the scenario is not the same frame twice
  (its refills and the hero's strafe run on the wall clock during warm-up), so the noise floor is large and these
  pairs cannot show a small change. Half 1 (2 / 2 Godot): base vs after 1,577,437 pixels over 2/255, after vs
  after-again 1,597,048. Half 2 (0 / 0): GDScript vs native 174,283 pixels over 2/255, native vs native-again 166,182.
  Both pairs are at their noise floor; the proofs are the two above.

## Tests (the new library built: `bash scripts/native/build.sh debug`, exit 0)

```
-gtest=test_stone_thrower_avatar, test_enemy_batch, test_mine_layer_model, test_sniper_avatar, test_enemy_vat,
  test_charger_avatar, test_view_wake, tests/e2e/test_e2e_signatures_ruins_rocks   -> exit 0, 77/77 tests, 57863 asserts
-gdir=tests/arch,tests/golden,tests/unit/native -ginclude_subdirs                  -> exit 0, 46/46 tests, 28132 asserts
  (test_native_fixtures: the kernels' fixtures unchanged; native_kernels_hash.txt untouched)
gdformat --check src scripts tests && gdlint src scripts tests                     -> 1966 unchanged; no problems
```
Half 1 alone (old library): the six presentation and native files 68/68 (exit 0), the e2e 2/2 (exit 0).

## Not measured / left

- The merged tree on a quiet machine: NOT YET RUN (the lead's).
- Linux (gcc) equality of the new native code: NOT YET RUN (CI).

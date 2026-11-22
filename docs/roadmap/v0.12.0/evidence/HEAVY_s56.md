# The Sniper into the native enemy batch (step 56)

Build SHA: base `29552c31` (`lead-v0120` at `62ed3094` merged into the Needle base `7589fda2`) plus this commit's tree
(the runs after the merge were on the uncommitted worktree, the same files as committed; the twin probes and the
mutation runs were on `7589fda2` plus the same Sniper files, before the merge).
Machine: the owner's PC (i7-10700K, RTX 3060). Worktree `wt-s56`, branch `v0120-s56`. Other agents' Godot ran beside
these runs (Godot process counts by `tasklist | grep -ci godot`; one Godot run shows as 2 lines). Raw logs:
`C:/Users/extri/Desktop/zerodepth/appdata-s56/` (not tracked).

## Why the Sniper was not batched

`git log -S "KIND_SNIPER" -- src/presentation/world_view/enemy_batch.gd`: `5f431804` (v0.11.1 step 55) batched it on its
horde code body; `d744b0ff` (step 47b) took it out when it moved to the owner's model (SniperAvatar, LeggedRig), whose
avatar then had no batch row or native class. No look reason: the same gap the Needle had.

## What changed

- `EnemyBatch.KINDS` takes `KIND_SNIPER`. Its avatar reads nothing of the tree on the VAT path (its turn is its facing
  node's `rotation.y`, a plain object's; its death timer the batch's `DEATH_SECONDS`), as the Needle's. Its events
  `_touch()`, its reads `_peek()`.
- `ZdCrowd` runs its sync, frame step and pose (`native/src/zd_avatar_sniper.cpp`: `apply_state` with the shot, miss,
  vent, settle and hurt triggers, `advance`, `_pose` and every clip, `_body_xf` at the hub, `_lens`, `_muzzle`,
  `vat_drives`), line by line in the GDScript's float widths (doubles for its floats; floats for its `_vd` with every
  `+=` rounded back, its `_foot`, `_dir` and lean, its transforms; the engine's sin, cos), through the Needle's
  `LeggedRig` port unchanged.
- Native class 14 (`SNIPER_MODEL`: `SNIPER` = 7 is the old horde body's, still in the horde code). Its fields are
  43..110 (`SN_*`): 24 state fields, 17 raw drives, its three legs' rest hips, knees and feet (27, set once). `STRIDE`
  stays 124. `in_more`'s first value carries its HP, as the Needle's (the hit flinch).
- GDScript: `BatchSniperRow` (`batch_sniper_row.gd`) holds the row export and import; `BatchAvatars` adds the class,
  the HP input and the script fallback's sync. The GDScript stays the reference and the fallback.
- The Split Sniper (its biome's variant, the same avatar) is not on the VAT path (`VatCrowd.supports` takes base kinds
  only), so the batch cannot take it: it stays on its nodes (PRESENTATION_CONTRACTS §11.3 row). Its second kick is in
  the row (`SN_DOUBLE`) and is proven in the equality test below on base-kind avatars set to kick twice.
- `test_sniper_avatar.gd`'s "keeps its node (not batched)" now asserts the Sniper batched and the Split Sniper not.

## The look

- Bit for bit: `tests/unit/native/test_native_crowd_sniper.gd` `test_the_native_snipers_draw_the_script_ones_bodies` (its
  own file: `test_native_crowd.gd` reached 967 lines with the Warden's; the two share `CrowdTwins`,
  `tests/support/crowd_twins.gd`, the views' compare helpers moved out of `test_native_crowd.gd`): 12
  Snipers round an invulnerable hero (two far out: the catch-up), 300 frames of 0, 1, 1, 2 ticks, reduced motion on
  frames 200-229, HP drops every 7 frames, hits with flashes, flinches, knocks, holds and tints, two spawns, a kill
  every 40 frames picked mid-attack when one is, the second kick set on the hit avatars before frame 150; the furniture
  and every VAT set's instance and drive buffers native against GDScript, equal every frame. Its print:
  `sniper states seen (frames): { 0: 490, 1: 1735, 2: 824, 3: 10, 4: 264 }, { "flinched": 76, "held": 31, "killed": 5, "killed_attacking": 3 }`
  - On the merged tree (the whole file, 9 tests): exit 0, `9/9 passed`, 546 asserts.
  - Able to fail, then put back (`-gunit_test_name=snipers`, exit 1 each):
    - `sniper_avatar.gd` walk lean `0.03` to `0.0300001`:
      `frame 37: _looks 17|00000000|0.4500|1a1a22ff|3a55c0ff,2c4092ff,5f5551ff,ff2a22ff field 2 at 58: 0.34704995 vs 0.34704992`
    - `sniper_avatar.gd` second kick `0.85` to `0.8500001`:
      `frame 107: _looks 17|00000000|0.4500|1a1a22ff|3a55c0ff,2c4092ff,5f5551ff,ff2a22ff field 3 at 2: 0.5165002 vs 0.5165001`
- The twin probe (`frame_probe.gd -- --biome=night_rocks --enemies=42 --secs=20 --warm=5 --size=2560x1440
  --kinds=sniper --twin`, off screen, `sha=7589fda2` plus the Sniper files):
```
batched, native (0 Godot lines before, 2 after):
twin: 962 frames compared, 36546 body instances, 88392 furniture instances against the twin's nodes
twin differences (largest; frames over the threshold): bar_basis max 0.000000 over 0, bar_new_basis max 0.377528 over 81, bar_new_pos max 0.122720 over 46, bar_pos max 0.000002 over 0, bodies_drawn max 0.000000 over 0, body_basis max 0.000000 over 0, body_color max 0.000000 over 0, body_drives max 0.289146 over 2469, body_pos max 0.000000 over 0, chunks_drawn max 0.000000 over 0, disc_basis max 0.000000 over 0, disc_pos max 0.000002 over 0, ring_basis max 0.000000 over 0, ring_pos max 0.000002 over 0
nodes against nodes (--ab=no_batch, 4 / 4):
twin: 992 frames compared, 38243 body instances, 0 furniture instances against the twin's nodes
twin differences (largest; frames over the threshold): bodies_drawn max 0.000000 over 0, body_basis max 0.000000 over 0, body_color max 0.000000 over 0, body_drives max 0.060936 over 2978, body_pos max 0.000000 over 0, chunks_drawn max 0.000000 over 0
```
  Body places, bases and colours are 0 in both. The drives differ only on the shell's lift and tilt (drives 4 and 5),
  as often in both (2469 frames over 962 against 2978 over 992). The batched run's largest (0.289) is above this
  floor run's largest (0.061), so I looked at what it is, with a local diagnostic in `batch_twin.gd` (the example at
  each largest difference, with the Sniper's clocks; not committed). Two more runs:
```
batched (4 / -):   body_drives max 0.064902 over 3529
  twin max: body_drives frame 828 0.06490 id 521 clocks [3, 0.05, -1.0, -1.0, -1.0, -1.0, 1.0] vs [4, 0.05, 0.05, -1.0, -1.0, -1.0, 1.0] t 1.8100 vs 1.8100
nodes against nodes (0 / 2):   body_drives max 0.064902 over 2184 (981 frames)
  twin max: body_drives frame 632 0.06490 id 12 clocks [3, 0.05, -1.0, -1.0, -1.0, -1.0, 1.0] vs [4, 0.05, 0.05, -1.0, -1.0, -1.0, 1.0] t 15.4898 vs 15.4898
batched (2 / 2):   body_drives max 0.064902 over 2368 (828 frames)
  twin max: body_drives frame 366 0.06490 id 25 clocks [3, 0.05, ...] vs [4, 0.05, 0.05, ...] t 10.9627 vs 10.9627
```
  (clocks: state, shot, vent, settle, hurt, death, rise.) The largest difference in batched and in nodes-against-nodes
  runs is the same thing: at the same clock one view still shows the shot (state 3) and the other is already in the
  recovery (state 4) with its vent started, so the two views' syncs are a tick apart. That is the harness's own
  spread, with no batch at all. A vent at its height lifts the shell 0.035 m over the drive's 0.12 m span: 0.29, the
  first run's 0.289, which is the same skew caught deeper into a vent. Every other row is 0, under the 0.0005
  tolerance, or `bar_new` (a bar's first two frames, kept apart by the twin on purpose). All runs exit 0.
- The sim kernels' fixtures: `tests/golden` and `tests/unit/native` below;
  `tests/golden/fixtures/native_kernels_hash.txt` untouched (no sim file changed).

## Timing

NOT YET RUN (measured once with every kind moved; owner, 2026-11-22, through the lead).

## Tests (merged tree; `scripts/native/ensure.sh` built the library: exit 0, no compiler warning)

```
-gtest=res://tests/unit/native/test_native_crowd.gd            -> exit 0, 9/9 tests, 546 asserts (2 Godot lines before)
-gtest= 17 presentation files (test_sniper_avatar, test_needle_avatar, test_enemy_batch, test_enemy_vat,
  test_enemy_vat_more, test_view_wake, test_spawn_reuse, test_windup_tells, test_variant_views,
  test_enemy_palettes, test_telegraph_parity, test_enemy_versions, test_damage_flash, test_hit_impact,
  test_screen_cull, test_enemy_shadows, test_crowd_view)
                                                               -> exit 1, 137/138: test_sniper_avatar.gd:376
                                                                  "keeps its node (not batched)" (the old fact;
                                                                  updated, above)
-gtest=res://tests/unit/presentation/test_sniper_avatar.gd     -> exit 0, 17/17 tests, 909 asserts
-gdir=tests/arch,tests/golden,tests/unit/native -ginclude_subdirs  -> exit 0, 49/49 tests, 28491 asserts (4 Godot lines before)
gdformat --check src scripts tests && gdlint src scripts tests   -> 1970 unchanged; no problems
```
After merging `lead-v0120` at `ab4b110c` (the Warden) and moving the test, the library rebuilt (`ensure.sh` exit 0, no
compiler warning or error) and:
```
-gdir=tests/arch,tests/golden,tests/unit/native -ginclude_subdirs
  -gtest=tests/unit/presentation/test_sniper_avatar.gd,tests/unit/presentation/test_enemy_batch.gd
                                                               -> exit 0, 74/74 tests, 30034 asserts (0 Godot lines before)
gdformat --check src scripts tests && gdlint src scripts tests   -> 1974 unchanged; no problems
```
The Sniper's print in that run is the same as above (the same states, flinches, holds and kills).
No e2e or seams (the lead runs them with every kind moved).

## Not measured / left

- The timings and the merged tree on a quiet machine: NOT YET RUN (the lead's).
- Linux (gcc) equality of the new native code: NOT YET RUN (CI).
- The Split Sniper stays on its nodes (above).
- `test_native_crowd.gd` is 862 lines (its compare helpers in `CrowdTwins`), the Sniper's test in its own file.

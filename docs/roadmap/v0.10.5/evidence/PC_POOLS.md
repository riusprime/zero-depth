# v0.10.5 PC: idle effect pools wait outside the scene tree

Why: [PERF_PLAYLOG_2](PERF_PLAYLOG_2.md). After 42b279c5 and 8a1c9f38 filled the effect pools at load, the owner's
run had about 2,300 more nodes (median 5,988 → 8,303), and light fights got about 1 ms slower. Idle pooled instances
sat in the scene tree, where the engine pays for them every frame.

## What changed (presentation only, EI-07)

| Pool | Idle entries now | Back in the tree |
|---|---|---|
| `PackFx` (PackPrefill, FireballPack, the elite beam) | made in the tree (their scripts ready), then `remove_child`, kept in `_idle` | `_take` on spawn; `_release` parks it again (after an AnimationPlayer's `animation_finished`, one frame later, deferred, unless spawned again meanwhile) |
| `EliteViews` rings and the pooled arrival sigil | `remove_child` when parked (the sigil parks itself when its fade ends) | `_ring_for`, `_arrival` |
| `TelegraphViews` (PREPARED pairs) | made outside the tree | `_take`; `_put_back` removes it |
| `StatusVisuals` fading pieces | made outside the tree | `_take_fx`; removed when faded |
| `FireballViews` prepared look sets (3 MultiMeshInstance3D a look) | made outside the tree | the look's first draw (`FireballPack.attach`); then it stays, as a lazily made set did before |

- Each owner frees its out-of-tree entries on `NOTIFICATION_PREDELETE`. The new test reports no orphans from the pools.
  It reports one `BarChunks` orphan, which comes from `ActorViews`, not from this step.
- **Types that stay in the tree while idle: none.** Only the pool owners' own nodes (one each) and the live entries are
  in it.
- **The warm draw:** `ShaderWarmup.build` walks the view once, at the view build's `shader_warmup` job, behind the
  cover. It now also walks each owner's `idle_pieces()` as hidden pieces (with the owner's WARM_META, so the elite
  pieces are drawn whatever their material). Its proxies hold the meshes and materials, so the pieces don't need to be
  in the tree. The PackFx pools are filled after that job and draw nothing per floor: their pipelines are the
  session's (PackFxSessionWarm), as before.
- **The views' per-frame loops:**
  - PackFx `_process` walks only `_live` and `_warm_nodes`;
  - EliteViews walks only `_fx` and `_marks`;
  - StatusVisuals walks only `_fx`;
  - FireballViews' `_draw` already skips looks with nothing drawn (PF2).
  - One loop did walk idle entries: TelegraphViews `_process` set two shader parameters on every boss look's
    materials every frame, and `prepare()` makes all of them. It now updates only the looks that the last sync drew.
- `OBJECT_NODE_COUNT` (the perf log's `nodes` column) counts only the nodes in the tree. The nodes kept outside show as
  `OBJECT_ORPHAN_NODE_COUNT`.

## Nodes on a built floor

The run starts in the real `main.tscn` (STAGE_SEED). The script waits for the cover to open plus 90 frames, then walks
the tree. The machine is the owner's PC (i7-10700K), headless. No timing was measured.

Before: base `1f309fd5`, unchanged code. The script was then an earlier copy without the `orphan_node_count` line.

```
$ APPDATA=$(mktemp -d) godot --headless --fixed-fps 60 --path . -s scripts/checks/pool_node_count.gd 2>&1 | grep -E "pool_nodes|ERROR|SCRIPT"
pool_nodes: tree=5829
pool_nodes: object_node_count=5829
pool_nodes: view=5383
pool_nodes: pack_fx    in_tree=2715 idle_outside=0
pool_nodes: telegraphs in_tree=95 idle_outside=0
pool_nodes: status_fx  in_tree=7 idle_outside=0
pool_nodes: elite_fx   in_tree=14 idle_outside=0
pool_nodes: fireballs  in_tree=55 idle_outside=0
```

After: `1f309fd5` plus this step's working tree (the PC commit).

```
$ APPDATA=$(mktemp -d) godot --headless --fixed-fps 60 --path . -s scripts/checks/pool_node_count.gd 2>&1 | grep -E "pool_nodes|SCRIPT ERROR"
pool_nodes: tree=2948
pool_nodes: object_node_count=2948
pool_nodes: orphan_node_count=2881
pool_nodes: view=2502
pool_nodes: pack_fx    in_tree=1 idle_outside=420
pool_nodes: telegraphs in_tree=1 idle_outside=26
pool_nodes: status_fx  in_tree=1 idle_outside=6
pool_nodes: elite_fx   in_tree=1 idle_outside=6
pool_nodes: fireballs  in_tree=1 idle_outside=54
```

`idle_outside` counts pool entries (instance roots); `orphan_node_count` counts all their nodes. The tree went from
**5,829 to 2,948** nodes on this floor. The 2,881 nodes that left the tree are exactly the out-of-tree count.

The baseline run's exit output was filtered for `ERROR`, so the two runs' "ObjectDB instances leaked at exit" warnings
were not compared. The script quits without freeing `main`.

## Tests

The tests ran headless, each with a fresh `APPDATA`. The 8 other view files and the e2e ran on this step's final
`src/`. `test_first_use_warm.gd` was re-run after its `_nodes()` helper was fixed: in the first run, 6 tests failed
because the helper counted only the nodes in the tree, so a pool entry joining the tree looked like a new node. The
fixed helper adds the orphan count.

```
godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=<the files below> -gexit
res://tests/unit/presentation/test_elite_views.gd 7/7 passed.
res://tests/unit/presentation/test_enemy_fireball_views.gd 4/4 passed.
res://tests/unit/presentation/test_pack_fx.gd 17/17 passed.
res://tests/unit/presentation/test_pack_fx_session_warm.gd 4/4 passed.
res://tests/unit/presentation/test_shader_warmup.gd 3/3 passed.
res://tests/unit/presentation/test_status_visuals.gd 7/7 passed.
res://tests/unit/presentation/test_telegraph_parity.gd 3/3 passed.
res://tests/unit/presentation/test_boss_telegraph_parity.gd 9/9 passed.

godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/presentation/test_first_use_warm.gd -gexit
14/14 passed.
Tests                14
Passing Tests        14
Asserts             352
Orphans               2      (BarChunks, ActorViews')

godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/e2e/test_e2e_elites.gd -gexit
Tests                 1
Passing Tests         1
Asserts              18
---- All tests passed! ----
```

The new test, `test_idle_pool_entries_wait_outside_the_tree_after_the_load`, fills every pool as the load does. It
then checks three things:
- no idle entry is in the tree;
- a spawn takes its instance into the tree, and a release puts it back outside;
- the warm-up still makes its proxies from the out-of-tree pieces.

Lint: `gdformat --check` and `gdlint` on the 9 touched files report no problems.

Timing: NOT YET RUN (owner hardware, the owner's next logged run).

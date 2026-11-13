# The native core

The sim's hottest loops are C++, in a GDExtension library built from `native/`. This page is the as-built contract:
what the library does in each tick phase, what stays GDScript, the rules that keep its results deterministic, and how
to change it safely. The design written before the build is
[`../roadmap/v0.11.1/NATIVE_CORE.md`](../roadmap/v0.11.1/NATIVE_CORE.md) (history: where it and this page differ,
this page and the code win). How to build the library: [`../../native/README.md`](../../native/README.md).

## 1. What it is, and what it is not

- **It is** one C++ class per world, `ZdWorld` (`native/src/zd_world.h`), with one batched call per tick phase. Each
  call reads the GDScript stores' columns, does the per-row arithmetic for every row it owns, writes the columns it
  changed, and hands back a short list of what GDScript must finish. That call is a **kernel**. There are five:
  `move` (the collision passes), `ai` (enemy thinking and steering), `strike` (enemy hit tests), `shots` (the
  projectile sweep) and `nav` (the path flood).
- **It is not** the rules. Damage, procs, cards, statuses, the hero's abilities, bosses, elites, events, spawning,
  rewards and every random draw stay GDScript. A kernel never decides what a hit does; it says that a hit happened.
- **It holds no state of its own.** Between two calls `ZdWorld` keeps only caches derived from the world (§3). The
  hashed truth is the GDScript columns, so the snapshot, the state hash and the views do not know the library exists.
- **Presentation has its own class**, `ZdCrowd` (`native/src/zd_crowd.h`, `zd_crowd_avatars.cpp`, `zd_avatar.*`):
  the batched enemies' instance writer. It reads only what the views give it and is described in
  [`PRESENTATION_CONTRACTS.md`](PRESENTATION_CONTRACTS.md) §11. It is not a sim kernel.

Terms used on this page:

| Term | Meaning |
|---|---|
| **Kernel** | One batched `ZdWorld` call for one phase: `resolve_actors`, `think`, `move`, `strike`, `sweep_shots`, `nav_flood` |
| **Bridge** | The GDScript file that calls a kernel and finishes its work: `src/sim/world/native_*.gd` |
| **Intent** | One entry in the list a kernel hands back: a code, a row and up to two ints and four floats. GDScript applies the list in order |
| **Table kind** | An enemy kind the per-kind table runs natively: mode NATIVE or HOOKED (§5) |
| **Hook** | A bit in a table kind's row that makes the kernel emit an extra intent so GDScript runs that kind's own rule at that moment |
| **Script row** | A row the kernels skip and GDScript runs as before: a SCRIPT kind, the dummy, or any row in an egg state |
| **Column** | A packed array field of `ActorStore` or `ProjectileStore` (`pos_x`, `state`, `life`, …) |

## 2. The tick, phase by phase

Phases as numbered in `World.step` ([`SIM_CONTRACTS.md`](SIM_CONTRACTS.md) §2). Only the rows below changed; every
other phase is GDScript. Since step 54b each kernel is the only path for what it covers: there are no kernel bits
and no GDScript branch beside them (`world.gd` calls each bridge once a phase: `_run_ai`, `_move_and_collide`,
`_projectile_hits`, `_begin_nav_flood`, and `NativeStrike.resolve` in place of the old `_resolve_enemies`).

| Phase | Kernel (C++) | Reads | Writes / returns | GDScript after it (bridge) |
|---|---|---|---|---|
| 3 nav | `nav_flood(seeds, max_steps, targets)` (`zd_nav.cpp`), on the `NavField.PERIOD` tick, the whole flood in one call | the nav grid cache, its extra cells, the seeds and targets | the distances (`nav_dist()`), the work, whether it stopped at its targets | `NavField.flood` copies `nav_dist()` into `NavField.dist` (`NativeNav.fill`) |
| 3 ai | `think(actors, hero, tick, held, mine_owners)` (`zd_ai.cpp`) | the actor columns, the hero (9 floats, `NativeAi.hero_of`), a spell-stun byte a row (or empty), the mines' owners | `state state_t cd fire_cd pick windup lock_a facing lock_x lock_y lock_len plan_x plan_y plan_block`, each group only when changed; intents | `NativeAi._apply_think`, then the script rows' `think` (`_script_think`) |
| 5 move (steer) | `move(actors, hero, slow, slow_permille)` (`zd_ai.cpp`) | the actor columns; a slow factor a row only while an element pair or a spell hold could change it | `pos_x pos_y lock_x lock_y lock_len lock_a facing`; intents | the script rows steer **before** the call (`NativeAi.move`); `CHARGE_STEP` intents after it; then `PlayerSkill.push` |
| 5 move (collide) | `resolve_actors(actors, through, heavy, ghost0, iters)` (`zd_collide.cpp`) | `pos_x pos_y radius`, the wall and solid caches, the boss flags | `pos_x pos_y`; the number of pair pushes | `NativeMove.resolve` rebuilds `World._actor_grid` from the final positions for the later phases |
| 6 resolve | `strike(actors, hero)` (`zd_strike.cpp`) | the actor columns, the hero | nothing written; a list of entries | `NativeStrike.resolve`: the list (all but touches), then the script rows' `resolve`, then the critters' touches |
| 6 proj | `sweep_shots(projectiles, actors, skip, walls_only)` (`zd_shots.cpp`) | the projectile and actor columns, a Mine-hold byte and a walls-only byte a projectile (each empty when unused) | the advanced `pos_x pos_y life` of the projectiles that met nothing; at most one event a projectile | `NativeShots.sweep`: the steering pre-pass runs **before** the call; the events after it, each through `ProjectileContacts` |

Every list a kernel returns is **ascending by row (or projectile), then by code**, and GDScript applies it in that
order. A kernel returns `-1` and changes nothing when a cache is missing or a column has the wrong length. The
bridge then logs an error and nothing falls back to GDScript (there is no GDScript version): `think` and
`strike` leave that phase's table rows (and its script rows) unrun for the tick, `move` leaves the table rows
standing (the script rows have already moved), and `sweep_shots` skips the phase's contacts.

### 2.1 The intent and entry codes

`think` and `move` (`zd_ai.h` `Intent`, mirrored in `NativeAi.Intent`):

| Code | From | Meaning | GDScript does |
|---|---|---|---|
| 2 `THINK_TICK` | think | the Rubble Warden's think tick, before the frozen check | `Variants.on_think` |
| 3 `MOVE_TICK` | think | the Mender heals instead of attacking | `EnemyAi._mend` |
| 4 `WINDUP_START` | think | an attack began; `a` the aim | `NativeAi._windup_start`: the windup length drawn from `rng_enemy`, the Arc Caster's spell, the Star Warper's star |
| 5 `WINDUP_END` | think | a windup ran out for a kind that may cancel (the Star Warper) | `StarfallKinds.cancel`, else the row goes ACTIVE |
| 6 `RELOCATE` | think | a Sniper's recovery ended | `EnemyAi._plan_relocation` (it draws) |
| 7 `CHARGE_STEP` | move | a charge with a trail stepped | `Variants.on_charge_step` |

Codes 1 (`FLOW`) and 8 (`RELOCATE_STEP`) are gone since step 54b: they handed a blocked walk and a relocating
Sniper's walk to the GDScript flow field while the flood could still be GDScript's; the kernels now read the nav
cache themselves (`NativeAi.ready` keeps it current with `NativeNav.sync`). The numbers stay unused.

`strike` (`zd_strike.h` `StrikeOut`, mirrored in `NativeStrike.Out`):

| Code | Meaning | GDScript does |
|---|---|---|
| 1 `HIT` | a shape touched the hero and its origin sees the hero; `a` damage, `b` tags, `(f0, f1)` the origin when `f2` is 1 | `Damage.hit` with `EnemyAi.powered` |
| 2 `CONTACT` | a contact kind's body touched the hero; `b` 1 when seen | `fire_cd = 1` (its one hit), then the hit when seen |
| 3 `TOUCH` | a critter's touch | `cd = contact_cd_ticks`, then the hit when seen; applied after the script rows |
| 4 `BOLT` | a burst shot; `a` its angle, `b` its index | `EnemyAi._fire`, `fire_cd += 1`, the Dim Needle's look, `BossRicochet.arm_turret` |
| 5 `WAVE` | a pattern's wave; `a` the wave, `b` the slot | `EnemyAi.fire_wave` (its caps and fairness) |
| 6 `ACTIVE_HOOK` | a hooked kind's active tick | `EnemyAi._resolve_horde`: mines, the Frost Spitter's blob, the Star Warper's blink, the split lanes |

When it applies the list, `NativeStrike` stops at the first entry after the hero dies and skips a row that is dead or
frozen, as the per-enemy checks did.

`sweep_shots` (`zd_shots.h`, `NativeShots.HOLD/CONTACT/END`): `HOLD` a Mine disc holding (`GlaiveMods.hold`);
`CONTACT` (projectile, body or -1, wall or -1, `t`); `END` advanced and out of life (`ProjectileContacts.range_end`).
A contact whose body died earlier in the same phase is swept again with `sweep_one` against the bodies as they stand,
so a dead body is never hit.

### 2.2 A worked example: an attack start

A Needle in MOVE sees the hero in range with its cooldown done.

1. `ZdWorld::think` (`zd_ai.cpp`, the `S_MOVE` case) does everything that needs no draw: `state = WINDUP`,
   `state_t = 0`, `lock_x/lock_y` = its position, `lock_a` = the aim, `windup` = the table's `K_WINDUP`, and the aim
   (`AIM_AT_START`). It emits `WINDUP_START(row, aim)` only when a draw or an extra is due: the row's
   `K_WINDUP_MAX > K_WINDUP`, the kind casts spells, or it has the windup-start hook.
2. At the end of the call it writes the changed column groups back as new arrays (`cols::put_i32`, `put_f32`) and
   returns the intent count.
3. `NativeAi.think` reads `ai_intents_i()`/`ai_intents_f()` and, for this row, calls `_windup_start`, which draws
   `a.windup[i] = w.rng_enemy.range_int(windup_ticks, windup_max_ticks)` when the table's maximum is longer. Every row's draws come in ascending row
   order, so the `rng_enemy` stream advances the same way on every run.
4. Then the script rows think (`_script_think`: bosses, elites, signatures, the dummy, then the critters in one loop).

## 3. The data model

| What | Owner | On the native side |
|---|---|---|
| Every `ActorStore` and `ProjectileStore` column | GDScript (hashed, snapshotted, read by views) | read by name at each call, never kept |
| `NavField.dist` | GDScript (snapshotted) | a cache of the last flooded field; written back whole after a flood |
| Walls and standing solids | GDScript (`World.walls`, `Solids`) | a wall grid, sent again when `World._wall_rev` changes (`NativeWorld.sync_walls`) |
| The direction tables | GDScript (`Kin.cos_table`, `sin_table`: 513 floats each) | the same floats, sent once at the world's start (`NativeWorld.setup`) |
| The per-kind table and the tuning | GDScript content (`NativeKindTable.build`) | sent when a table-reading kernel needs it and the world's `tuning` object changed (`NativeWorld.sync_kinds`, stamped by identity) |
| The nav grid, its extra cells | GDScript (`NavField`) | sent when `NavField.grid_rev` or `dist_rev` changed (`NativeNav.sync`) |
| The body grid | derived | rebuilt inside each kernel that needs it, every call |

The rules:
- **Columns cross by name.** A kernel reads a column with `Object::get` (`cols::f32`, `i32`, `u8` in
  `zd_columns.h`); the packed array shares the store's buffer, so the read costs the call, not a copy (about 0.1 µs a
  read, about 0.3 µs a write, by the shared core's PROGRESS row; `scripts/bench/native_columns_bench.gd` measures
  it).
- **A kernel writes new arrays, never in place.** A changed column goes back with `cols::put_*`, which builds a new
  packed array and calls `Object::set`. Writing into the array it was given would be a silent copy (copy on write)
  and the store would keep the old values. A kernel that changes a column carries every row it does not own (script
  rows) through unchanged.
- **No GDScript local holds a column across a native call.** `var px := a.pos_x`, then a kernel, then `px[i]` reads
  the old array. The bridges read through the store each time (`NativeAi`'s and `NativeStrike`'s headers say so); a
  change to `world.gd` near a kernel call must keep that.
- **Every World makes its native object itself.** `World._init` calls `NativeWorld.make()`
  (`src/sim/world/native_world.gd`), which checks `ClassDB.class_exists(&"ZdWorld")`, instantiates it and sends the
  direction tables. That file is the one place in `src/sim` allowed to name `ClassDB`, with exactly those two calls
  (`tests/arch/test_sim_purity.gd`). There is no factory, no `World.native_kernels`, no `native_on` and no kernel
  bits (step 54b deleted `NativeSwitch`). A `NavField` flooded on its own (a test bot's) makes its own native side
  the same way.
- **Without the library** `make()` returns null and reports `NativeWorld.MISSING` (how to build it) once a process;
  that `World`'s `step()` then only counts ticks. The game's start (`NativeCheck.passes`, `src/app/native_check.gd`)
  shows the message and quits with exit code 1; a GUT run stops before its first test with exit code 1
  (`tests/support/native_required_hook.gd`, `res://.gutconfig.json`). There is no GDScript fallback.

### 3.1 A worked example: a kernel needs a new column

Say `strike` must read `ActorStore.power`, which no kernel reads yet.

1. `native/src/zd_columns.h`: add `power` to `ColumnNames` (it is already there; a new store field would add its
   `godot::StringName` here) and initialise it by its exact GDScript field name in `zd_columns.cpp`'s constructor.
2. In the kernel: `const PackedInt32Array pw = cols::i32(actors, names_.power);`, then check its length against the
   row count and return `-1` if it differs. Read it through `pw.ptr()`, never `ptrw()`.
3. If the kernel changes it: copy it into the scratch (`cols::load`), change the copy, and send it back once at the
   end with `cols::put_i32(actors, names_.power, scratch.power)`.
4. Nothing changes in the snapshot or the hash: the column was already GDScript's.

## 4. Determinism

The game's results are recorded on Windows (MSVC) and checked on Linux (gcc). Each rule below exists because
breaking it changes a float bit on one compiler or one run and not another.

| Rule | Why | Where it is enforced |
|---|---|---|
| A value that lands in a column is a `float` (IEEE single); a local that mirrors a GDScript `float` (a double) is a `double` | The columns are float32 and the hash reads them; GDScript's own locals are doubles, so `Trig::angle_of` reckons in double to give `Kin.angle_of` exactly | code review; `test_native_geom.gd` |
| MSVC `/fp:precise`, gcc and clang `-ffp-contract=off -fno-fast-math`, the x86-64 baseline (SSE2) | Fast-math reorders sums; contraction fuses `a*b+c` into one rounding (FMA); `-march=native` or AVX lets each CPU pick its own instructions | `native/SConstruct` fails the build on a banned flag |
| No C-library `sin`, `cos`, `atan2`, `pow`, `exp`, `log` in sim code | Each C library rounds them its own way. Directions come from `Kin`'s 513-entry tables, sent to `Trig`; `dir`, `angle_of`, `turn_toward` are ported once in `zd_geom` | code review; `test_native_geom.gd` (every angle, seeded vectors, `turn_toward` exact) |
| The one exception, presentation only: `zd_avatar.cpp` calls the engine's own `sin`, `cos`, `exp`, `asin` (`UtilityFunctions`) | The batched avatars must give GDScript's numbers bit for bit, and GDScript's are the engine's; the MSVC library's `sinf` differed in the last bit near π. The engine's *float* sine and cosine (what its `Basis` builders call) are per platform (`fsin`, `fcos`): on Windows the engine's double function rounded to float; on Linux the system's `sinf`/`cosf` themselves, which the engine and the library share and which are not always the double function rounded (the PR's first Linux run failed on exactly that: one buffer float off by its last bit) | `test_native_crowd.gd` (bit-for-bit buffers), on both platforms in CI |
| Every loop runs over rows in ascending index; grids are counting sorts (stable); candidate lists ascend; sums over neighbours add in that order | A different visiting order changes a float sum | code review |
| A sweep's tie on `t` keeps the wall, then the lower wall index, then the lower body index | So two equal contacts always resolve the same way | `test_native_shots.gd` |
| No `std::unordered_*` iteration, no pointer-ordered containers, no threads | Their order depends on addresses or scheduling | code review |
| Angles are `int32` in 1/4096 turns with `& 4095`; `%` is written out where GDScript's `posmod` is meant; float to int only on values in range | C++ `%` truncates toward zero; an out-of-range conversion is undefined | code review |
| **No random draw in C++** | Every draw stays on the sim's named streams, in GDScript, at the intents, in ascending row order (EI-05) | the intents' design; the outcome hashes |
| No clock, OS or engine query in a kernel | Results must not depend on time; the `bench_*` and probe methods are never called from `src/sim` | code review |

**The fixtures.** `ZdWorld.determinism_probe()` runs a fixed scene (walls, solids, 240 bodies) through the
collision kernel for 60 ticks and returns the FNV-1a hash of every result's float bits. `tests/unit/app/
test_native_move.gd` pins the value MSVC gives (`DETERMINISM_PROBE`). Since step 54b every kernel has a fixture too
(`tests/support/native_fixtures.gd`): on a seeded horde world (floor 3 of run 31, 60 table-kind enemies, 120 ticks
played) each kernel is called once, directly (`nav`, `think`, `move`, `collide`, `strike`, `shots`, plus the probe),
and its outputs and the columns it writes are hashed (`tests/golden/fixtures/native_kernels_hash.txt`); the same
world played 600 ticks gives `native_horde_hash.txt`. Both were recorded from the owner's Windows build (MSVC,
`tests/golden/generate_native_fixtures.gd`). `tests/golden/test_native_fixtures.gd` checks them in every GUT run (the
debug library) and `scripts/native/check_release.sh` with the release library; a mismatch says "the native core gives
different results on this compiler/platform" and names the kernel. The first Linux (gcc) run is on the PR into
`main` (the `verify` workflow's checks job runs both builds); it has not run locally. The goldens re-recorded from
the native core at step 54b are listed in PROGRESS "Goldens changed on purpose".

## 5. The per-kind table

`NativeKindTable` (`src/sim/ai/native_kind_table.gd`) builds one row per `ActorStore.Kind` (54 kinds: the player, the
dummy and 52 enemies): `KI` ints and `KF` floats, plus `TUNING` floats beside it, from the world's compiled
`EnemyTable`s and `EnemyAi`'s per-kind lookups. It is content, not state: never hashed, rebuilt from the loadout.
`native/src/zd_kinds.h` holds the same offsets and bits; `ZdWorld.kind_layout()` hands them back and
`test_native_ai.gd` compares them one by one, so a field added on one side only fails a test.

| Mode | Kinds | Count |
|---|---|---|
| **NATIVE** (the table alone) | Charger, Hatchling, Swarmer, Warden, Needle, Lens Drone, Splitter, Splitling, Shield Bearer, Sniper, Arc Caster, Bomb Drone, Gravity Node, Kiln Beetle, Glacier Turtle, the five critters (Dust Mite, Cave Bat, Ember Flea, Ice Crab, Star Mote) | 20 |
| **HOOKED** (the table plus hooks) | Mender, Mine Layer, Rubble Warden, Dim Needle, Ember Charger, Frost Charger, Split Sniper, Frost Spitter, Star Warper | 9 |
| **SCRIPT** (GDScript runs the row) | the bosses, the elites, the Ruins and Night Rocks signatures, the Cinder Priest, the player, the dummy | 25 |

The list is pinned by `test_the_kinds_run_in_the_modes_of_the_design` (`tests/unit/app/test_native_move.gd`).
`NativeKindTable.mode_of` decides it:
1. no `EnemyTable` in this world, not an enemy kind, or the boss role: SCRIPT;
2. the elite or Ruins flag (`EnemyAi.F_ELITE`, `F_RUINS`), or the Cinder Priest: SCRIPT;
3. any hook bit (`hooks_of`), or `NEEDS_MAY` (the Mine Layer's mine count): HOOKED;
4. else NATIVE.

At run time a row of a table kind in a state at or past `BossSignatures.EGG` is a script row too
(`ZdWorld.rows_for_script`). A script row's body still goes through the native collision passes.

The hooks (`HOOK_*` in `NativeKindTable`, `kt::HOOK_*` in `zd_kinds.h`) and the intent each one adds: `THINK_TICK`
(the Rubble Warden), `MOVE_TICK` (the Mender), `WINDUP_START` and `WINDUP_END` (the Star Warper), `CHARGE_STEP` (a
charging kind whose table has a trail), `BOLT` (the Dim Needle's look, applied inside the `BOLT` entry), `ACTIVE`
(Mine Layer, Frost Spitter, Star Warper, Split Sniper).

### 5.1 Adding an enemy kind

1. Add the kind and its `EnemyTable` as for any enemy ([`CONTENT_SCHEMA.md`](CONTENT_SCHEMA.md)).
2. Decide its mode by what its rules need:
   - **NATIVE** when everything it does is the generic state machine with a shape in `NativeKindTable.Shape`
     (contact, locked disc, bash lane, snipe lane, rune disc, burst, pattern) and the flags in `flags_for`. Give it a
     `behaviour_of` base kind that already runs natively, or add its flags.
   - **HOOKED** when it is a native kind plus one rule at a known moment (a think tick, a move tick, a windup start or
     end, a charge step, a bolt, its active tick). Add the bit in `hooks_of` and, if it needs an `ACTIVE` rule, its
     branch in `EnemyAi._resolve_horde`.
   - **SCRIPT** when it has its own walk, its own state machine or reads state another enemy writes in the same phase
     (bosses, elites, the signatures). Give it the boss role, the elite or Ruins flag, or name it in `mode_of`.
3. Update the lists in `test_the_kinds_run_in_the_modes_of_the_design`. A table kind is covered by
   `test_every_table_kind_runs_the_state_cycle` (`tests/unit/native/test_native_ai.gd`: it only ever takes the state
   machine's steps) and `test_the_table_kinds_hurt_the_hero_and_fire` (`test_native_strike.gd`) by being in the table;
   since step 54b there is no GDScript path to compare with, so these are rule tests, and the kind's own behaviour
   tests (`tests/unit/sim/`) run on the native path.
4. A new field the kernels must read: add the `K_*`/`KF_*`/`T_*` constant at the end of its block in
   `native_kind_table.gd`, the same constant in `zd_kinds.h`, its place in `kind_layout()` and in the layout test.
   `KI`/`KF` grow by themselves.

## 6. Saves, snapshots and the state hash

- `WorldSnapshot.WORLD_KEPT` lists `native` as setup, not state (`src/sim/core/world_snapshot.gd`).
  A snapshot never carries the native side.
- A restore rebuilds every cache by itself: the wall revision differs, so `sync_walls` resends the walls; the kind
  table is stamped by the `tuning` object's identity, so a new world resends it; `from_snapshot` bumps
  `nav.dist_rev`, so `NativeNav.sync` resends the restored distances.
- The state hash is the same function over the same columns. Save and resume are exact because the truth is the
  float32 and int32 columns, which round-trip bit for bit. Proved per kernel by the "same twice and resumes exactly"
  tests (§8) and, across sims, by `tests/unit/app/test_native_core.gd` (a save made under one sim resumes under the
  other with an equal state hash).
- The native core does not give the GDScript sim's results bit for bit (another order, single precision; owner,
  LOCKED_DECISIONS 2026-11-11). `horde_phases` at 120 enemies: script `14f2fbce…bcad`, native `a769a0c2…ccbd94`, each
  the same on every run ([`PERF_NATIVE.md`](../roadmap/v0.11.1/evidence/PERF_NATIVE.md)).

## 7. Files

| File | Owns |
|---|---|
| `native/src/zd_world.{h,cpp}` | `ZdWorld`: the caches, the setup methods, the probes, every kernel's declaration and binding (in its own labelled block) |
| `native/src/zd_geom.{h,cpp}` | `Box`, the circle and sweep tests, `WallGrid`, `BodyGrid`, `Trig` (`dir`, `angle_of`, `turn_toward`) |
| `native/src/zd_columns.{h,cpp}` | `ColumnNames`, `cols::` read and write by name |
| `native/src/zd_kinds.h` | the per-kind table's offsets, flags and hooks (mirror of `NativeKindTable`) |
| `native/src/zd_collide.{h,cpp}` | `resolve`, `resolve_actors`, `determinism_probe`, the pair benchmarks |
| `native/src/zd_ai.{h,cpp}` | `think`, `move`, the intents, `kind_layout`, `ai_hero_layout` |
| `native/src/zd_strike.{h,cpp}` | `strike`, its entry codes and shapes, `strike_layout` |
| `native/src/zd_shots.{h,cpp}` | `sweep_shots`, `shot_events`, `shot_t`, `sweep_one` |
| `native/src/zd_nav.{h,cpp}` | the nav grid cache, `nav_flood`, `nav_dist`, `nav::direction` |
| `native/src/zd_crowd.{h,cpp}`, `zd_crowd_avatars.cpp`, `zd_avatar.{h,cpp}` | `ZdCrowd`: presentation only ([`PRESENTATION_CONTRACTS.md`](PRESENTATION_CONTRACTS.md) §11) |
| `native/src/register_types.cpp` | registers `ZdWorld` and `ZdCrowd` |
| `native/SConstruct`, `scripts/native/build.sh`, `fetch_bindings.sh` | the build, its float flags, the bindings at `native/GODOT_CPP_COMMIT` |
| `src/app/native_check.gd` | `NativeCheck`: the game's start without the library: reports `NativeWorld.MISSING`, shows it in a dialog when there is a display, quits with exit code 1 |
| `src/sim/world/native_world.gd` | `NativeWorld`: `make` (the sim's only `ClassDB` use), `available`, `MISSING` and `report_missing`, `sync_walls`, `sync_kinds`, `obb_floats` |
| `src/sim/world/native_move.gd`, `native_ai.gd`, `native_strike.gd`, `native_shots.gd`, `native_nav.gd` | the bridges: the call, the masks, the intent handlers |
| `src/sim/ai/native_kind_table.gd` | the per-kind table, its modes, flags, hooks and shapes |
| `src/sim/combat/projectile_contacts.gd` | what a projectile contact does (damage, pierce, bounce, split, procs, the end hooks), shared by both sweep paths |
| `tests/unit/native/`, `tests/unit/app/test_native_*.gd`, `tests/golden/test_native_fixtures.gd`, `tests/support/native_fixtures.gd`, `tests/support/native_required_hook.gd` (a GUT run stops at once without the library) | the tests ([`TEST_MATRIX.md`](TEST_MATRIX.md) §7) |

## 8. Changing or adding a kernel safely

The recipe at the top of `native/src/zd_world.h`, with what the kernels' authors actually had to do:

1. **Measure first.** Run `horde_phases.gd` (or `shot_phases.gd`, `attack_phases.gd`) on the phase and read its
   share of the tick ([`../process/PERF_TOOLS.md`](../process/PERF_TOOLS.md)). A loop under a few hundredths of a
   millisecond is not worth a kernel.
2. **`zd_<name>.h`:** the kernel's scratch struct (working vectors, rebuilt every call) and its codes. Mirror every
   code and offset in the bridge's GDScript enum, and expose a `*_layout()` probe that returns them so a test can
   compare the two.
3. **`zd_<name>.cpp`:** `int ZdWorld::<name>(...)`, reading the caches (`walls_`, `trig_`, `kinds_`, `nav_`,
   `names_`) and the columns by name. Check every column's length first and return `-1` on a mismatch. Loop rows in
   ascending index. Write changed columns once, at the end, as new arrays. Emit intents for anything that needs a
   draw or a rule.
4. **`zd_world.h`:** add the `#include` (KERNEL INCLUDES), the declarations (KERNEL METHODS) and the scratch member
   (KERNEL SCRATCH), each in its own block separated by a blank line so parallel kernels merge without touching each
   other's lines. **`zd_world.cpp`:** the `ClassDB::bind_method` lines (KERNEL BINDINGS). `SConstruct` compiles every
   `native/src/*.cpp`; no build change is needed.
5. **The bridge, `src/sim/world/native_<name>.gd`:** sync the caches first (`NativeWorld.sync_walls`,
   `NativeAi.ready`), build the masks only when they can be non-empty, call the kernel, apply the list in order, then
   run the script rows. Move any rule both paths need into a shared file first, unchanged (as the sweep's hit body
   went to `ProjectileContacts`).
6. **`world.gd`:** one branch at the phase. Keep the phase probe marks (`phase_probe.begin/end`) so the tools can
   still split it.
7. **Tests** (`tests/unit/native/test_native_<name>.gd`), each pending without the library (`_built()`):
   - the layout probe against the GDScript constants;
   - each case against GDScript's answer on a fixed scene (the same states on the same ticks, the same hits, the same
     events; the flood is integer arithmetic and must be identical cell for cell);
   - a horde run twice with equal hashes, and a snapshot restored mid-run that continues identically;
   - the existing rule tests of that phase with the kernel on, through the pre-run hook
     ([`TEST_MATRIX.md`](TEST_MATRIX.md) §7).
8. **Run it combined.** Run the new kernel with every other kernel on, not only alone: the kernels were first run
   together by the lead after each had passed alone (LESSONS L25).
9. **Changing an existing kernel's arithmetic** changes results: say so in PROGRESS, re-record the goldens on purpose
   (each named), and re-pin `DETERMINISM_PROBE` only if the collision kernel changed.

## 9. What was not ported, and why

"Design §n" is a section of [`../roadmap/v0.11.1/NATIVE_CORE.md`](../roadmap/v0.11.1/NATIVE_CORE.md), measured on a
busy machine with sub-probes: read those rows for proportions only.

| Not ported | Why | Its cost, measured |
|---|---|---|
| The hero's systems (actions, dash abilities, auto abilities, statuses, regen, the after-tick work) | Content-heavy rules (cards, procs, engines) that change often; one hero, not a crowd | At 120 enemies, `actions` 0.094 ms and about 0.28 ms of hero systems and glue a tick (design §1.3, busy machine: proportions); `dash_abilities` 0.359 ms a tick in the heavy build (`attack_phases`, [`PERF_AFTER.md`](../roadmap/v0.11.1/evidence/PERF_AFTER.md)) |
| What a hit does: `Damage.hit`, procs, pierce, bounce, split, homing (`ProjectileContacts`) | Rules, not geometry; a few contacts a tick | damage and procs about 2 % of the projectile phase (design §1.3, busy machine) |
| Projectile steering (orbit, homing, return, spiral; a Gravity Node's bend) | Per-form rules | runs as a GDScript pre-pass, only when a projectile has a behaviour or a Gravity Node stands |
| Bosses, elites, the signatures, the Cinder Priest | One to a few a room, each with its own state machine | `sim_bench` `reference_boss` 0.496 ms a tick ([`PERF_AFTER.md`](../roadmap/v0.11.1/evidence/PERF_AFTER.md)) |
| `World._actor_grid` (the body grid the GDScript queries read) | Still read by rules code; rebuilt by `NativeMove` from the final positions | `ai.grid` 0.055 ms at 120 (design §1.1, busy machine) |

The tick at 120 enemies with every kernel on: 0.547–0.577 ms against 3.32–3.35 ms in GDScript; a horde frame's sim
span 5.8 → 2.8 ms ([`PERF_NATIVE.md`](../roadmap/v0.11.1/evidence/PERF_NATIVE.md), quiet machine). What remains of
that span is the hero's systems, the per-tick listeners, and more than one tick a frame while a frame is over
16.7 ms.

## 10. Where the build differs from the design

From the code and the native core's rows in
[`../roadmap/v0.11.1/PROGRESS.md`](../roadmap/v0.11.1/PROGRESS.md):

1. **Kiln Beetle and Glacier Turtle are NATIVE**, not HOOKED: 20 native and 9 hooked kinds, not 18 and 11.
2. **Steering and collision are two kernels under two bits:** `ZdWorld.move` (steering, the `ai` bit) and
   `resolve_actors` (collision, the `move` bit), not one `move` call.
3. **`think` takes the mines' owners, not a `may` mask:** the kernel counts a Mine Layer's mines itself. The slow
   factor crosses as a float a row (`slow`) only while an element pair or a spell hold could change it, not as a
   permille int column.
4. **More intents than designed:** `THINK_TICK` and `CHARGE_STEP` exist (`FLOW` and `RELOCATE_STEP`, which handed
   work back to the GDScript flow field, existed until step 54b); `strike` adds
   `CONTACT` and `TOUCH` and carries the hit's origin in `HIT`.
5. **The projectile steering pre-pass runs `ProjectileMoves.steer` on every projectile** when any projectile has a
   behaviour or a Gravity Node stands, not only on the rows with a behaviour.
6. **The cross-compiler fixtures are per kernel, not one `selftest_hash()`:** `native_kernels_hash.txt` and
   `native_horde_hash.txt` (step 54b; "The fixtures" in §4), recorded from the Windows build. Whether the Linux build
   gives the same values is first known from the PR's CI.
7. **The GDScript actor grid stays**; no native `actors_near`.
8. **No decision-rate change**, as the design recommended: the walk plan stays every 8 ticks, staggered by id. The
   flood runs whole on its `PERIOD` tick (one bounded flood about 0.2 ms native against 4–8 ms in GDScript, by the
   path flood's PROGRESS row).
9. **The renderer bridge is presentation-side:** no `crowd_rows` on `ZdWorld`. `ZdCrowd` takes the view's own slot
   columns and avatar rows, never the sim's.
10. **The cost of a column by name was measured** at about 0.1 µs a read and 0.3 µs a write (the design estimated
    0.3–0.5 µs each), and the tick came out at 0.55–0.58 ms at 120 enemies (the design estimated about 0.72).

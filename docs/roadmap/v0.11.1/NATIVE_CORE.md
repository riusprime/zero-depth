> **This is the design as written before the build** (history, not maintained). The as-built contract is
> [`../../architecture/NATIVE_CORE.md`](../../architecture/NATIVE_CORE.md); where the two differ, that page and the code win.

# The native core: design (v0.11.1 step 51)

- **Status:** design, for steps 52 to 55 (PLAN Wave 7; owner L15, L16, L17).
- **Build read:** `v0111-s51` = the spike `v0111-s49` (`3b3587b7`) merged with `claude/v0110` (`f6864b98`):
  `2cd2e414`. Godot `4.7.2`, the spike's `template_debug` library, Windows 11, the owner's PC (i7-10700K).
- **Machine:** **not quiet.** Two other Godot processes were running before and after the runs (`tasklist`).
  Read every number below for proportions, not as evidence of speed. `evidence/PERF_NATIVE.md` (step 54) is the one
  measured on a quiet machine.
- **Who:** an agent (step 51). Estimates are marked **(est.)** with the factor assumed.

## 0. The short version

- GDScript keeps the truth: every hashed column stays in `ActorStore` and `ProjectileStore`. The native side is a set
  of **batched kernels with caches**: one call per phase, columns in, columns and a short list of **intents** out.
  Rules that are content stay in GDScript: damage, procs, cards, bosses, events, randomness. The snapshot and the hash
  don't change shape.
- **One native object per world** (`ZdWorld`, which replaces the spike's `ZdMover`) holds the caches: walls, solids,
  trig tables, the per-kind table, the nav grid. Kernels: `think`, `move`, `strike`, `sweep_shots`, `nav_flood`.
- **52 of 54 actor kinds:** 18 run purely from a per-kind table, 11 from the table plus a GDScript hook on an
  intent, and 23 stay GDScript (14 bosses, 3 elites, 5 Ruins signatures, the Cinder Priest), as well as eggs and
  dummies.
- **Decision rates:** the walk plan already runs at 7.5 Hz, staggered by id (`PLAN_PERIOD` 8). On the native side
  the per-tick state machine for 120 enemies is about 0.02-0.03 ms (est.), so lowering it more saves almost nothing
  and the player could feel it. **I recommend no further rate cuts**: no half-rate separation and no half-rate for
  enemies far away. The one rate change I recommend is to the flood: run it whole in one tick instead of in six
  slices.
- **Estimate:** the tick at 120 enemies goes from 3.08 ms (measured, noisy) to about 0.7-0.8 ms (est.) after the
  flip. What's left is mostly the hero's systems (`actions`, `dash_abilities`, `statuses`, `after`), which aren't
  ported.

## 1. Where `ai` and the other phases go: the measured split

### 1.1 Commands and runs
Two runs, both at `2cd2e414`, both `--native=1` (the spike's collision passes on):
```
godot --headless --path . -s scripts/checks/horde_phases.gd -- --counts=20,60,120 --ticks=1800 --native=1
godot --headless --path . -s scripts/checks/horde_phases.gd -- --counts=120 --ticks=1800 --native=0
```
- **The clean run:** the unchanged tree. Its phase means, in ms per tick:
```
                  20 enemies   60 enemies   120 enemies   120, native off
step                  0.884        1.648        3.076          4.588
nav_flood             0.197        0.238        0.305          0.365
ai                    0.224        0.620        1.187          1.424
  ai.grid             0.013        0.038        0.055          0.072
  ai.plan             0.086        0.253        0.480          0.596
move                  0.137        0.302        0.526          1.548
  move.steer          0.071        0.195        0.378          0.442
  move.native         0.012        0.023        0.038            —
  move.grid           0.013        0.038        0.055          0.127
actions               0.050        0.065        0.094          0.116
resolve               0.043        0.087        0.173          0.213
proj                  0.087        0.146        0.509          0.578
flood_alone (min / median, the whole flood from scratch, GDScript):
                    1.47/2.61    2.01/2.14    4.00/4.44      3.48/4.18
outcome_hash at 120, off: 14f2fbce…abcad (the baseline's, unchanged)
```
- **The split run:** temporary sub-probes, not committed: a timer around every enemy's `think`, `move` and
  `resolve`, bucketed by the state the enemy was in; timers inside `plan` (`_walk_dir`, the grid query, the spread
  sum, the wall check, the flow lookup); `sees_player`, `_start_windup`, `_aim` and `ItemProcs.slow_factor`; and
  `_projectile_hits` split into steer, walls and bodies. Each timed sample costs 0.43 µs of probe (measured in the
  same process). The run inflates everything: the step mean is 10.8 ms against 3.08. Even `nav_flood`, which has no
  per-actor probes, is 2.2× slower, so the machine was busier as well. **Only the proportions of the split run are
  used below.** They're scaled to the clean run's phase totals, and every scaled number is marked (est.).
- The means include the ticks a hit-stop or a choice skips (about one tick in five here: 95 `think` calls a tick
  for 120 alive enemies).

### 1.2 `ai` at 120 enemies (clean 1.187 ms)
| Part | Clean ms | Calls a tick | Hot or cold | Code |
|---|---|---|---|---|
| The actor grid build | 0.055 (measured) | 1 | hot, once a tick | `world.gd` `_run_ai`, `ai.grid` |
| The walk plan | 0.480 (measured) | 11.8 (one enemy in eight) | hot, staggered | `enemy_ai.gd` `plan`, l. 559 |
| … the wall check on the line to the hero (`_blocked`: a grid walk plus sweeps) | 0.16 (est., 34 %) | 11.8 | hot | l. 777 |
| … the neighbour query (`actors_near`) | 0.07 (est., 15 %) | 11.8, 10.8 candidates each | hot | l. 568, `DenseGrid.query_rect` |
| … `_walk_dir` (band, strafe, flank) | 0.06 (est., 13 %) | 11.9 | hot | l. 515 |
| … the spread sum | 0.06 (est., 12 %) | 11.8 | hot | `_spread_over`, l. 600 |
| … the flow lookup (`nav.direction`) when blocked | 0.03 (est., 6 %) | 4.8 (40 % of plans) | warm | `nav_field.gd` l. 855 |
| The per-tick state machine (counters, range and cooldown test, facing) | 0.46 (est.) | 95 | **hot, every enemy every tick** | `think`, l. 266-366 |
| … sight line when an attack could start (`sees_player`) | 0.02 (est.) | 2.1 | cold | l. 1131 |
| … aim while a windup tracks (`_aim`, `lead_angle`) | 0.03 (est.) | 4.4 | warm | l. 1075 |
| … `_start_windup` | 0.006 (est.) | 0.29 | **cold** | l. 1029 |
| Loop glue: role lookup, calls, kind flags | 0.19 (est.) | 95 | hot | `_run_ai`, `think` head |

The state buckets (split run, inclusive of a plan that fell in that tick): MOVE 76 %, WINDUP 12 %, RECOVER 6 %,
ACTIVE 3 %, SPAWN 2 %. The enemies' state shares were MOVE 74 %, WINDUP 11 %, RECOVER 9 %, ACTIVE 4 %, SPAWN 2 %.
**Per enemy and tick:** about 7 µs of state machine and glue (clean, est.). **Per plan:** about 41 µs (clean,
measured: 0.480 ms / 11.8).

At 20 and 60 enemies the shape is the same: `ai.plan` is 38 % and 41 % of `ai` (measured), and the grid is 6 %.
The neighbour candidates per plan grow with the crowd's density: 4.8, 7.1, 10.8 at 20, 60, 120.

**Reading:** two thirds of `ai` is per-enemy-per-tick work that is the same for every table kind (counters,
distance, cooldown, facing) plus dispatch. One third is the plan, which is geometry: a wall sweep, a grid query,
a sum. Both are what the spike showed native code doing about 20× faster. The cold paths (windup start, sight,
aim) are under 5 % together.

### 1.3 The other phases at 120 enemies
- **`move.steer`, clean 0.378:** the MOVE-state enemies' calls 55 % (`move`, l. 467-512), the charge step 2 %, the
  other states 14 %, glue 29 %. Inside those calls, `ItemProcs.slow_factor` is 18 % of the phase: 95 calls a tick.
  It runs before the state tests, so every enemy pays for it, even a recovering one. Hot: every enemy, every tick.
- **`resolve`, clean 0.173:** the enemy loop is 96 %. The extras (`Mines`, `Variants`, `RuinsRocks`,
  `BossSignatures` advance) are 4 %. Of the loop, more than half is visiting the roughly 91 enemies that aren't
  ACTIVE and return at once (`r.move` alone is 26 %). Real hit tests cover about 3.8 ACTIVE enemies a tick. Hot
  dispatch, cold work.
- **`proj`, clean 0.509, 58 live projectiles a tick:** the sweep is 87 %. Within it: the actor candidates and circle
  sweeps 41 %, the wall sweeps 19 %, `ProjectileMoves.steer` 12 % (called for every projectile; it returns at once
  for plain ones but still costs a call), and the segment-box and loop glue 27 %. Damage and procs are 2 %, the removal
  under 1 %. Hot: per projectile, per tick. The hits are cold (a few a tick).
- **`nav_flood`, clean 0.305 mean:** `nav.advance` (one slice of the bucketed flood) 90 %, `_nav_targets` 10 %. The
  whole flood from scratch is 4.0-4.4 ms at 120 targets (`flood_alone`). The world floods every 12 ticks, in 6 slices
  (`NavField.PERIOD`, `SLICES`).
- **What isn't ported, clean:** `actions` 0.094, plus about 0.28 of hero systems and glue (`dash_abilities`,
  `statuses`, `remove_dead`, `after`, input). These stay GDScript.

## 2. The data model

### 2.1 Who owns what
| State | Where it lives | Owner of the truth | Notes |
|---|---|---|---|
| Every `ActorStore` column (ids, kinds, pos, radius, hp, state, state_t, facing, lock_*, cd, fire_cd, windup, pick, plan_*, power, the statuses) | GDScript packed arrays, as today | **GDScript** | Hashed, snapshotted and read by views exactly as today. A native kernel reads them at the start of its call and writes back the ones it changed, as whole new arrays |
| `ProjectileStore` columns | GDScript | **GDScript** | Same contract |
| `NavField.dist` | GDScript `PackedInt32Array` | **GDScript** (snapshotted) | The native flood writes the whole array back on its tick |
| Walls, solids (the boxes) | GDScript `Array[Obb]`, `Solids` | GDScript | Native keeps a **cache**: its wall grid, sent again when `World._wall_rev` changes (the spike's rule) |
| The trig tables | `Kin` (`TrigLut`) | GDScript | Native gets the same 513-entry float32 tables once, at its creation, so both sides use one table |
| The per-kind table | built from the `EnemyTable` resources | GDScript (content, `LOADOUT_CLASSES`) | Native gets it as two flat arrays at `set_enemy_tables` (§4) and again on restore |
| The tuning (`w.tuning.ai_*`) | `SimTuning` | GDScript | Sent with the kind table |
| The nav grid (blocked cells, adjacency, weights) | `NavField` | GDScript (derived from walls) | Native cache, sent on wall change (`build`, `set_extra`) |
| The actor grid (bodies by cell) | native, rebuilt inside each kernel that needs it | derived | Nothing between ticks. GDScript keeps its own `_actor_grid` until the flip (§7.6) |
| Previous-tick positions for the renderer (step 55) | native | derived, presentation-only | Not hashed, not saved |

**The rule: between two calls the native object holds nothing that isn't derived from hashed state.** So
`WorldSnapshot` doesn't change. `ZdWorld` goes into `WORLD_KEPT` as "setup, not state", as `native_mover` already
does. A restore rebuilds the caches: the wall revision mismatch resends the walls, `set_enemy_tables` resends the
kinds, and the nav field resends its grid. The state hash stays the same function over the same columns, in the
same field order. The values change at the flip because the arithmetic is different. Save and resume are exact
because the truth is the float32 and int32 columns, which round-trip bit for bit.

### 2.2 How columns cross
- **In:** the kernel takes the store object and reads each column it needs with `Object::get(name)`. The packed
  array comes back sharing its buffer (copy on write), so the read is a pointer, not a copy. The spike passed
  columns as arguments; at 20-30 columns a call, by name is less error-prone.
- **Out:** for each column it changed, the kernel builds a new packed array (a `memcpy` of the input, then its
  writes) and calls `Object::set(name, out)`. It never writes into the array it was given, because copy on write
  would make that a silent copy. It must also carry the script-owned rows (§4.3) through unchanged.
- **Cost (est.):** the spike measured about 1 µs for a call that hands over three columns and reads two back.
  I didn't measure a `get`/`set` by name. The estimate is 0.3-0.5 µs each, so 20-30 µs a tick for the four kernels.
  Step 52 measures it and, if it's larger, moves to positional arguments.
- **Rule for GDScript (a review item for every step):** no GDScript local may alias a column across a native call
  (`var px := a.pos_x` then a kernel, then `px[i]`). Such a local would read the old array. Today's code does this
  only inside single functions; the steps check each call site they touch.
- **Rare reads from rules code:** rules code keeps reading `a.pos_x[i]` from the GDScript columns, as today. Native
  accessors are only for derived queries that GDScript would otherwise have to rebuild: `actors_near(rect)` on the
  native grid (after the flip), `sweep_one(projectile)` (§3.5). Each one is a single call of about 0.3 µs.

## 3. The entry points (one batched call a phase)

All are methods of `ZdWorld` (a `RefCounted`, one per `World`, made by the app layer's factory as the spike's mover
is). The GDScript bridges live in `src/sim/world/native_*.gd`. Every list handed back is ascending by actor or
projectile index, then by intent code. GDScript applies it in that order.

### 3.1 The tick as it will run
```
phase            native                                   GDScript
0-2 input        —                                        as today (freeze, choices, input, interact, Solids.step)
3 nav            nav_flood(goal, steps, targets) on       targets list (native at the flip); dist written back
                 PERIOD ticks, whole, one call
3 ai             think(actors, hero, tick)                pre: masks (held, may_attack) only when needed
                   -> columns + intents                   apply intents ascending (rng, windup data, hooks)
                                                          script rows: BossAi / EliteAi / RuinsRocks / priest / eggs / dummies .think
4 actions        —                                        as today (hero)
5 move           —                                        hero step; script rows .move; PlayerSkill.push
                 move(actors, hero, speed col)            (one call: table-kind steering, then the collision passes)
                   -> pos, lock_len, facing, intents      apply intents (charge-step trails); RuinsRocks.block_hero
6 resolve        strike(actors, hero)                     apply hits / bolts / pattern waves / hooks ascending;
                   -> hit list, fire list, hooks          script rows .resolve; Mines/Variants/... advance
6 proj           sweep_shots(projectiles, actors, skip)   pre: steer only projectiles with `moves`, Gravity bend
                   -> contacts, advanced pos/life, ends   apply contacts ascending (Damage.hit, procs, pierce, bounce)
7-11             —                                        as today
```

### 3.2 `think(actors: ActorStore, hero: PackedFloat32Array, tick: int, held: PackedByteArray, may: PackedByteArray) -> int`
- **Inputs:** the columns `ids kinds dead state state_t cd fire_cd facing pos_x pos_y radius lock_x lock_y lock_a
  lock_len windup pick plan_x plan_y plan_block frozen_t hp max_hp`. `hero` holds x, y, vel x, vel y, radius,
  dead, dashing, and the dash landing x and y (barriers are walls, so the wall revision covers them). `held` has one byte a row (a spell stun) and is
  empty when `spell_hold_id` is empty. `may` has one byte a row for the kinds whose attack needs a script test (the
  Mine Layer's mine count) and is empty when no such kind is alive.
- **Inside, for each table row** (mode NATIVE or HOOKED, §4), in index order:
  1. The plan, on its tick (`(tick - id) mod PLAN_PERIOD == 0`): the walk direction, the neighbour push over the
     native grid, the wall check, the flow lookup.
  2. The frozen or held skip.
  3. `state_t += 1` and the `cd` countdown.
  4. The state machine: SPAWN → MOVE; MOVE: range, cooldown, sight, the facing rule, then the attack start; WINDUP:
     tracking aim, then → ACTIVE; ACTIVE: the done rule; RECOVER: → MOVE with cooldown.
- **It sets everything that needs no randomness.** At an attack start it enters WINDUP itself: `lock_x/y` = pos,
  `lock_a` = aim, the charge's `lock_len` = `clear_run`, the Splitter's disc centre, the Shield Bearer's facing. It
  sets `windup` to the table's minimum, then emits `WINDUP_START`.
- **It hands back intents** (`intents_i: PackedInt32Array`, stride 4: code, row, a, b; `intents_f:
  PackedFloat32Array`, stride 4):
  - `WINDUP_START(row, aim)`: GDScript draws the windup length from `rng_enemy` when `windup_max > windup`. It
    also runs the kind's extras: the Arc Caster's spell pick (and, for the rune, its windup and lock at the hero),
    the Star Warper's `mark_spot`. This keeps every `rng_enemy` draw in GDScript, in ascending actor order.
  - `RELOCATE(row)`: a Sniper's RECOVER → MOVE. GDScript runs `_plan_relocation` (it draws).
  - `WINDUP_END(row)`: only for kinds with the hook bit (the Star Warper's `cancel`). GDScript may put the row back.
  - `MOVE_TICK(row)`: only for hooked kinds that act while walking (the Mender's `_mend`, the Rubble Warden's crust
    check, `CanyonShore.on_think` for the shore kinds).
- **Returns** the number of intents. GDScript then runs `think` for the script rows (§4.3) as today.

### 3.3 `move(actors, hero, speed_permille: PackedInt32Array, through: PackedInt32Array, heavy: PackedInt32Array, ghost0: bool, iters: int) -> int`
- **Inside:** the table rows' steering: the planned walk with the melee contact stop, the charge with its turn
  rate, the Sniper's relocation walk with the wall steer, and the Gravity Node's hold. Then the spike's collision
  passes over every body, script rows included.
- **`speed_permille`** is `ItemProcs.slow_factor` as a column, built by GDScript only when a slow, a freeze, an
  element pair or a spell hold could apply (`slow_t` any, `pair_mask`, `spell_hold_id`). Otherwise it's empty and
  read as 1000. That removes the 18 % of `move.steer` the factor costs today.
- **Out:** `pos_x pos_y lock_a lock_len facing`, plus intents `CHARGE_STEP(row)` for kinds with a trail
  (`Variants.on_charge_step`).
- The collision passes stay last, so the hero and the script rows have moved first.

### 3.4 `strike(actors, hero) -> int`
- **Inside:** for each table row that is ACTIVE, not frozen, and the hero alive, the table's hit shape on its tick:
  - contact: Charger, Swarmer, Hatchling, critters, using `fire_cd` as "hit once";
  - the locked disc: the Warden's slam, the Splitter's swipe;
  - the bash lane;
  - the snipe lane, or lanes for the Split Sniper (hook);
  - the rune disc;
  - the Needle's burst schedule;
  - a pattern's wave schedule (`BulletPatterns.wave_at` is data: the table carries each pattern's wave ticks).
- It runs the sight test from the hit's origin (`_hit_player`'s rule) natively.
- **Out:**
  - `HIT(row, amount, tags, from_x, from_y)`: GDScript calls `Damage.hit` with `powered()`. It stops applying once
    the hero is dead, as the per-enemy check does today.
  - `BOLT(row, angle, k)`: GDScript runs `_fire` and `queue_projectile` (and the Dim Needle's look, and
    `BossRicochet.arm_turret`).
  - `WAVE(row, k)`: GDScript runs `BulletPatterns.fire`, which keeps its caps and fairness.
  - `ACTIVE_HOOK(row)`: `Mines.drop`, `CanyonShore.throw_blob`, the Star Warper's blink and strike.
  - It writes `fire_cd` for contact and burst counting.
- The critters' touch (`CritterAi.touch_all`) is a table row of this kernel: contact, `cd` = `contact_cd_ticks`.

### 3.5 `sweep_shots(projectiles: ProjectileStore, actors: ActorStore, skip: PackedByteArray, walls_only: PackedByteArray) -> int`
- **Inside:** each projectile's segment for this tick against the native wall grid and the actor grid (built here
  from the phase-start positions), with today's rules: the team filter, dead bodies skipped, the earliest `t`, and a
  tie going to the wall and then to the lower actor index.
- `skip` (the Glaive Mine hold) and `walls_only` (Void and Wave shots) are built by GDScript only when such
  projectiles exist.
- **Out:**
  - Contacts: projectile, actor or −1, wall or −1, `t`. These are only the projectiles that hit something.
  - For the rest, the kernel writes the advanced `pos_x pos_y` and the decremented `life`, and lists those whose
    life ran out (`END(projectile, x, y)`).
- **GDScript then runs the contact list in ascending projectile order,** with today's body of the loop (moved to
  `src/sim/world/projectile_contacts.gd`): `Bomb.touches`, `Damage.hit`, procs, the card hooks, pierce, bounce, the
  end hooks, `BossSignatures.on_shot_end`.
- **Stale contacts:** if the contact's actor died earlier in this same phase, GDScript calls
  `sweep_one(projectile, skip_dead)` (one native call) for that projectile's next contact. That reproduces today's
  meaning: a dead body isn't hit.
- **Projectiles with `moves`** (orbit, homing, return, spiral) keep their GDScript steering. It runs as a pre-pass
  over those rows only, before the sweep, as the Gravity Node's bend does. Plain shots no longer pay the
  `ProjectileMoves.steer` call.

### 3.6 `nav_flood(goal: Vector2, max_steps: int, targets: PackedInt32Array) -> PackedInt32Array`
- **Inside:** today's bucketed octile Dijkstra (ORTHO 5, DIAG 7, `RING` 8, the seeds for a hero in a blocked
  cell, the target margin), on the nav grid cache. It writes `dist`, `last_work` and the flooded key.
- **Whole, in one call, on the `PERIOD` tick:** 4.0-4.4 ms in GDScript is about 0.1-0.2 ms native (est., at
  20-40×). That's one tick in twelve, inside the 6.9 ms budget, so the slices (`begin_build`, `advance`,
  `_back`, `build_state`) go at the flip.
- `direction(p)` stays a native method, because `think` uses it. The GDScript copy stays for the script rows and
  the views until the flip.

### 3.7 Setup methods
- `set_trig(cos, sin)`.
- `set_walls(obbs)` and `set_solids(obbs)` (the spike's).
- `set_kinds(ints, floats, tuning)` (§4.2).
- `set_nav_grid(origin, size, blocked, adj_start, adj, adj_w)`.
- `set_nav_dist(dist)`, for step 52, before the flood is native.
- `rows_for_script() -> PackedInt32Array`: the rows whose kind is in mode SCRIPT, so GDScript doesn't scan all rows
  to find them.

## 4. The per-kind behaviours

### 4.1 Which kinds run from data and which need script
`ActorStore.Kind` has 54 kinds: the player, the dummy and 52 enemies.

| Mode | Kinds | Count | What the native loop needs |
|---|---|---|---|
| **NATIVE** (pure table) | Charger, Hatchling, Swarmer, Warden, Needle, Lens Drone (runs the Needle), Splitter, Splitling, Shield Bearer, Sniper, Arc Caster, Bomb Drone, Gravity Node, the 5 critters | 18 | The table. The randomness and the projectiles go through the uniform intents (`WINDUP_START`, `RELOCATE`, `BOLT`, `WAVE`) |
| **HOOKED** (table plus a GDScript hook on an intent) | Mender (`MOVE_TICK`: `_mend`), Mine Layer (`may` mask, `ACTIVE_HOOK`: `Mines.drop`), Rubble Warden (`MOVE_TICK`: crust), Dim Needle (`BOLT`: look), Ember and Frost Charger (`CHARGE_STEP`: trail), Split Sniper (`ACTIVE_HOOK`: split lanes), Kiln Beetle and Glacier Turtle (Warden base; their shells and bursts are damage-side and death-side, already GDScript), Frost Spitter (aim without lead; `ACTIVE_HOOK`: blob), Star Warper (`WINDUP_START`: star; `WINDUP_END`: cancel; `ACTIVE_HOOK`: blink) | 11 | The table plus a hook bit set |
| **SCRIPT** (native skips the row; GDScript runs it as today) | 14 bosses (Gatekeeper, Brood Mother, Siege Engine, Warlord, Hive Lens, Foundry, Colossus, Prism, Nemesis, Tidecaller, the two Twin Wardens, Clockwork Judge, Lantern Shade); 3 elites (Breaker, Rift Hunter, Conduit); 5 Ruins signatures (Wire Weaver, Wire Post, Scrap Hound, Rock Lurker, Stone Thrower); the Cinder Priest (its walk follows its vent; `on_think` every tick) | 23 | Nothing. The native loop leaves their columns alone. Their bodies still go through the native collision passes. Also SCRIPT: any row with `state >= BossSignatures.EGG`, and the dummy |

The horde, the critters and the biome variants are all native or hooked. The script kinds come one to a few per room.
**29 of 52 enemy kinds (56 %) are native or hooked, and they make up nearly every body in a crowd.** The elites'
walk is the generic plan, so they can switch to the native plan at the flip (`EliteAi.think` calls `EnemyAi.plan`).

### 4.2 The table
It's built in GDScript (`src/sim/ai/native_kind_table.gd`) from `EnemyTable` and the kind flags `EnemyAi` already
computes (`_flags`, `_behaviour`), and sent as two flat arrays indexed by kind (stride `KI` ints, `KF` floats).

**Ints:**
- `mode`: NATIVE, HOOKED or SCRIPT;
- `behaviour`: the base kind, as `behaviour_of`;
- `flags`: CHARGES, KEEPS_AWAY, TURNS_SLOWLY, CRITTER, FLEES_THEN_STRAFES (Needle), STATIONARY (Gravity Node),
  RELOCATES (Sniper), TRACKS (`tracking`), AIM_NO_LEAD (Bomb Drone, Frost Spitter), FACES_ON_PLAN;
- `hooks`: MOVE_TICK, WINDUP_START_EXTRA, WINDUP_END, CHARGE_STEP, BOLT, ACTIVE;
- `cooldown_ticks`, `windup_ticks`, `active_ticks`, `recover_ticks`;
- `turn_rate`, `charge_turn`, `front_half_arc`, `lead_max_ticks`;
- `burst_count`, `burst_gap_ticks`, `burst_spread`;
- `shape`: NONE, CONTACT, LOCKED_DISC, BASH_LANE, SNIPE_LANE, RUNE_DISC, BURST, PATTERN, HOOK;
- `damage`, `tags`, `contact_cd_ticks`;
- the pattern's wave ticks as an offset into a shared int array;
- `max_mines` (read through `may`), `commit_ticks`.

**Floats:**
- `radius_m`, `speed`, `attack_range_m`, `flee_distance_m`, `keep_distance_m`, `keep_min_m`;
- `charge_speed`, `charge_distance_m`;
- `reach_m`, `slam_radius_m`, `lane_half_m`, `rune_radius_m`;
- `bolt_speed`, `spread_speed`, the pattern speed;
- the snipe lane length.

**The tuning,** sent beside it: `spawn_in_ticks`, `ai_commit_ticks`, `ai_snipe_commit_ticks`, `ai_strafe_permille`,
`ai_flank_min_m`, `ai_flank_range_m`, `ai_flank_permille`, `ai_spread_radius_m`, `ai_spread_weight`,
`ai_relocate_speed_permille`, `ai_relocate_max_ticks`, and `PLAN_PERIOD`.

A test builds the table for every kind and checks it against the slow tests (`behaviour_of`, `flags_of`,
`role_of`), as `test_enemy_ai` already does for `_flags`.

### 4.3 Script rows
GDScript gets `rows_for_script()` and runs `BossAi.think/move/resolve`, `EliteAi`, `RuinsRocks`, the Cinder
Priest, eggs and dummies on those rows only, after the native call of each phase.

This is an order change: today the script rows think interleaved with the table rows by index. The critters already
made the same change in O9c. Nothing a script row reads in `think` is written by a table row's `think`. The
exceptions are the Mender's heal (an `hp` write, applied as an intent before the script rows) and the Warper's
`lock`; neither is read by a boss.

## 5. Enemies decide less often

### 5.1 What already runs at a lower rate
- The walk plan: every 8 ticks (7.5 Hz), on the phase `id mod 8`, so a crowd's plans spread evenly. Elites plan
  every 4 ticks (owner W3-S10).
- The flow field: every 12 ticks.
- The Mender's scan: every 15 ticks.
- So "enemy decisions at 10-15 Hz" is already true, and lower, for the walk, which is the expensive decision:
  41 µs a plan in GDScript.

### 5.2 What stays every tick, and why
| Every tick | Why |
|---|---|
| The walk and charge integration (`move`) | A body moving at 7.5 Hz steps visibly. The view interpolates between ticks, not between plans |
| Facing for the slow turners (Warden, Shield Bearer) | Their facing is their armour (`Damage.target_mult`), read on every hit |
| `state_t`, `cd`, the windup and recover timers | The telegraphs are drawn from them (`EnemyAi.telegraph`, ticks-to-hit), and the player reads them |
| The tracking aim during a windup until commit | The telegraph line follows the hero. At 15 Hz it would visibly stutter |
| The attack-start check (range, cooldown, sight) | Native cost ≈ 0 (est.). At 15 Hz an attack would start up to 66 ms late: small, but a change to the enemies' pace that no rule asked for |
| The collision passes | Bodies would overlap and pop (below) |

### 5.3 The three proposals
- **Enemy decisions at 10-15 Hz, staggered by `id mod N`:** already done for the plan (N = 8). For the per-tick
  state machine I **don't recommend** a lower rate. In GDScript it would save at most part of 0.46 ms (est.).
  Natively the whole state machine for 120 enemies is about 0.02-0.03 ms (est., 20×), so a lower rate saves under
  0.02 ms. The cost: attacks start late, and windups can end up to a quarter of a second off their drawn length
  unless the timers stay per tick, which is most of the state machine anyway.
- **Enemy-enemy separation on alternate ticks, half the horde each tick:** **not recommended.** The native pair
  pass is 0.038 ms at 120 (measured, `move.native`), so halving it saves about 0.02 ms. Half-rate separation lets a
  pack overlap for a tick and then pop apart, which the player sees in a dense swarm.
- **Far off-screen enemies at half rate:** **not recommended.**
  - The sim doesn't know the camera (EI-02, EI-07), so "off screen" would have to be a distance from the hero.
  - Hordes spawn in the hero's room or a neighbour, so few enemies are far away.
  - Enemies past the flood's bound (80 m of path) already take the cheap straight walk.
  - A half-rate enemy that walks into view moves differently for a moment.
- **What I do recommend:** the flood whole in one tick (§3.6), because natively the slicing costs more in
  complexity than it saves. I also recommend keeping `PLAN_PERIOD` at 8 through the flip, so the side-by-side
  comparison measures the port alone. After the flip a native plan costs about 2 µs (est.), and 4 ticks (15 Hz,
  quicker reactions to a dodge) would cost about 0.03 ms more. That is an owner question (§9), not a speed one.

**Expected saving from rates: none beyond what the port gives.** The rates matter only if the port stalls: then the
GDScript fallback could take the attack check down to the plan tick (about −0.1 ms, est.).

## 6. Determinism rules for the C++

1. **Floats:**
   - `float` (IEEE single) for every value that lands in a column. The columns are float32, and the hash reads
     float32. A local may be `float` or `double`, but each function picks one and keeps it. No `long double`.
   - Only `+ - * /`, `sqrt` (correctly rounded on SSE2 and on every IEEE platform), `fabs`, `min`, `max`, `floor`
     on finite values.
   - No `sin`, `cos`, `atan2`, `pow`, `exp` or `log`: directions and angles come from the shared tables
     (`Kin.dir`, `angle_of` with its binary search over the same table, `turn_toward`), ported once into `zd_geom`.
2. **Compiler flags,** set in the SConstruct by step 50 and checked by a test that reads the build's flags string:
   - MSVC: `/fp:precise`, never `/fp:fast` or `/fp:contract`, and no `/arch:AVX2` (it brings FMA).
   - gcc and clang: `-ffp-contract=off -fno-fast-math -fno-associative-math -fexcess-precision=standard`, x86-64
     baseline (SSE2, no x87, no `-march=native`). The same flags for `template_debug` and `template_release`.
3. **Order:**
   - Every loop runs over rows in ascending index.
   - The grids are counting sorts, which are stable.
   - Candidate lists come back ascending, and sums over neighbours add in that order.
   - A tie on `t` keeps the earlier find: the wall, then the lower index.
   - No `std::unordered_*` iteration, no pointer-ordered containers, and `std::stable_sort` with a full key
     wherever a sort is needed.
   - No threads, until a later step proves a fixed partition merged in index order.
4. **Integers:**
   - Angle math in `int32` with `& 4095`.
   - `posmod` written out: C++ `%` truncates toward zero, as GDScript's does.
   - Float to int only on values checked to be in range (`int(f)` truncates on both).
   - No signed overflow.
5. **Randomness:**
   - The native code draws nothing. Every draw stays in GDScript, on `rng_enemy` and the other named streams, at
     the intents, in ascending row order (§3.2). The streams' states are hashed as today.
   - If a later kernel needs a draw inside a loop, the rule is: port `DeterministicRng`'s xorshift32 into
     `zd_rng.h`, pass the stream's state in, and write it back. Never use a C library generator.
6. **No clocks, no OS, no engine queries** in the kernels. The spike's `bench_*` methods are probe-only and are
   never called from `src/sim`.

**Tests:**
- **Self-determinism:** a horde scene (the `horde_phases` world, 600 ticks, 60 enemies) run twice in one process and
  once in a second process gives the same hash chain.
- **Save and resume:** snapshot at tick 300, apply to a fresh base world, step to 900. The hash equals the
  continuous run's.
- **Cross-compiler identity:**
  - Committed fixtures: `tests/golden/fixtures/native_horde_hash.txt` for the scene, and
    `native_kernels_hash.txt`, the hash of each kernel's output over 10,000 seeded inputs (a probe-only
    `selftest_hash()` method).
  - Linux CI (gcc) and the owner's Windows build (MSVC) both run the test against the same files. A mismatch fails
    the test and names the first kernel that differs.
  - Both build types (`template_debug` and `template_release`) are checked, since the optimisation level must not
    change a bit.
- **Rules:** the existing enemy AI, collision and projectile rule tests run with the switch on, as the spike's
  pre-run hook did (124 of 124 for the move passes).

## 7. The order of work

Each step merges behind the switch, off by default, so the game doesn't change. Each reports `horde_phases --native=0`
against `--native=1` at 20, 60 and 120, plus its own tests.
- **The switch** becomes one flag with kernel names for testing: `--native=move,ai,strike,shots,nav`, or `all`.
- **Every step owns its new files.** The shared ones (`world.gd`, `register_types.cpp`, `zd_world.h`) change only
  in the few lines named.

### 7.1 Step 52a: the shared core (one agent, first, small)
- **What:**
  - `ZdMover` becomes `ZdWorld`.
  - Shared geometry and trig move out of `zd_mover.cpp`.
  - The column I/O helper.
  - The generalised switch.
  - The kind-table builder: GDScript side only, with its test.
- **C++:** `native/src/zd_world.{h,cpp}` (from `zd_mover.*`), `zd_geom.{h,cpp}` (`Box`, the sweeps, the wall grid,
  the trig tables, `dir`, `angle_of`, `turn_toward`), `zd_columns.{h,cpp}`, `register_types.cpp`.
- **GDScript:** `src/sim/world/native_move.gd` (renamed calls), `src/app/native_switch.gd`,
  `src/sim/ai/native_kind_table.gd`, and `world.gd` (the field and the factory: about 5 lines).
- **Tests:** `tests/unit/native/test_native_geom.gd`: `dir` and `angle_of` against `Kin` for all 4,096 angles and
  10,000 seeded vectors, within one unit; `turn_toward` exact. `test_native_kind_table.gd`.
- **Done when:** the spike's numbers are unchanged, and the move tests pass with it on.

### 7.2 Step 52b: enemy AI, `think` and `move` (one agent)
- **C++:** `native/src/zd_ai.{h,cpp}` (the plan, the state machine, the steering) and `zd_kinds.{h,cpp}` (the table
  reader). It adds `think` and `move` to `zd_world.h` (two declarations).
- **GDScript:**
  - `src/sim/world/native_ai.gd`: the bridge, the masks, and the intent handlers. The handlers call the existing
    `EnemyAi`, `StarfallKinds`, `Variants` and `CanyonShore` functions.
  - `world.gd`: `_run_ai` and `_move_and_collide`, a branch each (about 20 lines).
  - `enemy_ai.gd` only to make 3-4 private helpers callable (`_plan_relocation`, `_mend`). No new code, because of
    its line cap.
- **Tests:** `tests/unit/native/test_native_ai.gd`: each NATIVE kind's state cycle, and each intent applied. The
  existing `tests/unit/sim/test_enemy_ai*.gd` and the critter tests run with `ai` on through the pre-run hook.
- **Expected (est.):** `ai` 1.19 → about 0.15 ms, `move.steer` 0.38 → about 0.03 ms.

### 7.3 Step 52c: enemy strike (one agent, after 52b: it reads 52b's table)
- **C++:** `native/src/zd_strike.{h,cpp}`, plus one declaration in `zd_world.h`.
- **GDScript:** `native_ai.gd` (the hit, bolt, wave and hook handlers), and `world.gd`'s resolve block (about 10
  lines).
- **Tests:** `test_native_strike.gd` covers each shape against the GDScript one on fixed scenes (same hit or no
  hit, not the same bits). The resolve rule tests run with it on.
- **Expected (est.):** `resolve` 0.17 → about 0.04 ms.

### 7.4 Step 53a: projectile sweep (one agent, parallel with 52b and 52c)
- **C++:** `native/src/zd_shots.{h,cpp}`, plus one declaration.
- **GDScript:**
  - `src/sim/world/native_shots.gd`.
  - `src/sim/world/projectile_contacts.gd`: today's per-projectile hit body, moved out of `world.gd` unchanged, so
    both paths call it.
  - `world.gd` `_projectile_hits`, which becomes the steer pre-pass, the sweep, and the contact loop.
- **Tests:** `test_native_shots.gd` (ties, a dead body mid-phase, pierce, bounce, Void through bodies). The
  projectile and card tests run with `shots` on.
- **Expected (est.):** `proj` 0.51 → about 0.06 ms.

### 7.5 Step 53b: the nav flood (one agent, parallel with the others)
- **C++:** `native/src/zd_nav.{h,cpp}` (the grid cache, the flood and `direction`). In 52a, `zd_world.h` declares the
  nav grid slot that 52b reads and 53b fills.
- **GDScript:** `src/sim/world/native_nav.gd`, the `nav_field.gd` hooks (`build`, `set_extra`, `flood`), and
  `world.gd` `_begin_nav_flood` (about 5 lines).
- **Tests:** `test_native_nav.gd`. The native flood's `dist` is checked against `flood_reference` on fixed floors:
  the integer octile distances must be **identical**, because the flood is all integers, so it can be exact. The
  flow-field and nav rule tests run with `nav` on.
- **Expected (est.):** `nav_flood` 0.31 mean → about 0.03 ms, with one tick in 12 at about +0.2 ms.

**In parallel:** after 52a, three agents: 52b, 53a and 53b. Their C++ files are disjoint. Each adds one or two
declarations to `zd_world.h` and edits a different function in `world.gd`, so the conflicts are small, textual,
and the lead resolves them. 52c follows 52b. On the owner's PC they can test at the same time, each with its own
`APPDATA`.

### 7.6 Step 54: the flip (the lead)
- **Deletes:**
  - The switch, `NativeSwitch`'s factory path, and the "no library" fallback. After the flip the game needs the
    library on every export platform.
  - `World._resolve_bodies` and `move.pairs`.
  - The table kinds' paths in `EnemyAi.think`, `move` and `resolve`: the shared state machine, `_walk_dir`, `plan`
    (the elites switch to native), `_spread_over`, `spread_push`. It keeps `telegraph` and the lane and disc
    functions the views draw (EI-07). It also keeps the shape functions, since GDScript still needs them for the
    script rows and the views. `enemy_ai.gd` should drop well under 1,000 lines, and its exemption row goes.
  - `CritterAi`'s three loops.
  - The `_projectile_hits` sweep loop.
  - `NavField`'s GDScript flood and slicing: `_run`, `_begin`, `begin_build`, `advance`, `build_state`,
    `restore_build`, `_back`. It keeps `flood_reference` for the tests. In `WorldSnapshot`, the nav `"build"`
    entry goes.
  - `World._actor_grid`'s two builds: the script queries go to the native `actors_near`. DenseGrid's circle mode
    goes if nothing else uses it.
  - Step 36's dead state.
- **Re-records, on purpose, named in PROGRESS:**
  - `tests/golden/fixtures/replay_ground_plane.json` (its world has enemies);
  - `export_smoke_hash.txt`;
  - `modifier_equivalence.json` (only if its worlds have enemies; the generator says);
  - every pinned `outcome_hash` or event-log fixture the seams list fails on;
  - the new native fixtures from §6.
- **The side-by-side:** the last GDScript build against the native one, over 1,000 seeds, with `SCORECARD` metrics
  (time to kill, damage taken per room, deaths by cause, room clear times). A difference beyond the bands goes to
  the owner, not to a retune.
- **Evidence:** `evidence/PERF_NATIVE.md` on a quiet machine. **OWNER ONLY:** do fights feel the same?

## 8. The renderer bridge (step 55): the interface only
The views read the sim's columns through `WorldReader`'s column getters (`actor_pos_x_column` and the rest, used by
`CritterCrowd`), and `VatCrowd` writes one instance per enemy from the avatars' interpolated transforms. Since the
truth stays in GDScript columns, the views keep working unchanged after the flip. What a batch path needs from the
native side:
- **`ZdWorld.crowd_rows(kind_mask: PackedInt32Array) -> PackedFloat32Array`:** one row per live, visible actor of
  those kinds, stride 12: id, kind, x, y, previous-tick x, y, facing (as the table's cos and sin), state, state_t,
  windup, and a flags word (spawning, egg, vanished, hidden). The previous-tick positions are a presentation cache
  that `move` copies at its start, never hashed. That's one call a frame, read-only (EI-07).
- **`ZdCrowdWriter` (a separate class, presentation-side, in `native/src/view/`):**
  `write(rows, alpha, multimesh_rid, look_table)`. It interpolates, takes the pose drive (windup raise, strike, gait
  phase) from state, state_t, windup and speed, and fills the MultiMesh buffer through `RenderingServer` in one
  upload. It reads `crowd_rows` and never the sim's columns. The pose formulas now in `HordeAvatar` would have to be
  pure functions of those fields plus frame time. Step 55 decides that.
- **Out of scope here:** hit flashes and tints. The view keeps them and passes them as a per-id colour array.

## 9. Risks and open questions for the owner
1. **Hits inside a tick are batched.** Enemy hits apply after every enemy decides. Projectiles sweep from the
   phase-start positions, so a body pushed by an earlier hit in the same tick is swept where it stood. This is
   deterministic, and it's the kind of change L16 allows. *Recommendation:* accept it; the side-by-side comparison
   shows whether it matters.
2. **After the flip the game needs the library.** Every export platform needs a build: Windows (MSVC) and Linux (gcc)
   are planned in step 50. macOS or web would need their own builds and their own cross-compiler check.
   *Question:* which platforms must ship? *Recommendation:* Windows and Linux only for now.
3. **The plan rate after the flip.** A native plan is cheap, so planning every 4 ticks (15 Hz) again would make
   enemies react sooner to a dodge. *Recommendation:* keep 8 through the flip, then decide in a playtest.
4. **The thread trial (step 48)** gained 4-15 % on a 3-4 ms tick. With a tick under 1 ms (est.) it gains little and
   costs a frame of delay. *Recommendation:* drop it after `PERF_NATIVE`.
5. **The frame.** At 120 swarmers the frame is about 23 ms and `sim_step` about 4.9 ms of it (`PERF_AFTER`). The
   port might take about 3.5 ms off a frame (est.). The rest is view and GPU work, so 144 fps still needs the
   renderer bridge and view work. *Recommendation:* decide step 55 from `PERF_NATIVE`, as the PLAN says.
6. **The cross-compiler proof needs two machines:** CI for gcc and the owner's PC for MSVC. The first proof is the
   step 52a test run on both. Until then, "identical across compilers" is a design rule, not a result.

**What I couldn't determine:**
- The real native factor for the plan's branchy code. I assumed 20×, the spike's in-game factor on similar
  geometry; it could be 10×.
- The cost of `Object::get`/`set` by name per column (not measured).
- The bosses' and signatures' tick costs: not in this scene. `sim_bench`'s `reference_boss` tick is 0.50 ms in
  `PERF_AFTER`.
- The split's absolute numbers: the machine was shared and the sub-probes inflate the run. Only the proportions
  stand.

## 10. Estimate: the tick at 120 enemies, phase by phase (ms)
The "today" column is measured, from the clean run in §1.1, on a noisy machine. Every other column is an
**estimate**. Each step's ported work is assumed **20× faster**, the spike's measured in-game factor on the move
passes (35-70× isolated), less the boundary cost: about 20-30 µs a tick for columns crossing by name, plus the
GDScript handling of intents and contacts, sized from the measured cold-path call counts (§1).

| Phase | Today (measured) | After 52a | After 52b (ai, move) | After 52c (strike) | After 53a (shots) | After 53b (nav) | After 54 (flip) |
|---|---|---|---|---|---|---|---|
| nav_flood | 0.305 | 0.305 | 0.305 | 0.305 | 0.305 | 0.03 | 0.03 |
| ai | 1.187 | 1.19 | 0.15 | 0.15 | 0.15 | 0.15 | 0.10 (grid gone) |
| actions | 0.094 | 0.09 | 0.09 | 0.09 | 0.09 | 0.09 | 0.09 |
| move | 0.526 | 0.53 | 0.18 | 0.18 | 0.18 | 0.18 | 0.12 (grid gone) |
| resolve | 0.173 | 0.17 | 0.17 | 0.04 | 0.04 | 0.04 | 0.04 |
| proj | 0.509 | 0.51 | 0.51 | 0.51 | 0.06 | 0.06 | 0.06 |
| the rest (dash_abilities, statuses, remove_dead, after, input) | 0.282 | 0.28 | 0.28 | 0.28 | 0.28 | 0.28 | 0.28 |
| **step** | **3.076** | **3.08** | **≈1.7** | **≈1.6** | **≈1.1** | **≈0.83** | **≈0.72** |

Why each number:
- **ai after 52b:** the grid stays (0.055); plan plus state machine (0.94 ms of GDScript) at 20× is 0.05; columns
  in and out 0.02; intents (about 5 a tick at about 5 µs) 0.03.
- **move:** steering 0.38 at 20× plus the slow column is 0.03, plus the native passes (0.04), the grid (0.055) and
  the hero (0.05).
- **resolve:** the native scan, plus about 4 actives' hits applied in GDScript, plus the extras (0.02).
- **proj:** the sweep 0.44 at 20× is 0.02; columns 0.01; contacts and removal 0.03.
- **nav:** 4.0-4.4 ms at 20× is about 0.2 ms once in 12 ticks, plus the target list.
- **The flip:** the two actor-grid builds go once the script queries use the native grid.
- At 60 and 20 enemies the same factors give about 0.55 and 0.4 ms (est.). There, the hero's systems and the rest
  are already most of the tick.

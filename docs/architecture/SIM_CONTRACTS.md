# Sim contracts

The rules every file under `src/sim/` follows. The layering and folders are in
[`ARCHITECTURE.md`](ARCHITECTURE.md). The invariants these rules serve are EI-02..EI-07 and EI-11 in
[`LOCKED_DECISIONS.md`](LOCKED_DECISIONS.md).

Deathventory's domain was a pure reducer that cloned its state for every command. That suited a turn-based game,
but it can't run a real-time game at 60 Hz. Here **one `World` is mutated in place, one tick at a time**.
Determinism is enforced at the boundary instead:

> The same (sim version, content hash, seed, loadout, `InputFrame` log) always produces the same state hash at
> every checkpoint.

Numbers marked **starting value** are tuning defaults, not measurements. Numbers from the gap analysis are cited
as `GA §n` or `GA: <topic>` ([`../design/ROGUELIKE_GAP_ANALYSIS_v0.1.md`](../design/ROGUELIKE_GAP_ANALYSIS_v0.1.md)
holds the citation map).

---

## 1. Units

| Quantity | Unit in the sim | Type |
|---|---|---|
| Time | ticks (1 tick = 1/60 s) | `int` |
| Position, radius, velocity | metres, metres per tick | `float` (stored as float32, see §6) |
| Aim angle | 1/4096 of a turn (0 = +X, counter-clockwise) | `int` in `[0, 4096)` |
| Aim distance | centimetres | `int` |
| Move input | −127..127 per axis | `Vector2i` |
| HP, damage, barrier, heal, stacks | points | `int` |
| Chance | per mille (‰) | `int` in `[0, 1000]` |
| Proc coefficient | percent | `int` in `[0, 100]` |
| Multipliers | per mille (1000 = ×1.0) | `int` |

- Content is authored in **seconds** and **metres** because that's how designers think. The content compiler
  converts seconds to ticks once with `ticks = int(round(seconds * 60.0))`, and fails validation if a non-zero
  duration rounds to 0 ticks.
- 1 world unit = 1 metre on the gameplay plane. The plane's Y axis maps to the 3D view's −Z axis
  ([`ARCHITECTURE.md`](ARCHITECTURE.md) §6).

## 2. The tick

`World.step(frame: InputFrame) -> void` advances exactly one tick. The phases run in this order every tick, and
the order is part of the contract:

| # | Phase | Notes |
|---|---|---|
| 1 | **Freeze check** | If `world.freeze_ticks > 0`: decrement it, add the frame's `pressed` bits to the input buffer (§3), increment `world.tick`, publish cues and **stop**. Nothing moves, no status ticks, and **the input buffer doesn't age** during hit-stop. |
| 1b | **Choosing** (v0.3.0 E) | If an altar's or chest's 3-card choice is open (`world.choosing >= 0`): apply only the frame's `pick` (take a card, or cancel), increment `world.tick` and **stop**. Every gameplay phase waits (no AI, movement, hits, statuses, spawns, run time); presses made during the choice are dropped when it closes. |
| 1c | **Run-flow hold** (v0.3.0 B; v0.3.5 PT) | If the floor is over (`BossFlow` `EXITED`), the hero is going into the portal (`ENTERING`, `enter_ticks`: 60, or 24 with reduced motion) or arriving on a floor after the first (`arrive_left > 0`, `arrive_ticks`: 48, or 18): advance only that countdown (`BossFlow.advance_transit`: the way in turns `EXITED` after `enter_ticks`), increment `world.tick` and **stop**. The frame is ignored (no buffering), nothing moves, run time doesn't count. The run flow sets both lengths at setup (`set_transit`); views read the progress (`WorldReader.portal_enter_progress`, `arrival_progress`). `FLOOR_EXIT` is emitted once, as the portal takes the hero. |
| 2 | **Input** | Apply the `InputFrame` to the player: move intent, aim, held buttons, and new presses into the 6-tick buffer. |
| 2b | **Interact** (v0.3.0 E) | A buffered `INTERACT` press within reach of an altar or chest opens it (`Rewards.interact`): a chest you can't afford stays shut; otherwise its offer is rolled once (loot stream) and the choice opens. If it opened, increment `world.tick` and stop. Otherwise a press still buffered within reach of the gamble shrine (v0.3.0 L19, `Gamble.interact`) pays its price and grants one stat at once (loot stream, weighted over the stats under their cap), or records a refusal; the tick goes on. |
| 3 | **AI** | Enemies think in ascending entity id. Expensive thinking (path queries, target scoring) is staggered: an enemy with id `n` runs its heavy pass only when `(tick + n) % AI_HEAVY_PERIOD == 0` (**starting value** `AI_HEAVY_PERIOD = 6`). Light steering runs every tick. |
| 4 | **Action states** | Each actor's current action advances through `WINDUP → ACTIVE → RECOVERY` by tick counts. A buffered press starts a new action only when the current one allows cancelling. |
| 5 | **Move and collide** | Actors move, then resolve against walls and each other (§6). Projectiles sweep (§6). |
| 6 | **Hits** | Active hitboxes and projectile sweeps produce `HIT` events in a fixed order: attacker id, then hitbox index, then target id. |
| 7 | **Drain the effect queue** | All events and triggered payoffs resolve (§7–§8). |
| 8 | **Statuses** | Status timers tick; damage-over-time emits `DAMAGE` (never `HIT`, proc 0) and drains through the queue again. |
| 9 | **Deaths and waves** | Entities marked dead are removed. Spawns queued this tick are added with new ids. The encounter checks its wave and clear conditions. |
| 10 | **Publish cues** | The tick's events are appended to the event log that presentation reads (§9). |
| 11 | **Optional hash** | When a checkpoint is due (§10), the `StateHasher` runs. |

**Who calls `step`.** `SimDriver` (in `src/app/`) calls it from `_physics_process`. Godot's project settings
make that a fixed 60 Hz loop with a catch-up cap ([`ARCHITECTURE.md`](ARCHITECTURE.md) §4). Headless sims,
replays and tests call `step` directly in a loop, with no scene tree.

**Hit-stop** is sim state: `world.freeze_ticks += n` from a hit's `hitstop_ticks`, capped at
`FREEZE_CAP_TICKS` (**starting value** 8) in total. The view never pauses the game on its own.

## 3. `InputFrame`

```gdscript
class_name InputFrame extends RefCounted
var move: Vector2i        # −127..127 per axis, world-plane space, deadzone already applied
var aim_angle: int        # 0..4095, 1/4096 of a turn
var aim_dist_cm: int      # distance from the player to the aim point, 0..AIM_DIST_MAX_CM (starting value 3000)
var held: int             # bitmask of buttons held this tick
var pressed: int          # bitmask of buttons pressed since the previous tick
```

- **Button bits:** `PRIMARY = 1`, `UTILITY = 2`, `DASH = 4`, `INTERACT = 8`, `SHOOT = 16`, then (v0.3.5 K)
  `VENT = 32` (the Vent button, owner F1) and `SKILL = 64` (the build's second ability, owner F18). New bits are
  appended, never renumbered. `VENT` and `SKILL` presses buffer like the others (6 ticks, not aged during
  hit-stop) in `World.kit` (`KitState`), which is hashed only once either was pressed, so the kernel goldens keep
  their hashes.
- **Vent and Skill** (v0.3.5 K, `PlayerSkill`, phase 4 after the attacks). A `VENT` press while Hot or Overclock
  fires the vent blast (`Heat.vent`, the same shape and damage as before) and resets heat to 0 (event `VENT`,
  `amount` = heat vented); under Hot, overheated or without heat it does nothing but the cold click (event
  `VENT_COLD`). Dash and blink no longer vent. A `SKILL` press starts the build's skill when it is ready (cooldown
  over, no swing, dash or guard, not overheated); the skill then commits: no swing, shot, dash or blink starts until
  it ends. Its movement (the Lunge Cleave's lunge, the Scatter Blast's step back) is the player's movement in phase
  5 in place of walking, so walls stop it as they stop a dash; the Scatter Blast's knockback slides enemies in phase
  5 before walls and bodies resolve. Shapes: the cleave is `AttackShapes.arc_touches`; each pellet is a swept ray
  (`PlayerSkill.pellet_touches`, angles from `AttackShapes.pellet_angles`) stopping at the first wall or body.
- **`pick: int`** (v0.3.0 E): the 3-card pick, delivered once like a press. `0` = none, `1..3` = take that card,
  `-1` = cancel (keep the altar or chest for later). The pick UI sends it through `InputLatch.note_pick`.
- **Latching.** The application layer's `InputLatch` collects device events between ticks. A press and release
  that both happen between two ticks still set the `pressed` bit on the next frame, so a tap shorter than one
  frame is never lost. Each `pressed` bit is delivered exactly once.
- **Buffer.** The sim keeps each `pressed` bit for 6 ticks (`INPUT_BUFFER_TICKS = 6`) in the player's state inside
  `World`. An action that can't start yet (for example, a dash during recovery) starts as soon as it can, if that
  happens inside the window. Freeze ticks don't count toward the 6.
- **Quantization.** The latch turns raw input into the frame:
  - **Move:** the stick or WASD vector is screen-relative. It is rotated into the sim plane by the camera yaw
    (below), deadzoned, and scaled to −127..127.
  - **Aim with the stick:** the right stick is screen-relative too, so it is rotated the same way.
  - **Aim with the mouse:** a ray from the camera hits the ground plane at core height. That gives a world point,
    which is already in sim coordinates, so no rotation is applied.
  - Both aims become an angle and a distance.
- **Rotation convention** (the one place it's defined).
  - The camera rig has `rotation.y = +45°`. Sim `(x, y)` maps to 3D `(x, 0, −y)`.
  - So screen input `(sx, sy)`, with `sy` positive for up, rotates **+45°** (counter-clockwise) into the sim:
    `(sx·c − sy·c, sx·c + sy·c)` with `c = √½`.
  - **Worked example:**

    | Input | Screen | Sim angle (1/4096 turn) | Sim direction |
    |---|---|---|---|
    | W or stick up | up | 1536 (135°) | `(−0.707, 0.707)` |
    | D or stick right | right | 512 (45°) | `(0.707, 0.707)` |
    | S | down | 3584 (315°) | `(0.707, −0.707)` |
    | A | left | 2560 (225°) | `(−0.707, −0.707)` |

    `tests/unit/application/test_input_latch.gd` asserts this table.
  - **Aim assist** (gamepad only, about a 12° cone, GA: input) is applied **before** quantization. The replay log
    stores the final, assisted aim, so replays never re-run assist.
- **Bots** build `InputFrame`s too. They inject their own aim error and reaction delay (see
  [`../balance/SCORECARD.md`](../balance/SCORECARD.md) §3), so a bot run is replayable like a human one.
- **Replay file:** a header (sim version, content hash, seed, loadout, the save version if resumed), then one
  encoded frame per tick. Runs of identical frames are run-length encoded.

## 4. Entities and ids

- Entity ids are monotonic `int`s per `World`, starting at 1, and are **never reused**.
- Actor and projectile arrays are kept in ascending id order. New entities spawn into a queue that is applied in
  phase 9; deaths are also applied in phase 9. Nothing is removed from an array while it's being iterated.
- **No gameplay logic iterates a `Dictionary`.** Dictionaries are only for lookups by key. Anything that affects
  outcomes iterates an id-ordered `Array` or packed array.
- The player is always entity id 1.

## 5. Randomness

- `RngStream` wraps Deathventory's `DeterministicRng` math (ported with `rng_step.gd`, see
  [`ARCHITECTURE.md`](ARCHITECTURE.md) §12) in a mutable object.
  - The generator is **xorshift32** (shifts 13/17/5, masked to 32 bits). A zero state is remapped to
    `0x6D2B79F5`.
  - Its methods are `next_u32()`, `range_int(lo, hi)`, `chance_permille(p)` and `pick_weighted(weights)`.
  - `range_int` and `pick_weighted` use **rejection sampling**. Deathventory's `weighted_index` took
    `value % total`, which is biased.
  - The stream's 32-bit state is part of `World`, so it is hashed and saved.
- The run seed derives four gameplay streams by name: `map`, `loot`, `combat`, `ai`. Derivation is Deathventory's
  `derive_stream_seed(run_seed, name)`: FNV-1a 32 over the seed's 4 little-endian bytes, `:` and the lowercase
  UTF-8 name.
- **The enemy sub-stream** (v0.3.5 AI). `World.rng_enemy` is derived as `ai:enemy`, a sub-stream of `ai` like the
  per-room ones below. Normal enemies draw from it (each attack's windup length, the Arc Caster's spell), so the
  spawn director's and the bosses' `ai` draws stay where they were. Its state is hashed only in worlds with enemy
  tables (§10).
- **Per-room streams.** Each room derives its own `combat:room:k` and `ai:room:k` streams from the run seed and
  the room's index `k`. Re-entering a room after a resume therefore replays its randomness exactly, whatever
  happened earlier.
- **Per-room generation seeds.** `FloorGenerator` derives one sub-seed per room from the `map` stream, so changing
  one room's template never shifts any other room.
- The `cosmetic` stream lives in presentation (particle jitter, camera shake noise, pitch jitter). It is derived
  from the run seed by the same `derive_stream_seed(run_seed, "cosmetic")`, so screenshots and replays look the same
  every time. It never reaches the sim, and the arch lint fails if `src/sim/` mentions it.

## 6. Kinematics and collision

**Numeric rules (the determinism promise depends on these):**
- Every gameplay quantity that isn't a position or velocity is an `int` (§1).
- Positions and velocities are float32 (`Vector2` or `PackedFloat32Array`). Kinematic code uses only `+ − × ÷`
  and `sqrt`, which IEEE-754 rounds the same way everywhere.
- Directions come from `Kin.dir(angle: int) -> Vector2`, a lookup into a generated table of 4096 unit vectors.
  `scripts/sim/gen_trig_lut.gd` writes the table once as exact float32 bit patterns into
  `src/sim/core/trig_lut.gd`, and the file is committed. The sim never calls `sin`, `cos` or `atan2`.
- `Kin.angle_of(v: Vector2) -> int` replaces `atan2`: an octant reduction plus a binary search over the table.
- Diminishing returns use authored integer tables (`stacks → value`), never `log`, `pow` or `exp`. (Deathventory's
  `StackCurve` used `ln`.)
- **The promise:** bit-identical results for the same Godot build on x86_64. The proof is the replay golden
  producing the same hash on the ubuntu and windows CI jobs (EI-11). If the hashes ever differ, the contingency is
  fixed-point kinematics (positions as `int` millimetres). That is an EI change: it needs evidence and the owner's
  approval.

**Shapes:**
- Actors are circles (`radius` in metres).
- Walls and cover are oriented boxes (OBBs: centre, half-extents, angle as `int` 1/4096 turn).
- Projectiles are swept segments from last tick's position to this tick's.

**Broadphase:**
- A uniform grid with 1 m cells is rebuilt for actors each tick, in id order.
- Each room has a static wall grid, built once when the room loads.

**Resolution:**
- Actors resolve against walls first, then against each other, in ascending id pairs `(a, b)` with `a < b`.
- Penetration is pushed out along the minimum axis. There are at most `COLLIDE_ITERS` passes per tick
  (**starting value** 2).
- A projectile stops at its first contact along the sweep, ordered by distance and then by target id.

**Why not Godot physics?** Its contact order isn't guaranteed to be deterministic, it needs a scene tree (which
rules out headless sims), and the game has no height axis to simulate.

**Projectiles** are stored as structure-of-arrays inside `World` (packed arrays for position, velocity, radius,
remaining ticks, owner, `root_id`, `proc_pct`, `effect_id`). Each projectile carries its provenance, so a hit
from a projectile resolves under the chain that fired it (§7).

## 7. Events and provenance

Every gameplay consequence is a `SimEvent`:

| Field | Type | Meaning |
|---|---|---|
| `seq` | int | Global sequence number in this `World`, monotonic |
| `tick` | int | Tick it happened on |
| `kind` | enum | `HIT`, `DAMAGE`, `HEAL`, `BARRIER`, `KILL`, `STATUS_APPLY`, `STATUS_TICK`, `SPAWN`, `LIMIT`, then appended: `PICKUP` (v0.2.0; v0.3.0 E: also a card taken from an altar or chest), `COMBO_UNLOCKED` (v0.3.0 G), `BOSS_DEFEATED` (v0.3.0 C: once per boss, after its `KILL`; `amount` = its boss table index) and `SHARDS` (v0.3.0 E: a kill paid `amount` shards at `pos`), …, then (v0.3.5 K) `SKILL_USED` (the build skill started; `amount` = `SkillTable.Kind`, `root_id` = the skill's root, which all its hits share), `VENT` (the Vent button vented `amount` heat) and `VENT_COLD` (the Vent button under Hot: nothing vented). The first nine were declared in v0.0.1, even though early versions emit only some kinds. New kinds are appended, never inserted, because kinds are hashed |
| `root_id` | int | The chain this event belongs to. A player action, an enemy attack or a status tick opens a new root |
| `parent_seq` | int | The event that caused this one (−1 for a root) |
| `depth` | int | 0 for a root; parent depth + 1 otherwise |
| `source_id` | int | Entity that dealt it (the projectile, the actor, or the status owner) |
| `owner_id` | int | Actor credited with it (the player for the player's projectiles) |
| `target_id` | int | Entity affected |
| `amount` | int | Amount requested |
| `amount_applied` | int | Amount after barriers, caps and HP limits |
| `proc_pct` | int | Proc coefficient carried by this event (§8) |
| `tags` | int | Bitmask: `MELEE`, `PROJECTILE`, `DOT`, `AREA`, `CRIT`, … (appended, never renumbered; each its own bit, `test_sim_event_tags.gd`). v0.3.5 K: `SKILL = 1 << 21` marks a build-skill hit (the cleave carries `MELEE`, a pellet `PROJECTILE`); a landed skill adds its own heat once per use |
| `effect_id` | StringName | The item effect that produced it, or `&""` |
| `ancestry` | PackedStringArray | Effect ids already fired in this chain, root to here |
| `pos` | Vector2 | Where it happened, for presentation |

**`RootLedger`** keeps one record per open root: the owner, the base proc, the set of `(effect_id)` already fired
under this root, and a reference count of live things carrying the root (projectiles, area fields, DoTs). A root
is garbage-collected when its count reaches 0 and the queue holds none of its events.

## 8. The effect queue, procs and caps

**`EffectQueue`** (adapted from Deathventory's `event_queue.gd`) orders pending events by
`(depth, priority, root_id, seq)`, ascending. Draining it:

1. Pop the next event and apply it to `World` (the damage pipeline below for `HIT`/`DAMAGE`).
2. For each trigger binding on the affected actors (compiled by `LoadoutCompiler`, see
   [`CONTENT_SCHEMA.md`](CONTENT_SCHEMA.md) §2), the binding fires only if **all** of these hold:
   - its effect id is **not** in the event's `ancestry`;
   - `(root_id, effect_id)` has **not** fired yet (one activation per item effect per root chain);
   - its internal cooldown (ICD, in ticks) is ready;
   - its condition passes;
   - for on-hit triggers, the event's `proc_pct > 0`.
3. A firing binding enqueues its payoff as child events: `depth + 1`, `ancestry + [effect_id]`, and
   `proc_pct = parent.proc_pct * payoff.proc_pct / 100` (integer division).

**Damage pipeline** for a `HIT` (all integer math, in this order):
1. `base` from the attack or payoff.
2. Attacker flat adds, then attacker multipliers: `amt = (base + flat) * mult_permille / 1000`.
3. Target modifiers: guard, facing armour and vulnerability states, as **per-mille multipliers** applied once.
   The Warden's armour is by the hit's direction against its facing: its front arc takes `front_mult_permille`
   (tag `ARMOURED`), its rear arc `rear_mult_permille` (tag `WEAK_SPOT`), the sides 1000. It never blocks (owner,
   2026-10-07). There is no flat per-hit reduction. Deathventory's flat Guard cut was regressive: it removed 50% of a 4-damage hit but only 9% of a 22-damage one (L7).
4. Barrier absorbs first, then HP. `amount` is the request; `amount_applied` is what HP and barrier actually lost.
5. Emit `DAMAGE`. If HP reaches 0 and the target is not already dead, mark it dead and emit **exactly one**
   `KILL`. Later lethal events against a dead target apply nothing.
6. On-hit triggers then see the `HIT` (step 2 of the drain).

**Damage-over-time** ticks emit `DAMAGE` with `tags |= DOT` and `proc_pct = 0`. They never emit `HIT`, so they
can't trigger on-hit effects.

**`CapLedger`** limits sustain: heals, barrier gain and resource refunds have per-window caps (GA: caps). It logs
every request with `requested` vs `applied`, so cap pressure shows up in run records.

**Watchdog** (**starting values**, EI-06):
- chain depth ≤ 8;
- ≤ 128 events per root;
- ≤ 512 events per tick.

Hitting any of them stops that chain, emits one `LIMIT` event naming the guard, and continues the tick. Tests and
sims assert that the `LIMIT` count is 0. The fuzz test is deliberately stricter: ≤ 256 events per tick, so normal
play stays well under the watchdog ([`TEST_MATRIX.md`](TEST_MATRIX.md) T-FUZZ).

## 9. What presentation receives

Presentation sees the sim only through `WorldReader`, a read-only facade over `World`
([`ARCHITECTURE.md`](ARCHITECTURE.md) §3). It offers:
- `events_since(seq) -> Array[SimEvent]`: read-only, in `seq` order.
- `snapshot() -> Dictionary`: a plain-data copy for the inspector, desync diffs and debug views. It is not used
  for gameplay.
- Getters for positions, HP, statuses, action states and telegraphs. Views use these every frame.
- **Cues** are events plus derived presentation hints (for example "hit-stop started"). The `CueBuffer` in
  `src/application/` passes them on **without blocking the sim**. Deathventory's `PresentationGate` let animation
  hold the game; that is gone (see [`ARCHITECTURE.md`](ARCHITECTURE.md) §12).
- **Forecasts:** any preview number or area is computed by calling the same sim function the real outcome uses,
  on the current state, without mutating it (EI-07).

## 10. Hashing and checkpoints

- `StateHasher` streams `World` fields in a **fixed, documented order** into SHA-256 (`HashingContext`):
  - ints as 8-byte little-endian values;
  - floats as their float32 bit patterns;
  - arrays in id order;
  - dictionaries only through sorted keys.
- Fields added after a golden was recorded are hashed only when the world uses them, so the golden holds:
  - the enemy AI (v0.3.5 AI): `rng_enemy`'s state and `ActorStore.AI_FIELDS` (`windup`, `pick`), after the bosses'
    fields, only in worlds with enemy tables;
  - the bosses' v0.3.5 fields (`BossStore.gap_t`, `dash_t`, `dash_x`, `dash_y`) are part of `BossStore`, hashed only
    in worlds with boss tables.
  - the mines (v0.4.0 EN; `MineStore`: ids, owner, damage, life, fuse, fuse total, position, radius), after the enemy
    AI fields, only once a mine was ever dropped (`MineStore.touched`).
- It runs on demand, not every tick:
  - every 60 ticks in replays and goldens (a checkpoint);
  - at encounter end;
  - in tests.
- A replay that doesn't match its checkpoint hash reports the first mismatching checkpoint and diffs the two
  `snapshot()`s.

## 10b. Enemy and boss AI (v0.3.5 AI; owner lines F3-F6)

Starting values; `EnemyAi` and `BossAi` hold the rules, `data/enemies` and `data/bosses` the numbers.
- **No damage without a readable cause** still holds: every windup lasts at least `MIN_TELEGRAPH_TICKS` (24), and
  the shape the view draws is the shape the hit uses (EI-07). What changed is *when the shape stops moving*.
- **Windups drawn per attack.** A normal enemy's windup is drawn from `telegraph_seconds..telegraph_max_seconds`
  (24..40 ticks for the Charger, Warden, Needle and Hatchling) from `rng_enemy`, at the windup's start.
- **Tracking, then commit.** An aimed windup (the Needle's burst, the Arc Caster's bolt and spread; the bosses'
  lanes, sweeps, charges, leaps, barrages, rails and bolt fans) re-aims at the player every tick until its last
  `COMMIT_TICKS` / `track_commit_seconds` (12 ticks), then holds. The telegraph moves with it.
- **Leading.** Normal shots aim where the player will be after the shot's flight time at its current velocity
  (capped at 30 ticks); a dashing player is aimed at where the dash ends (`BossChallenge.dash_landing`). A boss's
  aimed attacks lead by `lead_seconds`, and for `dash_read_seconds` after a dash go at its landing point instead.
- **Charges bend.** A charge in progress turns toward the player by at most `charge_turn_dps` (60 deg/s); the view
  keeps drawing the rest of the run (`EnemyAi.running_lane`). A charge hits within `CONTACT_SLOP_M` (0.02 m) of
  contact, because phase 5 has already pushed the bodies exactly apart.
- **Spreading.** Walking enemies push off other enemies within 1.6 m, and melee walkers within 2-6 m of the player
  swing out to the side their id picks, so a pack surrounds instead of stacking.
- **The gap-closer.** A boss whose player stays beyond `gap_close_distance_m` (from its edge) for
  `gap_close_seconds` performs `gap_close_attack` (Gatekeeper: charge; Brood Mother: leap; Siege Engine: bolt fan).
  The punish attack (`punish_*`, BX) keeps its priority.
- **Arc Caster.** Keeps 6-9 m away and casts by weight: a 22 m/s bolt down a line shown for 30 ticks, a 3-bolt
  spread (14 deg apart, 16 m/s), or a rune under the player that erupts after 36 ticks. One damage number (12).
- **Bomb Drone.** A ground-plane body like any other (melee and shots hit it where its shadow is; the view draws it
  1.8 m up). Keeps 5-8 m away, lobs a bomb at where the player stands: a 1.8 m circle that fills for 48 ticks, then
  explodes for 16. It keeps drifting while the bomb flies; killing it first defuses the bomb (the bomb is its
  windup).

## 10c. The horde kinds (v0.4.0 EN)

Starting values; `EnemyAi` and `Mines` hold the rules, `data/enemies` the numbers. Every attack keeps the readable-cause
rule (a windup of at least 24 ticks, the drawn shape is the hit) and has a recap line (`CAUSE_*`).
- **Swarmer** (packs of 8 from the spawner): the Charger's behaviour with a short, unbent lunge.
- **Splitter.** Swipes a disc `reach_m` ahead of it (`swipe_disc`, fixed at the windup's start). When it dies
  (tick phase 9, `EnemyAi.on_death`) it queues `split_count` Splitlings 0.45 m to either side of where it fell; they
  arrive in the same phase with the usual spawn-in. A Splitling swipes the same way and never splits. Dissolving
  (a boss summon) doesn't split it.
- **Shield Bearer.** `Damage.target_mult` gives a hit from within its front half-arc a multiplier of 0 and
  `TAG_BLOCKED` (a bolt into it ends there); sides and back take 1000. It turns at `turn_rate` only while walking,
  starts a bash only at a player inside the shield arc, and bashes along its facing (`bash_lane`).
- **Mender.** No attack and no telegraph. It keeps its patient (`pick` = the ally's id) while it is alive, hurt and
  within `heal_range_m`; otherwise it looks for the most hurt normal enemy in range every 15 ticks (staggered by id;
  bosses are never healed). Every `heal_period_ticks` it adds `heal_amount` HP (capped at max) and emits `HEAL`
  (source/owner the Mender, target the ally). The view marks it as the priority target.
- **Mine Layer and mines** (tick phase 6, after the enemies' hits). Its active tick drops a mine at its feet (at most
  `max_mines`). An idle mine lives `mine_life_ticks`; when the player's body touches its circle it arms, and
  `fuse_ticks` later (the attack's telegraph, >= 24) it blows, hitting the player if still in the circle. The layer's
  telegraph is its armed mines' discs (`Mines.telegraph`, style `mine`); its own drop shows none (it hurts nobody).
  A mine whose layer is gone is removed (killing the layer defuses its mines). Mine ids come from the actor id
  counter.
- **Sniper.** Keeps 10-14 m. Its line (`snipe_lane`, style `snipe`) shows for 60 ticks, follows the player until
  `SNIPE_COMMIT_TICKS` (24) before the shot, then a hit resolves down the drawn line (TAG_PROJECTILE, no
  projectile). After recovering it walks at 1.5x speed to a spot 45-90 deg around the player (the side and angle
  from `rng_enemy`) in the middle of its band (`pick` = 1), and shoots again only once there (within 0.5 m) or after
  150 ticks.

## 11. Scaling and threat

- **Floor index drives scaling.** Enemy HP, damage and density come from authored integer tables per floor
  (`data/threat/scaling.tres`), with values from GA: scaling.
- **Threat T** adds to those tables through `ThreatModifier`s ([`CONTENT_SCHEMA.md`](CONTENT_SCHEMA.md) §7). The
  player raises T only by choice (PD-05). Every threat cost is shown on the fork or reward before the choice.
- There is no time-based scaling: no global clock and no enrage timer.
- All scaling is integer `‰` tables. A formula that needs `pow` or `exp` is authored as a table instead.
- **The formula is locked by evidence.** Its first version is measured in v0.3.0 and recorded in that version's
  `evidence/`. Later changes need a new sim result showing the scorecard bands still hold
  ([`../balance/SCORECARD.md`](../balance/SCORECARD.md)).

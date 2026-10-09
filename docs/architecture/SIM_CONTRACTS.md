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
| 1b′ | **Shopping** (v0.5.0 SH) | If the floor's shop is open (`world.shop.open`): apply only the frame's `pick` as a shop action (`Shop.choose`: buy card 1..4, `PICK_SHOP_HEAL`, `PICK_SHOP_REROLL`, `PICK_SHOP_SELL + n`, or `PICK_CANCEL` to close), increment `world.tick` and **stop**. Every gameplay phase waits, as for an altar's choice; presses made while it is open are dropped when it closes. v0.5.0 EV: next, an open event panel (`world.ev.open >= 0`) holds the world the same way; only its `pick` applies (`Events.choose`: 1..n takes that choice, cancel is "Leave"). |
| 1c | **Run-flow hold** (v0.3.0 B; v0.3.5 PT) | If the floor is over (`BossFlow` `EXITED`), the hero is going into the portal (`ENTERING`, `enter_ticks`: 60, or 24 with reduced motion) or arriving on a floor after the first (`arrive_left > 0`, `arrive_ticks`: 48, or 18): advance only that countdown (`BossFlow.advance_transit`: the way in turns `EXITED` after `enter_ticks`), increment `world.tick` and **stop**. The frame is ignored (no buffering), nothing moves, run time doesn't count. The run flow sets both lengths at setup (`set_transit`); views read the progress (`WorldReader.portal_enter_progress`, `arrival_progress`). `FLOOR_EXIT` is emitted once, as the portal takes the hero. |
| 2 | **Input** | Apply the `InputFrame` to the player: move intent, aim, held buttons, and new presses into the 6-tick buffer. |
| 2b | **Interact** (v0.3.0 E) | A buffered `INTERACT` press within reach of an altar or chest opens it (`Rewards.interact`): a chest you can't afford stays shut; otherwise its offer is rolled once (loot stream) and the choice opens. If it opened, increment `world.tick` and stop. Otherwise (v0.5.0 EV) a press within reach of a ready event pedestal (`Events.interact`) opens its panel (its choices' cards and curses rolled once, on `loot:event`); if it opened, increment `world.tick` and stop. Otherwise a press still buffered within reach of the shop terminal (v0.5.0 SH, `Shop.interact`) opens the shop (its stock drawn on the first open, from `loot`, by a chest's rules: `Offers.draw`); if it opened, increment `world.tick` and stop. Otherwise a press still buffered within reach of the gamble shrine (v0.3.0 L19, `Gamble.interact`) pays its price and grants one stat at once (loot stream, weighted over the stats under their cap), or records a refusal; the tick goes on. |
| 3 | **AI** | Enemies think in ascending entity id. Expensive thinking (path queries, target scoring) is staggered: an enemy with id `n` runs its heavy pass only when `(tick + n) % AI_HEAVY_PERIOD == 0` (**starting value** `AI_HEAVY_PERIOD = 6`). Light steering runs every tick. |
| 4 | **Action states** | Each actor's current action advances through `WINDUP → ACTIVE → RECOVERY` by tick counts. A buffered press starts a new action only when the current one allows cancelling. |
| 5 | **Move and collide** | Actors move, then resolve against walls and each other (§6). Projectiles sweep (§6). |
| 6 | **Hits** | Active hitboxes and projectile sweeps produce `HIT` events in a fixed order: attacker id, then hitbox index, then target id. |
| 7 | **Drain the effect queue** | All events and triggered payoffs resolve (§7–§8). |
| 8 | **Statuses** | Status timers tick; damage-over-time emits `DAMAGE` (never `HIT`, proc 0) and drains through the queue again. |
| 9 | **Deaths and waves** | Entities marked dead are removed (v0.6.0 CU: as each leaves, `CoreTheft.on_death` drops a core stolen in its window, and Marked's rare card). Spawns queued this tick are added with new ids. The encounter checks its wave and clear conditions. v0.5.0 EV: right after the removal, `Events.advance` drops dead elites, opens an Ambush Cache's chest once its pack is gone and counts a Wandering Drone defence (paying its shards when held); v0.6.0 CU: then `CoreTheft.advance` runs the staggers and steal windows down. |
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
- **Shop actions** (v0.5.0 SH) ride on `pick` while the shop is open: `1..4` buy that stock card,
  `PICK_SHOP_HEAL = 20`, `PICK_SHOP_REROLL = 21`, `PICK_SHOP_SELL = 100` + the index in `Shop.sell_list` (mods in
  pickup order, stat cards one entry per card code in first-taken order, abilities but the weapon in slot order),
  `-1` closes. The shop panel sends them through `InputLatch.note_pick`. Prices, refunds and the rules are in
  [`CONTENT_SCHEMA.md`](CONTENT_SCHEMA.md) §3 (Shop); a refusal (unaffordable, sold out, can't apply, nothing to
  do) changes only `ShopState.denied_tick`.
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
- **v0.4.0 BS** adds two named streams, derived the same way: `crit` (one roll per direct player hit while the crit
  chance is above 0; `Stats.outgoing`) and `ability` (the auto abilities' randomness: a spare bomb's scatter;
  `Abilities`). Offers still draw only `loot`. Both states join the hash with the build block (§10).
- **v0.5.0 EV** adds three sub-streams, derived the same way, so no older draw moves: `map:event` (which rooms hold
  an event; drawn fresh from the run seed by `Events.pick_rooms`, a pure function of layout and seed), `loot:event`
  (`World.ev.rng`: the event drawn per pedestal, each panel's cards and curses on its first open, an ambush's kinds
  and spots, the cursed-chest roll and its card and curse) and `ai:elite` (`World.ev.rng_elite`: one roll per spawn
  while an elite curse is held). They are sub-streams of `map`, `loot` and `ai` like `ai:enemy`; EI-05 lists them
  (owner approval 2026-10-08). Both world states join the hash with the event block (§10).
- **v0.6.0 CU** draws only on named streams that already exist: `combat` (Rooted's dodge: one draw per enemy hit that
  would land on the player, only while a dodge chance is held; `Curses.dodges`), `ai:elite` (core theft: the card an
  elite's or a boss's core holds, drawn when it becomes an elite (`Curses.make_elite`) or rises (`World.spawn_boss`);
  `CoreTheft.on_elite`, `on_boss`) and `loot:event` (the cursed chest's roll and its trade-off curse; a core redrawn at
  its drop when its card no longer applies; Marked's rare card from a slain elite). Cores exist only in worlds with
  the event streams (`World.ev.rng_elite`), so older worlds draw nothing new.
- **Per-room streams.** Each room derives its own `combat:room:k` and `ai:room:k` streams from the run seed and
  the room's index `k`. Re-entering a room after a resume therefore replays its randomness exactly, whatever
  happened earlier. First used in v0.5.5 AR by the sealed arenas' waves (`Arenas`): derived at each seal from the
  floor's seed (`World.seed_value`, which the run seed derives per floor), so room `k` on each floor has its own.
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

**Broadphase** (`DenseGrid`, v0.4.0 SC; it was a Dictionary-of-Arrays uniform grid with 1 m cells):
- A dense grid of 2 m cells over what it holds, each cell's indices in one flat list (a counting sort, no
  Dictionary). Queries return ascending indices without duplicates: every entry whose box overlaps the query, and
  maybe a few more.
- Actors: one entry per centre (queries grow by the largest radius), rebuilt in place in tick phase 3 (the enemies'
  plans query it) and before each collision pass.
- Walls: one entry per covered cell, built with the floor and again when a wall is added in play (the boss door) or
  removed (v0.5.0 PB: the boss door reopening, `World.remove_wall_now`).
  A line of sight or a charge's run walks only the cells along the segment (`World.walls_along`); no sweep tests
  every wall of the floor any more.
- Which candidates a pass sees decides the order bodies are pushed in, so changing the cells changes the replay
  golden: it changed on purpose in v0.4.0 SC (v0.4.0 PROGRESS, "Goldens changed on purpose").

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
| `kind` | enum | `HIT`, `DAMAGE`, `HEAL`, `BARRIER`, `KILL`, `STATUS_APPLY`, `STATUS_TICK`, `SPAWN`, `LIMIT`, then appended: `PICKUP` (v0.2.0; v0.3.0 E: also a card taken from an altar or chest), `COMBO_UNLOCKED` (v0.3.0 G), `BOSS_DEFEATED` (v0.3.0 C: once per boss, after its `KILL`; `amount` = its boss table index) and `SHARDS` (v0.3.0 E: a kill paid `amount` shards at `pos`), …, then (v0.3.5 K) `SKILL_USED` (the build skill started; `amount` = `SkillTable.Kind`, `root_id` = the skill's root, which all its hits share), `VENT` (the Vent button vented `amount` heat) and `VENT_COLD` (the Vent button under Hot: nothing vented). Then (v0.5.0 SH) `SHOP_BUY` (shards spent at the shop: `amount` = the price, `effect_id` = the card's id or `shop_heal` / `shop_reroll`; a bought card also emits `PICKUP` from the terminal, the heal a `HEAL` with `effect_id` `shop_heal`) and `SHOP_SALVAGE` (shards back: `amount` = the refund, `effect_id` = what was sold, `target_id` = its card code). The first nine were declared in v0.0.1, even though early versions emit only some kinds. New kinds are appended, never inserted, because kinds are hashed |
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

**Stats and crit (v0.4.0 BS, owner F9; `Stats`).** A hit the player owns on an enemy first takes the damage stat
(`amount × damage / 1000`, half up) and then, unless it is a DoT tick, one crit roll on the `crit` stream:
`range_int(0, 999) < chance`, chance = the player's base (data: 5 %) + crit-chance cards, at most 750. A crit
multiplies by the crit multiplier (base 1500 + crit-damage cards, at most 4000), half up, and tags `HIT` and `DAMAGE`
with `TAG_CRIT` (bit 16, reserved since v0.0.1). This sits before step 2's attacker multipliers, so it applies to
every player source alike: swings, bolts, skills, abilities, vents and item payoffs (chains, shockwaves, thorns).
DoT ticks the player owns take the damage stat but never crit. A hit the player takes is cut by armour after the
target multipliers (`× armour / 1000`, at least 1). Cards stack multiplicatively per card in per mille (two +10 % =
1210) within their caps; the other stats are read where the sim computes them (cooldowns: dash, skill, blink, bombs;
attack speed: shot period, drone period, a swing's recovery; area: swing and cleave reach, vent radius, ability
radii; move speed; shard gain; pickup range: reward, shrine and pickup reach; regen: per mille of max HP per second,
in and out of combat). Worlds whose player has no crit and no cards (the kernel goldens) never roll.

**Abilities (v0.4.0 BS, owner F8; `Abilities`).** Auto abilities run in phase 6, after the projectile sweeps, so
`World.enemies_near` can use the uniform grid of this tick's bodies; their hits carry `TAG_ABILITY` (bit 24) and an
effect id (`bomb_lobber`, `drone_buddy`, `drone_chain`, `orbit_blades`, `blink_shock`, `combo_sword_wave`), so they
never add heat. Targeting: Bomb Lobber = the enemy with the most others touching a bomb-sized disc around it within
range (ties: nearest the player, then lower index); Drone Buddy = the nearest enemy to the drone within range; Orbit
Blades = any enemy touching a blade, once per enemy per `hit_ticks`. Enemies still spawning in are skipped.

**Element abilities and ability combos (v0.4.0 AB; `ElementAbilities`, `AbilityCombos`).** Arc Field picks its
targets among the enemies within range (alive, not spawning in, ascending index) by a partial shuffle on the
`ability` stream (`range_int(k, n − 1)` per pick); Frost Nova hits every such enemy in its radius; fire patches hit
each enemy touching one at most once per Flame Trail's `hit_ticks`. Each cast and each fire hit takes its own root.
These abilities feed the v0.3.0 engines directly (`Engines.add_shock`, `add_frost`, `add_burn`) after a hit that
landed; the engine numbers come from `World.item_mods`, which `World.refresh_build` rebuilds from the items owned
and then folds in each owned ability's `engine` item (`ItemMods.fold_engine`: engine numbers only, never a feeder;
the stronger value wins). Their hits carry only `TAG_ABILITY` (and `TAG_AREA`), so `Engines.on_hit` sees no source
and no item feeder adds stacks through them. Ability combos are `ComboTable`s with two abilities: `refresh_build`
(after every ability card and at each floor's start) owns those whose abilities are both at `min_level`
(`COMBO_UNLOCKED` as for items). Their payoffs follow §7–§8's loop rules: Storm Bombs, Glacier Ring and Ember Ward
run between `Engines.begin` and `end` (ancestry and the watchdog); Storm Bombs fires once per bomb root, Napalm Drone
once per bolt root, Glacier Ring once per (blade root, enemy) (`ProcLedger` codes 64–66); Wingman and Ember Ward are
rate-limited by their window; Blink Charge only queues bombs and Blade Dance and Superconductor only change numbers
(radius, damage). New hit effect ids: `arc_field`, `frost_nova`, `flame_trail`, `storm_bombs`, `napalm_drone`,
`blade_dance`, `superconductor`, `ember_ward` (and status effects `glacier_ring`).

**Overrun (v0.4.0 AB; `Overrun`).** An Overrun enemy's damage rides on SC's per-enemy power
(`ActorStore.power`, applied by `EnemyAi.powered` to every attack, bolt and mine): `Overrun.on_spawn` multiplies the
tier's power by `damage_permille`, so the two compose (tier × 1.5) and nothing changes in this pipeline. The rest of
the branch is in §11.

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

## 8b. Attack specs and modifiers (v0.6.0 MX1)

Design: [`../design/MODIFIER_ENGINE.md`](../design/MODIFIER_ENGINE.md) (owner B2–B9). MX1 is its "order of work"
step 1: the spec, the compile and one launch for the weapon attacks, with the v0.5 items that touch them moved into
modifier data and no change in what the game does.

**`AttackSpec`** (`src/sim/combat/attack_spec.gd`): one attack as data, in sim units. `form` (`ARC`, `BOLT`, `RING`,
`BEAM`, `ZONE`, `ORBITER`, `LOB`, `BURST`); `tags` for target filters (`weapon`, `melee`, `projectile`, `skill`,
`ability`, `area`, `chain`, `hook`, `auto`); pattern (`count` over the full fan `spread`, `repeat_delay_ticks` /
`repeat_damage_permille`); size (`half_arc`, `reach_m` × (1000 + `reach_bonus_permille`) / 1000, `radius_m`, `speed`,
`life_ticks`, `period_ticks`, `rate_bonus_permille`); payload (`damage`, `damage_permille` when the shot splits,
`nth_every` / `nth_damage_permille`, `hitstop_ticks`, statuses with stacks and `every`, `elements` for the view);
behaviour (`bounces`, `pierce`, `seek`); `hooks` (`AttackHook`: a trigger `ON_HIT`, `ON_KILL`, `ON_NTH` or `ON_END`,
an `every`, flat damage or a per-mille share of the parent's base damage, and a `child` spec); `depth` (0 root, at
most 2); `modifier_ids` (what rewrote it, in order).

**Compile** (`Modifiers.compile(w)`): base specs come from the player table: `blade_step_0..3` (the combo steps,
`[weapon, melee]`), `gun_bolt` (`[weapon, projectile]`), and `skill` (Lunge Cleave `[skill, melee]`, Scatter Blast a
`BEAM` fan `[skill, projectile]`). Both weapons' specs are compiled in every run (the build only enables one, L15).
The build's modifiers are the owned items' `ItemTable.modifiers`, in pick order. Each base spec goes through
**`FORM → PATTERN → BEHAVIOUR → PAYLOAD → HOOK → SCALE`**; inside a stage the modifiers run in pick order and each
one's ops in order; a modifier touches a spec only if the spec carries every tag of its `target` (empty = all).
Ops: `SET`, `ADD`, `MAX`, `MIN`, `MUL_PERMILLE` (integer fields stay integers: `c × v / 1000`), `SET_FORM`,
`STATUS` (the last op in pick order sets a status's stacks and `every`), `ELEMENT` (appended once), `HOOK` (a child
spec built from the op and compiled through every modifier at `depth + 1`; none at depth 2). **Form layering**
(design §2, owner B8): the first `SET_FORM` sets the form; each later one never replaces it but adds an `ON_END`
hook whose child is a copy of the spec in the new form, compiled through the stages after `FORM`. **Riders** keep two
v0.5 rules exact: a weapon step's hits burn whenever the burn engine runs (Wildfire, Flame Trail's borrowed engine),
and the bolt's hits slow whenever the slow runs (Glacial Edge, Cold Snap); a rider is a status, never an element.
No randomness is drawn (EI-05).

**Cache and hash.** The book (`AttackBook`) is cached on `World.attack_book`; `World._build_mods` (an item picked, an
ability granted or levelled, a floor's carry) and a snapshot restore set it to null, and the next read compiles it.
So a compile happens on pick and on load, never per tick. `World.state_hash` adds the book's SHA-256 digest
(`Modifiers.hash_into`) once the build has a modifier; worlds without one (the kernel goldens) hash as before.
Saves store the build's item ids (as before); the snapshot keeps `attack_book` out and the restore recompiles it
(`WorldSnapshot.WORLD_KEPT`).

**Launch** (`Attacks.launch(w, spec, ctx)`): the one entry point that runs a spec. The drivers keep their timing
(`PlayerKit`: the combo's ticks and the shot period; `PlayerSkill`: the lunge) and the runtime factors (the build's
per mille with its carried remainder, Overcharge, Momentum, Bulwark, the gamble shrine, crit and the damage stat in
`Damage.hit`), and pass the damage, angle, root, tags and effect id in an `AttackContext`. Runners in MX1: `ARC`
(the steps and the cleave; reach = `Attacks.arc_reach_m`: a weapon step's base × its reach bonus × Combo Sword's
level, then area, then Hot; a Skill's base × area), `BOLT` (queued for phase 9 as before, one per offset of
`count` / `spread` plus Pulse Gun's twins), `BURST` (a disc), `BEAM` (`seek`: a jump to the nearest other enemy
within `reach_m`; otherwise a fan of rays that stop at the first wall or enemy). The other forms do nothing until the
cards that use them (MX stage 2+). The shape functions (`arc_touches`, `ray_touches`) are the ones the views'
forecasts call (EI-07).

**Hooks and their guard** (design §2): `ON_HIT` and `ON_KILL` run after a landed hit (`every` counts the landed hits
of one launch); `ON_NTH` when an Nth combo step resolves (Overcharge's shockwave); `ON_END` after an arc or a burst
resolves, from where it ends. A player projectile's hit runs the bolt spec's `ON_HIT` hooks (MX1: a projectile does
not carry its spec, so every player projectile reads the Gun bolt's, which is v0.5's Static Chain rule); an `every`
there counts landed bolts on `World.chain_count`, at most once per root (`World.chain_root`). Every hook launch goes
through `Attacks.run_hook`: its child runs at `depth + 1` (at most `MAX_HOOK_DEPTH` = 2) with half the parent's proc
coefficient, so `HIT.proc_pct` is 100 for a root attack, 50 for a hook's attack and 25 below that (`Damage.hit`'s new
`proc_pct` argument; `DAMAGE` keeps 100, `DOT` 0); a hook never runs while its own id is in `World.hook_chain`
(ancestry; empty between ticks); at most `MAX_LAUNCHES_PER_TICK` = 256 launches run in one tick, then one `LIMIT`
(effect `attack_launch_cap`) and the tick's other launches are dropped. A hook attack's own statuses feed at stacks ×
its proc coefficient (rounded down), once per root per target (`ProcLedger` codes 48–52); a root attack's statuses
feed through their v0.5 sources (`Engines.on_hit` by source: a melee hit reads the current step spec, a projectile
hit the bolt spec; `ItemEffects.on_melee_hit` for a step's burn; `ItemProcs.on_bolt_hit` for the slow). The engines'
own guards (`ProcLedger`, `Engines.begin` ancestry and the watchdog) are unchanged; MX1's hook guard keeps its own
chain so v0.5's event provenance (`depth`, `ancestry`) is unchanged.

**What MX1 moved, exactly.** Long Edge (reach bonus), Twin Arc (repeat), Ember Edge (burn status), Splinter Shot
(count, spread, damage share), Rapid Coil (rate bonus), Ricochet Core (bounces), Overcharge (Nth step and its
`ON_NTH` burst), Static Chain (shock status and the bolt's `ON_HIT` seeking beam), Frost Core (slow and frost
statuses), Cinder Shot, Conductor, Serrated Edge, Barbed Bolts, Glacial Edge (their statuses). The items keep their
cards and engine numbers (burn, shock, bleed, frost, slow; the shock Static Chain's jumps and Overcharge's shockwave
feed). The other 17 items (dash, guard, kill, heat, sustain and the ability mods) are not attack rewrites yet (MX
stage 2). The equivalence test (`test_modifier_equivalence`, fixture recorded on the v0.5 code) holds every outcome
equal; the one event-level change is `HIT.proc_pct` on Overcharge's shockwave and Static Chain's jump (now 50).

## 8c. The build model and the ability modifiers (v0.6.0 MX2)

Design: [`../design/MODIFIER_ENGINE.md`](../design/MODIFIER_ENGINE.md) "The build" (owner B7, B8) and "Order of work"
step 2. Evidence: [`../roadmap/v0.5.5/evidence/MODIFIER_ENGINE_2.md`](../roadmap/v0.5.5/evidence/MODIFIER_ENGINE_2.md).

**The build** (`BuildSlots`, `src/sim/abilities/build_slots.gd`): the starting weapon (Combo Sword / Pulse Gun, with
its Skill, the dash and Vent; it still levels with its cards), one utility pick (Blink or Aegis, on the utility button,
outside the slots), up to `BuildSlots.SLOTS` = 6 modifier slots and unlimited stat cards (no slot). v0.4.0's four
ability slots are gone. A **modifier card** is one of the six auto abilities (`AbilityTable.is_modifier`: Bomb
Lobber, Drone Buddy, Orbit Blades, Arc Field, Frost Nova, Flame Trail) or an item that changes attacks
(`BuildSlots.is_slot_item`: it names modifiers, or it is an ability's mod: Cluster Payload, Overclocked Drone, Razor
Orbit, Afterimage). The other 13 items take no slot (they don't rewrite attacks). Afterimage's, Cluster Payload's and
Overclocked Drone's numbers stayed in `ItemMods` in MX2; v0.6.0 MX4 made them modifiers of ops (§8d). `World.mod_slots` holds the modifier cards
in pick order as `Offers` codes (an item index, or `ABILITY_BASE` + an ability index), the layer order
`Modifiers.build_modifiers` compiles in; `BuildSlots.sync` keeps it after every change of what is held (a listed card
stays in place, a new one is appended, one not held leaves), and it is carried (`RunCarry.FIELDS`).

**Taking a card** goes through `BuildSlots.take(w, code, replace)` (`Offers.apply`): a held modifier levels up (an
ability, levels 1..5) and uses no slot; a new one takes the next slot; with the six full it needs a **swap**: it
replaces slot `replace` in place (that card leaves the build: an item with its combos, `Shop.remove_item`; an ability
with its level, cooldown and floor state, `Abilities.remove_slot`, and the ability combos it no longer earns). The
swap is a choice the world waits on, like an altar's pick: `World.swap_code` (the card), `swap_source`
(`BuildSlots.Source`: `REWARD` the altar or chest pick, `SHOP` a buy, `GRANT` a card with no panel: an event's card,
a floor pickup, the dev panel), `swap_ref` (its offer index). `InputFrame.pick` answers it: `PICK_SWAP_BASE + n`
(30..35) replaces slot n, `PICK_SWAP_SKIP` (39) or `PICK_CANCEL` skips. A skip at an altar or the shop goes back to its
cards (nothing paid; a chest's price and a shop's price are paid only when the swap is answered); a skipped grant
leaves the card. A `GRANT` swap runs in `World.step` before the altar's pick (only the answer runs; the tick counts).
`World.add_item` and `Abilities.grant` stay uncapped for tests and labs (the scenario worlds of MX1 hold up to 11
attack items); every player-facing path caps. Hash: `mod_slots` and the swap fields once touched (worlds without a
slot, the kernel goldens among them, hash as before).

**The ability modifiers' attacks.** `Modifiers.compile` adds a spec per held ability modifier, id = the ability id,
tags `[ability, auto, <bomb|drone|orbit|field|nova|trail>, <area|projectile|melee>]`, its v0.5 numbers at its level
(damage × level, radius × level, count, flight / life, cooldown or period); compiled through every modifier (a target
filter reaches it by those tags: Razor Orbit targets `orbit`), then `Modifiers.inherit` gives it the weapon's own
attack's statuses (not the riders), elements and `ON_HIT` / `ON_KILL` hooks (the Blade's first step, or the Gun's
bolt); the drone's copy of a Gun also takes the bolt's count, spread, split share, bounces and pierce. When they fire
(`ModifierAbilities`; Drone Buddy and Orbit Blades keep their v0.5 drivers in `Abilities`):

| Ability | Form | When (owner pick) | Starting values |
|---|---|---|---|
| Bomb Lobber | `LOB` | every `every_attacks`-th weapon attack (a step resolving, a shot), once its cooldown is ready; the count waits for an enemy in range | every 4th attack, 2.5 s cooldown; targets, damage, radius, count, flight as v0.5 |
| Drone Buddy | `BOLT` | each drone's period, at the nearest enemy (v0.5) | a copy of the weapon's attack: its payload and hooks (and a Gun's pattern and behaviour), v0.5 damage and period |
| Orbit Blades | `ORBITER` | each touch of a blade (v0.5: once per enemy per `hit_seconds`) | copies of your attack: the weapon's payload and hooks |
| Arc Field | `ZONE` | a weapon attack leaves a shock field where it ends (the arc's tip; a shot's aim point, 1.5 m to `range_m`), at most once per `level_cooldown` | 1.6 m, 2 s, a hit every 0.5 s, at most `level_count` enemies a tick, 12 damage and `level_extra` shock |
| Frost Nova | `RING` | its modifier (`data/modifiers/frost_nova.tres`) gives the weapon the frost element and 1 frost stack a hit; `streak_kills` kills each within `streak_seconds` send a ring from the player, at most once per `level_cooldown` | 4 kills within 2 s of each other; the ring grows to the v0.5 nova radius over 0.3 s; 10 damage and `level_extra` frost |
| Flame Trail | `ZONE` | a patch every 0.8 m of a dash; a patch where a player projectile ends, at most once per `period_seconds` | v0.5 radius, life, damage and burn per level |

**Runners** (`Attacks.launch`): `LOB` queues a bomb (`AbilityState.bomb_*`, with its spec key and hook level) that
lands `life_ticks` later through `Attacks.land_lob` (every enemy in the blast: a hit of the spec, then its `ON_END`
hooks; Storm Bombs and Cluster Payload as before); `ZONE` lights a patch (`ElementAbilities.add_zone`: the fire
patches, now with a spec key, a hook level and a per-tick cap; an enemy is hit once per the spec's `period_ticks` per
patch kind); `RING` grows a ring (`ModifierAbilities.add_ring`: an enemy is hit when the ring's edge crosses its near
edge; `ON_END` when it reaches its radius); `ORBITER` from a hook sweeps its blades once. The area stat scales a
lingering form's radius at launch (`Attacks.area_radius`, as v0.5's abilities had it). A hook's lingering child takes
the times an op can't name: `Modifiers.HOOK_LOB_TICKS`, `HOOK_ZONE_TICKS`, `HOOK_ZONE_GAP`, `RING_TICKS`.
`Attacks.land(spec, ctx, i)` is one hit of a spec (an orbiter's touch, a patch's, a ring's, a blast's) under
`World.hit_spec`.

**Projectiles carry their spec.** `ProjectileStore.spec_key` names the spec a player projectile runs (`AttackBook`
files every spec and every hook child by key: a root by id, a child under `"<parent key>/<n>"`). Its hit feeds that
spec's statuses (`Engines.on_hit` reads `World.hit_spec`, set around the projectile's `Damage.hit`), its slow
(`ItemProcs`), its `ON_HIT` and (on a kill) `ON_KILL` hooks, and where it ends (a hit that stops it, a wall, its life)
its `ON_END` hooks and Flame Trail's fire (`Attacks.on_projectile_end`). A projectile without a key (Wingman's
volley, Thorn Mantle's bolts, a save from before MX2, a spec gone with a build change) reads the Gun bolt's, v0.5's
rule. Statuses: a projectile and a weapon attack feed through `Engines.on_hit` (as MX1); an ability's other attacks
(a bomb, an orbiter, a patch, a ring) feed their spec's statuses at proc 100 in `Attacks._feed` and `Engines.on_hit`
skips them (no double feed). `spec_key` is hashed only once a projectile names one.

**Saves.** `RunSaver.PAYLOAD_VERSION` 3 (reads 2 and 3). A carry without `mod_slots` (v0.5) sets
`World.migrate_slots`; `Abilities.start_floor`, once the abilities' tables are set, runs `BuildSlots.migrate`: the
held modifier cards in a fixed order (the abilities in their v0.5 slot order, then the attack items in pickup order),
the first six kept and the rest leaving the build (last first); levels are kept. A snapshot from before MX1/MX2 may
lack the fields listed in `WorldSnapshot.ADDED_SINCE_V05`; they keep the base world's values, the per-entry arrays
are padded (`_pad_added`) and the slots migrate the same way. The ability ids are the modifier ids, so no id maps.

**CatchUp.power** (§11) reads the new build: the modifier slots' levels (an ability modifier's level, an attack item
1) and the utility's level at `ability_level_permille` each, the items without a slot at `item_permille`, the combos
at `combo_permille`.

## 8d. The M-list's modifiers (v0.6.0 MX4)

Design: [`../design/MODIFIER_ENGINE.md`](../design/MODIFIER_ENGINE.md) "Order of work" step 4; the cards are the PLAN's
M1–M30 (owner: "keep all M1–M30"). Evidence: [`../roadmap/v0.5.5/evidence/MODIFIER_ENGINE_4.md`](../roadmap/v0.5.5/evidence/MODIFIER_ENGINE_4.md).
Every card is a `ModifierDefinition` of ops (CONTENT_SCHEMA "Modifiers"); the runner features below are the only
code the list needed, each general (any card may use it), each on the one clock, none drawing randomness.

**More base specs.** Besides the weapon's steps, its bolt, the Skill and the ability modifiers, every book compiles
the **moments** `dash`, `move`, `blink` and `body` (form `BURST`, tags `[<id>, moment]`, no damage of their own) and,
with heat, **`vent`** (a `BURST` of the heat table's `vent_radius_m`, tags `[vent, area]`). A modifier with an empty
target rewrites every attack but never a moment: a moment's spec is reached only by a target naming its tag. The
dash's `ON_LAUNCH` hooks fire as it starts (from where it starts) and its `ON_END` hooks as it ends (where it ends);
the move spec's `ON_LAUNCH` hooks every `Modifiers.MOVE_STEP_M` (1.4 m) walked, not dashing; the blink spec's as a
blink leaves (`AbilityMods` keeps a waiting one as v0.5's echo); the body spec is read, never launched (its rules
below). Vent's blast (`Heat.vent`, Meltdown's too) launches the vent spec inside `Engines.begin` with its run-time
radius (`AttackContext.radius_m`: the spec's radius × Heat Sink × area) and damage: the same hits as v0.5.

**Spec fields added** (`AttackSpec`, appended to the hash order): pattern `directions` (`DIR_FORWARD`, `DIR_CIRCLE`:
`count` evenly round; an arc's full circle), `back_permille` (also fired straight back at that share), `aim_offset`
(every bolt's aim turned); behaviour `chains` (a seeking beam's further jumps, each to the nearest enemy not hit yet
within `reach_m`), `homing` (a projectile's turn per tick toward the nearest enemy within 8 m; an arc snaps to the
nearest within reach + 2 m), `returns`, `orbit_ticks`, `intangible`; `mirror` (1: copy the weapon's form, pattern
and every hook; 2: take every hook of the weapon); payload `pull_m`; the body's `barrier_ticks`, `charge_ticks`,
`charge_permille`, `resonance_permille`; the drone's `heat_rate_permille`; and `lineage` (below). Form `WEAPON`
(a hook's child only) launches the weapon's last attack (the Blade's current combo step, the Gun's shot) when it
fires, at a share of the weapon's damage (`Modifiers.weapon_damage`, no remainder carried); with `DIR_CIRCLE` it goes
all round (a full-circle arc, `count` bolts).

**Hooks** take three more triggers: `ON_END` in data (where an arc ends, a projectile ends, a burst, a bomb's blast,
a ring at its radius, the dash's end), `ON_LAUNCH` (as an attack launches, from its origin, at its angle) and
`EVERY_NTH` (every `every`-th launch of the spec launches the child instead; counted in `World.mx.counts`). A hook may
wait (`delay_ticks`: its child goes into the launch queue below) and may be conditional (`when` `OVERCLOCK`: only at
Overclock). A hook op's `hook_ops` shape the child before the build compiles it (a count, a speed, a life, a status,
an element). A bolt child of an arc is a crescent as wide as the arc; a bolt child of a hit leaves from past the enemy
it hit. **Lineage** is the ancestry guard at compile time: a modifier never adds its hook to a spec its own hook made
(Split Shot's splits never split, Cluster Payload's bomblets never split, Aftershock never blasts its own blast); the
run-time guard is unchanged (depth ≤ 2, proc 100 → 50 → 25, `World.hook_chain`, 256 launches a tick).

**A form change keeps the attack's reach** (`SpecForms.change_form`, the first `SET_FORM` and every layer): the range
the spec had (an arc's reach, a bolt's speed × life, a ring's, burst's or zone's radius, a beam's or lob's reach)
becomes the new form's, clamped per form (a bolt turned ring rings out to half its flight, 1.5–6 m). The virtual
field `range` (`MUL_PERMILLE` only) scales whichever field is the form's range.

**Launch** (`Attacks.launch`), in order: a `WEAPON` child resolves; an `EVERY_NTH` hook may replace the launch; a root
weapon or Skill attack takes Ascension's charge; a seeking arc snaps; the form runs; its `ON_LAUNCH` hooks fire; a
root attack with `back_permille` fires back (an arc, a bolt, a beam or a lob; a back copy never repeats); a root
attack with `repeat_delay_ticks` that is not a combo step queues its repeat (the steps keep the Twin Arc echo, so a
step repeats once). Root attacks in a lingering or round form (a weapon turned ring, Vent's blast) feed their own
statuses like an ability's (`Attacks._feed`); an inherited status with an `every` counts that form's own hits
(`ModifierRuntime.every_hit`, per spec and status), so an every-3rd burn on a field burns every 3rd field hit.

**The launch queue** (`World.mx`, `ModifierState`; run in tick phase 6 by `ModifierRuntime.advance`, oldest first):
Twin Cast's repeats (repeat_damage_permille of the damage, from where the player is then when the attack was the
player's own) and delayed hook children (Long Shadow's afterimage). A queued launch keeps its hook level and proc,
and its hook id rides `World.hook_chain` while it runs; one whose spec left the build is dropped.

**Projectile behaviours** (`ProjectileMoves`; `ProjectileStore` columns `pierce_left`, `ret`, `home`, `orbit_t`,
`orbit_n`, `orbit_a`, `life0`, `speed`, set from the spec when it spawns, hashed only once one had a behaviour):
pierce N passes through N enemies (after Hot's and Pulse Gun's pierce); a returning projectile turns back at half its
life, passes through every enemy and ends at the player; a homing one turns toward the nearest enemy; an orbiting one
circles the player at 1.4 m for `orbit_ticks` (its life waits) and leaves along the aim it began on. A hook's
projectile hit carries its spec's effect id (Echo Slash's crescent, Split Shot's splits, Shatter's shards).

**Body rules** (`ModifierRuntime`): Ascension, after `charge_ticks` without a root weapon or Skill attack, the next
one deals × `charge_permille`; Aether Shell, out of combat (no damage dealt or taken, `PlayerBuildState.combat_tick`)
for `barrier_ticks`, the next enemy hit on the player is absorbed (HIT emitted, no damage, a `STATUS_APPLY` on the
player with effect `aether_shell`) and combat starts again; Resonance, an attacker multiplier in `Damage.hit` after
Cold Snap's: + `resonance_permille` per status on the enemy (burning, shocked, bleeding, chilled or frozen, slowed,
poisoned). Phase Dash: `World.dash_iframes_active` holds for the whole dash and the player skips body collisions.
Gravity Well: a burst with `pull_m` moves every enemy it touches (not a boss, not spawning) up to that far toward its
centre before its hits; walls push them out in the next collision pass.

**Venom** (`Venom`, M4): status `poison` (`ModifierOpDefinition.STATUSES`), stacks capped at `poison_max_stacks`, each
new stack refreshing `poison_ticks`; every `poison_period_ticks` the DoT deals `poison_damage` × stacks (its own root,
never a HIT); a poisoned enemy's death spreads its stacks to every enemy within `poison_spread_m`, once per enemy per
dying root (`ProcLedger` code 70; the poison feed is `Engines.CODE_FEED_POISON` 56 + source). The numbers are the
strongest held (Venom Core's card). Actor columns `poison_stacks`, `poison_t`, `poison_cd`, hashed with the modifier
engine's state.

**What the views read** (`AttackSpec.read`, for MX3's `AttackFormLooks`): `directions` as a name (`"circle"`,
`"back"` when the spec also fires back, else `"forward"`), the motion cues `home` and `return` (bools), and
`damage_mul_permille` (the product of the `MUL_PERMILLE` ops on `damage`: the attack's weight), besides the numbers
above. What no spec shows is `WorldReader.modifier_marks` (`ModifierOverlays`).

**Hash, saves.** `Modifiers.hash_into` adds, after the book's digest and only once the build has a modifier, the
queue and counters (`ModifierState`), the poison columns while poison runs and the projectile behaviour columns once
used; worlds without a modifier (the kernel goldens) hash as before. `World.mx`, the projectile columns and the poison
columns are in the snapshot (`WorldSnapshot.STATE_CLASSES` has `ModifierState`); a save from before MX4 lacks them
(`ADDED_SINCE_V05`): the base's fresh state, zeroed columns.

**Offers.** `ItemDefinition.Rarity.LEGENDARY` (and `ItemTable.LEGENDARY`): such a card is only drawn by the boss's
legendary tier and a boss's core (`ItemPool.available(w, true)`); altars, chests, shops and elites never draw one.
The M-list's cards are items of kind `MODIFIER` that name their own modifier; trinkets are `RARE`; an ability merge
names its ability (`requires_ability`); a card tagged `heat` needs a run with heat. Item indices keep v0.5's order
(the items of v0.5's kinds by id, then the `MODIFIER` cards by id: `ModifierCompiler.item_defs`), so a save's item
codes still name the same cards. **CatchUp.power** counts a slot's card as levels: an ability modifier its level,
a v0.5 item 1, an M-list card 1, 2 if rare, 3 if legendary.

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
- **Attack specs** (v0.6.0 MX1, §8b): `attack_ids()`, `attack_spec(id)` (the final spec as plain data, hooks and
  children included), `step_attack_id(step)` and `attack_digest()`. The views draw the weapon attacks from these
  (`AttackView`), never from which cards are held. Reading compiles the cached book when the build just changed:
  the same compile the sim would run, so it never changes an outcome or the hash.

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
  - the event block (v0.5.0 EV; `Events.hash_into`, after the gamble shrine, before the run flow): `curses_owned`,
    `threat_peak`, then `EventState.hash_into` (the two stream states, the pedestals and their rolls, the open panel,
    ambush, defence, Overclock bonus, elites, cursed offers and the last-result ticks), only in worlds set up with
    event or curse tables or holding a curse (`EventState.touched`). v0.6.0 CU appends to it, each only once touched:
    the trade-off curses' state (`CurseState`: Brittle's stun ticks and start, Rooted's last dodge and count, Heavy
    Hands' shot count and last boosted hit, Blood Price's last cost) and core theft (`CoreState`: each carrier's id,
    card, boss flag, stagger meter, stagger and window ticks; the drops on the floor and their kinds; the last window
    and steal). Both are in WorldSnapshot.STATE_CLASSES.
  - the shop (v0.5.0 SH; `ShopState`: id, room, open, rolled, heal used, rerolls, last action, tick and value, the
    refusal tick, the stock, the position), after the gamble shrine, only on floors with a shop; the stat cards taken
    (`World.stat_cards`, the `Offers` codes in order) with the build block, once it is touched.
- It runs on demand, not every tick:
  - every 60 ticks in replays and goldens (a checkpoint);
  - at encounter end;
  - in tests.
- A replay that doesn't match its checkpoint hash reports the first mismatching checkpoint and diffs the two
  `snapshot()`s.

## 10a. The world snapshot (v0.4.0 SV)

`WorldSnapshot` (`src/sim/core/world_snapshot.gd`) turns a whole `World` into plain data and back, for saves
([`ARCHITECTURE.md`](ARCHITECTURE.md) §10). Pure: no file I/O, no hashing.
- **`World.to_snapshot()`** (between ticks) copies **every script variable** of `World` and of every state object it
  holds (`STATE_CLASSES`: the stores, `RngStream`s, `AbilityState`, `KitState`, `HeatState`, `BossFlow`, the actor
  grid…), recursively, in declaration order; packed arrays are duplicated. New state is snapshotted without a list to
  keep. A wall array goes as packed columns. `{format: FORMAT, world: …}`; `FORMAT` changes only when the encoding
  does.
- **Not copied, by name** (`WORLD_KEPT`, each with its reason): the loadout tables (content compiled at setup, kept
  from the base world), the event log (not state; `_event_seq` is copied), the wall grid (rebuilt from the walls), the
  pending boss door and its prepared flow field (only whether they are still pending), and the flow field (rebuilt
  from the walls; its last flood is copied). Objects of a `LOADOUT_CLASSES` class are kept wherever they appear.
- **An object of an unclassified class is an error naming its path** (`take(w, errors)`), never a silent skip.
- **`World.from_snapshot(snap, base)`** writes the snapshot into `base`, a world built from the same generation inputs
  (run seed, floor, build, content) at any tick. It checks the base's generated walls start the snapshot's (else the
  save doesn't fit), re-adds a boss door sealed in play through its prepared field, and rebuilds the grid and flow
  field for any other added wall. A save taken after the boss died (v0.5.0 PB) holds the floor's own walls again (the
  door was removed), so it restores an open door and open portals; `World._nav_open` (the field from before the
  seal, swapped back in when the door reopens) is not copied: `apply`'s re-seal sets it. The restored world's `state_hash()` equals the saved world's, and stepping both with
  the same inputs keeps them equal (`tests/unit/sim/test_world_snapshot.gd`, T-SAVE).
- **The guard** (same test file): every `World` field is in the snapshot or in `WORLD_KEPT`; every object reachable
  from `World` is classified; every object with `hash_into` is a `STATE_CLASSES` class; the loadout tables don't change
  over a long run with a boss fight. A workstream adding a store class adds it to `STATE_CLASSES` (and `_make` if it
  can appear inside an array) or, for read-only content, to `LOADOUT_CLASSES`.

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
- **Staggered plans (v0.4.0 SC).** An enemy re-plans its walk every `EnemyAi.PLAN_PERIOD` (4) ticks, on the ticks
  where `tick % 4 == id % 4`, so a quarter of a crowd plans each tick; it moves every tick along the last plan
  (`ActorStore.plan_x/plan_y`: the way it picks, the spread push, and the flow field while a wall blocks the straight
  walk). The wall check (a sweep along the line to the player) runs every other plan (`plan_block`). A melee walker
  still stops the tick it touches the player. Walkers face the player on their plan ticks and as they attack; the
  Warden turns every tick (its facing is its armour). Timers, windups, tracking and hits still run every tick. The
  plan fields are hashed with the other AI fields.
- **The flow field (v0.4.0 SC).** One flood a `NavField.PERIOD` (10 ticks) from the player for every enemy, stopped
  `NavField.WORLD_FLOOD_STEPS` (160 half-metre steps, ~80 m of path) out, and skipped when the player is still in
  the cell of the last flood (the walls don't change between builds, so the result would be the same). An enemy past
  the bound walks straight until it is back in reach.
- **The gap-closer.** A boss whose player stays beyond `gap_close_distance_m` (from its edge) for
  `gap_close_seconds` performs `gap_close_attack` (Gatekeeper: charge; Brood Mother: leap; Siege Engine: bolt fan).
  The punish attack (`punish_*`, BX) keeps its priority.
- **Arc Caster.** Keeps 6-9 m away and casts by weight: a 22 m/s bolt down a line shown for 30 ticks, a 3-bolt
  spread (14 deg apart, 16 m/s), or a rune under the player that erupts after 36 ticks. One damage number (12).
- **Bomb Drone.** A ground-plane body like any other (melee and shots hit it where its shadow is; the view draws it
  1.8 m up). Keeps 5-8 m away, lobs a bomb at where the player stands: a 1.8 m circle that fills for 48 ticks, then
  explodes for 16. It keeps drifting while the bomb flies; killing it first defuses the bomb (the bomb is its
  windup).
- **v0.4.0 BO.** The flood move (`BossAi.flood_lane_of`, one shape function, drawn and hit alike) tracks and leads
  like the other aimed moves, then its lanes stand for the active time and re-arm the boss's one-hit flag every
  `burn_ticks`, so a player standing in them is hurt at most once per burn period. A boss whose
  `weak_drops_armour` is set (the Warlord) skips its front armour in `Damage.target_mult` while its weak point is
  open. The Lens Drone (the Hive Lens's split, `deploy`) runs the Needle's rules (`EnemyAi.behaviour_of`). New
  actor kinds `WARLORD`, `HIVE_LENS`, `FOUNDRY`, `LENS_DRONE` are appended after `BOMB_DRONE`.

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

- **Floor and danger tier drive scaling (v0.4.0 SC, owner F7/F10).** A normal enemy's max HP is its base ×
  `enemy_hp_floor_permille[floor − 1]` (`data/run/three_floors.tres`: 1.9^(f − 1)) × `hp_tier_permille[tier]`
  (`data/spawning/floor_1.tres`: 1.10^tier), its damage × `enemy_damage_floor_permille` (1.4^(f − 1)) ×
  `damage_tier_permille` (1.05^tier), each step rounded half up (`SpawnTable.scale`). The floor factor is applied to
  the compiled enemy tables when the floor is built (`RunState.scale_enemies`, so a boss's summons get it too); the
  tier factor to each enemy as the spawn director brings it in (HP, and `ActorStore.power`, which `EnemyAi` applies
  to every hit and shot). Tier n starts at n × 30 s of the floor's run time; past the tables' last entry (tier 20,
  ten minutes) the factors stay flat, which keeps the integer products small.
- **The difficulty curve (v0.4.0 TU, owner D1–D4).** On a floor with a curve (`SpawnTable.curve`, a `CurveTable`),
  floor time picks a phase (`phase_at`: the last phase whose start has passed). The curve's danger tier × 1000
  (`tier_permille_at`, integer interpolation within a ramping phase, held in a holding one and at the peak) replaces
  the plain `run_ticks / tier_ticks` everywhere the tier is read (`SpawnTable.danger_tier`): the HP and damage tables,
  the shard bonus (`Rewards.shards_for_kill`) and the HUD's meter. The alive cap is `cap(floor, tier) ×
  cap_permille_at` (at least 1, `cap_now`), the interval `interval(tier) × interval_permille_at` (`interval_now`), an
  arrival's HP and power SC's tier values × `hp_permille_at` / `damage_permille_at` (`hp_now`, `power_now`), and a mix
  row may spawn once its phase has begun (`row_open`); a phase's `pack_cap` caps the pack size. The curve is loadout
  (compiled content, not hashed, not snapshotted): a save resumes on a floor built with the same curve.
- **Heal orbs (v0.4.0 TU, owner D8).** A normal enemy's death (tick phase 9, `Rewards.on_kill`) rolls the `loot`
  stream once against `heal_orb_chance_permille`; a hit lays an orb (`World.orbs`, `HealOrbStore`: id and position,
  hashed once touched, snapshotted) where it fell, at most 16 (the oldest goes). After the pickups, a hurt player
  within `heal_orb_reach_m` × the pickup-range stat takes the nearest one: + `heal_orb_heal_permille` of max HP,
  capped, one `HEAL` event (`effect_id` `heal_orb`). Bosses drop none; orbs don't expire.
- **The floor-1 boss (v0.4.0 TU, owner D9).** `RunState.scale_bosses` multiplies floor f's boss HP and damage by
  `boss_ease_floor_permille[f − 1]` in the same step as the per-floor and Deep factors; `RunState.prepare` sets
  `World.boss_room_heal_permille`, which the sealing of the boss room (`BossFlow`, `HEAL` with `boss_room_heal`)
  restores, capped at max HP.
- **Enemies that join mid-fight** through `World.queue_enemy` (a Splitter's Splitlings, a boss's summons) arrive in
  tick phase 9 with the same scaling as a spawner pack (`SpawnDirector.scale_arrival`: the tier, the curve's easing,
  then the Overrun's ×1.5 when it applies), read at the floor time of that tick (v0.4.0 TU; before it they kept only
  the floor scaling).
- **Bosses keep their own per-floor scaling** (`boss_hp_per_floor`, `boss_damage_per_floor`: +40 % HP and +20 %
  damage a floor), applied once, and no tier scaling.
- **Optional routes (v0.5.0 RT, R5).** On a run's floor before the last the boss room holds two gates: the gate and
  the **Deep gate** (`Routes.place_deep_gate`, a pure function of the layout: on the back wall beside the gate,
  else on a side wall; interior pieces in its zone are removed only if no spot is clear). Both open on the boss's
  death (`PORTAL_OPENED`, `amount` 1 when the Deep gate opened too); walking into one sets
  `BossFlow.route_taken` once (`Routes.Route`: `NORMAL` 0, `DEEP` 1; `FLOOR_EXIT.amount` = the route) and the other
  closes. `RunState.routes` keeps each floor's route (floor 1 `NORMAL`). On a **Deep** floor the floor factor is
  multiplied by `deep_scale` (1.25) before it scales anything: enemy tables × `scale(floor‰, 1250)`, bosses ×
  `(1000 + per_floor × (f − 1)) × 1250 / 1000` — one scale per table, so nothing is applied twice; the tier's HP and
  `power` come on top per enemy as before. A Deep floor also gets `deep_extra_chests` (1) more chests and one free
  **epic altar** (`BossFlow.epic_altar_id`; `Offers.roll_epic`: epic stat cards and level-ups of owned abilities,
  from the loot stream, never a curse or a mod), placed on item spots the floor's rewards left free (no stream is
  drawn). `BossFlow` hashes `routes, route_taken, deep, epic_altar_id`. Threat T for a Deep floor: +1 per Deep floor
  taken (`World.deep_threat`, in `Curses.threat`).
- **Deep floors that bite (v0.5.5 DS, owner S5).** On a Deep floor (`Routes.is_deep`): the first pack the spawn
  director brings into each room has an elite as its first member (`SpawnDirector.deep_elite`, `Curses.make_elite`;
  the rooms already served are `World.deep_elite_rooms`, hashed once one was; no stream is drawn); the epic altar
  stands on the free spot nearest the boss door, the floor's end (`Routes.end_first`; still free and curse-free);
  the event draw takes a Deep-only event first while one is left (`EventTable.deep_only`, `Events.draw_event`; on a
  normal floor such an event has weight 0, so the other events' draws don't move); and the floor's extra T raises
  the hidden catch-up's caps (below). The violet look is presentation's (`StageView`, over the biome's mood).
- **The hidden catch-up (v0.5.5 DS, owner D3-D7, D10, B1: "regular scaling + multiplier based on how much you
  grew", "Yes, but hidden").** Everything above stays the regular scaling; `CatchUp` multiplies on top of it. The
  build's power `P` (per mille of a fresh build, `CatchUp.power`, the one function a later term such as the modifier
  engine's slots joins) is a pure function of the loadout: `weapon_permille(weapon level) × DAMAGE × GLASS_CANNON ×
  (1000 + ONRUSH) × expected_crit(chance, mult) / expected_crit(base) × ATTACK_SPEED × (1000 + ability_level ×
  levels of the non-weapon abilities + item × items held + combo × combos owned)`, each step `/ 1000` in integers;
  nothing about how the run is played (HP, shards, kills, position) enters. `m = clamp(isqrt(P × 10⁶ / E), 1000,
  cap)` per mille with an integer square root (no float, no `pow`). At floor entry (`CatchUp.start_floor`, after the
  carry, the abilities, the heat and the events are set up; `Main._start_floor`) `E = expected_power[f − 1]` and
  `cap = cap[f − 1] + threat_cap × T` (`Curses.threat`: curses held and Deep floors taken); `m` is then fixed for the
  floor (`World.catch_up`, a `CatchUpState`: P, E, cap, m and the boss's, hashed only when the loadout has
  `World.catch_up_table`, snapshotted as state; the table is loadout). Each arriving enemy (`SpawnDirector.
  scale_arrival`, after the tier, the curve and the Overrun; the ambush's elites) gets max HP × m and
  `ActorStore.power × isqrt(m × 1000)` (damage × sqrt(m)). A boss reads its own m when it spawns (`World.spawn_boss`,
  `CatchUp.on_boss`): P now against `boss_expected[f − 1]` (the expected power at the floor's end) with
  `boss_cap[f − 1] + threat_cap × T`; its max HP × m and its attacks' damage × sqrt(m) (`ActorStore.power`, read by
  `BossAi.powered` on every hit and bolt; the closing band's hazard is not scaled). Starting values
  (`data/scaling/catch_up.tres`): E = 1000 / 2000 / 4000, cap ×1.5 / ×2 / ×2.5, boss E = 2000 / 4000 / 7000, boss cap
  ×2 / ×3 / ×4, +0.25 per T, 120 per ability level, 80 per item, 150 per combo. It is never shown to the player: no
  `WorldReader` accessor exists (a test checks); the dev panel reads the world directly.
- **Boss phase gates (v0.5.5 DS, owner D7: mechanics HP can't skip).** Every boss has three phases at 1000 / 660 /
  330 ‰ of max HP (data). Damage on a boss stops at the next phase's threshold (`BossGates.clamp_damage` in
  `Damage._apply`, so a hit, a DoT tick or a burst all stop there; only the world's own hits, owner 0 such as the dev
  panel's Kill boss, pass). `BossAi._update_phase` advances one phase at a time, and each new phase opens with its
  gate (`BossGates.begin`): the attack in progress and the stagger stop, the boss enters state `BossAi.GATE` (6) for
  `GATE_TICKS` (60), standing still and invulnerable, `STATUS_APPLY` with `effect_id` `boss_phase_gate` (amount = the
  gate) is emitted, and `clamp(floor + gate − 1, 2, 4)` adds of the floor's spawn mix open now (round-robin, no stream)
  are queued on a 3.2 m ring (they rise with the normal spawn-in and arrive scaled like any enemy). The gate deals no
  damage. Then the phase's entry attack starts (its own telegraph). `BossStore.gate_t` holds the ticks left.
  Without spawning (the boss labs) a gate brings no adds.
- **After the boss (v0.5.0 PB, owner D10).** `BossFlow` (tick phase 9): the boss's death (`FIGHT` → `OPEN`,
  `PORTAL_OPENED`) also reopens the boss door: `World.remove_wall_now(boss_door_wall)` takes its collider out of the
  walls (matched by shape), rebuilds the wall grid and swaps back the flow field from before the seal (no rebuild),
  flooded at once. `door_sealed()` is true only in `FIGHT`, so `blink_may_land` lets a blink cross the open doorway
  again; `boss_reached()` is true from the seal on. `spawns_open(w)`: in `WAITING`, and in `OPEN` while the player's
  room (`FloorLayout.room_of`; a doorway counts as outside) isn't the boss room; otherwise `count_time` keeps the
  floor clock (`run_ticks`) running, so spawns resume at the curve's level for the floor time, and
  `SpawnDirector.far_points` never anchors in the boss room. The seal happens only from `WAITING`, so its D9 heal
  and `BOSS_ROOM_SEALED` are once a floor. No event kind or hashed field was added: the door's state follows from
  `BossFlow.state`, and the walls are not hashed.
- **Density.** The alive cap is `cap_by_floor` (14 / 30 / 50) + 6 a tier, at most 120; packs arrive every
  `interval_start` (2.5 s) × `interval_tier_permille` (0.9^tier), at least 0.4 s apart (SpawnDirector).
- **Threat T** adds to those tables through `ThreatModifier`s ([`CONTENT_SCHEMA.md`](CONTENT_SCHEMA.md) §7). The
  player raises T only by choice (PD-05). Every threat cost is shown on the fork or reward before the choice.
- **Curses** (v0.5.0 EV; `Curses`) are the first choice-driven T: each one held adds its `threat` (1) to T; T is
  `Curses.threat(w)`, its run peak `World.threat_peak`, and `RunState.threat_by_floor` records T as each floor ends
  (M-THREAT). A curse comes only with a reward the player took knowing it (a cursed chest card, an event choice;
  the card and panel show it first). Its effect is a fixed amount read at one hook each: normal enemies' move speed
  (`EnemyAi.move`), both regen sources, heat decay, the spawn director's arrival size and elite roll, and every shard
  price (`Curses.price`: chests, the gamble shrine, event costs, shops). `Curses.cleanse` lifts one (T falls; the
  peak stays). The T-indexed `ThreatModifier` tables (CONTENT_SCHEMA §7) are not built yet.
- **Trade-off curses** (v0.6.0 CU, PLAN v0.5.5 S6, S7, C1-C8): a curse may carry a second drawback and an upside
  (`CurseTable.effect_2`, `up_effect`); `Curses.total` sums all three. A cursed chest's cursed card is now the curse
  itself (`Offers.CURSE`, code 3000 + curse; rare-level, drawn among the trade-off curses you don't hold); the epic
  stat card it used to carry is gone. Event choices' random curses draw plain curses only. Each effect is read at one
  hook: no dash (`World._advance_actions`), dodge (`Damage.hit`, before any damage: the hurt i-frames and a
  STATUS_APPLY `dodge`), attack speed (`Stats.period`, `Stats.swing_end`), the 4th Blade combo step and every 4th Gun
  shot (`PlayerKit` through `Curses.swing_damage` / `shot_damage`), max HP (`Stats.max_hp`; taking or lifting it moves
  `actors.max_hp[0]` by the difference, and `Events.setup` applies a carried one), crit chance (`Stats.crit_chance`),
  the Skill's and Blink's HP cost (`Curses.on_ability_use`, never below 1 HP, no DAMAGE event) and skill/ability hit
  damage (`Stats.outgoing`), heat decay and Overclock damage (`Heat`), the minimap (`WorldReader.minimap_blind`),
  shards (`Stats.shards`), Brittle's stun (`Damage._apply` on an enemy hit that hurt, not a DoT tick: no move, swing,
  shot, dash, skill or blink while it runs; `Curses.advance` in phase 4) and move speed, Marked's elite hunt
  (`EnemyAi.move`: elites within `hunt_range_m` × (1 + amount)) and its rare card on an elite's death.
- **Core theft** (v0.6.0 CU, PLAN X2; `CoreTheft`): every elite and boss carries a core (one card, drawn on
  `ai:elite`; a boss's from the legendary tier). An elite's direct damage (never DoT) fills its meter; at
  `core_stagger_permille` of its max HP it staggers for `core_stagger_ticks` (its attack is cancelled, `EnemyAi.think`
  and `move` skip it) and the meter resets. A boss staggers by its own meter (BossAi, only read). A stagger while the
  carrier lives opens its steal window for `core_window_ticks`. In phase 9 (`World._remove_dead`) a carrier dying with
  its window open drops its core: `CoreTheft.grant` (the one grant function) puts a free one-card reward
  (`RewardStore.Kind.DROP`, offer set at once) at the body, opened like an altar through the pick. A core whose card
  no longer applies is redrawn on `loot:event`. Then `CoreTheft.advance` (after `Events.advance`) drops gone carriers
  and runs the staggers and windows down.
- There is no time-based scaling: no global clock and no enrage timer.
- **Overrun (v0.4.0 AB, the first T branch).** `OverrunRooms.mark` picks one room per floor after the boss room is
  attached, from the `map:overrun` sub-stream (the `map` stream itself and the walls never change): any room but the
  hall, the boss room, its host and the portal room that is off the shortest doorway path from the hall to the host
  and whose removal keeps the two joined; fewest doorways first (a dead end in 979 of 1,000 seeds). While the player
  stands in it (`FloorLayout.room_of`, tick phase 9), the spawn director's alive cap (`SpawnTable.cap(floor, tier)`)
  is `× spawn_permille` and its interval (`interval(tier)`) `÷` it, and every pack member that arrives becomes an
  Overrun enemy: its tier-scaled HP and its tier power each `× hp_permille` / `× damage_permille` (they compose:
  floor scaling in the tables, tier on arrival, then Overrun).
  `kills_to_clear` Overrun kills (counted wherever they die) clear it: an altar at the room's open spot nearest its
  centre, its offer pre-rolled from the loot stream (ability level-ups first, then new abilities), and the shards those
  kills paid paid again `× (shard_permille − 1000) / 1000` (one `SHARDS` event). Hashed once the room was entered.
  **v0.5.5 AR (owner S8):** the Overrun is the hardest sealed arena (below); the spawn multiplier and
  `kills_to_clear` are gone: its `waves_min..waves_max` waves of `wave_sizes[floor]` spawn inside, each member an
  Overrun enemy, and the altar and bonus come after the last wave.
- **Sealed arenas (v0.5.5 AR; PLAN D2, X1 "open floor, sealed arenas"; `ArenaRooms`, `Arenas`).** With an arena
  table, `ArenaRooms.mark` (after the Overrun room, before the rewards) makes `round(combat rooms × share)` rooms
  arenas: combat rooms are all but the hall (shrine), the boss room and its host, the portal room, the Overrun and the
  shop's room; event rooms are picked afterwards among the rest. No draw: candidates are taken in a fixed order
  (fewest doorways, most hops from the hall, lower index), each only if every non-arena room stays reachable from
  the hall with every arena and the Overrun shut (an arena is always skippable), and only with at least 3 spawn
  points. In play (tick phase 9, `Arenas.advance` after the deaths): the tick the player stands in an uncleared arena
  it seals: a barrier `Obb` per doorway joins `World.walls` (`World.add_barrier`: collision, shots, sight; never the
  flow field, so no rebuild), the room derives its `combat:room:k` and `ai:room:k` streams (§5), draws its wave count
  from `combat:room:k` and its first wave is due `first_wave_ticks` later. While sealed the spawn director does not
  run (the run clock still counts, `Arenas.count_time`) and a blink never lands outside the room. A wave spawns
  `wave_size(floor)` enemies inside (kinds weighted as the director's at the curve's level, `ai:room:k`; spots from
  the room's spawn points ≥ `min_spawn_distance_m` from the player, shuffled from `combat:room:k`), each scaled as any
  arrival (`SpawnDirector.scale_arrival`) with an elite-curse roll; the next is due `wave_gap_ticks` after no enemy is
  alive in the room and none is queued. After the last wave the barriers leave the walls (the wall grid is rebuilt)
  and the room joins `ArenaState.cleared` for the floor. The floor's altars and chests fill arena spots first
  (`Rewards.arena_first`); a reward in an uncleared arena is locked (`Arenas.locked`; `Rewards.nearest` skips it).
  `ArenaState` is hashed once an arena sealed and is snapshotted (STATE_CLASSES); a restore rebuilds only the wall
  grid for the barriers.
- **The boss's legendary altar (v0.5.5 AR, owner X1b; `BossReward`).** Tick phase 9 after the boss flow: the tick
  `BossFlow.opened_tick` is set (the boss died) and the loadout has a `LegendaryTable`, a free
  `RewardStore.Kind.LEGENDARY` reward appears at `FloorLayout.boss_spawn` (`World.legendary_id`, hashed once set; it
  stays set after the pick). Its offer (`Offers.roll_legendary`, loot stream, on the first open) is up to 3 cards from
  the tier only: legendary stat cards (`Offers.LEGENDARY` = rarity 3) and the pool's mods.
- There is no enrage timer. The danger tier is the floor's own clock (it restarts on every floor and counts only
  while the player lives), not a global one; the owner asked for scaling over time (F10, v0.4.0 PLAN).
- All scaling is integer `‰` tables. A formula that needs `pow` or `exp` is authored as a table instead.
- **The formula is locked by evidence.** Its first version is measured in v0.3.0 and recorded in that version's
  `evidence/`. Later changes need a new sim result showing the scorecard bands still hold
  ([`../balance/SCORECARD.md`](../balance/SCORECARD.md)). The v0.4.0 change (SC, above) is the owner's direction;
  its sim result against the expected-build bot is v0.4.0 step TU's (not run in SC). **Superseded 2026-10-08
  (owner P1, v0.5.5):** bot balance sims are no longer run or evidence; a scaling change is judged by the owner's
  play (LOCKED_DECISIONS 2026-10-08).

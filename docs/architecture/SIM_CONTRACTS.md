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
| 1b | **Choosing** (v0.3.0 E) | If an altar's or chest's 3-card choice is open (`world.choosing >= 0`): apply only the frame's `pick` (take a card, or cancel; v0.8.0 N7: on a chest's dealt card any pick value takes it), increment `world.tick` and **stop**. Every gameplay phase waits (no AI, movement, hits, statuses, spawns, run time); presses made during the choice are dropped when it closes. |
| 1b′ | **Shopping** (v0.5.0 SH) | If the floor's shop is open (`world.shop.open`): apply only the frame's `pick` as a shop action (`Shop.choose`: buy card 1..4, `PICK_SHOP_HEAL`, `PICK_SHOP_REROLL`, `PICK_SHOP_SELL + n`, or `PICK_CANCEL` to close), increment `world.tick` and **stop**. Every gameplay phase waits, as for an altar's choice; presses made while it is open are dropped when it closes. v0.5.0 EV: next, an open event panel (`world.ev.open >= 0`) holds the world the same way; only its `pick` applies (`Events.choose`: 1..n takes that choice, cancel is "Leave"). |
| 1c | **Run-flow hold** (v0.3.0 B; v0.3.5 PT) | If the floor is over (`BossFlow` `EXITED`), the hero is going into the portal (`ENTERING`, `enter_ticks`: 60, or 24 with reduced motion) or arriving on a floor after the first (`arrive_left > 0`, `arrive_ticks`: 48, or 18): advance only that countdown (`BossFlow.advance_transit`: the way in turns `EXITED` after `enter_ticks`), increment `world.tick` and **stop**. The frame is ignored (no buffering), nothing moves, run time doesn't count. The run flow sets both lengths at setup (`set_transit`); views read the progress (`WorldReader.portal_enter_progress`, `arrival_progress`). `FLOOR_EXIT` is emitted once, as the portal takes the hero. v0.8.0 N11 (O69): every run floor opens with the arrival (the hero landing on the floor's receiver), its length data (`SimTuning.arrival_first_ticks` 96 on floor 1 of a run, `arrival_ticks` 48 later, `arrival_calm_ticks` 18 with reduced motion; `BossFlow.arrival_length`): nothing spawns, nothing acts and the hero can't be hit until it ends. The app holds the first tick until the loading cover has opened (`SimDriver.hold`). v0.8.0 fix (2026-10-17): the arrival's countdown runs ahead of phase 1b, so a Swap or choice opened while the hero arrives (the dev panel's grant lands between ticks) waits for the landing and never stops the arrival; the HUD (hidden until the landing) takes no Swap answer meanwhile. |
| 2 | **Input** | Apply the `InputFrame` to the player: move intent, aim, held buttons, and new presses into the 6-tick buffer. |
| 2b | **Interact** (v0.3.0 E) | A buffered `INTERACT` press within reach of an altar or chest opens it (`Rewards.interact`): a chest you can't afford stays shut; otherwise its offer is rolled once (loot stream) and the choice opens. v0.8.0 N7 (owner O61): a chest rolls one card (`Offers.CHEST_CARDS`) and deals it (`Rewards.deal`: the reward is `RewardStore.DEALT` while the world waits); phase 1b takes it on the next pick of any value (its price paid, its `PICKUP`, the card applied), so the panel's forecast reads the state before the take; a cursed chest (its curse card before its one card) is a choice as before. If it opened, increment `world.tick` and stop. Otherwise (v0.5.0 EV) a press within reach of a ready event pedestal (`Events.interact`) opens its panel (its choices' cards and curses rolled once, on `loot:event`); if it opened, increment `world.tick` and stop. Otherwise a press still buffered within reach of the shop terminal (v0.5.0 SH, `Shop.interact`) opens the shop (its stock drawn on the first open, from `loot`, by a chest's rules: `Offers.draw`); if it opened, increment `world.tick` and stop. Otherwise a press still buffered within reach of the gamble shrine (v0.3.0 L19, `Gamble.interact`) pays its price and grants one stat at once (loot stream, weighted over the stats under their cap), or records a refusal; the tick goes on. v0.8.0 N14 (owner O72): a paid use first rolls its failure (`fail_permille`, 300, on `loot:shrine:<use>`, one stream per paid use from the floor seed): a failed use is paid, grants nothing, emits `GAMBLE_FAIL` and sets `gamble_fail_tick`; every paid use steps the price up; a win counts toward `max_wins` (3), after which the shrine is spent and refuses. `gamble_wins` and `gamble_fail_tick` are saved and hashed (in the shrine's block, only once they differ from a shrine that never failed); a floor has a shrine with `floor_chance_permille` (400, on `map:shrine`), in a combat room that is not the start hall, the boss room or its host, the portal, Overrun or shop room or an arena (`Gamble.site`); a floor saved before N14 keeps its start-hall shrine. |
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
- **The wand's reorder** (v0.6.5 WN1, §8e) rides on `pick` at any tick: `PICK_WAND_MOVE_BASE` (1000) + from × 16 +
  to moves the wand's card in slot `from` to slot `to`. `World.step` applies it first; the rest of the tick sees no
  pick. The swap answers (§8c) go up to `PICK_SWAP_BASE + 7` (the wand grows to 8 slots).
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
  `Abilities`; v0.8.0 P2: Void's black-hole roll, one draw per shot or landing slash of a spec with
  `hole_permille` > 0, `BlackHoles.roll`, so a build without Void draws nothing new). Offers still draw only `loot`. Both states join the hash with the build block (§10).
- **v0.5.0 EV** adds three sub-streams, derived the same way, so no older draw moves: `map:event` (which rooms hold
  an event; drawn fresh from the run seed by `Events.pick_rooms`, a pure function of layout and seed), `loot:event`
  (`World.ev.rng`: the event drawn per pedestal, each panel's cards and curses on its first open, an ambush's kinds
  and spots, the cursed-chest roll and its card and curse) and `ai:elite` (`World.ev.rng_elite`: one roll per spawn
  while an elite curse is held). They are sub-streams of `map`, `loot` and `ai` like `ai:enemy`; EI-05 lists them
  (owner approval 2026-10-08). Both world states join the hash with the event block (§10).
- **v0.8.0 N17** (owner O75) adds the sub-stream `map:curse_room`, derived from the floor seed like `map:shrine` (its
  first draw dropped, `Gamble.stream`): whether the floor has a curse room (`curse_room_floor_chance_permille`, 400)
  and which allowed combat room (a drawn order of `Events.curse_rooms`, minus the shrine's room), a pure function of
  layout, rules and seed (`Events.curse_site`). The altar's event is then drawn on `loot:event` after the common
  rooms' draws, from the curse events only; the common rooms draw from the others. `EventState.curse_k` (the
  altar's pedestal) is saved and hashed once >= 0. A floor saved under floor rules 1-6 draws as before (no room).
- **v0.8.0 N19** (owner O80) keeps the same `map:curse_room` draws (the chance, then the drawn order) and adds no
  stream: on a Deep floor the chance is `curse_room_deep_chance_permille` (1000); the drawn order is then grouped,
  keeping the drawn order inside each group (small rooms, interior <= `Events.SMALL_ROOM_M2` 170 m², holding no reward;
  other rooms holding none; small rooms holding one; the rest), and the first with an altar spot (`Events.curse_spot`)
  wins. `CurseRoom.furnish` (pure, no draw) then clears the room's interior, puts the altar's footprint and the crystal
  clusters into the world's walls and drops the room's spawn points. Whispering Deep is a curse event (drawn only for
  the altar; on a Deep floor first, as before); Echo Mirror needs `stat_raised` (`Need.STAT_RAISED`). Floor rules 8; a
  floor saved under rules 7 is rebuilt with N17's room, draw and look (`Events.CURSE_RULES_N17`).
- **v0.6.0 CU** draws only on named streams that already exist: `combat` (Rooted's dodge: one draw per enemy hit that
  would land on the player, only while a dodge chance is held; `Curses.dodges`), `ai:elite` (core theft: the card an
  elite's or a boss's core holds, drawn when it becomes an elite (`Curses.make_elite`) or rises (`World.spawn_boss`);
  `CoreTheft.on_elite`, `on_boss`) and `loot:event` (the cursed chest's roll and its trade-off curse; a core redrawn at
  its drop when its card no longer applies; Marked's rare card from a slain elite). Cores exist only in worlds with
  the event streams (`World.ev.rng_elite`), so older worlds draw nothing new.
- **v0.7.5 NB1** adds the sub-stream `map:ice`, derived the same way from the floor seed (`World.seed_value`), like
  `map:overrun` and `map:event`: Frozen Shore's ice patches (`IcePatches.lay`, a pure function of the layout, the
  walls and the seed; every room draws its chance and count, so skipping one room never shifts another). No other
  stream draws more, and floors of other biomes draw nothing. The ice (`World.ice`, an `IceField`) is loadout: laid
  at setup, never written in play, kept from the base on restore (`WorldSnapshot.WORLD_KEPT`) and not hashed (like
  the layout); its effect is: while the hero's position at the start of the move is on a patch, the hero eases with
  the ice's `accel_permille` / `decel_permille` instead of the player's own (a slide). The dash, skills and enemies
  are unchanged on ice. EI-05's list names the streams of LOCKED_DECISIONS; `map:ice` is a sub-stream of `map` the
  way `map:overrun` is (flagged for the owner in the v0.7.5 PLAN).
- **v0.7.5 NB2** adds the sub-stream `map:starglow` the same way (`IcePatches.stream_of(kind)`: `map:<kind>`; ice
  keeps `map:ice`): Starfall's starglow pools, laid by the same `IcePatches.lay` rules into the same `World.ice`
  (an `IceField` whose `kind` is `&"starglow"`; a floor has one surface at most). Its effect: while the hero's
  position at the start of the move is on a pool, the hero's target walking velocity is scaled by the field's
  `speed_permille` (1250: a quarter faster) and they ease with its `accel_permille` / `decel_permille` (Starfall:
  0.1 s up, 0.2 s down, a short drift). Ice's `speed_permille` is 1000, and at 1000 the scale is skipped, so the
  target is untouched and Frozen Shore plays exactly as in NB1. Loadout, not hashed, kept on restore, like the ice; dash, skills and enemies
  unchanged. Not in EI-05's list either (flagged with `map:ice`).
- **Per-room streams.** Each room derives its own `combat:room:k` and `ai:room:k` streams from the run seed and
  the room's index `k`. Re-entering a room after a resume therefore replays its randomness exactly, whatever
  happened earlier. First used in v0.5.5 AR by the sealed arenas' waves (`Arenas`): derived at each seal from the
  floor's seed (`World.seed_value`, which the run seed derives per floor), so room `k` on each floor has its own.
- **The intensity director's cycles (v0.8.0 N5).** `Intensity` derives `ai:intensity:<cycle>` from the floor's seed
  (`World.seed_value`) when a build-up reaches its peak, and draws two numbers from it: the peak's length, then the
  quiet's. No stream is stored (the cycle count is state), so the draws replay exactly after a resume and never move
  any other stream. A sub-stream of `ai` like `ai:room:k`; not in EI-05's list either (flagged with `map:ice`, D13).
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
| `kind` | enum | `HIT`, `DAMAGE`, `HEAL`, `BARRIER`, `KILL`, `STATUS_APPLY`, `STATUS_TICK`, `SPAWN`, `LIMIT`, then appended: `PICKUP` (v0.2.0; v0.3.0 E: also a card taken from an altar or chest), `COMBO_UNLOCKED` (v0.3.0 G), `BOSS_DEFEATED` (v0.3.0 C: once per boss, after its `KILL`; `amount` = its boss table index) and `SHARDS` (v0.3.0 E: a kill paid `amount` shards at `pos`), …, then (v0.3.5 K) `SKILL_USED` (the build skill started; `amount` = `SkillTable.Kind`, `root_id` = the skill's root, which all its hits share), `VENT` (the Vent button vented `amount` heat) and `VENT_COLD` (the Vent button under Hot: nothing vented). Then (v0.5.0 SH) `SHOP_BUY` (shards spent at the shop: `amount` = the price, `effect_id` = the card's id or `shop_heal` / `shop_reroll`; a bought card also emits `PICKUP` from the terminal, the heal a `HEAL` with `effect_id` `shop_heal`) and `SHOP_SALVAGE` (shards back: `amount` = the refund, `effect_id` = what was sold, `target_id` = its card code). The first nine were declared in v0.0.1, even though early versions emit only some kinds. v0.8.0 RM appends `REMNANT_SPAWN`, `REMNANT_ACTIVATE` and `REMNANT_END` (§8l). New kinds are appended, never inserted, because kinds are hashed |
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
1210) within their caps, except an `additive` card (**v0.8.0 SG**, owner O91: damage, attack speed and Glass Cannon;
two +10 % = 1200). The damage multiplier is one additive bucket, `(DAMAGE + ONRUSH while moving + Hoarder's bonus) ×
GLASS_CANNON` (`Stats.damage_permille`); the curses (Blood Price, Glass Heart, Heavy Hands) stay explicit multipliers.
Attack speed has one rule (`AttackRate`): the raw bonus = `ATTACK_SPEED − 1000` + the attack's wand
`rate_bonus_permille` (a negative one counts); the effective bonus counts it in full up to `attack_speed_knee`
(500), at `attack_speed_slope` (500 ‰) up to `attack_speed_knee2` (1500), at `attack_speed_slope2` (250 ‰) above
(`SimTuning`, `data/tuning/sim.tres`); the rate `1000 + effective` (at least 1) then takes Heavy Hands' cut. The Gun's
period is `base × 1000 / rate` half up (at least 2 ticks once changed), the Blade's whole swing (hit tick, sweep,
recovery) scales by the same rate (at least `rate_min`), the drone's period reads the stat alone. A save made before
SG (`World.stat_rules` 0) rebuilds DAMAGE, ATTACK_SPEED and GLASS_CANNON from `stat_cards` and the gamble stacks on
load (`Stats.migrate_rules`). The other stats are read where the sim computes them (cooldowns: dash, skill, blink,
bombs; attack speed: shot period, drone period, the Blade's swing; area: swing and cleave reach, vent radius, ability
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
one's ops in order (**v0.6.5 WN1: replaced by the wand's left-to-right slot order, §8e**); a modifier touches a
spec only if the spec carries every tag of its `target` (empty = all).
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
step 2. Evidence: [`../roadmap/v0.6.0/evidence/MODIFIER_ENGINE_2.md`](../roadmap/v0.6.0/evidence/MODIFIER_ENGINE_2.md).

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
cards (nothing paid; a chest's price and a shop's price are paid only when the swap is answered; v0.8.0 N7: a chest's
dealt card that needs the swap opens it on the answer; a skip shows the card again, a cancel leaves the chest shut with its card); a skipped grant
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
M1–M30 (owner: "keep all M1–M30"). Evidence: [`../roadmap/v0.6.0/evidence/MODIFIER_ENGINE_4.md`](../roadmap/v0.6.0/evidence/MODIFIER_ENGINE_4.md).
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
Gravity Well's pull (a burst with `pull_m`) is retired (v0.8.0 P2, owner O24): no card sets `pull_m` (kept in the hash
order). **Void's black holes** (v0.8.0 P2) are deleted (v0.9.0 VP, owner C §6.4): the card `gravity_well` is retired
(`migration.tres`: a Gun run's becomes the Void form card, a Blade run's is refunded), `BlackHoles`, `hole_*` and its
state are gone; an older snapshot's `hole_*` are ignored on restore. **The Void form** (`VoidShots`, v0.9.0 VP, Q10):
a bolt with `void_mm` > 0 passes through bodies (World's projectile pass); tick phase 6 (`ModifierRuntime.advance`):
each player Void shot hits every enemy within `void_mm` (the area stat on it) as it comes in and every
`void_tick_ticks` (12) while it stays (`World.mx.void_shot` / `void_foe` / `void_next`, a wait per shot and enemy,
hashed only while one waits, snapshotted `ADDED_SINCE_V05`), each tick of a shot its own root, `Attacks.land` with
the Laser's feeding rule; then each enemy within `void_pull_mm` (3 m) is stepped toward the shot's path (the line it
flies along), at most `void_pull_mmps` (1 m/s, weaker with distance), the pulls of all shots on one enemy summed and
capped at the strongest one's top step (no stacking), with a separation push from neighbours within 0.3 m of its
edge; heavies (radius ≥ 0.5 m) half, bosses, elites and spawning enemies none (`VoidShots.steps`, pure: the view's
lean reads it).
**The Lance form** (`Lance`, v0.9.0 AF1, Q7 F5; AF1b, the owner's "low-key Hadouken"): a BOLT spec with `lance` > 0
charges as G13 Charge did (`GunForms.hold`, `World.mx.hold_t`, `hold_ticks` 72, `hold_permille` 11600, +580 a level)
except that a full charge waits for the release; the release (`PlayerKit._fire_bolt`) launches the Gun's own bolt (the
orb's speed, life and look; Twin's lanes at its share) with `pierce` 999 (every enemy, once each; a wall ends it), its
radius × `Lance.size_permille` (× 1 on a tap → × 2 at full) and its damage × the charge ‰; then `Lance.on_release`
emits one `SimEvent.Kind.LANCE` (pos = the muzzle, amount = the ball's radius mm, amount_applied = the aim, proc_pct =
the charge ‰) and starts the push back: `World.mx.recoil_t` = 6 ticks of `recoil_step` = 0.5 m × the charge fraction
/ 6 against the aim, added to the walk in `World._move_and_collide` (walls resolve it); hashed and saved only while
it runs. The card `gun_charge` is retired into it (`migration.tres`).
**The Scatter form** (`Scatter`, v0.9.0 AF1, Q7 F6): a BOLT spec with `pellets` > 0 (the Gun's own bolt runner:
`count` 6 over `spread` 25°, 5 m, `share_permille` 1000 so the pellets past the centre are secondary); `pellets` only
marks them for the view. No new state.
**The Glaive form** (`Glaive`, v0.9.0 AF2, Q7 F7): a BOLT spec with `glaive` > 0 and `returns` 1 (the retired
Boomerang's rule, `ProjectileMoves`: it passes through every enemy, turns at half its life and ends at the hero; a
disc's life never runs out on the way home, and going out a pierce's push spends the ticks its distance takes, so it
turns 7 m out): one
disc every 0.7 s at 14 m/s for 1.0 s (7 m out), `share_permille` 1600 (× 1.6 an orb hit a pass). `glaive` only marks it
for the view. The card `boomerang` is retired into it (`migration.tres`). No new state.
**The Seekers form** (`Seekers`, v0.9.0 AF2, Q7 F8): a BOLT spec with `seekers` > 0: `count` 3 over 40°, `homing`
360 °/s, 10 m/s for 1 s, `share_permille` 450 (the darts past the centre are secondary). A dart's homing target is `Seekers.target`:
the enemies within 10.8 m of the hero, nearest the hero first, taken at the dart's rank (its id modulo `count`), so one
volley spreads over the three nearest; read from the world each tick. No new state.

**The Wave form** (`WaveShots`, v0.9.0 AF3, Q7 F9): a BOLT spec with `wave_mm` > 0 (3000; the area stat scales it):
one shot every 54 ticks (attack speed at half its bonus), 0.1 m a tick, 108 ticks (10.8 m), × 6 an orb hit (+5 % a
level). World's projectile pass skips bodies for it (as the Void's); in tick phase 6 (`ModifierRuntime.advance`, after
`VoidShots.advance`) each Wave shot's band (`wave_mm` wide square to its flight, `DEPTH_M` 0.5 deep) lands one hit
(`Attacks.land`) on every enemy whose body it covers with no wall between, once per shot: the wait is kept in the Void's
per-shot list (`ModifierState.void_shot / void_foe / void_next`, next = the shot's remaining life + 2), so no new state
class and the hash and snapshot already cover it. Its card `gun_wave` is not the Blade's Wave (`echo_slash`) and has no
`wave` tag.
**The Wisps form** (`Wisps`, v0.9.0 AF3, Q7 F10): a bolt spec with `wisps` > 0 (3) keeps the orbs and adds wisps round
the hero at `ORBIT_R_M` 1.1, a turn every 150 ticks, their places a function of `World.tick` (no state). In tick phase
6 each wisp whose turn it is (every `wisp_ticks` 36, staggered evenly) launches the bolt spec from itself at the
nearest enemy it can see within an orb's flight, at `wisp_permille` (400, +20 a level) of the shot's damage, as a
repeat (`ctx.repeat`: no root moments, an extra under ShotCap's 40 a second; its projectile carries the REPEAT bit,
which is how the view tells a wisp's orb), at 650 ‰ of the orb's size.

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

## 8e. The wand (v0.6.5 WN1)

Design: [`../design/WAND.md`](../design/WAND.md) (owner-approved; W3, W6). Evidence:
[`../roadmap/v0.7.0/evidence/WAND_1.md`](../roadmap/v0.7.0/evidence/WAND_1.md). The wand is the build's modifier
slots (`World.mod_slots`, §8c) read left to right; this section replaces §8b's fixed stage order for the compile.

**The compile reads left to right** (`WandCompile`, `src/sim/combat/wand_compile.gd`; `Modifiers.compile_for` builds
one per world). Each card rewrites the spell built so far, in slot order; inside one card its ops still run in stage
order (`ModifierTable.Stage`). The readings where an op's meaning depended on v0.6.0's stage sort:
- a numeric op changes the field as the spell has it at that slot (Big·Split: one big shot whose splits are normal;
  Split·Big: the splits are big too);
- a hook's child (a card's own child attack: Split Shot's splits, Ember Core's kill burst) is built where its card
  sits and compiled by its own card (never its own hook again: lineage) and the cards to its right, never the ones
  to its left;
- a second form op layers as before (an `ON_END` copy in the new form), the copy carrying the spell's shape and
  payload so far but not its hooks, compiled by its card's other ops and the cards to its right; a third form op
  layers on the attack and on the first layer (the depth guard bounds it);
- the riders (§8b) still run after the compile: a v0.5 engine the build runs (Ember Edge's burn, the slow) keeps
  riding the weapon's root attacks whatever the order (a known limit until the old cards migrate, WN5).

**Triggers** (`ModifierOp.Op.TRIGGER`, a trigger card's one op; WAND.md T1–T4) cut the wand. On every spec the
trigger's target reaches (the four cards target every attack), the trigger ends the spell: the cards to its right
don't rewrite it, they build a **child spell** filed as an `AttackHook` (id and effect id: the trigger card's;
damage `WandTable.child_damage_permille` of the hit that set it off). The child starts as a **small copy of the
basic attack** (`WandTable`, data): on a Gun run the Gun's bolt with its radius × `child_size_permille` and its life
× `child_range_permille`, else the Blade's first slash with its reach × `child_size_permille`; tags the weapon's plus
`hook`. Triggers: `ON_HIT` (where a hit lands), `ON_KILL` (where an enemy dies), `ON_END` (where the spell ends: an
arc's tip, a projectile's end, a burst, a bomb, a ring), `ON_FINISHER` (the Blade's T4: compiled into the combo's
last step's `ON_HIT`; no other spec gets a child but the cut still ends it) and `ON_CRIT` (the Gun's T4,
`hook_trigger_gun`: `Attacks` runs it after a landed hit whose `HIT` carried `TAG_CRIT`, read from
`World.last_hit_crit`, which `Damage.hit` sets as it returns). A trigger reaches every spec built to its left (an
earlier Split card's splits get the cut too). A second trigger nests once more: the attack at depth 0, its child at
1, the child's child at 2; a third casts nothing and the cards past it reach nothing. The run-time guard is §8b's:
depth ≤ 2, proc 100 → 50 → 25 (v0.6.5 WN1: a hook's projectile now carries it on its `HIT` too,
`Attacks.projectile_proc`), the ancestry chain, 256 launches a tick. A spec the trigger's target doesn't reach (the
moments: the dash, walking, a blink, the body) reads past it, so a dash card right of a trigger still rewrites the
dash. No randomness is drawn (EI-05).

**The slots grow** (`Wand.slots`): `WandTable.slots_at(World.floor_index)`: 4 on floor 1, 6 after the first boss, 8
after the second (`data/wand/wand.tres`, starting values; the last entry repeats). A world without
`World.wand_table` (a lab, the unit worlds) keeps `BuildSlots.SLOTS` = 6. `BuildSlots.full` is "as many cards as the
wand's slots"; with every slot full a new card opens the Swap (§8c; the answers `PICK_SWAP_BASE + n`, n up to 7). The
held cards keep their order across floors (the carry). Utility (Blink, Aegis) and stat cards stay outside the wand.

**The reorder is input** (owner W3: "the order that you put them in the wand"; WAND.md rule 4). `InputFrame.pick` =
`PICK_WAND_MOVE_BASE` (1000) + from × `WAND_MOVE_STRIDE` (16) + to (`InputFrame.wand_move`) moves the card in slot
`from` to slot `to`; the cards between shift by one. `World.step` applies it first, in any state (a choice or the
shop open, hit-stop), then the rest of the tick reads a copy of the frame with no pick, so a move never answers a
choice. A move from or to an empty slot, or to the same slot, changes nothing. The book compiles again on its next
read (`Modifiers.invalidate`); `mod_slots` is hashed (§8c), so a replay with the same moves is the same run.

**How the views' moves reach the sim** (v0.6.5 WN2). The pause menu stops the ticks (EI-03: no tick, no move), so the
Build page edits a preview only and, when it closes, queues the fewest moves that give its order (`Wand.plan_moves`,
at most one per slot) in `InputLatch.queue_wand_move`; the latch delivers its queue one pick per frame after a pick
already latched, and a pick noted while moves wait goes after them (so a Swap answer given after a reorder arrives
after it). The moves land on the first ticks after the pause closes. The Swap panel (the sim ticks while it waits)
sends each reorder as it is made, and an insert as its answer `PICK_SWAP_BASE + leave` then the move `leave → at`
(`Wand.swap_picks`). Previews use the sim's own pure rules (`Wand.moved_order` / `moved_read` / `swapped_read`,
through `WorldReader.wand_moved` / `wand_swapped`; EI-07). While a swap waits, `WorldReader.wand()["incoming"]` is
the card offered (same shape; `{}` otherwise). Stepping the world a tick per move while paused was rejected: a tick
moves the whole world (enemies, timers), which a pause must not do.

**Reads.** `WorldReader.wand()` (`Wand.read`): the weapon (`&"gun"` or `&"blade"`), the slot count, each card in
slot order (code, id, name key, type, level, `trigger`: -1 or the `AttackSpec.Trigger` it cuts on for this run) and
the cuts (the trigger slots). `WorldReader.wand_read_back()` (`Wand.describe`, pure): the plain-words read-back as
translation keys and their arguments (`WAND_READ_*`, the card name keys): "You fire a bolt shaped by Split Shot.
Each hit casts a small bolt shaped by Ember Core." (`Wand.render(lines, translate)` words it with any translation
Callable; the Build page and the Swap panel render it, WN2).

**Saves.** `RunSaver.PAYLOAD_VERSION` 4 (reads 2, 3 and 4): `mod_slots` is the slot order the player arranged. A
version-3 payload's slots are in pick order, which is its wand order as it stands; the slot count comes from the
floor reached, and a wand holding more cards than that keeps them all (the next new card needs a Swap). A v0.5 carry
(no slots) migrates as in §8c into the floor reached's slot count. A snapshot round-trips the order with equal
hashes (`WandTable` and `last_hit_crit` are kept out: loadout and transient).

**CatchUp.power** (§11) reads the wand's cards (`Wand.size`; a trigger card counts 1), whatever their order: a
reorder never changes P.

## 8f. The Gun pool (v0.6.5 WN3)

Design: [`../design/WAND.md`](../design/WAND.md) G1–G16 (owner "Approve all", PLAN v0.6.5 W7). Evidence:
[`../roadmap/v0.7.0/evidence/WAND_GUN.md`](../roadmap/v0.7.0/evidence/WAND_GUN.md). Every Gun card is a modifier of
the bolt (target `projectile`), compiled left to right by §8e's wand, so its place in the wand decides which spells
it reaches (a card reaches the children built to its left, never those to its right).

**The cards.** G1 Big Shot (`gun_big_shot`: radius × 2, speed × 0.75, flight × 1.333 so the range holds, damage ×
1.6), G2 Rapid Fire (`gun_rapid_fire`: radius × 0.6, rate + 600 ‰, damage × 0.7), G3 Twin (`gun_twin`: `twin` + 1),
G4 Spread (`gun_spread`: count + 2, spread + 30°), G5 Split (`split_shot`: an `ON_HIT` hook, 3 bolts of radius
0.08 m, half the bolt, at 50 %), G6 Pierce (`gun_pierce`: pierce + 2), G7 Ricochet (`gun_ricochet`: bounces + 2),
G8 Homing (`gun_homing`: + 360°/s), G9 Boomerang (`boomerang`), G10 Orbit (`orbit_rounds`: 0.5 s round you), G11
Spiral (`gun_spiral`: `spiral` 35°), G12 Mine (`gun_mine`: `mine_ticks` 3 s and an `ON_END` burst of 1.2 m at 100 %,
effect `gun_mine`), G13 Charge (`gun_charge`: `hold_ticks` 1 s, `hold_permille` 3000), G14 Echo (`gun_echo`: again
after 0.3 s at 60 %, the MX4 repeat), G15 Backfire (`gun_backfire`: back at 100 %, the MX4 back copy), G16 Halo
(`halo_shot`: count × 3, a circle, range × 0.5). Starting values. G5, G9, G10 and G16 are the v0.6 cards of those
ids, turned Gun-only (their ids stay, so saves name them); Seeker, Twin Cast and Rearguard stay with the Blade
(`requires_weapon` blade): on a Gun run G8, G14 and G15 do their job. The rest of the v0.6 cards migrate in WN5.

**Runner features** (`GunForms`, `src/sim/combat/gun_forms.gd`; the spec fields appended to `AttackSpec.INT_FIELDS`,
the hash order):
- `twin` (PATTERN): each bolt of a shot fires with `twin` more beside it, parallel, `GunForms.TWIN_GAP_RADII` (2.6)
  of its radius apart, each a full bolt (`Attacks._bolts`, `GunForms.lanes`).
- `spiral` (BEHAVIOUR, 1/4096 turns): the projectile's heading is its line's plus `spiral × cos(2π age /
  SPIRAL_TICKS)` (24 ticks a turn), applied each tick as a turn of its velocity by the swing's change, after homing
  and the way back (`ProjectileMoves.steer` → `GunForms.spiral_turn`); `age` = ticks since it left (after an orbit).
- `mine_ticks` (BEHAVIOUR): on spawn the projectile's life grows by it; once its life is down to it, it stands still
  (velocity 0, nothing else steers it) until an enemy touches it (the hit ends it: its `ON_END` hooks, the card's
  blast) or the wait runs out (it ends there, its `ON_END` too). A still projectile's sweep is its own disc
  (`Collide.sweep_vs_circle` at t = 0 on overlap).
- `hold_ticks` / `hold_permille` (PAYLOAD): with a charging bolt (`Modifiers.bolt(w).hold_ticks > 0`) `PlayerKit` no
  longer fires on the period while SHOOT is held: each held tick that could fire charges `World.mx.hold_t` (up to
  `hold_ticks`); a release, or a full charge, fires one shot whose damage and bolt radius are × (1000 +
  (hold_permille − 1000) × held / hold_ticks) ‰ (`AttackContext.size_permille`), then the period's cooldown. The
  button is read from `World.held_buttons` (the input frame's held bits, EI-04); nothing else times it.
ProjectileStore columns `spiral` and `mine_t` (hashed with the behaviour columns once a projectile used one);
`ModifierState.hold_t` (hashed only while non-zero). Older snapshots lack them (`WorldSnapshot.ADDED_SINCE_V05`:
padded with 0).

**Levels** (WAND.md rule 6, "A duplicate levels up"): a wand card is an item tagged `wand` (`CardLevels`). Taking one
you hold raises its level (1–5, `World.card_levels` by item index, run-long: `RunCarry`, hashed with the build's
slots once a card levelled) and uses no slot; while below 5 it stays in the offers (altars, chests, the shop,
events, cores: `CardLevels.can_take`). Its modifiers compile at that level (`ModifierTable.at`: each op's value +
`per_level` × (level − 1), a hook's damage share likewise, a hook's child ops too). `CatchUp.power` counts a card's
levels past the first. No randomness anywhere (EI-05).

**The pool.** Gun cards carry `requires_weapon` gun (L15's filter): offered only in Gun runs. The 12 new ones are a
new item kind `WAND` (33, appended), whose indices come after the trigger cards, pool by pool
(`ModifierCompiler.WAND_POOL_ORDER`: the Gun's, then the Blade's §8g, each in id order; `ModifierCompiler.item_defs`),
so every earlier index names the same card.

**The views** (EI-07, read only): `AttackFormLooks.cues_of` adds `twin`, `helix`, `mine`, `swell`; the size is the
spec's radius and weight (Big Shot ×1.6 thicker), the count and pattern the spec's; a live bolt is drawn from its own
trail (so a homing, spiralling or bouncing path shows as it flies) and scaled by its own radius over its spec's (a
charged shot, `AttackFormView.live_scale`); while the Gun charges, an orb at the muzzle grows with
`WorldReader.gun_charge()`; a waiting mine draws a ground ring.
## 8g. The Blade pool (v0.6.5 WN4)

Design: [`../design/WAND.md`](../design/WAND.md) B1–B16 (owner-approved, G1 "Approve all"; W5: "the slash becomes a
spell"). Evidence: [`../roadmap/v0.7.0/evidence/WAND_BLADE.md`](../roadmap/v0.7.0/evidence/WAND_BLADE.md). Each card is
modifier data that rewrites the Blade's combo steps (target `[weapon, melee]`, so a trigger's child slash too) in slot
order (§8e); the runner features below are in `BladeForms` (`src/sim/combat/blade_forms.gd`, state `World.blade`:
`BladeState`), each read from the compiled spec, none drawing randomness, on the one clock.

**Spec fields added** (`AttackSpec`, appended to the hash order; content names in `ModifierOpDefinition.FIELD_STAGE`):
`motion` (-1, or a `SwingStep.Motion`: Thrust's stab, Whirl's spin), `parry`, `counter_ticks` / `counter_permille`,
`carry`, `echo_mirror`, `knockback_m`, `line_m`, `step_m`. Tags `wave` (a flying slash: Wave's and Counter's crescents)
and `finisher` (the combo's last step, `Modifiers.base_step`). `AttackHook.WHEN_COUNTER` (2). An `ORBITER` hook needs
its orbit's reach.

**The swing itself** (`BladeForms.step`, read by `PlayerKit.current_step`): a step whose spec sets `motion`, a swing
speed (`rate_bonus_permille`, which the arc never read before: Flurry +500, Heavy −300; every tick of the swing, its hit
tick too, scales by 1000 / (1000 + bonus), never under `BladeTable.rate_min`) or `step_m` (Lunge Step, added to the
step's lunge and spread over at least `BladeTable.lunge_ticks`, `SwingStep.lunge_over`) swings as a copy of its
`SwingStep`. The combo window, the hit and the views all read that copy (EI-07).

**Runners.** An arc's landed hit with `knockback_m` pushes the enemy (not a boss) straight away over
`knock_ticks` (Heavy). An arc with `parry` removes every enemy projectile its shape touches when it resolves and on
every later tick of the swing (Parry Edge; `BladeState.parried` counts them). A `BURST` with `line_m` is a line from
its origin along its angle (Fissure: an `ON_END` hook from the arc's tip, waiting 0.3 s in the launch queue, its crack;
every enemy within `radius_m` of the line is hit, then its `ON_END` hooks from the far end). An `ORBITER` with
`orbit_ticks` lingers (Orbit Blades): a blade circles the player at `reach_m`, turning `orbit_turn` a tick, hits what
it touches and rests `orbit_gap`; at most `orbit_max` blades (the oldest leaves). A slash within `counter_ticks` of the
last dash's end deals × `counter_permille` (once per dash) and that tick its `WHEN_COUNTER` hooks fire (Counter's wave).
**Compile-time:** a carry child (Finisher+'s shockwave) takes its slash's statuses, elements and hit hooks after the
compile (`BladeForms.settle` → `Modifiers.inherit`), so it carries cards on either side of it; a bolt hook of a
full-circle arc flies as a ring of `CRESCENT_RING` (4) crescents (`BladeForms.hook_base`: Whirl·Wave throws a ring,
Wave·Whirl one crescent).

**The cards** (data `data/modifiers/` + `data/items/`; numbers are starting values): B1 `wide_arc`, B2 `echo_slash`
(Wave), B12 `long_shadow` (Afterimage) and B15 `blade_orbit` (Orbit Blades) keep their v0.6 ids and item indices and
become the Blade cards; B3 `split_wave`, B4 `whirl`, B5 `double_slash`, B6 `thrust`, B7 `heavy`, B8 `flurry`, B9
`fissure`, B10 `chain_cut`, B11 `parry_edge`, B13 `lunge_step`, B14 `finisher_plus`, B16 `counter` are new items of kind
`WAND` (`ItemDefinition.Kind.WAND`, 33, as §8f), indexed after the Gun pool's cards (`ModifierCompiler.WAND_POOL_ORDER`),
so no Gun index moves. Their pool is `requires_weapon = blade` (with the item tag `blade`; validated for `WAND` cards):
offered only in Blade runs. All 16 are tagged `wand`.

**Levels**: §8f's (`CardLevels`, the item tag `wand`, `World.card_levels`, `ModifierTable.at`): one system for every
pool. Each Blade card's ops name their own `per_level` (a hook's child ops too: Split Wave's count, Chain Cut's jumps).

**Tunables** no card's ops name: `World.blade_table` (`BladeTable`, from `data/wand/blade_forms.tres`; a lab world
without it reads the class defaults).

**Hash, saves.** `BladeState` is hashed (`ModifierRuntime.hash_into`, inside `Modifiers.hash_into`) once touched, and
copied by the snapshot (`STATE_CLASSES`; a save from before WN4 lacks it: `ADDED_SINCE_V05`, the base's fresh
state). The view's marks (`fx_*`) are in it: what the views draw of slashes no blade draws (a ghost slash,
a mirrored echo, a fissure's eruption, a cut shot, a counter, a carry shockwave), at most 24, kept 40 ticks.

**Reads.** `WorldReader.blade_forms()` (`BladeForms.read`: the marks, the orbiting blades' positions, the cracks
waiting to erupt, the shots cut, the last counter's tick, the enemies being pushed) and `WorldReader.blade_swing()`
(the current swing's weight, speed bonus, lunge, knockback, parry): `BladeFormView`, `KitView` and the hero's avatar
draw from them.

## 8h. The shared pool and the triggers offered (v0.6.5 WN5a)

Design: [`../design/WAND.md`](../design/WAND.md) S1–S7, T1–T4 (owner-approved, G1 "Approve all"). Evidence:
[`../roadmap/v0.7.0/evidence/WAND_SHARED.md`](../roadmap/v0.7.0/evidence/WAND_SHARED.md). The shared cards are
modifiers on every attack (empty target), compiled left to right by §8e, offered in both weapons' runs; the trigger
cards (§8e) are offered too.

**The cards** (CONTENT_SCHEMA "v0.6.5 WN5a"; starting values): S1 Fire `ember_core` (burn 1, ember; an `ON_KILL`
burst 1.5 m at 60 %), S2 Lightning `storm_core` (storm; an `ON_HIT` seeking beam within 4 m at 50 % that jumps once
more: 2 more enemies), S3 Frost `frost_core` (slow, frost 1, frost element: the frost engine's threshold 3 freezes
for 1 s), S4 Venom `venom_core` (poison 1, venom; the poison spreads on death, §8d), S5 Bleed `shared_bleed` (bleed
1, bleed element), S6 Void `gravity_well` (void on the spell; v0.8.0 P2: `hole_permille` 80 + 30 a level, `hole_damage_permille` 300:
black holes, §8b), S7
Explosive `shared_explosive` (an `ON_END` burst 1.4 m at 60 % where the spell ends: an arc's tip, a projectile's end,
a burst; its child drawn ember). Each levels 1–5 (§8f's `CardLevels`). Everything else is the v0.3 / v0.6 engines.

**S5's moving bleed.** `ItemMods.bleed_move_period_ticks` (the shortest owned; 0 = none). `Engines.bleed_period(w)`:
while the player moves (`World.move_intent` not zero, or dashing) the bleed ticks every `min(bleed_period,
bleed_move_period)` ticks, else every `bleed_period`; a bleeding enemy's countdown is clamped to the moving period
when it applies. Without the card the bleed is v0.5's exactly.

**Order fixes the shared cards needed** (WN1's known limits):
- **Riders** (§8b) ride only on an engine something outside the wand runs: an owned item that is not a wand card
  (`CardLevels.is_card`) bringing burn (or the slow), or none (an ability's borrow). So Fire right of a trigger no
  longer burns the slash (it burns the child), Frost right of one no longer slows the bolt; Wildfire or Glacial Edge
  (v0.5) still ride every root attack as before.
- **A child slash** (an `ARC` at depth > 0: a trigger's cast) hits under `World.hit_spec`, and `Engines.on_hit`
  no longer feeds it the combo step's statuses: it feeds its own (`Attacks._feed`).
- **A trigger's cast feeds its statuses whole** (a spec tagged `cast`, below): `_feed` takes its stacks, not stacks ×
  proc (1 × 50 % rounded down was 0, so ON HIT · Fire never burned on the Blade); a cast bolt already fed whole
  through `Engines.on_hit`. The proc coefficient (§8e: 100 → 50 → 25 on `HIT.proc_pct`) is unchanged.
- **A hook's bolt leaves past the enemy it hit** (§8d's rule) measured from the enemy's centre: the hit point is the
  projectile's centre at contact, so the child spawned inside the enemy and hit it again (Split's shards, a trigger's
  cast bolt). The Blade's child slash still starts on the hit and sweeps that enemy too.

**T4's face per weapon.** `ItemTable.name_key_gun` / `desc_key_gun` (empty: one face); `Offers.item_keys(w, it)`
gives the Gun face on a Gun-only run. `Offers.info`, `WorldReader.item_name_key` / `item_desc_key` and so the wand's
read (`Wand.read`), the pick cards, the Swap and the Build page show On Finisher with the Blade and On Crit with the
Gun.

**The casts the views draw** (`WandCasts`, `src/sim/combat/wand_casts.gd`; EI-07). WandCompile tags a trigger's child
spell `cast` (`WandCasts.TAG_CAST`). `Attacks.run_hook` notes each child it launches at once (not a delayed one) when
it is a cast (any form) or a `BURST` / `ARC` no other view draws (not an `ON_NTH` wave, a Fissure line or a carried
shockwave): the tick, the child's book key, where from, which way, and whether it is a cast, in `World.mx`
(`ModifierState.cast_*`), at most `WandCasts.MAX` (32), none older than 60 ticks at the next note. View data only:
no outcome reads it, `ModifierState.hash_into` and `touched()` leave it out, the snapshot copies it.
`WorldReader.wand_casts()` reads it; AttackFormView draws each mark once: a cast's sigil (a flash in
`AttackFormLooks.CAST_SIGIL` and a small ring in the child's elements) and, for a slash or a blast, the child spell
from its own spec; a cast bolt flies with the `cast` cue. `AttackFormLooks.cues_of` adds `cast` (a spec tagged
`cast`) and `blast` (an `ON_END` burst hook: Explosive). No randomness anywhere (EI-05).
## 8i. The old cards' migration and the legendary tier (v0.6.5 WN5b)

Design: [`../design/WAND.md`](../design/WAND.md) "What happens to the v0.6 cards" (the mapping table). Evidence:
[`../roadmap/v0.7.0/evidence/WAND_MIGRATION.md`](../roadmap/v0.7.0/evidence/WAND_MIGRATION.md).

**Retired cards.** `data/wand/migration.tres` (CONTENT_SCHEMA "the wand") lists 43 v0.6 cards: 13 of the 14 v0.5 attack
items, the four ability mods, the 17 M-list cards that did not keep their id (as a wand card, WN3/WN4, or as a shared
card, WN5a: Ember, Storm, Frost and Venom Core and Gravity Well are S1–S4 and S6), the three MX4 legendary versions and
the six ability modifiers. Each compiles `ItemTable.retired` / `AbilityTable.retired`: `ItemPool` never
draws a retired item (altars, chests, the shop, events, cores, the legendary tier) and `Abilities.can_take` refuses a
retired ability (altars, the shop, events, the overrun); `World.add_item`, `Abilities.grant` and the dev panel still
take one. Nothing is deleted, so item and ability indices and old saves resolve.

**The migration** (`WandMigration.run`, `src/sim/abilities/wand_migration.gd`): a build that still holds a retired
card is rewritten once, at `Abilities.start_floor` (after the carry: a new floor from an old save's carry) and after a
save's snapshot is written (`Main._start_floor`). The cards in wand order (`World.mod_slots`: a v0.6 save's pick order;
then held retired cards outside a slot) are read; a retired card becomes its row's target for the run's weapon
(`WandTable.migrate_blade` / `migrate_gun`, by id) in its place in the wand; a target already held, or met twice,
levels up instead: the levels add (an ability its level, a `LEGENDARY` item `CardLevels.MAX_LEVEL`, any other card 1),
at most 5. A card without a match (an empty target, or a target not in the data yet: S5 `shared_bleed` and S7
`shared_explosive` until WN5a merges) is refunded as shards, the shop's salvage price on this floor (`ShopTable.sell_price` by its rarity for an
item; `ability_refund_per_level` × its level for an ability; `Shop.sell_list`'s numbers). The old card leaves as a sale
does (`Shop.remove_item` with its combos; `Abilities.remove_slot`). Deterministic, idempotent, no randomness; a world
without `World.wand_table` (a lab) changes nothing. A wand that ends up larger than the floor's slots keeps every card
(§8e). The payload stays version 4: the migration reads the content, not the version. v0.6.1 snapshots (payload 3)
lacked `World.tuning` (the dev panel's Step 6); it is in `WorldSnapshot.ADDED_SINCE_V05` now (the base's loadout), so
they load.

**The legendary tier** (`LegendaryTable.wand_level`, data 5): `Offers.roll_legendary` draws, besides the tier's
`mods`, every wand card of the run's pool still in `ItemPool.available(w, true)`; a wand card picked at the boss's
legendary altar is raised to `wand_level` after it is taken (`BossReward.on_pick` from `Rewards.choose`; a held card
rises, never falls). The tier's `mods` are three legendary triggers: `ModifierOp.casts` 2 (`trigger_on_hit_twice`,
`trigger_on_kill_twice`, `trigger_on_end_twice`): `WandCompile._cut` files the child spell `casts` times as hooks of
the same trigger, the n-th with `delay_ticks` × n (0.15 s: the later casts go through the launch queue, §8d). The pick
of 3 is unchanged. `WorldReader.legendary_card_level(i)` tells the pick panel the level ("Mod · Level 5 · Legendary").
**Superseded by v0.8.0 FL** (§8m): the level-5 grant is gone (`BossReward.on_pick`, `BossReward.level_after` and
`WorldReader.legendary_card_level` were removed; `LegendaryTable.wand_level` is retired and the content must hold 0).

## 8j. Blade combinations and the Gun's top end (v0.8.0 BL)

G1: [`../roadmap/v0.8.0/BLADE_AUDIT.md`](../roadmap/v0.8.0/BLADE_AUDIT.md) (owner, 2026-10-14: rows B1–B7 as
proposed). Evidence: [`../roadmap/v0.8.0/evidence/BLADE.md`](../roadmap/v0.8.0/evidence/BLADE.md).
- **Levels that start late (B2).** `ModifierOp.per_level_after` (content `ModifierOpDefinition.per_level_after`, 1..4,
  default 1): the op's `per_level` counts only for the levels above it (`at_level`: value + per_level × max(0, level −
  per_level_after)). A `MUL_PERMILLE` op's `per_level` is kept as a float and rounded per level (Flurry's 250 / 3).
- **Repeats (B1).** `AttackSpec.repeats` (a `LATE_INT_FIELDS` field: hashed with its name only when not 0, so a spec
  without it hashes as before): a root attack with `repeat_delay_ticks` repeats `max(1, repeats)` times, the first
  `repeat_delay_ticks` after it, each next one `ModifierRuntime.REPEAT_GAP_TICKS` (5) after the one before. A combo
  step's first repeat stays its echo (`World.echo_*`); the others go through the launch queue (§8d,
  `ModifierRuntime.queue_echoes`: from where the player is then, the echo's effect id), so the next swing never
  cancels them. Double Slash sets `repeats` = its level at 70 %.
- **A slash hit casts twice (B3).** On a Blade run (`PlayerBuild.has_blade`, a combo), `WandCompile._cut` files an
  `ON_HIT` / `ON_KILL` / `ON_FINISHER` cut on an `ARC` spec `WandTable.blade_hit_casts` (2) times its casts, the n-th
  with `delay_ticks` = n × (the trigger's own delay, or `blade_cast_gap_ticks`: 6). `ON_END`, `ON_CRIT`, the Gun and
  every non-arc spec are unchanged.
- **Once per line (B6).** `WandTable.once_per_line` (data: `split_shot`, `shared_explosive`): a HOOK op of one of these
  cards is not added to a spec whose `lineage` already holds one of them (`WandCompile.once_more`), so Split's splits,
  Explosive's blast and anything cast from them neither split nor explode; the first shot does both.
- **Blast merge (B6).** `Attacks.merged`, in `run_hook` before an undelayed child launches: for a hook in
  `WandTable.blast_merge_ids` (Explosive), past `blast_merge_after` (8) such blasts set off in one tick, one within its
  child's `radius_m` of a blast already set off that tick does not go off (`World.blast_merged` counts it); one farther
  away still does. `World.blast_tick` / `blast_pos` / `blast_merged` are per-tick, not hashed, and in
  `WorldSnapshot.ADDED_SINCE_V05`.
- **Offer weight (B5).** `ItemPool.card_weight`: a mod draw (`ItemPool.draw_weighted`, `Offers.draw`'s mods) weighs a
  card its rarity weight × `RewardTable.own_weapon_card_permille` (data 1500) when it is a wand card of the run's own
  weapon, × 1000 otherwise. The loot stream is drawn the same number of times.
- **New cards (B4).** Blade Storm (`blade_storm`, rare: an `ON_LAUNCH` hook of 1 + level returning bolts, 45 %) and
  Riposte Chain (`riposte_chain`: an `ON_KILL` seeking beam, reach 4 m, `chains` = level, 80 %). Their items have
  `index_wave` 1: `ModifierCompiler.item_defs` puts every wave-0 card first in its v0.6.5 order, then wave 1, so no
  saved item index moves.
- **The Blade Storm build's cost (v0.8.0 PF2, owner O9).** Evidence: [`../roadmap/v0.8.0/evidence/PERF.md`](
  ../roadmap/v0.8.0/evidence/PERF.md) "PF2". Two rules, both data:
  - *Cast-free line.* `WandTable.cast_free_lines` (data: `blade_storm`): `WandCompile._cut` files no trigger cut on a
    spec whose `lineage` holds one of these cards (`WandCompile.cast_free`); the trigger still ends that spec (the cards
    to its right don't rewrite it). A Blade Storm blade's hits cast no trigger's spell; the slash, Wave's crescents and
    every other spec cast as before.
  - *A cap of its own.* `AttackSpec.alive_max` (a `LATE_INT_FIELDS` field; content op field `alive_max`, PATTERN):
    `Attacks._bolts` launches a bolt of such a spec only while `World.player_projectiles_of(spec.id)` (its projectiles
    alive and queued, every key of that id, counted on demand at the launch) is under it; a launch cut short throws the
    bolts that fit, in pattern order, and leaves one `LIMIT` event (`effect_id` `attack_alive_cap`, `amount` the cap).
    Blade Storm's child sets it to 36 (6 slashes × 6 blades: a level-5 Double Slash swing). Nothing is stored per tick
    (no `WorldSnapshot` field); a spec without it hashes as before. `SimTuning.player_shots_max` still holds.

## 8k. Shared damage, repeats and rhythms (v0.8.0 MR)

Owner O91; spec [`../roadmap/v0.8.0/BALANCE_PASS.md`](../roadmap/v0.8.0/BALANCE_PASS.md) "MR" (starting values);
WAND.md rules 10–11. Evidence: [`../roadmap/v0.8.0/evidence/BALANCE_MR.md`](../roadmap/v0.8.0/evidence/BALANCE_MR.md).
- **Shares.** `AttackSpec.share_permille` (`LATE_INT_FIELDS`; content op field `share_permille`, PAYLOAD; 0 = whole):
  `Modifiers.numeric` reads 0 as 1000, so a card's `MUL_PERMILLE` multiplies down the wand (Twin 600, Spread 550, Halo
  400; each `+per_level`), and the view's `damage_mul_permille` takes the same factor. `Attacks._shared_form` runs the
  form with the launch's `damage` and `base_damage` at that share (its hooks' shares are of it); `ON_LAUNCH`, the back
  copy and the repeat queue keep the whole. A Ring's `take_in` of a count drops the share (its pulses take
  `ring_share_permille`). Spread's count is +2 at level 1, +1 a level after; Echo repeats at 500 (+50); Double Slash
  at 600.
- **Secondary proc.** `WandTable.secondary_proc_permille` (data 500; `SecondaryProc`). Secondary: a sharing spec's bolts
  past its primary one (`Attacks._bolts`: the centre offset's first lane, a circle's first), every bolt of a secondary
  launch, the Echo repeat (`ModifierState.FLAG_SECONDARY` on `queue_repeat`), Double Slash's echoes (`queue_echoes`;
  the first echo: `PlayerKit.swing_arc` with `EFFECT_TWIN_ARC`, now also a repeat). A bolt carries it in
  `ProjectileStore.second` (bits `SECONDARY` 1, `REPEAT` 2; a lazy column: empty, unhashed, absent from older saves
  until the first such bolt). A secondary hit sets `World.hit_proc_permille` (transient; `Attacks._hit`, the projectile
  sweep) and its feeds scale: `Engines.on_hit`, `_landed`'s burn, `_feed`. A secondary's hook child launches at
  `proc_pct` × the proc (its statuses), and a `TAG_CAST` child at that share of its damage (`run_hook`); the child is
  not secondary itself. Stacks: rounded down, the remainder (per mille) carried in `ModifierState.sec_carry`.
- **Repeats never repeat.** `AttackSpec.recast` (`LATE_INT_FIELDS`): `WandCompile._cut` sets it on a trigger's n ≥ 1
  cast (×2 legendaries, a slash hit's second) and on everything built from it (`_hook`, `_cut`, `_layer`'s copy); a
  spec with it casts each trigger once. A repeat's context (`AttackContext.repeat`, not a back copy; inherited by its
  children, `FLAG_REPEAT` on its queued hooks, `ProjectileStore.REPEAT` on its bolts) never launches a hook whose child
  has `recast` (`run_hook`). The depth, lineage, `once_per_line`, 256-a-tick and shot caps are unchanged.
- **Rhythms.** `FireRhythm` returns an extra rate bonus counted into the attack's raw bonus
  (`ItemEffects.shot_period_ticks`, `BladeForms.step`). Rapid Fire: `ramp_permille` 100 × (streak − 1), at most
  `ramp_cap_permille` (600 +150), the streak reset after `ramp_reset_ticks` (24) without a shot
  (`PlayerKit._fire_bolt` → `on_shot`); base +300, radius × 0.7, damage × 0.85. Flurry: the first `burst_swings` (3;
  4 at level 3, 5 at level 5: per_level 0.5 from level 3, rounded) swings that start `burst_pause_ticks` (36) or more
  after the last swing ended come `burst_permille` (800) faster (`on_swing` at the swing's start, which records its
  end tick); damage × 0.85. State: `ModifierState.ramp_n`, `ramp_tick`, `burst_n`, `burst_free` (hashed only when
  set; `ADDED_SINCE_V05`). A whole-number op field without a unit keeps its `per_level` as is (`ModifierCompiler`), so
  ½ a level rounds per level.
- **Split Wave without Wave.** `ModifierDefinition.alt_target` / `ModifierOpDefinition.alt`: on a spec of the
  alt target (not of the target) with no hook child of the target yet, the card's `alt` ops run instead
  (`WandCompile.alt_reading`): a slash with no flying slash throws 2 crescents (+1) at 400 (+50) on each hit.
- **Placement flags.** `Wand.flags(read)`: `UI_WAND_DEAD_TRIGGER` for a card in `WandTable.after_trigger_dead`
  (`gun_echo`, `double_slash`, `gun_charge`) right of a trigger, `UI_WAND_DEAD_DEEP` past the third trigger. `describe`
  leaves the first out of its spell and lists them (`WAND_READ_DEAD`); `WandRow` dims the tile and shows the reason.

## 8l. Remnants, Dodge Imprint and Thermal Break (v0.8.0 RM)

Owner O91 ("Build reusable remnants, connections and events—not hardcoded modifier-pair scripts. Define inheritance,
lifetimes, hit intervals and activation limits"); spec [`../roadmap/v0.8.0/BALANCE_PASS.md`](../roadmap/v0.8.0/BALANCE_PASS.md)
"RM" and MR 4 (starting values); WAND.md rules 12–13. Evidence: [`../roadmap/v0.8.0/evidence/BALANCE_RM.md`](../roadmap/v0.8.0/evidence/BALANCE_RM.md).
- **Compile.** `ModifierOpDefinition.Op.REMNANT` (10) with the `remnant_*` fields → `ModifierOp.remnant`
  (`RemnantRule`: kind SEGMENT / ANCHOR / MARK / FRAGMENT, spawn LINK / CONTACT / HIT / PATH / NONE, activate
  ENEMY_CROSS / ATTACK_CROSS / PULL / TURN / FINISHER / DELAY / CONSUME, life, own cap, gap, charges, lengths, pull,
  bend, turn, delay, stacks, period, releases; `at_level` grows life, cap and stacks). `WandCompile.apply` builds it
  as a hook (the HOOK guards: depth, lineage, `once_per_line`; its child built by the card and the cards to its right)
  that carries the rule, the card's slot and trigger section (`section_of`: trigger cards left of it) and, on a
  FINISHER remnant, `extract` (the spec is the combo's finisher). A CONTACT or HIT remnant is an `ON_HIT` hook; a
  LINK, PATH or NONE one is `AttackSpec.Trigger.ON_REMNANT` (8, appended), which no moment fires. `AttackBook`
  indexes the remnant hooks by their child's key (`remnant_hook`) and lists the consumers. `AttackHook.hash_into`
  adds the rule, slot, section and extract only for a remnant hook; `AttackSpec.imprint_ticks` / `imprint_permille`
  are `LATE_INT_FIELDS`. A build without a remnant card compiles and hashes as before.
- **Left.** `Attacks.run_hook` hands a remnant hook to `Remnants.on_hook` (no launch): CONTACT, a crack of
  `length_m` along the attack's way centred on the hit (one per card per root a tick); HIT, an anchor at the hit
  (likewise), a mark on the enemy (its direction: from the attack's origin to the enemy, or the attack's way when it
  hit where it is), a fragment on the enemy (+1, at most `stack_max`, its life refreshed). LINK: `Attacks._bolts`
  marks each bolt it queues (`World.set_pending_link`, pending column 13); `World._apply_spawns` calls
  `Remnants.on_link`, which links the bolt to the last one marked with the same key within `link_ticks` (the thread's
  ends ride the two projectiles while they fly: `rem_target`, `rem_target2` are their ids). PATH: `Remnants.on_arc`
  (a slash: `ARC_CHORDS` chords at `PATH_REACH` of its reach, one path) and `on_bolt_end` (a bolt: the line it flew).
  Nothing is left by an attack at the deepest hook level or while the card's id is on `World.hook_chain`.
- **Inheritance.** A remnant stores its activation's level: depth + 1 and half the proc of the attack that left it
  (`rem_depth`, `rem_proc`), its root, its damage basis (that hit's base damage), its slot and section. Its cast is
  the remnant hook's child (a break or an extraction casts the hitting spec's own hook's child), launched through
  `Attacks.launch` with the card's id pushed on `hook_chain`; a DELAY cast is a repeat (`AttackContext.repeat`).
- **Limits** (`WandTable`, `data/wand/wand.tres`): each card's `max_alive`, `remnant_kind_max` per kind (48, 16, 48,
  48), `remnant_max` (96) in all: past a cap the oldest goes (`REMNANT_END`, `END_REPLACED`). `remnant_activations_max`
  (64) a tick, then one `LIMIT` event (`effect_id` `remnant_cap`, `amount` the cap); every cast also passes
  `Attacks._count` (256 launches a tick). A remnant's `gap_ticks` per enemy, per path (`rem_group`; `gap_*`); its
  charges (`-1`: until its life).
- **Tick phase 6** (`ModifierRuntime.advance`, after the launch queue, before the black holes): `Remnants.advance`
  ends the remnants past their life (`END_EXPIRED`), whose cast left the build or whose enemy is gone (`END_GONE`);
  threads and marks follow; then, in store order by uid: ENEMY_CROSS (each enemy touching the segment, its half
  width, takes the cast), ATTACK_CROSS by a player projectile of another root whose move this tick crosses it (a
  slash crosses in `on_arc`), PULL (enemies within `pull_radius_m` move `pull_step_m` toward it, not a boss, stopping
  0.3 m short; player projectiles within `bend_radius_m` turn `bend_step` toward it, an orbiting one excepted), DELAY
  (after `delay_ticks`, each enemy touching the path once, then spent); then the consumers: every `period_ticks` since
  the last release (`finale_tick`), the remnants of the consumer's section with a slot left of its own, oldest first,
  at most `release_max`, each releasing the consumer's cast at its basis where it is (`END_CONSUMED`). No randomness.
- **Events** (appended to `SimEvent.Kind`): `REMNANT_SPAWN` (effect = card, amount = kind), `REMNANT_ACTIVATE` (effect
  = card, amount = the cast's damage), `REMNANT_END` (effect = card, amount = `Remnants.END_*`).
- **Dodge Imprint** (`long_shadow`, same id): the dash spec's `imprint_ticks`; `Remnants.on_dash_start` keeps the start
  (`imprint_at`) until the dash's end + `imprint_ticks` (`imprint_until`); the next root weapon attack
  (`Attacks.launch`, depth 0, not a repeat or a back copy) launches from there at × `imprint_permille` and spends it
  (one `REMNANT_ACTIVATE`).
- **Thermal Break** (`Engines.thermal_break`, from `add_burn` and `add_frost`): an enemy with burn stacks and frost
  stacks or a freeze, whichever came second, inside `Engines.begin`: burn and frost (and a freeze) consumed, one
  `STATUS_APPLY` (`thermal_break`, amount = the burn stacks; the view's shatter), one `Damage.tick_dot` of
  `WandTable.thermal_base` + `thermal_per_burn` × stacks (6, 4: × the damage stat, TAG_DOT, proc 0). Fire and Frost
  from any source react; it never feeds a status, so it can't chain itself.
- **State, hash, saves.** `ModifierState.rem_*` (struct of arrays, oldest first), `gap_*`, `rem_act_tick` / `_n`,
  `link_*`, `finale_tick`, `imprint_at` / `_until`: copied by `WorldSnapshot`, listed in `ADDED_SINCE_V05` (an older
  save has none), hashed (`ModifierState._hash_remnants`) only once `remnants_touched()` (a remnant card acted), so no
  older digest moves. The view reads `WorldReader.remnants()` / `remnant_cast_radius` (`RemnantViews`, pooled).
- **Mutations.** Item tag `mutation`; `ItemDefinition.offer_weight_permille` (`ItemTable`; 1000 = as its tier)
  multiplies `ItemPool.card_weight`; a card under 1000 never fills the boss's legendary chance slot
  (`Offers.legendary_cards`). Double Exposure and Grand Finale: legendary tier, 150.

## 8m. Floor-paced loot (v0.8.0 FL)

Owner O91 ([`../roadmap/v0.8.0/BALANCE_PASS.md`](../roadmap/v0.8.0/BALANCE_PASS.md) "FL"); evidence
[`../roadmap/v0.8.0/evidence/BALANCE_FL.md`](../roadmap/v0.8.0/evidence/BALANCE_FL.md). `LootPacing` is the one rule
every card source draws through; `World.loot_pacing` (`LootPacingTable`, loadout, not hashed) holds the numbers, and a
world without it (labs, the older scenarios) draws exactly as before FL (no multiplier, ceiling 5, no guarantee and no
extra draw on `loot`).
- **Stage.** `LootPacing.stage`: `DEEP` on a Deep floor (`Routes.is_deep`) or any floor of loop ≥ 2, else
  `FLOOR_1..FLOOR_3` by `World.floor_index` (3 and past it: `FLOOR_3`). `next_stage` is one later, at most `DEEP`.
- **Categories.** `ItemTable.loot_category` (`LootPacing.Category`: OTHER, FORM, ELEMENT, ADVANCED, TRIGGER,
  MUTATION). Stat cards are their own category (an `Offers` STAT code) and keep their weights.
- **Weights.** `ItemPool.card_weight` ends × the stage's per-mille multiplier for the card's category
  (`LootPacing.weigh`, integer, rounded down; OTHER × 1). The events' mod draw (`Events._mod`) and an elite's core
  (`CoreTheft.draw_card`) weigh their mods the same way (their old weight × 1000 × the multiplier / 1000; the core's
  stat cards × 1000 so the ratio holds).
- **Ceiling.** `CardLevels.can_take(w, idx, ceiling = -1)`: a held wand card is takeable from a source only below
  `LootPacing.ceiling` (or the given ceiling, at most 5). So `ItemPool.available` (altars, chests, the shop's restock and
  reroll, events, cores, the boss's card) never offers a held card at the ceiling, and `Shop.can_apply` (buying, an
  event's block, a stolen core's re-check at its drop, which then redraws) refuses it. `CardLevels.level_up` itself has
  no ceiling: a jackpot and the boss's upgrade pass it. The dev panel's grant passes `MAX_LEVEL` (exempt).
- **Guarantee.** `Offers.roll` of a regular altar (not a chest, the shop, the epic or the boss's altar): while
  `World.loot_guaranteed` < the stage's `guaranteed_altars` it counts one, and an offer holding no `LootPacing.compatible`
  card has one card replaced (`_slot`: the last card, never an altar's leading fresh ability) by one drawn from
  `ItemPool.available` by the altar's weights (one `loot` draw). Compatible: a usable wand card of category form, element
  or advanced that would act where it lands (a new card at the wand's end, a held one where it sits): not past
  `WandCompile.MAX_DEPTH` triggers, not a `WandTable.after_trigger_dead` card right of a trigger.
- **Jackpot.** `Offers.roll` of a regular altar or a chest: one `loot` draw (0..999) against `jackpot_permille`; on a
  hit one card (`_slot`, never the only compatible card) becomes a jackpot card uniformly from `LootPacing.jackpot_pool`
  (a held wand card exactly at the ceiling, below 5, or a mutation; `ItemPool.available(w, true, ceiling + 1)`), one
  more draw. The pair (reward id, card) is appended to `World.loot_jackpots`; `WorldReader.choice_jackpot(k)` reads it
  and the pick card's line starts "Jackpot" (`PickPanel.jackpot_face`, `PICK_JACKPOT`).
- **The boss's altar** (`Offers.roll_legendary`, replacing the level-5 grant of §8i): the Legendary chance's draw as
  before; then with `LegendaryTable.upgrade` one held wand card below `LootPacing.next_ceiling`
  (`Offers.boss_upgrades`, uniform; taking it raises it one level as anywhere); then with `card_categories` (data
  advanced, trigger) and no Legendary card, one card of those categories from `ItemPool.available(w)` (weight 1000 × the
  stage's multiplier; never a Legendary card nor a mutation, so the ×2 triggers stay the chance's); the rest legendary
  stat cards (and `mods`) by the tier's weights as before. The loop's extra picks are unchanged.
- **State.** `World.loot_guaranteed` (hashed once above 0) and `World.loot_jackpots` (hashed once not empty) are per
  floor, in `WorldSnapshot.ADDED_SINCE_V05` (an older save: 0 and none). Economy unchanged: reward counts, prices and
  shards. The Overrun's ability cards and the Deep epic altar's ability level-ups and epic stat cards hold no wand card,
  so pacing does not reach them.

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
  from the walls; its last flood is copied, and v0.8.0 NF its last flood's work and a build in progress as
  `NavField.build_state()`: goal cell, bound, targets, budget, slices run; restore runs the same slices again, a save
  from before NF has none). Objects of a `LOADOUT_CLASSES` class are kept wherever they appear.
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
  the bound walks straight until it is back in reach. **v0.8.0 NF (owner O90, "A then"):** the periodic flood is
  built over `NavField.SLICES` (3) ticks into a back field (`begin_build` on the flood tick, `advance` that tick and
  the next two; slices before the last stop between buckets once the build's work, the cells taken from the buckets,
  reaches a third of the last flood's work, at least `SLICE_MIN`; the last finishes) and swapped in when done, so
  enemies follow a field up to 2 ticks older; the finished field and key equal `flood()`'s from the same goal and
  targets. Floods that follow a wall change stay at once and drop a build in progress: `add_wall_now`,
  `remove_wall_now`, `set_nav_extra`, and a field's first flood since its build.
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

## 10d. Dodge-first boss fights (v0.7.5 BF1; owner N15, [`BOSS_FIGHTS.md`](../design/BOSS_FIGHTS.md))

Starting values; `BulletPatterns`, `BossDodge` and `BossAi` hold the rules, `data/bullet_patterns` and
`data/bosses` the numbers.
- **Bullet patterns.** A `pattern` attack fires its `BulletPatternTable` over its active time from the boss's body
  (`BossDodge.resolve_pattern`, tick phase 6). On each wave tick (`BulletPatterns.wave_at`: the lob, then every
  `wave_gap_ticks`), `BulletPatterns.wave_shots(pattern, wave, origin, aim, origin_r)` gives the wave's spawn points
  and velocities: a pure function of its arguments (no stream is drawn; angles in 1/4096 turns through `Kin`, a
  flower's rose a `Kin.dir` lookup), so the shape a test or view computes is the shape fired. Kinds: ring (count,
  gaps, turn per wave), spiral (arms, spin, reverse), fan (count, spread, alternate offset), cross (arms, spin), wall
  (a marching line with a bouncing gap; crossing), flower (petal speeds, cut gaps) and burst (a lobbed shell that
  lands on the attack's locked target as a hurting disc, then a star). The aim is the attack's `lock_a`, tracked
  until it commits like any aimed attack.
- **Fair.** A shot whose spawn point is within `safe_radius_m` + the player's radius of the player, or touches a wall,
  is left out. Shots are ordinary hostile projectiles (`World.queue_projectile`, TAG_PROJECTILE, the attack's damage
  × the boss's power, no bounces), so they stop at walls and hit once. At most `MAX_SHOTS_PER_TICK` (160) are queued
  in a tick (`World.pending_projectiles`) and `MAX_ALIVE` (900) projectiles live; past either the wave's other shots
  are dropped with one `LIMIT` event (`effect_id` `bullet_cap`). Every shipped pattern keeps a gap the hero fits
  (the content validation and `test_bullet_patterns.gd`). One attack at a time per boss, so a pattern never starts
  while that boss's marker is locking.
- **Fireball looks.** Each shot carries its pattern's `look` (`ProjectileStore.look`, `WorldReader.projectile_look`;
  the column fills the first time a fireball flies and is hashed only then, so a world that never fired one hashes
  as before). An old save lacks it: none.
- **Tracked, then locked.** An attack with `lock_ticks` (from `lock_seconds`) aims at the player's exact position
  (`BossAi._target`, no lead and no dash read) and tracks until its windup's last `lock_ticks`, then holds. The
  `marks` and `row_lanes` moves lay `count` markers `mark_gap_ticks` apart: marker k starts at k × gap, sits on the
  player's position (BossStore points, set in phase 3 from the position before this tick's move) until
  k × gap + windup − lock, holds, and strikes once at k × gap + windup (active tick k × gap), where it locked
  (`BossDodge.mark_of`, `row_lanes_of`: one shape function each, drawn and hit alike). Each marker may hit (the
  hurt iframes still apply). A telegraph with a lock carries `tracked` and `locked` (the view: a dull outline, then a
  bright flash). Applied to the Gatekeeper's Fist Slam (1/2/3 circles by phase) and Shock Lanes (row and column) and
  the Warlord's Spear Lines (flood), Lunge (charge) and Javelin Rain (barrage); 0.8 s each. v0.7.5 BF3: the Siege
  Engine's Barrage (marks), Mortar Grid (grid) and Rail (lanes), the Foundry's Molten Flood (row_flood) and Firestorm
  (flood).
- **Shielded signature.** While a `shielded` attack winds up or runs (`BossDodge.shielded`,
  `WorldReader.boss_shielded`), a hit on the boss emits its `HIT` with `TAG_BLOCKED` and deals nothing; damage over
  time does nothing; the world's own hits (owner 0, the dev panel's Kill boss) pass. It opens between patterns (the
  Gatekeeper's Rock Rings and the Warlord's Shield Wall open the weak point when they end). The 66 / 33 % gates stay.
- **Reads for the views and avatars.** `WorldReader.boss_shielded(i)`, `boss_pattern(i)` (`{}` or id, kind, look,
  shielded, winding, progress), `projectile_look(i)`, `MOVE_PATTERN` / `MOVE_MARKS` / `MOVE_ROW_LANES`.
- **Big boss rooms (owner N18).** Every boss's room is 4 x 4 and its body 1.3x (data). `RunState.FLOOR_RULES` is 3;
  a floor resumed from a payload with rules 1 or 2 rebuilds its boss room at `legacy_arena_cells`
  (`RunState.legacy_boss_room`, `RunSaver.boss_arena`), so the snapshot fits the floor it was saved on.
- **Hashing.** The patterns and the lock add no state: markers use the BossStore points, patterns the attack's clock;
  only the fireballs' look column is new (above). The kernel replay golden is boss-free.
- **v0.7.5 BF2: eggs and a tracked burrow.** A `marks` attack with a pattern (the Brood Mother's Egg Storm) fires it
  from each circle as it strikes (`BossDodge.burst_mark`): `local` ticks after circle k struck, wave
  `wave_at(pattern, local + lob)` fires from the circle's centre, `egg_r` (half its radius) out, aimed at the
  player's position then (the pattern's aim offset puts the player in a gap), under the same fairness and caps. While
  a circle is locked its telegraph item carries `lob` (from the boss to the circle; the view's egg). A `burrow` with
  a lock (`BossDodge.tracked_burrow`) keeps BossStore point 0 on the player's exact position from its windup's end
  through `track_ticks` (the telegraph: a tracked `disc`), then locks it (`lock_x/y`), burrows to it at its speed while
  the circle is locked for `erupt_ticks`, erupts there (the disc), and fires its pattern from it over
  `BossDodge.eruption_ticks` before it finishes. No new state: the points, the lock and the attack's clock.
  The Hive Lens's Focus Beam is `lanes` with a lock (no new rule).
- **v0.7.5 BF2 fix: readable patterns and their recap.** A pattern attack's telegraph is its cast for its whole
  windup and firing (`BossDodge.cast_telegraph`: `{"shape": &"cast", "ground": false, "progress", "move", "look"}`;
  a burst's landing disc until it lands, then the cast). Nothing is drawn on the ground; the avatar poses from it. So
  every wave's shots come from a cast visible for at least the windup (>= `MIN_TELEGRAPH_TICKS`), which the
  readable-cause check reads. A boss's fireball carries the attack that fired it (`ProjectileStore.cause`, filled
  the first time a boss's fireball flies and hashed only then; -1 for others); a shot that kills the player sets
  `World.killer_attack` to it, so the recap names that pattern, not the boss's attack at the time of death.

## 10e. Enemy fireballs (v0.7.5 EF; owner N16, [`BOSS_FIGHTS.md`](../design/BOSS_FIGHTS.md) "Normal enemies")

Starting values in `data/bullet_patterns` (CONTENT_SCHEMA §3); `EnemyAi` holds the rules.
- **Who.** The Arc Caster's bolt and spread (a fan of 3 slow plasma balls, narrow and wide), the Lens Drone's attack
  (a ring of 6 orbs; it still flies the Needle's walk) and the Bomb Drone's bomb (a lobbed fireball that bursts into an
  X of 4). The Needle's burst, the Sniper's line, the melee kinds' attacks, the Arc Caster's rune, the Mine Layer and
  the Mender are unchanged. Elites of the three kinds (the Ambush Cache, Marked) fire the same patterns: an elite is
  its kind's AI.
- **How.** `EnemyAi.pattern_of(w, i)` is the pattern in play (`EnemyTable.patterns`: the Arc Caster's by its spell,
  the others' first; null otherwise). The windup aims as before (tracked, committing `ai_commit_ticks` before it
  fires), led at the pattern's own speed; the Bomb Drone's landing is the player's exact position (no lead), tracked
  the same way, its X turned to the throw (`lock_a`). In ACTIVE, `_resolve_pattern` (tick phase 6) fires each wave on
  `BulletPatterns.wave_at` ticks through `BulletPatterns.fire` (the caps, no spawn on the player or in a wall, shots
  stop at walls), from the body, or for the BURST from the landing point once it has flown `lob_ticks`, where the
  landing itself hurts within `land_radius_m` (TAG_AREA). ACTIVE lasts until the pattern's last wave. No stream is
  drawn by a pattern (the windup's length draw is the same as before).
- **Damage and scaling.** Each fireball (and the landing) deals the attack's `damage` (RunState's per-floor and loop
  scaling of `EnemyTable.damage`), powered by the danger tier and the hidden catch-up (`EnemyAi.powered`,
  `ActorStore.power`), as every enemy hit.
- **Nothing on the ground.** Their `telegraph()` is `{"shape": &"cast", "ground": false, "progress", "look"}` in the
  windup and, for the Bomb Drone in the air, `{"shape": &"lob", "ground": false, "from", "to", "progress", "look"}`.
  TelegraphViews draws no `ground: false` telegraph; the bodies' own windups (the caster's crystal, the drones' glow)
  and FireballViews' lobbed ball are the cues. The readable-cause check counts the windup (the shots then fly
  slowly on screen).
- **v0.8.0 TG (owner O4, Q3): the melee kinds, the Sniper and the Needle off the ground too.** Their telegraphs keep
  every field (shape, `obb` / `obbs` / `center` + `radius`, `progress`, `style`) and gain `"ground": false`: the
  Charger / Hatchling / Swarmer windup lane and running lane, the Splitter / Splitling disc, the Shield Bearer's
  `bash` lane, the Warden's slam disc, the Sniper's `snipe` line, the Needle's lanes. Only the Arc Caster's rune and
  the Mine Layer's mines stay on the ground among normal enemies. `telegraph()` is computed, never stored or hashed:
  no state, stream, golden or save changes.
- **Hashing.** No new state: the patterns use the actor's own clock and lock fields; the fireballs' look column
  (§10d) fills the first time one flies. `tests/golden` is unchanged (its replays have no Arc Caster, Lens Drone or
  Bomb Drone shot).
- **v0.7.5 BF3: the board, the molten rows and the rain.** `grid`: the board's centre (BossStore point 0) tracks the
  player's exact position like any locked attack and holds at windup − lock; volley k strikes once at active tick
  k × `mark_gap_ticks` on the circles of `BossDodge.grid_discs(w, i, k)` (the cells whose (x + y) parity is k's,
  centred cells' centres clear of walls; drawn and hit alike), each volley may hit; the telegraph (`&"marks"`, one
  disc item per circle) shows volley 0 for the whole windup and each later one only for its lock
  (`BossDodge.grid_state`). `row_flood`: `BossDodge.row_flood_of(w, i, k)` (lanes along x through point 0, offset
  `gap_m` in y, cut by walls) tracked then locked, then standing and burning like `flood` (`burn_ticks`). A raining
  flower (`BulletPatternTable.rain_ticks` > 0, also its `lob_ticks`): wave k's drops are thrown at active tick
  k × `wave_gap_ticks` and land (`fire()`, with its fairness rules: none on the player or in a wall) `rain_ticks`
  later at `wave_shots`' points, `rain_m` × the petal's share out from the body's edge; in the air they are only a
  read (`BossDodge.rain_drops`, `WorldReader.boss_rain(i)`: from, to, progress) and hurt nothing. No new state is
  hashed. `MOVE_GRID` / `MOVE_ROW_FLOOD` for the views.

## 10f. Boss signature mechanics (v0.8.0 BS1, BS2; owner O5, [`BOSS_SIGNATURES.md`](../roadmap/v0.8.0/BOSS_SIGNATURES.md) S1-S6)

Starting values in `data/bosses` (CONTENT_SCHEMA §4, the shape params below; all in the F10 Bosses page);
`BossSignatures` holds the rules. Pure: no stream is drawn.
- **S1, the Gatekeeper's pillars.** The tick after marker k of a `row_lanes` attack with `pillar_ticks` struck (tick
  phase 6; so the strike's own lanes, drawn and hit on its tick, are never cut by its pillars; the attack stays
  active a tick longer for its last cross), pillars (squares `pillar_m` a side, axis-aligned) rise along its two lanes every `pillar_step_m` out
  from the crossing each way (the crossing stays open), as far as each lane ran. A pillar rises only where it touches
  no living body (plus `BODY_MARGIN_M` 0.3) and keeps 2 × the player's radius + `PASS_SLACK_M` (0.15) from every
  wall, the door and every other pillar (`BossSignatures.fits`: the corners of both boxes and the inscribed circle).
  So each pillar is an island in the hero's free space: it never splits it, never closes a way, never seals anyone
  in. A pillar is a wall while it stands: `World.add_barrier` (collision, shots, sight, `EnemyAi.clear_run`), and the
  flow field goes round it through `NavField.set_extra` (its cells blocked on top of the walls' build, the flood
  rerun at once). It sinks on `pillar_until` (`BossSignatures.advance`, phase 6, before the projectile sweep):
  `World.remove_barriers`, the field reopened. Its boss gone, its pillars go. State: `BossStore.pillar_*` (centre,
  half side, the tick it rose and sinks, its boss), hashed only while any stands, besides the walls (hashed already).
- **S2, the Warlord's shield and javelins.** A boss whose `front_mult_permille` is 0 blocks every hit from its front
  arc (`Damage.target_mult`: `HIT` with `TAG_BLOCKED`, nothing applied; damage over time ignores armour as before);
  the Warlord's arc is 120° (±60°); its sides take ×1, its back (100°) ×1.25; while its weak point is open the shield
  is down (`weak_point_drops_armour`). A `pattern` attack with `recall_ticks`: each of its shots that ends on a wall or
  at its range (not on a body) sticks there (`BossSignatures.on_shot_end`, from `World._projectile_hits`, for a
  projectile with a cause): the point, the angle it flew, its boss and attack, the tick it stuck and the tick it
  flies back: the tick the attack's active time began + `recall_at` (the pattern's duration + its shots' life +
  `recall_ticks`), so every javelin of a throw flies back on one tick. Then (phase 6) each is queued as a hostile
  shot from where it stuck, back along the line it came (its angle + 180°), at the pattern's speed and radius, the
  attack's damage × the boss's power, living until the boss's edge; a javelin within the pattern's safe radius of the
  player crumbles instead (no shot spawns on top of you). The attack stays active until they are home
  (`recall_at` + the shots' life). State: `BossStore.jav_*`, hashed only while any stands.
- **S3, the Brood Mother's eggs.** A `marks` attack with `egg_ticks` doesn't burst at the landing: each circle as it
  strikes (after its hit) queues an egg (`World.queue_egg`), unless `max_alive` of `enemy_kind` are alive or coming
  (eggs count). In phase 9 the egg arrives as an actor of that kind (a Hatchling), scaled as any arrival, then made an
  egg (`BossSignatures.make_egg`): state `EGG` (7), HP `egg_hp` at the kind's base HP (scaled as its own HP was),
  hittable at once, still (no walk, no attack); its EnemyAi fields hold its ticks (`windup`), the HP it hatches with
  (`pick`) and the attack that laid it (`lock_a`). In phase 3 (`EnemyAi.think`, after its clock): its boss gone, it
  crumbles; its time up, it hatches (its kind's HP, state SPAWN, the spawn-in) or, from its boss's phase
  `burst_phase` on, bursts (`EGG_BURST`, 8): its attack's pattern fires from where it lies over the pattern's waves
  (phase 6, `EnemyAi.resolve`), aimed at the player, through `BulletPatterns.fire` (the fairness and caps), then it is
  gone. A crumbled or burst egg leaves with state `EGG_GONE` (9): no kill, no shards, no heal orb
  (`World._remove_dead`). A broken egg is a kill like any. No new hashed fields: the actor columns.
- **Readable cause.** A returning javelin or an egg's burst carries `BossSignatures.LATE_CAUSE` (4096) + its attack as
  its cause (`ProjectileStore.cause`); the recap reads that attack's `late_cause_key` (`CAUSE_WARLORD_RECALL`,
  `CAUSE_BROOD_EGG_BURST`). `BulletPatterns.fire` takes an explicit cause for it.
- **Reads.** `WorldReader.boss_pillars()`, `boss_javelins(i)`, `boss_recall_permille(i)`, `actor_egg_permille(i)`,
  `STATE_EGG` / `STATE_EGG_BURST`.
- **Saves.** The new `BossStore` lists are in `WorldSnapshot.ADDED_SINCE_V05` (an older save has none). A snapshot with
  pillars standing restores them as walls the way play added them (the door first, then the barriers and pillars:
  only the wall grid is rebuilt, never the flow field) and sets the field's extra cells again before its last flood
  is copied, so a restored fight steps exactly as the uninterrupted one (`test_boss_signatures.gd`).
- **S4, the Hive Lens's Gaze (v0.8.0 BS2; `BossGaze`).** A new move, `gaze` (`BossAttackTable.Move.GAZE`, appended).
  As its windup begins the beam's start angle is the angle to the player + 2048 (straight away; `actors.lock_a`) and
  the ai stream picks the way it will turn (`BossStore.span`, ±1); every windup tick the start re-aims straight away
  from the player, so on its first active tick the beam points away from where the player stands (it never starts
  on you). Active tick `st`: its angle is `lock_a + way × along × 1024 / quarter_ticks` with `along` a triangle wave
  of period `reverse_ticks` (`st % reverse` out, then back: integer maths), so it turns a quarter turn every
  `quarter_ticks` and reverses every `reverse_ticks`. The beam is a lane from the boss's edge along that angle, as
  long as `length_m` unless `EnemyAi.clear_run` (radius `half_width_m`) stops it on a wall (walls, pillars, the
  door); it hurts a player it touches once every `burn_ticks` (`BossStore.hit` resets on each burn tick; the hurt
  iframes apply). Its `pattern` (the orbs) fires again every `orb_every_ticks` from that tick on, from the body,
  aimed at the player through `BulletPatterns.fire`, carrying `LATE_CAUSE` + the attack (the recap reads its
  `late_cause_key`). The boss faces along the beam. No new state: the actor's lock and `BossStore.span`.
- **S5, the Siege Engine's ricochets (BS2; `BossRicochet`).** A `pattern` attack with `bounces` (1) queues its shots
  with that many wall bounces (`World.set_pending_bounces`); a `deploy` attack with `bounce_phase` makes the shots of
  turrets of its `enemy_kind`, from that phase index on (the live boss's), bounce once too, carrying that attack as
  their cause (`EnemyAi` after a turret's shot). The bounce is the projectile sweep's own (`World._projectile_hits`,
  `ItemEffects.bounce`: reflected on the face normal of the wall hit, `v − 2(v·n)n`, an exact component flip for
  axis-aligned walls). Fair: a hostile shot does not bounce when its reflected path over `SAFE_TICKS` (30, 0.5 s)
  would touch the player (`BossRicochet.may_bounce`, a swept circle); it breaks on the wall instead. After a bounce
  its cause becomes `LATE_CAUSE` + its attack (the recap names the ricochet; a turret's resolves through the live
  boss's table). Bounces are the existing `ProjectileStore.bounces` column: no new state.
- **S6, the Foundry's lava and meltdown (BS2; `BossLava`).** A `row_flood` attack with `lava_ticks`: on its last
  standing tick (phase 6) each lane is cut by fords `ford_m` wide (at the boss's x, and where the line from the
  room's centre to its exit crosses the lane, or the exit's x) and the pieces stay molten from the next tick for
  `lava_ticks`, but only if `BossLava.fair` passes: with all molten floor down, a flood over the flow field's free
  cells that keep the hero's radius from it, inside the room, joins the boss's edge to the player (within their
  radius + 1.6 m) and to the exit (the boss door's inside, `FloorLayout.boss_door_inside(1.0)`; a room without one
  checks the boss and the player only). Otherwise none of it is laid. A `melt` attack (`Move.MELT`) on its first
  active tick melts the room for good (one meltdown per boss): beyond `r0` = the room's inscribed radius −
  `melt_ring_m` (24 m − ring without a room) from its centre (the sealed boss room's, or the boss's spot); every
  `melt_step_ticks` the radius drops `melt_step_m`, never under `melt_min_m`; a bridge `ford_m` wide from the centre
  to the exit stays cool. Each step glows `melt_warn_ticks` before it (`BossLava.melt_warn`; the attack's windup is
  the first ring's glow). Molten floor under the player's centre burns (phase 6, `BossLava.advance`, one clock
  `BossStore.burn_cd`): lava `lava_damage` every `lava_burn_ticks` (cause `LATE_CAUSE` + its attack), the melt its
  attack's `damage` every `burn_ticks` (cause its attack), as `Damage.tick_dot` × the boss's power. The flow field
  goes round both (`NavField.set_extra` boxes + melt shapes, `BossSignatures.set_nav_extra`), refreshed when lava is
  laid or cools and when a melt steps in. While its melt stands the Foundry keeps to cool ground (its centre its
  radius inside the edge, `BossLava.keep_on_ground` after it walks). Its boss gone, its lava and melt go. State:
  `BossStore.lava_*`, `melt_*`, `burn_cd` (hashed only while any is down; in `ADDED_SINCE_V05`).
- **Reads (BS2).** `WorldReader.boss_gaze(i)`, `boss_lava()`, `boss_melts()`, `MOVE_GAZE`, `MOVE_MELT`, `TEAM_ENEMY`;
  `BossAi.telegraph` draws nothing on the ground for `gaze` and `melt` (`"ground": false`).

## 10g. The final boss's Prism (v0.8.0 FB2; owner O17, [`FINAL_BOSS.md`](../roadmap/v0.8.0/FINAL_BOSS.md) F5, F7)

- **The body (`BossPrism`).** A body whose table has a `cross` attack floats: it glides to the fight's centre
  (`FinalFight.home`, where the first body rose) at its speed in every state but its rise, a gate and the shatter, and
  never pursues. Its shards (`BossTable.shard_count`, `shard_orbit_m`, `shard_turn_milli`) are points
  `shard_pos(k, tick)` on a ring round it, turning with the world's tick (no state); they are what fires.
- **The Cross (`cross`, `BossAttackTable.Move.CROSS`, appended).** `count` beams in a plus from her edge
  (`EnemyAi.clear_run`: stopped by walls), one shape function (`beam_at`), drawn and hit alike. The windup (the
  spin-up) re-aims the arms every tick to `aim + 2048 / count` (the player midway between two arms; never on one).
  `_lock` sets the way (`BossStore.span`: the opposite of her last Cross's; the first one's from the ai stream) and the
  quarter `q = fast + (slow − fast) × hp / max_hp` (integer, stored in point 7). Arm 0's angle `st` ticks into the
  spin is the Gaze's triangle wave (`lock_a + span × along × 1024 / q`, reversing every `reverse_ticks`). For
  `spin_ticks` a beam touching the player hurts once per `burn_ticks` window; the rest of the active time is the
  window. `BossDodge.shielded` is true through the windup and the spin and false in the window (and in the two
  ticks of recovery and choice after it): the Prism can be hurt only then.
- **Orbs.** While the beams turn, from `orb_every_ticks` on, volley `v` fires the attack's pattern from shard
  `v % shards` (each wave aimed at the player from the shard), through `BulletPatterns.fire` (its fairness and caps),
  carrying `BossSignatures.LATE_CAUSE + attack` (the recap's orb line).
- **Fast bolts.** Every `bolt_every_ticks` over the whole active time (spin and window), shard `(st / every) % shards`
  locks an aim line (its place in point 0, its angle and start tick in point 1) at the player's position; after the
  bolt attack's `lock_ticks` (0.4 s) a bolt flies down it (that attack's speed, radius, range and damage, look
  `crown_bolt`, cause = that attack). It doesn't track; none fires while the player is within 1.0 m (+ radius) of the
  shard.
- **The HP from the measured DPS (owner F7).** `FinalFight` holds a meter: a ring of 60 one-second buckets of the
  damage the player dealt (`Damage._apply`: `scaled`, the hit's damage before the HP and gate clamps, any target but
  the player) while the fight is measured (`FinalBoss.measuring`: not won, the player alive, the body neither rising,
  gated nor shattering, and not itself a `dps_hp` body). As a `dps_hp` body rises (`FinalBoss._spawn`) its HP is set:
  with `n` = min(its `dps_seconds`, the seconds closed) ≥ `dps_min_seconds`,
  `hp = Σ(last n seconds) × dps_target_ticks × window_permille / (n × 60 × 1000)`, else its table's `hp`; clamped to
  `dps_hp_min..dps_hp_max`. `window_permille` (compiled) is Σ window / Σ (windup + active + recovery + cooldown) over
  its Crosses. Integer maths: the same meter gives the same HP. Loops and the hidden catch-up don't change it (their
  damage scaling still applies).
- **State and saves.** `FinalFight.home`, `dps_secs`, `dps_head`, `dps_closed`, `dps_acc`, `dps_t` are hashed with the
  fight and listed in `WorldSnapshot.ADDED_SINCE_V05` (an FB1 save restores with a fresh meter and the centre).
- **Reads (FB2).** `WorldReader.boss_cross(i)` (`BossPrism.state`: winding, window, progress, arms, angle,
  half_width, way, quarter, speed, bolt; FB2's orb_shard is gone with the Cross's orbs, PR), `boss_shards(i)`,
  `final_dps(seconds)`, `MOVE_CROSS`. `BossAi.telegraph` draws nothing on the ground for `cross` (`"ground": false`).
- **One spell at a time (v0.8.0 PR, owner O84).** Supersedes "Orbs" above and the bolts' "whole active time":
  - **The rotation.** A body with `BossTable.rotation` (`FinalBossDefinition.spell_rotation`) never draws its next
    attack: in MOVE with no cooldown left, `BossPrism.next_spell` takes the attack after `BossStore.last_attack` in
    the phase's list (the first when none), and waits (-1) while any shot it fired is in the air or queued
    (`BossPrism.shots_alive`: projectiles whose owner is its id, plus `World.pending_projectiles_of`). The Prism's
    list: `cross_ring`, `crown_ring`, `cross_spiral`, `crown_spiral`, `cross_flower`, `crown_flower`.
  - **A Cross fires no orbs** (validation: no `pattern_id` on a `cross`). Its bolts start only in the window:
    `BOLT_LEAD_TICKS` (18) after the spin ends, then every `bolt_every_ticks`, while one can still fire before the
    active time ends (`BossPrism.bolt_starting`; the shard is the bolt's order in the window % shards).
  - **The orb spells** are `pattern` attacks with `BossAttackTable.fixed_aim` (shape param `aim_degrees`): `_lock` sets
    `lock_a` to it, so every wave fires from her centre at that angle plus the pattern's own turn, wherever the player
    is. In a rotation body an orb spell's active time is at least its pattern's duration plus its shots' life
    (`FinalBodyCompiler`), so she is shielded until its last orb is gone.
  - So: no shot of hers is in the air while a beam is aimed (the windup) or burning (the spin); orbs fly only in an orb
    spell and never with a bolt. `window_permille` for a rotation body is the open part of one rotation (each Cross's
    window, every recovery and cooldown, the active time of an attack that isn't shielded) over its length.

## 10h. The final boss's Nemesis (v0.8.0 FB3; owner F6 "Weapon + dash + 2-3 cards", F7, [`FINAL_BOSS.md`](../roadmap/v0.8.0/FINAL_BOSS.md))

- **A mimic body (`BossTable.mimic`; `BossNemesis`, `NemesisBuild`).** As it rises (`FinalBoss._spawn`) the fight
  reads the build once (`NemesisBuild.prepare`) into `FinalFight`: the run's weapon (a Gun without the Blade is the
  Gun, anything else the Blade), its hit and cap, a Blade run's combo arcs (`Modifiers.step(k)`: `half_arc`,
  `Attacks.arc_reach_m`, clamped), its ranged form (`shot`: a Gun run's `Modifiers.bolt` as a volley; a Blade run's
  thrown crescents when the wand throws any) and the hostile copies of the strongest cards (`casts`). A card taken
  later changes nothing mid-duel. An FB2 save (no mimic state) reads it at the Nemesis's next tick (`ready` false),
  its HP as saved.
- **The record (tick phase 9).** While a mimic body fights (not shattering), `FinalBoss.advance` calls
  `BossNemesis.record`: the player's position into the echo ring (`ECHO_MAX` = 120 ticks) and, on the tick a dash
  begins (`dash_ticks_left == dash_ticks`), `dash_due = tick + dash_react_ticks` and its unit direction.
- **The dash (phase 3 and 5).** On `dash_due` the Nemesis dashes if it is free (MOVE or RECOVER, not dashing): the
  player's own dash (`dash_distance_m / dash_ticks` a tick for `dash_ticks`, `dash_iframe_ticks` invulnerable), the
  player's way, the opposite way in the mirror stance; a due dash in any other state is dropped. It never hurts; no
  attack starts while it dashes; a stagger, gate or shatter ends it. One `STATUS_APPLY` (`nemesis_dash`).
- **The stance (phase 3 and 5, MOVE only).** `ECHO` walks to `echo_at(echo_ticks)` (the player's place that many ticks
  ago), `MIRROR` to `home × 2 − player`, `CLOSE` to the player, `BACK` to `back_off_m` from the player away from it;
  at its speed (`EnemyAi.steer`), stopping 0.3 m short. Every `stance_ticks` in MOVE a new stance is drawn from the
  ai stream (`pick_weighted(stance_weights)`); a finished `mimic_combo` sets `BACK`.
- **The moves (appended: `MIMIC_COMBO`, `MIMIC_SHOTS`, `CARD_CAST`).** The pick (`BossAi._choose`) leaves out an attack
  whose `weapon` isn't the run's and a `card_cast` whose `card` the build doesn't hold. Each tracks the player
  (aim and place; a card's blast point, BossStore point 0) until its last `lock_ticks`, then holds.
  - `mimic_combo`: swing k lands at `windup + k × mark_gap_ticks` (k < `count`), the player's combo step `k mod n`'s
    arc where it locked; each swing follows (stepping in at the attack's speed) until `lock_ticks` before it lands.
  - `mimic_shots`: volley v at active tick `v × gap_ticks` (v < `volleys`) of `FinalFight.shot` (or `count` crescents
    `spread` apart), down the locked aim, from the locked place.
  - `card_cast`: on its first active tick its volley and its blast (a disc of `blast_m` on the locked point); its arc at
    active ticks `k × mark_gap_ticks` (k < `arc_strikes`).
- **Hostile copies (`NemesisCast`).** Card `c` at level `l` is compiled alone on the run's weapon
  (`WandCompile.for_world(w, [its modifiers at l]).spec(base_bolt or base_step(0))`) and copied: an ARC root → an arc
  (`half_arc`, reach clamped to `reach_max_m`, 1 + min(repeats, 2) strikes); a BOLT root → a volley (`count × (1 +
  twin)` ≤ `shots_max`, `spread`, a ring for `directions = circle`, a back shot for `back_permille`; speed and radius
  clamped; flight ≤ `shot_range_m`); first-level hooks only: a BOLT child → the thrown volley (an ARC root) or splits
  fanned from each shot (a BOLT root; total ≤ `shots_max`); a BURST, ZONE, RING or LOB child → the blast (radius
  clamped). Deeper hooks and trigger cuts are never copied: a hostile shot runs no spec (`spec_key` ""), so nothing
  splits, explodes or casts again (BL's once-per-line, PF2's cast-free). Damage weight: `spec.damage × 1000 /
  base.damage`, 500..2000.
- **Fair.** No volley shot is queued within 1.0 m (+ the player's radius) of the player or in a wall; each goes
  through `BulletPatterns.room` (160 a tick, 900 alive; past it one `LIMIT` `bullet_cap`). Looks: `nemesis_bolt`,
  `nemesis_crescent`; each shot carries its attack (the recap's line).
- **HP and damage from the build (owner F7).** `hp = max_hp × build_hp_permille / 1000 + (with n ≥ dps_min_seconds
  measured of the last dps_seconds) Σ damage × dps_target_ticks / (n × 60)`, clamped to `dps_hp_min..dps_hp_max`
  (the meter of §10g; integer maths). `cap = max(1, max_hp × damage_cap_permille / 1000)` (< 1000: never a
  one-shot); `hit = min(max(weapon_damage × build_damage_permille / 1000, damage_min), cap)` with
  `Modifiers.weapon_damage`; an attack deals `hit × damage / 100 × weight / 1000`, clamped to 1..cap. Loops
  (`RunState.scale_bosses` skips a mimic table) and the hidden catch-up don't scale it: the build carries them.
- **State and saves.** `FinalFight.ready`, `weapon`, `hit`, `hit_cap`, `combo_half`, `combo_reach`, `shot`, `casts`
  (`NemesisCast`, a state class), `echo_x`, `echo_y`, `echo_head`, `echo_n`, `dash_due`, `dash_dir`, `dash_t`,
  `dash_vel`, `stance`, `stance_t`: hashed once a mimic body has fought (an earlier fight hashes as before) and listed
  in `WorldSnapshot.ADDED_SINCE_V05`.
- **Reads (FB3).** `WorldReader.nemesis(i)` (`BossNemesis.state`: weapon, stance, dashing, dash_dir, echo, mirror,
  hit, hit_cap, cards, casting, cast_progress), `MOVE_MIMIC_COMBO`, `MOVE_MIMIC_SHOTS`, `MOVE_CARD_CAST`,
  `STANCE_*`, `EFFECT_NEMESIS_DASH`, `EFFECT_NEMESIS_CAST`. `BossAi.telegraph`: a swing as an `&"arc"` (tracked,
  locked, striking), a volley's lines as `&"lanes"`, a card as `&"marks"` (items: `&"arc"`, `&"lanes"`, `&"disc"`;
  `card`, `card_index`, `striking`, `strike_items`). `BossAi.cause_key` moved to `BossCauses.key` (unchanged rules).


## 10i. The final boss's pace and The Fallen's windows (v0.8.0 N2; owner O41, O42, O52, [`FINAL_BOSS.md`](../roadmap/v0.8.0/FINAL_BOSS.md) "N2")

Supersedes §10g's HP formula (for a paced body), §10h's "HP and damage from the build" (The Fallen is paced; its hits
below) and FB3's cap of a fifth of max HP (D36).
- **The pace (`FinalPace`, `BossTable.pace`).** `dps_milli = Σ damage × 1000 / n` over the meter's last
  `dps_seconds` (n ≥ `dps_min_seconds`, else 0). `time = clamp(pace_ref_ticks × isqrt(pace_ref_dps × 10⁹ / dps_milli)
  / 1000, pace_min_ticks, pace_max_ticks)`; `hp = clamp(dps_milli × time × window_permille / (60 × 10⁶), dps_hp_min,
  dps_hp_max)` (`CatchUp.isqrt`, 64-bit ints). Set in `FinalBoss._spawn` (`FinalPace.rise`) when the meter holds
  enough, else in tick phase 9 (`FinalPace.advance`) the first tick it does; `hp` keeps its fill (`hp × fill / 1000`,
  at least 1). `FinalFight.paced`, `pace_dps` record it. `FinalBoss.dps_hp_of` returns it for a paced table.
- **The rate cap.** Tick phase 9, each tick a paced body is not rising, shattering or dead: `pace_budget +=
  rate = max(1, max_hp × 1000 / pace_min_ticks)`, at most `rate × pace_burst_ticks`. `Damage._apply` →
  `BossGates.clamp_damage` → `FinalBoss.clamp_damage(…, owner_id)`: the 1-HP floor of a body before the last, then
  `FinalPace.cap_hit`: owner 0 (the world's own hit) passes; else, in a mimic window, `× nerf_permille`; then
  `min(amount, pace_budget / 1000)`, paid from the bucket. The meter (§10g `note_damage`) still records the hit's
  damage before the clamp.
- **The Fallen's windows (`BossTable.window_ticks` > 0).** `u = tick − phase_tick − boss_intro_ticks −
  window_first_ticks + window_warn_ticks`; OFF for u < 0; else `c = u mod window_every_ticks`: WARN for c <
  `window_warn_ticks`, ON for c < warn + `window_ticks`, else OFF; OFF while shattering, rising, dead or won. No state
  of its own (a function of the tick and the rise). One `STATUS_APPLY` on the tick each state begins (`fallen_warn`,
  `fallen_open`, `fallen_close`; amount = the state).
- **In a window** (`FinalPace.copies`): `BossNemesis.allowed` keeps §10h's rule (the run's weapon, the cards held)
  and leaves out `weapon = own`; a due dash is answered; stances are drawn from all four weights. `BossNemesis.lock`
  sets `FinalFight.copying` at each attack's start, kept to its end: a copying combo swings the player's steps, a
  copying `mimic_shots` fires `FinalFight.shot`, a card is cast only while copying. The player: `nerf_permille =
  clamp(pace_ref_dps × 10⁶ / pace_dps, nerf_min_permille, 1000)` on their hits on it; `Stats.move_permille` at most
  1000 (`FinalPace.move_cap`).
- **Outside a window:** every non-card attack may be picked (whatever the run's weapon; `weapon = own` too), no card,
  no dash answer, stances only CLOSE and BACK; combos swing the attack's own arc, shots are the attack's own crescents.
- **Its hits.** `NemesisBuild.damage_of(w, atk, weight)`: `own = max(1, max_hp × atk.damage / 100)` (the data's
  `damage` is a per cent of the player's max HP, by `hit_class`); not copying → `min(own, cap)`; copying →
  `clamp(max(own, hit × weight / 1000), 1, cap)`, `cap = max_hp × damage_cap_permille / 1000` (500).
- **State and saves.** `FinalFight.paced`, `pace_dps`, `pace_budget`, `copying`: hashed with the fight (always, after
  the meter) and listed in `WorldSnapshot.ADDED_SINCE_V05` (an older save: unpaced, an empty bucket).
- **Reads (N2).** `WorldReader.final_pace()` (`FinalPace.state` + `capped`: paced, dps, seconds, budget, capped,
  window, window_left, window_len, nerf, copying), `WorldReader.fallen_window()`, `FALLEN_OFF`, `FALLEN_WARN`,
  `FALLEN_ON`.

## 10j. The Tidecaller's Pull and Undertow (v0.9.0 NB1; owner Q24, [`BOSSES_4_5.md`](../roadmap/v0.9.0/BOSSES_4_5.md) N1)

- **Kind.** `ActorStore.Kind.TIDECALLER` (appended), a boss kind (`BossAi.is_boss_kind`); floor 4's pool
  (`data/boss_pools/floor_4.tres`).
- **The Pull (`tide` move, `BossTide`).** Shielded. Windup (the bell), then an active time of `tide_pull_ticks` +
  `tide_push_ticks`. In tick phase 5 (`BossAi.move`, after the player's own step, before walls resolve) the player is
  moved by `drift_of`: toward the boss at `tide_pull` per tick in the pull, away at `tide_push` in the push, each capped
  at `BossSchemas.TIDE_MAX_MPS` (1.5 m/s) / 60; the pull stops `BODY_GAP_M` short of the body; none while dashing or
  dead. **Wall rule (`shift`):** a step is taken only if it doesn't press the player deeper toward a wall: `press(p)`
  is the deepest penetration of a circle of the player's radius + `WALL_MARGIN_M` (0.6 m) into any wall; the whole
  step, else its x part, else its y part, is taken when its `press` is 0 or no more than now, else none (so never into
  a corner, never pinned on a wall). In the pull every live shot of the boss turns toward it by `tide_bend` (1/4096
  turns a tick, `Kin.turn_toward`, speed kept). Its pattern fires (`BossDodge.resolve_pattern`) only while
  `state_t < tide_pull_ticks`; none in the push (content: the pattern's duration is under the pull).
- **Cadence.** `BossTable.sig_every_ticks` > 0: in MOVE with no cooldown, `BossTide.due` starts the phase's first
  `tide` attack once `tick >= due`; `on_start` (any `tide` start, a phase's entry too) sets `due = tick +
  sig_every_ticks`; the first is `sig_first_ticks` after the boss's first think in MOVE. The weighted pick leaves cadence
  attacks out. State: `BossStore.sig_boss` / `sig_due` (lists, one entry per such boss, removed when it dies), hashed
  after a `-2` sentinel only while non-empty; `WorldSnapshot.ADDED_SINCE_V05` (an older save has none).
- **The Undertow.** A `marks` attack with `drag_m` > 0: when a circle strikes, a player within `drag_reach_m` of its
  centre is moved `min(drag_m, distance)` toward it by the same wall rule (not while dashing).
- **Reads.** `WorldReader.boss_tide(i)` (`BossTide.state`: phase `TIDE_NONE` / `TIDE_PULL` / `TIDE_PUSH`, windup,
  progress ‰, speed m/s, centre), `KIND_TIDECALLER`, `MOVE_TIDE`, `TIDE_MAX_MPS`.

## 10k. The Twin Wardens: one boss in two bodies (v0.9.0 NB2; owner Q24, [`BOSSES_4_5.md`](../roadmap/v0.9.0/BOSSES_4_5.md) N2)

- **Kinds.** `TWIN_WARDEN` (the amber body: the boss) and `TWIN_WARDEN_VIOLET` (its twin), appended after `CONDUIT`;
  both boss kinds (`BossTwin.is_twin_kind`). Floor 4's pool holds the Tidecaller and the Wardens (`twin_wardens`,
  `save_order` 2: compiled after the Tidecaller, every saved boss index unchanged).
- **Two linked actors (`BossTwin`).** `World.spawn_boss` makes the boss; `BossTwin.on_spawn` adds its twin
  (`BossTable.twin_kind`) `twin_m` to the side (the first clear side, at least `chain_min_m` away) with the boss's HP,
  max HP, `power`, intro invulnerability and freeze immunity, a `BossStore` entry of the same table, and the pair in
  `BossStore.twin_*` (`twin_lead`, `twin_body`, `twin_angry`, `twin_anger_t`, `twin_burn_cd`; hashed after a `-3`
  sentinel only while non-empty; `WorldSnapshot.ADDED_SINCE_V05`). Each body runs the boss framework (windup, markers,
  shield, its own stagger meter); the boss is the bar (`WorldReader.boss_index`, the first live boss), `World.boss_id`,
  the codex's fight, the only `BOSS_DEFEATED`, reward, kill count and legendary core (`BossTwin.leaves` in
  `World._remove_dead`: the twin's entry goes with no defeat, shards, kill or core); only the boss's gate brings adds.
  `World.boss_table_of_kind` answers the twin's kind with its boss's table (the death recap).
- **One HP.** `Damage._apply` → `share_hp`: after a body's HP changes the twin's equals it (so both cross the 66 % and
  33 % gates on the same think); `fall_together`: a body killed kills the other at once with its own `KILL` (the same
  hit's child, no on-kill procs).
- **One mind.** The twin never picks (`BossTwin.think` returns early for it in MOVE, turning it to the player); when
  the boss starts attack k (`BossAi.start_attack` → `on_start`) the twin starts k the same tick if it is in MOVE.
- **Steps (`BossTwin.moves`, phase 5).** The boss pursues as any boss; the twin walks to its flank, `flank_m` from the
  player at a right angle from its boss on its own side; each × `anger_permille` / 1000 while angry; in a Chain Sweep
  the twin swings to the line's end at `SWING_MULT` (4) × its speed. **Chain length (`_tether`)**, after the steps
  and again in phase 6 (after walls and bodies push): the twin is put at `clamp(d, chain_min_m, chain_max_m)` along the
  line from its boss; if a wall stands there the boss gives way along the line instead, else both share the move.
- **The chain's burn (phase 6, the boss's resolve).** A player whose centre is within `player.radius_m +
  chain_half_m` of the segment between the two centres takes `chain_burn` (× catch-up power) as damage over time
  (`Damage.tick_dot`, effect `twin_chain`; hurt iframes apply) when `twin_burn_cd` is 0, which then becomes
  `chain_burn_ticks` (counted down in the boss's think, so the hit-stop pauses it). Never while dashing, never while
  `BossTide.press(p) > 0` (against a wall: it can't pin the player), never while either body rises or is in a gate,
  never while the boss's Chain Sweep runs (`lifted`). The chain is not solid. A kill by it names the first
  `chain_sweep` attack's late cause (`LATE_CAUSE + k`, its `late_cause_key`).
- **Anger.** `Damage._apply` → `on_hit` (non-DoT, applied > 0, from the player): the other body is angry for
  `anger_ticks` (`twin_angry` its id, `twin_anger_t`); one at a time; `STATUS_APPLY` (effect `twin_anger`) when it
  turns.
- **Crossfire (`crossfire`, shielded).** On start the safe spot `S` = the chain's midpoint + `distance_m` along the
  chain's normal toward the player (0.75, then 0.5 of it if a wall stands there), stored as each body's `pt(b, 0)`;
  each body's `lock_a` aims at `S`. Each wave of its pattern (a fan centred on `S`) leaves out every shot whose heading
  is within `angle_of(Vector2(|S − body|, gap_m))` of `lock_a` (`BulletPatterns.fire`'s `gap`), so the two gaps cross
  only at `S`; the twin's shots take `twin_look`.
- **Chain Sweep (`chain_sweep`, locked).** Through the windup until its last `lock_ticks` the boss's line tracks:
  `lock_a` = the angle to the player, `lock_len` = `clamp(dist + reach_m, chain_min_m, chain_max_m)` cut by
  `EnemyAi.clear_run`; on its first active tick a player touching the lane (`AttackShapes.lane` from the boss's lock
  point, `half_width_m`) is hit once (`hit_player`). The twin's copy draws and strikes nothing.
- **Reads.** `WorldReader.boss_twin(i)` (`BossTwin.state`: lead, partner, angry, anger ‰, chain ends, hot, lifted,
  burned; Crossfire's safe spot, gap lane, progress, firing; the Chain Sweep's from, to, half width, locked, progress,
  struck), `KIND_TWIN_WARDEN`, `KIND_TWIN_WARDEN_VIOLET`, `MOVE_CROSSFIRE`, `MOVE_CHAIN_SWEEP`, `EFFECT_TWIN_ANGER`,
  `EFFECT_TWIN_CHAIN`.

## 10l. The Clockwork Judge: your echo (v0.9.0 NB3; owner Q24, [`BOSSES_4_5.md`](../roadmap/v0.9.0/BOSSES_4_5.md) N3)

- **Kind.** `CLOCKWORK_JUDGE`, appended after `TWIN_WARDEN_VIOLET`; a boss kind. Floor 5's pool
  (`data/boss_pools/floor_5.tres`) holds the Judge only until NB4 adds the Lantern Shade (`clockwork_judge`,
  `save_order` 3: compiled after the Wardens, every saved boss index unchanged).
- **The recording (`BossJudge.record`, tick phase 3, every live boss).** A boss whose table has `echo_points` > 0
  (compiled from its first `echo` attack: `record_seconds` / `step_seconds`, 12 = 3.0 / 0.25) owns the echo
  (`BossStore.echo_boss`, its actor id; the first Judge to think, one at a time) and, on every tick that is a multiple
  of `echo_gap_ticks` (15) while the player lives, appends the player's position to `echo_x` / `echo_y`, keeping the
  last `echo_points`, oldest first.
- **The echo (`echo`, shielded, on the cadence).** `BossTide.due` treats `echo` as a cadence move (`is_cadence_move`:
  `tide` or `echo`): the phase's first one every `sig_every_ticks` (600) start to start, the first `sig_first_ticks`
  (240) after the clock starts, never by the pick. On start (`BossJudge.on_start`, after the lock) the recording locks
  into the path (`path_x`, `path_y`, `path_k` = each point's index in the recording), every point within `radius_m` +
  the player's radius + `echo_safe_m` (0.9 + 0.35 + 0.3) of the player's position then left out (it never strikes
  where you stand at its start). The windup (48 ticks) shows the whole path; on active tick `path_k × echo_gap_ticks`
  each point strikes a disc of `radius_m` (`hit_player`, its own hit each: `bosses.hit` cleared per point), so the
  strikes come in the order walked, 0.25 s apart; the active time is `(echo_points − 1) × echo_gap_ticks + 1`. A new
  attack by the Judge clears the path; one echo at a time (one attack at a time, the cadence 10 s).
- **The cadence holds (`BossTide.HOLD`).** `due(…, cd)` returns `HOLD` (−2) when the signature is due but the boss's
  cooldown still runs; the punish and the gap-closer then wait, so a player keeping far away can't starve the
  cadence (the Tidecaller's Pull too).
- **The Verdict (`verdict`, locked).** Its square (`square_half_m` each way, axis-aligned: `AttackShapes.lane` from
  `c − (half, 0)` along +x) starts on the player (`on_start`), follows their exact position through the windup until
  its last `lock_ticks` (`track_verdict`), then holds; on its first active tick a player whose circle touches the
  square is hit once. Its telegraph is a `&"lanes"` with the one square, `tracked`, `locked`.
- **State.** `echo_boss`, `echo_x`, `echo_y`, `path_x`, `path_y`, `path_k` in `BossStore`, hashed after a `-4` sentinel
  only while a Judge records (`echo_boss >= 0`), in `WorldSnapshot.ADDED_SINCE_V05` (an older save has none: the Judge
  records again from its next think); `BossSignatures.on_boss_gone` → `BossJudge.on_boss_gone` clears them.
- **Reads.** `WorldReader.boss_echo(i)` (`BossJudge.state`: recording ‰ of the window before the next due tick, the
  trail, the phase `ECHO_NONE` / `ECHO_SHOW` / `ECHO_REPLAY`, and while one runs progress, t, windup, gap, radius and
  the path `[{pos, k, at, struck}]`; a winding Verdict's centre, half, locked, progress), `KIND_CLOCKWORK_JUDGE`,
  `MOVE_ECHO`, `MOVE_VERDICT`.

## 11. Scaling and threat

- **Floor and danger tier drive scaling (v0.4.0 SC, owner F7/F10).** A normal enemy's max HP is its base ×
  `enemy_hp_floor_permille[floor − 1]` (`data/run/five_floors.tres` since v0.9.0 FV: 1000, 1380, 1900, 2620, 3610,
  v0.8.0's 1.9^(f − 1) over three floors stretched over five) × `hp_tier_permille[tier]`
  (`data/spawning/floor_1.tres`: 1.10^tier), its damage × `enemy_damage_floor_permille` (1000, 1180, 1400, 1660,
  1960; was 1.4^(f − 1)) ×
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
  engine's slots joins) is a pure function of the loadout: `weapon_permille(weapon level) × (DAMAGE + ONRUSH) ×
  GLASS_CANNON × expected_crit(chance, mult) / expected_crit(base) × rate × (1000 + ability_level ×
  levels of the non-weapon abilities + item × items held + combo × combos owned)`, each step `/ 1000` in integers;
  v0.8.0 SG: `(DAMAGE + ONRUSH)` is the additive bucket (Onrush always counted, Hoarder never) and `rate` is
  `1000 + AttackRate.curve(ATTACK_SPEED − 1000 + the held cards' rate_bonus_permille ADD ops at their levels)`
  (`CatchUp.rate_permille`, `wand_rate_bonus`: summed whatever the order, so a reorder still never changes P; no
  curse, as before); nothing about how the run is played (HP, shards, kills, position) enters. `m = clamp(isqrt(P × 10⁶ / E), 1000,
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
- **The intensity director (v0.8.0 N5, owner O58, Left 4 Dead's director: "It doesn't change how hard the game hits.
  It changes when.").** On a run floor `ContentCompiler.compile_floor_spawning` hangs `SpawnTable.intensity` (an
  `IntensityTable`, loadout) from `data/spawning/intensity.tres`; a spawner without it (labs, kernel, a hand-built
  `compile_spawning`) runs and hashes as before. `Intensity.advance` runs at the top of `SpawnDirector.advance`
  (tick phase 9), so only on ordinary floor spawning: a sealed arena, the Overrun, the boss room, the encounters and
  the final arena never run it (it is frozen there). `World.intensity` (an `IntensityState`: `level` = intensity ×
  1000, 0..1000000, `mode`, `timer`, `quiet_len`, `cycle`, `calm`, `last_hp`, `seen_tick`; hashed only with the
  table; snapshotted; `ADDED_SINCE_V05`: an older save's floor starts in `BUILD_UP` at 0). Each tick it runs:
  **hit**: the hero's HP fell since the tick before (only if the director ran that tick: `seen_tick = tick − 1`; any
  HP loss counts) → `+ lost × hit_full_hp_gain / max HP`; **close**: an alive enemy within `close_radius_m` →
  `+ close_gain_per_tick`; **kill**: `World._remove_dead` → `Intensity.on_death`, an enemy dying within
  `close_radius_m` → `+ close_kill_gain` (only while the director ran the tick before); **drain**: `calm` counts the
  ticks with no hit and no close enemy; from `calm_ticks` on, `− drain_per_tick`; clamped to 0..1000000. Then the
  state: `BUILD_UP` → `PEAK` at `peak_level` (one stream `ai:intensity:<cycle>` derived from the world's seed draws
  the peak's length in `peak_ticks_min..max`, then the quiet's in `quiet_ticks_min..max`); `PEAK` → `PULL_BACK` when
  its timer ends (timer = `pull_back_max_ticks`); `PULL_BACK` → `QUIET` once at most `pull_back_enemies` alive enemies
  are within `pull_back_radius_m`, or on its timeout; `QUIET` → `BUILD_UP` (`cycle + 1`) once its drawn length has
  passed and `level ≤ relax_level`, or at the latest `quiet_ticks_max` after it began (then `level` drops to
  `relax_level`). Gate: in `PULL_BACK` and `QUIET` `SpawnDirector.advance` sends no pack (`Intensity.sending`; the
  interval clock runs down to 0 and waits; the enemies out stay); in `BUILD_UP` the next interval is the curve's ×
  `build_interval_permille` (`Intensity.interval`, the ramp toward the peak); `PEAK` keeps the curve's. The cap, the
  mix, the pack, the tier, the curve, the curses, Deep and the catch-up are untouched: the director changes when, not
  what or how strong. The player gets no cue (owner: "the enemies are the real indicator"); `WorldReader.
  has_intensity`, `intensity` (0..1000), `intensity_mode`, `intensity_timer` exist for the dev panel (F10's Tools page:
  `DevPanel.intensity_text`).
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
  arenas: combat rooms are all but the hall (the arrival receiver), the boss room and its host, the portal room, the Overrun and the
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
- **Floor rules (v0.7.5 MG; owner N9-N12).** A floor is 15-19 rooms before the boss room (16-20 with it; was 10-12),
  footprints up to the extra-large 4×4, on a span of 11 cells (`FloorParams`, from `data/map` through
  `RunContentCompiler.compile_map`; the same `map` stream draws, in the same order). The arena share is 0.11 (was
  0.33): with the Overrun room a floor averages 2.4 challenge rooms (was 3.2). Two features follow a floor cadence,
  `FloorCadence.on(floor, first, every)`: a pure function of the run's floor number (counted from 1, and on past the
  run's last floor for an endless loop), no draw. The shop stands on `ShopTable.on_floor` floors (1, 3, 5 …;
  `FloorScenario.add_shop` places nothing on the others). Chests roll the cursed offer only on
  `EventRules.curse_floor` floors (1, 3, 5 …) and while `EventState.cursed_rolled` (hashed with the event state,
  snapshotted; a pre-MG snapshot restores it as 0) is under `cursed_chests_per_floor` (1): at most one cursed chest
  every two floors; the 25 % draw on `loot:event` is taken first, so the stream only moves where a chest is refused.
  A floor resumed from a save made before v0.7.5 is rebuilt with v0.7.0's rules (`RunState.floor_rules`).
- **Designed rooms (v0.8.0 RT; owner O12).** With layouts (`FloorParams.room_layouts`, from `data/room_layouts`), after
  the room templates are drawn, each room in order except the start hall and the portal room whose size has layouts
  draws, from the `map` stream, a layout (by weight), a quarter turn (any for a square room; for a long room the two
  that keep the layout's long side along the room's) and a mirror (`RoomLayouts.draw`). No draw then moves the turn
  and mirror to whichever allowed way round puts the fewest of the layout's blockers in a doorway's box (the drawn way
  first; `FloorGenerator._settle_orientation`). The room is furnished from it instead of its template: each group,
  in the layout's order, placed in metres (`RoomLayouts.place_group`: anchors scale with the room, pieces keep their
  metres, everything axis-aligned, whole centimetres) is kept whole or dropped whole: dropped when a blocker would
  leave the room, stand in a doorway's box (the doorway's width plus 1 m either side, 3 m deep from the wall face),
  or fail a vignette's checks (doorways, start and gate clear; flush with a wall or the slab gap from it and from
  every other piece; the room one region holding every doorway approach). Drawn-only pieces go with their group
  (decoration in a doorway's box is left out) into `FloorLayout.layout_props`, presentation only; blockers carry their
  kit piece (`piece_tags`) and drawn height (`piece_heights`). Rooms of a size without layouts, the start hall and the
  portal room keep their rule-built interiors; the boss room, the shop, the arenas and the Overrun room are chosen
  afterwards as before. Every room size has layouts since RT2 (24); a room whose doorways drop most of its groups is
  still a whole room (checked over many floors in `test_room_layouts.gd`). Floor rules 5 (`RunState.FLOOR_RULES`,
  RT2): a floor saved under rules 1-3 is rebuilt without layouts and makes none of these draws; one saved under rules
  4 (RT1) is rebuilt with RT1's three layouts only (`RunSaver.rt1_layouts`), so its 1×1, 2×1, 3×1, 4×3 and 4×4 rooms
  draw nothing, as then; either way it is the floor it was saved on. Nothing new is hashed or saved (the floor
  is rebuilt from its seed and rules; the snapshot's walls must match it).
- **Shop rooms (v0.8.0 SR; owner O13; `ShopRoom`, `FloorScenario.add_shop`).** After `ShopPlacement.pick` (its rule
  unchanged, so the room, the arenas and the routes stay put), on a floor whose shop table has a shop room for the
  floor's biome (`ShopTable.room_for`), `ShopRoom.furnish` replaces that room's interior (every piece from `slab_first`
  inside it, and its drawn pieces) with the biome's layout. No draw. The frame is the quarter turn whose -y points from
  the room's centre toward its first doorway's approach (the farther axis; ties to x). The stall stands at the first
  of its spots where it fits, pushed flush to a side or the back within the slab gap; it fits when it passes a
  designed group's checks (`FloorGenerator.vignette_fits`) and no doorway's box, its approach box (clipped to the
  room) keeps its full depth across the counter's width, every item spot of the room keeps the item clearance from it
  and stays out of the approach, and the room stays one region (enemy clearance) holding the doorways' approaches, the
  item spots and a point 1.8 m in front of the counter. The dressing's groups are kept or dropped whole by the same
  checks and never stand in the approach. Kit solids join `FloorLayout.walls` (drawn by the dresser); the stall and
  any `shop_*` solid go to `FloorLayout.shop_solids`, which `add_shop` appends to the world's walls after the layout's
  walls and the gate's, the Deep gate's and the shrine's footprints (never drawn as walls; `ShopStallView` draws them);
  `shop_pos` is the counter's centre (the shop's interaction point, `Shop.pos`), `shop_angle` its facing; the room's
  spawn points keep those clear of the new pieces (spawn clearance), out of the approach and 1.6 m from the counter.
  When no spot fits, nothing changes and the terminal stands as before (none over the 120 run floors of
  `tests/unit/sim/test_shop_rooms.gd`, which bounds it at 3 %; one in 30 other floors probed, a 12.8 × 8.9 m room
  whose reward stood in the walk-up lane). Floor rules 5: a floor saved under rules 1-4 has no shop rooms in its tables
  and is rebuilt with its terminal. Nothing new is hashed or saved.
- **v0.8.0 P2 (owner O28): two devices, no choice.** On an Ascension floor in state `OPEN`, standing in the portal's
  opening (`BossFlow.in_portal`) calls `enter_ascension(Choice.ASCENSION)` (1, v0.7.5's END) and standing within
  `Ascension.LOOP_RADIUS_M` (0.9 m) of `FloorLayout.loop_pos` calls `enter_ascension(Choice.LOOP)` (2, v0.7.5's ASCEND).
  The Loop device is placed at setup (`FloorScenario.build`, a loop's last floor: `Ascension.place_loop_device`, a pure
  function of the layout: the centre of the clear front square of the first spot `Routes.fits` without clearing, else
  `boss_spawn`); nothing solid is added. Nothing waits on a pick (`World.step` lost the Ascension wait; `ascend_open`
  and `ascend_declined` stay false and are still hashed and saved). The paragraph below is v0.7.5's, kept for the
  history: read END as the portal (to the final boss, FB1) and ASCEND as the Loop device; `Ascension.ascended` is
  `looped`, `ended` is `took_portal`.
- **The Ascension portal and the endless loop (v0.7.5 AP, owner N4; `Ascension`, `BossFlow`, `RunState`).** On a
  run's last floor of a loop (`RunState.is_last_floor`, loop-local) `RunState.prepare` sets `BossFlow.ascension`: the
  boss room's gate is the Ascension portal (the gate's own footprint, opening and `in_portal`; no Deep gate on that
  floor). It opens with the boss's death like any gate (`PORTAL_OPENED`). In state `OPEN`, standing in its opening sets
  `BossFlow.ascend_open` unless `ascend_declined`; leaving the opening clears `ascend_declined`. While `ascend_open`
  the world waits (`World.step`, beside the shop's and the event panel's waits: only the pick runs, the tick counts).
  The pick (`InputFrame.pick`): `Ascension.PICK_END` (1) or `PICK_ASCEND` (2) call `BossFlow.enter_ascension`
  (`ascend_choice` = `Ascension.Choice.END` 1 / `ASCEND` 2, state `ENTERING`, `route_taken` `NORMAL`, `FLOOR_EXIT`
  amount 0, then the usual transit); `PICK_CANCEL` is Not yet (`ascend_open` false, `ascend_declined` true); any
  other pick is ignored. `WorldReader.outcome` on an exited Ascension floor: 1 (won) for End, 3 (next floor) for
  Ascend. `BossFlow` hashes `1, ascend_open, ascend_declined, ascend_choice` after its RT fields only when
  `ascension` (every other floor hashes as before).
  - **Floor numbers.** `RunState.floor_index` stays the floor within the loop (1..`floors`): the per-floor tables,
    boss pools, curves, arena wave sizes, prices and reward scaling read it (`World.floor_index`).
    `RunState.run_floor(f) = loop_floors + f` counts the run's floors across loops: the floor seeds
    (`floor_<run floor>`), the boss drawn (`boss_<run floor>`), `routes` (one entry per run floor) and Deep, the biome
    order (one entry per run floor), the boss's floor-1 ease and the boss-room heal (only the run's first floor), and,
    through `World.run_floor` / `run_floor_index()` (0 outside a run: `floor_index`), `FloorCadence`'s shop
    (`FloorScenario.add_shop`) and cursed-chest floors (`Curses.curse_floor_open`) and `Wand.slots`. So shops and
    curses keep "every two floors" across a loop's seam (run floors 1, 3, 5 …: loop 2's floor 2 when floors = 3) and a
    wand never shrinks.
  - **Ascend** (`RunState.finish_floor` when `Ascension.ascended(w)`): totals and the carry as through any portal
    (`RunCarry`: the build, the 40 % heal, half the shards), then `loop_floors += floor_index`, `loop += 1`,
    `floor_index = 1`, and the next loop's biomes are drawn: every biome of the run's list shuffled from the stream
    `biomes_loop_<loop>` (a sub-stream of the run seed like `biomes`), appended for the loop's floors; its first floor
    never repeats the floor before it (swap with the second when it would).
  - **Harder each loop** (data, `RunDefinition` → `RunTable`): `RunState.loop_permille(step)` = 1000 × (step / 1000)
    ^ (loop − 1), computed by repeated integer multiplication and capped at `loop_scale_cap_permille` (EI-02: no
    `pow`). Normal enemies' HP and damage per mille × `loop_enemy_hp_permille` / `loop_enemy_damage_permille`'s loop
    factor (`scale_enemies`, after the floor and Deep factors: one more `SpawnTable.scale` each); bosses' HP and
    attack damage × `loop_boss_hp_permille` / `loop_boss_damage_permille`'s (`scale_bosses`, integer division).
    v0.8.0 P3 (owner O35): on a Deep floor past loop 1 both then × `loop_deep_ease_permille` (900; one more
    `SpawnTable.scale` for enemies, one more integer step for bosses, before the floor-1 ease); nowhere else.
    `prepare` sets `World.loop`, `World.run_floor`, `World.loop_threat` = `loop_threat` × (loop − 1) (added to
    `Curses.threat`, so it shows as T and raises the catch-up caps through `threat_cap`) and `World.loop_cap_permille`
    = `loop_catch_up_cap_permille` × (loop − 1), added to both catch-up caps (`CatchUp.start_floor`, `on_boss`).
    World hashes `loop, run_floor, loop_threat, loop_cap_permille` (after the run-flow fields) only when loop > 1.
  - **Saves.** `WorldSnapshot` copies the new World and BossFlow fields; a snapshot without them (any save before AP)
    keeps the base world's (`ADDED_SINCE_V05`: loop 1, or the Ascension portal on an old save's last floor, from
    `prepare`). The run payload's `loop` / `loop_floors` (ARCHITECTURE §10) default to 1 / 0.
- **The boss's legendary altar (v0.5.5 AR, owner X1b; `BossReward`).** Tick phase 9 after the boss flow: the tick
  `BossFlow.opened_tick` is set (the boss died) and the loadout has a `LegendaryTable`, a free
  `RewardStore.Kind.LEGENDARY` reward appears at `FloorLayout.boss_spawn` (`World.legendary_id`, hashed once set; it
  stays set after the pick). Its offer (`Offers.roll_legendary`, loot stream, on the first open) is up to 3 cards from
  the tier only: legendary stat cards (`Offers.LEGENDARY` = rarity 3) and the pool's mods.
  v0.8.0 RR (owner O33; `docs/roadmap/v0.8.0/evidence/RARITY.md`): the roll first draws `range_int(0, 999)` against
  `LegendaryTable.chance(World.loop)` (only when the chance is between 0 and 1000); under it the first card is a
  Legendary card (an item of rarity `LEGENDARY` still in the pool, uniform, one more draw), and no Legendary card is a
  pool mod otherwise. The death sets `World.legendary_picks` = `LegendaryTable.extra_picks(loop)`; a pick at the altar
  while it is above 0 uses one, clears the offer (`rolled` 0) and keeps the altar (`BossReward.another_pick`); it is
  hashed only while above 0 and saved (`WorldSnapshot.ADDED_SINCE_V05`). Altars', chests' and the shop's mod draws
  weigh each tier (`ItemPool.card_weight`: per mille of a common card, × the weapon's own ×1.5 / 1000); a legendary
  card enters their pool only while its source's weight is above 0.
- There is no enrage timer. The danger tier is the floor's own clock (it restarts on every floor and counts only
  while the player lives), not a global one; the owner asked for scaling over time (F10, v0.4.0 PLAN).
- All scaling is integer `‰` tables. A formula that needs `pow` or `exp` is authored as a table instead.
- **The formula is locked by evidence.** Its first version is measured in v0.3.0 and recorded in that version's
  `evidence/`. Later changes need a new sim result showing the scorecard bands still hold
  ([`../balance/SCORECARD.md`](../balance/SCORECARD.md)). The v0.4.0 change (SC, above) is the owner's direction;
  its sim result against the expected-build bot is v0.4.0 step TU's (not run in SC). **Superseded 2026-10-08
  (owner P1, v0.5.5):** bot balance sims are no longer run or evidence; a scaling change is judged by the owner's
  play (LOCKED_DECISIONS 2026-10-08).

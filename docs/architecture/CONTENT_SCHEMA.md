# Content schema

How the game's data is defined, validated, discovered and compiled. The invariant is EI-08 in
[`LOCKED_DECISIONS.md`](LOCKED_DECISIONS.md). Sim-side meaning (ticks, events, procs) is in
[`SIM_CONTRACTS.md`](SIM_CONTRACTS.md).

## 0. Rules for every definition

- Every definition is a typed `Resource` subclass in `src/content/defs/`, saved as `.tres` under `data/`.
- Every definition has `@export var id: StringName`. It is unique within its type, `snake_case`, and never
  reused for something else once shipped (saves and replays refer to it).
- Every definition implements `validate() -> Array[ValidationIssue]` (ported from Deathventory's
  `validation_issue.gd`). An issue has a severity (`ERROR` or `WARNING`), the resource path, the field and a
  message. **Any `ERROR` fails the content test and blocks the game from starting a run.**
- Player-facing text fields hold **translation keys**, never text: `name_key`, `desc_key`, and so on. A key
  must exist in `locale/strings.csv` with both `en` and `es` filled (EI-10).
- Durations are authored in seconds (`float`) and distances in metres. `ContentCompiler` converts durations to
  ticks once ([`SIM_CONTRACTS.md`](SIM_CONTRACTS.md) §1). The sim never reads a `Resource` directly.
- **Tracing values.** Where a field's values come from the gap analysis, the `@export` in the definition's `.gd`
  says so in a doc comment (`## Values: GA §5`). A `.tres` can't carry this: its comments are dropped when the
  editor re-saves it.
- **Starting values.** Values that are tuning defaults rather than sourced numbers are listed in
  [`../design/GAME_BLUEPRINT.md`](../design/GAME_BLUEPRINT.md) §C, "Starting values in use", with the file, the
  field and the value.
- New enum values are appended, never inserted, because saved files store the integer.

## 1. Discovery and loading

- **One scanner.** `ContentScanner.scan(root: String) -> PackedStringArray` walks a folder tree with
  `ResourceLoader.list_directory()` (Godot 4.4+).
  - That call lists resources by their logical names, both in the editor and in exported packs, where files are
    remapped.
  - It isn't recursive: entries ending in `/` are folders, and the scanner descends into them itself.
  - The results are sorted.
- Deathventory found files with `DirAccess` and `.tres` suffix checks. Every export shipped empty until v0.9.6
  fixed it by stripping `.remap` by hand ([`../LESSONS.md`](../LESSONS.md) L4). Here the engine call does that
  work, and the export smoke proves it.
- **`ContentRepository`** (adapted from Deathventory) loads every definition type from its folder through the
  scanner, indexes by `id`, runs `validate()` on each, and cross-checks references (an encounter naming an enemy
  that doesn't exist is an `ERROR`).
- **Content hash.** The repository computes a SHA-256 manifest hash over the sorted list of
  `(type, id, canonical properties)`.
  - "Canonical properties" means the `CanonicalValue` encoding of each loaded resource's storage properties.
  - It is **not** the file bytes. Exports convert text `.tres` to binary by default, so file bytes differ between
    the project and the pack. Loaded values don't.
  - Replays and saves record the hash. The export smoke checks that the pack's hash equals the project's
    (`scripts/content/print_manifest.gd` prints it).

## 2. Items and effects

```gdscript
class_name ItemDefinition extends Resource
@export var id: StringName
@export var name_key: StringName
@export var desc_key: StringName
@export var icon: Texture2D               # optional; a generated fallback is used when null
@export var tags: PackedStringArray       # archetype and family tags, e.g. ["bleed", "melee"]
@export var max_stacks: int = 1
@export var effects: Array[EffectDefinition]
@export var is_plain_support: bool = false   # a stat stick with no trigger; counted against the pool limit
```

```gdscript
class_name EffectDefinition extends Resource
@export var id: StringName                # unique across all items; used for ancestry and the once-per-root rule
@export var trigger: Trigger              # enum: ON_HIT, ON_KILL, ON_DAMAGED, ON_DASH, ON_GUARD, ON_STATUS_APPLY, ON_ROOM_START, PASSIVE, …
@export var conditions: Array[ConditionDefinition]   # all must pass
@export var payoff: PayoffDefinition
@export var priority: int = 0             # orders siblings in the effect queue; lower runs first
@export var icd_seconds: float = 0.0      # internal cooldown; compiled to ticks
@export var proc_pct: int = 100           # multiplies the parent proc for children
@export var per_stack: PackedInt32Array   # payoff magnitude for 1, 2, 3, … stacks (an integer table, no curves)
```

- **Trigger → Condition → Payoff.** Every item that isn't plain support has at least one effect with a trigger
  other than `PASSIVE`. Flat stat cards never made builds in Deathventory (L7).
- **Pool rule:** at most 4 plain-support items in a 24-item pool (GA: items). The pool validator counts
  `is_plain_support` per pool and fails above the limit.
- **No flat per-hit damage reduction payoff.** Reductions are per-mille multipliers or structural (block, guard
  arc, dodge). The validator rejects a `REDUCE_FLAT` payoff on `ON_DAMAGED`.
- `per_stack` must be non-empty and non-decreasing unless the effect is tagged `diminishing`. Its length must be
  at least `max_stacks`.
- `ConditionDefinition` and `PayoffDefinition` are small typed resources with a `kind` enum plus typed params.
  Each `kind` declares its param schema, and `validate()` checks the params against it.

**Loot pools:** `LootPoolDefinition` lists `(item_id, weight)` pairs, a floor range and the archetype tags it
serves. The reward-schedule rules (PD-07) read pools; they don't live in them.

## 3. Enemies

```gdscript
class_name EnemyDefinition extends Resource
@export var id: StringName
@export var name_key: StringName
@export var behaviour_id: StringName      # selects a behaviour script in src/sim/ai/
@export var behaviour_params: Dictionary  # checked against the behaviour's param schema
@export var hp: int
@export var radius_m: float
@export var move_speed_mps: float
@export var attacks: Array[AttackDefinition]
@export var stress_tags: PackedStringArray   # which archetype engines this enemy stresses (see the blueprint's stress matrix)
```

```gdscript
class_name AttackDefinition extends Resource
@export var id: StringName
@export var shape: Shape                  # enum: CIRCLE, CONE, LINE, RING, PROJECTILE
@export var shape_params: Dictionary      # e.g. radius_m, angle_deg, length_m, width_m, speed_mps
@export var telegraph_seconds: float      # windup; compiled to ticks; >= MIN_TELEGRAPH_TICKS
@export var telegraph_max_seconds: float  # v0.3.5 AI: > telegraph_seconds -> each windup is drawn in between (0 = fixed)
@export var active_seconds: float
@export var recovery_seconds: float
@export var damage: int
@export var proc_pct: int = 100
@export var hitstop_ticks: int = 0
```

- Each `behaviour_id` has a param schema in code (`src/content/behaviour_schemas.gd`: content is the lowest
  layer, so validation can read it; the behaviours themselves are in `src/sim/ai/`). Unknown keys and missing
  required keys are `ERROR`s.
- **Warden armour** (owner, 2026-10-07: no block). `warden` takes `front_arc_degrees` and `rear_arc_degrees`
  (each 0..360, together at most 360), `front_mult_permille` (1..1000: armour softens a hit, never blocks it) and
  `rear_mult_permille` (1000..3000). **Starting values:** 120°, 800, 120°, 1100. Anything else is an `ERROR`.
- **Telegraph minimum.** `telegraph_seconds` must compile to at least `MIN_TELEGRAPH_TICKS` (GA: enemies; a kernel
  constant). An attack with no readable warning fails validation. This is the content side of "no damage without
  a readable cause".
- **Several attacks** (v0.3.5 AI). A behaviour with more than one attack lists them in its schema (`"attacks"`: each
  an `id`, a `shape` and its `shape_params`); the definition gives exactly those, in that order. An enemy's attacks
  share one `damage` (RunState scales it per floor); a mismatch is an `ERROR`. `telegraph_max_seconds` below
  `telegraph_seconds` (and not 0) is an `ERROR` (`telegraph_range`).
- **v0.3.5 AI behaviours and params.** `charger` and `hatchling` add `charge_turn_dps` (60: a charge's turn rate);
  `needle`'s burst adds `spread_degrees` (10: the angle between shots); `arc_caster` (`attack_range_m`,
  `cooldown_seconds`, `keep_min_m`, `keep_max_m`, `bolt_weight`, `spread_weight`, `rune_weight`; attacks `bolt`
  PROJECTILE `speed_mps`/`radius_m`/`range_m`, `spread` PROJECTILE `count`/`spread_degrees`/`speed_mps`/`radius_m`/
  `range_m`, `rune` CIRCLE `radius_m`); `bomb_drone` (`attack_range_m`, `cooldown_seconds`, `keep_min_m`,
  `keep_max_m`; one CIRCLE attack, `radius_m`: the bomb's circle, its telegraph the fuse). **Starting values:** Arc
  Caster HP 40, damage 12, 4 shards, bolt 22 m/s after a 0.5 s line, rune after 0.6 s; Bomb Drone HP 30, damage 16,
  4 shards, circle 1.8 m over 0.8 s. The spawner adds the Arc Caster from danger tier 1 and the Bomb Drone from
  tier 2 (`data/spawning/floor_1.tres`, weight 2 each).
- **v0.4.0 EN horde behaviours and params** (starting values, `data/enemies/<id>.tres`):
  - `swarmer` (as `charger`; one LINE `bite`, `length_m`/`speed_mps`): HP 8 (one sword slash), damage 5, 1 shard,
    4.6 m/s, a 2 m lunge at 12 m/s after a 24-30 tick lane.
  - `splitter` (`attack_range_m`, `cooldown_seconds`, `split_count`; one CIRCLE `swipe`, `radius_m`/`reach_m`: a disc
    `reach_m` ahead of it): HP 50, damage 12, 3 shards; dies into `split_count` (2) `splitling`s (same params without
    `split_count`; HP 16, damage 6, 1 shard), which never split.
  - `shield_bearer` (`attack_range_m`, `cooldown_seconds`, `shield_arc_degrees`, `turn_rate_dps`; one LINE `bash`,
    `length_m`/`half_width_m`): HP 90, damage 18, 6 shards, 1.4 m/s, a 120 deg shield that blocks every hit from its
    front (multiplier 0, `TAG_BLOCKED`), turning at 80 deg/s; it bashes only a player inside that arc.
  - `mender` (`keep_min_m`, `keep_max_m`, `heal_amount`, `heal_period_seconds`, `heal_range_m`; **no attacks**, the
    schema's `"attacks": []`): HP 35, 5 shards, keeps 6-9 m, heals 5 HP every 0.5 s to the most hurt ally within 7 m.
  - `mine_layer` (`attack_range_m`, `cooldown_seconds`, `keep_min_m`, `keep_max_m`, `drop_seconds`, `max_mines`,
    `mine_life_seconds`; one CIRCLE `mine`, `radius_m`: the mine's circle, its telegraph the fuse after it arms):
    HP 40, damage 18, 4 shards, keeps 4-7 m, drops a mine every 2.5 s (0.5 s drop), at most 3, each lasting 20 s;
    a 1.5 m circle that arms when the player touches it and blows 0.6 s (36 ticks) later.
  - `sniper` (`attack_range_m`, `cooldown_seconds`, `keep_min_m`, `keep_max_m`; one LINE `shot`, `range_m`/
    `half_width_m`): HP 30, damage 28, 5 shards, keeps 10-14 m, a 20 m line shown for 1.0 s (60 ticks), then a hit
    down it; then it walks to a new spot.
  - Positive params (`split_count`, `max_mines`, `heal_*`, `mine_life_seconds`, `drop_seconds`) <= 0 are an `ERROR`
    (`not_positive`); `shield_arc_degrees` outside 0..360 is an `ERROR` (`armour`).
  - The spawner's mix (`data/spawning/floor_1.tres`): Swarmer (weight 3, tier 1, `pack` 8) and Splitter (2, tier 1);
    Shield Bearer (2), Mine Layer (2), Sniper (1) from tier 2; Mender (1) from tier 3. The horde kinds other than the
    Swarmer ship `pack` 1 (singles). `SpawnMixEntry.pack` follows the one rule in §7 (0 = the floor's draw; `mix_entry`
    `ERROR` below 0).
- **v0.4.0 BO:** `lens_drone` takes the `needle` schema (`attack_range_m`, `cooldown_seconds`, `keep_distance_m`,
  `flee_distance_m`; one PROJECTILE burst) and flies the Needle's behaviour under its own actor kind
  (`EnemyAi.behaviour_of`). It is the Hive Lens's split, never spawned by a floor. **Starting values:** HP 45,
  damage 8, 3 shards, 2 pulses 10 m/s after a 0.5-0.67 s line, keeps 6 m.
- `stress_tags` feed the enemy × archetype stress matrix in [`../balance/SCORECARD.md`](../balance/SCORECARD.md).
- **Shards** (v0.3.0 E): `@export var shards: int` (>= 0; Charger 3, Needle 4, Warden 6) is what a kill pays,
  × (1 + `shard_tier_bonus` × danger tier) rounded half up (v0.4.0 TU: the floor's plain 30 s tier, so shards keep
  growing after the difficulty curve holds at its peak; owner D7). `@export var shards_by_floor: bool` (bosses) pays
  `shards` × the floor number instead, with no tier scaling.

**Item rarity** (v0.3.0 E): the shipped `ItemDefinition` has `@export var rarity: Rarity` (`COMMON`, `RARE`;
default `COMMON`). Chests weight rare items higher (`RewardsDefinition.rare_weight_chest`). `@export var requires_utility: StringName` (empty, `guard` or `blink`) keeps an item out of every offer unless the
player chose that utility (Bulwark: `guard`).
v0.5.0 CP: `@export var requires_ability: StringName` (empty, or an `AbilityDefinition.Kind` in lower case, e.g.
`bomb_lobber`) keeps an **ability mod** out of every offer until the player owns that ability; the tag `ability`
(added to the closed tag set) and `requires_ability` go together. Four kinds, appended: `CLUSTER_PAYLOAD`
(`bomblets`, `bomblet_damage_permille`, `bomblet_radius_permille`, `bomblet_delay_seconds`), `OVERCLOCKED_DRONE`
(`drone_rate_per_heat_permille`; also offered only in runs with heat), `RAZOR_ORBIT` (`stacks_per_hit` and the
bleed fields, as Serrated Edge) and `AFTERIMAGE` (`afterimage_damage`, `afterimage_radius_m`,
`afterimage_delay_seconds`). Each validates the fields it reads (positive; seconds at least one tick).

**Rewards** (v0.3.0 E, category `rewards`, `data/rewards/floor.tres`): `RewardsDefinition` holds the floor's
altar and chest counts (inclusive ranges), `chest_prices` by chest order on floor 1, `floor_price_step` (each
later floor adds that share of the floor-1 price), `rare_weight_chest` / `rare_weight_altar`, `offer_size` (1..3),
`interact_radius_m` and `shard_tier_bonus`. Validation: ranges ordered and non-negative, prices positive, weights
and the radius positive. v0.4.0 TU (owner D8): `heal_orb_chance` (0.1: a normal enemy's kill drops a heal orb, one
loot-stream roll), `heal_orb_heal` (0.25 of max HP) and `heal_orb_reach_m` (0.9 m, × the pickup-range stat); both
shares within 0..1 (`range`), the reach positive.

**Overclock heat** (v0.3.0 L18, category `heat`, `data/heat/overclock.tres`; design in
[`../design/SIGNATURE.md`](../design/SIGNATURE.md)): `HeatDefinition` holds `max_heat` (the overheat point), the
gain per landed attack type (`gain_swing`, `gain_finisher`, `gain_bolt`, in heat points), the decay
(`decay_delay_seconds`, `decay_per_second`), the thresholds (`hot_threshold` with `hot_reach_bonus`,
`overclock_threshold` with `overclock_damage_bonus` and `overclock_burn_stacks`), the overheat stall
(`overheat_seconds`, `overheat_move_multiplier`) and the vent blast (`vent_radius_m`, `vent_damage_per_heat`).
Validation: gains, rates, bonuses and the blast positive; `0 < hot_threshold < overclock_threshold < max_heat`;
the move multiplier in (0, 1]. Heat items (`ItemDefinition` kinds `HEAT_SINK`, `THERMAL_EDGE`, `MELTDOWN`, tag
`heat`) add `vent_damage_bonus_permille`, `vent_radius_bonus_permille`, `heat_hot_threshold` and
`meltdown_damage_permille`; they are offered only in runs with heat.
**Gamble shrine** (v0.3.0 L19, category `gamble`, `data/gamble/shrine.tres`): `GambleDefinition` holds
`base_price` (floor 1's first use), `price_step` (each use on a floor multiplies the next price by 1 + step, rounded
half up; the count resets per floor), `floor_price_step` (raises a later floor's base like the chests'),
`interact_radius_m`, the placement rule's `spot_distance_m` and `clear_radius_m`, and `stats`: an array of
`GambleStatEntry` (`stat`, one of `GambleStatEntry.STATS`; `amount`, HP for `max_hp`, % for the rest, regen in % of
max HP per second; `weight`; `max_stacks`, the cap). Validation: prices, radii, amounts, weights and caps positive,
steps non-negative, every stat known and listed once, the pool not empty.

**Shop** (v0.5.0 SH, PLAN R1, R2; category `shop`, `data/shop/terminal.tres`): `ShopDefinition` holds `offer_size`
(cards in the stock, 4), `rarity_prices` (floor 1's price for a common, rare and epic card: 30 / 55 / 90; a mod or
an ability card is common or rare), `floor_price_step` (each later floor raises every price but the reroll by this
share of floor 1's: × 1, 1.5, 2), `heal_share` (0.3 of max HP, once per shop) and `heal_price` (40 × the floor
step), `reroll_price` and `reroll_step` (20, then × 1.5 per use at that shop, rounded half up: 20, 30, 45, 68),
`sell_share` (a mod or stat card sells for 0.4 of its shop price; a stat card one stack, the stat values rebuilt from
the cards left so the caps hold), `ability_refund_per_level` (10 shards per level, was 25: a free ability plus a bought level-up must not salvage for profit, M-LOOP; for salvaging an ability, never the
weapon; its slot frees for a later ability card) and `interact_radius_m`. The stock is drawn from `loot` by a chest's
rules (`Offers.draw`: ability cards only while they can apply, mods only with their ability), and a mod in the stock
is out of the item pool like one in an altar's offer. Placement is a pass of its own (`ShopPlacement.pick`, stream
`shop_room`, never `map`): one per floor, never the start hall, the boss room or the room before the boss door, dead
ends first. Validation: prices, the heal and reroll prices, the refund and the radius positive; three rarity prices;
the steps non-negative; the shares in (0, 1]; `offer_size` 1–9.

## 4. Encounters and bosses

```gdscript
class_name EncounterDefinition extends Resource
@export var id: StringName
@export var tags: PackedStringArray       # e.g. ["floor_1", "ranged_heavy"]; used by the generator
@export var waves: Array[WaveDefinition]  # each wave: (enemy_id, count, spawn_slot_tag, delay_seconds)
@export var min_floor: int = 1
@export var max_floor: int = 3
@export var threat_cost: int = 0          # > 0 only for optional branch encounters
```

```gdscript
class_name BossDefinition extends ContentDef       # data/bosses/<id>.tres (v0.3.0 C)
@export var id: StringName                         # one of BossSchemas.KINDS: each boss has its own actor kind and model
@export var name_key: StringName
@export var hp: int
@export var radius_m: float
@export var move_speed_mps: float
@export var turn_rate_dps: float                   # 0 = always faces the player
@export var keep_distance_m: float                 # pursuit stops this far away (0 = melee)
@export var front_arc_degrees: float               # armour, as the Warden's (§3)
@export var front_mult_permille: int
@export var rear_arc_degrees: float
@export var rear_mult_permille: int
@export var stagger_size: int                      # stagger meter size in damage points; rules in the blueprint §F
@export var stagger_decay_per_second: float
@export var stagger_seconds: float
@export var attacks: Array[BossAttackDefinition]   # AttackDefinition + move, min/max_range_m, weight, cooldown_seconds, cause_key
@export var phases: Array[BossPhaseDefinition]     # each: hp_threshold_permille, attack_ids, entry_attack, speed/cooldown_permille
@export var arena_cells: Vector2i                  # the boss room's size in cells
@export var arena_template: int                    # its interior (FloorLayout.Template; BossSchemas.ARENA_TEMPLATES)
# Boss challenge (v0.3.0 BX, PLAN L17/L26). Distances run from the boss's edge to the player.
@export var ranged_full_m: float                   # ranged armour: full damage up to here...
@export var ranged_far_m: float                    # ...falling linearly to ranged_far_permille here and beyond
@export var ranged_far_permille: int               # 1..1000 (1000 = none)
@export var punish_distance_m: float               # beyond this for punish_seconds -> punish_attack
@export var punish_seconds: float
@export var punish_attack: StringName              # an attack id (empty = none); it needn't be in a phase
@export var weak_point_seconds: float              # open after an attack with opens_weak_point
@export var weak_point_range_m: float              # hits from within it...
@export var weak_point_mult_permille: int          # ...deal this (1000..4000)
@export var weak_point_stagger_permille: int       # ...and fill the stagger meter at this (1000..4000)
@export var weak_point_drops_armour: bool          # v0.4.0 BO: while it is open the front armour is off (the Warlord's shield)
@export var arena_close_phase: int                 # closing arena starts at this phase (-1 = not by phase)
@export var arena_close_after_seconds: float       # or after this long fighting (0 = not by time)
@export var arena_close_step_seconds: float        # a step every this long...
@export var arena_close_step_m: float              # ...this far in (0 = never closes)
@export var arena_close_warn_seconds: float        # each step marked first (>= MIN_TELEGRAPH_TICKS, < the step)
@export var arena_safe_half_m: float               # stops this far from the room's centre on each axis
@export var arena_hazard_damage: int               # standing in the band: damage over time...
@export var arena_hazard_seconds: float            # ...every this long
@export var recovery_permille: int                 # scales every attack's recovery (1..2000)
@export var lead_seconds: float                    # aimed attacks lead the player's velocity (0..1)
# v0.3.5 AI (owner F3). Starting values on all three bosses: 0.2, 0.5, the gap-closer after 2.0 s.
@export var track_commit_seconds: float            # aimed windups track the player until their last this-long (>= 0)
@export var dash_read_seconds: float               # after a dash, aimed attacks go at its landing point (0..2)
@export var gap_close_attack: StringName           # an attack id (empty = none), done when out of reach...
@export var gap_close_distance_m: float            # ...beyond this from the boss's edge...
@export var gap_close_seconds: float               # ...for this long
```

- Boss attacks (v0.3.0 BX) also take `opens_weak_point: bool`, and `follow_up: StringName` (another attack of the
  boss) with `follow_up_permille` (0..1000): the chance it starts at once instead of the recovery (a follow-up never
  chains again). The `pull` move (`inner_radius_m`, `radius_m`, `pull_mps`, `pull_range_m`) drags the player in
  during its windup, then slams a ring.
- The `flood` move (v0.4.0 BO; LINE): `count` parallel lanes `gap_m` apart (centre to centre, > 0), centred on the
  line toward the player, each `length_m` long and `width_m` wide from the boss's edge, cut short by walls. The
  lanes are marked for the windup; then they stand for the whole `active_seconds` (drawn styled: the Warlord's
  spears, the Foundry's molten floor) and hurt a player in them at most once every `burn_seconds` (at least a tick).
  `count` is at most 8, as every count.

- Phases are ordered by descending `hp_threshold_permille`. The first phase starts at 1000.
- Each attack's `move` has a param schema in `src/content/boss_schemas.gd` (the shape and the `shape_params` keys);
  missing or unknown keys are `ERROR`s. Every attack's `telegraph_seconds`, and a burrow's `erupt_seconds` (the
  eruption's own mark), compile to at least `MIN_TELEGRAPH_TICKS`. Every attack names a `cause_key` (the death
  recap line).
- `BossPoolDefinition` (`data/boss_pools/floor_<n>.tres`): `floor_index` and the `boss_ids` that floor draws from.
  Since v0.4.0 BO each pool holds two: floor 1 Gatekeeper and Warlord, floor 2 Brood Mother and Hive Lens, floor 3
  Siege Engine and Foundry. A run draws each floor's boss from its own stream (`RunState.pick_boss`).
- Changed from the earlier sketch (`enemy: EnemyDefinition`, `stagger_threshold`, `arena_template_id`) when the
  bosses were built (v0.3.0 C): the numbers live on the boss itself and the arena is the cells and template the
  floor generator reads.

## 5. Rooms

- **Authoring:** a room is a `.tscn` in `data/rooms_src/<biome or shared>/`. It uses marker nodes only: `Marker3D`
  for entries, exits, spawn slots and cover slots, and `MeshInstance3D` boxes for walls. Each marker carries
  metadata (`tag`, `size`, `optional`). These scenes are an editor convenience; the sim never loads them.
- **Baking:** `scripts/content/bake_rooms.gd` reads every room scene and writes a `RoomTemplate` `.tres` to
  `data/rooms/` with plain arrays (wall OBBs, slot positions, tags). CI re-bakes and fails if `git diff` shows
  any change, so the baked files always match their sources.

```gdscript
class_name RoomTemplate extends Resource
@export var id: StringName
@export var tags: PackedStringArray       # size class, shape, "arena", "set_piece", biome affinity
@export var size_m: Vector2
@export var walls: Array[Dictionary]      # {center, half_extents, angle} per wall; angle in 1/4096 turn
@export var entries: Array[Dictionary]    # {pos, facing}
@export var exits: Array[Dictionary]
@export var spawn_slots: Array[Dictionary]   # {pos, tag}
@export var cover_slots: Array[Dictionary]   # {pos, size, optional}
```

- Validation: at least one entry and one exit, every slot inside the room bounds, and no spawn slot closer than
  6 m to any entry. The generator's own checks are in
  [`ARCHITECTURE.md`](ARCHITECTURE.md) §9.

## 6. Biomes

```gdscript
class_name BiomeDefinition extends Resource
@export var id: StringName                # ruins, night_rocks, red_canyon, frozen_shore, …
@export var name_key: StringName
@export var palette: Dictionary           # token -> Color; keys from docs/art/ART_DIRECTION.md §2
@export var props: Array[PropDefinition]  # rocks, grass, trees, fences, barrels; mesh + placement rules
@export var enemy_weights: Dictionary     # enemy_id -> weight for this biome's encounter fill
@export var hazard_flavour: StringName    # mild flavour only, e.g. &"ice_edge"; never a difficulty step
@export var template_tags: PackedStringArray
```

- A biome never changes the difficulty tables (PD-04). The validator rejects an `enemy_weights` table that adds an
  enemy outside the floor's allowed list.
- `palette` must define exactly the seven biome tokens listed in
  [`../art/ART_DIRECTION.md`](../art/ART_DIRECTION.md) §2: `ground`, `ground_alt`, `cover`, `accent`, `edge`,
  `ambient`, `outline`.
  - A missing or unknown key is an `ERROR`.
  - An `outline` below 3:1 contrast against `ground` is an `ERROR`.
  - Actor colours are fixed `ThemePalette` tokens, not biome tokens.
- `PropDefinition` (defined in v0.3.0): `id`, a mesh kind (a primitive or a procgen recipe), a size range, whether
  it blocks movement (only cover blocks), and its placement rule (cover slot, Poisson scatter or edge).

## 7. Threat and scaling

```gdscript
class_name ThreatModifier extends Resource
@export var id: StringName
@export var name_key: StringName
@export var desc_key: StringName
@export var threat_cost: int              # added to T when chosen
@export var effect: StringName            # e.g. &"enemy_hp", &"elite_chance", &"extra_wave"
@export var permille_by_t: PackedInt32Array   # integer table indexed by T
```

No formula in content uses `pow` or `exp`: growth is authored as integer `‰` tables. Since v0.4.0 SC (owner F7,
F10) the tables live with the run and the spawner (there is no `data/threat/scaling.tres`):

- **`RunDefinition`** (`data/run/three_floors.tres`): `enemy_hp_floor_permille` and `enemy_damage_floor_permille`,
  one entry per floor (shipped `[1000, 1900, 3610]` and `[1000, 1400, 1960]`: 1.9^(f − 1), 1.4^(f − 1)); a floor
  past the end uses the last entry. `boss_hp_per_floor` and `boss_damage_per_floor` (0.4, 0.2; they were
  `enemy_hp_per_floor`/`enemy_damage_per_floor`) scale bosses only: × (1 + value × (f − 1)), never with the
  enemies' tables. v0.5.0 RT: `deep_scale` (1.25, at least 1) multiplies both on a Deep floor, and
  `deep_extra_chests` (1, not negative) adds chests there ([`SIM_CONTRACTS.md`](SIM_CONTRACTS.md) §11).
- **`SpawnDirectorDefinition`** (`data/spawning/floor_1.tres`, used on every floor): `tier_seconds` (30);
  `cap_by_floor` (`[14, 30, 50]`), `cap_per_tier` (6), `cap_max` (120); `interval_start_seconds` (2.5),
  `interval_min_seconds` (0.4), `interval_tier_permille` (0.9^tier); `hp_tier_permille` (1.10^tier),
  `damage_tier_permille` (1.05^tier); `pack_min_by_floor` (`[2, 3, 3]`), `pack_max_by_floor` (`[3, 4, 5]`);
  `min_distance_m` (8), `edge_band_m` (3: a pack's anchor is a spawn point this close to its room's walls when the
  rooms offer one); `mix`. The three tier tables hold tiers 0-20 (ten minutes); a later tier uses the last entry.
- **`SpawnMixEntry`**: `enemy_id`, `weight`, `unlock_tier` and `pack` — one rule since the v0.4.0 SC + EN merge:
  `0` (the default) takes the floor's draw (`pack_min_by_floor`..`pack_max_by_floor`), `> 0` always brings that
  many (the Swarmer's 8; the other horde kinds ship `1`, singles as EN designed them). A pack stands on rings around
  its anchor and never takes the alive count past the cap. A new enemy joins the hordes with one more entry.
- **`RunDefinition`, v0.4.0 TU (owner D9, "Ease floor 1 only"):** `boss_ease_floor_permille` (`[800, 1000, 1000]`:
  a floor's boss HP and attack damage × this, on top of the per-floor factors and Deep) and
  `boss_room_heal_floor_permille` (`[1000, 0, 0]`: the share of max HP restored when the boss room seals); both per
  floor, past the end the last entry, entries 1..1000 / 0..1000 (`range`).
- **`DifficultyCurveDefinition`** (v0.4.0 TU, owner 2026-10-08 D1–D4; `data/curves/floor_1.tres` .. `floor_3.tres`,
  category `curve`, one per floor by `floor_index`): `phases`, an ordered list of **`DifficultyPhase`**:
  `start_seconds` (floor time; the first at 0), `name_key` (the HUD's name, en + es), `tier_permille` (the danger tier
  × 1000 at the phase start: SC's per-tier HP, damage and interval tables and the shard bonus read the curve's tier),
  `cap_permille` (1..1000 of SC's alive cap at that tier), `interval_permille` (× SC's interval; > 1000 is slower),
  `hp_permille` and `damage_permille` (1..1000 of SC's tier values: the curve only eases toward the peak),
  `pack_cap` (the largest pack; 0 = no limit, a Swarmer pack of 8), `hold` (true: the phase keeps its values; false:
  every number ramps linearly to the next phase's) and `kinds` (the mix's enemy ids that start appearing in it; the
  earlier phases' stay). The last phase is the **peak** and holds. SC's mix still gives the weights; with a curve its
  `unlock_tier` is not read. `ContentCompiler.compile_floor_spawning(repo, floor)` hangs the floor's compiled curve
  (`CurveTable`) on its `SpawnTable`; a floor without a curve runs SC's plain 30 s tiers. A kind is **new to the run**
  on the first floor whose curve names it (the HUD announces it when it first appears).
  - Validation: `floor_index` ≥ 1 (`floor_index`); phases present (`missing`), none null (`phase`), each named
    (`phase_name`); cap and HP / damage within 1..1000, tier ≥ 0, interval ≥ 1, pack ≥ 0 (`phase_range`); a kind
    named once per curve (`phase_kind`); each phase starts after the one before (`phase_order`) and is never easier
    (tier, cap, HP and damage don't fall, the interval doesn't grow: `phase_ramp`); the first phase starts at 0,
    holds, has tier 0 and opens at least one kind (`calm`). Content tests also hold the shipped curves to: kinds in
    SC's mix, every mix kind on some floor, every kind in before the peak, the peak's tier within SC's tables; the peak's start is tested against
    the measured boss-door times (owner D7, `TuningRun.peak_ticks`).
- **Validation** (`ContentDef.check_permille_table`): a table has 1-64 entries, starts at exactly 1000, every entry is
  within 1..100000 (×100 at most, so the integer products stay small), and HP, damage and per-floor tables never
  fall while the interval table never rises (`table_size`, `table_start`, `table_range`, `table_order`). A floor's
  cap above `cap_max` is `cap_range`; a pack range whose max is under its min, or whose arrays differ in length, is
  `pack_range`; a negative `pack` is `mix_entry`; a negative `edge_band_m` is `negative`.

### Events and curses (v0.5.0 EV)

Compiled by `EventCompiler` (application), beside `ContentCompiler`; the sim reads `EventTable`, `CurseTable` and
`EventRules`. Every number is a starting value.

```gdscript
class_name EventDefinition extends ContentDef          # data/events/*.tres, category "events"
@export var name_key: StringName
@export var desc_key: StringName
@export var weight := 10                               # draw weight among the floor's events
@export var min_floor := 1
@export var requires: StringName = &""                 # "", "curse", "heat", "stat_card", "ability"
@export var choices: Array[EventChoiceDefinition]      # 1..2; the panel always adds "Leave it"

class_name EventChoiceDefinition extends Resource
@export var label_key: StringName
@export var cost: StringName = &"none"                 # none, hp, max_hp, shards, overheat, fight, defend
@export var cost_amount := 0.0                         # % max HP (hp, max_hp), shards per floor, enemies, seconds
@export var reward: StringName = &"stat_epic"          # stat_epic, stat_echo, mod, chest, overclock,
                                                       # ability_level, shards, cleanse
@export var reward_amount := 0.0                       # % Overclock damage, shards per floor
@export var curse: StringName = &""                    # "", "random" (one you don't hold), or a curse id

class_name CurseDefinition extends ContentDef          # data/curses/*.tres, category "curses"
@export var name_key: StringName
@export var desc_key: StringName                       # one %s: the amount
@export var effect: StringName                         # enemy_speed, regen, heat_decay, extra_enemy, prices,
                                                       # elite_chance
@export var amount := 15.0                             # percent (a count for extra_enemy)
@export var threat := 1                                # added to T while held
@export var weight := 10

class_name EventRulesDefinition extends ContentDef     # data/event_rules/floor.tres, category "event_rules"
# rooms_min/max (1-2 per floor), interact_radius_m, clear_radius_m, reward_gap_m (the pedestal's clearance from
# walls and from altar and chest spots), cursed_chest_chance (%), elite_hp_bonus (%), ambush_min_distance_m,
# defend_radius_m
```

Validation: known costs, rewards, effects and requirements; amounts where a cost or reward needs one (an HP cost
below 100 %); a chest reward only after a fight; a choice that costs nothing must carry a curse; 1-2 choices;
`threat >= 1`. Curses differ from the T-indexed `ThreatModifier` above: each has one fixed amount (no table by T);
the `ThreatModifier` tables are still unbuilt.

## 8. Player

```gdscript
class_name PlayerDefinition extends Resource
@export var id: StringName
@export var hp: int
@export var radius_m: float
@export var move_speed_mps: float
@export var primary: PrimaryDefinition   # melee combo (one SwingStepDefinition per step), bolt (v0.1.0; v0.3.0 L11)
@export var dash: DashDefinition          # distance_m, duration_seconds, cooldown_seconds, iframes_seconds
@export var utilities: Array[UtilityDefinition]   # guard and the mobile skill; one is chosen before the run
```

`SwingStepDefinition` (v0.3.0 L11): one melee combo step, in order inside `PrimaryDefinition.combo` (1–8 steps):
`motion` (how the view moves the blade: `SLASH_RIGHT_TO_LEFT`, `SLASH_LEFT_TO_RIGHT`, `THRUST`, `SPIN`),
`active_seconds` (start → the hit, > 0), `recovery_seconds` (the hit → the end; the combo window opens then, except
after the last step), `arc_degrees` (0 < arc ≤ 360, centred on the aim), `reach_m` (> 0, beyond the player's edge),
`damage` (> 0), `hitstop_seconds`, `lunge_m` (0–2 m along the aim, spread over the ticks before the hit, so a
lunging step must hit 2 ticks or more in) and `sweep_seconds` (the blade's crossing time, presentation only).

`UtilityDefinition` (defined in v0.1.0): `id`, `name_key`, `kind` (`GUARD` or `MOBILE`), the timings in seconds,
a cooldown, and `params` checked against the kind's schema.

v0.4.0 BS (owner F11, PD-01 flipped): no utility is chosen before the run. `UtilityDefinition` stays for the forced
loadouts of tests and tools (`ContentCompiler.apply_utility`); in a run, Blink and Aegis are abilities (below).
`PlayerDefinition` gains `crit_chance` (0–1, data 0.05) and `crit_damage` (≥ 1, data 1.5), compiled to per mille.

`AbilityDefinition` (v0.4.0 BS, owner F8; `data/abilities/`, category `ability`): `id`, `kind` (`COMBO_SWORD`,
`PULSE_GUN`, `BOMB_LOBBER`, `DRONE_BUDDY`, `ORBIT_BLADES`, `BLINK`, `AEGIS`; appended, never renumbered),
`activation` (`MANUAL` or `AUTO`), `button` (`NONE` for auto; `PRIMARY` or `UTILITY` for manual, required),
`rarity`, `name_key`, `desc_key`, `start_weapon` (`blade`/`gun`: slot 1 of that build; empty for a card), `tags`
(closed set: melee, bolt, area, auto, utility, weapon, summon, orbit), `cooldown_seconds`, `damage`, `range_m`,
`radius_m`, `speed_mps`, `period_seconds`, `duration_seconds`, `hit_seconds`, and the per-level table: six arrays of
exactly 5 entries (L1–L5): `level_damage`, `level_radius`, `level_rate` (multipliers > 0), `level_count` (≥ 1),
`level_cooldown` (seconds ≥ 0), `level_extra` (≥ 0; per kind: the sword's wave, the gun's pierce, the drone's
chain, the blink's charges, Aegis's charge cap). Each kind validates the fields it reads. Compiled by
`ContentCompiler.compile_abilities` (id order) into `AbilityTable`.

v0.4.0 AB appends three auto kinds, `ARC_FIELD`, `FROST_NOVA` and `FLAME_TRAIL`, the tags `shock`, `frost` and `fire`,
and `engine_item` (an item id; required for those three, and the validator checks the item exists): the item whose
engine numbers (shock threshold and discharge, frost threshold and freeze with its chill, burn damage, period,
duration and stack cap) the ability's status uses when no owned item brings stronger ones. For those kinds
`level_extra` is the status stacks per hit (≥ 1 at every level). Arc Field reads `range_m`, `damage`,
`level_count` (targets) and `level_cooldown` (> 0); Frost Nova `radius_m`, `damage`, `level_radius` and
`level_cooldown` (> 0); Flame Trail `radius_m` (a patch), `period_seconds` (least time between patches),
`duration_seconds` (a patch's life, × `level_rate`), `hit_seconds` (per enemy) and `damage` (× `level_damage`).
Shipped: Arc Field 3 targets within 6 m, 12 damage, 1 shock stack, 1.5 s (−0.1 s and +1 target a level; engine
Static Chain); Frost Nova 3 m (+0.4 m a level), 10 damage, 2 frost stacks (4 from L3: a nova freezes on its own),
every 4 s (3 s at L5; engine Glacial Edge); Flame Trail 0.9 m patches every 0.15 s and 0.8 m of movement, 2 s, 3
damage every 0.5 s (6/s), 1 burn stack, +25 % damage and duration a level (engine Ember Edge).

`ComboDefinition` (v0.4.0 AB) may pair two abilities instead of two items: `ability_a`, `ability_b` (ability ids,
both required and different, never together with `item_a`/`item_b`) and `min_level` (1–5, data 3: both owned at that
level or higher evolve the pair). The effect must be one of the appended ability effects `STORM_BOMBS`,
`NAPALM_DRONE`, `GLACIER_RING`, `BLINK_CHARGE`, `BLADE_DANCE`, `WINGMAN`, `SUPERCONDUCTOR`, `EMBER_WARD`, each
validating the fields it reads (`damage`, `radius_m`, `stacks`, `count`, `share_permille`, `window_seconds`; see
[`../design/INTERACTIONS.md`](../design/INTERACTIONS.md) "Ability combos"). The validator checks both abilities exist
and that no ability pair repeats. Compiled with the item combos (`ComboTable.ability_a/b`, indices in
`compile_abilities` order; `item_a/b` stay −1).

`OverrunDefinition` (v0.4.0 AB; `data/overrun/overrun.tres`, category `overrun`): the Overrun threat branch.
`hp_multiplier`, `damage_multiplier`, `spawn_multiplier` (≥ 1; data 1.5 each), `kills_to_clear` (> 0; data 12) and
`shard_multiplier` (≥ 1; data 2.0). Compiled by `ContentCompiler.compile_overrun` into `OverrunTable` (per mille).

`StatCardDefinition` (v0.4.0 BS, owner F9; `data/stat_cards/`, category `stat_card`): `id`, `stat` (one of
`max_hp`, `damage`, `crit_chance`, `crit_damage`, `attack_speed`, `area`, `cooldowns`, `move_speed`, `regen`,
`shard_gain`, `pickup_range`, `armour`), `name_key`, `desc_key` (one `%s` for the amount), `amounts` (common, rare,
epic; positive, rising; percent, points for crit, percent of max HP per second for regen), `cap` (0 = none; crit
chance and crit damage in percent points, the others as a multiplier: 2.5 = ×2.5, 0.4 = −60 %) and `weight`.
v0.5.0 CP adds five rule stats, appended: `glass_cannon`, `onrush`, `overkill`, `hoarder`, `fast_hands`, and two
fields: `side` (3 positive percents, only for `glass_cannon` (the max HP cut) and `hoarder` (the shard gain)) and
`limit` (only for `glass_cannon` (the lowest max HP multiplier, 0 < limit < 1), `overkill` (the splash reach in m)
and `hoarder` (the most shards that count)); any other stat must leave both empty. Caps of the added stats
(`onrush`, `overkill`, `hoarder`, as for crit and regen) are in percent points. Offers draw a stat by its `weight`.
A stat card's `desc_key` takes a second `%s` for `side` when it has one. Rules: `Stats` (src/sim/abilities).

`RewardsDefinition` (v0.4.0 BS) gains `altar_card_weights` and `chest_card_weights` ([ability, stat, mod]) and
`altar_rarity_weights` and `chest_rarity_weights` ([common, rare, epic]): 3 weights ≥ 0, not all 0.

`DashDefinition.cooldown_seconds` is 1.4 s in `data/player/runner.tres` since v0.3.5 K (owner F12; it was 0.8 s).

`BuildDefinition` (v0.3.0 L15, L16; `data/builds/`): `id`, `weapon` (`BLADE` or `GUN`), `name_key`, `desc_key`,
`damage_permille` (100–5000, the weapon's damage factor) and, since v0.3.5 K (owner F18), `skill`, a required
`SkillDefinition` sub-resource: the build's second ability on the Skill button. Its fields:

| Field | Kinds | Rule |
|---|---|---|
| `kind` | both | `LUNGE_CLEAVE` (the Blade's) or `SCATTER_BLAST` (the Gun's); it must belong to the build's weapon |
| `name_key`, `desc_key` | both | required locale keys (the HUD pip shows the name) |
| `cooldown_seconds` | both | 1 tick to 60 s, counted from the press |
| `damage` | both | 1–1000, per hit (cleave) or per pellet; the build's `damage_permille` applies |
| `heat` | both | 0–100 heat points a landed use adds, once per use |
| `lunge_m`, `lunge_seconds` | Lunge Cleave | (0, 12] m along the facing, over 1 tick to 2 s |
| `arc_degrees`, `reach_m`, `hitstop_seconds` | Lunge Cleave | the cleave's fan (0–360°, (0, 12] m past the user's edge) and its hit-stop (0–8 ticks) |
| `pellets`, `cone_degrees`, `range_m`, `pellet_radius_m` | Scatter Blast | 1–32 rays spread evenly over the cone toward the aim, out to `range_m` past the user's edge |
| `knockback_m`, `knockback_seconds` | Scatter Blast | each enemy hit (not a boss) slides away (0–12 m) |
| `recoil_m`, `recoil_seconds` | Scatter Blast | the user steps back (0–12 m) |

Shipped starting values: Lunge Cleave 3.5 m lunge in 0.2 s, 180° cleave reaching 2.2 m, 28 damage, the finisher's
7-tick hit-stop, 5 heat, 4 s; Scatter Blast 7 pellets over 60°, 4 m, 6 damage each, 1.5 m knockback, 0.8 m step
back, 2.5 heat, 3.5 s. `ContentCompiler.compile_skill` turns it into `SkillTable` on `PlayerTable.skill`
(`apply_build`); outside a build (the kernel and lab worlds) there is none and the Skill button does nothing.

Values come from GA §5 (player kit). Until the gap analysis report is in the repo, v0.0.1 uses starting values,
listed in [`../design/GAME_BLUEPRINT.md`](../design/GAME_BLUEPRINT.md) §C. The owner tunes them during the v0.0.1
Windows check.

## 9. Compiled tables

At encounter start, `ContentCompiler` turns the definitions an encounter needs into plain typed arrays and
dictionaries inside `World`, converting seconds to ticks and resolving ids to indices. `LoadoutCompiler` turns
the player's items and stacks into a `StatBlock` and trigger bindings, and only recompiles when stacks change.
The sim reads these compiled tables, never `Resource`s. In v0.0.1 the compiler handles only `PlayerDefinition`
(to `PlayerTable`), which the app passes to `World.new()`.

## 10. Locale

- `locale/strings.csv` has the columns `keys,en,es`. Godot imports it as two `Translation`s, which are listed in
  `project.godot` under `internationalization/locale/translations` and ship with the export.
- Keys are `UPPER_SNAKE` with a domain prefix: `UI_`, `ITEM_`, `ENEMY_`, `BIOME_`, `HINT_`, `CREDITS_`.
- `tests/content/test_locale_coverage.gd` fails if:
  - a `*_key` in any definition is missing from the CSV;
  - a CSV row has an empty `en` or `es` cell;
  - a `tr("…")` literal in `src/` names a key that isn't in the CSV;
  - a `text = "…"` (or `tooltip_text`) property in a `.tscn` under `src/` holds anything other than a key that is
    in the CSV. Controls auto-translate their `text`, so `.tscn` files hold keys.

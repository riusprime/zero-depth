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
@export var desc_key: StringName          # v0.7.5 CX: the Codex's line about it (a locale key; empty = no line)
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
- **v0.7.5 EF (owner N16) — the fireball enemies.** The Arc Caster's `bolt` and `spread`, the Lens Drone's attack and
  the Bomb Drone's `bomb` are PROJECTILE attacks whose only shape param is `pattern_id`, a `BulletPatternDefinition`
  id (§4b); `ContentCompiler.compile_enemy(def, repo)` resolves it into `EnemyTable.patterns` (one per attack, null
  where none: the rune) through `PatternCompiler.compile_enemy_patterns`, and the attack is active until the
  pattern's last wave. The old bolt/burst/circle params are gone from those schemas. The attack's `damage` is each
  fireball's (and the Bomb Drone's landing's). **Starting values** (`data/bullet_patterns/`):
  `arc_caster_plasma_fan` (FAN 3 over 30 deg, 4 m/s, r 0.18, 13 m, look `arc_plasma`), `arc_caster_plasma_fan_wide`
  (FAN 3 over 56 deg, 3.5 m/s), `lens_drone_orb_ring` (RING 12 with 6 one-shot gaps = 6 orbs, offset 30 deg so one
  flies at the player, 3.5 m/s, r 0.13, 10 m, look `lens_orb`), `bomb_drone_fire_x` (BURST 4 at 45 deg to the throw
  = an X, lob 0.6 s, landing radius 0.5 m, 4 m/s, r 0.15, 7 m, safe radius 0.6 m, look `bomb_cinder`). Windups,
  cooldowns, HP, damage and shards are unchanged.
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
  damage 8, 3 shards, 2 pulses 10 m/s after a 0.5-0.67 s line, keeps 6 m. v0.7.5 EF: its attack is a pattern (a ring
  of 6 slow orbs, `pattern_id` only; above), its windup still 0.5-0.67 s, with no line drawn.
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
**v0.6.0 MX4:** Cluster Payload's, Overclocked Drone's and Afterimage's fields left the item: each names its own
modifier (`data/modifiers/<id>.tres`: an `ON_END` lob of 3 bomblets on the `bomb` spec; `SET heat_rate_permille 8`
on the `drone` spec; a waiting `ON_LAUNCH` burst on the `blink` spec), and the kinds joined `MODIFIER_KINDS`. The
rarity gains `LEGENDARY` (offered only by the boss's legendary tier and a boss's core). The kind `MODIFIER` (31,
appended) is a modifier card of the M-list: it names its own modifier and carries only the engine numbers that
modifier feeds (burn fields, the shock fields, `slow_*`, and Venom Core's poison: `poison_damage`,
`poison_period_seconds`, `poison_seconds`, `poison_max_stacks`, `poison_spread_m`; each set checked when present). The
tag set gains `venom`; a `MODIFIER` card tagged `heat` is offered only in runs with heat. Item indices keep v0.5's
order: the items of the v0.5 kinds by id, then the `MODIFIER` cards by id (`ModifierCompiler.item_defs`).

**Modifiers** (v0.6.0 MX1, category `modifiers`, `data/modifiers/*.tres`; design
[`../design/MODIFIER_ENGINE.md`](../design/MODIFIER_ENGINE.md) §2; sim side
[`SIM_CONTRACTS.md`](SIM_CONTRACTS.md) §8b). A modifier rewrites attack specs. `ModifierDefinition` (a
`ContentDef`, discovered by `ContentScanner` like every definition):

```gdscript
class_name ModifierDefinition extends ContentDef
enum Stage { FORM, PATTERN, BEHAVIOUR, PAYLOAD, HOOK, SCALE }   # appended, never renumbered; v0.6.5 WN1: one card's
                                                                # own op order (across cards: the wand's slot order)
@export var family: StringName            # the card family (CardFrames.FRAME keys: damage, projectile, area, fire, time, ...)
@export var rarity: Rarity                # COMMON, RARE (v0.6.0 MX4: LEGENDARY)
@export var target: PackedStringArray     # tags a spec must all carry (weapon, melee, projectile, skill, ability, area,
                                          # chain, hook, auto; v0.6.0 MX2 the ability modifiers' own attacks: bomb,
                                          # drone, orbit, field, nova, trail; v0.6.0 MX4 the moments: dash, vent,
                                          # move, blink, body); empty = every attack (never a moment)
@export var stage: Stage                  # the stage its ops run in, unless an op names another
@export var ops: Array[ModifierOpDefinition]
@export var overlay: StringName           # optional visual overlay id (design §4); empty in MX1
```

```gdscript
class_name ModifierOpDefinition extends Resource   # a sub-resource of ops
enum Op { SET, ADD, MAX, MIN, MUL_PERMILLE, SET_FORM, STATUS, ELEMENT, HOOK, TRIGGER }   # v0.6.5 WN1: TRIGGER
enum Form { ARC, BOLT, RING, BEAM, ZONE, ORBITER, LOB, BURST, WEAPON }   # MX4: WEAPON, a hook's child only
enum Trigger { ON_HIT, ON_KILL, ON_NTH, ON_END, ON_LAUNCH, EVERY_NTH, ON_CRIT, ON_FINISHER }   # MX4: ON_END..
                                                                # EVERY_NTH; v0.6.5 WN1: ON_CRIT, ON_FINISHER
enum When { ALWAYS, OVERCLOCK }                                         # MX4
@export var op: Op
@export var stage: int = -1               # -1: the modifier's stage
@export var field: StringName             # numeric ops: one of FIELD_STAGE's keys, in content units
@export var value: float                  # MUL_PERMILLE: per mille
@export var form: Form                    # SET_FORM, and a HOOK's attack
@export var status: StringName            # STATUS: burn, shock, bleed, frost, slow (MX4: poison)
@export var stacks: int                   #   stacks a landed hit feeds
@export var every: int                    #   one application every N landed hits (0 = each)
@export var element: StringName           # ELEMENT: ember, storm, frost, venom, void, bleed
@export var hook_trigger: Trigger         # HOOK: when
@export var hook_tags: PackedStringArray  #   the spawned attack's tags (it also gets `hook`)
@export var hook_radius_m: float          #   a BURST's radius (MX2: also a LOB's blast, a ZONE's, a RING's)
@export var hook_reach_m: float           #   a BEAM's jump reach (MX2: a LOB's throw along the parent's way)
@export var hook_damage: int              #   flat damage, or
@export var hook_damage_permille: int     #   a share of the parent's base damage (at least 1)
@export var hook_every: int               #   fires every Nth time (0 = each)
@export var hook_effect: StringName       #   the effect id its hits carry
@export var hook_delay_seconds: float     #   MX4: the child waits this long after its trigger (0 = at once)
@export var hook_when: When               #   MX4: ALWAYS, or only at Overclock
@export var hook_ops: Array[ModifierOpDefinition]  # MX4: shape the child before the build compiles it (no HOOK, no SET_FORM)
@export var hook_trigger_gun: int = -1    # v0.6.5 WN1 (TRIGGER): the trigger on a Gun run, when it differs (-1: same)
```

- **Fields and stages** (`ModifierOpDefinition.FIELD_STAGE`): PATTERN `count`, `spread_degrees`,
  `repeat_delay_seconds`, `repeat_damage_permille`; BEHAVIOUR `bounces`, `pierce`; PAYLOAD `damage`,
  `damage_permille`, `nth_every`, `nth_damage_permille`, `hitstop_seconds`; SCALE `arc_degrees` (the full width),
  `reach_m`, `reach_bonus_permille`, `radius_m`, `speed_mps`, `life_seconds`, `period_seconds`,
  `rate_bonus_permille`. `SET_FORM` runs in FORM, `STATUS` and `ELEMENT` in PAYLOAD, `HOOK` in HOOK. v0.6.0 MX4
  (SIM_CONTRACTS §8d): FORM `mirror`; PATTERN `directions` (0 forward, 1 circle), `back_damage_permille`,
  `aim_offset_degrees`; BEHAVIOUR `chains`, `homing_dps` (degrees per second), `returns`, `orbit_seconds`,
  `intangible`; PAYLOAD `pull_m`, `barrier_seconds`, `charge_seconds`, `charge_permille`, `resonance_permille`; SCALE
  `heat_rate_permille`, and the virtual `range` (`MUL_PERMILLE` on whichever field is the form's range).
- **Validation** (`ERROR`): id; a known family; rarity; known target tags, none twice; at least one op; each op a
  known kind and, for a numeric op, a known field; each op's effective stage equal to the stage its kind or field
  belongs to; `MUL_PERMILLE` > 0; a known status with stacks > 0 and every >= 0; a known element; a known form; a
  hook on a known trigger with known tags, spawning a `BURST` (radius > 0) or a `BEAM` (reach > 0); v0.6.0 MX2 also
  a `LOB`, a `ZONE` or a `RING` (radius > 0; the lingering times are the compile's: `Modifiers.HOOK_LOB_TICKS`,
  `HOOK_ZONE_TICKS`, `HOOK_ZONE_GAP`, `RING_TICKS`), with damage or a damage share > 0, every >= 0. v0.6.0 MX4: also
  a `BOLT` or an `ARC` (radius or reach > 0) and a `WEAPON` copy (no size); the triggers `ON_END`, `ON_LAUNCH` and
  `EVERY_NTH` (every >= 2); a delay >= 0; a known `when`; each of `hook_ops` neither a hook nor a form change, with a
  known field, status or element.
- **Compile** (`ModifierCompiler`, application): seconds to ticks (`SimTick.seconds_to_ticks`), degrees to 1/4096
  turns (`ContentCompiler.degrees_to_units`; `arc_degrees` to the half width), m/s to m per tick, integer fields
  rounded once; `MUL_PERMILLE` values stay per mille. The same functions the item compiler used, so a migrated item
  keeps its exact numbers.
- **v0.6.0 MX2: the modifier slots.** A card that names modifiers (an item, or an ability: `AbilityDefinition.
  modifiers`), and every ability mod (`requires_ability`), is a modifier card: it takes one of the six slots and
  its modifiers compile in slot order (SIM_CONTRACTS §8c). Shipped in MX2: `frost_nova` (Frost Nova's frost element:
  target `weapon`, 1 frost stack a hit and the `frost` element) and `razor_orbit` (Razor Orbit: target `orbit`, 1
  bleed stack and the `bleed` element; the bleed engine's numbers stay on the item). 16 modifiers in MX2.
- **v0.6.0 MX4: the M-list.** 29 new cards (M1–M30; M3 Frost Core is the v0.5 item, generalised), 3 legendary
  versions for the boss's tier (Tempest Core, Inferno Core, Echo Storm) and the three ability mods' own modifiers:
  51 modifiers in all. Each card's ops, target and numbers are the table in
  [`../roadmap/v0.6.0/evidence/MODIFIER_ENGINE_4.md`](../roadmap/v0.6.0/evidence/MODIFIER_ENGINE_4.md); every number
  is a starting value.
- **v0.6.5 WN1: the wand** (design [`../design/WAND.md`](../design/WAND.md); sim side
  [`SIM_CONTRACTS.md`](SIM_CONTRACTS.md) §8e). The compile reads the slots left to right; a card's own ops keep
  their stage order. **Triggers:** a modifier whose one op is `TRIGGER` (stage HOOK) is a trigger: `hook_trigger` is
  one of `ON_HIT`, `ON_KILL`, `ON_END`, `ON_FINISHER`, `ON_CRIT` (`ModifierOpDefinition.WAND_TRIGGERS`), and
  `hook_trigger_gun` (-1, or one of those) the trigger on a Gun run. Validation (`trigger`, `range`): a trigger
  modifier has its one op only; a wand trigger; only a trigger card (`ItemDefinition.Kind.TRIGGER`, 32, appended)
  names a trigger modifier, and it names exactly one (`ModifierDefinition.cross_check`). Shipped (placeholder names
  and looks until WN5): `trigger_on_hit` (On Hit / Al Impactar), `trigger_on_kill` (On Kill / Al Matar),
  `trigger_on_end` (On End / Al Terminar), `trigger_on_finisher` (On Finisher / On Crit; Al Rematar / Al Crítico:
  `ON_FINISHER`, the Gun's `ON_CRIT`); each an item of kind `TRIGGER` tagged `trigger` (a new item tag), family
  `time` (silver, a placeholder frame), common. Trigger cards are never offered yet (`ItemPool` skips the kind; WN5
  opens their pool); item indices
  put them after the `MODIFIER` cards (`ModifierCompiler.item_defs`: v0.5 kinds by id, `MODIFIER` by id, `TRIGGER`
  by id), so every earlier index names the same card. 55 modifiers, 67 items.
- **v0.6.5 WN3: the Gun pool** (WAND.md G1–G16; sim side [`SIM_CONTRACTS.md`](SIM_CONTRACTS.md) §8f). New op
  fields: PATTERN `twin` (more bolts side by side); BEHAVIOUR `spiral_degrees` (the corkscrew's swing),
  `mine_seconds` (a mine's wait after its flight); PAYLOAD `hold_seconds`, `hold_permille` (Charge: the time to a
  full charge and the size and damage it reaches). `ModifierOpDefinition.per_level: float` (default 0): added to the
  op's value per card level above 1, in the op's own units (a `HOOK` op: to `hook_damage_permille`); only a numeric
  op or a hook may carry one (`range`). Items: a new kind `WAND` (33, appended; a wand card of a weapon's pool) and a
  new item tag `wand` (a card that levels up 1–5: `CardLevels`); a `WAND` item is tagged `wand` (`tags`) and a `wand`
  card names modifiers (`missing`). `requires_weapon` is the pool: the Gun's cards say `gun`. Shipped: 12 new
  modifiers and `WAND` items (`gun_big_shot`, `gun_rapid_fire`, `gun_twin`, `gun_spread`, `gun_pierce`,
  `gun_ricochet`, `gun_homing`, `gun_spiral`, `gun_mine`, `gun_charge`, `gun_echo`, `gun_backfire`; names
  `ITEM_GUN_*` in en and es) and four v0.6 cards turned Gun wand cards with their ids kept (`split_shot` G5, its
  shards 0.08 m and + 1 a level; `boomerang` G9; `orbit_rounds` G10; `halo_shot` G16), each with its level steps;
  `seeker`, `twin_cast`, `rearguard` now `requires_weapon` blade. Item indices: v0.5 kinds by id, `MODIFIER` by id,
  `TRIGGER` by id, then `WAND` by id. 67 modifiers, 79 items. Every number is a starting value.
- **v0.6.5 WN1: `WandDefinition`** (category `wand`, `data/wand/wand.tres`, its own file so the dev panel's tuning
  data merges beside it; compiled by `WandCompiler` into `WandTable`, `World.wand_table`):

  ```gdscript
  class_name WandDefinition extends ContentDef
  const MAX_SLOTS := 8
  @export var slots_per_floor := PackedInt32Array([4, 6, 8])   # the wand's slots on floor f (entry f − 1; last repeats)
  @export var child_size_permille := 600                       # a trigger's child spell: the basic attack's size (a
  @export var child_range_permille := 600                      #   bolt's radius, a slash's reach), a bolt's flight
  @export var child_damage_permille := 500                     #   and the share of the hit that set it off
  ```

  Validation: `slots_per_floor` 1..64 entries, each 1..`MAX_SLOTS` and never lower than the one before
  (`table_size`, `range`, `table_order`); the three shares 1..10000 (`range`). Every number is a starting value.
- **v0.6.5 WN4: the Blade pool** (design [`../design/WAND.md`](../design/WAND.md) B1–B16; sim side
  [`SIM_CONTRACTS.md`](SIM_CONTRACTS.md) §8g). New op fields (`ModifierOpDefinition.FIELD_STAGE`): `motion` (FORM;
  `SwingStep.Motion`: 2 thrust, 3 spin), `echo_mirror` (PATTERN), `step_m` (BEHAVIOUR), `parry`, `counter_seconds`,
  `counter_permille`, `carry`, `knockback_m` (PAYLOAD), `line_m` (SCALE). `ModifierOpDefinition.When.COUNTER` (2: the
  hook fires only on a slash that counters). New target tags `wave` (a flying slash) and `finisher` (the combo's last
  step). An `ORBITER` hook is allowed (it needs `hook_reach_m`, its orbit's radius; with `orbit_seconds` in its
  `hook_ops` it lingers). **Levels:** WN3's (`ModifierOpDefinition.per_level`, the item tag `wand`; the WN3/WN4 merge
  kept one system: a hook's `hook_ops` carry their own `per_level`). **Pool cards:** `ItemDefinition.Kind.WAND` (33,
  as WN3), indexed after the Gun pool's cards (`ModifierCompiler.item_defs`: v0.5 kinds, `MODIFIER`, `TRIGGER`, then
  `WAND` pool by pool in `ModifierCompiler.WAND_POOL_ORDER` (gun, blade, both), each by id); a `WAND` card tagged
  `blade` requires the blade and the other way round (`range`). Shipped: B1 `wide_arc` (now Blade-only, +60° arc
  +30 % reach), B2 `echo_slash` (Wave), B12 `long_shadow` (Afterimage, Blade-only) and B15 `blade_orbit` (Orbit
  Blades: no longer an Orbit Blades merge) keep their ids, kinds and indices; B3 `split_wave`, B4 `whirl`, B5
  `double_slash`, B6 `thrust`, B7 `heavy`, B8 `flurry`, B9 `fissure`, B10 `chain_cut`, B11 `parry_edge`, B13
  `lunge_step`, B14 `finisher_plus`, B16 `counter` are new `WAND` items; all 16 `requires_weapon = blade`, tag
  `blade` and `wand` (levels 1–5). Each card's ops and numbers: the table in
  [`../roadmap/v0.7.0/evidence/WAND_BLADE.md`](../roadmap/v0.7.0/evidence/WAND_BLADE.md). With WN3's Gun pool: 79
  modifiers, 91 items.
- **v0.6.5 WN4: `BladeFormsDefinition`** (category `wand`, id `blade_forms`, `data/wand/blade_forms.tres`; compiled
  by `BladeCompiler` into `BladeTable`, `World.blade_table`): the runner numbers no card's ops name.

  ```gdscript
  class_name BladeFormsDefinition extends ContentDef
  @export var orbit_max := 6                  # Orbit Blades: blades at once (the oldest leaves); 1..32
  @export var orbit_turns_per_second := 1.0   #   their turn round the hero
  @export var orbit_gap_seconds := 0.2        #   a blade rests this long after a hit
  @export var knock_seconds := 0.13           # Heavy: the knockback slides over this long
  @export var lunge_seconds := 0.1            # Lunge Step: its step is spread over at least this long
  @export var min_rate_permille := 250        # a swing is never slower than this share of its speed; 50..1000
  ```

  Validation: the counts and shares in range (`range`), the times positive (`not_positive`). Every number is a starting
  value.
- **v0.6.5 WN5a: the shared pool and the triggers offered** (design [`../design/WAND.md`](../design/WAND.md) S1–S7,
  T1–T4; sim side [`SIM_CONTRACTS.md`](SIM_CONTRACTS.md) §8h). New `ItemDefinition` fields (appended):
  `bleed_move_period_seconds: float` (S5: the bleed's period while the player moves; 0 = none; when set, under
  `bleed_period_seconds`: `range`), `name_key_gun` / `desc_key_gun: StringName` (T4: the card's face on a Gun run;
  empty = the same face; both or neither: `missing`). A `WAND` card may bring an engine's numbers like a `MODIFIER`
  card (burn, poison, and the bleed's without a dash burst). The shared pool's cards are `requires_weapon = ""`
  (offered in both runs) and tagged `wand` (levels 1–5). Five v0.6 cards that already did the job keep their ids,
  kinds and item indices and become the shared cards: S1 Fire `ember_core` (its kill burst + 10 % a level), S2
  Lightning `storm_core` (its chain + 10 % a level), S3 Frost `frost_core` (a new `MUL_PERMILLE damage 1000`,
  + 50 ‰ a level), S4 Venom `venom_core` (the same), S6 Void `gravity_well` (a new `ELEMENT void` on the spell; its
  pull + 10 % a level); their names became Fire / Fuego, Lightning / Rayo, Frost / Escarcha, Venom / Veneno, Void /
  Vacío. Two new `WAND` items and modifiers: S5 `shared_bleed` (`STATUS bleed 1`, `ELEMENT bleed`,
  `MUL_PERMILLE damage 1000` + 50 ‰ a level; the bleed 1 a stack every 0.5 s, 0.25 s while moving, 4 s, 8 stacks;
  Bleed / Sangrado) and S7 `shared_explosive` (a `HOOK ON_END BURST` 1.4 m at 600 ‰, + 100 ‰ a level, effect
  `shared_explosive`, its child `ELEMENT ember`; Explosive / Explosivo), both target every attack, indexed in the
  shared pool (`WAND_POOL_ORDER`'s `""`, after the Blade's) by id. Triggers: `ItemPool` offers kind `TRIGGER` now;
  `trigger_on_finisher` is On Finisher / Al Rematar, with `name_key_gun` On Crit / Al Crítico. 81 modifiers, 93 items.
  Every number is a starting value.
- **v0.6.5 WN5b: `WandMigrationDefinition`** (category `wand`, id `migration`, `data/wand/migration.tres`; design
  [`../design/WAND.md`](../design/WAND.md) "What happens to the v0.6 cards", the full table there): the one table that
  retires the v0.6 cards and says what each becomes. Read by `WandCompiler.from_repo` into `WandTable.migrate_*`
  (sim: `WandMigration`, SIM_CONTRACTS §8i) and by `ContentCompiler.compile_items` / `compile_abilities`
  (`WandCompiler.retire_items` / `retire_abilities`: `ItemTable.retired`, `AbilityTable.retired`).

  ```gdscript
  class_name WandMigrationDefinition extends ContentDef
  @export var old_ids: Array[StringName] = []     # the retired cards: item ids or ability ids (43 in the data)
  @export var blade_into: Array[StringName] = []  # what each becomes on a Blade run (&"": refunded as shards)
  @export var gun_into: Array[StringName] = []    # ... on a Gun run
  @export var pending: Array[StringName] = []     # targets another step brings (WN5a's S1–S7), allowed to be missing
  ```

  Validation: the three arrays one entry each (`table_size`), no empty or repeated old id (`missing`,
  `duplicate_id`), no target that is itself retired (`retired_target`); cross-check: every old id names an item or an
  ability, every non-empty target an item or a `pending` id (`unknown_item`). A retired card is never offered (altars,
  chests, the shop, events, cores, the legendary tier, the overrun); it is not deleted, so old saves and item indices
  still resolve and the dev panel can still grant it. The shared-pool targets are WN5a's ids: `ember_core` (S1),
  `storm_core` (S2), `frost_core` (S3), `venom_core` (S4), `gravity_well` (S6), kept v0.6 cards and never retired, and
  `shared_bleed` (S5), `shared_explosive` (S7), new cards listed in `pending` until WN5a merges.
- **v0.6.5 WN5b: legendary triggers.** `ModifierOpDefinition.hook_casts` (TRIGGER only, 1..3; else `range`): the
  cut's child spell is cast that many times per trigger, each `hook_delay_seconds` after the one before. Three
  `TRIGGER` items of rarity `LEGENDARY` (`trigger_on_hit_twice`, `trigger_on_kill_twice`, `trigger_on_end_twice`;
  `ITEM_TRIGGER_ON_*_TWICE` en + es; 2 casts, 0.15 s apart, starting values), indexed after every pool
  (`ModifierCompiler.item_defs`), offered only by the legendary tier (and a boss's core, which draws from its `mods`).
  Content: 82 modifiers, 94 items.
- **Items name their modifiers.** `ItemDefinition.modifiers: Array[StringName]` lists the modifier ids an item brings
  into the build, in order; `ContentCompiler.compile_item(def, repo)` compiles them into `ItemTable.modifiers`. The 14
  item kinds whose effects are attack rewrites (`ItemDefinition.MODIFIER_KINDS`: Long Edge, Twin Arc, Ember Edge,
  Splinter Shot, Rapid Coil, Ricochet Core, Overcharge, Static Chain, Frost Core, Cinder Shot, Conductor, Serrated
  Edge, Barbed Bolts, Glacial Edge) must name at least one (`missing`), and `ContentValidator` checks every named id
  exists (`unknown_modifier`). Each ships a modifier of its own id. Their attack fields left the item
  (`reach_bonus_permille`, `echo_*`, `split_*`, `fire_rate_bonus_permille`, `bounces`, `overcharge_*`,
  `shockwave_*`, `chain_*`, `stack_every`, and `stacks_per_hit` where only a weapon hit used it); the engine numbers
  stay on the item (`stacks_per_hit` stays on Static Chain and Overcharge: their jump and shockwave feed shock).
  Shipped values (MX1, migrated unchanged): Long Edge `ADD reach_bonus_permille 350` (SCALE); Twin Arc
  `SET repeat_delay_seconds 0.1`, `MAX repeat_damage_permille 500` (PATTERN); Splinter Shot `MAX count 3`,
  `MAX spread_degrees 12` (PATTERN), `SET damage_permille 600` (PAYLOAD); Rapid Coil `ADD rate_bonus_permille 400`;
  Ricochet Core `ADD bounces 1`; Overcharge `SET nth_every 4`, `SET nth_damage_permille 2000`, a `HOOK` `ON_NTH`
  `BURST` radius 2 m at 500 ‰ (`overcharge`); Static Chain `STATUS shock 1 every 2`, `ELEMENT storm`, a `HOOK`
  `ON_HIT` `BEAM` reach 4 m, 5 damage, every 3 (`static_chain`); Frost Core `STATUS slow`, `STATUS frost 1 every 3`,
  `ELEMENT frost`; Cinder Shot `STATUS burn 1 every 3`, `ELEMENT ember`; Conductor `STATUS shock 1`,
  `ELEMENT storm`; Serrated Edge `STATUS bleed 1`, `ELEMENT bleed`; Barbed Bolts `STATUS bleed 1 every 2`,
  `ELEMENT bleed`; Glacial Edge `STATUS frost 1`, `ELEMENT frost`; Ember Edge `STATUS burn 1`, `ELEMENT ember`.
  Melee ones target `[weapon, melee]`, bolt ones `[weapon, projectile]`, so none touches the Skills (as in v0.5).
- No modifier has a `name_key`: in MX1 the card is still the item. Modifier cards, slots and Swap are MX stage 2.

**Rewards** (v0.3.0 E, category `rewards`, `data/rewards/floor.tres`): `RewardsDefinition` holds the floor's
altar and chest counts (inclusive ranges), `chest_prices` by chest order on floor 1, `floor_price_step` (each
later floor adds that share of the floor-1 price), `rare_weight_chest` / `rare_weight_altar`, `offer_size` (1..3),
`interact_radius_m` and `shard_tier_bonus`. Validation: ranges ordered and non-negative, prices positive, weights
and the radius positive. v0.4.0 TU (owner D8): `heal_orb_chance` (0.1: a normal enemy's kill drops a heal orb, one
loot-stream roll), `heal_orb_heal` (0.25 of max HP) and `heal_orb_reach_m` (0.9 m, × the pickup-range stat); both
shares within 0..1 (`range`), the reach positive. v0.5.5 EC: `heal_orb_chance` is a base under the Lifesprout stat
card and ships 0 (owner D9: orbs only with the card); `altars_cap` (2, owner S1: the floor's placed altars past it
become chests, the same draws and spots; 0 = no cap; ≥ 0) and `shard_scale` (0.7, owner S4: every kill's shards ×
this, rounded half up; > 0).

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
the steps non-negative; the shares in (0, 1]; `offer_size` 1–9. v0.5.5 EC: a reroll draws only the unsold slots (a
bought slot stays sold for the floor, owner S2); `max_buys` (4, owner S3: cards bought at the floor's shop, the heal
and rerolls don't count; 0 = no limit; ≥ 0); `late_floor_price` (1.5, owner S4: floors 2+ multiply the floor step
by this: × 1, 2.25, 3; salvage refunds stay on the floor step alone; ≥ 1). v0.7.5 MG (owner N12, "the shop is
also gonna be there every two … floors"): `first_floor` (1) and `every_floors` (2), both > 0: the shop stands on
floor `first_floor` and every `every_floors` floors after it (`FloorCadence.on`, `ShopTable.on_floor`: floors 1, 3,
5 …; a 3-floor run has two). The floor number keeps counting past the run's last floor, so an endless loop keeps
the rhythm. On a floor without the shop, `FloorScenario.add_shop` places nothing; the room `ShopPlacement` would take
stays an ordinary room (still never an arena, so the floor's other picks don't move).

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
@export var desc_key: StringName                   # v0.7.5 CX: the Codex's line about it (empty = no line)
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
                                                   # v0.5.5 DS: every shipped boss has 1000 / 660 / 330 (each later phase opens with a gate)
@export var arena_cells: Vector2i                  # the boss room's size in cells
@export var arena_template: int                    # its interior (FloorLayout.Template; BossSchemas.ARENA_TEMPLATES)
@export var legacy_arena_cells: Vector2i           # v0.7.5 BF1 (N18): the room before every boss went 4 x 4; a floor of an
                                                   # older save (floor rules 1-2) is rebuilt with it ((0, 0) = arena_cells)
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

- **v0.7.5 BF1 (owner N15, dodge-first fights; [`BOSS_FIGHTS.md`](../design/BOSS_FIGHTS.md)).** Boss attacks also
  take `lock_seconds: float` (0 = as before) and `shielded: bool`. With a lock, the marker follows the player's exact
  position (no lead) for `telegraph_seconds - lock_seconds`, then holds and flashes for `lock_seconds` (at least
  `MIN_TELEGRAPH_TICKS`, and under the telegraph) before it strikes. `shielded` (the signature pattern) keeps the boss
  shielded through its windup and active time. Three new moves:
  - `pattern` (PROJECTILE): `pattern_id`, a `BulletPatternDefinition` id (§4b). The attack is active for the
    pattern's whole duration (`active_seconds` is a floor). `damage` is each fireball's.
  - `marks` (CIRCLE): `count` ground circles of `radius_m`, `stagger_seconds` apart, each tracked then locked
    (`lock_seconds` required). Active until the last strikes.
  - `row_lanes` (LINE): `count` crosses of two lanes (the player's row and column), `length_m` long, `width_m` wide,
    `stagger_seconds` apart, tracked then locked like `marks`; cut short by walls.
- **v0.7.5 BF2 (the Brood Mother and the Hive Lens).** A move may take optional params (`BossSchemas.MOVES[move]
  ["optional"]`; any other unknown key is still an `ERROR`):
  - `marks` + `pattern_id` (a BURST, §4b): each circle is an egg's landing; while it is locked an egg flies onto it,
    and as it strikes the pattern's waves burst from it (the pattern's lob is the circle's lock; `land_radius_m` is
    unused, the circle's `radius_m` is the landing). Active until the last egg's burst has fired.
  - `burrow` + `pattern_id` (a RING): a ring of shots bursts from the eruption, its gap on the player. A `burrow`
    with `lock_seconds` lays its eruption circle on the player's exact position while the ripple tracks
    (`track_seconds`), then holds it for `erupt_seconds` (set it to the lock, 0.8 s) and erupts there.
  - The Hive Lens's Focus Beam is a `lanes` attack (count 1, or 3 in phase 3) with `lock_seconds`.

### 4b. Bullet patterns (`data/bullet_patterns/*.tres`, v0.7.5 BF1)

```gdscript
class_name BulletPatternDefinition extends ContentDef   # category bullet_patterns; in the F10 panel's Bosses page
enum Kind { RING, SPIRAL, FAN, CROSS, WALL, FLOWER, BURST }
@export var kind: Kind
@export var look: StringName            # the fireball's look key (FireballViews.LOOKS; required): each boss/enemy its own
@export var speed_mps: float            # 1.5..7 ("slow": about 3-5)
@export var radius_m: float             # each shot's radius
@export var range_m: float              # how far a shot flies (life = range / speed); shots stop at walls
@export var waves: int                  # >= 1 ...
@export var wave_gap_seconds: float     # ... this far apart (>= a tick when waves > 1)
@export var turn_per_wave_degrees: float  # each wave turns by this from the last ...
@export var alternate: bool             # ... or, set, every other wave only (a fan's "offset each wave")
@export var aim_offset_degrees: float   # the first wave's base angle from the aim at the player
@export var safe_radius_m: float        # no shot spawns within this (+ the player's radius) of the player (>= 0.5)
@export var count: int                  # RING / FAN / FLOWER / BURST: shots a wave (1..64; a burst's star <= 16)
@export var gap_count: int              # RING: gaps (>= 1) ...
@export var gap_width: int              # ... each this many shots left out; the gap must be >= 1 m wide 4 m out
@export var spread_degrees: float       # FAN: 0 < spread <= 300
@export var arms: int                   # SPIRAL / CROSS: streams (1..8)
@export var spin_dps: float             # SPIRAL / CROSS: their turn (degrees a second; negative = clockwise)
@export var reverse_at_seconds: float   # SPIRAL: the turn reverses this long after the first wave (0 = never)
@export var wall_length_m: float        # WALL: shots spacing_m apart across the aim, marching along it ...
@export var spacing_m: float            #   (<= 64 shots a wall)
@export var gap_m: float                # ... with a gap (>= 1 m) gap_offset_m off the aim line, moving
@export var gap_offset_m: float         #   gap_shift_m a wave and bouncing between the wall's ends
@export var gap_shift_m: float
@export var crossing: bool              # WALL: a second wall at right angles (the Warlord's phase 3)
@export var petals: int                 # FLOWER: speed follows |cos(petals × angle / 2)| (a table lookup), 2..12 ...
@export var petal_min_permille: int     # ... from this share of the speed in a valley ...
@export var petal_cut_permille: int     # ... and shots under this are left out (100..900): the gaps between petals
@export var lob_seconds: float          # BURST: the shell flies this long to the attack's locked target ...
@export var land_radius_m: float        # ... lands as a marker of this radius (it hurts), and bursts into its star
```

v0.7.5 EF: enemies fire patterns too (§3, "the fireball enemies"): an enemy attack names one with `pattern_id`. A
Bomb Drone's BURST draws no landing marker (owner N16): its flying fireball is the cue.

Compiled by `PatternCompiler.compile_pattern` into a `BulletPatternTable` (sim units) that the boss attack carries
(`BossAttackTable.pattern`); `BulletPatterns` fires it (SIM_CONTRACTS §10d). Every number is a starting value (F10).

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

### Floor generation (`data/map/floor.tres`, v0.7.5 MG)

`MapDefinition` (category `map`; owner N9, "make maps bigger the rooms … even bigger rooms … up to 20 rooms"): the
generator's room numbers, compiled by `RunContentCompiler.compile_map` over `FloorParams.defaults()` (whose values
equal the file's; a test keeps them equal, so a floor built without content is the floor the run builds).
`rooms_min` / `rooms_max` (15 / 19: rooms before the boss room, the start hall included; the boss room makes 16-20),
`footprint_x` / `footprint_y` / `footprint_weights` (parallel arrays: footprint k is x × y cells, drawn with its
weight; 1×1 22, 2×1 14, 1×2 14, 3×1 8, 1×3 8, 2×2 12, 3×2 7, 2×3 7, 3×3 5, 4×3 2, 3×4 2 and the extra-large 4×4 2),
`max_span` (11 cells: the floor's extent either way, the boss room aside) and `place_attempts` (600). The rest of
`FloorParams` (cell size, walls, doorways, spots) stays code. Validation: 2 ≤ min ≤ max ≤ 19, the three arrays the
same non-empty length, footprints 1-4 cells a side, weights ≥ 0 with a positive sum, span 5-16, attempts > 0.
A floor resumed from a save made before v0.7.5 is rebuilt with v0.7.0's numbers (`FloorParams.v070()`, an arena share
of 330 per mille and a shop on every floor; `RunState.floor_rules`, `RunSaver.floor_tables`), so its snapshot fits.

## 6. Biomes

```gdscript
class_name BiomeDefinition extends Resource
@export var id: StringName                # ruins, night_rocks, red_canyon, frozen_shore, starfall, …
@export var name_key: StringName
@export var desc_key: StringName          # v0.7.5 CX: the Codex's line about it (empty = no line)
@export var palette: Dictionary           # token -> Color; keys from docs/art/ART_DIRECTION.md §2
@export var props: Array[PropDefinition]  # rocks, grass, trees, fences, barrels; mesh + placement rules
@export var enemy_weights: Dictionary     # enemy_id -> weight for this biome's encounter fill
@export var hazard_flavour: StringName    # mild flavour only, e.g. &"ice_edge"; never a difficulty step
@export var template_tags: PackedStringArray
@export var mood: BiomeMood               # v0.5.9: the lighting mood StageView lights the floor with
@export var surface: BiomeSurface         # v0.7.5 NB1/NB2: ground that plays differently (ice, starglow); null for none
@export var look: BiomeLook               # v0.7.5 NB1: own dressing, edge and enemy cast; null = hand-written look
```

- **The Codex (v0.7.5 CX)** lists every biome definition on its Biomes page (`CodexCatalog`), drawn as a small
  landscape in the biome's `palette`, so a new biome shows there with no code. Its `desc_key` (`BIOME_<ID>_DESC`,
  en and es) is the page's line; the shipped biomes, enemies and bosses each have one
  (`tests/content/test_codex_content.gd`).
- `BiomeMood` (v0.5.9 Step 1, `src/content/defs/biome_mood.gd`) holds presentation only, never read by the sim:
  - sun colour, energy and angle;
  - ambient colour and energy;
  - void colour and AgX exposure;
  - SSAO, SSIL and the geometric contact shadow (`contact_radius`, `contact_strength`);
  - fog, glow (intensity, threshold, bloom, spread) and the vignette;
  - the warm light colour, energy and range that fire props use;
  - the hero light's energy and range;
  - the grade: shadow and highlight colours and strength (a split tone), contrast and saturation (the lighting pass
    after v0.6.1, [`docs/art/LIGHTING_PASS.md`](../art/LIGHTING_PASS.md)).

  A missing mood is a `mood_missing` `ERROR`. A value outside its range, or a sun that doesn't point down, is a
  `mood_invalid` `ERROR`.

- `BiomeSurface` (v0.7.5 NB1, `src/content/defs/biome_surface.gd`; Frozen Shore's ice) is the one biome field the
  sim reads, compiled by `BiomeCompiler.compile_ice` into an `IceField` and laid per floor by `IcePatches` from the
  `map:ice` sub-stream (SIM_CONTRACTS §5):
  - `kind` (`&"ice"`, the only kind);
  - `room_share_permille`: the share of rooms that get patches (never the start hall, the boss room, the portal's
    room or the shop's room); `patches_min`..`patches_max` per chosen room;
  - `size_min_m`..`size_max_m`: a patch's sides (0.5 m steps); `clearance_m`: kept from walls, doorways, item spots,
    the start and the gates;
  - `accel_seconds`, `stop_seconds`: the hero's easing on ice (seconds to 90 %), in place of the player's own.

  A value out of range is a `surface_invalid` `ERROR`. Mild flavour only (PD-04): ice never hurts and the dash is
  unchanged on it.

  v0.7.5 NB2 adds a second kind and one field:
  - `kind` is one of `BiomeSurface.KINDS`: `&"ice"` (Frozen Shore) or `&"starglow"` (Starfall's starglow pools);
  - `speed_scale` (0.5..1.5, default 1.0): the hero's top walking speed on the surface, times their own (Starfall
    1.25; ice keeps 1.0, so Frozen Shore plays exactly as in NB1).

  `BiomeCompiler.compile_surface` compiles any kind into an `IceField` (its `kind` and `speed_permille` set);
  `compile_ice` still answers for ice only. `IcePatches` draws each kind from its own sub-stream, `map:<kind>`
  (`map:ice`, `map:starglow`; SIM_CONTRACTS §5). Starglow only helps (never hurts), and the dash is unchanged on it.
- `BiomeLook` (v0.7.5 NB1, `src/content/defs/biome_look.gd`) is presentation only, never read by the sim:
  - `square_cover`: kit piece id -> int weight, what square cover footprints are drawn with (empty: the dresser's
    own rule);
  - `decor_swap`: kit decoration piece -> the piece drawn instead (a kit piece or a code-made `CodeProps` piece);
  - `edge`: what lies past the floor's edge (`&""` the void, `&"water"` the frozen sea, v0.7.5 NB2 `&"stars"` the
    starry void with floating islands; `BiomeLook.EDGES`, drawn by `BiomeEdge`, the stars' pieces in `StarVoid`);
  - v0.7.5 NB2: a `square_cover` piece may be a code-made `CodeProps` piece of role cover (Starfall's
    `star_monolith`), drawn at its own height;
  - `enemy_tint`: the cast enemies' grey parts take (alpha = strength, at most 0.8; red parts, rings and bars never
    change).

  A value out of range or an unknown edge is a `look_invalid` `ERROR`; that every named piece resolves is a
  presentation test (`tests/unit/presentation/test_frozen_shore.gd`, `test_starfall.gd`). A biome without a look
  keeps its hand-written look (Ruins, Night Rocks, Red Canyon).
- A new biome is: `data/biomes/<id>.tres` (palette, mood, optional surface and look), its id appended to
  `data/run/three_floors.tres` `biomes` (last: saves store indices), an ambience cue `data/audio/cues/<id>.tres` and
  its loop (`scripts/audio/generate_sfx.py`), `BIOME_<ID>` and `BIOME_<ID>_DESC` locale keys (en and es), and
  optionally a `ShardCluster.TINTS` row and a `BiomeEdge` style. Shipped (v0.7.5): `ruins`, `night_rocks`,
  `red_canyon`, `frozen_shore` (NB1), `starfall` (NB2; a working name, the owner may rename it).
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
- **`RunDefinition`, v0.5.5 EC (owner Q-S4, "Keep half"):** `shard_carry` (0.5: the share of unspent shards a
  portal carries to the next floor, rounded down; the rest is shown as left behind on the arrival card; 0..1,
  `range`).
- **`RunDefinition`, v0.7.5 AP (owner N4, the Ascension loop; starting values, the owner tunes):** each loop past the
  first multiplies, compounding per loop, normal enemies' HP and damage by `loop_enemy_hp_permille` (4000) and
  `loop_enemy_damage_permille` (2000), bosses' HP and attack damage by `loop_boss_hp_permille` (2000) and
  `loop_boss_damage_permille` (1500), each 1000..`loop_scale_cap_permille` (`range`), the factor never past
  `loop_scale_cap_permille` (100000, × 100); and adds `loop_threat` (2, threat T, ≥ 0, `negative`) and
  `loop_catch_up_cap_permille` (500, to both hidden catch-up caps, ≥ 0, `negative`). `floors` is a loop's length.
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
    has tier 0 and opens at least one kind, and only the first phase may hold (`calm`; v0.5.5 D1: floor 1's first
    phase is a 30 s calm that holds, floors 2–3 start at the warm-up level with no calm). Content tests also hold
    the shipped curves to: kinds in SC's mix, every mix kind on some floor, every kind in before the peak, the
    peak's tier within SC's tables; the peak's start is data (90 s on floor 1, 30 s on floors 2–3, starting values),
    no longer the bots' measured boss-door times (owner P1).
- **Validation** (`ContentDef.check_permille_table`): a table has 1-64 entries, starts at exactly 1000, every entry is
  within 1..100000 (×100 at most, so the integer products stay small), and HP, damage and per-floor tables never
  fall while the interval table never rises (`table_size`, `table_start`, `table_range`, `table_order`). A floor's
  cap above `cap_max` is `cap_range`; a pack range whose max is under its min, or whose arrays differ in length, is
  `pack_range`; a negative `pack` is `mix_entry`; a negative `edge_band_m` is `negative`.

- **`CatchUpDefinition`** (v0.5.5 DS, owner D4 and D7; `data/scaling/catch_up.tres`, category `scaling`, id
  `catch_up`): the hidden catch-up's numbers, all per mille ([`SIM_CONTRACTS.md`](SIM_CONTRACTS.md) §11):
  `expected_power_permille` (E at floor entry, `[1000, 2000, 4000]`), `cap_permille` (`[1500, 2000, 2500]`),
  `boss_expected_power_permille` (E at the floor's end, `[2000, 4000, 7000]`), `boss_cap_permille` (`[2000, 3000,
  4000]`), entry f − 1 and the last repeats; `threat_cap_bonus_permille` (250 per T), and the build's power terms
  `ability_level_permille` (120), `item_permille` (80), `combo_permille` (150). Validation: each table 1-64 entries,
  entries within 1..100000 (caps 1000..100000) and never falling (`table_size`, `table_range`, `table_order`); the
  four single numbers within 0..10000 (`range`). Starting values the owner tunes by play.

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
@export var deep_only := false                         # v0.5.5 DS (S5): Deep floors only, drawn first there
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
@export var effect_2: StringName = &""                 # v0.6.0 CU: a second drawback ("" = none)
@export var amount_2 := 0.0
@export var up_effect: StringName = &""                # v0.6.0 CU: a trade-off's upside ("" = a plain curse)
@export var up_amount := 0.0
@export var up_desc_key: StringName                    # one %s (or none for an on/off effect)
@export var threat := 1                                # added to T while held
@export var weight := 10

class_name EventRulesDefinition extends ContentDef     # data/event_rules/floor.tres, category "event_rules"
# rooms_min/max (1-2 per floor), interact_radius_m, clear_radius_m, reward_gap_m (the pedestal's clearance from
# walls and from altar and chest spots), cursed_chest_chance (%), elite_hp_bonus (%), ambush_min_distance_m,
# defend_radius_m; v0.6.0 CU: core_stagger_share (%), core_stagger_seconds, core_window_seconds, core_mod_weight,
# hunt_range_m, drop_offset_m; v0.7.5 MG: cursed_chest_first_floor (1), cursed_chest_every_floors (2),
# cursed_chests_per_floor (1)
```

v0.7.5 MG (owner N10, "the curse appear too often we're gonna have one every two floors"): a chest's offer rolls
`cursed_chest_chance` only on a curse floor (`EventRules.curse_floor`, `FloorCadence.on`: `cursed_chest_first_floor`,
then every `cursed_chest_every_floors` floors: 1, 3, 5 …), and only while the floor's cursed offers are under
`cursed_chests_per_floor` (`EventState.cursed_rolled`, snapshotted). So at most one cursed chest every two floors.
The chance is still drawn from `loot:event` on every floor before the check, so the stream moves as before until a
chest is refused. Validation: first and every ≥ 1, per floor ≥ 0. The dev route (`force_curse`) skips the rule.

Validation: known costs, rewards, effects and requirements; amounts where a cost or reward needs one (an HP cost
below 100 %); a chest reward only after a fight; a choice that costs nothing must carry a curse; 1-2 choices;
`threat >= 1`. v0.6.0 CU (PLAN v0.5.5 S6, S7): a curse may add `effect_2` / `amount_2` (a second drawback) and
`up_effect` / `up_amount` / `up_desc_key` (the upside of a trade-off curse; `&""` = a plain curse). The effects list
grows (appended, never renumbered): `no_dash`, `dodge`, `attack_slow`, `fourth_hit`, `max_hp_cut`, `crit_chance`,
`ability_hp_cost`, `ability_damage`, `heat_linger`, `overclock_damage`, `no_minimap`, `shard_gain`, `hit_stun`,
`move_speed`, `elite_hunt`, `elite_rare_drop`. Amounts are percent, except the counts (`extra_enemy`, and 1 for the
on/off `no_dash`, `no_minimap`, `elite_rare_drop`) and `hit_stun` in seconds; a cut (`attack_slow`, `max_hp_cut`,
`heat_linger`) is at most 90 %. A trade-off needs `up_desc_key`. Shipped: five plain curses (`leaky_core`,
`price_gouge`, `swarm_call`, `swift_foes`, `withering`) and the eight trade-offs C1-C8 (`rooted`, `heavy_hands`,
`glass_heart`, `blood_price`, `fevered`, `tunnel_vision`, `brittle`, and `marked_hunt`, which became C8 Marked: it
keeps its id and its 12 % elite chance as `effect_2`). The event rules add core theft's numbers: `core_stagger_share`
(%, 30), `core_stagger_seconds` (0.75), `core_window_seconds` (2), `core_mod_weight` (10), `hunt_range_m` (16) and
`drop_offset_m` (0.9).
Curses differ from the T-indexed `ThreatModifier` above: each has one fixed amount (no table by T);
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

v0.6.0 MX2 (owner B7; SIM_CONTRACTS §8c): the six auto abilities are weapon modifiers (each takes one of the six
modifier slots; Blink and Aegis are the utility pick outside them; the starting weapons stay). Appended fields:
`modifiers: Array[StringName]` (ModifierDefinition ids the ability adds while held, at its place in the slot order;
the cross-check reports an unknown one), `every_attacks` (Bomb Lobber: lobs on every Nth weapon attack; > 0 for that
kind), `streak_kills` and `streak_seconds` (Frost Nova's kill streak; > 0 for that kind). Arc Field now reads
`radius_m` (its field), `duration_seconds` (the field's life) and `hit_seconds` (> 0 each), `level_count` as the most
enemies its field hits a tick, `range_m` as how far a shot's field may land. Shipped starting values: Bomb Lobber
every 4th attack (2.5 s cooldown kept); Arc Field 1.6 m, 2 s, every 0.5 s; Frost Nova `modifiers = [frost_nova]`, 4
kills within 2 s of each other. Every other number is v0.5's.

`ComboDefinition` (v0.4.0 AB) may pair two abilities instead of two items: `ability_a`, `ability_b` (ability ids,
both required and different, never together with `item_a`/`item_b`) and `min_level` (1–5, data 3: both owned at that
level or higher evolve the pair). The effect must be one of the appended ability effects `STORM_BOMBS`,
`NAPALM_DRONE`, `GLACIER_RING`, `BLINK_CHARGE`, `BLADE_DANCE`, `WINGMAN`, `SUPERCONDUCTOR`, `EMBER_WARD`, each
validating the fields it reads (`damage`, `radius_m`, `stacks`, `count`, `share_permille`, `window_seconds`; see
[`../design/INTERACTIONS.md`](../design/INTERACTIONS.md) "Ability combos"). The validator checks both abilities exist
and that no ability pair repeats. Compiled with the item combos (`ComboTable.ability_a/b`, indices in
`compile_abilities` order; `item_a/b` stay −1).

`OverrunDefinition` (v0.4.0 AB; `data/overrun/overrun.tres`, category `overrun`): the Overrun threat branch.
`hp_multiplier`, `damage_multiplier` (≥ 1; data 1.5 each), `shard_multiplier` (≥ 1; data 2.0) and, since v0.5.5 AR
(owner S8, replacing `spawn_multiplier` and `kills_to_clear`), `waves_min` / `waves_max` (> 0, max ≥ min; data 3 / 5)
and `wave_sizes` (one positive size per floor, the last repeats; data 4, 8, 12). Compiled by
`ContentCompiler.compile_overrun` into `OverrunTable` (per mille).

`ArenaDefinition` (v0.5.5 AR, PLAN D2 / X1; `data/arenas/arena.tres`, category `arena`): the sealed arenas. `share`
(0..1; data 0.11, was 0.33 until v0.7.5 MG, owner N11 "reduce the amount of challenge rooms … like 20% less": the
share of a floor's combat rooms that are arenas; with the Overrun room a floor averages 2.4 challenge rooms, was 3.2), `waves_min` / `waves_max` (data 2 / 3),
`wave_sizes` (per floor; data 3, 5, 7), `first_wave_seconds` (data 0.75), `wave_gap_seconds` (data 1.0) and
`min_spawn_distance` (m; data 3.0). Compiled by `ContentCompiler.compile_arena` into `ArenaTable` (ticks, per mille).
Without the definition a floor has no regular arenas (the Overrun still seals).

`LegendaryDefinition` (v0.5.5 AR, owner X1b "Pick a legendary card"; `data/legendary/boss.tres`, category
`legendary`): the boss-only legendary tier. `stat_cards` (stat card ids offered at the legendary rarity), `mods` (item
ids), `stat_weight` / `mod_weight` (data 60 / 40), `offer_size` (1..3; data 3) and `stat_multiplier` (≥ 1; data 1.6:
a legendary stat card is its epic amount × this; `compile_stat_cards` appends that fourth rarity to every
`StatTable`). Compiled by `ContentCompiler.compile_legendary` into `LegendaryTable` (indices into the compiled stat
cards and items). v0.6.0 MX4: `mods` are the legendary modifiers: the three legendary versions (Tempest Core,
Inferno Core, Echo Storm; rarity `LEGENDARY`, never in another pool) and the five trinkets (Shock Circles, Halo Shot,
Boomerang, Orbit Rounds, Short Fuse); a boss's core draws from the same list.
v0.6.5 WN5b (WAND.md "The legendary tier offers level-5 versions and a few unique triggers"): `wand_level` (0..5;
data 5): with it every wand card (an item tagged `wand`, of the run's pool) is a pool mod too, and a pick at the
boss's legendary altar takes it at that level (a held one rises to it; `BossReward.on_pick`); `mods` are now the three
legendary triggers (the MX4 legendary versions and trinkets were retired or are wand cards). The pool needs cards:
`stat_cards`, `mods` or `wand_level` (`missing`).

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
v0.5.5 EC (owner D9) appends `lifesprout` (SIDED): the only source of heal orbs. The first card sets a kill's orb
chance to its `amounts` (10 %), every further card adds its `side` (+5 %), read capped at `cap` (30 percent points).

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

### Sim tuning (`data/tuning/sim.tres`, the dev panel's Step 6)

`SimTuningDefinition` (category `tuning`, id `sim`) holds the designer numbers the sim once kept as constants:
spawn-in, a boss's rise and post-stagger wait, phase-gate length, adds and ring, enemy AI commit, strafe, flank,
spread, Sniper relocation and Mender scan, the heal-orb cap, the pickup radius, the fire-patch cap, hit rate and
Flame Trail spacing, the shortest field throw. Seconds, metres and per mille; `RunContentCompiler.compile_sim_tuning`
turns it into `SimTuning` on `World.tuning`. The shipped file equals the old constants (a test checks), which stay
as `SimTuning`'s defaults. A value that must be positive and isn't, or `gate_adds_max < gate_adds_min`, is a
`range` `ERROR`. Map generation (`FloorParams`) is not in it yet.

### Achievements (`data/achievements/*.tres`, v0.7.5 AC)

`AchievementDefinition` (category `achievements`) is one local achievement, read by the app layer only (the sim
never sees it):

```gdscript
@export var name_key: StringName   # ACH_<ID>_NAME; a CODEX_EACH one has a %s for the entry's name
@export var desc_key: StringName   # ACH_<ID>_DESC; the same %s rule
@export var glyph: StringName      # a code-drawn picture (AchievementDefinition.GLYPHS)
@export var group: StringName      # the page's section (GROUPS: run, bosses, biomes, build, combat, risk, codex, ascension)
@export var order := 0             # its place in the group
@export var hidden := false        # "???" until unlocked
@export var kind: Kind             # STAT, CODEX_TOTAL, CODEX_MAX, CODEX_EACH, CODEX_EVERY
@export var stat: StringName       # STAT: a run counter from AchievementDefinition.STATS (e.g. runs:won, runs:ascended)
@export var page: StringName       # CODEX_*: cards / enemies / bosses / biomes
@export var section: StringName    # CODEX_EACH / CODEX_EVERY: one section of the page (e.g. the Gun pool), or all
@export var counter: StringName    # CODEX_*: the page's counter (empty for EACH / EVERY: the entry is met)
@export var target := 1
```

- `CODEX_EACH` expands into one achievement per Codex entry of its page or section, id `<id>_<entry id>`
  (`boss_warlord`, `biome_frozen_shore`), so a new boss or biome in the data has its own with no new file;
  `CODEX_EVERY` needs every entry of its scope (the scope grows with the data).
- `ERROR`s (`achievement`): a missing key, an unknown glyph, group, stat, page or counter, a target under 1, a
  section on a kind that reads none. `tests/content/test_achievement_content.gd` also checks the keys in en and es
  (with the `%s` exactly on the per-entry ones) and that the pages and counters match `CodexStore`.

## 9. Compiled tables

At encounter start, `ContentCompiler` turns the definitions an encounter needs into plain typed arrays and
dictionaries inside `World`, converting seconds to ticks and resolving ids to indices. `LoadoutCompiler` turns
the player's items and stacks into a `StatBlock` and trigger bindings, and only recompiles when stacks change.
The sim reads these compiled tables, never `Resource`s. In v0.0.1 the compiler handles only `PlayerDefinition`
(to `PlayerTable`), which the app passes to `World.new()`.

## 10. Locale

- `locale/strings.csv` has the columns `keys,en,es`. Godot imports it as two `Translation`s, which are listed in
  `project.godot` under `internationalization/locale/translations` and ship with the export.
- Keys are `UPPER_SNAKE` with a domain prefix: `UI_`, `ITEM_`, `ENEMY_`, `BIOME_`, `HINT_`, `CREDITS_`
  (v0.7.5 AC: `ACH_` for the achievements' names and sentences).
- `tests/content/test_locale_coverage.gd` fails if:
  - a `*_key` in any definition is missing from the CSV;
  - a CSV row has an empty `en` or `es` cell;
  - a `tr("…")` literal in `src/` names a key that isn't in the CSV;
  - a `text = "…"` (or `tooltip_text`) property in a `.tscn` under `src/` holds anything other than a key that is
    in the CSV. Controls auto-translate their `text`, so `.tscn` files hold keys.

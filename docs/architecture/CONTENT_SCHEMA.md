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
- `stress_tags` feed the enemy × archetype stress matrix in [`../balance/SCORECARD.md`](../balance/SCORECARD.md).

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
```

- Phases are ordered by descending `hp_threshold_permille`. The first phase starts at 1000.
- Each attack's `move` has a param schema in `src/content/boss_schemas.gd` (the shape and the `shape_params` keys);
  missing or unknown keys are `ERROR`s. Every attack's `telegraph_seconds`, and a burrow's `erupt_seconds` (the
  eruption's own mark), compile to at least `MIN_TELEGRAPH_TICKS`. Every attack names a `cause_key` (the death
  recap line).
- `BossPoolDefinition` (`data/boss_pools/floor_<n>.tres`): `floor_index` and the `boss_ids` that floor draws from.
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

`data/threat/scaling.tres` (`ScalingTable`) holds per-floor `‰` tables for enemy HP, damage and density. Values
come from GA: scaling. No formula in content uses `pow` or `exp`.

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

class_name BossTable
extends RefCounted
## One boss's compiled numbers in sim units (metres, metres per tick, ticks, 1/4096 turns, per mille). Built from
## BossDefinition by ContentCompiler.compile_bosses; give the list to World.set_boss_tables.
## The arena (arena_cells, arena_template) is what the floor generator reads to build the boss room.

var id := &""
var name_key := &""
var kind := ActorStore.Kind.GATEKEEPER
var hp := 1
var radius_m := 1.0
var speed := 0.0
## 1/4096 turns per tick while pursuing (0 = always faces the player).
var turn_rate := 0
var keep_distance_m := 0.0
## Armour by hit direction, as EnemyTable (Damage.target_mult).
var front_half_arc := 0
var front_mult_permille := 1000
var rear_half_arc := 0
var rear_mult_permille := 1000
## Stagger meter: size and decay per tick in milli-points (1000 per damage point), and the stagger's length.
var stagger_size_milli := 1000
var stagger_decay_milli := 0
var stagger_ticks := 150
var attacks: Array[BossAttackTable] = []
## Phases, in order: HP threshold (per mille of max HP), the attack indices it picks from, its entry attack (-1 =
## none), and its speed and cooldown per mille.
var phase_threshold := PackedInt32Array()
var phase_attacks: Array[PackedInt32Array] = []
var phase_entry := PackedInt32Array()
var phase_speed_permille := PackedInt32Array()
var phase_cd_permille := PackedInt32Array()
## The boss room: size in cells and its interior template (a FloorLayout.Template value).
var arena_cells := Vector2i(2, 2)
var arena_template := 0


## The attack index with this id, or -1.
func attack_index(attack_id: StringName) -> int:
	for k in attacks.size():
		if attacks[k].id == attack_id:
			return k
	return -1


## A boss from a floor's pool (indices into World.boss_tables), drawn from `rng` (the map stream). -1 if empty.
static func pick(pool: PackedInt32Array, rng: RngStream) -> int:
	if pool.is_empty():
		return -1
	return pool[rng.range_int(0, pool.size() - 1)]

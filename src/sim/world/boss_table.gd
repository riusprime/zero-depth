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
## Boss challenge (v0.3.0 BX, L17 and L26; BossChallenge). Distances are from the boss's edge to the player's centre.
## Ranged armour: the player's hits deal 1000 per mille up to ranged_full_m, falling linearly to ranged_far_permille
## at ranged_far_m and beyond.
var ranged_full_m := 5.0
var ranged_far_m := 12.0
var ranged_far_permille := 1000
## Punish: beyond punish_distance_m for punish_ticks, it performs attack punish_attack (-1 = none).
var punish_distance_m := 9.0
var punish_ticks := 0
var punish_attack := -1
## Weak point: open for weak_ticks after an attack that opens it; hits from within weak_range_m deal weak_mult and
## fill the stagger meter by weak_stagger (per mille).
var weak_ticks := 0
var weak_range_m := 2.5
var weak_mult_permille := 1000
var weak_stagger_permille := 1000
## v0.4.0 BO: while the weak point is open the front armour doesn't apply (the Warlord lifts its shield).
var weak_drops_armour := false
## Closing arena: it starts at phase close_phase (-1 = not by phase) or after close_after_ticks of fighting (0 = not
## by time); every close_step_ticks the band moves close_step_m inward (0 = never closes), each step marked
## close_warn_ticks first, and stops safe_half_m short of the room's centre on each axis. Standing in the band hurts
## hazard_damage every hazard_ticks.
var close_phase := -1
var close_after_ticks := 0
var close_step_ticks := 1
var close_step_m := 0.0
var close_warn_ticks := 24
var safe_half_m := 5.0
var hazard_damage := 0
var hazard_ticks := 30
## Harder AI: attacks aim where the player will be in lead_ticks at their current velocity.
var lead_ticks := 0
## v0.3.5 AI (owner F3): aimed windups keep tracking the player until their last commit_ticks (0 = they lock at the
## start); for dash_read_ticks after a dash, aimed attacks go at its landing point (0 = off); beyond
## gap_distance_m for gap_ticks, it performs gap_attack, its gap-closer (-1 = none).
var commit_ticks := 0
var dash_read_ticks := 0
var gap_distance_m := 0.0
var gap_ticks := 0
var gap_attack := -1


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

class_name ActorStore
extends RefCounted
## Actors as parallel arrays in ascending id order (SIM_CONTRACTS §4). Index 0 is always the player.
## Kinds are appended, never renumbered, because they are hashed.

## HATCHLING and the bosses (v0.3.0 C): the Brood Mother's small Charger, then one kind per boss (BossAi). The
## Arc Caster and the Bomb Drone (v0.3.5 AI) come after them, then the horde kinds (v0.4.0 EN; SPLITLING is what a
## Splitter splits into).
## Arc Caster and the Bomb Drone (v0.3.5 AI) come after them; then the second boss of each pool and the Hive Lens's
## drones (v0.4.0 BO).
enum Kind {
	PLAYER,
	DUMMY,
	CHARGER,
	WARDEN,
	NEEDLE,
	HATCHLING,
	GATEKEEPER,
	BROOD_MOTHER,
	SIEGE_ENGINE,
	ARC_CASTER,
	BOMB_DRONE,
	SWARMER,
	SPLITTER,
	SPLITLING,
	SHIELD_BEARER,
	MENDER,
	MINE_LAYER,
	SNIPER,
	WARLORD,
	HIVE_LENS,
	FOUNDRY,
	LENS_DRONE,
}

const TEAM_PLAYER := 0
const TEAM_ENEMY := 1
const INT_FIELDS: Array[StringName] = [
	&"ids",
	&"kinds",
	&"teams",
	&"hp",
	&"max_hp",
	&"invuln",
	&"dead",
	&"state",
	&"state_t",
	&"facing",
	&"lock_a",
	&"cd",
	&"fire_cd",
	&"burn_stacks",
	&"burn_t",
	&"burn_cd",
	&"burn_root",
	&"slow_t",
]
## Engine statuses (v0.3.0 G), kept apart from INT_FIELDS so worlds without items hash as before: World hashes
## them (hash_statuses) only when its loadout has items.
const STATUS_FIELDS: Array[StringName] = [
	&"shock_stacks",
	&"shock_t",
	&"bleed_stacks",
	&"bleed_t",
	&"bleed_cd",
	&"frost_stacks",
	&"frost_t",
	&"frozen_t",
	&"freeze_immune",
]
## Enemy AI (v0.3.5 AI; EnemyAi), kept apart from INT_FIELDS so worlds without enemy tables (the kernel golden)
## hash as before: World hashes them (hash_ai) only when its loadout has enemies.
const AI_FIELDS: Array[StringName] = [&"windup", &"pick", &"plan_block", &"power"]
## The staggered plan (v0.4.0 SC; EnemyAi.plan): the walk, refreshed every EnemyAi.PLAN_PERIOD ticks.
const AI_FLOAT_FIELDS: Array[StringName] = [&"plan_x", &"plan_y"]
const FLOAT_FIELDS: Array[StringName] = [
	&"pos_x", &"pos_y", &"radius", &"lock_x", &"lock_y", &"lock_len", &"jitter_x", &"jitter_y"
]

var ids := PackedInt32Array()
var kinds := PackedInt32Array()
var teams := PackedInt32Array()
var pos_x := PackedFloat32Array()
var pos_y := PackedFloat32Array()
var radius := PackedFloat32Array()
var hp := PackedInt32Array()
var max_hp := PackedInt32Array()
## Ticks of invulnerability left (after a hit, a spawn-in, a blink).
var invuln := PackedInt32Array()
## 1 once a KILL was emitted; dead actors leave the store in tick phase 9 (the player stays, dead).
var dead := PackedInt32Array()
## Behaviour state machine (EnemyAi): the state, ticks spent in it, facing, a locked point and angle, a cooldown.
var state := PackedInt32Array()
var state_t := PackedInt32Array()
var facing := PackedInt32Array()
var lock_x := PackedFloat32Array()
var lock_y := PackedFloat32Array()
var lock_a := PackedInt32Array()
## A locked length (a charge's lane, a burst's line), cut short by walls.
var lock_len := PackedFloat32Array()
var cd := PackedInt32Array()
## Dummy AI: ticks until the next shot, and the target offset picked by the heavy pass.
var fire_cd := PackedInt32Array()
var jitter_x := PackedFloat32Array()
var jitter_y := PackedFloat32Array()
## Ember Edge burn (v0.2.0 items): stacks, ticks until it runs out, ticks to the next DoT tick, and the root that
## last added a stack (one stack per root chain).
var burn_stacks := PackedInt32Array()
var burn_t := PackedInt32Array()
var burn_cd := PackedInt32Array()
var burn_root := PackedInt32Array()
## Frost Core slow (v0.2.0 J): ticks left (0 = not slowed). EnemyAi.move scales its speed while it runs.
var slow_t := PackedInt32Array()
## Engines (v0.3.0 G; Engines): shock stacks and ticks until they fade; bleed stacks, ticks until they fade and to
## the next DoT tick; frost stacks and ticks until they fade, ticks left frozen; 1 = never frozen (bosses: frost
## only slows them; set it when the actor is added).
var shock_stacks := PackedInt32Array()
var shock_t := PackedInt32Array()
var bleed_stacks := PackedInt32Array()
var bleed_t := PackedInt32Array()
var bleed_cd := PackedInt32Array()
var frost_stacks := PackedInt32Array()
var frost_t := PackedInt32Array()
var frozen_t := PackedInt32Array()
var freeze_immune := PackedInt32Array()
## Enemy AI (v0.3.5 AI): the current attack's windup in ticks (drawn per attack), and which attack an enemy with
## several (the Arc Caster) is winding up. v0.4.0 EN: a Mender's pick is the id it heals (0 = none), a Sniper's 1
## while it relocates.
var windup := PackedInt32Array()
var pick := PackedInt32Array()
## The staggered plan (v0.4.0 SC): 1 while the straight walk toward the player was blocked by a wall at the last
## check (follow the flow field), and the walk itself (direction × the share of full speed), per tick.
var plan_block := PackedInt32Array()
var plan_x := PackedFloat32Array()
var plan_y := PackedFloat32Array()
## v0.4.0 SC: an enemy's damage factor in per mille (World.add_enemy sets 1000; the spawn director the danger tier's).
var power := PackedInt32Array()


func size() -> int:
	return ids.size()


func add(id: int, kind: int, team: int, p: Vector2, r: float, p_hp: int, p_fire_cd: int) -> int:
	# Packed arrays are values: get() returns a copy, so append to it and set it back.
	for f in INT_FIELDS + STATUS_FIELDS + AI_FIELDS:
		var ai: PackedInt32Array = get(f)
		ai.append(0)
		set(f, ai)
	for f in FLOAT_FIELDS + AI_FLOAT_FIELDS:
		var af: PackedFloat32Array = get(f)
		af.append(0.0)
		set(f, af)
	var i := ids.size() - 1
	ids[i] = id
	kinds[i] = kind
	teams[i] = team
	pos_x[i] = p.x
	pos_y[i] = p.y
	radius[i] = r
	hp[i] = p_hp
	max_hp[i] = p_hp
	fire_cd[i] = p_fire_cd
	return i


func pos(i: int) -> Vector2:
	return Vector2(pos_x[i], pos_y[i])


func set_pos(i: int, p: Vector2) -> void:
	pos_x[i] = p.x
	pos_y[i] = p.y


func index_of(id: int) -> int:
	return ids.bsearch(id) if ids.has(id) else -1


## Removes the entries at the given ascending indices, keeping order.
func remove_sorted(indices: PackedInt32Array) -> void:
	if indices.is_empty():
		return
	# v0.4.0 SC: in place, last first, with the arrays' own remove_at (a native move, not a rebuild).
	for f in INT_FIELDS + STATUS_FIELDS + AI_FIELDS:
		var ai: PackedInt32Array = get(f)
		for k in range(indices.size() - 1, -1, -1):
			ai.remove_at(indices[k])
		set(f, ai)
	for f in FLOAT_FIELDS + AI_FLOAT_FIELDS:
		var af: PackedFloat32Array = get(f)
		for k in range(indices.size() - 1, -1, -1):
			af.remove_at(indices[k])
		set(f, af)


func hash_into(h: StateHasher) -> void:
	for f in INT_FIELDS:
		h.add_ints(get(f))
	for f in FLOAT_FIELDS:
		h.add_f32s(get(f))


## The engine statuses (v0.3.0 G), in STATUS_FIELDS order.
func hash_statuses(h: StateHasher) -> void:
	for f in STATUS_FIELDS:
		h.add_ints(get(f))


## The enemy AI fields (v0.3.5 AI), in AI_FIELDS order.
func hash_ai(h: StateHasher) -> void:
	for f in AI_FIELDS:
		h.add_ints(get(f))
	for f in AI_FLOAT_FIELDS:
		h.add_f32s(get(f))
